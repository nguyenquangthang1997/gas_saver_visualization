pragma solidity ^0.5.0;

import "./ERC20.sol";
import "./ERC20Detailed.sol";
import "./ERC20Pow.sol";
import "./Ownable.sol";

/**
* @dev EBitcoin Token (EBT)
*/
contract EBitcoin is IERC20, ERC20, ERC20Detailed, ERC20Pow, Ownable {

    using SafeMath for uint256;

    struct BankAccount {
        uint256 balance;
        uint256 interestSettled;
        uint256 lastBlockNumber;
    }

    mapping (address => BankAccount) private _bankAccounts;

    //Suppose one block in 10 minutes, one day is 144
    uint256 private _interestInterval = 144;

    /**
    * @dev Init
    */
    constructor ()
        ERC20Detailed("EBitcoin Token", "EBT", 8)
        ERC20Pow(2**16, 2**232, 210000, 5000000000, 504, 60, 144)
    public {}

    /**
    * @dev Returns the amount of bank balance owned by `account`
    */
    function bankBalanceOf(address account) public view returns (uint256) {
        return _bankAccounts[account].balance;
    }

    /**
    * @dev Returns the amount of bank interes owned by `account`
    */
    function bankInterestOf(address account) public view returns (uint256) {

        // No interest without deposit
        BankAccount storage item = _bankAccounts[account];
        if(0 == item.balance)  return 0;

        // balance * day / 365 * 0.01
        uint256 blockNumber = getBlockCount();
        uint256 intervalCount = blockNumber.sub(item.lastBlockNumber).div(_interestInterval);
        uint256 interest = item.balance.mul(intervalCount).div(365).div(100);
        return interest.add(item.interestSettled);
    }

    /**
    * @dev Deposit `amount` tokens in the bank
    *
    * Returns a boolean value indicating whether the operation succeeded
    *
    * Emits a {Transfer} event.
    */
    function bankDeposit(uint256 amount) public returns (bool) {

        // Deducting balance
        uint256 balance = _getBalance(msg.sender);
        _setBalance(msg.sender, balance.sub(amount, "Token: bank deposit amount exceeds balance"));

        // If have a bank balance, need to calculate interest first
        BankAccount storage item = _bankAccounts[msg.sender];
        if (0 != item.balance) {

            // balance * day / 365 * 0.01
            uint256 blockNumber = getBlockCount();
            uint256 intervalCount = blockNumber.sub(item.lastBlockNumber).div(_interestInterval);
            uint256 interest = item.balance.mul(intervalCount).div(365).div(100);

            // Append
            item.balance = item.balance.add(amount);
            item.interestSettled = item.interestSettled.add(interest);
            item.lastBlockNumber = blockNumber;
        }
        else {

            // Init
            item.balance = amount;
            item.interestSettled = 0;
            item.lastBlockNumber = getBlockCount();
        }

        emit Transfer(msg.sender, address(0), amount);
        return true;
    }

    /**
    * @dev Withdrawal `amount` tokens in the bank
    *
    * Returns a boolean value indicating whether the operation succeeded
    *
    * Emits a {Transfer} event.
    */
    function bankWithdrawal(uint256 amount) public returns (bool) {

        // Bank balance greater than or equal amount
        BankAccount storage item = _bankAccounts[msg.sender];
        require(0 == amount || 0 != item.balance, "Token: withdrawal amount exceeds bank balance");

        // balance * day / 365 * 0.01
        uint256 blockNumber = getBlockCount();
        uint256 intervalCount = blockNumber.sub(item.lastBlockNumber).div(_interestInterval);
        uint256 interest = item.balance.mul(intervalCount).div(365).div(100);
        interest = interest.add(item.interestSettled);

        // Interest is enough to pay
        if (interest >= amount) {

            // Deducting interest
            item.lastBlockNumber = blockNumber;
            item.interestSettled = interest.sub(amount);

            // Transfer balance and increase total supply
            _setBalance(msg.sender, _getBalance(msg.sender).add(amount));
            _setTotalSupply(_getTotalSupply().add(amount));
        }
        else {

            // Deducting interest and bank balance
            uint256 remainAmount = amount.sub(interest);
            item.balance = item.balance.sub(remainAmount, "Token: withdrawal amount exceeds bank balance");
            item.lastBlockNumber = blockNumber;
            item.interestSettled = 0;

            // Transfer balance and increase total supply
            _setBalance(msg.sender, _getBalance(msg.sender).add(amount));
            _setTotalSupply(_getTotalSupply().add(interest));
        }

        emit Transfer(address(0), msg.sender, amount);
        return true;
    }

    /**
    * @dev Owner can transfer out any accidentally sent ERC20 tokens
    */
    function transferAnyERC20Token(address tokenAddress, uint256 amount) public onlyOwner returns (bool) {
        return IERC20(tokenAddress).transfer(getOwner(), amount);
    }
}
pragma solidity ^0.5.0;

import "./IERC20.sol";
import "./SafeMath.sol";

/**
* @dev ERC20.
*/
contract ERC20 is IERC20 {

    using SafeMath for uint256;

    uint256 private _totalSupply;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    /**
    * @dev See {IERC20-totalSupply}.
    */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
    * @dev See {IERC20-balanceOf}.
    */
    function balanceOf(address account) public view returns (uint256) {
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
    function transfer(address recipient, uint256 amount) public returns (bool){
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
    * @dev See {IERC20-allowance}.
    */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
    * @dev See {IERC20-approve}.
    *
    * Requirements:
    *
    * - `spender` cannot be the zero address.
    */
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
    * @dev See {IERC20-transferFrom}.
    *
    * Emits an {Approval} event indicating the updated allowance. This is not
    * required by the EIP. See the note at the beginning of {ERC20};
    *
    * Requirements:
    * - `sender` and `recipient` cannot be the zero address.
    * - `sender` must have a balance of at least `amount`.
    * - the caller must have allowance for `sender`'s tokens of at least
    * `amount`.
    */
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
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
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
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
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
    * @dev Moves tokens `amount` from `sender` to `recipient`.
    *
    * This is internal function is equivalent to {transfer}, and can be used to
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
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /**
    * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
    *
    * This is internal function is equivalent to `approve`, and can be used to
    * e.g. set automatic allowances for certain subsystems, etc.
    *
    * Emits an {Approval} event.
    *
    * Requirements:
    *
    * - `owner` cannot be the zero address.
    * - `spender` cannot be the zero address.
    */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
    * the total supply.
    *
    * Emits a {Transfer} event with `from` set to the zero address.
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
    * @dev Destroys `amount` tokens from `account`, reducing the
    * total supply.
    *
    * Emits a {Transfer} event with `to` set to the zero address.
    *
    * Requirements
    *
    * - `account` cannot be the zero address.
    * - `account` must have at least `amount` tokens.
    */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
    * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
    * from the caller's allowance.
    *
    * See {_burn} and {_approve}.
    */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount, "ERC20: burn amount exceeds allowance"));
    }

    /**
    * @dev Internal method
    */
    function _getTotalSupply() internal view returns (uint256) {
        return _totalSupply;
    }

    /**
    * @dev Internal method
    */
    function _setTotalSupply(uint256 value) internal {
        _totalSupply = value;
    }

    /**
    * @dev Internal method
    */
    function _getBalance(address account) internal view returns (uint256) {
        return _balances[account];
    }

    /**
    * @dev Internal method
    */
    function _setBalance(address account, uint256 value) internal {
        _balances[account] = value;
    }
}
pragma solidity ^0.5.0;

