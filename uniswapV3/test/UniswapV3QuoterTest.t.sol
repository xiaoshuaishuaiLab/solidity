// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/UniswapV3Factory.sol";
import "../src/UniswapV3Pool.sol";
import "../src/lib/Math.sol";
import "../src/NonfungiblePositionManager.sol";
import "../src/UniswapV3Quoter.sol";

import "prb-math/Common.sol";


contract UniswapV3QuoterTest is Test{


    ERC20Mintable weth;
    ERC20Mintable usdt;
    ERC20Mintable uni;

    UniswapV3Factory factory;
    UniswapV3Pool pool;
    NonfungiblePositionManager ntfManager;
//    ERC20Mintable uni;
    UniswapV3Quoter quoter;



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
            console.log("false weth > usdt");
        }

        factory = new UniswapV3Factory();
        address poolAddress = factory.createPool(address(weth), address(usdt), fee);
        console.log("pool address: ", poolAddress);
        pool = UniswapV3Pool(poolAddress);
        // 初始价格2500
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
        weth.approve(address(ntfManager), type(uint256).max);
        usdt.approve(address(ntfManager), type(uint256).max);

        NonfungiblePositionManager.MintParams memory param = NonfungiblePositionManager.MintParams({
            recipient:address(this),
            token0: address(usdt),
            token1: address(weth),
            fee: fee,
            lowerTick: (curTick/60) * 60  - 120 * 100,
            upperTick: (curTick/60) * 60 + 120 * 100,
            amount0Desired: 25000 ether,
            amount1Desired: 10 ether,
            amount0Min: 0,
            amount1Min: 0
        });

        uint256 tokenId = ntfManager.mint(param);
        quoter = new UniswapV3Quoter(address(factory));


    }
   //  forge test  --match-test testQuoteUSDTforETH -vvvvv
    function testQuoteUSDTForETH() public {
        (uint256 amountOut, uint160 sqrtPriceX96After, int24 tickAfter) = quoter
            .quoteSingle(
            UniswapV3Quoter.QuoteSingleParams({
                tokenIn: address(weth),
                tokenOut: address(usdt),
                fee: fee,
                amountIn: 1 ether,
                sqrtPriceLimitX96: Math.sqrtPFrac(1,2000)
            })
        );
        assertEq(amountOut,2385181619683654192399);
    }


}
