pragma solidity ^0.5.8;

import "./erc20.sol";

/**
* @title Burnable Token
* @dev Token that can be irreversibly burned (destroyed).
*/
contract ERC20Burnable is ERC20 {
	/**
	* @dev Burns a specific amount of tokens.
	* @param value The amount of token to be burned.
	*/
	function burn(uint256 value) external {
		_burn(msg.sender, value);
	}

	/**
	* @dev Burns a specific amount of tokens from the target address and decrements allowance.
	* @param from address The account whose tokens will be burned.
	* @param value uint256 The amount of token to be burned.
	*/
	function burnFrom(address from, uint256 value) external {
		_burnFrom(from, value);
	}
}

pragma solidity ^0.5.8;

import "./safemath.sol";
import "./ierc20.sol";

/**
* @title Standard ERC20 token
** @dev Implementation of the basic standard token.
* https://eips.ethereum.org/EIPS/eip-20
* Originally based on code by FirstBlood:
* https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
** This implementation emits additional Approval events, allowing applications to reconstruct the allowance status for
* all accounts just by listening to said events. Note that this isn't required by the specification, and other
* compliant implementations may not do it.
*/
contract ERC20 is IERC20 {
	using SafeMath for uint256;

	mapping (address => uint256) internal _balances;

	mapping (address => mapping (address => uint256)) private _allowed;

	uint256 private _totalSupply;

	/**
	* @dev Total number of tokens in existence.
	*/
	function totalSupply() external view returns (uint256) {
		return _totalSupply;
	}

	/**
	* @dev Gets the balance of the specified address.
	* @param owner The address to query the balance of.
	* @return A uint256 representing the amount owned by the passed address.
	*/
	function balanceOf(address owner) external view returns (uint256) {
		return _balances[owner];
	}

	/**
	* @dev Function to check the amount of tokens that an owner allowed to a spender.
	* @param owner address The address which owns the funds.
	* @param spender address The address which will spend the funds.
	* @return A uint256 specifying the amount of tokens still available for the spender.
	*/
	function allowance(address owner, address spender) external view returns (uint256) {
		return _allowed[owner][spender];
	}

	/**
	* @dev Transfer token to a specified address.
	* @param to The address to transfer to.
	* @param value The amount to be transferred.
	*/
	function transfer(address to, uint256 value) external returns (bool) {
		_transfer(msg.sender, to, value);
		return true;
	}

	/**
	* @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
	* Beware that changing an allowance with this method brings the risk that someone may use both the old
	* and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
	* race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
	* https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
	* @param spender The address which will spend the funds.
	* @param value The amount of tokens to be spent.
	*/
	function approve(address spender, uint256 value) public returns (bool) {
		_approve(msg.sender, spender, value);
		return true;
	}

	/**
	* @dev Transfer tokens from one address to another.
	* Note that while this function emits an Approval event, this is not required as per the specification,
	* and other compliant implementations may not emit the event.
	* @param from address The address which you want to send tokens from
	* @param to address The address which you want to transfer to
	* @param value uint256 the amount of tokens to be transferred
	*/
	function transferFrom(address from, address to, uint256 value) external returns (bool) {
		_transfer(from, to, value);
		_approve(from, msg.sender, _allowed[from][msg.sender].sub(value));
		return true;
	}

	/**
	* @dev Increase the amount of tokens that an owner allowed to a spender.
	* approve should be called when _allowed[msg.sender][spender] == 0. To increment
	* allowed value is better to use this function to avoid 2 calls (and wait until
	* the first transaction is mined)
	* From MonolithDAO Token.sol
	* Emits an Approval event.
	* @param spender The address which will spend the funds.
	* @param addedValue The amount of tokens to increase the allowance by.
	*/
	function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
		_approve(msg.sender, spender, _allowed[msg.sender][spender].add(addedValue));
		return true;
	}

	/**
	* @dev Decrease the amount of tokens that an owner allowed to a spender.
	* approve should be called when _allowed[msg.sender][spender] == 0. To decrement
	* allowed value is better to use this function to avoid 2 calls (and wait until
	* the first transaction is mined)
	* From MonolithDAO Token.sol
	* Emits an Approval event.
	* @param spender The address which will spend the funds.
	* @param subtractedValue The amount of tokens to decrease the allowance by.
	*/
	function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
		_approve(msg.sender, spender, _allowed[msg.sender][spender].sub(subtractedValue));
		return true;
	}

	/**
	* @dev Transfer token for a specified addresses.
	* @param from The address to transfer from.
	* @param to The address to transfer to.
	* @param value The amount to be transferred.
	*/
	function _transfer(address from, address to, uint256 value) internal {
		require(to != address(0), "ERC20: transfer to the zero address");
        require(_balances[from]>=value, "ERC20 transfer: not enough tokens");
		_balances[from] = _balances[from].sub(value);
		_balances[to] = _balances[to].add(value);
		emit Transfer(from, to, value);
	}

	/**
	* @dev Internal function that mints an amount of the token and assigns it to
	* an account. This encapsulates the modification of balances such that the
	* proper events are emitted.
	* @param account The account that will receive the created tokens.
	* @param value The amount that will be created.
	*/
	function _mint(address account, uint256 value) internal {
		require(account != address(0), "ERC20: mint to the zero address");

		_totalSupply = _totalSupply.add(value);
		_balances[account] = _balances[account].add(value);
		emit Transfer(address(0), account, value);
	}

	/**
	* @dev Internal function that burns an amount of the token of a given
	* account.
	* @param account The account whose tokens will be burnt.
	* @param value The amount that will be burnt.
	*/
	function _burn(address account, uint256 value) internal {
		require(account != address(0), "ERC20: burn from the zero address");
		require(_balances[account] >= value, "Burn: not enough tokens");
		_totalSupply = _totalSupply.sub(value);
		_balances[account] = _balances[account].sub(value);
		emit Transfer(account, address(0), value);
	}

	/**
	* @dev Approve an address to spend another addresses' tokens.
	* @param owner The address that owns the tokens.
	* @param spender The address that will spend the tokens.
	* @param value The number of tokens that can be spent.
	*/
	function _approve(address owner, address spender, uint256 value) internal {
		require(owner != address(0), "ERC20: approve from the zero address");
		require(spender != address(0), "ERC20: approve to the zero address");
		_allowed[owner][spender] = value;
		emit Approval(owner, spender, value);
	}

	/**
	* @dev Internal function that burns an amount of the token of a given
	* account, deducting from the sender's allowance for said account. Uses the
	* internal burn function.
	* Emits an Approval event (reflecting the reduced allowance).
	* @param account The account whose tokens will be burnt.
	* @param value The amount that will be burnt.
	*/
	function _burnFrom(address account, uint256 value) internal {
		require(_allowed[account][msg.sender]>=value, "Burn: allowance too low");
		_burn(account, value);
		_approve(account, msg.sender, _allowed[account][msg.sender].sub(value));
	}
}

