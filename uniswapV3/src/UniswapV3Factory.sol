// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./UniswapV3Pool.sol";
import "./interfaces/IUniswapV3PoolDeployer.sol";
import "./interfaces/IUniswapV3Pool.sol";

contract UniswapV3Factory is IUniswapV3PoolDeployer {

    mapping(uint24 => uint24) feeAmountTickSpacing;


    constructor(){
        feeAmountTickSpacing[500] = 10;
        feeAmountTickSpacing[3000] = 60;
    }

    function createPool(
        address tokenX,
        address tokenY,
        uint24 fee
    ) external returns (address pool) {
        (tokenX, tokenY) = tokenX < tokenY ? (tokenX, tokenY) : (tokenY, tokenX);
        // Implementation of pool creation logic goes here
        // This is a placeholder implementation
        bytes32 salt = keccak256(abi.encodePacked(tokenX, tokenY, fee));
//        CREATE2 指令的好处是，只要合约的 bytecode 及 salt 不变，那么创建出来的地址也将不变。
        IUniswapV3Pool v3Pool = new UniswapV3Pool{salt: salt}(address (this),
            tokenX,
            tokenY,
            fee, feeAmountTickSpacing[fee]
        );

        pool = address(v3Pool);
    }
}
