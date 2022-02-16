pragma solidity 0.4.24;

contract ERC20Token {
  function totalSupply() public constant returns (uint);
  function balanceOf(address tokenOwner) public constant returns (uint balance);
  function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
  function transfer(address to, uint256 tokens) public returns (bool success);
  function approve(address spender, uint256 tokens) public returns (bool success);
  function transferFrom(address from, address to, uint256 tokens) public returns (bool success);

  event Transfer(address indexed from, address indexed to, uint tokens);
  event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

pragma solidity 0.4.24;

import "./SafeMath.sol";
import './StandardToken.sol';
import './Ownable.sol';

contract FLXCToken is StandardToken, Ownable {

    using SafeMath for uint256;

    string public constant symbol = "FLXC";
    string public constant name = "FLXC Token";
    uint8 public constant decimals = 18;

    // Total Number of tokens ever goint to be minted. 10 BILLION FLXC tokens.
    uint256 private constant minting_capped_amount = 10000000000 * 10 ** uint256(decimals);

    // 10% of inital supply.
    uint256  constant vesting_amount = 100000000 * 10 ** uint256(decimals);

    uint256 private initialSupply = minting_capped_amount;

    address public vestingAddress;

  
    /** @dev to cap the total number of tokens that will ever be newly minted
      * owner has to stop the minting by setting this variable to true.
      */
    bool public mintingFinished = false;

    /** @dev Miniting Essentials functions as per OpenZeppelin standards
      */
    modifier canMint() {
      require(!mintingFinished);
      _;
    }
    modifier hasMintPermission() {
      require(msg.sender == owner);
      _;
    }

    /** @dev to prevent malicious use of FLXC tokens and to comply with Anti
      * Money laundering regulations FLXC tokens can be frozen.
      */
    mapping (address => bool) public frozenAccount;

    /** @dev This generates a public event on the blockchain that will notify clients
      */
    event FrozenFunds(address target, bool frozen);
    event Mint(address indexed to, uint256 amount);
    event MintFinished();
    event Burn(address indexed burner, uint256 value);

    constructor() public {

        _totalSupply = minting_capped_amount;
        owner = msg.sender;
        balances[owner] = _totalSupply;
        emit Transfer(address(0), owner, balances[owner]);
    }

    /* Do not accept ETH */
    function() public payable {
        revert();
    }


    function setVestingAddress(address _vestingAddress) external onlyOwner {
        vestingAddress = _vestingAddress;
        assert(approve(vestingAddress, vesting_amount));
    }
   
    function getVestingAmount() public view returns(uint256) {
        return vesting_amount;
    }


    /** @dev Transfer possible only after ICO ends and Frozen accounts
      * wont be able to transfer funds to other any other account and viz.
      * @notice added safeTransfer functionality
      */
    function transfer(address _to, uint256 _value) public returns(bool) {
        require(!frozenAccount[msg.sender]);
        require(!frozenAccount[_to]);

        require(super.transfer(_to, _value));
        return true;
    }

    /** @dev Only owner's tokens can be transferred before Crowdsale ends.
      * beacuse the inital supply of FLXC is allocated to owners acc and later
      * distributed to various subcontracts.
      * @notice added safeTransferFrom functionality
      */
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool) {
        require(!frozenAccount[_from]);
        require(!frozenAccount[_to]);
        require(!frozenAccount[msg.sender]);


        require(super.transferFrom(_from, _to, _value));
        return true;
    }

    /** @notice added safeApprove functionality
      */
    function approve(address spender, uint256 tokens) public returns (bool){
        require(super.approve(spender, tokens));
        return true;
    }

   /** @notice `freeze? Prevent | Allow` `target` from sending & receiving tokens
     * @param target Address to be frozen
     * @param freeze either to freeze it or not
     */
    function freezeAccount(address target, bool freeze) public onlyOwner {
        require(frozenAccount[target] != freeze);

        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }


    /** @dev Function to mint tokens
      * @param _to The address that will receive the minted tokens.
      * @param _amount The amount of tokens to mint.
      * @return A boolean that indicates if the operation was successful.
      */
    function mint(address _to, uint256 _amount) public hasMintPermission canMint returns (bool) {
      require(_totalSupply.add(_amount) <= minting_capped_amount);

      _totalSupply = _totalSupply.add(_amount);
      balances[_to] = balances[_to].add(_amount);
      emit Mint(_to, _amount);
      emit Transfer(address(0), _to, _amount);
      return true;
    }

   /** @dev Function to stop minting new tokens.
     * @return True if the operation was successful.
     */
    function finishMinting() public onlyOwner canMint returns (bool) {
      mintingFinished = true;
      emit MintFinished();
      return true;
    }

    /** @dev Burns a specific amount of tokens.
      * @param _value The amount of token to be burned.
      */
     function burn(uint256 _value) public {
       _burn(msg.sender, _value);
     }

     function _burn(address _who, uint256 _value) internal {
       require(_value <= balances[_who]);
       // no need to require value <= totalSupply, since that would imply the
       // sender's balance is greater than the totalSupply, which *should* be an assertion failure

       balances[_who] = balances[_who].sub(_value);
       _totalSupply = _totalSupply.sub(_value);
       emit Burn(_who, _value);
       emit Transfer(_who, address(0), _value);
     }
}




pragma solidity 0.4.24;

import './StandardTokenVesting.sol';
import './Ownable.sol';