import "./ERC20.sol";

/**
* @dev Optional functions from the ERC20 standard.
*/
contract ERC20Detailed is ERC20 {

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
    * NOTE: This information is only used for _display_ purposes: it in
    * no way affects any of the arithmetic of the contract, including
    * {IERC20-balanceOf} and {IERC20-transfer}.
    */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}
pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./ERC20.sol";

/**
* @dev ERC20Pow
*/
contract ERC20Pow is ERC20 {

    using SafeMath for uint256;

    // recommended value is 2**16
    uint256 private _MINIMUM_TARGET;

    // a big number is easier, bitcoin uses 2**224
    uint256 private _MAXIMUM_TARGET;

    // Reward halving interval, bitcoin uses 210000
    uint256 private _REWARD_INTERVAL;

    // Difficulty adjustment interval, bitcoin uses 2016
    uint256 private _BLOCKS_PER_READJUSTMENT;

    // Suppose the block is 10 minutes, the ETH block is 10 seconds, then the value is 600/10=60
    uint256 private _ETHBLOCK_EXCHANGERATE;

    // Urgent adjustment threshold
    uint256 private _URGENTADJUST_THRESHOLD;

    // Block count
    uint256 private _blockCount;

    // Block reward, bitcoin uses 5000000000
    uint256 private _blockReward;

    // Mining related
    uint256 private _miningTarget;
    bytes32 private _challengeNumber;

    // Prevent duplication
    mapping(bytes32 => bytes32) private _solutionForChallenge;

    // Calculate the time interval
    uint256 private _latestDifficultyPeriodStarted;

    /**
    * @dev Init
    */
    constructor (
        uint256 minimumTarget,
        uint256 maximumTarget,
        uint256 rewardInterval,
        uint256 blockReward,
        uint256 blocksPerReadjustment,
        uint256 ethBlockExchangeRate,
        uint256 urgentAdjustThreshold
    ) public {
        _MINIMUM_TARGET = minimumTarget;
        _MAXIMUM_TARGET = maximumTarget;
        _REWARD_INTERVAL = rewardInterval;
        _BLOCKS_PER_READJUSTMENT = blocksPerReadjustment;
        _ETHBLOCK_EXCHANGERATE = ethBlockExchangeRate;
        _URGENTADJUST_THRESHOLD = urgentAdjustThreshold;
        _blockReward = blockReward;
        _miningTarget = _MAXIMUM_TARGET;
        _latestDifficultyPeriodStarted = uint256(block.number);
        _newMiningBlock();
    }

    /**
    * @dev Current block number
    */
    function getBlockCount() public view returns (uint256) {
        return _blockCount;
    }

    /**
    * @dev Current challenge number
    */
    function getChallengeNumber() public view returns (bytes32) {
        return _challengeNumber;
    }

    /**
    * @dev Current mining difficulty
    */
    function getMiningDifficulty() public view returns (uint256) {
        return _MAXIMUM_TARGET.div(_miningTarget);
    }

    /**
    * @dev Current mining target
    */
    function getMiningTarget() public view returns (uint256) {
        return _miningTarget;
    }

    /**
    * @dev Current mining reward
    */
    function getMiningReward() public view returns (uint256) {
        return _blockReward;
    }

    /**
    * @dev Submit proof
    * Emits a {SubmitProof} event
    */
    function submitProof(uint256 nonce, bytes32 challengeDigest) public returns (bool) {

        // Calculated hash
        bytes32 digest = keccak256(abi.encodePacked(_challengeNumber, msg.sender, nonce));

        // Verify digest
        require(digest == challengeDigest, "ERC20Pow: invalid params");
        require(uint256(digest) <= _miningTarget, "ERC20Pow: invalid nonce");

        // Prevent duplication
        bytes32 solution = _solutionForChallenge[_challengeNumber];
        _solutionForChallenge[_challengeNumber] = digest;
        require(solution == bytes32(0), "ERC20Pow: already exists");

        // Mint
        if (0 != _blockReward) {
            _mint(msg.sender, _blockReward);
        }

        // Next round of challenges
        _newMiningBlock();

        emit SubmitProof(msg.sender, _miningTarget, _challengeNumber);
        return true;
    }

    /**
    * @dev Urgent adjust difficulty
    * When the hash power suddenly drops sharply, the difficulty can be reduced
    * Emits a {UrgentAdjustDifficulty} event
    */
    function urgentAdjustDifficulty() public returns (bool) {

        // Must greatly exceed expectations
        uint256 targetEthBlocksPerDiffPeriod = _BLOCKS_PER_READJUSTMENT.mul(_ETHBLOCK_EXCHANGERATE);
        uint256 ethBlocksSinceLastDifficultyPeriod = uint256(block.number).sub(_latestDifficultyPeriodStarted);
        require(ethBlocksSinceLastDifficultyPeriod.div(targetEthBlocksPerDiffPeriod) > _URGENTADJUST_THRESHOLD, "ERC20Pow: invalid operation");

        _reAdjustDifficulty();
        _newChallengeNumber();

        emit UrgentAdjustDifficulty(msg.sender, _miningTarget, _challengeNumber);
        return true;
    }

    /**
    * @dev internal
    */
    function _newChallengeNumber() internal {
        _challengeNumber = keccak256(abi.encodePacked(blockhash(block.number - 1), msg.sender));
    }

    /**
    * @dev internal
    */
    function _newMiningBlock() internal {

        // Block number + 1
        _blockCount = _blockCount.add(1);

        // Block reward is cut in half
        if (0 == _blockCount.mod(_REWARD_INTERVAL)) {
            _blockReward = _blockReward.div(2);
        }

        // Re-Adjust difficulty
        if(0 == _blockCount.mod(_BLOCKS_PER_READJUSTMENT)) {
            _reAdjustDifficulty();
        }

        // Generate challenge number
        _newChallengeNumber();
    }

    /**
    * @dev internal
    */
    function _reAdjustDifficulty() internal {

        uint256 targetEthBlocksPerDiffPeriod = _BLOCKS_PER_READJUSTMENT.mul(_ETHBLOCK_EXCHANGERATE);
        uint256 ethBlocksSinceLastDifficultyPeriod = uint256(block.number).sub(_latestDifficultyPeriodStarted);

        // If there were less eth blocks passed in time than expected
        if (ethBlocksSinceLastDifficultyPeriod < targetEthBlocksPerDiffPeriod) {

            // Increase difficulty
            uint256 excessBlockPct = targetEthBlocksPerDiffPeriod.mul(100).div(ethBlocksSinceLastDifficultyPeriod);

            // Range 0 - 1000
            uint256 excessBlockPctExtra = excessBlockPct.sub(100);
            if(excessBlockPctExtra > 1000) excessBlockPctExtra = 1000;

            // Up to 50%
            _miningTarget = _miningTarget.sub(_miningTarget.div(2000).mul(excessBlockPctExtra));
        }
        else if(ethBlocksSinceLastDifficultyPeriod > targetEthBlocksPerDiffPeriod) {

            // Reduce difficulty
            uint256 shortageBlockPct = ethBlocksSinceLastDifficultyPeriod.mul(100).div(targetEthBlocksPerDiffPeriod);

            // Range 0 - 1000
            uint256 shortageBlockPctExtra = shortageBlockPct.sub(100);
            if(shortageBlockPctExtra > 1000) shortageBlockPctExtra = 1000;

            // Up to 50%
            _miningTarget = _miningTarget.add(_miningTarget.div(2000).mul(shortageBlockPctExtra));
        }

        if(_miningTarget < _MINIMUM_TARGET) _miningTarget = _MINIMUM_TARGET;
        if(_miningTarget > _MAXIMUM_TARGET) _miningTarget = _MAXIMUM_TARGET;
        _latestDifficultyPeriodStarted = block.number;
    }

    /**
    * @dev Emitted when new challenge number
    */
    event SubmitProof(address indexed miner, uint256 newMiningTarget, bytes32 newChallengeNumber);
    event UrgentAdjustDifficulty(address indexed miner, uint256 newMiningTarget, bytes32 newChallengeNumber);
}
pragma solidity ^0.5.0;

