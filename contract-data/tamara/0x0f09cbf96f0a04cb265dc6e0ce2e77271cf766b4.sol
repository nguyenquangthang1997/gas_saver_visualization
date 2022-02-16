pragma solidity ^0.5.4;

import "./SafeMath.sol";
import "./IERC20.sol";

contract ERC20 is IERC20 {

  using SafeMath for uint256;

  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowances;
  uint256 private _totalSupply;

  function totalSupply()
  public view
  returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account)
  public view
  returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount)
  public
  returns (bool) {
    _transfer(msg.sender, recipient, amount);
    return true;
  }

  function allowance(address owner, address spender)
  public view
  returns (uint256) {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount)
  public
  returns (bool) {
    _approve(msg.sender, spender, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount)
  public
  returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
    return true;
  }

  function _transfer(address sender, address recipient, uint256 amount)
  internal {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");

    _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
    _balances[recipient] = _balances[recipient].add(amount);
    emit Transfer(sender, recipient, amount);
  }

  function _mint(address account, uint256 amount)
  internal {
    require(account != address(0), "ERC20: mint to the zero address");
    _totalSupply = _totalSupply.add(amount);
    _balances[account] = _balances[account].add(amount);
    emit Transfer(address(0), account, amount);
  }

  function _burn(address account, uint256 amount)
  internal {
    require(account != address(0), "ERC20: burn from the zero address");
    _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
    _totalSupply = _totalSupply.sub(amount);
    emit Transfer(account, address(0), amount);
  }

  function _approve(address owner, address spender, uint256 amount)
  internal {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");
    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }
}
pragma solidity ^0.5.4;

contract HasBlacklist{

  mapping(address => bool) private blacklist;

  event Blacklist(address indexed addr, bool blakclisted);

  function isBlacklisted(address addr)
  public view
  returns(bool){
    return blacklist[addr];
  }

  function _addToBlacklist(address addr)
  internal{
    blacklist[addr] = true;
    emit Blacklist(addr, blacklist[addr]);
  }

  function _removeFromBlacklist(address addr)
  internal{
    blacklist[addr] = false;
    emit Blacklist(addr, blacklist[addr]);
  }
}
pragma solidity ^0.5.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
pragma solidity ^0.5.0;

contract MasterCopy {

  address public masterCopy;
  event Upgraded(address masterCopy);

  function _changeMasterCopy(address _masterCopy)
  internal {
    require(_masterCopy != address(0), "Invalid master copy address provided");
    emit Upgraded(_masterCopy);
    masterCopy = _masterCopy;
  }
}

pragma solidity >=0.4.21 <0.6.0;

contract Migrations {
  address public owner;
  uint public last_completed_migration;

  constructor() public {
    owner = msg.sender;
  }

  modifier restricted() {
    if (msg.sender == owner) _;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }

  function upgrade(address new_address) public restricted {
    Migrations upgraded = Migrations(new_address);
    upgraded.setCompleted(last_completed_migration);
  }
}

pragma solidity ^0.5.4;


contract Ownable {

  address private _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  function owner() public view returns (address) {
    return _owner;
  }

  modifier onlyOwner() {
    require(isOwner(), "ONLY_OWNER");
    _;
  }

  function isOwner()
  public view
  returns (bool) {
    return msg.sender == _owner;
  }

  function renounceOwnership()
  public
  onlyOwner {
    emit OwnershipTransferred(_owner, address(0x01));
    _owner = address(0x01);
  }

  function transferOwnership(address newOwner)
  external
  onlyOwner {
    _transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner)
  internal {
    require(newOwner != address(0), "BAD_ADDRESS");
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
}
pragma solidity ^0.5.4;

contract Pausable{

  bool paused;

  event Paused();
  event Unpaused();

  modifier whenNotPaused(){
    require(!paused, "PAUSED");
    _;
  }

  modifier whenPaused(){
    require(paused, "NOT_PAUSED");
    _;
  }

  function _pause() internal {
    emit Paused();
    paused = true;
  }

  function _unpause() internal {
    emit Unpaused();
    paused = false;
  }

  function isPaused()
  public view
  returns(bool){
    return paused;
  }
}
pragma solidity ^0.5.4;

contract Proxy {

  address implementation;

  constructor(address _implementation)
  public {
    implementation = _implementation;
  }

  function()
  external payable {
    // solium-disable-next-line security/no-inline-assembly
    assembly {
      let target := sload(0)
      calldatacopy(0, 0, calldatasize())
      let result := delegatecall(gas, target, 0, calldatasize(), 0, 0)
      returndatacopy(0, 0, returndatasize())
      switch result
      case 0 { revert(0, returndatasize()) }
      default { return(0, returndatasize()) }
    }
  }
}
pragma solidity ^0.5.4;

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      require(c >= a, "SafeMath: addition overflow");
      return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
      return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
      require(b <= a, errorMessage);
      uint256 c = a - b;
      return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
      if (a == 0) {
        return 0;
      }
      uint256 c = a * b;
      require(c / a == b, "SafeMath: multiplication overflow");
      return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
      return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
      require(b > 0, errorMessage);
      uint256 c = a / b;
      return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
      return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
      require(b != 0, errorMessage);
      return a % b;
    }
}
pragma solidity ^0.5.4;

