// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./LiquidityMath.sol";

library Tick {

    struct Info {
        bool initialized;
        // total liquidity at tick
        uint128 liquidityGross;
        // amount of liqudiity added or subtracted when tick is crossed
        int128 liquidityNet;
        // fee growth on the other side of this tick (relative to the current tick)
        // 以tick为界，分为左右，和curTick不在一边的fee的总和，假如我们再定义一个变量feeGrowthInside0X128,feeGrowthInside0X128 = fg - feeGrowthOutside0X128;
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
    }


    function update(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        int24 currentTick,
        int128 liquidityDelta,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        bool upper
    ) internal returns (bool flipped) {
        // 这一行代码不用考虑tickInfo是空的情况吗？
        // 在 Solidity 中，mapping 访问一个不存在的 key（如 self[tick]）时，会自动返回该结构体的“默认值”（即所有字段为 0/false）。
        //tickInfo 始终是一个合法的 storage 引用，后续对其字段的赋值会自动初始化该 slot。
        //
        //所以，不存在“空指针”或“未初始化”异常，直接使用即可。
        Tick.Info storage tickInfo = self[tick];

        uint128 liquidityBefore = tickInfo.liquidityGross;
        uint128 liquidityAfter = LiquidityMath.addLiquidity(
            liquidityBefore,
            liquidityDelta
        );

        /*
        这行代码用于判断 tick 的激活状态是否发生了改变。让我来详细解释：

        liquidityBefore == 0 判断更新前该 tick 是否没有流动性
        liquidityAfter == 0 判断更新后该 tick 是否没有流动性
        != 操作符比较这两个布尔值是否不相等
        所以：
        如果更新前后流动性状态不同（一个为 0，一个不为 0），则 flipped = true
        如果更新前后流动性状态相同（都为 0 或都不为 0），则 flipped = false
        具体场景：

        如果之前没有流动性（liquidityBefore == 0）且现在添加了流动性（liquidityAfter != 0）
        (true) != (false) = true
        tick 被激活
        如果之前有流动性（liquidityBefore != 0）且现在流动性被完全移除（liquidityAfter == 0）
        (false) != (true) = true
        tick 被关闭
        如果之前有流动性且现在仍有流动性，或之前没有流动性现在也没有

        (false) != (false) 或 (true) != (true) = false
        tick 状态未改变
        这个值被用于 TickBitmap 中更新 tick 的位图索引。

        */
        flipped = (liquidityAfter == 0) != (liquidityBefore == 0);

        /*
        if (liquidityBefore == 0) - 判断这是否是 tick 的首次初始化（之前没有流动性）


        if (tick <= currentTick) - 判断这个 tick 是否在当前价格以下或等于当前价格


        如果是，就将当前全局累计手续费设为该 tick 的 outside 手续费
        这是一个重要的约定：认为该 tick 以下的所有历史手续费都已经被收集了
        tickInfo.feeGrowthOutsideX128 的设置：


        对于低于当前价格的 tick：outside = global（认为下方费用都已收集）
        对于高于当前价格的 tick：outside = 0（认为上方还没产生费用）
        tickInfo.initialized = true - 标记该 tick 已被初始化


        这种设计用于正确追踪流动性区间内的手续费。当价格穿过 tick 时，可以通过 outside 值计算区间内实际产生的手续费。

        这是 Uniswap V3 手续费计算机制的基础部分，确保了不同价格区间的流动性提供者能够准确获得其应得的手续费。

        */
        if (liquidityBefore == 0) {
            // by convention, assume that all previous fees were collected below
            // the tick
            if (tick <= currentTick) {
                tickInfo.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                tickInfo.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
            }

            tickInfo.initialized = true;
        }

        tickInfo.liquidityGross = liquidityAfter;
        tickInfo.liquidityNet = upper
            ? int128(int256(tickInfo.liquidityNet) - liquidityDelta)
            : int128(int256(tickInfo.liquidityNet) + liquidityDelta);
    }


    function cross(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal returns (int128 liquidityDelta) {
        Tick.Info storage info = self[tick];
        info.feeGrowthOutside0X128 =
            feeGrowthGlobal0X128 -
            info.feeGrowthOutside0X128;
        info.feeGrowthOutside1X128 =
            feeGrowthGlobal1X128 -
            info.feeGrowthOutside1X128;
        liquidityDelta = info.liquidityNet;
    }




    function getFeeGrowthInside(
        mapping(int24 => Tick.Info) storage self,
        int24 lowerTick_,
        int24 upperTick_,
        int24 currentTick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    )
    internal
    view
    returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        Tick.Info storage lowerTick = self[lowerTick_];
        Tick.Info storage upperTick = self[upperTick_];

        uint256 feeGrowthBelow0X128;
        uint256 feeGrowthBelow1X128;
        if (currentTick >= lowerTick_) {
            feeGrowthBelow0X128 = lowerTick.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = lowerTick.feeGrowthOutside1X128;
        } else {
            feeGrowthBelow0X128 =
                feeGrowthGlobal0X128 -
                lowerTick.feeGrowthOutside0X128;
            feeGrowthBelow1X128 =
                feeGrowthGlobal1X128 -
                lowerTick.feeGrowthOutside1X128;
        }

        uint256 feeGrowthAbove0X128;
        uint256 feeGrowthAbove1X128;
        if (currentTick < upperTick_) {
            feeGrowthAbove0X128 = upperTick.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = upperTick.feeGrowthOutside1X128;
        } else {
            feeGrowthAbove0X128 =
                feeGrowthGlobal0X128 -
                upperTick.feeGrowthOutside0X128;
            feeGrowthAbove1X128 =
                feeGrowthGlobal1X128 -
                upperTick.feeGrowthOutside1X128;
        }

        feeGrowthInside0X128 =
            feeGrowthGlobal0X128 -
            feeGrowthBelow0X128 -
            feeGrowthAbove0X128;
        feeGrowthInside1X128 =
            feeGrowthGlobal1X128 -
            feeGrowthBelow1X128 -
            feeGrowthAbove1X128;
    }
}