/**
* @dev Interface of the ERC20 standard as defined in the EIP. Does not include
* the optional functions; to access them see {ERC20Detailed}.
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
    * a call to {approve}. `value` is the new allowance.
    */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
pragma solidity ^0.5.0;

/**
* @dev Ownable authentication.
*/
contract Ownable {

    /**
    * @dev Owner account.
    */
    address private _owner;

    /**
    * @dev Init owner as the contract creator.
    */
    constructor() public {
        _owner = msg.sender;
    }

    /**
    * @dev Owner authentication.
    */
    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: authentication failed");
        _;
    }

    /**
    * @dev Get current owner.
    */
    function getOwner() public view returns (address) {
        return _owner;
    }

    /**
    * @dev Transfer owner.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        require(_owner != newOwner, "Ownable: transfer ownership new owner and old owner are the same");
        address oldOwner = _owner; _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
    * @dev Event transfer owner.
    */
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
    * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
    * overflow (when the result is negative).
    *
    * Counterpart to Solidity's `-` operator.
    *
    * Requirements:
    * - Subtraction cannot overflow.
    *
    * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
    * @dev Get it via `npm install @openzeppelin/contracts@next`.
    */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
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
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0)  return 0;
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
        return div(a, b, "SafeMath: division by zero");
    }

    /**
    * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
    * division by zero. The result is rounded towards zero.
    *
    * Counterpart to Solidity's `/` operator. Note: this function uses a
    * `revert` opcode (which leaves remaining gas untouched) while Solidity
    * uses an invalid opcode to revert (consuming all remaining gas).
    *
    * Requirements:
    * - The divisor cannot be zero.
    * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
    * @dev Get it via `npm install @openzeppelin/contracts@next`.
    */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
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
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
    * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
    * Reverts with custom message when dividing by zero.
    *
    * Counterpart to Solidity's `%` operator. This function uses a `revert`
    * opcode (which leaves remaining gas untouched) while Solidity uses an
    * invalid opcode to revert (consuming all remaining gas).
    *
    * Requirements:
    * - The divisor cannot be zero.
    *
    * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
    * @dev Get it via `npm install @openzeppelin/contracts@next`.
    */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
pragma solidity ^0.5.0;

import "./ERC20.sol";
import "./ERC20Detailed.sol";
import "./ERC20Pow.sol";
import "./Ownable.sol";

