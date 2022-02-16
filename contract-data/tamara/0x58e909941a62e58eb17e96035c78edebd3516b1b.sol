pragma solidity 0.4.26;


contract ERC20Interface {

    /// @return total amount of tokens
    function totalSupply() public view returns (uint);

    /// @tokenOwner The address from which the balance will be retrieved
    /// @return The balance
    function balanceOf(address tokenOwner) public view returns (uint balance);

    /// @param tokenOwner The address of the account owning tokens
    /// @param spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens allowed to spent
    function allowance(address tokenOwner, address spender) public view returns (uint remaining);

    /// @notice send `tokens` token to `to` from `msg.sender`
    /// @param to The address of the recipient
    /// @param tokens The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address to, uint tokens) public returns (bool success);

    /// @notice send `tokens` token to `to` from `from` on the condition it is approved by `from`
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param tokens The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    /// @notice `msg.sender` approves `spender` to spend `tokens` tokens
    /// @param spender The address of the account able to transfer the tokens
    /// @param tokens The amount of wei to be approved for transfer
    /// @return Whether the approval was successful or not
    function approve(address spender, uint tokens) public returns (bool success);

    function mint(uint256 value) public returns (bool);
    function mintToWallet(address to, uint256 tokens) public returns (bool);
    function burn(uint256 value) public returns (bool);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

}

