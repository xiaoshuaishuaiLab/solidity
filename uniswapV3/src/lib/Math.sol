// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;
import "./FixedPoint96.sol";
import "abdk-math/ABDKMath64x64.sol";

library Math {
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

}