import "./ERC20.sol";
import "./TokenDetails.sol";
import "./Ownable.sol";
import "./Pausable.sol";
import "./HasBlacklist.sol";
import "./MasterCopy.sol";

contract Token is MasterCopy, ERC20, TokenDetails, Ownable, Pausable, HasBlacklist{

  function setup(address __owner)
  external {
    require(owner() == address(0), "ALREADY_INITIALIZED");
    _transferOwnership(__owner);
    detail("Visible", "VSB", 18);
    _mint(owner(), 100000000000000000000000000);
  }

  function mint(uint256 value)
  external onlyOwner whenNotPaused {
    _mint(owner(), value);
  }

  function burn(uint256 value)
  external whenNotPaused {
    _burn(msg.sender, value);
  }

  function pause()
  external onlyOwner whenNotPaused {
    _pause();
  }

  function unpause()
  external onlyOwner whenPaused {
    _unpause();
  }

  function addToBlacklist(address addr)
  external onlyOwner {
    _addToBlacklist(addr);
  }

  function removeFromBlacklist(address addr)
  external onlyOwner {
    _removeFromBlacklist(addr);
  }

  function transfer(address to, uint256 value)
  public whenNotPaused
  returns (bool) {
    require(!isBlacklisted(msg.sender), "BLACKLISTED");
    return super.transfer(to, value);
  }

  function transferFrom(address from, address to, uint256 value)
  public whenNotPaused
  returns (bool) {
    require(!isBlacklisted(from), "BLACKLISTED");
    return super.transferFrom(from, to, value);
  }

  function approve(address spender, uint256 value)
  public whenNotPaused
  returns (bool) {
    require(!isBlacklisted(msg.sender), "BLACKLISTED");
    return super.approve(spender, value);
  }

  function upgrade(address _newImplementation)
  external onlyOwner{
    _changeMasterCopy(_newImplementation);
  }
}
pragma solidity ^0.5.4;

contract TokenDetails{

  string private _name;
  string private _symbol;
  uint8 private _decimals;

  function detail(string memory name, string memory symbol, uint8 decimals)
  internal {
    _name = name;
    _symbol = symbol;
    _decimals = decimals;
  }

  function name()
  public view
  returns (string memory) {
    return _name;
  }

  function symbol()
  public view
  returns (string memory) {
    return _symbol;
  }

  function decimals()
  public view
  returns (uint8) {
    return _decimals;
  }
}
pragma solidity ^0.5.4;

import "./SafeMath.sol";
import "./IERC20.sol";

contract ERC20 is IERC20 {

  using SafeMath for uint256;

  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowances;
  uint256 private _totalSupply;

  function totalSupply()
  public view
  returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account)
  public view
  returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount)
  public
  returns (bool) {
    _transfer(msg.sender, recipient, amount);
    return true;
  }

  function allowance(address owner, address spender)
  public view
  returns (uint256) {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount)
  public
  returns (bool) {
    _approve(msg.sender, spender, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount)
  public
  returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
    return true;
  }

  function _transfer(address sender, address recipient, uint256 amount)
  internal {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");

    _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
    _balances[recipient] = _balances[recipient].add(amount);
    emit Transfer(sender, recipient, amount);
  }

  function _mint(address account, uint256 amount)
  internal {
    require(account != address(0), "ERC20: mint to the zero address");
    _totalSupply = _totalSupply.add(amount);
    _balances[account] = _balances[account].add(amount);
    emit Transfer(address(0), account, amount);
  }

  function _burn(address account, uint256 amount)
  internal {
    require(account != address(0), "ERC20: burn from the zero address");
    _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
    _totalSupply = _totalSupply.sub(amount);
    emit Transfer(account, address(0), amount);
  }

  function _approve(address owner, address spender, uint256 amount)
  internal {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");
    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }
}
pragma solidity ^0.5.4;

