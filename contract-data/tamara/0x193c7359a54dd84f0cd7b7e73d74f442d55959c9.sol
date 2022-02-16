pragma solidity ^0.4.24;

import "./ERC20Basic.sol";
import "./SafeMath.sol";

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
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }

}
pragma solidity ^0.4.24;

import "./StandardToken.sol";

contract BurnableToken is StandardToken {

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
pragma solidity ^0.4.24;
import "./ERC20Basic.sol";

contract ERC20 is ERC20Basic {
  // Optional token name
  string  public  name = "zeosX";
  string  public  symbol;
  uint256  public  decimals = 18; // standard token precision. override to customize
    
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}
pragma solidity ^0.4.24;

contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}
pragma solidity ^0.4.24;

import "./Owned.sol";

contract KYCVerification is Owned{
    
    mapping(address => bool) public kycAddress;
    
    event LogKYCVerification(address _kycAddress,bool _status);
    
    constructor () public {
        owner = msg.sender;
    }

    function updateVerifcationBatch(address[] _kycAddress,bool _status) onlyOwner public returns(bool)
    {
        for(uint tmpIndex = 0; tmpIndex < _kycAddress.length; tmpIndex++)
        {
            kycAddress[_kycAddress[tmpIndex]] = _status;
            emit LogKYCVerification(_kycAddress[tmpIndex],_status);
        }
        
        return true;
    }
    
    function updateVerifcation(address _kycAddress,bool _status) onlyOwner public returns(bool)
    {
        kycAddress[_kycAddress] = _status;
        
        emit LogKYCVerification(_kycAddress,_status);
        
        return true;
    }
    
    function isVerified(address _user) view public returns(bool)
    {
        return kycAddress[_user] == true; 
    }
}
pragma solidity ^0.4.24;

contract Owned {
    address public owner;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}
pragma solidity ^0.4.24;
/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
 
library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}
pragma solidity ^0.4.24;

import "./ERC20.sol";
import "./BasicToken.sol";

contract StandardToken is ERC20, BasicToken {

  mapping (address => mapping (address => uint256)) internal allowed;

  function multiTransfer(address[] _to,uint[] _value) public returns (bool);

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
pragma solidity ^0.4.24;
/* import "./oraclizeAPI_0.5.sol"; */
import "./Owned.sol";
import "./BurnableToken.sol";
import "./KYCVerification.sol";

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) external; }

