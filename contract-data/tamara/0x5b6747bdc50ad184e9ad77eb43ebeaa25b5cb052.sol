pragma solidity ^0.5.0 <0.6.0;

import "./C3StorageInterface.sol";
import "./ERC20ControllerInterface.sol";
import "./C3Emitter.sol";

import "./C3Base.sol";
import "./C3Events.sol";
import "./Ownable.sol";
import "./InteropOwnable.sol";

contract C3 is C3Base, C3Emitter, C3Events, Ownable {
  address private _logicBoardAddress;
  address private _storageAddress;

  string  private _name;
  string  private _symbol;
  uint8   private _decimals;

  constructor(
    string memory pname, string memory psymbol, uint8 pdecimals,
    address _logicBoard, address _storage
  ) public {
    _name = pname;
    _symbol = psymbol;
    _decimals = pdecimals;

    _logicBoardAddress = _logicBoard;
    _storageAddress = _storage;
    _ownerAddr = msg.sender;
  }

  function name() public view returns (string memory) {
    return _name;
  }

  function symbol() public view returns (string memory) {
    return _symbol;
  }

  function decimals() public view returns (uint8) {
    return _decimals;
  }

  function upgradeLogicBoard(address _newLogicBoard) public onlyOwner {
    require(_newLogicBoard != address(0x0), "can't set logic board to a null address");
    _logicBoardAddress = _newLogicBoard;
  }

  function totalSupply() public view returns (uint256) {
    return C3StorageInterface(_storageAddress).totalSupply();
  }

  function balanceOf(address _owner) public view returns (uint256 balance) {
    return C3StorageInterface(_storageAddress).balanceOf(_owner);
  }

  function transfer(address _to, uint256 _value) public returns (bool success) {
    return ERC20ControllerInterface(_logicBoardAddress).transfer(msg.sender, _to, _value);
  }

  function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
    return ERC20ControllerInterface(_logicBoardAddress).transferFrom(msg.sender, _from, _to, _value);
  }

  function approve(address _spender, uint256 _value) public returns (bool success) {
    return ERC20ControllerInterface(_logicBoardAddress).approve(msg.sender, _spender, _value);
  }

  function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
    return ERC20ControllerInterface(_logicBoardAddress).allowance(msg.sender, _owner, _spender);
  }

  function burn(uint256 value) public returns (bool success) {
    return ERC20ControllerInterface(_logicBoardAddress).burn(msg.sender, value);
  }

  function burnFrom(address from, uint256 value) public returns (bool success) {
    return ERC20ControllerInterface(_logicBoardAddress).burnFrom(msg.sender, from, value);
  }

  modifier internalUsage {
    require(msg.sender == _storageAddress || msg.sender == _logicBoardAddress);
    _;
  }

  function fireTransferEvent(address from, address to, uint256 tokens) public internalUsage {
    emit Transfer(from, to, tokens);
  }

  function fireApprovalEvent(address tokenOwner, address spender, uint tokens) public internalUsage {
    emit Approval(tokenOwner, spender, tokens);
  }

  function logicBoard() internal view returns (address) {
    return _logicBoardAddress;
  }
}

pragma solidity ^0.5.0 <0.6.0;

contract C3Base {
  function () external payable {
    _fallback();
  }

  function _fallback() internal {
    _delegateCall(logicBoard());
  }

  function logicBoard() internal view returns (address);

  function _delegateCall(address _logicBoard) internal {
    // solium-disable-next-line security/no-inline-assembly
    assembly {
      // Load msg.data. We take full control of memory in this inline assembly
      // block because it will not return to Solidity code. We overwrite the
      // Solidity scratch pad at memory position 0.
      calldatacopy(0, 0, calldatasize)

      // Call the logicBoard.
      // out and outsize are 0 because we don't know the size yet.
      let result := delegatecall(gas, _logicBoard, 0, calldatasize, 0, 0)

      // Copy the returned data.
      returndatacopy(0, 0, returndatasize)

      switch result
      // delegatecall returns 0 on error.
      case 0 { revert(0, returndatasize) }
      default { return(0, returndatasize) }
    }
  }
}

pragma solidity ^0.5.0 <0.6.0;

interface C3Emitter {
  function fireTransferEvent(address from, address to, uint256 tokens) external;

  function fireApprovalEvent(address tokenOwner, address spender, uint tokens) external;
}

pragma solidity ^0.5.0 <0.6.0;