contract HasBlacklist{

  mapping(address => bool) private blacklist;

  event Blacklist(address indexed addr, bool blakclisted);

  function isBlacklisted(address addr)
  public view
  returns(bool){
    return blacklist[addr];
  }

  function _addToBlacklist(address addr)
  internal{
    blacklist[addr] = true;
    emit Blacklist(addr, blacklist[addr]);
  }

  function _removeFromBlacklist(address addr)
  internal{
    blacklist[addr] = false;
    emit Blacklist(addr, blacklist[addr]);
  }
}
pragma solidity ^0.5.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
pragma solidity ^0.5.0;

contract MasterCopy {

  address public masterCopy;
  event Upgraded(address masterCopy);

  function _changeMasterCopy(address _masterCopy)
  internal {
    require(_masterCopy != address(0), "Invalid master copy address provided");
    emit Upgraded(_masterCopy);
    masterCopy = _masterCopy;
  }
}

pragma solidity >=0.4.21 <0.6.0;

contract Migrations {
  address public owner;
  uint public last_completed_migration;

  constructor() public {
    owner = msg.sender;
  }

  modifier restricted() {
    if (msg.sender == owner) _;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }

  function upgrade(address new_address) public restricted {
    Migrations upgraded = Migrations(new_address);
    upgraded.setCompleted(last_completed_migration);
  }
}

pragma solidity ^0.5.4;


contract Ownable {

  address private _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  function owner() public view returns (address) {
    return _owner;
  }

  modifier onlyOwner() {
    require(isOwner(), "ONLY_OWNER");
    _;
  }

  function isOwner()
  public view
  returns (bool) {
    return msg.sender == _owner;
  }

  function renounceOwnership()
  public
  onlyOwner {
    emit OwnershipTransferred(_owner, address(0x01));
    _owner = address(0x01);
  }

  function transferOwnership(address newOwner)
  external
  onlyOwner {
    _transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner)
  internal {
    require(newOwner != address(0), "BAD_ADDRESS");
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
}
pragma solidity ^0.5.4;

contract Pausable{

  bool paused;

  event Paused();
  event Unpaused();

  modifier whenNotPaused(){
    require(!paused, "PAUSED");
    _;
  }

  modifier whenPaused(){
    require(paused, "NOT_PAUSED");
    _;
  }

  function _pause() internal {
    emit Paused();
    paused = true;
  }

  function _unpause() internal {
    emit Unpaused();
    paused = false;
  }

  function isPaused()
  public view
  returns(bool){
    return paused;
  }
}
pragma solidity ^0.5.4;

contract Proxy {

  address implementation;

  constructor(address _implementation)
  public {
    implementation = _implementation;
  }

  function()
  external payable {
    // solium-disable-next-line security/no-inline-assembly
    assembly {
      let target := sload(0)
      calldatacopy(0, 0, calldatasize())
      let result := delegatecall(gas, target, 0, calldatasize(), 0, 0)
      returndatacopy(0, 0, returndatasize())
      switch result
      case 0 { revert(0, returndatasize()) }
      default { return(0, returndatasize()) }
    }
  }
}
pragma solidity ^0.5.4;

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      require(c >= a, "SafeMath: addition overflow");
      return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
      return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
      require(b <= a, errorMessage);
      uint256 c = a - b;
      return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
      if (a == 0) {
        return 0;
      }
      uint256 c = a * b;
      require(c / a == b, "SafeMath: multiplication overflow");
      return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
      return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
      require(b > 0, errorMessage);
      uint256 c = a / b;
      return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
      return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
      require(b != 0, errorMessage);
      return a % b;
    }
}
pragma solidity ^0.5.4;

import "./ERC20.sol";
import "./TokenDetails.sol";
import "./Ownable.sol";
import "./Pausable.sol";
import "./HasBlacklist.sol";
import "./MasterCopy.sol";