/**
* @dev EBitcoin Token (EBT)
*/
contract EBitcoin is IERC20, ERC20, ERC20Detailed, ERC20Pow, Ownable {

    using SafeMath for uint256;

    struct BankAccount {
        uint256 balance;
        uint256 interestSettled;
        uint256 lastBlockNumber;
    }

    mapping (address => BankAccount) private _bankAccounts;

    //Suppose one block in 10 minutes, one day is 144
    uint256 private _interestInterval = 144;

    /**
    * @dev Init
    */
    constructor ()
        ERC20Detailed("EBitcoin Token", "EBT", 8)
        ERC20Pow(2**16, 2**232, 210000, 5000000000, 504, 60, 144)
    public {}

    /**
    * @dev Returns the amount of bank balance owned by `account`
    */
    function bankBalanceOf(address account) public view returns (uint256) {
        return _bankAccounts[account].balance;
    }

    /**
    * @dev Returns the amount of bank interes owned by `account`
    */
    function bankInterestOf(address account) public view returns (uint256) {

        // No interest without deposit
        BankAccount storage item = _bankAccounts[account];
        if(0 == item.balance)  return 0;

        // balance * day / 365 * 0.01
        uint256 blockNumber = getBlockCount();
        uint256 intervalCount = blockNumber.sub(item.lastBlockNumber).div(_interestInterval);
        uint256 interest = item.balance.mul(intervalCount).div(365).div(100);
        return interest.add(item.interestSettled);
    }

    /**
    * @dev Deposit `amount` tokens in the bank
    *
    * Returns a boolean value indicating whether the operation succeeded
    *
    * Emits a {Transfer} event.
    */
    function bankDeposit(uint256 amount) public returns (bool) {

        // Deducting balance
        uint256 balance = _getBalance(msg.sender);
        _setBalance(msg.sender, balance.sub(amount, "Token: bank deposit amount exceeds balance"));

        // If have a bank balance, need to calculate interest first
        BankAccount storage item = _bankAccounts[msg.sender];
        if (0 != item.balance) {

            // balance * day / 365 * 0.01
            uint256 blockNumber = getBlockCount();
            uint256 intervalCount = blockNumber.sub(item.lastBlockNumber).div(_interestInterval);
            uint256 interest = item.balance.mul(intervalCount).div(365).div(100);

            // Append
            item.balance = item.balance.add(amount);
            item.interestSettled = item.interestSettled.add(interest);
            item.lastBlockNumber = blockNumber;
        }
        else {

            // Init
            item.balance = amount;
            item.interestSettled = 0;
            item.lastBlockNumber = getBlockCount();
        }

        emit Transfer(msg.sender, address(0), amount);
        return true;
    }

    /**
    * @dev Withdrawal `amount` tokens in the bank
    *
    * Returns a boolean value indicating whether the operation succeeded
    *
    * Emits a {Transfer} event.
    */
    function bankWithdrawal(uint256 amount) public returns (bool) {

        // Bank balance greater than or equal amount
        BankAccount storage item = _bankAccounts[msg.sender];
        require(0 == amount || 0 != item.balance, "Token: withdrawal amount exceeds bank balance");

        // balance * day / 365 * 0.01
        uint256 blockNumber = getBlockCount();
        uint256 intervalCount = blockNumber.sub(item.lastBlockNumber).div(_interestInterval);
        uint256 interest = item.balance.mul(intervalCount).div(365).div(100);
        interest = interest.add(item.interestSettled);

        // Interest is enough to pay
        if (interest >= amount) {

            // Deducting interest
            item.lastBlockNumber = blockNumber;
            item.interestSettled = interest.sub(amount);

            // Transfer balance and increase total supply
            _setBalance(msg.sender, _getBalance(msg.sender).add(amount));
            _setTotalSupply(_getTotalSupply().add(amount));
        }
        else {

            // Deducting interest and bank balance
            uint256 remainAmount = amount.sub(interest);
            item.balance = item.balance.sub(remainAmount, "Token: withdrawal amount exceeds bank balance");
            item.lastBlockNumber = blockNumber;
            item.interestSettled = 0;

            // Transfer balance and increase total supply
            _setBalance(msg.sender, _getBalance(msg.sender).add(amount));
            _setTotalSupply(_getTotalSupply().add(interest));
        }

        emit Transfer(address(0), msg.sender, amount);
        return true;
    }

    /**
    * @dev Owner can transfer out any accidentally sent ERC20 tokens
    */
    function transferAnyERC20Token(address tokenAddress, uint256 amount) public onlyOwner returns (bool) {
        return IERC20(tokenAddress).transfer(getOwner(), amount);
    }
}
pragma solidity ^0.5.0;

import "./IERC20.sol";
import "./SafeMath.sol";

/**
* @dev ERC20.
*/
contract ERC20 is IERC20 {

    using SafeMath for uint256;

    uint256 private _totalSupply;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    /**
    * @dev See {IERC20-totalSupply}.
    */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
    * @dev See {IERC20-balanceOf}.
    */
    function balanceOf(address account) public view returns (uint256) {
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
    function transfer(address recipient, uint256 amount) public returns (bool){
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
    * @dev See {IERC20-allowance}.
    */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
    * @dev See {IERC20-approve}.
    *
    * Requirements:
    *
    * - `spender` cannot be the zero address.
    */
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
    * @dev See {IERC20-transferFrom}.
    *
    * Emits an {Approval} event indicating the updated allowance. This is not
    * required by the EIP. See the note at the beginning of {ERC20};
    *
    * Requirements:
    * - `sender` and `recipient` cannot be the zero address.
    * - `sender` must have a balance of at least `amount`.
    * - the caller must have allowance for `sender`'s tokens of at least
    * `amount`.
    */
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
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
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
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
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
    * @dev Moves tokens `amount` from `sender` to `recipient`.
    *
    * This is internal function is equivalent to {transfer}, and can be used to
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
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /**
    * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
    *
    * This is internal function is equivalent to `approve`, and can be used to
    * e.g. set automatic allowances for certain subsystems, etc.
    *
    * Emits an {Approval} event.
    *
    * Requirements:
    *
    * - `owner` cannot be the zero address.
    * - `spender` cannot be the zero address.
    */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
    * the total supply.
    *
    * Emits a {Transfer} event with `from` set to the zero address.
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
    * @dev Destroys `amount` tokens from `account`, reducing the
    * total supply.
    *
    * Emits a {Transfer} event with `to` set to the zero address.
    *
    * Requirements
    *
    * - `account` cannot be the zero address.
    * - `account` must have at least `amount` tokens.
    */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
    * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
    * from the caller's allowance.
    *
    * See {_burn} and {_approve}.
    */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount, "ERC20: burn amount exceeds allowance"));
    }

    /**
    * @dev Internal method
    */
    function _getTotalSupply() internal view returns (uint256) {
        return _totalSupply;
    }

    /**
    * @dev Internal method
    */
    function _setTotalSupply(uint256 value) internal {
        _totalSupply = value;
    }

    /**
    * @dev Internal method
    */
    function _getBalance(address account) internal view returns (uint256) {
        return _balances[account];
    }

    /**
    * @dev Internal method
    */
    function _setBalance(address account, uint256 value) internal {
        _balances[account] = value;
    }
}
pragma solidity ^0.5.0;

import "./ERC20.sol";

/**
* @dev Optional functions from the ERC20 standard.
*/
contract ERC20Detailed is ERC20 {

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
    * NOTE: This information is only used for _display_ purposes: it in
    * no way affects any of the arithmetic of the contract, including
    * {IERC20-balanceOf} and {IERC20-transfer}.
    */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}
pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./ERC20.sol";

