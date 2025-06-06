// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./UniswapV3Pool.sol";
import   "./interfaces/IUniswapV3PoolDeployer.sol";
import  "./interfaces/IUniswapV3Pool.sol";

contract UniswapV3Factory is IUniswapV3PoolDeployer{

    constructor(){

    }

    function createPool(
        address tokenX,
        address tokenY,
        uint24 fee
    ) external  returns (address pool) {

        (tokenX,tokenY) = tokenX<tokenY?(tokenX,tokenY):(tokenY,tokenX);
        // Implementation of pool creation logic goes here
        // This is a placeholder implementation
        bytes32 salt = keccak256(abi.encodePacked(tokenX,tokenY,fee));
        IUniswapV3Pool v3Pool = new UniswapV3Pool{salt: salt}(
            tokenX,
            tokenY,
            fee
        );


        pool = address(v3Pool);
    }
}