pragma solidity ^0.5.8;

/**
* @title ERC20 interface
* @dev see https://eips.ethereum.org/EIPS/eip-20
*/
interface IERC20 {
	function transfer(address to, uint256 value) external returns (bool);

	function approve(address spender, uint256 value) external returns (bool);

	function transferFrom(address from, address to, uint256 value) external returns (bool);

	function totalSupply() external view returns (uint256);

	function balanceOf(address who) external view returns (uint256);

	function allowance(address owner, address spender) external view returns (uint256);

	event Transfer(address indexed from, address indexed to, uint256 value);

	event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity ^0.5.8;

/**
* @title Ownable
* @dev The Ownable contract has an owner address, and provides basic authorization control
* functions, this simplifies the implementation of "user permissions".
*/
contract Ownable {
	address public owner;
	address public newOwner;

	event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

	/**
	* @dev Throws if called by any account other than the owner.
	*/
	modifier onlyOwner() {
		require(isOwner(), "Ownable: caller is not the owner");
		_;
	}

	/**
	* @return true if `msg.sender` is the owner of the contract.
	*/
	function isOwner() public view returns (bool) {
		return msg.sender == owner;
	}

	/**
	* @dev Allows the current owner to relinquish control of the contract.
	* It will not be possible to call the functions with the `onlyOwner`
	* modifier anymore.
	* @notice Renouncing ownership will leave the contract without an owner,
	* thereby removing any functionality that is only available to the owner.
	*/
	function renounceOwnership() external onlyOwner {
		emit OwnershipTransferred(owner, address(0));
		owner = address(0);
	}

	/**
	* @dev Allows the current owner to transfer control of the contract to a newOwner.
	* @param _newOwner The address to transfer ownership to.
	*/
	function transferOwnership(address _newOwner) external onlyOwner {
		newOwner = _newOwner;
	}

	function acceptOwnership() public{
		require (newOwner == msg.sender, "Ownable: only new Owner can accept");
		emit OwnershipTransferred(owner, newOwner);
		owner = newOwner;
		newOwner = address(0);
	}
}

pragma solidity ^0.5.7;

/**
* @title SafeMath
* @dev Unsigned math operations with safety checks that revert on error.
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
		require(c / a == b, "SafeMath: multiplication overflow");

		return c;
	}

	/**
	* @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
	*/
	function div(uint256 a, uint256 b) internal pure returns (uint256) {
		// Solidity only automatically asserts when dividing by 0
		require(b > 0, "SafeMath: division by zero");
		uint256 c = a / b;
		// assert(a == b * c + a % b); // There is no case in which this doesn't hold

		return c;
	}

	/**
	* @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
	*/
	function sub(uint256 a, uint256 b) internal pure returns (uint256) {
		require(b <= a, "SafeMath: subtraction overflow");
		uint256 c = a - b;

		return c;
	}

	/**
	* @dev Adds two unsigned integers, reverts on overflow.
	*/
	function add(uint256 a, uint256 b) internal pure returns (uint256) {
		uint256 c = a + b;
		require(c >= a, "SafeMath: addition overflow");

		return c;
	}

	/**
	* @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
	* reverts when dividing by zero.
	*/
	function mod(uint256 a, uint256 b) internal pure returns (uint256) {
		require(b != 0, "SafeMath: modulo by zero");
		return a % b;
	}
}

pragma solidity ^0.5.8;

import "./erc20.sol";
import "./ownable.sol";