pragma solidity 0.4.26;


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public{
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

pragma solidity 0.4.26;
/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 * Credits go to OpenZeppelin: https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/math/SafeMath.sol
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

pragma solidity 0.4.26;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
/**
 * SolarStake Token
 */


contract SlrsToken is ERC20Interface, Ownable {

    using SafeMath for uint256;
    uint256  public  totalSupply;
    address public itoContract;

    mapping  (address => uint256)             public          _balances;
    mapping  (address => mapping (address => uint256)) public  _approvals;


    string   public  name = "SolarStake Token";
    string   public  symbol = "SLRS";
    uint256  public  decimals = 18;

    event Mint(uint256 tokens);
    event MintToWallet(address indexed to, uint256 tokens);
    event MintFromContract(address indexed to, uint256 tokens);
    event Burn(uint256 tokens);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);


    constructor () public{
    }

    function totalSupply() public view returns (uint256) {
        return totalSupply;
    }
    function balanceOf(address tokenOwner) public view returns (uint256) {
        return _balances[tokenOwner];
    }
    function allowance(address tokenOwner, address spender) public view returns (uint256) {
        return _approvals[tokenOwner][spender];
    }

    function transfer(address to, uint256 tokens) public returns (bool) {
        require(to != address(0));
        require(tokens > 0 && _balances[msg.sender] >= tokens);
        _balances[msg.sender] = _balances[msg.sender].sub(tokens);
        _balances[to] = _balances[to].add(tokens);
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint256 tokens) public returns (bool) {
        require(from != address(0));
        require(to != address(0));
        require(tokens > 0 && _balances[from] >= tokens && _approvals[from][msg.sender] >= tokens);
        _approvals[from][msg.sender] = _approvals[from][msg.sender].sub(tokens);
        _balances[from] = _balances[from].sub(tokens);
        _balances[to] = _balances[to].add(tokens);
        emit Transfer(from, to, tokens);
        return true;
    }

    function approve(address spender, uint256 tokens) public returns (bool) {
        require(spender != address(0));
        require(tokens > 0 && tokens <= _balances[msg.sender]);
        _approvals[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    // mint tokens to owner wallet
    function mint(uint256 tokens) public onlyOwner returns (bool) {
        require(tokens > 0);
        _balances[msg.sender] = _balances[msg.sender].add(tokens);
        totalSupply = totalSupply.add(tokens);
        emit Mint(tokens);
        return true;
    }

    // Minting to wallets directly
    function mintToWallet(address to, uint256 tokens) public onlyOwner returns (bool) {
      totalSupply = totalSupply.add(tokens);
      _balances[to] = _balances[to].add(tokens);
      emit MintToWallet(to, tokens);
      return true;
    }

    // Minting to wallets from ITOContract
    function mintFromContract(address to, uint256 tokens) public returns (bool) {
      require(msg.sender == itoContract);
      totalSupply = totalSupply.add(tokens);
      _balances[to] = _balances[to].add(tokens);
      emit MintFromContract(to, tokens);
      return true;
    }

    // burning tokens from owner wallet
    function burn(uint256 tokens) public onlyOwner returns (bool)  {
        require(tokens > 0 && tokens <= _balances[msg.sender]);
        _balances[msg.sender] = _balances[msg.sender].sub(tokens);
        totalSupply = totalSupply.sub(tokens);
        emit Burn(tokens);
        return true;
    }

    // Owner can transfer out any accidentally sent ERC20 tokens
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }

    // Set address of ITOContract to allow minting from ITOContract
    function setItoContract(address _itoContract) public onlyOwner {
      if (_itoContract != address(0)) {
        itoContract = _itoContract;
      }
    }

}

pragma solidity 0.4.26;


contract ERC20Interface {

    /// @return total amount of tokens
    function totalSupply() public view returns (uint);

    /// @tokenOwner The address from which the balance will be retrieved
    /// @return The balance
    function balanceOf(address tokenOwner) public view returns (uint balance);

    /// @param tokenOwner The address of the account owning tokens
    /// @param spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens allowed to spent
    function allowance(address tokenOwner, address spender) public view returns (uint remaining);

    /// @notice send `tokens` token to `to` from `msg.sender`
    /// @param to The address of the recipient
    /// @param tokens The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address to, uint tokens) public returns (bool success);

    /// @notice send `tokens` token to `to` from `from` on the condition it is approved by `from`
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param tokens The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    /// @notice `msg.sender` approves `spender` to spend `tokens` tokens
    /// @param spender The address of the account able to transfer the tokens
    /// @param tokens The amount of wei to be approved for transfer
    /// @return Whether the approval was successful or not
    function approve(address spender, uint tokens) public returns (bool success);

    function mint(uint256 value) public returns (bool);
    function mintToWallet(address to, uint256 tokens) public returns (bool);
    function burn(uint256 value) public returns (bool);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

}

pragma solidity 0.4.26;


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public{
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

pragma solidity 0.4.26;
/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 * Credits go to OpenZeppelin: https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/math/SafeMath.sol
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

pragma solidity 0.4.26;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
/**
 * SolarStake Token
 */


contract SlrsToken is ERC20Interface, Ownable {

    using SafeMath for uint256;
    uint256  public  totalSupply;
    address public itoContract;

    mapping  (address => uint256)             public          _balances;
    mapping  (address => mapping (address => uint256)) public  _approvals;


    string   public  name = "SolarStake Token";
    string   public  symbol = "SLRS";
    uint256  public  decimals = 18;

    event Mint(uint256 tokens);
    event MintToWallet(address indexed to, uint256 tokens);
    event MintFromContract(address indexed to, uint256 tokens);
    event Burn(uint256 tokens);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);


    constructor () public{
    }

    function totalSupply() public view returns (uint256) {
        return totalSupply;
    }
    function balanceOf(address tokenOwner) public view returns (uint256) {
        return _balances[tokenOwner];
    }
    function allowance(address tokenOwner, address spender) public view returns (uint256) {
        return _approvals[tokenOwner][spender];
    }

    function transfer(address to, uint256 tokens) public returns (bool) {
        require(to != address(0));
        require(tokens > 0 && _balances[msg.sender] >= tokens);
        _balances[msg.sender] = _balances[msg.sender].sub(tokens);
        _balances[to] = _balances[to].add(tokens);
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint256 tokens) public returns (bool) {
        require(from != address(0));
        require(to != address(0));
        require(tokens > 0 && _balances[from] >= tokens && _approvals[from][msg.sender] >= tokens);
        _approvals[from][msg.sender] = _approvals[from][msg.sender].sub(tokens);
        _balances[from] = _balances[from].sub(tokens);
        _balances[to] = _balances[to].add(tokens);
        emit Transfer(from, to, tokens);
        return true;
    }

    function approve(address spender, uint256 tokens) public returns (bool) {
        require(spender != address(0));
        require(tokens > 0 && tokens <= _balances[msg.sender]);
        _approvals[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    // mint tokens to owner wallet
    function mint(uint256 tokens) public onlyOwner returns (bool) {
        require(tokens > 0);
        _balances[msg.sender] = _balances[msg.sender].add(tokens);
        totalSupply = totalSupply.add(tokens);
        emit Mint(tokens);
        return true;
    }

    // Minting to wallets directly
    function mintToWallet(address to, uint256 tokens) public onlyOwner returns (bool) {
      totalSupply = totalSupply.add(tokens);
      _balances[to] = _balances[to].add(tokens);
      emit MintToWallet(to, tokens);
      return true;
    }

    // Minting to wallets from ITOContract
    function mintFromContract(address to, uint256 tokens) public returns (bool) {
      require(msg.sender == itoContract);
      totalSupply = totalSupply.add(tokens);
      _balances[to] = _balances[to].add(tokens);
      emit MintFromContract(to, tokens);
      return true;
    }

    // burning tokens from owner wallet
    function burn(uint256 tokens) public onlyOwner returns (bool)  {
        require(tokens > 0 && tokens <= _balances[msg.sender]);
        _balances[msg.sender] = _balances[msg.sender].sub(tokens);
        totalSupply = totalSupply.sub(tokens);
        emit Burn(tokens);
        return true;
    }

    // Owner can transfer out any accidentally sent ERC20 tokens
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }

    // Set address of ITOContract to allow minting from ITOContract
    function setItoContract(address _itoContract) public onlyOwner {
      if (_itoContract != address(0)) {
        itoContract = _itoContract;
      }
    }

}

pragma solidity 0.4.26;


contract ERC20Interface {

    /// @return total amount of tokens
    function totalSupply() public view returns (uint);

    /// @tokenOwner The address from which the balance will be retrieved
    /// @return The balance
    function balanceOf(address tokenOwner) public view returns (uint balance);

    /// @param tokenOwner The address of the account owning tokens
    /// @param spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens allowed to spent
    function allowance(address tokenOwner, address spender) public view returns (uint remaining);

    /// @notice send `tokens` token to `to` from `msg.sender`
    /// @param to The address of the recipient
    /// @param tokens The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address to, uint tokens) public returns (bool success);

    /// @notice send `tokens` token to `to` from `from` on the condition it is approved by `from`
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param tokens The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    /// @notice `msg.sender` approves `spender` to spend `tokens` tokens
    /// @param spender The address of the account able to transfer the tokens
    /// @param tokens The amount of wei to be approved for transfer
    /// @return Whether the approval was successful or not
    function approve(address spender, uint tokens) public returns (bool success);

    function mint(uint256 value) public returns (bool);
    function mintToWallet(address to, uint256 tokens) public returns (bool);
    function burn(uint256 value) public returns (bool);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

}

pragma solidity 0.4.26;


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public{
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

pragma solidity 0.4.26;
/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 * Credits go to OpenZeppelin: https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/math/SafeMath.sol
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

pragma solidity 0.4.26;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
/**
 * SolarStake Token
 */


contract SlrsToken is ERC20Interface, Ownable {

    using SafeMath for uint256;
    uint256  public  totalSupply;
    address public itoContract;

    mapping  (address => uint256)             public          _balances;
    mapping  (address => mapping (address => uint256)) public  _approvals;


    string   public  name = "SolarStake Token";
    string   public  symbol = "SLRS";
    uint256  public  decimals = 18;

    event Mint(uint256 tokens);
    event MintToWallet(address indexed to, uint256 tokens);
    event MintFromContract(address indexed to, uint256 tokens);
    event Burn(uint256 tokens);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);


    constructor () public{
    }

    function totalSupply() public view returns (uint256) {
        return totalSupply;
    }
    function balanceOf(address tokenOwner) public view returns (uint256) {
        return _balances[tokenOwner];
    }
    function allowance(address tokenOwner, address spender) public view returns (uint256) {
        return _approvals[tokenOwner][spender];
    }

    function transfer(address to, uint256 tokens) public returns (bool) {
        require(to != address(0));
        require(tokens > 0 && _balances[msg.sender] >= tokens);
        _balances[msg.sender] = _balances[msg.sender].sub(tokens);
        _balances[to] = _balances[to].add(tokens);
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint256 tokens) public returns (bool) {
        require(from != address(0));
        require(to != address(0));
        require(tokens > 0 && _balances[from] >= tokens && _approvals[from][msg.sender] >= tokens);
        _approvals[from][msg.sender] = _approvals[from][msg.sender].sub(tokens);
        _balances[from] = _balances[from].sub(tokens);
        _balances[to] = _balances[to].add(tokens);
        emit Transfer(from, to, tokens);
        return true;
    }

    function approve(address spender, uint256 tokens) public returns (bool) {
        require(spender != address(0));
        require(tokens > 0 && tokens <= _balances[msg.sender]);
        _approvals[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    // mint tokens to owner wallet
    function mint(uint256 tokens) public onlyOwner returns (bool) {
        require(tokens > 0);
        _balances[msg.sender] = _balances[msg.sender].add(tokens);
        totalSupply = totalSupply.add(tokens);
        emit Mint(tokens);
        return true;
    }

    // Minting to wallets directly
    function mintToWallet(address to, uint256 tokens) public onlyOwner returns (bool) {
      totalSupply = totalSupply.add(tokens);
      _balances[to] = _balances[to].add(tokens);
      emit MintToWallet(to, tokens);
      return true;
    }

    // Minting to wallets from ITOContract
    function mintFromContract(address to, uint256 tokens) public returns (bool) {
      require(msg.sender == itoContract);
      totalSupply = totalSupply.add(tokens);
      _balances[to] = _balances[to].add(tokens);
      emit MintFromContract(to, tokens);
      return true;
    }

    // burning tokens from owner wallet
    function burn(uint256 tokens) public onlyOwner returns (bool)  {
        require(tokens > 0 && tokens <= _balances[msg.sender]);
        _balances[msg.sender] = _balances[msg.sender].sub(tokens);
        totalSupply = totalSupply.sub(tokens);
        emit Burn(tokens);
        return true;
    }

    // Owner can transfer out any accidentally sent ERC20 tokens
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }

    // Set address of ITOContract to allow minting from ITOContract
    function setItoContract(address _itoContract) public onlyOwner {
      if (_itoContract != address(0)) {
        itoContract = _itoContract;
      }
    }

}

