pragma solidity >=0.4.24 <0.6.0;
/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract IERC20Token{
// these functions aren't abstract since the compiler emits automatically generated getter functions as external
function name() public view returns(string memory);
function symbol() public view returns(string memory);
function decimals() public view returns(uint256);
function totalSupply() public view returns (uint256);
function balanceOf(address _owner) public view returns (uint256);
function allowance(address _owner, address _spender) public view returns (uint256);

function transfer(address _to, uint256 _value) public returns (bool success);
function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
function approve(address _spender, uint256 _value) public returns (bool success);
 event Transfer(
    address indexed from,
    address indexed to,
    uint256 value
  );

  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}
pragma solidity >=0.4.24 <0.6.0;
import "./UrgencyPause.sol";
import "./SafeMath.sol";
import "./IERC20Token.sol";
import "./Ownable.sol";

contract Omg is Ownable, UrgencyPause {
    using SafeMath for uint256;

    uint256 private _startTime = 1567213749;  //解仓时间s 2019/9/1 9:00:00 - 1
    uint256 constant UNLOCK_DURATION = 100;
    uint256 constant DAY_UINT = 1*24*60*60;  //换算成天数
    address[] private _investors;
    mapping (address=>Investor) _mapInvestors;

    IERC20Token private _xlToken;
     //投资者结构体
     struct Investor {
         address account;
         uint256 lockXLs;
         uint256 unlockXLs;
     }

     event TokenChanged(address indexed token,uint256 indexed time);
     event LockXLEvent(address indexed acc,uint256 indexed lockXLs);
     event StartTimeUnlock(address indexed account,uint256 indexed startTime);
     event UnlockXLEvent(address indexed acc,uint256 indexed unlockXLs);
     constructor(IERC20Token token) public {
         _xlToken = IERC20Token(token);
     }

     function () external {
         if(super.isManager(msg.sender)){
             unlockBatch(); //管理者批量发送
         }else{
             unlockAccount(msg.sender);  //单个拉取
         }
     }
     
     //当前天数 1-100
     function curDays() public view returns(uint256) {
         uint256 curSeconds = now.sub(_startTime);
         uint256 curDay = curSeconds.div(DAY_UINT);
         return curDay;
     }
     
     //是否完成释放
     function isFinished() public view returns(bool) {
         return curDays() >= UNLOCK_DURATION;
     }


     //设置解仓时间
      function setStartTimeUnLock(uint256 _time) public onlyOwner {
          _startTime = _time;
          emit StartTimeUnlock(msg.sender,_time);
      }
    
    function setToken(IERC20Token _token) public onlyOwner {
        _xlToken = IERC20Token(_token);
        emit TokenChanged(address(_token),now);
    }

    //投资者数量
    function investors() public view returns(uint256 count) {
        return _investors.length;
    }

    //添加用户锁仓记录
    function addInvestor(address _acc,uint256 _lockXLs) public notPaused onlyOwner {
        require(_acc != address(0),"无地址");
        uint256 lockXLs = _lockXLs;//.div(10**18); //除去精度
        require(_mapInvestors[_acc].account == address(0),"该投资者已存在!!");
        _investors.push(_acc);
        _mapInvestors[_acc] = Investor({account:_acc,lockXLs:lockXLs,unlockXLs:0});
        emit LockXLEvent(_acc,lockXLs);
    }

    //删除用户记录
    function removeInvestorAtIndex(uint256  index) public onlyOwner {
        if(index < _investors.length) {
            address acc = _investors[index];
            _mapInvestors[acc] = Investor(address(0),0,0);
            delete _investors[index];
            //填上删除的空白
            _investors[index] = _investors[_investors.length - 1];
        }
    }

    function investorAtAccount(address acc) public view returns(address account,
         uint256 lockXLs,
         uint256 unlockXLs) {
        Investor storage inv = _mapInvestors[acc];
             account = inv.account;
             lockXLs = inv.lockXLs;
             unlockXLs = inv.unlockXLs;
    }

    function appendLocksXLs(address acc,uint256 lockXls) public onlyManager {
        require(acc != address(0),"0地址");
        if(_mapInvestors[acc].account == address(0)){//新增
            addInvestor(acc,lockXls);
        }else{ //追加
            Investor storage inv = _mapInvestors[acc];
            inv.lockXLs = inv.lockXLs.add(lockXls);
        }
    }

   //解锁某个账户
    function unlockAccount(address acc) internal {
        Investor storage inv = _mapInvestors[acc];
             if(inv.account == address(0)){
                 return;
             }
              uint curDay = curDays();
              //1%,100天
              uint256 totalUnlock = inv.lockXLs.mul(curDay).div(UNLOCK_DURATION);

              //当前总释放量 - 已经释放的量
              uint256 unlocking = totalUnlock.sub(inv.unlockXLs);
              if(unlocking <= 0){ //等零则已经释放过
                  return;
              }
              inv.unlockXLs = totalUnlock;
              _mapInvestors[acc].unlockXLs = totalUnlock;
              _xlToken.transfer(inv.account,unlocking);
              emit UnlockXLEvent(inv.account,unlocking);
    }
    //批量释放
    function unlockBatch() public notPaused onlyManager {
       // require(isFinished() == false,"释放时间已到");
        //当前释放量 = 锁仓总量*curDay/100 - 已经释放量
        uint curDay = curDays();
        require(curDay <= UNLOCK_DURATION,"释放周期完成!");
        for (uint256 i = 0; i < _investors.length; ++i){
             address acc = _investors[i];
             if(acc == address(0)){
                 continue;
             }
             unlockAccount(acc);
        }
    }

    function balanceAt(address acc) public view returns(uint256 balance){
        require(acc != address(0),"地址无效!");
        balance = _xlToken.balanceOf(acc);
    }
}

