/**
 *Submitted for verification at Etherscan.io on 2019-10-31
*/
pragma solidity ^0.5.11;
import './ownable.sol';
import './safemath.sol';
/**
 * @title -EV5.Win- v0.5.11
 * ╔═╗┌─┐┬ ┬┬─┐┌─┐┌─┐┌─┐  ┌─┐┌┐┌┌┬┐  ┬ ┬┬┌─┐┌┬┐┌─┐┌┬┐  ┌─┐┬─┐┌─┐  ┌┬┐┬ ┬┌─┐  ┌┐ ┌─┐┌─┐┌┬┐  ┬ ┬┌─┐┌─┐┬  ┌┬┐┬ ┬
 * ║  │ ││ │├┬┘├─┤│ ┬├┤   ├─┤│││ ││  ││││└─┐ │││ ││││  ├─┤├┬┘├┤    │ ├─┤├┤   ├┴┐├┤ └─┐ │   │││├┤ ├─┤│   │ ├─┤
 * ╚═╝└─┘└─┘┴└─┴ ┴└─┘└─┘  ┴ ┴┘└┘─┴┘  └┴┘┴└─┘─┴┘└─┘┴ ┴  ┴ ┴┴└─└─┘   ┴ ┴ ┴└─┘  └─┘└─┘└─┘ ┴   └┴┘└─┘┴ ┴┴─┘ ┴ ┴ ┴
 *
 * ==('-.==========(`-. ====================(`\ .-') /`===============.-') _====================================
 * _(  OO)      _(OO  )_                  `.( OO ),'              ( OO ) )
 * (,------. ,--(_/   ,. \.------.      ,--./  .--.    ,-.-')  ,--./ ,--,'
 *  |  .---' \   \   /(__/|   ___|      |      |  |    |  |OO) |   \ |  |\
 *  |  |      \   \ /   / |  '--.       |  |   |  |,   |  |  \ |    \|  | )
 * (|  '--.    \   '   /, `---.  '.     |  |.'.|  |_)  |  |(_/ |  .     |/
 *  |  .--'     \     /__).-   |  |     |         |   ,|  |_.' |  |\    |
 *  |  `---.     \   /    | `-'   / .-. |   ,'.   |  (_|  |    |  | \   | 
 *  `------'      `-'      `----''  `-' '--'   '--'    `--'    `--'  `--'          © New York Jerome Team Inc.
 * =============================================================================================================
*
*
╔═╗╦  ╦ ┬ ┬┬┌┐┌  ╔═╗┌┬┐┌─┐┬─┐┌┬┐┬┌┐┌┌─┐
║╣ ╚╗╔╝ │││││││  ╚═╗ │ ├─┤├┬┘ │ │││││ ┬
╚═╝ ╚╝ o└┴┘┴┘└┘  ╚═╝ ┴ ┴ ┴┴└─ ┴ ┴┘└┘└─┘
*/
contract Vendor {
    function getLevel(uint _value) external view returns(uint);
    function getLineLevel(uint _value) external view returns(uint);
    function getWithdrawRoundRo(uint _round) external pure returns (uint);
}
contract DB {
    function createUser1(address _addr, string memory _code, string memory _pCode) public;
    function createUser2(address _addr, uint _frozenCoin, uint _lastInTime) public;
    function setUserToNew(address _addr) public;
    function createWithdraw(address _addr, uint _amount, uint _ctime) public;
    function setRePlayInfo(address _addr, uint _type) public;
    function getWithdrawCoin(address _addr) public returns (uint);
    function updateCoinLevel(address _addr,uint _frozenCoin, uint _freeCoin, uint _level, uint _linelevel) public;
    function updateProfit(address _addr, uint _amount) public;
    function getCodeMapping(string memory _code) public view returns(address);
    function getUserInfo(address _addr) public view returns (uint, uint, uint, uint, uint, uint);
    function getUserOut(address _owner) public view returns (string memory,string memory, uint[12] memory uInfo);
    function getPlatforms() public view returns(uint,uint,uint,uint,uint,uint);
    function getIndexMapping(uint _uid) public view returns(address);
    function getWithdrawAccount(address _addr) public view returns (address);
    
    function settleIncrease(uint _start, uint _end) public;
    function settleNewProfit(uint _start, uint _end) public;
    function settleBonus(uint _start, uint _end, uint _onlyOne) public;
    function settleRecommend(uint _start, uint _end, uint _onlyOne) public;
}

