// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "../src/interfaces/IUniswapV3Pool.sol";


abstract contract TestUtils {

    function encodeExtra(
        address token0_,
        address token1_,
        address payer
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
            IUniswapV3Pool.CallbackData({
                token0: token0_,
                token1: token1_,
                payer: payer
            })
        );
    }

}