/**
* @dev ERC20Pow
*/
contract ERC20Pow is ERC20 {

    using SafeMath for uint256;

    // recommended value is 2**16
    uint256 private _MINIMUM_TARGET;

    // a big number is easier, bitcoin uses 2**224
    uint256 private _MAXIMUM_TARGET;

    // Reward halving interval, bitcoin uses 210000
    uint256 private _REWARD_INTERVAL;

    // Difficulty adjustment interval, bitcoin uses 2016
    uint256 private _BLOCKS_PER_READJUSTMENT;

    // Suppose the block is 10 minutes, the ETH block is 10 seconds, then the value is 600/10=60
    uint256 private _ETHBLOCK_EXCHANGERATE;

    // Urgent adjustment threshold
    uint256 private _URGENTADJUST_THRESHOLD;

    // Block count
    uint256 private _blockCount;

    // Block reward, bitcoin uses 5000000000
    uint256 private _blockReward;

    // Mining related
    uint256 private _miningTarget;
    bytes32 private _challengeNumber;

    // Prevent duplication
    mapping(bytes32 => bytes32) private _solutionForChallenge;

    // Calculate the time interval
    uint256 private _latestDifficultyPeriodStarted;

    /**
    * @dev Init
    */
    constructor (
        uint256 minimumTarget,
        uint256 maximumTarget,
        uint256 rewardInterval,
        uint256 blockReward,
        uint256 blocksPerReadjustment,
        uint256 ethBlockExchangeRate,
        uint256 urgentAdjustThreshold
    ) public {
        _MINIMUM_TARGET = minimumTarget;
        _MAXIMUM_TARGET = maximumTarget;
        _REWARD_INTERVAL = rewardInterval;
        _BLOCKS_PER_READJUSTMENT = blocksPerReadjustment;
        _ETHBLOCK_EXCHANGERATE = ethBlockExchangeRate;
        _URGENTADJUST_THRESHOLD = urgentAdjustThreshold;
        _blockReward = blockReward;
        _miningTarget = _MAXIMUM_TARGET;
        _latestDifficultyPeriodStarted = uint256(block.number);
        _newMiningBlock();
    }

    /**
    * @dev Current block number
    */
    function getBlockCount() public view returns (uint256) {
        return _blockCount;
    }

    /**
    * @dev Current challenge number
    */
    function getChallengeNumber() public view returns (bytes32) {
        return _challengeNumber;
    }

    /**
    * @dev Current mining difficulty
    */
    function getMiningDifficulty() public view returns (uint256) {
        return _MAXIMUM_TARGET.div(_miningTarget);
    }

    /**
    * @dev Current mining target
    */
    function getMiningTarget() public view returns (uint256) {
        return _miningTarget;
    }

    /**
    * @dev Current mining reward
    */
    function getMiningReward() public view returns (uint256) {
        return _blockReward;
    }

    /**
    * @dev Submit proof
    * Emits a {SubmitProof} event
    */
    function submitProof(uint256 nonce, bytes32 challengeDigest) public returns (bool) {

        // Calculated hash
        bytes32 digest = keccak256(abi.encodePacked(_challengeNumber, msg.sender, nonce));

        // Verify digest
        require(digest == challengeDigest, "ERC20Pow: invalid params");
        require(uint256(digest) <= _miningTarget, "ERC20Pow: invalid nonce");

        // Prevent duplication
        bytes32 solution = _solutionForChallenge[_challengeNumber];
        _solutionForChallenge[_challengeNumber] = digest;
        require(solution == bytes32(0), "ERC20Pow: already exists");

        // Mint
        if (0 != _blockReward) {
            _mint(msg.sender, _blockReward);
        }

        // Next round of challenges
        _newMiningBlock();

        emit SubmitProof(msg.sender, _miningTarget, _challengeNumber);
        return true;
    }

    /**
    * @dev Urgent adjust difficulty
    * When the hash power suddenly drops sharply, the difficulty can be reduced
    * Emits a {UrgentAdjustDifficulty} event
    */
    function urgentAdjustDifficulty() public returns (bool) {

        // Must greatly exceed expectations
        uint256 targetEthBlocksPerDiffPeriod = _BLOCKS_PER_READJUSTMENT.mul(_ETHBLOCK_EXCHANGERATE);
        uint256 ethBlocksSinceLastDifficultyPeriod = uint256(block.number).sub(_latestDifficultyPeriodStarted);
        require(ethBlocksSinceLastDifficultyPeriod.div(targetEthBlocksPerDiffPeriod) > _URGENTADJUST_THRESHOLD, "ERC20Pow: invalid operation");

        _reAdjustDifficulty();
        _newChallengeNumber();

        emit UrgentAdjustDifficulty(msg.sender, _miningTarget, _challengeNumber);
        return true;
    }

    /**
    * @dev internal
    */
    function _newChallengeNumber() internal {
        _challengeNumber = keccak256(abi.encodePacked(blockhash(block.number - 1), msg.sender));
    }

    /**
    * @dev internal
    */
    function _newMiningBlock() internal {

        // Block number + 1
        _blockCount = _blockCount.add(1);

        // Block reward is cut in half
        if (0 == _blockCount.mod(_REWARD_INTERVAL)) {
            _blockReward = _blockReward.div(2);
        }

        // Re-Adjust difficulty
        if(0 == _blockCount.mod(_BLOCKS_PER_READJUSTMENT)) {
            _reAdjustDifficulty();
        }

        // Generate challenge number
        _newChallengeNumber();
    }

    /**
    * @dev internal
    */
    function _reAdjustDifficulty() internal {

        uint256 targetEthBlocksPerDiffPeriod = _BLOCKS_PER_READJUSTMENT.mul(_ETHBLOCK_EXCHANGERATE);
        uint256 ethBlocksSinceLastDifficultyPeriod = uint256(block.number).sub(_latestDifficultyPeriodStarted);

        // If there were less eth blocks passed in time than expected
        if (ethBlocksSinceLastDifficultyPeriod < targetEthBlocksPerDiffPeriod) {

            // Increase difficulty
            uint256 excessBlockPct = targetEthBlocksPerDiffPeriod.mul(100).div(ethBlocksSinceLastDifficultyPeriod);

            // Range 0 - 1000
            uint256 excessBlockPctExtra = excessBlockPct.sub(100);
            if(excessBlockPctExtra > 1000) excessBlockPctExtra = 1000;

            // Up to 50%
            _miningTarget = _miningTarget.sub(_miningTarget.div(2000).mul(excessBlockPctExtra));
        }
        else if(ethBlocksSinceLastDifficultyPeriod > targetEthBlocksPerDiffPeriod) {

            // Reduce difficulty
            uint256 shortageBlockPct = ethBlocksSinceLastDifficultyPeriod.mul(100).div(targetEthBlocksPerDiffPeriod);

            // Range 0 - 1000
            uint256 shortageBlockPctExtra = shortageBlockPct.sub(100);
            if(shortageBlockPctExtra > 1000) shortageBlockPctExtra = 1000;

            // Up to 50%
            _miningTarget = _miningTarget.add(_miningTarget.div(2000).mul(shortageBlockPctExtra));
        }

        if(_miningTarget < _MINIMUM_TARGET) _miningTarget = _MINIMUM_TARGET;
        if(_miningTarget > _MAXIMUM_TARGET) _miningTarget = _MAXIMUM_TARGET;
        _latestDifficultyPeriodStarted = block.number;
    }

    /**
    * @dev Emitted when new challenge number
    */
    event SubmitProof(address indexed miner, uint256 newMiningTarget, bytes32 newChallengeNumber);
    event UrgentAdjustDifficulty(address indexed miner, uint256 newMiningTarget, bytes32 newChallengeNumber);
}
pragma solidity ^0.5.0;

