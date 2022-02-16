pragma solidity ^0.5.3;

/**
 * Utility library of inline functions on addresses
 */
library Address {
    /**
     * Returns whether the target address is a contract
     * @dev This function will return false if invoked during the constructor of a contract,
     * as the code is not actually created until after the constructor finishes.
     * @param account address of the account to check
     * @return whether the target address is a contract
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // XXX Currently there is no better way to check if there is a contract in an address
        // than to check the size of the code at that address.
        // See https://ethereum.stackexchange.com/a/14016/36603
        // for more details about how this works.
        // TODO Check this again before the Serenity release, because all addresses will be
        // contracts then.
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

pragma solidity ^0.5.3;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
 */
interface IERC20Token {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
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

pragma solidity ^0.5.3;

contract Owned {
    address public owner;

    modifier onlyOwner {
        require(msg.sender == owner, "Only owner can perform transaction.");
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    function changeOwner(address _newOwner) public onlyOwner returns (bool success) {
        owner = _newOwner;
        return true;
    }
}

pragma solidity ^0.5.3;

import { Owned } from "./Ownable.sol";

contract Pausable is Owned{
    bool public isPaused;
    
    event Pause(address _owner, uint _timestamp);
    event Unpause(address _owner, uint _timestamp);
    
    modifier whenPaused {
        require(isPaused);
        _;
    }
    
    modifier whenNotPaused {
        require(!isPaused);
        _;
    }
    
    function pause() public onlyOwner whenNotPaused {
        isPaused = true;
        emit Pause(msg.sender, now);
    }
    
    function unpause() public onlyOwner whenPaused {
        isPaused = false;
        emit Unpause(msg.sender, now);
    }
}

pragma solidity ^0.5.3;

/**
 * @title SafeMath
 * @dev Unsigned math operations with safety checks that revert on error
 */
library SafeMath {
    /**
     * @dev Multiplies two unsigned integers, reverts on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
     * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Adds two unsigned integers, reverts on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
     * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
     * reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

pragma solidity ^0.5.3;

// ----------------------------------------------------------------------------
// 'CRYPTOBUCKS' Token Contract
//
// Deployed To : 0x4d9ee34b7ee0d3cef04e5909c27a266e7eb14712
// Symbol      : CBUCKS
// Name        : CRYPTOBUCKS
// Total Supply: 10,000,000,000 CBUCKS
// Decimals    : 2
//
// (c) By 'ANONYMOUS' With 'CBUCKS' Symbol 2019.
//
// ----------------------------------------------------------------------------

// Interfaces
import { IERC20Token } from "./iERC20Token.sol";
// Libraries
import { SafeMath } from "./SafeMath.sol";
import { Whitelist } from "./Whitelist.sol";
import { Address } from "./Address.sol";
// Inherited Contracts
import { Pausable } from "./Pausable.sol";

contract Token is IERC20Token, Whitelist, Pausable {
  using SafeMath for uint256;
  using Address for address;

  string _name;
  string _symbol;
  uint256 _totalSupply;
  uint256 _decimals;
  uint256 _totalBurned;

  constructor () public {
    _name = "CRYPTOBUCKS";
    _symbol = "CBUCKS";
    _totalSupply = 1000000000000;
    _decimals = 2;
    _totalBurned = 0;
    balances[0xE43eBCb96564a6FB3B7A4AbbfD7008b415591b09] = _totalSupply;
    emit Transfer(address(this), 0xE43eBCb96564a6FB3B7A4AbbfD7008b415591b09, _totalSupply);
  }

  mapping(address => uint256) private balances;
  mapping(address => mapping(address => uint256)) private allowed;
  mapping(address => bool) private burners;

  event Burned(address indexed from, uint256 value, uint256 timestamp);
  event AssignedBurner(address indexed from, address indexed burner, uint256 timestamp);

  function name() external view returns (string memory) {
    return _name;
  }

  function symbol() external view returns (string memory) {
    return _symbol;
  }

  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  function decimals() external view returns (uint256) {
    return _decimals;
  }

  function balanceOf(address account) external view returns (uint256) {
    return balances[account];
  }

  function allowance(address owner, address spender) external view returns (uint256) {
    return allowed[owner][spender];
  }

  function transfer(
    address recipient,
    uint256 amount
    ) external whenNotPaused onlyWhitelisted(msg.sender, recipient) validRecipient(recipient)
    validAmount(amount) validAddress(recipient) returns (bool) {
      balances[msg.sender] = balances[msg.sender].sub(amount);
      balances[recipient] = balances[recipient].add(amount);
      emit Transfer(msg.sender, recipient, amount);
  }

  function approve(
    address spender,
    uint256 amount
    ) external whenNotPaused validAddress(spender) validRecipient(spender)
    validAmount(amount) returns (bool) {
    allowed[msg.sender][spender] = allowed[msg.sender][spender].add(amount);
    emit Approval(msg.sender, spender, amount);
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
    ) external whenNotPaused validAddress(recipient) validRecipient(recipient)
    validAmount(amount) returns (bool) {
      require(allowed[sender][msg.sender] >= amount, "Above spender allowance.");
      allowed[sender][msg.sender] = allowed[sender][msg.sender].sub(amount);
      balances[recipient] = balances[recipient].add(amount);
      emit Transfer(sender, recipient, amount);
    }

  modifier validAddress(address _address) {
    require(_address != address(0), "Cannot send to address 0x0.");
    _;
  }

  modifier validAmount(uint256 _amount) {
    require(_amount > 0, "Amount must be greater than 0.");
    _;
  }

  modifier validRecipient(address _address) {
    require(msg.sender != _address, "Cannot send to yourself.");
    _;
  }

  // BURN FUNCTIONALITIES

  function totalBurned() external view returns (uint256) {
    return _totalBurned;
  }
  
  function addBurner(address _newBurner) external onlyOwner returns (bool) {
    require(burners[_newBurner] == false, "Address is already a burner.");
    burners[_newBurner] = true;
    emit AssignedBurner(msg.sender, _newBurner, now);
  }

  modifier onlyBurner() {
    require(burners[msg.sender] == true, "Sender is not a burner.");
    _;
  }

  function burn(
    uint256 _burnAmount
  ) external whenNotPaused onlyBurner returns (bool) {
      balances[msg.sender] = balances[msg.sender].sub(_burnAmount);
      _totalSupply = _totalSupply.sub(_burnAmount);
      _totalBurned = _totalBurned.add(_burnAmount);
      emit Burned(msg.sender, _burnAmount, now);
  }
}
pragma solidity ^0.5.3;

import { Owned } from "./Ownable.sol";

contract Whitelist is Owned{
    
    bool public whitelistToggle = false;
    
    mapping(address => bool) whitelistedAccounts;
    
    modifier onlyWhitelisted(address from, address to) {
        if(whitelistToggle){
            require(whitelistedAccounts[from], "Sender account is not whitelisted");
            require(whitelistedAccounts[to], "Receiver account is not whitelisted");
        }
        _;
    }
    
    event Whitelisted(address account);
    event UnWhitelisted(address account);
    
    event ToggleWhitelist(address sender, uint timestamp);
    event UntoggleWhitelist(address sender, uint timestamp);
    
    function addWhitelist(address account) public onlyOwner returns(bool) {
        whitelistedAccounts[account] = true;
        emit Whitelisted(account);
    }
        
    function removeWhitelist(address account) public onlyOwner returns(bool) {
        whitelistedAccounts[account] = false;
        emit UnWhitelisted(account);
    }
    
    function toggle() external onlyOwner {
        whitelistToggle = true;
        emit ToggleWhitelist(msg.sender, now);
    }
    
    function untoggle() external onlyOwner {
        whitelistToggle = false;
        emit UntoggleWhitelist(msg.sender, now);
    }
    
    function isWhiteListed(address account) public view returns(bool){
        return whitelistedAccounts[account];
    }
    
}

pragma solidity ^0.5.3;

/**
 * Utility library of inline functions on addresses
 */
library Address {
    /**
     * Returns whether the target address is a contract
     * @dev This function will return false if invoked during the constructor of a contract,
     * as the code is not actually created until after the constructor finishes.
     * @param account address of the account to check
     * @return whether the target address is a contract
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // XXX Currently there is no better way to check if there is a contract in an address
        // than to check the size of the code at that address.
        // See https://ethereum.stackexchange.com/a/14016/36603
        // for more details about how this works.
        // TODO Check this again before the Serenity release, because all addresses will be
        // contracts then.
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

pragma solidity ^0.5.3;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
 */
interface IERC20Token {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
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

pragma solidity ^0.5.3;

contract Owned {
    address public owner;

    modifier onlyOwner {
        require(msg.sender == owner, "Only owner can perform transaction.");
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    function changeOwner(address _newOwner) public onlyOwner returns (bool success) {
        owner = _newOwner;
        return true;
    }
}

pragma solidity ^0.5.3;

import { Owned } from "./Ownable.sol";

contract Pausable is Owned{
    bool public isPaused;
    
    event Pause(address _owner, uint _timestamp);
    event Unpause(address _owner, uint _timestamp);
    
    modifier whenPaused {
        require(isPaused);
        _;
    }
    
    modifier whenNotPaused {
        require(!isPaused);
        _;
    }
    
    function pause() public onlyOwner whenNotPaused {
        isPaused = true;
        emit Pause(msg.sender, now);
    }
    
    function unpause() public onlyOwner whenPaused {
        isPaused = false;
        emit Unpause(msg.sender, now);
    }
}

pragma solidity ^0.5.3;

/**
 * @title SafeMath
 * @dev Unsigned math operations with safety checks that revert on error
 */
library SafeMath {
    /**
     * @dev Multiplies two unsigned integers, reverts on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
     * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Adds two unsigned integers, reverts on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
     * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
     * reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

pragma solidity ^0.5.3;

// ----------------------------------------------------------------------------
// 'CRYPTOBUCKS' Token Contract
//
// Deployed To : 0x4d9ee34b7ee0d3cef04e5909c27a266e7eb14712
// Symbol      : CBUCKS
// Name        : CRYPTOBUCKS
// Total Supply: 10,000,000,000 CBUCKS
// Decimals    : 2
//
// (c) By 'ANONYMOUS' With 'CBUCKS' Symbol 2019.
//
// ----------------------------------------------------------------------------

// Interfaces
import { IERC20Token } from "./iERC20Token.sol";
// Libraries
import { SafeMath } from "./SafeMath.sol";
import { Whitelist } from "./Whitelist.sol";
import { Address } from "./Address.sol";
// Inherited Contracts
import { Pausable } from "./Pausable.sol";

contract Token is IERC20Token, Whitelist, Pausable {
  using SafeMath for uint256;
  using Address for address;

  string _name;
  string _symbol;
  uint256 _totalSupply;
  uint256 _decimals;
  uint256 _totalBurned;

  constructor () public {
    _name = "CRYPTOBUCKS";
    _symbol = "CBUCKS";
    _totalSupply = 1000000000000;
    _decimals = 2;
    _totalBurned = 0;
    balances[0xE43eBCb96564a6FB3B7A4AbbfD7008b415591b09] = _totalSupply;
    emit Transfer(address(this), 0xE43eBCb96564a6FB3B7A4AbbfD7008b415591b09, _totalSupply);
  }

  mapping(address => uint256) private balances;
  mapping(address => mapping(address => uint256)) private allowed;
  mapping(address => bool) private burners;

  event Burned(address indexed from, uint256 value, uint256 timestamp);
  event AssignedBurner(address indexed from, address indexed burner, uint256 timestamp);

  function name() external view returns (string memory) {
    return _name;
  }

  function symbol() external view returns (string memory) {
    return _symbol;
  }

  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  function decimals() external view returns (uint256) {
    return _decimals;
  }

  function balanceOf(address account) external view returns (uint256) {
    return balances[account];
  }

  function allowance(address owner, address spender) external view returns (uint256) {
    return allowed[owner][spender];
  }

  function transfer(
    address recipient,
    uint256 amount
    ) external whenNotPaused onlyWhitelisted(msg.sender, recipient) validRecipient(recipient)
    validAmount(amount) validAddress(recipient) returns (bool) {
      balances[msg.sender] = balances[msg.sender].sub(amount);
      balances[recipient] = balances[recipient].add(amount);
      emit Transfer(msg.sender, recipient, amount);
  }

  function approve(
    address spender,
    uint256 amount
    ) external whenNotPaused validAddress(spender) validRecipient(spender)
    validAmount(amount) returns (bool) {
    allowed[msg.sender][spender] = allowed[msg.sender][spender].add(amount);
    emit Approval(msg.sender, spender, amount);
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
    ) external whenNotPaused validAddress(recipient) validRecipient(recipient)
    validAmount(amount) returns (bool) {
      require(allowed[sender][msg.sender] >= amount, "Above spender allowance.");
      allowed[sender][msg.sender] = allowed[sender][msg.sender].sub(amount);
      balances[recipient] = balances[recipient].add(amount);
      emit Transfer(sender, recipient, amount);
    }

  modifier validAddress(address _address) {
    require(_address != address(0), "Cannot send to address 0x0.");
    _;
  }

  modifier validAmount(uint256 _amount) {
    require(_amount > 0, "Amount must be greater than 0.");
    _;
  }

  modifier validRecipient(address _address) {
    require(msg.sender != _address, "Cannot send to yourself.");
    _;
  }

  // BURN FUNCTIONALITIES

  function totalBurned() external view returns (uint256) {
    return _totalBurned;
  }
  
  function addBurner(address _newBurner) external onlyOwner returns (bool) {
    require(burners[_newBurner] == false, "Address is already a burner.");
    burners[_newBurner] = true;
    emit AssignedBurner(msg.sender, _newBurner, now);
  }

  modifier onlyBurner() {
    require(burners[msg.sender] == true, "Sender is not a burner.");
    _;
  }

  function burn(
    uint256 _burnAmount
  ) external whenNotPaused onlyBurner returns (bool) {
      balances[msg.sender] = balances[msg.sender].sub(_burnAmount);
      _totalSupply = _totalSupply.sub(_burnAmount);
      _totalBurned = _totalBurned.add(_burnAmount);
      emit Burned(msg.sender, _burnAmount, now);
  }
}
pragma solidity ^0.5.3;

import { Owned } from "./Ownable.sol";

contract Whitelist is Owned{
    
    bool public whitelistToggle = false;
    
    mapping(address => bool) whitelistedAccounts;
    
    modifier onlyWhitelisted(address from, address to) {
        if(whitelistToggle){
            require(whitelistedAccounts[from], "Sender account is not whitelisted");
            require(whitelistedAccounts[to], "Receiver account is not whitelisted");
        }
        _;
    }
    
    event Whitelisted(address account);
    event UnWhitelisted(address account);
    
    event ToggleWhitelist(address sender, uint timestamp);
    event UntoggleWhitelist(address sender, uint timestamp);
    
    function addWhitelist(address account) public onlyOwner returns(bool) {
        whitelistedAccounts[account] = true;
        emit Whitelisted(account);
    }
        
    function removeWhitelist(address account) public onlyOwner returns(bool) {
        whitelistedAccounts[account] = false;
        emit UnWhitelisted(account);
    }
    
    function toggle() external onlyOwner {
        whitelistToggle = true;
        emit ToggleWhitelist(msg.sender, now);
    }
    
    function untoggle() external onlyOwner {
        whitelistToggle = false;
        emit UntoggleWhitelist(msg.sender, now);
    }
    
    function isWhiteListed(address account) public view returns(bool){
        return whitelistedAccounts[account];
    }
    
}

pragma solidity ^0.5.3;

/**
 * Utility library of inline functions on addresses
 */
library Address {
    /**
     * Returns whether the target address is a contract
     * @dev This function will return false if invoked during the constructor of a contract,
     * as the code is not actually created until after the constructor finishes.
     * @param account address of the account to check
     * @return whether the target address is a contract
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // XXX Currently there is no better way to check if there is a contract in an address
        // than to check the size of the code at that address.
        // See https://ethereum.stackexchange.com/a/14016/36603
        // for more details about how this works.
        // TODO Check this again before the Serenity release, because all addresses will be
        // contracts then.
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

pragma solidity ^0.5.3;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
 */
interface IERC20Token {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
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

pragma solidity ^0.5.3;

contract Owned {
    address public owner;

    modifier onlyOwner {
        require(msg.sender == owner, "Only owner can perform transaction.");
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    function changeOwner(address _newOwner) public onlyOwner returns (bool success) {
        owner = _newOwner;
        return true;
    }
}

pragma solidity ^0.5.3;

import { Owned } from "./Ownable.sol";

contract Pausable is Owned{
    bool public isPaused;
    
    event Pause(address _owner, uint _timestamp);
    event Unpause(address _owner, uint _timestamp);
    
    modifier whenPaused {
        require(isPaused);
        _;
    }
    
    modifier whenNotPaused {
        require(!isPaused);
        _;
    }
    
    function pause() public onlyOwner whenNotPaused {
        isPaused = true;
        emit Pause(msg.sender, now);
    }
    
    function unpause() public onlyOwner whenPaused {
        isPaused = false;
        emit Unpause(msg.sender, now);
    }
}

pragma solidity ^0.5.3;

/**
 * @title SafeMath
 * @dev Unsigned math operations with safety checks that revert on error
 */
library SafeMath {
    /**
     * @dev Multiplies two unsigned integers, reverts on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
     * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Adds two unsigned integers, reverts on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
     * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
     * reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

pragma solidity ^0.5.3;

// ----------------------------------------------------------------------------
// 'CRYPTOBUCKS' Token Contract
//
// Deployed To : 0x4d9ee34b7ee0d3cef04e5909c27a266e7eb14712
// Symbol      : CBUCKS
// Name        : CRYPTOBUCKS
// Total Supply: 10,000,000,000 CBUCKS
// Decimals    : 2
//
// (c) By 'ANONYMOUS' With 'CBUCKS' Symbol 2019.
//
// ----------------------------------------------------------------------------

// Interfaces
import { IERC20Token } from "./iERC20Token.sol";
// Libraries
import { SafeMath } from "./SafeMath.sol";
import { Whitelist } from "./Whitelist.sol";
import { Address } from "./Address.sol";
// Inherited Contracts
import { Pausable } from "./Pausable.sol";

contract Token is IERC20Token, Whitelist, Pausable {
  using SafeMath for uint256;
  using Address for address;

  string _name;
  string _symbol;
  uint256 _totalSupply;
  uint256 _decimals;
  uint256 _totalBurned;

  constructor () public {
    _name = "CRYPTOBUCKS";
    _symbol = "CBUCKS";
    _totalSupply = 1000000000000;
    _decimals = 2;
    _totalBurned = 0;
    balances[0xE43eBCb96564a6FB3B7A4AbbfD7008b415591b09] = _totalSupply;
    emit Transfer(address(this), 0xE43eBCb96564a6FB3B7A4AbbfD7008b415591b09, _totalSupply);
  }

  mapping(address => uint256) private balances;
  mapping(address => mapping(address => uint256)) private allowed;
  mapping(address => bool) private burners;

  event Burned(address indexed from, uint256 value, uint256 timestamp);
  event AssignedBurner(address indexed from, address indexed burner, uint256 timestamp);

  function name() external view returns (string memory) {
    return _name;
  }

  function symbol() external view returns (string memory) {
    return _symbol;
  }

  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  function decimals() external view returns (uint256) {
    return _decimals;
  }

  function balanceOf(address account) external view returns (uint256) {
    return balances[account];
  }

  function allowance(address owner, address spender) external view returns (uint256) {
    return allowed[owner][spender];
  }

  function transfer(
    address recipient,
    uint256 amount
    ) external whenNotPaused onlyWhitelisted(msg.sender, recipient) validRecipient(recipient)
    validAmount(amount) validAddress(recipient) returns (bool) {
      balances[msg.sender] = balances[msg.sender].sub(amount);
      balances[recipient] = balances[recipient].add(amount);
      emit Transfer(msg.sender, recipient, amount);
  }

  function approve(
    address spender,
    uint256 amount
    ) external whenNotPaused validAddress(spender) validRecipient(spender)
    validAmount(amount) returns (bool) {
    allowed[msg.sender][spender] = allowed[msg.sender][spender].add(amount);
    emit Approval(msg.sender, spender, amount);
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
    ) external whenNotPaused validAddress(recipient) validRecipient(recipient)
    validAmount(amount) returns (bool) {
      require(allowed[sender][msg.sender] >= amount, "Above spender allowance.");
      allowed[sender][msg.sender] = allowed[sender][msg.sender].sub(amount);
      balances[recipient] = balances[recipient].add(amount);
      emit Transfer(sender, recipient, amount);
    }

  modifier validAddress(address _address) {
    require(_address != address(0), "Cannot send to address 0x0.");
    _;
  }

  modifier validAmount(uint256 _amount) {
    require(_amount > 0, "Amount must be greater than 0.");
    _;
  }

  modifier validRecipient(address _address) {
    require(msg.sender != _address, "Cannot send to yourself.");
    _;
  }

  // BURN FUNCTIONALITIES

  function totalBurned() external view returns (uint256) {
    return _totalBurned;
  }
  
  function addBurner(address _newBurner) external onlyOwner returns (bool) {
    require(burners[_newBurner] == false, "Address is already a burner.");
    burners[_newBurner] = true;
    emit AssignedBurner(msg.sender, _newBurner, now);
  }

  modifier onlyBurner() {
    require(burners[msg.sender] == true, "Sender is not a burner.");
    _;
  }

  function burn(
    uint256 _burnAmount
  ) external whenNotPaused onlyBurner returns (bool) {
      balances[msg.sender] = balances[msg.sender].sub(_burnAmount);
      _totalSupply = _totalSupply.sub(_burnAmount);
      _totalBurned = _totalBurned.add(_burnAmount);
      emit Burned(msg.sender, _burnAmount, now);
  }
}
pragma solidity ^0.5.3;

import { Owned } from "./Ownable.sol";

contract Whitelist is Owned{
    
    bool public whitelistToggle = false;
    
    mapping(address => bool) whitelistedAccounts;
    
    modifier onlyWhitelisted(address from, address to) {
        if(whitelistToggle){
            require(whitelistedAccounts[from], "Sender account is not whitelisted");
            require(whitelistedAccounts[to], "Receiver account is not whitelisted");
        }
        _;
    }
    
    event Whitelisted(address account);
    event UnWhitelisted(address account);
    
    event ToggleWhitelist(address sender, uint timestamp);
    event UntoggleWhitelist(address sender, uint timestamp);
    
    function addWhitelist(address account) public onlyOwner returns(bool) {
        whitelistedAccounts[account] = true;
        emit Whitelisted(account);
    }
        
    function removeWhitelist(address account) public onlyOwner returns(bool) {
        whitelistedAccounts[account] = false;
        emit UnWhitelisted(account);
    }
    
    function toggle() external onlyOwner {
        whitelistToggle = true;
        emit ToggleWhitelist(msg.sender, now);
    }
    
    function untoggle() external onlyOwner {
        whitelistToggle = false;
        emit UntoggleWhitelist(msg.sender, now);
    }
    
    function isWhiteListed(address account) public view returns(bool){
        return whitelistedAccounts[account];
    }
    
}