contract Token is MasterCopy, ERC20, TokenDetails, Ownable, Pausable, HasBlacklist{

  function setup(address __owner)
  external {
    require(owner() == address(0), "ALREADY_INITIALIZED");
    _transferOwnership(__owner);
    detail("Visible", "VSB", 18);
    _mint(owner(), 100000000000000000000000000);
  }

  function mint(uint256 value)
  external onlyOwner whenNotPaused {
    _mint(owner(), value);
  }

  function burn(uint256 value)
  external whenNotPaused {
    _burn(msg.sender, value);
  }

  function pause()
  external onlyOwner whenNotPaused {
    _pause();
  }

  function unpause()
  external onlyOwner whenPaused {
    _unpause();
  }

  function addToBlacklist(address addr)
  external onlyOwner {
    _addToBlacklist(addr);
  }

  function removeFromBlacklist(address addr)
  external onlyOwner {
    _removeFromBlacklist(addr);
  }

  function transfer(address to, uint256 value)
  public whenNotPaused
  returns (bool) {
    require(!isBlacklisted(msg.sender), "BLACKLISTED");
    return super.transfer(to, value);
  }

  function transferFrom(address from, address to, uint256 value)
  public whenNotPaused
  returns (bool) {
    require(!isBlacklisted(from), "BLACKLISTED");
    return super.transferFrom(from, to, value);
  }

  function approve(address spender, uint256 value)
  public whenNotPaused
  returns (bool) {
    require(!isBlacklisted(msg.sender), "BLACKLISTED");
    return super.approve(spender, value);
  }

  function upgrade(address _newImplementation)
  external onlyOwner{
    _changeMasterCopy(_newImplementation);
  }
}
pragma solidity ^0.5.4;

contract TokenDetails{

  string private _name;
  string private _symbol;
  uint8 private _decimals;

  function detail(string memory name, string memory symbol, uint8 decimals)
  internal {
    _name = name;
    _symbol = symbol;
    _decimals = decimals;
  }

  function name()
  public view
  returns (string memory) {
    return _name;
  }

  function symbol()
  public view
  returns (string memory) {
    return _symbol;
  }

  function decimals()
  public view
  returns (uint8) {
    return _decimals;
  }
}
pragma solidity ^0.5.4;

import "./SafeMath.sol";
import "./IERC20.sol";

contract ERC20 is IERC20 {

  using SafeMath for uint256;

  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowances;
  uint256 private _totalSupply;

  function totalSupply()
  public view
  returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account)
  public view
  returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount)
  public
  returns (bool) {
    _transfer(msg.sender, recipient, amount);
    return true;
  }

  function allowance(address owner, address spender)
  public view
  returns (uint256) {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount)
  public
  returns (bool) {
    _approve(msg.sender, spender, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount)
  public
  returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
    return true;
  }

  function _transfer(address sender, address recipient, uint256 amount)
  internal {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");

    _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
    _balances[recipient] = _balances[recipient].add(amount);
    emit Transfer(sender, recipient, amount);
  }

  function _mint(address account, uint256 amount)
  internal {
    require(account != address(0), "ERC20: mint to the zero address");
    _totalSupply = _totalSupply.add(amount);
    _balances[account] = _balances[account].add(amount);
    emit Transfer(address(0), account, amount);
  }

  function _burn(address account, uint256 amount)
  internal {
    require(account != address(0), "ERC20: burn from the zero address");
    _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
    _totalSupply = _totalSupply.sub(amount);
    emit Transfer(account, address(0), amount);
  }

  function _approve(address owner, address spender, uint256 amount)
  internal {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");
    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }
}
pragma solidity ^0.5.4;

contract HasBlacklist{

  mapping(address => bool) private blacklist;

  event Blacklist(address indexed addr, bool blakclisted);

  function isBlacklisted(address addr)
  public view
  returns(bool){
    return blacklist[addr];
  }

  function _addToBlacklist(address addr)
  internal{
    blacklist[addr] = true;
    emit Blacklist(addr, blacklist[addr]);
  }

  function _removeFromBlacklist(address addr)
  internal{
    blacklist[addr] = false;
    emit Blacklist(addr, blacklist[addr]);
  }
}
pragma solidity ^0.5.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
pragma solidity ^0.5.0;

contract MasterCopy {

  address public masterCopy;
  event Upgraded(address masterCopy);

  function _changeMasterCopy(address _masterCopy)
  internal {
    require(_masterCopy != address(0), "Invalid master copy address provided");
    emit Upgraded(_masterCopy);
    masterCopy = _masterCopy;
  }
}

pragma solidity >=0.4.21 <0.6.0;

contract Migrations {
  address public owner;
  uint public last_completed_migration;

  constructor() public {
    owner = msg.sender;
  }

  modifier restricted() {
    if (msg.sender == owner) _;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }

  function upgrade(address new_address) public restricted {
    Migrations upgraded = Migrations(new_address);
    upgraded.setCompleted(last_completed_migration);
  }
}

pragma solidity ^0.5.4;