/**
* @dev Interface of the ERC20 standard as defined in the EIP. Does not include
* the optional functions; to access them see {ERC20Detailed}.
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
    * a call to {approve}. `value` is the new allowance.
    */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
pragma solidity ^0.5.0;

/**
* @dev Ownable authentication.
*/
contract Ownable {

    /**
    * @dev Owner account.
    */
    address private _owner;

    /**
    * @dev Init owner as the contract creator.
    */
    constructor() public {
        _owner = msg.sender;
    }

    /**
    * @dev Owner authentication.
    */
    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: authentication failed");
        _;
    }

    /**
    * @dev Get current owner.
    */
    function getOwner() public view returns (address) {
        return _owner;
    }

    /**
    * @dev Transfer owner.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        require(_owner != newOwner, "Ownable: transfer ownership new owner and old owner are the same");
        address oldOwner = _owner; _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
    * @dev Event transfer owner.
    */
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
    * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
    * overflow (when the result is negative).
    *
    * Counterpart to Solidity's `-` operator.
    *
    * Requirements:
    * - Subtraction cannot overflow.
    *
    * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
    * @dev Get it via `npm install @openzeppelin/contracts@next`.
    */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
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
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0)  return 0;
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
        return div(a, b, "SafeMath: division by zero");
    }

    /**
    * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
    * division by zero. The result is rounded towards zero.
    *
    * Counterpart to Solidity's `/` operator. Note: this function uses a
    * `revert` opcode (which leaves remaining gas untouched) while Solidity
    * uses an invalid opcode to revert (consuming all remaining gas).
    *
    * Requirements:
    * - The divisor cannot be zero.
    * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
    * @dev Get it via `npm install @openzeppelin/contracts@next`.
    */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
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
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
    * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
    * Reverts with custom message when dividing by zero.
    *
    * Counterpart to Solidity's `%` operator. This function uses a `revert`
    * opcode (which leaves remaining gas untouched) while Solidity uses an
    * invalid opcode to revert (consuming all remaining gas).
    *
    * Requirements:
    * - The divisor cannot be zero.
    *
    * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
    * @dev Get it via `npm install @openzeppelin/contracts@next`.
    */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
pragma solidity ^0.5.0;

import "./ERC20.sol";
import "./ERC20Detailed.sol";
import "./ERC20Pow.sol";
import "./Ownable.sol";

/**
* @dev EBitcoin Token (EBT)
*/
contract EBitcoin is IERC20, ERC20, ERC20Detailed, ERC20Pow, Ownable {

    using SafeMath for uint256;

    struct BankAccount {
        uint256 balance;
        uint256 interestSettled;
        uint256 lastBlockNumber;
    }

    mapping (address => BankAccount) private _bankAccounts;

    //Suppose one block in 10 minutes, one day is 144
    uint256 private _interestInterval = 144;

    /**
    * @dev Init
    */
    constructor ()
        ERC20Detailed("EBitcoin Token", "EBT", 8)
        ERC20Pow(2**16, 2**232, 210000, 5000000000, 504, 60, 144)
    public {}

    /**
    * @dev Returns the amount of bank balance owned by `account`
    */
    function bankBalanceOf(address account) public view returns (uint256) {
        return _bankAccounts[account].balance;
    }

    /**
    * @dev Returns the amount of bank interes owned by `account`
    */
    function bankInterestOf(address account) public view returns (uint256) {

        // No interest without deposit
        BankAccount storage item = _bankAccounts[account];
        if(0 == item.balance)  return 0;

        // balance * day / 365 * 0.01
        uint256 blockNumber = getBlockCount();
        uint256 intervalCount = blockNumber.sub(item.lastBlockNumber).div(_interestInterval);
        uint256 interest = item.balance.mul(intervalCount).div(365).div(100);
        return interest.add(item.interestSettled);
    }

    /**
    * @dev Deposit `amount` tokens in the bank
    *
    * Returns a boolean value indicating whether the operation succeeded
    *
    * Emits a {Transfer} event.
    */
    function bankDeposit(uint256 amount) public returns (bool) {

        // Deducting balance
        uint256 balance = _getBalance(msg.sender);
        _setBalance(msg.sender, balance.sub(amount, "Token: bank deposit amount exceeds balance"));

        // If have a bank balance, need to calculate interest first
        BankAccount storage item = _bankAccounts[msg.sender];
        if (0 != item.balance) {

            // balance * day / 365 * 0.01
            uint256 blockNumber = getBlockCount();
            uint256 intervalCount = blockNumber.sub(item.lastBlockNumber).div(_interestInterval);
            uint256 interest = item.balance.mul(intervalCount).div(365).div(100);

            // Append
            item.balance = item.balance.add(amount);
            item.interestSettled = item.interestSettled.add(interest);
            item.lastBlockNumber = blockNumber;
        }
        else {

            // Init
            item.balance = amount;
            item.interestSettled = 0;
            item.lastBlockNumber = getBlockCount();
        }

        emit Transfer(msg.sender, address(0), amount);
        return true;
    }

    /**
    * @dev Withdrawal `amount` tokens in the bank
    *
    * Returns a boolean value indicating whether the operation succeeded
    *
    * Emits a {Transfer} event.
    */
    function bankWithdrawal(uint256 amount) public returns (bool) {

        // Bank balance greater than or equal amount
        BankAccount storage item = _bankAccounts[msg.sender];
        require(0 == amount || 0 != item.balance, "Token: withdrawal amount exceeds bank balance");

        // balance * day / 365 * 0.01
        uint256 blockNumber = getBlockCount();
        uint256 intervalCount = blockNumber.sub(item.lastBlockNumber).div(_interestInterval);
        uint256 interest = item.balance.mul(intervalCount).div(365).div(100);
        interest = interest.add(item.interestSettled);

        // Interest is enough to pay
        if (interest >= amount) {

            // Deducting interest
            item.lastBlockNumber = blockNumber;
            item.interestSettled = interest.sub(amount);

            // Transfer balance and increase total supply
            _setBalance(msg.sender, _getBalance(msg.sender).add(amount));
            _setTotalSupply(_getTotalSupply().add(amount));
        }
        else {

            // Deducting interest and bank balance
            uint256 remainAmount = amount.sub(interest);
            item.balance = item.balance.sub(remainAmount, "Token: withdrawal amount exceeds bank balance");
            item.lastBlockNumber = blockNumber;
            item.interestSettled = 0;

            // Transfer balance and increase total supply
            _setBalance(msg.sender, _getBalance(msg.sender).add(amount));
            _setTotalSupply(_getTotalSupply().add(interest));
        }

        emit Transfer(address(0), msg.sender, amount);
        return true;
    }

    /**
    * @dev Owner can transfer out any accidentally sent ERC20 tokens
    */
    function transferAnyERC20Token(address tokenAddress, uint256 amount) public onlyOwner returns (bool) {
        return IERC20(tokenAddress).transfer(getOwner(), amount);
    }
}
pragma solidity ^0.5.0;