contract Timelocks is ERC20, Ownable{

    uint public lockedBalance;

    struct Locker {
        uint amount;
        uint locktime;
    }

    mapping(address => Locker[]) timeLocks;

    /**
    * @dev function that lock tokens held by contract. Tokens can be unlocked and send to user after fime pass
    * @param lockTimestamp timestamp after whih coins can be unlocked
    * @param amount amount of tokens to lock
    * @param user address of uset that cn unlock and posess tokens
    */
    function lock(uint lockTimestamp, uint amount, address user) external onlyOwner {
        _lock(lockTimestamp, amount, user);
    }

	function _lock(uint lockTimestamp, uint amount, address user) internal{
        uint current = _balances[address(this)];
        require(amount <= current.sub(lockedBalance), "Lock: Not enough tokens");
        lockedBalance = lockedBalance.add(amount);
        timeLocks[user].push(Locker(amount, lockTimestamp));
    }

    /**
     * @dev Function to unlock timelocked tokens
     * If block.timestap passed tokens are sent to owner and lock is removed from database
     */
    function unlock() external
    {
        require(timeLocks[msg.sender].length > 0, "Unlock: No locks!");
        Locker[] storage l = timeLocks[msg.sender];
        for (uint i = 0; i < l.length; i++)
        {
            if (l[i].locktime < block.timestamp) {
                uint amount = l[i].amount;
                require(amount <= lockedBalance && amount <= _balances[address(this)], "Unlock: Not enough coins on contract!");
                lockedBalance = lockedBalance.sub(amount);
                _transfer(address(this), msg.sender, amount);
                for (uint j = i; j < l.length - 1; j++)
                {
                    l[j] = l[j + 1];
                }
                l.length--;
                i--;
            }
        }
    }

    /**
     * @dev Function to check how many locks are on caller account
     * We need it because (for now) contract can not retrurn array of structs
     * @return number of timelocked locks
     */
    function locks() external view returns(uint)
    {
        return _locks(msg.sender);
    }

    /**
     * @dev Function to check timelocks of any user
     * @param user addres of user
     * @return nuber of locks
     */
    function locksOf(address user) external view returns(uint) {
        return _locks(user);
    }

    function _locks(address user) internal view returns(uint){
        return timeLocks[user].length;
    }

    /**
     * @dev Function to check given timeLock
     * @param num number of timeLock
     * @return amount locked
     * @return timestamp after whih coins can be unlocked
     */
    function showLock(uint num) external view returns(uint, uint)
    {
        return _showLock(msg.sender, num);
    }

    /**
     * @dev Function to show timeLock of any user
     * @param user address of user
     * @param num number of lock
     * @return amount locked
     * @return timestamp after whih can be unlocked
     */
    function showLockOf(address user, uint num) external view returns(uint, uint) {
        return _showLock(user, num);
    }

    function _showLock(address user, uint num) internal view returns(uint, uint) {
        require(timeLocks[user].length > 0, "ShowLock: No locks!");
        require(num < timeLocks[user].length, "ShowLock: Index over number of locks.");
        Locker[] storage l = timeLocks[user];
        return (l[num].amount, l[num].locktime);
    }
}

pragma solidity ^0.5.8;

import "./ierc20.sol";
import "./safemath.sol";
import "./erc20.sol";
import "./burnable.sol";
import "./ownable.sol";
import "./timelocks.sol";

contract ContractFallbacks {
    function receiveApproval(address from, uint256 _amount, address _token, bytes memory _data) public;
	function onTokenTransfer(address from, uint256 amount, bytes memory data) public returns (bool success);
}

contract Wolfs is IERC20, ERC20, ERC20Burnable, Ownable, Timelocks {
	using SafeMath for uint256;

	string public name;
	string public symbol;
	uint8 public decimals;

	/**
	*	@dev Token constructor
	*/
	constructor () public {
		name = "Wolfs Group AG";
		symbol = "WLF";
		decimals = 0;

		owner = 0x7fd429DBb710674614A35e967788Fa3e23A5c1C9;
		emit OwnershipTransferred(address(0), owner);

		_mint(0xc7eEef150818b5D3301cc93a965195F449603805, 15000000);
		_mint(0x7fd429DBb710674614A35e967788Fa3e23A5c1C9, 135000000);
	}

	/**
	 * @dev function that allow to approve for transfer and call contract in one transaction
	 * @param _spender contract address
	 * @param _amount amount of tokens
	 * @param _extraData optional encoded data to send to contract
	 * @return True if function call was succesfull
	 */
    function approveAndCall(address _spender, uint256 _amount, bytes calldata _extraData) external returns (bool success)
	{
        require(approve(_spender, _amount), "ERC20: Approve unsuccesfull");
        ContractFallbacks(_spender).receiveApproval(msg.sender, _amount, address(this), _extraData);
        return true;
    }

    /**
     * @dev function that transer tokens to diven address and call function on that address
     * @param _to address to send tokens and call
     * @param _value amount of tokens
     * @param _data optional extra data to process in calling contract
     * @return success True if all succedd
     */
	function transferAndCall(address _to, uint _value, bytes calldata _data) external returns (bool success)
  	{
  	    _transfer(msg.sender, _to, _value);
		ContractFallbacks(_to).onTokenTransfer(msg.sender, _value, _data);
		return true;
  	}

}

pragma solidity ^0.5.8;

import "./erc20.sol";

/**
* @title Burnable Token
* @dev Token that can be irreversibly burned (destroyed).
*/
contract ERC20Burnable is ERC20 {
	/**
	* @dev Burns a specific amount of tokens.
	* @param value The amount of token to be burned.
	*/
	function burn(uint256 value) external {
		_burn(msg.sender, value);
	}

	/**
	* @dev Burns a specific amount of tokens from the target address and decrements allowance.
	* @param from address The account whose tokens will be burned.
	* @param value uint256 The amount of token to be burned.
	*/
	function burnFrom(address from, uint256 value) external {
		_burnFrom(from, value);
	}
}

pragma solidity ^0.5.8;

import "./safemath.sol";
import "./ierc20.sol";

