# ERC1155 多代币标准详解

## 📚 项目文件说明

本项目包含三个核心文件，帮助你深入理解ERC1155标准：

1. **IERC1155.sol** - ERC1155接口定义
2. **ERC1155.sol** - 完整的ERC1155实现（包含详细注释）
3. **GameItemsERC1155.sol** - 实际应用示例（游戏道具系统）

---

## 🎯 ERC1155核心概念

### 什么是ERC1155？

ERC1155是以太坊上的**多代币标准**，由Enjin团队提出。与ERC20和ERC721不同，它可以在**一个合约**中同时管理：

- ✅ **同质化代币**（Fungible Tokens - FT）：如游戏金币、积分
- ✅ **非同质化代币**（Non-Fungible Tokens - NFT）：如独特的游戏装备
- ✅ **半同质化代币**（Semi-Fungible Tokens）：如限量版道具

### 为什么使用ERC1155？

| 对比项 | ERC20 | ERC721 | ERC1155 |
|--------|-------|--------|---------|
| 代币类型 | 仅同质化 | 仅非同质化 | 两者皆可 |
| 批量操作 | ❌ | ❌ | ✅ |
| Gas效率 | 中等 | 低 | 高 |
| 应用场景 | 货币、积分 | 艺术品、收藏品 | 游戏、元宇宙 |

**优势：**
- 批量转账节省Gas（一次可以转移多种代币）
- 单个合约管理所有代币类型
- 更灵活的代币设计

---

## 🏗️ 核心数据结构

### 1. 余额映射（最重要！）

```solidity
// 嵌套映射：代币ID => (账户地址 => 余额)
mapping(uint256 => mapping(address => uint256)) private _balances;
```

**理解方式：**
```
_balances[1][Alice] = 100    // Alice持有100个ID为1的代币（如金币）
_balances[1][Bob] = 50       // Bob持有50个ID为1的代币
_balances[2][Alice] = 1      // Alice持有1个ID为2的代币（如稀有剑）
_balances[1001][Charlie] = 1 // Charlie持有1个ID为1001的NFT
```

**为什么是嵌套映射？**
- 第一层按代币ID分类
- 第二层存储每个地址的余额
- 高效查询任意账户的任意代币余额

### 2. 授权映射

```solidity
// 所有者 => (操作者 => 是否授权)
mapping(address => mapping(address => bool)) private _operatorApprovals;
```

**注意：这是"全部授权"！**
```
_operatorApprovals[Alice][Bob] = true
// 表示Alice授权Bob操作Alice的所有代币（所有ID）
```

与ERC20/ERC721不同：
- ERC20: `approve(spender, amount)` - 授权特定数量
- ERC721: `approve(spender, tokenId)` - 授权特定NFT
- ERC1155: `setApprovalForAll(operator, true)` - 授权所有代币

---

## 🔑 核心方法解析

### 查询类方法

#### `balanceOf(address account, uint256 id) → uint256`
查询单个账户持有的某种代币数量。

```solidity
uint256 goldBalance = token.balanceOf(Alice, 1); // Alice的金币数量
```

#### `balanceOfBatch(address[] accounts, uint256[] ids) → uint256[]`
批量查询多个账户的多种代币余额。

```solidity
address[] memory accounts = [Alice, Bob, Charlie];
uint256[] memory ids = [1, 2, 3];
uint256[] memory balances = token.balanceOfBatch(accounts, ids);
// 返回：[Alice的id1余额, Bob的id2余额, Charlie的id3余额]
```

**为什么有批量查询？**
- 节省Gas：一次调用获取多个余额
- 减少RPC请求：前端应用更高效

### 转账类方法

#### `safeTransferFrom(from, to, id, amount, data)`
安全转账单种代币。

**执行流程：**
1. ✅ 检查接收地址不为零
2. ✅ 检查调用者权限（是所有者或被授权）
3. ✅ 检查余额是否充足
4. ⚙️ 更新发送方余额（减少）
5. ⚙️ 更新接收方余额（增加）
6. 📢 触发`TransferSingle`事件
7. 🔒 检查接收方是否能安全接收代币

**关键代码：**
```solidity
// 先减后加，防止重入攻击
unchecked {
    _balances[id][from] = fromBalance - amount;
}
_balances[id][to] += amount;
```

#### `safeBatchTransferFrom(from, to, ids[], amounts[], data)`
批量转账多种代币。

**优势示例：**
```solidity
// 传统方式（ERC20/721）：需要3次交易
token1.transfer(Bob, 100);
token2.transfer(Bob, 50);
token3.transfer(Bob, 1);

// ERC1155方式：只需1次交易！
token.safeBatchTransferFrom(
    Alice,
    Bob,
    [1, 2, 3],      // 代币IDs
    [100, 50, 1],   // 对应数量
    ""
);
```

### 授权类方法

#### `setApprovalForAll(address operator, bool approved)`
设置或取消操作者的全部授权。

```solidity
// Alice授权Bob操作她的所有代币
token.setApprovalForAll(Bob, true);

// Bob现在可以代表Alice转账任何代币
token.safeTransferFrom(Alice, Charlie, 1, 100, "");
```

#### `isApprovedForAll(address account, address operator) → bool`
查询是否已授权。

---

## 📡 核心事件

### TransferSingle
单次转账事件。

```solidity
event TransferSingle(
    address indexed operator,  // 执行者
    address indexed from,      // 发送方
    address indexed to,        // 接收方
    uint256 id,                // 代币ID
    uint256 value              // 数量
);
```

**触发场景：**
- 用户转账单种代币
- 铸造单种代币（from = 0x0）
- 销毁单种代币（to = 0x0）