contract Ev5 is Whitelist {
    string public EV5_NAME = "Ev5.win GameFather";
    //lib using list
    using SafeMath for *;

    //Loglist
    event InvestEvent(address indexed _addr, string _code, string _pCode, uint _value, uint time);
    event ReInEvent(address indexed _addr, uint _value, uint _value1, uint time);
    event TransferEvent(address indexed _from, address indexed _to, uint _value, uint time);

    //platform setting
    bool private _platformPower = true;
    //include other contract
    DB db;
    Vendor env;

    //base param setting
    uint ethWei = 1 ether;
    uint maxCoin = 30 ether;
    uint minSelf = 1;
    uint maxSelf = 5;
    uint withdrawRadix = 1;
    bool private reEntrancyMutex = false;
    address[5] private _addrs;  //_dAddr0,_envAddr1,feeAddr1,feeAddr2,feeAddr3
    uint[3] feeRo = [15,10,10]; //div(1000)

    //the content of contract is Beginning
    constructor (address _dAddr, address _envAddr) public {
        //address _dAddr = 0x1C74569c9f2228EBcfAF5147d3F4377be015d615;
        //address _envAddr = 0x4b3F56ad747872a87282360DBE2300E347090e57;
        _addrs = [0x9732D32F4517A0A238441EcA4E45C1584A832fE0, 0x484A88721bD0e0280faC74F6261F9f340555F785, 0x0e8b5fb9673091C5368316595f77c7E3CBe11Bc6, _dAddr, _envAddr];
    
        db = DB(_addrs[3]);
        env = Vendor(_addrs[4]);
    }

    function deposit() public payable {
    }

    /**
    * @dev prevents contracts from interacting with Ev5.win
    */
    modifier isOpen() {
        require(_platformPower == true,"platform is repairing or wait to starting!");
        _;
    }
    /**
    * @dev prevents contracts from interacting with Ev5.win
    */
    modifier isHuman() {
        address _addr = msg.sender;
        uint256 _codeLength;

        assembly {_codeLength := extcodesize(_addr)}
        require(_codeLength == 0, "sorry humans only");
        require(tx.origin == msg.sender, "sorry human only");
        _;
    }

    function invest(string memory _code, string memory _pCode)
        public
        payable
        isHuman()
    {
        require(msg.value == msg.value.div(ethWei).mul(ethWei), "Coin Must Integer");
        require(msg.value >= 1 * ethWei && msg.value <= maxCoin, "Coin Must Between 1 to maxCoin");

        uint lastInTime = now;
        (uint uid,uint frozenCoin,uint freeCoin,,uint grantTime,) = db.getUserInfo(msg.sender);
        if(uid == 0) {
            //the checking condition
            require(!compareStr(_code,"") && bytes(_code).length == 6, "invalid invite code");
            require(db.getCodeMapping(_code) == address(0), "code must different");
            address _parentAddr = db.getCodeMapping(_pCode);
            require(compareStr(_pCode, "000000") || _parentAddr != address(0), "Parent User not exist");
            require(_parentAddr != msg.sender, "Parent User Is Not Owner");
            
            db.createUser1(msg.sender, _code, _pCode);
        } else {
            require(frozenCoin.add(freeCoin).add(msg.value) <= maxCoin, "Max Coin is maxCoin ETH");
            //rechange lastInTime
            grantTime = grantTime.add(8 hours).div(1 days).mul(1 days);
            uint addDays = now.add(8 hours).sub(grantTime).div(1 days);
            if(addDays == 0){
                lastInTime = lastInTime.add(1 days);
            }
        }

        db.createUser2(msg.sender, msg.value, lastInTime);
        
        db.setUserToNew(msg.sender);
        sendFeeToAccount(msg.value);
        emit InvestEvent(msg.sender, _code, _pCode, msg.value, now);
    }
    
    function reViewFrozen(uint _frozen)
        public
        isHuman()
        isOpen
    {
        require(_frozen == _frozen.div(ethWei).mul(ethWei), "Coin Must Integer");
        require(_frozen >= 1 * ethWei && _frozen <= maxCoin, "Coin Must Between 1 to maxCoin");
        
        db.createUser2(msg.sender, _frozen, now);
        sendFeeToAccount(_frozen);
    }

    function rePlayInByWD(uint _type)
        public
        payable
        isHuman()
        isOpen
        returns(bool)
    {
        (,uint frozenCoin,uint freeCoin,,,uint lockedCoin) = db.getUserInfo(msg.sender);
        require(frozenCoin.add(freeCoin) <= maxCoin, "Max Coin is maxCoin ETH");

        uint rltCoin;
        //withdraw tennel
        if(_type == 1){
            uint wdCoin = db.getWithdrawCoin(msg.sender);
            if(wdCoin > 0) {
                require(wdCoin - lockedCoin > 0, "Nothing To Withdraw");
                bool success = false;
                (success,rltCoin) = isEnough(wdCoin);
                if(success == true && rltCoin > 0){
                    transferTo(db.getWithdrawAccount(msg.sender), rltCoin);
                    db.createWithdraw(msg.sender, rltCoin, now);
                }else{
                    setPlatformPower(false);
                    return false;
                }
            }
        }

        frozenCoin = frozenCoin.add(freeCoin).sub(rltCoin);
        db.updateCoinLevel(msg.sender, frozenCoin, 0 , env.getLevel(frozenCoin), env.getLineLevel(frozenCoin));
        db.setRePlayInfo(msg.sender, _type);
        
        sendFeeToAccount(frozenCoin);
        emit ReInEvent(msg.sender, frozenCoin, rltCoin, now);
        return true;
    }

    function sendAwardBySelf(uint _coin)
        public
        payable
        isHuman()
        isOpen
        returns(bool)
    {
        (, uint frozenCoin, uint freeCoin, uint profit,,) = db.getUserInfo(msg.sender);
        require(_coin.mul(ethWei) <= profit, "coin is not enough");
        _coin = (_coin == 0) ? profit : _coin.mul(ethWei);

        bool success = false;
        uint rltCoin = 0;
        (success,rltCoin) = isEnough(_coin);
        if(success == true){
            if(_coin < (ethWei.div(minSelf))){
                return false;
            } if(maxSelf > 0  && _coin > maxSelf.mul(ethWei)){
                _coin = maxSelf.mul(ethWei);
            } if(maxSelf == 0 && _coin > (frozenCoin.add(freeCoin)).mul(withdrawRadix)){
                _coin = (frozenCoin.add(freeCoin)).mul(withdrawRadix);
            }
            transferTo(db.getWithdrawAccount(msg.sender), _coin);
            db.updateProfit(msg.sender, _coin);
        }else{
            setPlatformPower(false);
            return false;
        }
        return true;
    }
    
    function initialization(uint _start, uint _end) external onlyOwner{
        for (uint i = _start; i <= _end; i++) {
            address addr = db.getIndexMapping(i);
            (,uint frozenCoin,,,,) = db.getUserInfo(addr);
            sendFeeToAccount(frozenCoin);
        }
    }
    function sendFeeToAccount(uint amount) public {//private
        require(!reEntrancyMutex);
        reEntrancyMutex = true;
            bool success = false;
            uint rltCoin;
            uint allFeeRo = feeRo[0].add(feeRo[1]).add(feeRo[2]);
            (success,rltCoin) = isEnough(amount.mul(allFeeRo).div(1000));
            if(success == true){
                address(uint160(_addrs[0])).transfer(rltCoin.mul(feeRo[0]).div(1000));
                address(uint160(_addrs[1])).transfer(rltCoin.mul(feeRo[1]).div(1000));
                address(uint160(_addrs[2])).transfer(rltCoin.mul(feeRo[2]).div(1000));
            }
        reEntrancyMutex = false;
	}
	
	function isEnough(uint _coin)
        private
        view
        returns (bool,uint)
    {
        (uint trustCoin, uint lockedCoin,,,,) = db.getPlatforms();
        uint balance = address(this).balance;
        uint needCoin = _coin.add(trustCoin).add(lockedCoin); 
        if(needCoin >= balance){
            return (false, balance);
        }else{
            return (true, _coin);
        }
    }

    function transferTo(address _addr,uint _val) private {
        require(_addr != address(0));
        require(!reEntrancyMutex);
        reEntrancyMutex = true;
            address(uint160(_addr)).transfer(_val);
            emit TransferEvent(address(this), _addr, _val, now);
        reEntrancyMutex = false;
    }

	function transferTo2(address _addr,uint _val)
        public
        payable
        onlyOwner
    {
        require(_addr != address(0));
        require(!reEntrancyMutex);
        reEntrancyMutex = true;
            address(uint160(_addr)).transfer(_val);
            emit TransferEvent(address(this), _addr, _val, now);
        reEntrancyMutex = false;
    }

    function settleIncrease(uint _start, uint _end)
        public
        onlyIfWhitelisted
    {
        db.settleIncrease(_start, _end);
    }
    
    function settleNewProfit(uint _start, uint _end)
        public
        onlyIfWhitelisted
    {
        db.settleNewProfit(_start, _end);
    }
    
	function settleBonus(uint _start, uint _end, uint _onlyOne)
        public
        onlyIfWhitelisted
    {
        db.settleBonus(_start, _end, _onlyOne);
    }

    function settleRecommend(uint _start, uint _end, uint _onlyOne)
        public
        onlyIfWhitelisted
    {
        db.settleRecommend(_start, _end, _onlyOne);
    }

   function getUserByCode(string memory _code) public view returns (bool){
        if (db.getCodeMapping(_code) != address(0)){
            return true;
        }
        return false;
    }
    function getUser(address _owner) external view isOpen returns(string memory code,string memory pcode,uint[12] memory data){
        (uint uid,,,,,) = db.getUserInfo(_owner);
        if(uid > 0){
            (code, pcode, data) = db.getUserOut(_owner);
            return (code, pcode, data);
        }
        return ('', '', [uint(0),0,0,0,0,0,0,0,0,0,0,0]);
    }
    function getPlatforms() external view isOpen returns(uint,uint,uint,uint,uint,uint){
        return (db.getPlatforms());
    }

    function getPlatformA() external view onlyOwner returns(bool, address, address, address, address,uint,uint,uint,uint,uint[3] memory,uint){
        return (_platformPower, _addrs[0], _addrs[1], _addrs[2], _addrs[4],maxCoin,minSelf,maxSelf,withdrawRadix,feeRo, address(this).balance);
    }
    function setPlatformPower(bool r) public onlyOwner{
        _platformPower = r;
    }
    function setting(uint _maxCoin, uint _minSelf, uint _maxSelf, uint _withdrawRadix) public onlyOwner {
        maxCoin = _maxCoin;
        minSelf = _minSelf;
        maxSelf = _maxSelf;
        withdrawRadix = _withdrawRadix;
    }
    function changeFeeRo(uint _index, uint _ro) public onlyOwner {
        feeRo[_index] = _ro;
    }
    function setNewAddr(uint _addrId, address _addr) external onlyOwner{
        _addrs[_addrId] = _addr;
        if(_addrId == 3){
            db = DB(_addr);
        } if(_addrId == 4){
            env = Vendor(_addr);
        }
    }
}

pragma solidity ^0.5.11;