contract C3Events {
  event Transfer(address indexed from, address indexed to, uint tokens);
  event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

pragma solidity ^0.5.0 <0.6.0;

import "./C3Emitter.sol";
import "./ERC20ControllerInterface.sol";

import "./InteropOwnable.sol";
import "./C3StorageInterface.sol";
import "./SafeMath.sol";

// solium-disable-next-line camelcase
contract C3LogicBoard_V0 is ERC20ControllerInterface, InteropOwnable {
  using SafeMath for uint256;

  C3StorageInterface private _storage;

  C3Emitter private _emitter;

  /**
   * deprecation flag used to disable old logic boards.
   * board owner can use setDeprecationFlag to control this.
   **/
  bool private deprecated = false;

  constructor(address storageImpl) public {
    _storage = C3StorageInterface(storageImpl);

    _ownerAddr = msg.sender;
  }

  function setDeprecationFlag(bool isDeprecated) external onlyOwner {
    deprecated = isDeprecated;
  }

  function setStorage(C3StorageInterface _newStorage) external onlyOwner {
    _storage = _newStorage;
  }

  function balanceOf(
    address /*_requestedBy*/,
    address owner) external view returns (uint256 balance) {
    require(!deprecated);
    return _storage.balanceOf(owner);
  }

  function transfer(
    address _requestedBy,
    address _to, uint256 _value) external onlyInteropOwner returns (bool success) {
    require(!deprecated);
    return _transfer(_requestedBy, _requestedBy, _to, _value);
  }

  function transferFrom(
    address _requestedBy,
    address _from, address _to, uint256 _value) external onlyInteropOwner returns (bool success) {
    require(!deprecated);

    return _transfer(_requestedBy, _from, _to, _value);
  }

  function approve(address _requestedBy, address _spender, uint256 _value)
    external onlyInteropOwner returns (bool success) {
    require(!deprecated);
    require(_storage.balanceOf(_requestedBy) >= _value, "insufficient funds");

    // see https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM
    require(
      _storage.allowance(_requestedBy, _spender) == 0 || _value == 0,
      "you should reset your previous allowance value for this spender."
    );

    _emitter.fireApprovalEvent(_requestedBy, _spender, _value);
    return _storage.approve(_requestedBy, _spender, _value);
  }

  function allowance(
    address /*_requestedBy*/,
    address _owner, address _spender) external onlyInteropOwner view returns (uint256 remaining) {
    require(!deprecated);
    require(_spender != address(0x0));
    return _storage.allowance(_owner, _spender);
  }

  function totalSupply(address /*requestedBy*/) external view returns (uint256) {
    require(!deprecated);
    return _storage.totalSupply();
  }

  function burn(address requestedBy, uint256 value) external onlyInteropOwner returns (bool success) {
    require(!deprecated);
    return _burn(requestedBy, requestedBy, value);
  }

  function burnFrom(address requestedBy, address from, uint256 value) external onlyInteropOwner returns (bool success) {
    require(!deprecated);
    return _burn(requestedBy, from, value);
  }

  function setEmitterAddress(address emitter) public onlyOwner {
    require(emitter != address(0x0));
    _emitter = C3Emitter(emitter);
  }

  function _burn(address _requestedBy, address _from, uint256 _value) private returns (bool success) {
    require(!deprecated);
    if (_requestedBy == _from) {
    // if transfer requested by owner, check if owner got enough funds
      require(_storage.balanceOf(_from) >= _value, "insufficient funds");
    } else {
      // if transfer was not requested by owner, we must check for both:
      //   1) if owner allowed enough funds to the potential spender (a.k.a. request's sender)
      //   2) and if owner actually got enough funds for the spender
      require(_storage.allowance(_from, _requestedBy) >= _value && _storage.balanceOf(_from) >= _value, "insufficient allowance or funds");
    }

    if (_value != 0) {
      require(_storage.balanceSub(_from, _value));
      require(_storage.totalSupplySub(_value));
    }
    _emitter.fireTransferEvent(_from, address(0x0), _value);

    return true;
  }

  function _transfer(address _requestedBy, address _from, address _to, uint256 _value) private returns (bool success) {
    require(!deprecated);
    //solium-disable operator-whitespace
    require(
      // burn operation requires additional checks and operations,
      // so we're disabling this via _transfer
      _to != address(0x0) &&
      // transfering tokens to logic boards, storage or root token contract
      // is basically is a burn operation. without reducing totalSupply
      // that tokens would be wasted.
      _to != address(this) &&
      _to != address(_storage) &&
      _to != address(_emitter),
      "use burn()/burnFrom() method instead"
    );

    if (_requestedBy == _from) {
    // if transfer requested by owner, check if owner got enough funds
      require(_storage.balanceOf(_from) >= _value, "insufficient funds");
    } else {
      // if transfer was not requested by owner, we must check for both:
      //   1) if owner allowed enough funds to the potential spender (a.k.a. request's sender)
      //   2) and if owner actually got enough funds for the spender
      require(_storage.allowance(_from, _requestedBy) >= _value && _storage.balanceOf(_from) >= _value, "insufficient allowance or funds");
    }

    // transfers with _value = 0 MUST be treated as normal transfers and fire the Transfer event.
    if (_value != 0) {
      require(_storage.balanceTransfer(_from, _to, _value));
    }
    _emitter.fireTransferEvent(_from, _to, _value);

    return true;
  }
}

pragma solidity ^0.5.0 <0.6.0;

import "./C3Emitter.sol";

import "./InteropOwnable.sol";
import "./SafeMath.sol";
import "./C3Events.sol";

import "./ReentrancyGuard.sol";

contract C3Storage is InteropOwnable, C3Events, ReentrancyGuard {
  using SafeMath for uint256;

  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowed;

  uint256 private _totalSupply;
  address private _emitter;
  bool private storageInitialized;

  constructor(uint256 initialSupply) public {
    _totalSupply = initialSupply;
    _ownerAddr = msg.sender;
  }

  function balanceOf(address owner) external view returns (uint256) {
    require(storageInitialized);
    return _balances[owner];
  }

  function balanceAdd(address _owner, uint256 value) external onlyInteropOwner nonReentrant returns (bool success) {
    require(storageInitialized);
    if (_balances[_owner] == 0) {
      _balances[_owner] = value;
      return true;
    }
    _balances[_owner] = _balances[_owner].add(value);
    return true;
  }

  function balanceSub(address _owner, uint256 value) external onlyInteropOwner nonReentrant returns (bool success) {
    require(storageInitialized);
    if (_balances[_owner] < value) {
      return false;
    }

    _balances[_owner] = _balances[_owner].sub(value);
    return true;
  }

  function balanceTransfer(address _from, address _to, uint256 value)
    external onlyInteropOwner nonReentrant returns (bool success) {
    require(storageInitialized);
    if (_balances[_from] < value) {
      return false;
    }
    _balances[_from] = _balances[_from].sub(value);
    _balances[_to] = _balances[_to].add(value);
    return true;
  }

  function allowance(address _owner, address _spender) external view returns (uint256 remaining) {
    require(storageInitialized);
    return _allowed[_owner][_spender];
  }

  function approve(address _owner, address _spender, uint256 value) external onlyInteropOwner returns (bool success) {
    require(storageInitialized);
    _allowed[_owner][_spender] = value;

    return true;
  }

  function totalSupply() external view returns (uint256) {
    require(storageInitialized);
    return _totalSupply;
  }

  function totalSupplyAdd(uint256 value) external onlyInteropOwner returns (bool success) {
    require(storageInitialized);
    _totalSupply = _totalSupply.add(value);
    return true;
  }

  function totalSupplySub(uint256 value) external onlyInteropOwner returns (bool success) {
    require(storageInitialized);
    if (value > _totalSupply) {
      return false;
    }

    _totalSupply = _totalSupply.sub(value);
    return true;
  }

  function setEmitterAddress(address emitter) external onlyOwner {
    require(emitter != address(0x0));
    _emitter = emitter;
  }

  function initializeTokens() public onlyOwner {
    require(!storageInitialized && _emitter != address(0x0), "storage was already initialized or emitter was not set");
    _balances[_ownerAddr] = _totalSupply;
    C3Emitter(_emitter).fireTransferEvent(address(0x0), _ownerAddr, _totalSupply);
    storageInitialized = true;
  }
}

pragma solidity ^0.5.0 <0.6.0;

interface C3StorageInterface {
  function balanceOf(address _owner) external view returns (uint256 balance);
  function balanceAdd(address _to, uint256 value) external returns (bool success);
  function balanceSub(address _to, uint256 value) external returns (bool success);
  function balanceTransfer(address _from, address _to, uint256 value)
    external returns (bool success);

  function allowance(address _owner, address _spender) external view returns (uint256 remaining);
  function approve(address _owner, address _to, uint256 value) external returns (bool success);

  function totalSupply() external view returns (uint256);
  function totalSupplyAdd(uint256 value) external returns (bool success);
  function totalSupplySub(uint256 value) external returns (bool success);
}

pragma solidity ^0.5.0 <0.6.0;

interface ERC20ControllerInterface {
  function totalSupply(address _requestedBy) external view returns (uint256);
  function balanceOf(address _requestedBy, address tokenOwner) external view returns (uint256 balance);
  function allowance(address _requestedBy, address tokenOwner, address spender)
    external view returns (uint256 remaining);
  function transfer(address _requestedBy, address to, uint256 tokens) external returns (bool success);
  function approve(address _requestedBy, address spender, uint256 tokens) external returns (bool success);
  function transferFrom(address _requestedBy, address from, address to, uint256 tokens) external returns (bool success);

  function burn(address _requestedBy, uint256 value) external returns (bool success);
  function burnFrom(address _requestedBy, address from, uint256 value) external returns (bool success);
}

pragma solidity ^0.5.0 <0.6.0;

contract ERC20Interface {
  function totalSupply() public view returns (uint256);
  function balanceOf(address tokenOwner) public view returns (uint256 balance);
  function allowance(address tokenOwner, address spender) public view returns (uint256 remaining);
  function transfer(address to, uint256 tokens) public returns (bool success);
  function approve(address spender, uint256 tokens) public returns (bool success);
  function transferFrom(address from, address to, uint256 tokens) public returns (bool success);
}

pragma solidity ^0.5.0 <0.6.0;

import "./Ownable.sol";

contract InteropOwnable is Ownable {
  mapping (address => bool) internal _interopOwners;

  modifier onlyInteropOwner {
    require(_interopOwners[msg.sender], "this method is only for interop owner");
    _;
  }

  function addInteropOwner(address newOwner) public onlyOwner {
    _interopOwners[newOwner] = true;
  }

  function removeInteropOwner(address newOwner) public onlyOwner {
    _interopOwners[newOwner] = false;
  }
}

pragma solidity ^0.5.0 <0.6.0;

contract Ownable {
  address internal _ownerAddr;

  modifier onlyOwner {
    require(msg.sender == _ownerAddr, "this method is only for owner");
    _;
  }

  function updateOwner(address newOwner) public onlyOwner {
    _ownerAddr = newOwner;
  }
}

pragma solidity ^0.5.0 <0.6.0;

contract ReentrancyGuard {
  uint256 private _currentCounterState;

  constructor () public {
    _currentCounterState = 1;
  }

  modifier nonReentrant() {
    _currentCounterState++;
    uint256 originalCounterState = _currentCounterState;
    _;
    require(originalCounterState == _currentCounterState);
  }
}

pragma solidity ^0.5.0 <0.6.0;

library SafeMath {
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, "overflow protection");

    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a, "overflow protection");
    uint256 c = a - b;

    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0, "divide by zero");
    uint256 c = a / b;

    return c;
  }

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b, "overflow protection");

    return c;
  }

  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0, "divide by zero");

    uint256 c = a % b;
    return c;
  }
}

