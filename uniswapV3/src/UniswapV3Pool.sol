// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./interfaces/IUniswapV3Pool.sol";


contract UniswapV3Pool is IUniswapV3Pool {
    address public immutable tokenX;
    address public immutable tokenY;
//    address public immutable factory;
    uint24 public  immutable  fee;

    constructor(address _tokenX,
        address _tokenY,
        uint24 _fee){

        tokenX = _tokenX;
        tokenY = _tokenY;
        fee = _fee;
    }
}
