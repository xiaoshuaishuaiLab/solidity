// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./interfaces/IUniswapV3Pool.sol";
import "./lib/TickMath.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./lib/Position.sol";
import "./lib/Tick.sol";
import "./lib/Math.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./lib/PoolAddress.sol";
import "./interfaces/IUniswapV3PoolDeployer.sol";
import "./lib/TickBitmap.sol";
import "forge-std/Test.sol";


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
    using Position for Position.Info;
    using Position for mapping(bytes32 => Position.Info);
    using Tick for Tick.Info;
    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for mapping(int16 => uint256);

    error InvalidTickRange();
    error ZeroLiquidity();

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

    /**
    当前tick拥有的流动性，可以理解为当前tick的流动性头寸总和。
    在不考虑gas优化的情况下，把这个变量放到slot0结构体中更合适。
    **/
    uint128 public liquidity;


    constructor() {
        (factory, token0, token1, tickSpacing, fee) = IUniswapV3PoolDeployer(msg.sender).parameters();
    }

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
    }

    struct ModifyPositionParams {
        address owner;
        int24 lowerTick;
        int24 upperTick;
        int128 liquidityDelta;
    }


    function initialize(uint160 startSqrtPriceX96) external {
        require(slot0.sqrtPriceX96 == 0, 'AI');

        int24 tick = TickMath.getTickAtSqrtRatio(startSqrtPriceX96);
        slot0 = Slot0(startSqrtPriceX96, tick);

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
        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = ticks.getFeeGrowthInside(params.lowerTick, params.upperTick,slot0_.tick, feeGrowthGlobal0X128_, feeGrowthGlobal1X128_);


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


    function balance0() internal returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }
}