/** @notice Factory is a software design pattern for creating instances of a class.
 * Using this pattern simplifies creating new vesting contracts and saves
 * transaction costs ("gas"). Instead of deploying a new TokenVesting contract
 * for each team member, we deploy a single instance of TokenVestingFactory
 * that ensures the creation of new token vesting contracts.
 */

contract FLXCTokenVestingFactory is Ownable {

    mapping(address => StandardTokenVesting) vestingContractAddresses;

    // The token being sold
    FLXCToken public token;

    event CreatedStandardVestingContract(StandardTokenVesting vesting);

    constructor(address _token) public {
        require(_token != address(0));
        owner = msg.sender;
        token = FLXCToken(_token);
    }

   /** @dev Deploy FLXCTokenVestingFactory, and use it to create vesting contracts
     * for founders, advisors and developers. after creation transfer FLXC tokens
     * to those addresses and vesting vaults will be initialised.
     */
    // function create(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration, bool _revocable, uint256 noOfTokens) onlyOwner public returns(StandardTokenVesting) {
    function create(address _beneficiary, uint256 _cliff, uint256 _duration, bool _revocable, uint256 noOfTokens) public onlyOwner  returns(StandardTokenVesting) {
        StandardTokenVesting vesting = new StandardTokenVesting(_beneficiary, now , _cliff , _duration, _revocable);

        vesting.transferOwnership(msg.sender);
        vestingContractAddresses[_beneficiary] = vesting;
        emit CreatedStandardVestingContract(vesting);
        assert(token.transferFrom(owner, vesting, noOfTokens));

        return vesting;
    }

    function getVestingContractAddress(address _beneficiary) public view returns(address) {
        require(_beneficiary != address(0));
        require(vestingContractAddresses[_beneficiary] != address(0));

        return vestingContractAddresses[_beneficiary];
    }

    function releasableAmount(address _beneficiary) public view returns(uint256) {
        require(getVestingContractAddress( _beneficiary) != address(0));
        return vestingContractAddresses[_beneficiary].releasableAmount(token);
    }

    function vestedAmount(address _beneficiary) public view returns(uint256) {
        require(getVestingContractAddress(_beneficiary) != address(0));
        return vestingContractAddresses[_beneficiary].vestedAmount(token);
    }

    function release(address _beneficiary) public returns(bool) {
        require(getVestingContractAddress(_beneficiary) != address(0));
        return vestingContractAddresses[_beneficiary].release(token);
    }


}

pragma solidity 0.4.24;

contract Ownable {

    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}

pragma solidity 0.4.24;

import "./Ownable.sol";

/* Pausable contract */
contract Pausable is Ownable {

    event Pause();
    event Unpause();

    bool public paused = false;

    /** @dev Modifier to make a function callable only when the contract is not paused.
      */
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    /** @dev Modifier to make a function callable only when the contract is paused.
      */
    modifier whenPaused() {
        require(paused);
        _;
    }

    /** @dev called by the owner to pause, triggers stopped state
      */
    function pause() onlyOwner whenNotPaused public {
        paused = true;
        emit Pause();
    }

    /** @dev called by the owner to unpause, returns to normal state
      */
    function unpause() onlyOwner whenPaused public {
        paused = false;
        emit Unpause();
    }

}

pragma solidity 0.4.24;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

pragma solidity 0.4.24;

import './ERC20Token.sol';
import './SafeMath.sol';

contract StandardToken is ERC20Token {

  using SafeMath for uint256;

  // Global variable to store total number of tokens passed from FLXCToken.sol
  uint256 _totalSupply;

  mapping(address => uint256) balances;
  mapping(address => mapping(address => uint256)) allowed;

  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address tokenOwner) public view returns (uint256){
        return balances[tokenOwner];
  }



  function transfer(address to, uint256 tokens) public returns (bool){
      require(to != address(0));
      require(tokens > 0 && tokens <= balances[msg.sender]);

      balances[msg.sender] = balances[msg.sender].sub(tokens);
      balances[to] = balances[to].add(tokens);
      emit Transfer(msg.sender, to, tokens);
      return true;
  }

  // Transfer tokens from one address to another
  function transferFrom(address from, address to, uint256 tokens) public returns (bool success){
      require(to != address(0));
      require(tokens > 0 && tokens <= balances[from]);
      require(tokens <= allowed[from][msg.sender]);

      balances[from] = balances[from].sub(tokens);
      balances[to] = balances[to].add(tokens);
      allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
      emit Transfer(from, to, tokens);

      return true;
  }

  // Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
  function approve(address spender, uint256 tokens) public returns (bool success){
      allowed[msg.sender][spender] = tokens;
      emit Approval(msg.sender, spender, tokens);
      return true;
  }

  // Function to check the amount of tokens that an owner allowed to a spender.
  function allowance(address tokenOwner, address spender) public view returns (uint256 remaining){
      return allowed[tokenOwner][spender];
  }

  // Increase the amount of tokens that an owner allowed to a spender.
  // approve should be called when allowed[spender] == 0.
  // To increment allowed value is better to use this function to avoid 2 calls (and wait until the first transaction is mined)
  function increaseApproval(address spender, uint256 addedValue) public returns (bool) {
    allowed[msg.sender][spender] = (allowed[msg.sender][spender].add(addedValue));
    emit Approval(msg.sender, spender, allowed[msg.sender][spender]);
    return true;
  }

  // Decrease the amount of tokens that an owner allowed to a spender.
  // approve should be called when allowed[spender] == 0.
  // To decrement allowed value is better to use this function to avoid 2 calls (and wait until the first transaction is mined)
  function decreaseApproval(address spender, uint256 subtractedValue ) public returns (bool){
    uint256 oldValue = allowed[msg.sender][spender];
    if (subtractedValue >= oldValue) {
      allowed[msg.sender][spender] = 0;
    } else {
      allowed[msg.sender][spender] = oldValue.sub(subtractedValue);
    }
    emit Approval(msg.sender, spender, allowed[msg.sender][spender]);
    return true;
  }

}

