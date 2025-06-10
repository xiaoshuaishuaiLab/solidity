// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;
import "./BitMath.sol";

library TickBitmap {
    /// @notice Computes the position in the mapping where the initialized bit for a tick lives
    /// @param tick The tick for which to compute the position
    /// @return wordPos The key in the mapping containing the word in which the bit is stored
    /// @return bitPos The bit position in the word where the flag is stored
    function position(int24 tick)
    private
    pure
    returns (int16 wordPos, uint8 bitPos)
    {
        wordPos = int16(tick >> 8);
        bitPos = uint8(uint24(tick % 256));
    }


    /// @notice Flips the initialized state for a given tick from false to true, or vice versa
    /// @param self The mapping in which to flip the tick
    /// @param tick The tick to flip
    /// @param tickSpacing The spacing between usable ticks
    // 虽然因为tick可以是负数，tickSpacing是整数，但是为了保证require(tick % tickSpacing == 0)的校验，此处将tickSpacing的类型作为int24
    function flipTick(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal {
        // require 一定要加原因，不然没法定位到是哪里报错了
        require(tick % tickSpacing == 0,"tick % tickSpacing !=0"); // ensure that the tick is spaced
        (int16 wordPos, uint8 bitPos) = position(tick / tickSpacing);
        uint256 mask = 1 << bitPos;
        self[wordPos] ^= mask;
    }


    /// @notice Returns the next initialized tick contained in the same word (or adjacent word) as the tick that is either
    /// to the left (less than or equal to) or right (greater than) of the given tick
    /// @param self The mapping in which to compute the next initialized tick
    /// @param tick The starting tick
    /// @param tickSpacing The spacing between usable ticks
    /// @param lte Whether to search for the next initialized tick to the left (less than or equal to the starting tick)
    /// @return next The next initialized or uninitialized tick up to 256 ticks away from the current tick
    /// @return initialized Whether the next tick is initialized, as the function only searches within up to 256 ticks
    /**
    查找距离当前 tick 最近的、已初始化的 tick（即 liquidity 发生过变化的 tick），查找范围限定在同一个 256 位 word 内（最多 256 个 tick）。
    主要作用：

    给定一个 tick，和 tickSpacing，判断在同一个 word 内，向左（lte=true）或向右（lte=false）最近的已初始化 tick 的位置。
    返回下一个已初始化 tick 的索引（next），以及该 tick 是否真的被初始化（initialized）。
    用途：

    swap、mint、burn 等操作时，需要快速定位下一个流动性边界（已初始化 tick），以便高效计算价格和流动性变化。
    简要流程：

    计算当前 tick 在 bitmap 中的位置（wordPos, bitPos）。
    根据查找方向，构造掩码，筛选出 word 内已初始化的 tick。
    如果有，返回最近的已初始化 tick 的索引和 true；否则返回边界 tick 和 false。
    这样可以极大提升 tick 查找效率，节省 gas。
    todo 画个图解释下
    **/
    function nextInitializedTickWithinOneWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--; // round towards negative infinity

        if (lte) {
            (int16 wordPos, uint8 bitPos) = position(compressed);
            // all the 1s at or to the right of the current bitPos
            uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
            uint256 masked = self[wordPos] & mask;

            // if there are no initialized ticks to the right of or at the current tick, return rightmost in the word
            initialized = masked != 0;
            // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
            next = initialized
                ? (compressed -
                    int24(
                        uint24(bitPos - BitMath.mostSignificantBit(masked))
                    )) * tickSpacing
                : (compressed - int24(uint24(bitPos))) * tickSpacing;
        } else {
            // start from the word of the next tick, since the current tick state doesn't matter
            (int16 wordPos, uint8 bitPos) = position(compressed + 1);
            // all the 1s at or to the left of the bitPos
            uint256 mask = ~((1 << bitPos) - 1);
            uint256 masked = self[wordPos] & mask;

            // if there are no initialized ticks to the left of the current tick, return leftmost in the word
            initialized = masked != 0;
            // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
            next = initialized
                ? (compressed +
                1 +
                    int24(
                        uint24((BitMath.leastSignificantBit(masked) - bitPos))
                    )) * tickSpacing
                : (compressed + 1 + int24(uint24((type(uint8).max - bitPos)))) *
                tickSpacing;
        }
    }
}
