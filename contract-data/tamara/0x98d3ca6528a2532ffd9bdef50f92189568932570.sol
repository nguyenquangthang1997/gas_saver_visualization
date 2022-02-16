pragma solidity ^0.5.3;


import "./ERC20Basic.sol";
import "./SafeMath.sol";


/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
contract BasicToken is ERC20Basic {
  using SafeMath for uint256;

  mapping(address => uint256) balances;

  uint256 totalSupply_;

  /**
  * @dev total number of tokens in existence
  */
  function totalSupply() public view returns (uint256) {
    return totalSupply_;
  }

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);

    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }

}

pragma solidity ^0.5.3;

import "./BasicToken.sol";


/**
 * @title Burnable Token
 * @dev Token that can be irreversibly burned (destroyed).
 */
contract BurnableToken is BasicToken {

  event Burn(address indexed burner, uint256 value);

  /**
   * @dev Burns a specific amount of tokens.
   * @param _value The amount of token to be burned.
   */
  function burn(uint256 _value) public {
    require(_value <= balances[msg.sender]);
    // no need to require value <= totalSupply, since that would imply the
    // sender's balance is greater than the totalSupply, which *should* be an assertion failure

    address burner = msg.sender;
    balances[burner] = balances[burner].sub(_value);
    totalSupply_ = totalSupply_.sub(_value);
    emit Burn(burner, _value);
    emit Transfer(burner, address(0), _value);
  }
}

pragma solidity ^0.5.3;

import "./ERC20Basic.sol";


/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity ^0.5.3;


/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

pragma solidity 0.5.11;

import "./Ownable.sol";
import "./GolemNetworkTokenBatching.sol";
import "./ReceivingContract.sol";