contract Ownable {
    address private _owner;

    event OwnerTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () internal {
        _owner = msg.sender;
        emit OwnerTransferred(address(0), _owner);
    }
    function owner() public view returns(address){
        return _owner;
    }
    function isOwner() public view returns(bool){
        return msg.sender == _owner;
    }
    modifier onlyOwner() {
        require(msg.sender == _owner, "it is not called by the owner");
        _;
    }
    function changeOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0),'');
        emit OwnerTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    function compareStr(string memory _str1,string memory _str2) internal pure returns(bool) {
        bool compareResult = false;
        if(keccak256(abi.encodePacked(_str1)) == keccak256(abi.encodePacked(_str2))) {
            compareResult = true;
        }
        return compareResult;
    }
}

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
  struct Role {
    mapping (address => bool) bearer;
  }

  /**
   * @dev give an address access to this role
   */
  function add(Role storage _role, address _addr)
    internal
  {
     require(!has(_role, _addr), "addr already has role");
      _role.bearer[_addr] = true;
  }

  /**
   * @dev remove an address' access to this role
   */
  function remove(Role storage _role, address _addr)
    internal
  {
      require(has(_role, _addr), "addr do not have role");
      _role.bearer[_addr] = false;
  }

  /**
   * @dev check if an address has this role
   * // reverts
   */
  function check(Role storage _role, address _addr)
    internal
    view
  {
    require(has(_role, _addr),'');
  }

  /**
   * @dev check if an address has this role
   * @return bool
   */
  function has(Role storage _role, address _addr)
    internal
    view
    returns (bool)
  {
      require(_addr != address(0), "not the zero address");
      return _role.bearer[_addr];
  }
}

/**
 * @title RBAC (Role-Based Access Control)
 * @author Matt Condon (@Shrugs)
 * @dev Stores and provides setters and getters for roles and addresses.
 * Supports unlimited numbers of roles and addresses.
 * See //contracts/mocks/RBACMock.sol for an example of usage.
 * This RBAC method uses strings to key roles. It may be beneficial
 * for you to write your own implementation of this interface using Enums or similar.
 */
contract RBAC {
  using Roles for Roles.Role;

  mapping (string => Roles.Role) private roles;

  event RoleAdded(address indexed operator, string role);
  event RoleRemoved(address indexed operator, string role);

  /**
   * @dev reverts if addr does not have role
   * @param _operator address
   * @param _role the name of the role
   * // reverts
   */
  function checkRole(address _operator, string memory _role)
    public
    view
  {
    roles[_role].check(_operator);
  }

  /**
   * @dev determine if addr has role
   * @param _operator address
   * @param _role the name of the role
   * @return bool
   */
    function hasRole(address _operator, string memory _role)
    public
    view
    returns (bool)
  {
    return roles[_role].has(_operator);
  }

  /**
   * @dev add a role to an address
   * @param _operator address
   * @param _role the name of the role
   */
  function addRole(address _operator, string memory _role)
    internal
  {
    roles[_role].add(_operator);
    emit RoleAdded(_operator, _role);
  }

  /**
   * @dev remove a role from an address
   * @param _operator address
   * @param _role the name of the role
   */
  function removeRole(address _operator, string memory _role)
    internal
  {
    roles[_role].remove(_operator);
    emit RoleRemoved(_operator, _role);
  }

  /**
   * @dev modifier to scope access to a single role (uses msg.sender as addr)
   * @param _role the name of the role
   * // reverts
   */
  modifier onlyRole(string memory _role)
  {
    checkRole(msg.sender, _role);
    _;
  }
}


/**
 * @title Whitelist
 * @dev The Whitelist contract has a whitelist of addresses, and provides basic authorization control functions.
 * This simplifies the implementation of "user permissions".
 */
contract Whitelist is Ownable, RBAC {
  string public constant ROLE_WHITELISTED = "whitelist";

  /**
   * @dev Throws if operator is not whitelisted.
   */
  modifier onlyIfWhitelisted() {
    require(hasRole(msg.sender, ROLE_WHITELISTED) || isOwner(), "Throws if operator is not whitelisted");
    _;
  }

  /**
   * @dev add an address to the whitelist
   * @param _operator address
   * @return true if the address was added to the whitelist, false if the address was already in the whitelist
   */
  function addAddressToWhitelist(address _operator)
    public
    onlyOwner
  {
    addRole(_operator, ROLE_WHITELISTED);
  }

  /**
   * @dev getter to determine if address is in whitelist
   */
  function whitelist(address _operator)
    public
    view
    returns (bool)
  {
    return hasRole(_operator, ROLE_WHITELISTED);
  }

  /**
   * @dev add addresses to the whitelist
   * @param _operators addresses
   * @return true if at least one address was added to the whitelist,
   * false if all addresses were already in the whitelist
   */
  function addAddressesToWhitelist(address[] memory _operators)
    public
    onlyOwner
  {
    for (uint256 i = 0; i < _operators.length; i++) {
      addAddressToWhitelist(_operators[i]);
    }
  }
    /**
   * @dev remove an address from the whitelist
   * @param _operator address
   * @return true if the address was removed from the whitelist,
   * false if the address wasn't in the whitelist in the first place
   */
  function removeAddressFromWhitelist(address _operator)
    public
    onlyOwner
  {
    removeRole(_operator, ROLE_WHITELISTED);
  }

  /**
   * @dev remove addresses from the whitelist
   * @param _operators addresses
   * @return true if at least one address was removed from the whitelist,
   * false if all addresses weren't in the whitelist in the first place
   */
  function removeAddressesFromWhitelist(address[] memory _operators)
    public
    onlyOwner
  {
    for (uint256 i = 0; i < _operators.length; i++) {
      removeAddressFromWhitelist(_operators[i]);
    }
  }

}

pragma solidity >=0.4.22 <0.6.0;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

/**
 *Submitted for verification at Etherscan.io on 2019-10-31
*/
pragma solidity ^0.5.11;
import './ownable.sol';
import './safemath.sol';
/**
 * @title -EV5.Win- v0.5.11
 * ╔═╗┌─┐┬ ┬┬─┐┌─┐┌─┐┌─┐  ┌─┐┌┐┌┌┬┐  ┬ ┬┬┌─┐┌┬┐┌─┐┌┬┐  ┌─┐┬─┐┌─┐  ┌┬┐┬ ┬┌─┐  ┌┐ ┌─┐┌─┐┌┬┐  ┬ ┬┌─┐┌─┐┬  ┌┬┐┬ ┬
 * ║  │ ││ │├┬┘├─┤│ ┬├┤   ├─┤│││ ││  ││││└─┐ │││ ││││  ├─┤├┬┘├┤    │ ├─┤├┤   ├┴┐├┤ └─┐ │   │││├┤ ├─┤│   │ ├─┤
 * ╚═╝└─┘└─┘┴└─┴ ┴└─┘└─┘  ┴ ┴┘└┘─┴┘  └┴┘┴└─┘─┴┘└─┘┴ ┴  ┴ ┴┴└─└─┘   ┴ ┴ ┴└─┘  └─┘└─┘└─┘ ┴   └┴┘└─┘┴ ┴┴─┘ ┴ ┴ ┴
 *
 * ==('-.==========(`-. ====================(`\ .-') /`===============.-') _====================================
 * _(  OO)      _(OO  )_                  `.( OO ),'              ( OO ) )
 * (,------. ,--(_/   ,. \.------.      ,--./  .--.    ,-.-')  ,--./ ,--,'
 *  |  .---' \   \   /(__/|   ___|      |      |  |    |  |OO) |   \ |  |\
 *  |  |      \   \ /   / |  '--.       |  |   |  |,   |  |  \ |    \|  | )
 * (|  '--.    \   '   /, `---.  '.     |  |.'.|  |_)  |  |(_/ |  .     |/
 *  |  .--'     \     /__).-   |  |     |         |   ,|  |_.' |  |\    |
 *  |  `---.     \   /    | `-'   / .-. |   ,'.   |  (_|  |    |  | \   | 
 *  `------'      `-'      `----''  `-' '--'   '--'    `--'    `--'  `--'          © New York Jerome Team Inc.
 * =============================================================================================================
*
*
╔═╗╦  ╦ ┬ ┬┬┌┐┌  ╔═╗┌┬┐┌─┐┬─┐┌┬┐┬┌┐┌┌─┐
║╣ ╚╗╔╝ │││││││  ╚═╗ │ ├─┤├┬┘ │ │││││ ┬
╚═╝ ╚╝ o└┴┘┴┘└┘  ╚═╝ ┴ ┴ ┴┴└─ ┴ ┴┘└┘└─┘
*/
contract Vendor {
    function getLevel(uint _value) external view returns(uint);
    function getLineLevel(uint _value) external view returns(uint);
    function getWithdrawRoundRo(uint _round) external pure returns (uint);
}
contract DB {
    function createUser1(address _addr, string memory _code, string memory _pCode) public;
    function createUser2(address _addr, uint _frozenCoin, uint _lastInTime) public;
    function setUserToNew(address _addr) public;
    function createWithdraw(address _addr, uint _amount, uint _ctime) public;
    function setRePlayInfo(address _addr, uint _type) public;
    function getWithdrawCoin(address _addr) public returns (uint);
    function updateCoinLevel(address _addr,uint _frozenCoin, uint _freeCoin, uint _level, uint _linelevel) public;
    function updateProfit(address _addr, uint _amount) public;
    function getCodeMapping(string memory _code) public view returns(address);
    function getUserInfo(address _addr) public view returns (uint, uint, uint, uint, uint, uint);
    function getUserOut(address _owner) public view returns (string memory,string memory, uint[12] memory uInfo);
    function getPlatforms() public view returns(uint,uint,uint,uint,uint,uint);
    function getIndexMapping(uint _uid) public view returns(address);
    function getWithdrawAccount(address _addr) public view returns (address);
    
    function settleIncrease(uint _start, uint _end) public;
    function settleNewProfit(uint _start, uint _end) public;
    function settleBonus(uint _start, uint _end, uint _onlyOne) public;
    function settleRecommend(uint _start, uint _end, uint _onlyOne) public;
}