import "./IERC20.sol";
import "./SafeMath.sol";

/**
* @dev ERC20.
*/
contract ERC20 is IERC20 {

    using SafeMath for uint256;

    uint256 private _totalSupply;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    /**
    * @dev See {IERC20-totalSupply}.
    */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
    * @dev See {IERC20-balanceOf}.
    */
    function balanceOf(address account) public view returns (uint256) {
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
    function transfer(address recipient, uint256 amount) public returns (bool){
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
    * @dev See {IERC20-allowance}.
    */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
    * @dev See {IERC20-approve}.
    *
    * Requirements:
    *
    * - `spender` cannot be the zero address.
    */
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
    * @dev See {IERC20-transferFrom}.
    *
    * Emits an {Approval} event indicating the updated allowance. This is not
    * required by the EIP. See the note at the beginning of {ERC20};
    *
    * Requirements:
    * - `sender` and `recipient` cannot be the zero address.
    * - `sender` must have a balance of at least `amount`.
    * - the caller must have allowance for `sender`'s tokens of at least
    * `amount`.
    */
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
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
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
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
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
    * @dev Moves tokens `amount` from `sender` to `recipient`.
    *
    * This is internal function is equivalent to {transfer}, and can be used to
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
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /**
    * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
    *
    * This is internal function is equivalent to `approve`, and can be used to
    * e.g. set automatic allowances for certain subsystems, etc.
    *
    * Emits an {Approval} event.
    *
    * Requirements:
    *
    * - `owner` cannot be the zero address.
    * - `spender` cannot be the zero address.
    */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
    * the total supply.
    *
    * Emits a {Transfer} event with `from` set to the zero address.
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
    * @dev Destroys `amount` tokens from `account`, reducing the
    * total supply.
    *
    * Emits a {Transfer} event with `to` set to the zero address.
    *
    * Requirements
    *
    * - `account` cannot be the zero address.
    * - `account` must have at least `amount` tokens.
    */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
    * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
    * from the caller's allowance.
    *
    * See {_burn} and {_approve}.
    */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount, "ERC20: burn amount exceeds allowance"));
    }

    /**
    * @dev Internal method
    */
    function _getTotalSupply() internal view returns (uint256) {
        return _totalSupply;
    }

    /**
    * @dev Internal method
    */
    function _setTotalSupply(uint256 value) internal {
        _totalSupply = value;
    }

    /**
    * @dev Internal method
    */
    function _getBalance(address account) internal view returns (uint256) {
        return _balances[account];
    }

    /**
    * @dev Internal method
    */
    function _setBalance(address account, uint256 value) internal {
        _balances[account] = value;
    }
}
pragma solidity ^0.5.0;

import "./ERC20.sol";

/**
* @dev Optional functions from the ERC20 standard.
*/
contract ERC20Detailed is ERC20 {

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
    * NOTE: This information is only used for _display_ purposes: it in
    * no way affects any of the arithmetic of the contract, including
    * {IERC20-balanceOf} and {IERC20-transfer}.
    */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}
pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./ERC20.sol";

