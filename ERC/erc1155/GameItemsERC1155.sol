// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC1155.sol";

/**
 * @title 游戏道具NFT合约 - ERC1155使用示例
 * @dev 这是一个实际应用案例，展示如何使用ERC1155创建游戏道具系统
 *
 * 应用场景：
 * 一个游戏中有多种道具：
 * - ID 1: 金币（同质化代币，每个玩家可以有多个）
 * - ID 2: 银币（同质化代币）
 * - ID 3: 普通剑（同质化道具）
 * - ID 4: 稀有剑（限量道具）
 * - ID 1001-9999: 独特NFT（每个ID只有1个）
 */
contract GameItemsERC1155 is ERC1155 {

    // ========== 状态变量 ==========

    /// @dev 合约所有者
    address public owner;

    /// @dev 每种代币的名称
    mapping(uint256 => string) public tokenNames;

    /// @dev 每种代币的最大供应量（0表示无限）
    mapping(uint256 => uint256) public maxSupply;

    /// @dev 每种代币的当前供应量
    mapping(uint256 => uint256) public currentSupply;

    /// @dev NFT起始ID（大于等于此ID的代币每个地址只能持有1个）
    uint256 public constant NFT_START_ID = 1000;

    // ========== 事件 ==========

    /// @dev 创建新代币类型事件
    event TokenTypeCreated(uint256 indexed id, string name, uint256 maxSupply);

    /// @dev 铸造事件
    event ItemMinted(address indexed to, uint256 indexed id, uint256 amount);

    // ========== 修饰器 ==========

    /// @dev 只有所有者可以调用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // ========== 构造函数 ==========

    /**
     * @dev 构造函数
     * @param uri_ 代币元数据URI模板
     */
    constructor(string memory uri_) ERC1155(uri_) {
        owner = msg.sender;

        // 初始化一些游戏道具类型
        _createTokenType(1, "Gold Coin", 0); // 金币，无限供应
        _createTokenType(2, "Silver Coin", 0); // 银币，无限供应
        _createTokenType(3, "Common Sword", 10000); // 普通剑，最多10000把
        _createTokenType(4, "Rare Sword", 100); // 稀有剑，最多100把
        _createTokenType(5, "Epic Shield", 50); // 史诗盾牌，最多50个
    }

    // ========== 管理员函数 ==========

    /**
     * @dev 创建新的代币类型
     * @param id 代币ID
     * @param name 代币名称
     * @param maxSupply_ 最大供应量（0表示无限）
     */
    function createTokenType(
        uint256 id,
        string memory name,
        uint256 maxSupply_
    ) external onlyOwner {
        _createTokenType(id, name, maxSupply_);
    }

    /**
     * @dev 内部函数：创建代币类型
     */
    function _createTokenType(
        uint256 id,
        string memory name,
        uint256 maxSupply_
    ) internal {
        require(bytes(tokenNames[id]).length == 0, "Token type already exists");
        tokenNames[id] = name;
        maxSupply[id] = maxSupply_;
        emit TokenTypeCreated(id, name, maxSupply_);
    }

    /**
     * @dev 铸造代币给指定地址
     * @param to 接收者地址
     * @param id 代币ID
     * @param amount 数量
     *
     * 业务逻辑：
     * 1. 检查是否超过最大供应量
     * 2. 如果是NFT（ID >= 1000），每个地址只能持有1个
     * 3. 更新当前供应量
     * 4. 调用内部_mint函数
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) external onlyOwner {
        require(bytes(tokenNames[id]).length > 0, "Token type does not exist");

        // 检查最大供应量
        if (maxSupply[id] > 0) {
            require(
                currentSupply[id] + amount <= maxSupply[id],
                "Exceeds maximum supply"
            );
        }

        // NFT检查：如果是NFT，确保amount为1且接收者当前余额为0
        if (id >= NFT_START_ID) {
            require(amount == 1, "NFT can only mint 1 at a time");
            require(balanceOf(to, id) == 0, "Address already owns this NFT");
        }

        currentSupply[id] += amount;
        _mint(to, id, amount, "");

        emit ItemMinted(to, id, amount);
    }

    /**
     * @dev 批量铸造多种代币
     * @param to 接收者地址
     * @param ids 代币ID数组
     * @param amounts 数量数组
     *
     * 使用场景：给新玩家发放初始道具包
     */
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external onlyOwner {
        require(ids.length == amounts.length, "Arrays length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            require(bytes(tokenNames[ids[i]]).length > 0, "Token type does not exist");

            // 检查供应量
            if (maxSupply[ids[i]] > 0) {
                require(
                    currentSupply[ids[i]] + amounts[i] <= maxSupply[ids[i]],
                    "Exceeds maximum supply"
                );
            }

            // NFT检查
            if (ids[i] >= NFT_START_ID) {
                require(amounts[i] == 1, "NFT can only mint 1");
                require(balanceOf(to, ids[i]) == 0, "Already owns this NFT");
            }

            currentSupply[ids[i]] += amounts[i];
        }

        _mintBatch(to, ids, amounts, "");
    }

    /**
     * @dev 玩家消耗/销毁道具
     * @param id 代币ID
     * @param amount 数量
     *
     * 使用场景：
     * - 使用消耗品（如药水）
     * - 合成时销毁材料
     * - 完成任务消耗道具
     */
    function burn(uint256 id, uint256 amount) external {
        _burn(msg.sender, id, amount);
        currentSupply[id] -= amount;
    }

    /**
     * @dev 批量销毁道具
     * @param ids 代币ID数组
     * @param amounts 数量数组
     */
    function burnBatch(uint256[] memory ids, uint256[] memory amounts) external {
        require(ids.length == amounts.length, "Arrays length mismatch");

        _burnBatch(msg.sender, ids, amounts);

        for (uint256 i = 0; i < ids.length; i++) {
            currentSupply[ids[i]] -= amounts[i];
        }
    }

    // ========== 游戏逻辑示例函数 ==========

    /**
     * @dev 游戏内交易：玩家用金币购买道具
     * @param itemId 要购买的道具ID
     * @param price 价格（金币数量）
     *
     * 这个函数展示了ERC1155在游戏经济系统中的应用：
     * 1. 销毁玩家的金币（ID=1）
     * 2. 铸造对应的游戏道具给玩家
     */
    function buyItemWithGold(uint256 itemId, uint256 price) external {
        require(bytes(tokenNames[itemId]).length > 0, "Item does not exist");
        require(itemId != 1, "Cannot buy gold with gold");

        // 检查玩家金币余额
        require(balanceOf(msg.sender, 1) >= price, "Insufficient gold");

        // 销毁金币
        _burn(msg.sender, 1, price);
        currentSupply[1] -= price;

        // 铸造道具
        if (maxSupply[itemId] > 0) {
            require(
                currentSupply[itemId] < maxSupply[itemId],
                "Item sold out"
            );
        }

        currentSupply[itemId] += 1;
        _mint(msg.sender, itemId, 1, "");
    }

    /**
     * @dev 道具合成：用多个材料合成新道具
     * @param materialIds 材料ID数组
     * @param materialAmounts 材料数量数组
     * @param resultId 合成结果道具ID
     *
     * 使用场景：3把普通剑(ID=3) + 10个金币(ID=1) => 1把稀有剑(ID=4)
     */
    function craftItem(
        uint256[] memory materialIds,
        uint256[] memory materialAmounts,
        uint256 resultId
    ) external {
        require(bytes(tokenNames[resultId]).length > 0, "Result item does not exist");

        // 销毁材料
        _burnBatch(msg.sender, materialIds, materialAmounts);
        for (uint256 i = 0; i < materialIds.length; i++) {
            currentSupply[materialIds[i]] -= materialAmounts[i];
        }

        // 铸造结果
        if (maxSupply[resultId] > 0) {
            require(
                currentSupply[resultId] < maxSupply[resultId],
                "Cannot craft, max supply reached"
            );
        }

        currentSupply[resultId] += 1;
        _mint(msg.sender, resultId, 1, "");
    }

    // ========== 查询函数 ==========

    /**
     * @dev 查询代币信息
     * @param id 代币ID
     * @return name 名称
     * @return currentSupply_ 当前供应量
     * @return maxSupply_ 最大供应量
     */
    function getTokenInfo(uint256 id)
        external
        view
        returns (
            string memory name,
            uint256 currentSupply_,
            uint256 maxSupply_
        )
    {
        return (tokenNames[id], currentSupply[id], maxSupply[id]);
    }

    /**
     * @dev 查询玩家的所有道具余额
     * @param player 玩家地址
     * @param ids 要查询的道具ID数组
     * @return 余额数组
     */
    function getPlayerItems(address player, uint256[] memory ids)
        external
        view
        returns (uint256[] memory)
    {
        address[] memory accounts = new address[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            accounts[i] = player;
        }
        return balanceOfBatch(accounts, ids);
    }
}