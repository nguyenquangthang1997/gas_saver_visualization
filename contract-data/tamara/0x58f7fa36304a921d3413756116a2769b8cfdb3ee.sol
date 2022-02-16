pragma solidity ^0.5.2;

interface ERC20 {
    function transferFrom(address _from, address _to, uint _value) external returns (bool);
    function approve(address _spender, uint _value) external returns (bool);
    function allowance(address _owner, address _spender) external view returns (uint);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}
pragma solidity ^0.5.2;

interface ERC223 {
    function transfer(address _to, uint _value, bytes calldata _data) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint value, bytes indexed data);
}
pragma solidity ^0.5.2;

contract ERC223ReceivingContract {
    function tokenFallback(address _from, uint _value, bytes calldata _data) external;
}
pragma solidity ^0.5.2;

import "Token.sol";
import "ERC20.sol";
import "ERC223.sol";
import "ERC223ReceivingContract.sol";

contract Nox is Token("NOX", "Noximilien", 18, 1000000000), ERC20, ERC223 {

    constructor() public {
        _balanceOf[msg.sender] = _totalSupply;
    }
    
    function totalSupply() public view returns (uint) {
        return _totalSupply;
    }
    
    function balanceOf(address _addr) public view returns (uint) {
        return _balanceOf[_addr];
    }

    function transfer(address _to, uint _value) public returns (bool) {
        if (_value > 0 && 
            _value <= _balanceOf[msg.sender] &&
            !isContract(_to)) {
            _balanceOf[msg.sender] -= _value;
            _balanceOf[_to] += _value;
            emit Transfer(msg.sender, _to, _value);
            return true;
        }
        return false;
    }

    function transfer(address _to, uint _value, bytes memory _data) public returns (bool) {
        if (_value > 0 && 
            _value <= _balanceOf[msg.sender] &&
            isContract(_to)) {
            _balanceOf[msg.sender] -= _value;
            _balanceOf[_to] += _value;
            ERC223ReceivingContract _contract = ERC223ReceivingContract(_to);
                _contract.tokenFallback(msg.sender, _value, _data);
            emit Transfer(msg.sender, _to, _value, _data);
            return true;
        }
        return false;
    }

    function isContract(address _addr) public view returns (bool) {
        uint codeSize;
        assembly {
            codeSize := extcodesize(_addr)
        }
        return codeSize > 0;
    }

    function transferFrom(address _from, address _to, uint _value) public returns (bool) {
        if (_allowances[_from][msg.sender] > 0 &&
            _value > 0 &&
            _allowances[_from][msg.sender] >= _value &&
            _balanceOf[_from] >= _value) {
            _balanceOf[_from] -= _value;
            _balanceOf[_to] += _value;
            _allowances[_from][msg.sender] -= _value;
            emit Transfer(_from, _to, _value);
            return true;
        }
        return false;
    }
    
    function approve(address _spender, uint _value) public returns (bool) {
        _allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    function allowance(address _owner, address _spender) public view returns (uint) {
        return _allowances[_owner][_spender];
    }
}
pragma solidity ^0.5.2;

contract Token {
    string internal _symbol;
    string internal _name;
    uint8 internal _decimals;
    uint internal _totalSupply;
    mapping (address => uint) internal _balanceOf;
    mapping (address => mapping (address => uint)) internal _allowances;
    
    constructor(string memory symbol, string memory name, uint8 decimals, uint totalSupply) public {
        _symbol = symbol;
        _name = name;
        _decimals = decimals;
        _totalSupply = totalSupply * 10**uint(decimals);
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
    
    function totalSupply() public view returns (uint) {
        return _totalSupply;
    }
    
    function balanceOf(address _addr) public view returns (uint);
    function transfer(address _to, uint _value) public returns (bool);
    event Transfer(address indexed _from, address indexed _to, uint _value);
}
pragma solidity ^0.5.2;

interface ERC20 {
    function transferFrom(address _from, address _to, uint _value) external returns (bool);
    function approve(address _spender, uint _value) external returns (bool);
    function allowance(address _owner, address _spender) external view returns (uint);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}
pragma solidity ^0.5.2;

interface ERC223 {
    function transfer(address _to, uint _value, bytes calldata _data) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint value, bytes indexed data);
}
pragma solidity ^0.5.2;

contract ERC223ReceivingContract {
    function tokenFallback(address _from, uint _value, bytes calldata _data) external;
}
pragma solidity ^0.5.2;

import "Token.sol";
import "ERC20.sol";
import "ERC223.sol";
import "ERC223ReceivingContract.sol";

contract Nox is Token("NOX", "Noximilien", 18, 1000000000), ERC20, ERC223 {

    constructor() public {
        _balanceOf[msg.sender] = _totalSupply;
    }
    
    function totalSupply() public view returns (uint) {
        return _totalSupply;
    }
    
    function balanceOf(address _addr) public view returns (uint) {
        return _balanceOf[_addr];
    }

    function transfer(address _to, uint _value) public returns (bool) {
        if (_value > 0 && 
            _value <= _balanceOf[msg.sender] &&
            !isContract(_to)) {
            _balanceOf[msg.sender] -= _value;
            _balanceOf[_to] += _value;
            emit Transfer(msg.sender, _to, _value);
            return true;
        }
        return false;
    }

    function transfer(address _to, uint _value, bytes memory _data) public returns (bool) {
        if (_value > 0 && 
            _value <= _balanceOf[msg.sender] &&
            isContract(_to)) {
            _balanceOf[msg.sender] -= _value;
            _balanceOf[_to] += _value;
            ERC223ReceivingContract _contract = ERC223ReceivingContract(_to);
                _contract.tokenFallback(msg.sender, _value, _data);
            emit Transfer(msg.sender, _to, _value, _data);
            return true;
        }
        return false;
    }

    function isContract(address _addr) public view returns (bool) {
        uint codeSize;
        assembly {
            codeSize := extcodesize(_addr)
        }
        return codeSize > 0;
    }

    function transferFrom(address _from, address _to, uint _value) public returns (bool) {
        if (_allowances[_from][msg.sender] > 0 &&
            _value > 0 &&
            _allowances[_from][msg.sender] >= _value &&
            _balanceOf[_from] >= _value) {
            _balanceOf[_from] -= _value;
            _balanceOf[_to] += _value;
            _allowances[_from][msg.sender] -= _value;
            emit Transfer(_from, _to, _value);
            return true;
        }
        return false;
    }
    
    function approve(address _spender, uint _value) public returns (bool) {
        _allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    function allowance(address _owner, address _spender) public view returns (uint) {
        return _allowances[_owner][_spender];
    }
}
pragma solidity ^0.5.2;

contract Token {
    string internal _symbol;
    string internal _name;
    uint8 internal _decimals;
    uint internal _totalSupply;
    mapping (address => uint) internal _balanceOf;
    mapping (address => mapping (address => uint)) internal _allowances;
    
    constructor(string memory symbol, string memory name, uint8 decimals, uint totalSupply) public {
        _symbol = symbol;
        _name = name;
        _decimals = decimals;
        _totalSupply = totalSupply * 10**uint(decimals);
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
    
    function totalSupply() public view returns (uint) {
        return _totalSupply;
    }
    
    function balanceOf(address _addr) public view returns (uint);
    function transfer(address _to, uint _value) public returns (bool);
    event Transfer(address indexed _from, address indexed _to, uint _value);
}
pragma solidity ^0.5.2;

interface ERC20 {
    function transferFrom(address _from, address _to, uint _value) external returns (bool);
    function approve(address _spender, uint _value) external returns (bool);
    function allowance(address _owner, address _spender) external view returns (uint);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}
pragma solidity ^0.5.2;

interface ERC223 {
    function transfer(address _to, uint _value, bytes calldata _data) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint value, bytes indexed data);
}
pragma solidity ^0.5.2;

contract ERC223ReceivingContract {
    function tokenFallback(address _from, uint _value, bytes calldata _data) external;
}
pragma solidity ^0.5.2;

import "Token.sol";
import "ERC20.sol";
import "ERC223.sol";
import "ERC223ReceivingContract.sol";

contract Nox is Token("NOX", "Noximilien", 18, 1000000000), ERC20, ERC223 {

    constructor() public {
        _balanceOf[msg.sender] = _totalSupply;
    }
    
    function totalSupply() public view returns (uint) {
        return _totalSupply;
    }
    
    function balanceOf(address _addr) public view returns (uint) {
        return _balanceOf[_addr];
    }

    function transfer(address _to, uint _value) public returns (bool) {
        if (_value > 0 && 
            _value <= _balanceOf[msg.sender] &&
            !isContract(_to)) {
            _balanceOf[msg.sender] -= _value;
            _balanceOf[_to] += _value;
            emit Transfer(msg.sender, _to, _value);
            return true;
        }
        return false;
    }

    function transfer(address _to, uint _value, bytes memory _data) public returns (bool) {
        if (_value > 0 && 
            _value <= _balanceOf[msg.sender] &&
            isContract(_to)) {
            _balanceOf[msg.sender] -= _value;
            _balanceOf[_to] += _value;
            ERC223ReceivingContract _contract = ERC223ReceivingContract(_to);
                _contract.tokenFallback(msg.sender, _value, _data);
            emit Transfer(msg.sender, _to, _value, _data);
            return true;
        }
        return false;
    }

    function isContract(address _addr) public view returns (bool) {
        uint codeSize;
        assembly {
            codeSize := extcodesize(_addr)
        }
        return codeSize > 0;
    }

    function transferFrom(address _from, address _to, uint _value) public returns (bool) {
        if (_allowances[_from][msg.sender] > 0 &&
            _value > 0 &&
            _allowances[_from][msg.sender] >= _value &&
            _balanceOf[_from] >= _value) {
            _balanceOf[_from] -= _value;
            _balanceOf[_to] += _value;
            _allowances[_from][msg.sender] -= _value;
            emit Transfer(_from, _to, _value);
            return true;
        }
        return false;
    }
    
    function approve(address _spender, uint _value) public returns (bool) {
        _allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    function allowance(address _owner, address _spender) public view returns (uint) {
        return _allowances[_owner][_spender];
    }
}
pragma solidity ^0.5.2;

contract Token {
    string internal _symbol;
    string internal _name;
    uint8 internal _decimals;
    uint internal _totalSupply;
    mapping (address => uint) internal _balanceOf;
    mapping (address => mapping (address => uint)) internal _allowances;
    
    constructor(string memory symbol, string memory name, uint8 decimals, uint totalSupply) public {
        _symbol = symbol;
        _name = name;
        _decimals = decimals;
        _totalSupply = totalSupply * 10**uint(decimals);
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
    
    function totalSupply() public view returns (uint) {
        return _totalSupply;
    }
    
    function balanceOf(address _addr) public view returns (uint);
    function transfer(address _to, uint _value) public returns (bool);
    event Transfer(address indexed _from, address indexed _to, uint _value);
}