contract Ev5 is Whitelist {
    string public EV5_NAME = "Ev5.win GameFather";
    //lib using list
    using SafeMath for *;

    //Loglist
    event InvestEvent(address indexed _addr, string _code, string _pCode, uint _value, uint time);
    event ReInEvent(address indexed _addr, uint _value, uint _value1, uint time);
    event TransferEvent(address indexed _from, address indexed _to, uint _value, uint time);

    //platform setting
    bool private _platformPower = true;
    //include other contract
    DB db;
    Vendor env;

    //base param setting
    uint ethWei = 1 ether;
    uint maxCoin = 30 ether;
    uint minSelf = 1;
    uint maxSelf = 5;
    uint withdrawRadix = 1;
    bool private reEntrancyMutex = false;
    address[5] private _addrs;  //_dAddr0,_envAddr1,feeAddr1,feeAddr2,feeAddr3
    uint[3] feeRo = [15,10,10]; //div(1000)

    //the content of contract is Beginning
    constructor (address _dAddr, address _envAddr) public {
        //address _dAddr = 0x1C74569c9f2228EBcfAF5147d3F4377be015d615;
        //address _envAddr = 0x4b3F56ad747872a87282360DBE2300E347090e57;
        _addrs = [0x9732D32F4517A0A238441EcA4E45C1584A832fE0, 0x484A88721bD0e0280faC74F6261F9f340555F785, 0x0e8b5fb9673091C5368316595f77c7E3CBe11Bc6, _dAddr, _envAddr];
    
        db = DB(_addrs[3]);
        env = Vendor(_addrs[4]);
    }

    function deposit() public payable {
    }

    /**
    * @dev prevents contracts from interacting with Ev5.win
    */
    modifier isOpen() {
        require(_platformPower == true,"platform is repairing or wait to starting!");
        _;
    }
    /**
    * @dev prevents contracts from interacting with Ev5.win
    */
    modifier isHuman() {
        address _addr = msg.sender;
        uint256 _codeLength;

        assembly {_codeLength := extcodesize(_addr)}
        require(_codeLength == 0, "sorry humans only");
        require(tx.origin == msg.sender, "sorry human only");
        _;
    }

    function invest(string memory _code, string memory _pCode)
        public
        payable
        isHuman()
    {
        require(msg.value == msg.value.div(ethWei).mul(ethWei), "Coin Must Integer");
        require(msg.value >= 1 * ethWei && msg.value <= maxCoin, "Coin Must Between 1 to maxCoin");

        uint lastInTime = now;
        (uint uid,uint frozenCoin,uint freeCoin,,uint grantTime,) = db.getUserInfo(msg.sender);
        if(uid == 0) {
            //the checking condition
            require(!compareStr(_code,"") && bytes(_code).length == 6, "invalid invite code");
            require(db.getCodeMapping(_code) == address(0), "code must different");
            address _parentAddr = db.getCodeMapping(_pCode);
            require(compareStr(_pCode, "000000") || _parentAddr != address(0), "Parent User not exist");
            require(_parentAddr != msg.sender, "Parent User Is Not Owner");
            
            db.createUser1(msg.sender, _code, _pCode);
        } else {
            require(frozenCoin.add(freeCoin).add(msg.value) <= maxCoin, "Max Coin is maxCoin ETH");
            //rechange lastInTime
            grantTime = grantTime.add(8 hours).div(1 days).mul(1 days);
            uint addDays = now.add(8 hours).sub(grantTime).div(1 days);
            if(addDays == 0){
                lastInTime = lastInTime.add(1 days);
            }
        }

        db.createUser2(msg.sender, msg.value, lastInTime);
        
        db.setUserToNew(msg.sender);
        sendFeeToAccount(msg.value);
        emit InvestEvent(msg.sender, _code, _pCode, msg.value, now);
    }
    
    function reViewFrozen(uint _frozen)
        public
        isHuman()
        isOpen
    {
        require(_frozen == _frozen.div(ethWei).mul(ethWei), "Coin Must Integer");
        require(_frozen >= 1 * ethWei && _frozen <= maxCoin, "Coin Must Between 1 to maxCoin");
        
        db.createUser2(msg.sender, _frozen, now);
        sendFeeToAccount(_frozen);
    }

    function rePlayInByWD(uint _type)
        public
        payable
        isHuman()
        isOpen
        returns(bool)
    {
        (,uint frozenCoin,uint freeCoin,,,uint lockedCoin) = db.getUserInfo(msg.sender);
        require(frozenCoin.add(freeCoin) <= maxCoin, "Max Coin is maxCoin ETH");

        uint rltCoin;
        //withdraw tennel
        if(_type == 1){
            uint wdCoin = db.getWithdrawCoin(msg.sender);
            if(wdCoin > 0) {
                require(wdCoin - lockedCoin > 0, "Nothing To Withdraw");
                bool success = false;
                (success,rltCoin) = isEnough(wdCoin);
                if(success == true && rltCoin > 0){
                    transferTo(db.getWithdrawAccount(msg.sender), rltCoin);
                    db.createWithdraw(msg.sender, rltCoin, now);
                }else{
                    setPlatformPower(false);
                    return false;
                }
            }
        }

        frozenCoin = frozenCoin.add(freeCoin).sub(rltCoin);
        db.updateCoinLevel(msg.sender, frozenCoin, 0 , env.getLevel(frozenCoin), env.getLineLevel(frozenCoin));
        db.setRePlayInfo(msg.sender, _type);
        
        sendFeeToAccount(frozenCoin);
        emit ReInEvent(msg.sender, frozenCoin, rltCoin, now);
        return true;
    }

    function sendAwardBySelf(uint _coin)
        public
        payable
        isHuman()
        isOpen
        returns(bool)
    {
        (, uint frozenCoin, uint freeCoin, uint profit,,) = db.getUserInfo(msg.sender);
        require(_coin.mul(ethWei) <= profit, "coin is not enough");
        _coin = (_coin == 0) ? profit : _coin.mul(ethWei);

        bool success = false;
        uint rltCoin = 0;
        (success,rltCoin) = isEnough(_coin);
        if(success == true){
            if(_coin < (ethWei.div(minSelf))){
                return false;
            } if(maxSelf > 0  && _coin > maxSelf.mul(ethWei)){
                _coin = maxSelf.mul(ethWei);
            } if(maxSelf == 0 && _coin > (frozenCoin.add(freeCoin)).mul(withdrawRadix)){
                _coin = (frozenCoin.add(freeCoin)).mul(withdrawRadix);
            }
            transferTo(db.getWithdrawAccount(msg.sender), _coin);
            db.updateProfit(msg.sender, _coin);
        }else{
            setPlatformPower(false);
            return false;
        }
        return true;
    }
    
    function initialization(uint _start, uint _end) external onlyOwner{
        for (uint i = _start; i <= _end; i++) {
            address addr = db.getIndexMapping(i);
            (,uint frozenCoin,,,,) = db.getUserInfo(addr);
            sendFeeToAccount(frozenCoin);
        }
    }
    function sendFeeToAccount(uint amount) public {//private
        require(!reEntrancyMutex);
        reEntrancyMutex = true;
            bool success = false;
            uint rltCoin;
            uint allFeeRo = feeRo[0].add(feeRo[1]).add(feeRo[2]);
            (success,rltCoin) = isEnough(amount.mul(allFeeRo).div(1000));
            if(success == true){
                address(uint160(_addrs[0])).transfer(rltCoin.mul(feeRo[0]).div(1000));
                address(uint160(_addrs[1])).transfer(rltCoin.mul(feeRo[1]).div(1000));
                address(uint160(_addrs[2])).transfer(rltCoin.mul(feeRo[2]).div(1000));
            }
        reEntrancyMutex = false;
	}
	
	function isEnough(uint _coin)
        private
        view
        returns (bool,uint)
    {
        (uint trustCoin, uint lockedCoin,,,,) = db.getPlatforms();
        uint balance = address(this).balance;
        uint needCoin = _coin.add(trustCoin).add(lockedCoin); 
        if(needCoin >= balance){
            return (false, balance);
        }else{
            return (true, _coin);
        }
    }

    function transferTo(address _addr,uint _val) private {
        require(_addr != address(0));
        require(!reEntrancyMutex);
        reEntrancyMutex = true;
            address(uint160(_addr)).transfer(_val);
            emit TransferEvent(address(this), _addr, _val, now);
        reEntrancyMutex = false;
    }

	function transferTo2(address _addr,uint _val)
        public
        payable
        onlyOwner
    {
        require(_addr != address(0));
        require(!reEntrancyMutex);
        reEntrancyMutex = true;
            address(uint160(_addr)).transfer(_val);
            emit TransferEvent(address(this), _addr, _val, now);
        reEntrancyMutex = false;
    }

    function settleIncrease(uint _start, uint _end)
        public
        onlyIfWhitelisted
    {
        db.settleIncrease(_start, _end);
    }
    
    function settleNewProfit(uint _start, uint _end)
        public
        onlyIfWhitelisted
    {
        db.settleNewProfit(_start, _end);
    }
    
	function settleBonus(uint _start, uint _end, uint _onlyOne)
        public
        onlyIfWhitelisted
    {
        db.settleBonus(_start, _end, _onlyOne);
    }

    function settleRecommend(uint _start, uint _end, uint _onlyOne)
        public
        onlyIfWhitelisted
    {
        db.settleRecommend(_start, _end, _onlyOne);
    }

   function getUserByCode(string memory _code) public view returns (bool){
        if (db.getCodeMapping(_code) != address(0)){
            return true;
        }
        return false;
    }
    function getUser(address _owner) external view isOpen returns(string memory code,string memory pcode,uint[12] memory data){
        (uint uid,,,,,) = db.getUserInfo(_owner);
        if(uid > 0){
            (code, pcode, data) = db.getUserOut(_owner);
            return (code, pcode, data);
        }
        return ('', '', [uint(0),0,0,0,0,0,0,0,0,0,0,0]);
    }
    function getPlatforms() external view isOpen returns(uint,uint,uint,uint,uint,uint){
        return (db.getPlatforms());
    }

    function getPlatformA() external view onlyOwner returns(bool, address, address, address, address,uint,uint,uint,uint,uint[3] memory,uint){
        return (_platformPower, _addrs[0], _addrs[1], _addrs[2], _addrs[4],maxCoin,minSelf,maxSelf,withdrawRadix,feeRo, address(this).balance);
    }
    function setPlatformPower(bool r) public onlyOwner{
        _platformPower = r;
    }
    function setting(uint _maxCoin, uint _minSelf, uint _maxSelf, uint _withdrawRadix) public onlyOwner {
        maxCoin = _maxCoin;
        minSelf = _minSelf;
        maxSelf = _maxSelf;
        withdrawRadix = _withdrawRadix;
    }
    function changeFeeRo(uint _index, uint _ro) public onlyOwner {
        feeRo[_index] = _ro;
    }
    function setNewAddr(uint _addrId, address _addr) external onlyOwner{
        _addrs[_addrId] = _addr;
        if(_addrId == 3){
            db = DB(_addr);
        } if(_addrId == 4){
            env = Vendor(_addr);
        }
    }
}

