// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../UniswapV3Pool.sol";


library PoolAddress {
    /**
     这里计算地址的方法，是否可以不用uint160再包装下？
     这里必须用 uint160 包装，因为以太坊地址是 20 字节（160 位），而 keccak256 计算出的哈希值是 32 字节（256 位）。
    直接用 address(uint256(...)) 也可以，但 address 类型底层就是 uint160，用 uint160 明确截断高位更安全、规范
    **/

    function computeAddress(
        address factory,
        address token0,
        address token1,
        uint24 fee
    ) internal pure returns (address pool) {
        require(token0 < token1);

        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1, fee)),
                            keccak256(type(UniswapV3Pool).creationCode)
                        )
                    )
                )
            )
        );
    }
}