pragma solidity ^0.5.0 <0.6.0;

contract C3Utils {
  function isContract(address x) internal view returns(bool) {
    uint256 size;
    // For now there is no better way to check if there is a contract in an address
    // than to check the size of the code at that address.
    // See https://ethereum.stackexchange.com/a/14016/36603
    // for more details about how this works.

    // solium-disable-next-line security/no-inline-assembly
    assembly { size := extcodesize(x) }
    return size > 0;
  }
}
pragma solidity ^0.5.0 <0.6.0;

import "./C3StorageInterface.sol";
import "./ERC20ControllerInterface.sol";
import "./C3Emitter.sol";

import "./C3Base.sol";
import "./C3Events.sol";
import "./Ownable.sol";
import "./InteropOwnable.sol";

contract C3 is C3Base, C3Emitter, C3Events, Ownable {
  address private _logicBoardAddress;
  address private _storageAddress;

  string  private _name;
  string  private _symbol;
  uint8   private _decimals;

  constructor(
    string memory pname, string memory psymbol, uint8 pdecimals,
    address _logicBoard, address _storage
  ) public {
    _name = pname;
    _symbol = psymbol;
    _decimals = pdecimals;

    _logicBoardAddress = _logicBoard;
    _storageAddress = _storage;
    _ownerAddr = msg.sender;
  }

  function name() public view returns (string memory) {
    return _name;
  }

  function symbol() public view returns (string memory) {
    return _symbol;
  }

  function decimals() public view returns (uint8) {
    return _decimals;
  }

  function upgradeLogicBoard(address _newLogicBoard) public onlyOwner {
    require(_newLogicBoard != address(0x0), "can't set logic board to a null address");
    _logicBoardAddress = _newLogicBoard;
  }

  function totalSupply() public view returns (uint256) {
    return C3StorageInterface(_storageAddress).totalSupply();
  }

  function balanceOf(address _owner) public view returns (uint256 balance) {
    return C3StorageInterface(_storageAddress).balanceOf(_owner);
  }

  function transfer(address _to, uint256 _value) public returns (bool success) {
    return ERC20ControllerInterface(_logicBoardAddress).transfer(msg.sender, _to, _value);
  }

  function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
    return ERC20ControllerInterface(_logicBoardAddress).transferFrom(msg.sender, _from, _to, _value);
  }

  function approve(address _spender, uint256 _value) public returns (bool success) {
    return ERC20ControllerInterface(_logicBoardAddress).approve(msg.sender, _spender, _value);
  }

  function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
    return ERC20ControllerInterface(_logicBoardAddress).allowance(msg.sender, _owner, _spender);
  }

  function burn(uint256 value) public returns (bool success) {
    return ERC20ControllerInterface(_logicBoardAddress).burn(msg.sender, value);
  }

  function burnFrom(address from, uint256 value) public returns (bool success) {
    return ERC20ControllerInterface(_logicBoardAddress).burnFrom(msg.sender, from, value);
  }

  modifier internalUsage {
    require(msg.sender == _storageAddress || msg.sender == _logicBoardAddress);
    _;
  }

  function fireTransferEvent(address from, address to, uint256 tokens) public internalUsage {
    emit Transfer(from, to, tokens);
  }

  function fireApprovalEvent(address tokenOwner, address spender, uint tokens) public internalUsage {
    emit Approval(tokenOwner, spender, tokens);
  }

  function logicBoard() internal view returns (address) {
    return _logicBoardAddress;
  }
}

