// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.14;

import "./Math.sol";
import "prb-math/Common.sol";

library SwapMath {
    /**
    计算本次 swap 步骤的价格推进、输入/输出代币数量和手续费。
     简要说明：

     输入参数包括当前价格、目标价格、流动性、剩余可交换数量和手续费率。
     计算本次 swap 步骤最多能推进到哪个价格（sqrtPriceNextX96），以及实际消耗的输入代币（amountIn）、获得的输出代币（amountOut）和手续费（feeAmount）。
     该方法会判断本次 swap 是否能推进到目标价格，还是只推进到部分价格，并据此计算实际的代币数量和手续费。
    **/
    function computeSwapStep(
        uint160 sqrtPriceCurrentX96,
        uint160 sqrtPriceTargetX96,
        uint128 liquidity,
        uint256 amountRemaining,
        uint24 fee
    )
        internal
        pure
        returns (
            uint160 sqrtPriceNextX96,
            uint256 amountIn,
            uint256 amountOut,
            uint256 feeAmount
        )
    {
        bool zeroForOne = sqrtPriceCurrentX96 >= sqrtPriceTargetX96;
        uint256 amountRemainingLessFee = mulDiv(
            amountRemaining,
            1e6 - fee,
            1e6
        );

        amountIn = zeroForOne
            ? Math.calcAmount0Delta(
                sqrtPriceCurrentX96,
                sqrtPriceTargetX96,
                liquidity,
                true
            )
            : Math.calcAmount1Delta(
                sqrtPriceCurrentX96,
                sqrtPriceTargetX96,
                liquidity,
                true
            );

        if (amountRemainingLessFee >= amountIn)
            sqrtPriceNextX96 = sqrtPriceTargetX96;
        else
            sqrtPriceNextX96 = Math.getNextSqrtPriceFromInput(
                sqrtPriceCurrentX96,
                liquidity,
                amountRemainingLessFee,
                zeroForOne
            );

        bool max = sqrtPriceNextX96 == sqrtPriceTargetX96;

        if (zeroForOne) {
            amountIn = max
                ? amountIn
                : Math.calcAmount0Delta(
                    sqrtPriceCurrentX96,
                    sqrtPriceNextX96,
                    liquidity,
                    true
                );
            amountOut = Math.calcAmount1Delta(
                sqrtPriceCurrentX96,
                sqrtPriceNextX96,
                liquidity,
                false
            );
        } else {
            amountIn = max
                ? amountIn
                : Math.calcAmount1Delta(
                    sqrtPriceCurrentX96,
                    sqrtPriceNextX96,
                    liquidity,
                    true
                );
            amountOut = Math.calcAmount0Delta(
                sqrtPriceCurrentX96,
                sqrtPriceNextX96,
                liquidity,
                false
            );
        }

        if (!max) {
            feeAmount = amountRemaining - amountIn;
        } else {
            feeAmount = Math.mulDivRoundingUp(amountIn, fee, 1e6 - fee);
        }
    }
}
