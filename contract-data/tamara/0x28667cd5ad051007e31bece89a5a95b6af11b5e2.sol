pragma solidity ^0.5.11;

contract Owned {
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    address payable owner;
    address payable newOwner;
    function changeOwner(address payable _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        if (msg.sender == newOwner) {
            owner = newOwner;
        }
    }
}

contract ERC20 {
    uint256 public totalSupply;
    function balanceOf(address _owner) view public returns (uint256 balance);
    function transfer(address _to, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);
    function allowance(address _owner, address _spender) view public returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract Token is Owned,  ERC20 {
    string public symbol;
    string public name;
    uint8 public decimals;
    mapping (address=>uint256) balances;
    mapping (address=>mapping (address=>uint256)) allowed;
    
    function balanceOf(address _owner) view public returns (uint256 balance) {return balances[_owner];}
    
    function transfer(address _to, uint256 _amount) public returns (bool success) {
        require (balances[msg.sender]>=_amount&&_amount>0&&balances[_to]+_amount>balances[_to]);
        balances[msg.sender]-=_amount;
        balances[_to]+=_amount;
        emit Transfer(msg.sender,_to,_amount);
        return true;
    }
  
    function transferFrom(address _from,address _to,uint256 _amount) public returns (bool success) {
        require (balances[_from]>=_amount&&allowed[_from][msg.sender]>=_amount&&_amount>0&&balances[_to]+_amount>balances[_to]);
        balances[_from]-=_amount;
        allowed[_from][msg.sender]-=_amount;
        balances[_to]+=_amount;
        emit Transfer(_from, _to, _amount);
        return true;
    }
  
    function approve(address _spender, uint256 _amount) public returns (bool success) {
        allowed[msg.sender][_spender]=_amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }
    
    function allowance(address _owner, address _spender) view public returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }
}

contract PagerToken is Token{
    uint256 public rate;
    uint8 public fee;
    
    constructor() public{
        symbol = "PGR";
        name = "PagerToken";
        decimals = 8;
        totalSupply = 0;
        rate = 588235;
        fee = 2;
        owner = msg.sender;
        balances[owner] = totalSupply;
    }
    
    function sell(uint256 _amount) payable public returns (bool ok){
        require(_amount>0&&balances[msg.sender]>=_amount&&_amount*rate<=address(this).balance);
        balances[msg.sender]-=_amount;
        totalSupply-=_amount;
        uint256 amount = _amount*rate;
        uint256 royalty = amount*fee/100;
        msg.sender.transfer(amount-royalty);
        owner.transfer(royalty);
        return true;
    }
    
    function () payable external {
        if (msg.value>0) {
          uint256 tokens = msg.value/rate;
          totalSupply+=tokens;
          balances[msg.sender]+=tokens;
          rate+=(tokens+block.number*10)/1e6;
        }
    }
}