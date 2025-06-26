// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IUniswapV3Pool {
    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }

    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256, int256);

    function slot0()
    external
    view
    returns (
        uint160 sqrtPriceX96,
        int24 tick
//    ,
//        uint16 observationIndex,
//        uint16 observationCardinality,
//        uint16 observationCardinalityNext
    );

}
