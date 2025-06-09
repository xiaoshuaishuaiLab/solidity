// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/UniswapV3Factory.sol";
import "../src/UniswapV3Pool.sol";
import "../src/lib/Math.sol";
import "../src/NonfungiblePositionManager.sol";
import "prb-math/Common.sol";



contract NonfungiblePositionManagerTest {

    ERC20Mintable weth;
    ERC20Mintable usdt;
    UniswapV3Factory factory;
    UniswapV3Pool pool;
    NonfungiblePositionManager ntfManager;
    uint24 constant fee = 3000;
    uint256 constant WETH_BALANCE = 100 ether; // -887272
    uint256 constant USDT_BALANCE = 250000 ether; // -887272

    int24 curTick;

    function setUp() public  {
        // 已知address (weth) > address (usdt) ，即token0是usdt，token1是weth
        weth = new ERC20Mintable("Wrapped Ether","WETH");

        usdt = new ERC20Mintable("USDT","USDT");

        if(address (weth) < address (usdt)) {
            console.log("true weth < usdt");
        } else {
            console.log("false weth < usdt");
        }

        factory = new UniswapV3Factory();
        address poolAddress = factory.createPool(address(weth), address(usdt), fee);
        console.log("pool address: ", poolAddress);
        pool = UniswapV3Pool(poolAddress);
        // 初始价格2500
//        pool.initialize(Math.sqrtP(mulDiv(1,1,2500)));
        pool.initialize(Math.sqrtPFrac(1,2500));

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        console.log("slot0.sqrtPriceX96: %s", sqrtPriceX96);
        console.log("slot0.tick: %s", tick); // 78244
        curTick = tick;
        ntfManager = new NonfungiblePositionManager(address(factory));

        weth.mint(address(this), WETH_BALANCE);
        usdt.mint(address(this),  USDT_BALANCE);

        console.log("wet balanceOf: ", weth.balanceOf(address(this)));
        console.log("usdt balanceOf: ", usdt.balanceOf(address(this)));
//
        weth.approve(address(ntfManager), type(uint256).max);
        usdt.approve(address(ntfManager), type(uint256).max);

    }

    // forge test  --match-test testMint -vvvv
    function testMint() public {
        // int24 tickLower = ; // 72244
        // int24 tickUpper = 78244 + 60 * 100; // 84,244

        NonfungiblePositionManager.MintParams memory param = NonfungiblePositionManager.MintParams({
            recipient:address(this),
            token0: address(usdt),
            token1: address(weth),
            fee: fee,
            lowerTick: curTick - 120 * 100,
            upperTick: curTick + 120 * 100,
            amount0Desired: 25000 ether,
            amount1Desired: 10 ether,
            amount0Min: 0,
            amount1Min: 0
        });
        console.log("begin mint");
        uint256 tokenId = ntfManager.mint(param);
        console.log("tokenId: ", tokenId);
        console.log("wet balanceOf: ", weth.balanceOf(address(this)));
        console.log("usdt balanceOf: ", usdt.balanceOf(address(this)));
        console.log("pool.liquidity: ", pool.liquidity());

    }


}