contract UTRAToken is Owned, BurnableToken {

    string public name = "SurePAY Utility, Transaction, Reward and Access Token.";
    string public symbol = "UTRA";
    uint8 public decimals = 5;
    
    uint256 public initialSupply = 8100000000 * (10 ** uint256(decimals));
    uint256 public totalSupply = 8100000000 * (10 ** uint256(decimals));
    uint256 public externalAuthorizePurchase = 0;
    
    
    mapping (address => bool) public frozenAccount;
    mapping(address => uint8) authorizedCaller;
    mapping (address => bool) public lockingEnabled;
    
    bool public kycEnabled = true;

    KYCVerification public kycVerification;

    event KYCMandateUpdate(bool _kycEnabled);
    event KYCContractAddressUpdate(KYCVerification _kycAddress);
    event LockFunds(address _buyer,bool _status);


    modifier onlyAuthCaller(){
        require(authorizedCaller[msg.sender] == 1 || msg.sender == owner);
        _;
    }
    
    /*
        check locking status of user address.
    */
    modifier lockingVerified(address _guy) {
        if(lockingEnabled[_guy] == true){
            revert("Account is locked");
        }
        _;
    }
    
    modifier kycVerified(address _guy) {
      if(kycEnabled == true){
          if(kycVerification.isVerified(_guy) == false)
          {
              revert("KYC Not Verified");
          }
      }
      _;
    }
    
     modifier frozenVerified(address _guy) {
        if(frozenAccount[_guy] == true)
        {
            revert("Account is freeze");
        }
        _;
    }

    function updateKycContractAddress(KYCVerification _kycAddress) public onlyOwner returns(bool)
    {
      kycVerification = _kycAddress;

      emit KYCContractAddressUpdate(_kycAddress);

      return true;
    }

    function updateKycMandate(bool _kycEnabled) public onlyAuthCaller returns(bool)
    {
        kycEnabled = _kycEnabled;
        emit KYCMandateUpdate(_kycEnabled);
        return true;
    }
    
    function forceUpdateLockStatus(address _holder,bool _lock) public onlyAuthCaller returns(bool)
    {
        lockingEnabled[_holder] = _lock;
        emit LockFunds(_holder, _lock);
        return true;
    }

    /* This generates a public event on the blockchain that will notify clients */
    event FrozenFunds(address target, bool frozen);
    
    /* Events */
    event AuthorizedCaller(address caller);
    event DeAuthorizedCaller(address caller);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    constructor() public {
        owner = msg.sender;
        balances[0x49156f159aAf87207fD54401eB1F73974968768C] = totalSupply;
        
        /* unlock totalSupply holder account */
        
        lockingEnabled[0x49156f159aAf87207fD54401eB1F73974968768C] = false;
        
        emit Transfer(address(0x0), address(this), totalSupply);
        emit Transfer(address(this), address(0x49156f159aAf87207fD54401eB1F73974968768C), totalSupply);
            
        authorizedCaller[msg.sender] = 1;
        emit AuthorizedCaller(msg.sender);
    }
    
    /* authorize caller */
    function authorizeCaller(address _caller) public onlyOwner returns(bool) 
    {
        authorizedCaller[_caller] = 1;
        emit AuthorizedCaller(_caller);
        return true;
    }
    
    /* deauthorize caller */
    function deAuthorizeCaller(address _caller) public onlyOwner returns(bool) 
    {
        authorizedCaller[_caller] = 0;
        emit DeAuthorizedCaller(_caller);
        return true;
    }
    
    function () payable public {
        revert();
    }
    

    /* Internal transfer, only can be called by this contract */
    function _transfer(address _from, address _to, uint _value) internal {
        require (_to != 0x0);                               // Prevent transfer to 0x0 address. Use burn() instead
        require (balances[_from] > _value);                // Check if the sender has enough
        require (balances[_to].add(_value) > balances[_to]); // Check for overflow
        balances[_from] = balances[_from].sub(_value);                         // Subtract from the sender
        balances[_to] = balances[_to].add(_value);                           // Add the same to the recipient
        emit Transfer(_from, _to, _value);
    }

    /// @notice Create `mintedAmount` tokens and send it to `target`
    /// @param target Address to receive the tokens
    /// @param mintedAmount the amount of tokens it will receive
    function mintToken(address target, uint256 mintedAmount) onlyOwner public {
        balances[target] = balances[target].add(mintedAmount);
        totalSupply = totalSupply.add(mintedAmount);
        emit Transfer(0, this, mintedAmount);
        emit Transfer(this, target, mintedAmount);
    }

    /// @notice `freeze? Prevent | Allow` `target` from sending & receiving tokens
    /// @param target Address to be frozen
    /// @param freeze either to freeze it or not
    function freezeAccount(address target, bool freeze) onlyOwner public {
        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }


    function purchaseToken(address _receiver, uint _tokens) onlyAuthCaller public {
        require(_tokens > 0);
        require(initialSupply > _tokens);
        
        lockingEnabled[_receiver] = true;
        emit LockFunds(_receiver, true);
        
        initialSupply = initialSupply.sub(_tokens);
        _transfer(owner, _receiver, _tokens);              // makes the transfers
        externalAuthorizePurchase = externalAuthorizePurchase.add(_tokens);
    }

    /**
      * @dev transfer token for a specified address
      * @param _to The address to transfer to.
      * @param _value The amount to be transferred.
    */
    function transfer(address _to, uint256 _value) public kycVerified(msg.sender) frozenVerified(msg.sender) lockingVerified(msg.sender)  returns (bool) {
        _transfer(msg.sender,_to,_value);
        return true;
    }
    
    /*
        Please make sure before calling this function from UI, Sender has sufficient balance for 
        All transfers 
    */
    function multiTransfer(address[] _to,uint[] _value) public kycVerified(msg.sender) frozenVerified(msg.sender) lockingVerified(msg.sender) returns (bool) {
        require(_to.length == _value.length, "Length of Destination should be equal to value");
        for(uint _interator = 0;_interator < _to.length; _interator++ )
        {
            _transfer(msg.sender,_to[_interator],_value[_interator]);
        }
        return true;    
    }
    
    /*
        Lock user address
    */
    function lockUserAddress() public returns(bool){
        lockingEnabled[msg.sender] = true;
        emit LockFunds(msg.sender, true);
    }
    
    /*
        Unlock User Address
    */
    function unlockUserAddress() public returns(bool){
        lockingEnabled[msg.sender] = false;
        emit LockFunds(msg.sender, false);
    }
}