pragma solidity >=0.4.24 <0.6.0;
import "./IERC20Token.sol";
contract Ownable {
    address private _owner;
    mapping (address=>bool) private _managers;
    event OwnershipTransferred(address indexed prevOwner,address indexed newOwner);
    event WithdrawEtherEvent(address indexed receiver,uint256 indexed amount,uint256 indexed atime);
    //管理者处理事件
    event ManagerChange(address indexed manager,bool indexed isMgr);
    //modifier
    modifier onlyOwner{
        require(msg.sender == _owner, "sender not eq owner");
        _;
    }

    modifier onlyManager{
        require(_managers[msg.sender] == true, "不是管理员");
        _;
    }
    constructor() internal{
        _owner = msg.sender;
        _managers[msg.sender] = true;
    }

    function owner() public view returns(address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "newOwner can't be empty!");
        address prevOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(prevOwner,newOwner);
    }

    //管理员
    function changeManager(address account,bool isManager) public onlyOwner {
        _managers[account] = isManager;
        emit ManagerChange(account,isManager);
    }
    function isManager(address account) public view returns(bool) {
        return _managers[account];
    }

    /**
     * @dev Rescue compatible ERC20 Token
     *
     * @param tokenAddr ERC20 The address of the ERC20 token contract
     * @param receiver The address of the receiver
     * @param amount uint256
     */
    function rescueTokens(IERC20Token tokenAddr, address receiver, uint256 amount) external onlyOwner {
        IERC20Token _token = IERC20Token(tokenAddr);
        require(receiver != address(0),"receiver can't be empty!");
        uint256 balance = _token.balanceOf(address(this));
        require(balance >= amount,"balance is not enough!");
        require(_token.transfer(receiver, amount),"transfer failed!!");
    }

    /**
     * @dev Withdraw ether
     */
    function withdrawEther(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0),"address can't be empty");
        uint256 balance = address(this).balance;
        require(balance >= amount,"this balance is not enough!");
        to.transfer(amount);
       emit WithdrawEtherEvent(to,amount,now);
    }


}
pragma solidity >=0.4.24 <0.6.0;

