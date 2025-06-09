// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "prb-math/Common.sol";
import "./FixedPoint128.sol";
import "./LiquidityMath.sol";

library Position {

    struct Info {
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // token0的数量
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    function get(mapping(bytes32 => Info) storage self, address owner, int24 lowerTick, int24 upperTick)
    internal
    view
    returns (Info storage positionInfo)
    {
        bytes32 key = keccak256(abi.encodePacked(owner, lowerTick, upperTick));
        return self[key];
    }

    function update(
        Info storage self,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal {
        // 这个代码是uniswap v3里，feeGrowthGlobal0X128的累加逻辑，即每一份流动性对应的手续费总和 * FixedPoint128.Q128,
        // 所以下面的tokensOwed0的计算是手续费差值*自己的liquidity/FixedPoint128.Q128
        // feeGrowthGlobal0X128 += FullMath.mulDiv(paid0 - fees0, FixedPoint128.Q128, _liquidity);

       uint128 tokensOwed0 = uint128(
           mulDiv(
               feeGrowthInside0X128 - self.feeGrowthInside0LastX128,
               self.liquidity,
               FixedPoint128.Q128
           )
       );
       uint128 tokensOwed1 = uint128(
           mulDiv(
               feeGrowthInside1X128 - self.feeGrowthInside1LastX128,
               self.liquidity,
               FixedPoint128.Q128
           )
       );

        self.liquidity = LiquidityMath.addLiquidity(
            self.liquidity,
            liquidityDelta
        );

       self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
       self.feeGrowthInside1LastX128 = feeGrowthInside1X128;

       if (tokensOwed0 > 0 || tokensOwed1 > 0) {
           self.tokensOwed0 += tokensOwed0;
           self.tokensOwed1 += tokensOwed1;
       }
    }
}