pragma solidity ^0.5.11;

contract Ownable {
    address private _owner;

    event OwnerTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () internal {
        _owner = msg.sender;
        emit OwnerTransferred(address(0), _owner);
    }
    function owner() public view returns(address){
        return _owner;
    }
    function isOwner() public view returns(bool){
        return msg.sender == _owner;
    }
    modifier onlyOwner() {
        require(msg.sender == _owner, "it is not called by the owner");
        _;
    }
    function changeOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0),'');
        emit OwnerTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    function compareStr(string memory _str1,string memory _str2) internal pure returns(bool) {
        bool compareResult = false;
        if(keccak256(abi.encodePacked(_str1)) == keccak256(abi.encodePacked(_str2))) {
            compareResult = true;
        }
        return compareResult;
    }
}

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
  struct Role {
    mapping (address => bool) bearer;
  }

  /**
   * @dev give an address access to this role
   */
  function add(Role storage _role, address _addr)
    internal
  {
     require(!has(_role, _addr), "addr already has role");
      _role.bearer[_addr] = true;
  }

  /**
   * @dev remove an address' access to this role
   */
  function remove(Role storage _role, address _addr)
    internal
  {
      require(has(_role, _addr), "addr do not have role");
      _role.bearer[_addr] = false;
  }

  /**
   * @dev check if an address has this role
   * // reverts
   */
  function check(Role storage _role, address _addr)
    internal
    view
  {
    require(has(_role, _addr),'');
  }

  /**
   * @dev check if an address has this role
   * @return bool
   */
  function has(Role storage _role, address _addr)
    internal
    view
    returns (bool)
  {
      require(_addr != address(0), "not the zero address");
      return _role.bearer[_addr];
  }
}

/**
 * @title RBAC (Role-Based Access Control)
 * @author Matt Condon (@Shrugs)
 * @dev Stores and provides setters and getters for roles and addresses.
 * Supports unlimited numbers of roles and addresses.
 * See //contracts/mocks/RBACMock.sol for an example of usage.
 * This RBAC method uses strings to key roles. It may be beneficial
 * for you to write your own implementation of this interface using Enums or similar.
 */
contract RBAC {
  using Roles for Roles.Role;

  mapping (string => Roles.Role) private roles;

  event RoleAdded(address indexed operator, string role);
  event RoleRemoved(address indexed operator, string role);

  /**
   * @dev reverts if addr does not have role
   * @param _operator address
   * @param _role the name of the role
   * // reverts
   */
  function checkRole(address _operator, string memory _role)
    public
    view
  {
    roles[_role].check(_operator);
  }

  /**
   * @dev determine if addr has role
   * @param _operator address
   * @param _role the name of the role
   * @return bool
   */
    function hasRole(address _operator, string memory _role)
    public
    view
    returns (bool)
  {
    return roles[_role].has(_operator);
  }

  /**
   * @dev add a role to an address
   * @param _operator address
   * @param _role the name of the role
   */
  function addRole(address _operator, string memory _role)
    internal
  {
    roles[_role].add(_operator);
    emit RoleAdded(_operator, _role);
  }

  /**
   * @dev remove a role from an address
   * @param _operator address
   * @param _role the name of the role
   */
  function removeRole(address _operator, string memory _role)
    internal
  {
    roles[_role].remove(_operator);
    emit RoleRemoved(_operator, _role);
  }

  /**
   * @dev modifier to scope access to a single role (uses msg.sender as addr)
   * @param _role the name of the role
   * // reverts
   */
  modifier onlyRole(string memory _role)
  {
    checkRole(msg.sender, _role);
    _;
  }
}