/*
    Library for basic math operations with overflow/underflow protection
*/
library SafeMath {
    /**
        @dev returns the sum of _x and _y, reverts if the calculation overflows

        @param _x   value 1
        @param _y   value 2

        @return sum
    */
    function add(uint256 _x, uint256 _y) internal pure returns (uint256) {
        uint256 z = _x + _y;
        require(z >= _x,"SafeMath->mul got a exception");
        return z;
    }

    /**
        @dev returns the difference of _x minus _y, reverts if the calculation underflows

        @param _x   minuend
        @param _y   subtrahend

        @return difference
    */
    function sub(uint256 _x, uint256 _y) internal pure returns (uint256) {
        require(_x >= _y,"SafeMath->sub got a exception");
        return _x - _y;
    }

    /**
        @dev returns the product of multiplying _x by _y, reverts if the calculation overflows

        @param _x   factor 1
        @param _y   factor 2

        @return product
    */
    function mul(uint256 _x, uint256 _y) internal pure returns (uint256) {
        // gas optimization
        if (_x == 0)
            return 0;

        uint256 z = _x * _y;
        require(z / _x == _y,"SafeMath->mul got a exception");
        return z;
    }

      /**
        @dev Integer division of two numbers truncating the quotient, reverts on division by zero.

        @param _x   dividend
        @param _y   divisor

        @return quotient
    */
    function div(uint256 _x, uint256 _y) internal pure returns (uint256) {
        require(_y > 0,"SafeMath->div got a exception");
        uint256 c = _x / _y;

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

pragma solidity >=0.4.24 <0.6.0;
/*
*紧急情况下暂停转账
*
*/
import "./Ownable.sol";
contract UrgencyPause is Ownable{
    bool private _paused;
    event Paused(address indexed account,bool indexed state);
    
    modifier notPaused(){
        require(!_paused,"the state is paused!");
        _;
    }
    constructor() public{
        _paused = false;
    }


    function paused() public view returns(bool) {
        return _paused;
    }

    function setPaused(bool state) public onlyManager {
            _paused = state;
            emit Paused(msg.sender,_paused);
    }

}

pragma solidity >=0.4.24 <0.6.0;
/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract IERC20Token{
// these functions aren't abstract since the compiler emits automatically generated getter functions as external
function name() public view returns(string memory);
function symbol() public view returns(string memory);
function decimals() public view returns(uint256);
function totalSupply() public view returns (uint256);
function balanceOf(address _owner) public view returns (uint256);
function allowance(address _owner, address _spender) public view returns (uint256);

function transfer(address _to, uint256 _value) public returns (bool success);
function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
function approve(address _spender, uint256 _value) public returns (bool success);
 event Transfer(
    address indexed from,
    address indexed to,
    uint256 value
  );

  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}
pragma solidity >=0.4.24 <0.6.0;
import "./UrgencyPause.sol";
import "./SafeMath.sol";
import "./IERC20Token.sol";
import "./Ownable.sol";

contract Omg is Ownable, UrgencyPause {
    using SafeMath for uint256;

    uint256 private _startTime = 1567213749;  //解仓时间s 2019/9/1 9:00:00 - 1
    uint256 constant UNLOCK_DURATION = 100;
    uint256 constant DAY_UINT = 1*24*60*60;  //换算成天数
    address[] private _investors;
    mapping (address=>Investor) _mapInvestors;

    IERC20Token private _xlToken;
     //投资者结构体
     struct Investor {
         address account;
         uint256 lockXLs;
         uint256 unlockXLs;
     }

     event TokenChanged(address indexed token,uint256 indexed time);
     event LockXLEvent(address indexed acc,uint256 indexed lockXLs);
     event StartTimeUnlock(address indexed account,uint256 indexed startTime);
     event UnlockXLEvent(address indexed acc,uint256 indexed unlockXLs);
     constructor(IERC20Token token) public {
         _xlToken = IERC20Token(token);
     }

     function () external {
         if(super.isManager(msg.sender)){
             unlockBatch(); //管理者批量发送
         }else{
             unlockAccount(msg.sender);  //单个拉取
         }
     }
     
     //当前天数 1-100
     function curDays() public view returns(uint256) {
         uint256 curSeconds = now.sub(_startTime);
         uint256 curDay = curSeconds.div(DAY_UINT);
         return curDay;
     }
     
     //是否完成释放
     function isFinished() public view returns(bool) {
         return curDays() >= UNLOCK_DURATION;
     }


     //设置解仓时间
      function setStartTimeUnLock(uint256 _time) public onlyOwner {
          _startTime = _time;
          emit StartTimeUnlock(msg.sender,_time);
      }
    
    function setToken(IERC20Token _token) public onlyOwner {
        _xlToken = IERC20Token(_token);
        emit TokenChanged(address(_token),now);
    }

    //投资者数量
    function investors() public view returns(uint256 count) {
        return _investors.length;
    }

    //添加用户锁仓记录
    function addInvestor(address _acc,uint256 _lockXLs) public notPaused onlyOwner {
        require(_acc != address(0),"无地址");
        uint256 lockXLs = _lockXLs;//.div(10**18); //除去精度
        require(_mapInvestors[_acc].account == address(0),"该投资者已存在!!");
        _investors.push(_acc);
        _mapInvestors[_acc] = Investor({account:_acc,lockXLs:lockXLs,unlockXLs:0});
        emit LockXLEvent(_acc,lockXLs);
    }

    //删除用户记录
    function removeInvestorAtIndex(uint256  index) public onlyOwner {
        if(index < _investors.length) {
            address acc = _investors[index];
            _mapInvestors[acc] = Investor(address(0),0,0);
            delete _investors[index];
            //填上删除的空白
            _investors[index] = _investors[_investors.length - 1];
        }
    }

    function investorAtAccount(address acc) public view returns(address account,
         uint256 lockXLs,
         uint256 unlockXLs) {
        Investor storage inv = _mapInvestors[acc];
             account = inv.account;
             lockXLs = inv.lockXLs;
             unlockXLs = inv.unlockXLs;
    }

    function appendLocksXLs(address acc,uint256 lockXls) public onlyManager {
        require(acc != address(0),"0地址");
        if(_mapInvestors[acc].account == address(0)){//新增
            addInvestor(acc,lockXls);
        }else{ //追加
            Investor storage inv = _mapInvestors[acc];
            inv.lockXLs = inv.lockXLs.add(lockXls);
        }
    }

   //解锁某个账户
    function unlockAccount(address acc) internal {
        Investor storage inv = _mapInvestors[acc];
             if(inv.account == address(0)){
                 return;
             }
              uint curDay = curDays();
              //1%,100天
              uint256 totalUnlock = inv.lockXLs.mul(curDay).div(UNLOCK_DURATION);

              //当前总释放量 - 已经释放的量
              uint256 unlocking = totalUnlock.sub(inv.unlockXLs);
              if(unlocking <= 0){ //等零则已经释放过
                  return;
              }
              inv.unlockXLs = totalUnlock;
              _mapInvestors[acc].unlockXLs = totalUnlock;
              _xlToken.transfer(inv.account,unlocking);
              emit UnlockXLEvent(inv.account,unlocking);
    }
    //批量释放
    function unlockBatch() public notPaused onlyManager {
       // require(isFinished() == false,"释放时间已到");
        //当前释放量 = 锁仓总量*curDay/100 - 已经释放量
        uint curDay = curDays();
        require(curDay <= UNLOCK_DURATION,"释放周期完成!");
        for (uint256 i = 0; i < _investors.length; ++i){
             address acc = _investors[i];
             if(acc == address(0)){
                 continue;
             }
             unlockAccount(acc);
        }
    }

    function balanceAt(address acc) public view returns(uint256 balance){
        require(acc != address(0),"地址无效!");
        balance = _xlToken.balanceOf(acc);
    }
}

pragma solidity >=0.4.24 <0.6.0;
import "./IERC20Token.sol";
contract Ownable {
    address private _owner;
    mapping (address=>bool) private _managers;
    event OwnershipTransferred(address indexed prevOwner,address indexed newOwner);
    event WithdrawEtherEvent(address indexed receiver,uint256 indexed amount,uint256 indexed atime);
    //管理者处理事件
    event ManagerChange(address indexed manager,bool indexed isMgr);
    //modifier
    modifier onlyOwner{
        require(msg.sender == _owner, "sender not eq owner");
        _;
    }

    modifier onlyManager{
        require(_managers[msg.sender] == true, "不是管理员");
        _;
    }
    constructor() internal{
        _owner = msg.sender;
        _managers[msg.sender] = true;
    }

    function owner() public view returns(address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "newOwner can't be empty!");
        address prevOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(prevOwner,newOwner);
    }

    //管理员
    function changeManager(address account,bool isManager) public onlyOwner {
        _managers[account] = isManager;
        emit ManagerChange(account,isManager);
    }
    function isManager(address account) public view returns(bool) {
        return _managers[account];
    }

    /**
     * @dev Rescue compatible ERC20 Token
     *
     * @param tokenAddr ERC20 The address of the ERC20 token contract
     * @param receiver The address of the receiver
     * @param amount uint256
     */
    function rescueTokens(IERC20Token tokenAddr, address receiver, uint256 amount) external onlyOwner {
        IERC20Token _token = IERC20Token(tokenAddr);
        require(receiver != address(0),"receiver can't be empty!");
        uint256 balance = _token.balanceOf(address(this));
        require(balance >= amount,"balance is not enough!");
        require(_token.transfer(receiver, amount),"transfer failed!!");
    }

    /**
     * @dev Withdraw ether
     */
    function withdrawEther(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0),"address can't be empty");
        uint256 balance = address(this).balance;
        require(balance >= amount,"this balance is not enough!");
        to.transfer(amount);
       emit WithdrawEtherEvent(to,amount,now);
    }


}
pragma solidity >=0.4.24 <0.6.0;

