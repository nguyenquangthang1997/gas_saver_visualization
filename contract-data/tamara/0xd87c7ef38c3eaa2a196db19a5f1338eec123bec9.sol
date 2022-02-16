pragma solidity >=0.4.21 <0.6.0;

import "./SafeMath.sol";

contract Earnings {
    using SafeMath for *;

    // -------------------- mapping ------------------------ //
    mapping(address => UserWithdraw) public userWithdraw; // record user withdraw reward information

    // -------------------- variate ------------------------ //
    uint8 constant internal percent = 100;
    uint8 constant internal remain = 20;       // Static and dynamic rewards returns remain at 20 percent

    address public resonanceAddress;
    address public owner;

    // -------------------- struct ------------------------ //
    struct UserWithdraw {
        uint256 withdrawStraight; // withdraw straight eth amount
        uint256 withdrawTeam;  // withdraw team eth amount
        uint256 withdrawStatic; // withdraw static eth amount
        uint256 withdrawTerminator;//withdraw terminator amount
        uint256 withdrawNode;  // withdraw node amount
        uint256 lockEth;      // user lock eth
        uint256 activateEth;  // record user activate eth
    }

    constructor()
    public{
        owner = msg.sender;
    }

    // -------------------- modifier ------------------------ //
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    modifier onlyResonance (){
        require(msg.sender == resonanceAddress);
        _;
    }

    // -------------------- owner api ------------------------ //
    function allowResonance(address _addr) public onlyOwner() {
        resonanceAddress = _addr;
    }

    // -------------------- Resonance api ------------------------ //
    // calculate actual reinvest amount, include amount + lockEth
    function calculateReinvestAmount(
        address reinvestAddress,
        uint256 amount,
        uint256 userAmount,
        uint8 requireType)//type: 1 => straightEth, 2 => teamEth, 3 => withdrawStatic, 4 => withdrawNode
    public
    onlyResonance()
    returns (uint256)
    {
        if (requireType == 1) {
            require(amount.add((userWithdraw[reinvestAddress].withdrawStatic).mul(100).div(80)) <= userAmount);
        } else if (requireType == 2) {
            require(amount.add((userWithdraw[reinvestAddress].withdrawStraight).mul(100).div(80)) <= userAmount.add(amount));
        } else if (requireType == 3) {
            require(amount.add((userWithdraw[reinvestAddress].withdrawTeam).mul(100).div(80)) <= userAmount.add(amount));
        } else if (requireType == 5) {
            require(amount.add((userWithdraw[reinvestAddress].withdrawNode).mul(100).div(80)) <= userAmount);
        }

        //      userWithdraw[reinvestAddress].lockEth = userWithdraw[reinvestAddress].lockEth.add(amount.mul(remain).div(100));\
        uint256 _active = userWithdraw[reinvestAddress].lockEth - userWithdraw[reinvestAddress].activateEth;
        if (amount > _active) {
            userWithdraw[reinvestAddress].activateEth += _active;
            amount = amount.add(_active);
        } else {
            userWithdraw[reinvestAddress].activateEth = userWithdraw[reinvestAddress].activateEth.add(amount);
            amount = amount.mul(2);
        }

        return amount;
    }

    function routeAddLockEth(
        address withdrawAddress,
        uint256 amount,
        uint256 lockProfits,
        uint256 userRouteEth,
        uint256 routeType)
    public
    onlyResonance()
    {
        if (routeType == 1) {
            addLockEthStatic(withdrawAddress, amount, lockProfits, userRouteEth);
        } else if (routeType == 2) {
            addLockEthStraight(withdrawAddress, amount, userRouteEth);
        } else if (routeType == 3) {
            addLockEthTeam(withdrawAddress, amount, userRouteEth);
        } else if (routeType == 4) {
            addLockEthTerminator(withdrawAddress, amount, userRouteEth);
        } else if (routeType == 5) {
            addLockEthNode(withdrawAddress, amount, userRouteEth);
        }
    }

    function addLockEthStatic(address withdrawAddress, uint256 amount, uint256 lockProfits, uint256 userStatic)
    internal
    {
        require(amount.add(userWithdraw[withdrawAddress].withdrawStatic.mul(100).div(percent - remain)) <= userStatic);
        userWithdraw[withdrawAddress].lockEth += lockProfits;
        userWithdraw[withdrawAddress].withdrawStatic += amount.sub(lockProfits);
    }

    function addLockEthStraight(address withdrawAddress, uint256 amount, uint256 userStraightEth)
    internal
    {
        require(amount.add(userWithdraw[withdrawAddress].withdrawStraight.mul(100).div(percent - remain)) <= userStraightEth);
        userWithdraw[withdrawAddress].lockEth += amount.mul(remain).div(100);
        userWithdraw[withdrawAddress].withdrawStraight += amount.mul(percent - remain).div(100);
    }

    function addLockEthTeam(address withdrawAddress, uint256 amount, uint256 userTeamEth)
    internal
    {
        require(amount.add(userWithdraw[withdrawAddress].withdrawTeam.mul(100).div(percent - remain)) <= userTeamEth);
        userWithdraw[withdrawAddress].lockEth += amount.mul(remain).div(100);
        userWithdraw[withdrawAddress].withdrawTeam += amount.mul(percent - remain).div(100);
    }

    function addLockEthTerminator(address withdrawAddress, uint256 amount, uint256 withdrawAmount)
    internal
    {
        userWithdraw[withdrawAddress].lockEth += amount.mul(remain).div(100);
        userWithdraw[withdrawAddress].withdrawTerminator += withdrawAmount;
    }

    function addLockEthNode(address withdrawAddress, uint256 amount, uint256 userNodeEth)
    internal
    {
        require(amount.add(userWithdraw[withdrawAddress].withdrawNode.mul(100).div(percent - remain)) <= userNodeEth);
        userWithdraw[withdrawAddress].lockEth += amount.mul(remain).div(100);
        userWithdraw[withdrawAddress].withdrawNode += amount.mul(percent - remain).div(100);
    }


    function addActivateEth(address userAddress, uint256 amount)
    public
    onlyResonance()
    {
        uint256 _afterFounds = getAfterFounds(userAddress);
        if (amount > _afterFounds) {
            userWithdraw[userAddress].activateEth = userWithdraw[userAddress].lockEth;
        }
        else {
            userWithdraw[userAddress].activateEth += amount;
        }
    }

    function changeWithdrawTeamZero(address userAddress)
    public
    onlyResonance()
    {
        userWithdraw[userAddress].withdrawTeam = 0;
    }

    function getWithdrawStraight(address reinvestAddress)
    public
    view
    onlyResonance()
    returns (uint256)
    {
        return userWithdraw[reinvestAddress].withdrawStraight;
    }

    function getWithdrawStatic(address reinvestAddress)
    public
    view
    onlyResonance()
    returns (uint256)
    {
        return userWithdraw[reinvestAddress].withdrawStatic;
    }

    function getWithdrawTeam(address reinvestAddress)
    public
    view
    onlyResonance()
    returns (uint256)
    {
        return userWithdraw[reinvestAddress].withdrawTeam;
    }

    function getWithdrawNode(address reinvestAddress)
    public
    view
    onlyResonance()
    returns (uint256)
    {
        return userWithdraw[reinvestAddress].withdrawNode;
    }

    function getAfterFounds(address userAddress)
    public
    view
    onlyResonance()
    returns (uint256)
    {
        return userWithdraw[userAddress].lockEth - userWithdraw[userAddress].activateEth;
    }

    function getStaticAfterFounds(address reinvestAddress) public
    view
    onlyResonance()
    returns (uint256, uint256)
    {
        return (userWithdraw[reinvestAddress].withdrawStatic, userWithdraw[reinvestAddress].lockEth - userWithdraw[reinvestAddress].activateEth);
    }

    function getStaticAfterFoundsTeam(address userAddress) public
    view
    onlyResonance()
    returns (uint256, uint256, uint256)
    {
        return (userWithdraw[userAddress].withdrawStatic, userWithdraw[userAddress].lockEth - userWithdraw[userAddress].activateEth, userWithdraw[userAddress].withdrawTeam);
    }

    function getUserWithdrawInfo(address reinvestAddress) public
    view
    onlyResonance()
    returns (
        uint256 withdrawStraight,
        uint256 withdrawTeam,
        uint256 withdrawStatic,
        uint256 withdrawNode
    )
    {
        withdrawStraight = userWithdraw[reinvestAddress].withdrawStraight;
        withdrawTeam = userWithdraw[reinvestAddress].withdrawTeam;
        withdrawStatic = userWithdraw[reinvestAddress].withdrawStatic;
        withdrawNode = userWithdraw[reinvestAddress].withdrawNode;
    }

}

pragma solidity ^0.5.0;

import "./IERC20.sol";
import "./SafeMath.sol";

/**
 * @dev Implementation of the `IERC20` interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using `_mint`.
 * For a generic mechanism see `ERC20Mintable`.
 *
 * *For a detailed writeup see our guide [How to implement supply
 * mechanisms](https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226).*
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an `Approval` event is emitted on calls to `transferFrom`.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard `decreaseAllowance` and `increaseAllowance`
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See `IERC20.approve`.
 */
contract ERC20 is IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    /**
     * @dev See `IERC20.totalSupply`.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See `IERC20.balanceOf`.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See `IERC20.transfer`.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev See `IERC20.allowance`.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See `IERC20.approve`.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev See `IERC20.transferFrom`.
     *
     * Emits an `Approval` event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of `ERC20`;
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `value`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in `IERC20.approve`.
     *
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in `IERC20.approve`.
     *
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to `transfer`, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a `Transfer` event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a `Transfer` event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

     /**
     * @dev Destoys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a `Transfer` event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an `Approval` event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Destoys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See `_burn` and `_approve`.
     */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount));
    }
}

pragma solidity ^0.5.0;

import "./ERC20.sol";

/**
 * @dev Extension of `ERC20` that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
contract ERC20Burnable is ERC20 {
    /**
     * @dev Destoys `amount` tokens from the caller.
     *
     * See `ERC20._burn`.
     */
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    /**
     * @dev See `ERC20._burnFrom`.
     */
    function burnFrom(address account, uint256 amount) public {
        _burnFrom(account, amount);
    }
}

pragma solidity ^0.5.0;

import "./ERC20Mintable.sol";

/**
 * @dev Extension of `ERC20Mintable` that adds a cap to the supply of tokens.
 */
contract ERC20Capped is ERC20Mintable {
    uint256 private _cap;

    /**
     * @dev Sets the value of the `cap`. This value is immutable, it can only be
     * set once during construction.
     */
    constructor (uint256 cap) public {
        require(cap > 0, "ERC20Capped: cap is 0");
        _cap = cap;
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }

    /**
     * @dev See `ERC20Mintable.mint`.
     *
     * Requirements:
     *
     * - `value` must not cause the total supply to go over the cap.
     */
    function _mint(address account, uint256 value) internal {
        require(totalSupply().add(value) <= _cap, "ERC20Capped: cap exceeded");
        super._mint(account, value);
    }
}

pragma solidity ^0.5.0;

import "./IERC20.sol";

/**
 * @dev Optional functions from the ERC20 standard.
 */
contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for `name`, `symbol`, and `decimals`. All three of
     * these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name, string memory symbol, uint8 decimals) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei.
     *
     * > Note that this information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * `IERC20.balanceOf` and `IERC20.transfer`.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

pragma solidity ^0.5.0;

import "./ERC20.sol";
import "./MinterRole.sol";

/**
 * @dev Extension of `ERC20` that adds a set of accounts with the `MinterRole`,
 * which have permission to mint (create) new tokens as they see fit.
 *
 * At construction, the deployer of the contract is the only minter.
 */
contract ERC20Mintable is ERC20, MinterRole {
    /**
     * @dev See `ERC20._mint`.
     *
     * Requirements:
     *
     * - the caller must have the `MinterRole`.
     */
    function mint(address account, uint256 amount) public onlyMinter returns (bool) {
        _mint(account, amount);
        return true;
    }
}

pragma solidity ^0.5.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see `ERC20Detailed`.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through `transferFrom`. This is
     * zero by default.
     *
     * This value changes when `approve` or `transferFrom` are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * > Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an `Approval` event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to `approve`. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity >=0.4.21 <0.6.0;

import "./ERC20.sol";
import "./ERC20Detailed.sol";
import "./ERC20Capped.sol";
import "./ERC20Burnable.sol";

// 测试用的Token
contract KOCToken is ERC20, ERC20Detailed, ERC20Burnable {

    event CreateTokenSuccess(address owner, uint256 balance);

    uint256 amount = 2100000000;
    constructor(

    )
    ERC20Burnable()
    ERC20Detailed("KOC", "KOC", 18)
    ERC20()
    public
    {
        _mint(msg.sender, amount * (10 ** 18));
        emit CreateTokenSuccess(msg.sender, balanceOf(msg.sender));
    }
}

pragma solidity ^0.5.0;

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
        require(isMinter(msg.sender), "MinterRole: caller does not have the Minter role");
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

pragma solidity >=0.4.21 <0.6.0;

contract Recommend {
    // -------------------- mapping ------------------------ //
    mapping(address => RecommendRecord) internal recommendRecord;  // record straight reward information


    // -------------------- struct ------------------------ //
    struct RecommendRecord {
        uint256[] straightTime;  // this record start time, 3 days timeout
        address[] refeAddress; // referral address
        uint256[] ethAmount; // this record buy eth amount
        bool[] supported; // false means unsupported
    }

    // -------------------- variate ------------------------ //
    address public resonanceAddress;
    address public owner;

    constructor()
    public{
        owner = msg.sender;
    }

    // -------------------- modifier ------------------------ //
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    modifier onlyResonance (){
        require(msg.sender == resonanceAddress);
        _;
    }

    // -------------------- owner api ------------------------ //
    function allowResonance(address _addr) public onlyOwner() {
        resonanceAddress = _addr;
    }

    // -------------------- Resonance api ----------------//
    function getRecommendByIndex(uint256 index, address userAddress)
    public
    view
//    onlyResonance() TODO
    returns (
        uint256 straightTime,
        address refeAddress,
        uint256 ethAmount,
        bool supported
    )
    {
        straightTime = recommendRecord[userAddress].straightTime[index];
        refeAddress = recommendRecord[userAddress].refeAddress[index];
        ethAmount = recommendRecord[userAddress].ethAmount[index];
        supported = recommendRecord[userAddress].supported[index];
    }

    function pushRecommend(
        address userAddress,
        address refeAddress,
        uint256 ethAmount
    )
    public
    onlyResonance()
    {
        RecommendRecord storage _recommendRecord = recommendRecord[userAddress];
        _recommendRecord.straightTime.push(block.timestamp);
        _recommendRecord.refeAddress.push(refeAddress);
        _recommendRecord.ethAmount.push(ethAmount);
        _recommendRecord.supported.push(false);
    }

    function setSupported(uint256 index, address userAddress, bool supported)
    public
    onlyResonance()
    {
        recommendRecord[userAddress].supported[index] = supported;
    }

    // -------------------- user api ------------------------ //
    // get current address's recommend record
    function getRecommendRecord()
    public
    view
    returns (
        uint256[] memory straightTime,
        address[] memory refeAddress,
        uint256[] memory ethAmount,
        bool[]    memory supported
    )
    {
        RecommendRecord memory records = recommendRecord[msg.sender];
        straightTime = records.straightTime;
        refeAddress = records.refeAddress;
        ethAmount = records.ethAmount;
        supported = records.supported;
    }

}

pragma solidity >=0.4.21 <0.6.0;

import "./SafeMath.sol";
import "./Earnings.sol";
import "./TeamRewards.sol";
import "./Terminator.sol";
import "./Recommend.sol";

import "./ResonanceF.sol";