pragma solidity ^0.5.0 <0.6.0;

contract C3Base {
  function () external payable {
    _fallback();
  }

  function _fallback() internal {
    _delegateCall(logicBoard());
  }

  function logicBoard() internal view returns (address);

  function _delegateCall(address _logicBoard) internal {
    // solium-disable-next-line security/no-inline-assembly
    assembly {
      // Load msg.data. We take full control of memory in this inline assembly
      // block because it will not return to Solidity code. We overwrite the
      // Solidity scratch pad at memory position 0.
      calldatacopy(0, 0, calldatasize)

      // Call the logicBoard.
      // out and outsize are 0 because we don't know the size yet.
      let result := delegatecall(gas, _logicBoard, 0, calldatasize, 0, 0)

      // Copy the returned data.
      returndatacopy(0, 0, returndatasize)

      switch result
      // delegatecall returns 0 on error.
      case 0 { revert(0, returndatasize) }
      default { return(0, returndatasize) }
    }
  }
}

pragma solidity ^0.5.0 <0.6.0;

interface C3Emitter {
  function fireTransferEvent(address from, address to, uint256 tokens) external;

  function fireApprovalEvent(address tokenOwner, address spender, uint tokens) external;
}

pragma solidity ^0.5.0 <0.6.0;

contract C3Events {
  event Transfer(address indexed from, address indexed to, uint tokens);
  event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

pragma solidity ^0.5.0 <0.6.0;

import "./C3Emitter.sol";
import "./ERC20ControllerInterface.sol";

import "./InteropOwnable.sol";
import "./C3StorageInterface.sol";
import "./SafeMath.sol";

// solium-disable-next-line camelcase
contract C3LogicBoard_V0 is ERC20ControllerInterface, InteropOwnable {
  using SafeMath for uint256;

  C3StorageInterface private _storage;

  C3Emitter private _emitter;

  /**
   * deprecation flag used to disable old logic boards.
   * board owner can use setDeprecationFlag to control this.
   **/
  bool private deprecated = false;

  constructor(address storageImpl) public {
    _storage = C3StorageInterface(storageImpl);

    _ownerAddr = msg.sender;
  }

  function setDeprecationFlag(bool isDeprecated) external onlyOwner {
    deprecated = isDeprecated;
  }

  function setStorage(C3StorageInterface _newStorage) external onlyOwner {
    _storage = _newStorage;
  }

  function balanceOf(
    address /*_requestedBy*/,
    address owner) external view returns (uint256 balance) {
    require(!deprecated);
    return _storage.balanceOf(owner);
  }

  function transfer(
    address _requestedBy,
    address _to, uint256 _value) external onlyInteropOwner returns (bool success) {
    require(!deprecated);
    return _transfer(_requestedBy, _requestedBy, _to, _value);
  }

  function transferFrom(
    address _requestedBy,
    address _from, address _to, uint256 _value) external onlyInteropOwner returns (bool success) {
    require(!deprecated);

    return _transfer(_requestedBy, _from, _to, _value);
  }

  function approve(address _requestedBy, address _spender, uint256 _value)
    external onlyInteropOwner returns (bool success) {
    require(!deprecated);
    require(_storage.balanceOf(_requestedBy) >= _value, "insufficient funds");

    // see https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM
    require(
      _storage.allowance(_requestedBy, _spender) == 0 || _value == 0,
      "you should reset your previous allowance value for this spender."
    );

    _emitter.fireApprovalEvent(_requestedBy, _spender, _value);
    return _storage.approve(_requestedBy, _spender, _value);
  }

  function allowance(
    address /*_requestedBy*/,
    address _owner, address _spender) external onlyInteropOwner view returns (uint256 remaining) {
    require(!deprecated);
    require(_spender != address(0x0));
    return _storage.allowance(_owner, _spender);
  }

  function totalSupply(address /*requestedBy*/) external view returns (uint256) {
    require(!deprecated);
    return _storage.totalSupply();
  }

  function burn(address requestedBy, uint256 value) external onlyInteropOwner returns (bool success) {
    require(!deprecated);
    return _burn(requestedBy, requestedBy, value);
  }

  function burnFrom(address requestedBy, address from, uint256 value) external onlyInteropOwner returns (bool success) {
    require(!deprecated);
    return _burn(requestedBy, from, value);
  }

  function setEmitterAddress(address emitter) public onlyOwner {
    require(emitter != address(0x0));
    _emitter = C3Emitter(emitter);
  }

  function _burn(address _requestedBy, address _from, uint256 _value) private returns (bool success) {
    require(!deprecated);
    if (_requestedBy == _from) {
    // if transfer requested by owner, check if owner got enough funds
      require(_storage.balanceOf(_from) >= _value, "insufficient funds");
    } else {
      // if transfer was not requested by owner, we must check for both:
      //   1) if owner allowed enough funds to the potential spender (a.k.a. request's sender)
      //   2) and if owner actually got enough funds for the spender
      require(_storage.allowance(_from, _requestedBy) >= _value && _storage.balanceOf(_from) >= _value, "insufficient allowance or funds");
    }

    if (_value != 0) {
      require(_storage.balanceSub(_from, _value));
      require(_storage.totalSupplySub(_value));
    }
    _emitter.fireTransferEvent(_from, address(0x0), _value);

    return true;
  }

  function _transfer(address _requestedBy, address _from, address _to, uint256 _value) private returns (bool success) {
    require(!deprecated);
    //solium-disable operator-whitespace
    require(
      // burn operation requires additional checks and operations,
      // so we're disabling this via _transfer
      _to != address(0x0) &&
      // transfering tokens to logic boards, storage or root token contract
      // is basically is a burn operation. without reducing totalSupply
      // that tokens would be wasted.
      _to != address(this) &&
      _to != address(_storage) &&
      _to != address(_emitter),
      "use burn()/burnFrom() method instead"
    );

    if (_requestedBy == _from) {
    // if transfer requested by owner, check if owner got enough funds
      require(_storage.balanceOf(_from) >= _value, "insufficient funds");
    } else {
      // if transfer was not requested by owner, we must check for both:
      //   1) if owner allowed enough funds to the potential spender (a.k.a. request's sender)
      //   2) and if owner actually got enough funds for the spender
      require(_storage.allowance(_from, _requestedBy) >= _value && _storage.balanceOf(_from) >= _value, "insufficient allowance or funds");
    }

    // transfers with _value = 0 MUST be treated as normal transfers and fire the Transfer event.
    if (_value != 0) {
      require(_storage.balanceTransfer(_from, _to, _value));
    }
    _emitter.fireTransferEvent(_from, _to, _value);

    return true;
  }
}

pragma solidity ^0.5.0 <0.6.0;

import "./C3Emitter.sol";

import "./InteropOwnable.sol";
import "./SafeMath.sol";
import "./C3Events.sol";

import "./ReentrancyGuard.sol";

contract C3Storage is InteropOwnable, C3Events, ReentrancyGuard {
  using SafeMath for uint256;

  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowed;

  uint256 private _totalSupply;
  address private _emitter;
  bool private storageInitialized;

  constructor(uint256 initialSupply) public {
    _totalSupply = initialSupply;
    _ownerAddr = msg.sender;
  }

  function balanceOf(address owner) external view returns (uint256) {
    require(storageInitialized);
    return _balances[owner];
  }

  function balanceAdd(address _owner, uint256 value) external onlyInteropOwner nonReentrant returns (bool success) {
    require(storageInitialized);
    if (_balances[_owner] == 0) {
      _balances[_owner] = value;
      return true;
    }
    _balances[_owner] = _balances[_owner].add(value);
    return true;
  }

  function balanceSub(address _owner, uint256 value) external onlyInteropOwner nonReentrant returns (bool success) {
    require(storageInitialized);
    if (_balances[_owner] < value) {
      return false;
    }

    _balances[_owner] = _balances[_owner].sub(value);
    return true;
  }

  function balanceTransfer(address _from, address _to, uint256 value)
    external onlyInteropOwner nonReentrant returns (bool success) {
    require(storageInitialized);
    if (_balances[_from] < value) {
      return false;
    }
    _balances[_from] = _balances[_from].sub(value);
    _balances[_to] = _balances[_to].add(value);
    return true;
  }

  function allowance(address _owner, address _spender) external view returns (uint256 remaining) {
    require(storageInitialized);
    return _allowed[_owner][_spender];
  }

  function approve(address _owner, address _spender, uint256 value) external onlyInteropOwner returns (bool success) {
    require(storageInitialized);
    _allowed[_owner][_spender] = value;

    return true;
  }

  function totalSupply() external view returns (uint256) {
    require(storageInitialized);
    return _totalSupply;
  }

  function totalSupplyAdd(uint256 value) external onlyInteropOwner returns (bool success) {
    require(storageInitialized);
    _totalSupply = _totalSupply.add(value);
    return true;
  }

  function totalSupplySub(uint256 value) external onlyInteropOwner returns (bool success) {
    require(storageInitialized);
    if (value > _totalSupply) {
      return false;
    }

    _totalSupply = _totalSupply.sub(value);
    return true;
  }

  function setEmitterAddress(address emitter) external onlyOwner {
    require(emitter != address(0x0));
    _emitter = emitter;
  }

  function initializeTokens() public onlyOwner {
    require(!storageInitialized && _emitter != address(0x0), "storage was already initialized or emitter was not set");
    _balances[_ownerAddr] = _totalSupply;
    C3Emitter(_emitter).fireTransferEvent(address(0x0), _ownerAddr, _totalSupply);
    storageInitialized = true;
  }
}

pragma solidity ^0.5.0 <0.6.0;

interface C3StorageInterface {
  function balanceOf(address _owner) external view returns (uint256 balance);
  function balanceAdd(address _to, uint256 value) external returns (bool success);
  function balanceSub(address _to, uint256 value) external returns (bool success);
  function balanceTransfer(address _from, address _to, uint256 value)
    external returns (bool success);

  function allowance(address _owner, address _spender) external view returns (uint256 remaining);
  function approve(address _owner, address _to, uint256 value) external returns (bool success);

  function totalSupply() external view returns (uint256);
  function totalSupplyAdd(uint256 value) external returns (bool success);
  function totalSupplySub(uint256 value) external returns (bool success);
}

pragma solidity ^0.5.0 <0.6.0;

interface ERC20ControllerInterface {
  function totalSupply(address _requestedBy) external view returns (uint256);
  function balanceOf(address _requestedBy, address tokenOwner) external view returns (uint256 balance);
  function allowance(address _requestedBy, address tokenOwner, address spender)
    external view returns (uint256 remaining);
  function transfer(address _requestedBy, address to, uint256 tokens) external returns (bool success);
  function approve(address _requestedBy, address spender, uint256 tokens) external returns (bool success);
  function transferFrom(address _requestedBy, address from, address to, uint256 tokens) external returns (bool success);

  function burn(address _requestedBy, uint256 value) external returns (bool success);
  function burnFrom(address _requestedBy, address from, uint256 value) external returns (bool success);
}

pragma solidity ^0.5.0 <0.6.0;

contract ERC20Interface {
  function totalSupply() public view returns (uint256);
  function balanceOf(address tokenOwner) public view returns (uint256 balance);
  function allowance(address tokenOwner, address spender) public view returns (uint256 remaining);
  function transfer(address to, uint256 tokens) public returns (bool success);
  function approve(address spender, uint256 tokens) public returns (bool success);
  function transferFrom(address from, address to, uint256 tokens) public returns (bool success);
}

pragma solidity ^0.5.0 <0.6.0;

import "./Ownable.sol";

contract InteropOwnable is Ownable {
  mapping (address => bool) internal _interopOwners;

  modifier onlyInteropOwner {
    require(_interopOwners[msg.sender], "this method is only for interop owner");
    _;
  }

  function addInteropOwner(address newOwner) public onlyOwner {
    _interopOwners[newOwner] = true;
  }

  function removeInteropOwner(address newOwner) public onlyOwner {
    _interopOwners[newOwner] = false;
  }
}

pragma solidity ^0.5.0 <0.6.0;

contract Ownable {
  address internal _ownerAddr;

  modifier onlyOwner {
    require(msg.sender == _ownerAddr, "this method is only for owner");
    _;
  }

  function updateOwner(address newOwner) public onlyOwner {
    _ownerAddr = newOwner;
  }
}

pragma solidity ^0.5.0 <0.6.0;

contract ReentrancyGuard {
  uint256 private _currentCounterState;

  constructor () public {
    _currentCounterState = 1;
  }

  modifier nonReentrant() {
    _currentCounterState++;
    uint256 originalCounterState = _currentCounterState;
    _;
    require(originalCounterState == _currentCounterState);
  }
}

pragma solidity ^0.5.0 <0.6.0;

library SafeMath {
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, "overflow protection");

    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a, "overflow protection");
    uint256 c = a - b;

    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0, "divide by zero");
    uint256 c = a / b;

    return c;
  }

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b, "overflow protection");

    return c;
  }

  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0, "divide by zero");

    uint256 c = a % b;
    return c;
  }
}