/*
    Library for basic math operations with overflow/underflow protection
*/
library SafeMath {
    /**
        @dev returns the sum of _x and _y, reverts if the calculation overflows

        @param _x   value 1
        @param _y   value 2

        @return sum
    */
    function add(uint256 _x, uint256 _y) internal pure returns (uint256) {
        uint256 z = _x + _y;
        require(z >= _x,"SafeMath->mul got a exception");
        return z;
    }

    /**
        @dev returns the difference of _x minus _y, reverts if the calculation underflows

        @param _x   minuend
        @param _y   subtrahend

        @return difference
    */
    function sub(uint256 _x, uint256 _y) internal pure returns (uint256) {
        require(_x >= _y,"SafeMath->sub got a exception");
        return _x - _y;
    }

    /**
        @dev returns the product of multiplying _x by _y, reverts if the calculation overflows

        @param _x   factor 1
        @param _y   factor 2

        @return product
    */
    function mul(uint256 _x, uint256 _y) internal pure returns (uint256) {
        // gas optimization
        if (_x == 0)
            return 0;

        uint256 z = _x * _y;
        require(z / _x == _y,"SafeMath->mul got a exception");
        return z;
    }

      /**
        @dev Integer division of two numbers truncating the quotient, reverts on division by zero.

        @param _x   dividend
        @param _y   divisor

        @return quotient
    */
    function div(uint256 _x, uint256 _y) internal pure returns (uint256) {
        require(_y > 0,"SafeMath->div got a exception");
        uint256 c = _x / _y;

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

pragma solidity >=0.4.24 <0.6.0;
/*
*紧急情况下暂停转账
*
*/
import "./Ownable.sol";
contract UrgencyPause is Ownable{
    bool private _paused;
    event Paused(address indexed account,bool indexed state);
    
    modifier notPaused(){
        require(!_paused,"the state is paused!");
        _;
    }
    constructor() public{
        _paused = false;
    }


    function paused() public view returns(bool) {
        return _paused;
    }

    function setPaused(bool state) public onlyManager {
            _paused = state;
            emit Paused(msg.sender,_paused);
    }

}

pragma solidity >=0.4.24 <0.6.0;
/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract IERC20Token{
// these functions aren't abstract since the compiler emits automatically generated getter functions as external
function name() public view returns(string memory);
function symbol() public view returns(string memory);
function decimals() public view returns(uint256);
function totalSupply() public view returns (uint256);
function balanceOf(address _owner) public view returns (uint256);
function allowance(address _owner, address _spender) public view returns (uint256);

function transfer(address _to, uint256 _value) public returns (bool success);
function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
function approve(address _spender, uint256 _value) public returns (bool success);
 event Transfer(
    address indexed from,
    address indexed to,
    uint256 value
  );

  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}
pragma solidity >=0.4.24 <0.6.0;
import "./UrgencyPause.sol";
import "./SafeMath.sol";
import "./IERC20Token.sol";
import "./Ownable.sol";

contract Omg is Ownable, UrgencyPause {
    using SafeMath for uint256;

    uint256 private _startTime = 1567213749;  //解仓时间s 2019/9/1 9:00:00 - 1
    uint256 constant UNLOCK_DURATION = 100;
    uint256 constant DAY_UINT = 1*24*60*60;  //换算成天数
    address[] private _investors;
    mapping (address=>Investor) _mapInvestors;

    IERC20Token private _xlToken;
     //投资者结构体
     struct Investor {
         address account;
         uint256 lockXLs;
         uint256 unlockXLs;
     }

     event TokenChanged(address indexed token,uint256 indexed time);
     event LockXLEvent(address indexed acc,uint256 indexed lockXLs);
     event StartTimeUnlock(address indexed account,uint256 indexed startTime);
     event UnlockXLEvent(address indexed acc,uint256 indexed unlockXLs);
     constructor(IERC20Token token) public {
         _xlToken = IERC20Token(token);
     }

     function () external {
         if(super.isManager(msg.sender)){
             unlockBatch(); //管理者批量发送
         }else{
             unlockAccount(msg.sender);  //单个拉取
         }
     }
     
     //当前天数 1-100
     function curDays() public view returns(uint256) {
         uint256 curSeconds = now.sub(_startTime);
         uint256 curDay = curSeconds.div(DAY_UINT);
         return curDay;
     }
     
     //是否完成释放
     function isFinished() public view returns(bool) {
         return curDays() >= UNLOCK_DURATION;
     }


     //设置解仓时间
      function setStartTimeUnLock(uint256 _time) public onlyOwner {
          _startTime = _time;
          emit StartTimeUnlock(msg.sender,_time);
      }
    
    function setToken(IERC20Token _token) public onlyOwner {
        _xlToken = IERC20Token(_token);
        emit TokenChanged(address(_token),now);
    }

    //投资者数量
    function investors() public view returns(uint256 count) {
        return _investors.length;
    }

    //添加用户锁仓记录
    function addInvestor(address _acc,uint256 _lockXLs) public notPaused onlyOwner {
        require(_acc != address(0),"无地址");
        uint256 lockXLs = _lockXLs;//.div(10**18); //除去精度
        require(_mapInvestors[_acc].account == address(0),"该投资者已存在!!");
        _investors.push(_acc);
        _mapInvestors[_acc] = Investor({account:_acc,lockXLs:lockXLs,unlockXLs:0});
        emit LockXLEvent(_acc,lockXLs);
    }

    //删除用户记录
    function removeInvestorAtIndex(uint256  index) public onlyOwner {
        if(index < _investors.length) {
            address acc = _investors[index];
            _mapInvestors[acc] = Investor(address(0),0,0);
            delete _investors[index];
            //填上删除的空白
            _investors[index] = _investors[_investors.length - 1];
        }
    }

    function investorAtAccount(address acc) public view returns(address account,
         uint256 lockXLs,
         uint256 unlockXLs) {
        Investor storage inv = _mapInvestors[acc];
             account = inv.account;
             lockXLs = inv.lockXLs;
             unlockXLs = inv.unlockXLs;
    }

    function appendLocksXLs(address acc,uint256 lockXls) public onlyManager {
        require(acc != address(0),"0地址");
        if(_mapInvestors[acc].account == address(0)){//新增
            addInvestor(acc,lockXls);
        }else{ //追加
            Investor storage inv = _mapInvestors[acc];
            inv.lockXLs = inv.lockXLs.add(lockXls);
        }
    }

   //解锁某个账户
    function unlockAccount(address acc) internal {
        Investor storage inv = _mapInvestors[acc];
             if(inv.account == address(0)){
                 return;
             }
              uint curDay = curDays();
              //1%,100天
              uint256 totalUnlock = inv.lockXLs.mul(curDay).div(UNLOCK_DURATION);

              //当前总释放量 - 已经释放的量
              uint256 unlocking = totalUnlock.sub(inv.unlockXLs);
              if(unlocking <= 0){ //等零则已经释放过
                  return;
              }
              inv.unlockXLs = totalUnlock;
              _mapInvestors[acc].unlockXLs = totalUnlock;
              _xlToken.transfer(inv.account,unlocking);
              emit UnlockXLEvent(inv.account,unlocking);
    }
    //批量释放
    function unlockBatch() public notPaused onlyManager {
       // require(isFinished() == false,"释放时间已到");
        //当前释放量 = 锁仓总量*curDay/100 - 已经释放量
        uint curDay = curDays();
        require(curDay <= UNLOCK_DURATION,"释放周期完成!");
        for (uint256 i = 0; i < _investors.length; ++i){
             address acc = _investors[i];
             if(acc == address(0)){
                 continue;
             }
             unlockAccount(acc);
        }
    }

    function balanceAt(address acc) public view returns(uint256 balance){
        require(acc != address(0),"地址无效!");
        balance = _xlToken.balanceOf(acc);
    }
}

pragma solidity >=0.4.24 <0.6.0;
import "./IERC20Token.sol";
contract Ownable {
    address private _owner;
    mapping (address=>bool) private _managers;
    event OwnershipTransferred(address indexed prevOwner,address indexed newOwner);
    event WithdrawEtherEvent(address indexed receiver,uint256 indexed amount,uint256 indexed atime);
    //管理者处理事件
    event ManagerChange(address indexed manager,bool indexed isMgr);
    //modifier
    modifier onlyOwner{
        require(msg.sender == _owner, "sender not eq owner");
        _;
    }

    modifier onlyManager{
        require(_managers[msg.sender] == true, "不是管理员");
        _;
    }
    constructor() internal{
        _owner = msg.sender;
        _managers[msg.sender] = true;
    }

    function owner() public view returns(address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "newOwner can't be empty!");
        address prevOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(prevOwner,newOwner);
    }

    //管理员
    function changeManager(address account,bool isManager) public onlyOwner {
        _managers[account] = isManager;
        emit ManagerChange(account,isManager);
    }
    function isManager(address account) public view returns(bool) {
        return _managers[account];
    }

    /**
     * @dev Rescue compatible ERC20 Token
     *
     * @param tokenAddr ERC20 The address of the ERC20 token contract
     * @param receiver The address of the receiver
     * @param amount uint256
     */
    function rescueTokens(IERC20Token tokenAddr, address receiver, uint256 amount) external onlyOwner {
        IERC20Token _token = IERC20Token(tokenAddr);
        require(receiver != address(0),"receiver can't be empty!");
        uint256 balance = _token.balanceOf(address(this));
        require(balance >= amount,"balance is not enough!");
        require(_token.transfer(receiver, amount),"transfer failed!!");
    }

    /**
     * @dev Withdraw ether
     */
    function withdrawEther(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0),"address can't be empty");
        uint256 balance = address(this).balance;
        require(balance >= amount,"this balance is not enough!");
        to.transfer(amount);
       emit WithdrawEtherEvent(to,amount,now);
    }


}
pragma solidity >=0.4.24 <0.6.0;