contract Resonance is ResonanceF {
    using SafeMath for uint256;

    uint256     public totalSupply = 0;
    uint256     constant internal bonusPrice = 0.0000001 ether; // init price
    uint256     constant internal priceIncremental = 0.00000001 ether; // increase price
    uint256     constant internal magnitude = 2 ** 64;
    uint256     public perBonusDivide = 0; //per Profit divide
    uint256     public  systemRetain = 0;
    uint256     public terminatorPoolAmount; //terminator award Pool Amount
    uint256     public activateSystem = 20;
    uint256     public activateGlobal = 20;

    mapping(address => User) public userInfo; // user define all user's information
    mapping(address => address[]) public straightInviteAddress; // user  effective straight invite address, sort reward
    mapping(address => int256) internal payoutsTo; // record
    mapping(address => uint256[11]) public userSubordinateCount;
    mapping(address => uint256) public whitelistPerformance;
    mapping(address => UserReinvest) public userReinvest;
    mapping(address => uint256) public lastStraightLength;

    uint8   constant internal remain = 20;       // Static and dynamic rewards returns remain at 20 percent
    uint32  constant internal ratio = 1000;      // eth to erc20 token ratio
    uint32  constant internal blockNumber = 40000; // straight sort reward block number
    uint256 public   currentBlockNumber;
    uint256 public   straightSortRewards = 0;
    uint256  public initAddressAmount = 0;   // The first 100 addresses and enough to 1 eth, 100 -500 enough to 5 eth, 500 addresses later cancel limit
    uint256 public totalEthAmount = 0; // all user total buy eth amount
    uint8 constant public percent = 100;

    address  public eggAddress = address(0x12d4fEcccc3cbD5F7A2C9b88D709317e0E616691);   // total eth 1 percent to  egg address
    address  public systemAddress = address(0x6074510054e37D921882B05Ab40537Ce3887F3AD);
    address  public nodeAddressReward = address(0xB351d5030603E8e89e1925f6d6F50CDa4D6754A6);
    address  public globalAddressReward = address(0x49eec1928b457d1f26a2466c8bd9eC1318EcB68f);
    address [10] public straightSort; // straight reward

    Earnings internal earningsInstance;
    TeamRewards internal teamRewardInstance;
    Terminator internal terminatorInstance;
    Recommend internal recommendInstance;

    struct User {
        address userAddress;  // user address
        uint256 ethAmount;    // user buy eth amount
        uint256 profitAmount; // user profit amount
        uint256 tokenAmount;  // user get token amount
        uint256 tokenProfit;  // profit by profitAmount
        uint256 straightEth;  // user straight eth
        uint256 lockStraight;
        uint256 teamEth;      // team eth reward
        bool staticTimeout;      // static timeout, 3 days
        uint256 staticTime;     // record static out time
        uint8 level;        // user team level
        address straightAddress;
        uint256 refeTopAmount; // subordinate address topmost eth amount
        address refeTopAddress; // subordinate address topmost eth address
    }

    struct UserReinvest {
//        uint256 nodeReinvest;
        uint256 staticReinvest;
        bool    isPush;
    }

    uint8[7] internal rewardRatio;  // [0] means market support rewards         10%
    // [1] means static rewards                 30%
    // [2] means straight rewards               30%
    // [3] means team rewards                   29%
    // [4] means terminator rewards             5%
    // [5] means straight sort rewards          5%
    // [6] means egg rewards                    1%

    uint8[11] internal teamRatio; // team reward ratio

    modifier mustAdmin (address adminAddress){
        require(adminAddress != address(0));
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3] || adminAddress == admin[4]);
        _;
    }

    modifier mustReferralAddress (address referralAddress) {
        require(msg.sender != admin[0] || msg.sender != admin[1] || msg.sender != admin[2] || msg.sender != admin[3] || msg.sender != admin[4]);
        if (teamRewardInstance.isWhitelistAddress(msg.sender)) {
            require(referralAddress == admin[0] || referralAddress == admin[1] || referralAddress == admin[2] || referralAddress == admin[3] || referralAddress == admin[4]);
        }
        _;
    }

    modifier limitInvestmentCondition(uint256 ethAmount){
         if (initAddressAmount <= 50) {
            require(ethAmount <= 5 ether);
            _;
        } else {
            _;
        }
    }

    modifier limitAddressReinvest() {
        if (initAddressAmount <= 50 && userInfo[msg.sender].ethAmount > 0) {
            require(msg.value <= userInfo[msg.sender].ethAmount.mul(3));
        }
        _;
    }
    // -------------------- modifier ------------------------ //

    // --------------------- event -------------------------- //
    event WithdrawStaticProfits(address indexed user, uint256 ethAmount);
    event Buy(address indexed user, uint256 ethAmount, uint256 buyTime);
    event Withdraw(address indexed user, uint256 ethAmount, uint8 indexed value, uint256 buyTime);
    event Reinvest(address indexed user, uint256 indexed ethAmount, uint8 indexed value, uint256 buyTime);
    event SupportSubordinateAddress(uint256 indexed index, address indexed subordinate, address indexed refeAddress, bool supported);
    // --------------------- event -------------------------- //

    constructor(
        address _erc20Address,
        address _earningsAddress,
        address _teamRewardsAddress,
        address _terminatorAddress,
        address _recommendAddress
    )
    public
    {
        earningsInstance = Earnings(_earningsAddress);
        teamRewardInstance = TeamRewards(_teamRewardsAddress);
        terminatorInstance = Terminator(_terminatorAddress);
        kocInstance = KOCToken(_erc20Address);
        recommendInstance = Recommend(_recommendAddress);
        rewardRatio = [10, 30, 30, 29, 5, 5, 1];
        teamRatio = [6, 5, 4, 3, 3, 2, 2, 1, 1, 1, 1];
        currentBlockNumber = block.number;
    }

    // -------------------- user api ----------------//
    function buy(address referralAddress)
    public
    mustReferralAddress(referralAddress)
    limitInvestmentCondition(msg.value)
    payable
    {
        require(!teamRewardInstance.getWhitelistTime());
        uint256 ethAmount = msg.value;
        address userAddress = msg.sender;
        User storage _user = userInfo[userAddress];

        _user.userAddress = userAddress;

        if (_user.ethAmount == 0 && !teamRewardInstance.isWhitelistAddress(userAddress)) {
            teamRewardInstance.referralPeople(userAddress, referralAddress);
            _user.straightAddress = referralAddress;
        } else {
            referralAddress == teamRewardInstance.getUserreferralAddress(userAddress);
        }

        address straightAddress;
        address whiteAddress;
        address adminAddress;
        bool whitelist;
        (straightAddress, whiteAddress, adminAddress, whitelist) = teamRewardInstance.getUserSystemInfo(userAddress);
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3] || adminAddress == admin[4]);

        if (userInfo[referralAddress].userAddress == address(0)) {
            userInfo[referralAddress].userAddress = referralAddress;
        }

        if (userInfo[userAddress].straightAddress == address(0)) {
            userInfo[userAddress].straightAddress = straightAddress;
        }

        // uint256 _withdrawStatic;
        uint256 _lockEth;
        uint256 _withdrawTeam;
        (, _lockEth, _withdrawTeam) = earningsInstance.getStaticAfterFoundsTeam(userAddress);

        if (ethAmount >= _lockEth) {
            ethAmount = ethAmount.add(_lockEth);
            if (userInfo[userAddress].staticTimeout && userInfo[userAddress].staticTime + 3 days < block.timestamp) {
                address(uint160(systemAddress)).transfer(userInfo[userAddress].teamEth.sub(_withdrawTeam.mul(100).div(80)));
                userInfo[userAddress].teamEth = 0;
                earningsInstance.changeWithdrawTeamZero(userAddress);
            }
            userInfo[userAddress].staticTimeout = false;
            userInfo[userAddress].staticTime = block.timestamp;
        } else {
            _lockEth = ethAmount;
            ethAmount = ethAmount.mul(2);
        }

        earningsInstance.addActivateEth(userAddress, _lockEth);
        if (initAddressAmount <= 50 && userInfo[userAddress].ethAmount > 0) {
            require(userInfo[userAddress].profitAmount == 0);
        }

        if (ethAmount >= 1 ether && _user.ethAmount == 0) {// when initAddressAmount <= 500, address can only invest once before out of static
            initAddressAmount++;
        }

        calculateBuy(_user, ethAmount, straightAddress, whiteAddress, adminAddress, userAddress);

        straightReferralReward(_user, ethAmount);
        // calculate straight referral reward

        uint256 topProfits = whetherTheCap();
        require(earningsInstance.getWithdrawStatic(msg.sender).mul(100).div(80) <= topProfits);

        emit Buy(userAddress, ethAmount, block.timestamp);
    }

    // contains some methods for buy or reinvest
    function calculateBuy(
        User storage user,
        uint256 ethAmount,
        address straightAddress,
        address whiteAddress,
        address adminAddress,
        address users
    )
    internal
    {
        require(ethAmount > 0);
        user.ethAmount = teamRewardInstance.isWhitelistAddress(user.userAddress) ? (ethAmount.mul(110).div(100)).add(user.ethAmount) : ethAmount.add(user.ethAmount);

        if (user.ethAmount > user.refeTopAmount.mul(60).div(100)) {
            user.straightEth += user.lockStraight;
            user.lockStraight = 0;
        }
        if (user.ethAmount >= 1 ether && !userReinvest[user.userAddress].isPush && !teamRewardInstance.isWhitelistAddress(user.userAddress)) {
                straightInviteAddress[straightAddress].push(user.userAddress);
                userReinvest[user.userAddress].isPush = true;
                // record straight address
            if (straightInviteAddress[straightAddress].length.sub(lastStraightLength[straightAddress]) > straightInviteAddress[straightSort[9]].length.sub(lastStraightLength[straightSort[9]])) {
                    bool has = false;
                    //search this address
                    for (uint i = 0; i < 10; i++) {
                        if (straightSort[i] == straightAddress) {
                            has = true;
                        }
                    }
                    if (!has) {
                        //search this address if not in this array,go sort after cover last
                        straightSort[9] = straightAddress;
                    }
                    // sort referral address
                    quickSort(straightSort, int(0), int(9));
                    // straightSortAddress(straightAddress);
                }
//            }

        }

        address(uint160(eggAddress)).transfer(ethAmount.mul(rewardRatio[6]).div(100));
        // transfer to eggAddress 1% eth

        straightSortRewards += ethAmount.mul(rewardRatio[5]).div(100);
        // straight sort rewards, 5% eth

        teamReferralReward(ethAmount, straightAddress);
        // issue team reward

        terminatorPoolAmount += ethAmount.mul(rewardRatio[4]).div(100);
        // issue terminator reward

        calculateToken(user, ethAmount);
        // calculate and transfer KOC token

        calculateProfit(user, ethAmount, users);
        // calculate user earn profit

        updateTeamLevel(straightAddress);
        // update team level

        totalEthAmount += ethAmount;

        whitelistPerformance[whiteAddress] += ethAmount;
        whitelistPerformance[adminAddress] += ethAmount;

        addTerminator(user.userAddress);
    }

    // contains five kinds of reinvest, 1 means reinvest static rewards, 2 means recommend rewards
    //                                  3 means team rewards,  4 means terminators rewards, 5 means node rewards
    function reinvest(uint256 amount, uint8 value)
    public
    payable
    {
        address reinvestAddress = msg.sender;

        address straightAddress;
        address whiteAddress;
        address adminAddress;
        (straightAddress, whiteAddress, adminAddress,) = teamRewardInstance.getUserSystemInfo(msg.sender);

        require(value == 1 || value == 2 || value == 3 || value == 4, "resonance 303");

        uint256 earningsProfits = 0;

        if (value == 1) {
            earningsProfits = whetherTheCap();
            uint256 _withdrawStatic;
            uint256 _afterFounds;
            uint256 _withdrawTeam;
            (_withdrawStatic, _afterFounds, _withdrawTeam) = earningsInstance.getStaticAfterFoundsTeam(reinvestAddress);

            _withdrawStatic = _withdrawStatic.mul(100).div(80);
            require(_withdrawStatic.add(userReinvest[reinvestAddress].staticReinvest).add(amount) <= earningsProfits);

            if (amount >= _afterFounds) {
                if (userInfo[reinvestAddress].staticTimeout && userInfo[reinvestAddress].staticTime + 3 days < block.timestamp) {
                    address(uint160(systemAddress)).transfer(userInfo[reinvestAddress].teamEth.sub(_withdrawTeam.mul(100).div(80)));
                    userInfo[reinvestAddress].teamEth = 0;
                    earningsInstance.changeWithdrawTeamZero(reinvestAddress);
                }
                userInfo[reinvestAddress].staticTimeout = false;
                userInfo[reinvestAddress].staticTime = block.timestamp;
            }
            userReinvest[reinvestAddress].staticReinvest += amount;
        } else if (value == 2) {
            //复投直推
            require(userInfo[reinvestAddress].straightEth >= amount);
            userInfo[reinvestAddress].straightEth = userInfo[reinvestAddress].straightEth.sub(amount);

            earningsProfits = userInfo[reinvestAddress].straightEth;
        } else if (value == 3) {
            require(userInfo[reinvestAddress].teamEth >= amount);
            userInfo[reinvestAddress].teamEth = userInfo[reinvestAddress].teamEth.sub(amount);

            earningsProfits = userInfo[reinvestAddress].teamEth;
        } else if (value == 4) {
            terminatorInstance.reInvestTerminatorReward(reinvestAddress, amount);
        }

        amount = earningsInstance.calculateReinvestAmount(msg.sender, amount, earningsProfits, value);

        calculateBuy(userInfo[reinvestAddress], amount, straightAddress, whiteAddress, adminAddress, reinvestAddress);

        straightReferralReward(userInfo[reinvestAddress], amount);

        emit Reinvest(reinvestAddress, amount, value, block.timestamp);
    }

    // contains five kinds of withdraw, 1 means withdraw static rewards, 2 means recommend rewards
    //                                  3 means team rewards,  4 means terminators rewards, 5 means node rewards
    function withdraw(uint256 amount, uint8 value)
    public
    {
        address withdrawAddress = msg.sender;
        require(value == 1 || value == 2 || value == 3 || value == 4);

        uint256 _lockProfits = 0;
        uint256 _userRouteEth = 0;
        uint256 transValue = amount.mul(80).div(100);

        if (value == 1) {
            _userRouteEth = whetherTheCap();
            _lockProfits = SafeMath.mul(amount, remain).div(100);
        } else if (value == 2) {
            _userRouteEth = userInfo[withdrawAddress].straightEth;
        } else if (value == 3) {
            if (userInfo[withdrawAddress].staticTimeout) {
                require(userInfo[withdrawAddress].staticTime + 3 days >= block.timestamp);
            }
            _userRouteEth = userInfo[withdrawAddress].teamEth;
        } else if (value == 4) {
            _userRouteEth = amount.mul(80).div(100);
            terminatorInstance.modifyTerminatorReward(withdrawAddress, _userRouteEth);
        }

        earningsInstance.routeAddLockEth(withdrawAddress, amount, _lockProfits, _userRouteEth, value);

        address(uint160(withdrawAddress)).transfer(transValue);

        emit Withdraw(withdrawAddress, amount, value, block.timestamp);
    }

    // referral address support subordinate, 10%
    function supportSubordinateAddress(uint256 index, address subordinate)
    public
    payable
    {
        User storage _user = userInfo[msg.sender];

        require(_user.ethAmount.sub(_user.tokenProfit.mul(100).div(120)) >= _user.refeTopAmount.mul(60).div(100));

        uint256 straightTime;
        address refeAddress;
        uint256 ethAmount;
        bool supported;
        (straightTime, refeAddress, ethAmount, supported) = recommendInstance.getRecommendByIndex(index, _user.userAddress);
        require(!supported);

        require(straightTime.add(3 days) >= block.timestamp && refeAddress == subordinate && msg.value >= ethAmount.div(10));

        if (_user.ethAmount.add(msg.value) >= _user.refeTopAmount.mul(60).div(100)) {
            _user.straightEth += ethAmount.mul(rewardRatio[2]).div(100);
        } else {
            _user.lockStraight += ethAmount.mul(rewardRatio[2]).div(100);
        }

        address straightAddress;
        address whiteAddress;
        address adminAddress;
        (straightAddress, whiteAddress, adminAddress,) = teamRewardInstance.getUserSystemInfo(subordinate);
        calculateBuy(userInfo[subordinate], msg.value, straightAddress, whiteAddress, adminAddress, subordinate);

        recommendInstance.setSupported(index, _user.userAddress, true);

        emit SupportSubordinateAddress(index, subordinate, refeAddress, supported);
    }

    // -------------------- internal function ----------------//
    // calculate team reward and issue reward
    //teamRatio = [6, 5, 4, 3, 3, 2, 2, 1, 1, 1, 1];
    function teamReferralReward(uint256 ethAmount, address referralStraightAddress)
    internal
    {
        if (teamRewardInstance.isWhitelistAddress(msg.sender)) {
            uint256 _systemRetain = ethAmount.mul(rewardRatio[3]).div(100);
            uint256 _nodeReward = _systemRetain.mul(activateSystem).div(100);
            systemRetain += _nodeReward;
            address(uint160(nodeAddressReward)).transfer(_nodeReward.mul(100 - activateGlobal).div(100));
            address(uint160(globalAddressReward)).transfer(_nodeReward.mul(activateGlobal).div(100));
            address(uint160(systemAddress)).transfer(_systemRetain.mul(100 - activateSystem).div(100));
        } else {
            uint256 _refeReward = ethAmount.mul(rewardRatio[3]).div(100);

            //system residue eth
            uint256 residueAmount = _refeReward;

            //user straight address
            User memory currentUser = userInfo[referralStraightAddress];

            //issue team reward
            for (uint8 i = 2; i <= 12; i++) {//i start at 2, end at 12
                //get straight user
                address straightAddress = currentUser.straightAddress;

                User storage currentUserStraight = userInfo[straightAddress];
                //if straight user meet requirements
                if (currentUserStraight.level >= i) {
                    uint256 currentReward = _refeReward.mul(teamRatio[i - 2]).div(29);
                    currentUserStraight.teamEth = currentUserStraight.teamEth.add(currentReward);
                    //sub reward amount
                    residueAmount = residueAmount.sub(currentReward);
                }

                currentUser = userInfo[straightAddress];
            }

            uint256 _nodeReward = residueAmount.mul(activateSystem).div(100);
            systemRetain = systemRetain.add(_nodeReward);
            address(uint160(systemAddress)).transfer(residueAmount.mul(100 - activateSystem).div(100));

            address(uint160(nodeAddressReward)).transfer(_nodeReward.mul(100 - activateGlobal).div(100));
            address(uint160(globalAddressReward)).transfer(_nodeReward.mul(activateGlobal).div(100));
        }
    }

    function updateTeamLevel(address refferAddress)
    internal
    {
        User memory currentUserStraight = userInfo[refferAddress];

        uint8 levelUpCount = 0;

        uint256 currentInviteCount = straightInviteAddress[refferAddress].length;
        if (currentInviteCount >= 2) {
            levelUpCount = 2;
        }

        if (currentInviteCount > 12) {
            currentInviteCount = 12;
        }

        uint256 lackCount = 0;
        for (uint8 j = 2; j < currentInviteCount; j++) {
            if (userSubordinateCount[refferAddress][j - 1] >= 1 + lackCount) {
                levelUpCount = j + 1;
                lackCount = 0;
            } else {
                lackCount++;
            }
        }

        if (levelUpCount > currentUserStraight.level) {
            uint8 oldLevel = userInfo[refferAddress].level;
            userInfo[refferAddress].level = levelUpCount;

            if (currentUserStraight.straightAddress != address(0)) {
                if (oldLevel > 0) {
                    if (userSubordinateCount[currentUserStraight.straightAddress][oldLevel - 1] > 0) {
                        userSubordinateCount[currentUserStraight.straightAddress][oldLevel - 1] = userSubordinateCount[currentUserStraight.straightAddress][oldLevel - 1] - 1;
                    }
                }

                userSubordinateCount[currentUserStraight.straightAddress][levelUpCount - 1] = userSubordinateCount[currentUserStraight.straightAddress][levelUpCount - 1] + 1;
                updateTeamLevel(currentUserStraight.straightAddress);
            }
        }
    }

    // calculate bonus profit
    function calculateProfit(User storage user, uint256 ethAmount, address users)
    internal
    {
        if (teamRewardInstance.isWhitelistAddress(user.userAddress)) {
            ethAmount = ethAmount.mul(110).div(100);
        }

        uint256 userBonus = ethToBonus(ethAmount);
        require(userBonus >= 0 && SafeMath.add(userBonus, totalSupply) >= totalSupply);
        totalSupply += userBonus;
        uint256 tokenDivided = SafeMath.mul(ethAmount, rewardRatio[1]).div(100);
        getPerBonusDivide(tokenDivided, userBonus, users);
        user.profitAmount += userBonus;
    }

    // get user bonus information for calculate static rewards
    function getPerBonusDivide(uint256 tokenDivided, uint256 userBonus, address users)
    public
    {
        uint256 fee = tokenDivided * magnitude;
        perBonusDivide += SafeMath.div(SafeMath.mul(tokenDivided, magnitude), totalSupply);
        //calculate every bonus earnings eth
        fee = fee - (fee - (userBonus * (tokenDivided * magnitude / (totalSupply))));

        int256 updatedPayouts = (int256) ((perBonusDivide * userBonus) - fee);

        payoutsTo[users] += updatedPayouts;
    }

    // calculate and transfer KOC token
    function calculateToken(User storage user, uint256 ethAmount)
    internal
    {
        kocInstance.transfer(user.userAddress, ethAmount.mul(ratio));
        user.tokenAmount += ethAmount.mul(ratio);
    }

    // calculate straight reward and record referral address recommendRecord
    function straightReferralReward(User memory user, uint256 ethAmount)
    internal
    {
        address _referralAddresses = user.straightAddress;
        userInfo[_referralAddresses].refeTopAmount = (userInfo[_referralAddresses].refeTopAmount > user.ethAmount) ? userInfo[_referralAddresses].refeTopAmount : user.ethAmount;
        userInfo[_referralAddresses].refeTopAddress = (userInfo[_referralAddresses].refeTopAmount > user.ethAmount) ? userInfo[_referralAddresses].refeTopAddress : user.userAddress;

        recommendInstance.pushRecommend(_referralAddresses, user.userAddress, ethAmount);

        if (teamRewardInstance.isWhitelistAddress(user.userAddress)) {
            uint256 _systemRetain = ethAmount.mul(rewardRatio[2]).div(100);

            uint256 _nodeReward = _systemRetain.mul(activateSystem).div(100);
            systemRetain += _nodeReward;
            address(uint160(systemAddress)).transfer(_systemRetain.mul(100 - activateSystem).div(100));

            address(uint160(globalAddressReward)).transfer(_nodeReward.mul(activateGlobal).div(100));
            address(uint160(nodeAddressReward)).transfer(_nodeReward.mul(100 - activateGlobal).div(100));
        }
    }

    // sort straight address, 10
    function straightSortAddress(address referralAddress)
    internal
    {
        for (uint8 i = 0; i < 10; i++) {
            if (straightInviteAddress[straightSort[i]].length.sub(lastStraightLength[straightSort[i]]) < straightInviteAddress[referralAddress].length.sub(lastStraightLength[referralAddress])) {
                address  [] memory temp;
                for (uint j = i; j < 10; j++) {
                    temp[j] = straightSort[j];
                }
                straightSort[i] = referralAddress;
                for (uint k = i; k < 9; k++) {
                    straightSort[k + 1] = temp[k];
                }
            }
        }
    }

    //sort straight address, 10
    function quickSort(address  [10] storage arr, int left, int right) internal {
        int i = left;
        int j = right;
        if (i == j) return;
        uint pivot = straightInviteAddress[arr[uint(left + (right - left) / 2)]].length.sub(lastStraightLength[arr[uint(left + (right - left) / 2)]]);
        while (i <= j) {
            while (straightInviteAddress[arr[uint(i)]].length.sub(lastStraightLength[arr[uint(i)]]) > pivot) i++;
            while (pivot > straightInviteAddress[arr[uint(j)]].length.sub(lastStraightLength[arr[uint(j)]])) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, left, j);
        if (i < right)
            quickSort(arr, i, right);
    }

    // settle straight rewards
    function settleStraightRewards()
    internal
    {
        uint256 addressAmount;
        for (uint8 i = 0; i < 10; i++) {
            addressAmount += straightInviteAddress[straightSort[i]].length - lastStraightLength[straightSort[i]];
        }

        uint256 _straightSortRewards = SafeMath.div(straightSortRewards, 2);
        uint256 perAddressReward = SafeMath.div(_straightSortRewards, addressAmount);
        for (uint8 j = 0; j < 10; j++) {
            address(uint160(straightSort[j])).transfer(SafeMath.mul(straightInviteAddress[straightSort[j]].length.sub(lastStraightLength[straightSort[j]]), perAddressReward));
            straightSortRewards = SafeMath.sub(straightSortRewards, SafeMath.mul(straightInviteAddress[straightSort[j]].length.sub(lastStraightLength[straightSort[j]]), perAddressReward));
            lastStraightLength[straightSort[j]] = straightInviteAddress[straightSort[j]].length;
        }
        delete (straightSort);
        currentBlockNumber = block.number;
    }

    // calculate bonus
    function ethToBonus(uint256 ethereum)
    internal
    view
    returns (uint256)
    {
        uint256 _price = bonusPrice * 1e18;
        // calculate by wei
        uint256 _tokensReceived =
        (
        (
        SafeMath.sub(
            (sqrt
        (
            (_price ** 2)
            +
            (2 * (priceIncremental * 1e18) * (ethereum * 1e18))
            +
            (((priceIncremental) ** 2) * (totalSupply ** 2))
            +
            (2 * (priceIncremental) * _price * totalSupply)
        )
            ), _price
        )
        ) / (priceIncremental)
        ) - (totalSupply);

        return _tokensReceived;
    }

    // utils for calculate bonus
    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    // get user bonus profits
    function myBonusProfits(address user)
    view
    public
    returns (uint256)
    {
        return (uint256) ((int256)(perBonusDivide.mul(userInfo[user].profitAmount)) - payoutsTo[user]).div(magnitude);
    }

    function whetherTheCap()
    internal
    returns (uint256)
    {
        require(userInfo[msg.sender].ethAmount.mul(120).div(100) >= userInfo[msg.sender].tokenProfit);
        uint256 _currentAmount = userInfo[msg.sender].ethAmount.sub(userInfo[msg.sender].tokenProfit.mul(100).div(120));
        uint256 topProfits = _currentAmount.mul(remain + 100).div(100);
        uint256 userProfits = myBonusProfits(msg.sender);

        if (userProfits > topProfits) {
            userInfo[msg.sender].profitAmount = 0;
            payoutsTo[msg.sender] = 0;
            userInfo[msg.sender].tokenProfit += topProfits;
            userInfo[msg.sender].staticTime = block.timestamp;
            userInfo[msg.sender].staticTimeout = true;
        }

        if (topProfits == 0) {
            topProfits = userInfo[msg.sender].tokenProfit;
        } else {
            topProfits = (userProfits >= topProfits) ? topProfits : userProfits.add(userInfo[msg.sender].tokenProfit); // not add again
        }

        return topProfits;
    }

    // -------------------- set api ---------------- //
    function setStraightSortRewards()
    public
    onlyAdmin()
    returns (bool)
    {
        require(currentBlockNumber + blockNumber < block.number);
        settleStraightRewards();
        return true;
    }

    // -------------------- get api ---------------- //
    // get straight sort list, 10 addresses
    function getStraightSortList()
    public
    view
    returns (address[10] memory)
    {
        return straightSort;
    }

    // get effective straight addresses current step
    function getStraightInviteAddress()
    public
    view
    returns (address[] memory)
    {
        return straightInviteAddress[msg.sender];
    }

    // get currentBlockNumber
    function getcurrentBlockNumber()
    public
    view
    returns (uint256){
        return currentBlockNumber;
    }

    function getPurchaseTasksInfo()
    public
    view
    returns (
        uint256 ethAmount,
        uint256 refeTopAmount,
        address refeTopAddress,
        uint256 lockStraight
    )
    {
        User memory getUser = userInfo[msg.sender];
        ethAmount = getUser.ethAmount.sub(getUser.tokenProfit.mul(100).div(120));
        refeTopAmount = getUser.refeTopAmount;
        refeTopAddress = getUser.refeTopAddress;
        lockStraight = getUser.lockStraight;
    }

    function getPersonalStatistics()
    public
    view
    returns (
        uint256 holdings,
        uint256 dividends,
        uint256 invites,
        uint8 level,
        uint256 afterFounds,
        uint256 referralRewards,
        uint256 teamRewards,
        uint256 nodeRewards
    )
    {
        User memory getUser = userInfo[msg.sender];

        uint256 _withdrawStatic;
        (_withdrawStatic, afterFounds) = earningsInstance.getStaticAfterFounds(getUser.userAddress);

        holdings = getUser.ethAmount.sub(getUser.tokenProfit.mul(100).div(120));
        dividends = (myBonusProfits(msg.sender) >= holdings.mul(120).div(100)) ? holdings.mul(120).div(100) : myBonusProfits(msg.sender);
        invites = straightInviteAddress[msg.sender].length;
        level = getUser.level;
        referralRewards = getUser.straightEth;
        teamRewards = getUser.teamEth;
        uint256 _nodeRewards = (totalEthAmount == 0) ? 0 : whitelistPerformance[msg.sender].mul(systemRetain).div(totalEthAmount);
        nodeRewards = (whitelistPerformance[msg.sender] < 500 ether) ? 0 : _nodeRewards;
    }

    function getUserBalance()
    public
    view
    returns (
        uint256 staticBalance,
        uint256 recommendBalance,
        uint256 teamBalance,
        uint256 terminatorBalance,
        uint256 nodeBalance,
        uint256 totalInvest,
        uint256 totalDivided,
        uint256 withdrawDivided
    )
    {
        User memory getUser = userInfo[msg.sender];
        uint256 _currentEth = getUser.ethAmount.sub(getUser.tokenProfit.mul(100).div(120));

        uint256 withdrawStraight;
        uint256 withdrawTeam;
        uint256 withdrawStatic;
        uint256 withdrawNode;
        (withdrawStraight, withdrawTeam, withdrawStatic, withdrawNode) = earningsInstance.getUserWithdrawInfo(getUser.userAddress);

//        uint256 _staticReward = getUser.ethAmount.mul(120).div(100).sub(withdrawStatic.mul(100).div(80));
        uint256 _staticReward = (getUser.ethAmount.mul(120).div(100) > withdrawStatic.mul(100).div(80)) ? getUser.ethAmount.mul(120).div(100).sub(withdrawStatic.mul(100).div(80)) : 0;

        uint256 _staticBonus = (withdrawStatic.mul(100).div(80) < myBonusProfits(msg.sender).add(getUser.tokenProfit)) ? myBonusProfits(msg.sender).add(getUser.tokenProfit).sub(withdrawStatic.mul(100).div(80)) : 0;

        staticBalance = (myBonusProfits(getUser.userAddress) >= _currentEth.mul(remain + 100).div(100)) ? _staticReward.sub(userReinvest[getUser.userAddress].staticReinvest) : _staticBonus.sub(userReinvest[getUser.userAddress].staticReinvest);

        recommendBalance = getUser.straightEth.sub(withdrawStraight.mul(100).div(80));
        teamBalance = getUser.teamEth.sub(withdrawTeam.mul(100).div(80));
        terminatorBalance = terminatorInstance.getTerminatorRewardAmount(getUser.userAddress);
        nodeBalance = 0;
        totalInvest = getUser.ethAmount;
        totalDivided = getUser.tokenProfit.add(myBonusProfits(getUser.userAddress));
        withdrawDivided = earningsInstance.getWithdrawStatic(getUser.userAddress).mul(100).div(80);
    }

    // returns contract statistics
    function contractStatistics()
    public
    view
    returns (
        uint256 recommendRankPool,
        uint256 terminatorPool
    )
    {
        recommendRankPool = straightSortRewards;
        terminatorPool = getCurrentTerminatorAmountPool();
    }

    function listNodeBonus(address node)
    public
    view
    returns (
        address nodeAddress,
        uint256 performance
    )
    {
        nodeAddress = node;
        performance = whitelistPerformance[node];
    }

    function listRankOfRecommend()
    public
    view
    returns (
        address[10] memory _straightSort,
        uint256[10] memory _inviteNumber
    )
    {
        for (uint8 i = 0; i < 10; i++) {
            if (straightSort[i] == address(0)){
                break;
            }
            _inviteNumber[i] = straightInviteAddress[straightSort[i]].length.sub(lastStraightLength[straightSort[i]]);
        }
        _straightSort = straightSort;
    }

    // return current effective user for initAddressAmount
    function getCurrentEffectiveUser()
    public
    view
    returns (uint256)
    {
        return initAddressAmount;
    }
    function addTerminator(address addr)
    internal
    {
        uint256 allInvestAmount = userInfo[addr].ethAmount.sub(userInfo[addr].tokenProfit.mul(100).div(120));
        uint256 withdrawAmount = terminatorInstance.checkBlockWithdrawAmount(block.number);
        terminatorInstance.addTerminator(addr, allInvestAmount, block.number, (terminatorPoolAmount - withdrawAmount).div(2));
    }

    function isLockWithdraw()
    public
    view
    returns (
        bool isLock,
        uint256 lockTime
    )
    {
        isLock = userInfo[msg.sender].staticTimeout;
        lockTime = userInfo[msg.sender].staticTime;
    }

    function modifyActivateSystem(uint256 value)
    mustAdmin(msg.sender)
    public
    {
        activateSystem = value;
    }

    function modifyActivateGlobal(uint256 value)
    mustAdmin(msg.sender)
    public
    {
        activateGlobal = value;
    }

    //return Current Terminator reward pool amount
    function getCurrentTerminatorAmountPool()
    view public
    returns(uint256 amount)
    {
        return terminatorPoolAmount-terminatorInstance.checkBlockWithdrawAmount(block.number);
    }
}

