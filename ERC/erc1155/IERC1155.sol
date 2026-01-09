// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ERC1155 多代币标准接口
 * @dev ERC1155是一个多代币标准，允许在单个合约中管理多种代币类型
 * 每个代币类型由唯一的ID标识，可以是同质化代币(FT)或非同质化代币(NFT)
 */
interface IERC1155 {

    /**
     * @dev 单次转账事件
     * @param operator 执行转账操作的地址（通常是msg.sender）
     * @param from 代币发送方地址
     * @param to 代币接收方地址
     * @param id 代币类型ID
     * @param value 转账数量
     */
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

    /**
     * @dev 批量转账事件
     * @param operator 执行转账操作的地址
     * @param from 代币发送方地址
     * @param to 代币接收方地址
     * @param ids 代币类型ID数组
     * @param values 对应的转账数量数组
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev 授权事件
     * @param account 代币所有者地址
     * @param operator 被授权的操作者地址
     * @param approved true表示授权，false表示取消授权
     */
    event ApprovalForAll(
        address indexed account,
        address indexed operator,
        bool approved
    );

    /**
     * @dev URI更新事件
     * @param value 新的URI值
     * @param id 代币类型ID
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev 查询账户持有的某种代币数量
     * @param account 账户地址
     * @param id 代币类型ID
     * @return 该账户持有的代币数量
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev 批量查询多个账户持有的多种代币数量
     * @param accounts 账户地址数组
     * @param ids 代币类型ID数组
     * @return 对应的代币数量数组
     */
    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);

    /**
     * @dev 设置或取消操作者的授权
     * @param operator 操作者地址
     * @param approved true表示授权，false表示取消授权
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev 查询是否已授权
     * @param account 代币所有者地址
     * @param operator 操作者地址
     * @return 是否已授权
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev 安全转账单种代币
     * @param from 发送方地址
     * @param to 接收方地址
     * @param id 代币类型ID
     * @param amount 转账数量
     * @param data 附加数据
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @dev 安全批量转账多种代币
     * @param from 发送方地址
     * @param to 接收方地址
     * @param ids 代币类型ID数组
     * @param amounts 转账数量数组
     * @param data 附加数据
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

/**
 * @title ERC1155接收者接口
 * @dev 合约必须实现此接口才能接收ERC1155代币
 */
interface IERC1155Receiver {
    /**
     * @dev 处理单个ERC1155代币的接收
     * @return 返回函数选择器表示接收成功
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev 处理批量ERC1155代币的接收
     * @return 返回函数选择器表示接收成功
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}