/**
* @title Standard ERC20 token
** @dev Implementation of the basic standard token.
* https://eips.ethereum.org/EIPS/eip-20
* Originally based on code by FirstBlood:
* https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
** This implementation emits additional Approval events, allowing applications to reconstruct the allowance status for
* all accounts just by listening to said events. Note that this isn't required by the specification, and other
* compliant implementations may not do it.
*/
contract ERC20 is IERC20 {
	using SafeMath for uint256;

	mapping (address => uint256) internal _balances;

	mapping (address => mapping (address => uint256)) private _allowed;

	uint256 private _totalSupply;

	/**
	* @dev Total number of tokens in existence.
	*/
	function totalSupply() external view returns (uint256) {
		return _totalSupply;
	}

	/**
	* @dev Gets the balance of the specified address.
	* @param owner The address to query the balance of.
	* @return A uint256 representing the amount owned by the passed address.
	*/
	function balanceOf(address owner) external view returns (uint256) {
		return _balances[owner];
	}

	/**
	* @dev Function to check the amount of tokens that an owner allowed to a spender.
	* @param owner address The address which owns the funds.
	* @param spender address The address which will spend the funds.
	* @return A uint256 specifying the amount of tokens still available for the spender.
	*/
	function allowance(address owner, address spender) external view returns (uint256) {
		return _allowed[owner][spender];
	}

	/**
	* @dev Transfer token to a specified address.
	* @param to The address to transfer to.
	* @param value The amount to be transferred.
	*/
	function transfer(address to, uint256 value) external returns (bool) {
		_transfer(msg.sender, to, value);
		return true;
	}

	/**
	* @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
	* Beware that changing an allowance with this method brings the risk that someone may use both the old
	* and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
	* race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
	* https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
	* @param spender The address which will spend the funds.
	* @param value The amount of tokens to be spent.
	*/
	function approve(address spender, uint256 value) public returns (bool) {
		_approve(msg.sender, spender, value);
		return true;
	}

	/**
	* @dev Transfer tokens from one address to another.
	* Note that while this function emits an Approval event, this is not required as per the specification,
	* and other compliant implementations may not emit the event.
	* @param from address The address which you want to send tokens from
	* @param to address The address which you want to transfer to
	* @param value uint256 the amount of tokens to be transferred
	*/
	function transferFrom(address from, address to, uint256 value) external returns (bool) {
		_transfer(from, to, value);
		_approve(from, msg.sender, _allowed[from][msg.sender].sub(value));
		return true;
	}

	/**
	* @dev Increase the amount of tokens that an owner allowed to a spender.
	* approve should be called when _allowed[msg.sender][spender] == 0. To increment
	* allowed value is better to use this function to avoid 2 calls (and wait until
	* the first transaction is mined)
	* From MonolithDAO Token.sol
	* Emits an Approval event.
	* @param spender The address which will spend the funds.
	* @param addedValue The amount of tokens to increase the allowance by.
	*/
	function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
		_approve(msg.sender, spender, _allowed[msg.sender][spender].add(addedValue));
		return true;
	}

	/**
	* @dev Decrease the amount of tokens that an owner allowed to a spender.
	* approve should be called when _allowed[msg.sender][spender] == 0. To decrement
	* allowed value is better to use this function to avoid 2 calls (and wait until
	* the first transaction is mined)
	* From MonolithDAO Token.sol
	* Emits an Approval event.
	* @param spender The address which will spend the funds.
	* @param subtractedValue The amount of tokens to decrease the allowance by.
	*/
	function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
		_approve(msg.sender, spender, _allowed[msg.sender][spender].sub(subtractedValue));
		return true;
	}

	/**
	* @dev Transfer token for a specified addresses.
	* @param from The address to transfer from.
	* @param to The address to transfer to.
	* @param value The amount to be transferred.
	*/
	function _transfer(address from, address to, uint256 value) internal {
		require(to != address(0), "ERC20: transfer to the zero address");
        require(_balances[from]>=value, "ERC20 transfer: not enough tokens");
		_balances[from] = _balances[from].sub(value);
		_balances[to] = _balances[to].add(value);
		emit Transfer(from, to, value);
	}

	/**
	* @dev Internal function that mints an amount of the token and assigns it to
	* an account. This encapsulates the modification of balances such that the
	* proper events are emitted.
	* @param account The account that will receive the created tokens.
	* @param value The amount that will be created.
	*/
	function _mint(address account, uint256 value) internal {
		require(account != address(0), "ERC20: mint to the zero address");

		_totalSupply = _totalSupply.add(value);
		_balances[account] = _balances[account].add(value);
		emit Transfer(address(0), account, value);
	}

	/**
	* @dev Internal function that burns an amount of the token of a given
	* account.
	* @param account The account whose tokens will be burnt.
	* @param value The amount that will be burnt.
	*/
	function _burn(address account, uint256 value) internal {
		require(account != address(0), "ERC20: burn from the zero address");
		require(_balances[account] >= value, "Burn: not enough tokens");
		_totalSupply = _totalSupply.sub(value);
		_balances[account] = _balances[account].sub(value);
		emit Transfer(account, address(0), value);
	}

	/**
	* @dev Approve an address to spend another addresses' tokens.
	* @param owner The address that owns the tokens.
	* @param spender The address that will spend the tokens.
	* @param value The number of tokens that can be spent.
	*/
	function _approve(address owner, address spender, uint256 value) internal {
		require(owner != address(0), "ERC20: approve from the zero address");
		require(spender != address(0), "ERC20: approve to the zero address");
		_allowed[owner][spender] = value;
		emit Approval(owner, spender, value);
	}

	/**
	* @dev Internal function that burns an amount of the token of a given
	* account, deducting from the sender's allowance for said account. Uses the
	* internal burn function.
	* Emits an Approval event (reflecting the reduced allowance).
	* @param account The account whose tokens will be burnt.
	* @param value The amount that will be burnt.
	*/
	function _burnFrom(address account, uint256 value) internal {
		require(_allowed[account][msg.sender]>=value, "Burn: allowance too low");
		_burn(account, value);
		_approve(account, msg.sender, _allowed[account][msg.sender].sub(value));
	}
}

pragma solidity ^0.5.8;

/**
* @title ERC20 interface
* @dev see https://eips.ethereum.org/EIPS/eip-20
*/
interface IERC20 {
	function transfer(address to, uint256 value) external returns (bool);

	function approve(address spender, uint256 value) external returns (bool);

	function transferFrom(address from, address to, uint256 value) external returns (bool);

	function totalSupply() external view returns (uint256);

	function balanceOf(address who) external view returns (uint256);

	function allowance(address owner, address spender) external view returns (uint256);

	event Transfer(address indexed from, address indexed to, uint256 value);