pragma solidity ^0.4.24;

import "./ERC20Basic.sol";
import "./SafeMath.sol";

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
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }

}
pragma solidity ^0.4.24;

import "./StandardToken.sol";

contract BurnableToken is StandardToken {

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
pragma solidity ^0.4.24;
import "./ERC20Basic.sol";

contract ERC20 is ERC20Basic {
  // Optional token name
  string  public  name = "zeosX";
  string  public  symbol;
  uint256  public  decimals = 18; // standard token precision. override to customize
    
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}
pragma solidity ^0.4.24;

contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}
pragma solidity ^0.4.24;

import "./Owned.sol";

contract KYCVerification is Owned{
    
    mapping(address => bool) public kycAddress;
    
    event LogKYCVerification(address _kycAddress,bool _status);
    
    constructor () public {
        owner = msg.sender;
    }

    function updateVerifcationBatch(address[] _kycAddress,bool _status) onlyOwner public returns(bool)
    {
        for(uint tmpIndex = 0; tmpIndex < _kycAddress.length; tmpIndex++)
        {
            kycAddress[_kycAddress[tmpIndex]] = _status;
            emit LogKYCVerification(_kycAddress[tmpIndex],_status);
        }
        
        return true;
    }
    
    function updateVerifcation(address _kycAddress,bool _status) onlyOwner public returns(bool)
    {
        kycAddress[_kycAddress] = _status;
        
        emit LogKYCVerification(_kycAddress,_status);
        
        return true;
    }
    
    function isVerified(address _user) view public returns(bool)
    {
        return kycAddress[_user] == true; 
    }
}
pragma solidity ^0.4.24;

contract Owned {
    address public owner;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}
pragma solidity ^0.4.24;
/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
 
library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}
pragma solidity ^0.4.24;

import "./ERC20.sol";
import "./BasicToken.sol";

contract StandardToken is ERC20, BasicToken {

  mapping (address => mapping (address => uint256)) internal allowed;

  function multiTransfer(address[] _to,uint[] _value) public returns (bool);

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
pragma solidity ^0.4.24;
/* import "./oraclizeAPI_0.5.sol"; */
import "./Owned.sol";
import "./BurnableToken.sol";
import "./KYCVerification.sol";

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) external; }

