
// SPDX-License-Identifier: MIT
// ____                            ___       ______                                           
///\  _`\   __                    /\_ \     /\__  _\   __                                     
//\ \ \L\ \/\_\    __  _     __   \//\ \    \/_/\ \/  /\_\      __        __    _ __    ____  
// \ \ ,__/\/\ \  /\ \/'\  /'__`\   \ \ \      \ \ \  \/\ \   /'_ `\    /'__`\ /\`'__\ /',__\ 
//  \ \ \/  \ \ \ \/>  </ /\  __/    \_\ \_     \ \ \  \ \ \ /\ \L\ \  /\  __/ \ \ \/ /\__, `\
//   \ \_\   \ \_\ /\_/\_\\ \____\   /\____\     \ \_\  \ \_\\ \____ \ \ \____\ \ \_\ \/\____/
//    \/_/    \/_/ \//\/_/ \/____/   \/____/      \/_/   \/_/ \/___L\ \ \/____/  \/_/  \/___/ 
//                                                              /\____/                       
//                                                              \_/__/    
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface iPixelTigers {
    function ownerGenesisCount(address owner) external view returns(uint256);
    function numberOfLegendaries(address owner) external view returns(uint256);
    function numberOfUniques(address owner) external view returns(uint256);
    function balanceOf(address owner) external view returns(uint256);
    function tokenGenesisOfOwner(address owner) external view returns(uint256[] memory);
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract PixelERC20 is ERC20, Ownable {

    uint256 constant public BASE_RATE = 7 ether;
    uint256 constant public OG_RATE = 10 ether;
    uint256 constant public LEGENDARY_UNIQUE_RATE = 15 ether;
    uint256 constant public BONUS_RATE = 1 ether;
    uint256 constant public TICKET_PRICE = 10 ether;

    uint256 public amountLeftForReserve = 145000 ether;
    uint256 public amountTakenFromReserve;
    uint256 public numEntriesMain;
    uint256 public numEntriesSub;
    uint256 public numEntriesEvent;
    uint256 public numEntriesSpend;
    uint256 public START = 1643130000;
    uint256 public priceEvents;
    uint256 public maxEventEntries;
    uint256 public priceSpend;

    bool public rewardPaused = false;
    bool public mainRaffleActive = false;
    bool public subRaffleActive = false;
    bool public eventsActive = false;

    mapping(address => uint256) public minttime;
    mapping(address => uint256) private storeRewards;
    mapping(address => uint256) private lastUpdate;

    mapping(address => bool) public allowedAddresses;

    iPixelTigers public PixelTigers;

    constructor(address nftAddress) ERC20("PIXEL", "PXL") {
        PixelTigers = iPixelTigers(nftAddress);
    }

    function airdrop(address[] calldata to, uint256 amount) external onlyOwner {
        uint256 totalamount = to.length * amount * 1000000000000000000;
        require(totalamount <= amountLeftForReserve, "No more reserved");
        for(uint256 i; i < to.length; i++){
            _mint(to[i], amount * 1000000000000000000);
        }
        amountLeftForReserve -= totalamount;
        amountTakenFromReserve += totalamount;
    }

    function timeStamp(address user) external {
        require(msg.sender == address(PixelTigers));
        storeRewards[user] += pendingReward(user);
        minttime[user] = block.timestamp;
        lastUpdate[user] = block.timestamp;
    }

    function enterMainRaffle(uint256 numTickets) external {
        require(PixelTigers.balanceOf(msg.sender) > 0, "Do not own any Tigers");
        require(mainRaffleActive, "Main Raffle not active");
        _burn(msg.sender, (numTickets*TICKET_PRICE));

        numEntriesMain += numTickets;
    }

    function enterSubRaffle(uint256 numTickets) external {
        require(PixelTigers.balanceOf(msg.sender) > 0, "Do not own any Tigers");
        require(subRaffleActive, "Sub Raffle not active");
        _burn(msg.sender, (numTickets*TICKET_PRICE));

        numEntriesSub += numTickets;
    }

    function enterEvents(uint256 count) external {
        require(PixelTigers.balanceOf(msg.sender) > 0, "Do not own any Tigers");
        require(eventsActive, "Sub Raffle not active");
        require(numEntriesEvent + count <= maxEventEntries, "No more slots");
        _burn(msg.sender, (count*priceEvents));

        numEntriesEvent += count;
    }

    function spend(uint256 count) external {
        require(PixelTigers.balanceOf(msg.sender) > 0, "Do not own any Tigers");
        _burn(msg.sender, (count*priceSpend));

        numEntriesSpend += count;
    }

    function burn(address user, uint256 amount) external {
        require(allowedAddresses[msg.sender] || msg.sender == address(PixelTigers), "Address does not have permission to burn");
        _burn(user, amount);
    }

    function claimReward() external {
        require(!rewardPaused, "Claiming of $pixel has been paused"); 
        _mint(msg.sender, pendingReward(msg.sender) + storeRewards[msg.sender]);
        storeRewards[msg.sender] = 0;
        lastUpdate[msg.sender] = block.timestamp;
    }

    //called when transfers happened, to ensure new users will generate tokens too
    function rewardSystemUpdate(address from, address to) external {
        require(msg.sender == address(PixelTigers));
        if(from != address(0)){
            storeRewards[from] += pendingReward(from);
            lastUpdate[from] = block.timestamp;
        }
        if(to != address(0)){
            storeRewards[to] += pendingReward(to);
            lastUpdate[to] = block.timestamp;
        }
    }

    function totalTokensClaimable(address user) external view returns(uint256) {    
        return pendingReward(user) + storeRewards[user];
    }

    function numberOG(address user) external view returns(uint256){
        return PixelTigers.numberOfUniques(user) - PixelTigers.numberOfLegendaries(user);
    }

    function numLegendaryAndUniques(address user) external view returns(uint256){
        return PixelTigers.numberOfLegendaries(user);
    }

    function numNormalTigers(address user) external view returns(uint256){
        return PixelTigers.ownerGenesisCount(user) - PixelTigers.numberOfUniques(user);
    }

    function userRate(address user) external view returns(uint256){
        uint256 numberNormal = PixelTigers.ownerGenesisCount(user) - PixelTigers.numberOfUniques(user);
        uint256 numOG = PixelTigers.numberOfUniques(user) - PixelTigers.numberOfLegendaries(user);
        return PixelTigers.numberOfLegendaries(user) * LEGENDARY_UNIQUE_RATE + numOG * OG_RATE + (PixelTigers.ownerGenesisCount(user) - PixelTigers.numberOfUniques(user)) * BASE_RATE + (2 <= numberNormal ? 2 : numberNormal) * BONUS_RATE * numOG;
    }

    function pendingReward(address user) internal view returns(uint256) {
        uint256 numOG = PixelTigers.numberOfUniques(user) - PixelTigers.numberOfLegendaries(user);
        uint256 numberNormal = PixelTigers.ownerGenesisCount(user) - PixelTigers.numberOfUniques(user);
        if (minttime[user] == 0) {
            return PixelTigers.numberOfLegendaries(user) * LEGENDARY_UNIQUE_RATE * (block.timestamp - (lastUpdate[user] >= START ? lastUpdate[user] : START)) /86400 + numOG * OG_RATE * (block.timestamp - (lastUpdate[user] >= START ? lastUpdate[user] : START)) /86400 + numberNormal * BASE_RATE * (block.timestamp - (lastUpdate[user] >= START ? lastUpdate[user] : START)) /86400 + (2 <= numberNormal ? 2 : numberNormal) * BONUS_RATE * numOG * (block.timestamp - (lastUpdate[user] >= START ? lastUpdate[user] : START)) /86400;
        } else{
            return PixelTigers.numberOfLegendaries(user) * LEGENDARY_UNIQUE_RATE * (block.timestamp - (lastUpdate[user] >= minttime[user] ? lastUpdate[user] : minttime[user])) /86400 + numOG * OG_RATE * (block.timestamp - (lastUpdate[user] >= minttime[user] ? lastUpdate[user] : minttime[user])) /86400 + numberNormal * BASE_RATE * (block.timestamp - (lastUpdate[user] >= minttime[user] ? lastUpdate[user] : minttime[user])) /86400 + (2 <= numberNormal ? 2 : numberNormal) * BONUS_RATE * numOG * (block.timestamp - (lastUpdate[user] >= minttime[user] ? lastUpdate[user] : minttime[user])) /86400;
        }
    }

    function setAllowedAddresses(address _address, bool _access) public onlyOwner {
        allowedAddresses[_address] = _access;
    }

    function setERC721(address ERC721Address) external onlyOwner {
        PixelTigers = iPixelTigers(ERC721Address);
    }

    function setEvent(uint256 price, uint256 maxentries) external onlyOwner {
        priceEvents = price * 1000000000000000000;
        maxEventEntries = maxentries;
    }

    function setSpend(uint256 price) external onlyOwner {
        priceSpend = price * 1000000000000000000;
    }

    function toggleReward() public onlyOwner {
        rewardPaused = !rewardPaused;
    }

    function clearMainRaffleList() external onlyOwner{
        numEntriesMain = 0;
    }

    function clearSubRaffleList() external onlyOwner{
        numEntriesSub = 0;
    }

    function clearEvents() external onlyOwner{
        numEntriesEvent = 0;
    }

    function toggleMainRaffle() public onlyOwner {
        mainRaffleActive = !mainRaffleActive;
    }

    function toggleSubRaffle() public onlyOwner {
        subRaffleActive = !subRaffleActive;
    }

    function toggleEvents() public onlyOwner {
        eventsActive = !eventsActive;
    }
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
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
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}