contract GNTDeposit is ReceivingContract, Ownable {
    using SafeMath for uint256;

    address public concent;
    address public coldwallet;

    // Deposit will be locked for this much longer after unlocking and before
    // it's possible to withdraw.
    uint256 public withdrawal_delay;

    // Contract will not accept new deposits if the total amount of tokens it
    // holds would exceed this amount.
    uint256 public maximum_deposits_total;
    // Maximum deposit value per user.
    uint256 public maximum_deposit_amount;

    // Limit amount of tokens Concent can reimburse within a single day.
    uint256 public daily_reimbursement_limit;
    uint256 private current_reimbursement_day;
    uint256 private current_reimbursement_sum;

    GolemNetworkTokenBatching public token;
    // owner => amount
    mapping (address => uint256) public balances;
    // owner => timestamp after which withdraw is possible
    //        | 0 if locked
    mapping (address => uint256) public locked_until;

    event ConcentTransferred(address indexed _previousConcent, address indexed _newConcent);
    event ColdwalletTransferred(address indexed _previousColdwallet, address indexed _newColdwallet);
    event Deposit(address indexed _owner, uint256 _amount);
    event Withdraw(address indexed _from, address indexed _to, uint256 _amount);
    event Lock(address indexed _owner);
    event Unlock(address indexed _owner);
    event Burn(address indexed _who, uint256 _amount);
    event ReimburseForSubtask(address indexed _requestor, address indexed _provider, uint256 _amount, bytes32 _subtask_id);
    event ReimburseForNoPayment(address indexed _requestor, address indexed _provider, uint256 _amount, uint256 _closure_time);
    event ReimburseForVerificationCosts(address indexed _from, uint256 _amount, bytes32 _subtask_id);
    event ReimburseForCommunication(address indexed _from, uint256 _amount);

    constructor(
        GolemNetworkTokenBatching _token,
        address _concent,
        address _coldwallet,
        uint256 _withdrawal_delay
    )
        public
    {
        token = _token;
        concent = _concent;
        coldwallet = _coldwallet;
        withdrawal_delay = _withdrawal_delay;
    }

    // modifiers

    modifier onlyUnlocked() {
        require(isUnlocked(msg.sender), "Deposit is not unlocked");
        _;
    }

    modifier onlyConcent() {
        require(msg.sender == concent, "Concent only method");
        _;
    }

    modifier onlyToken() {
        require(msg.sender == address(token), "Token only method");
        _;
    }

    // views

    function balanceOf(address _owner) external view returns (uint256) {
        return balances[_owner];
    }

    function isLocked(address _owner) external view returns (bool) {
        return locked_until[_owner] == 0;
    }

    function isTimeLocked(address _owner) external view returns (bool) {
        return locked_until[_owner] > block.timestamp;
    }

    function isUnlocked(address _owner) public view returns (bool) {
        return locked_until[_owner] != 0 && locked_until[_owner] < block.timestamp;
    }

    function getTimelock(address _owner) external view returns (uint256) {
        return locked_until[_owner];
    }

    function isDepositPossible(address _owner, uint256 _amount) external view returns (bool) {
        return !_isTotalDepositsLimitHit(_amount) && !_isMaximumDepositLimitHit(_owner, _amount);
    }

    // management

    function transferConcent(address _newConcent) onlyOwner external {
        require(_newConcent != address(0), "New concent address cannot be 0");
        emit ConcentTransferred(concent, _newConcent);
        concent = _newConcent;
    }

    function transferColdwallet(address _newColdwallet) onlyOwner external {
        require(_newColdwallet != address(0), "New coldwallet address cannot be 0");
        emit ColdwalletTransferred(coldwallet, _newColdwallet);
        coldwallet = _newColdwallet;
    }

    function setMaximumDepositsTotal(uint256 _value) onlyOwner external {
        maximum_deposits_total = _value;
    }

    function setMaximumDepositAmount(uint256 _value) onlyOwner external {
        maximum_deposit_amount = _value;
    }

    function setDailyReimbursementLimit(uint256 _value) onlyOwner external {
        daily_reimbursement_limit = _value;
    }

    // deposit API

    function unlock() external {
        locked_until[msg.sender] = block.timestamp + withdrawal_delay;
        emit Unlock(msg.sender);
    }

    function lock() external {
        locked_until[msg.sender] = 0;
        emit Lock(msg.sender);
    }

    function onTokenReceived(address _from, uint256 _amount, bytes calldata /* _data */) external onlyToken {
        // Pass 0 as the amount since this check happens post transfer, thus
        // amount is already accounted for in the balance
        require(!_isTotalDepositsLimitHit(0), "Total deposits limit hit");
        require(!_isMaximumDepositLimitHit(_from, _amount), "Maximum deposit limit hit");
        balances[_from] += _amount;
        locked_until[_from] = 0;
        emit Deposit(_from, _amount);
    }

    function withdraw(address _to) onlyUnlocked external {
        uint256 _amount = balances[msg.sender];
        balances[msg.sender] = 0;
        locked_until[msg.sender] = 0;
        require(token.transfer(_to, _amount));
        emit Withdraw(msg.sender, _to, _amount);
    }

    function burn(address _whom, uint256 _amount) onlyConcent external {
        require(balances[_whom] >= _amount, "Not enough funds to burn");
        balances[_whom] -= _amount;
        if (balances[_whom] == 0) {
            locked_until[_whom] = 0;
        }
        token.burn(_amount);
        emit Burn(_whom, _amount);
    }

    function reimburseForSubtask(
        address _requestor,
        address _provider,
        uint256 _amount,
        bytes32 _subtask_id,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        uint256 _reimburse_amount
    )
        onlyConcent
        external
    {
        require(_isValidSignature(_requestor, _provider, _amount, _subtask_id, _v, _r, _s), "Invalid signature");
        require(_reimburse_amount <= _amount, "Reimburse amount exceeds allowed");
        _reimburse(_requestor, _provider, _reimburse_amount);
        emit ReimburseForSubtask(_requestor, _provider, _reimburse_amount, _subtask_id);
    }

    function reimburseForNoPayment(
        address _requestor,
        address _provider,
        uint256[] calldata _amount,
        bytes32[] calldata _subtask_id,
        uint8[] calldata _v,
        bytes32[] calldata _r,
        bytes32[] calldata _s,
        uint256 _reimburse_amount,
        uint256 _closure_time
    )
        onlyConcent
        external
    {
        require(_amount.length == _subtask_id.length);
        require(_amount.length == _v.length);
        require(_amount.length == _r.length);
        require(_amount.length == _s.length);
        // Can't merge the following two loops as we exceed the number of veriables on the stack
        // and the compiler gives: CompilerError: Stack too deep, try removing local variables.
        for (uint256 i = 0; i < _amount.length; i++) {
          require(_isValidSignature(_requestor, _provider, _amount[i], _subtask_id[i], _v[i], _r[i], _s[i]), "Invalid signature");
        }
        uint256 total_amount = 0;
        for (uint256 i = 0; i < _amount.length; i++) {
          total_amount += _amount[i];
        }
        require(_reimburse_amount <= total_amount, "Reimburse amount exceeds total");
        _reimburse(_requestor, _provider, _reimburse_amount);
        emit ReimburseForNoPayment(_requestor, _provider, _reimburse_amount, _closure_time);
    }

    function reimburseForVerificationCosts(
        address _from,
        uint256 _amount,
        bytes32 _subtask_id,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        uint256 _reimburse_amount
    )
        onlyConcent
        external
    {
        require(_isValidSignature(_from, address(this), _amount, _subtask_id, _v, _r, _s), "Invalid signature");
        require(_reimburse_amount <= _amount, "Reimburse amount exceeds allowed");
        _reimburse(_from, coldwallet, _reimburse_amount);
        emit ReimburseForVerificationCosts(_from, _reimburse_amount, _subtask_id);
    }

    function reimburseForCommunication(
        address _from,
        uint256 _amount
    )
        onlyConcent
        external
    {
        _reimburse(_from, coldwallet, _amount);
        emit ReimburseForCommunication(_from, _amount);
    }

    // internals

    function _reimburse(address _from, address _to, uint256 _amount) private {
        require(balances[_from] >= _amount, "Not enough funds to reimburse");
        if (daily_reimbursement_limit != 0) {
            if (current_reimbursement_day != block.timestamp / 1 days) {
                current_reimbursement_day = block.timestamp / 1 days;
                current_reimbursement_sum = 0;
            }
            require(current_reimbursement_sum + _amount <= daily_reimbursement_limit, "Daily reimbursement limit hit");
            current_reimbursement_sum += _amount;
        }
        balances[_from] -= _amount;
        if (balances[_from] == 0) {
            locked_until[_from] = 0;
        }
        require(token.transfer(_to, _amount));
    }

    function _isTotalDepositsLimitHit(uint256 _amount) private view returns (bool) {
        if (maximum_deposits_total == 0) {
            return false;
        }
        return token.balanceOf(address(this)).add(_amount) > maximum_deposits_total;
    }

    function _isMaximumDepositLimitHit(address _owner, uint256 _amount) private view returns (bool) {
        if (maximum_deposit_amount == 0) {
            return false;
        }
        return balances[_owner].add(_amount) > maximum_deposit_amount;
    }

    function _isValidSignature(
        address _from,
        address _to,
        uint256 _amount,
        bytes32 _subtask_id,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public view returns (bool) {
        // Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf)
        // describes what constitutes a valid signature.
        if (uint256(_s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return false;
        }
        if (_v != 27 && _v != 28) {
            return false;
        }
        return _from == ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n124", address(this), _from, _to, _amount, _subtask_id)), _v, _r, _s);
    }

}

// Copyright 2018 Golem Factory
// Licensed under the GNU General Public License v3. See the LICENSE file.

pragma solidity ^0.5.3;

import "./ReceivingContract.sol";
import "./TokenProxy.sol";


/// GolemNetworkTokenBatching can be treated as an upgraded GolemNetworkToken.
/// 1. It is fully ERC20 compliant (GNT is missing approve and transferFrom)
/// 2. It implements slightly modified ERC677 (transferAndCall method)
/// 3. It provides batchTransfer method - an optimized way of executing multiple transfers
///
/// On how to convert between GNT and GNTB see TokenProxy documentation.
contract GolemNetworkTokenBatching is TokenProxy {

    string public constant name = "Golem Network Token Batching";
    string public constant symbol = "GNTB";
    uint8 public constant decimals = 18;


    event BatchTransfer(address indexed from, address indexed to, uint256 value,
        uint64 closureTime);

    constructor(ERC20Basic _gntToken) TokenProxy(_gntToken) public {
    }

    function batchTransfer(bytes32[] calldata payments, uint64 closureTime) external {
        require(block.timestamp >= closureTime);

        uint balance = balances[msg.sender];

        for (uint i = 0; i < payments.length; ++i) {
            // A payment contains compressed data:
            // first 96 bits (12 bytes) is a value,
            // following 160 bits (20 bytes) is an address.
            bytes32 payment = payments[i];
            address addr = address(uint256(payment));
            require(addr != address(0) && addr != msg.sender);
            uint v = uint(payment) / 2**160;
            require(v <= balance);
            balances[addr] += v;
            balance -= v;
            emit BatchTransfer(msg.sender, addr, v, closureTime);
        }

        balances[msg.sender] = balance;
    }

    function transferAndCall(address to, uint256 value, bytes calldata data) external {
      // Transfer always returns true so no need to check return value
      transfer(to, value);

      // No need to check whether recipient is a contract, this method is
      // supposed to used only with contract recipients
      ReceivingContract(to).onTokenReceived(msg.sender, value, data);
    }
}

pragma solidity ^0.5.3;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Owner only method");
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * @notice Renouncing to ownership will leave the contract without an owner.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

pragma solidity 0.5.11;

/// Contracts implementing this interface are compatible with
/// GolemNetworkTokenBatching's transferAndCall method
contract ReceivingContract {
    function onTokenReceived(address _from, uint _value, bytes calldata _data) external;
}

pragma solidity ^0.5.3;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

pragma solidity ^0.5.3;

import "./BasicToken.sol";
import "./ERC20.sol";


/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * @dev https://github.com/ethereum/EIPs/issues/20
 * @dev Based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract StandardToken is ERC20, BasicToken {

  mapping (address => mapping (address => uint256)) internal allowed;


  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    emit Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    require(allowed[msg.sender][_spender] == 0);
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public view returns (uint256) {
    return allowed[_owner][_spender];
  }

  /**
   * @dev Increase the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _addedValue The amount of tokens to increase the allowance by.
   */
  function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  /**
   * @dev Decrease the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To decrement
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _subtractedValue The amount of tokens to decrease the allowance by.
   */
  function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

}

// Copyright 2018 Golem Factory
// Licensed under the GNU General Public License v3. See the LICENSE file.

pragma solidity ^0.5.3;

import "./BurnableToken.sol";
import "./StandardToken.sol";

/// The Gate is a contract with unique address to allow a token holder
/// (called "User") to transfer tokens from original Token to the Proxy.
///
/// The Gate does not know who its User is. The User-Gate relationship is
/// managed by the Proxy.
contract Gate {
    ERC20Basic private TOKEN;
    address private PROXY;

    /// Gates are to be created by the TokenProxy.
    constructor(ERC20Basic _token, address _proxy) public {
        TOKEN = _token;
        PROXY = _proxy;
    }

    /// Transfer requested amount of tokens from Gate to Proxy address.
    /// Only the Proxy can request this and should request transfer of all
    /// tokens.
    function transferToProxy(uint256 _value) public {
        require(msg.sender == PROXY);

        require(TOKEN.transfer(PROXY, _value));
    }
}


/// The Proxy for existing tokens implementing a subset of ERC20 interface.
///
/// This contract creates a token Proxy contract to extend the original Token
/// contract interface. The Proxy requires only transfer() and balanceOf()
/// methods from ERC20 to be implemented in the original Token contract.
///
/// All migrated tokens are in Proxy's account on the Token side and distributed
/// among Users on the Proxy side.
///
/// For an user to migrate some amount of ones tokens from Token to Proxy
/// the procedure is as follows.
///
/// 1. Create an individual Gate for migration. The Gate address will be
///    reported with the GateOpened event and accessible by getGateAddress().
/// 2. Transfer tokens to be migrated to the Gate address.
/// 3. Execute Proxy.transferFromGate() to finalize the migration.
///
/// In the step 3 the User's tokens are going to be moved from the Gate to
/// the User's balance in the Proxy.
contract TokenProxy is StandardToken, BurnableToken {

    ERC20Basic public TOKEN;

    mapping(address => address) private gates;


    event GateOpened(address indexed gate, address indexed user);

    event Mint(address indexed to, uint256 amount);

    constructor(ERC20Basic _token) public {
        TOKEN = _token;
    }

    function getGateAddress(address _user) external view returns (address) {
        return gates[_user];
    }

    /// Create a new migration Gate for the User.
    function openGate() external {
        address user = msg.sender;

        // Do not allow creating more than one Gate per User.
        require(gates[user] == address(0));

        // Create new Gate.
        address gate = address(new Gate(TOKEN, address(this)));

        // Remember User - Gate relationship.
        gates[user] = gate;

        emit GateOpened(gate, user);
    }

    function transferFromGate() external {
        address user = msg.sender;

        address gate = gates[user];

        // Make sure the User's Gate exists.
        require(gate != address(0));

        uint256 value = TOKEN.balanceOf(gate);

        Gate(gate).transferToProxy(value);

        // Handle the information about the amount of migrated tokens.
        // This is a trusted information becase it comes from the Gate.
        totalSupply_ += value;
        balances[user] += value;

        emit Mint(user, value);
    }

    function withdraw(uint256 _value) external {
        withdrawTo(_value, msg.sender);
    }

    function withdrawTo(uint256 _value, address _destination) public {
        require(_value > 0 && _destination != address(0));
        burn(_value);
        TOKEN.transfer(_destination, _value);
    }
}

pragma solidity ^0.5.3;


import "./ERC20Basic.sol";
import "./SafeMath.sol";


/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
contract BasicToken is ERC20Basic {
  using SafeMath for uint256;

  mapping(address => uint256) balances;

  uint256 totalSupply_;

  /**
  * @dev total number of tokens in existence
  */
  function totalSupply() public view returns (uint256) {
    return totalSupply_;
  }

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);

    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }

}

