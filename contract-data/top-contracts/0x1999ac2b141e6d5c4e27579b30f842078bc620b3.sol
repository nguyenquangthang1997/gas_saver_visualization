{"ERC20.sol":{"content":"pragma solidity \u003e=0.4.24;\r\n\r\nimport \"./IERC20.sol\";\r\nimport \"./safemath.sol\";\r\n\r\ncontract ERC20 is IERC20 {\r\n  using SafeMath for uint256;\r\n\r\n  mapping (address =\u003e uint256) private _balances;\r\n\r\n  mapping (address =\u003e mapping (address =\u003e uint256)) private _allowed;\r\n\r\n  uint256 private _totalSupply;\r\n\r\n  /**\r\n  * @dev Total number of tokens in existence\r\n  */\r\n  function totalSupply() public view returns (uint256) {\r\n    return _totalSupply;\r\n  }\r\n\r\n  /**\r\n  * @dev Gets the balance of the specified address.\r\n  * @param owner The address to query the balance of.\r\n  * @return An uint256 representing the amount owned by the passed address.\r\n  */\r\n  function balanceOf(address owner) public view returns (uint256) {\r\n    return _balances[owner];\r\n  }\r\n\r\n  /**\r\n   * @dev Function to check the amount of tokens that an owner allowed to a spender.\r\n   * @param owner address The address which owns the funds.\r\n   * @param spender address The address which will spend the funds.\r\n   * @return A uint256 specifying the amount of tokens still available for the spender.\r\n   */\r\n  function allowance(\r\n    address owner,\r\n    address spender\r\n   )\r\n    public\r\n    view\r\n    returns (uint256)\r\n  {\r\n    return _allowed[owner][spender];\r\n  }\r\n\r\n  /**\r\n  * @dev Transfer token for a specified address\r\n  * @param to The address to transfer to.\r\n  * @param value The amount to be transferred.\r\n  */\r\n  function transfer(address to, uint256 value) public returns (bool) {\r\n    require(value \u003c= _balances[msg.sender]);\r\n    require(to != address(0));\r\n\r\n    _balances[msg.sender] = _balances[msg.sender].sub(value);\r\n    _balances[to] = _balances[to].add(value);\r\n    emit Transfer(msg.sender, to, value);\r\n    return true;\r\n  }\r\n\r\n  /**\r\n   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.\r\n   * Beware that changing an allowance with this method brings the risk that someone may use both the old\r\n   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this\r\n   * race condition is to first reduce the spender\u0027s allowance to 0 and set the desired value afterwards:\r\n   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729\r\n   * @param spender The address which will spend the funds.\r\n   * @param value The amount of tokens to be spent.\r\n   */\r\n  function approve(address spender, uint256 value) public returns (bool) {\r\n    require(spender != address(0));\r\n\r\n    _allowed[msg.sender][spender] = value;\r\n    emit Approval(msg.sender, spender, value);\r\n    return true;\r\n  }\r\n\r\n  /**\r\n   * @dev Transfer tokens from one address to another\r\n   * @param from address The address which you want to send tokens from\r\n   * @param to address The address which you want to transfer to\r\n   * @param value uint256 the amount of tokens to be transferred\r\n   */\r\n  function transferFrom(\r\n    address from,\r\n    address to,\r\n    uint256 value\r\n  )\r\n    public\r\n    returns (bool)\r\n  {\r\n    require(value \u003c= _balances[from]);\r\n    require(value \u003c= _allowed[from][msg.sender]);\r\n    require(to != address(0));\r\n\r\n    _balances[from] = _balances[from].sub(value);\r\n    _balances[to] = _balances[to].add(value);\r\n    _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);\r\n    emit Transfer(from, to, value);\r\n    return true;\r\n  }\r\n\r\n  /**\r\n   * @dev Increase the amount of tokens that an owner allowed to a spender.\r\n   * approve should be called when allowed_[_spender] == 0. To increment\r\n   * allowed value is better to use this function to avoid 2 calls (and wait until\r\n   * the first transaction is mined)\r\n   * From MonolithDAO Token.sol\r\n   * @param spender The address which will spend the funds.\r\n   * @param addedValue The amount of tokens to increase the allowance by.\r\n   */\r\n  function increaseAllowance(\r\n    address spender,\r\n    uint256 addedValue\r\n  )\r\n    public\r\n    returns (bool)\r\n  {\r\n    require(spender != address(0));\r\n\r\n    _allowed[msg.sender][spender] = (\r\n      _allowed[msg.sender][spender].add(addedValue));\r\n    emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);\r\n    return true;\r\n  }\r\n\r\n  /**\r\n   * @dev Decrease the amount of tokens that an owner allowed to a spender.\r\n   * approve should be called when allowed_[_spender] == 0. To decrement\r\n   * allowed value is better to use this function to avoid 2 calls (and wait until\r\n   * the first transaction is mined)\r\n   * From MonolithDAO Token.sol\r\n   * @param spender The address which will spend the funds.\r\n   * @param subtractedValue The amount of tokens to decrease the allowance by.\r\n   */\r\n  function decreaseAllowance(\r\n    address spender,\r\n    uint256 subtractedValue\r\n  )\r\n    public\r\n    returns (bool)\r\n  {\r\n    require(spender != address(0));\r\n\r\n    _allowed[msg.sender][spender] = (\r\n      _allowed[msg.sender][spender].sub(subtractedValue));\r\n    emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);\r\n    return true;\r\n  }\r\n\r\n  /**\r\n   * @dev Internal function that mints an amount of the token and assigns it to\r\n   * an account. This encapsulates the modification of balances such that the\r\n   * proper events are emitted.\r\n   * @param account The account that will receive the created tokens.\r\n   * @param amount The amount that will be created.\r\n   */\r\n  function _mint(address account, uint256 amount) internal {\r\n    require(account != address(0));\r\n    _totalSupply = _totalSupply.add(amount);\r\n    _balances[account] = _balances[account].add(amount);\r\n    emit Transfer(address(0), account, amount);\r\n  }\r\n\r\n  /**\r\n   * @dev Internal function that burns an amount of the token of a given\r\n   * account.\r\n   * @param account The account whose tokens will be burnt.\r\n   * @param amount The amount that will be burnt.\r\n   */\r\n  function _burn(address account, uint256 amount) internal {\r\n    require(account != address(0));\r\n    require(amount \u003c= _balances[account]);\r\n\r\n    _totalSupply = _totalSupply.sub(amount);\r\n    _balances[account] = _balances[account].sub(amount);\r\n    emit Transfer(account, address(0), amount);\r\n  }\r\n\r\n  /**\r\n   * @dev Internal function that burns an amount of the token of a given\r\n   * account, deducting from the sender\u0027s allowance for said account. Uses the\r\n   * internal burn function.\r\n   * @param account The account whose tokens will be burnt.\r\n   * @param amount The amount that will be burnt.\r\n   */\r\n  function _burnFrom(address account, uint256 amount) internal {\r\n    require(amount \u003c= _allowed[account][msg.sender]);\r\n\r\n    // Should https://github.com/OpenZeppelin/zeppelin-solidity/issues/707 be accepted,\r\n    // this function needs to emit an event with the updated approval.\r\n    _allowed[account][msg.sender] = _allowed[account][msg.sender].sub(\r\n      amount);\r\n    _burn(account, amount);\r\n  }\r\n}"},"hyperorchidprotocol.sol":{"content":"pragma solidity \u003e=0.4.24;\r\n\r\nimport \"./ERC20.sol\";\r\n\r\ncontract HyperOrchidProtocol is ERC20{\r\n\r\n    string  public constant  name = \"Hyper Orchid Protocol\";\r\n    string  public constant  symbol = \"HOP\";\r\n    uint8   public constant  decimals = 18;\r\n    uint256 public constant INITIAL_SUPPLY = 4.2e8 * (10 ** uint256(decimals));\r\n\r\n    constructor() public{\r\n        _mint(msg.sender, INITIAL_SUPPLY);\r\n    }\r\n}"},"IERC20.sol":{"content":"pragma solidity \u003e=0.4.24;\r\n\r\ninterface IERC20 {\r\n  function totalSupply() external view returns (uint256);\r\n\r\n  function balanceOf(address who) external view returns (uint256);\r\n\r\n  function allowance(address owner, address spender)\r\n    external view returns (uint256);\r\n\r\n  function transfer(address to, uint256 value) external returns (bool);\r\n\r\n  function approve(address spender, uint256 value)\r\n    external returns (bool);\r\n\r\n  function transferFrom(address from, address to, uint256 value)\r\n    external returns (bool);\r\n\r\n  event Transfer(\r\n    address indexed from,\r\n    address indexed to,\r\n    uint256 value\r\n  );\r\n\r\n  event Approval(\r\n    address indexed owner,\r\n    address indexed spender,\r\n    uint256 value\r\n  );\r\n}"},"safemath.sol":{"content":"pragma solidity \u003e=0.4.24;\r\n\r\nlibrary SafeMath {\r\n\r\n  function mul(uint256 a, uint256 b) internal pure returns (uint256) {\r\n\r\n    if (a == 0) {\r\n      return 0;\r\n    }\r\n\r\n    uint256 c = a * b;\r\n    require(c / a == b);\r\n\r\n    return c;\r\n  }\r\n\r\n\r\n  function div(uint256 a, uint256 b) internal pure returns (uint256) {\r\n    require(b \u003e 0); // Solidity only automatically asserts when dividing by 0\r\n    uint256 c = a / b;\r\n\r\n    return c;\r\n  }\r\n\r\n  function sub(uint256 a, uint256 b) internal pure returns (uint256) {\r\n    require(b \u003c= a);\r\n    uint256 c = a - b;\r\n\r\n    return c;\r\n  }\r\n\r\n  function add(uint256 a, uint256 b) internal pure returns (uint256) {\r\n    uint256 c = a + b;\r\n    require(c \u003e= a);\r\n\r\n    return c;\r\n  }\r\n\r\n  function mod(uint256 a, uint256 b) internal pure returns (uint256) {\r\n    require(b != 0);\r\n    return a % b;\r\n  }\r\n}"}}