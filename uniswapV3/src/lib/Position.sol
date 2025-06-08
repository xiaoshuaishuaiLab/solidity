// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library Position {

    struct Info {
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }
}