pragma solidity ^0.5.3;

import "./BasicToken.sol";


/**
 * @title Burnable Token
 * @dev Token that can be irreversibly burned (destroyed).
 */
contract BurnableToken is BasicToken {

  event Burn(address indexed burner, uint256 value);

  /**
   * @dev Burns a specific amount of tokens.
   * @param _value The amount of token to be burned.
   */
  function burn(uint256 _value) public {
    require(_value <= balances[msg.sender]);
    // no need to require value <= totalSupply, since that would imply the
    // sender's balance is greater than the totalSupply, which *should* be an assertion failure

    address burner = msg.sender;
    balances[burner] = balances[burner].sub(_value);
    totalSupply_ = totalSupply_.sub(_value);
    emit Burn(burner, _value);
    emit Transfer(burner, address(0), _value);
  }
}

pragma solidity ^0.5.3;

import "./ERC20Basic.sol";


/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity ^0.5.3;


/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

pragma solidity 0.5.11;

import "./Ownable.sol";
import "./GolemNetworkTokenBatching.sol";
import "./ReceivingContract.sol";

contract GNTDeposit is ReceivingContract, Ownable {
    using SafeMath for uint256;

    address public concent;
    address public coldwallet;

    // Deposit will be locked for this much longer after unlocking and before
    // it's possible to withdraw.
    uint256 public withdrawal_delay;

    // Contract will not accept new deposits if the total amount of tokens it
    // holds would exceed this amount.
    uint256 public maximum_deposits_total;
    // Maximum deposit value per user.
    uint256 public maximum_deposit_amount;

    // Limit amount of tokens Concent can reimburse within a single day.
    uint256 public daily_reimbursement_limit;
    uint256 private current_reimbursement_day;
    uint256 private current_reimbursement_sum;

    GolemNetworkTokenBatching public token;
    // owner => amount
    mapping (address => uint256) public balances;
    // owner => timestamp after which withdraw is possible
    //        | 0 if locked
    mapping (address => uint256) public locked_until;

    event ConcentTransferred(address indexed _previousConcent, address indexed _newConcent);
    event ColdwalletTransferred(address indexed _previousColdwallet, address indexed _newColdwallet);
    event Deposit(address indexed _owner, uint256 _amount);
    event Withdraw(address indexed _from, address indexed _to, uint256 _amount);
    event Lock(address indexed _owner);
    event Unlock(address indexed _owner);
    event Burn(address indexed _who, uint256 _amount);
    event ReimburseForSubtask(address indexed _requestor, address indexed _provider, uint256 _amount, bytes32 _subtask_id);
    event ReimburseForNoPayment(address indexed _requestor, address indexed _provider, uint256 _amount, uint256 _closure_time);
    event ReimburseForVerificationCosts(address indexed _from, uint256 _amount, bytes32 _subtask_id);
    event ReimburseForCommunication(address indexed _from, uint256 _amount);

    constructor(
        GolemNetworkTokenBatching _token,
        address _concent,
        address _coldwallet,
        uint256 _withdrawal_delay
    )
        public
    {
        token = _token;
        concent = _concent;
        coldwallet = _coldwallet;
        withdrawal_delay = _withdrawal_delay;
    }

    // modifiers

    modifier onlyUnlocked() {
        require(isUnlocked(msg.sender), "Deposit is not unlocked");
        _;
    }

    modifier onlyConcent() {
        require(msg.sender == concent, "Concent only method");
        _;
    }

    modifier onlyToken() {
        require(msg.sender == address(token), "Token only method");
        _;
    }

    // views

    function balanceOf(address _owner) external view returns (uint256) {
        return balances[_owner];
    }

    function isLocked(address _owner) external view returns (bool) {
        return locked_until[_owner] == 0;
    }

    function isTimeLocked(address _owner) external view returns (bool) {
        return locked_until[_owner] > block.timestamp;
    }

    function isUnlocked(address _owner) public view returns (bool) {
        return locked_until[_owner] != 0 && locked_until[_owner] < block.timestamp;
    }

    function getTimelock(address _owner) external view returns (uint256) {
        return locked_until[_owner];
    }

    function isDepositPossible(address _owner, uint256 _amount) external view returns (bool) {
        return !_isTotalDepositsLimitHit(_amount) && !_isMaximumDepositLimitHit(_owner, _amount);
    }

    // management

    function transferConcent(address _newConcent) onlyOwner external {
        require(_newConcent != address(0), "New concent address cannot be 0");
        emit ConcentTransferred(concent, _newConcent);
        concent = _newConcent;
    }

    function transferColdwallet(address _newColdwallet) onlyOwner external {
        require(_newColdwallet != address(0), "New coldwallet address cannot be 0");
        emit ColdwalletTransferred(coldwallet, _newColdwallet);
        coldwallet = _newColdwallet;
    }

    function setMaximumDepositsTotal(uint256 _value) onlyOwner external {
        maximum_deposits_total = _value;
    }

    function setMaximumDepositAmount(uint256 _value) onlyOwner external {
        maximum_deposit_amount = _value;
    }

    function setDailyReimbursementLimit(uint256 _value) onlyOwner external {
        daily_reimbursement_limit = _value;
    }

    // deposit API

    function unlock() external {
        locked_until[msg.sender] = block.timestamp + withdrawal_delay;
        emit Unlock(msg.sender);
    }

    function lock() external {
        locked_until[msg.sender] = 0;
        emit Lock(msg.sender);
    }

    function onTokenReceived(address _from, uint256 _amount, bytes calldata /* _data */) external onlyToken {
        // Pass 0 as the amount since this check happens post transfer, thus
        // amount is already accounted for in the balance
        require(!_isTotalDepositsLimitHit(0), "Total deposits limit hit");
        require(!_isMaximumDepositLimitHit(_from, _amount), "Maximum deposit limit hit");
        balances[_from] += _amount;
        locked_until[_from] = 0;
        emit Deposit(_from, _amount);
    }

    function withdraw(address _to) onlyUnlocked external {
        uint256 _amount = balances[msg.sender];
        balances[msg.sender] = 0;
        locked_until[msg.sender] = 0;
        require(token.transfer(_to, _amount));
        emit Withdraw(msg.sender, _to, _amount);
    }

    function burn(address _whom, uint256 _amount) onlyConcent external {
        require(balances[_whom] >= _amount, "Not enough funds to burn");
        balances[_whom] -= _amount;
        if (balances[_whom] == 0) {
            locked_until[_whom] = 0;
        }
        token.burn(_amount);
        emit Burn(_whom, _amount);
    }

    function reimburseForSubtask(
        address _requestor,
        address _provider,
        uint256 _amount,
        bytes32 _subtask_id,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        uint256 _reimburse_amount
    )
        onlyConcent
        external
    {
        require(_isValidSignature(_requestor, _provider, _amount, _subtask_id, _v, _r, _s), "Invalid signature");
        require(_reimburse_amount <= _amount, "Reimburse amount exceeds allowed");
        _reimburse(_requestor, _provider, _reimburse_amount);
        emit ReimburseForSubtask(_requestor, _provider, _reimburse_amount, _subtask_id);
    }

    function reimburseForNoPayment(
        address _requestor,
        address _provider,
        uint256[] calldata _amount,
        bytes32[] calldata _subtask_id,
        uint8[] calldata _v,
        bytes32[] calldata _r,
        bytes32[] calldata _s,
        uint256 _reimburse_amount,
        uint256 _closure_time
    )
        onlyConcent
        external
    {
        require(_amount.length == _subtask_id.length);
        require(_amount.length == _v.length);
        require(_amount.length == _r.length);
        require(_amount.length == _s.length);
        // Can't merge the following two loops as we exceed the number of veriables on the stack
        // and the compiler gives: CompilerError: Stack too deep, try removing local variables.
        for (uint256 i = 0; i < _amount.length; i++) {
          require(_isValidSignature(_requestor, _provider, _amount[i], _subtask_id[i], _v[i], _r[i], _s[i]), "Invalid signature");
        }
        uint256 total_amount = 0;
        for (uint256 i = 0; i < _amount.length; i++) {
          total_amount += _amount[i];
        }
        require(_reimburse_amount <= total_amount, "Reimburse amount exceeds total");
        _reimburse(_requestor, _provider, _reimburse_amount);
        emit ReimburseForNoPayment(_requestor, _provider, _reimburse_amount, _closure_time);
    }

    function reimburseForVerificationCosts(
        address _from,
        uint256 _amount,
        bytes32 _subtask_id,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        uint256 _reimburse_amount
    )
        onlyConcent
        external
    {
        require(_isValidSignature(_from, address(this), _amount, _subtask_id, _v, _r, _s), "Invalid signature");
        require(_reimburse_amount <= _amount, "Reimburse amount exceeds allowed");
        _reimburse(_from, coldwallet, _reimburse_amount);
        emit ReimburseForVerificationCosts(_from, _reimburse_amount, _subtask_id);
    }

    function reimburseForCommunication(
        address _from,
        uint256 _amount
    )
        onlyConcent
        external
    {
        _reimburse(_from, coldwallet, _amount);
        emit ReimburseForCommunication(_from, _amount);
    }

    // internals

    function _reimburse(address _from, address _to, uint256 _amount) private {
        require(balances[_from] >= _amount, "Not enough funds to reimburse");
        if (daily_reimbursement_limit != 0) {
            if (current_reimbursement_day != block.timestamp / 1 days) {
                current_reimbursement_day = block.timestamp / 1 days;
                current_reimbursement_sum = 0;
            }
            require(current_reimbursement_sum + _amount <= daily_reimbursement_limit, "Daily reimbursement limit hit");
            current_reimbursement_sum += _amount;
        }
        balances[_from] -= _amount;
        if (balances[_from] == 0) {
            locked_until[_from] = 0;
        }
        require(token.transfer(_to, _amount));
    }

    function _isTotalDepositsLimitHit(uint256 _amount) private view returns (bool) {
        if (maximum_deposits_total == 0) {
            return false;
        }
        return token.balanceOf(address(this)).add(_amount) > maximum_deposits_total;
    }

    function _isMaximumDepositLimitHit(address _owner, uint256 _amount) private view returns (bool) {
        if (maximum_deposit_amount == 0) {
            return false;
        }
        return balances[_owner].add(_amount) > maximum_deposit_amount;
    }

    function _isValidSignature(
        address _from,
        address _to,
        uint256 _amount,
        bytes32 _subtask_id,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public view returns (bool) {
        // Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf)
        // describes what constitutes a valid signature.
        if (uint256(_s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return false;
        }
        if (_v != 27 && _v != 28) {
            return false;
        }
        return _from == ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n124", address(this), _from, _to, _amount, _subtask_id)), _v, _r, _s);
    }

}

// Copyright 2018 Golem Factory
// Licensed under the GNU General Public License v3. See the LICENSE file.

pragma solidity ^0.5.3;

import "./ReceivingContract.sol";
import "./TokenProxy.sol";


/// GolemNetworkTokenBatching can be treated as an upgraded GolemNetworkToken.
/// 1. It is fully ERC20 compliant (GNT is missing approve and transferFrom)
/// 2. It implements slightly modified ERC677 (transferAndCall method)
/// 3. It provides batchTransfer method - an optimized way of executing multiple transfers
///
/// On how to convert between GNT and GNTB see TokenProxy documentation.
contract GolemNetworkTokenBatching is TokenProxy {

    string public constant name = "Golem Network Token Batching";
    string public constant symbol = "GNTB";
    uint8 public constant decimals = 18;


    event BatchTransfer(address indexed from, address indexed to, uint256 value,
        uint64 closureTime);

    constructor(ERC20Basic _gntToken) TokenProxy(_gntToken) public {
    }

    function batchTransfer(bytes32[] calldata payments, uint64 closureTime) external {
        require(block.timestamp >= closureTime);

        uint balance = balances[msg.sender];

        for (uint i = 0; i < payments.length; ++i) {
            // A payment contains compressed data:
            // first 96 bits (12 bytes) is a value,
            // following 160 bits (20 bytes) is an address.
            bytes32 payment = payments[i];
            address addr = address(uint256(payment));
            require(addr != address(0) && addr != msg.sender);
            uint v = uint(payment) / 2**160;
            require(v <= balance);
            balances[addr] += v;
            balance -= v;
            emit BatchTransfer(msg.sender, addr, v, closureTime);
        }

        balances[msg.sender] = balance;
    }

    function transferAndCall(address to, uint256 value, bytes calldata data) external {
      // Transfer always returns true so no need to check return value
      transfer(to, value);

      // No need to check whether recipient is a contract, this method is
      // supposed to used only with contract recipients
      ReceivingContract(to).onTokenReceived(msg.sender, value, data);
    }
}

pragma solidity ^0.5.3;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Owner only method");
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * @notice Renouncing to ownership will leave the contract without an owner.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

pragma solidity 0.5.11;

/// Contracts implementing this interface are compatible with
/// GolemNetworkTokenBatching's transferAndCall method
contract ReceivingContract {
    function onTokenReceived(address _from, uint _value, bytes calldata _data) external;
}

pragma solidity ^0.5.3;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

pragma solidity ^0.5.3;

import "./BasicToken.sol";
import "./ERC20.sol";


/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * @dev https://github.com/ethereum/EIPs/issues/20
 * @dev Based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract StandardToken is ERC20, BasicToken {

  mapping (address => mapping (address => uint256)) internal allowed;


  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    emit Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    require(allowed[msg.sender][_spender] == 0);
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public view returns (uint256) {
    return allowed[_owner][_spender];
  }

  /**
   * @dev Increase the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _addedValue The amount of tokens to increase the allowance by.
   */
  function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  /**
   * @dev Decrease the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To decrement
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _subtractedValue The amount of tokens to decrease the allowance by.
   */
  function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

}

// Copyright 2018 Golem Factory
// Licensed under the GNU General Public License v3. See the LICENSE file.

pragma solidity ^0.5.3;

import "./BurnableToken.sol";
import "./StandardToken.sol";

/// The Gate is a contract with unique address to allow a token holder
/// (called "User") to transfer tokens from original Token to the Proxy.
///
/// The Gate does not know who its User is. The User-Gate relationship is
/// managed by the Proxy.
contract Gate {
    ERC20Basic private TOKEN;
    address private PROXY;

    /// Gates are to be created by the TokenProxy.
    constructor(ERC20Basic _token, address _proxy) public {
        TOKEN = _token;
        PROXY = _proxy;
    }

    /// Transfer requested amount of tokens from Gate to Proxy address.
    /// Only the Proxy can request this and should request transfer of all
    /// tokens.
    function transferToProxy(uint256 _value) public {
        require(msg.sender == PROXY);

        require(TOKEN.transfer(PROXY, _value));
    }
}


/// The Proxy for existing tokens implementing a subset of ERC20 interface.
///
/// This contract creates a token Proxy contract to extend the original Token
/// contract interface. The Proxy requires only transfer() and balanceOf()
/// methods from ERC20 to be implemented in the original Token contract.
///
/// All migrated tokens are in Proxy's account on the Token side and distributed
/// among Users on the Proxy side.
///
/// For an user to migrate some amount of ones tokens from Token to Proxy
/// the procedure is as follows.
///
/// 1. Create an individual Gate for migration. The Gate address will be
///    reported with the GateOpened event and accessible by getGateAddress().
/// 2. Transfer tokens to be migrated to the Gate address.
/// 3. Execute Proxy.transferFromGate() to finalize the migration.
///
/// In the step 3 the User's tokens are going to be moved from the Gate to
/// the User's balance in the Proxy.
contract TokenProxy is StandardToken, BurnableToken {

    ERC20Basic public TOKEN;

    mapping(address => address) private gates;


    event GateOpened(address indexed gate, address indexed user);

    event Mint(address indexed to, uint256 amount);

    constructor(ERC20Basic _token) public {
        TOKEN = _token;
    }

    function getGateAddress(address _user) external view returns (address) {
        return gates[_user];
    }

    /// Create a new migration Gate for the User.
    function openGate() external {
        address user = msg.sender;

        // Do not allow creating more than one Gate per User.
        require(gates[user] == address(0));

        // Create new Gate.
        address gate = address(new Gate(TOKEN, address(this)));

        // Remember User - Gate relationship.
        gates[user] = gate;

        emit GateOpened(gate, user);
    }

    function transferFromGate() external {
        address user = msg.sender;

        address gate = gates[user];

        // Make sure the User's Gate exists.
        require(gate != address(0));

        uint256 value = TOKEN.balanceOf(gate);

        Gate(gate).transferToProxy(value);

        // Handle the information about the amount of migrated tokens.
        // This is a trusted information becase it comes from the Gate.
        totalSupply_ += value;
        balances[user] += value;

        emit Mint(user, value);
    }

    function withdraw(uint256 _value) external {
        withdrawTo(_value, msg.sender);
    }

    function withdrawTo(uint256 _value, address _destination) public {
        require(_value > 0 && _destination != address(0));
        burn(_value);
        TOKEN.transfer(_destination, _value);
    }
}

pragma solidity ^0.5.3;


import "./ERC20Basic.sol";
import "./SafeMath.sol";


/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
contract BasicToken is ERC20Basic {
  using SafeMath for uint256;

  mapping(address => uint256) balances;

  uint256 totalSupply_;

  /**
  * @dev total number of tokens in existence
  */
  function totalSupply() public view returns (uint256) {
    return totalSupply_;
  }

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);

    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }

}

