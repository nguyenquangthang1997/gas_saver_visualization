{"BaaSid.sol":{"content":"pragma solidity ^0.5.4;\r\n\r\nimport \"./ercInterface.sol\";\r\n\r\ncontract BaaSid is ERC20, Ownable, Pausable {\r\n\r\n    using SafeMath for uint256;\r\n\r\n    struct LockupInfo {\r\n        uint256 releaseTime;\r\n        uint256 lockupBalance;\r\n        \r\n    }\r\n\r\n    string public name;\r\n    string public symbol;\r\n    uint8 constant public decimals =18;\r\n    uint256 internal initialSupply;\r\n    uint256 internal totalSupply_;\r\n    uint256 internal mintCap;\r\n\r\n    mapping(address =\u003e uint256) internal balances;\r\n    mapping(address =\u003e bool) internal locks;\r\n    mapping(address =\u003e bool) public frozen;\r\n    mapping(address =\u003e mapping(address =\u003e uint256)) internal allowed;\r\n    mapping(address =\u003e LockupInfo[]) internal lockupInfo;\r\n    \r\n    address implementation;\r\n\r\n    event Lock(address indexed holder, uint256 value);\r\n    event Unlock(address indexed holder, uint256 value);\r\n    event Burn(address indexed owner, uint256 value);\r\n    event Mint(uint256 value);\r\n    event Freeze(address indexed holder);\r\n    event Unfreeze(address indexed holder);\r\n\r\n    modifier notFrozen(address _holder) {\r\n        require(!frozen[_holder]);\r\n        _;\r\n    }\r\n\r\n    constructor() public {\r\n        name = \"BaaSid\";\r\n        symbol = \"BAAS\";\r\n        initialSupply = 10000000000;\r\n        totalSupply_ = initialSupply * 10 ** uint(decimals);\r\n        mintCap = 10000000000 * 10 ** uint(decimals);\r\n        balances[owner] = totalSupply_;\r\n\r\n        emit Transfer(address(0), owner, totalSupply_);\r\n    }\r\n\r\n    function () payable external {\r\n        address impl = implementation;\r\n        require(impl != address(0));\r\n        assembly {\r\n            let ptr := mload(0x40)\r\n            calldatacopy(ptr, 0, calldatasize)\r\n            let result := delegatecall(gas, impl, ptr, calldatasize, 0, 0)\r\n            let size := returndatasize\r\n            returndatacopy(ptr, 0, size)\r\n            \r\n            switch result\r\n            case 0 { revert(ptr, size) }\r\n            default { return(ptr, size) }\r\n        }\r\n    }\r\n    function _setImplementation(address _newImp) internal {\r\n        implementation = _newImp;\r\n    }\r\n    \r\n    function upgradeTo(address _newImplementation) public onlyOwner {\r\n        require(implementation != _newImplementation);\r\n        _setImplementation(_newImplementation);\r\n    }\r\n\r\n    function totalSupply() public view returns (uint256) {\r\n        return totalSupply_;\r\n    }\r\n\r\n    function transfer(address _to, uint256 _value) public whenNotPaused notFrozen(msg.sender) returns (bool) {\r\n        if (locks[msg.sender]) {\r\n            autoUnlock(msg.sender);\r\n        }\r\n        require(_to != address(0));\r\n        require(_value \u003c= balances[msg.sender]);\r\n\r\n        // SafeMath.sub will throw if there is not enough balance.\r\n        balances[msg.sender] = balances[msg.sender].sub(_value);\r\n        balances[_to] = balances[_to].add(_value);\r\n        emit Transfer(msg.sender, _to, _value);\r\n        return true;\r\n    }\r\n    \r\n     function multiTransfer(address[] memory _toList, uint256[] memory _valueList) public whenNotPaused notFrozen(msg.sender) returns(bool){\r\n        if(_toList.length != _valueList.length){\r\n            revert();\r\n        }\r\n        \r\n        for(uint256 i = 0; i \u003c _toList.length; i++){\r\n            transfer(_toList[i], _valueList[i]);\r\n        }\r\n        \r\n        return true;\r\n    }\r\n    \r\n   \r\n    function balanceOf(address _holder) public view returns (uint256 balance) {\r\n        uint256 lockedBalance = 0;\r\n        if(locks[_holder]) {\r\n            for(uint256 idx = 0; idx \u003c lockupInfo[_holder].length ; idx++ ) {\r\n                lockedBalance = lockedBalance.add(lockupInfo[_holder][idx].lockupBalance);\r\n            }\r\n        }\r\n        return balances[_holder] + lockedBalance;\r\n    }\r\n    \r\n    function currentBalanceOf(address _holder) public view returns(uint256 balance){\r\n        uint256 unlockedBalance = 0;\r\n        if(locks[_holder]){\r\n            for(uint256 idx =0; idx \u003c lockupInfo[_holder].length; idx++){\r\n                if( lockupInfo[_holder][idx].releaseTime \u003c= now){\r\n                    unlockedBalance = unlockedBalance.add(lockupInfo[_holder][idx].lockupBalance);\r\n                }\r\n            }\r\n        }\r\n        return balances[_holder] + unlockedBalance;\r\n    }\r\n\r\n    function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused notFrozen(_from)returns (bool) {\r\n        if (locks[_from]) {\r\n            autoUnlock(_from);\r\n        }\r\n        require(_to != address(0));\r\n        require(_value \u003c= balances[_from]);\r\n        require(_value \u003c= allowed[_from][msg.sender]);\r\n\r\n        balances[_from] = balances[_from].sub(_value);\r\n        balances[_to] = balances[_to].add(_value);\r\n        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);\r\n        emit Transfer(_from, _to, _value);\r\n        return true;\r\n    }\r\n\r\n    function approve(address _spender, uint256 _value) public whenNotPaused returns (bool) {\r\n        allowed[msg.sender][_spender] = _value;\r\n        emit Approval(msg.sender, _spender, _value);\r\n        return true;\r\n    }\r\n\r\n    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {\r\n        require(spender != address(0));\r\n        allowed[msg.sender][spender] = (allowed[msg.sender][spender].add(addedValue));\r\n\r\n        emit Approval(msg.sender, spender, allowed[msg.sender][spender]);\r\n        return true;\r\n    }\r\n\r\n    function decreaseAllowance( address spender, uint256 subtractedValue) public returns (bool) {\r\n        require(spender != address(0));\r\n        allowed[msg.sender][spender] = (allowed[msg.sender][spender].sub(subtractedValue));\r\n\r\n        emit Approval(msg.sender, spender, allowed[msg.sender][spender]);\r\n        return true;\r\n    }\r\n\r\n    function allowance(address _holder, address _spender) public view returns (uint256) {\r\n        return allowed[_holder][_spender];\r\n    }\r\n\r\n    function lock(address _holder, uint256 _releaseStart, uint256 _amount) public onlyOwner returns(bool){\r\n        require(balances[_holder] \u003e= _amount);\r\n        balances[_holder] = balances[_holder].sub(_amount);\r\n        \r\n        lockupInfo[_holder].push(\r\n            LockupInfo(_releaseStart, _amount)    \r\n        );\r\n        \r\n        locks[_holder] = true;\r\n        \r\n        emit Lock(_holder, _amount);\r\n        \r\n        return true;\r\n        \r\n    }\r\n\r\n    function _unlock(address _holder, uint256 _idx) internal returns (bool) {\r\n        require(locks[_holder]);\r\n        require(_idx \u003c lockupInfo[_holder].length);\r\n        LockupInfo storage lockupinfo = lockupInfo[_holder][_idx];\r\n        uint256 releaseAmount = lockupinfo.lockupBalance;\r\n        \r\n        delete lockupInfo[_holder][_idx];\r\n        \r\n        lockupInfo[_holder][_idx] = lockupInfo[_holder][lockupInfo[_holder].length.sub(1)];\r\n        \r\n        lockupInfo[_holder].length -= 1;\r\n        \r\n        if(lockupInfo[_holder].length == 0){\r\n            locks[_holder] = false;\r\n        }\r\n        \r\n        emit Unlock(_holder, releaseAmount);\r\n        balances[_holder] = balances[_holder].add(releaseAmount);\r\n        \r\n        return true;\r\n    }\r\n\r\n    function unlock(address _holder, uint256 _idx) public onlyOwner returns (bool) {\r\n        _unlock(_holder, _idx);\r\n    }\r\n\r\n    function freezeAccount(address _holder) public onlyOwner returns (bool) {\r\n        require(!frozen[_holder]);\r\n        frozen[_holder] = true;\r\n        emit Freeze(_holder);\r\n        return true;\r\n    }\r\n\r\n    function unfreezeAccount(address _holder) public onlyOwner returns (bool) {\r\n        require(frozen[_holder]);\r\n        frozen[_holder] = false;\r\n        emit Unfreeze(_holder);\r\n        return true;\r\n    }\r\n\r\n    function getNowTime() public view returns(uint256) {\r\n        return now;\r\n    }\r\n\r\n    function showLockState(address _holder, uint256 _idx) public view returns (bool, uint256, uint256, uint256) {\r\n        if(locks[_holder]) {\r\n            return (\r\n                locks[_holder],\r\n                lockupInfo[_holder].length,\r\n                lockupInfo[_holder][_idx].releaseTime,\r\n                lockupInfo[_holder][_idx].lockupBalance\r\n            );\r\n        } else {\r\n            return (\r\n                locks[_holder],\r\n                lockupInfo[_holder].length,\r\n                0,0\r\n            );\r\n\r\n        }\r\n    }\r\n    \r\n  \r\n    function distribute(address _to, uint256 _value) public onlyOwner returns (bool) {\r\n        require(_to != address(0));\r\n        require(_value \u003c= balances[msg.sender]);\r\n\r\n        balances[msg.sender] = balances[msg.sender].sub(_value);\r\n        balances[_to] = balances[_to].add(_value);\r\n        emit Transfer(msg.sender, _to, _value);\r\n        return true;\r\n    }\r\n\r\n   \r\n    \r\n    function claimToken(ERC20 token, address _to, uint256 _value) public onlyOwner returns (bool) {\r\n        token.transfer(_to, _value);\r\n        return true;\r\n    }\r\n\r\n    function burn(uint256 _value) public onlyOwner returns (bool success) {\r\n        require(_value \u003c= balances[msg.sender]);\r\n        address burner = msg.sender;\r\n        balances[burner] = balances[burner].sub(_value);\r\n        totalSupply_ = totalSupply_.sub(_value);\r\n        emit Burn(burner, _value);\r\n        emit Transfer(burner, address(0), _value);\r\n        return true;\r\n    }\r\n    \r\n    function burnFrom(address account, uint256 _value) public returns (bool) {\r\n        uint256 decreasedAllowance = allowance(account, msg.sender).sub(_value);\r\n\r\n        approve(msg.sender, decreasedAllowance);\r\n        burn(_value);\r\n    }\r\n   \r\n \r\n    function mint(address _to, uint256 _amount) onlyOwner public returns (bool) {\r\n        require(mintCap \u003e= totalSupply_.add(_amount));\r\n        totalSupply_ = totalSupply_.add(_amount);\r\n        balances[_to] = balances[_to].add(_amount);\r\n        emit Transfer(address(0), _to, _amount);\r\n        return true;\r\n    }\r\n\r\n     function autoUnlock(address _holder) internal returns(bool){\r\n        if(locks[_holder] == false){\r\n            return true;\r\n        }\r\n        \r\n        for(uint256 idx = 0; idx \u003c lockupInfo[_holder].length; idx++){\r\n            if(lockupInfo[_holder][idx].releaseTime \u003c= now)\r\n            {\r\n                if(_unlock(_holder, idx)){\r\n                    idx -= 1;\r\n                }\r\n            }\r\n        }\r\n        return true;\r\n    }\r\n}"},"ercInterface.sol":{"content":"pragma solidity ^0.5.4;\r\n\r\ncontract Ownable {\r\n    address public owner;\r\n    address public newOwner;\r\n\r\n    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);\r\n\r\n    constructor() public {\r\n        owner = msg.sender;\r\n        newOwner = address(0);\r\n    }\r\n\r\n    modifier onlyOwner() {\r\n        require(msg.sender == owner);\r\n        _;\r\n    }\r\n    modifier onlyNewOwner() {\r\n        require(msg.sender != address(0));\r\n        require(msg.sender == newOwner);\r\n        _;\r\n    }\r\n\r\n    function transferOwnership(address _newOwner) public onlyOwner {\r\n        require(_newOwner != address(0));\r\n        newOwner = _newOwner;\r\n    }\r\n\r\n    function acceptOwnership() public onlyNewOwner returns(bool) {\r\n        emit OwnershipTransferred(owner, newOwner);\r\n        owner = newOwner;\r\n        newOwner = address(0);\r\n    }\r\n}\r\n\r\n\r\nlibrary SafeMath {\r\n\r\n    function mul(uint256 a, uint256 b) internal pure returns (uint256) {\r\n        if (a == 0) {\r\n            return 0;\r\n        }\r\n        uint256 c = a * b;\r\n        assert(c / a == b);\r\n        return c;\r\n    }\r\n\r\n    function div(uint256 a, uint256 b) internal pure returns (uint256) {\r\n        // assert(b \u003e 0); // Solidity automatically throws when dividing by 0\r\n        uint256 c = a / b;\r\n        // assert(a == b * c + a % b); // There is no case in which this doesn\u0027t hold\r\n        return c;\r\n    }\r\n\r\n    function sub(uint256 a, uint256 b) internal pure returns (uint256) {\r\n        assert(b \u003c= a);\r\n        return a - b;\r\n    }\r\n\r\n    function add(uint256 a, uint256 b) internal pure returns (uint256) {\r\n        uint256 c = a + b;\r\n        assert(c \u003e= a);\r\n        return c;\r\n    }\r\n}\r\n\r\ncontract Pausable is Ownable {\r\n    event Pause();\r\n    event Unpause();\r\n\r\n    bool public paused = false;\r\n\r\n    modifier whenNotPaused() {\r\n        require(!paused);\r\n        _;\r\n    }\r\n\r\n    modifier whenPaused() {\r\n        require(paused);\r\n        _;\r\n    }\r\n\r\n    function pause() onlyOwner whenNotPaused public {\r\n        paused = true;\r\n        emit Pause();\r\n    }\r\n\r\n    function unpause() onlyOwner whenPaused public {\r\n        paused = false;\r\n        emit Unpause();\r\n    }\r\n}\r\n\r\ncontract ERC20 {\r\n    function totalSupply() public view returns (uint256);\r\n    function balanceOf(address who) public view returns (uint256);\r\n    function allowance(address owner, address spender) public view returns (uint256);\r\n    function transfer(address to, uint256 value) public returns (bool);\r\n    function transferFrom(address from, address to, uint256 value) public returns (bool);\r\n    function approve(address spender, uint256 value) public returns (bool);\r\n\r\n    event Approval(address indexed owner, address indexed spender, uint256 value);\r\n    event Transfer(address indexed from, address indexed to, uint256 value);\r\n}"}}