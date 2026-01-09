// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC1155.sol";

/**
 * @title ERC1155 多代币标准实现
 * @dev 这是一个完整的ERC1155实现，包含详细注释帮助理解
 *
 * ERC1155核心概念：
 * 1. 多代币类型：一个合约可以管理无限种代币，每种由唯一的ID标识
 * 2. 批量操作：支持批量转账和批量查询，节省gas
 * 3. 灵活性：同一合约可以同时包含同质化代币(FT)和非同质化代币(NFT)
 */
contract ERC1155 is IERC1155 {

    // ========== 数据结构 ==========

    /**
     * @dev 核心数据结构1: 嵌套映射存储余额
     * 第一层：代币类型ID => 第二层映射
     * 第二层：账户地址 => 该账户持有该类型代币的数量
     *
     * 举例：_balances[tokenId][userAddress] = amount
     * - _balances[1][Alice] = 100 表示Alice持有100个ID为1的代币
     * - _balances[2][Bob] = 1 表示Bob持有1个ID为2的代币（可能是NFT）
     */
    mapping(uint256 => mapping(address => uint256)) private _balances;

    /**
     * @dev 核心数据结构2: 授权映射
     * 第一层：代币所有者地址 => 第二层映射
     * 第二层：操作者地址 => 是否被授权
     *
     * 举例：_operatorApprovals[owner][operator] = true
     * - _operatorApprovals[Alice][Bob] = true 表示Alice授权Bob操作Alice的所有代币
     * 注意：这是"全部授权"，不是针对单个代币ID或数量的授权
     */
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev 代币URI基础路径
     * URI用于存储代币的元数据（图片、描述等）
     * 通常格式为：baseURI + tokenId + ".json"
     * 例如："https://token.com/api/token/{id}.json"
     */
    string private _uri;

    // ========== 构造函数 ==========

    /**
     * @dev 构造函数，设置代币的URI
     * @param uri_ 代币元数据的URI模板
     */
    constructor(string memory uri_) {
        _setURI(uri_);
    }

    // ========== 查询函数 ==========

    /**
     * @dev 查询单个账户持有的某种代币数量
     * @param account 账户地址
     * @param id 代币类型ID
     * @return 该账户持有的代币数量
     *
     * 实现逻辑：直接从_balances嵌套映射中读取
     */
    function balanceOf(address account, uint256 id)
        public
        view
        override
        returns (uint256)
    {
        require(account != address(0), "ERC1155: balance query for zero address");
        return _balances[id][account];
    }

    /**
     * @dev 批量查询多个账户持有的多种代币数量
     * @param accounts 账户地址数组
     * @param ids 代币类型ID数组
     * @return 对应的代币数量数组
     *
     * 实现逻辑：
     * 1. 确保两个数组长度相同
     * 2. 创建返回数组
     * 3. 循环调用balanceOf获取每个账户的对应代币余额
     *
     * 举例：
     * accounts = [Alice, Bob, Charlie]
     * ids = [1, 2, 3]
     * 返回 = [Alice的id1余额, Bob的id2余额, Charlie的id3余额]
     */
    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    )
        public
        view
        override
        returns (uint256[] memory)
    {
        require(
            accounts.length == ids.length,
            "ERC1155: accounts and ids length mismatch"
        );

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev 查询操作者是否被授权
     * @param account 代币所有者
     * @param operator 操作者
     * @return 是否被授权
     */
    function isApprovedForAll(address account, address operator)
        public
        view
        override
        returns (bool)
    {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev 获取代币的URI
     * @param id 代币类型ID
     * @return 代币的元数据URI
     */
    function uri(uint256 id) public view virtual returns (string memory) {
        return _uri;
    }

    // ========== 授权函数 ==========

    /**
     * @dev 设置或取消操作者的授权
     * @param operator 操作者地址
     * @param approved true表示授权，false表示取消授权
     *
     * 实现逻辑：
     * 1. 检查不能授权给自己
     * 2. 更新_operatorApprovals映射
     * 3. 触发ApprovalForAll事件
     *
     * 注意：这是"全部授权"，授权后operator可以操作msg.sender的所有代币
     */
    function setApprovalForAll(address operator, bool approved)
        public
        override
    {
        require(
            msg.sender != operator,
            "ERC1155: setting approval status for self"
        );
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    // ========== 转账函数 ==========

    /**
     * @dev 安全转账单种代币
     * @param from 发送方地址
     * @param to 接收方地址
     * @param id 代币类型ID
     * @param amount 转账数量
     * @param data 附加数据，传递给接收者合约
     *
     * 实现逻辑：
     * 1. 检查接收地址不为零
     * 2. 检查调用者是代币所有者或被授权的操作者
     * 3. 获取发送方当前余额
     * 4. 检查余额是否足够
     * 5. 更新发送方和接收方余额（先减后加，防止重入攻击）
     * 6. 触发TransferSingle事件
     * 7. 如果接收方是合约，检查其是否正确实现了接收接口
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    )
        public
        override
    {
        require(to != address(0), "ERC1155: transfer to zero address");
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "ERC1155: caller is not owner nor approved"
        );

        address operator = msg.sender;

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");

        // 先减后加，防止重入攻击
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    /**
     * @dev 安全批量转账多种代币
     * @param from 发送方地址
     * @param to 接收方地址
     * @param ids 代币类型ID数组
     * @param amounts 转账数量数组
     * @param data 附加数据
     *
     * 实现逻辑：
     * 1. 基本检查（接收地址、授权、数组长度）
     * 2. 循环处理每种代币的转账
     * 3. 触发TransferBatch事件
     * 4. 检查接收方是否正确实现接收接口
     *
     * 优势：批量转账可以节省gas费用，因为只需一次授权检查和一次事件触发
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        public
        override
    {
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );
        require(to != address(0), "ERC1155: transfer to zero address");
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "ERC1155: caller is not owner nor approved"
        );

        address operator = msg.sender;

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(
                fromBalance >= amount,
                "ERC1155: insufficient balance for transfer"
            );
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    // ========== 内部函数 ==========

    /**
     * @dev 内部铸造函数（创建新代币）
     * @param to 接收者地址
     * @param id 代币类型ID
     * @param amount 铸造数量
     * @param data 附加数据
     *
     * 使用场景：
     * - 铸造同质化代币：mint(Alice, 1, 1000, "") 给Alice铸造1000个ID为1的代币
     * - 铸造非同质化代币：mint(Bob, 101, 1, "") 给Bob铸造1个ID为101的NFT
     */
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        require(to != address(0), "ERC1155: mint to zero address");

        address operator = msg.sender;

        _balances[id][to] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }

    /**
     * @dev 内部批量铸造函数
     * @param to 接收者地址
     * @param ids 代币类型ID数组
     * @param amounts 铸造数量数组
     * @param data 附加数据
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        require(to != address(0), "ERC1155: mint to zero address");
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );

        address operator = msg.sender;

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    /**
     * @dev 内部销毁函数（销毁代币）
     * @param from 持有者地址
     * @param id 代币类型ID
     * @param amount 销毁数量
     *
     * 使用场景：游戏中消耗道具、销毁代币减少总供应量等
     */
    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal {
        require(from != address(0), "ERC1155: burn from zero address");

        address operator = msg.sender;

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }

        emit TransferSingle(operator, from, address(0), id, amount);
    }

    /**
     * @dev 内部批量销毁函数
     * @param from 持有者地址
     * @param ids 代币类型ID数组
     * @param amounts 销毁数量数组
     */
    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal {
        require(from != address(0), "ERC1155: burn from zero address");
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );

        address operator = msg.sender;

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);
    }

    /**
     * @dev 设置URI
     * @param newuri 新的URI字符串
     */
    function _setURI(string memory newuri) internal {
        _uri = newuri;
    }

    /**
     * @dev 检查接收方是否能安全接收ERC1155代币（单个）
     *
     * 为什么需要这个检查？
     * 防止代币被发送到不支持ERC1155的合约中，导致代币永久锁定
     *
     * 工作原理：
     * 1. 如果接收方是EOA（外部账户），直接返回
     * 2. 如果接收方是合约，调用其onERC1155Received函数
     * 3. 检查返回值是否为正确的函数选择器
     */
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    /**
     * @dev 检查接收方是否能安全接收ERC1155代币（批量）
     */
    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }
}