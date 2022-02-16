{"ERC20.sol":{"content":"pragma solidity ^0.5.0;\n\nimport \"./IERC20.sol\";\nimport \"./SafeMath.sol\";\n\n/**\n * @dev Implementation of the `IERC20` interface.\n *\n * This implementation is agnostic to the way tokens are created. This means\n * that a supply mechanism has to be added in a derived contract using `_mint`.\n * For a generic mechanism see `ERC20Mintable`.\n *\n * *For a detailed writeup see our guide [How to implement supply\n * mechanisms](https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226).*\n *\n * We have followed general OpenZeppelin guidelines: functions revert instead\n * of returning `false` on failure. This behavior is nonetheless conventional\n * and does not conflict with the expectations of ERC20 applications.\n *\n * Additionally, an `Approval` event is emitted on calls to `transferFrom`.\n * This allows applications to reconstruct the allowance for all accounts just\n * by listening to said events. Other implementations of the EIP may not emit\n * these events, as it isn\u0027t required by the specification.\n *\n * Finally, the non-standard `decreaseAllowance` and `increaseAllowance`\n * functions have been added to mitigate the well-known issues around setting\n * allowances. See `IERC20.approve`.\n */\ncontract ERC20 is IERC20 {\n    using SafeMath for uint256;\n\n    mapping (address =\u003e uint256) public _balances;\n\n    mapping (address =\u003e mapping (address =\u003e uint256)) public _allowances;\n\n    uint256 private _totalSupply;\n\n    /**\n     * @dev See `IERC20.totalSupply`.\n     */\n    function totalSupply() public view returns (uint256) {\n        return _totalSupply;\n    }\n\n    /**\n     * @dev See `IERC20.balanceOf`.\n     */\n    function balanceOf(address account) public view returns (uint256) {\n        return _balances[account];\n    }\n\n    /**\n     * @dev See `IERC20.transfer`.\n     *\n     * Requirements:\n     *\n     * - `recipient` cannot be the zero address.\n     * - the caller must have a balance of at least `amount`.\n     */\n    function transfer(address recipient, uint256 amount) public returns (bool) {\n        _transfer(msg.sender, recipient, amount);\n        return true;\n    }\n\n    /**\n     * @dev See `IERC20.allowance`.\n     */\n    function allowance(address owner, address spender) public view returns (uint256) {\n        return _allowances[owner][spender];\n    }\n\n    /**\n     * @dev See `IERC20.approve`.\n     *\n     * Requirements:\n     *\n     * - `spender` cannot be the zero address.\n     */\n    function approve(address spender, uint256 value) public returns (bool) {\n        _approve(msg.sender, spender, value);\n        return true;\n    }\n\n    /**\n     * @dev See `IERC20.transferFrom`.\n     *\n     * Emits an `Approval` event indicating the updated allowance. This is not\n     * required by the EIP. See the note at the beginning of `ERC20`;\n     *\n     * Requirements:\n     * - `sender` and `recipient` cannot be the zero address.\n     * - `sender` must have a balance of at least `value`.\n     * - the caller must have allowance for `sender`\u0027s tokens of at least\n     * `amount`.\n     */\n    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {\n        _transfer(sender, recipient, amount);\n        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));\n        return true;\n    }\n\n    /**\n     * @dev Atomically increases the allowance granted to `spender` by the caller.\n     *\n     * This is an alternative to `approve` that can be used as a mitigation for\n     * problems described in `IERC20.approve`.\n     *\n     * Emits an `Approval` event indicating the updated allowance.\n     *\n     * Requirements:\n     *\n     * - `spender` cannot be the zero address.\n     */\n    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {\n        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));\n        return true;\n    }\n\n    /**\n     * @dev Atomically decreases the allowance granted to `spender` by the caller.\n     *\n     * This is an alternative to `approve` that can be used as a mitigation for\n     * problems described in `IERC20.approve`.\n     *\n     * Emits an `Approval` event indicating the updated allowance.\n     *\n     * Requirements:\n     *\n     * - `spender` cannot be the zero address.\n     * - `spender` must have allowance for the caller of at least\n     * `subtractedValue`.\n     */\n    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {\n        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));\n        return true;\n    }\n\n    /**\n     * @dev Moves tokens `amount` from `sender` to `recipient`.\n     *\n     * This is internal function is equivalent to `transfer`, and can be used to\n     * e.g. implement automatic token fees, slashing mechanisms, etc.\n     *\n     * Emits a `Transfer` event.\n     *\n     * Requirements:\n     *\n     * - `sender` cannot be the zero address.\n     * - `recipient` cannot be the zero address.\n     * - `sender` must have a balance of at least `amount`.\n     */\n    function _transfer(address sender, address recipient, uint256 amount) internal {\n        require(sender != address(0), \"ERC20: transfer from the zero address\");\n        require(recipient != address(0), \"ERC20: transfer to the zero address\");\n\n        _balances[sender] = _balances[sender].sub(amount);\n        _balances[recipient] = _balances[recipient].add(amount);\n        emit Transfer(sender, recipient, amount);\n    }\n\n    /** @dev Creates `amount` tokens and assigns them to `account`, increasing\n     * the total supply.\n     *\n     * Emits a `Transfer` event with `from` set to the zero address.\n     *\n     * Requirements\n     *\n     * - `to` cannot be the zero address.\n     */\n    function _mint(address account, uint256 amount) internal {\n        require(account != address(0), \"ERC20: mint to the zero address\");\n\n        _totalSupply = _totalSupply.add(amount);\n        _balances[account] = _balances[account].add(amount);\n        emit Transfer(address(0), account, amount);\n    }\n\n     /**\n     * @dev Destoys `amount` tokens from `account`, reducing the\n     * total supply.\n     *\n     * Emits a `Transfer` event with `to` set to the zero address.\n     *\n     * Requirements\n     *\n     * - `account` cannot be the zero address.\n     * - `account` must have at least `amount` tokens.\n     */\n    function _burn(address account, uint256 value) internal {\n        require(account != address(0), \"ERC20: burn from the zero address\");\n\n        _totalSupply = _totalSupply.sub(value);\n        _balances[account] = _balances[account].sub(value);\n        emit Transfer(account, address(0), value);\n    }\n\n    /**\n     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.\n     *\n     * This is internal function is equivalent to `approve`, and can be used to\n     * e.g. set automatic allowances for certain subsystems, etc.\n     *\n     * Emits an `Approval` event.\n     *\n     * Requirements:\n     *\n     * - `owner` cannot be the zero address.\n     * - `spender` cannot be the zero address.\n     */\n    function _approve(address owner, address spender, uint256 value) internal {\n        require(owner != address(0), \"ERC20: approve from the zero address\");\n        require(spender != address(0), \"ERC20: approve to the zero address\");\n\n        _allowances[owner][spender] = value;\n        emit Approval(owner, spender, value);\n    }\n\n    /**\n     * @dev Destoys `amount` tokens from `account`.`amount` is then deducted\n     * from the caller\u0027s allowance.\n     *\n     * See `_burn` and `_approve`.\n     */\n    function _burnFrom(address account, uint256 amount) internal {\n        _burn(account, amount);\n        _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount));\n    }\n}"},"ERC20Burnable.sol":{"content":"pragma solidity ^0.5.0;\nimport \"./ERC20.sol\";\n\n/**\n * @dev Extension of `ERC20` that allows token holders to destroy both their own\n * tokens and those that they have an allowance for, in a way that can be\n * recognized off-chain (via event analysis).\n */\ncontract ERC20Burnable is ERC20 {\n    /**\n     * @dev Destoys `amount` tokens from the caller.\n     *\n     * See `ERC20._burn`.\n     */\n    function burn(uint256 amount) public {\n        _burn(msg.sender, amount);\n    }\n\n    /**\n     * @dev See `ERC20._burnFrom`.\n     */\n    function burnFrom(address account, uint256 amount) public {\n        _burnFrom(account, amount);\n    }\n}"},"IERC20.sol":{"content":"pragma solidity ^0.5.0;\n\n/**\n * @dev Interface of the ERC20 standard as defined in the EIP. Does not include\n * the optional functions; to access them see `ERC20Detailed`.\n */\ninterface IERC20 {\n    /**\n     * @dev Returns the amount of tokens in existence.\n     */\n    function totalSupply() external view returns (uint256);\n\n    /**\n     * @dev Returns the amount of tokens owned by `account`.\n     */\n    function balanceOf(address account) external view returns (uint256);\n\n    /**\n     * @dev Moves `amount` tokens from the caller\u0027s account to `recipient`.\n     *\n     * Returns a boolean value indicating whether the operation succeeded.\n     *\n     * Emits a `Transfer` event.\n     */\n    function transfer(address recipient, uint256 amount) external returns (bool);\n\n    /**\n     * @dev Returns the remaining number of tokens that `spender` will be\n     * allowed to spend on behalf of `owner` through `transferFrom`. This is\n     * zero by default.\n     *\n     * This value changes when `approve` or `transferFrom` are called.\n     */\n    function allowance(address owner, address spender) external view returns (uint256);\n\n    /**\n     * @dev Sets `amount` as the allowance of `spender` over the caller\u0027s tokens.\n     *\n     * Returns a boolean value indicating whether the operation succeeded.\n     *\n     * \u003e Beware that changing an allowance with this method brings the risk\n     * that someone may use both the old and the new allowance by unfortunate\n     * transaction ordering. One possible solution to mitigate this race\n     * condition is to first reduce the spender\u0027s allowance to 0 and set the\n     * desired value afterwards:\n     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729\n     *\n     * Emits an `Approval` event.\n     */\n    function approve(address spender, uint256 amount) external returns (bool);\n\n    /**\n     * @dev Moves `amount` tokens from `sender` to `recipient` using the\n     * allowance mechanism. `amount` is then deducted from the caller\u0027s\n     * allowance.\n     *\n     * Returns a boolean value indicating whether the operation succeeded.\n     *\n     * Emits a `Transfer` event.\n     */\n    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);\n\n    /**\n     * @dev Emitted when `value` tokens are moved from one account (`from`) to\n     * another (`to`).\n     *\n     * Note that `value` may be zero.\n     */\n    event Transfer(address indexed from, address indexed to, uint256 value);\n\n    /**\n     * @dev Emitted when the allowance of a `spender` for an `owner` is set by\n     * a call to `approve`. `value` is the new allowance.\n     */\n    event Approval(address indexed owner, address indexed spender, uint256 value);\n}"},"LockableToken.sol":{"content":"pragma solidity ^0.5.0; // solidity 0.5.2\n\nimport \u0027./ERC20.sol\u0027;\nimport \u0027./MultiOwnable.sol\u0027;\nimport \u0027./ERC20Burnable.sol\u0027;\n/**\n * @title Lockable token\n */\ncontract LockableToken is ERC20, MultiOwnable, ERC20Burnable {\n    bool public locked = true;\n    uint256 public constant LOCK_MAX = uint256(-1);\n\n    /**\n     * dev 락 상태에서도 거래 가능한 언락 계정\n     */\n    mapping(address =\u003e bool) public unlockAddrs;\n    /**\n     * dev 계정 별로 lock value 만큼 잔고가 잠김\n     * dev - 값이 0 일 때 : 잔고가 0 이어도 되므로 제한이 없는 것임.\n     * dev - 값이 LOCK_MAX 일 때 : 잔고가 uint256 의 최대값이므로 아예 잠긴 것임.\n     */\n    mapping(address =\u003e uint256) public lockValues;\n\n    event Locked(bool locked, string note);\n    event LockedTo(address indexed addr, bool locked, string note);\n    event SetLockValue(address indexed addr, uint256 value, string note);\n\n    constructor() public {\n        unlockTo(msg.sender,  \"\");\n    }\n\n    modifier checkUnlock (address addr, uint256 value) {\n        require(!locked || unlockAddrs[addr], \"The account is currently locked.\");\n        require(_balances[addr].sub(value) \u003e= lockValues[addr], \"Transferable limit exceeded. Check the status of the lock value.\");\n        _;\n    }\n\n    function lock(string memory note) onlyOwner public {\n        locked = true;\n        emit Locked(locked, note);\n    }\n\n    function unlock(string memory note) onlyOwner public {\n        locked = false;\n        emit Locked(locked, note);\n    }\n\n    function lockTo(address addr, string memory note) onlyOwner public {\n        setLockValue(addr, LOCK_MAX, note);\n        unlockAddrs[addr] = false;\n\n        emit LockedTo(addr, true, note);\n    }\n\n    function unlockTo(address addr, string memory note) onlyOwner public {\n        if (lockValues[addr] == LOCK_MAX)\n            setLockValue(addr, 0, note);\n        unlockAddrs[addr] = true;\n\n        emit LockedTo(addr, false, note);\n    }\n\n    function setLockValue(address addr, uint256 value, string memory note) onlyOwner public {\n        lockValues[addr] = value;\n        emit SetLockValue(addr, value, note);\n    }\n\n    /**\n     * dev 이체 가능 금액을 조회한다.\n     */\n    function getMyUnlockValue() public view returns (uint256) {\n        address addr = msg.sender;\n        if ((!locked || unlockAddrs[addr]) \u0026\u0026 _balances[addr] \u003e lockValues[addr])\n            return _balances[addr].sub(lockValues[addr]);\n        else\n            return 0;\n    }\n\n    function transfer(address to, uint256 value) checkUnlock(msg.sender, value) public returns (bool) {\n        return super.transfer(to, value);\n    }\n\n    function transferFrom(address from, address to, uint256 value) checkUnlock(from, value) public returns (bool) {\n        return super.transferFrom(from, to, value);\n    }\n    \n    function burn(uint256 amount) onlyOwner public {\n        return super.burn(amount);\n    }\n    \n    function burnFrom(address account, uint256 amount) onlyOwner public {\n        return super.burnFrom(account,amount);\n    }\n    \n}"},"MultiOwnable.sol":{"content":"pragma solidity ^0.5.0; // solidity 0.5.2\n\nimport \"./SafeMath.sol\";\n\n/**\n * @title MultiOwnable\n * dev\n */\ncontract MultiOwnable {\n    using SafeMath for uint256;\n\n    address public root; // 혹시 몰라 준비해둔 superOwner 의 백업. 하드웨어 월렛 주소로 세팅할 예정.\n    address public superOwner;\n    mapping (address =\u003e bool) public owners;\n    address[] public ownerList;\n\n    // for changeSuperOwnerByDAO\n    // mapping(address =\u003e mapping (address =\u003e bool)) public preSuperOwnerMap;\n    mapping(address =\u003e address) public candidateSuperOwnerMap;\n\n\n    event ChangedRoot(address newRoot);\n    event ChangedSuperOwner(address newSuperOwner);\n    event AddedNewOwner(address newOwner);\n    event DeletedOwner(address deletedOwner);\n\n    constructor() public {\n        root = msg.sender;\n        superOwner = msg.sender;\n        owners[root] = true;\n\n        ownerList.push(msg.sender);\n\n    }\n\n    modifier onlyRoot() {\n        require(msg.sender == root, \"Root privilege is required.\");\n        _;\n    }\n\n    modifier onlySuperOwner() {\n        require(msg.sender == superOwner, \"SuperOwner priviledge is required.\");\n        _;\n    }\n\n    modifier onlyOwner() {\n        require(owners[msg.sender], \"Owner priviledge is required.\");\n        _;\n    }\n\n    /**\n     * dev root 교체 (root 는 root 와 superOwner 를 교체할 수 있는 권리가 있다.)\n     * dev 기존 루트가 관리자에서 지워지지 않고, 새 루트가 자동으로 관리자에 등록되지 않음을 유의!\n     */\n    function changeRoot(address newRoot) onlyRoot public returns (bool) {\n        require(newRoot != address(0), \"This address to be set is zero address(0). Check the input address.\");\n\n        root = newRoot;\n\n        emit ChangedRoot(newRoot);\n        return true;\n    }\n\n    /**\n     * dev superOwner 교체 (root 는 root 와 superOwner 를 교체할 수 있는 권리가 있다.)\n     * dev 기존 superOwner 가 관리자에서 지워지지 않고, 새 superOwner 가 자동으로 관리자에 등록되지 않음을 유의!\n     */\n    function changeSuperOwner(address newSuperOwner) onlyRoot public returns (bool) {\n        require(newSuperOwner != address(0), \"This address to be set is zero address(0). Check the input address.\");\n\n        superOwner = newSuperOwner;\n\n        emit ChangedSuperOwner(newSuperOwner);\n        return true;\n    }\n\n    /**\n     * dev owner 들의 1/2 초과가 합의하면 superOwner 를 교체할 수 있다.\n     */\n    function changeSuperOwnerByDAO(address newSuperOwner) onlyOwner public returns (bool) {\n        require(newSuperOwner != address(0), \"This address to be set is zero address(0). Check the input address.\");\n        require(newSuperOwner != candidateSuperOwnerMap[msg.sender], \"You have already voted for this account.\");\n\n        candidateSuperOwnerMap[msg.sender] = newSuperOwner;\n\n        uint8 votingNumForSuperOwner = 0;\n        uint8 i = 0;\n\n        for (i = 0; i \u003c ownerList.length; i++) {\n            if (candidateSuperOwnerMap[ownerList[i]] == newSuperOwner)\n                votingNumForSuperOwner++;\n        }\n\n        if (votingNumForSuperOwner \u003e ownerList.length / 2) { // 과반수 이상이면 DAO 성립 =\u003e superOwner 교체\n            superOwner = newSuperOwner;\n\n            // 초기화\n            for (i = 0; i \u003c ownerList.length; i++) {\n                delete candidateSuperOwnerMap[ownerList[i]];\n            }\n\n            emit ChangedSuperOwner(newSuperOwner);\n        }\n\n        return true;\n    }\n\n    function newOwner(address owner) onlySuperOwner public returns (bool) {\n        require(owner != address(0), \"This address to be set is zero address(0). Check the input address.\");\n        require(!owners[owner], \"This address is already registered.\");\n\n        owners[owner] = true;\n        ownerList.push(owner);\n\n        emit AddedNewOwner(owner);\n        return true;\n    }\n\n    function deleteOwner(address owner) onlySuperOwner public returns (bool) {\n        require(owners[owner], \"This input address is not a super owner.\");\n        delete owners[owner];\n\n        for (uint256 i = 0; i \u003c ownerList.length; i++) {\n            if (ownerList[i] == owner) {\n                ownerList[i] = ownerList[ownerList.length.sub(1)];\n                ownerList.length = ownerList.length.sub(1);\n                break;\n            }\n        }\n\n        emit DeletedOwner(owner);\n        return true;\n    }\n}"},"MyToken.sol":{"content":"pragma solidity ^0.5.0; // solidity 0.5.2\n\nimport \u0027./LockableToken.sol\u0027;\n\ncontract MyToken is LockableToken {\n  string public constant name = \"FANZY EXCHANGE\";\n  string public constant symbol = \"FX\";\n  uint public constant decimals = 18; // 소수점 18자리\n  uint public constant INITIAL_SUPPLY = 7000000000 * 10 ** decimals; // 초기 발행량\n\n  constructor() public {\n    _mint(msg.sender, INITIAL_SUPPLY);\n  }\n}\n"},"SafeMath.sol":{"content":"pragma solidity ^0.5.0;\n\n/**\n * @dev Wrappers over Solidity\u0027s arithmetic operations with added overflow\n * checks.\n *\n * Arithmetic operations in Solidity wrap on overflow. This can easily result\n * in bugs, because programmers usually assume that an overflow raises an\n * error, which is the standard behavior in high level programming languages.\n * `SafeMath` restores this intuition by reverting the transaction when an\n * operation overflows.\n *\n * Using this library instead of the unchecked operations eliminates an entire\n * class of bugs, so it\u0027s recommended to use it always.\n */\nlibrary SafeMath {\n    /**\n     * @dev Returns the addition of two unsigned integers, reverting on\n     * overflow.\n     *\n     * Counterpart to Solidity\u0027s `+` operator.\n     *\n     * Requirements:\n     * - Addition cannot overflow.\n     */\n    function add(uint256 a, uint256 b) internal pure returns (uint256) {\n        uint256 c = a + b;\n        require(c \u003e= a, \"SafeMath: addition overflow\");\n\n        return c;\n    }\n\n    /**\n     * @dev Returns the subtraction of two unsigned integers, reverting on\n     * overflow (when the result is negative).\n     *\n     * Counterpart to Solidity\u0027s `-` operator.\n     *\n     * Requirements:\n     * - Subtraction cannot overflow.\n     */\n    function sub(uint256 a, uint256 b) internal pure returns (uint256) {\n        require(b \u003c= a, \"SafeMath: subtraction overflow\");\n        uint256 c = a - b;\n\n        return c;\n    }\n\n    /**\n     * @dev Returns the multiplication of two unsigned integers, reverting on\n     * overflow.\n     *\n     * Counterpart to Solidity\u0027s `*` operator.\n     *\n     * Requirements:\n     * - Multiplication cannot overflow.\n     */\n    function mul(uint256 a, uint256 b) internal pure returns (uint256) {\n        // Gas optimization: this is cheaper than requiring \u0027a\u0027 not being zero, but the\n        // benefit is lost if \u0027b\u0027 is also tested.\n        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522\n        if (a == 0) {\n            return 0;\n        }\n\n        uint256 c = a * b;\n        require(c / a == b, \"SafeMath: multiplication overflow\");\n\n        return c;\n    }\n\n    /**\n     * @dev Returns the integer division of two unsigned integers. Reverts on\n     * division by zero. The result is rounded towards zero.\n     *\n     * Counterpart to Solidity\u0027s `/` operator. Note: this function uses a\n     * `revert` opcode (which leaves remaining gas untouched) while Solidity\n     * uses an invalid opcode to revert (consuming all remaining gas).\n     *\n     * Requirements:\n     * - The divisor cannot be zero.\n     */\n    function div(uint256 a, uint256 b) internal pure returns (uint256) {\n        // Solidity only automatically asserts when dividing by 0\n        require(b \u003e 0, \"SafeMath: division by zero\");\n        uint256 c = a / b;\n        // assert(a == b * c + a % b); // There is no case in which this doesn\u0027t hold\n\n        return c;\n    }\n\n    /**\n     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),\n     * Reverts when dividing by zero.\n     *\n     * Counterpart to Solidity\u0027s `%` operator. This function uses a `revert`\n     * opcode (which leaves remaining gas untouched) while Solidity uses an\n     * invalid opcode to revert (consuming all remaining gas).\n     *\n     * Requirements:\n     * - The divisor cannot be zero.\n     */\n    function mod(uint256 a, uint256 b) internal pure returns (uint256) {\n        require(b != 0, \"SafeMath: modulo by zero\");\n        return a % b;\n    }\n}"}}