/**
* @dev ERC20Pow
*/
contract ERC20Pow is ERC20 {

    using SafeMath for uint256;

    // recommended value is 2**16
    uint256 private _MINIMUM_TARGET;

    // a big number is easier, bitcoin uses 2**224
    uint256 private _MAXIMUM_TARGET;

    // Reward halving interval, bitcoin uses 210000
    uint256 private _REWARD_INTERVAL;

    // Difficulty adjustment interval, bitcoin uses 2016
    uint256 private _BLOCKS_PER_READJUSTMENT;

    // Suppose the block is 10 minutes, the ETH block is 10 seconds, then the value is 600/10=60
    uint256 private _ETHBLOCK_EXCHANGERATE;

    // Urgent adjustment threshold
    uint256 private _URGENTADJUST_THRESHOLD;

    // Block count
    uint256 private _blockCount;

    // Block reward, bitcoin uses 5000000000
    uint256 private _blockReward;

    // Mining related
    uint256 private _miningTarget;
    bytes32 private _challengeNumber;

    // Prevent duplication
    mapping(bytes32 => bytes32) private _solutionForChallenge;

    // Calculate the time interval
    uint256 private _latestDifficultyPeriodStarted;

    /**
    * @dev Init
    */
    constructor (
        uint256 minimumTarget,
        uint256 maximumTarget,
        uint256 rewardInterval,
        uint256 blockReward,
        uint256 blocksPerReadjustment,
        uint256 ethBlockExchangeRate,
        uint256 urgentAdjustThreshold
    ) public {
        _MINIMUM_TARGET = minimumTarget;
        _MAXIMUM_TARGET = maximumTarget;
        _REWARD_INTERVAL = rewardInterval;
        _BLOCKS_PER_READJUSTMENT = blocksPerReadjustment;
        _ETHBLOCK_EXCHANGERATE = ethBlockExchangeRate;
        _URGENTADJUST_THRESHOLD = urgentAdjustThreshold;
        _blockReward = blockReward;
        _miningTarget = _MAXIMUM_TARGET;
        _latestDifficultyPeriodStarted = uint256(block.number);
        _newMiningBlock();
    }

    /**
    * @dev Current block number
    */
    function getBlockCount() public view returns (uint256) {
        return _blockCount;
    }

    /**
    * @dev Current challenge number
    */
    function getChallengeNumber() public view returns (bytes32) {
        return _challengeNumber;
    }

    /**
    * @dev Current mining difficulty
    */
    function getMiningDifficulty() public view returns (uint256) {
        return _MAXIMUM_TARGET.div(_miningTarget);
    }

    /**
    * @dev Current mining target
    */
    function getMiningTarget() public view returns (uint256) {
        return _miningTarget;
    }

    /**
    * @dev Current mining reward
    */
    function getMiningReward() public view returns (uint256) {
        return _blockReward;
    }

    /**
    * @dev Submit proof
    * Emits a {SubmitProof} event
    */
    function submitProof(uint256 nonce, bytes32 challengeDigest) public returns (bool) {

        // Calculated hash
        bytes32 digest = keccak256(abi.encodePacked(_challengeNumber, msg.sender, nonce));

        // Verify digest
        require(digest == challengeDigest, "ERC20Pow: invalid params");
        require(uint256(digest) <= _miningTarget, "ERC20Pow: invalid nonce");

        // Prevent duplication
        bytes32 solution = _solutionForChallenge[_challengeNumber];
        _solutionForChallenge[_challengeNumber] = digest;
        require(solution == bytes32(0), "ERC20Pow: already exists");

        // Mint
        if (0 != _blockReward) {
            _mint(msg.sender, _blockReward);
        }

        // Next round of challenges
        _newMiningBlock();

        emit SubmitProof(msg.sender, _miningTarget, _challengeNumber);
        return true;
    }

    /**
    * @dev Urgent adjust difficulty
    * When the hash power suddenly drops sharply, the difficulty can be reduced
    * Emits a {UrgentAdjustDifficulty} event
    */
    function urgentAdjustDifficulty() public returns (bool) {

        // Must greatly exceed expectations
        uint256 targetEthBlocksPerDiffPeriod = _BLOCKS_PER_READJUSTMENT.mul(_ETHBLOCK_EXCHANGERATE);
        uint256 ethBlocksSinceLastDifficultyPeriod = uint256(block.number).sub(_latestDifficultyPeriodStarted);
        require(ethBlocksSinceLastDifficultyPeriod.div(targetEthBlocksPerDiffPeriod) > _URGENTADJUST_THRESHOLD, "ERC20Pow: invalid operation");

        _reAdjustDifficulty();
        _newChallengeNumber();

        emit UrgentAdjustDifficulty(msg.sender, _miningTarget, _challengeNumber);
        return true;
    }

    /**
    * @dev internal
    */
    function _newChallengeNumber() internal {
        _challengeNumber = keccak256(abi.encodePacked(blockhash(block.number - 1), msg.sender));
    }

    /**
    * @dev internal
    */
    function _newMiningBlock() internal {

        // Block number + 1
        _blockCount = _blockCount.add(1);

        // Block reward is cut in half
        if (0 == _blockCount.mod(_REWARD_INTERVAL)) {
            _blockReward = _blockReward.div(2);
        }

        // Re-Adjust difficulty
        if(0 == _blockCount.mod(_BLOCKS_PER_READJUSTMENT)) {
            _reAdjustDifficulty();
        }

        // Generate challenge number
        _newChallengeNumber();
    }

    /**
    * @dev internal
    */
    function _reAdjustDifficulty() internal {

        uint256 targetEthBlocksPerDiffPeriod = _BLOCKS_PER_READJUSTMENT.mul(_ETHBLOCK_EXCHANGERATE);
        uint256 ethBlocksSinceLastDifficultyPeriod = uint256(block.number).sub(_latestDifficultyPeriodStarted);

        // If there were less eth blocks passed in time than expected
        if (ethBlocksSinceLastDifficultyPeriod < targetEthBlocksPerDiffPeriod) {

            // Increase difficulty
            uint256 excessBlockPct = targetEthBlocksPerDiffPeriod.mul(100).div(ethBlocksSinceLastDifficultyPeriod);

            // Range 0 - 1000
            uint256 excessBlockPctExtra = excessBlockPct.sub(100);
            if(excessBlockPctExtra > 1000) excessBlockPctExtra = 1000;

            // Up to 50%
            _miningTarget = _miningTarget.sub(_miningTarget.div(2000).mul(excessBlockPctExtra));
        }
        else if(ethBlocksSinceLastDifficultyPeriod > targetEthBlocksPerDiffPeriod) {

            // Reduce difficulty
            uint256 shortageBlockPct = ethBlocksSinceLastDifficultyPeriod.mul(100).div(targetEthBlocksPerDiffPeriod);

            // Range 0 - 1000
            uint256 shortageBlockPctExtra = shortageBlockPct.sub(100);
            if(shortageBlockPctExtra > 1000) shortageBlockPctExtra = 1000;

            // Up to 50%
            _miningTarget = _miningTarget.add(_miningTarget.div(2000).mul(shortageBlockPctExtra));
        }

        if(_miningTarget < _MINIMUM_TARGET) _miningTarget = _MINIMUM_TARGET;
        if(_miningTarget > _MAXIMUM_TARGET) _miningTarget = _MAXIMUM_TARGET;
        _latestDifficultyPeriodStarted = block.number;
    }

    /**
    * @dev Emitted when new challenge number
    */
    event SubmitProof(address indexed miner, uint256 newMiningTarget, bytes32 newChallengeNumber);
    event UrgentAdjustDifficulty(address indexed miner, uint256 newMiningTarget, bytes32 newChallengeNumber);
}
pragma solidity ^0.5.0;

/**
* @dev Interface of the ERC20 standard as defined in the EIP. Does not include
* the optional functions; to access them see {ERC20Detailed}.
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
    * a call to {approve}. `value` is the new allowance.
    */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
pragma solidity ^0.5.0;

/**
* @dev Ownable authentication.
*/
contract Ownable {

    /**
    * @dev Owner account.
    */
    address private _owner;

    /**
    * @dev Init owner as the contract creator.
    */
    constructor() public {
        _owner = msg.sender;
    }

    /**
    * @dev Owner authentication.
    */
    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: authentication failed");
        _;
    }

    /**
    * @dev Get current owner.
    */
    function getOwner() public view returns (address) {
        return _owner;
    }

    /**
    * @dev Transfer owner.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        require(_owner != newOwner, "Ownable: transfer ownership new owner and old owner are the same");
        address oldOwner = _owner; _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
    * @dev Event transfer owner.
    */
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
    * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
    * overflow (when the result is negative).
    *
    * Counterpart to Solidity's `-` operator.
    *
    * Requirements:
    * - Subtraction cannot overflow.
    *
    * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
    * @dev Get it via `npm install @openzeppelin/contracts@next`.
    */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
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
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0)  return 0;
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
        return div(a, b, "SafeMath: division by zero");
    }

    /**
    * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
    * division by zero. The result is rounded towards zero.
    *
    * Counterpart to Solidity's `/` operator. Note: this function uses a
    * `revert` opcode (which leaves remaining gas untouched) while Solidity
    * uses an invalid opcode to revert (consuming all remaining gas).
    *
    * Requirements:
    * - The divisor cannot be zero.
    * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
    * @dev Get it via `npm install @openzeppelin/contracts@next`.
    */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
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
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
    * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
    * Reverts with custom message when dividing by zero.
    *
    * Counterpart to Solidity's `%` operator. This function uses a `revert`
    * opcode (which leaves remaining gas untouched) while Solidity uses an
    * invalid opcode to revert (consuming all remaining gas).
    *
    * Requirements:
    * - The divisor cannot be zero.
    *
    * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
    * @dev Get it via `npm install @openzeppelin/contracts@next`.
    */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