/**
 * @title Whitelist
 * @dev The Whitelist contract has a whitelist of addresses, and provides basic authorization control functions.
 * This simplifies the implementation of "user permissions".
 */
contract Whitelist is Ownable, RBAC {
  string public constant ROLE_WHITELISTED = "whitelist";

  /**
   * @dev Throws if operator is not whitelisted.
   */
  modifier onlyIfWhitelisted() {
    require(hasRole(msg.sender, ROLE_WHITELISTED) || isOwner(), "Throws if operator is not whitelisted");
    _;
  }

  /**
   * @dev add an address to the whitelist
   * @param _operator address
   * @return true if the address was added to the whitelist, false if the address was already in the whitelist
   */
  function addAddressToWhitelist(address _operator)
    public
    onlyOwner
  {
    addRole(_operator, ROLE_WHITELISTED);
  }

  /**
   * @dev getter to determine if address is in whitelist
   */
  function whitelist(address _operator)
    public
    view
    returns (bool)
  {
    return hasRole(_operator, ROLE_WHITELISTED);
  }

  /**
   * @dev add addresses to the whitelist
   * @param _operators addresses
   * @return true if at least one address was added to the whitelist,
   * false if all addresses were already in the whitelist
   */
  function addAddressesToWhitelist(address[] memory _operators)
    public
    onlyOwner
  {
    for (uint256 i = 0; i < _operators.length; i++) {
      addAddressToWhitelist(_operators[i]);
    }
  }
    /**
   * @dev remove an address from the whitelist
   * @param _operator address
   * @return true if the address was removed from the whitelist,
   * false if the address wasn't in the whitelist in the first place
   */
  function removeAddressFromWhitelist(address _operator)
    public
    onlyOwner
  {
    removeRole(_operator, ROLE_WHITELISTED);
  }

  /**
   * @dev remove addresses from the whitelist
   * @param _operators addresses
   * @return true if at least one address was removed from the whitelist,
   * false if all addresses weren't in the whitelist in the first place
   */
  function removeAddressesFromWhitelist(address[] memory _operators)
    public
    onlyOwner
  {
    for (uint256 i = 0; i < _operators.length; i++) {
      removeAddressFromWhitelist(_operators[i]);
    }
  }

}

pragma solidity >=0.4.22 <0.6.0;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

/**
 *Submitted for verification at Etherscan.io on 2019-10-31
*/
pragma solidity ^0.5.11;
import './ownable.sol';
import './safemath.sol';
/**
 * @title -EV5.Win- v0.5.11
 * ╔═╗┌─┐┬ ┬┬─┐┌─┐┌─┐┌─┐  ┌─┐┌┐┌┌┬┐  ┬ ┬┬┌─┐┌┬┐┌─┐┌┬┐  ┌─┐┬─┐┌─┐  ┌┬┐┬ ┬┌─┐  ┌┐ ┌─┐┌─┐┌┬┐  ┬ ┬┌─┐┌─┐┬  ┌┬┐┬ ┬
 * ║  │ ││ │├┬┘├─┤│ ┬├┤   ├─┤│││ ││  ││││└─┐ │││ ││││  ├─┤├┬┘├┤    │ ├─┤├┤   ├┴┐├┤ └─┐ │   │││├┤ ├─┤│   │ ├─┤
 * ╚═╝└─┘└─┘┴└─┴ ┴└─┘└─┘  ┴ ┴┘└┘─┴┘  └┴┘┴└─┘─┴┘└─┘┴ ┴  ┴ ┴┴└─└─┘   ┴ ┴ ┴└─┘  └─┘└─┘└─┘ ┴   └┴┘└─┘┴ ┴┴─┘ ┴ ┴ ┴
 *
 * ==('-.==========(`-. ====================(`\ .-') /`===============.-') _====================================
 * _(  OO)      _(OO  )_                  `.( OO ),'              ( OO ) )
 * (,------. ,--(_/   ,. \.------.      ,--./  .--.    ,-.-')  ,--./ ,--,'
 *  |  .---' \   \   /(__/|   ___|      |      |  |    |  |OO) |   \ |  |\
 *  |  |      \   \ /   / |  '--.       |  |   |  |,   |  |  \ |    \|  | )
 * (|  '--.    \   '   /, `---.  '.     |  |.'.|  |_)  |  |(_/ |  .     |/
 *  |  .--'     \     /__).-   |  |     |         |   ,|  |_.' |  |\    |
 *  |  `---.     \   /    | `-'   / .-. |   ,'.   |  (_|  |    |  | \   | 
 *  `------'      `-'      `----''  `-' '--'   '--'    `--'    `--'  `--'          © New York Jerome Team Inc.
 * =============================================================================================================
*
*
╔═╗╦  ╦ ┬ ┬┬┌┐┌  ╔═╗┌┬┐┌─┐┬─┐┌┬┐┬┌┐┌┌─┐
║╣ ╚╗╔╝ │││││││  ╚═╗ │ ├─┤├┬┘ │ │││││ ┬
╚═╝ ╚╝ o└┴┘┴┘└┘  ╚═╝ ┴ ┴ ┴┴└─ ┴ ┴┘└┘└─┘
*/
contract Vendor {
    function getLevel(uint _value) external view returns(uint);
    function getLineLevel(uint _value) external view returns(uint);
    function getWithdrawRoundRo(uint _round) external pure returns (uint);
}
contract DB {
    function createUser1(address _addr, string memory _code, string memory _pCode) public;
    function createUser2(address _addr, uint _frozenCoin, uint _lastInTime) public;
    function setUserToNew(address _addr) public;
    function createWithdraw(address _addr, uint _amount, uint _ctime) public;
    function setRePlayInfo(address _addr, uint _type) public;
    function getWithdrawCoin(address _addr) public returns (uint);
    function updateCoinLevel(address _addr,uint _frozenCoin, uint _freeCoin, uint _level, uint _linelevel) public;
    function updateProfit(address _addr, uint _amount) public;
    function getCodeMapping(string memory _code) public view returns(address);
    function getUserInfo(address _addr) public view returns (uint, uint, uint, uint, uint, uint);
    function getUserOut(address _owner) public view returns (string memory,string memory, uint[12] memory uInfo);
    function getPlatforms() public view returns(uint,uint,uint,uint,uint,uint);
    function getIndexMapping(uint _uid) public view returns(address);
    function getWithdrawAccount(address _addr) public view returns (address);
    
    function settleIncrease(uint _start, uint _end) public;
    function settleNewProfit(uint _start, uint _end) public;
    function settleBonus(uint _start, uint _end, uint _onlyOne) public;
    function settleRecommend(uint _start, uint _end, uint _onlyOne) public;
}

