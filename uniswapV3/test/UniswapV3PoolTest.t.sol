// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/UniswapV3Factory.sol";
import "../src/UniswapV3Pool.sol";
import "../src/lib/Math.sol";
import "../src/NonfungiblePositionManager.sol";
import "prb-math/Common.sol";
import "./TestUtils.sol";


contract UniswapV3PoolTest is TestUtils, Test {

    ERC20Mintable weth;
    ERC20Mintable usdt;
    UniswapV3Factory factory;
    UniswapV3Pool pool;
    NonfungiblePositionManager ntfManager;
    uint24 constant fee = 3000;
    uint256 constant WETH_BALANCE = 100 ether; // -887272
    uint256 constant USDT_BALANCE = 250000 ether; // -887272

    int24 curTick;
    bytes extra;


    function setUp() public {
        // 已知address (weth) > address (usdt) ，即token0是usdt，token1是weth
        weth = new ERC20Mintable("Wrapped Ether", "WETH");

        usdt = new ERC20Mintable("USDT", "USDT");

        if (address(weth) < address(usdt)) {
            console.log("true weth < usdt");
        } else {
            console.log("false weth > usdt");
        }

        factory = new UniswapV3Factory();
        address poolAddress = factory.createPool(address(weth), address(usdt), fee);
        console.log("pool address: ", poolAddress);
        pool = UniswapV3Pool(poolAddress);
        // 初始价格2500
        pool.initialize(Math.sqrtPFrac(1, 2500));

        (uint160 sqrtPriceX96, int24 tick,,,) = pool.slot0();
        console.log("slot0.sqrtPriceX96: %s", sqrtPriceX96);
        console.log("slot0.tick: %s", tick); // 78244
        curTick = tick;
        ntfManager = new NonfungiblePositionManager(address(factory));

        weth.mint(address(this), WETH_BALANCE);
        usdt.mint(address(this), USDT_BALANCE);


        weth.approve(address(ntfManager), type(uint256).max);
        usdt.approve(address(ntfManager), type(uint256).max);

        // 因为下面有当前合约给pool转账的逻辑，又用了transferFrom方法，所以需要自己给自己授权，或者改用transfer方法
        weth.approve(address(this), type(uint256).max);
        usdt.approve(address(this), type(uint256).max);



        NonfungiblePositionManager.MintParams memory param = NonfungiblePositionManager.MintParams({
            recipient: address(this),
            token0: address(usdt),
            token1: address(weth),
            fee: fee,
            lowerTick: (curTick / 60) * 60 - 120 * 100,
            upperTick: (curTick / 60) * 60 + 120 * 100,
            amount0Desired: 25000 ether,
            amount1Desired: 10 ether,
            amount0Min: 0,
            amount1Min: 0
        });
        uint256 tokenId = ntfManager.mint(param);
        extra = encodeExtra(address(usdt), address(weth), address(this));

        console2.log("wet balanceOf: ", weth.balanceOf(address(this)));
        console2.log("usdt balanceOf: ", usdt.balanceOf(address(this)));
    }

    //  clear ; forge test  --match-test testSwapWithNoPriceLimit -vvvvv
    // 滑点区间很高 1 ether都能被兑换
    function testSwapWithNoPriceLimit() public {

        uint256 amountIn = 1 ether;
        uint160 sqrtPriceLimitX96 = Math.sqrtPFrac(1, 2000);
        (int256 amount0, int256 amount1) = pool.swap(address(this), false, amountIn, sqrtPriceLimitX96, extra);
        assertEq(amount1,1 ether);
        assertEq(amount0,-2385181619683654192399);
    }


    //  clear ; forge test  --match-test testSwapWithPriceLimit -vvvvv
    // 滑点区间很小 1 ether不都能被兑换
    function testSwapWithPriceLimit() public {

        uint256 amountIn = 1 ether;
        uint160 sqrtPriceLimitX96 = Math.sqrtPFrac(1, 2400);
        (int256 amount0, int256 amount1) = pool.swap(address(this), false, amountIn, sqrtPriceLimitX96, extra);
        assertEq(amount1,458301521841489147);
        console2.log("amount0", amount0);
    }


    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) public {

        IUniswapV3Pool.CallbackData memory extra = abi.decode(
            data,
            (IUniswapV3Pool.CallbackData)
        );


        if (amount0 > 0) {
//            IERC20(extra.token0).transfer(msg.sender, uint256(amount0));
            IERC20(extra.token0).transferFrom(extra.payer, msg.sender, uint256(amount0));
        }

        if (amount1 > 0) {
//            IERC20(extra.token1).transfer(msg.sender, uint256(amount1));
            IERC20(extra.token1).transferFrom(extra.payer, msg.sender, uint256(amount1));
        }

    }

}