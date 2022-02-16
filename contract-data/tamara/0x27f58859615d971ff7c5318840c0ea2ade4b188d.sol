/**
 * Source Code first verified at https://etherscan.io on Wednesday, March 13, 2019
 (UTC) */

pragma solidity 0.5.7;

contract ERC20 {
  function totalSupply()public view returns (uint256 total_Supply);
  function balanceOf(address who)public view returns (uint256);
  function transfer(address to, uint256 value)public returns (bool success);
  function transferFrom(address from, address to, uint256 value)public returns (bool success);
  function approve(address spender, uint256 value)public returns (bool success);
  function allowance(address owner, address spender)public view returns (uint256 remaining);
  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

pragma solidity ^0.5.0;

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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
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
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
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
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
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
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

pragma solidity 0.5.7;

import "./ERC20.sol";
import "./SafeMath.sol";


contract UzNEX is ERC20 {
    using SafeMath for uint256;
    //--- Token configurations ----//
    string private constant _name = "UzNEX Coin";
    string private constant _symbol = "UNB";
    uint8 private constant _decimals = 18;

    uint256 private _totalsupply = 8000000000 * (10 ** uint256(_decimals));
    address private _owner;


    struct Lock {
        uint256 time;
        uint256 amount;
    }

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowed;
    mapping (address => Lock) private locks;


    event Burn(address indexed from, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == _owner, "Only owner is allowed");
        _;
    }

    constructor() public
    {
        balances[msg.sender] = _totalsupply;
        _owner = msg.sender;

    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }


    function owner() public view returns (address) {
        return _owner;
    }

    function lockStatus(address _of) public view returns (uint256,uint256,uint256) {
        return (block.timestamp, locks[_of].time, locks[_of].amount);
    }

    function totalSupply() public view returns (uint256) {
        return _totalsupply;
    }

    function balanceOf(address _of) public view returns (uint256) {
        return balances[_of];
    }

    function lockToken(address _of, uint256 _amount, uint256 _time) public onlyOwner  {
        locks[_of].time = _time;
        locks[_of].amount = _amount;
    }

    function unlockToken(address _of) public onlyOwner  {
        locks[_of].time = block.timestamp;
        locks[_of].amount = 0;
    }


    function approve(address _spender, uint256 _amount) public  returns (bool)  {
        require(_spender != address(0), "Address can not be 0x0");
        require(balances[msg.sender] >= _amount, "Balance does not have enough tokens");
        require(balances[msg.sender] - locks[msg.sender].amount >= _amount || block.timestamp >= locks[msg.sender].time,"Sender address is locked");
        allowed[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    function allowance(address _from, address _spender) public view returns (uint256) {
        return allowed[_from][_spender];
    }

    function transfer(address _to, uint256 _amount) public  returns (bool) {
        require(_to != address(0), "Receiver can not be 0x0");
        require(balances[msg.sender] >= _amount, "Balance does not have enough tokens");
        require(balances[msg.sender] - locks[msg.sender].amount >= _amount || block.timestamp >= locks[msg.sender].time,"Sender address is locked");
        balances[msg.sender] = (balances[msg.sender]).sub(_amount);
        balances[_to] = (balances[_to]).add(_amount);
        emit Transfer(msg.sender, _to, _amount);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount ) public  returns (bool)  {
        require(_to != address(0), "Receiver can not be 0x0");
        require(balances[_from] >= _amount, "Source's balance is not enough");
        require(allowed[_from][msg.sender] >= _amount, "Allowance is not enough");
        require(balances[_from] - locks[_from].amount >= _amount || block.timestamp >= locks[_from].time,"Sender address is locked");
        balances[_from] = (balances[_from]).sub(_amount);
        allowed[_from][msg.sender] = (allowed[_from][msg.sender]).sub(_amount);
        balances[_to] = (balances[_to]).add(_amount);
        emit Transfer(_from, _to, _amount);
        return true;
    }

    function burn(uint256 _value) public onlyOwner returns (bool) {
        require(balances[msg.sender] >= _value,"Balance does not have enough tokens");
        balances[msg.sender] = (balances[msg.sender]).sub(_value);
        _totalsupply = _totalsupply.sub(_value);
        emit Burn(msg.sender, _value);
        return true;
    }
}

/**
 * Source Code first verified at https://etherscan.io on Wednesday, March 13, 2019
 (UTC) */

pragma solidity 0.5.7;

contract ERC20 {
  function totalSupply()public view returns (uint256 total_Supply);
  function balanceOf(address who)public view returns (uint256);
  function transfer(address to, uint256 value)public returns (bool success);
  function transferFrom(address from, address to, uint256 value)public returns (bool success);
  function approve(address spender, uint256 value)public returns (bool success);
  function allowance(address owner, address spender)public view returns (uint256 remaining);
  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

pragma solidity ^0.5.0;

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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
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
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
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
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
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
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

pragma solidity 0.5.7;

import "./ERC20.sol";
import "./SafeMath.sol";


contract UzNEX is ERC20 {
    using SafeMath for uint256;
    //--- Token configurations ----//
    string private constant _name = "UzNEX Coin";
    string private constant _symbol = "UNB";
    uint8 private constant _decimals = 18;

    uint256 private _totalsupply = 8000000000 * (10 ** uint256(_decimals));
    address private _owner;


    struct Lock {
        uint256 time;
        uint256 amount;
    }

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowed;
    mapping (address => Lock) private locks;


    event Burn(address indexed from, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == _owner, "Only owner is allowed");
        _;
    }

    constructor() public
    {
        balances[msg.sender] = _totalsupply;
        _owner = msg.sender;

    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }


    function owner() public view returns (address) {
        return _owner;
    }

    function lockStatus(address _of) public view returns (uint256,uint256,uint256) {
        return (block.timestamp, locks[_of].time, locks[_of].amount);
    }

    function totalSupply() public view returns (uint256) {
        return _totalsupply;
    }

    function balanceOf(address _of) public view returns (uint256) {
        return balances[_of];
    }

    function lockToken(address _of, uint256 _amount, uint256 _time) public onlyOwner  {
        locks[_of].time = _time;
        locks[_of].amount = _amount;
    }

    function unlockToken(address _of) public onlyOwner  {
        locks[_of].time = block.timestamp;
        locks[_of].amount = 0;
    }


    function approve(address _spender, uint256 _amount) public  returns (bool)  {
        require(_spender != address(0), "Address can not be 0x0");
        require(balances[msg.sender] >= _amount, "Balance does not have enough tokens");
        require(balances[msg.sender] - locks[msg.sender].amount >= _amount || block.timestamp >= locks[msg.sender].time,"Sender address is locked");
        allowed[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    function allowance(address _from, address _spender) public view returns (uint256) {
        return allowed[_from][_spender];
    }

    function transfer(address _to, uint256 _amount) public  returns (bool) {
        require(_to != address(0), "Receiver can not be 0x0");
        require(balances[msg.sender] >= _amount, "Balance does not have enough tokens");
        require(balances[msg.sender] - locks[msg.sender].amount >= _amount || block.timestamp >= locks[msg.sender].time,"Sender address is locked");
        balances[msg.sender] = (balances[msg.sender]).sub(_amount);
        balances[_to] = (balances[_to]).add(_amount);
        emit Transfer(msg.sender, _to, _amount);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount ) public  returns (bool)  {
        require(_to != address(0), "Receiver can not be 0x0");
        require(balances[_from] >= _amount, "Source's balance is not enough");
        require(allowed[_from][msg.sender] >= _amount, "Allowance is not enough");
        require(balances[_from] - locks[_from].amount >= _amount || block.timestamp >= locks[_from].time,"Sender address is locked");
        balances[_from] = (balances[_from]).sub(_amount);
        allowed[_from][msg.sender] = (allowed[_from][msg.sender]).sub(_amount);
        balances[_to] = (balances[_to]).add(_amount);
        emit Transfer(_from, _to, _amount);
        return true;
    }

    function burn(uint256 _value) public onlyOwner returns (bool) {
        require(balances[msg.sender] >= _value,"Balance does not have enough tokens");
        balances[msg.sender] = (balances[msg.sender]).sub(_value);
        _totalsupply = _totalsupply.sub(_value);
        emit Burn(msg.sender, _value);
        return true;
    }
}

/**
 * Source Code first verified at https://etherscan.io on Wednesday, March 13, 2019
 (UTC) */

pragma solidity 0.5.7;

contract ERC20 {
  function totalSupply()public view returns (uint256 total_Supply);
  function balanceOf(address who)public view returns (uint256);
  function transfer(address to, uint256 value)public returns (bool success);
  function transferFrom(address from, address to, uint256 value)public returns (bool success);
  function approve(address spender, uint256 value)public returns (bool success);
  function allowance(address owner, address spender)public view returns (uint256 remaining);
  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

pragma solidity ^0.5.0;

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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
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
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
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
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
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
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

pragma solidity 0.5.7;

import "./ERC20.sol";
import "./SafeMath.sol";


contract UzNEX is ERC20 {
    using SafeMath for uint256;
    //--- Token configurations ----//
    string private constant _name = "UzNEX Coin";
    string private constant _symbol = "UNB";
    uint8 private constant _decimals = 18;

    uint256 private _totalsupply = 8000000000 * (10 ** uint256(_decimals));
    address private _owner;


    struct Lock {
        uint256 time;
        uint256 amount;
    }

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowed;
    mapping (address => Lock) private locks;


    event Burn(address indexed from, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == _owner, "Only owner is allowed");
        _;
    }

    constructor() public
    {
        balances[msg.sender] = _totalsupply;
        _owner = msg.sender;

    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }


    function owner() public view returns (address) {
        return _owner;
    }

    function lockStatus(address _of) public view returns (uint256,uint256,uint256) {
        return (block.timestamp, locks[_of].time, locks[_of].amount);
    }

    function totalSupply() public view returns (uint256) {
        return _totalsupply;
    }

    function balanceOf(address _of) public view returns (uint256) {
        return balances[_of];
    }

    function lockToken(address _of, uint256 _amount, uint256 _time) public onlyOwner  {
        locks[_of].time = _time;
        locks[_of].amount = _amount;
    }

    function unlockToken(address _of) public onlyOwner  {
        locks[_of].time = block.timestamp;
        locks[_of].amount = 0;
    }


    function approve(address _spender, uint256 _amount) public  returns (bool)  {
        require(_spender != address(0), "Address can not be 0x0");
        require(balances[msg.sender] >= _amount, "Balance does not have enough tokens");
        require(balances[msg.sender] - locks[msg.sender].amount >= _amount || block.timestamp >= locks[msg.sender].time,"Sender address is locked");
        allowed[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    function allowance(address _from, address _spender) public view returns (uint256) {
        return allowed[_from][_spender];
    }

    function transfer(address _to, uint256 _amount) public  returns (bool) {
        require(_to != address(0), "Receiver can not be 0x0");
        require(balances[msg.sender] >= _amount, "Balance does not have enough tokens");
        require(balances[msg.sender] - locks[msg.sender].amount >= _amount || block.timestamp >= locks[msg.sender].time,"Sender address is locked");
        balances[msg.sender] = (balances[msg.sender]).sub(_amount);
        balances[_to] = (balances[_to]).add(_amount);
        emit Transfer(msg.sender, _to, _amount);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount ) public  returns (bool)  {
        require(_to != address(0), "Receiver can not be 0x0");
        require(balances[_from] >= _amount, "Source's balance is not enough");
        require(allowed[_from][msg.sender] >= _amount, "Allowance is not enough");
        require(balances[_from] - locks[_from].amount >= _amount || block.timestamp >= locks[_from].time,"Sender address is locked");
        balances[_from] = (balances[_from]).sub(_amount);
        allowed[_from][msg.sender] = (allowed[_from][msg.sender]).sub(_amount);
        balances[_to] = (balances[_to]).add(_amount);
        emit Transfer(_from, _to, _amount);
        return true;
    }

    function burn(uint256 _value) public onlyOwner returns (bool) {
        require(balances[msg.sender] >= _value,"Balance does not have enough tokens");
        balances[msg.sender] = (balances[msg.sender]).sub(_value);
        _totalsupply = _totalsupply.sub(_value);
        emit Burn(msg.sender, _value);
        return true;
    }
}