pragma solidity ^0.5.3;

import "./BasicToken.sol";


/**
 * @title Burnable Token
 * @dev Token that can be irreversibly burned (destroyed).
 */
contract BurnableToken is BasicToken {

  event Burn(address indexed burner, uint256 value);

  /**
   * @dev Burns a specific amount of tokens.
   * @param _value The amount of token to be burned.
   */
  function burn(uint256 _value) public {
    require(_value <= balances[msg.sender]);
    // no need to require value <= totalSupply, since that would imply the
    // sender's balance is greater than the totalSupply, which *should* be an assertion failure

    address burner = msg.sender;
    balances[burner] = balances[burner].sub(_value);
    totalSupply_ = totalSupply_.sub(_value);
    emit Burn(burner, _value);
    emit Transfer(burner, address(0), _value);
  }
}

pragma solidity ^0.5.3;

import "./ERC20Basic.sol";


/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity ^0.5.3;


/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

pragma solidity 0.5.11;

import "./Ownable.sol";
import "./GolemNetworkTokenBatching.sol";
import "./ReceivingContract.sol";

contract GNTDeposit is ReceivingContract, Ownable {
    using SafeMath for uint256;

    address public concent;
    address public coldwallet;

    // Deposit will be locked for this much longer after unlocking and before
    // it's possible to withdraw.
    uint256 public withdrawal_delay;

    // Contract will not accept new deposits if the total amount of tokens it
    // holds would exceed this amount.
    uint256 public maximum_deposits_total;
    // Maximum deposit value per user.
    uint256 public maximum_deposit_amount;

    // Limit amount of tokens Concent can reimburse within a single day.
    uint256 public daily_reimbursement_limit;
    uint256 private current_reimbursement_day;
    uint256 private current_reimbursement_sum;

    GolemNetworkTokenBatching public token;
    // owner => amount
    mapping (address => uint256) public balances;
    // owner => timestamp after which withdraw is possible
    //        | 0 if locked
    mapping (address => uint256) public locked_until;

    event ConcentTransferred(address indexed _previousConcent, address indexed _newConcent);
    event ColdwalletTransferred(address indexed _previousColdwallet, address indexed _newColdwallet);
    event Deposit(address indexed _owner, uint256 _amount);
    event Withdraw(address indexed _from, address indexed _to, uint256 _amount);
    event Lock(address indexed _owner);
    event Unlock(address indexed _owner);
    event Burn(address indexed _who, uint256 _amount);
    event ReimburseForSubtask(address indexed _requestor, address indexed _provider, uint256 _amount, bytes32 _subtask_id);
    event ReimburseForNoPayment(address indexed _requestor, address indexed _provider, uint256 _amount, uint256 _closure_time);
    event ReimburseForVerificationCosts(address indexed _from, uint256 _amount, bytes32 _subtask_id);
    event ReimburseForCommunication(address indexed _from, uint256 _amount);

    constructor(
        GolemNetworkTokenBatching _token,
        address _concent,
        address _coldwallet,
        uint256 _withdrawal_delay
    )
        public
    {
        token = _token;
        concent = _concent;
        coldwallet = _coldwallet;
        withdrawal_delay = _withdrawal_delay;
    }

    // modifiers

    modifier onlyUnlocked() {
        require(isUnlocked(msg.sender), "Deposit is not unlocked");
        _;
    }

    modifier onlyConcent() {
        require(msg.sender == concent, "Concent only method");
        _;
    }

    modifier onlyToken() {
        require(msg.sender == address(token), "Token only method");
        _;
    }

    // views

    function balanceOf(address _owner) external view returns (uint256) {
        return balances[_owner];
    }

    function isLocked(address _owner) external view returns (bool) {
        return locked_until[_owner] == 0;
    }

    function isTimeLocked(address _owner) external view returns (bool) {
        return locked_until[_owner] > block.timestamp;
    }

    function isUnlocked(address _owner) public view returns (bool) {
        return locked_until[_owner] != 0 && locked_until[_owner] < block.timestamp;
    }

    function getTimelock(address _owner) external view returns (uint256) {
        return locked_until[_owner];
    }

    function isDepositPossible(address _owner, uint256 _amount) external view returns (bool) {
        return !_isTotalDepositsLimitHit(_amount) && !_isMaximumDepositLimitHit(_owner, _amount);
    }

    // management

    function transferConcent(address _newConcent) onlyOwner external {
        require(_newConcent != address(0), "New concent address cannot be 0");
        emit ConcentTransferred(concent, _newConcent);
        concent = _newConcent;
    }

    function transferColdwallet(address _newColdwallet) onlyOwner external {
        require(_newColdwallet != address(0), "New coldwallet address cannot be 0");
        emit ColdwalletTransferred(coldwallet, _newColdwallet);
        coldwallet = _newColdwallet;
    }

    function setMaximumDepositsTotal(uint256 _value) onlyOwner external {
        maximum_deposits_total = _value;
    }

    function setMaximumDepositAmount(uint256 _value) onlyOwner external {
        maximum_deposit_amount = _value;
    }

    function setDailyReimbursementLimit(uint256 _value) onlyOwner external {
        daily_reimbursement_limit = _value;
    }

    // deposit API

    function unlock() external {
        locked_until[msg.sender] = block.timestamp + withdrawal_delay;
        emit Unlock(msg.sender);
    }

    function lock() external {
        locked_until[msg.sender] = 0;
        emit Lock(msg.sender);
    }

    function onTokenReceived(address _from, uint256 _amount, bytes calldata /* _data */) external onlyToken {
        // Pass 0 as the amount since this check happens post transfer, thus
        // amount is already accounted for in the balance
        require(!_isTotalDepositsLimitHit(0), "Total deposits limit hit");
        require(!_isMaximumDepositLimitHit(_from, _amount), "Maximum deposit limit hit");
        balances[_from] += _amount;
        locked_until[_from] = 0;
        emit Deposit(_from, _amount);
    }

    function withdraw(address _to) onlyUnlocked external {
        uint256 _amount = balances[msg.sender];
        balances[msg.sender] = 0;
        locked_until[msg.sender] = 0;
        require(token.transfer(_to, _amount));
        emit Withdraw(msg.sender, _to, _amount);
    }

    function burn(address _whom, uint256 _amount) onlyConcent external {
        require(balances[_whom] >= _amount, "Not enough funds to burn");
        balances[_whom] -= _amount;
        if (balances[_whom] == 0) {
            locked_until[_whom] = 0;
        }
        token.burn(_amount);
        emit Burn(_whom, _amount);
    }

    function reimburseForSubtask(
        address _requestor,
        address _provider,
        uint256 _amount,
        bytes32 _subtask_id,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        uint256 _reimburse_amount
    )
        onlyConcent
        external
    {
        require(_isValidSignature(_requestor, _provider, _amount, _subtask_id, _v, _r, _s), "Invalid signature");
        require(_reimburse_amount <= _amount, "Reimburse amount exceeds allowed");
        _reimburse(_requestor, _provider, _reimburse_amount);
        emit ReimburseForSubtask(_requestor, _provider, _reimburse_amount, _subtask_id);
    }

    function reimburseForNoPayment(
        address _requestor,
        address _provider,
        uint256[] calldata _amount,
        bytes32[] calldata _subtask_id,
        uint8[] calldata _v,
        bytes32[] calldata _r,
        bytes32[] calldata _s,
        uint256 _reimburse_amount,
        uint256 _closure_time
    )
        onlyConcent
        external
    {
        require(_amount.length == _subtask_id.length);
        require(_amount.length == _v.length);
        require(_amount.length == _r.length);
        require(_amount.length == _s.length);
        // Can't merge the following two loops as we exceed the number of veriables on the stack
        // and the compiler gives: CompilerError: Stack too deep, try removing local variables.
        for (uint256 i = 0; i < _amount.length; i++) {
          require(_isValidSignature(_requestor, _provider, _amount[i], _subtask_id[i], _v[i], _r[i], _s[i]), "Invalid signature");
        }
        uint256 total_amount = 0;
        for (uint256 i = 0; i < _amount.length; i++) {
          total_amount += _amount[i];
        }
        require(_reimburse_amount <= total_amount, "Reimburse amount exceeds total");
        _reimburse(_requestor, _provider, _reimburse_amount);
        emit ReimburseForNoPayment(_requestor, _provider, _reimburse_amount, _closure_time);
    }

    function reimburseForVerificationCosts(
        address _from,
        uint256 _amount,
        bytes32 _subtask_id,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        uint256 _reimburse_amount
    )
        onlyConcent
        external
    {
        require(_isValidSignature(_from, address(this), _amount, _subtask_id, _v, _r, _s), "Invalid signature");
        require(_reimburse_amount <= _amount, "Reimburse amount exceeds allowed");
        _reimburse(_from, coldwallet, _reimburse_amount);
        emit ReimburseForVerificationCosts(_from, _reimburse_amount, _subtask_id);
    }

    function reimburseForCommunication(
        address _from,
        uint256 _amount
    )
        onlyConcent
        external
    {
        _reimburse(_from, coldwallet, _amount);
        emit ReimburseForCommunication(_from, _amount);
    }

    // internals

    function _reimburse(address _from, address _to, uint256 _amount) private {
        require(balances[_from] >= _amount, "Not enough funds to reimburse");
        if (daily_reimbursement_limit != 0) {
            if (current_reimbursement_day != block.timestamp / 1 days) {
                current_reimbursement_day = block.timestamp / 1 days;
                current_reimbursement_sum = 0;
            }
            require(current_reimbursement_sum + _amount <= daily_reimbursement_limit, "Daily reimbursement limit hit");
            current_reimbursement_sum += _amount;
        }
        balances[_from] -= _amount;
        if (balances[_from] == 0) {
            locked_until[_from] = 0;
        }
        require(token.transfer(_to, _amount));
    }

    function _isTotalDepositsLimitHit(uint256 _amount) private view returns (bool) {
        if (maximum_deposits_total == 0) {
            return false;
        }
        return token.balanceOf(address(this)).add(_amount) > maximum_deposits_total;
    }

    function _isMaximumDepositLimitHit(address _owner, uint256 _amount) private view returns (bool) {
        if (maximum_deposit_amount == 0) {
            return false;
        }
        return balances[_owner].add(_amount) > maximum_deposit_amount;
    }

    function _isValidSignature(
        address _from,
        address _to,
        uint256 _amount,
        bytes32 _subtask_id,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public view returns (bool) {
        // Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf)
        // describes what constitutes a valid signature.
        if (uint256(_s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return false;
        }
        if (_v != 27 && _v != 28) {
            return false;
        }
        return _from == ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n124", address(this), _from, _to, _amount, _subtask_id)), _v, _r, _s);
    }

}

// Copyright 2018 Golem Factory
// Licensed under the GNU General Public License v3. See the LICENSE file.

pragma solidity ^0.5.3;

import "./ReceivingContract.sol";
import "./TokenProxy.sol";


/// GolemNetworkTokenBatching can be treated as an upgraded GolemNetworkToken.
/// 1. It is fully ERC20 compliant (GNT is missing approve and transferFrom)
/// 2. It implements slightly modified ERC677 (transferAndCall method)
/// 3. It provides batchTransfer method - an optimized way of executing multiple transfers
///
/// On how to convert between GNT and GNTB see TokenProxy documentation.
contract GolemNetworkTokenBatching is TokenProxy {

    string public constant name = "Golem Network Token Batching";
    string public constant symbol = "GNTB";
    uint8 public constant decimals = 18;


    event BatchTransfer(address indexed from, address indexed to, uint256 value,
        uint64 closureTime);

    constructor(ERC20Basic _gntToken) TokenProxy(_gntToken) public {
    }

    function batchTransfer(bytes32[] calldata payments, uint64 closureTime) external {
        require(block.timestamp >= closureTime);

        uint balance = balances[msg.sender];

        for (uint i = 0; i < payments.length; ++i) {
            // A payment contains compressed data:
            // first 96 bits (12 bytes) is a value,
            // following 160 bits (20 bytes) is an address.
            bytes32 payment = payments[i];
            address addr = address(uint256(payment));
            require(addr != address(0) && addr != msg.sender);
            uint v = uint(payment) / 2**160;
            require(v <= balance);
            balances[addr] += v;
            balance -= v;
            emit BatchTransfer(msg.sender, addr, v, closureTime);
        }

        balances[msg.sender] = balance;
    }

    function transferAndCall(address to, uint256 value, bytes calldata data) external {
      // Transfer always returns true so no need to check return value
      transfer(to, value);

      // No need to check whether recipient is a contract, this method is
      // supposed to used only with contract recipients
      ReceivingContract(to).onTokenReceived(msg.sender, value, data);
    }
}

pragma solidity ^0.5.3;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Owner only method");
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * @notice Renouncing to ownership will leave the contract without an owner.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

pragma solidity 0.5.11;

/// Contracts implementing this interface are compatible with
/// GolemNetworkTokenBatching's transferAndCall method
contract ReceivingContract {
    function onTokenReceived(address _from, uint _value, bytes calldata _data) external;
}

pragma solidity ^0.5.3;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

pragma solidity ^0.5.3;

import "./BasicToken.sol";
import "./ERC20.sol";


/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * @dev https://github.com/ethereum/EIPs/issues/20
 * @dev Based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract StandardToken is ERC20, BasicToken {

  mapping (address => mapping (address => uint256)) internal allowed;


  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    emit Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    require(allowed[msg.sender][_spender] == 0);
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public view returns (uint256) {
    return allowed[_owner][_spender];
  }

  /**
   * @dev Increase the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _addedValue The amount of tokens to increase the allowance by.
   */
  function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  /**
   * @dev Decrease the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To decrement
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _subtractedValue The amount of tokens to decrease the allowance by.
   */
  function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

}

// Copyright 2018 Golem Factory
// Licensed under the GNU General Public License v3. See the LICENSE file.

pragma solidity ^0.5.3;

import "./BurnableToken.sol";
import "./StandardToken.sol";

/// The Gate is a contract with unique address to allow a token holder
/// (called "User") to transfer tokens from original Token to the Proxy.
///
/// The Gate does not know who its User is. The User-Gate relationship is
/// managed by the Proxy.
contract Gate {
    ERC20Basic private TOKEN;
    address private PROXY;

    /// Gates are to be created by the TokenProxy.
    constructor(ERC20Basic _token, address _proxy) public {
        TOKEN = _token;
        PROXY = _proxy;
    }

    /// Transfer requested amount of tokens from Gate to Proxy address.
    /// Only the Proxy can request this and should request transfer of all
    /// tokens.
    function transferToProxy(uint256 _value) public {
        require(msg.sender == PROXY);

        require(TOKEN.transfer(PROXY, _value));
    }
}


/// The Proxy for existing tokens implementing a subset of ERC20 interface.
///
/// This contract creates a token Proxy contract to extend the original Token
/// contract interface. The Proxy requires only transfer() and balanceOf()
/// methods from ERC20 to be implemented in the original Token contract.
///
/// All migrated tokens are in Proxy's account on the Token side and distributed
/// among Users on the Proxy side.
///
/// For an user to migrate some amount of ones tokens from Token to Proxy
/// the procedure is as follows.
///
/// 1. Create an individual Gate for migration. The Gate address will be
///    reported with the GateOpened event and accessible by getGateAddress().
/// 2. Transfer tokens to be migrated to the Gate address.
/// 3. Execute Proxy.transferFromGate() to finalize the migration.
///
/// In the step 3 the User's tokens are going to be moved from the Gate to
/// the User's balance in the Proxy.
contract TokenProxy is StandardToken, BurnableToken {

    ERC20Basic public TOKEN;

    mapping(address => address) private gates;


    event GateOpened(address indexed gate, address indexed user);

    event Mint(address indexed to, uint256 amount);

    constructor(ERC20Basic _token) public {
        TOKEN = _token;
    }

    function getGateAddress(address _user) external view returns (address) {
        return gates[_user];
    }

    /// Create a new migration Gate for the User.
    function openGate() external {
        address user = msg.sender;

        // Do not allow creating more than one Gate per User.
        require(gates[user] == address(0));

        // Create new Gate.
        address gate = address(new Gate(TOKEN, address(this)));

        // Remember User - Gate relationship.
        gates[user] = gate;

        emit GateOpened(gate, user);
    }

    function transferFromGate() external {
        address user = msg.sender;

        address gate = gates[user];

        // Make sure the User's Gate exists.
        require(gate != address(0));

        uint256 value = TOKEN.balanceOf(gate);

        Gate(gate).transferToProxy(value);

        // Handle the information about the amount of migrated tokens.
        // This is a trusted information becase it comes from the Gate.
        totalSupply_ += value;
        balances[user] += value;

        emit Mint(user, value);
    }

    function withdraw(uint256 _value) external {
        withdrawTo(_value, msg.sender);
    }

    function withdrawTo(uint256 _value, address _destination) public {
        require(_value > 0 && _destination != address(0));
        burn(_value);
        TOKEN.transfer(_destination, _value);
    }
}