pragma solidity >=0.4.21 <0.6.0;

import "./KOCToken.sol";

contract ResonanceF {
    address[5] internal admin = [address(0x8434750c01D702c9cfabb3b7C5AA2774Ee67C90D), address(0xD8e79f0D2592311E740Ff097FFb0a7eaa8cb506a), address(0x740beb9fa9CCC6e971f90c25C5D5CC77063a722D), address(0x1b5bbac599f1313dB3E8061A0A65608f62897B0C), address(0x6Fd6dF175B97d2E6D651b536761e0d36b33A9495)];

    address internal boosAddress = address(0x541f5417187981b28Ef9e7Df814b160Ae2Bcb72C);

    KOCToken  internal kocInstance;

    modifier onlyAdmin () {
        address adminAddress = msg.sender;
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3]|| adminAddress == admin[4]);
        _;
    }

    function withdrawAll()
    public
    payable
    onlyAdmin()
    {
       address(uint160(boosAddress)).transfer(address(this).balance);
       kocInstance.transfer(address(uint160(boosAddress)), kocInstance.balanceOf(address(this)));
    }
}

pragma solidity ^0.5.0;

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev Give an account access to this role.
     */
    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    /**
     * @dev Remove an account's access to this role.
     */
    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    /**
     * @dev Check if an account has this role.
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}

pragma solidity ^0.5.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

pragma solidity >=0.4.21 <0.6.0;

contract TeamRewards {

    // -------------------- mapping ------------------------ //
    mapping(address => UserSystemInfo) public userSystemInfo;// user system information mapping
    mapping(address => address[])      public whitelistAddress;   // Whitelist addresses defined at the beginning of the project

    // -------------------- array ------------------------ //
    address[5] internal admin = [address(0x8434750c01D702c9cfabb3b7C5AA2774Ee67C90D), address(0xD8e79f0D2592311E740Ff097FFb0a7eaa8cb506a), address(0x740beb9fa9CCC6e971f90c25C5D5CC77063a722D), address(0x1b5bbac599f1313dB3E8061A0A65608f62897B0C), address(0x6Fd6dF175B97d2E6D651b536761e0d36b33A9495)];

    // -------------------- variate ------------------------ //
    address public resonanceAddress;
    address public owner;
    bool    public whitelistTime;

    // -------------------- event ------------------------ //
    event TobeWhitelistAddress(address indexed user, address adminAddress);

    // -------------------- structure ------------------------ //
    // user system information
    struct UserSystemInfo {
        address userAddress;     // user address
        address straightAddress; // straight Address
        address whiteAddress;    // whiteList Address
        address adminAddress;    // admin Address
        bool whitelist;  // if whitelist
    }

    constructor()
    public{
        whitelistTime = true;
        owner = msg.sender;
    }

    // -------------------- modifier ------------------------ //
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    modifier onlyAdmin () {
        address adminAddress = msg.sender;
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3] || adminAddress == admin[4]);
        _;
    }

    modifier mustAdmin (address adminAddress){
        require(adminAddress != address(0));
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3] || adminAddress == admin[4]);
        _;
    }

    modifier onlyResonance (){
        require(msg.sender == resonanceAddress);
        _;
    }

    // -------------------- user api ----------------//
    function toBeWhitelistAddress(address adminAddress, address whitelist)
    public
    mustAdmin(adminAddress)
    onlyAdmin()
    payable
    {
        require(whitelistTime);
        require(!userSystemInfo[whitelist].whitelist);
        whitelistAddress[adminAddress].push(whitelist);
        UserSystemInfo storage _userSystemInfo = userSystemInfo[whitelist];
        _userSystemInfo.straightAddress = adminAddress;
        _userSystemInfo.whiteAddress = whitelist;
        _userSystemInfo.adminAddress = adminAddress;
        _userSystemInfo.whitelist = true;
        emit TobeWhitelistAddress(whitelist, adminAddress);
    }

    // -------------------- Resonance api ----------------//
    function referralPeople(address userAddress,address referralAddress)
    public
    onlyResonance()
    {
        UserSystemInfo storage _userSystemInfo = userSystemInfo[userAddress];
        _userSystemInfo.straightAddress = referralAddress;
        _userSystemInfo.whiteAddress = userSystemInfo[referralAddress].whiteAddress;
        _userSystemInfo.adminAddress = userSystemInfo[referralAddress].adminAddress;
    }

    function getUserSystemInfo(address userAddress)
    public
    view
    returns (
        address  straightAddress,
        address whiteAddress,
        address adminAddress,
        bool whitelist)
    {
        straightAddress = userSystemInfo[userAddress].straightAddress;
        whiteAddress = userSystemInfo[userAddress].whiteAddress;
        adminAddress = userSystemInfo[userAddress].adminAddress;
        whitelist    = userSystemInfo[userAddress].whitelist;
    }

    function getUserreferralAddress(address userAddress)
    public
    view
    onlyResonance()
    returns (address )
    {
        return userSystemInfo[userAddress].straightAddress;
    }

    // -------------------- Owner api ----------------//
    function allowResonance(address _addr) public onlyOwner() {
        resonanceAddress = _addr;
    }

    // -------------------- Admin api ---------------- //
    // set whitelist close
    function setWhitelistTime(bool off)
    public
    onlyAdmin()
    {
        whitelistTime = off;
    }

    function getWhitelistTime()
    public
    view
    returns (bool)
    {
        return whitelistTime;
    }

    // get all whitelist by admin address
    function getAdminWhitelistAddress(address adminx)
    public
    view
    returns (address[] memory)
    {
        return whitelistAddress[adminx];
    }

    // check if the user is whitelist
    function isWhitelistAddress(address user)
    public
    view
    returns (bool)
    {
        return userSystemInfo[user].whitelist;
    }

    function getStraightAddress (address userAddress)
    public
    view
    returns (address  straightAddress)
    {
        straightAddress = userSystemInfo[userAddress].straightAddress;
    }
}

pragma solidity >=0.4.21 <0.6.0;

contract Terminator {

    address terminatorOwner;     //合约拥有者
    address callOwner;           //部分方法允许调用者（主合约）

    struct recodeTerminator {
        address userAddress;     //用户地址
        uint256 amountInvest;    //用户留存在合约当中的金额
    }

    uint256 public BlockNumber;                                                           //区块高度
    uint256 public AllTerminatorInvestAmount;                                             //终结者所有用户总投入金额
    uint256 public TerminatorRewardPool;                                                  //当前终结者奖池金额
    uint256 public TerminatorRewardWithdrawPool;                                          //终结者可提现奖池金额
    uint256 public signRecodeTerminator;                                                  //标记插入位置

    recodeTerminator[50] public recodeTerminatorInfo;                                     //终结者记录数组
    mapping(address => uint256 [4]) internal terminatorAllReward;                         //用户总奖励金额和已提取的奖励金额和复投总金额
    mapping(uint256 => address[50]) internal blockAllTerminatorAddress;                   //每个区块有多少终结者
    uint256[] internal signBlockHasTerminator;                                            //产生终结者的区块数组

    //事件
    event AchieveTerminator(uint256 terminatorBlocknumber);  //成为终结者

    //初始化合约
    constructor() public{
        terminatorOwner = msg.sender;
    }

    //添加终结者（主合约调用）
    function addTerminator(address addr, uint256 amount, uint256 blockNumber, uint256 amountPool)
    public
    checkCallOwner(msg.sender)
    {
        require(amount > 0);
        require(amountPool > 0);
        if (blockNumber >= BlockNumber + 240 && BlockNumber != 0) {
            addRecodeToTerminatorArray(BlockNumber);
            signBlockHasTerminator.push(BlockNumber);
        }
        addRecodeTerminator(addr, amount, blockNumber, amountPool);
        BlockNumber = blockNumber;
    }

    //用户提取奖励（主合约调用）
    function modifyTerminatorReward(address addr, uint256 amount)
    public
    checkCallOwner(msg.sender)
    {
        require(amount <= terminatorAllReward[addr][0] - (terminatorAllReward[addr][1] * 100 / 80) - terminatorAllReward[addr][3]);
        terminatorAllReward[addr][1] += amount;
    }
    //用户复投(主合约调用)
    function reInvestTerminatorReward(address addr, uint256 amount)
    public
    checkCallOwner(msg.sender)
    {
        require(amount <= terminatorAllReward[addr][0] - (terminatorAllReward[addr][1] * 100 / 80) - terminatorAllReward[addr][3]);
        terminatorAllReward[addr][3] += amount;
    }

    //添加用户信息记录，等待触发终结者(内部调用)
    function addRecodeTerminator(address addr, uint256 amount, uint256 blockNumber, uint256 amountPool)
    internal
    {
        recodeTerminator memory t = recodeTerminator(addr, amount);
        if (blockNumber == BlockNumber) {
            if (signRecodeTerminator >= 50) {
                AllTerminatorInvestAmount -= recodeTerminatorInfo[signRecodeTerminator % 50].amountInvest;
            }
            recodeTerminatorInfo[signRecodeTerminator % 50] = t;
            signRecodeTerminator++;
            AllTerminatorInvestAmount += amount;
        } else {
            recodeTerminatorInfo[0] = t;
            signRecodeTerminator = 1;
            AllTerminatorInvestAmount = amount;
        }
        TerminatorRewardPool = amountPool;
    }
    //产生终结者，将终结者信息写入并计算奖励（内部调用）
    function addRecodeToTerminatorArray(uint256 blockNumber)
    internal
    {
        for (uint256 i = 0; i < 50; i++) {
            if (i >= signRecodeTerminator) {
                break;
            }
            address userAddress = recodeTerminatorInfo[i].userAddress;
            uint256 reward = (recodeTerminatorInfo[i].amountInvest) * (TerminatorRewardPool) / (AllTerminatorInvestAmount);

            blockAllTerminatorAddress[blockNumber][i] = userAddress;
            terminatorAllReward[userAddress][0] += reward;
            terminatorAllReward[userAddress][2] = reward;
        }
        TerminatorRewardWithdrawPool += TerminatorRewardPool;
        emit AchieveTerminator(blockNumber);
    }

    //添加主合约调用权限(合约拥有者调用)
    function addCallOwner(address addr)
    public
    checkTerminatorOwner(msg.sender)
    {
        callOwner = addr;
    }
    //根据区块高度获取获取所有获得终结者奖励地址
    function getAllTerminatorAddress(uint256 blockNumber)
    view public
    returns (address[50] memory)
    {
        return blockAllTerminatorAddress[blockNumber];
    }
    //获取最近一次获得终结者区块高度和奖励的所有用户地址和上一次获奖数量
    function getLatestTerminatorInfo()
    view public
    returns (uint256 blockNumber, address[50] memory addressArray, uint256[50] memory amountArray)
    {
        uint256 index = signBlockHasTerminator.length;

        address[50] memory rewardAddress;
        uint256[50] memory rewardAmount;
        if (index <= 0) {
            return (0, rewardAddress, rewardAmount);
        } else {
            uint256 blocks = signBlockHasTerminator[index - 1];
            rewardAddress = blockAllTerminatorAddress[blocks];
            for (uint256 i = 0; i < 50; i++) {
                if (rewardAddress[i] == address(0)) {
                    break;
                }
                rewardAmount[i] = terminatorAllReward[rewardAddress[i]][2];
            }
            return (blocks, rewardAddress, rewardAmount);
        }
    }
    //获取可提现奖励金额
    function getTerminatorRewardAmount(address addr)
    view public
    returns (uint256)
    {
        return terminatorAllReward[addr][0] - (terminatorAllReward[addr][1] * 100 / 80) - terminatorAllReward[addr][3];
    }
    //获取用户所有奖励金额和已提现金额和上一次获奖金额和复投金额
    function getUserTerminatorRewardInfo(address addr)
    view public
    returns (uint256[4] memory)
    {
        return terminatorAllReward[addr];
    }
    //获取所有产生终结者的区块数组
    function getAllTerminatorBlockNumber()
    view public
    returns (uint256[] memory){
        return signBlockHasTerminator;
    }
    //获取当次已提走奖池金额（供主合约调用）
    function checkBlockWithdrawAmount(uint256 blockNumber)
    view public
    returns (uint256)
    {
        if (blockNumber >= BlockNumber + 240 && BlockNumber != 0) {
            return (TerminatorRewardPool + TerminatorRewardWithdrawPool);
        } else {
            return (TerminatorRewardWithdrawPool);
        }
    }
    //检查合约拥有者权限
    modifier checkTerminatorOwner(address addr)
    {
        require(addr == terminatorOwner);
        _;
    }
    //检查合约调用者权限（检查是否是主合约调用）
    modifier checkCallOwner(address addr)
    {
        require(addr == callOwner || addr == terminatorOwner);
        _;
    }
}
//备注：
//部署完主合约后，需要调用该合约的addCallOwner方法，传入主合约地址，为主合约调该合约方法添加权限

pragma solidity >=0.4.21 <0.6.0;

import "./SafeMath.sol";

contract Earnings {
    using SafeMath for *;

    // -------------------- mapping ------------------------ //
    mapping(address => UserWithdraw) public userWithdraw; // record user withdraw reward information

    // -------------------- variate ------------------------ //
    uint8 constant internal percent = 100;
    uint8 constant internal remain = 20;       // Static and dynamic rewards returns remain at 20 percent

    address public resonanceAddress;
    address public owner;

    // -------------------- struct ------------------------ //
    struct UserWithdraw {
        uint256 withdrawStraight; // withdraw straight eth amount
        uint256 withdrawTeam;  // withdraw team eth amount
        uint256 withdrawStatic; // withdraw static eth amount
        uint256 withdrawTerminator;//withdraw terminator amount
        uint256 withdrawNode;  // withdraw node amount
        uint256 lockEth;      // user lock eth
        uint256 activateEth;  // record user activate eth
    }

    constructor()
    public{
        owner = msg.sender;
    }

    // -------------------- modifier ------------------------ //
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    modifier onlyResonance (){
        require(msg.sender == resonanceAddress);
        _;
    }

    // -------------------- owner api ------------------------ //
    function allowResonance(address _addr) public onlyOwner() {
        resonanceAddress = _addr;
    }

    // -------------------- Resonance api ------------------------ //
    // calculate actual reinvest amount, include amount + lockEth
    function calculateReinvestAmount(
        address reinvestAddress,
        uint256 amount,
        uint256 userAmount,
        uint8 requireType)//type: 1 => straightEth, 2 => teamEth, 3 => withdrawStatic, 4 => withdrawNode
    public
    onlyResonance()
    returns (uint256)
    {
        if (requireType == 1) {
            require(amount.add((userWithdraw[reinvestAddress].withdrawStatic).mul(100).div(80)) <= userAmount);
        } else if (requireType == 2) {
            require(amount.add((userWithdraw[reinvestAddress].withdrawStraight).mul(100).div(80)) <= userAmount.add(amount));
        } else if (requireType == 3) {
            require(amount.add((userWithdraw[reinvestAddress].withdrawTeam).mul(100).div(80)) <= userAmount.add(amount));
        } else if (requireType == 5) {
            require(amount.add((userWithdraw[reinvestAddress].withdrawNode).mul(100).div(80)) <= userAmount);
        }

        //      userWithdraw[reinvestAddress].lockEth = userWithdraw[reinvestAddress].lockEth.add(amount.mul(remain).div(100));\
        uint256 _active = userWithdraw[reinvestAddress].lockEth - userWithdraw[reinvestAddress].activateEth;
        if (amount > _active) {
            userWithdraw[reinvestAddress].activateEth += _active;
            amount = amount.add(_active);
        } else {
            userWithdraw[reinvestAddress].activateEth = userWithdraw[reinvestAddress].activateEth.add(amount);
            amount = amount.mul(2);
        }

        return amount;
    }

    function routeAddLockEth(
        address withdrawAddress,
        uint256 amount,
        uint256 lockProfits,
        uint256 userRouteEth,
        uint256 routeType)
    public
    onlyResonance()
    {
        if (routeType == 1) {
            addLockEthStatic(withdrawAddress, amount, lockProfits, userRouteEth);
        } else if (routeType == 2) {
            addLockEthStraight(withdrawAddress, amount, userRouteEth);
        } else if (routeType == 3) {
            addLockEthTeam(withdrawAddress, amount, userRouteEth);
        } else if (routeType == 4) {
            addLockEthTerminator(withdrawAddress, amount, userRouteEth);
        } else if (routeType == 5) {
            addLockEthNode(withdrawAddress, amount, userRouteEth);
        }
    }

    function addLockEthStatic(address withdrawAddress, uint256 amount, uint256 lockProfits, uint256 userStatic)
    internal
    {
        require(amount.add(userWithdraw[withdrawAddress].withdrawStatic.mul(100).div(percent - remain)) <= userStatic);
        userWithdraw[withdrawAddress].lockEth += lockProfits;
        userWithdraw[withdrawAddress].withdrawStatic += amount.sub(lockProfits);
    }

    function addLockEthStraight(address withdrawAddress, uint256 amount, uint256 userStraightEth)
    internal
    {
        require(amount.add(userWithdraw[withdrawAddress].withdrawStraight.mul(100).div(percent - remain)) <= userStraightEth);
        userWithdraw[withdrawAddress].lockEth += amount.mul(remain).div(100);
        userWithdraw[withdrawAddress].withdrawStraight += amount.mul(percent - remain).div(100);
    }

    function addLockEthTeam(address withdrawAddress, uint256 amount, uint256 userTeamEth)
    internal
    {
        require(amount.add(userWithdraw[withdrawAddress].withdrawTeam.mul(100).div(percent - remain)) <= userTeamEth);
        userWithdraw[withdrawAddress].lockEth += amount.mul(remain).div(100);
        userWithdraw[withdrawAddress].withdrawTeam += amount.mul(percent - remain).div(100);
    }

    function addLockEthTerminator(address withdrawAddress, uint256 amount, uint256 withdrawAmount)
    internal
    {
        userWithdraw[withdrawAddress].lockEth += amount.mul(remain).div(100);
        userWithdraw[withdrawAddress].withdrawTerminator += withdrawAmount;
    }

    function addLockEthNode(address withdrawAddress, uint256 amount, uint256 userNodeEth)
    internal
    {
        require(amount.add(userWithdraw[withdrawAddress].withdrawNode.mul(100).div(percent - remain)) <= userNodeEth);
        userWithdraw[withdrawAddress].lockEth += amount.mul(remain).div(100);
        userWithdraw[withdrawAddress].withdrawNode += amount.mul(percent - remain).div(100);
    }


    function addActivateEth(address userAddress, uint256 amount)
    public
    onlyResonance()
    {
        uint256 _afterFounds = getAfterFounds(userAddress);
        if (amount > _afterFounds) {
            userWithdraw[userAddress].activateEth = userWithdraw[userAddress].lockEth;
        }
        else {
            userWithdraw[userAddress].activateEth += amount;
        }
    }

    function changeWithdrawTeamZero(address userAddress)
    public
    onlyResonance()
    {
        userWithdraw[userAddress].withdrawTeam = 0;
    }

    function getWithdrawStraight(address reinvestAddress)
    public
    view
    onlyResonance()
    returns (uint256)
    {
        return userWithdraw[reinvestAddress].withdrawStraight;
    }

    function getWithdrawStatic(address reinvestAddress)
    public
    view
    onlyResonance()
    returns (uint256)
    {
        return userWithdraw[reinvestAddress].withdrawStatic;
    }

    function getWithdrawTeam(address reinvestAddress)
    public
    view
    onlyResonance()
    returns (uint256)
    {
        return userWithdraw[reinvestAddress].withdrawTeam;
    }

    function getWithdrawNode(address reinvestAddress)
    public
    view
    onlyResonance()
    returns (uint256)
    {
        return userWithdraw[reinvestAddress].withdrawNode;
    }

    function getAfterFounds(address userAddress)
    public
    view
    onlyResonance()
    returns (uint256)
    {
        return userWithdraw[userAddress].lockEth - userWithdraw[userAddress].activateEth;
    }

    function getStaticAfterFounds(address reinvestAddress) public
    view
    onlyResonance()
    returns (uint256, uint256)
    {
        return (userWithdraw[reinvestAddress].withdrawStatic, userWithdraw[reinvestAddress].lockEth - userWithdraw[reinvestAddress].activateEth);
    }

    function getStaticAfterFoundsTeam(address userAddress) public
    view
    onlyResonance()
    returns (uint256, uint256, uint256)
    {
        return (userWithdraw[userAddress].withdrawStatic, userWithdraw[userAddress].lockEth - userWithdraw[userAddress].activateEth, userWithdraw[userAddress].withdrawTeam);
    }

    function getUserWithdrawInfo(address reinvestAddress) public
    view
    onlyResonance()
    returns (
        uint256 withdrawStraight,
        uint256 withdrawTeam,
        uint256 withdrawStatic,
        uint256 withdrawNode
    )
    {
        withdrawStraight = userWithdraw[reinvestAddress].withdrawStraight;
        withdrawTeam = userWithdraw[reinvestAddress].withdrawTeam;
        withdrawStatic = userWithdraw[reinvestAddress].withdrawStatic;
        withdrawNode = userWithdraw[reinvestAddress].withdrawNode;
    }

}

pragma solidity ^0.5.0;

import "./IERC20.sol";
import "./SafeMath.sol";

/**
 * @dev Implementation of the `IERC20` interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using `_mint`.
 * For a generic mechanism see `ERC20Mintable`.
 *
 * *For a detailed writeup see our guide [How to implement supply
 * mechanisms](https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226).*
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an `Approval` event is emitted on calls to `transferFrom`.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard `decreaseAllowance` and `increaseAllowance`
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See `IERC20.approve`.
 */
