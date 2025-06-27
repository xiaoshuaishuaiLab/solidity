// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.14;

import "./interfaces/IUniswapV3Pool.sol";
import "./lib/TickMath.sol";
import "./lib/PoolAddress.sol";


contract UniswapV3Quoter {

    struct QuoteSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        uint256 amountIn;
        uint160 sqrtPriceLimitX96;
    }

    address public immutable factory;


    constructor(address factory_) {
        factory = factory_;
    }


    function quoteSingle(QuoteSingleParams memory params)
    public
    returns (
        uint256 amountOut,
        uint160 sqrtPriceX96After,
        int24 tickAfter
    ){
        IUniswapV3Pool pool = getPool(
            params.tokenIn,
            params.tokenOut,
            params.fee
        );

        bool zeroForOne = params.tokenIn < params.tokenOut;

        try
        pool.swap(
            address(this),
            zeroForOne,
            params.amountIn,
            params.sqrtPriceLimitX96 == 0
                ? (
                zeroForOne
                    ? TickMath.MIN_SQRT_RATIO + 1
                    : TickMath.MAX_SQRT_RATIO - 1
            )
                : params.sqrtPriceLimitX96,
            abi.encode(address(pool))
        )
        {} catch (bytes memory reason) {
            return abi.decode(reason, (uint256, uint160, int24));
        }
    }


    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory data
    ) external view {
        address pool = abi.decode(data, (address));

        uint256 amountOut = amount0Delta > 0
            ? uint256(-amount1Delta)
            : uint256(-amount0Delta);
        (uint160 sqrtPriceX96After, int24 tickAfter,,, ) = IUniswapV3Pool(
            pool
        ).slot0();


        assembly {
            let ptr := mload(0x40)
            mstore(ptr, amountOut)
            mstore(add(ptr, 0x20), sqrtPriceX96After)
            mstore(add(ptr, 0x40), tickAfter)
            revert(ptr, 96)
        }
    }


    // todo 将项目里用到getPool的方法都优化下
    function getPool(
        address token0,
        address token1,
        uint24 fee
    ) internal view returns (IUniswapV3Pool pool) {
        (token0, token1) = token0 < token1
            ? (token0, token1)
            : (token1, token0);
        pool = IUniswapV3Pool(
            PoolAddress.computeAddress(factory, token0, token1, fee)
        );
    }
}