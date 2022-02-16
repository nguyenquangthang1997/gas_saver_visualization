pragma solidity ^0.5.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () internal { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}
pragma solidity ^0.5.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
 */
interface IERC20 {
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
pragma solidity ^0.5.0;

import "./Context.sol";
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
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
     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
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
     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
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
     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
pragma solidity ^0.5.0;

import "./IERC20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

/**
 * @title TokenTimelock
 * @dev A token holder contract that can release its token balance gradually like a
 * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the
 * owner.
 * use this contract need :
 * 1.release ERC20 contract;
 * 2.configure and release TokenTimelock contract
 * 3.transfer ERC20 Tokens which need to be timelocked to TokenTimelock contract
 * 4.when time reached, call release() to release tokens to beneficiary
 * 
 * for example:
 * (D=Duration   R=ReleaseRatio)
 *      ^
 *      |
 *      |
 *  R4  |                ————
 *  R3  |            ————
 *  R2  |        ————
 *  R1  |    ———— 
 *      |         
 *      |——————————————————————————>
 *            D1  D2   D3  D4
 * 
 * start = 2019-1-1 00:00:00
 * D1=D2=D3=D4=1year
 * R1=10,R2=20,R3=30,R4=40  (please ensure R1+R2+R3+R4=100)
 * so, you will get below tokens in total
 *        Time                                     Tokens Get
 *   Start~Start+D1                                   0
 * Start+D1~Start+D1+D2                      10% total in this Timelock contract
 * Start+D1+D2~Start+D1+D2+D3              10%+20% total
 * Start+D1+D2+D3~Start+D1+D2+D3+D4        10%+20%+30% total
 * Start+D1+D2+D3+D4~infinity              10%+20%+30%+40% total(usually ensures 100 percent)
 */
contract TokenTimelock is Ownable {
    // The vesting schedule is time-based (i.e. using block timestamps as opposed to e.g. block numbers), and is
    // therefore sensitive to timestamp manipulation (which is something miners can do, to a certain degree). Therefore,
    // it is recommended to avoid using short time durations (less than a minute). Typical vesting schemes, with a
    // cliff period of a year and a duration of four years, are safe to use.
    // solhint-disable not-rely-on-time

    using SafeMath for uint256;

    event TokensReleased(address token, uint256 amount);
    event TokenTimelockRevoked(address token);

    // beneficiary of tokens after they are released
    address private _beneficiary;

    // Durations and timestamps are expressed in UNIX time, the same units as block.timestamp.
    
    uint256 private _start;
    uint256 private _totalDuration;
    
    //Durations and token release ratios expressed in UNIX time
    struct DurationsAndRatios{
        uint256 _periodDuration;
        uint256 _periodReleaseRatio;
    }
    DurationsAndRatios[4] _durationRatio;//four period of duration and ratios
    
    bool private _revocable;

    mapping (address => uint256) private _released;
    mapping (address => bool) private _revoked;

    /**
     * @dev Creates a vesting contract that vests its balance of any ERC20 token to the
     * beneficiary, gradually in a linear fashion until start + duration. By then all
     * of the balance will have vested.
     * @param beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param start the time (as Unix time) at which point vesting starts
     * @param firstDuration: first period duration
     * @param firstRatio: first period release ratio
     * @param secondDuration: second period duration
     * @param secondRatio: second period release ratio
     * @param thirdDuration: third period duration
     * @param thirdRatio: third period release ratio
     * @param fourthDuration: fourth period duration
     * @param fourthRatio: fourth period release ratio
     * @param revocable whether the vesting is revocable or not
     */
    constructor (address beneficiary, uint256 start, uint256 firstDuration,uint256 firstRatio,uint256 secondDuration, uint256 secondRatio,
    uint256 thirdDuration,uint256 thirdRatio,uint256 fourthDuration, uint256 fourthRatio,bool revocable) public {
        require(beneficiary != address(0), "TokenTimelock: beneficiary is the zero address");
        
        require(firstRatio.add(secondRatio).add(thirdRatio).add(fourthRatio)==100, "TokenTimelock: ratios added not equal 100.");
    
        _beneficiary = beneficiary;
        _revocable = revocable;
        _start = start;
        
        _durationRatio[0]._periodDuration = firstDuration;
        _durationRatio[1]._periodDuration = secondDuration;
        _durationRatio[2]._periodDuration = thirdDuration;
        _durationRatio[3]._periodDuration = fourthDuration;
        
        _durationRatio[0]._periodReleaseRatio = firstRatio;
        _durationRatio[1]._periodReleaseRatio = secondRatio;
        _durationRatio[2]._periodReleaseRatio = thirdRatio;
        _durationRatio[3]._periodReleaseRatio = fourthRatio;
        
        _totalDuration = firstDuration.add(secondDuration).add(thirdDuration).add(fourthDuration);
        require(_start.add(_totalDuration) > block.timestamp, "TokenTimelock: final time is before current time");
        
    }

    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    /**
     * @return the end time of every period.
     */
    function getDurationsAndRatios() public view returns (uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256) {
        return (_durationRatio[0]._periodDuration,_durationRatio[1]._periodDuration,_durationRatio[2]._periodDuration,_durationRatio[3]._periodDuration,
        _durationRatio[0]._periodReleaseRatio,_durationRatio[1]._periodReleaseRatio,_durationRatio[2]._periodReleaseRatio,_durationRatio[3]._periodReleaseRatio);
    }

    /**
     * @return the start time of the token vesting.
     */
    function start() public view returns (uint256) {
        return _start;
    }
    
    /**
     * @return current time of the contract.
     */
    function currentTime() public view returns (uint256) {
        return block.timestamp;
    }
    
    /**
     * @return the total duration of the token vesting.
     */
    function totalDuration() public view returns (uint256) {
        return _totalDuration;
    }
    
    /**
     * @return true if the vesting is revocable.
     */
    function revocable() public view returns (bool) {
        return _revocable;
    }
    
    /**
     * @return the amount of the token released.
     */
    function released(address token) public view returns (uint256) {
        return _released[token];
    }
    
    /**
     * @return true if the token is revoked.
     */
    function revoked(address token) public view returns (bool) {
        return _revoked[token];
    }
    
    /**
     * @notice Transfers vested tokens to beneficiary.
     * @param token ERC20 token which is being vested
     */
    function release(IERC20 token) public {
        uint256 unreleased = _releasableAmount(token);

        require(unreleased > 0, "TokenTimelock: no tokens are due");

        _released[address(token)] = _released[address(token)].add(unreleased);

        token.transfer(_beneficiary, unreleased);

        emit TokensReleased(address(token), unreleased);
    }

    /**
     * @notice Allows the owner to revoke the vesting. Tokens already vested
     * remain in the contract, the rest are returned to the owner.
     * @param token ERC20 token which is being vested
     */
    function revoke(IERC20 token) public onlyOwner {
        require(_revocable, "TokenTimelock: cannot revoke");
        require(!_revoked[address(token)], "TokenTimelock: token already revoked");

        uint256 balance = token.balanceOf(address(this));

        uint256 unreleased = _releasableAmount(token);
        uint256 refund = balance.sub(unreleased);

        _revoked[address(token)] = true;

        token.transfer(owner(), refund);

        emit TokenTimelockRevoked(address(token));
    }
    
    /**
     * @dev Calculates the amount that has already vested but hasn't been released yet.
     * @param token ERC20 token which is being vested
     */
    function _releasableAmount(IERC20 token) private view returns (uint256) {
        return _vestedAmount(token).sub(_released[address(token)]);
    }
    
    /**
     * @dev Calculates the amount that should be vested totally.
     * @param token ERC20 token which is being vested
     */
    function _vestedAmount(IERC20 token) private view returns (uint256) {
        uint256 currentBalance = token.balanceOf(address(this));//token balance in TokenTimelock contract
        uint256 totalBalance = currentBalance.add(_released[address(token)]);//total balance in TokenTimelock contract
        
        uint256[4] memory periodEndTimestamp;
        periodEndTimestamp[0] = _start.add(_durationRatio[0]._periodDuration);
        periodEndTimestamp[1] = periodEndTimestamp[0].add(_durationRatio[1]._periodDuration);
        periodEndTimestamp[2] = periodEndTimestamp[1].add(_durationRatio[2]._periodDuration);
        periodEndTimestamp[3] = periodEndTimestamp[2].add(_durationRatio[3]._periodDuration);
        uint256 releaseRatio;
        if (block.timestamp < periodEndTimestamp[0]) {
            return 0;
        }else if(block.timestamp >= periodEndTimestamp[0] && block.timestamp < periodEndTimestamp[1]){
            releaseRatio = _durationRatio[0]._periodReleaseRatio;
        }else if(block.timestamp >= periodEndTimestamp[1] && block.timestamp < periodEndTimestamp[2]){
            releaseRatio = _durationRatio[0]._periodReleaseRatio.add(_durationRatio[1]._periodReleaseRatio);
        }else if(block.timestamp >= periodEndTimestamp[2] && block.timestamp < periodEndTimestamp[3]) {
            releaseRatio = _durationRatio[0]._periodReleaseRatio.add(_durationRatio[1]._periodReleaseRatio).add(_durationRatio[2]._periodReleaseRatio);
        } else {
            releaseRatio = 100;
        }
        return releaseRatio.mul(totalBalance).div(100);
    }
    
}
pragma solidity ^0.5.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () internal { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}
pragma solidity ^0.5.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
 */
interface IERC20 {
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
pragma solidity ^0.5.0;

import "./Context.sol";
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
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
     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
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
     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
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
     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
pragma solidity ^0.5.0;

import "./IERC20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

/**
 * @title TokenTimelock
 * @dev A token holder contract that can release its token balance gradually like a
 * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the
 * owner.
 * use this contract need :
 * 1.release ERC20 contract;
 * 2.configure and release TokenTimelock contract
 * 3.transfer ERC20 Tokens which need to be timelocked to TokenTimelock contract
 * 4.when time reached, call release() to release tokens to beneficiary
 * 
 * for example:
 * (D=Duration   R=ReleaseRatio)
 *      ^
 *      |
 *      |
 *  R4  |                ————
 *  R3  |            ————
 *  R2  |        ————
 *  R1  |    ———— 
 *      |         
 *      |——————————————————————————>
 *            D1  D2   D3  D4
 * 
 * start = 2019-1-1 00:00:00
 * D1=D2=D3=D4=1year
 * R1=10,R2=20,R3=30,R4=40  (please ensure R1+R2+R3+R4=100)
 * so, you will get below tokens in total
 *        Time                                     Tokens Get
 *   Start~Start+D1                                   0
 * Start+D1~Start+D1+D2                      10% total in this Timelock contract
 * Start+D1+D2~Start+D1+D2+D3              10%+20% total
 * Start+D1+D2+D3~Start+D1+D2+D3+D4        10%+20%+30% total
 * Start+D1+D2+D3+D4~infinity              10%+20%+30%+40% total(usually ensures 100 percent)
 */
contract TokenTimelock is Ownable {
    // The vesting schedule is time-based (i.e. using block timestamps as opposed to e.g. block numbers), and is
    // therefore sensitive to timestamp manipulation (which is something miners can do, to a certain degree). Therefore,
    // it is recommended to avoid using short time durations (less than a minute). Typical vesting schemes, with a
    // cliff period of a year and a duration of four years, are safe to use.
    // solhint-disable not-rely-on-time

    using SafeMath for uint256;

    event TokensReleased(address token, uint256 amount);
    event TokenTimelockRevoked(address token);

    // beneficiary of tokens after they are released
    address private _beneficiary;

    // Durations and timestamps are expressed in UNIX time, the same units as block.timestamp.
    
    uint256 private _start;
    uint256 private _totalDuration;
    
    //Durations and token release ratios expressed in UNIX time
    struct DurationsAndRatios{
        uint256 _periodDuration;
        uint256 _periodReleaseRatio;
    }
    DurationsAndRatios[4] _durationRatio;//four period of duration and ratios
    
    bool private _revocable;

    mapping (address => uint256) private _released;
    mapping (address => bool) private _revoked;

    /**
     * @dev Creates a vesting contract that vests its balance of any ERC20 token to the
     * beneficiary, gradually in a linear fashion until start + duration. By then all
     * of the balance will have vested.
     * @param beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param start the time (as Unix time) at which point vesting starts
     * @param firstDuration: first period duration
     * @param firstRatio: first period release ratio
     * @param secondDuration: second period duration
     * @param secondRatio: second period release ratio
     * @param thirdDuration: third period duration
     * @param thirdRatio: third period release ratio
     * @param fourthDuration: fourth period duration
     * @param fourthRatio: fourth period release ratio
     * @param revocable whether the vesting is revocable or not
     */
    constructor (address beneficiary, uint256 start, uint256 firstDuration,uint256 firstRatio,uint256 secondDuration, uint256 secondRatio,
    uint256 thirdDuration,uint256 thirdRatio,uint256 fourthDuration, uint256 fourthRatio,bool revocable) public {
        require(beneficiary != address(0), "TokenTimelock: beneficiary is the zero address");
        
        require(firstRatio.add(secondRatio).add(thirdRatio).add(fourthRatio)==100, "TokenTimelock: ratios added not equal 100.");
    
        _beneficiary = beneficiary;
        _revocable = revocable;
        _start = start;
        
        _durationRatio[0]._periodDuration = firstDuration;
        _durationRatio[1]._periodDuration = secondDuration;
        _durationRatio[2]._periodDuration = thirdDuration;
        _durationRatio[3]._periodDuration = fourthDuration;
        
        _durationRatio[0]._periodReleaseRatio = firstRatio;
        _durationRatio[1]._periodReleaseRatio = secondRatio;
        _durationRatio[2]._periodReleaseRatio = thirdRatio;
        _durationRatio[3]._periodReleaseRatio = fourthRatio;
        
        _totalDuration = firstDuration.add(secondDuration).add(thirdDuration).add(fourthDuration);
        require(_start.add(_totalDuration) > block.timestamp, "TokenTimelock: final time is before current time");
        
    }

    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    /**
     * @return the end time of every period.
     */
    function getDurationsAndRatios() public view returns (uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256) {
        return (_durationRatio[0]._periodDuration,_durationRatio[1]._periodDuration,_durationRatio[2]._periodDuration,_durationRatio[3]._periodDuration,
        _durationRatio[0]._periodReleaseRatio,_durationRatio[1]._periodReleaseRatio,_durationRatio[2]._periodReleaseRatio,_durationRatio[3]._periodReleaseRatio);
    }

    /**
     * @return the start time of the token vesting.
     */
    function start() public view returns (uint256) {
        return _start;
    }
    
    /**
     * @return current time of the contract.
     */
    function currentTime() public view returns (uint256) {
        return block.timestamp;
    }
    
    /**
     * @return the total duration of the token vesting.
     */
    function totalDuration() public view returns (uint256) {
        return _totalDuration;
    }
    
    /**
     * @return true if the vesting is revocable.
     */
    function revocable() public view returns (bool) {
        return _revocable;
    }
    
    /**
     * @return the amount of the token released.
     */
    function released(address token) public view returns (uint256) {
        return _released[token];
    }
    
    /**
     * @return true if the token is revoked.
     */
    function revoked(address token) public view returns (bool) {
        return _revoked[token];
    }
    
    /**
     * @notice Transfers vested tokens to beneficiary.
     * @param token ERC20 token which is being vested
     */
    function release(IERC20 token) public {
        uint256 unreleased = _releasableAmount(token);

        require(unreleased > 0, "TokenTimelock: no tokens are due");

        _released[address(token)] = _released[address(token)].add(unreleased);

        token.transfer(_beneficiary, unreleased);

        emit TokensReleased(address(token), unreleased);
    }

    /**
     * @notice Allows the owner to revoke the vesting. Tokens already vested
     * remain in the contract, the rest are returned to the owner.
     * @param token ERC20 token which is being vested
     */
    function revoke(IERC20 token) public onlyOwner {
        require(_revocable, "TokenTimelock: cannot revoke");
        require(!_revoked[address(token)], "TokenTimelock: token already revoked");

        uint256 balance = token.balanceOf(address(this));

        uint256 unreleased = _releasableAmount(token);
        uint256 refund = balance.sub(unreleased);

        _revoked[address(token)] = true;

        token.transfer(owner(), refund);

        emit TokenTimelockRevoked(address(token));
    }
    
    /**
     * @dev Calculates the amount that has already vested but hasn't been released yet.
     * @param token ERC20 token which is being vested
     */
    function _releasableAmount(IERC20 token) private view returns (uint256) {
        return _vestedAmount(token).sub(_released[address(token)]);
    }
    
    /**
     * @dev Calculates the amount that should be vested totally.
     * @param token ERC20 token which is being vested
     */
    function _vestedAmount(IERC20 token) private view returns (uint256) {
        uint256 currentBalance = token.balanceOf(address(this));//token balance in TokenTimelock contract
        uint256 totalBalance = currentBalance.add(_released[address(token)]);//total balance in TokenTimelock contract
        
        uint256[4] memory periodEndTimestamp;
        periodEndTimestamp[0] = _start.add(_durationRatio[0]._periodDuration);
        periodEndTimestamp[1] = periodEndTimestamp[0].add(_durationRatio[1]._periodDuration);
        periodEndTimestamp[2] = periodEndTimestamp[1].add(_durationRatio[2]._periodDuration);
        periodEndTimestamp[3] = periodEndTimestamp[2].add(_durationRatio[3]._periodDuration);
        uint256 releaseRatio;
        if (block.timestamp < periodEndTimestamp[0]) {
            return 0;
        }else if(block.timestamp >= periodEndTimestamp[0] && block.timestamp < periodEndTimestamp[1]){
            releaseRatio = _durationRatio[0]._periodReleaseRatio;
        }else if(block.timestamp >= periodEndTimestamp[1] && block.timestamp < periodEndTimestamp[2]){
            releaseRatio = _durationRatio[0]._periodReleaseRatio.add(_durationRatio[1]._periodReleaseRatio);
        }else if(block.timestamp >= periodEndTimestamp[2] && block.timestamp < periodEndTimestamp[3]) {
            releaseRatio = _durationRatio[0]._periodReleaseRatio.add(_durationRatio[1]._periodReleaseRatio).add(_durationRatio[2]._periodReleaseRatio);
        } else {
            releaseRatio = 100;
        }
        return releaseRatio.mul(totalBalance).div(100);
    }
    
}
pragma solidity ^0.5.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () internal { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}
pragma solidity ^0.5.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
 */
interface IERC20 {
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
pragma solidity ^0.5.0;

import "./Context.sol";
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
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
     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
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
     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
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
     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
pragma solidity ^0.5.0;

import "./IERC20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

/**
 * @title TokenTimelock
 * @dev A token holder contract that can release its token balance gradually like a
 * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the
 * owner.
 * use this contract need :
 * 1.release ERC20 contract;
 * 2.configure and release TokenTimelock contract
 * 3.transfer ERC20 Tokens which need to be timelocked to TokenTimelock contract
 * 4.when time reached, call release() to release tokens to beneficiary
 * 
 * for example:
 * (D=Duration   R=ReleaseRatio)
 *      ^
 *      |
 *      |
 *  R4  |                ————
 *  R3  |            ————
 *  R2  |        ————
 *  R1  |    ———— 
 *      |         
 *      |——————————————————————————>
 *            D1  D2   D3  D4
 * 
 * start = 2019-1-1 00:00:00
 * D1=D2=D3=D4=1year
 * R1=10,R2=20,R3=30,R4=40  (please ensure R1+R2+R3+R4=100)
 * so, you will get below tokens in total
 *        Time                                     Tokens Get
 *   Start~Start+D1                                   0
 * Start+D1~Start+D1+D2                      10% total in this Timelock contract
 * Start+D1+D2~Start+D1+D2+D3              10%+20% total
 * Start+D1+D2+D3~Start+D1+D2+D3+D4        10%+20%+30% total
 * Start+D1+D2+D3+D4~infinity              10%+20%+30%+40% total(usually ensures 100 percent)
 */
contract TokenTimelock is Ownable {
    // The vesting schedule is time-based (i.e. using block timestamps as opposed to e.g. block numbers), and is
    // therefore sensitive to timestamp manipulation (which is something miners can do, to a certain degree). Therefore,
    // it is recommended to avoid using short time durations (less than a minute). Typical vesting schemes, with a
    // cliff period of a year and a duration of four years, are safe to use.
    // solhint-disable not-rely-on-time

    using SafeMath for uint256;

    event TokensReleased(address token, uint256 amount);
    event TokenTimelockRevoked(address token);

    // beneficiary of tokens after they are released
    address private _beneficiary;

    // Durations and timestamps are expressed in UNIX time, the same units as block.timestamp.
    
    uint256 private _start;
    uint256 private _totalDuration;
    
    //Durations and token release ratios expressed in UNIX time
    struct DurationsAndRatios{
        uint256 _periodDuration;
        uint256 _periodReleaseRatio;
    }
    DurationsAndRatios[4] _durationRatio;//four period of duration and ratios
    
    bool private _revocable;

    mapping (address => uint256) private _released;
    mapping (address => bool) private _revoked;

    /**
     * @dev Creates a vesting contract that vests its balance of any ERC20 token to the
     * beneficiary, gradually in a linear fashion until start + duration. By then all
     * of the balance will have vested.
     * @param beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param start the time (as Unix time) at which point vesting starts
     * @param firstDuration: first period duration
     * @param firstRatio: first period release ratio
     * @param secondDuration: second period duration
     * @param secondRatio: second period release ratio
     * @param thirdDuration: third period duration
     * @param thirdRatio: third period release ratio
     * @param fourthDuration: fourth period duration
     * @param fourthRatio: fourth period release ratio
     * @param revocable whether the vesting is revocable or not
     */
    constructor (address beneficiary, uint256 start, uint256 firstDuration,uint256 firstRatio,uint256 secondDuration, uint256 secondRatio,
    uint256 thirdDuration,uint256 thirdRatio,uint256 fourthDuration, uint256 fourthRatio,bool revocable) public {
        require(beneficiary != address(0), "TokenTimelock: beneficiary is the zero address");
        
        require(firstRatio.add(secondRatio).add(thirdRatio).add(fourthRatio)==100, "TokenTimelock: ratios added not equal 100.");
    
        _beneficiary = beneficiary;
        _revocable = revocable;
        _start = start;
        
        _durationRatio[0]._periodDuration = firstDuration;
        _durationRatio[1]._periodDuration = secondDuration;
        _durationRatio[2]._periodDuration = thirdDuration;
        _durationRatio[3]._periodDuration = fourthDuration;
        
        _durationRatio[0]._periodReleaseRatio = firstRatio;
        _durationRatio[1]._periodReleaseRatio = secondRatio;
        _durationRatio[2]._periodReleaseRatio = thirdRatio;
        _durationRatio[3]._periodReleaseRatio = fourthRatio;
        
        _totalDuration = firstDuration.add(secondDuration).add(thirdDuration).add(fourthDuration);
        require(_start.add(_totalDuration) > block.timestamp, "TokenTimelock: final time is before current time");
        
    }

    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    /**
     * @return the end time of every period.
     */
    function getDurationsAndRatios() public view returns (uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256) {
        return (_durationRatio[0]._periodDuration,_durationRatio[1]._periodDuration,_durationRatio[2]._periodDuration,_durationRatio[3]._periodDuration,
        _durationRatio[0]._periodReleaseRatio,_durationRatio[1]._periodReleaseRatio,_durationRatio[2]._periodReleaseRatio,_durationRatio[3]._periodReleaseRatio);
    }

    /**
     * @return the start time of the token vesting.
     */
    function start() public view returns (uint256) {
        return _start;
    }
    
    /**
     * @return current time of the contract.
     */
    function currentTime() public view returns (uint256) {
        return block.timestamp;
    }
    
    /**
     * @return the total duration of the token vesting.
     */
    function totalDuration() public view returns (uint256) {
        return _totalDuration;
    }
    
    /**
     * @return true if the vesting is revocable.
     */
    function revocable() public view returns (bool) {
        return _revocable;
    }
    
    /**
     * @return the amount of the token released.
     */
    function released(address token) public view returns (uint256) {
        return _released[token];
    }
    
    /**
     * @return true if the token is revoked.
     */
    function revoked(address token) public view returns (bool) {
        return _revoked[token];
    }
    
    /**
     * @notice Transfers vested tokens to beneficiary.
     * @param token ERC20 token which is being vested
     */
    function release(IERC20 token) public {
        uint256 unreleased = _releasableAmount(token);

        require(unreleased > 0, "TokenTimelock: no tokens are due");

        _released[address(token)] = _released[address(token)].add(unreleased);

        token.transfer(_beneficiary, unreleased);

        emit TokensReleased(address(token), unreleased);
    }

    /**
     * @notice Allows the owner to revoke the vesting. Tokens already vested
     * remain in the contract, the rest are returned to the owner.
     * @param token ERC20 token which is being vested
     */
    function revoke(IERC20 token) public onlyOwner {
        require(_revocable, "TokenTimelock: cannot revoke");
        require(!_revoked[address(token)], "TokenTimelock: token already revoked");

        uint256 balance = token.balanceOf(address(this));

        uint256 unreleased = _releasableAmount(token);
        uint256 refund = balance.sub(unreleased);

        _revoked[address(token)] = true;

        token.transfer(owner(), refund);

        emit TokenTimelockRevoked(address(token));
    }
    
    /**
     * @dev Calculates the amount that has already vested but hasn't been released yet.
     * @param token ERC20 token which is being vested
     */
    function _releasableAmount(IERC20 token) private view returns (uint256) {
        return _vestedAmount(token).sub(_released[address(token)]);
    }
    
    /**
     * @dev Calculates the amount that should be vested totally.
     * @param token ERC20 token which is being vested
     */
    function _vestedAmount(IERC20 token) private view returns (uint256) {
        uint256 currentBalance = token.balanceOf(address(this));//token balance in TokenTimelock contract
        uint256 totalBalance = currentBalance.add(_released[address(token)]);//total balance in TokenTimelock contract
        
        uint256[4] memory periodEndTimestamp;
        periodEndTimestamp[0] = _start.add(_durationRatio[0]._periodDuration);
        periodEndTimestamp[1] = periodEndTimestamp[0].add(_durationRatio[1]._periodDuration);
        periodEndTimestamp[2] = periodEndTimestamp[1].add(_durationRatio[2]._periodDuration);
        periodEndTimestamp[3] = periodEndTimestamp[2].add(_durationRatio[3]._periodDuration);
        uint256 releaseRatio;
        if (block.timestamp < periodEndTimestamp[0]) {
            return 0;
        }else if(block.timestamp >= periodEndTimestamp[0] && block.timestamp < periodEndTimestamp[1]){
            releaseRatio = _durationRatio[0]._periodReleaseRatio;
        }else if(block.timestamp >= periodEndTimestamp[1] && block.timestamp < periodEndTimestamp[2]){
            releaseRatio = _durationRatio[0]._periodReleaseRatio.add(_durationRatio[1]._periodReleaseRatio);
        }else if(block.timestamp >= periodEndTimestamp[2] && block.timestamp < periodEndTimestamp[3]) {
            releaseRatio = _durationRatio[0]._periodReleaseRatio.add(_durationRatio[1]._periodReleaseRatio).add(_durationRatio[2]._periodReleaseRatio);
        } else {
            releaseRatio = 100;
        }
        return releaseRatio.mul(totalBalance).div(100);
    }
    
}