pragma solidity 0.4.24;

import "./FLXCToken.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

/** @title StandardTokenVesting
  * @dev A token holder contract that can release its token balance gradually like a
  * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the owner.
  */
contract StandardTokenVesting is Ownable {
  using SafeMath for uint256;

  event Released(uint256 amount);
  event Revoked();

  // beneficiary of tokens after they are released
  address public beneficiary;

  uint256 public cliff;
  uint256 public start;
  uint256 public duration;

  bool public revocable;

  mapping (address => uint256) public released;
  mapping (address => bool) public revoked;


  /** @dev Creates a vesting contract that vests its balance of any ERC20 token to the
   * _beneficiary, gradually in a linear fashion until _start + _duration. By then all
   * of the balance will have vested.
   * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
   * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
   * @param _start the time (as Unix time) at which point vesting starts
   * @param _duration duration in seconds of the period in which the tokens will vest
   * @param _revocable whether the vesting is revocable or not
   */
  constructor(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration, bool _revocable) public {
    require(_beneficiary != address(0));
    require(_cliff <= _duration);

    beneficiary = _beneficiary;
    revocable = _revocable;
    duration = _duration;
    owner = msg.sender;
    cliff = _start.add(_cliff);
    start = _start;
  }

  /** @notice Transfers vested tokens to beneficiary.
    * @param token ERC20 token which is being vested
    */
  function release(FLXCToken token) public returns (bool){
    uint256 unreleased = releasableAmount(token);
    require(unreleased > 0);
    released[token] = released[token].add(unreleased);

    token.transfer(beneficiary, unreleased);
    emit Released(unreleased);
    return true;
  }

  /** @notice Allows the owner to revoke the vesting. Tokens already vested
    * remain in the contract, the rest are returned to the owner.
    * @param token ERC20 token which is being vested
    */
  function revoke(FLXCToken token) public onlyOwner returns(bool) {
    require(revocable);
    require(!revoked[token]);
    uint256 balance = token.balanceOf(this);
    uint256 unreleased = releasableAmount(token);
    uint256 refund = balance.sub(unreleased);

    revoked[token] = true;
    token.transfer(owner, refund);
    emit Revoked();

    return true;
  }

  /** @dev Calculates the amount that has already vested but hasn't been released yet.
    * @param token ERC20 token which is being vested
    */
  function releasableAmount(FLXCToken token) public view returns (uint256) {
    return vestedAmount(token).sub(released[token]);
  }

  /** @dev Calculates the amount that has already vested.
    * @param token FLXC Token which is being vested
    */
  function vestedAmount(FLXCToken token) public view returns (uint256) {
    uint256 currentBalance = token.balanceOf(this);
    uint256 totalBalance = currentBalance.add(released[token]);

    if (block.timestamp < cliff) {
      return 0;
    } else if (block.timestamp >= start.add(duration) || revoked[token]) {
      return totalBalance;
    } else {
      return totalBalance.mul(block.timestamp.sub(start)).div(duration);
    }
  }
}

pragma solidity 0.4.24;

