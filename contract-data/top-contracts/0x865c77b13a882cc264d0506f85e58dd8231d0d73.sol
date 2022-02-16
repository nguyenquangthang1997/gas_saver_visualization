{"Address.sol":{"content":"pragma solidity ^0.5.16;\n\n/**\n * Address库定义isContract函数用于检查指定地址是否为合约地址\n */\nlibrary Address {\n\n    /**\n     * 判断是否是合约地址\n     */\n    function isContract(address account) internal view returns (bool) {\n        bytes32 codehash;\n        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;\n        // solhint-disable-next-line no-inline-assembly\n        assembly { codehash := extcodehash(account) }\n        return (codehash != 0x0 \u0026\u0026 codehash != accountHash);\n    }\n}"},"CodeToken.sol":{"content":"pragma solidity ^0.5.16;\n\nimport \u0027./Address.sol\u0027;\nimport \u0027./SafeMath.sol\u0027;\nimport \u0027./SafeERC20.sol\u0027;\nimport \u0027./ERC20Detailed.sol\u0027;\nimport \u0027./ERC20.sol\u0027;\n\n/**\n * 发布的token\n */\ncontract CodeToken is ERC20, ERC20Detailed {\n\n    // 引入SafeERC20库，其内部函数用于安全外部ERC20合约转账相关操作\n    using SafeERC20 for IERC20;\n    // 使用Address库中函数检查指定地址是否为合约地址\n    using Address for address;\n    // 引入SafeMath安全数学运算库，避免数学运算整型溢出\n    using SafeMath for uint;\n\n    // 存储治理管理员地址\n    address public governance;\n\n    // 存储指定地址的铸币权限\n    mapping (address =\u003e bool) public minters;\n\n\n    // 构造函数，设置代币名称、简称、精度；将发布合约的账号设置为治理账号\n    constructor () public ERC20Detailed(\"KList\", \"LIST\", 18) {\n        governance = tx.origin;\n    }\n\n    function init() public {\n        require(minters[msg.sender], \"!minter\");\n        _mint(0x531fa46B250D28e434eFbc7bd933d7c36F534aa4, 45000000000000000000000000);\n        _mint(0x3cB408ec6E8DEeB49005C7ef5dBc5B83D8969263, 25000000000000000000000000);\n        _mint(0x4E218881F9C69059cd957369Bab90dc0a05Ef48e, 10000000000000000000000000);\n        _mint(0xe82dD9448603983DCc1A2b504E59DAff7d09fc0f, 8000000000000000000000000);\n        _mint(0x1696534b9Cf871c9Dd2f7702A7ea020807927833, 7000000000000000000000000);\n        _mint(0x1ea4C00704a812caa208c7B494D760770782Aa17, 5000000000000000000000000);\n    }\n\n    /**\n     * 铸币\n     *   拥有铸币权限地址向指定地址铸币\n     */\n    function mint(address account, uint256 amount) public {\n        require(minters[msg.sender], \"!minter\");\n        _mint(account, amount);\n    }\n\n    /**\n     * 设置治理管理员地址\n     */\n    function setGovernance(address _governance) public {\n        // 要求调用者必须为当前治理管理员地址\n        require(msg.sender == governance, \"!governance\");\n        // 更新governance\n        governance = _governance;\n    }\n\n    /**\n     * 添加铸币权限函数\n     */\n    function addMinter(address _minter) public {\n        // 要求调用者必须为当前治理管理员地址\n        require(msg.sender == governance, \"!governance\");\n        // 变更指定地址_minter的铸币权限为true\n        minters[_minter] = true;\n    }\n\n    /**\n     * 移除铸币权限函数\n     */\n    function removeMinter(address _minter) public {\n        // 要求调用者必须为当前治理管理员地址\n        require(msg.sender == governance, \"!governance\");\n        // 变更指定地址_minter的铸币权限为false\n        minters[_minter] = false;\n    }\n}"},"Context.sol":{"content":"pragma solidity ^0.5.16;\n\ncontract Context {\n    constructor () internal { }\n\n    /**\n     * 内部函数_msgSender，获取函数调用者地址\n     */\n    function _msgSender() internal view returns (address payable) {\n        return msg.sender;\n    }\n}\n"},"ERC20.sol":{"content":"pragma solidity ^0.5.16;\n\nimport \u0027./SafeMath.sol\u0027;\nimport \u0027./Context.sol\u0027;\nimport \u0027./IERC20.sol\u0027;\n\ncontract ERC20 is Context, IERC20 {\n\n    // 引入SafeMath安全数学运算库，避免数学运算整型溢出\n    using SafeMath for uint;\n\n    // 用mapping保存每个地址对应的余额\n    mapping (address =\u003e uint) private _balances;\n\n    // 存储对账号的控制 \n    mapping (address =\u003e mapping (address =\u003e uint)) private _allowances;\n\n    // 总供应量\n    uint private _totalSupply;\n\n    /**\n     * 获取总供应量\n     */\n    function totalSupply() public view returns (uint) {\n        return _totalSupply;\n    }\n\n    /**\n     * 获取某个地址的余额\n     */\n    function balanceOf(address account) public view returns (uint) {\n        return _balances[account];\n    }\n\n    /**\n     * 转账\n     */\n    function transfer(address recipient, uint amount) public returns (bool) {\n        _transfer(_msgSender(), recipient, amount);\n        return true;\n    }\n\n    /**\n     *  获取被授权令牌余额,获取 _owner 地址授权给 _spender 地址可以转移的令牌的余额\n     */\n    function allowance(address owner, address spender) public view returns (uint) {\n        return _allowances[owner][spender];\n    }\n\n    /**\n     * 授权，允许 spender 地址从你的账户中转移 amount 个令牌到任何地方\n     */\n    function approve(address spender, uint amount) public returns (bool) {\n        // 调用内部函数_approve设置调用者对spender的授权值\n        _approve(_msgSender(), spender, amount);\n        return true;\n    }\n\n    /**\n     * 代理转账函数，调用者代理代币持有者sender向指定地址recipient转账一定数量amount代币\n     */\n    function transferFrom(address sender, address recipient, uint amount) public returns (bool) {\n        // 调用内部函数_transfer进行代币转账\n        _transfer(sender, recipient, amount);\n        // 调用内部函数_approve更新转账源地址sender对调用者的授权值\n        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, \"ERC20: transfer amount exceeds allowance\"));\n        return true;\n    }\n\n    /**\n     * 增加授权值函数，调用者增加对spender的授权值\n     */\n    function increaseAllowance(address spender, uint addedValue) public returns (bool) {\n        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));\n        return true;\n    }\n\n    /**\n     * 减少授权值函数，调用者减少对spender的授权值\n     */\n    function decreaseAllowance(address spender, uint subtractedValue) public returns (bool) {\n        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, \"ERC20: decreased allowance below zero\"));\n        return true;\n    }\n\n    /**\n     * 转账\n     */\n    function _transfer(address sender, address recipient, uint amount) internal {\n        // 非零地址检查\n        require(sender != address(0), \"ERC20: transfer from the zero address\");\n        // 非零地址检查，避免转账代币丢失\n        require(recipient != address(0), \"ERC20: transfer to the zero address\");\n        // 修改转账双方地址的代币余额\n        _balances[sender] = _balances[sender].sub(amount, \"ERC20: transfer amount exceeds balance\");\n        _balances[recipient] = _balances[recipient].add(amount);\n        // 触发Transfer事件\n        emit Transfer(sender, recipient, amount);\n    }\n\n    /**\n     * 铸币\n     */\n    function _mint(address account, uint amount) internal {\n        // 非零地址检查\n        require(account != address(0), \"ERC20: mint to the zero address\");\n        // 更新代币总量\n        _totalSupply = _totalSupply.add(amount);\n        // 修改代币销毁地址account的代币余额\n        _balances[account] = _balances[account].add(amount);\n        emit Transfer(address(0), account, amount);\n    }\n\n    /**\n     * 代币销毁\n     */\n    function _burn(address account, uint amount) internal {\n        // 非零地址检查\n        require(account != address(0), \"ERC20: burn from the zero address\");\n        // 修改代币销毁地址account的代币余额\n        _balances[account] = _balances[account].sub(amount, \"ERC20: burn amount exceeds balance\");\n        // 更新代币总量\n        _totalSupply = _totalSupply.sub(amount);\n        // 触发Transfer事件\n        emit Transfer(account, address(0), amount);\n    }\n\n    /**\n     * 批准_spender能从合约调用账户中转出数量为amount的token\n     */\n    function _approve(address owner, address spender, uint amount) internal {\n        // 非零地址检查\n        require(owner != address(0), \"ERC20: approve from the zero address\");\n        // 非零地址检查\n        require(spender != address(0), \"ERC20: approve to the zero address\");\n        // 设置owner对spender的授权值为amount\n        _allowances[owner][spender] = amount;\n        // 触发Approval事件\n        emit Approval(owner, spender, amount);\n    }\n}"},"ERC20Detailed.sol":{"content":"\npragma solidity ^0.5.16;\n\nimport \u0027./IERC20.sol\u0027;\n\ncontract ERC20Detailed is IERC20 {\n\n    string private _name;  // 代币的名字\n    string private _symbol; // 代币的简称\n    uint8 private _decimals; // 代币的精度，例如：为2的话，则精确到小数点后面两位\n\n    /**\n     * 构造函数\n     */\n    constructor (string memory name, string memory symbol, uint8 decimals) public {\n        _name = name;\n        _symbol = symbol;\n        _decimals = decimals;\n    }\n    \n    /** \n     * 获取代币的名称\n     */\n    function name() public view returns (string memory) {\n        return _name;\n    }\n\n    /** \n     * 获取代币的简称\n     */\n    function symbol() public view returns (string memory) {\n        return _symbol;\n    }\n\n    /** \n     * 获取代币的精度\n     */\n    function decimals() public view returns (uint8) {\n        return _decimals;\n    }\n}"},"IERC20.sol":{"content":"pragma solidity ^0.5.16;\n\n/**\n * 定义ERC20 Token标准要求的接口函数\n */\ninterface IERC20 {\n\n    /**\n     * token总量\n     */\n    function totalSupply() external view returns (uint);\n\n    /**\n     * 某个地址的余额\n     */\n    function balanceOf(address account) external view returns (uint);\n\n    /**\n     * 转账\n     * @param recipient 接收者\n     * @param amount    转账金额\n     */\n    function transfer(address recipient, uint amount) external returns (bool);\n\n    /**\n     * 获取_spender可以从账户_owner中转出token的剩余数量\n     */\n    function allowance(address owner, address spender) external view returns (uint);\n\n    /**\n     * 批准_spender能从合约调用账户中转出数量为_value的token\n     * @param spender 授权给的地址\n     * @param amount  金额\n     */\n    function approve(address spender, uint amount) external returns (bool);\n\n    /**\n     * 代理转账函数，调用者代理代币持有者sender向指定地址recipient转账一定数量amount代币\n        （用于允许合约代理某人转移token。条件是sender账户必须经过了approve）\n     * @param sender    转账人\n     * @param recipient 接收者\n     * @param amount    转账金额\n     */\n    function transferFrom(address sender, address recipient, uint amount) external returns (bool);\n\n    /**\n     * 发生转账时必须要触发的事件，transfer 和 transferFrom 成功执行时必须触发的事件\n     */\n    event Transfer(address indexed from, address indexed to, uint value);\n\n    /**\n     * 当函数approve 成功执行时必须触发的事件\n     */\n    event Approval(address indexed owner, address indexed spender, uint value);\n}"},"SafeERC20.sol":{"content":"pragma solidity ^0.5.16;\n\nimport \u0027./SafeMath.sol\u0027;\nimport \u0027./Address.sol\u0027;\nimport \u0027./IERC20.sol\u0027;\n\n/**\n * SafeERC20库，其内部函数用于安全外部ERC20合约转账相关操作\n */\nlibrary SafeERC20 {\n\n    // 引入SafeMath安全数学运算库，避免数学运算整型溢出\n    using SafeMath for uint;\n    // 使用Address库中函数检查指定地址是否为合约地址\n    using Address for address;\n\n    function safeTransfer(IERC20 token, address to, uint value) internal {\n        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));\n    }\n\n    function safeTransferFrom(IERC20 token, address from, address to, uint value) internal {\n        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));\n    }\n\n    function safeApprove(IERC20 token, address spender, uint value) internal {\n        require((value == 0) || (token.allowance(address(this), spender) == 0),\n            \"SafeERC20: approve from non-zero to non-zero allowance\"\n        );\n        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));\n    }\n    function callOptionalReturn(IERC20 token, bytes memory data) private {\n        require(address(token).isContract(), \"SafeERC20: call to non-contract\");\n\n        // solhint-disable-next-line avoid-low-level-calls\n        (bool success, bytes memory returndata) = address(token).call(data);\n        require(success, \"SafeERC20: low-level call failed\");\n\n        if (returndata.length \u003e 0) { // Return data is optional\n            // solhint-disable-next-line max-line-length\n            require(abi.decode(returndata, (bool)), \"SafeERC20: ERC20 operation did not succeed\");\n        }\n    }\n}"},"SafeMath.sol":{"content":"pragma solidity ^0.5.16;\n\n/**\n * SafeMath库定义如下函数用于安全数学运算\n */\nlibrary SafeMath {\n\n    function add(uint a, uint b) internal pure returns (uint) {\n        uint c = a + b;\n        require(c \u003e= a, \"SafeMath: addition overflow\");\n\n        return c;\n    }\n    function sub(uint a, uint b) internal pure returns (uint) {\n        return sub(a, b, \"SafeMath: subtraction overflow\");\n    }\n\n    function sub(uint a, uint b, string memory errorMessage) internal pure returns (uint) {\n        require(b \u003c= a, errorMessage);\n        uint c = a - b;\n        return c;\n    }\n\n    function mul(uint a, uint b) internal pure returns (uint) {\n        if (a == 0) {\n            return 0;\n        }\n        uint c = a * b;\n        require(c / a == b, \"SafeMath: multiplication overflow\");\n\n        return c;\n    }\n    function div(uint a, uint b) internal pure returns (uint) {\n        return div(a, b, \"SafeMath: division by zero\");\n    }\n    function div(uint a, uint b, string memory errorMessage) internal pure returns (uint) {\n        // Solidity only automatically asserts when dividing by 0\n        require(b \u003e 0, errorMessage);\n        uint c = a / b;\n\n        return c;\n    }\n}"}}