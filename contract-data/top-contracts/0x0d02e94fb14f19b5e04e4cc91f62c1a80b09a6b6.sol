{"Address.sol":{"content":"// SPDX-License-Identifier: MIT\n\npragma solidity \u003e=0.6.2 \u003c0.8.0;\n\n/**\n * @dev Collection of functions related to the address type\n */\nlibrary Address {\n    /**\n     * @dev Returns true if `account` is a contract.\n     *\n     * [IMPORTANT]\n     * ====\n     * It is unsafe to assume that an address for which this function returns\n     * false is an externally-owned account (EOA) and not a contract.\n     *\n     * Among others, `isContract` will return false for the following\n     * types of addresses:\n     *\n     *  - an externally-owned account\n     *  - a contract in construction\n     *  - an address where a contract will be created\n     *  - an address where a contract lived, but was destroyed\n     * ====\n     */\n    function isContract(address account) internal view returns (bool) {\n        // This method relies on extcodesize, which returns 0 for contracts in\n        // construction, since the code is only stored at the end of the\n        // constructor execution.\n\n        uint256 size;\n        // solhint-disable-next-line no-inline-assembly\n        assembly { size := extcodesize(account) }\n        return size \u003e 0;\n    }\n\n    /**\n     * @dev Replacement for Solidity\u0027s `transfer`: sends `amount` wei to\n     * `recipient`, forwarding all available gas and reverting on errors.\n     *\n     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost\n     * of certain opcodes, possibly making contracts go over the 2300 gas limit\n     * imposed by `transfer`, making them unable to receive funds via\n     * `transfer`. {sendValue} removes this limitation.\n     *\n     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].\n     *\n     * IMPORTANT: because control is transferred to `recipient`, care must be\n     * taken to not create reentrancy vulnerabilities. Consider using\n     * {ReentrancyGuard} or the\n     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].\n     */\n    function sendValue(address payable recipient, uint256 amount) internal {\n        require(address(this).balance \u003e= amount, \"Address: insufficient balance\");\n\n        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value\n        (bool success, ) = recipient.call{ value: amount }(\"\");\n        require(success, \"Address: unable to send value, recipient may have reverted\");\n    }\n\n    /**\n     * @dev Performs a Solidity function call using a low level `call`. A\n     * plain`call` is an unsafe replacement for a function call: use this\n     * function instead.\n     *\n     * If `target` reverts with a revert reason, it is bubbled up by this\n     * function (like regular Solidity function calls).\n     *\n     * Returns the raw returned data. To convert to the expected return value,\n     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].\n     *\n     * Requirements:\n     *\n     * - `target` must be a contract.\n     * - calling `target` with `data` must not revert.\n     *\n     * _Available since v3.1._\n     */\n    function functionCall(address target, bytes memory data) internal returns (bytes memory) {\n      return functionCall(target, data, \"Address: low-level call failed\");\n    }\n\n    /**\n     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with\n     * `errorMessage` as a fallback revert reason when `target` reverts.\n     *\n     * _Available since v3.1._\n     */\n    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {\n        return functionCallWithValue(target, data, 0, errorMessage);\n    }\n\n    /**\n     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],\n     * but also transferring `value` wei to `target`.\n     *\n     * Requirements:\n     *\n     * - the calling contract must have an ETH balance of at least `value`.\n     * - the called Solidity function must be `payable`.\n     *\n     * _Available since v3.1._\n     */\n    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {\n        return functionCallWithValue(target, data, value, \"Address: low-level call with value failed\");\n    }\n\n    /**\n     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but\n     * with `errorMessage` as a fallback revert reason when `target` reverts.\n     *\n     * _Available since v3.1._\n     */\n    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {\n        require(address(this).balance \u003e= value, \"Address: insufficient balance for call\");\n        require(isContract(target), \"Address: call to non-contract\");\n\n        // solhint-disable-next-line avoid-low-level-calls\n        (bool success, bytes memory returndata) = target.call{ value: value }(data);\n        return _verifyCallResult(success, returndata, errorMessage);\n    }\n\n    /**\n     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],\n     * but performing a static call.\n     *\n     * _Available since v3.3._\n     */\n    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {\n        return functionStaticCall(target, data, \"Address: low-level static call failed\");\n    }\n\n    /**\n     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],\n     * but performing a static call.\n     *\n     * _Available since v3.3._\n     */\n    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {\n        require(isContract(target), \"Address: static call to non-contract\");\n\n        // solhint-disable-next-line avoid-low-level-calls\n        (bool success, bytes memory returndata) = target.staticcall(data);\n        return _verifyCallResult(success, returndata, errorMessage);\n    }\n\n    /**\n     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],\n     * but performing a delegate call.\n     *\n     * _Available since v3.4._\n     */\n    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {\n        return functionDelegateCall(target, data, \"Address: low-level delegate call failed\");\n    }\n\n    /**\n     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],\n     * but performing a delegate call.\n     *\n     * _Available since v3.4._\n     */\n    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {\n        require(isContract(target), \"Address: delegate call to non-contract\");\n\n        // solhint-disable-next-line avoid-low-level-calls\n        (bool success, bytes memory returndata) = target.delegatecall(data);\n        return _verifyCallResult(success, returndata, errorMessage);\n    }\n\n    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {\n        if (success) {\n            return returndata;\n        } else {\n            // Look for revert reason and bubble it up if present\n            if (returndata.length \u003e 0) {\n                // The easiest way to bubble the revert reason is using memory via assembly\n\n                // solhint-disable-next-line no-inline-assembly\n                assembly {\n                    let returndata_size := mload(returndata)\n                    revert(add(32, returndata), returndata_size)\n                }\n            } else {\n                revert(errorMessage);\n            }\n        }\n    }\n}\n"},"Context.sol":{"content":"// SPDX-License-Identifier: MIT\n\npragma solidity \u003e=0.6.0 \u003c0.8.0;\n\n/*\n * @dev Provides information about the current execution context, including the\n * sender of the transaction and its data. While these are generally available\n * via msg.sender and msg.data, they should not be accessed in such a direct\n * manner, since when dealing with GSN meta-transactions the account sending and\n * paying for execution may not be the actual sender (as far as an application\n * is concerned).\n *\n * This contract is only required for intermediate, library-like contracts.\n */\nabstract contract Context {\n    function _msgSender() internal view virtual returns (address payable) {\n        return msg.sender;\n    }\n\n    function _msgData() internal view virtual returns (bytes memory) {\n        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691\n        return msg.data;\n    }\n}\n"},"ETHSwapAgent.sol":{"content":"pragma solidity \u003e=0.6.4;\n\nimport \"./IERC20Query.sol\";\nimport \"./Context.sol\";\nimport \"./SafeERC20.sol\";\nimport \"./Initializable.sol\";\n\ncontract ETHSwapAgent is Context, Initializable {\n\n    using SafeERC20 for IERC20;\n\n    mapping(address =\u003e bool) public registeredERC20;\n    mapping(bytes32 =\u003e bool) public filledBSCTx;\n    address payable public owner;\n    uint256 public swapFee;\n\n    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);\n    event SwapPairRegister(address indexed sponsor,address indexed erc20Addr, string name, string symbol, uint8 decimals);\n    event SwapStarted(address indexed erc20Addr, address indexed fromAddr, uint256 amount, uint256 feeAmount);\n    event SwapFilled(address indexed erc20Addr, bytes32 indexed bscTxHash, address indexed toAddress, uint256 amount);\n\n    constructor() public {\n    }\n\n    function initialize(uint256 fee, address payable ownerAddr) public initializer {\n        swapFee = fee;\n        owner = ownerAddr;\n    }\n\n    /**\n     * @dev Throws if called by any account other than the owner.\n     */\n    modifier onlyOwner() {\n        require(owner == _msgSender(), \"Ownable: caller is not the owner\");\n        _;\n    }\n\n    modifier notContract() {\n        require(!isContract(msg.sender), \"contract is not allowed to swap\");\n        require(msg.sender == tx.origin, \"no proxy contract is allowed\");\n       _;\n    }\n\n    function isContract(address addr) internal view returns (bool) {\n        uint size;\n        assembly { size := extcodesize(addr) }\n        return size \u003e 0;\n    }\n\n    /**\n        * @dev Leaves the contract without owner. It will not be possible to call\n        * `onlyOwner` functions anymore. Can only be called by the current owner.\n        *\n        * NOTE: Renouncing ownership will leave the contract without an owner,\n        * thereby removing any functionality that is only available to the owner.\n        */\n    function renounceOwnership() public onlyOwner {\n        emit OwnershipTransferred(owner, address(0));\n        owner = address(0);\n    }\n\n    /**\n     * @dev Transfers ownership of the contract to a new account (`newOwner`).\n     * Can only be called by the current owner.\n     */\n    function transferOwnership(address payable newOwner) public onlyOwner {\n        require(newOwner != address(0), \"Ownable: new owner is the zero address\");\n        emit OwnershipTransferred(owner, newOwner);\n        owner = newOwner;\n    }\n\n    /**\n     * @dev Returns set minimum swap fee from ERC20 to BEP20\n     */\n    function setSwapFee(uint256 fee) onlyOwner external {\n        swapFee = fee;\n    }\n\n    function registerSwapPairToBSC(address erc20Addr) external returns (bool) {\n        require(!registeredERC20[erc20Addr], \"already registered\");\n\n        string memory name = IERC20Query(erc20Addr).name();\n        string memory symbol = IERC20Query(erc20Addr).symbol();\n        uint8 decimals = IERC20Query(erc20Addr).decimals();\n\n        require(bytes(name).length\u003e0, \"empty name\");\n        require(bytes(symbol).length\u003e0, \"empty symbol\");\n\n        registeredERC20[erc20Addr] = true;\n\n        emit SwapPairRegister(msg.sender, erc20Addr, name, symbol, decimals);\n        return true;\n    }\n\n    function fillBSC2ETHSwap(bytes32 bscTxHash, address erc20Addr, address toAddress, uint256 amount) onlyOwner external returns (bool) {\n        require(!filledBSCTx[bscTxHash], \"bsc tx filled already\");\n        require(registeredERC20[erc20Addr], \"not registered token\");\n\n        filledBSCTx[bscTxHash] = true;\n        IERC20(erc20Addr).safeTransfer(toAddress, amount);\n\n        emit SwapFilled(erc20Addr, bscTxHash, toAddress, amount);\n        return true;\n    }\n\n    function swapETH2BSC(address erc20Addr, uint256 amount) payable external notContract returns (bool) {\n        require(registeredERC20[erc20Addr], \"not registered token\");\n        require(msg.value == swapFee, \"swap fee not equal\");\n\n        IERC20(erc20Addr).safeTransferFrom(msg.sender, address(this), amount);\n        if (msg.value != 0) {\n            owner.transfer(msg.value);\n        }\n\n        emit SwapStarted(erc20Addr, msg.sender, amount, msg.value);\n        return true;\n    }\n}"},"IERC20.sol":{"content":"// SPDX-License-Identifier: MIT\n\npragma solidity \u003e=0.6.0 \u003c0.8.0;\n\n/**\n * @dev Interface of the ERC20 standard as defined in the EIP.\n */\ninterface IERC20 {\n    /**\n     * @dev Returns the amount of tokens in existence.\n     */\n    function totalSupply() external view returns (uint256);\n\n    /**\n     * @dev Returns the amount of tokens owned by `account`.\n     */\n    function balanceOf(address account) external view returns (uint256);\n\n    /**\n     * @dev Moves `amount` tokens from the caller\u0027s account to `recipient`.\n     *\n     * Returns a boolean value indicating whether the operation succeeded.\n     *\n     * Emits a {Transfer} event.\n     */\n    function transfer(address recipient, uint256 amount) external returns (bool);\n\n    /**\n     * @dev Returns the remaining number of tokens that `spender` will be\n     * allowed to spend on behalf of `owner` through {transferFrom}. This is\n     * zero by default.\n     *\n     * This value changes when {approve} or {transferFrom} are called.\n     */\n    function allowance(address owner, address spender) external view returns (uint256);\n\n    /**\n     * @dev Sets `amount` as the allowance of `spender` over the caller\u0027s tokens.\n     *\n     * Returns a boolean value indicating whether the operation succeeded.\n     *\n     * IMPORTANT: Beware that changing an allowance with this method brings the risk\n     * that someone may use both the old and the new allowance by unfortunate\n     * transaction ordering. One possible solution to mitigate this race\n     * condition is to first reduce the spender\u0027s allowance to 0 and set the\n     * desired value afterwards:\n     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729\n     *\n     * Emits an {Approval} event.\n     */\n    function approve(address spender, uint256 amount) external returns (bool);\n\n    /**\n     * @dev Moves `amount` tokens from `sender` to `recipient` using the\n     * allowance mechanism. `amount` is then deducted from the caller\u0027s\n     * allowance.\n     *\n     * Returns a boolean value indicating whether the operation succeeded.\n     *\n     * Emits a {Transfer} event.\n     */\n    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);\n\n    /**\n     * @dev Emitted when `value` tokens are moved from one account (`from`) to\n     * another (`to`).\n     *\n     * Note that `value` may be zero.\n     */\n    event Transfer(address indexed from, address indexed to, uint256 value);\n\n    /**\n     * @dev Emitted when the allowance of a `spender` for an `owner` is set by\n     * a call to {approve}. `value` is the new allowance.\n     */\n    event Approval(address indexed owner, address indexed spender, uint256 value);\n}\n"},"IERC20Query.sol":{"content":"pragma solidity \u003e=0.6.4;\n\ninterface IERC20Query {\n    /**\n     * @dev Returns the amount of tokens in existence.\n     */\n    function totalSupply() external view returns (uint256);\n\n    /**\n     * @dev Returns the token decimals.\n     */\n    function decimals() external view returns (uint8);\n\n    /**\n     * @dev Returns the token symbol.\n     */\n    function symbol() external view returns (string memory);\n\n    /**\n    * @dev Returns the token name.\n    */\n    function name() external view returns (string memory);\n\n    /**\n     * @dev Returns the amount of tokens owned by `account`.\n     */\n    function balanceOf(address account) external view returns (uint256);\n}"},"Initializable.sol":{"content":"// SPDX-License-Identifier: MIT\n\n// solhint-disable-next-line compiler-version\npragma solidity \u003e=0.4.24 \u003c0.8.0;\n\nimport \"./Address.sol\";\n\n/**\n * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed\n * behind a proxy. Since a proxied contract can\u0027t have a constructor, it\u0027s common to move constructor logic to an\n * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer\n * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.\n *\n * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as\n * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.\n *\n * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure\n * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.\n */\nabstract contract Initializable {\n\n    /**\n     * @dev Indicates that the contract has been initialized.\n     */\n    bool private _initialized;\n\n    /**\n     * @dev Indicates that the contract is in the process of being initialized.\n     */\n    bool private _initializing;\n\n    /**\n     * @dev Modifier to protect an initializer function from being invoked twice.\n     */\n    modifier initializer() {\n        require(_initializing || _isConstructor() || !_initialized, \"Initializable: contract is already initialized\");\n\n        bool isTopLevelCall = !_initializing;\n        if (isTopLevelCall) {\n            _initializing = true;\n            _initialized = true;\n        }\n\n        _;\n\n        if (isTopLevelCall) {\n            _initializing = false;\n        }\n    }\n\n    /// @dev Returns true if and only if the function is running in the constructor\n    function _isConstructor() private view returns (bool) {\n        return !Address.isContract(address(this));\n    }\n}\n"},"SafeERC20.sol":{"content":"// SPDX-License-Identifier: MIT\n\npragma solidity \u003e=0.6.0 \u003c0.8.0;\n\nimport \"./IERC20.sol\";\nimport \"./SafeMath.sol\";\nimport \"./Address.sol\";\n\n/**\n * @title SafeERC20\n * @dev Wrappers around ERC20 operations that throw on failure (when the token\n * contract returns false). Tokens that return no value (and instead revert or\n * throw on failure) are also supported, non-reverting calls are assumed to be\n * successful.\n * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,\n * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.\n */\nlibrary SafeERC20 {\n    using SafeMath for uint256;\n    using Address for address;\n\n    function safeTransfer(IERC20 token, address to, uint256 value) internal {\n        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));\n    }\n\n    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {\n        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));\n    }\n\n    /**\n     * @dev Deprecated. This function has issues similar to the ones found in\n     * {IERC20-approve}, and its usage is discouraged.\n     *\n     * Whenever possible, use {safeIncreaseAllowance} and\n     * {safeDecreaseAllowance} instead.\n     */\n    function safeApprove(IERC20 token, address spender, uint256 value) internal {\n        // safeApprove should only be called when setting an initial allowance,\n        // or when resetting it to zero. To increase and decrease it, use\n        // \u0027safeIncreaseAllowance\u0027 and \u0027safeDecreaseAllowance\u0027\n        // solhint-disable-next-line max-line-length\n        require((value == 0) || (token.allowance(address(this), spender) == 0),\n            \"SafeERC20: approve from non-zero to non-zero allowance\"\n        );\n        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));\n    }\n\n    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {\n        uint256 newAllowance = token.allowance(address(this), spender).add(value);\n        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));\n    }\n\n    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {\n        uint256 newAllowance = token.allowance(address(this), spender).sub(value, \"SafeERC20: decreased allowance below zero\");\n        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));\n    }\n\n    /**\n     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement\n     * on the return value: the return value is optional (but if data is returned, it must not be false).\n     * @param token The token targeted by the call.\n     * @param data The call data (encoded using abi.encode or one of its variants).\n     */\n    function _callOptionalReturn(IERC20 token, bytes memory data) private {\n        // We need to perform a low level call here, to bypass Solidity\u0027s return data size checking mechanism, since\n        // we\u0027re implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that\n        // the target address contains contract code and also asserts for success in the low-level call.\n\n        bytes memory returndata = address(token).functionCall(data, \"SafeERC20: low-level call failed\");\n        if (returndata.length \u003e 0) { // Return data is optional\n            // solhint-disable-next-line max-line-length\n            require(abi.decode(returndata, (bool)), \"SafeERC20: ERC20 operation did not succeed\");\n        }\n    }\n}\n"},"SafeMath.sol":{"content":"// SPDX-License-Identifier: MIT\n\npragma solidity \u003e=0.6.0 \u003c0.8.0;\n\n/**\n * @dev Wrappers over Solidity\u0027s arithmetic operations with added overflow\n * checks.\n *\n * Arithmetic operations in Solidity wrap on overflow. This can easily result\n * in bugs, because programmers usually assume that an overflow raises an\n * error, which is the standard behavior in high level programming languages.\n * `SafeMath` restores this intuition by reverting the transaction when an\n * operation overflows.\n *\n * Using this library instead of the unchecked operations eliminates an entire\n * class of bugs, so it\u0027s recommended to use it always.\n */\nlibrary SafeMath {\n    /**\n     * @dev Returns the addition of two unsigned integers, with an overflow flag.\n     *\n     * _Available since v3.4._\n     */\n    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {\n        uint256 c = a + b;\n        if (c \u003c a) return (false, 0);\n        return (true, c);\n    }\n\n    /**\n     * @dev Returns the substraction of two unsigned integers, with an overflow flag.\n     *\n     * _Available since v3.4._\n     */\n    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {\n        if (b \u003e a) return (false, 0);\n        return (true, a - b);\n    }\n\n    /**\n     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.\n     *\n     * _Available since v3.4._\n     */\n    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {\n        // Gas optimization: this is cheaper than requiring \u0027a\u0027 not being zero, but the\n        // benefit is lost if \u0027b\u0027 is also tested.\n        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522\n        if (a == 0) return (true, 0);\n        uint256 c = a * b;\n        if (c / a != b) return (false, 0);\n        return (true, c);\n    }\n\n    /**\n     * @dev Returns the division of two unsigned integers, with a division by zero flag.\n     *\n     * _Available since v3.4._\n     */\n    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {\n        if (b == 0) return (false, 0);\n        return (true, a / b);\n    }\n\n    /**\n     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.\n     *\n     * _Available since v3.4._\n     */\n    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {\n        if (b == 0) return (false, 0);\n        return (true, a % b);\n    }\n\n    /**\n     * @dev Returns the addition of two unsigned integers, reverting on\n     * overflow.\n     *\n     * Counterpart to Solidity\u0027s `+` operator.\n     *\n     * Requirements:\n     *\n     * - Addition cannot overflow.\n     */\n    function add(uint256 a, uint256 b) internal pure returns (uint256) {\n        uint256 c = a + b;\n        require(c \u003e= a, \"SafeMath: addition overflow\");\n        return c;\n    }\n\n    /**\n     * @dev Returns the subtraction of two unsigned integers, reverting on\n     * overflow (when the result is negative).\n     *\n     * Counterpart to Solidity\u0027s `-` operator.\n     *\n     * Requirements:\n     *\n     * - Subtraction cannot overflow.\n     */\n    function sub(uint256 a, uint256 b) internal pure returns (uint256) {\n        require(b \u003c= a, \"SafeMath: subtraction overflow\");\n        return a - b;\n    }\n\n    /**\n     * @dev Returns the multiplication of two unsigned integers, reverting on\n     * overflow.\n     *\n     * Counterpart to Solidity\u0027s `*` operator.\n     *\n     * Requirements:\n     *\n     * - Multiplication cannot overflow.\n     */\n    function mul(uint256 a, uint256 b) internal pure returns (uint256) {\n        if (a == 0) return 0;\n        uint256 c = a * b;\n        require(c / a == b, \"SafeMath: multiplication overflow\");\n        return c;\n    }\n\n    /**\n     * @dev Returns the integer division of two unsigned integers, reverting on\n     * division by zero. The result is rounded towards zero.\n     *\n     * Counterpart to Solidity\u0027s `/` operator. Note: this function uses a\n     * `revert` opcode (which leaves remaining gas untouched) while Solidity\n     * uses an invalid opcode to revert (consuming all remaining gas).\n     *\n     * Requirements:\n     *\n     * - The divisor cannot be zero.\n     */\n    function div(uint256 a, uint256 b) internal pure returns (uint256) {\n        require(b \u003e 0, \"SafeMath: division by zero\");\n        return a / b;\n    }\n\n    /**\n     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),\n     * reverting when dividing by zero.\n     *\n     * Counterpart to Solidity\u0027s `%` operator. This function uses a `revert`\n     * opcode (which leaves remaining gas untouched) while Solidity uses an\n     * invalid opcode to revert (consuming all remaining gas).\n     *\n     * Requirements:\n     *\n     * - The divisor cannot be zero.\n     */\n    function mod(uint256 a, uint256 b) internal pure returns (uint256) {\n        require(b \u003e 0, \"SafeMath: modulo by zero\");\n        return a % b;\n    }\n\n    /**\n     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on\n     * overflow (when the result is negative).\n     *\n     * CAUTION: This function is deprecated because it requires allocating memory for the error\n     * message unnecessarily. For custom revert reasons use {trySub}.\n     *\n     * Counterpart to Solidity\u0027s `-` operator.\n     *\n     * Requirements:\n     *\n     * - Subtraction cannot overflow.\n     */\n    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {\n        require(b \u003c= a, errorMessage);\n        return a - b;\n    }\n\n    /**\n     * @dev Returns the integer division of two unsigned integers, reverting with custom message on\n     * division by zero. The result is rounded towards zero.\n     *\n     * CAUTION: This function is deprecated because it requires allocating memory for the error\n     * message unnecessarily. For custom revert reasons use {tryDiv}.\n     *\n     * Counterpart to Solidity\u0027s `/` operator. Note: this function uses a\n     * `revert` opcode (which leaves remaining gas untouched) while Solidity\n     * uses an invalid opcode to revert (consuming all remaining gas).\n     *\n     * Requirements:\n     *\n     * - The divisor cannot be zero.\n     */\n    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {\n        require(b \u003e 0, errorMessage);\n        return a / b;\n    }\n\n    /**\n     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),\n     * reverting with custom message when dividing by zero.\n     *\n     * CAUTION: This function is deprecated because it requires allocating memory for the error\n     * message unnecessarily. For custom revert reasons use {tryMod}.\n     *\n     * Counterpart to Solidity\u0027s `%` operator. This function uses a `revert`\n     * opcode (which leaves remaining gas untouched) while Solidity uses an\n     * invalid opcode to revert (consuming all remaining gas).\n     *\n     * Requirements:\n     *\n     * - The divisor cannot be zero.\n     */\n    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {\n        require(b \u003e 0, errorMessage);\n        return a % b;\n    }\n}\n"}}