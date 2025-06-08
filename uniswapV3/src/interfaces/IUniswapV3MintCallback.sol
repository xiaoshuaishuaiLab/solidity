// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IUniswapV3MintCallback {
    // Callback data structure for Uniswap V3 mint callback
    struct CallbackData {
        address token0;
        address token1;
        uint24 fee;
        address payer;
    }

    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata data) external;
}
