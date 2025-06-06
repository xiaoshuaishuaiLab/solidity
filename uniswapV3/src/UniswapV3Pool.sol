// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./interfaces/IUniswapV3Pool.sol";
import  "./lib/TickMath.sol";


contract UniswapV3Pool is IUniswapV3Pool {


    address public immutable tokenX;
    address public immutable tokenY;
//    address public immutable factory;
    uint24 public  immutable  fee;
    uint24 public  immutable  tickSpacing;

    Slot0 public slot0;

    constructor(address _tokenX,
        address _tokenY,
        uint24 _fee,uint24 _tickSpacing) {
        tokenX = _tokenX;
        tokenY = _tokenY;
        fee = _fee;
        tickSpacing = _tickSpacing;
    }

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24  tick;
    }

    function initialize(uint160 startSqrtPriceX96) external  {
        require(slot0.sqrtPriceX96 == 0, 'AI');

        int24 tick = TickMath.getTickAtSqrtRatio(startSqrtPriceX96);

        slot0 = Slot0(startSqrtPriceX96, tick);

    }
}