contract ERC20 is IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    /**
     * @dev See `IERC20.totalSupply`.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See `IERC20.balanceOf`.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See `IERC20.transfer`.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev See `IERC20.allowance`.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See `IERC20.approve`.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev See `IERC20.transferFrom`.
     *
     * Emits an `Approval` event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of `ERC20`;
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `value`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in `IERC20.approve`.
     *
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in `IERC20.approve`.
     *
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to `transfer`, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a `Transfer` event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a `Transfer` event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

     /**
     * @dev Destoys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a `Transfer` event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an `Approval` event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Destoys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See `_burn` and `_approve`.
     */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount));
    }
}

pragma solidity ^0.5.0;

import "./ERC20.sol";

/**
 * @dev Extension of `ERC20` that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
contract ERC20Burnable is ERC20 {
    /**
     * @dev Destoys `amount` tokens from the caller.
     *
     * See `ERC20._burn`.
     */
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    /**
     * @dev See `ERC20._burnFrom`.
     */
    function burnFrom(address account, uint256 amount) public {
        _burnFrom(account, amount);
    }
}

pragma solidity ^0.5.0;

import "./ERC20Mintable.sol";

/**
 * @dev Extension of `ERC20Mintable` that adds a cap to the supply of tokens.
 */
contract ERC20Capped is ERC20Mintable {
    uint256 private _cap;

    /**
     * @dev Sets the value of the `cap`. This value is immutable, it can only be
     * set once during construction.
     */
    constructor (uint256 cap) public {
        require(cap > 0, "ERC20Capped: cap is 0");
        _cap = cap;
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }

    /**
     * @dev See `ERC20Mintable.mint`.
     *
     * Requirements:
     *
     * - `value` must not cause the total supply to go over the cap.
     */
    function _mint(address account, uint256 value) internal {
        require(totalSupply().add(value) <= _cap, "ERC20Capped: cap exceeded");
        super._mint(account, value);
    }
}

pragma solidity ^0.5.0;

import "./IERC20.sol";

/**
 * @dev Optional functions from the ERC20 standard.
 */
contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for `name`, `symbol`, and `decimals`. All three of
     * these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name, string memory symbol, uint8 decimals) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei.
     *
     * > Note that this information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * `IERC20.balanceOf` and `IERC20.transfer`.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

pragma solidity ^0.5.0;

import "./ERC20.sol";
import "./MinterRole.sol";

/**
 * @dev Extension of `ERC20` that adds a set of accounts with the `MinterRole`,
 * which have permission to mint (create) new tokens as they see fit.
 *
 * At construction, the deployer of the contract is the only minter.
 */
contract ERC20Mintable is ERC20, MinterRole {
    /**
     * @dev See `ERC20._mint`.
     *
     * Requirements:
     *
     * - the caller must have the `MinterRole`.
     */
    function mint(address account, uint256 amount) public onlyMinter returns (bool) {
        _mint(account, amount);
        return true;
    }
}

pragma solidity ^0.5.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see `ERC20Detailed`.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through `transferFrom`. This is
     * zero by default.
     *
     * This value changes when `approve` or `transferFrom` are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * > Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an `Approval` event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to `approve`. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity >=0.4.21 <0.6.0;

import "./ERC20.sol";
import "./ERC20Detailed.sol";
import "./ERC20Capped.sol";
import "./ERC20Burnable.sol";

// 测试用的Token
contract KOCToken is ERC20, ERC20Detailed, ERC20Burnable {

    event CreateTokenSuccess(address owner, uint256 balance);

    uint256 amount = 2100000000;
    constructor(

    )
    ERC20Burnable()
    ERC20Detailed("KOC", "KOC", 18)
    ERC20()
    public
    {
        _mint(msg.sender, amount * (10 ** 18));
        emit CreateTokenSuccess(msg.sender, balanceOf(msg.sender));
    }
}

pragma solidity ^0.5.0;

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
        require(isMinter(msg.sender), "MinterRole: caller does not have the Minter role");
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

pragma solidity >=0.4.21 <0.6.0;

contract Recommend {
    // -------------------- mapping ------------------------ //
    mapping(address => RecommendRecord) internal recommendRecord;  // record straight reward information


    // -------------------- struct ------------------------ //
    struct RecommendRecord {
        uint256[] straightTime;  // this record start time, 3 days timeout
        address[] refeAddress; // referral address
        uint256[] ethAmount; // this record buy eth amount
        bool[] supported; // false means unsupported
    }

    // -------------------- variate ------------------------ //
    address public resonanceAddress;
    address public owner;

    constructor()
    public{
        owner = msg.sender;
    }

    // -------------------- modifier ------------------------ //
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    modifier onlyResonance (){
        require(msg.sender == resonanceAddress);
        _;
    }

    // -------------------- owner api ------------------------ //
    function allowResonance(address _addr) public onlyOwner() {
        resonanceAddress = _addr;
    }

    // -------------------- Resonance api ----------------//
    function getRecommendByIndex(uint256 index, address userAddress)
    public
    view
//    onlyResonance() TODO
    returns (
        uint256 straightTime,
        address refeAddress,
        uint256 ethAmount,
        bool supported
    )
    {
        straightTime = recommendRecord[userAddress].straightTime[index];
        refeAddress = recommendRecord[userAddress].refeAddress[index];
        ethAmount = recommendRecord[userAddress].ethAmount[index];
        supported = recommendRecord[userAddress].supported[index];
    }

    function pushRecommend(
        address userAddress,
        address refeAddress,
        uint256 ethAmount
    )
    public
    onlyResonance()
    {
        RecommendRecord storage _recommendRecord = recommendRecord[userAddress];
        _recommendRecord.straightTime.push(block.timestamp);
        _recommendRecord.refeAddress.push(refeAddress);
        _recommendRecord.ethAmount.push(ethAmount);
        _recommendRecord.supported.push(false);
    }

    function setSupported(uint256 index, address userAddress, bool supported)
    public
    onlyResonance()
    {
        recommendRecord[userAddress].supported[index] = supported;
    }

    // -------------------- user api ------------------------ //
    // get current address's recommend record
    function getRecommendRecord()
    public
    view
    returns (
        uint256[] memory straightTime,
        address[] memory refeAddress,
        uint256[] memory ethAmount,
        bool[]    memory supported
    )
    {
        RecommendRecord memory records = recommendRecord[msg.sender];
        straightTime = records.straightTime;
        refeAddress = records.refeAddress;
        ethAmount = records.ethAmount;
        supported = records.supported;
    }

}

pragma solidity >=0.4.21 <0.6.0;

import "./SafeMath.sol";
import "./Earnings.sol";
import "./TeamRewards.sol";
import "./Terminator.sol";
import "./Recommend.sol";

import "./ResonanceF.sol";

