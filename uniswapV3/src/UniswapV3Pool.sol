// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./interfaces/IUniswapV3Pool.sol";
import "./lib/TickMath.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./lib/Position.sol";
import "./lib/Tick.sol";
import "./lib/Math.sol";
import "./lib/Oracle.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./lib/PoolAddress.sol";
import "./interfaces/IUniswapV3PoolDeployer.sol";
import "./lib/TickBitmap.sol";
import "./lib/SwapMath.sol";
import "forge-std/console2.sol";
import "prb-math/Common.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";



contract UniswapV3Pool is IUniswapV3Pool {
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );
    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );
    // topic0 = "0xac49e518f90a358f652e4400164f05a5d8f7e35e7747279bc3a93dbf584e125a";
    event IncreaseObservationCardinalityNext(
        uint16 observationCardinalityNextOld,
        uint16 observationCardinalityNextNew
    );
    using Position for Position.Info;
    using Position for mapping(bytes32 => Position.Info);
    using Tick for Tick.Info;
    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for mapping(int16 => uint256);
    using Oracle for Oracle.Observation[65535];


    error InvalidTickRange();
    error ZeroLiquidity();
    error NotEnoughLiquidity();
    error InsufficientInputAmount();


    // 在v3源码里，这个成员变量的目的主要负责权限控制，在咱这个简单项目中，暂时用不着，主要是为了计算pool的地址
    address public immutable factory;
    address public immutable token0;
    address public immutable token1;
    uint24 public  immutable  tickSpacing;
    uint24 public  immutable  fee;

    Slot0 public slot0;
    mapping(bytes32 => Position.Info) public positions;
    mapping(int24 => Tick.Info) public ticks;
    mapping(int16 => uint256) public tickBitmap;
    // 当前池子的token0手续费总和
    uint256 public feeGrowthGlobal0X128;
    // 当前池子的token1手续费总和
    uint256 public feeGrowthGlobal1X128;
    Oracle.Observation[65535] public observations;

    /**
    当前tick拥有的流动性，可以理解为当前tick的流动性头寸总和。
    在不考虑gas优化的情况下，把这个变量放到slot0结构体中更合适。
    **/
    uint128 public liquidity;

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
        // Most recent observation index  最新观测点的索引
        uint16 observationIndex;
        // Maximum number of observations  当前可用的观测点数量（历史窗口长度）。
        uint16 observationCardinality;
        // Next maximum number of observations  计划扩容到的观测点数量
        //  看了下 这个 USDC/ETH 交易对的值才是723 https://etherscan.io/address/0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640#events
        uint16 observationCardinalityNext;
    }

    struct ModifyPositionParams {
        address owner;
        int24 lowerTick;
        int24 upperTick;
        int128 liquidityDelta;
    }

    struct SwapState {
        // 本次 swap 剩余待交换的输入或输出数量。
        uint256 amountSpecifiedRemaining;
        // 已累计计算出的输出或输入数量（取决于 swap 方向）。
        uint256 amountCalculated;
        // 当前池子的价格（以 Q96 定点的平方根价格表示）。
        uint160 sqrtPriceX96;
        // 当前价格对应的 tick 索引。
        int24 tick;
        // 当前全局手续费增长值（Q128 定点），用于计算手续费分配。
        uint256 feeGrowthGlobalX128;
        // 当前价格区间内的有效流动性。
        uint128 liquidity;
    }

    struct StepState {
        uint160 sqrtPriceStartX96; // 本次 swap 步骤开始时的价格（Q96 定点的平方根价格）
        int24 nextTick;            // 本次 swap 步骤中即将遇到的下一个 tick 索引
        bool initialized;          // 下一个 tick 是否已初始化（即该 tick 是否有流动性变化）
        uint160 sqrtPriceNextX96;  // 下一个 tick 对应的价格（Q96 定点的平方根价格）
        uint256 amountIn;          // 本次 swap 步骤实际消耗的输入代币数量
        uint256 amountOut;         // 本次 swap 步骤实际获得的输出代币数量
        uint256 feeAmount;         // 本次 swap 步骤产生的手续费数量
    }


    constructor() {
        (factory, token0, token1, tickSpacing, fee) = IUniswapV3PoolDeployer(msg.sender).parameters();
    }

    function initialize(uint160 startSqrtPriceX96) external {
        require(slot0.sqrtPriceX96 == 0, 'AI');


        int24 tick = TickMath.getTickAtSqrtRatio(startSqrtPriceX96);
        (uint16 cardinality, uint16 cardinalityNext) = observations.initialize(
            _blockTimestamp()
        );
        slot0 = Slot0(startSqrtPriceX96, tick,0,cardinality,cardinalityNext);

    }




    // recipient 兑换人，zeroForOne = true ,用token0买token1，价格下降，否则则是token1到token0，amountSpecified 本次交换的输入或输出数量（取决于调用方式）
    //sqrtPriceLimitX96，本次交换允许到达的价格上限/下限（以 sqrt(P) 形式，Q96 定点数），用于限制滑点。
    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) public returns (int256 amount0, int256 amount1) {
        Slot0 memory slot0_ = slot0;
        uint128 liquidity_ = liquidity;
        //        这段校验的作用是：确保 swap 操作时用户设置的价格限制 sqrtPriceLimitX96 合理且在允许范围内，否则就回退（revert）。
        //    具体解释如下：
        //        zeroForOne 为 true 时（即用 token0 换 token1，价格向下走）：
        //        sqrtPriceLimitX96 必须小于当前价格 slot0_.sqrtPriceX96（因为价格只能往下走），且不能小于最小允许值 TickMath.MIN_SQRT_RATIO。
        //        zeroForOne 为 false 时（即用 token1 换 token0，价格向上走）：
        //        sqrtPriceLimitX96 必须大于当前价格 slot0_.sqrtPriceX96（因为价格只能往上走），且不能大于最大允许值 TickMath.MAX_SQRT_RATIO
        if (zeroForOne) {
            if (sqrtPriceLimitX96 > slot0_.sqrtPriceX96 || sqrtPriceLimitX96 < TickMath.MIN_SQRT_RATIO) {
                revert("Invalid sqrtPriceLimitX96 for zeroForOne swap");
            }
        } else {
            if (sqrtPriceLimitX96 < slot0_.sqrtPriceX96 || sqrtPriceLimitX96 > TickMath.MAX_SQRT_RATIO) {
                revert("Invalid sqrtPriceLimitX96 for oneForZero swap");
            }
        }

        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: slot0_.sqrtPriceX96,
            tick: slot0_.tick,
            feeGrowthGlobalX128: zeroForOne ? feeGrowthGlobal0X128 : feeGrowthGlobal1X128,
            liquidity: liquidity_
        });

        while (state.amountSpecifiedRemaining > 0 && state.sqrtPriceX96 != sqrtPriceLimitX96) {
            StepState memory step;
            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.nextTick, step.initialized) = tickBitmap.nextInitializedTickWithinOneWord(
                state.tick,
                int24(tickSpacing),
                zeroForOne
            );

            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.nextTick);

            uint160 sqrtPriceTargetX96;
            if (zeroForOne) {
                if (step.sqrtPriceNextX96 < sqrtPriceLimitX96) {
                    sqrtPriceTargetX96 = sqrtPriceLimitX96;
                } else {
                    sqrtPriceTargetX96 = step.sqrtPriceNextX96;
                }
            } else {
                if (step.sqrtPriceNextX96 < sqrtPriceLimitX96) {
                    sqrtPriceTargetX96 = step.sqrtPriceNextX96;
                } else {
                    sqrtPriceTargetX96 = sqrtPriceLimitX96;
                }
            }

            (
                state.sqrtPriceX96,
                step.amountIn,
                step.amountOut,
                step.feeAmount
            ) = SwapMath.computeSwapStep(state.sqrtPriceX96, sqrtPriceTargetX96,
                state.liquidity, state.amountSpecifiedRemaining, fee);

            state.amountSpecifiedRemaining = state.amountSpecifiedRemaining - (step.amountIn + step.feeAmount);
            state.amountCalculated = state.amountCalculated + step.amountOut;

            // 可以在swap之前就判断liquidity是否大于0
            if (state.liquidity > 0) {
                state.feeGrowthGlobalX128 = state.feeGrowthGlobalX128 + mulDiv(
                    step.feeAmount,
                    FixedPoint128.Q128,
                    state.liquidity
                );
            }

            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                if (step.initialized) {
                    int128 liquidityDelta = ticks.cross(
                        step.nextTick,
                        (
                            zeroForOne
                                ? state.feeGrowthGlobalX128
                                : feeGrowthGlobal0X128
                        ),
                        (
                            zeroForOne
                                ? feeGrowthGlobal1X128
                                : state.feeGrowthGlobalX128
                        )
                    );

                    if (zeroForOne) liquidityDelta = - liquidityDelta;

                    state.liquidity = LiquidityMath.addLiquidity(
                        state.liquidity,
                        liquidityDelta
                    );

                    if (state.liquidity == 0) revert NotEnoughLiquidity();
                }

                state.tick = zeroForOne ? step.nextTick - 1 : step.nextTick;
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                // 为swap后，价格变化很小，不到一个tickSpacing，但没有跨越下一个已初始化的 tick（即没有进入下一个流动性区间），
                // 此时需要根据最新的价格，重新计算当前所在的 tick 索引。
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        // tick 变了
        if (state.tick != slot0_.tick) {
            (
                uint16 observationIndex,
                uint16 observationCardinality
            ) = observations.write(
                slot0_.observationIndex,
                _blockTimestamp(),
                slot0_.tick,
                slot0_.observationCardinality,
                slot0_.observationCardinalityNext
            );

            (
                slot0.sqrtPriceX96,
                slot0.tick,
                slot0.observationIndex,
                slot0.observationCardinality
            ) = (
                state.sqrtPriceX96,
                state.tick,
                observationIndex,
                observationCardinality
            );
        } else {
            slot0.sqrtPriceX96 = state.sqrtPriceX96;
        }
        if (liquidity_ != state.liquidity) liquidity = state.liquidity;

        if (zeroForOne) {
            feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
        } else {
            feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
        }

        if (zeroForOne) {
            amount0 = int256(amountSpecified - state.amountSpecifiedRemaining);
            amount1 = - int256(state.amountCalculated);
        } else {
            amount0 = - int256(state.amountCalculated);
            amount1 = int256(amountSpecified - state.amountSpecifiedRemaining);
        }

        if (zeroForOne) {
            IERC20(token1).transfer(recipient, uint256(-amount1));

            uint256 balance0Before = balance0();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
                amount0,
                amount1,
                data
            );
            if (balance0Before + uint256(amount0) > balance0())
                revert InsufficientInputAmount();
        } else {
            IERC20(token0).transfer(recipient, uint256(-amount0));

            uint256 balance1Before = balance1();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
                amount0,
                amount1,
                data
            );
            if (balance1Before + uint256(amount1) > balance1())
                revert InsufficientInputAmount();
        }

        emit Swap(
            msg.sender,
            recipient,
            amount0,
            amount1,
            slot0.sqrtPriceX96,
            state.liquidity,
            slot0.tick
        );
    }


    /**
    address recipient 参数，会一直都是NonfungiblePositionManager 的合约地址，这样设计的目的是什么?
    这样设计的目的是：NonfungiblePositionManager 合约本身作为所有 Uniswap V3 头寸（position）的托管者，即所有流动性头寸都归属于该合约，由它统一管理和记录。这样做有以下几个原因：
    NFT 头寸托管：每个 position 都对应一个 NFT，NFT 的持有者才是真正的 owner。合约内部用 mapping 记录每个 NFT（tokenId）对应的 position 信息。
    安全性和抽象：用户不直接与 pool 合约交互，而是通过 NonfungiblePositionManager 进行所有操作，便于权限校验、手续费结算、头寸管理等。
    便于 fee 结算和提取：所有头寸的 fee、奖励等都先归集到 NonfungiblePositionManager，用户通过 collect/burn 等接口领取。
    兼容 ERC721：NFT 头寸的转让、授权等都由 NonfungiblePositionManager 统一处理，符合 ERC721 标准。
    所以，mint 时 recipient 固定为 NonfungiblePositionManager 合约地址，实际的“归属权”由 NFT 的持有者决定。
    **/
    function mint(address recipient, int24 lowerTick, int24 upperTick, uint128 amount, bytes calldata data)
    external returns (uint256 amount0, uint256 amount1) {
        if (
            lowerTick >= upperTick ||
            lowerTick < TickMath.MIN_TICK ||
            upperTick > TickMath.MAX_TICK
        ) revert InvalidTickRange();

        if (amount == 0) revert ZeroLiquidity();

        (,int256 amount0In,int256 amount1In) = _modifyPosition(
            ModifyPositionParams({
                owner: recipient,
                lowerTick: lowerTick,
                upperTick: upperTick,
                liquidityDelta: int128(amount)
            })
        );
        console.log("upperTick: %s", upperTick);
        amount0 = uint256(amount0In);
        amount1 = uint256(amount1In);

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) {
            balance0Before = balance0();
        }
        if (amount1 > 0) {
            balance1Before = balance0();
        }

        IUniswapV3MintCallback(recipient).uniswapV3MintCallback(
            amount0,
            amount1,
            data
        );

        if (amount0 > 0 && balance0Before + amount0 > balance0()) {
            revert("Mint: token0 balance mismatch");
        }
        if (amount1 > 0 && balance1Before + amount1 > balance1()) {
            revert("Mint: token1 balance mismatch");
        }

        emit Mint(
            msg.sender,
            recipient,
            lowerTick,
            upperTick,
            amount,
            amount0,
            amount1
        );
    }


    function _modifyPosition(ModifyPositionParams memory params) internal returns (Position.Info storage position, int256 amount0, int256 amount1) {
        // 这里可以添加逻辑来处理流动性头寸的修改
        // 比如增加或减少流动性，更新头寸状态等
        position = positions.get(params.owner, params.lowerTick, params.upperTick);

        // gas 费用优化：将 slot0 结构体的值存储在一个局部变量中，避免多次读取存储
        Slot0 memory slot0_ = slot0;


        uint256 feeGrowthGlobal0X128_ = feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128_ = feeGrowthGlobal1X128;

        bool flippedLower = ticks.update(
            params.lowerTick,
            slot0_.tick,
            int128(params.liquidityDelta),
            feeGrowthGlobal0X128_,
            feeGrowthGlobal1X128_,
            false
        );

        bool flippedUpper = ticks.update(
            params.upperTick,
            slot0_.tick,
            int128(params.liquidityDelta),
            feeGrowthGlobal0X128_,
            feeGrowthGlobal1X128_,
            true
        );

        if (flippedLower) {
            tickBitmap.flipTick(params.lowerTick, int24(tickSpacing));
        }

        if (flippedUpper) {
            tickBitmap.flipTick(params.upperTick, int24(tickSpacing));
        }
        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = ticks.getFeeGrowthInside(params.lowerTick, params.upperTick, slot0_.tick, feeGrowthGlobal0X128_, feeGrowthGlobal1X128_);


        position.update(params.liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128);

        if (slot0_.tick < params.lowerTick) {
            amount0 = Math.calcAmount0Delta(
                TickMath.getSqrtRatioAtTick(params.lowerTick),
                TickMath.getSqrtRatioAtTick(params.upperTick),
                params.liquidityDelta
            );
        } else if (slot0_.tick < params.upperTick) {
            amount0 = Math.calcAmount0Delta(
                slot0_.sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(params.upperTick),
                params.liquidityDelta
            );

            amount1 = Math.calcAmount1Delta(
                TickMath.getSqrtRatioAtTick(params.lowerTick),
                slot0_.sqrtPriceX96,
                params.liquidityDelta
            );
            // 更新当前tick流动性
            liquidity = LiquidityMath.addLiquidity(
                liquidity,
                params.liquidityDelta
            );
        } else {
            amount1 = Math.calcAmount1Delta(
                TickMath.getSqrtRatioAtTick(params.lowerTick),
                TickMath.getSqrtRatioAtTick(params.upperTick),
                params.liquidityDelta
            );
        }
    }


    function observe(uint32[] calldata secondsAgos)
    public
    view
    returns (int56[] memory tickCumulatives)
    {
        return
            observations.observe(
            _blockTimestamp(),
            secondsAgos,
            slot0.tick,
            slot0.observationIndex,
            slot0.observationCardinality
        );
    }


    function increaseObservationCardinalityNext(
        uint16 observationCardinalityNext
    ) public {
        uint16 observationCardinalityNextOld = slot0.observationCardinalityNext;
        uint16 observationCardinalityNextNew = observations.grow(
            observationCardinalityNextOld,
            observationCardinalityNext
        );

        if (observationCardinalityNextNew != observationCardinalityNextOld) {
            slot0.observationCardinalityNext = observationCardinalityNextNew;
            emit IncreaseObservationCardinalityNext(
                observationCardinalityNextOld,
                observationCardinalityNextNew
            );
        }
    }



    function balance0() internal returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }

    function _blockTimestamp() internal view returns (uint32 timestamp) {
        timestamp = uint32(block.timestamp);
    }
}