pragma solidity ^0.5.0 <0.6.0;

contract C3Utils {
  function isContract(address x) internal view returns(bool) {
    uint256 size;
    // For now there is no better way to check if there is a contract in an address
    // than to check the size of the code at that address.
    // See https://ethereum.stackexchange.com/a/14016/36603
    // for more details about how this works.

    // solium-disable-next-line security/no-inline-assembly
    assembly { size := extcodesize(x) }
    return size > 0;
  }
}
pragma solidity ^0.5.0 <0.6.0;

import "./C3StorageInterface.sol";
import "./ERC20ControllerInterface.sol";
import "./C3Emitter.sol";

import "./C3Base.sol";
import "./C3Events.sol";
import "./Ownable.sol";
import "./InteropOwnable.sol";

contract C3 is C3Base, C3Emitter, C3Events, Ownable {
  address private _logicBoardAddress;
  address private _storageAddress;

  string  private _name;
  string  private _symbol;
  uint8   private _decimals;

  constructor(
    string memory pname, string memory psymbol, uint8 pdecimals,
    address _logicBoard, address _storage
  ) public {
    _name = pname;
    _symbol = psymbol;
    _decimals = pdecimals;

    _logicBoardAddress = _logicBoard;
    _storageAddress = _storage;
    _ownerAddr = msg.sender;
  }

  function name() public view returns (string memory) {
    return _name;
  }

  function symbol() public view returns (string memory) {
    return _symbol;
  }

  function decimals() public view returns (uint8) {
    return _decimals;
  }

  function upgradeLogicBoard(address _newLogicBoard) public onlyOwner {
    require(_newLogicBoard != address(0x0), "can't set logic board to a null address");
    _logicBoardAddress = _newLogicBoard;
  }

  function totalSupply() public view returns (uint256) {
    return C3StorageInterface(_storageAddress).totalSupply();
  }

  function balanceOf(address _owner) public view returns (uint256 balance) {
    return C3StorageInterface(_storageAddress).balanceOf(_owner);
  }

  function transfer(address _to, uint256 _value) public returns (bool success) {
    return ERC20ControllerInterface(_logicBoardAddress).transfer(msg.sender, _to, _value);
  }

  function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
    return ERC20ControllerInterface(_logicBoardAddress).transferFrom(msg.sender, _from, _to, _value);
  }

  function approve(address _spender, uint256 _value) public returns (bool success) {
    return ERC20ControllerInterface(_logicBoardAddress).approve(msg.sender, _spender, _value);
  }

  function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
    return ERC20ControllerInterface(_logicBoardAddress).allowance(msg.sender, _owner, _spender);
  }

  function burn(uint256 value) public returns (bool success) {
    return ERC20ControllerInterface(_logicBoardAddress).burn(msg.sender, value);
  }

  function burnFrom(address from, uint256 value) public returns (bool success) {
    return ERC20ControllerInterface(_logicBoardAddress).burnFrom(msg.sender, from, value);
  }

  modifier internalUsage {
    require(msg.sender == _storageAddress || msg.sender == _logicBoardAddress);
    _;
  }

  function fireTransferEvent(address from, address to, uint256 tokens) public internalUsage {
    emit Transfer(from, to, tokens);
  }

  function fireApprovalEvent(address tokenOwner, address spender, uint tokens) public internalUsage {
    emit Approval(tokenOwner, spender, tokens);
  }

  function logicBoard() internal view returns (address) {
    return _logicBoardAddress;
  }
}