contract UTRAToken is Owned, BurnableToken {

    string public name = "SurePAY Utility, Transaction, Reward and Access Token.";
    string public symbol = "UTRA";
    uint8 public decimals = 5;
    
    uint256 public initialSupply = 8100000000 * (10 ** uint256(decimals));
    uint256 public totalSupply = 8100000000 * (10 ** uint256(decimals));
    uint256 public externalAuthorizePurchase = 0;
    
    
    mapping (address => bool) public frozenAccount;
    mapping(address => uint8) authorizedCaller;
    mapping (address => bool) public lockingEnabled;
    
    bool public kycEnabled = true;

    KYCVerification public kycVerification;

    event KYCMandateUpdate(bool _kycEnabled);
    event KYCContractAddressUpdate(KYCVerification _kycAddress);
    event LockFunds(address _buyer,bool _status);


    modifier onlyAuthCaller(){
        require(authorizedCaller[msg.sender] == 1 || msg.sender == owner);
        _;
    }
    
    /*
        check locking status of user address.
    */
    modifier lockingVerified(address _guy) {
        if(lockingEnabled[_guy] == true){
            revert("Account is locked");
        }
        _;
    }
    
    modifier kycVerified(address _guy) {
      if(kycEnabled == true){
          if(kycVerification.isVerified(_guy) == false)
          {
              revert("KYC Not Verified");
          }
      }
      _;
    }
    
     modifier frozenVerified(address _guy) {
        if(frozenAccount[_guy] == true)
        {
            revert("Account is freeze");
        }
        _;
    }

    function updateKycContractAddress(KYCVerification _kycAddress) public onlyOwner returns(bool)
    {
      kycVerification = _kycAddress;

      emit KYCContractAddressUpdate(_kycAddress);

      return true;
    }

    function updateKycMandate(bool _kycEnabled) public onlyAuthCaller returns(bool)
    {
        kycEnabled = _kycEnabled;
        emit KYCMandateUpdate(_kycEnabled);
        return true;
    }
    
    function forceUpdateLockStatus(address _holder,bool _lock) public onlyAuthCaller returns(bool)
    {
        lockingEnabled[_holder] = _lock;
        emit LockFunds(_holder, _lock);
        return true;
    }

    /* This generates a public event on the blockchain that will notify clients */
    event FrozenFunds(address target, bool frozen);
    
    /* Events */
    event AuthorizedCaller(address caller);
    event DeAuthorizedCaller(address caller);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    constructor() public {
        owner = msg.sender;
        balances[0x49156f159aAf87207fD54401eB1F73974968768C] = totalSupply;
        
        /* unlock totalSupply holder account */
        
        lockingEnabled[0x49156f159aAf87207fD54401eB1F73974968768C] = false;
        
        emit Transfer(address(0x0), address(this), totalSupply);
        emit Transfer(address(this), address(0x49156f159aAf87207fD54401eB1F73974968768C), totalSupply);
            
        authorizedCaller[msg.sender] = 1;
        emit AuthorizedCaller(msg.sender);
    }
    
    /* authorize caller */
    function authorizeCaller(address _caller) public onlyOwner returns(bool) 
    {
        authorizedCaller[_caller] = 1;
        emit AuthorizedCaller(_caller);
        return true;
    }
    
    /* deauthorize caller */
    function deAuthorizeCaller(address _caller) public onlyOwner returns(bool) 
    {
        authorizedCaller[_caller] = 0;
        emit DeAuthorizedCaller(_caller);
        return true;
    }
    
    function () payable public {
        revert();
    }
    

    /* Internal transfer, only can be called by this contract */
    function _transfer(address _from, address _to, uint _value) internal {
        require (_to != 0x0);                               // Prevent transfer to 0x0 address. Use burn() instead
        require (balances[_from] > _value);                // Check if the sender has enough
        require (balances[_to].add(_value) > balances[_to]); // Check for overflow
        balances[_from] = balances[_from].sub(_value);                         // Subtract from the sender
        balances[_to] = balances[_to].add(_value);                           // Add the same to the recipient
        emit Transfer(_from, _to, _value);
    }

    /// @notice Create `mintedAmount` tokens and send it to `target`
    /// @param target Address to receive the tokens
    /// @param mintedAmount the amount of tokens it will receive
    function mintToken(address target, uint256 mintedAmount) onlyOwner public {
        balances[target] = balances[target].add(mintedAmount);
        totalSupply = totalSupply.add(mintedAmount);
        emit Transfer(0, this, mintedAmount);
        emit Transfer(this, target, mintedAmount);
    }

    /// @notice `freeze? Prevent | Allow` `target` from sending & receiving tokens
    /// @param target Address to be frozen
    /// @param freeze either to freeze it or not
    function freezeAccount(address target, bool freeze) onlyOwner public {
        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }


    function purchaseToken(address _receiver, uint _tokens) onlyAuthCaller public {
        require(_tokens > 0);
        require(initialSupply > _tokens);
        
        lockingEnabled[_receiver] = true;
        emit LockFunds(_receiver, true);
        
        initialSupply = initialSupply.sub(_tokens);
        _transfer(owner, _receiver, _tokens);              // makes the transfers
        externalAuthorizePurchase = externalAuthorizePurchase.add(_tokens);
    }

    /**
      * @dev transfer token for a specified address
      * @param _to The address to transfer to.
      * @param _value The amount to be transferred.
    */
    function transfer(address _to, uint256 _value) public kycVerified(msg.sender) frozenVerified(msg.sender) lockingVerified(msg.sender)  returns (bool) {
        _transfer(msg.sender,_to,_value);
        return true;
    }
    
    /*
        Please make sure before calling this function from UI, Sender has sufficient balance for 
        All transfers 
    */
    function multiTransfer(address[] _to,uint[] _value) public kycVerified(msg.sender) frozenVerified(msg.sender) lockingVerified(msg.sender) returns (bool) {
        require(_to.length == _value.length, "Length of Destination should be equal to value");
        for(uint _interator = 0;_interator < _to.length; _interator++ )
        {
            _transfer(msg.sender,_to[_interator],_value[_interator]);
        }
        return true;    
    }
    
    /*
        Lock user address
    */
    function lockUserAddress() public returns(bool){
        lockingEnabled[msg.sender] = true;
        emit LockFunds(msg.sender, true);
    }
    
    /*
        Unlock User Address
    */
    function unlockUserAddress() public returns(bool){
        lockingEnabled[msg.sender] = false;
        emit LockFunds(msg.sender, false);
    }
}

