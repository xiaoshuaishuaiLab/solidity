# about
在学习了solidity基础，uniswap V3后，以学习目的，实现的uniswap V3的逻辑

## 完成内容
- [x] 创建流动性池 uniswapV3/src/UniswapV3Factory#createPool
- [x] 质押流动性 uniswapV3/src/NonfungiblePositionManager#mint
- [x] 交换代币 uniswapV3/src/UniswapV3Pool#swap
- [x]  合约报价  uniswapV3/src/UniswapV3Quoter#quoteSingle
- []  移除流动性
- []  价格预言机
- []  pair合约
- []  取回质押代币
- []  前端界面 (from https://github.com/Jeiwan/uniswapv3-book)
- []  部署



# 参考资料
梁培利老师的视频，深入浅出的讲解了uniswap V2到v3的演进.
https://www.bilibili.com/video/BV1b3o4YzEnF


手把手教你构建一个uniswap v3，写的浅显易懂，直接阅读英文难度不是很大
https://github.com/Jeiwan/uniswapv3-book

其中文翻译见
https://github.com/ryang-max/uniswapV3-book-zh-cn

白皮书
https://app.uniswap.org/whitepaper-v3.pdf

参考博客
https://paco0x.org/uniswap-v3-1/

# lp管理工具
专业化和工具化： 催生了各种自动化工具和策略协议（如 Arrakis Finance, Gamma Strategies 等），帮助 LP 更好地管理 V3 头寸，例如自动再平衡、自动复投费用等，从而降低了普通用户的管理负担。

# 审计报告
https://github.com/abdk-consulting/audits/blob/main/uniswap/ABDK_UniswapV3_v_1.pdf

看审计报告可以学到一些东西

# 质押策略 
https://atise.medium.com/liquidity-provider-strategies-for-uniswap-v3-an-introduction-42970cf9df4


# install
```
forge install  paulrberg/prb-math
```

