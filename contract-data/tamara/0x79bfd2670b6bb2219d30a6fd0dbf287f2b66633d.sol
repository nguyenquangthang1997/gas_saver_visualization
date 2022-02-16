pragma solidity ^0.4.18;

contract ERC20 {
    uint256 public totalSupply;
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity ^0.4.18;
import './StandardToken.sol';

contract ICNode is StandardToken {
    address public admin;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping (address => bool) public frozenAccount;
    mapping (address => uint256) public frozenTimestamp;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function ICNode(
        string initialName,
        string initialSymbol,
        uint256 initialSupply,
        uint8 initialDecimals,
        address initialAdminAddress
        ) public {
            name=initialName;
            symbol=initialSymbol;
            decimals=initialDecimals;
            totalSupply =initialSupply * 10 ** uint256(initialDecimals);
            admin = initialAdminAddress;
            balances[msg.sender] = totalSupply;
    }

    function freeze(
        address _target,
        bool _freeze
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        require(_target != address(0));
        frozenAccount[_target] = _freeze;
        return true;
    }

    function freezeWithTimestamp(
        address _target,
        uint256 _timestamp
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        require(_target != address(0));
        frozenTimestamp[_target] = _timestamp;
        return true;
    }

    function multiFreeze(
        address[] _targets,
        bool[] _freezes
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        require(_targets.length == _freezes.length);
        uint256 len = _targets.length;
        require(len > 0);
        for (uint256 i = 0; i < len; i = i.add(1)) {
            address _target = _targets[i];
            require(_target != address(0));
            bool _freeze = _freezes[i];
            frozenAccount[_target] = _freeze;
        }
        return true;
    }
    function multiFreezeWithTimestamp(
        address[] _targets,
        uint256[] _timestamps
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        require(_targets.length == _timestamps.length);
        uint256 len = _targets.length;
        require(len > 0);
        for (uint256 i = 0; i < len; i = i.add(1)) {
            address _target = _targets[i];
            require(_target != address(0));
            uint256 _timestamp = _timestamps[i];
            frozenTimestamp[_target] = _timestamp;
        }
        return true;
    }

    function multiTransfer(
        address[] _tos,
        uint256[] _values
    )
    public
    returns (bool) {
        require(!frozenAccount[msg.sender]);
        require(now > frozenTimestamp[msg.sender]);
        require(_tos.length == _values.length);
        uint256 len = _tos.length;
        require(len > 0);
        uint256 amount = 0;
        for (uint256 i = 0; i < len; i = i.add(1)) {
            amount = amount.add(_values[i]);
        }
        require(amount <= balances[msg.sender]);
        for (uint256 j = 0; j < len; j = j.add(1)) {
            address _to = _tos[j];
            require(_to != address(0));
            balances[_to] = balances[_to].add(_values[j]);
            balances[msg.sender] = balances[msg.sender].sub(_values[j]);
            Transfer(msg.sender, _to, _values[j]);
        }
        return true;
    }
    function transfer(
        address _to,
        uint256 _value
    )
    public
    returns (bool) {
        require(!frozenAccount[msg.sender]);
        require(now > frozenTimestamp[msg.sender]);
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        Transfer(msg.sender, _to, _value);
        return true;
    }
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )
    public
    returns (bool)
    {
        require(!frozenAccount[_from]);
        require(now > frozenTimestamp[msg.sender]);
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);

        Transfer(_from, _to, _value);
        return true;
    }

    function approve(
        address _spender,
        uint256 _value
    ) public
    returns (bool) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }
    function getFrozenTimestamp(
        address _target
    )
    public view
    returns (uint256) {
        require(_target != address(0));
        return frozenTimestamp[_target];
    }
    function getFrozenAccount(
        address _target
    )
    public view
    returns (bool) {
        require(_target != address(0));
        return frozenAccount[_target];
    }
    function getBalance()
    public view
    returns (uint256) {
        return address(this).balance;
    }
    function setName (
        string _value
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        name = _value;
        return true;
    }
    function setSymbol (
        string _value
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        symbol = _value;
        return true;
    }
    function kill()
    public {
        require(msg.sender == admin);
        selfdestruct(admin);
    }

}
pragma solidity ^0.4.18;

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

pragma solidity ^0.4.18;

import './ERC20.sol';
import './SafeMath.sol';
contract StandardToken is ERC20 {
    using SafeMath for uint256;
    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) internal allowed;

      function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
      }

      function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
      }
      function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        Transfer(_from, _to, _value);
        return true;
      }
      function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
      }
      function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
      }
}