contract ERC20Token {
  function totalSupply() public constant returns (uint);
  function balanceOf(address tokenOwner) public constant returns (uint balance);
  function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
  function transfer(address to, uint256 tokens) public returns (bool success);
  function approve(address spender, uint256 tokens) public returns (bool success);
  function transferFrom(address from, address to, uint256 tokens) public returns (bool success);

  event Transfer(address indexed from, address indexed to, uint tokens);
  event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

pragma solidity 0.4.24;

import "./SafeMath.sol";
import './StandardToken.sol';
import './Ownable.sol';

contract FLXCToken is StandardToken, Ownable {

    using SafeMath for uint256;

    string public constant symbol = "FLXC";
    string public constant name = "FLXC Token";
    uint8 public constant decimals = 18;

    // Total Number of tokens ever goint to be minted. 10 BILLION FLXC tokens.
    uint256 private constant minting_capped_amount = 10000000000 * 10 ** uint256(decimals);

    // 10% of inital supply.
    uint256  constant vesting_amount = 100000000 * 10 ** uint256(decimals);

    uint256 private initialSupply = minting_capped_amount;

    address public vestingAddress;

  
    /** @dev to cap the total number of tokens that will ever be newly minted
      * owner has to stop the minting by setting this variable to true.
      */
    bool public mintingFinished = false;

    /** @dev Miniting Essentials functions as per OpenZeppelin standards
      */
    modifier canMint() {
      require(!mintingFinished);
      _;
    }
    modifier hasMintPermission() {
      require(msg.sender == owner);
      _;
    }

    /** @dev to prevent malicious use of FLXC tokens and to comply with Anti
      * Money laundering regulations FLXC tokens can be frozen.
      */
    mapping (address => bool) public frozenAccount;

    /** @dev This generates a public event on the blockchain that will notify clients
      */
    event FrozenFunds(address target, bool frozen);
    event Mint(address indexed to, uint256 amount);
    event MintFinished();
    event Burn(address indexed burner, uint256 value);

    constructor() public {

        _totalSupply = minting_capped_amount;
        owner = msg.sender;
        balances[owner] = _totalSupply;
        emit Transfer(address(0), owner, balances[owner]);
    }

    /* Do not accept ETH */
    function() public payable {
        revert();
    }


    function setVestingAddress(address _vestingAddress) external onlyOwner {
        vestingAddress = _vestingAddress;
        assert(approve(vestingAddress, vesting_amount));
    }
   
    function getVestingAmount() public view returns(uint256) {
        return vesting_amount;
    }


    /** @dev Transfer possible only after ICO ends and Frozen accounts
      * wont be able to transfer funds to other any other account and viz.
      * @notice added safeTransfer functionality
      */
    function transfer(address _to, uint256 _value) public returns(bool) {
        require(!frozenAccount[msg.sender]);
        require(!frozenAccount[_to]);

        require(super.transfer(_to, _value));
        return true;
    }

    /** @dev Only owner's tokens can be transferred before Crowdsale ends.
      * beacuse the inital supply of FLXC is allocated to owners acc and later
      * distributed to various subcontracts.
      * @notice added safeTransferFrom functionality
      */
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool) {
        require(!frozenAccount[_from]);
        require(!frozenAccount[_to]);
        require(!frozenAccount[msg.sender]);


        require(super.transferFrom(_from, _to, _value));
        return true;
    }

    /** @notice added safeApprove functionality
      */
    function approve(address spender, uint256 tokens) public returns (bool){
        require(super.approve(spender, tokens));
        return true;
    }

   /** @notice `freeze? Prevent | Allow` `target` from sending & receiving tokens
     * @param target Address to be frozen
     * @param freeze either to freeze it or not
     */
    function freezeAccount(address target, bool freeze) public onlyOwner {
        require(frozenAccount[target] != freeze);

        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }


    /** @dev Function to mint tokens
      * @param _to The address that will receive the minted tokens.
      * @param _amount The amount of tokens to mint.
      * @return A boolean that indicates if the operation was successful.
      */
    function mint(address _to, uint256 _amount) public hasMintPermission canMint returns (bool) {
      require(_totalSupply.add(_amount) <= minting_capped_amount);

      _totalSupply = _totalSupply.add(_amount);
      balances[_to] = balances[_to].add(_amount);
      emit Mint(_to, _amount);
      emit Transfer(address(0), _to, _amount);
      return true;
    }

   /** @dev Function to stop minting new tokens.
     * @return True if the operation was successful.
     */
    function finishMinting() public onlyOwner canMint returns (bool) {
      mintingFinished = true;
      emit MintFinished();
      return true;
    }

    /** @dev Burns a specific amount of tokens.
      * @param _value The amount of token to be burned.
      */
     function burn(uint256 _value) public {
       _burn(msg.sender, _value);
     }

     function _burn(address _who, uint256 _value) internal {
       require(_value <= balances[_who]);
       // no need to require value <= totalSupply, since that would imply the
       // sender's balance is greater than the totalSupply, which *should* be an assertion failure

       balances[_who] = balances[_who].sub(_value);
       _totalSupply = _totalSupply.sub(_value);
       emit Burn(_who, _value);
       emit Transfer(_who, address(0), _value);
     }
}




pragma solidity 0.4.24;

import './StandardTokenVesting.sol';
import './Ownable.sol';


/** @notice Factory is a software design pattern for creating instances of a class.
 * Using this pattern simplifies creating new vesting contracts and saves
 * transaction costs ("gas"). Instead of deploying a new TokenVesting contract
 * for each team member, we deploy a single instance of TokenVestingFactory
 * that ensures the creation of new token vesting contracts.
 */

contract FLXCTokenVestingFactory is Ownable {

    mapping(address => StandardTokenVesting) vestingContractAddresses;

    // The token being sold
    FLXCToken public token;

    event CreatedStandardVestingContract(StandardTokenVesting vesting);

    constructor(address _token) public {
        require(_token != address(0));
        owner = msg.sender;
        token = FLXCToken(_token);
    }

   /** @dev Deploy FLXCTokenVestingFactory, and use it to create vesting contracts
     * for founders, advisors and developers. after creation transfer FLXC tokens
     * to those addresses and vesting vaults will be initialised.
     */
    // function create(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration, bool _revocable, uint256 noOfTokens) onlyOwner public returns(StandardTokenVesting) {
    function create(address _beneficiary, uint256 _cliff, uint256 _duration, bool _revocable, uint256 noOfTokens) public onlyOwner  returns(StandardTokenVesting) {
        StandardTokenVesting vesting = new StandardTokenVesting(_beneficiary, now , _cliff , _duration, _revocable);

        vesting.transferOwnership(msg.sender);
        vestingContractAddresses[_beneficiary] = vesting;
        emit CreatedStandardVestingContract(vesting);
        assert(token.transferFrom(owner, vesting, noOfTokens));

        return vesting;
    }

    function getVestingContractAddress(address _beneficiary) public view returns(address) {
        require(_beneficiary != address(0));
        require(vestingContractAddresses[_beneficiary] != address(0));

        return vestingContractAddresses[_beneficiary];
    }

    function releasableAmount(address _beneficiary) public view returns(uint256) {
        require(getVestingContractAddress( _beneficiary) != address(0));
        return vestingContractAddresses[_beneficiary].releasableAmount(token);
    }

    function vestedAmount(address _beneficiary) public view returns(uint256) {
        require(getVestingContractAddress(_beneficiary) != address(0));
        return vestingContractAddresses[_beneficiary].vestedAmount(token);
    }

    function release(address _beneficiary) public returns(bool) {
        require(getVestingContractAddress(_beneficiary) != address(0));
        return vestingContractAddresses[_beneficiary].release(token);
    }


}