/*
    Library for basic math operations with overflow/underflow protection
*/
library SafeMath {
    /**
        @dev returns the sum of _x and _y, reverts if the calculation overflows

        @param _x   value 1
        @param _y   value 2

        @return sum
    */
    function add(uint256 _x, uint256 _y) internal pure returns (uint256) {
        uint256 z = _x + _y;
        require(z >= _x,"SafeMath->mul got a exception");
        return z;
    }

    /**
        @dev returns the difference of _x minus _y, reverts if the calculation underflows

        @param _x   minuend
        @param _y   subtrahend

        @return difference
    */
    function sub(uint256 _x, uint256 _y) internal pure returns (uint256) {
        require(_x >= _y,"SafeMath->sub got a exception");
        return _x - _y;
    }

    /**
        @dev returns the product of multiplying _x by _y, reverts if the calculation overflows

        @param _x   factor 1
        @param _y   factor 2

        @return product
    */
    function mul(uint256 _x, uint256 _y) internal pure returns (uint256) {
        // gas optimization
        if (_x == 0)
            return 0;

        uint256 z = _x * _y;
        require(z / _x == _y,"SafeMath->mul got a exception");
        return z;
    }

      /**
        @dev Integer division of two numbers truncating the quotient, reverts on division by zero.

        @param _x   dividend
        @param _y   divisor

        @return quotient
    */
    function div(uint256 _x, uint256 _y) internal pure returns (uint256) {
        require(_y > 0,"SafeMath->div got a exception");
        uint256 c = _x / _y;

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

pragma solidity >=0.4.24 <0.6.0;
/*
*紧急情况下暂停转账
*
*/
import "./Ownable.sol";
contract UrgencyPause is Ownable{
    bool private _paused;
    event Paused(address indexed account,bool indexed state);
    
    modifier notPaused(){
        require(!_paused,"the state is paused!");
        _;
    }
    constructor() public{
        _paused = false;
    }


    function paused() public view returns(bool) {
        return _paused;
    }

    function setPaused(bool state) public onlyManager {
            _paused = state;
            emit Paused(msg.sender,_paused);
    }

}