pragma solidity ^0.4.24;

import "./ERC20Basic.sol";
import "./SafeMath.sol";

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
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }

}
pragma solidity ^0.4.24;

import "./StandardToken.sol";

contract BurnableToken is StandardToken {

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
pragma solidity ^0.4.24;
import "./ERC20Basic.sol";

contract ERC20 is ERC20Basic {
  // Optional token name
  string  public  name = "zeosX";
  string  public  symbol;
  uint256  public  decimals = 18; // standard token precision. override to customize
    
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}
pragma solidity ^0.4.24;

contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}
pragma solidity ^0.4.24;

import "./Owned.sol";

contract KYCVerification is Owned{
    
    mapping(address => bool) public kycAddress;
    
    event LogKYCVerification(address _kycAddress,bool _status);
    
    constructor () public {
        owner = msg.sender;
    }

    function updateVerifcationBatch(address[] _kycAddress,bool _status) onlyOwner public returns(bool)
    {
        for(uint tmpIndex = 0; tmpIndex < _kycAddress.length; tmpIndex++)
        {
            kycAddress[_kycAddress[tmpIndex]] = _status;
            emit LogKYCVerification(_kycAddress[tmpIndex],_status);
        }
        
        return true;
    }
    
    function updateVerifcation(address _kycAddress,bool _status) onlyOwner public returns(bool)
    {
        kycAddress[_kycAddress] = _status;
        
        emit LogKYCVerification(_kycAddress,_status);
        
        return true;
    }
    
    function isVerified(address _user) view public returns(bool)
    {
        return kycAddress[_user] == true; 
    }
}
pragma solidity ^0.4.24;

contract Owned {
    address public owner;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}
pragma solidity ^0.4.24;
/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
 
library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}
pragma solidity ^0.4.24;

import "./ERC20.sol";
import "./BasicToken.sol";

contract StandardToken is ERC20, BasicToken {

  mapping (address => mapping (address => uint256)) internal allowed;

  function multiTransfer(address[] _to,uint[] _value) public returns (bool);

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
pragma solidity ^0.4.24;
/* import "./oraclizeAPI_0.5.sol"; */
import "./Owned.sol";
import "./BurnableToken.sol";
import "./KYCVerification.sol";

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) external; }