	event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity ^0.5.8;

/**
* @title Ownable
* @dev The Ownable contract has an owner address, and provides basic authorization control
* functions, this simplifies the implementation of "user permissions".
*/
contract Ownable {
	address public owner;
	address public newOwner;

	event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

	/**
	* @dev Throws if called by any account other than the owner.
	*/
	modifier onlyOwner() {
		require(isOwner(), "Ownable: caller is not the owner");
		_;
	}

	/**
	* @return true if `msg.sender` is the owner of the contract.
	*/
	function isOwner() public view returns (bool) {
		return msg.sender == owner;
	}

	/**
	* @dev Allows the current owner to relinquish control of the contract.
	* It will not be possible to call the functions with the `onlyOwner`
	* modifier anymore.
	* @notice Renouncing ownership will leave the contract without an owner,
	* thereby removing any functionality that is only available to the owner.
	*/
	function renounceOwnership() external onlyOwner {
		emit OwnershipTransferred(owner, address(0));
		owner = address(0);
	}

	/**
	* @dev Allows the current owner to transfer control of the contract to a newOwner.
	* @param _newOwner The address to transfer ownership to.
	*/
	function transferOwnership(address _newOwner) external onlyOwner {
		newOwner = _newOwner;
	}

	function acceptOwnership() public{
		require (newOwner == msg.sender, "Ownable: only new Owner can accept");
		emit OwnershipTransferred(owner, newOwner);
		owner = newOwner;
		newOwner = address(0);
	}
}

pragma solidity ^0.5.7;

/**
* @title SafeMath
* @dev Unsigned math operations with safety checks that revert on error.
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
		require(c / a == b, "SafeMath: multiplication overflow");

		return c;
	}

	/**
	* @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
	*/
	function div(uint256 a, uint256 b) internal pure returns (uint256) {
		// Solidity only automatically asserts when dividing by 0
		require(b > 0, "SafeMath: division by zero");
		uint256 c = a / b;
		// assert(a == b * c + a % b); // There is no case in which this doesn't hold

		return c;
	}

	/**
	* @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
	*/
	function sub(uint256 a, uint256 b) internal pure returns (uint256) {
		require(b <= a, "SafeMath: subtraction overflow");
		uint256 c = a - b;

		return c;
	}

	/**
	* @dev Adds two unsigned integers, reverts on overflow.
	*/
	function add(uint256 a, uint256 b) internal pure returns (uint256) {
		uint256 c = a + b;
		require(c >= a, "SafeMath: addition overflow");

		return c;
	}

	/**
	* @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
	* reverts when dividing by zero.
	*/
	function mod(uint256 a, uint256 b) internal pure returns (uint256) {
		require(b != 0, "SafeMath: modulo by zero");
		return a % b;
	}
}

pragma solidity ^0.5.8;

import "./erc20.sol";
import "./ownable.sol";

contract Timelocks is ERC20, Ownable{

    uint public lockedBalance;

    struct Locker {
        uint amount;
        uint locktime;
    }

    mapping(address => Locker[]) timeLocks;

    /**
    * @dev function that lock tokens held by contract. Tokens can be unlocked and send to user after fime pass
    * @param lockTimestamp timestamp after whih coins can be unlocked
    * @param amount amount of tokens to lock
    * @param user address of uset that cn unlock and posess tokens
    */
    function lock(uint lockTimestamp, uint amount, address user) external onlyOwner {
        _lock(lockTimestamp, amount, user);
    }

	function _lock(uint lockTimestamp, uint amount, address user) internal{
        uint current = _balances[address(this)];
        require(amount <= current.sub(lockedBalance), "Lock: Not enough tokens");
        lockedBalance = lockedBalance.add(amount);
        timeLocks[user].push(Locker(amount, lockTimestamp));
    }

    /**
     * @dev Function to unlock timelocked tokens
     * If block.timestap passed tokens are sent to owner and lock is removed from database
     */
    function unlock() external
    {
        require(timeLocks[msg.sender].length > 0, "Unlock: No locks!");
        Locker[] storage l = timeLocks[msg.sender];
        for (uint i = 0; i < l.length; i++)
        {
            if (l[i].locktime < block.timestamp) {
                uint amount = l[i].amount;
                require(amount <= lockedBalance && amount <= _balances[address(this)], "Unlock: Not enough coins on contract!");
                lockedBalance = lockedBalance.sub(amount);
                _transfer(address(this), msg.sender, amount);
                for (uint j = i; j < l.length - 1; j++)
                {
                    l[j] = l[j + 1];
                }
                l.length--;
                i--;
            }
        }
    }

    /**
     * @dev Function to check how many locks are on caller account
     * We need it because (for now) contract can not retrurn array of structs
     * @return number of timelocked locks
     */
    function locks() external view returns(uint)
    {
        return _locks(msg.sender);
    }

    /**
     * @dev Function to check timelocks of any user
     * @param user addres of user
     * @return nuber of locks
     */
    function locksOf(address user) external view returns(uint) {
        return _locks(user);
    }

    function _locks(address user) internal view returns(uint){
        return timeLocks[user].length;
    }

    /**
     * @dev Function to check given timeLock
     * @param num number of timeLock
     * @return amount locked
     * @return timestamp after whih coins can be unlocked
     */
    function showLock(uint num) external view returns(uint, uint)
    {
        return _showLock(msg.sender, num);
    }

    /**
     * @dev Function to show timeLock of any user
     * @param user address of user
     * @param num number of lock
     * @return amount locked
     * @return timestamp after whih can be unlocked
     */
    function showLockOf(address user, uint num) external view returns(uint, uint) {
        return _showLock(user, num);
    }

    function _showLock(address user, uint num) internal view returns(uint, uint) {
        require(timeLocks[user].length > 0, "ShowLock: No locks!");
        require(num < timeLocks[user].length, "ShowLock: Index over number of locks.");
        Locker[] storage l = timeLocks[user];
        return (l[num].amount, l[num].locktime);
    }
}

pragma solidity ^0.5.8;

import "./ierc20.sol";
import "./safemath.sol";
import "./erc20.sol";
import "./burnable.sol";
import "./ownable.sol";
import "./timelocks.sol";