### TransferBatch
批量转账事件。

```solidity
event TransferBatch(
    address indexed operator,
    address indexed from,
    address indexed to,
    uint256[] ids,       // 代币ID数组
    uint256[] values     // 数量数组
);
```

### ApprovalForAll
授权事件。

```solidity
event ApprovalForAll(
    address indexed account,   // 所有者
    address indexed operator,  // 操作者
    bool approved              // 是否授权
);
```

---

## 🎮 实际应用案例：游戏道具系统

参考 `GameItemsERC1155.sol` 文件，展示了完整的游戏经济系统：

### 代币设计

| 代币ID | 名称 | 类型 | 最大供应量 | 用途 |
|--------|------|------|------------|------|
| 1 | Gold Coin | 同质化 | 无限 | 游戏货币 |
| 2 | Silver Coin | 同质化 | 无限 | 游戏货币 |
| 3 | Common Sword | 同质化 | 10,000 | 普通装备 |
| 4 | Rare Sword | 半同质化 | 100 | 稀有装备 |
| 1001+ | Unique NFT | 非同质化 | 1 | 独特装备 |

### 核心功能

#### 1. 铸造道具
```solidity
// 管理员给玩家发放初始装备
gameItems.mint(player, 1, 1000);  // 1000金币
gameItems.mint(player, 3, 2);     // 2把普通剑
```

#### 2. 游戏内购买
```solidity
// 玩家用100金币购买1把稀有剑
gameItems.buyItemWithGold(4, 100);
// 内部逻辑：销毁100金币 + 铸造1把稀有剑
```

#### 3. 道具合成
```solidity
// 3把普通剑 + 10金币 => 1把稀有剑
uint256[] memory materialIds = [3, 1];
uint256[] memory amounts = [3, 10];
gameItems.craftItem(materialIds, amounts, 4);
```

#### 4. 批量发放
```solidity
// 新手礼包：100金币 + 50银币 + 1把普通剑
uint256[] memory ids = [1, 2, 3];
uint256[] memory amounts = [100, 50, 1];
gameItems.mintBatch(newPlayer, ids, amounts);
```

---

## 🔒 安全机制

### 1. 接收检查（SafeTransfer）

为什么需要？
- 防止代币被发送到不支持ERC1155的合约
- 避免代币永久锁定

**工作原理：**
```solidity
if (to.code.length > 0) {  // 如果是合约
    // 调用接收方的onERC1155Received函数
    // 检查返回值是否正确
}
```

**合约接收代币必须实现：**
```solidity
function onERC1155Received(
    address operator,
    address from,
    uint256 id,
    uint256 value,
    bytes calldata data
) external returns (bytes4) {
    // 返回函数选择器表示接收成功
    return this.onERC1155Received.selector;
}
```

### 2. 防重入攻击

**先减后加模式：**
```solidity
// 先更新发送方余额（减少）
_balances[id][from] = fromBalance - amount;

// 再更新接收方余额（增加）
_balances[id][to] += amount;

// 最后触发事件和外部调用
emit TransferSingle(...);
_doSafeTransferAcceptanceCheck(...);
```

### 3. 权限检查

```solidity
require(
    from == msg.sender || isApprovedForAll(from, msg.sender),
    "ERC1155: caller is not owner nor approved"
);
```

---

## 💡 与ERC20/ERC721对比

### 转账对比

**ERC20（单一代币）：**
```solidity
token.transfer(to, 100);
```

**ERC721（单个NFT）：**
```solidity
nft.transferFrom(from, to, tokenId);
```

**ERC1155（支持批量）：**
```solidity
// 单个
token.safeTransferFrom(from, to, id, amount, "");

// 批量
token.safeBatchTransferFrom(from, to, [1,2,3], [100,50,1], "");
```

### Gas成本对比（转10种代币）

| 标准 | 操作次数 | 相对Gas成本 |
|------|----------|-------------|
| ERC20 | 10次transfer | ~100% |
| ERC721 | 10次transferFrom | ~120% |
| ERC1155 | 1次batchTransfer | ~40% |

---

## 📖 学习建议

### 1. 先理解数据结构
- 重点理解嵌套映射 `_balances`
- 画图模拟不同账户的代币持有情况

### 2. 追踪一次完整转账
- 从 `safeTransferFrom` 开始
- 逐步跟踪权限检查、余额更新、事件触发

### 3. 运行示例合约
- 部署 `GameItemsERC1155.sol`
- 尝试铸造、转账、批量操作
- 观察事件日志

### 4. 实践项目
- 实现自己的NFT游戏道具
- 创建多代币奖励系统
- 构建元宇宙资产合约

---

## 🚀 使用场景

1. **游戏行业**
   - 游戏内货币 + 装备 + 道具
   - 一个合约管理所有资产

2. **NFT市场**
   - 同时发售多个系列
   - 批量空投节省Gas

3. **DeFi协议**
   - 多种奖励代币
   - 流动性挖矿凭证

4. **元宇宙**
   - 虚拟土地 + 建筑 + 装饰
   - 跨平台资产互通

---

## 📝 总结

ERC1155是以太坊代币标准的重要创新：

- ✅ **统一标准**：一个合约管理所有代币类型
- ✅ **高效节能**：批量操作大幅节省Gas
- ✅ **灵活设计**：支持FT、NFT、SFT
- ✅ **广泛应用**：特别适合游戏和元宇宙

通过本项目的三个文件，你可以：
1. 理解接口定义（IERC1155.sol）
2. 掌握实现细节（ERC1155.sol）
3. 学习实际应用（GameItemsERC1155.sol）

祝你学习愉快！🎉