contract UTRAToken is Owned, BurnableToken {

    string public name = "SurePAY Utility, Transaction, Reward and Access Token.";
    string public symbol = "UTRA";
    uint8 public decimals = 5;
    
    uint256 public initialSupply = 8100000000 * (10 ** uint256(decimals));
    uint256 public totalSupply = 8100000000 * (10 ** uint256(decimals));
    uint256 public externalAuthorizePurchase = 0;
    
    
    mapping (address => bool) public frozenAccount;
    mapping(address => uint8) authorizedCaller;
    mapping (address => bool) public lockingEnabled;
    
    bool public kycEnabled = true;

    KYCVerification public kycVerification;

    event KYCMandateUpdate(bool _kycEnabled);
    event KYCContractAddressUpdate(KYCVerification _kycAddress);
    event LockFunds(address _buyer,bool _status);


    modifier onlyAuthCaller(){
        require(authorizedCaller[msg.sender] == 1 || msg.sender == owner);
        _;
    }
    
    /*
        check locking status of user address.
    */
    modifier lockingVerified(address _guy) {
        if(lockingEnabled[_guy] == true){
            revert("Account is locked");
        }
        _;
    }
    
    modifier kycVerified(address _guy) {
      if(kycEnabled == true){
          if(kycVerification.isVerified(_guy) == false)
          {
              revert("KYC Not Verified");
          }
      }
      _;
    }
    
     modifier frozenVerified(address _guy) {
        if(frozenAccount[_guy] == true)
        {
            revert("Account is freeze");
        }
        _;
    }

    function updateKycContractAddress(KYCVerification _kycAddress) public onlyOwner returns(bool)
    {
      kycVerification = _kycAddress;

      emit KYCContractAddressUpdate(_kycAddress);

      return true;
    }

    function updateKycMandate(bool _kycEnabled) public onlyAuthCaller returns(bool)
    {
        kycEnabled = _kycEnabled;
        emit KYCMandateUpdate(_kycEnabled);
        return true;
    }
    
    function forceUpdateLockStatus(address _holder,bool _lock) public onlyAuthCaller returns(bool)
    {
        lockingEnabled[_holder] = _lock;
        emit LockFunds(_holder, _lock);
        return true;
    }

    /* This generates a public event on the blockchain that will notify clients */
    event FrozenFunds(address target, bool frozen);
    
    /* Events */
    event AuthorizedCaller(address caller);
    event DeAuthorizedCaller(address caller);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    constructor() public {
        owner = msg.sender;
        balances[0x49156f159aAf87207fD54401eB1F73974968768C] = totalSupply;
        
        /* unlock totalSupply holder account */
        
        lockingEnabled[0x49156f159aAf87207fD54401eB1F73974968768C] = false;
        
        emit Transfer(address(0x0), address(this), totalSupply);
        emit Transfer(address(this), address(0x49156f159aAf87207fD54401eB1F73974968768C), totalSupply);
            
        authorizedCaller[msg.sender] = 1;
        emit AuthorizedCaller(msg.sender);
    }
    
    /* authorize caller */
    function authorizeCaller(address _caller) public onlyOwner returns(bool) 
    {
        authorizedCaller[_caller] = 1;
        emit AuthorizedCaller(_caller);
        return true;
    }
    
    /* deauthorize caller */
    function deAuthorizeCaller(address _caller) public onlyOwner returns(bool) 
    {
        authorizedCaller[_caller] = 0;
        emit DeAuthorizedCaller(_caller);
        return true;
    }
    
    function () payable public {
        revert();
    }
    

    /* Internal transfer, only can be called by this contract */
    function _transfer(address _from, address _to, uint _value) internal {
        require (_to != 0x0);                               // Prevent transfer to 0x0 address. Use burn() instead
        require (balances[_from] > _value);                // Check if the sender has enough
        require (balances[_to].add(_value) > balances[_to]); // Check for overflow
        balances[_from] = balances[_from].sub(_value);                         // Subtract from the sender
        balances[_to] = balances[_to].add(_value);                           // Add the same to the recipient
        emit Transfer(_from, _to, _value);
    }

    /// @notice Create `mintedAmount` tokens and send it to `target`
    /// @param target Address to receive the tokens
    /// @param mintedAmount the amount of tokens it will receive
    function mintToken(address target, uint256 mintedAmount) onlyOwner public {
        balances[target] = balances[target].add(mintedAmount);
        totalSupply = totalSupply.add(mintedAmount);
        emit Transfer(0, this, mintedAmount);
        emit Transfer(this, target, mintedAmount);
    }

    /// @notice `freeze? Prevent | Allow` `target` from sending & receiving tokens
    /// @param target Address to be frozen
    /// @param freeze either to freeze it or not
    function freezeAccount(address target, bool freeze) onlyOwner public {
        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }


    function purchaseToken(address _receiver, uint _tokens) onlyAuthCaller public {
        require(_tokens > 0);
        require(initialSupply > _tokens);
        
        lockingEnabled[_receiver] = true;
        emit LockFunds(_receiver, true);
        
        initialSupply = initialSupply.sub(_tokens);
        _transfer(owner, _receiver, _tokens);              // makes the transfers
        externalAuthorizePurchase = externalAuthorizePurchase.add(_tokens);
    }

    /**
      * @dev transfer token for a specified address
      * @param _to The address to transfer to.
      * @param _value The amount to be transferred.
    */
    function transfer(address _to, uint256 _value) public kycVerified(msg.sender) frozenVerified(msg.sender) lockingVerified(msg.sender)  returns (bool) {
        _transfer(msg.sender,_to,_value);
        return true;
    }
    
    /*
        Please make sure before calling this function from UI, Sender has sufficient balance for 
        All transfers 
    */
    function multiTransfer(address[] _to,uint[] _value) public kycVerified(msg.sender) frozenVerified(msg.sender) lockingVerified(msg.sender) returns (bool) {
        require(_to.length == _value.length, "Length of Destination should be equal to value");
        for(uint _interator = 0;_interator < _to.length; _interator++ )
        {
            _transfer(msg.sender,_to[_interator],_value[_interator]);
        }
        return true;    
    }
    
    /*
        Lock user address
    */
    function lockUserAddress() public returns(bool){
        lockingEnabled[msg.sender] = true;
        emit LockFunds(msg.sender, true);
    }
    
    /*
        Unlock User Address
    */
    function unlockUserAddress() public returns(bool){
        lockingEnabled[msg.sender] = false;
        emit LockFunds(msg.sender, false);
    }
}