contract ContractFallbacks {
    function receiveApproval(address from, uint256 _amount, address _token, bytes memory _data) public;
	function onTokenTransfer(address from, uint256 amount, bytes memory data) public returns (bool success);
}

contract Wolfs is IERC20, ERC20, ERC20Burnable, Ownable, Timelocks {
	using SafeMath for uint256;

	string public name;
	string public symbol;
	uint8 public decimals;

	/**
	*	@dev Token constructor
	*/
	constructor () public {
		name = "Wolfs Group AG";
		symbol = "WLF";
		decimals = 0;

		owner = 0x7fd429DBb710674614A35e967788Fa3e23A5c1C9;
		emit OwnershipTransferred(address(0), owner);

		_mint(0xc7eEef150818b5D3301cc93a965195F449603805, 15000000);
		_mint(0x7fd429DBb710674614A35e967788Fa3e23A5c1C9, 135000000);
	}

	/**
	 * @dev function that allow to approve for transfer and call contract in one transaction
	 * @param _spender contract address
	 * @param _amount amount of tokens
	 * @param _extraData optional encoded data to send to contract
	 * @return True if function call was succesfull
	 */
    function approveAndCall(address _spender, uint256 _amount, bytes calldata _extraData) external returns (bool success)
	{
        require(approve(_spender, _amount), "ERC20: Approve unsuccesfull");
        ContractFallbacks(_spender).receiveApproval(msg.sender, _amount, address(this), _extraData);
        return true;
    }

    /**
     * @dev function that transer tokens to diven address and call function on that address
     * @param _to address to send tokens and call
     * @param _value amount of tokens
     * @param _data optional extra data to process in calling contract
     * @return success True if all succedd
     */
	function transferAndCall(address _to, uint _value, bytes calldata _data) external returns (bool success)
  	{
  	    _transfer(msg.sender, _to, _value);
		ContractFallbacks(_to).onTokenTransfer(msg.sender, _value, _data);
		return true;
  	}

}

pragma solidity ^0.5.8;

import "./erc20.sol";

/**
* @title Burnable Token
* @dev Token that can be irreversibly burned (destroyed).
*/
contract ERC20Burnable is ERC20 {
	/**
	* @dev Burns a specific amount of tokens.
	* @param value The amount of token to be burned.
	*/
	function burn(uint256 value) external {
		_burn(msg.sender, value);
	}

	/**
	* @dev Burns a specific amount of tokens from the target address and decrements allowance.
	* @param from address The account whose tokens will be burned.
	* @param value uint256 The amount of token to be burned.
	*/
	function burnFrom(address from, uint256 value) external {
		_burnFrom(from, value);
	}
}

pragma solidity ^0.5.8;

import "./safemath.sol";
import "./ierc20.sol";

/**
* @title Standard ERC20 token
** @dev Implementation of the basic standard token.
* https://eips.ethereum.org/EIPS/eip-20
* Originally based on code by FirstBlood:
* https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
** This implementation emits additional Approval events, allowing applications to reconstruct the allowance status for
* all accounts just by listening to said events. Note that this isn't required by the specification, and other
* compliant implementations may not do it.
*/
contract ERC20 is IERC20 {
	using SafeMath for uint256;

	mapping (address => uint256) internal _balances;

	mapping (address => mapping (address => uint256)) private _allowed;

	uint256 private _totalSupply;

	/**
	* @dev Total number of tokens in existence.
	*/
	function totalSupply() external view returns (uint256) {
		return _totalSupply;
	}

	/**
	* @dev Gets the balance of the specified address.
	* @param owner The address to query the balance of.
	* @return A uint256 representing the amount owned by the passed address.
	*/
	function balanceOf(address owner) external view returns (uint256) {
		return _balances[owner];
	}

	/**
	* @dev Function to check the amount of tokens that an owner allowed to a spender.
	* @param owner address The address which owns the funds.
	* @param spender address The address which will spend the funds.
	* @return A uint256 specifying the amount of tokens still available for the spender.
	*/
	function allowance(address owner, address spender) external view returns (uint256) {
		return _allowed[owner][spender];
	}

	/**
	* @dev Transfer token to a specified address.
	* @param to The address to transfer to.
	* @param value The amount to be transferred.
	*/
	function transfer(address to, uint256 value) external returns (bool) {
		_transfer(msg.sender, to, value);
		return true;
	}

	/**
	* @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
	* Beware that changing an allowance with this method brings the risk that someone may use both the old
	* and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
	* race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
	* https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
	* @param spender The address which will spend the funds.
	* @param value The amount of tokens to be spent.
	*/
	function approve(address spender, uint256 value) public returns (bool) {
		_approve(msg.sender, spender, value);
		return true;
	}

	/**
	* @dev Transfer tokens from one address to another.
	* Note that while this function emits an Approval event, this is not required as per the specification,
	* and other compliant implementations may not emit the event.
	* @param from address The address which you want to send tokens from
	* @param to address The address which you want to transfer to
	* @param value uint256 the amount of tokens to be transferred
	*/
	function transferFrom(address from, address to, uint256 value) external returns (bool) {
		_transfer(from, to, value);
		_approve(from, msg.sender, _allowed[from][msg.sender].sub(value));
		return true;
	}

	/**
	* @dev Increase the amount of tokens that an owner allowed to a spender.
	* approve should be called when _allowed[msg.sender][spender] == 0. To increment
	* allowed value is better to use this function to avoid 2 calls (and wait until
	* the first transaction is mined)
	* From MonolithDAO Token.sol
	* Emits an Approval event.
	* @param spender The address which will spend the funds.
	* @param addedValue The amount of tokens to increase the allowance by.
	*/
	function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
		_approve(msg.sender, spender, _allowed[msg.sender][spender].add(addedValue));
		return true;
	}

	/**
	* @dev Decrease the amount of tokens that an owner allowed to a spender.
	* approve should be called when _allowed[msg.sender][spender] == 0. To decrement
	* allowed value is better to use this function to avoid 2 calls (and wait until
	* the first transaction is mined)
	* From MonolithDAO Token.sol
	* Emits an Approval event.
	* @param spender The address which will spend the funds.
	* @param subtractedValue The amount of tokens to decrease the allowance by.
	*/
	function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
		_approve(msg.sender, spender, _allowed[msg.sender][spender].sub(subtractedValue));
		return true;
	}

	/**
	* @dev Transfer token for a specified addresses.
	* @param from The address to transfer from.
	* @param to The address to transfer to.
	* @param value The amount to be transferred.
	*/
	function _transfer(address from, address to, uint256 value) internal {
		require(to != address(0), "ERC20: transfer to the zero address");
        require(_balances[from]>=value, "ERC20 transfer: not enough tokens");
		_balances[from] = _balances[from].sub(value);
		_balances[to] = _balances[to].add(value);
		emit Transfer(from, to, value);
	}

	/**
	* @dev Internal function that mints an amount of the token and assigns it to
	* an account. This encapsulates the modification of balances such that the
	* proper events are emitted.
	* @param account The account that will receive the created tokens.
	* @param value The amount that will be created.
	*/
	function _mint(address account, uint256 value) internal {
		require(account != address(0), "ERC20: mint to the zero address");

		_totalSupply = _totalSupply.add(value);
		_balances[account] = _balances[account].add(value);
		emit Transfer(address(0), account, value);
	}

	/**
	* @dev Internal function that burns an amount of the token of a given
	* account.
	* @param account The account whose tokens will be burnt.
	* @param value The amount that will be burnt.
	*/
	function _burn(address account, uint256 value) internal {
		require(account != address(0), "ERC20: burn from the zero address");
		require(_balances[account] >= value, "Burn: not enough tokens");
		_totalSupply = _totalSupply.sub(value);
		_balances[account] = _balances[account].sub(value);
		emit Transfer(account, address(0), value);
	}

	/**
	* @dev Approve an address to spend another addresses' tokens.
	* @param owner The address that owns the tokens.
	* @param spender The address that will spend the tokens.
	* @param value The number of tokens that can be spent.
	*/
	function _approve(address owner, address spender, uint256 value) internal {
		require(owner != address(0), "ERC20: approve from the zero address");
		require(spender != address(0), "ERC20: approve to the zero address");
		_allowed[owner][spender] = value;
		emit Approval(owner, spender, value);
	}

	/**
	* @dev Internal function that burns an amount of the token of a given
	* account, deducting from the sender's allowance for said account. Uses the
	* internal burn function.
	* Emits an Approval event (reflecting the reduced allowance).
	* @param account The account whose tokens will be burnt.
	* @param value The amount that will be burnt.
	*/
	function _burnFrom(address account, uint256 value) internal {
		require(_allowed[account][msg.sender]>=value, "Burn: allowance too low");
		_burn(account, value);
		_approve(account, msg.sender, _allowed[account][msg.sender].sub(value));
	}
}

