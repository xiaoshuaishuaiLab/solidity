// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./UniswapV3Pool.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./lib/LiquidityMath.sol";
import "./lib/PoolAddress.sol";
import "openzeppelin/contracts/token/ERC721/ERC721.sol";
import "forge-std/Test.sol";


contract NonfungiblePositionManager is ERC721, IUniswapV3MintCallback {
    uint256 private _nextTokenId;
    address public immutable factory;


    constructor(address _factory)
    ERC721("uniswap v3 LP", "LP")
    {
        factory = _factory;
    }

    struct TokenPosition {
        address pool;
        int24 lowerTick;
        int24 upperTick;
    }

    mapping(uint256 => TokenPosition) public tokenPositions;



    struct MintParams {
        address recipient;
        address token0;
        address token1;
        uint24 fee;
        int24 lowerTick;
        int24 upperTick;
        // 这两个参数是用户希望添加的流动性数量
        uint256 amount0Desired;
        uint256 amount1Desired;
        // 这两个参数是用户希望添加的流动性数量的最小值,用于滑点常见检测，todo 暂时先不管
        uint256 amount0Min;
        uint256 amount1Min;
    }


    function mint(MintParams calldata params) external returns (uint256 tokenId) {
        UniswapV3Pool pool = getPool(params);
        console.log("pool address: %s", address(pool));
        (uint160 sqrtPriceX96,) = pool.slot0();

        uint128 liquidity = LiquidityMath.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(params.lowerTick),
            TickMath.getSqrtRatioAtTick(params.upperTick),
            params.amount0Desired,
            params.amount1Desired
        );

//        mint(address recipient, int24 lowerTick, int24 upperTick,uint128 amount,bytes calldata data)

        (uint256 amount0, uint256 amount1) = pool.mint(address(this), params.lowerTick, params.upperTick, liquidity, abi.encode(
            IUniswapV3MintCallback.CallbackData({
                token0: pool.token0(),
                token1: pool.token1(),
                fee: pool.fee(),
                payer: msg.sender
            })));


        tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);

        tokenPositions[tokenId] = TokenPosition({
            pool: address(pool),
            lowerTick: params.lowerTick,
            upperTick: params.upperTick
        });
    }


    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata data) external {
        IUniswapV3MintCallback.CallbackData memory callbackData = abi.decode(data, (IUniswapV3MintCallback.CallbackData));
        address  poolAddress = PoolAddress.computeAddress(factory, callbackData.token0, callbackData.token1, callbackData.fee);

        require(msg.sender == poolAddress, "Invalid pool");

        if (callbackData.token0 != address(0) && amount0 > 0) {
            IERC20(callbackData.token0).transferFrom(callbackData.payer, msg.sender, amount0);
        }
        if (callbackData.token1 != address(0) && amount1 > 0) {
            IERC20(callbackData.token1).transferFrom(callbackData.payer, msg.sender, amount1);
        }

    }

    function getPool(MintParams calldata params) internal view returns (UniswapV3Pool pool) {
        (address token0, address token1) = params.token0 < params.token1
            ? (params.token0, params.token1)
            : (params.token1, params.token0);
        pool = UniswapV3Pool(PoolAddress.computeAddress(factory, token0, token1, params.fee));
    }


}