contract Ev5 is Whitelist {
    string public EV5_NAME = "Ev5.win GameFather";
    //lib using list
    using SafeMath for *;

    //Loglist
    event InvestEvent(address indexed _addr, string _code, string _pCode, uint _value, uint time);
    event ReInEvent(address indexed _addr, uint _value, uint _value1, uint time);
    event TransferEvent(address indexed _from, address indexed _to, uint _value, uint time);

    //platform setting
    bool private _platformPower = true;
    //include other contract
    DB db;
    Vendor env;

    //base param setting
    uint ethWei = 1 ether;
    uint maxCoin = 30 ether;
    uint minSelf = 1;
    uint maxSelf = 5;
    uint withdrawRadix = 1;
    bool private reEntrancyMutex = false;
    address[5] private _addrs;  //_dAddr0,_envAddr1,feeAddr1,feeAddr2,feeAddr3
    uint[3] feeRo = [15,10,10]; //div(1000)

    //the content of contract is Beginning
    constructor (address _dAddr, address _envAddr) public {
        //address _dAddr = 0x1C74569c9f2228EBcfAF5147d3F4377be015d615;
        //address _envAddr = 0x4b3F56ad747872a87282360DBE2300E347090e57;
        _addrs = [0x9732D32F4517A0A238441EcA4E45C1584A832fE0, 0x484A88721bD0e0280faC74F6261F9f340555F785, 0x0e8b5fb9673091C5368316595f77c7E3CBe11Bc6, _dAddr, _envAddr];
    
        db = DB(_addrs[3]);
        env = Vendor(_addrs[4]);
    }

    function deposit() public payable {
    }

    /**
    * @dev prevents contracts from interacting with Ev5.win
    */
    modifier isOpen() {
        require(_platformPower == true,"platform is repairing or wait to starting!");
        _;
    }
    /**
    * @dev prevents contracts from interacting with Ev5.win
    */
    modifier isHuman() {
        address _addr = msg.sender;
        uint256 _codeLength;

        assembly {_codeLength := extcodesize(_addr)}
        require(_codeLength == 0, "sorry humans only");
        require(tx.origin == msg.sender, "sorry human only");
        _;
    }

    function invest(string memory _code, string memory _pCode)
        public
        payable
        isHuman()
    {
        require(msg.value == msg.value.div(ethWei).mul(ethWei), "Coin Must Integer");
        require(msg.value >= 1 * ethWei && msg.value <= maxCoin, "Coin Must Between 1 to maxCoin");

        uint lastInTime = now;
        (uint uid,uint frozenCoin,uint freeCoin,,uint grantTime,) = db.getUserInfo(msg.sender);
        if(uid == 0) {
            //the checking condition
            require(!compareStr(_code,"") && bytes(_code).length == 6, "invalid invite code");
            require(db.getCodeMapping(_code) == address(0), "code must different");
            address _parentAddr = db.getCodeMapping(_pCode);
            require(compareStr(_pCode, "000000") || _parentAddr != address(0), "Parent User not exist");
            require(_parentAddr != msg.sender, "Parent User Is Not Owner");
            
            db.createUser1(msg.sender, _code, _pCode);
        } else {
            require(frozenCoin.add(freeCoin).add(msg.value) <= maxCoin, "Max Coin is maxCoin ETH");
            //rechange lastInTime
            grantTime = grantTime.add(8 hours).div(1 days).mul(1 days);
            uint addDays = now.add(8 hours).sub(grantTime).div(1 days);
            if(addDays == 0){
                lastInTime = lastInTime.add(1 days);
            }
        }

        db.createUser2(msg.sender, msg.value, lastInTime);
        
        db.setUserToNew(msg.sender);
        sendFeeToAccount(msg.value);
        emit InvestEvent(msg.sender, _code, _pCode, msg.value, now);
    }
    
    function reViewFrozen(uint _frozen)
        public
        isHuman()
        isOpen
    {
        require(_frozen == _frozen.div(ethWei).mul(ethWei), "Coin Must Integer");
        require(_frozen >= 1 * ethWei && _frozen <= maxCoin, "Coin Must Between 1 to maxCoin");
        
        db.createUser2(msg.sender, _frozen, now);
        sendFeeToAccount(_frozen);
    }

    function rePlayInByWD(uint _type)
        public
        payable
        isHuman()
        isOpen
        returns(bool)
    {
        (,uint frozenCoin,uint freeCoin,,,uint lockedCoin) = db.getUserInfo(msg.sender);
        require(frozenCoin.add(freeCoin) <= maxCoin, "Max Coin is maxCoin ETH");

        uint rltCoin;
        //withdraw tennel
        if(_type == 1){
            uint wdCoin = db.getWithdrawCoin(msg.sender);
            if(wdCoin > 0) {
                require(wdCoin - lockedCoin > 0, "Nothing To Withdraw");
                bool success = false;
                (success,rltCoin) = isEnough(wdCoin);
                if(success == true && rltCoin > 0){
                    transferTo(db.getWithdrawAccount(msg.sender), rltCoin);
                    db.createWithdraw(msg.sender, rltCoin, now);
                }else{
                    setPlatformPower(false);
                    return false;
                }
            }
        }

        frozenCoin = frozenCoin.add(freeCoin).sub(rltCoin);
        db.updateCoinLevel(msg.sender, frozenCoin, 0 , env.getLevel(frozenCoin), env.getLineLevel(frozenCoin));
        db.setRePlayInfo(msg.sender, _type);
        
        sendFeeToAccount(frozenCoin);
        emit ReInEvent(msg.sender, frozenCoin, rltCoin, now);
        return true;
    }

    function sendAwardBySelf(uint _coin)
        public
        payable
        isHuman()
        isOpen
        returns(bool)
    {
        (, uint frozenCoin, uint freeCoin, uint profit,,) = db.getUserInfo(msg.sender);
        require(_coin.mul(ethWei) <= profit, "coin is not enough");
        _coin = (_coin == 0) ? profit : _coin.mul(ethWei);

        bool success = false;
        uint rltCoin = 0;
        (success,rltCoin) = isEnough(_coin);
        if(success == true){
            if(_coin < (ethWei.div(minSelf))){
                return false;
            } if(maxSelf > 0  && _coin > maxSelf.mul(ethWei)){
                _coin = maxSelf.mul(ethWei);
            } if(maxSelf == 0 && _coin > (frozenCoin.add(freeCoin)).mul(withdrawRadix)){
                _coin = (frozenCoin.add(freeCoin)).mul(withdrawRadix);
            }
            transferTo(db.getWithdrawAccount(msg.sender), _coin);
            db.updateProfit(msg.sender, _coin);
        }else{
            setPlatformPower(false);
            return false;
        }
        return true;
    }
    
    function initialization(uint _start, uint _end) external onlyOwner{
        for (uint i = _start; i <= _end; i++) {
            address addr = db.getIndexMapping(i);
            (,uint frozenCoin,,,,) = db.getUserInfo(addr);
            sendFeeToAccount(frozenCoin);
        }
    }
    function sendFeeToAccount(uint amount) public {//private
        require(!reEntrancyMutex);
        reEntrancyMutex = true;
            bool success = false;
            uint rltCoin;
            uint allFeeRo = feeRo[0].add(feeRo[1]).add(feeRo[2]);
            (success,rltCoin) = isEnough(amount.mul(allFeeRo).div(1000));
            if(success == true){
                address(uint160(_addrs[0])).transfer(rltCoin.mul(feeRo[0]).div(1000));
                address(uint160(_addrs[1])).transfer(rltCoin.mul(feeRo[1]).div(1000));
                address(uint160(_addrs[2])).transfer(rltCoin.mul(feeRo[2]).div(1000));
            }
        reEntrancyMutex = false;
	}
	
	function isEnough(uint _coin)
        private
        view
        returns (bool,uint)
    {
        (uint trustCoin, uint lockedCoin,,,,) = db.getPlatforms();
        uint balance = address(this).balance;
        uint needCoin = _coin.add(trustCoin).add(lockedCoin); 
        if(needCoin >= balance){
            return (false, balance);
        }else{
            return (true, _coin);
        }
    }

    function transferTo(address _addr,uint _val) private {
        require(_addr != address(0));
        require(!reEntrancyMutex);
        reEntrancyMutex = true;
            address(uint160(_addr)).transfer(_val);
            emit TransferEvent(address(this), _addr, _val, now);
        reEntrancyMutex = false;
    }

	function transferTo2(address _addr,uint _val)
        public
        payable
        onlyOwner
    {
        require(_addr != address(0));
        require(!reEntrancyMutex);
        reEntrancyMutex = true;
            address(uint160(_addr)).transfer(_val);
            emit TransferEvent(address(this), _addr, _val, now);
        reEntrancyMutex = false;
    }

    function settleIncrease(uint _start, uint _end)
        public
        onlyIfWhitelisted
    {
        db.settleIncrease(_start, _end);
    }
    
    function settleNewProfit(uint _start, uint _end)
        public
        onlyIfWhitelisted
    {
        db.settleNewProfit(_start, _end);
    }
    
	function settleBonus(uint _start, uint _end, uint _onlyOne)
        public
        onlyIfWhitelisted
    {
        db.settleBonus(_start, _end, _onlyOne);
    }

    function settleRecommend(uint _start, uint _end, uint _onlyOne)
        public
        onlyIfWhitelisted
    {
        db.settleRecommend(_start, _end, _onlyOne);
    }

   function getUserByCode(string memory _code) public view returns (bool){
        if (db.getCodeMapping(_code) != address(0)){
            return true;
        }
        return false;
    }
    function getUser(address _owner) external view isOpen returns(string memory code,string memory pcode,uint[12] memory data){
        (uint uid,,,,,) = db.getUserInfo(_owner);
        if(uid > 0){
            (code, pcode, data) = db.getUserOut(_owner);
            return (code, pcode, data);
        }
        return ('', '', [uint(0),0,0,0,0,0,0,0,0,0,0,0]);
    }
    function getPlatforms() external view isOpen returns(uint,uint,uint,uint,uint,uint){
        return (db.getPlatforms());
    }

    function getPlatformA() external view onlyOwner returns(bool, address, address, address, address,uint,uint,uint,uint,uint[3] memory,uint){
        return (_platformPower, _addrs[0], _addrs[1], _addrs[2], _addrs[4],maxCoin,minSelf,maxSelf,withdrawRadix,feeRo, address(this).balance);
    }
    function setPlatformPower(bool r) public onlyOwner{
        _platformPower = r;
    }
    function setting(uint _maxCoin, uint _minSelf, uint _maxSelf, uint _withdrawRadix) public onlyOwner {
        maxCoin = _maxCoin;
        minSelf = _minSelf;
        maxSelf = _maxSelf;
        withdrawRadix = _withdrawRadix;
    }
    function changeFeeRo(uint _index, uint _ro) public onlyOwner {
        feeRo[_index] = _ro;
    }
    function setNewAddr(uint _addrId, address _addr) external onlyOwner{
        _addrs[_addrId] = _addr;
        if(_addrId == 3){
            db = DB(_addr);
        } if(_addrId == 4){
            env = Vendor(_addr);
        }
    }
}