pragma solidity ^0.5.8;

/**
* @title ERC20 interface
* @dev see https://eips.ethereum.org/EIPS/eip-20
*/
interface IERC20 {
	function transfer(address to, uint256 value) external returns (bool);

	function approve(address spender, uint256 value) external returns (bool);

	function transferFrom(address from, address to, uint256 value) external returns (bool);

	function totalSupply() external view returns (uint256);

	function balanceOf(address who) external view returns (uint256);

	function allowance(address owner, address spender) external view returns (uint256);

	event Transfer(address indexed from, address indexed to, uint256 value);

	event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity ^0.5.8;

/**
* @title Ownable
* @dev The Ownable contract has an owner address, and provides basic authorization control
* functions, this simplifies the implementation of "user permissions".
*/
contract Ownable {
	address public owner;
	address public newOwner;

	event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

	/**
	* @dev Throws if called by any account other than the owner.
	*/
	modifier onlyOwner() {
		require(isOwner(), "Ownable: caller is not the owner");
		_;
	}

	/**
	* @return true if `msg.sender` is the owner of the contract.
	*/
	function isOwner() public view returns (bool) {
		return msg.sender == owner;
	}

	/**
	* @dev Allows the current owner to relinquish control of the contract.
	* It will not be possible to call the functions with the `onlyOwner`
	* modifier anymore.
	* @notice Renouncing ownership will leave the contract without an owner,
	* thereby removing any functionality that is only available to the owner.
	*/
	function renounceOwnership() external onlyOwner {
		emit OwnershipTransferred(owner, address(0));
		owner = address(0);
	}

	/**
	* @dev Allows the current owner to transfer control of the contract to a newOwner.
	* @param _newOwner The address to transfer ownership to.
	*/
	function transferOwnership(address _newOwner) external onlyOwner {
		newOwner = _newOwner;
	}

	function acceptOwnership() public{
		require (newOwner == msg.sender, "Ownable: only new Owner can accept");
		emit OwnershipTransferred(owner, newOwner);
		owner = newOwner;
		newOwner = address(0);
	}
}

pragma solidity ^0.5.7;

/**
* @title SafeMath
* @dev Unsigned math operations with safety checks that revert on error.
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
		require(c / a == b, "SafeMath: multiplication overflow");

		return c;
	}

	/**
	* @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
	*/
	function div(uint256 a, uint256 b) internal pure returns (uint256) {
		// Solidity only automatically asserts when dividing by 0
		require(b > 0, "SafeMath: division by zero");
		uint256 c = a / b;
		// assert(a == b * c + a % b); // There is no case in which this doesn't hold

		return c;
	}

	/**
	* @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
	*/
	function sub(uint256 a, uint256 b) internal pure returns (uint256) {
		require(b <= a, "SafeMath: subtraction overflow");
		uint256 c = a - b;

		return c;
	}