pragma solidity ^0.4.18;

contract ERC20 {
    uint256 public totalSupply;
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity ^0.4.18;
import './StandardToken.sol';

contract ICNode is StandardToken {
    address public admin;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping (address => bool) public frozenAccount;
    mapping (address => uint256) public frozenTimestamp;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function ICNode(
        string initialName,
        string initialSymbol,
        uint256 initialSupply,
        uint8 initialDecimals,
        address initialAdminAddress
        ) public {
            name=initialName;
            symbol=initialSymbol;
            decimals=initialDecimals;
            totalSupply =initialSupply * 10 ** uint256(initialDecimals);
            admin = initialAdminAddress;
            balances[msg.sender] = totalSupply;
    }

    function freeze(
        address _target,
        bool _freeze
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        require(_target != address(0));
        frozenAccount[_target] = _freeze;
        return true;
    }

    function freezeWithTimestamp(
        address _target,
        uint256 _timestamp
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        require(_target != address(0));
        frozenTimestamp[_target] = _timestamp;
        return true;
    }

    function multiFreeze(
        address[] _targets,
        bool[] _freezes
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        require(_targets.length == _freezes.length);
        uint256 len = _targets.length;
        require(len > 0);
        for (uint256 i = 0; i < len; i = i.add(1)) {
            address _target = _targets[i];
            require(_target != address(0));
            bool _freeze = _freezes[i];
            frozenAccount[_target] = _freeze;
        }
        return true;
    }
    function multiFreezeWithTimestamp(
        address[] _targets,
        uint256[] _timestamps
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        require(_targets.length == _timestamps.length);
        uint256 len = _targets.length;
        require(len > 0);
        for (uint256 i = 0; i < len; i = i.add(1)) {
            address _target = _targets[i];
            require(_target != address(0));
            uint256 _timestamp = _timestamps[i];
            frozenTimestamp[_target] = _timestamp;
        }
        return true;
    }

    function multiTransfer(
        address[] _tos,
        uint256[] _values
    )
    public
    returns (bool) {
        require(!frozenAccount[msg.sender]);
        require(now > frozenTimestamp[msg.sender]);
        require(_tos.length == _values.length);
        uint256 len = _tos.length;
        require(len > 0);
        uint256 amount = 0;
        for (uint256 i = 0; i < len; i = i.add(1)) {
            amount = amount.add(_values[i]);
        }
        require(amount <= balances[msg.sender]);
        for (uint256 j = 0; j < len; j = j.add(1)) {
            address _to = _tos[j];
            require(_to != address(0));
            balances[_to] = balances[_to].add(_values[j]);
            balances[msg.sender] = balances[msg.sender].sub(_values[j]);
            Transfer(msg.sender, _to, _values[j]);
        }
        return true;
    }
    function transfer(
        address _to,
        uint256 _value
    )
    public
    returns (bool) {
        require(!frozenAccount[msg.sender]);
        require(now > frozenTimestamp[msg.sender]);
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        Transfer(msg.sender, _to, _value);
        return true;
    }
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )
    public
    returns (bool)
    {
        require(!frozenAccount[_from]);
        require(now > frozenTimestamp[msg.sender]);
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);

        Transfer(_from, _to, _value);
        return true;
    }

    function approve(
        address _spender,
        uint256 _value
    ) public
    returns (bool) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }
    function getFrozenTimestamp(
        address _target
    )
    public view
    returns (uint256) {
        require(_target != address(0));
        return frozenTimestamp[_target];
    }
    function getFrozenAccount(
        address _target
    )
    public view
    returns (bool) {
        require(_target != address(0));
        return frozenAccount[_target];
    }
    function getBalance()
    public view
    returns (uint256) {
        return address(this).balance;
    }
    function setName (
        string _value
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        name = _value;
        return true;
    }
    function setSymbol (
        string _value
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        symbol = _value;
        return true;
    }
    function kill()
    public {
        require(msg.sender == admin);
        selfdestruct(admin);
    }

}
pragma solidity ^0.4.18;

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

pragma solidity ^0.4.18;

import './ERC20.sol';
import './SafeMath.sol';
contract StandardToken is ERC20 {
    using SafeMath for uint256;
    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) internal allowed;

      function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
      }

      function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
      }
      function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        Transfer(_from, _to, _value);
        return true;
      }
      function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
      }
      function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
      }
}

