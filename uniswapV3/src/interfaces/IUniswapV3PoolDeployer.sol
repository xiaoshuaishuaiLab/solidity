// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IUniswapV3PoolDeployer {
    struct PoolParameters {
        address factory;
        address token0;
        address token1;
        uint24 tickSpacing;
        uint24 fee;
    }

    function parameters()
    external
    returns (
        address factory,
        address token0,
        address token1,
        uint24 tickSpacing,
        uint24 fee
    );
}
