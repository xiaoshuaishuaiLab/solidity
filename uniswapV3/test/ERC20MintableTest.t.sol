// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ERC20Mintable} from "./ERC20Mintable.sol";


contract ERC20MintableTest is Test{

    // forge test  --match-test testERC20Init -vv
    function testERC20Init() public {
       ERC20Mintable weth = new ERC20Mintable("Wrapped Ether","WETH");
       weth.mint(address(this), 1000 ether);
        console.log("WETH balance: ", weth.balanceOf(address(this)));
        assert(weth.balanceOf(address(this)) == 1000 ether);


        ERC20Mintable usdt = new ERC20Mintable("USDT","USDT");
        usdt.mint(address(this), 1000 ether);

        console.log("usdt balance: ", usdt.balanceOf(address(this)));
        assert(usdt.balanceOf(address(this)) == 1000 ether);
    }

}
