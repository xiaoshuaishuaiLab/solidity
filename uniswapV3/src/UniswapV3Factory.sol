// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./UniswapV3Pool.sol";
import "./interfaces/IUniswapV3PoolDeployer.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "forge-std/console2.sol";

import "./lib/PoolAddress.sol";


contract UniswapV3Factory is IUniswapV3PoolDeployer {

    mapping(uint24 => uint24) feeAmountTickSpacing;

    PoolParameters public parameters;

    constructor(){
        feeAmountTickSpacing[500] = 10;
        feeAmountTickSpacing[3000] = 60;
    }

    // 注意，此处无需关心tokenA，tokenB的大小，但是自此之后所有的操作，都需要明确知道token的大小，也会用token0来表示较小的那个
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool) {
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        // Implementation of pool creation logic goes here
        // This is a placeholder implementation
        bytes32 salt = keccak256(abi.encodePacked(tokenA, tokenB, fee));
        /*
        CREATE2 指令的好处是，只要合约的 bytecode 及 salt 不变，那么创建出来的地址也将不变。
        注意此处不能用直接用下面的方式传递构造函数的参数，
             UniswapV3Pool v3Pool = new UniswapV3Pool{salt: salt}(address (this),
            tokenX,
            tokenY,
            fee, feeAmountTickSpacing[fee]
        );
        你用 new UniswapV3Pool{salt: salt}(...) 部署时，底层 create2 的 init_code 是 creationCode + abi.encode(constructor args)，即合约字节码+构造参数。
        因为在PoolAddress#computeAddress里是无参的，所以咱们需要将UniswapV3Pool改为无参的构造函数
        */

        parameters = PoolParameters({
            factory: address(this),
            token0: tokenA,
            token1: tokenB,
            tickSpacing: feeAmountTickSpacing[fee],
            fee: fee
        });
        UniswapV3Pool v3Pool = new UniswapV3Pool{salt: salt}();

        pool = address(v3Pool);

        delete parameters; // 此处类似与threadLocal的那种用法感觉
    }
}