contract Ownable {

  address private _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  function owner() public view returns (address) {
    return _owner;
  }

  modifier onlyOwner() {
    require(isOwner(), "ONLY_OWNER");
    _;
  }

  function isOwner()
  public view
  returns (bool) {
    return msg.sender == _owner;
  }

  function renounceOwnership()
  public
  onlyOwner {
    emit OwnershipTransferred(_owner, address(0x01));
    _owner = address(0x01);
  }

  function transferOwnership(address newOwner)
  external
  onlyOwner {
    _transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner)
  internal {
    require(newOwner != address(0), "BAD_ADDRESS");
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
}
pragma solidity ^0.5.4;

contract Pausable{

  bool paused;

  event Paused();
  event Unpaused();

  modifier whenNotPaused(){
    require(!paused, "PAUSED");
    _;
  }

  modifier whenPaused(){
    require(paused, "NOT_PAUSED");
    _;
  }

  function _pause() internal {
    emit Paused();
    paused = true;
  }

  function _unpause() internal {
    emit Unpaused();
    paused = false;
  }

  function isPaused()
  public view
  returns(bool){
    return paused;
  }
}
pragma solidity ^0.5.4;

contract Proxy {

  address implementation;

  constructor(address _implementation)
  public {
    implementation = _implementation;
  }

  function()
  external payable {
    // solium-disable-next-line security/no-inline-assembly
    assembly {
      let target := sload(0)
      calldatacopy(0, 0, calldatasize())
      let result := delegatecall(gas, target, 0, calldatasize(), 0, 0)
      returndatacopy(0, 0, returndatasize())
      switch result
      case 0 { revert(0, returndatasize()) }
      default { return(0, returndatasize()) }
    }
  }
}
pragma solidity ^0.5.4;

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      require(c >= a, "SafeMath: addition overflow");
      return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
      return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
      require(b <= a, errorMessage);
      uint256 c = a - b;
      return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
      if (a == 0) {
        return 0;
      }
      uint256 c = a * b;
      require(c / a == b, "SafeMath: multiplication overflow");
      return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
      return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
      require(b > 0, errorMessage);
      uint256 c = a / b;
      return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
      return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
      require(b != 0, errorMessage);
      return a % b;
    }
}
pragma solidity ^0.5.4;

import "./ERC20.sol";
import "./TokenDetails.sol";
import "./Ownable.sol";
import "./Pausable.sol";
import "./HasBlacklist.sol";
import "./MasterCopy.sol";

contract Token is MasterCopy, ERC20, TokenDetails, Ownable, Pausable, HasBlacklist{

  function setup(address __owner)
  external {
    require(owner() == address(0), "ALREADY_INITIALIZED");
    _transferOwnership(__owner);
    detail("Visible", "VSB", 18);
    _mint(owner(), 100000000000000000000000000);
  }

  function mint(uint256 value)
  external onlyOwner whenNotPaused {
    _mint(owner(), value);
  }

  function burn(uint256 value)
  external whenNotPaused {
    _burn(msg.sender, value);
  }

  function pause()
  external onlyOwner whenNotPaused {
    _pause();
  }

  function unpause()
  external onlyOwner whenPaused {
    _unpause();
  }

  function addToBlacklist(address addr)
  external onlyOwner {
    _addToBlacklist(addr);
  }

  function removeFromBlacklist(address addr)
  external onlyOwner {
    _removeFromBlacklist(addr);
  }

  function transfer(address to, uint256 value)
  public whenNotPaused
  returns (bool) {
    require(!isBlacklisted(msg.sender), "BLACKLISTED");
    return super.transfer(to, value);
  }

  function transferFrom(address from, address to, uint256 value)
  public whenNotPaused
  returns (bool) {
    require(!isBlacklisted(from), "BLACKLISTED");
    return super.transferFrom(from, to, value);
  }

  function approve(address spender, uint256 value)
  public whenNotPaused
  returns (bool) {
    require(!isBlacklisted(msg.sender), "BLACKLISTED");
    return super.approve(spender, value);
  }

  function upgrade(address _newImplementation)
  external onlyOwner{
    _changeMasterCopy(_newImplementation);
  }
}
pragma solidity ^0.5.4;

contract TokenDetails{

  string private _name;
  string private _symbol;
  uint8 private _decimals;

  function detail(string memory name, string memory symbol, uint8 decimals)
  internal {
    _name = name;
    _symbol = symbol;
    _decimals = decimals;
  }

  function name()
  public view
  returns (string memory) {
    return _name;
  }

  function symbol()
  public view
  returns (string memory) {
    return _symbol;
  }

  function decimals()
  public view
  returns (uint8) {
    return _decimals;
  }
}
