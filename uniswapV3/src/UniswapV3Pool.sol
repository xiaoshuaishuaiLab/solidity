// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./interfaces/IUniswapV3Pool.sol";
import "./lib/TickMath.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import  "./lib/Position.sol";


contract UniswapV3Pool is IUniswapV3Pool {
    error InvalidTickRange();
    error ZeroLiquidity();

    // 在v3源码里，这个成员变量的目的主要负责权限控制，在咱这个简单项目中，暂时用不着，主要是为了计算pool的地址
    address public immutable factory;
    address public immutable token0;
    address public immutable token1;
    uint24 public  immutable  fee;
    uint24 public  immutable  tickSpacing;

    Slot0 public slot0;
    mapping(bytes32 => Position.Info) public positions;

    constructor(address _factory,address _token0,
        address _token1,
        uint24 _fee, uint24 _tickSpacing) {
        factory = _factory;
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
        tickSpacing = _tickSpacing;

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
    function mint(address recipient, int24 lowerTick, int24 upperTick,uint128 amount,bytes calldata data) external returns (uint256 amount0, uint256 amount1) {
        if (
            lowerTick >= upperTick ||
            lowerTick < TickMath.MIN_TICK ||
            upperTick > TickMath.MAX_TICK
        ) revert InvalidTickRange();

        if(amount == 0) revert ZeroLiquidity();


    }

    function _modifyPosition(ModifyPositionParams memory params) internal returns (Position.Info info,uint256 amount0, uint256 amount1) {
        // 这里可以添加逻辑来处理流动性头寸的修改
        // 比如增加或减少流动性，更新头寸状态等

        return (0, 0);
    }


    function balance0() internal returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }
}
