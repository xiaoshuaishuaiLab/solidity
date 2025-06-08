// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/UniswapV3Factory.sol";
import "../src/UniswapV3Pool.sol";
import "../src/lib/Math.sol";


contract UniswapV3FactoryTest is Test{
    ERC20Mintable weth;
    ERC20Mintable usdt;

    UniswapV3Factory factory;
    function setUp() public  {
        weth = new ERC20Mintable("Wrapped Ether","WETH");
        usdt = new ERC20Mintable("USDT","USDT");
        factory = new UniswapV3Factory();
    }

    // forge test  --match-test testCreatePool -vv
    function testCreatePool() public {
        address poolAddress = factory.createPool(address(weth), address(usdt), 500);
        console.log("pool address: ", poolAddress);
        UniswapV3Pool pool = UniswapV3Pool(poolAddress);
        // 初始价格2500
        pool.initialize(Math.sqrtP(2500));
        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        console.log("slot0.sqrtPriceX96: %s", sqrtPriceX96);
        console.log("slot0.tick: %s", tick);


    }


}