pragma solidity 0.4.24;

contract Ownable {

    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}

pragma solidity 0.4.24;

import "./Ownable.sol";

/* Pausable contract */
contract Pausable is Ownable {

    event Pause();
    event Unpause();

    bool public paused = false;

    /** @dev Modifier to make a function callable only when the contract is not paused.
      */
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    /** @dev Modifier to make a function callable only when the contract is paused.
      */
    modifier whenPaused() {
        require(paused);
        _;
    }

    /** @dev called by the owner to pause, triggers stopped state
      */
    function pause() onlyOwner whenNotPaused public {
        paused = true;
        emit Pause();
    }

    /** @dev called by the owner to unpause, returns to normal state
      */
    function unpause() onlyOwner whenPaused public {
        paused = false;
        emit Unpause();
    }

}

pragma solidity 0.4.24;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

pragma solidity 0.4.24;

import './ERC20Token.sol';
import './SafeMath.sol';

contract StandardToken is ERC20Token {

  using SafeMath for uint256;

  // Global variable to store total number of tokens passed from FLXCToken.sol
  uint256 _totalSupply;

  mapping(address => uint256) balances;
  mapping(address => mapping(address => uint256)) allowed;

  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address tokenOwner) public view returns (uint256){
        return balances[tokenOwner];
  }



  function transfer(address to, uint256 tokens) public returns (bool){
      require(to != address(0));
      require(tokens > 0 && tokens <= balances[msg.sender]);

      balances[msg.sender] = balances[msg.sender].sub(tokens);
      balances[to] = balances[to].add(tokens);
      emit Transfer(msg.sender, to, tokens);
      return true;
  }

  // Transfer tokens from one address to another
  function transferFrom(address from, address to, uint256 tokens) public returns (bool success){
      require(to != address(0));
      require(tokens > 0 && tokens <= balances[from]);
      require(tokens <= allowed[from][msg.sender]);

      balances[from] = balances[from].sub(tokens);
      balances[to] = balances[to].add(tokens);
      allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
      emit Transfer(from, to, tokens);

      return true;
  }

  // Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
  function approve(address spender, uint256 tokens) public returns (bool success){
      allowed[msg.sender][spender] = tokens;
      emit Approval(msg.sender, spender, tokens);
      return true;
  }

  // Function to check the amount of tokens that an owner allowed to a spender.
  function allowance(address tokenOwner, address spender) public view returns (uint256 remaining){
      return allowed[tokenOwner][spender];
  }

  // Increase the amount of tokens that an owner allowed to a spender.
  // approve should be called when allowed[spender] == 0.
  // To increment allowed value is better to use this function to avoid 2 calls (and wait until the first transaction is mined)
  function increaseApproval(address spender, uint256 addedValue) public returns (bool) {
    allowed[msg.sender][spender] = (allowed[msg.sender][spender].add(addedValue));
    emit Approval(msg.sender, spender, allowed[msg.sender][spender]);
    return true;
  }

  // Decrease the amount of tokens that an owner allowed to a spender.
  // approve should be called when allowed[spender] == 0.
  // To decrement allowed value is better to use this function to avoid 2 calls (and wait until the first transaction is mined)
  function decreaseApproval(address spender, uint256 subtractedValue ) public returns (bool){
    uint256 oldValue = allowed[msg.sender][spender];
    if (subtractedValue >= oldValue) {
      allowed[msg.sender][spender] = 0;
    } else {
      allowed[msg.sender][spender] = oldValue.sub(subtractedValue);
    }
    emit Approval(msg.sender, spender, allowed[msg.sender][spender]);
    return true;
  }

}

pragma solidity 0.4.24;

import "./FLXCToken.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

/** @title StandardTokenVesting
  * @dev A token holder contract that can release its token balance gradually like a
  * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the owner.
  */