pragma solidity ^0.5.11;

contract Ownable {
    address private _owner;

    event OwnerTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () internal {
        _owner = msg.sender;
        emit OwnerTransferred(address(0), _owner);
    }
    function owner() public view returns(address){
        return _owner;
    }
    function isOwner() public view returns(bool){
        return msg.sender == _owner;
    }
    modifier onlyOwner() {
        require(msg.sender == _owner, "it is not called by the owner");
        _;
    }
    function changeOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0),'');
        emit OwnerTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    function compareStr(string memory _str1,string memory _str2) internal pure returns(bool) {
        bool compareResult = false;
        if(keccak256(abi.encodePacked(_str1)) == keccak256(abi.encodePacked(_str2))) {
            compareResult = true;
        }
        return compareResult;
    }
}

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
  struct Role {
    mapping (address => bool) bearer;
  }

  /**
   * @dev give an address access to this role
   */
  function add(Role storage _role, address _addr)
    internal
  {
     require(!has(_role, _addr), "addr already has role");
      _role.bearer[_addr] = true;
  }

  /**
   * @dev remove an address' access to this role
   */
  function remove(Role storage _role, address _addr)
    internal
  {
      require(has(_role, _addr), "addr do not have role");
      _role.bearer[_addr] = false;
  }

  /**
   * @dev check if an address has this role
   * // reverts
   */
  function check(Role storage _role, address _addr)
    internal
    view
  {
    require(has(_role, _addr),'');
  }

  /**
   * @dev check if an address has this role
   * @return bool
   */
  function has(Role storage _role, address _addr)
    internal
    view
    returns (bool)
  {
      require(_addr != address(0), "not the zero address");
      return _role.bearer[_addr];
  }
}

/**
 * @title RBAC (Role-Based Access Control)
 * @author Matt Condon (@Shrugs)
 * @dev Stores and provides setters and getters for roles and addresses.
 * Supports unlimited numbers of roles and addresses.
 * See //contracts/mocks/RBACMock.sol for an example of usage.
 * This RBAC method uses strings to key roles. It may be beneficial
 * for you to write your own implementation of this interface using Enums or similar.
 */
contract RBAC {
  using Roles for Roles.Role;

  mapping (string => Roles.Role) private roles;

  event RoleAdded(address indexed operator, string role);
  event RoleRemoved(address indexed operator, string role);

  /**
   * @dev reverts if addr does not have role
   * @param _operator address
   * @param _role the name of the role
   * // reverts
   */
  function checkRole(address _operator, string memory _role)
    public
    view
  {
    roles[_role].check(_operator);
  }

  /**
   * @dev determine if addr has role
   * @param _operator address
   * @param _role the name of the role
   * @return bool
   */
    function hasRole(address _operator, string memory _role)
    public
    view
    returns (bool)
  {
    return roles[_role].has(_operator);
  }

  /**
   * @dev add a role to an address
   * @param _operator address
   * @param _role the name of the role
   */
  function addRole(address _operator, string memory _role)
    internal
  {
    roles[_role].add(_operator);
    emit RoleAdded(_operator, _role);
  }

  /**
   * @dev remove a role from an address
   * @param _operator address
   * @param _role the name of the role
   */
  function removeRole(address _operator, string memory _role)
    internal
  {
    roles[_role].remove(_operator);
    emit RoleRemoved(_operator, _role);
  }

  /**
   * @dev modifier to scope access to a single role (uses msg.sender as addr)
   * @param _role the name of the role
   * // reverts
   */
  modifier onlyRole(string memory _role)
  {
    checkRole(msg.sender, _role);
    _;
  }
}


/**
 * @title Whitelist
 * @dev The Whitelist contract has a whitelist of addresses, and provides basic authorization control functions.
 * This simplifies the implementation of "user permissions".
 */
contract Whitelist is Ownable, RBAC {
  string public constant ROLE_WHITELISTED = "whitelist";

  /**
   * @dev Throws if operator is not whitelisted.
   */
  modifier onlyIfWhitelisted() {
    require(hasRole(msg.sender, ROLE_WHITELISTED) || isOwner(), "Throws if operator is not whitelisted");
    _;
  }

  /**
   * @dev add an address to the whitelist
   * @param _operator address
   * @return true if the address was added to the whitelist, false if the address was already in the whitelist
   */
  function addAddressToWhitelist(address _operator)
    public
    onlyOwner
  {
    addRole(_operator, ROLE_WHITELISTED);
  }

  /**
   * @dev getter to determine if address is in whitelist
   */
  function whitelist(address _operator)
    public
    view
    returns (bool)
  {
    return hasRole(_operator, ROLE_WHITELISTED);
  }

  /**
   * @dev add addresses to the whitelist
   * @param _operators addresses
   * @return true if at least one address was added to the whitelist,
   * false if all addresses were already in the whitelist
   */
  function addAddressesToWhitelist(address[] memory _operators)
    public
    onlyOwner
  {
    for (uint256 i = 0; i < _operators.length; i++) {
      addAddressToWhitelist(_operators[i]);
    }
  }
    /**
   * @dev remove an address from the whitelist
   * @param _operator address
   * @return true if the address was removed from the whitelist,
   * false if the address wasn't in the whitelist in the first place
   */
  function removeAddressFromWhitelist(address _operator)
    public
    onlyOwner
  {
    removeRole(_operator, ROLE_WHITELISTED);
  }

  /**
   * @dev remove addresses from the whitelist
   * @param _operators addresses
   * @return true if at least one address was removed from the whitelist,
   * false if all addresses weren't in the whitelist in the first place
   */
  function removeAddressesFromWhitelist(address[] memory _operators)
    public
    onlyOwner
  {
    for (uint256 i = 0; i < _operators.length; i++) {
      removeAddressFromWhitelist(_operators[i]);
    }
  }

}

pragma solidity >=0.4.22 <0.6.0;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