pragma solidity ^0.4.18;

contract ERC20 {
    uint256 public totalSupply;
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity ^0.4.18;
import './StandardToken.sol';

contract ICNode is StandardToken {
    address public admin;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping (address => bool) public frozenAccount;
    mapping (address => uint256) public frozenTimestamp;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function ICNode(
        string initialName,
        string initialSymbol,
        uint256 initialSupply,
        uint8 initialDecimals,
        address initialAdminAddress
        ) public {
            name=initialName;
            symbol=initialSymbol;
            decimals=initialDecimals;
            totalSupply =initialSupply * 10 ** uint256(initialDecimals);
            admin = initialAdminAddress;
            balances[msg.sender] = totalSupply;
    }

    function freeze(
        address _target,
        bool _freeze
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        require(_target != address(0));
        frozenAccount[_target] = _freeze;
        return true;
    }

    function freezeWithTimestamp(
        address _target,
        uint256 _timestamp
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        require(_target != address(0));
        frozenTimestamp[_target] = _timestamp;
        return true;
    }

    function multiFreeze(
        address[] _targets,
        bool[] _freezes
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        require(_targets.length == _freezes.length);
        uint256 len = _targets.length;
        require(len > 0);
        for (uint256 i = 0; i < len; i = i.add(1)) {
            address _target = _targets[i];
            require(_target != address(0));
            bool _freeze = _freezes[i];
            frozenAccount[_target] = _freeze;
        }
        return true;
    }
    function multiFreezeWithTimestamp(
        address[] _targets,
        uint256[] _timestamps
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        require(_targets.length == _timestamps.length);
        uint256 len = _targets.length;
        require(len > 0);
        for (uint256 i = 0; i < len; i = i.add(1)) {
            address _target = _targets[i];
            require(_target != address(0));
            uint256 _timestamp = _timestamps[i];
            frozenTimestamp[_target] = _timestamp;
        }
        return true;
    }

    function multiTransfer(
        address[] _tos,
        uint256[] _values
    )
    public
    returns (bool) {
        require(!frozenAccount[msg.sender]);
        require(now > frozenTimestamp[msg.sender]);
        require(_tos.length == _values.length);
        uint256 len = _tos.length;
        require(len > 0);
        uint256 amount = 0;
        for (uint256 i = 0; i < len; i = i.add(1)) {
            amount = amount.add(_values[i]);
        }
        require(amount <= balances[msg.sender]);
        for (uint256 j = 0; j < len; j = j.add(1)) {
            address _to = _tos[j];
            require(_to != address(0));
            balances[_to] = balances[_to].add(_values[j]);
            balances[msg.sender] = balances[msg.sender].sub(_values[j]);
            Transfer(msg.sender, _to, _values[j]);
        }
        return true;
    }
    function transfer(
        address _to,
        uint256 _value
    )
    public
    returns (bool) {
        require(!frozenAccount[msg.sender]);
        require(now > frozenTimestamp[msg.sender]);
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        Transfer(msg.sender, _to, _value);
        return true;
    }
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )
    public
    returns (bool)
    {
        require(!frozenAccount[_from]);
        require(now > frozenTimestamp[msg.sender]);
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);

        Transfer(_from, _to, _value);
        return true;
    }

    function approve(
        address _spender,
        uint256 _value
    ) public
    returns (bool) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }
    function getFrozenTimestamp(
        address _target
    )
    public view
    returns (uint256) {
        require(_target != address(0));
        return frozenTimestamp[_target];
    }
    function getFrozenAccount(
        address _target
    )
    public view
    returns (bool) {
        require(_target != address(0));
        return frozenAccount[_target];
    }
    function getBalance()
    public view
    returns (uint256) {
        return address(this).balance;
    }
    function setName (
        string _value
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        name = _value;
        return true;
    }
    function setSymbol (
        string _value
    )
    public
    returns (bool) {
        require(msg.sender == admin);
        symbol = _value;
        return true;
    }
    function kill()
    public {
        require(msg.sender == admin);
        selfdestruct(admin);
    }

}
pragma solidity ^0.4.18;

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

pragma solidity ^0.4.18;

import './ERC20.sol';
import './SafeMath.sol';
contract StandardToken is ERC20 {
    using SafeMath for uint256;
    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) internal allowed;

      function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
      }

      function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
      }
      function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        Transfer(_from, _to, _value);
        return true;
      }
      function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
      }
      function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
      }
}