contract StandardTokenVesting is Ownable {
  using SafeMath for uint256;

  event Released(uint256 amount);
  event Revoked();

  // beneficiary of tokens after they are released
  address public beneficiary;

  uint256 public cliff;
  uint256 public start;
  uint256 public duration;

  bool public revocable;

  mapping (address => uint256) public released;
  mapping (address => bool) public revoked;


  /** @dev Creates a vesting contract that vests its balance of any ERC20 token to the
   * _beneficiary, gradually in a linear fashion until _start + _duration. By then all
   * of the balance will have vested.
   * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
   * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
   * @param _start the time (as Unix time) at which point vesting starts
   * @param _duration duration in seconds of the period in which the tokens will vest
   * @param _revocable whether the vesting is revocable or not
   */
  constructor(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration, bool _revocable) public {
    require(_beneficiary != address(0));
    require(_cliff <= _duration);

    beneficiary = _beneficiary;
    revocable = _revocable;
    duration = _duration;
    owner = msg.sender;
    cliff = _start.add(_cliff);
    start = _start;
  }

  /** @notice Transfers vested tokens to beneficiary.
    * @param token ERC20 token which is being vested
    */
  function release(FLXCToken token) public returns (bool){
    uint256 unreleased = releasableAmount(token);
    require(unreleased > 0);
    released[token] = released[token].add(unreleased);

    token.transfer(beneficiary, unreleased);
    emit Released(unreleased);
    return true;
  }

  /** @notice Allows the owner to revoke the vesting. Tokens already vested
    * remain in the contract, the rest are returned to the owner.
    * @param token ERC20 token which is being vested
    */
  function revoke(FLXCToken token) public onlyOwner returns(bool) {
    require(revocable);
    require(!revoked[token]);
    uint256 balance = token.balanceOf(this);
    uint256 unreleased = releasableAmount(token);
    uint256 refund = balance.sub(unreleased);

    revoked[token] = true;
    token.transfer(owner, refund);
    emit Revoked();

    return true;
  }

  /** @dev Calculates the amount that has already vested but hasn't been released yet.
    * @param token ERC20 token which is being vested
    */
  function releasableAmount(FLXCToken token) public view returns (uint256) {
    return vestedAmount(token).sub(released[token]);
  }

  /** @dev Calculates the amount that has already vested.
    * @param token FLXC Token which is being vested
    */
  function vestedAmount(FLXCToken token) public view returns (uint256) {
    uint256 currentBalance = token.balanceOf(this);
    uint256 totalBalance = currentBalance.add(released[token]);

    if (block.timestamp < cliff) {
      return 0;
    } else if (block.timestamp >= start.add(duration) || revoked[token]) {
      return totalBalance;
    } else {
      return totalBalance.mul(block.timestamp.sub(start)).div(duration);
    }
  }
}

pragma solidity 0.4.24;

contract ERC20Token {
  function totalSupply() public constant returns (uint);
  function balanceOf(address tokenOwner) public constant returns (uint balance);
  function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
  function transfer(address to, uint256 tokens) public returns (bool success);
  function approve(address spender, uint256 tokens) public returns (bool success);
  function transferFrom(address from, address to, uint256 tokens) public returns (bool success);

  event Transfer(address indexed from, address indexed to, uint tokens);
  event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

pragma solidity 0.4.24;

import "./SafeMath.sol";
import './StandardToken.sol';
import './Ownable.sol';

contract FLXCToken is StandardToken, Ownable {

    using SafeMath for uint256;

    string public constant symbol = "FLXC";
    string public constant name = "FLXC Token";
    uint8 public constant decimals = 18;

    // Total Number of tokens ever goint to be minted. 10 BILLION FLXC tokens.
    uint256 private constant minting_capped_amount = 10000000000 * 10 ** uint256(decimals);

    // 10% of inital supply.
    uint256  constant vesting_amount = 100000000 * 10 ** uint256(decimals);

    uint256 private initialSupply = minting_capped_amount;

    address public vestingAddress;

  
    /** @dev to cap the total number of tokens that will ever be newly minted
      * owner has to stop the minting by setting this variable to true.
      */
    bool public mintingFinished = false;

    /** @dev Miniting Essentials functions as per OpenZeppelin standards
      */
    modifier canMint() {
      require(!mintingFinished);
      _;
    }
    modifier hasMintPermission() {
      require(msg.sender == owner);
      _;
    }

    /** @dev to prevent malicious use of FLXC tokens and to comply with Anti
      * Money laundering regulations FLXC tokens can be frozen.
      */
    mapping (address => bool) public frozenAccount;

    /** @dev This generates a public event on the blockchain that will notify clients
      */
    event FrozenFunds(address target, bool frozen);
    event Mint(address indexed to, uint256 amount);
    event MintFinished();
    event Burn(address indexed burner, uint256 value);

    constructor() public {

        _totalSupply = minting_capped_amount;
        owner = msg.sender;
        balances[owner] = _totalSupply;
        emit Transfer(address(0), owner, balances[owner]);
    }

    /* Do not accept ETH */
    function() public payable {
        revert();
    }


    function setVestingAddress(address _vestingAddress) external onlyOwner {
        vestingAddress = _vestingAddress;
        assert(approve(vestingAddress, vesting_amount));
    }
   
    function getVestingAmount() public view returns(uint256) {
        return vesting_amount;
    }


    /** @dev Transfer possible only after ICO ends and Frozen accounts
      * wont be able to transfer funds to other any other account and viz.
      * @notice added safeTransfer functionality
      */
    function transfer(address _to, uint256 _value) public returns(bool) {
        require(!frozenAccount[msg.sender]);
        require(!frozenAccount[_to]);

        require(super.transfer(_to, _value));
        return true;
    }

    /** @dev Only owner's tokens can be transferred before Crowdsale ends.
      * beacuse the inital supply of FLXC is allocated to owners acc and later
      * distributed to various subcontracts.
      * @notice added safeTransferFrom functionality
      */
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool) {
        require(!frozenAccount[_from]);
        require(!frozenAccount[_to]);
        require(!frozenAccount[msg.sender]);


        require(super.transferFrom(_from, _to, _value));
        return true;
    }

    /** @notice added safeApprove functionality
      */
    function approve(address spender, uint256 tokens) public returns (bool){
        require(super.approve(spender, tokens));
        return true;
    }

   /** @notice `freeze? Prevent | Allow` `target` from sending & receiving tokens
     * @param target Address to be frozen
     * @param freeze either to freeze it or not
     */
    function freezeAccount(address target, bool freeze) public onlyOwner {
        require(frozenAccount[target] != freeze);

        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }


    /** @dev Function to mint tokens
      * @param _to The address that will receive the minted tokens.
      * @param _amount The amount of tokens to mint.
      * @return A boolean that indicates if the operation was successful.
      */
    function mint(address _to, uint256 _amount) public hasMintPermission canMint returns (bool) {
      require(_totalSupply.add(_amount) <= minting_capped_amount);

      _totalSupply = _totalSupply.add(_amount);
      balances[_to] = balances[_to].add(_amount);
      emit Mint(_to, _amount);
      emit Transfer(address(0), _to, _amount);
      return true;
    }

   /** @dev Function to stop minting new tokens.
     * @return True if the operation was successful.
     */
    function finishMinting() public onlyOwner canMint returns (bool) {
      mintingFinished = true;
      emit MintFinished();
      return true;
    }

    /** @dev Burns a specific amount of tokens.
      * @param _value The amount of token to be burned.
      */
     function burn(uint256 _value) public {
       _burn(msg.sender, _value);
     }

     function _burn(address _who, uint256 _value) internal {
       require(_value <= balances[_who]);
       // no need to require value <= totalSupply, since that would imply the
       // sender's balance is greater than the totalSupply, which *should* be an assertion failure

       balances[_who] = balances[_who].sub(_value);
       _totalSupply = _totalSupply.sub(_value);
       emit Burn(_who, _value);
       emit Transfer(_who, address(0), _value);
     }
}