contract Resonance is ResonanceF {
    using SafeMath for uint256;

    uint256     public totalSupply = 0;
    uint256     constant internal bonusPrice = 0.0000001 ether; // init price
    uint256     constant internal priceIncremental = 0.00000001 ether; // increase price
    uint256     constant internal magnitude = 2 ** 64;
    uint256     public perBonusDivide = 0; //per Profit divide
    uint256     public  systemRetain = 0;
    uint256     public terminatorPoolAmount; //terminator award Pool Amount
    uint256     public activateSystem = 20;
    uint256     public activateGlobal = 20;

    mapping(address => User) public userInfo; // user define all user's information
    mapping(address => address[]) public straightInviteAddress; // user  effective straight invite address, sort reward
    mapping(address => int256) internal payoutsTo; // record
    mapping(address => uint256[11]) public userSubordinateCount;
    mapping(address => uint256) public whitelistPerformance;
    mapping(address => UserReinvest) public userReinvest;
    mapping(address => uint256) public lastStraightLength;

    uint8   constant internal remain = 20;       // Static and dynamic rewards returns remain at 20 percent
    uint32  constant internal ratio = 1000;      // eth to erc20 token ratio
    uint32  constant internal blockNumber = 40000; // straight sort reward block number
    uint256 public   currentBlockNumber;
    uint256 public   straightSortRewards = 0;
    uint256  public initAddressAmount = 0;   // The first 100 addresses and enough to 1 eth, 100 -500 enough to 5 eth, 500 addresses later cancel limit
    uint256 public totalEthAmount = 0; // all user total buy eth amount
    uint8 constant public percent = 100;

    address  public eggAddress = address(0x12d4fEcccc3cbD5F7A2C9b88D709317e0E616691);   // total eth 1 percent to  egg address
    address  public systemAddress = address(0x6074510054e37D921882B05Ab40537Ce3887F3AD);
    address  public nodeAddressReward = address(0xB351d5030603E8e89e1925f6d6F50CDa4D6754A6);
    address  public globalAddressReward = address(0x49eec1928b457d1f26a2466c8bd9eC1318EcB68f);
    address [10] public straightSort; // straight reward

    Earnings internal earningsInstance;
    TeamRewards internal teamRewardInstance;
    Terminator internal terminatorInstance;
    Recommend internal recommendInstance;

    struct User {
        address userAddress;  // user address
        uint256 ethAmount;    // user buy eth amount
        uint256 profitAmount; // user profit amount
        uint256 tokenAmount;  // user get token amount
        uint256 tokenProfit;  // profit by profitAmount
        uint256 straightEth;  // user straight eth
        uint256 lockStraight;
        uint256 teamEth;      // team eth reward
        bool staticTimeout;      // static timeout, 3 days
        uint256 staticTime;     // record static out time
        uint8 level;        // user team level
        address straightAddress;
        uint256 refeTopAmount; // subordinate address topmost eth amount
        address refeTopAddress; // subordinate address topmost eth address
    }

    struct UserReinvest {
//        uint256 nodeReinvest;
        uint256 staticReinvest;
        bool    isPush;
    }

    uint8[7] internal rewardRatio;  // [0] means market support rewards         10%
    // [1] means static rewards                 30%
    // [2] means straight rewards               30%
    // [3] means team rewards                   29%
    // [4] means terminator rewards             5%
    // [5] means straight sort rewards          5%
    // [6] means egg rewards                    1%

    uint8[11] internal teamRatio; // team reward ratio

    modifier mustAdmin (address adminAddress){
        require(adminAddress != address(0));
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3] || adminAddress == admin[4]);
        _;
    }

    modifier mustReferralAddress (address referralAddress) {
        require(msg.sender != admin[0] || msg.sender != admin[1] || msg.sender != admin[2] || msg.sender != admin[3] || msg.sender != admin[4]);
        if (teamRewardInstance.isWhitelistAddress(msg.sender)) {
            require(referralAddress == admin[0] || referralAddress == admin[1] || referralAddress == admin[2] || referralAddress == admin[3] || referralAddress == admin[4]);
        }
        _;
    }

    modifier limitInvestmentCondition(uint256 ethAmount){
         if (initAddressAmount <= 50) {
            require(ethAmount <= 5 ether);
            _;
        } else {
            _;
        }
    }

    modifier limitAddressReinvest() {
        if (initAddressAmount <= 50 && userInfo[msg.sender].ethAmount > 0) {
            require(msg.value <= userInfo[msg.sender].ethAmount.mul(3));
        }
        _;
    }
    // -------------------- modifier ------------------------ //

    // --------------------- event -------------------------- //
    event WithdrawStaticProfits(address indexed user, uint256 ethAmount);
    event Buy(address indexed user, uint256 ethAmount, uint256 buyTime);
    event Withdraw(address indexed user, uint256 ethAmount, uint8 indexed value, uint256 buyTime);
    event Reinvest(address indexed user, uint256 indexed ethAmount, uint8 indexed value, uint256 buyTime);
    event SupportSubordinateAddress(uint256 indexed index, address indexed subordinate, address indexed refeAddress, bool supported);
    // --------------------- event -------------------------- //

    constructor(
        address _erc20Address,
        address _earningsAddress,
        address _teamRewardsAddress,
        address _terminatorAddress,
        address _recommendAddress
    )
    public
    {
        earningsInstance = Earnings(_earningsAddress);
        teamRewardInstance = TeamRewards(_teamRewardsAddress);
        terminatorInstance = Terminator(_terminatorAddress);
        kocInstance = KOCToken(_erc20Address);
        recommendInstance = Recommend(_recommendAddress);
        rewardRatio = [10, 30, 30, 29, 5, 5, 1];
        teamRatio = [6, 5, 4, 3, 3, 2, 2, 1, 1, 1, 1];
        currentBlockNumber = block.number;
    }

    // -------------------- user api ----------------//
    function buy(address referralAddress)
    public
    mustReferralAddress(referralAddress)
    limitInvestmentCondition(msg.value)
    payable
    {
        require(!teamRewardInstance.getWhitelistTime());
        uint256 ethAmount = msg.value;
        address userAddress = msg.sender;
        User storage _user = userInfo[userAddress];

        _user.userAddress = userAddress;

        if (_user.ethAmount == 0 && !teamRewardInstance.isWhitelistAddress(userAddress)) {
            teamRewardInstance.referralPeople(userAddress, referralAddress);
            _user.straightAddress = referralAddress;
        } else {
            referralAddress == teamRewardInstance.getUserreferralAddress(userAddress);
        }

        address straightAddress;
        address whiteAddress;
        address adminAddress;
        bool whitelist;
        (straightAddress, whiteAddress, adminAddress, whitelist) = teamRewardInstance.getUserSystemInfo(userAddress);
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3] || adminAddress == admin[4]);

        if (userInfo[referralAddress].userAddress == address(0)) {
            userInfo[referralAddress].userAddress = referralAddress;
        }

        if (userInfo[userAddress].straightAddress == address(0)) {
            userInfo[userAddress].straightAddress = straightAddress;
        }

        // uint256 _withdrawStatic;
        uint256 _lockEth;
        uint256 _withdrawTeam;
        (, _lockEth, _withdrawTeam) = earningsInstance.getStaticAfterFoundsTeam(userAddress);

        if (ethAmount >= _lockEth) {
            ethAmount = ethAmount.add(_lockEth);
            if (userInfo[userAddress].staticTimeout && userInfo[userAddress].staticTime + 3 days < block.timestamp) {
                address(uint160(systemAddress)).transfer(userInfo[userAddress].teamEth.sub(_withdrawTeam.mul(100).div(80)));
                userInfo[userAddress].teamEth = 0;
                earningsInstance.changeWithdrawTeamZero(userAddress);
            }
            userInfo[userAddress].staticTimeout = false;
            userInfo[userAddress].staticTime = block.timestamp;
        } else {
            _lockEth = ethAmount;
            ethAmount = ethAmount.mul(2);
        }

        earningsInstance.addActivateEth(userAddress, _lockEth);
        if (initAddressAmount <= 50 && userInfo[userAddress].ethAmount > 0) {
            require(userInfo[userAddress].profitAmount == 0);
        }

        if (ethAmount >= 1 ether && _user.ethAmount == 0) {// when initAddressAmount <= 500, address can only invest once before out of static
            initAddressAmount++;
        }

        calculateBuy(_user, ethAmount, straightAddress, whiteAddress, adminAddress, userAddress);

        straightReferralReward(_user, ethAmount);
        // calculate straight referral reward

        uint256 topProfits = whetherTheCap();
        require(earningsInstance.getWithdrawStatic(msg.sender).mul(100).div(80) <= topProfits);

        emit Buy(userAddress, ethAmount, block.timestamp);
    }

    // contains some methods for buy or reinvest
    function calculateBuy(
        User storage user,
        uint256 ethAmount,
        address straightAddress,
        address whiteAddress,
        address adminAddress,
        address users
    )
    internal
    {
        require(ethAmount > 0);
        user.ethAmount = teamRewardInstance.isWhitelistAddress(user.userAddress) ? (ethAmount.mul(110).div(100)).add(user.ethAmount) : ethAmount.add(user.ethAmount);

        if (user.ethAmount > user.refeTopAmount.mul(60).div(100)) {
            user.straightEth += user.lockStraight;
            user.lockStraight = 0;
        }
        if (user.ethAmount >= 1 ether && !userReinvest[user.userAddress].isPush && !teamRewardInstance.isWhitelistAddress(user.userAddress)) {
                straightInviteAddress[straightAddress].push(user.userAddress);
                userReinvest[user.userAddress].isPush = true;
                // record straight address
            if (straightInviteAddress[straightAddress].length.sub(lastStraightLength[straightAddress]) > straightInviteAddress[straightSort[9]].length.sub(lastStraightLength[straightSort[9]])) {
                    bool has = false;
                    //search this address
                    for (uint i = 0; i < 10; i++) {
                        if (straightSort[i] == straightAddress) {
                            has = true;
                        }
                    }
                    if (!has) {
                        //search this address if not in this array,go sort after cover last
                        straightSort[9] = straightAddress;
                    }
                    // sort referral address
                    quickSort(straightSort, int(0), int(9));
                    // straightSortAddress(straightAddress);
                }
//            }

        }

        address(uint160(eggAddress)).transfer(ethAmount.mul(rewardRatio[6]).div(100));
        // transfer to eggAddress 1% eth

        straightSortRewards += ethAmount.mul(rewardRatio[5]).div(100);
        // straight sort rewards, 5% eth

        teamReferralReward(ethAmount, straightAddress);
        // issue team reward

        terminatorPoolAmount += ethAmount.mul(rewardRatio[4]).div(100);
        // issue terminator reward

        calculateToken(user, ethAmount);
        // calculate and transfer KOC token

        calculateProfit(user, ethAmount, users);
        // calculate user earn profit

        updateTeamLevel(straightAddress);
        // update team level

        totalEthAmount += ethAmount;

        whitelistPerformance[whiteAddress] += ethAmount;
        whitelistPerformance[adminAddress] += ethAmount;

        addTerminator(user.userAddress);
    }

    // contains five kinds of reinvest, 1 means reinvest static rewards, 2 means recommend rewards
    //                                  3 means team rewards,  4 means terminators rewards, 5 means node rewards
    function reinvest(uint256 amount, uint8 value)
    public
    payable
    {
        address reinvestAddress = msg.sender;

        address straightAddress;
        address whiteAddress;
        address adminAddress;
        (straightAddress, whiteAddress, adminAddress,) = teamRewardInstance.getUserSystemInfo(msg.sender);

        require(value == 1 || value == 2 || value == 3 || value == 4, "resonance 303");

        uint256 earningsProfits = 0;

        if (value == 1) {
            earningsProfits = whetherTheCap();
            uint256 _withdrawStatic;
            uint256 _afterFounds;
            uint256 _withdrawTeam;
            (_withdrawStatic, _afterFounds, _withdrawTeam) = earningsInstance.getStaticAfterFoundsTeam(reinvestAddress);

            _withdrawStatic = _withdrawStatic.mul(100).div(80);
            require(_withdrawStatic.add(userReinvest[reinvestAddress].staticReinvest).add(amount) <= earningsProfits);

            if (amount >= _afterFounds) {
                if (userInfo[reinvestAddress].staticTimeout && userInfo[reinvestAddress].staticTime + 3 days < block.timestamp) {
                    address(uint160(systemAddress)).transfer(userInfo[reinvestAddress].teamEth.sub(_withdrawTeam.mul(100).div(80)));
                    userInfo[reinvestAddress].teamEth = 0;
                    earningsInstance.changeWithdrawTeamZero(reinvestAddress);
                }
                userInfo[reinvestAddress].staticTimeout = false;
                userInfo[reinvestAddress].staticTime = block.timestamp;
            }
            userReinvest[reinvestAddress].staticReinvest += amount;
        } else if (value == 2) {
            //复投直推
            require(userInfo[reinvestAddress].straightEth >= amount);
            userInfo[reinvestAddress].straightEth = userInfo[reinvestAddress].straightEth.sub(amount);

            earningsProfits = userInfo[reinvestAddress].straightEth;
        } else if (value == 3) {
            require(userInfo[reinvestAddress].teamEth >= amount);
            userInfo[reinvestAddress].teamEth = userInfo[reinvestAddress].teamEth.sub(amount);

            earningsProfits = userInfo[reinvestAddress].teamEth;
        } else if (value == 4) {
            terminatorInstance.reInvestTerminatorReward(reinvestAddress, amount);
        }

        amount = earningsInstance.calculateReinvestAmount(msg.sender, amount, earningsProfits, value);

        calculateBuy(userInfo[reinvestAddress], amount, straightAddress, whiteAddress, adminAddress, reinvestAddress);

        straightReferralReward(userInfo[reinvestAddress], amount);

        emit Reinvest(reinvestAddress, amount, value, block.timestamp);
    }

    // contains five kinds of withdraw, 1 means withdraw static rewards, 2 means recommend rewards
    //                                  3 means team rewards,  4 means terminators rewards, 5 means node rewards
    function withdraw(uint256 amount, uint8 value)
    public
    {
        address withdrawAddress = msg.sender;
        require(value == 1 || value == 2 || value == 3 || value == 4);

        uint256 _lockProfits = 0;
        uint256 _userRouteEth = 0;
        uint256 transValue = amount.mul(80).div(100);

        if (value == 1) {
            _userRouteEth = whetherTheCap();
            _lockProfits = SafeMath.mul(amount, remain).div(100);
        } else if (value == 2) {
            _userRouteEth = userInfo[withdrawAddress].straightEth;
        } else if (value == 3) {
            if (userInfo[withdrawAddress].staticTimeout) {
                require(userInfo[withdrawAddress].staticTime + 3 days >= block.timestamp);
            }
            _userRouteEth = userInfo[withdrawAddress].teamEth;
        } else if (value == 4) {
            _userRouteEth = amount.mul(80).div(100);
            terminatorInstance.modifyTerminatorReward(withdrawAddress, _userRouteEth);
        }

        earningsInstance.routeAddLockEth(withdrawAddress, amount, _lockProfits, _userRouteEth, value);

        address(uint160(withdrawAddress)).transfer(transValue);

        emit Withdraw(withdrawAddress, amount, value, block.timestamp);
    }

    // referral address support subordinate, 10%
    function supportSubordinateAddress(uint256 index, address subordinate)
    public
    payable
    {
        User storage _user = userInfo[msg.sender];

        require(_user.ethAmount.sub(_user.tokenProfit.mul(100).div(120)) >= _user.refeTopAmount.mul(60).div(100));

        uint256 straightTime;
        address refeAddress;
        uint256 ethAmount;
        bool supported;
        (straightTime, refeAddress, ethAmount, supported) = recommendInstance.getRecommendByIndex(index, _user.userAddress);
        require(!supported);

        require(straightTime.add(3 days) >= block.timestamp && refeAddress == subordinate && msg.value >= ethAmount.div(10));

        if (_user.ethAmount.add(msg.value) >= _user.refeTopAmount.mul(60).div(100)) {
            _user.straightEth += ethAmount.mul(rewardRatio[2]).div(100);
        } else {
            _user.lockStraight += ethAmount.mul(rewardRatio[2]).div(100);
        }

        address straightAddress;
        address whiteAddress;
        address adminAddress;
        (straightAddress, whiteAddress, adminAddress,) = teamRewardInstance.getUserSystemInfo(subordinate);
        calculateBuy(userInfo[subordinate], msg.value, straightAddress, whiteAddress, adminAddress, subordinate);

        recommendInstance.setSupported(index, _user.userAddress, true);

        emit SupportSubordinateAddress(index, subordinate, refeAddress, supported);
    }

    // -------------------- internal function ----------------//
    // calculate team reward and issue reward
    //teamRatio = [6, 5, 4, 3, 3, 2, 2, 1, 1, 1, 1];
    function teamReferralReward(uint256 ethAmount, address referralStraightAddress)
    internal
    {
        if (teamRewardInstance.isWhitelistAddress(msg.sender)) {
            uint256 _systemRetain = ethAmount.mul(rewardRatio[3]).div(100);
            uint256 _nodeReward = _systemRetain.mul(activateSystem).div(100);
            systemRetain += _nodeReward;
            address(uint160(nodeAddressReward)).transfer(_nodeReward.mul(100 - activateGlobal).div(100));
            address(uint160(globalAddressReward)).transfer(_nodeReward.mul(activateGlobal).div(100));
            address(uint160(systemAddress)).transfer(_systemRetain.mul(100 - activateSystem).div(100));
        } else {
            uint256 _refeReward = ethAmount.mul(rewardRatio[3]).div(100);

            //system residue eth
            uint256 residueAmount = _refeReward;

            //user straight address
            User memory currentUser = userInfo[referralStraightAddress];

            //issue team reward
            for (uint8 i = 2; i <= 12; i++) {//i start at 2, end at 12
                //get straight user
                address straightAddress = currentUser.straightAddress;

                User storage currentUserStraight = userInfo[straightAddress];
                //if straight user meet requirements
                if (currentUserStraight.level >= i) {
                    uint256 currentReward = _refeReward.mul(teamRatio[i - 2]).div(29);
                    currentUserStraight.teamEth = currentUserStraight.teamEth.add(currentReward);
                    //sub reward amount
                    residueAmount = residueAmount.sub(currentReward);
                }

                currentUser = userInfo[straightAddress];
            }

            uint256 _nodeReward = residueAmount.mul(activateSystem).div(100);
            systemRetain = systemRetain.add(_nodeReward);
            address(uint160(systemAddress)).transfer(residueAmount.mul(100 - activateSystem).div(100));

            address(uint160(nodeAddressReward)).transfer(_nodeReward.mul(100 - activateGlobal).div(100));
            address(uint160(globalAddressReward)).transfer(_nodeReward.mul(activateGlobal).div(100));
        }
    }

    function updateTeamLevel(address refferAddress)
    internal
    {
        User memory currentUserStraight = userInfo[refferAddress];

        uint8 levelUpCount = 0;

        uint256 currentInviteCount = straightInviteAddress[refferAddress].length;
        if (currentInviteCount >= 2) {
            levelUpCount = 2;
        }

        if (currentInviteCount > 12) {
            currentInviteCount = 12;
        }

        uint256 lackCount = 0;
        for (uint8 j = 2; j < currentInviteCount; j++) {
            if (userSubordinateCount[refferAddress][j - 1] >= 1 + lackCount) {
                levelUpCount = j + 1;
                lackCount = 0;
            } else {
                lackCount++;
            }
        }

        if (levelUpCount > currentUserStraight.level) {
            uint8 oldLevel = userInfo[refferAddress].level;
            userInfo[refferAddress].level = levelUpCount;

            if (currentUserStraight.straightAddress != address(0)) {
                if (oldLevel > 0) {
                    if (userSubordinateCount[currentUserStraight.straightAddress][oldLevel - 1] > 0) {
                        userSubordinateCount[currentUserStraight.straightAddress][oldLevel - 1] = userSubordinateCount[currentUserStraight.straightAddress][oldLevel - 1] - 1;
                    }
                }

                userSubordinateCount[currentUserStraight.straightAddress][levelUpCount - 1] = userSubordinateCount[currentUserStraight.straightAddress][levelUpCount - 1] + 1;
                updateTeamLevel(currentUserStraight.straightAddress);
            }
        }
    }

    // calculate bonus profit
    function calculateProfit(User storage user, uint256 ethAmount, address users)
    internal
    {
        if (teamRewardInstance.isWhitelistAddress(user.userAddress)) {
            ethAmount = ethAmount.mul(110).div(100);
        }

        uint256 userBonus = ethToBonus(ethAmount);
        require(userBonus >= 0 && SafeMath.add(userBonus, totalSupply) >= totalSupply);
        totalSupply += userBonus;
        uint256 tokenDivided = SafeMath.mul(ethAmount, rewardRatio[1]).div(100);
        getPerBonusDivide(tokenDivided, userBonus, users);
        user.profitAmount += userBonus;
    }

    // get user bonus information for calculate static rewards
    function getPerBonusDivide(uint256 tokenDivided, uint256 userBonus, address users)
    public
    {
        uint256 fee = tokenDivided * magnitude;
        perBonusDivide += SafeMath.div(SafeMath.mul(tokenDivided, magnitude), totalSupply);
        //calculate every bonus earnings eth
        fee = fee - (fee - (userBonus * (tokenDivided * magnitude / (totalSupply))));

        int256 updatedPayouts = (int256) ((perBonusDivide * userBonus) - fee);

        payoutsTo[users] += updatedPayouts;
    }

    // calculate and transfer KOC token
    function calculateToken(User storage user, uint256 ethAmount)
    internal
    {
        kocInstance.transfer(user.userAddress, ethAmount.mul(ratio));
        user.tokenAmount += ethAmount.mul(ratio);
    }

    // calculate straight reward and record referral address recommendRecord
    function straightReferralReward(User memory user, uint256 ethAmount)
    internal
    {
        address _referralAddresses = user.straightAddress;
        userInfo[_referralAddresses].refeTopAmount = (userInfo[_referralAddresses].refeTopAmount > user.ethAmount) ? userInfo[_referralAddresses].refeTopAmount : user.ethAmount;
        userInfo[_referralAddresses].refeTopAddress = (userInfo[_referralAddresses].refeTopAmount > user.ethAmount) ? userInfo[_referralAddresses].refeTopAddress : user.userAddress;

        recommendInstance.pushRecommend(_referralAddresses, user.userAddress, ethAmount);

        if (teamRewardInstance.isWhitelistAddress(user.userAddress)) {
            uint256 _systemRetain = ethAmount.mul(rewardRatio[2]).div(100);

            uint256 _nodeReward = _systemRetain.mul(activateSystem).div(100);
            systemRetain += _nodeReward;
            address(uint160(systemAddress)).transfer(_systemRetain.mul(100 - activateSystem).div(100));

            address(uint160(globalAddressReward)).transfer(_nodeReward.mul(activateGlobal).div(100));
            address(uint160(nodeAddressReward)).transfer(_nodeReward.mul(100 - activateGlobal).div(100));
        }
    }

    // sort straight address, 10
    function straightSortAddress(address referralAddress)
    internal
    {
        for (uint8 i = 0; i < 10; i++) {
            if (straightInviteAddress[straightSort[i]].length.sub(lastStraightLength[straightSort[i]]) < straightInviteAddress[referralAddress].length.sub(lastStraightLength[referralAddress])) {
                address  [] memory temp;
                for (uint j = i; j < 10; j++) {
                    temp[j] = straightSort[j];
                }
                straightSort[i] = referralAddress;
                for (uint k = i; k < 9; k++) {
                    straightSort[k + 1] = temp[k];
                }
            }
        }
    }

    //sort straight address, 10
    function quickSort(address  [10] storage arr, int left, int right) internal {
        int i = left;
        int j = right;
        if (i == j) return;
        uint pivot = straightInviteAddress[arr[uint(left + (right - left) / 2)]].length.sub(lastStraightLength[arr[uint(left + (right - left) / 2)]]);
        while (i <= j) {
            while (straightInviteAddress[arr[uint(i)]].length.sub(lastStraightLength[arr[uint(i)]]) > pivot) i++;
            while (pivot > straightInviteAddress[arr[uint(j)]].length.sub(lastStraightLength[arr[uint(j)]])) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, left, j);
        if (i < right)
            quickSort(arr, i, right);
    }

    // settle straight rewards
    function settleStraightRewards()
    internal
    {
        uint256 addressAmount;
        for (uint8 i = 0; i < 10; i++) {
            addressAmount += straightInviteAddress[straightSort[i]].length - lastStraightLength[straightSort[i]];
        }

        uint256 _straightSortRewards = SafeMath.div(straightSortRewards, 2);
        uint256 perAddressReward = SafeMath.div(_straightSortRewards, addressAmount);
        for (uint8 j = 0; j < 10; j++) {
            address(uint160(straightSort[j])).transfer(SafeMath.mul(straightInviteAddress[straightSort[j]].length.sub(lastStraightLength[straightSort[j]]), perAddressReward));
            straightSortRewards = SafeMath.sub(straightSortRewards, SafeMath.mul(straightInviteAddress[straightSort[j]].length.sub(lastStraightLength[straightSort[j]]), perAddressReward));
            lastStraightLength[straightSort[j]] = straightInviteAddress[straightSort[j]].length;
        }
        delete (straightSort);
        currentBlockNumber = block.number;
    }

    // calculate bonus
    function ethToBonus(uint256 ethereum)
    internal
    view
    returns (uint256)
    {
        uint256 _price = bonusPrice * 1e18;
        // calculate by wei
        uint256 _tokensReceived =
        (
        (
        SafeMath.sub(
            (sqrt
        (
            (_price ** 2)
            +
            (2 * (priceIncremental * 1e18) * (ethereum * 1e18))
            +
            (((priceIncremental) ** 2) * (totalSupply ** 2))
            +
            (2 * (priceIncremental) * _price * totalSupply)
        )
            ), _price
        )
        ) / (priceIncremental)
        ) - (totalSupply);

        return _tokensReceived;
    }

    // utils for calculate bonus
    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    // get user bonus profits
    function myBonusProfits(address user)
    view
    public
    returns (uint256)
    {
        return (uint256) ((int256)(perBonusDivide.mul(userInfo[user].profitAmount)) - payoutsTo[user]).div(magnitude);
    }

    function whetherTheCap()
    internal
    returns (uint256)
    {
        require(userInfo[msg.sender].ethAmount.mul(120).div(100) >= userInfo[msg.sender].tokenProfit);
        uint256 _currentAmount = userInfo[msg.sender].ethAmount.sub(userInfo[msg.sender].tokenProfit.mul(100).div(120));
        uint256 topProfits = _currentAmount.mul(remain + 100).div(100);
        uint256 userProfits = myBonusProfits(msg.sender);

        if (userProfits > topProfits) {
            userInfo[msg.sender].profitAmount = 0;
            payoutsTo[msg.sender] = 0;
            userInfo[msg.sender].tokenProfit += topProfits;
            userInfo[msg.sender].staticTime = block.timestamp;
            userInfo[msg.sender].staticTimeout = true;
        }

        if (topProfits == 0) {
            topProfits = userInfo[msg.sender].tokenProfit;
        } else {
            topProfits = (userProfits >= topProfits) ? topProfits : userProfits.add(userInfo[msg.sender].tokenProfit); // not add again
        }

        return topProfits;
    }

    // -------------------- set api ---------------- //
    function setStraightSortRewards()
    public
    onlyAdmin()
    returns (bool)
    {
        require(currentBlockNumber + blockNumber < block.number);
        settleStraightRewards();
        return true;
    }

    // -------------------- get api ---------------- //
    // get straight sort list, 10 addresses
    function getStraightSortList()
    public
    view
    returns (address[10] memory)
    {
        return straightSort;
    }

    // get effective straight addresses current step
    function getStraightInviteAddress()
    public
    view
    returns (address[] memory)
    {
        return straightInviteAddress[msg.sender];
    }

    // get currentBlockNumber
    function getcurrentBlockNumber()
    public
    view
    returns (uint256){
        return currentBlockNumber;
    }

    function getPurchaseTasksInfo()
    public
    view
    returns (
        uint256 ethAmount,
        uint256 refeTopAmount,
        address refeTopAddress,
        uint256 lockStraight
    )
    {
        User memory getUser = userInfo[msg.sender];
        ethAmount = getUser.ethAmount.sub(getUser.tokenProfit.mul(100).div(120));
        refeTopAmount = getUser.refeTopAmount;
        refeTopAddress = getUser.refeTopAddress;
        lockStraight = getUser.lockStraight;
    }

    function getPersonalStatistics()
    public
    view
    returns (
        uint256 holdings,
        uint256 dividends,
        uint256 invites,
        uint8 level,
        uint256 afterFounds,
        uint256 referralRewards,
        uint256 teamRewards,
        uint256 nodeRewards
    )
    {
        User memory getUser = userInfo[msg.sender];

        uint256 _withdrawStatic;
        (_withdrawStatic, afterFounds) = earningsInstance.getStaticAfterFounds(getUser.userAddress);

        holdings = getUser.ethAmount.sub(getUser.tokenProfit.mul(100).div(120));
        dividends = (myBonusProfits(msg.sender) >= holdings.mul(120).div(100)) ? holdings.mul(120).div(100) : myBonusProfits(msg.sender);
        invites = straightInviteAddress[msg.sender].length;
        level = getUser.level;
        referralRewards = getUser.straightEth;
        teamRewards = getUser.teamEth;
        uint256 _nodeRewards = (totalEthAmount == 0) ? 0 : whitelistPerformance[msg.sender].mul(systemRetain).div(totalEthAmount);
        nodeRewards = (whitelistPerformance[msg.sender] < 500 ether) ? 0 : _nodeRewards;
    }

    function getUserBalance()
    public
    view
    returns (
        uint256 staticBalance,
        uint256 recommendBalance,
        uint256 teamBalance,
        uint256 terminatorBalance,
        uint256 nodeBalance,
        uint256 totalInvest,
        uint256 totalDivided,
        uint256 withdrawDivided
    )
    {
        User memory getUser = userInfo[msg.sender];
        uint256 _currentEth = getUser.ethAmount.sub(getUser.tokenProfit.mul(100).div(120));

        uint256 withdrawStraight;
        uint256 withdrawTeam;
        uint256 withdrawStatic;
        uint256 withdrawNode;
        (withdrawStraight, withdrawTeam, withdrawStatic, withdrawNode) = earningsInstance.getUserWithdrawInfo(getUser.userAddress);

//        uint256 _staticReward = getUser.ethAmount.mul(120).div(100).sub(withdrawStatic.mul(100).div(80));
        uint256 _staticReward = (getUser.ethAmount.mul(120).div(100) > withdrawStatic.mul(100).div(80)) ? getUser.ethAmount.mul(120).div(100).sub(withdrawStatic.mul(100).div(80)) : 0;

        uint256 _staticBonus = (withdrawStatic.mul(100).div(80) < myBonusProfits(msg.sender).add(getUser.tokenProfit)) ? myBonusProfits(msg.sender).add(getUser.tokenProfit).sub(withdrawStatic.mul(100).div(80)) : 0;

        staticBalance = (myBonusProfits(getUser.userAddress) >= _currentEth.mul(remain + 100).div(100)) ? _staticReward.sub(userReinvest[getUser.userAddress].staticReinvest) : _staticBonus.sub(userReinvest[getUser.userAddress].staticReinvest);

        recommendBalance = getUser.straightEth.sub(withdrawStraight.mul(100).div(80));
        teamBalance = getUser.teamEth.sub(withdrawTeam.mul(100).div(80));
        terminatorBalance = terminatorInstance.getTerminatorRewardAmount(getUser.userAddress);
        nodeBalance = 0;
        totalInvest = getUser.ethAmount;
        totalDivided = getUser.tokenProfit.add(myBonusProfits(getUser.userAddress));
        withdrawDivided = earningsInstance.getWithdrawStatic(getUser.userAddress).mul(100).div(80);
    }

    // returns contract statistics
    function contractStatistics()
    public
    view
    returns (
        uint256 recommendRankPool,
        uint256 terminatorPool
    )
    {
        recommendRankPool = straightSortRewards;
        terminatorPool = getCurrentTerminatorAmountPool();
    }

    function listNodeBonus(address node)
    public
    view
    returns (
        address nodeAddress,
        uint256 performance
    )
    {
        nodeAddress = node;
        performance = whitelistPerformance[node];
    }

    function listRankOfRecommend()
    public
    view
    returns (
        address[10] memory _straightSort,
        uint256[10] memory _inviteNumber
    )
    {
        for (uint8 i = 0; i < 10; i++) {
            if (straightSort[i] == address(0)){
                break;
            }
            _inviteNumber[i] = straightInviteAddress[straightSort[i]].length.sub(lastStraightLength[straightSort[i]]);
        }
        _straightSort = straightSort;
    }

    // return current effective user for initAddressAmount
    function getCurrentEffectiveUser()
    public
    view
    returns (uint256)
    {
        return initAddressAmount;
    }
    function addTerminator(address addr)
    internal
    {
        uint256 allInvestAmount = userInfo[addr].ethAmount.sub(userInfo[addr].tokenProfit.mul(100).div(120));
        uint256 withdrawAmount = terminatorInstance.checkBlockWithdrawAmount(block.number);
        terminatorInstance.addTerminator(addr, allInvestAmount, block.number, (terminatorPoolAmount - withdrawAmount).div(2));
    }

    function isLockWithdraw()
    public
    view
    returns (
        bool isLock,
        uint256 lockTime
    )
    {
        isLock = userInfo[msg.sender].staticTimeout;
        lockTime = userInfo[msg.sender].staticTime;
    }

    function modifyActivateSystem(uint256 value)
    mustAdmin(msg.sender)
    public
    {
        activateSystem = value;
    }

    function modifyActivateGlobal(uint256 value)
    mustAdmin(msg.sender)
    public
    {
        activateGlobal = value;
    }

    //return Current Terminator reward pool amount
    function getCurrentTerminatorAmountPool()
    view public
    returns(uint256 amount)
    {
        return terminatorPoolAmount-terminatorInstance.checkBlockWithdrawAmount(block.number);
    }
}

pragma solidity >=0.4.21 <0.6.0;

import "./KOCToken.sol";

contract ResonanceF {
    address[5] internal admin = [address(0x8434750c01D702c9cfabb3b7C5AA2774Ee67C90D), address(0xD8e79f0D2592311E740Ff097FFb0a7eaa8cb506a), address(0x740beb9fa9CCC6e971f90c25C5D5CC77063a722D), address(0x1b5bbac599f1313dB3E8061A0A65608f62897B0C), address(0x6Fd6dF175B97d2E6D651b536761e0d36b33A9495)];

    address internal boosAddress = address(0x541f5417187981b28Ef9e7Df814b160Ae2Bcb72C);

    KOCToken  internal kocInstance;

    modifier onlyAdmin () {
        address adminAddress = msg.sender;
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3]|| adminAddress == admin[4]);
        _;
    }

    function withdrawAll()
    public
    payable
    onlyAdmin()
    {
       address(uint160(boosAddress)).transfer(address(this).balance);
       kocInstance.transfer(address(uint160(boosAddress)), kocInstance.balanceOf(address(this)));
    }
}