pragma solidity ^0.5.0 <0.6.0;

contract C3Base {
  function () external payable {
    _fallback();
  }

  function _fallback() internal {
    _delegateCall(logicBoard());
  }

  function logicBoard() internal view returns (address);

  function _delegateCall(address _logicBoard) internal {
    // solium-disable-next-line security/no-inline-assembly
    assembly {
      // Load msg.data. We take full control of memory in this inline assembly
      // block because it will not return to Solidity code. We overwrite the
      // Solidity scratch pad at memory position 0.
      calldatacopy(0, 0, calldatasize)

      // Call the logicBoard.
      // out and outsize are 0 because we don't know the size yet.
      let result := delegatecall(gas, _logicBoard, 0, calldatasize, 0, 0)

      // Copy the returned data.
      returndatacopy(0, 0, returndatasize)

      switch result
      // delegatecall returns 0 on error.
      case 0 { revert(0, returndatasize) }
      default { return(0, returndatasize) }
    }
  }
}

pragma solidity ^0.5.0 <0.6.0;

interface C3Emitter {
  function fireTransferEvent(address from, address to, uint256 tokens) external;

  function fireApprovalEvent(address tokenOwner, address spender, uint tokens) external;
}

pragma solidity ^0.5.0 <0.6.0;

contract C3Events {
  event Transfer(address indexed from, address indexed to, uint tokens);
  event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

pragma solidity ^0.5.0 <0.6.0;

import "./C3Emitter.sol";
import "./ERC20ControllerInterface.sol";

import "./InteropOwnable.sol";
import "./C3StorageInterface.sol";
import "./SafeMath.sol";

// solium-disable-next-line camelcase
contract C3LogicBoard_V0 is ERC20ControllerInterface, InteropOwnable {
  using SafeMath for uint256;

  C3StorageInterface private _storage;

  C3Emitter private _emitter;

  /**
   * deprecation flag used to disable old logic boards.
   * board owner can use setDeprecationFlag to control this.
   **/
  bool private deprecated = false;

  constructor(address storageImpl) public {
    _storage = C3StorageInterface(storageImpl);

    _ownerAddr = msg.sender;
  }

  function setDeprecationFlag(bool isDeprecated) external onlyOwner {
    deprecated = isDeprecated;
  }

  function setStorage(C3StorageInterface _newStorage) external onlyOwner {
    _storage = _newStorage;
  }

  function balanceOf(
    address /*_requestedBy*/,
    address owner) external view returns (uint256 balance) {
    require(!deprecated);
    return _storage.balanceOf(owner);
  }

  function transfer(
    address _requestedBy,
    address _to, uint256 _value) external onlyInteropOwner returns (bool success) {
    require(!deprecated);
    return _transfer(_requestedBy, _requestedBy, _to, _value);
  }

  function transferFrom(
    address _requestedBy,
    address _from, address _to, uint256 _value) external onlyInteropOwner returns (bool success) {
    require(!deprecated);

    return _transfer(_requestedBy, _from, _to, _value);
  }

  function approve(address _requestedBy, address _spender, uint256 _value)
    external onlyInteropOwner returns (bool success) {
    require(!deprecated);
    require(_storage.balanceOf(_requestedBy) >= _value, "insufficient funds");

    // see https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM
    require(
      _storage.allowance(_requestedBy, _spender) == 0 || _value == 0,
      "you should reset your previous allowance value for this spender."
    );

    _emitter.fireApprovalEvent(_requestedBy, _spender, _value);
    return _storage.approve(_requestedBy, _spender, _value);
  }

  function allowance(
    address /*_requestedBy*/,
    address _owner, address _spender) external onlyInteropOwner view returns (uint256 remaining) {
    require(!deprecated);
    require(_spender != address(0x0));
    return _storage.allowance(_owner, _spender);
  }

  function totalSupply(address /*requestedBy*/) external view returns (uint256) {
    require(!deprecated);
    return _storage.totalSupply();
  }

  function burn(address requestedBy, uint256 value) external onlyInteropOwner returns (bool success) {
    require(!deprecated);
    return _burn(requestedBy, requestedBy, value);
  }

  function burnFrom(address requestedBy, address from, uint256 value) external onlyInteropOwner returns (bool success) {
    require(!deprecated);
    return _burn(requestedBy, from, value);
  }

  function setEmitterAddress(address emitter) public onlyOwner {
    require(emitter != address(0x0));
    _emitter = C3Emitter(emitter);
  }

  function _burn(address _requestedBy, address _from, uint256 _value) private returns (bool success) {
    require(!deprecated);
    if (_requestedBy == _from) {
    // if transfer requested by owner, check if owner got enough funds
      require(_storage.balanceOf(_from) >= _value, "insufficient funds");
    } else {
      // if transfer was not requested by owner, we must check for both:
      //   1) if owner allowed enough funds to the potential spender (a.k.a. request's sender)
      //   2) and if owner actually got enough funds for the spender
      require(_storage.allowance(_from, _requestedBy) >= _value && _storage.balanceOf(_from) >= _value, "insufficient allowance or funds");
    }

    if (_value != 0) {
      require(_storage.balanceSub(_from, _value));
      require(_storage.totalSupplySub(_value));
    }
    _emitter.fireTransferEvent(_from, address(0x0), _value);

    return true;
  }

  function _transfer(address _requestedBy, address _from, address _to, uint256 _value) private returns (bool success) {
    require(!deprecated);
    //solium-disable operator-whitespace
    require(
      // burn operation requires additional checks and operations,
      // so we're disabling this via _transfer
      _to != address(0x0) &&
      // transfering tokens to logic boards, storage or root token contract
      // is basically is a burn operation. without reducing totalSupply
      // that tokens would be wasted.
      _to != address(this) &&
      _to != address(_storage) &&
      _to != address(_emitter),
      "use burn()/burnFrom() method instead"
    );

    if (_requestedBy == _from) {
    // if transfer requested by owner, check if owner got enough funds
      require(_storage.balanceOf(_from) >= _value, "insufficient funds");
    } else {
      // if transfer was not requested by owner, we must check for both:
      //   1) if owner allowed enough funds to the potential spender (a.k.a. request's sender)
      //   2) and if owner actually got enough funds for the spender
      require(_storage.allowance(_from, _requestedBy) >= _value && _storage.balanceOf(_from) >= _value, "insufficient allowance or funds");
    }

    // transfers with _value = 0 MUST be treated as normal transfers and fire the Transfer event.
    if (_value != 0) {
      require(_storage.balanceTransfer(_from, _to, _value));
    }
    _emitter.fireTransferEvent(_from, _to, _value);

    return true;
  }
}

pragma solidity ^0.5.0 <0.6.0;

import "./C3Emitter.sol";

import "./InteropOwnable.sol";
import "./SafeMath.sol";
import "./C3Events.sol";

import "./ReentrancyGuard.sol";

contract C3Storage is InteropOwnable, C3Events, ReentrancyGuard {
  using SafeMath for uint256;

  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowed;

  uint256 private _totalSupply;
  address private _emitter;
  bool private storageInitialized;

  constructor(uint256 initialSupply) public {
    _totalSupply = initialSupply;
    _ownerAddr = msg.sender;
  }

  function balanceOf(address owner) external view returns (uint256) {
    require(storageInitialized);
    return _balances[owner];
  }

  function balanceAdd(address _owner, uint256 value) external onlyInteropOwner nonReentrant returns (bool success) {
    require(storageInitialized);
    if (_balances[_owner] == 0) {
      _balances[_owner] = value;
      return true;
    }
    _balances[_owner] = _balances[_owner].add(value);
    return true;
  }

  function balanceSub(address _owner, uint256 value) external onlyInteropOwner nonReentrant returns (bool success) {
    require(storageInitialized);
    if (_balances[_owner] < value) {
      return false;
    }

    _balances[_owner] = _balances[_owner].sub(value);
    return true;
  }

  function balanceTransfer(address _from, address _to, uint256 value)
    external onlyInteropOwner nonReentrant returns (bool success) {
    require(storageInitialized);
    if (_balances[_from] < value) {
      return false;
    }
    _balances[_from] = _balances[_from].sub(value);
    _balances[_to] = _balances[_to].add(value);
    return true;
  }

  function allowance(address _owner, address _spender) external view returns (uint256 remaining) {
    require(storageInitialized);
    return _allowed[_owner][_spender];
  }

  function approve(address _owner, address _spender, uint256 value) external onlyInteropOwner returns (bool success) {
    require(storageInitialized);
    _allowed[_owner][_spender] = value;

    return true;
  }

  function totalSupply() external view returns (uint256) {
    require(storageInitialized);
    return _totalSupply;
  }

  function totalSupplyAdd(uint256 value) external onlyInteropOwner returns (bool success) {
    require(storageInitialized);
    _totalSupply = _totalSupply.add(value);
    return true;
  }

  function totalSupplySub(uint256 value) external onlyInteropOwner returns (bool success) {
    require(storageInitialized);
    if (value > _totalSupply) {
      return false;
    }

    _totalSupply = _totalSupply.sub(value);
    return true;
  }

  function setEmitterAddress(address emitter) external onlyOwner {
    require(emitter != address(0x0));
    _emitter = emitter;
  }

  function initializeTokens() public onlyOwner {
    require(!storageInitialized && _emitter != address(0x0), "storage was already initialized or emitter was not set");
    _balances[_ownerAddr] = _totalSupply;
    C3Emitter(_emitter).fireTransferEvent(address(0x0), _ownerAddr, _totalSupply);
    storageInitialized = true;
  }
}

pragma solidity ^0.5.0 <0.6.0;

interface C3StorageInterface {
  function balanceOf(address _owner) external view returns (uint256 balance);
  function balanceAdd(address _to, uint256 value) external returns (bool success);
  function balanceSub(address _to, uint256 value) external returns (bool success);
  function balanceTransfer(address _from, address _to, uint256 value)
    external returns (bool success);

  function allowance(address _owner, address _spender) external view returns (uint256 remaining);
  function approve(address _owner, address _to, uint256 value) external returns (bool success);

  function totalSupply() external view returns (uint256);
  function totalSupplyAdd(uint256 value) external returns (bool success);
  function totalSupplySub(uint256 value) external returns (bool success);
}

pragma solidity ^0.5.0 <0.6.0;

interface ERC20ControllerInterface {
  function totalSupply(address _requestedBy) external view returns (uint256);
  function balanceOf(address _requestedBy, address tokenOwner) external view returns (uint256 balance);
  function allowance(address _requestedBy, address tokenOwner, address spender)
    external view returns (uint256 remaining);
  function transfer(address _requestedBy, address to, uint256 tokens) external returns (bool success);
  function approve(address _requestedBy, address spender, uint256 tokens) external returns (bool success);
  function transferFrom(address _requestedBy, address from, address to, uint256 tokens) external returns (bool success);

  function burn(address _requestedBy, uint256 value) external returns (bool success);
  function burnFrom(address _requestedBy, address from, uint256 value) external returns (bool success);
}

pragma solidity ^0.5.0 <0.6.0;

contract ERC20Interface {
  function totalSupply() public view returns (uint256);
  function balanceOf(address tokenOwner) public view returns (uint256 balance);
  function allowance(address tokenOwner, address spender) public view returns (uint256 remaining);
  function transfer(address to, uint256 tokens) public returns (bool success);
  function approve(address spender, uint256 tokens) public returns (bool success);
  function transferFrom(address from, address to, uint256 tokens) public returns (bool success);
}

pragma solidity ^0.5.0 <0.6.0;

import "./Ownable.sol";

contract InteropOwnable is Ownable {
  mapping (address => bool) internal _interopOwners;

  modifier onlyInteropOwner {
    require(_interopOwners[msg.sender], "this method is only for interop owner");
    _;
  }

  function addInteropOwner(address newOwner) public onlyOwner {
    _interopOwners[newOwner] = true;
  }

  function removeInteropOwner(address newOwner) public onlyOwner {
    _interopOwners[newOwner] = false;
  }
}

pragma solidity ^0.5.0 <0.6.0;

contract Ownable {
  address internal _ownerAddr;

  modifier onlyOwner {
    require(msg.sender == _ownerAddr, "this method is only for owner");
    _;
  }

  function updateOwner(address newOwner) public onlyOwner {
    _ownerAddr = newOwner;
  }
}

pragma solidity ^0.5.0 <0.6.0;

contract ReentrancyGuard {
  uint256 private _currentCounterState;

  constructor () public {
    _currentCounterState = 1;
  }

  modifier nonReentrant() {
    _currentCounterState++;
    uint256 originalCounterState = _currentCounterState;
    _;
    require(originalCounterState == _currentCounterState);
  }
}

pragma solidity ^0.5.0 <0.6.0;

library SafeMath {
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, "overflow protection");

    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a, "overflow protection");
    uint256 c = a - b;

    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0, "divide by zero");
    uint256 c = a / b;

    return c;
  }

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b, "overflow protection");

    return c;
  }

  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0, "divide by zero");

    uint256 c = a % b;
    return c;
  }
}

pragma solidity ^0.5.0 <0.6.0;

contract C3Utils {
  function isContract(address x) internal view returns(bool) {
    uint256 size;
    // For now there is no better way to check if there is a contract in an address
    // than to check the size of the code at that address.
    // See https://ethereum.stackexchange.com/a/14016/36603
    // for more details about how this works.

    // solium-disable-next-line security/no-inline-assembly
    assembly { size := extcodesize(x) }
    return size > 0;
  }
}