pragma solidity 0.4.24;

import './StandardTokenVesting.sol';
import './Ownable.sol';


/** @notice Factory is a software design pattern for creating instances of a class.
 * Using this pattern simplifies creating new vesting contracts and saves
 * transaction costs ("gas"). Instead of deploying a new TokenVesting contract
 * for each team member, we deploy a single instance of TokenVestingFactory
 * that ensures the creation of new token vesting contracts.
 */

contract FLXCTokenVestingFactory is Ownable {

    mapping(address => StandardTokenVesting) vestingContractAddresses;

    // The token being sold
    FLXCToken public token;

    event CreatedStandardVestingContract(StandardTokenVesting vesting);

    constructor(address _token) public {
        require(_token != address(0));
        owner = msg.sender;
        token = FLXCToken(_token);
    }

   /** @dev Deploy FLXCTokenVestingFactory, and use it to create vesting contracts
     * for founders, advisors and developers. after creation transfer FLXC tokens
     * to those addresses and vesting vaults will be initialised.
     */
    // function create(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration, bool _revocable, uint256 noOfTokens) onlyOwner public returns(StandardTokenVesting) {
    function create(address _beneficiary, uint256 _cliff, uint256 _duration, bool _revocable, uint256 noOfTokens) public onlyOwner  returns(StandardTokenVesting) {
        StandardTokenVesting vesting = new StandardTokenVesting(_beneficiary, now , _cliff , _duration, _revocable);

        vesting.transferOwnership(msg.sender);
        vestingContractAddresses[_beneficiary] = vesting;
        emit CreatedStandardVestingContract(vesting);
        assert(token.transferFrom(owner, vesting, noOfTokens));

        return vesting;
    }

    function getVestingContractAddress(address _beneficiary) public view returns(address) {
        require(_beneficiary != address(0));
        require(vestingContractAddresses[_beneficiary] != address(0));

        return vestingContractAddresses[_beneficiary];
    }

    function releasableAmount(address _beneficiary) public view returns(uint256) {
        require(getVestingContractAddress( _beneficiary) != address(0));
        return vestingContractAddresses[_beneficiary].releasableAmount(token);
    }

    function vestedAmount(address _beneficiary) public view returns(uint256) {
        require(getVestingContractAddress(_beneficiary) != address(0));
        return vestingContractAddresses[_beneficiary].vestedAmount(token);
    }

    function release(address _beneficiary) public returns(bool) {
        require(getVestingContractAddress(_beneficiary) != address(0));
        return vestingContractAddresses[_beneficiary].release(token);
    }


}

pragma solidity 0.4.24;

contract Ownable {

    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}

pragma solidity 0.4.24;

import "./Ownable.sol";

/* Pausable contract */
contract Pausable is Ownable {

    event Pause();
    event Unpause();

    bool public paused = false;

    /** @dev Modifier to make a function callable only when the contract is not paused.
      */
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    /** @dev Modifier to make a function callable only when the contract is paused.
      */
    modifier whenPaused() {
        require(paused);
        _;
    }

    /** @dev called by the owner to pause, triggers stopped state
      */
    function pause() onlyOwner whenNotPaused public {
        paused = true;
        emit Pause();
    }

    /** @dev called by the owner to unpause, returns to normal state
      */
    function unpause() onlyOwner whenPaused public {
        paused = false;
        emit Unpause();
    }

}

pragma solidity 0.4.24;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

pragma solidity 0.4.24;

import './ERC20Token.sol';
import './SafeMath.sol';