pragma solidity ^0.5.0;

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev Give an account access to this role.
     */
    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    /**
     * @dev Remove an account's access to this role.
     */
    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    /**
     * @dev Check if an account has this role.
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}

pragma solidity ^0.5.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

pragma solidity >=0.4.21 <0.6.0;

contract TeamRewards {

    // -------------------- mapping ------------------------ //
    mapping(address => UserSystemInfo) public userSystemInfo;// user system information mapping
    mapping(address => address[])      public whitelistAddress;   // Whitelist addresses defined at the beginning of the project

    // -------------------- array ------------------------ //
    address[5] internal admin = [address(0x8434750c01D702c9cfabb3b7C5AA2774Ee67C90D), address(0xD8e79f0D2592311E740Ff097FFb0a7eaa8cb506a), address(0x740beb9fa9CCC6e971f90c25C5D5CC77063a722D), address(0x1b5bbac599f1313dB3E8061A0A65608f62897B0C), address(0x6Fd6dF175B97d2E6D651b536761e0d36b33A9495)];

    // -------------------- variate ------------------------ //
    address public resonanceAddress;
    address public owner;
    bool    public whitelistTime;

    // -------------------- event ------------------------ //
    event TobeWhitelistAddress(address indexed user, address adminAddress);

    // -------------------- structure ------------------------ //
    // user system information
    struct UserSystemInfo {
        address userAddress;     // user address
        address straightAddress; // straight Address
        address whiteAddress;    // whiteList Address
        address adminAddress;    // admin Address
        bool whitelist;  // if whitelist
    }

    constructor()
    public{
        whitelistTime = true;
        owner = msg.sender;
    }

    // -------------------- modifier ------------------------ //
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    modifier onlyAdmin () {
        address adminAddress = msg.sender;
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3] || adminAddress == admin[4]);
        _;
    }

    modifier mustAdmin (address adminAddress){
        require(adminAddress != address(0));
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3] || adminAddress == admin[4]);
        _;
    }

    modifier onlyResonance (){
        require(msg.sender == resonanceAddress);
        _;
    }

    // -------------------- user api ----------------//
    function toBeWhitelistAddress(address adminAddress, address whitelist)
    public
    mustAdmin(adminAddress)
    onlyAdmin()
    payable
    {
        require(whitelistTime);
        require(!userSystemInfo[whitelist].whitelist);
        whitelistAddress[adminAddress].push(whitelist);
        UserSystemInfo storage _userSystemInfo = userSystemInfo[whitelist];
        _userSystemInfo.straightAddress = adminAddress;
        _userSystemInfo.whiteAddress = whitelist;
        _userSystemInfo.adminAddress = adminAddress;
        _userSystemInfo.whitelist = true;
        emit TobeWhitelistAddress(whitelist, adminAddress);
    }

    // -------------------- Resonance api ----------------//
    function referralPeople(address userAddress,address referralAddress)
    public
    onlyResonance()
    {
        UserSystemInfo storage _userSystemInfo = userSystemInfo[userAddress];
        _userSystemInfo.straightAddress = referralAddress;
        _userSystemInfo.whiteAddress = userSystemInfo[referralAddress].whiteAddress;
        _userSystemInfo.adminAddress = userSystemInfo[referralAddress].adminAddress;
    }

    function getUserSystemInfo(address userAddress)
    public
    view
    returns (
        address  straightAddress,
        address whiteAddress,
        address adminAddress,
        bool whitelist)
    {
        straightAddress = userSystemInfo[userAddress].straightAddress;
        whiteAddress = userSystemInfo[userAddress].whiteAddress;
        adminAddress = userSystemInfo[userAddress].adminAddress;
        whitelist    = userSystemInfo[userAddress].whitelist;
    }

    function getUserreferralAddress(address userAddress)
    public
    view
    onlyResonance()
    returns (address )
    {
        return userSystemInfo[userAddress].straightAddress;
    }

    // -------------------- Owner api ----------------//
    function allowResonance(address _addr) public onlyOwner() {
        resonanceAddress = _addr;
    }

    // -------------------- Admin api ---------------- //
    // set whitelist close
    function setWhitelistTime(bool off)
    public
    onlyAdmin()
    {
        whitelistTime = off;
    }

    function getWhitelistTime()
    public
    view
    returns (bool)
    {
        return whitelistTime;
    }

    // get all whitelist by admin address
    function getAdminWhitelistAddress(address adminx)
    public
    view
    returns (address[] memory)
    {
        return whitelistAddress[adminx];
    }

    // check if the user is whitelist
    function isWhitelistAddress(address user)
    public
    view
    returns (bool)
    {
        return userSystemInfo[user].whitelist;
    }

    function getStraightAddress (address userAddress)
    public
    view
    returns (address  straightAddress)
    {
        straightAddress = userSystemInfo[userAddress].straightAddress;
    }
}

pragma solidity >=0.4.21 <0.6.0;

contract Terminator {

    address terminatorOwner;     //合约拥有者
    address callOwner;           //部分方法允许调用者（主合约）

    struct recodeTerminator {
        address userAddress;     //用户地址
        uint256 amountInvest;    //用户留存在合约当中的金额
    }

    uint256 public BlockNumber;                                                           //区块高度
    uint256 public AllTerminatorInvestAmount;                                             //终结者所有用户总投入金额
    uint256 public TerminatorRewardPool;                                                  //当前终结者奖池金额
    uint256 public TerminatorRewardWithdrawPool;                                          //终结者可提现奖池金额
    uint256 public signRecodeTerminator;                                                  //标记插入位置

    recodeTerminator[50] public recodeTerminatorInfo;                                     //终结者记录数组
    mapping(address => uint256 [4]) internal terminatorAllReward;                         //用户总奖励金额和已提取的奖励金额和复投总金额
    mapping(uint256 => address[50]) internal blockAllTerminatorAddress;                   //每个区块有多少终结者
    uint256[] internal signBlockHasTerminator;                                            //产生终结者的区块数组

    //事件
    event AchieveTerminator(uint256 terminatorBlocknumber);  //成为终结者

    //初始化合约
    constructor() public{
        terminatorOwner = msg.sender;
    }

    //添加终结者（主合约调用）
    function addTerminator(address addr, uint256 amount, uint256 blockNumber, uint256 amountPool)
    public
    checkCallOwner(msg.sender)
    {
        require(amount > 0);
        require(amountPool > 0);
        if (blockNumber >= BlockNumber + 240 && BlockNumber != 0) {
            addRecodeToTerminatorArray(BlockNumber);
            signBlockHasTerminator.push(BlockNumber);
        }
        addRecodeTerminator(addr, amount, blockNumber, amountPool);
        BlockNumber = blockNumber;
    }

    //用户提取奖励（主合约调用）
    function modifyTerminatorReward(address addr, uint256 amount)
    public
    checkCallOwner(msg.sender)
    {
        require(amount <= terminatorAllReward[addr][0] - (terminatorAllReward[addr][1] * 100 / 80) - terminatorAllReward[addr][3]);
        terminatorAllReward[addr][1] += amount;
    }
    //用户复投(主合约调用)
    function reInvestTerminatorReward(address addr, uint256 amount)
    public
    checkCallOwner(msg.sender)
    {
        require(amount <= terminatorAllReward[addr][0] - (terminatorAllReward[addr][1] * 100 / 80) - terminatorAllReward[addr][3]);
        terminatorAllReward[addr][3] += amount;
    }

    //添加用户信息记录，等待触发终结者(内部调用)
    function addRecodeTerminator(address addr, uint256 amount, uint256 blockNumber, uint256 amountPool)
    internal
    {
        recodeTerminator memory t = recodeTerminator(addr, amount);
        if (blockNumber == BlockNumber) {
            if (signRecodeTerminator >= 50) {
                AllTerminatorInvestAmount -= recodeTerminatorInfo[signRecodeTerminator % 50].amountInvest;
            }
            recodeTerminatorInfo[signRecodeTerminator % 50] = t;
            signRecodeTerminator++;
            AllTerminatorInvestAmount += amount;
        } else {
            recodeTerminatorInfo[0] = t;
            signRecodeTerminator = 1;
            AllTerminatorInvestAmount = amount;
        }
        TerminatorRewardPool = amountPool;
    }
    //产生终结者，将终结者信息写入并计算奖励（内部调用）
    function addRecodeToTerminatorArray(uint256 blockNumber)
    internal
    {
        for (uint256 i = 0; i < 50; i++) {
            if (i >= signRecodeTerminator) {
                break;
            }
            address userAddress = recodeTerminatorInfo[i].userAddress;
            uint256 reward = (recodeTerminatorInfo[i].amountInvest) * (TerminatorRewardPool) / (AllTerminatorInvestAmount);

            blockAllTerminatorAddress[blockNumber][i] = userAddress;
            terminatorAllReward[userAddress][0] += reward;
            terminatorAllReward[userAddress][2] = reward;
        }
        TerminatorRewardWithdrawPool += TerminatorRewardPool;
        emit AchieveTerminator(blockNumber);
    }

    //添加主合约调用权限(合约拥有者调用)
    function addCallOwner(address addr)
    public
    checkTerminatorOwner(msg.sender)
    {
        callOwner = addr;
    }
    //根据区块高度获取获取所有获得终结者奖励地址
    function getAllTerminatorAddress(uint256 blockNumber)
    view public
    returns (address[50] memory)
    {
        return blockAllTerminatorAddress[blockNumber];
    }
    //获取最近一次获得终结者区块高度和奖励的所有用户地址和上一次获奖数量
    function getLatestTerminatorInfo()
    view public
    returns (uint256 blockNumber, address[50] memory addressArray, uint256[50] memory amountArray)
    {
        uint256 index = signBlockHasTerminator.length;

        address[50] memory rewardAddress;
        uint256[50] memory rewardAmount;
        if (index <= 0) {
            return (0, rewardAddress, rewardAmount);
        } else {
            uint256 blocks = signBlockHasTerminator[index - 1];
            rewardAddress = blockAllTerminatorAddress[blocks];
            for (uint256 i = 0; i < 50; i++) {
                if (rewardAddress[i] == address(0)) {
                    break;
                }
                rewardAmount[i] = terminatorAllReward[rewardAddress[i]][2];
            }
            return (blocks, rewardAddress, rewardAmount);
        }
    }
    //获取可提现奖励金额
    function getTerminatorRewardAmount(address addr)
    view public
    returns (uint256)
    {
        return terminatorAllReward[addr][0] - (terminatorAllReward[addr][1] * 100 / 80) - terminatorAllReward[addr][3];
    }
    //获取用户所有奖励金额和已提现金额和上一次获奖金额和复投金额
    function getUserTerminatorRewardInfo(address addr)
    view public
    returns (uint256[4] memory)
    {
        return terminatorAllReward[addr];
    }
    //获取所有产生终结者的区块数组
    function getAllTerminatorBlockNumber()
    view public
    returns (uint256[] memory){
        return signBlockHasTerminator;
    }
    //获取当次已提走奖池金额（供主合约调用）
    function checkBlockWithdrawAmount(uint256 blockNumber)
    view public
    returns (uint256)
    {
        if (blockNumber >= BlockNumber + 240 && BlockNumber != 0) {
            return (TerminatorRewardPool + TerminatorRewardWithdrawPool);
        } else {
            return (TerminatorRewardWithdrawPool);
        }
    }
    //检查合约拥有者权限
    modifier checkTerminatorOwner(address addr)
    {
        require(addr == terminatorOwner);
        _;
    }
    //检查合约调用者权限（检查是否是主合约调用）
    modifier checkCallOwner(address addr)
    {
        require(addr == callOwner || addr == terminatorOwner);
        _;
    }
}
//备注：
//部署完主合约后，需要调用该合约的addCallOwner方法，传入主合约地址，为主合约调该合约方法添加权限

pragma solidity >=0.4.21 <0.6.0;

import "./SafeMath.sol";

contract Earnings {
    using SafeMath for *;

    // -------------------- mapping ------------------------ //
    mapping(address => UserWithdraw) public userWithdraw; // record user withdraw reward information

    // -------------------- variate ------------------------ //
    uint8 constant internal percent = 100;
    uint8 constant internal remain = 20;       // Static and dynamic rewards returns remain at 20 percent

    address public resonanceAddress;
    address public owner;

    // -------------------- struct ------------------------ //
    struct UserWithdraw {
        uint256 withdrawStraight; // withdraw straight eth amount
        uint256 withdrawTeam;  // withdraw team eth amount
        uint256 withdrawStatic; // withdraw static eth amount
        uint256 withdrawTerminator;//withdraw terminator amount
        uint256 withdrawNode;  // withdraw node amount
        uint256 lockEth;      // user lock eth
        uint256 activateEth;  // record user activate eth
    }

    constructor()
    public{
        owner = msg.sender;
    }

    // -------------------- modifier ------------------------ //
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    modifier onlyResonance (){
        require(msg.sender == resonanceAddress);
        _;
    }

    // -------------------- owner api ------------------------ //
    function allowResonance(address _addr) public onlyOwner() {
        resonanceAddress = _addr;
    }

    // -------------------- Resonance api ------------------------ //
    // calculate actual reinvest amount, include amount + lockEth
    function calculateReinvestAmount(
        address reinvestAddress,
        uint256 amount,
        uint256 userAmount,
        uint8 requireType)//type: 1 => straightEth, 2 => teamEth, 3 => withdrawStatic, 4 => withdrawNode
    public
    onlyResonance()
    returns (uint256)
    {
        if (requireType == 1) {
            require(amount.add((userWithdraw[reinvestAddress].withdrawStatic).mul(100).div(80)) <= userAmount);
        } else if (requireType == 2) {
            require(amount.add((userWithdraw[reinvestAddress].withdrawStraight).mul(100).div(80)) <= userAmount.add(amount));
        } else if (requireType == 3) {
            require(amount.add((userWithdraw[reinvestAddress].withdrawTeam).mul(100).div(80)) <= userAmount.add(amount));
        } else if (requireType == 5) {
            require(amount.add((userWithdraw[reinvestAddress].withdrawNode).mul(100).div(80)) <= userAmount);
        }

        //      userWithdraw[reinvestAddress].lockEth = userWithdraw[reinvestAddress].lockEth.add(amount.mul(remain).div(100));\
        uint256 _active = userWithdraw[reinvestAddress].lockEth - userWithdraw[reinvestAddress].activateEth;
        if (amount > _active) {
            userWithdraw[reinvestAddress].activateEth += _active;
            amount = amount.add(_active);
        } else {
            userWithdraw[reinvestAddress].activateEth = userWithdraw[reinvestAddress].activateEth.add(amount);
            amount = amount.mul(2);
        }

        return amount;
    }

    function routeAddLockEth(
        address withdrawAddress,
        uint256 amount,
        uint256 lockProfits,
        uint256 userRouteEth,
        uint256 routeType)
    public
    onlyResonance()
    {
        if (routeType == 1) {
            addLockEthStatic(withdrawAddress, amount, lockProfits, userRouteEth);
        } else if (routeType == 2) {
            addLockEthStraight(withdrawAddress, amount, userRouteEth);
        } else if (routeType == 3) {
            addLockEthTeam(withdrawAddress, amount, userRouteEth);
        } else if (routeType == 4) {
            addLockEthTerminator(withdrawAddress, amount, userRouteEth);
        } else if (routeType == 5) {
            addLockEthNode(withdrawAddress, amount, userRouteEth);
        }
    }

    function addLockEthStatic(address withdrawAddress, uint256 amount, uint256 lockProfits, uint256 userStatic)
    internal
    {
        require(amount.add(userWithdraw[withdrawAddress].withdrawStatic.mul(100).div(percent - remain)) <= userStatic);
        userWithdraw[withdrawAddress].lockEth += lockProfits;
        userWithdraw[withdrawAddress].withdrawStatic += amount.sub(lockProfits);
    }

    function addLockEthStraight(address withdrawAddress, uint256 amount, uint256 userStraightEth)
    internal
    {
        require(amount.add(userWithdraw[withdrawAddress].withdrawStraight.mul(100).div(percent - remain)) <= userStraightEth);
        userWithdraw[withdrawAddress].lockEth += amount.mul(remain).div(100);
        userWithdraw[withdrawAddress].withdrawStraight += amount.mul(percent - remain).div(100);
    }

    function addLockEthTeam(address withdrawAddress, uint256 amount, uint256 userTeamEth)
    internal
    {
        require(amount.add(userWithdraw[withdrawAddress].withdrawTeam.mul(100).div(percent - remain)) <= userTeamEth);
        userWithdraw[withdrawAddress].lockEth += amount.mul(remain).div(100);
        userWithdraw[withdrawAddress].withdrawTeam += amount.mul(percent - remain).div(100);
    }

    function addLockEthTerminator(address withdrawAddress, uint256 amount, uint256 withdrawAmount)
    internal
    {
        userWithdraw[withdrawAddress].lockEth += amount.mul(remain).div(100);
        userWithdraw[withdrawAddress].withdrawTerminator += withdrawAmount;
    }

    function addLockEthNode(address withdrawAddress, uint256 amount, uint256 userNodeEth)
    internal
    {
        require(amount.add(userWithdraw[withdrawAddress].withdrawNode.mul(100).div(percent - remain)) <= userNodeEth);
        userWithdraw[withdrawAddress].lockEth += amount.mul(remain).div(100);
        userWithdraw[withdrawAddress].withdrawNode += amount.mul(percent - remain).div(100);
    }


    function addActivateEth(address userAddress, uint256 amount)
    public
    onlyResonance()
    {
        uint256 _afterFounds = getAfterFounds(userAddress);
        if (amount > _afterFounds) {
            userWithdraw[userAddress].activateEth = userWithdraw[userAddress].lockEth;
        }
        else {
            userWithdraw[userAddress].activateEth += amount;
        }
    }

    function changeWithdrawTeamZero(address userAddress)
    public
    onlyResonance()
    {
        userWithdraw[userAddress].withdrawTeam = 0;
    }

    function getWithdrawStraight(address reinvestAddress)
    public
    view
    onlyResonance()
    returns (uint256)
    {
        return userWithdraw[reinvestAddress].withdrawStraight;
    }

    function getWithdrawStatic(address reinvestAddress)
    public
    view
    onlyResonance()
    returns (uint256)
    {
        return userWithdraw[reinvestAddress].withdrawStatic;
    }

    function getWithdrawTeam(address reinvestAddress)
    public
    view
    onlyResonance()
    returns (uint256)
    {
        return userWithdraw[reinvestAddress].withdrawTeam;
    }

    function getWithdrawNode(address reinvestAddress)
    public
    view
    onlyResonance()
    returns (uint256)
    {
        return userWithdraw[reinvestAddress].withdrawNode;
    }

    function getAfterFounds(address userAddress)
    public
    view
    onlyResonance()
    returns (uint256)
    {
        return userWithdraw[userAddress].lockEth - userWithdraw[userAddress].activateEth;
    }

    function getStaticAfterFounds(address reinvestAddress) public
    view
    onlyResonance()
    returns (uint256, uint256)
    {
        return (userWithdraw[reinvestAddress].withdrawStatic, userWithdraw[reinvestAddress].lockEth - userWithdraw[reinvestAddress].activateEth);
    }

    function getStaticAfterFoundsTeam(address userAddress) public
    view
    onlyResonance()
    returns (uint256, uint256, uint256)
    {
        return (userWithdraw[userAddress].withdrawStatic, userWithdraw[userAddress].lockEth - userWithdraw[userAddress].activateEth, userWithdraw[userAddress].withdrawTeam);
    }

    function getUserWithdrawInfo(address reinvestAddress) public
    view
    onlyResonance()
    returns (
        uint256 withdrawStraight,
        uint256 withdrawTeam,
        uint256 withdrawStatic,
        uint256 withdrawNode
    )
    {
        withdrawStraight = userWithdraw[reinvestAddress].withdrawStraight;
        withdrawTeam = userWithdraw[reinvestAddress].withdrawTeam;
        withdrawStatic = userWithdraw[reinvestAddress].withdrawStatic;
        withdrawNode = userWithdraw[reinvestAddress].withdrawNode;
    }

}

pragma solidity ^0.5.0;

import "./IERC20.sol";
import "./SafeMath.sol";

/**
 * @dev Implementation of the `IERC20` interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using `_mint`.
 * For a generic mechanism see `ERC20Mintable`.
 *
 * *For a detailed writeup see our guide [How to implement supply
 * mechanisms](https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226).*
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an `Approval` event is emitted on calls to `transferFrom`.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard `decreaseAllowance` and `increaseAllowance`
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See `IERC20.approve`.
 */
contract ERC20 is IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    /**
     * @dev See `IERC20.totalSupply`.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See `IERC20.balanceOf`.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See `IERC20.transfer`.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev See `IERC20.allowance`.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See `IERC20.approve`.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev See `IERC20.transferFrom`.
     *
     * Emits an `Approval` event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of `ERC20`;
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `value`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in `IERC20.approve`.
     *
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in `IERC20.approve`.
     *
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to `transfer`, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a `Transfer` event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a `Transfer` event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

     /**
     * @dev Destoys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a `Transfer` event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an `Approval` event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Destoys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See `_burn` and `_approve`.
     */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount));
    }
}

pragma solidity ^0.5.0;

import "./ERC20.sol";

/**
 * @dev Extension of `ERC20` that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
contract ERC20Burnable is ERC20 {
    /**
     * @dev Destoys `amount` tokens from the caller.
     *
     * See `ERC20._burn`.
     */
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    /**
     * @dev See `ERC20._burnFrom`.
     */
    function burnFrom(address account, uint256 amount) public {
        _burnFrom(account, amount);
    }
}

pragma solidity ^0.5.0;

import "./ERC20Mintable.sol";

/**
 * @dev Extension of `ERC20Mintable` that adds a cap to the supply of tokens.
 */
contract ERC20Capped is ERC20Mintable {
    uint256 private _cap;

    /**
     * @dev Sets the value of the `cap`. This value is immutable, it can only be
     * set once during construction.
     */
    constructor (uint256 cap) public {
        require(cap > 0, "ERC20Capped: cap is 0");
        _cap = cap;
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }

    /**
     * @dev See `ERC20Mintable.mint`.
     *
     * Requirements:
     *
     * - `value` must not cause the total supply to go over the cap.
     */
    function _mint(address account, uint256 value) internal {
        require(totalSupply().add(value) <= _cap, "ERC20Capped: cap exceeded");
        super._mint(account, value);
    }
}

pragma solidity ^0.5.0;

import "./IERC20.sol";

/**
 * @dev Optional functions from the ERC20 standard.
 */
contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for `name`, `symbol`, and `decimals`. All three of
     * these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name, string memory symbol, uint8 decimals) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei.
     *
     * > Note that this information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * `IERC20.balanceOf` and `IERC20.transfer`.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

pragma solidity ^0.5.0;

import "./ERC20.sol";
import "./MinterRole.sol";

/**
 * @dev Extension of `ERC20` that adds a set of accounts with the `MinterRole`,
 * which have permission to mint (create) new tokens as they see fit.
 *
 * At construction, the deployer of the contract is the only minter.
 */
contract ERC20Mintable is ERC20, MinterRole {
    /**
     * @dev See `ERC20._mint`.
     *
     * Requirements:
     *
     * - the caller must have the `MinterRole`.
     */
    function mint(address account, uint256 amount) public onlyMinter returns (bool) {
        _mint(account, amount);
        return true;
    }
}

pragma solidity ^0.5.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see `ERC20Detailed`.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through `transferFrom`. This is
     * zero by default.
     *
     * This value changes when `approve` or `transferFrom` are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * > Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an `Approval` event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to `approve`. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity >=0.4.21 <0.6.0;

import "./ERC20.sol";
import "./ERC20Detailed.sol";
import "./ERC20Capped.sol";
import "./ERC20Burnable.sol";

// 测试用的Token
contract KOCToken is ERC20, ERC20Detailed, ERC20Burnable {

    event CreateTokenSuccess(address owner, uint256 balance);

    uint256 amount = 2100000000;
    constructor(

    )
    ERC20Burnable()
    ERC20Detailed("KOC", "KOC", 18)
    ERC20()
    public
    {
        _mint(msg.sender, amount * (10 ** 18));
        emit CreateTokenSuccess(msg.sender, balanceOf(msg.sender));
    }
}

pragma solidity ^0.5.0;

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
        require(isMinter(msg.sender), "MinterRole: caller does not have the Minter role");
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

pragma solidity >=0.4.21 <0.6.0;

contract Recommend {
    // -------------------- mapping ------------------------ //
    mapping(address => RecommendRecord) internal recommendRecord;  // record straight reward information


    // -------------------- struct ------------------------ //
    struct RecommendRecord {
        uint256[] straightTime;  // this record start time, 3 days timeout
        address[] refeAddress; // referral address
        uint256[] ethAmount; // this record buy eth amount
        bool[] supported; // false means unsupported
    }

    // -------------------- variate ------------------------ //
    address public resonanceAddress;
    address public owner;

    constructor()
    public{
        owner = msg.sender;
    }

    // -------------------- modifier ------------------------ //
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    modifier onlyResonance (){
        require(msg.sender == resonanceAddress);
        _;
    }

    // -------------------- owner api ------------------------ //
    function allowResonance(address _addr) public onlyOwner() {
        resonanceAddress = _addr;
    }

    // -------------------- Resonance api ----------------//
    function getRecommendByIndex(uint256 index, address userAddress)
    public
    view
//    onlyResonance() TODO
    returns (
        uint256 straightTime,
        address refeAddress,
        uint256 ethAmount,
        bool supported
    )
    {
        straightTime = recommendRecord[userAddress].straightTime[index];
        refeAddress = recommendRecord[userAddress].refeAddress[index];
        ethAmount = recommendRecord[userAddress].ethAmount[index];
        supported = recommendRecord[userAddress].supported[index];
    }

    function pushRecommend(
        address userAddress,
        address refeAddress,
        uint256 ethAmount
    )
    public
    onlyResonance()
    {
        RecommendRecord storage _recommendRecord = recommendRecord[userAddress];
        _recommendRecord.straightTime.push(block.timestamp);
        _recommendRecord.refeAddress.push(refeAddress);
        _recommendRecord.ethAmount.push(ethAmount);
        _recommendRecord.supported.push(false);
    }

    function setSupported(uint256 index, address userAddress, bool supported)
    public
    onlyResonance()
    {
        recommendRecord[userAddress].supported[index] = supported;
    }

    // -------------------- user api ------------------------ //
    // get current address's recommend record
    function getRecommendRecord()
    public
    view
    returns (
        uint256[] memory straightTime,
        address[] memory refeAddress,
        uint256[] memory ethAmount,
        bool[]    memory supported
    )
    {
        RecommendRecord memory records = recommendRecord[msg.sender];
        straightTime = records.straightTime;
        refeAddress = records.refeAddress;
        ethAmount = records.ethAmount;
        supported = records.supported;
    }

}

pragma solidity >=0.4.21 <0.6.0;

import "./SafeMath.sol";
import "./Earnings.sol";
import "./TeamRewards.sol";
import "./Terminator.sol";
import "./Recommend.sol";

import "./ResonanceF.sol";