	/**
	* @dev Adds two unsigned integers, reverts on overflow.
	*/
	function add(uint256 a, uint256 b) internal pure returns (uint256) {
		uint256 c = a + b;
		require(c >= a, "SafeMath: addition overflow");

		return c;
	}

	/**
	* @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
	* reverts when dividing by zero.
	*/
	function mod(uint256 a, uint256 b) internal pure returns (uint256) {
		require(b != 0, "SafeMath: modulo by zero");
		return a % b;
	}
}

pragma solidity ^0.5.8;

import "./erc20.sol";
import "./ownable.sol";

contract Timelocks is ERC20, Ownable{

    uint public lockedBalance;

    struct Locker {
        uint amount;
        uint locktime;
    }

    mapping(address => Locker[]) timeLocks;

    /**
    * @dev function that lock tokens held by contract. Tokens can be unlocked and send to user after fime pass
    * @param lockTimestamp timestamp after whih coins can be unlocked
    * @param amount amount of tokens to lock
    * @param user address of uset that cn unlock and posess tokens
    */
    function lock(uint lockTimestamp, uint amount, address user) external onlyOwner {
        _lock(lockTimestamp, amount, user);
    }

	function _lock(uint lockTimestamp, uint amount, address user) internal{
        uint current = _balances[address(this)];
        require(amount <= current.sub(lockedBalance), "Lock: Not enough tokens");
        lockedBalance = lockedBalance.add(amount);
        timeLocks[user].push(Locker(amount, lockTimestamp));
    }

    /**
     * @dev Function to unlock timelocked tokens
     * If block.timestap passed tokens are sent to owner and lock is removed from database
     */
    function unlock() external
    {
        require(timeLocks[msg.sender].length > 0, "Unlock: No locks!");
        Locker[] storage l = timeLocks[msg.sender];
        for (uint i = 0; i < l.length; i++)
        {
            if (l[i].locktime < block.timestamp) {
                uint amount = l[i].amount;
                require(amount <= lockedBalance && amount <= _balances[address(this)], "Unlock: Not enough coins on contract!");
                lockedBalance = lockedBalance.sub(amount);
                _transfer(address(this), msg.sender, amount);
                for (uint j = i; j < l.length - 1; j++)
                {
                    l[j] = l[j + 1];
                }
                l.length--;
                i--;
            }
        }
    }

    /**
     * @dev Function to check how many locks are on caller account
     * We need it because (for now) contract can not retrurn array of structs
     * @return number of timelocked locks
     */
    function locks() external view returns(uint)
    {
        return _locks(msg.sender);
    }

    /**
     * @dev Function to check timelocks of any user
     * @param user addres of user
     * @return nuber of locks
     */
    function locksOf(address user) external view returns(uint) {
        return _locks(user);
    }

    function _locks(address user) internal view returns(uint){
        return timeLocks[user].length;
    }

    /**
     * @dev Function to check given timeLock
     * @param num number of timeLock
     * @return amount locked
     * @return timestamp after whih coins can be unlocked
     */
    function showLock(uint num) external view returns(uint, uint)
    {
        return _showLock(msg.sender, num);
    }

    /**
     * @dev Function to show timeLock of any user
     * @param user address of user
     * @param num number of lock
     * @return amount locked
     * @return timestamp after whih can be unlocked
     */
    function showLockOf(address user, uint num) external view returns(uint, uint) {
        return _showLock(user, num);
    }

    function _showLock(address user, uint num) internal view returns(uint, uint) {
        require(timeLocks[user].length > 0, "ShowLock: No locks!");
        require(num < timeLocks[user].length, "ShowLock: Index over number of locks.");
        Locker[] storage l = timeLocks[user];
        return (l[num].amount, l[num].locktime);
    }
}

pragma solidity ^0.5.8;

import "./ierc20.sol";
import "./safemath.sol";
import "./erc20.sol";
import "./burnable.sol";
import "./ownable.sol";
import "./timelocks.sol";

contract ContractFallbacks {
    function receiveApproval(address from, uint256 _amount, address _token, bytes memory _data) public;
	function onTokenTransfer(address from, uint256 amount, bytes memory data) public returns (bool success);
}

contract Wolfs is IERC20, ERC20, ERC20Burnable, Ownable, Timelocks {
	using SafeMath for uint256;

	string public name;
	string public symbol;
	uint8 public decimals;

	/**
	*	@dev Token constructor
	*/
	constructor () public {
		name = "Wolfs Group AG";
		symbol = "WLF";
		decimals = 0;

		owner = 0x7fd429DBb710674614A35e967788Fa3e23A5c1C9;
		emit OwnershipTransferred(address(0), owner);

		_mint(0xc7eEef150818b5D3301cc93a965195F449603805, 15000000);
		_mint(0x7fd429DBb710674614A35e967788Fa3e23A5c1C9, 135000000);
	}

	/**
	 * @dev function that allow to approve for transfer and call contract in one transaction
	 * @param _spender contract address
	 * @param _amount amount of tokens
	 * @param _extraData optional encoded data to send to contract
	 * @return True if function call was succesfull
	 */
    function approveAndCall(address _spender, uint256 _amount, bytes calldata _extraData) external returns (bool success)
	{
        require(approve(_spender, _amount), "ERC20: Approve unsuccesfull");
        ContractFallbacks(_spender).receiveApproval(msg.sender, _amount, address(this), _extraData);
        return true;
    }

    /**
     * @dev function that transer tokens to diven address and call function on that address
     * @param _to address to send tokens and call
     * @param _value amount of tokens
     * @param _data optional extra data to process in calling contract
     * @return success True if all succedd
     */
	function transferAndCall(address _to, uint _value, bytes calldata _data) external returns (bool success)
  	{
  	    _transfer(msg.sender, _to, _value);
		ContractFallbacks(_to).onTokenTransfer(msg.sender, _value, _data);
		return true;
  	}

}

