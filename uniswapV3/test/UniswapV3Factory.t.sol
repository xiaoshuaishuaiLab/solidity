// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./ERC20Mintable.sol";
import "forge-std/Test.sol";
import {UniswapV3Factory} from "../src/UniswapV3Factory.sol";

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
        address pool = factory.createPool(address(weth), address(usdt), 500);
        console.log("pool address: ", pool);
//        factory.createPool();
    }
}