contract Resonance is ResonanceF {
    using SafeMath for uint256;

    uint256     public totalSupply = 0;
    uint256     constant internal bonusPrice = 0.0000001 ether; // init price
    uint256     constant internal priceIncremental = 0.00000001 ether; // increase price
    uint256     constant internal magnitude = 2 ** 64;
    uint256     public perBonusDivide = 0; //per Profit divide
    uint256     public  systemRetain = 0;
    uint256     public terminatorPoolAmount; //terminator award Pool Amount
    uint256     public activateSystem = 20;
    uint256     public activateGlobal = 20;

    mapping(address => User) public userInfo; // user define all user's information
    mapping(address => address[]) public straightInviteAddress; // user  effective straight invite address, sort reward
    mapping(address => int256) internal payoutsTo; // record
    mapping(address => uint256[11]) public userSubordinateCount;
    mapping(address => uint256) public whitelistPerformance;
    mapping(address => UserReinvest) public userReinvest;
    mapping(address => uint256) public lastStraightLength;

    uint8   constant internal remain = 20;       // Static and dynamic rewards returns remain at 20 percent
    uint32  constant internal ratio = 1000;      // eth to erc20 token ratio
    uint32  constant internal blockNumber = 40000; // straight sort reward block number
    uint256 public   currentBlockNumber;
    uint256 public   straightSortRewards = 0;
    uint256  public initAddressAmount = 0;   // The first 100 addresses and enough to 1 eth, 100 -500 enough to 5 eth, 500 addresses later cancel limit
    uint256 public totalEthAmount = 0; // all user total buy eth amount
    uint8 constant public percent = 100;

    address  public eggAddress = address(0x12d4fEcccc3cbD5F7A2C9b88D709317e0E616691);   // total eth 1 percent to  egg address
    address  public systemAddress = address(0x6074510054e37D921882B05Ab40537Ce3887F3AD);
    address  public nodeAddressReward = address(0xB351d5030603E8e89e1925f6d6F50CDa4D6754A6);
    address  public globalAddressReward = address(0x49eec1928b457d1f26a2466c8bd9eC1318EcB68f);
    address [10] public straightSort; // straight reward

    Earnings internal earningsInstance;
    TeamRewards internal teamRewardInstance;
    Terminator internal terminatorInstance;
    Recommend internal recommendInstance;

    struct User {
        address userAddress;  // user address
        uint256 ethAmount;    // user buy eth amount
        uint256 profitAmount; // user profit amount
        uint256 tokenAmount;  // user get token amount
        uint256 tokenProfit;  // profit by profitAmount
        uint256 straightEth;  // user straight eth
        uint256 lockStraight;
        uint256 teamEth;      // team eth reward
        bool staticTimeout;      // static timeout, 3 days
        uint256 staticTime;     // record static out time
        uint8 level;        // user team level
        address straightAddress;
        uint256 refeTopAmount; // subordinate address topmost eth amount
        address refeTopAddress; // subordinate address topmost eth address
    }

    struct UserReinvest {
//        uint256 nodeReinvest;
        uint256 staticReinvest;
        bool    isPush;
    }

    uint8[7] internal rewardRatio;  // [0] means market support rewards         10%
    // [1] means static rewards                 30%
    // [2] means straight rewards               30%
    // [3] means team rewards                   29%
    // [4] means terminator rewards             5%
    // [5] means straight sort rewards          5%
    // [6] means egg rewards                    1%

    uint8[11] internal teamRatio; // team reward ratio

    modifier mustAdmin (address adminAddress){
        require(adminAddress != address(0));
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3] || adminAddress == admin[4]);
        _;
    }

    modifier mustReferralAddress (address referralAddress) {
        require(msg.sender != admin[0] || msg.sender != admin[1] || msg.sender != admin[2] || msg.sender != admin[3] || msg.sender != admin[4]);
        if (teamRewardInstance.isWhitelistAddress(msg.sender)) {
            require(referralAddress == admin[0] || referralAddress == admin[1] || referralAddress == admin[2] || referralAddress == admin[3] || referralAddress == admin[4]);
        }
        _;
    }

    modifier limitInvestmentCondition(uint256 ethAmount){
         if (initAddressAmount <= 50) {
            require(ethAmount <= 5 ether);
            _;
        } else {
            _;
        }
    }

    modifier limitAddressReinvest() {
        if (initAddressAmount <= 50 && userInfo[msg.sender].ethAmount > 0) {
            require(msg.value <= userInfo[msg.sender].ethAmount.mul(3));
        }
        _;
    }
    // -------------------- modifier ------------------------ //

    // --------------------- event -------------------------- //
    event WithdrawStaticProfits(address indexed user, uint256 ethAmount);
    event Buy(address indexed user, uint256 ethAmount, uint256 buyTime);
    event Withdraw(address indexed user, uint256 ethAmount, uint8 indexed value, uint256 buyTime);
    event Reinvest(address indexed user, uint256 indexed ethAmount, uint8 indexed value, uint256 buyTime);
    event SupportSubordinateAddress(uint256 indexed index, address indexed subordinate, address indexed refeAddress, bool supported);
    // --------------------- event -------------------------- //

    constructor(
        address _erc20Address,
        address _earningsAddress,
        address _teamRewardsAddress,
        address _terminatorAddress,
        address _recommendAddress
    )
    public
    {
        earningsInstance = Earnings(_earningsAddress);
        teamRewardInstance = TeamRewards(_teamRewardsAddress);
        terminatorInstance = Terminator(_terminatorAddress);
        kocInstance = KOCToken(_erc20Address);
        recommendInstance = Recommend(_recommendAddress);
        rewardRatio = [10, 30, 30, 29, 5, 5, 1];
        teamRatio = [6, 5, 4, 3, 3, 2, 2, 1, 1, 1, 1];
        currentBlockNumber = block.number;
    }

    // -------------------- user api ----------------//
    function buy(address referralAddress)
    public
    mustReferralAddress(referralAddress)
    limitInvestmentCondition(msg.value)
    payable
    {
        require(!teamRewardInstance.getWhitelistTime());
        uint256 ethAmount = msg.value;
        address userAddress = msg.sender;
        User storage _user = userInfo[userAddress];

        _user.userAddress = userAddress;

        if (_user.ethAmount == 0 && !teamRewardInstance.isWhitelistAddress(userAddress)) {
            teamRewardInstance.referralPeople(userAddress, referralAddress);
            _user.straightAddress = referralAddress;
        } else {
            referralAddress == teamRewardInstance.getUserreferralAddress(userAddress);
        }

        address straightAddress;
        address whiteAddress;
        address adminAddress;
        bool whitelist;
        (straightAddress, whiteAddress, adminAddress, whitelist) = teamRewardInstance.getUserSystemInfo(userAddress);
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3] || adminAddress == admin[4]);

        if (userInfo[referralAddress].userAddress == address(0)) {
            userInfo[referralAddress].userAddress = referralAddress;
        }

        if (userInfo[userAddress].straightAddress == address(0)) {
            userInfo[userAddress].straightAddress = straightAddress;
        }

        // uint256 _withdrawStatic;
        uint256 _lockEth;
        uint256 _withdrawTeam;
        (, _lockEth, _withdrawTeam) = earningsInstance.getStaticAfterFoundsTeam(userAddress);

        if (ethAmount >= _lockEth) {
            ethAmount = ethAmount.add(_lockEth);
            if (userInfo[userAddress].staticTimeout && userInfo[userAddress].staticTime + 3 days < block.timestamp) {
                address(uint160(systemAddress)).transfer(userInfo[userAddress].teamEth.sub(_withdrawTeam.mul(100).div(80)));
                userInfo[userAddress].teamEth = 0;
                earningsInstance.changeWithdrawTeamZero(userAddress);
            }
            userInfo[userAddress].staticTimeout = false;
            userInfo[userAddress].staticTime = block.timestamp;
        } else {
            _lockEth = ethAmount;
            ethAmount = ethAmount.mul(2);
        }

        earningsInstance.addActivateEth(userAddress, _lockEth);
        if (initAddressAmount <= 50 && userInfo[userAddress].ethAmount > 0) {
            require(userInfo[userAddress].profitAmount == 0);
        }

        if (ethAmount >= 1 ether && _user.ethAmount == 0) {// when initAddressAmount <= 500, address can only invest once before out of static
            initAddressAmount++;
        }

        calculateBuy(_user, ethAmount, straightAddress, whiteAddress, adminAddress, userAddress);

        straightReferralReward(_user, ethAmount);
        // calculate straight referral reward

        uint256 topProfits = whetherTheCap();
        require(earningsInstance.getWithdrawStatic(msg.sender).mul(100).div(80) <= topProfits);

        emit Buy(userAddress, ethAmount, block.timestamp);
    }

    // contains some methods for buy or reinvest
    function calculateBuy(
        User storage user,
        uint256 ethAmount,
        address straightAddress,
        address whiteAddress,
        address adminAddress,
        address users
    )
    internal
    {
        require(ethAmount > 0);
        user.ethAmount = teamRewardInstance.isWhitelistAddress(user.userAddress) ? (ethAmount.mul(110).div(100)).add(user.ethAmount) : ethAmount.add(user.ethAmount);

        if (user.ethAmount > user.refeTopAmount.mul(60).div(100)) {
            user.straightEth += user.lockStraight;
            user.lockStraight = 0;
        }
        if (user.ethAmount >= 1 ether && !userReinvest[user.userAddress].isPush && !teamRewardInstance.isWhitelistAddress(user.userAddress)) {
                straightInviteAddress[straightAddress].push(user.userAddress);
                userReinvest[user.userAddress].isPush = true;
                // record straight address
            if (straightInviteAddress[straightAddress].length.sub(lastStraightLength[straightAddress]) > straightInviteAddress[straightSort[9]].length.sub(lastStraightLength[straightSort[9]])) {
                    bool has = false;
                    //search this address
                    for (uint i = 0; i < 10; i++) {
                        if (straightSort[i] == straightAddress) {
                            has = true;
                        }
                    }
                    if (!has) {
                        //search this address if not in this array,go sort after cover last
                        straightSort[9] = straightAddress;
                    }
                    // sort referral address
                    quickSort(straightSort, int(0), int(9));
                    // straightSortAddress(straightAddress);
                }
//            }

        }

        address(uint160(eggAddress)).transfer(ethAmount.mul(rewardRatio[6]).div(100));
        // transfer to eggAddress 1% eth

        straightSortRewards += ethAmount.mul(rewardRatio[5]).div(100);
        // straight sort rewards, 5% eth

        teamReferralReward(ethAmount, straightAddress);
        // issue team reward

        terminatorPoolAmount += ethAmount.mul(rewardRatio[4]).div(100);
        // issue terminator reward

        calculateToken(user, ethAmount);
        // calculate and transfer KOC token

        calculateProfit(user, ethAmount, users);
        // calculate user earn profit

        updateTeamLevel(straightAddress);
        // update team level

        totalEthAmount += ethAmount;

        whitelistPerformance[whiteAddress] += ethAmount;
        whitelistPerformance[adminAddress] += ethAmount;

        addTerminator(user.userAddress);
    }

    // contains five kinds of reinvest, 1 means reinvest static rewards, 2 means recommend rewards
    //                                  3 means team rewards,  4 means terminators rewards, 5 means node rewards
    function reinvest(uint256 amount, uint8 value)
    public
    payable
    {
        address reinvestAddress = msg.sender;

        address straightAddress;
        address whiteAddress;
        address adminAddress;
        (straightAddress, whiteAddress, adminAddress,) = teamRewardInstance.getUserSystemInfo(msg.sender);

        require(value == 1 || value == 2 || value == 3 || value == 4, "resonance 303");

        uint256 earningsProfits = 0;

        if (value == 1) {
            earningsProfits = whetherTheCap();
            uint256 _withdrawStatic;
            uint256 _afterFounds;
            uint256 _withdrawTeam;
            (_withdrawStatic, _afterFounds, _withdrawTeam) = earningsInstance.getStaticAfterFoundsTeam(reinvestAddress);

            _withdrawStatic = _withdrawStatic.mul(100).div(80);
            require(_withdrawStatic.add(userReinvest[reinvestAddress].staticReinvest).add(amount) <= earningsProfits);

            if (amount >= _afterFounds) {
                if (userInfo[reinvestAddress].staticTimeout && userInfo[reinvestAddress].staticTime + 3 days < block.timestamp) {
                    address(uint160(systemAddress)).transfer(userInfo[reinvestAddress].teamEth.sub(_withdrawTeam.mul(100).div(80)));
                    userInfo[reinvestAddress].teamEth = 0;
                    earningsInstance.changeWithdrawTeamZero(reinvestAddress);
                }
                userInfo[reinvestAddress].staticTimeout = false;
                userInfo[reinvestAddress].staticTime = block.timestamp;
            }
            userReinvest[reinvestAddress].staticReinvest += amount;
        } else if (value == 2) {
            //复投直推
            require(userInfo[reinvestAddress].straightEth >= amount);
            userInfo[reinvestAddress].straightEth = userInfo[reinvestAddress].straightEth.sub(amount);

            earningsProfits = userInfo[reinvestAddress].straightEth;
        } else if (value == 3) {
            require(userInfo[reinvestAddress].teamEth >= amount);
            userInfo[reinvestAddress].teamEth = userInfo[reinvestAddress].teamEth.sub(amount);

            earningsProfits = userInfo[reinvestAddress].teamEth;
        } else if (value == 4) {
            terminatorInstance.reInvestTerminatorReward(reinvestAddress, amount);
        }

        amount = earningsInstance.calculateReinvestAmount(msg.sender, amount, earningsProfits, value);

        calculateBuy(userInfo[reinvestAddress], amount, straightAddress, whiteAddress, adminAddress, reinvestAddress);

        straightReferralReward(userInfo[reinvestAddress], amount);

        emit Reinvest(reinvestAddress, amount, value, block.timestamp);
    }

    // contains five kinds of withdraw, 1 means withdraw static rewards, 2 means recommend rewards
    //                                  3 means team rewards,  4 means terminators rewards, 5 means node rewards
    function withdraw(uint256 amount, uint8 value)
    public
    {
        address withdrawAddress = msg.sender;
        require(value == 1 || value == 2 || value == 3 || value == 4);

        uint256 _lockProfits = 0;
        uint256 _userRouteEth = 0;
        uint256 transValue = amount.mul(80).div(100);

        if (value == 1) {
            _userRouteEth = whetherTheCap();
            _lockProfits = SafeMath.mul(amount, remain).div(100);
        } else if (value == 2) {
            _userRouteEth = userInfo[withdrawAddress].straightEth;
        } else if (value == 3) {
            if (userInfo[withdrawAddress].staticTimeout) {
                require(userInfo[withdrawAddress].staticTime + 3 days >= block.timestamp);
            }
            _userRouteEth = userInfo[withdrawAddress].teamEth;
        } else if (value == 4) {
            _userRouteEth = amount.mul(80).div(100);
            terminatorInstance.modifyTerminatorReward(withdrawAddress, _userRouteEth);
        }

        earningsInstance.routeAddLockEth(withdrawAddress, amount, _lockProfits, _userRouteEth, value);

        address(uint160(withdrawAddress)).transfer(transValue);

        emit Withdraw(withdrawAddress, amount, value, block.timestamp);
    }

    // referral address support subordinate, 10%
    function supportSubordinateAddress(uint256 index, address subordinate)
    public
    payable
    {
        User storage _user = userInfo[msg.sender];

        require(_user.ethAmount.sub(_user.tokenProfit.mul(100).div(120)) >= _user.refeTopAmount.mul(60).div(100));

        uint256 straightTime;
        address refeAddress;
        uint256 ethAmount;
        bool supported;
        (straightTime, refeAddress, ethAmount, supported) = recommendInstance.getRecommendByIndex(index, _user.userAddress);
        require(!supported);

        require(straightTime.add(3 days) >= block.timestamp && refeAddress == subordinate && msg.value >= ethAmount.div(10));

        if (_user.ethAmount.add(msg.value) >= _user.refeTopAmount.mul(60).div(100)) {
            _user.straightEth += ethAmount.mul(rewardRatio[2]).div(100);
        } else {
            _user.lockStraight += ethAmount.mul(rewardRatio[2]).div(100);
        }

        address straightAddress;
        address whiteAddress;
        address adminAddress;
        (straightAddress, whiteAddress, adminAddress,) = teamRewardInstance.getUserSystemInfo(subordinate);
        calculateBuy(userInfo[subordinate], msg.value, straightAddress, whiteAddress, adminAddress, subordinate);

        recommendInstance.setSupported(index, _user.userAddress, true);

        emit SupportSubordinateAddress(index, subordinate, refeAddress, supported);
    }

    // -------------------- internal function ----------------//
    // calculate team reward and issue reward
    //teamRatio = [6, 5, 4, 3, 3, 2, 2, 1, 1, 1, 1];
    function teamReferralReward(uint256 ethAmount, address referralStraightAddress)
    internal
    {
        if (teamRewardInstance.isWhitelistAddress(msg.sender)) {
            uint256 _systemRetain = ethAmount.mul(rewardRatio[3]).div(100);
            uint256 _nodeReward = _systemRetain.mul(activateSystem).div(100);
            systemRetain += _nodeReward;
            address(uint160(nodeAddressReward)).transfer(_nodeReward.mul(100 - activateGlobal).div(100));
            address(uint160(globalAddressReward)).transfer(_nodeReward.mul(activateGlobal).div(100));
            address(uint160(systemAddress)).transfer(_systemRetain.mul(100 - activateSystem).div(100));
        } else {
            uint256 _refeReward = ethAmount.mul(rewardRatio[3]).div(100);

            //system residue eth
            uint256 residueAmount = _refeReward;

            //user straight address
            User memory currentUser = userInfo[referralStraightAddress];

            //issue team reward
            for (uint8 i = 2; i <= 12; i++) {//i start at 2, end at 12
                //get straight user
                address straightAddress = currentUser.straightAddress;

                User storage currentUserStraight = userInfo[straightAddress];
                //if straight user meet requirements
                if (currentUserStraight.level >= i) {
                    uint256 currentReward = _refeReward.mul(teamRatio[i - 2]).div(29);
                    currentUserStraight.teamEth = currentUserStraight.teamEth.add(currentReward);
                    //sub reward amount
                    residueAmount = residueAmount.sub(currentReward);
                }

                currentUser = userInfo[straightAddress];
            }

            uint256 _nodeReward = residueAmount.mul(activateSystem).div(100);
            systemRetain = systemRetain.add(_nodeReward);
            address(uint160(systemAddress)).transfer(residueAmount.mul(100 - activateSystem).div(100));

            address(uint160(nodeAddressReward)).transfer(_nodeReward.mul(100 - activateGlobal).div(100));
            address(uint160(globalAddressReward)).transfer(_nodeReward.mul(activateGlobal).div(100));
        }
    }

    function updateTeamLevel(address refferAddress)
    internal
    {
        User memory currentUserStraight = userInfo[refferAddress];

        uint8 levelUpCount = 0;

        uint256 currentInviteCount = straightInviteAddress[refferAddress].length;
        if (currentInviteCount >= 2) {
            levelUpCount = 2;
        }

        if (currentInviteCount > 12) {
            currentInviteCount = 12;
        }

        uint256 lackCount = 0;
        for (uint8 j = 2; j < currentInviteCount; j++) {
            if (userSubordinateCount[refferAddress][j - 1] >= 1 + lackCount) {
                levelUpCount = j + 1;
                lackCount = 0;
            } else {
                lackCount++;
            }
        }

        if (levelUpCount > currentUserStraight.level) {
            uint8 oldLevel = userInfo[refferAddress].level;
            userInfo[refferAddress].level = levelUpCount;

            if (currentUserStraight.straightAddress != address(0)) {
                if (oldLevel > 0) {
                    if (userSubordinateCount[currentUserStraight.straightAddress][oldLevel - 1] > 0) {
                        userSubordinateCount[currentUserStraight.straightAddress][oldLevel - 1] = userSubordinateCount[currentUserStraight.straightAddress][oldLevel - 1] - 1;
                    }
                }

                userSubordinateCount[currentUserStraight.straightAddress][levelUpCount - 1] = userSubordinateCount[currentUserStraight.straightAddress][levelUpCount - 1] + 1;
                updateTeamLevel(currentUserStraight.straightAddress);
            }
        }
    }

    // calculate bonus profit
    function calculateProfit(User storage user, uint256 ethAmount, address users)
    internal
    {
        if (teamRewardInstance.isWhitelistAddress(user.userAddress)) {
            ethAmount = ethAmount.mul(110).div(100);
        }

        uint256 userBonus = ethToBonus(ethAmount);
        require(userBonus >= 0 && SafeMath.add(userBonus, totalSupply) >= totalSupply);
        totalSupply += userBonus;
        uint256 tokenDivided = SafeMath.mul(ethAmount, rewardRatio[1]).div(100);
        getPerBonusDivide(tokenDivided, userBonus, users);
        user.profitAmount += userBonus;
    }

    // get user bonus information for calculate static rewards
    function getPerBonusDivide(uint256 tokenDivided, uint256 userBonus, address users)
    public
    {
        uint256 fee = tokenDivided * magnitude;
        perBonusDivide += SafeMath.div(SafeMath.mul(tokenDivided, magnitude), totalSupply);
        //calculate every bonus earnings eth
        fee = fee - (fee - (userBonus * (tokenDivided * magnitude / (totalSupply))));

        int256 updatedPayouts = (int256) ((perBonusDivide * userBonus) - fee);

        payoutsTo[users] += updatedPayouts;
    }

    // calculate and transfer KOC token
    function calculateToken(User storage user, uint256 ethAmount)
    internal
    {
        kocInstance.transfer(user.userAddress, ethAmount.mul(ratio));
        user.tokenAmount += ethAmount.mul(ratio);
    }

    // calculate straight reward and record referral address recommendRecord
    function straightReferralReward(User memory user, uint256 ethAmount)
    internal
    {
        address _referralAddresses = user.straightAddress;
        userInfo[_referralAddresses].refeTopAmount = (userInfo[_referralAddresses].refeTopAmount > user.ethAmount) ? userInfo[_referralAddresses].refeTopAmount : user.ethAmount;
        userInfo[_referralAddresses].refeTopAddress = (userInfo[_referralAddresses].refeTopAmount > user.ethAmount) ? userInfo[_referralAddresses].refeTopAddress : user.userAddress;

        recommendInstance.pushRecommend(_referralAddresses, user.userAddress, ethAmount);

        if (teamRewardInstance.isWhitelistAddress(user.userAddress)) {
            uint256 _systemRetain = ethAmount.mul(rewardRatio[2]).div(100);

            uint256 _nodeReward = _systemRetain.mul(activateSystem).div(100);
            systemRetain += _nodeReward;
            address(uint160(systemAddress)).transfer(_systemRetain.mul(100 - activateSystem).div(100));

            address(uint160(globalAddressReward)).transfer(_nodeReward.mul(activateGlobal).div(100));
            address(uint160(nodeAddressReward)).transfer(_nodeReward.mul(100 - activateGlobal).div(100));
        }
    }

    // sort straight address, 10
    function straightSortAddress(address referralAddress)
    internal
    {
        for (uint8 i = 0; i < 10; i++) {
            if (straightInviteAddress[straightSort[i]].length.sub(lastStraightLength[straightSort[i]]) < straightInviteAddress[referralAddress].length.sub(lastStraightLength[referralAddress])) {
                address  [] memory temp;
                for (uint j = i; j < 10; j++) {
                    temp[j] = straightSort[j];
                }
                straightSort[i] = referralAddress;
                for (uint k = i; k < 9; k++) {
                    straightSort[k + 1] = temp[k];
                }
            }
        }
    }

    //sort straight address, 10
    function quickSort(address  [10] storage arr, int left, int right) internal {
        int i = left;
        int j = right;
        if (i == j) return;
        uint pivot = straightInviteAddress[arr[uint(left + (right - left) / 2)]].length.sub(lastStraightLength[arr[uint(left + (right - left) / 2)]]);
        while (i <= j) {
            while (straightInviteAddress[arr[uint(i)]].length.sub(lastStraightLength[arr[uint(i)]]) > pivot) i++;
            while (pivot > straightInviteAddress[arr[uint(j)]].length.sub(lastStraightLength[arr[uint(j)]])) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSort(arr, left, j);
        if (i < right)
            quickSort(arr, i, right);
    }

    // settle straight rewards
    function settleStraightRewards()
    internal
    {
        uint256 addressAmount;
        for (uint8 i = 0; i < 10; i++) {
            addressAmount += straightInviteAddress[straightSort[i]].length - lastStraightLength[straightSort[i]];
        }

        uint256 _straightSortRewards = SafeMath.div(straightSortRewards, 2);
        uint256 perAddressReward = SafeMath.div(_straightSortRewards, addressAmount);
        for (uint8 j = 0; j < 10; j++) {
            address(uint160(straightSort[j])).transfer(SafeMath.mul(straightInviteAddress[straightSort[j]].length.sub(lastStraightLength[straightSort[j]]), perAddressReward));
            straightSortRewards = SafeMath.sub(straightSortRewards, SafeMath.mul(straightInviteAddress[straightSort[j]].length.sub(lastStraightLength[straightSort[j]]), perAddressReward));
            lastStraightLength[straightSort[j]] = straightInviteAddress[straightSort[j]].length;
        }
        delete (straightSort);
        currentBlockNumber = block.number;
    }

    // calculate bonus
    function ethToBonus(uint256 ethereum)
    internal
    view
    returns (uint256)
    {
        uint256 _price = bonusPrice * 1e18;
        // calculate by wei
        uint256 _tokensReceived =
        (
        (
        SafeMath.sub(
            (sqrt
        (
            (_price ** 2)
            +
            (2 * (priceIncremental * 1e18) * (ethereum * 1e18))
            +
            (((priceIncremental) ** 2) * (totalSupply ** 2))
            +
            (2 * (priceIncremental) * _price * totalSupply)
        )
            ), _price
        )
        ) / (priceIncremental)
        ) - (totalSupply);

        return _tokensReceived;
    }

    // utils for calculate bonus
    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    // get user bonus profits
    function myBonusProfits(address user)
    view
    public
    returns (uint256)
    {
        return (uint256) ((int256)(perBonusDivide.mul(userInfo[user].profitAmount)) - payoutsTo[user]).div(magnitude);
    }

    function whetherTheCap()
    internal
    returns (uint256)
    {
        require(userInfo[msg.sender].ethAmount.mul(120).div(100) >= userInfo[msg.sender].tokenProfit);
        uint256 _currentAmount = userInfo[msg.sender].ethAmount.sub(userInfo[msg.sender].tokenProfit.mul(100).div(120));
        uint256 topProfits = _currentAmount.mul(remain + 100).div(100);
        uint256 userProfits = myBonusProfits(msg.sender);

        if (userProfits > topProfits) {
            userInfo[msg.sender].profitAmount = 0;
            payoutsTo[msg.sender] = 0;
            userInfo[msg.sender].tokenProfit += topProfits;
            userInfo[msg.sender].staticTime = block.timestamp;
            userInfo[msg.sender].staticTimeout = true;
        }

        if (topProfits == 0) {
            topProfits = userInfo[msg.sender].tokenProfit;
        } else {
            topProfits = (userProfits >= topProfits) ? topProfits : userProfits.add(userInfo[msg.sender].tokenProfit); // not add again
        }

        return topProfits;
    }

    // -------------------- set api ---------------- //
    function setStraightSortRewards()
    public
    onlyAdmin()
    returns (bool)
    {
        require(currentBlockNumber + blockNumber < block.number);
        settleStraightRewards();
        return true;
    }

    // -------------------- get api ---------------- //
    // get straight sort list, 10 addresses
    function getStraightSortList()
    public
    view
    returns (address[10] memory)
    {
        return straightSort;
    }

    // get effective straight addresses current step
    function getStraightInviteAddress()
    public
    view
    returns (address[] memory)
    {
        return straightInviteAddress[msg.sender];
    }

    // get currentBlockNumber
    function getcurrentBlockNumber()
    public
    view
    returns (uint256){
        return currentBlockNumber;
    }

    function getPurchaseTasksInfo()
    public
    view
    returns (
        uint256 ethAmount,
        uint256 refeTopAmount,
        address refeTopAddress,
        uint256 lockStraight
    )
    {
        User memory getUser = userInfo[msg.sender];
        ethAmount = getUser.ethAmount.sub(getUser.tokenProfit.mul(100).div(120));
        refeTopAmount = getUser.refeTopAmount;
        refeTopAddress = getUser.refeTopAddress;
        lockStraight = getUser.lockStraight;
    }

    function getPersonalStatistics()
    public
    view
    returns (
        uint256 holdings,
        uint256 dividends,
        uint256 invites,
        uint8 level,
        uint256 afterFounds,
        uint256 referralRewards,
        uint256 teamRewards,
        uint256 nodeRewards
    )
    {
        User memory getUser = userInfo[msg.sender];

        uint256 _withdrawStatic;
        (_withdrawStatic, afterFounds) = earningsInstance.getStaticAfterFounds(getUser.userAddress);

        holdings = getUser.ethAmount.sub(getUser.tokenProfit.mul(100).div(120));
        dividends = (myBonusProfits(msg.sender) >= holdings.mul(120).div(100)) ? holdings.mul(120).div(100) : myBonusProfits(msg.sender);
        invites = straightInviteAddress[msg.sender].length;
        level = getUser.level;
        referralRewards = getUser.straightEth;
        teamRewards = getUser.teamEth;
        uint256 _nodeRewards = (totalEthAmount == 0) ? 0 : whitelistPerformance[msg.sender].mul(systemRetain).div(totalEthAmount);
        nodeRewards = (whitelistPerformance[msg.sender] < 500 ether) ? 0 : _nodeRewards;
    }

    function getUserBalance()
    public
    view
    returns (
        uint256 staticBalance,
        uint256 recommendBalance,
        uint256 teamBalance,
        uint256 terminatorBalance,
        uint256 nodeBalance,
        uint256 totalInvest,
        uint256 totalDivided,
        uint256 withdrawDivided
    )
    {
        User memory getUser = userInfo[msg.sender];
        uint256 _currentEth = getUser.ethAmount.sub(getUser.tokenProfit.mul(100).div(120));

        uint256 withdrawStraight;
        uint256 withdrawTeam;
        uint256 withdrawStatic;
        uint256 withdrawNode;
        (withdrawStraight, withdrawTeam, withdrawStatic, withdrawNode) = earningsInstance.getUserWithdrawInfo(getUser.userAddress);

//        uint256 _staticReward = getUser.ethAmount.mul(120).div(100).sub(withdrawStatic.mul(100).div(80));
        uint256 _staticReward = (getUser.ethAmount.mul(120).div(100) > withdrawStatic.mul(100).div(80)) ? getUser.ethAmount.mul(120).div(100).sub(withdrawStatic.mul(100).div(80)) : 0;

        uint256 _staticBonus = (withdrawStatic.mul(100).div(80) < myBonusProfits(msg.sender).add(getUser.tokenProfit)) ? myBonusProfits(msg.sender).add(getUser.tokenProfit).sub(withdrawStatic.mul(100).div(80)) : 0;

        staticBalance = (myBonusProfits(getUser.userAddress) >= _currentEth.mul(remain + 100).div(100)) ? _staticReward.sub(userReinvest[getUser.userAddress].staticReinvest) : _staticBonus.sub(userReinvest[getUser.userAddress].staticReinvest);

        recommendBalance = getUser.straightEth.sub(withdrawStraight.mul(100).div(80));
        teamBalance = getUser.teamEth.sub(withdrawTeam.mul(100).div(80));
        terminatorBalance = terminatorInstance.getTerminatorRewardAmount(getUser.userAddress);
        nodeBalance = 0;
        totalInvest = getUser.ethAmount;
        totalDivided = getUser.tokenProfit.add(myBonusProfits(getUser.userAddress));
        withdrawDivided = earningsInstance.getWithdrawStatic(getUser.userAddress).mul(100).div(80);
    }

    // returns contract statistics
    function contractStatistics()
    public
    view
    returns (
        uint256 recommendRankPool,
        uint256 terminatorPool
    )
    {
        recommendRankPool = straightSortRewards;
        terminatorPool = getCurrentTerminatorAmountPool();
    }

    function listNodeBonus(address node)
    public
    view
    returns (
        address nodeAddress,
        uint256 performance
    )
    {
        nodeAddress = node;
        performance = whitelistPerformance[node];
    }

    function listRankOfRecommend()
    public
    view
    returns (
        address[10] memory _straightSort,
        uint256[10] memory _inviteNumber
    )
    {
        for (uint8 i = 0; i < 10; i++) {
            if (straightSort[i] == address(0)){
                break;
            }
            _inviteNumber[i] = straightInviteAddress[straightSort[i]].length.sub(lastStraightLength[straightSort[i]]);
        }
        _straightSort = straightSort;
    }

    // return current effective user for initAddressAmount
    function getCurrentEffectiveUser()
    public
    view
    returns (uint256)
    {
        return initAddressAmount;
    }
    function addTerminator(address addr)
    internal
    {
        uint256 allInvestAmount = userInfo[addr].ethAmount.sub(userInfo[addr].tokenProfit.mul(100).div(120));
        uint256 withdrawAmount = terminatorInstance.checkBlockWithdrawAmount(block.number);
        terminatorInstance.addTerminator(addr, allInvestAmount, block.number, (terminatorPoolAmount - withdrawAmount).div(2));
    }

    function isLockWithdraw()
    public
    view
    returns (
        bool isLock,
        uint256 lockTime
    )
    {
        isLock = userInfo[msg.sender].staticTimeout;
        lockTime = userInfo[msg.sender].staticTime;
    }

    function modifyActivateSystem(uint256 value)
    mustAdmin(msg.sender)
    public
    {
        activateSystem = value;
    }

    function modifyActivateGlobal(uint256 value)
    mustAdmin(msg.sender)
    public
    {
        activateGlobal = value;
    }

    //return Current Terminator reward pool amount
    function getCurrentTerminatorAmountPool()
    view public
    returns(uint256 amount)
    {
        return terminatorPoolAmount-terminatorInstance.checkBlockWithdrawAmount(block.number);
    }
}

