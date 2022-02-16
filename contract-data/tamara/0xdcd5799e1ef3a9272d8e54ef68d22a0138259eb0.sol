pragma solidity ^0.5.2;

import "./IERC20.sol";
import "./SafeMath.sol";

/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * https://eips.ethereum.org/EIPS/eip-20
 * Originally based on code by FirstBlood:
 * https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 *
 * This implementation emits additional Approval events, allowing applications to reconstruct the allowance status for
 * all accounts just by listening to said events. Note that this isn't required by the specification, and other
 * compliant implementations may not do it.
 */
contract ERC20 is IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowed;

    uint256 private _totalSupply;

    /**
     * @dev Total number of tokens in existence
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param owner The address to query the balance of.
     * @return A uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowed[owner][spender];
    }

    /**
     * @dev Transfer token to a specified address
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another.
     * Note that while this function emits an Approval event, this is not required as per the specification,
     * and other compliant implementations may not emit the event.
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        _transfer(from, to, value);
        _approve(from, msg.sender, _allowed[from][msg.sender].sub(value));
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     * approve should be called when _allowed[msg.sender][spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowed[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     * approve should be called when _allowed[msg.sender][spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowed[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    /**
     * @dev Transfer token for a specified addresses
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }

    /**
     * @dev Internal function that mints an amount of the token and assigns it to
     * an account. This encapsulates the modification of balances such that the
     * proper events are emitted.
     * @param account The account that will receive the created tokens.
     * @param value The amount that will be created.
     */
    function _mint(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.add(value);
        _balances[account] = _balances[account].add(value);
        emit Transfer(address(0), account, value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account.
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Approve an address to spend another addresses' tokens.
     * @param owner The address that owns the tokens.
     * @param spender The address that will spend the tokens.
     * @param value The number of tokens that can be spent.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        require(spender != address(0));
        require(owner != address(0));

        _allowed[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account, deducting from the sender's allowance for said account. Uses the
     * internal burn function.
     * Emits an Approval event (reflecting the reduced allowance).
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burnFrom(address account, uint256 value) internal {
        _burn(account, value);
        _approve(account, msg.sender, _allowed[account][msg.sender].sub(value));
    }
}

pragma solidity ^0.5.2;

import "./ERC20.sol";

/**
 * @title Burnable Token
 * @dev Token that can be irreversibly burned (destroyed).
 */
contract ERC20Burnable is ERC20 {
    /**
     * @dev Burns a specific amount of tokens.
     * @param value The amount of token to be burned.
     */
    function burn(uint256 value) public {
        _burn(msg.sender, value);
    }

    /**
     * @dev Burns a specific amount of tokens from the target address and decrements allowance
     * @param from address The account whose tokens will be burned.
     * @param value uint256 The amount of token to be burned.
     */
    function burnFrom(address from, uint256 value) public {
        _burnFrom(from, value);
    }
}

pragma solidity ^0.5.2;

import "./ERC20Mintable.sol";

/**
 * @title Capped token
 * @dev Mintable token with a token cap.
 */
contract ERC20Capped is ERC20Mintable {
    uint256 private _cap;

    constructor (uint256 cap) public {
        require(cap > 0);
        _cap = cap;
    }

    /**
     * @return the cap for the token minting.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }

    function _mint(address account, uint256 value) internal {
        require(totalSupply().add(value) <= _cap);
        super._mint(account, value);
    }
}

pragma solidity ^0.5.2;

import "./IERC20.sol";

/**
 * @title ERC20Detailed token
 * @dev The decimals are only for visualization purposes.
 * All the operations are done using the smallest and indivisible token unit,
 * just as on Ethereum all the operations are done in wei.
 */
contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor (string memory name, string memory symbol, uint8 decimals) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }

    /**
     * @return the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @return the symbol of the token.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @return the number of decimals of the token.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

pragma solidity ^0.5.2;

import "./ERC20.sol";
import "./MinterRole.sol";

/**
 * @title ERC20Mintable
 * @dev ERC20 minting logic
 */
contract ERC20Mintable is ERC20, MinterRole {
    /**
     * @dev Function to mint tokens
     * @param to The address that will receive the minted tokens.
     * @param value The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mint(address to, uint256 value) public onlyMinter returns (bool) {
        _mint(to, value);
        return true;
    }
}

pragma solidity ^0.5.2;

/**
 * @title ERC20 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-20
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity ^0.5.2;

import "./Roles.sol";

contract MinterRole {
    using Roles for Roles.Role;

    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);

    Roles.Role private _minters;

    constructor () internal {
        _addMinter(msg.sender);
    }

    modifier onlyMinter() {
        require(isMinter(msg.sender));
        _;
    }

    function isMinter(address account) public view returns (bool) {
        return _minters.has(account);
    }

    function addMinter(address account) public onlyMinter {
        _addMinter(account);
    }

    function renounceMinter() public {
        _removeMinter(msg.sender);
    }

    function _addMinter(address account) internal {
        _minters.add(account);
        emit MinterAdded(account);
    }

    function _removeMinter(address account) internal {
        _minters.remove(account);
        emit MinterRemoved(account);
    }
}

pragma solidity ^0.5.2;

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev give an account access to this role
     */
    function add(Role storage role, address account) internal {
        require(account != address(0));
        require(!has(role, account));

        role.bearer[account] = true;
    }

    /**
     * @dev remove an account's access to this role
     */
    function remove(Role storage role, address account) internal {
        require(account != address(0));
        require(has(role, account));

        role.bearer[account] = false;
    }

    /**
     * @dev check if an account has this role
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0));
        return role.bearer[account];
    }
}

pragma solidity ^0.5.2;

/**
 * @title SafeMath
 * @dev Unsigned math operations with safety checks that revert on error
 */
library SafeMath {
    /**
     * @dev Multiplies two unsigned integers, reverts on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
     * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Adds two unsigned integers, reverts on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
     * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
     * reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

pragma solidity >=0.4.21 <0.6.0;

import "./ERC20.sol";
import "./ERC20Detailed.sol";
import "./ERC20Capped.sol";
import "./ERC20Burnable.sol";

contract SFtoken is ERC20, ERC20Detailed, ERC20Burnable {

    event CreateTokenSuccess(address owner, uint256 balance);

    uint256 amount = 2100000000;
    constructor(
    )
    ERC20Burnable()
    ERC20Detailed("ERM", "ERM", 18)
    ERC20()
    public
    {
        _mint(msg.sender, amount * (10 ** 18));
        emit CreateTokenSuccess(msg.sender, balanceOf(msg.sender));
    }
}

pragma solidity >=0.4.21 <0.6.0;

import "./SFtoken.sol";

contract UtilFairWin {
    uint ethWei = 1 ether;

    function getLevel(uint value) public view returns(uint) {
        if (value >= 1*ethWei && value <= 5*ethWei) {
            return 1;
        }
        if (value >= 6*ethWei && value <= 10*ethWei) {
            return 2;
        }
        if (value >= 11*ethWei && value <= 15*ethWei) {
            return 3;
        }
        return 0;
    }

    function getLineLevel(uint value) public view returns(uint) {
        if (value >= 1*ethWei && value <= 5*ethWei) {
            return 1;
        }
        if (value >= 6*ethWei && value <= 10*ethWei) {
            return 2;
        }
        if (value >= 11*ethWei) {
            return 3;
        }
        return 0;
    }

    function getScByLevel(uint level) public pure returns(uint) {
        if (level == 1) {
            return 5;
        }
        if (level == 2) {
            return 7;
        }
        if (level == 3) {
            return 10;
        }
        return 0;
    }

    function getFireScByLevel(uint level) public pure returns(uint) {
        if (level == 1) {
            return 10;
        }
        if (level == 2) {
            return 10;
        }
        if (level == 3) {
            return 10;
        }
        return 0;
    }

    function getRecommendScaleByLevelAndTim(uint level,uint times) public pure returns(uint){
        if (level == 1 && times == 1) {
            return 50;
        }
        if (level == 2 && times == 1) {
            return 70;
        }
        if (level == 2 && times == 2) {
            return 50;
        }
        if (level == 3) {
            if(times == 1){
                return 100;
            }
            if (times == 2) {
                return 70;
            }
            if (times == 3) {
                return 50;
            }
            if (times >= 4 && times <= 10) {
                return 10;
            }
            if (times >= 11 && times <= 20) {
                return 5;
            }
            if (times >= 21) {
                return 1;
            }
        }
        return 0;
    }

    function compareStr(string memory _str, string memory str) public pure returns(bool) {
        if (keccak256(abi.encodePacked(_str)) == keccak256(abi.encodePacked(str))) {
            return true;
        }
        return false;
    }
}

contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor() internal {}
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


contract WhitelistAdminRole is Context, Ownable {
    using Roles for Roles.Role;

    event WhitelistAdminAdded(address indexed account);
    event WhitelistAdminRemoved(address indexed account);

    Roles.Role private _whitelistAdmins;

    constructor () internal {
        _addWhitelistAdmin(_msgSender());
    }

    modifier onlyWhitelistAdmin() {
        require(isWhitelistAdmin(_msgSender()) || isOwner(), "WhitelistAdminRole: caller does not have the WhitelistAdmin role");
        _;
    }

    function isWhitelistAdmin(address account) public view returns (bool) {
        return _whitelistAdmins.has(account);
    }

    function addWhitelistAdmin(address account) public onlyWhitelistAdmin {
        _addWhitelistAdmin(account);
    }

    function removeWhitelistAdmin(address account) public onlyOwner {
        _whitelistAdmins.remove(account);
        emit WhitelistAdminRemoved(account);
    }

    function renounceWhitelistAdmin() public {
        _removeWhitelistAdmin(_msgSender());
    }

    function _addWhitelistAdmin(address account) internal {
        _whitelistAdmins.add(account);
        emit WhitelistAdminAdded(account);
    }

    function _removeWhitelistAdmin(address account) internal {
        _whitelistAdmins.remove(account);
        emit WhitelistAdminRemoved(account);
    }
}

contract SuperFair is UtilFairWin, WhitelistAdminRole {

    using SafeMath for *;

    string constant private name = "SuperFair Official";

    uint ethWei = 1 ether;

    struct User{
        uint id;
        address userAddress;
        string inviteCode;
        string referrer;
        uint staticLevel;
        uint dynamicLevel;
        uint allInvest;
        uint freezeAmount;
        uint unlockAmount;
        uint allStaticAmount;
        uint allDynamicAmount;
        uint hisStaticAmount;
        uint hisDynamicAmount;
        Invest[] invests;
        uint staticFlag;
    }

    struct UserGlobal {
        uint id;
        address userAddress;
        string inviteCode;
        string referrer;
    }

    struct Invest{
        address userAddress;
        uint investAmount;
        uint investTime;
        uint times;
        uint day;
    }

    struct Order {
        address user;
        uint256 amount;
        string inviteCode;
        string referrer;
        bool execute;
    }

    struct WaitInfo {
        uint256 totalAmount;
        bool isWait;
        uint256 time;
        uint256[] seq;
    }

    string constant systemCode = "99999999";
    uint coefficient = 10;
    uint profit = 100;
    uint startTime;
    uint investCount = 0;
    mapping(uint => uint) rInvestCount;
    uint investMoney = 0;
    mapping(uint => uint) rInvestMoney;
    uint uid = 0;
    uint rid = 1;
    uint period = 3 days;

    uint256 public timeInterval = 1440;

    mapping (uint => mapping(address => User)) userRoundMapping;
    mapping(address => UserGlobal) userMapping;
    mapping (string => address) addressMapping;
    mapping (string => address) codeRegister;
    mapping (uint => address) public indexMapping;
    mapping (uint => mapping(uint256 => Order)) public waitOrder;
    mapping (uint => mapping(address => WaitInfo)) public waitInfo;
    uint32  public ratio = 1000;     // eth to erc20 token ratio
    mapping (uint => mapping(address => uint256[2])) public extraInfo;

    address payable public eggAddress = 0x9ddc752e3D59Cd16e4360743C6eB9608d39e6119; //彩蛋地址 ，玩家所有收益提现的10%
    address payable public fivePercentWallet = 0x76594F0FA263Ac33aa28E3AdbFebBcBaf7Db76A9; //5%钱包
    address payable public twoPercentWallet =  0x4200DBbda245be2b04a0a82eB1e08C6580D81C9b; //2%钱包
    address payable public threePercentWallet = 0x07BeEec61D7B28177521bFDd0fdA5A07d992e51F; //3%钱包

    SFtoken internal SFInstance;

    bool public waitLine = true;
    uint256 public numOrder = 1;
    uint256 public startNum = 1;

    modifier isHuman() {
        address addr = msg.sender;
        uint codeLength;

        assembly {codeLength := extcodesize(addr)}
        require(codeLength == 0, "sorry humans only");
        require(tx.origin == msg.sender, "sorry, human only");
        _;
    }

    event LogInvestIn(address indexed who, uint indexed uid, uint amount, uint time, string inviteCode, string referrer);
    event LogWithdrawProfit(address indexed who, uint indexed uid, uint amount, uint time);
    event LogRedeem(address indexed who, uint indexed uid, uint amount, uint now);

    constructor (address _erc20Address) public {
        SFInstance = SFtoken(_erc20Address);
    }

    function () external payable {
    }

    function calculateToken(address user, uint256 ethAmount)
    internal
    {
        SFInstance.transfer(user, ethAmount.mul(ratio));
    }


    function activeGame(uint time) external onlyWhitelistAdmin
    {
        require(time > now, "invalid game start time");
        startTime = time;
    }

    function modifyProfit(uint p) external onlyWhitelistAdmin
    {
        profit = p;
    }


    function setCoefficient(uint coeff) external onlyWhitelistAdmin
    {
        require(coeff > 0, "invalid coeff");
        coefficient = coeff;
    }

    function setRatio(uint32 r) external onlyWhitelistAdmin
    {
        ratio = r;
    }

    function setWaitLine (bool wait) external onlyWhitelistAdmin
    {
        waitLine = wait;
    }

    function modifyStartNum(uint256 number) external onlyWhitelistAdmin
    {
        startNum = number;
    }

    function executeLine(uint256 end) external onlyWhitelistAdmin
    {
        require(waitLine, "need wait line");
        for(uint256 i = startNum; i < startNum + end; i++) {
            require(waitOrder[rid][i].user != address(0), "user address can not be 0X");
            investIn(waitOrder[rid][i].user, waitOrder[rid][i].amount, waitOrder[rid][i].inviteCode, waitOrder[rid][i].referrer);
            waitOrder[rid][i].execute = true;
            waitInfo[rid][waitOrder[rid][i].user].isWait = false;
        }
        startNum += end;
    }

    function gameStart() public view returns(bool) {
        return startTime != 0 && now > startTime;
    }

    function waitInvest(string memory inviteCode, string memory referrer)
    public
    isHuman()
    payable
    {
        require(gameStart(), "game not start");
        require(msg.value >= 1*ethWei && msg.value <= 15*ethWei, "between 1 and 15");
        require(msg.value == msg.value.div(ethWei).mul(ethWei), "invalid msg value");
        require(codeRegister[inviteCode] == address(0) || codeRegister[inviteCode] == msg.sender, "can not repeat invite");

        UserGlobal storage userGlobal = userMapping[msg.sender];
        if (userGlobal.id == 0) {
            require(!compareStr(inviteCode, ""), "empty invite code");
            address referrerAddr = getUserAddressByCode(referrer);
            require(uint(referrerAddr) != 0, "referer not exist");
            require(referrerAddr != msg.sender, "referrer can't be self");
            require(!isUsed(inviteCode), "invite code is used");
        }

        Order storage order = waitOrder[rid][numOrder];
        order.user = msg.sender;
        order.amount = msg.value;
        order.inviteCode = inviteCode;
        order.referrer = referrer;

        WaitInfo storage info = waitInfo[rid][msg.sender];
        info.totalAmount += msg.value;
        require(info.totalAmount <= 15 ether, "eth amount between 1 and 15");
        info.isWait = true;
        info.seq.push(numOrder);
        info.time = now;

        codeRegister[inviteCode] = msg.sender;

        if(!waitLine){
            if(numOrder!=1){
                require(waitOrder[rid][numOrder - 1].execute, "last order not execute");
            }
            investIn(order.user, order.amount, order.inviteCode, order.referrer);
            order.execute = true;
            info.isWait = false;
            startNum += 1;
        }

        numOrder += 1;
    }

    function investIn(address usera, uint256 amount, string memory inviteCode, string memory referrer)
    private
    {
        UserGlobal storage userGlobal = userMapping[usera];
        if (userGlobal.id == 0) {
            require(!compareStr(inviteCode, ""), "empty invite code");
            address referrerAddr = getUserAddressByCode(referrer);
            extraInfo[rid][referrerAddr][1] += 1;
            require(uint(referrerAddr) != 0, "referer not exist");
            require(referrerAddr != usera, "referrer can't be self");

            require(!isUsed(inviteCode), "invite code is used");

            registerUser(usera, inviteCode, referrer);
        }

        User storage user = userRoundMapping[rid][usera];
        if (uint(user.userAddress) != 0) {
            require(user.freezeAmount.add(amount) <= 15*ethWei, "can not beyond 15 eth");
            user.allInvest = user.allInvest.add(amount);
            user.freezeAmount = user.freezeAmount.add(amount);
            user.staticLevel = getLevel(user.freezeAmount);
            user.dynamicLevel = getLineLevel(user.freezeAmount.add(user.unlockAmount));
        } else {
            user.id = userGlobal.id;
            user.userAddress = usera;
            user.freezeAmount = amount;
            user.staticLevel = getLevel(amount);
            user.allInvest = amount;
            user.dynamicLevel = getLineLevel(amount);
            user.inviteCode = userGlobal.inviteCode;
            user.referrer = userGlobal.referrer;
        }

        Invest memory invest = Invest(usera, amount, now, 0, 0);
        user.invests.push(invest);

        investCount = investCount.add(1);
        investMoney = investMoney.add(amount);
        rInvestCount[rid] = rInvestCount[rid].add(1);
        rInvestMoney[rid] = rInvestMoney[rid].add(amount);

        calculateToken(usera, amount);

        sendMoneyToUser(fivePercentWallet, amount.mul(5).div(100));  // 5%钱包
        sendMoneyToUser(twoPercentWallet, amount.mul(2).div(100));   // 2%钱包
        sendMoneyToUser(threePercentWallet, amount.mul(3).div(100)); // 3%钱包

    emit LogInvestIn(usera, userGlobal.id, amount, now, userGlobal.inviteCode, userGlobal.referrer);
    }

    function withdrawProfit()
    public
    isHuman()
    {
        require(gameStart(), "game not start");
        User storage user = userRoundMapping[rid][msg.sender];
        uint sendMoney = user.allStaticAmount.add(user.allDynamicAmount);

        bool isEnough = false;
        uint resultMoney = 0;
        (isEnough, resultMoney) = isEnoughBalance(sendMoney);
        if (!isEnough) {
            endRound();
        }

        uint256[2] storage extra = extraInfo[rid][msg.sender];
        extra[0] += resultMoney;
        if(extra[0] >= user.allInvest) {
            if(user.allInvest > (extra[0] - resultMoney)){
                resultMoney = user.allInvest - (extra[0] - resultMoney);
            } else {
                resultMoney = 0;
            }
        }

        if (resultMoney > 0) {
            sendMoneyToUser(eggAddress, resultMoney.mul(10).div(100));
            sendMoneyToUser(msg.sender, resultMoney.mul(90).div(100));
            user.allStaticAmount = 0;
            user.allDynamicAmount = 0;
            emit LogWithdrawProfit(msg.sender, user.id, resultMoney, now);
        }

    }

    function isEnoughBalance(uint sendMoney) private view returns (bool, uint){
        if (sendMoney >= address(this).balance) {
            return (false, address(this).balance);
        } else {
            return (true, sendMoney);
        }
    }

    function sendMoneyToUser(address payable userAddress, uint money) private {
        userAddress.transfer(money);
    }

    function calStaticProfit(address userAddr) external onlyWhitelistAdmin returns(uint)
    {
        return calStaticProfitInner(userAddr);
    }

    function calStaticProfitInner(address userAddr) private returns(uint)
    {
        User storage user = userRoundMapping[rid][userAddr];
        if (user.id == 0) {
            return 0;
        }

        uint scale = getScByLevel(user.staticLevel);
        uint allStatic = 0;

        if(user.hisStaticAmount.add(user.hisDynamicAmount) >=  user.allInvest){
            user.freezeAmount = 0;
            user.unlockAmount = user.allInvest;
            user.staticLevel = getLevel(user.freezeAmount);
            user.staticFlag = user.invests.length;
        } else {
            for (uint i = user.staticFlag; i < user.invests.length; i++) {
                Invest storage invest = user.invests[i];
                if(invest.day < 100) {
                    uint staticGaps = now.sub(invest.investTime).div(timeInterval.mul(1 minutes)); //TODO
                    uint unlockDay = now.sub(invest.investTime).div(timeInterval.mul(1 minutes)); // TODO
                    if (unlockDay>100) {
                        unlockDay = 100;
                        user.staticFlag++;
                    }

                    if(staticGaps > 100){
                        staticGaps = 100;
                    }
                    if (staticGaps > invest.times) {
                        allStatic += staticGaps.sub(invest.times).mul(scale).mul(invest.investAmount).div(1000);
                        invest.times = staticGaps;
                    }

                    user.freezeAmount = user.freezeAmount.sub(invest.investAmount.div(100).mul(unlockDay - invest.day).mul(profit).div(100));
                    user.unlockAmount = user.unlockAmount.add(invest.investAmount.div(100).mul(unlockDay - invest.day).mul(profit).div(100));
                    invest.day = unlockDay;
                }
            }
        }

        allStatic = allStatic.mul(coefficient).div(10);
        user.allStaticAmount = user.allStaticAmount.add(allStatic);
        user.hisStaticAmount = user.hisStaticAmount.add(allStatic);
        userRoundMapping[rid][userAddr] = user;
        return user.allStaticAmount;
    }

    function calDynamicProfit(uint start, uint end) external onlyWhitelistAdmin {
        for (uint i = start; i <= end; i++) {
            address userAddr = indexMapping[i];
            User memory user = userRoundMapping[rid][userAddr];

            if(user.allInvest > 0) {
                calStaticProfitInner(userAddr);
            }

            if (user.freezeAmount > 0) {
                uint scale = getScByLevel(user.staticLevel);
//                address reuser = addressMapping[user.referrer];
//                User memory reUser = userRoundMapping[rid][reuser];
//                if (reUser.freezeAmount > 0){
                    calUserDynamicProfit(user.referrer, user.allInvest, scale);
//                }
            }
        }
    }

    function registerUserInfo(address user, string calldata inviteCode, string calldata referrer) external onlyOwner {
        registerUser(user, inviteCode, referrer);
    }

    function calUserDynamicProfit(string memory referrer, uint money, uint shareSc) private {
        string memory tmpReferrer = referrer;

        for (uint i = 1; i <= 30; i++) {
            if (compareStr(tmpReferrer, "")) {
                break;
            }
            address tmpUserAddr = addressMapping[tmpReferrer];
            User storage calUser = userRoundMapping[rid][tmpUserAddr];

            if (calUser.freezeAmount <= 0){
                tmpReferrer = calUser.referrer;
                continue;
            }

            uint fireSc = getFireScByLevel(calUser.staticLevel);
            uint recommendSc = getRecommendScaleByLevelAndTim(calUser.dynamicLevel, i);
            uint moneyResult = 0;
            if (money <= calUser.freezeAmount.add(calUser.unlockAmount)) {
                moneyResult = money;
            } else {
                moneyResult = calUser.freezeAmount.add(calUser.unlockAmount);
            }

            if (recommendSc != 0) {
                uint tmpDynamicAmount = moneyResult.mul(shareSc).mul(fireSc).mul(recommendSc);
                tmpDynamicAmount = tmpDynamicAmount.div(1000).div(10).div(100);

                tmpDynamicAmount = tmpDynamicAmount.mul(coefficient).div(10);
                calUser.allDynamicAmount = calUser.allDynamicAmount.add(tmpDynamicAmount);
                calUser.hisDynamicAmount = calUser.hisDynamicAmount.add(tmpDynamicAmount);
            }

            tmpReferrer = calUser.referrer;
        }
    }

    function redeem()
    public
    isHuman()
    {
        withdrawProfit();
        require(gameStart(), "game not start");
        User storage user = userRoundMapping[rid][msg.sender];
        require(user.id > 0, "user not exist");

        calStaticProfitInner(msg.sender);

        uint sendMoney = user.unlockAmount;

        bool isEnough = false;
        uint resultMoney = 0;

        (isEnough, resultMoney) = isEnoughBalance(sendMoney);

        if (!isEnough) {
            endRound();
        }

        if (resultMoney > 0) {
            require(resultMoney <= user.allInvest,"redeem money can not be 0");
            sendMoneyToUser(msg.sender, resultMoney); // 游戏结束
            delete waitInfo[rid][msg.sender];

            user.staticLevel = 0;
            user.dynamicLevel = 0;
            user.allInvest = 0;
            user.freezeAmount = 0;
            user.unlockAmount = 0;
            user.allStaticAmount = 0;
            user.allDynamicAmount = 0;
            user.hisStaticAmount = 0;
            user.hisDynamicAmount = 0;
            user.staticFlag = 0;
            user.invests.length = 0;

            extraInfo[rid][msg.sender][0] = 0;

            emit LogRedeem(msg.sender, user.id, resultMoney, now);
        }
    }

    function endRound() private {
        rid++;
        startTime = now.add(period).div(1 days).mul(1 days);
        coefficient = 10;
    }

    function isUsed(string memory code) public view returns(bool) {
        address user = getUserAddressByCode(code);
        return uint(user) != 0;
    }

    function getUserAddressByCode(string memory code) public view returns(address) {
        return addressMapping[code];
    }

    function getGameInfo() public isHuman() view returns(uint, uint, uint, uint, uint, uint, uint, uint) {
        return (
        rid,
        uid,
        startTime,
        investCount,
        investMoney,
        rInvestCount[rid],
        rInvestMoney[rid],
        coefficient
        );
    }

    function getUserInfo(address user, uint roundId) public isHuman() view returns(
        uint[11] memory ct, string memory inviteCode, string memory referrer
    ) {

        if(roundId == 0){
            roundId = rid;
        }

        User memory userInfo = userRoundMapping[roundId][user];

        ct[0] = userInfo.id;
        ct[1] = userInfo.staticLevel;
        ct[2] = userInfo.dynamicLevel;
        ct[3] = userInfo.allInvest;
        ct[4] = userInfo.freezeAmount;
        ct[5] = userInfo.unlockAmount;
        ct[6] = userInfo.allStaticAmount;
        ct[7] = userInfo.allDynamicAmount;
        ct[8] = userInfo.hisStaticAmount;
        ct[9] = userInfo.hisDynamicAmount;
        ct[10] = extraInfo[rid][user][1];

        inviteCode = userInfo.inviteCode;
        referrer = userInfo.referrer;

        return (
        ct,
        inviteCode,
        referrer
        );
    }

    function getUserById(uint id) public view returns(address){
        return indexMapping[id];
    }

    function getWaitInfo(address user) public view returns (uint256 totalAmount, bool isWait, uint256 time, uint256[]  memory seq, bool wait) {
        totalAmount = waitInfo[rid][user].totalAmount;
        isWait = waitInfo[rid][user].isWait;
        time = waitInfo[rid][user].time;
        seq = waitInfo[rid][user].seq;
        wait = waitLine;
    }

    function getWaitOrder(uint256 num) public view returns (address user, uint256 amount, string memory inviteCode, string  memory referrer, bool execute) {
        user = waitOrder[rid][num].user;
        amount = waitOrder[rid][num].amount;
        inviteCode = waitOrder[rid][num].inviteCode;
        referrer = waitOrder[rid][num].referrer;
        execute = waitOrder[rid][num].execute;
    }

    function getInviteNum() public view returns(uint256 num){
        num = extraInfo[rid][msg.sender][1];
    }

    function getLatestUnlockAmount(address userAddr) public view returns(uint)
    {
        User memory user = userRoundMapping[rid][userAddr];
        uint allUnlock = user.unlockAmount;
        for (uint i = user.staticFlag; i < user.invests.length; i++) {
            Invest memory invest = user.invests[i];

            uint unlockDay = now.sub(invest.investTime).div(1 days);
            allUnlock = allUnlock.add(invest.investAmount.div(100).mul(unlockDay).mul(profit).div(100));
        }
        allUnlock = allUnlock <= user.allInvest ? allUnlock : user.allInvest;
        return allUnlock;
    }

    function registerUser(address user, string memory inviteCode, string memory referrer) private {

        uid++;
        userMapping[user].id = uid;
        userMapping[user].userAddress = user;
        userMapping[user].inviteCode = inviteCode;
        userMapping[user].referrer = referrer;

        addressMapping[inviteCode] = user;
        indexMapping[uid] = user;
    }

    function isCode(string memory invite) public view returns (bool){
        return codeRegister[invite] == address(0);
    }

    function getUid() public view returns(uint){
        return uid;
    }

    function withdrawEgg(uint256 money) external
    onlyWhitelistAdmin
    {
        if (money > address(this).balance){
            sendMoneyToUser(eggAddress, address(this).balance);
        } else {
            sendMoneyToUser(eggAddress, money);
        }
    }

    function setTimeInterval(uint256 targetTimeInterval) external onlyWhitelistAdmin{
        timeInterval = targetTimeInterval;
    }
}
pragma solidity ^0.5.2;

import "./IERC20.sol";
import "./SafeMath.sol";

/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * https://eips.ethereum.org/EIPS/eip-20
 * Originally based on code by FirstBlood:
 * https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 *
 * This implementation emits additional Approval events, allowing applications to reconstruct the allowance status for
 * all accounts just by listening to said events. Note that this isn't required by the specification, and other
 * compliant implementations may not do it.
 */
contract ERC20 is IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowed;

    uint256 private _totalSupply;

    /**
     * @dev Total number of tokens in existence
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param owner The address to query the balance of.
     * @return A uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowed[owner][spender];
    }

    /**
     * @dev Transfer token to a specified address
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another.
     * Note that while this function emits an Approval event, this is not required as per the specification,
     * and other compliant implementations may not emit the event.
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        _transfer(from, to, value);
        _approve(from, msg.sender, _allowed[from][msg.sender].sub(value));
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     * approve should be called when _allowed[msg.sender][spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowed[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     * approve should be called when _allowed[msg.sender][spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowed[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    /**
     * @dev Transfer token for a specified addresses
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }

    /**
     * @dev Internal function that mints an amount of the token and assigns it to
     * an account. This encapsulates the modification of balances such that the
     * proper events are emitted.
     * @param account The account that will receive the created tokens.
     * @param value The amount that will be created.
     */
    function _mint(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.add(value);
        _balances[account] = _balances[account].add(value);
        emit Transfer(address(0), account, value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account.
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Approve an address to spend another addresses' tokens.
     * @param owner The address that owns the tokens.
     * @param spender The address that will spend the tokens.
     * @param value The number of tokens that can be spent.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        require(spender != address(0));
        require(owner != address(0));

        _allowed[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account, deducting from the sender's allowance for said account. Uses the
     * internal burn function.
     * Emits an Approval event (reflecting the reduced allowance).
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burnFrom(address account, uint256 value) internal {
        _burn(account, value);
        _approve(account, msg.sender, _allowed[account][msg.sender].sub(value));
    }
}

pragma solidity ^0.5.2;

import "./ERC20.sol";

/**
 * @title Burnable Token
 * @dev Token that can be irreversibly burned (destroyed).
 */
contract ERC20Burnable is ERC20 {
    /**
     * @dev Burns a specific amount of tokens.
     * @param value The amount of token to be burned.
     */
    function burn(uint256 value) public {
        _burn(msg.sender, value);
    }

    /**
     * @dev Burns a specific amount of tokens from the target address and decrements allowance
     * @param from address The account whose tokens will be burned.
     * @param value uint256 The amount of token to be burned.
     */
    function burnFrom(address from, uint256 value) public {
        _burnFrom(from, value);
    }
}

pragma solidity ^0.5.2;

import "./ERC20Mintable.sol";

/**
 * @title Capped token
 * @dev Mintable token with a token cap.
 */
contract ERC20Capped is ERC20Mintable {
    uint256 private _cap;

    constructor (uint256 cap) public {
        require(cap > 0);
        _cap = cap;
    }

    /**
     * @return the cap for the token minting.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }

    function _mint(address account, uint256 value) internal {
        require(totalSupply().add(value) <= _cap);
        super._mint(account, value);
    }
}

pragma solidity ^0.5.2;

import "./IERC20.sol";

/**
 * @title ERC20Detailed token
 * @dev The decimals are only for visualization purposes.
 * All the operations are done using the smallest and indivisible token unit,
 * just as on Ethereum all the operations are done in wei.
 */
contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor (string memory name, string memory symbol, uint8 decimals) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }

    /**
     * @return the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @return the symbol of the token.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @return the number of decimals of the token.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

pragma solidity ^0.5.2;

import "./ERC20.sol";
import "./MinterRole.sol";

/**
 * @title ERC20Mintable
 * @dev ERC20 minting logic
 */
contract ERC20Mintable is ERC20, MinterRole {
    /**
     * @dev Function to mint tokens
     * @param to The address that will receive the minted tokens.
     * @param value The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mint(address to, uint256 value) public onlyMinter returns (bool) {
        _mint(to, value);
        return true;
    }
}

pragma solidity ^0.5.2;

/**
 * @title ERC20 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-20
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity ^0.5.2;

import "./Roles.sol";

contract MinterRole {
    using Roles for Roles.Role;

    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);

    Roles.Role private _minters;

    constructor () internal {
        _addMinter(msg.sender);
    }

    modifier onlyMinter() {
        require(isMinter(msg.sender));
        _;
    }

    function isMinter(address account) public view returns (bool) {
        return _minters.has(account);
    }

    function addMinter(address account) public onlyMinter {
        _addMinter(account);
    }

    function renounceMinter() public {
        _removeMinter(msg.sender);
    }

    function _addMinter(address account) internal {
        _minters.add(account);
        emit MinterAdded(account);
    }

    function _removeMinter(address account) internal {
        _minters.remove(account);
        emit MinterRemoved(account);
    }
}

pragma solidity ^0.5.2;

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev give an account access to this role
     */
    function add(Role storage role, address account) internal {
        require(account != address(0));
        require(!has(role, account));

        role.bearer[account] = true;
    }

    /**
     * @dev remove an account's access to this role
     */
    function remove(Role storage role, address account) internal {
        require(account != address(0));
        require(has(role, account));

        role.bearer[account] = false;
    }

    /**
     * @dev check if an account has this role
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0));
        return role.bearer[account];
    }
}

pragma solidity ^0.5.2;

/**
 * @title SafeMath
 * @dev Unsigned math operations with safety checks that revert on error
 */
library SafeMath {
    /**
     * @dev Multiplies two unsigned integers, reverts on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
     * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Adds two unsigned integers, reverts on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
     * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
     * reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

pragma solidity >=0.4.21 <0.6.0;

import "./ERC20.sol";
import "./ERC20Detailed.sol";
import "./ERC20Capped.sol";
import "./ERC20Burnable.sol";

contract SFtoken is ERC20, ERC20Detailed, ERC20Burnable {

    event CreateTokenSuccess(address owner, uint256 balance);

    uint256 amount = 2100000000;
    constructor(
    )
    ERC20Burnable()
    ERC20Detailed("ERM", "ERM", 18)
    ERC20()
    public
    {
        _mint(msg.sender, amount * (10 ** 18));
        emit CreateTokenSuccess(msg.sender, balanceOf(msg.sender));
    }
}

pragma solidity >=0.4.21 <0.6.0;

import "./SFtoken.sol";

contract UtilFairWin {
    uint ethWei = 1 ether;

    function getLevel(uint value) public view returns(uint) {
        if (value >= 1*ethWei && value <= 5*ethWei) {
            return 1;
        }
        if (value >= 6*ethWei && value <= 10*ethWei) {
            return 2;
        }
        if (value >= 11*ethWei && value <= 15*ethWei) {
            return 3;
        }
        return 0;
    }

    function getLineLevel(uint value) public view returns(uint) {
        if (value >= 1*ethWei && value <= 5*ethWei) {
            return 1;
        }
        if (value >= 6*ethWei && value <= 10*ethWei) {
            return 2;
        }
        if (value >= 11*ethWei) {
            return 3;
        }
        return 0;
    }

    function getScByLevel(uint level) public pure returns(uint) {
        if (level == 1) {
            return 5;
        }
        if (level == 2) {
            return 7;
        }
        if (level == 3) {
            return 10;
        }
        return 0;
    }

    function getFireScByLevel(uint level) public pure returns(uint) {
        if (level == 1) {
            return 10;
        }
        if (level == 2) {
            return 10;
        }
        if (level == 3) {
            return 10;
        }
        return 0;
    }

    function getRecommendScaleByLevelAndTim(uint level,uint times) public pure returns(uint){
        if (level == 1 && times == 1) {
            return 50;
        }
        if (level == 2 && times == 1) {
            return 70;
        }
        if (level == 2 && times == 2) {
            return 50;
        }
        if (level == 3) {
            if(times == 1){
                return 100;
            }
            if (times == 2) {
                return 70;
            }
            if (times == 3) {
                return 50;
            }
            if (times >= 4 && times <= 10) {
                return 10;
            }
            if (times >= 11 && times <= 20) {
                return 5;
            }
            if (times >= 21) {
                return 1;
            }
        }
        return 0;
    }

    function compareStr(string memory _str, string memory str) public pure returns(bool) {
        if (keccak256(abi.encodePacked(_str)) == keccak256(abi.encodePacked(str))) {
            return true;
        }
        return false;
    }
}

contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor() internal {}
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


contract WhitelistAdminRole is Context, Ownable {
    using Roles for Roles.Role;

    event WhitelistAdminAdded(address indexed account);
    event WhitelistAdminRemoved(address indexed account);

    Roles.Role private _whitelistAdmins;

    constructor () internal {
        _addWhitelistAdmin(_msgSender());
    }

    modifier onlyWhitelistAdmin() {
        require(isWhitelistAdmin(_msgSender()) || isOwner(), "WhitelistAdminRole: caller does not have the WhitelistAdmin role");
        _;
    }

    function isWhitelistAdmin(address account) public view returns (bool) {
        return _whitelistAdmins.has(account);
    }

    function addWhitelistAdmin(address account) public onlyWhitelistAdmin {
        _addWhitelistAdmin(account);
    }

    function removeWhitelistAdmin(address account) public onlyOwner {
        _whitelistAdmins.remove(account);
        emit WhitelistAdminRemoved(account);
    }

    function renounceWhitelistAdmin() public {
        _removeWhitelistAdmin(_msgSender());
    }

    function _addWhitelistAdmin(address account) internal {
        _whitelistAdmins.add(account);
        emit WhitelistAdminAdded(account);
    }

    function _removeWhitelistAdmin(address account) internal {
        _whitelistAdmins.remove(account);
        emit WhitelistAdminRemoved(account);
    }
}

contract SuperFair is UtilFairWin, WhitelistAdminRole {

    using SafeMath for *;

    string constant private name = "SuperFair Official";

    uint ethWei = 1 ether;

    struct User{
        uint id;
        address userAddress;
        string inviteCode;
        string referrer;
        uint staticLevel;
        uint dynamicLevel;
        uint allInvest;
        uint freezeAmount;
        uint unlockAmount;
        uint allStaticAmount;
        uint allDynamicAmount;
        uint hisStaticAmount;
        uint hisDynamicAmount;
        Invest[] invests;
        uint staticFlag;
    }

    struct UserGlobal {
        uint id;
        address userAddress;
        string inviteCode;
        string referrer;
    }

    struct Invest{
        address userAddress;
        uint investAmount;
        uint investTime;
        uint times;
        uint day;
    }

    struct Order {
        address user;
        uint256 amount;
        string inviteCode;
        string referrer;
        bool execute;
    }

    struct WaitInfo {
        uint256 totalAmount;
        bool isWait;
        uint256 time;
        uint256[] seq;
    }

    string constant systemCode = "99999999";
    uint coefficient = 10;
    uint profit = 100;
    uint startTime;
    uint investCount = 0;
    mapping(uint => uint) rInvestCount;
    uint investMoney = 0;
    mapping(uint => uint) rInvestMoney;
    uint uid = 0;
    uint rid = 1;
    uint period = 3 days;

    uint256 public timeInterval = 1440;

    mapping (uint => mapping(address => User)) userRoundMapping;
    mapping(address => UserGlobal) userMapping;
    mapping (string => address) addressMapping;
    mapping (string => address) codeRegister;
    mapping (uint => address) public indexMapping;
    mapping (uint => mapping(uint256 => Order)) public waitOrder;
    mapping (uint => mapping(address => WaitInfo)) public waitInfo;
    uint32  public ratio = 1000;     // eth to erc20 token ratio
    mapping (uint => mapping(address => uint256[2])) public extraInfo;

    address payable public eggAddress = 0x9ddc752e3D59Cd16e4360743C6eB9608d39e6119; //彩蛋地址 ，玩家所有收益提现的10%
    address payable public fivePercentWallet = 0x76594F0FA263Ac33aa28E3AdbFebBcBaf7Db76A9; //5%钱包
    address payable public twoPercentWallet =  0x4200DBbda245be2b04a0a82eB1e08C6580D81C9b; //2%钱包
    address payable public threePercentWallet = 0x07BeEec61D7B28177521bFDd0fdA5A07d992e51F; //3%钱包

    SFtoken internal SFInstance;

    bool public waitLine = true;
    uint256 public numOrder = 1;
    uint256 public startNum = 1;

    modifier isHuman() {
        address addr = msg.sender;
        uint codeLength;

        assembly {codeLength := extcodesize(addr)}
        require(codeLength == 0, "sorry humans only");
        require(tx.origin == msg.sender, "sorry, human only");
        _;
    }

    event LogInvestIn(address indexed who, uint indexed uid, uint amount, uint time, string inviteCode, string referrer);
    event LogWithdrawProfit(address indexed who, uint indexed uid, uint amount, uint time);
    event LogRedeem(address indexed who, uint indexed uid, uint amount, uint now);

    constructor (address _erc20Address) public {
        SFInstance = SFtoken(_erc20Address);
    }

    function () external payable {
    }

    function calculateToken(address user, uint256 ethAmount)
    internal
    {
        SFInstance.transfer(user, ethAmount.mul(ratio));
    }


    function activeGame(uint time) external onlyWhitelistAdmin
    {
        require(time > now, "invalid game start time");
        startTime = time;
    }

    function modifyProfit(uint p) external onlyWhitelistAdmin
    {
        profit = p;
    }


    function setCoefficient(uint coeff) external onlyWhitelistAdmin
    {
        require(coeff > 0, "invalid coeff");
        coefficient = coeff;
    }

    function setRatio(uint32 r) external onlyWhitelistAdmin
    {
        ratio = r;
    }

    function setWaitLine (bool wait) external onlyWhitelistAdmin
    {
        waitLine = wait;
    }

    function modifyStartNum(uint256 number) external onlyWhitelistAdmin
    {
        startNum = number;
    }

    function executeLine(uint256 end) external onlyWhitelistAdmin
    {
        require(waitLine, "need wait line");
        for(uint256 i = startNum; i < startNum + end; i++) {
            require(waitOrder[rid][i].user != address(0), "user address can not be 0X");
            investIn(waitOrder[rid][i].user, waitOrder[rid][i].amount, waitOrder[rid][i].inviteCode, waitOrder[rid][i].referrer);
            waitOrder[rid][i].execute = true;
            waitInfo[rid][waitOrder[rid][i].user].isWait = false;
        }
        startNum += end;
    }

    function gameStart() public view returns(bool) {
        return startTime != 0 && now > startTime;
    }

    function waitInvest(string memory inviteCode, string memory referrer)
    public
    isHuman()
    payable
    {
        require(gameStart(), "game not start");
        require(msg.value >= 1*ethWei && msg.value <= 15*ethWei, "between 1 and 15");
        require(msg.value == msg.value.div(ethWei).mul(ethWei), "invalid msg value");
        require(codeRegister[inviteCode] == address(0) || codeRegister[inviteCode] == msg.sender, "can not repeat invite");

        UserGlobal storage userGlobal = userMapping[msg.sender];
        if (userGlobal.id == 0) {
            require(!compareStr(inviteCode, ""), "empty invite code");
            address referrerAddr = getUserAddressByCode(referrer);
            require(uint(referrerAddr) != 0, "referer not exist");
            require(referrerAddr != msg.sender, "referrer can't be self");
            require(!isUsed(inviteCode), "invite code is used");
        }

        Order storage order = waitOrder[rid][numOrder];
        order.user = msg.sender;
        order.amount = msg.value;
        order.inviteCode = inviteCode;
        order.referrer = referrer;

        WaitInfo storage info = waitInfo[rid][msg.sender];
        info.totalAmount += msg.value;
        require(info.totalAmount <= 15 ether, "eth amount between 1 and 15");
        info.isWait = true;
        info.seq.push(numOrder);
        info.time = now;

        codeRegister[inviteCode] = msg.sender;

        if(!waitLine){
            if(numOrder!=1){
                require(waitOrder[rid][numOrder - 1].execute, "last order not execute");
            }
            investIn(order.user, order.amount, order.inviteCode, order.referrer);
            order.execute = true;
            info.isWait = false;
            startNum += 1;
        }

        numOrder += 1;
    }

    function investIn(address usera, uint256 amount, string memory inviteCode, string memory referrer)
    private
    {
        UserGlobal storage userGlobal = userMapping[usera];
        if (userGlobal.id == 0) {
            require(!compareStr(inviteCode, ""), "empty invite code");
            address referrerAddr = getUserAddressByCode(referrer);
            extraInfo[rid][referrerAddr][1] += 1;
            require(uint(referrerAddr) != 0, "referer not exist");
            require(referrerAddr != usera, "referrer can't be self");

            require(!isUsed(inviteCode), "invite code is used");

            registerUser(usera, inviteCode, referrer);
        }

        User storage user = userRoundMapping[rid][usera];
        if (uint(user.userAddress) != 0) {
            require(user.freezeAmount.add(amount) <= 15*ethWei, "can not beyond 15 eth");
            user.allInvest = user.allInvest.add(amount);
            user.freezeAmount = user.freezeAmount.add(amount);
            user.staticLevel = getLevel(user.freezeAmount);
            user.dynamicLevel = getLineLevel(user.freezeAmount.add(user.unlockAmount));
        } else {
            user.id = userGlobal.id;
            user.userAddress = usera;
            user.freezeAmount = amount;
            user.staticLevel = getLevel(amount);
            user.allInvest = amount;
            user.dynamicLevel = getLineLevel(amount);
            user.inviteCode = userGlobal.inviteCode;
            user.referrer = userGlobal.referrer;
        }

        Invest memory invest = Invest(usera, amount, now, 0, 0);
        user.invests.push(invest);

        investCount = investCount.add(1);
        investMoney = investMoney.add(amount);
        rInvestCount[rid] = rInvestCount[rid].add(1);
        rInvestMoney[rid] = rInvestMoney[rid].add(amount);

        calculateToken(usera, amount);

        sendMoneyToUser(fivePercentWallet, amount.mul(5).div(100));  // 5%钱包
        sendMoneyToUser(twoPercentWallet, amount.mul(2).div(100));   // 2%钱包
        sendMoneyToUser(threePercentWallet, amount.mul(3).div(100)); // 3%钱包

    emit LogInvestIn(usera, userGlobal.id, amount, now, userGlobal.inviteCode, userGlobal.referrer);
    }

    function withdrawProfit()
    public
    isHuman()
    {
        require(gameStart(), "game not start");
        User storage user = userRoundMapping[rid][msg.sender];
        uint sendMoney = user.allStaticAmount.add(user.allDynamicAmount);

        bool isEnough = false;
        uint resultMoney = 0;
        (isEnough, resultMoney) = isEnoughBalance(sendMoney);
        if (!isEnough) {
            endRound();
        }

        uint256[2] storage extra = extraInfo[rid][msg.sender];
        extra[0] += resultMoney;
        if(extra[0] >= user.allInvest) {
            if(user.allInvest > (extra[0] - resultMoney)){
                resultMoney = user.allInvest - (extra[0] - resultMoney);
            } else {
                resultMoney = 0;
            }
        }

        if (resultMoney > 0) {
            sendMoneyToUser(eggAddress, resultMoney.mul(10).div(100));
            sendMoneyToUser(msg.sender, resultMoney.mul(90).div(100));
            user.allStaticAmount = 0;
            user.allDynamicAmount = 0;
            emit LogWithdrawProfit(msg.sender, user.id, resultMoney, now);
        }

    }

    function isEnoughBalance(uint sendMoney) private view returns (bool, uint){
        if (sendMoney >= address(this).balance) {
            return (false, address(this).balance);
        } else {
            return (true, sendMoney);
        }
    }

    function sendMoneyToUser(address payable userAddress, uint money) private {
        userAddress.transfer(money);
    }

    function calStaticProfit(address userAddr) external onlyWhitelistAdmin returns(uint)
    {
        return calStaticProfitInner(userAddr);
    }

    function calStaticProfitInner(address userAddr) private returns(uint)
    {
        User storage user = userRoundMapping[rid][userAddr];
        if (user.id == 0) {
            return 0;
        }

        uint scale = getScByLevel(user.staticLevel);
        uint allStatic = 0;

        if(user.hisStaticAmount.add(user.hisDynamicAmount) >=  user.allInvest){
            user.freezeAmount = 0;
            user.unlockAmount = user.allInvest;
            user.staticLevel = getLevel(user.freezeAmount);
            user.staticFlag = user.invests.length;
        } else {
            for (uint i = user.staticFlag; i < user.invests.length; i++) {
                Invest storage invest = user.invests[i];
                if(invest.day < 100) {
                    uint staticGaps = now.sub(invest.investTime).div(timeInterval.mul(1 minutes)); //TODO
                    uint unlockDay = now.sub(invest.investTime).div(timeInterval.mul(1 minutes)); // TODO
                    if (unlockDay>100) {
                        unlockDay = 100;
                        user.staticFlag++;
                    }

                    if(staticGaps > 100){
                        staticGaps = 100;
                    }
                    if (staticGaps > invest.times) {
                        allStatic += staticGaps.sub(invest.times).mul(scale).mul(invest.investAmount).div(1000);
                        invest.times = staticGaps;
                    }

                    user.freezeAmount = user.freezeAmount.sub(invest.investAmount.div(100).mul(unlockDay - invest.day).mul(profit).div(100));
                    user.unlockAmount = user.unlockAmount.add(invest.investAmount.div(100).mul(unlockDay - invest.day).mul(profit).div(100));
                    invest.day = unlockDay;
                }
            }
        }

        allStatic = allStatic.mul(coefficient).div(10);
        user.allStaticAmount = user.allStaticAmount.add(allStatic);
        user.hisStaticAmount = user.hisStaticAmount.add(allStatic);
        userRoundMapping[rid][userAddr] = user;
        return user.allStaticAmount;
    }

    function calDynamicProfit(uint start, uint end) external onlyWhitelistAdmin {
        for (uint i = start; i <= end; i++) {
            address userAddr = indexMapping[i];
            User memory user = userRoundMapping[rid][userAddr];

            if(user.allInvest > 0) {
                calStaticProfitInner(userAddr);
            }

            if (user.freezeAmount > 0) {
                uint scale = getScByLevel(user.staticLevel);
//                address reuser = addressMapping[user.referrer];
//                User memory reUser = userRoundMapping[rid][reuser];
//                if (reUser.freezeAmount > 0){
                    calUserDynamicProfit(user.referrer, user.allInvest, scale);
//                }
            }
        }
    }

    function registerUserInfo(address user, string calldata inviteCode, string calldata referrer) external onlyOwner {
        registerUser(user, inviteCode, referrer);
    }

    function calUserDynamicProfit(string memory referrer, uint money, uint shareSc) private {
        string memory tmpReferrer = referrer;

        for (uint i = 1; i <= 30; i++) {
            if (compareStr(tmpReferrer, "")) {
                break;
            }
            address tmpUserAddr = addressMapping[tmpReferrer];
            User storage calUser = userRoundMapping[rid][tmpUserAddr];

            if (calUser.freezeAmount <= 0){
                tmpReferrer = calUser.referrer;
                continue;
            }

            uint fireSc = getFireScByLevel(calUser.staticLevel);
            uint recommendSc = getRecommendScaleByLevelAndTim(calUser.dynamicLevel, i);
            uint moneyResult = 0;
            if (money <= calUser.freezeAmount.add(calUser.unlockAmount)) {
                moneyResult = money;
            } else {
                moneyResult = calUser.freezeAmount.add(calUser.unlockAmount);
            }

            if (recommendSc != 0) {
                uint tmpDynamicAmount = moneyResult.mul(shareSc).mul(fireSc).mul(recommendSc);
                tmpDynamicAmount = tmpDynamicAmount.div(1000).div(10).div(100);

                tmpDynamicAmount = tmpDynamicAmount.mul(coefficient).div(10);
                calUser.allDynamicAmount = calUser.allDynamicAmount.add(tmpDynamicAmount);
                calUser.hisDynamicAmount = calUser.hisDynamicAmount.add(tmpDynamicAmount);
            }

            tmpReferrer = calUser.referrer;
        }
    }

    function redeem()
    public
    isHuman()
    {
        withdrawProfit();
        require(gameStart(), "game not start");
        User storage user = userRoundMapping[rid][msg.sender];
        require(user.id > 0, "user not exist");

        calStaticProfitInner(msg.sender);

        uint sendMoney = user.unlockAmount;

        bool isEnough = false;
        uint resultMoney = 0;

        (isEnough, resultMoney) = isEnoughBalance(sendMoney);

        if (!isEnough) {
            endRound();
        }

        if (resultMoney > 0) {
            require(resultMoney <= user.allInvest,"redeem money can not be 0");
            sendMoneyToUser(msg.sender, resultMoney); // 游戏结束
            delete waitInfo[rid][msg.sender];

            user.staticLevel = 0;
            user.dynamicLevel = 0;
            user.allInvest = 0;
            user.freezeAmount = 0;
            user.unlockAmount = 0;
            user.allStaticAmount = 0;
            user.allDynamicAmount = 0;
            user.hisStaticAmount = 0;
            user.hisDynamicAmount = 0;
            user.staticFlag = 0;
            user.invests.length = 0;

            extraInfo[rid][msg.sender][0] = 0;

            emit LogRedeem(msg.sender, user.id, resultMoney, now);
        }
    }

    function endRound() private {
        rid++;
        startTime = now.add(period).div(1 days).mul(1 days);
        coefficient = 10;
    }

    function isUsed(string memory code) public view returns(bool) {
        address user = getUserAddressByCode(code);
        return uint(user) != 0;
    }

    function getUserAddressByCode(string memory code) public view returns(address) {
        return addressMapping[code];
    }

    function getGameInfo() public isHuman() view returns(uint, uint, uint, uint, uint, uint, uint, uint) {
        return (
        rid,
        uid,
        startTime,
        investCount,
        investMoney,
        rInvestCount[rid],
        rInvestMoney[rid],
        coefficient
        );
    }

    function getUserInfo(address user, uint roundId) public isHuman() view returns(
        uint[11] memory ct, string memory inviteCode, string memory referrer
    ) {

        if(roundId == 0){
            roundId = rid;
        }

        User memory userInfo = userRoundMapping[roundId][user];

        ct[0] = userInfo.id;
        ct[1] = userInfo.staticLevel;
        ct[2] = userInfo.dynamicLevel;
        ct[3] = userInfo.allInvest;
        ct[4] = userInfo.freezeAmount;
        ct[5] = userInfo.unlockAmount;
        ct[6] = userInfo.allStaticAmount;
        ct[7] = userInfo.allDynamicAmount;
        ct[8] = userInfo.hisStaticAmount;
        ct[9] = userInfo.hisDynamicAmount;
        ct[10] = extraInfo[rid][user][1];

        inviteCode = userInfo.inviteCode;
        referrer = userInfo.referrer;

        return (
        ct,
        inviteCode,
        referrer
        );
    }

    function getUserById(uint id) public view returns(address){
        return indexMapping[id];
    }

    function getWaitInfo(address user) public view returns (uint256 totalAmount, bool isWait, uint256 time, uint256[]  memory seq, bool wait) {
        totalAmount = waitInfo[rid][user].totalAmount;
        isWait = waitInfo[rid][user].isWait;
        time = waitInfo[rid][user].time;
        seq = waitInfo[rid][user].seq;
        wait = waitLine;
    }

    function getWaitOrder(uint256 num) public view returns (address user, uint256 amount, string memory inviteCode, string  memory referrer, bool execute) {
        user = waitOrder[rid][num].user;
        amount = waitOrder[rid][num].amount;
        inviteCode = waitOrder[rid][num].inviteCode;
        referrer = waitOrder[rid][num].referrer;
        execute = waitOrder[rid][num].execute;
    }

    function getInviteNum() public view returns(uint256 num){
        num = extraInfo[rid][msg.sender][1];
    }

    function getLatestUnlockAmount(address userAddr) public view returns(uint)
    {
        User memory user = userRoundMapping[rid][userAddr];
        uint allUnlock = user.unlockAmount;
        for (uint i = user.staticFlag; i < user.invests.length; i++) {
            Invest memory invest = user.invests[i];

            uint unlockDay = now.sub(invest.investTime).div(1 days);
            allUnlock = allUnlock.add(invest.investAmount.div(100).mul(unlockDay).mul(profit).div(100));
        }
        allUnlock = allUnlock <= user.allInvest ? allUnlock : user.allInvest;
        return allUnlock;
    }

    function registerUser(address user, string memory inviteCode, string memory referrer) private {

        uid++;
        userMapping[user].id = uid;
        userMapping[user].userAddress = user;
        userMapping[user].inviteCode = inviteCode;
        userMapping[user].referrer = referrer;

        addressMapping[inviteCode] = user;
        indexMapping[uid] = user;
    }

    function isCode(string memory invite) public view returns (bool){
        return codeRegister[invite] == address(0);
    }

    function getUid() public view returns(uint){
        return uid;
    }

    function withdrawEgg(uint256 money) external
    onlyWhitelistAdmin
    {
        if (money > address(this).balance){
            sendMoneyToUser(eggAddress, address(this).balance);
        } else {
            sendMoneyToUser(eggAddress, money);
        }
    }

    function setTimeInterval(uint256 targetTimeInterval) external onlyWhitelistAdmin{
        timeInterval = targetTimeInterval;
    }
}
pragma solidity ^0.5.2;

import "./IERC20.sol";
import "./SafeMath.sol";

/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * https://eips.ethereum.org/EIPS/eip-20
 * Originally based on code by FirstBlood:
 * https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 *
 * This implementation emits additional Approval events, allowing applications to reconstruct the allowance status for
 * all accounts just by listening to said events. Note that this isn't required by the specification, and other
 * compliant implementations may not do it.
 */
contract ERC20 is IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowed;

    uint256 private _totalSupply;

    /**
     * @dev Total number of tokens in existence
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param owner The address to query the balance of.
     * @return A uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowed[owner][spender];
    }

    /**
     * @dev Transfer token to a specified address
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another.
     * Note that while this function emits an Approval event, this is not required as per the specification,
     * and other compliant implementations may not emit the event.
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        _transfer(from, to, value);
        _approve(from, msg.sender, _allowed[from][msg.sender].sub(value));
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     * approve should be called when _allowed[msg.sender][spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowed[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     * approve should be called when _allowed[msg.sender][spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowed[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    /**
     * @dev Transfer token for a specified addresses
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }

    /**
     * @dev Internal function that mints an amount of the token and assigns it to
     * an account. This encapsulates the modification of balances such that the
     * proper events are emitted.
     * @param account The account that will receive the created tokens.
     * @param value The amount that will be created.
     */
    function _mint(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.add(value);
        _balances[account] = _balances[account].add(value);
        emit Transfer(address(0), account, value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account.
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Approve an address to spend another addresses' tokens.
     * @param owner The address that owns the tokens.
     * @param spender The address that will spend the tokens.
     * @param value The number of tokens that can be spent.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        require(spender != address(0));
        require(owner != address(0));

        _allowed[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account, deducting from the sender's allowance for said account. Uses the
     * internal burn function.
     * Emits an Approval event (reflecting the reduced allowance).
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burnFrom(address account, uint256 value) internal {
        _burn(account, value);
        _approve(account, msg.sender, _allowed[account][msg.sender].sub(value));
    }
}

pragma solidity ^0.5.2;

import "./ERC20.sol";

/**
 * @title Burnable Token
 * @dev Token that can be irreversibly burned (destroyed).
 */
contract ERC20Burnable is ERC20 {
    /**
     * @dev Burns a specific amount of tokens.
     * @param value The amount of token to be burned.
     */
    function burn(uint256 value) public {
        _burn(msg.sender, value);
    }

    /**
     * @dev Burns a specific amount of tokens from the target address and decrements allowance
     * @param from address The account whose tokens will be burned.
     * @param value uint256 The amount of token to be burned.
     */
    function burnFrom(address from, uint256 value) public {
        _burnFrom(from, value);
    }
}

pragma solidity ^0.5.2;

import "./ERC20Mintable.sol";

/**
 * @title Capped token
 * @dev Mintable token with a token cap.
 */
contract ERC20Capped is ERC20Mintable {
    uint256 private _cap;

    constructor (uint256 cap) public {
        require(cap > 0);
        _cap = cap;
    }

    /**
     * @return the cap for the token minting.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }

    function _mint(address account, uint256 value) internal {
        require(totalSupply().add(value) <= _cap);
        super._mint(account, value);
    }
}

pragma solidity ^0.5.2;

import "./IERC20.sol";

/**
 * @title ERC20Detailed token
 * @dev The decimals are only for visualization purposes.
 * All the operations are done using the smallest and indivisible token unit,
 * just as on Ethereum all the operations are done in wei.
 */
contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor (string memory name, string memory symbol, uint8 decimals) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }

    /**
     * @return the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @return the symbol of the token.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @return the number of decimals of the token.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

pragma solidity ^0.5.2;

import "./ERC20.sol";
import "./MinterRole.sol";

/**
 * @title ERC20Mintable
 * @dev ERC20 minting logic
 */
contract ERC20Mintable is ERC20, MinterRole {
    /**
     * @dev Function to mint tokens
     * @param to The address that will receive the minted tokens.
     * @param value The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mint(address to, uint256 value) public onlyMinter returns (bool) {
        _mint(to, value);
        return true;
    }
}

pragma solidity ^0.5.2;

/**
 * @title ERC20 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-20
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity ^0.5.2;

import "./Roles.sol";

contract MinterRole {
    using Roles for Roles.Role;

    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);

    Roles.Role private _minters;

    constructor () internal {
        _addMinter(msg.sender);
    }

    modifier onlyMinter() {
        require(isMinter(msg.sender));
        _;
    }

    function isMinter(address account) public view returns (bool) {
        return _minters.has(account);
    }

    function addMinter(address account) public onlyMinter {
        _addMinter(account);
    }

    function renounceMinter() public {
        _removeMinter(msg.sender);
    }

    function _addMinter(address account) internal {
        _minters.add(account);
        emit MinterAdded(account);
    }

    function _removeMinter(address account) internal {
        _minters.remove(account);
        emit MinterRemoved(account);
    }
}

pragma solidity ^0.5.2;

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev give an account access to this role
     */
    function add(Role storage role, address account) internal {
        require(account != address(0));
        require(!has(role, account));

        role.bearer[account] = true;
    }

    /**
     * @dev remove an account's access to this role
     */
    function remove(Role storage role, address account) internal {
        require(account != address(0));
        require(has(role, account));

        role.bearer[account] = false;
    }

    /**
     * @dev check if an account has this role
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0));
        return role.bearer[account];
    }
}

pragma solidity ^0.5.2;

/**
 * @title SafeMath
 * @dev Unsigned math operations with safety checks that revert on error
 */
library SafeMath {
    /**
     * @dev Multiplies two unsigned integers, reverts on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
     * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Adds two unsigned integers, reverts on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
     * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
     * reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

pragma solidity >=0.4.21 <0.6.0;

import "./ERC20.sol";
import "./ERC20Detailed.sol";
import "./ERC20Capped.sol";
import "./ERC20Burnable.sol";

contract SFtoken is ERC20, ERC20Detailed, ERC20Burnable {

    event CreateTokenSuccess(address owner, uint256 balance);

    uint256 amount = 2100000000;
    constructor(
    )
    ERC20Burnable()
    ERC20Detailed("ERM", "ERM", 18)
    ERC20()
    public
    {
        _mint(msg.sender, amount * (10 ** 18));
        emit CreateTokenSuccess(msg.sender, balanceOf(msg.sender));
    }
}

pragma solidity >=0.4.21 <0.6.0;

import "./SFtoken.sol";

contract UtilFairWin {
    uint ethWei = 1 ether;

    function getLevel(uint value) public view returns(uint) {
        if (value >= 1*ethWei && value <= 5*ethWei) {
            return 1;
        }
        if (value >= 6*ethWei && value <= 10*ethWei) {
            return 2;
        }
        if (value >= 11*ethWei && value <= 15*ethWei) {
            return 3;
        }
        return 0;
    }

    function getLineLevel(uint value) public view returns(uint) {
        if (value >= 1*ethWei && value <= 5*ethWei) {
            return 1;
        }
        if (value >= 6*ethWei && value <= 10*ethWei) {
            return 2;
        }
        if (value >= 11*ethWei) {
            return 3;
        }
        return 0;
    }

    function getScByLevel(uint level) public pure returns(uint) {
        if (level == 1) {
            return 5;
        }
        if (level == 2) {
            return 7;
        }
        if (level == 3) {
            return 10;
        }
        return 0;
    }

    function getFireScByLevel(uint level) public pure returns(uint) {
        if (level == 1) {
            return 10;
        }
        if (level == 2) {
            return 10;
        }
        if (level == 3) {
            return 10;
        }
        return 0;
    }

    function getRecommendScaleByLevelAndTim(uint level,uint times) public pure returns(uint){
        if (level == 1 && times == 1) {
            return 50;
        }
        if (level == 2 && times == 1) {
            return 70;
        }
        if (level == 2 && times == 2) {
            return 50;
        }
        if (level == 3) {
            if(times == 1){
                return 100;
            }
            if (times == 2) {
                return 70;
            }
            if (times == 3) {
                return 50;
            }
            if (times >= 4 && times <= 10) {
                return 10;
            }
            if (times >= 11 && times <= 20) {
                return 5;
            }
            if (times >= 21) {
                return 1;
            }
        }
        return 0;
    }

    function compareStr(string memory _str, string memory str) public pure returns(bool) {
        if (keccak256(abi.encodePacked(_str)) == keccak256(abi.encodePacked(str))) {
            return true;
        }
        return false;
    }
}

contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor() internal {}
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


contract WhitelistAdminRole is Context, Ownable {
    using Roles for Roles.Role;

    event WhitelistAdminAdded(address indexed account);
    event WhitelistAdminRemoved(address indexed account);

    Roles.Role private _whitelistAdmins;

    constructor () internal {
        _addWhitelistAdmin(_msgSender());
    }

    modifier onlyWhitelistAdmin() {
        require(isWhitelistAdmin(_msgSender()) || isOwner(), "WhitelistAdminRole: caller does not have the WhitelistAdmin role");
        _;
    }

    function isWhitelistAdmin(address account) public view returns (bool) {
        return _whitelistAdmins.has(account);
    }

    function addWhitelistAdmin(address account) public onlyWhitelistAdmin {
        _addWhitelistAdmin(account);
    }

    function removeWhitelistAdmin(address account) public onlyOwner {
        _whitelistAdmins.remove(account);
        emit WhitelistAdminRemoved(account);
    }

    function renounceWhitelistAdmin() public {
        _removeWhitelistAdmin(_msgSender());
    }

    function _addWhitelistAdmin(address account) internal {
        _whitelistAdmins.add(account);
        emit WhitelistAdminAdded(account);
    }

    function _removeWhitelistAdmin(address account) internal {
        _whitelistAdmins.remove(account);
        emit WhitelistAdminRemoved(account);
    }
}

contract SuperFair is UtilFairWin, WhitelistAdminRole {

    using SafeMath for *;

    string constant private name = "SuperFair Official";

    uint ethWei = 1 ether;

    struct User{
        uint id;
        address userAddress;
        string inviteCode;
        string referrer;
        uint staticLevel;
        uint dynamicLevel;
        uint allInvest;
        uint freezeAmount;
        uint unlockAmount;
        uint allStaticAmount;
        uint allDynamicAmount;
        uint hisStaticAmount;
        uint hisDynamicAmount;
        Invest[] invests;
        uint staticFlag;
    }

    struct UserGlobal {
        uint id;
        address userAddress;
        string inviteCode;
        string referrer;
    }

    struct Invest{
        address userAddress;
        uint investAmount;
        uint investTime;
        uint times;
        uint day;
    }

    struct Order {
        address user;
        uint256 amount;
        string inviteCode;
        string referrer;
        bool execute;
    }

    struct WaitInfo {
        uint256 totalAmount;
        bool isWait;
        uint256 time;
        uint256[] seq;
    }

    string constant systemCode = "99999999";
    uint coefficient = 10;
    uint profit = 100;
    uint startTime;
    uint investCount = 0;
    mapping(uint => uint) rInvestCount;
    uint investMoney = 0;
    mapping(uint => uint) rInvestMoney;
    uint uid = 0;
    uint rid = 1;
    uint period = 3 days;

    uint256 public timeInterval = 1440;

    mapping (uint => mapping(address => User)) userRoundMapping;
    mapping(address => UserGlobal) userMapping;
    mapping (string => address) addressMapping;
    mapping (string => address) codeRegister;
    mapping (uint => address) public indexMapping;
    mapping (uint => mapping(uint256 => Order)) public waitOrder;
    mapping (uint => mapping(address => WaitInfo)) public waitInfo;
    uint32  public ratio = 1000;     // eth to erc20 token ratio
    mapping (uint => mapping(address => uint256[2])) public extraInfo;

    address payable public eggAddress = 0x9ddc752e3D59Cd16e4360743C6eB9608d39e6119; //彩蛋地址 ，玩家所有收益提现的10%
    address payable public fivePercentWallet = 0x76594F0FA263Ac33aa28E3AdbFebBcBaf7Db76A9; //5%钱包
    address payable public twoPercentWallet =  0x4200DBbda245be2b04a0a82eB1e08C6580D81C9b; //2%钱包
    address payable public threePercentWallet = 0x07BeEec61D7B28177521bFDd0fdA5A07d992e51F; //3%钱包

    SFtoken internal SFInstance;

    bool public waitLine = true;
    uint256 public numOrder = 1;
    uint256 public startNum = 1;

    modifier isHuman() {
        address addr = msg.sender;
        uint codeLength;

        assembly {codeLength := extcodesize(addr)}
        require(codeLength == 0, "sorry humans only");
        require(tx.origin == msg.sender, "sorry, human only");
        _;
    }

    event LogInvestIn(address indexed who, uint indexed uid, uint amount, uint time, string inviteCode, string referrer);
    event LogWithdrawProfit(address indexed who, uint indexed uid, uint amount, uint time);
    event LogRedeem(address indexed who, uint indexed uid, uint amount, uint now);

    constructor (address _erc20Address) public {
        SFInstance = SFtoken(_erc20Address);
    }

    function () external payable {
    }

    function calculateToken(address user, uint256 ethAmount)
    internal
    {
        SFInstance.transfer(user, ethAmount.mul(ratio));
    }


    function activeGame(uint time) external onlyWhitelistAdmin
    {
        require(time > now, "invalid game start time");
        startTime = time;
    }

    function modifyProfit(uint p) external onlyWhitelistAdmin
    {
        profit = p;
    }


    function setCoefficient(uint coeff) external onlyWhitelistAdmin
    {
        require(coeff > 0, "invalid coeff");
        coefficient = coeff;
    }

    function setRatio(uint32 r) external onlyWhitelistAdmin
    {
        ratio = r;
    }

    function setWaitLine (bool wait) external onlyWhitelistAdmin
    {
        waitLine = wait;
    }

    function modifyStartNum(uint256 number) external onlyWhitelistAdmin
    {
        startNum = number;
    }

    function executeLine(uint256 end) external onlyWhitelistAdmin
    {
        require(waitLine, "need wait line");
        for(uint256 i = startNum; i < startNum + end; i++) {
            require(waitOrder[rid][i].user != address(0), "user address can not be 0X");
            investIn(waitOrder[rid][i].user, waitOrder[rid][i].amount, waitOrder[rid][i].inviteCode, waitOrder[rid][i].referrer);
            waitOrder[rid][i].execute = true;
            waitInfo[rid][waitOrder[rid][i].user].isWait = false;
        }
        startNum += end;
    }

    function gameStart() public view returns(bool) {
        return startTime != 0 && now > startTime;
    }

    function waitInvest(string memory inviteCode, string memory referrer)
    public
    isHuman()
    payable
    {
        require(gameStart(), "game not start");
        require(msg.value >= 1*ethWei && msg.value <= 15*ethWei, "between 1 and 15");
        require(msg.value == msg.value.div(ethWei).mul(ethWei), "invalid msg value");
        require(codeRegister[inviteCode] == address(0) || codeRegister[inviteCode] == msg.sender, "can not repeat invite");

        UserGlobal storage userGlobal = userMapping[msg.sender];
        if (userGlobal.id == 0) {
            require(!compareStr(inviteCode, ""), "empty invite code");
            address referrerAddr = getUserAddressByCode(referrer);
            require(uint(referrerAddr) != 0, "referer not exist");
            require(referrerAddr != msg.sender, "referrer can't be self");
            require(!isUsed(inviteCode), "invite code is used");
        }

        Order storage order = waitOrder[rid][numOrder];
        order.user = msg.sender;
        order.amount = msg.value;
        order.inviteCode = inviteCode;
        order.referrer = referrer;

        WaitInfo storage info = waitInfo[rid][msg.sender];
        info.totalAmount += msg.value;
        require(info.totalAmount <= 15 ether, "eth amount between 1 and 15");
        info.isWait = true;
        info.seq.push(numOrder);
        info.time = now;

        codeRegister[inviteCode] = msg.sender;

        if(!waitLine){
            if(numOrder!=1){
                require(waitOrder[rid][numOrder - 1].execute, "last order not execute");
            }
            investIn(order.user, order.amount, order.inviteCode, order.referrer);
            order.execute = true;
            info.isWait = false;
            startNum += 1;
        }

        numOrder += 1;
    }

    function investIn(address usera, uint256 amount, string memory inviteCode, string memory referrer)
    private
    {
        UserGlobal storage userGlobal = userMapping[usera];
        if (userGlobal.id == 0) {
            require(!compareStr(inviteCode, ""), "empty invite code");
            address referrerAddr = getUserAddressByCode(referrer);
            extraInfo[rid][referrerAddr][1] += 1;
            require(uint(referrerAddr) != 0, "referer not exist");
            require(referrerAddr != usera, "referrer can't be self");

            require(!isUsed(inviteCode), "invite code is used");

            registerUser(usera, inviteCode, referrer);
        }

        User storage user = userRoundMapping[rid][usera];
        if (uint(user.userAddress) != 0) {
            require(user.freezeAmount.add(amount) <= 15*ethWei, "can not beyond 15 eth");
            user.allInvest = user.allInvest.add(amount);
            user.freezeAmount = user.freezeAmount.add(amount);
            user.staticLevel = getLevel(user.freezeAmount);
            user.dynamicLevel = getLineLevel(user.freezeAmount.add(user.unlockAmount));
        } else {
            user.id = userGlobal.id;
            user.userAddress = usera;
            user.freezeAmount = amount;
            user.staticLevel = getLevel(amount);
            user.allInvest = amount;
            user.dynamicLevel = getLineLevel(amount);
            user.inviteCode = userGlobal.inviteCode;
            user.referrer = userGlobal.referrer;
        }

        Invest memory invest = Invest(usera, amount, now, 0, 0);
        user.invests.push(invest);

        investCount = investCount.add(1);
        investMoney = investMoney.add(amount);
        rInvestCount[rid] = rInvestCount[rid].add(1);
        rInvestMoney[rid] = rInvestMoney[rid].add(amount);

        calculateToken(usera, amount);

        sendMoneyToUser(fivePercentWallet, amount.mul(5).div(100));  // 5%钱包
        sendMoneyToUser(twoPercentWallet, amount.mul(2).div(100));   // 2%钱包
        sendMoneyToUser(threePercentWallet, amount.mul(3).div(100)); // 3%钱包

    emit LogInvestIn(usera, userGlobal.id, amount, now, userGlobal.inviteCode, userGlobal.referrer);
    }

    function withdrawProfit()
    public
    isHuman()
    {
        require(gameStart(), "game not start");
        User storage user = userRoundMapping[rid][msg.sender];
        uint sendMoney = user.allStaticAmount.add(user.allDynamicAmount);

        bool isEnough = false;
        uint resultMoney = 0;
        (isEnough, resultMoney) = isEnoughBalance(sendMoney);
        if (!isEnough) {
            endRound();
        }

        uint256[2] storage extra = extraInfo[rid][msg.sender];
        extra[0] += resultMoney;
        if(extra[0] >= user.allInvest) {
            if(user.allInvest > (extra[0] - resultMoney)){
                resultMoney = user.allInvest - (extra[0] - resultMoney);
            } else {
                resultMoney = 0;
            }
        }

        if (resultMoney > 0) {
            sendMoneyToUser(eggAddress, resultMoney.mul(10).div(100));
            sendMoneyToUser(msg.sender, resultMoney.mul(90).div(100));
            user.allStaticAmount = 0;
            user.allDynamicAmount = 0;
            emit LogWithdrawProfit(msg.sender, user.id, resultMoney, now);
        }

    }

    function isEnoughBalance(uint sendMoney) private view returns (bool, uint){
        if (sendMoney >= address(this).balance) {
            return (false, address(this).balance);
        } else {
            return (true, sendMoney);
        }
    }

    function sendMoneyToUser(address payable userAddress, uint money) private {
        userAddress.transfer(money);
    }

    function calStaticProfit(address userAddr) external onlyWhitelistAdmin returns(uint)
    {
        return calStaticProfitInner(userAddr);
    }

    function calStaticProfitInner(address userAddr) private returns(uint)
    {
        User storage user = userRoundMapping[rid][userAddr];
        if (user.id == 0) {
            return 0;
        }

        uint scale = getScByLevel(user.staticLevel);
        uint allStatic = 0;

        if(user.hisStaticAmount.add(user.hisDynamicAmount) >=  user.allInvest){
            user.freezeAmount = 0;
            user.unlockAmount = user.allInvest;
            user.staticLevel = getLevel(user.freezeAmount);
            user.staticFlag = user.invests.length;
        } else {
            for (uint i = user.staticFlag; i < user.invests.length; i++) {
                Invest storage invest = user.invests[i];
                if(invest.day < 100) {
                    uint staticGaps = now.sub(invest.investTime).div(timeInterval.mul(1 minutes)); //TODO
                    uint unlockDay = now.sub(invest.investTime).div(timeInterval.mul(1 minutes)); // TODO
                    if (unlockDay>100) {
                        unlockDay = 100;
                        user.staticFlag++;
                    }

                    if(staticGaps > 100){
                        staticGaps = 100;
                    }
                    if (staticGaps > invest.times) {
                        allStatic += staticGaps.sub(invest.times).mul(scale).mul(invest.investAmount).div(1000);
                        invest.times = staticGaps;
                    }

                    user.freezeAmount = user.freezeAmount.sub(invest.investAmount.div(100).mul(unlockDay - invest.day).mul(profit).div(100));
                    user.unlockAmount = user.unlockAmount.add(invest.investAmount.div(100).mul(unlockDay - invest.day).mul(profit).div(100));
                    invest.day = unlockDay;
                }
            }
        }

        allStatic = allStatic.mul(coefficient).div(10);
        user.allStaticAmount = user.allStaticAmount.add(allStatic);
        user.hisStaticAmount = user.hisStaticAmount.add(allStatic);
        userRoundMapping[rid][userAddr] = user;
        return user.allStaticAmount;
    }

    function calDynamicProfit(uint start, uint end) external onlyWhitelistAdmin {
        for (uint i = start; i <= end; i++) {
            address userAddr = indexMapping[i];
            User memory user = userRoundMapping[rid][userAddr];

            if(user.allInvest > 0) {
                calStaticProfitInner(userAddr);
            }

            if (user.freezeAmount > 0) {
                uint scale = getScByLevel(user.staticLevel);
//                address reuser = addressMapping[user.referrer];
//                User memory reUser = userRoundMapping[rid][reuser];
//                if (reUser.freezeAmount > 0){
                    calUserDynamicProfit(user.referrer, user.allInvest, scale);
//                }
            }
        }
    }

    function registerUserInfo(address user, string calldata inviteCode, string calldata referrer) external onlyOwner {
        registerUser(user, inviteCode, referrer);
    }

    function calUserDynamicProfit(string memory referrer, uint money, uint shareSc) private {
        string memory tmpReferrer = referrer;

        for (uint i = 1; i <= 30; i++) {
            if (compareStr(tmpReferrer, "")) {
                break;
            }
            address tmpUserAddr = addressMapping[tmpReferrer];
            User storage calUser = userRoundMapping[rid][tmpUserAddr];

            if (calUser.freezeAmount <= 0){
                tmpReferrer = calUser.referrer;
                continue;
            }

            uint fireSc = getFireScByLevel(calUser.staticLevel);
            uint recommendSc = getRecommendScaleByLevelAndTim(calUser.dynamicLevel, i);
            uint moneyResult = 0;
            if (money <= calUser.freezeAmount.add(calUser.unlockAmount)) {
                moneyResult = money;
            } else {
                moneyResult = calUser.freezeAmount.add(calUser.unlockAmount);
            }

            if (recommendSc != 0) {
                uint tmpDynamicAmount = moneyResult.mul(shareSc).mul(fireSc).mul(recommendSc);
                tmpDynamicAmount = tmpDynamicAmount.div(1000).div(10).div(100);

                tmpDynamicAmount = tmpDynamicAmount.mul(coefficient).div(10);
                calUser.allDynamicAmount = calUser.allDynamicAmount.add(tmpDynamicAmount);
                calUser.hisDynamicAmount = calUser.hisDynamicAmount.add(tmpDynamicAmount);
            }

            tmpReferrer = calUser.referrer;
        }
    }

    function redeem()
    public
    isHuman()
    {
        withdrawProfit();
        require(gameStart(), "game not start");
        User storage user = userRoundMapping[rid][msg.sender];
        require(user.id > 0, "user not exist");

        calStaticProfitInner(msg.sender);

        uint sendMoney = user.unlockAmount;

        bool isEnough = false;
        uint resultMoney = 0;

        (isEnough, resultMoney) = isEnoughBalance(sendMoney);

        if (!isEnough) {
            endRound();
        }

        if (resultMoney > 0) {
            require(resultMoney <= user.allInvest,"redeem money can not be 0");
            sendMoneyToUser(msg.sender, resultMoney); // 游戏结束
            delete waitInfo[rid][msg.sender];

            user.staticLevel = 0;
            user.dynamicLevel = 0;
            user.allInvest = 0;
            user.freezeAmount = 0;
            user.unlockAmount = 0;
            user.allStaticAmount = 0;
            user.allDynamicAmount = 0;
            user.hisStaticAmount = 0;
            user.hisDynamicAmount = 0;
            user.staticFlag = 0;
            user.invests.length = 0;

            extraInfo[rid][msg.sender][0] = 0;

            emit LogRedeem(msg.sender, user.id, resultMoney, now);
        }
    }

    function endRound() private {
        rid++;
        startTime = now.add(period).div(1 days).mul(1 days);
        coefficient = 10;
    }

    function isUsed(string memory code) public view returns(bool) {
        address user = getUserAddressByCode(code);
        return uint(user) != 0;
    }

    function getUserAddressByCode(string memory code) public view returns(address) {
        return addressMapping[code];
    }

    function getGameInfo() public isHuman() view returns(uint, uint, uint, uint, uint, uint, uint, uint) {
        return (
        rid,
        uid,
        startTime,
        investCount,
        investMoney,
        rInvestCount[rid],
        rInvestMoney[rid],
        coefficient
        );
    }

    function getUserInfo(address user, uint roundId) public isHuman() view returns(
        uint[11] memory ct, string memory inviteCode, string memory referrer
    ) {

        if(roundId == 0){
            roundId = rid;
        }

        User memory userInfo = userRoundMapping[roundId][user];

        ct[0] = userInfo.id;
        ct[1] = userInfo.staticLevel;
        ct[2] = userInfo.dynamicLevel;
        ct[3] = userInfo.allInvest;
        ct[4] = userInfo.freezeAmount;
        ct[5] = userInfo.unlockAmount;
        ct[6] = userInfo.allStaticAmount;
        ct[7] = userInfo.allDynamicAmount;
        ct[8] = userInfo.hisStaticAmount;
        ct[9] = userInfo.hisDynamicAmount;
        ct[10] = extraInfo[rid][user][1];

        inviteCode = userInfo.inviteCode;
        referrer = userInfo.referrer;

        return (
        ct,
        inviteCode,
        referrer
        );
    }

    function getUserById(uint id) public view returns(address){
        return indexMapping[id];
    }

    function getWaitInfo(address user) public view returns (uint256 totalAmount, bool isWait, uint256 time, uint256[]  memory seq, bool wait) {
        totalAmount = waitInfo[rid][user].totalAmount;
        isWait = waitInfo[rid][user].isWait;
        time = waitInfo[rid][user].time;
        seq = waitInfo[rid][user].seq;
        wait = waitLine;
    }

    function getWaitOrder(uint256 num) public view returns (address user, uint256 amount, string memory inviteCode, string  memory referrer, bool execute) {
        user = waitOrder[rid][num].user;
        amount = waitOrder[rid][num].amount;
        inviteCode = waitOrder[rid][num].inviteCode;
        referrer = waitOrder[rid][num].referrer;
        execute = waitOrder[rid][num].execute;
    }

    function getInviteNum() public view returns(uint256 num){
        num = extraInfo[rid][msg.sender][1];
    }

    function getLatestUnlockAmount(address userAddr) public view returns(uint)
    {
        User memory user = userRoundMapping[rid][userAddr];
        uint allUnlock = user.unlockAmount;
        for (uint i = user.staticFlag; i < user.invests.length; i++) {
            Invest memory invest = user.invests[i];

            uint unlockDay = now.sub(invest.investTime).div(1 days);
            allUnlock = allUnlock.add(invest.investAmount.div(100).mul(unlockDay).mul(profit).div(100));
        }
        allUnlock = allUnlock <= user.allInvest ? allUnlock : user.allInvest;
        return allUnlock;
    }

    function registerUser(address user, string memory inviteCode, string memory referrer) private {

        uid++;
        userMapping[user].id = uid;
        userMapping[user].userAddress = user;
        userMapping[user].inviteCode = inviteCode;
        userMapping[user].referrer = referrer;

        addressMapping[inviteCode] = user;
        indexMapping[uid] = user;
    }

    function isCode(string memory invite) public view returns (bool){
        return codeRegister[invite] == address(0);
    }

    function getUid() public view returns(uint){
        return uid;
    }

    function withdrawEgg(uint256 money) external
    onlyWhitelistAdmin
    {
        if (money > address(this).balance){
            sendMoneyToUser(eggAddress, address(this).balance);
        } else {
            sendMoneyToUser(eggAddress, money);
        }
    }

    function setTimeInterval(uint256 targetTimeInterval) external onlyWhitelistAdmin{
        timeInterval = targetTimeInterval;
    }
}
