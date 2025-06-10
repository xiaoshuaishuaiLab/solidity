// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "./FixedPoint96.sol";
import "abdk-math/ABDKMath64x64.sol";
import "prb-math/Common.sol";

library Math {

    function calcAmount0Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount0) {
        if (sqrtPriceAX96 > sqrtPriceBX96)
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        require(sqrtPriceAX96 > 0);

        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 numerator2 = sqrtPriceBX96 - sqrtPriceAX96;

        if (roundUp) {
            amount0 = divRoundingUp(
                mulDivRoundingUp(numerator1, numerator2, sqrtPriceBX96),
                sqrtPriceAX96
            );
        } else {
            amount0 =
                mulDiv(numerator1, numerator2, sqrtPriceBX96) /
                sqrtPriceAX96;
        }
    }

    function calcAmount1Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount1) {
        if (sqrtPriceAX96 > sqrtPriceBX96)
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        if (roundUp) {
            amount1 = mulDivRoundingUp(
                liquidity,
                (sqrtPriceBX96 - sqrtPriceAX96),
                FixedPoint96.Q96
            );
        } else {
            amount1 = mulDiv(
                liquidity,
                (sqrtPriceBX96 - sqrtPriceAX96),
                FixedPoint96.Q96
            );
        }
    }


    function calcAmount0Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        int128 liquidity
    ) internal pure returns (int256 amount0) {
        /*
        对于 calcAmount1Delta 方法，当liquidity< 0 ,不向上取整，是因为移出流动性的时候，不能多给用户钱是吗？
        当 liquidity < 0 时，表示用户在移除流动性。此时如果向上取整，可能会导致多给用户一点 token，造成资金池损失。因此，移除流动性时要用向下取整（默认整除）
        ，保证不会多给用户钱，确保资金池安全。添加流动性时则用向上取整，避免用户因精度损失而吃亏。
        */
        amount0 = liquidity < 0
            ? -int256(
                calcAmount0Delta(
                    sqrtPriceAX96,
                    sqrtPriceBX96,
                    uint128(-liquidity),
                    false
                )
            )
            : int256(
                calcAmount0Delta(
                    sqrtPriceAX96,
                    sqrtPriceBX96,
                    uint128(liquidity),
                    true
                )
            );
    }

    function calcAmount1Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        int128 liquidity
    ) internal pure returns (int256 amount1) {
        amount1 = liquidity < 0
            ? -int256(
                calcAmount1Delta(
                    sqrtPriceAX96,
                    sqrtPriceBX96,
                    uint128(-liquidity),
                    false
                )
            )
            : int256(
                calcAmount1Delta(
                    sqrtPriceAX96,
                    sqrtPriceBX96,
                    uint128(liquidity),
                    true
                )
            );
    }

     function getNextSqrtPriceFromInput(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtPriceNextX96) {
        sqrtPriceNextX96 = zeroForOne
            ? getNextSqrtPriceFromAmount0RoundingUp(
                sqrtPriceX96,
                liquidity,
                amountIn
            )
            : getNextSqrtPriceFromAmount1RoundingDown(
                sqrtPriceX96,
                liquidity,
                amountIn
            );
    }



    // @return math.sqrt(price) * 2 ** 96
    // ABDKMath64x64.sqrt 内部又进行了一次 << 64 操作，所以开根号后只应该左移FixedPoint96.RESOLUTION - 64
    function sqrtP(uint256 price) internal pure returns (uint160) {
        return
            uint160(
            int160(
                ABDKMath64x64.sqrt(int128(int256(price << 64))) <<
                (FixedPoint96.RESOLUTION - 64)
            )
        );
    }

    // 处理价格是小数的情况
    function sqrtPFrac(uint256 numerator, uint256 denominator) internal pure returns (uint160) {
        return
            uint160(
            int160(
                ABDKMath64x64.sqrt(int128(int256(mulDiv(numerator << 64,1,denominator)))) <<
                (FixedPoint96.RESOLUTION - 64)
            )
        );
    }

function getNextSqrtPriceFromAmount0RoundingUp(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn
    ) internal pure returns (uint160) {
        uint256 numerator = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 product = amountIn * sqrtPriceX96;

        // If product doesn't overflow, use the precise formula.
        if (product / amountIn == sqrtPriceX96) {
            uint256 denominator = numerator + product;
            if (denominator >= numerator) {
                return
                    uint160(
                        mulDivRoundingUp(numerator, sqrtPriceX96, denominator)
                    );
            }
        }

        // If product overflows, use a less precise formula.
        return
            uint160(
                divRoundingUp(numerator, (numerator / sqrtPriceX96) + amountIn)
            );
    }

    function getNextSqrtPriceFromAmount1RoundingDown(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn
    ) internal pure returns (uint160) {
        return
            uint160(
                uint256(sqrtPriceX96) +
                    mulDiv(amountIn, FixedPoint96.Q96, liquidity)
            );
    }


    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }



    function divRoundingUp(uint256 numerator, uint256 denominator)
    internal
    pure
    returns (uint256 result)
    {
        assembly {
            result := add(
                div(numerator, denominator),
                gt(mod(numerator, denominator), 0)
            )
        }
    }
}