pragma solidity >=0.4.21 <0.6.0;

import "./KOCToken.sol";

contract ResonanceF {
    address[5] internal admin = [address(0x8434750c01D702c9cfabb3b7C5AA2774Ee67C90D), address(0xD8e79f0D2592311E740Ff097FFb0a7eaa8cb506a), address(0x740beb9fa9CCC6e971f90c25C5D5CC77063a722D), address(0x1b5bbac599f1313dB3E8061A0A65608f62897B0C), address(0x6Fd6dF175B97d2E6D651b536761e0d36b33A9495)];

    address internal boosAddress = address(0x541f5417187981b28Ef9e7Df814b160Ae2Bcb72C);

    KOCToken  internal kocInstance;

    modifier onlyAdmin () {
        address adminAddress = msg.sender;
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3]|| adminAddress == admin[4]);
        _;
    }

    function withdrawAll()
    public
    payable
    onlyAdmin()
    {
       address(uint160(boosAddress)).transfer(address(this).balance);
       kocInstance.transfer(address(uint160(boosAddress)), kocInstance.balanceOf(address(this)));
    }
}

pragma solidity ^0.5.0;

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev Give an account access to this role.
     */
    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    /**
     * @dev Remove an account's access to this role.
     */
    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    /**
     * @dev Check if an account has this role.
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}

pragma solidity ^0.5.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

pragma solidity >=0.4.21 <0.6.0;

contract TeamRewards {

    // -------------------- mapping ------------------------ //
    mapping(address => UserSystemInfo) public userSystemInfo;// user system information mapping
    mapping(address => address[])      public whitelistAddress;   // Whitelist addresses defined at the beginning of the project

    // -------------------- array ------------------------ //
    address[5] internal admin = [address(0x8434750c01D702c9cfabb3b7C5AA2774Ee67C90D), address(0xD8e79f0D2592311E740Ff097FFb0a7eaa8cb506a), address(0x740beb9fa9CCC6e971f90c25C5D5CC77063a722D), address(0x1b5bbac599f1313dB3E8061A0A65608f62897B0C), address(0x6Fd6dF175B97d2E6D651b536761e0d36b33A9495)];

    // -------------------- variate ------------------------ //
    address public resonanceAddress;
    address public owner;
    bool    public whitelistTime;

    // -------------------- event ------------------------ //
    event TobeWhitelistAddress(address indexed user, address adminAddress);

    // -------------------- structure ------------------------ //
    // user system information
    struct UserSystemInfo {
        address userAddress;     // user address
        address straightAddress; // straight Address
        address whiteAddress;    // whiteList Address
        address adminAddress;    // admin Address
        bool whitelist;  // if whitelist
    }

    constructor()
    public{
        whitelistTime = true;
        owner = msg.sender;
    }

    // -------------------- modifier ------------------------ //
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    modifier onlyAdmin () {
        address adminAddress = msg.sender;
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3] || adminAddress == admin[4]);
        _;
    }

    modifier mustAdmin (address adminAddress){
        require(adminAddress != address(0));
        require(adminAddress == admin[0] || adminAddress == admin[1] || adminAddress == admin[2] || adminAddress == admin[3] || adminAddress == admin[4]);
        _;
    }

    modifier onlyResonance (){
        require(msg.sender == resonanceAddress);
        _;
    }

    // -------------------- user api ----------------//
    function toBeWhitelistAddress(address adminAddress, address whitelist)
    public
    mustAdmin(adminAddress)
    onlyAdmin()
    payable
    {
        require(whitelistTime);
        require(!userSystemInfo[whitelist].whitelist);
        whitelistAddress[adminAddress].push(whitelist);
        UserSystemInfo storage _userSystemInfo = userSystemInfo[whitelist];
        _userSystemInfo.straightAddress = adminAddress;
        _userSystemInfo.whiteAddress = whitelist;
        _userSystemInfo.adminAddress = adminAddress;
        _userSystemInfo.whitelist = true;
        emit TobeWhitelistAddress(whitelist, adminAddress);
    }

    // -------------------- Resonance api ----------------//
    function referralPeople(address userAddress,address referralAddress)
    public
    onlyResonance()
    {
        UserSystemInfo storage _userSystemInfo = userSystemInfo[userAddress];
        _userSystemInfo.straightAddress = referralAddress;
        _userSystemInfo.whiteAddress = userSystemInfo[referralAddress].whiteAddress;
        _userSystemInfo.adminAddress = userSystemInfo[referralAddress].adminAddress;
    }

    function getUserSystemInfo(address userAddress)
    public
    view
    returns (
        address  straightAddress,
        address whiteAddress,
        address adminAddress,
        bool whitelist)
    {
        straightAddress = userSystemInfo[userAddress].straightAddress;
        whiteAddress = userSystemInfo[userAddress].whiteAddress;
        adminAddress = userSystemInfo[userAddress].adminAddress;
        whitelist    = userSystemInfo[userAddress].whitelist;
    }

    function getUserreferralAddress(address userAddress)
    public
    view
    onlyResonance()
    returns (address )
    {
        return userSystemInfo[userAddress].straightAddress;
    }

    // -------------------- Owner api ----------------//
    function allowResonance(address _addr) public onlyOwner() {
        resonanceAddress = _addr;
    }

    // -------------------- Admin api ---------------- //
    // set whitelist close
    function setWhitelistTime(bool off)
    public
    onlyAdmin()
    {
        whitelistTime = off;
    }

    function getWhitelistTime()
    public
    view
    returns (bool)
    {
        return whitelistTime;
    }

    // get all whitelist by admin address
    function getAdminWhitelistAddress(address adminx)
    public
    view
    returns (address[] memory)
    {
        return whitelistAddress[adminx];
    }

    // check if the user is whitelist
    function isWhitelistAddress(address user)
    public
    view
    returns (bool)
    {
        return userSystemInfo[user].whitelist;
    }

    function getStraightAddress (address userAddress)
    public
    view
    returns (address  straightAddress)
    {
        straightAddress = userSystemInfo[userAddress].straightAddress;
    }
}

pragma solidity >=0.4.21 <0.6.0;

contract Terminator {

    address terminatorOwner;     //合约拥有者
    address callOwner;           //部分方法允许调用者（主合约）

    struct recodeTerminator {
        address userAddress;     //用户地址
        uint256 amountInvest;    //用户留存在合约当中的金额
    }

    uint256 public BlockNumber;                                                           //区块高度
    uint256 public AllTerminatorInvestAmount;                                             //终结者所有用户总投入金额
    uint256 public TerminatorRewardPool;                                                  //当前终结者奖池金额
    uint256 public TerminatorRewardWithdrawPool;                                          //终结者可提现奖池金额
    uint256 public signRecodeTerminator;                                                  //标记插入位置

    recodeTerminator[50] public recodeTerminatorInfo;                                     //终结者记录数组
    mapping(address => uint256 [4]) internal terminatorAllReward;                         //用户总奖励金额和已提取的奖励金额和复投总金额
    mapping(uint256 => address[50]) internal blockAllTerminatorAddress;                   //每个区块有多少终结者
    uint256[] internal signBlockHasTerminator;                                            //产生终结者的区块数组

    //事件
    event AchieveTerminator(uint256 terminatorBlocknumber);  //成为终结者

    //初始化合约
    constructor() public{
        terminatorOwner = msg.sender;
    }

    //添加终结者（主合约调用）
    function addTerminator(address addr, uint256 amount, uint256 blockNumber, uint256 amountPool)
    public
    checkCallOwner(msg.sender)
    {
        require(amount > 0);
        require(amountPool > 0);
        if (blockNumber >= BlockNumber + 240 && BlockNumber != 0) {
            addRecodeToTerminatorArray(BlockNumber);
            signBlockHasTerminator.push(BlockNumber);
        }
        addRecodeTerminator(addr, amount, blockNumber, amountPool);
        BlockNumber = blockNumber;
    }

    //用户提取奖励（主合约调用）
    function modifyTerminatorReward(address addr, uint256 amount)
    public
    checkCallOwner(msg.sender)
    {
        require(amount <= terminatorAllReward[addr][0] - (terminatorAllReward[addr][1] * 100 / 80) - terminatorAllReward[addr][3]);
        terminatorAllReward[addr][1] += amount;
    }
    //用户复投(主合约调用)
    function reInvestTerminatorReward(address addr, uint256 amount)
    public
    checkCallOwner(msg.sender)
    {
        require(amount <= terminatorAllReward[addr][0] - (terminatorAllReward[addr][1] * 100 / 80) - terminatorAllReward[addr][3]);
        terminatorAllReward[addr][3] += amount;
    }

    //添加用户信息记录，等待触发终结者(内部调用)
    function addRecodeTerminator(address addr, uint256 amount, uint256 blockNumber, uint256 amountPool)
    internal
    {
        recodeTerminator memory t = recodeTerminator(addr, amount);
        if (blockNumber == BlockNumber) {
            if (signRecodeTerminator >= 50) {
                AllTerminatorInvestAmount -= recodeTerminatorInfo[signRecodeTerminator % 50].amountInvest;
            }
            recodeTerminatorInfo[signRecodeTerminator % 50] = t;
            signRecodeTerminator++;
            AllTerminatorInvestAmount += amount;
        } else {
            recodeTerminatorInfo[0] = t;
            signRecodeTerminator = 1;
            AllTerminatorInvestAmount = amount;
        }
        TerminatorRewardPool = amountPool;
    }
    //产生终结者，将终结者信息写入并计算奖励（内部调用）
    function addRecodeToTerminatorArray(uint256 blockNumber)
    internal
    {
        for (uint256 i = 0; i < 50; i++) {
            if (i >= signRecodeTerminator) {
                break;
            }
            address userAddress = recodeTerminatorInfo[i].userAddress;
            uint256 reward = (recodeTerminatorInfo[i].amountInvest) * (TerminatorRewardPool) / (AllTerminatorInvestAmount);

            blockAllTerminatorAddress[blockNumber][i] = userAddress;
            terminatorAllReward[userAddress][0] += reward;
            terminatorAllReward[userAddress][2] = reward;
        }
        TerminatorRewardWithdrawPool += TerminatorRewardPool;
        emit AchieveTerminator(blockNumber);
    }

    //添加主合约调用权限(合约拥有者调用)
    function addCallOwner(address addr)
    public
    checkTerminatorOwner(msg.sender)
    {
        callOwner = addr;
    }
    //根据区块高度获取获取所有获得终结者奖励地址
    function getAllTerminatorAddress(uint256 blockNumber)
    view public
    returns (address[50] memory)
    {
        return blockAllTerminatorAddress[blockNumber];
    }
    //获取最近一次获得终结者区块高度和奖励的所有用户地址和上一次获奖数量
    function getLatestTerminatorInfo()
    view public
    returns (uint256 blockNumber, address[50] memory addressArray, uint256[50] memory amountArray)
    {
        uint256 index = signBlockHasTerminator.length;

        address[50] memory rewardAddress;
        uint256[50] memory rewardAmount;
        if (index <= 0) {
            return (0, rewardAddress, rewardAmount);
        } else {
            uint256 blocks = signBlockHasTerminator[index - 1];
            rewardAddress = blockAllTerminatorAddress[blocks];
            for (uint256 i = 0; i < 50; i++) {
                if (rewardAddress[i] == address(0)) {
                    break;
                }
                rewardAmount[i] = terminatorAllReward[rewardAddress[i]][2];
            }
            return (blocks, rewardAddress, rewardAmount);
        }
    }
    //获取可提现奖励金额
    function getTerminatorRewardAmount(address addr)
    view public
    returns (uint256)
    {
        return terminatorAllReward[addr][0] - (terminatorAllReward[addr][1] * 100 / 80) - terminatorAllReward[addr][3];
    }
    //获取用户所有奖励金额和已提现金额和上一次获奖金额和复投金额
    function getUserTerminatorRewardInfo(address addr)
    view public
    returns (uint256[4] memory)
    {
        return terminatorAllReward[addr];
    }
    //获取所有产生终结者的区块数组
    function getAllTerminatorBlockNumber()
    view public
    returns (uint256[] memory){
        return signBlockHasTerminator;
    }
    //获取当次已提走奖池金额（供主合约调用）
    function checkBlockWithdrawAmount(uint256 blockNumber)
    view public
    returns (uint256)
    {
        if (blockNumber >= BlockNumber + 240 && BlockNumber != 0) {
            return (TerminatorRewardPool + TerminatorRewardWithdrawPool);
        } else {
            return (TerminatorRewardWithdrawPool);
        }
    }
    //检查合约拥有者权限
    modifier checkTerminatorOwner(address addr)
    {
        require(addr == terminatorOwner);
        _;
    }
    //检查合约调用者权限（检查是否是主合约调用）
    modifier checkCallOwner(address addr)
    {
        require(addr == callOwner || addr == terminatorOwner);
        _;
    }
}
//备注：
//部署完主合约后，需要调用该合约的addCallOwner方法，传入主合约地址，为主合约调该合约方法添加权限