contract StandardToken is ERC20Token {

  using SafeMath for uint256;

  // Global variable to store total number of tokens passed from FLXCToken.sol
  uint256 _totalSupply;

  mapping(address => uint256) balances;
  mapping(address => mapping(address => uint256)) allowed;

  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address tokenOwner) public view returns (uint256){
        return balances[tokenOwner];
  }



  function transfer(address to, uint256 tokens) public returns (bool){
      require(to != address(0));
      require(tokens > 0 && tokens <= balances[msg.sender]);

      balances[msg.sender] = balances[msg.sender].sub(tokens);
      balances[to] = balances[to].add(tokens);
      emit Transfer(msg.sender, to, tokens);
      return true;
  }

  // Transfer tokens from one address to another
  function transferFrom(address from, address to, uint256 tokens) public returns (bool success){
      require(to != address(0));
      require(tokens > 0 && tokens <= balances[from]);
      require(tokens <= allowed[from][msg.sender]);

      balances[from] = balances[from].sub(tokens);
      balances[to] = balances[to].add(tokens);
      allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
      emit Transfer(from, to, tokens);

      return true;
  }

  // Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
  function approve(address spender, uint256 tokens) public returns (bool success){
      allowed[msg.sender][spender] = tokens;
      emit Approval(msg.sender, spender, tokens);
      return true;
  }

  // Function to check the amount of tokens that an owner allowed to a spender.
  function allowance(address tokenOwner, address spender) public view returns (uint256 remaining){
      return allowed[tokenOwner][spender];
  }

  // Increase the amount of tokens that an owner allowed to a spender.
  // approve should be called when allowed[spender] == 0.
  // To increment allowed value is better to use this function to avoid 2 calls (and wait until the first transaction is mined)
  function increaseApproval(address spender, uint256 addedValue) public returns (bool) {
    allowed[msg.sender][spender] = (allowed[msg.sender][spender].add(addedValue));
    emit Approval(msg.sender, spender, allowed[msg.sender][spender]);
    return true;
  }

  // Decrease the amount of tokens that an owner allowed to a spender.
  // approve should be called when allowed[spender] == 0.
  // To decrement allowed value is better to use this function to avoid 2 calls (and wait until the first transaction is mined)
  function decreaseApproval(address spender, uint256 subtractedValue ) public returns (bool){
    uint256 oldValue = allowed[msg.sender][spender];
    if (subtractedValue >= oldValue) {
      allowed[msg.sender][spender] = 0;
    } else {
      allowed[msg.sender][spender] = oldValue.sub(subtractedValue);
    }
    emit Approval(msg.sender, spender, allowed[msg.sender][spender]);
    return true;
  }

}

pragma solidity 0.4.24;

import "./FLXCToken.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

/** @title StandardTokenVesting
  * @dev A token holder contract that can release its token balance gradually like a
  * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the owner.
  */
contract StandardTokenVesting is Ownable {
  using SafeMath for uint256;

  event Released(uint256 amount);
  event Revoked();

  // beneficiary of tokens after they are released
  address public beneficiary;

  uint256 public cliff;
  uint256 public start;
  uint256 public duration;

  bool public revocable;

  mapping (address => uint256) public released;
  mapping (address => bool) public revoked;


  /** @dev Creates a vesting contract that vests its balance of any ERC20 token to the
   * _beneficiary, gradually in a linear fashion until _start + _duration. By then all
   * of the balance will have vested.
   * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
   * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
   * @param _start the time (as Unix time) at which point vesting starts
   * @param _duration duration in seconds of the period in which the tokens will vest
   * @param _revocable whether the vesting is revocable or not
   */
  constructor(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration, bool _revocable) public {
    require(_beneficiary != address(0));
    require(_cliff <= _duration);

    beneficiary = _beneficiary;
    revocable = _revocable;
    duration = _duration;
    owner = msg.sender;
    cliff = _start.add(_cliff);
    start = _start;
  }

  /** @notice Transfers vested tokens to beneficiary.
    * @param token ERC20 token which is being vested
    */
  function release(FLXCToken token) public returns (bool){
    uint256 unreleased = releasableAmount(token);
    require(unreleased > 0);
    released[token] = released[token].add(unreleased);

    token.transfer(beneficiary, unreleased);
    emit Released(unreleased);
    return true;
  }

  /** @notice Allows the owner to revoke the vesting. Tokens already vested
    * remain in the contract, the rest are returned to the owner.
    * @param token ERC20 token which is being vested
    */
  function revoke(FLXCToken token) public onlyOwner returns(bool) {
    require(revocable);
    require(!revoked[token]);
    uint256 balance = token.balanceOf(this);
    uint256 unreleased = releasableAmount(token);
    uint256 refund = balance.sub(unreleased);

    revoked[token] = true;
    token.transfer(owner, refund);
    emit Revoked();

    return true;
  }

  /** @dev Calculates the amount that has already vested but hasn't been released yet.
    * @param token ERC20 token which is being vested
    */
  function releasableAmount(FLXCToken token) public view returns (uint256) {
    return vestedAmount(token).sub(released[token]);
  }

  /** @dev Calculates the amount that has already vested.
    * @param token FLXC Token which is being vested
    */
  function vestedAmount(FLXCToken token) public view returns (uint256) {
    uint256 currentBalance = token.balanceOf(this);
    uint256 totalBalance = currentBalance.add(released[token]);

    if (block.timestamp < cliff) {
      return 0;
    } else if (block.timestamp >= start.add(duration) || revoked[token]) {
      return totalBalance;
    } else {
      return totalBalance.mul(block.timestamp.sub(start)).div(duration);
    }
  }
}

