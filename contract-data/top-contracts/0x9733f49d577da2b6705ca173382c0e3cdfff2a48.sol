
pragma solidity 0.5.17;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "../interfaces/Comptroller.sol";
import "../interfaces/PriceOracle.sol";
import "../interfaces/CERC20.sol";
import "../interfaces/CEther.sol";
import "../Utils.sol";

contract CompoundOrder is Utils(address(0), address(0), address(0)), Ownable {
  // Constants
  uint256 internal constant NEGLIGIBLE_DEBT = 100; // we don't care about debts below 10^-4 USDC (0.1 cent)
  uint256 internal constant MAX_REPAY_STEPS = 3; // Max number of times we attempt to repay remaining debt
  uint256 internal constant DEFAULT_LIQUIDITY_SLIPPAGE = 10 ** 12; // 1e-6 slippage for redeeming liquidity when selling order
  uint256 internal constant FALLBACK_LIQUIDITY_SLIPPAGE = 10 ** 15; // 0.1% slippage for redeeming liquidity when selling order
  uint256 internal constant MAX_LIQUIDITY_SLIPPAGE = 10 ** 17; // 10% max slippage for redeeming liquidity when selling order

  // Contract instances
  Comptroller public COMPTROLLER; // The Compound comptroller
  PriceOracle public ORACLE; // The Compound price oracle
  CERC20 public CUSDC; // The Compound USDC market token
  address public CETH_ADDR;

  // Instance variables
  uint256 public stake;
  uint256 public collateralAmountInUSDC;
  uint256 public loanAmountInUSDC;
  uint256 public cycleNumber;
  uint256 public buyTime; // Timestamp for order execution
  uint256 public outputAmount; // Records the total output USDC after order is sold
  address public compoundTokenAddr;
  bool public isSold;
  bool public orderType; // True for shorting, false for longing
  bool internal initialized;


  constructor() public {}

  function init(
    address _compoundTokenAddr,
    uint256 _cycleNumber,
    uint256 _stake,
    uint256 _collateralAmountInUSDC,
    uint256 _loanAmountInUSDC,
    bool _orderType,
    address _usdcAddr,
    address payable _kyberAddr,
    address _comptrollerAddr,
    address _priceOracleAddr,
    address _cUSDCAddr,
    address _cETHAddr
  ) public {
    require(!initialized);
    initialized = true;

    // Initialize details of order
    require(_compoundTokenAddr != _cUSDCAddr);
    require(_stake > 0 && _collateralAmountInUSDC > 0 && _loanAmountInUSDC > 0); // Validate inputs
    stake = _stake;
    collateralAmountInUSDC = _collateralAmountInUSDC;
    loanAmountInUSDC = _loanAmountInUSDC;
    cycleNumber = _cycleNumber;
    compoundTokenAddr = _compoundTokenAddr;
    orderType = _orderType;

    COMPTROLLER = Comptroller(_comptrollerAddr);
    ORACLE = PriceOracle(_priceOracleAddr);
    CUSDC = CERC20(_cUSDCAddr);
    CETH_ADDR = _cETHAddr;
    USDC_ADDR = _usdcAddr;
    KYBER_ADDR = _kyberAddr;
    usdc = ERC20Detailed(_usdcAddr);
    kyber = KyberNetwork(_kyberAddr);

    // transfer ownership to msg.sender
    _transferOwnership(msg.sender);
  }

  /**
   * @notice Executes the Compound order
   * @param _minPrice the minimum token price
   * @param _maxPrice the maximum token price
   */
  function executeOrder(uint256 _minPrice, uint256 _maxPrice) public;

  /**
   * @notice Sells the Compound order and returns assets to PeakDeFiFund
   * @param _minPrice the minimum token price
   * @param _maxPrice the maximum token price
   */
  function sellOrder(uint256 _minPrice, uint256 _maxPrice) public returns (uint256 _inputAmount, uint256 _outputAmount);

  /**
   * @notice Repays the loans taken out to prevent the collateral ratio from dropping below threshold
   * @param _repayAmountInUSDC the amount to repay, in USDC
   */
  function repayLoan(uint256 _repayAmountInUSDC) public;

  /**
   * @notice Emergency method, which allow to transfer selected tokens to the fund address
   * @param _tokenAddr address of withdrawn token
   * @param _receiver address who should receive tokens
   */
  function emergencyExitTokens(address _tokenAddr, address _receiver) public onlyOwner {
    ERC20Detailed token = ERC20Detailed(_tokenAddr);
    token.safeTransfer(_receiver, token.balanceOf(address(this)));
  }

  function getMarketCollateralFactor() public view returns (uint256);

  function getCurrentCollateralInUSDC() public returns (uint256 _amount);

  function getCurrentBorrowInUSDC() public returns (uint256 _amount);

  function getCurrentCashInUSDC() public view returns (uint256 _amount);

  /**
   * @notice Calculates the current profit in USDC
   * @return the profit amount
   */
  function getCurrentProfitInUSDC() public returns (bool _isNegative, uint256 _amount) {
    uint256 l;
    uint256 r;
    if (isSold) {
      l = outputAmount;
      r = collateralAmountInUSDC;
    } else {
      uint256 cash = getCurrentCashInUSDC();
      uint256 supply = getCurrentCollateralInUSDC();
      uint256 borrow = getCurrentBorrowInUSDC();
      if (cash >= borrow) {
        l = supply.add(cash);
        r = borrow.add(collateralAmountInUSDC);
      } else {
        l = supply;
        r = borrow.sub(cash).mul(PRECISION).div(getMarketCollateralFactor()).add(collateralAmountInUSDC);
      }
    }

    if (l >= r) {
      return (false, l.sub(r));
    } else {
      return (true, r.sub(l));
    }
  }

  /**
   * @notice Calculates the current collateral ratio on Compound, using 18 decimals
   * @return the collateral ratio
   */
  function getCurrentCollateralRatioInUSDC() public returns (uint256 _amount) {
    uint256 supply = getCurrentCollateralInUSDC();
    uint256 borrow = getCurrentBorrowInUSDC();
    if (borrow == 0) {
      return uint256(-1);
    }
    return supply.mul(PRECISION).div(borrow);
  }

  /**
   * @notice Calculates the current liquidity (supply - collateral) on the Compound platform
   * @return the liquidity
   */
  function getCurrentLiquidityInUSDC() public returns (bool _isNegative, uint256 _amount) {
    uint256 supply = getCurrentCollateralInUSDC();
    uint256 borrow = getCurrentBorrowInUSDC().mul(PRECISION).div(getMarketCollateralFactor());
    if (supply >= borrow) {
      return (false, supply.sub(borrow));
    } else {
      return (true, borrow.sub(supply));
    }
  }

  function __sellUSDCForToken(uint256 _usdcAmount) internal returns (uint256 _actualUSDCAmount, uint256 _actualTokenAmount) {
    ERC20Detailed t = __underlyingToken(compoundTokenAddr);
    (,, _actualTokenAmount, _actualUSDCAmount) = __kyberTrade(usdc, _usdcAmount, t); // Sell USDC for tokens on Kyber
    require(_actualUSDCAmount > 0 && _actualTokenAmount > 0); // Validate return values
  }

  function __sellTokenForUSDC(uint256 _tokenAmount) internal returns (uint256 _actualUSDCAmount, uint256 _actualTokenAmount) {
    ERC20Detailed t = __underlyingToken(compoundTokenAddr);
    (,, _actualUSDCAmount, _actualTokenAmount) = __kyberTrade(t, _tokenAmount, usdc); // Sell tokens for USDC on Kyber
    require(_actualUSDCAmount > 0 && _actualTokenAmount > 0); // Validate return values
  }

  // Convert a USDC amount to the amount of a given token that's of equal value
  function __usdcToToken(address _cToken, uint256 _usdcAmount) internal view returns (uint256) {
    ERC20Detailed t = __underlyingToken(_cToken);
    return _usdcAmount.mul(PRECISION).div(10 ** getDecimals(usdc)).mul(10 ** getDecimals(t)).div(ORACLE.getUnderlyingPrice(_cToken).mul(10 ** getDecimals(t)).div(PRECISION));
  }

  // Convert a compound token amount to the amount of USDC that's of equal value
  function __tokenToUSDC(address _cToken, uint256 _tokenAmount) internal view returns (uint256) {
    return _tokenAmount.mul(ORACLE.getUnderlyingPrice(_cToken)).div(PRECISION).mul(10 ** getDecimals(usdc)).div(PRECISION);
  }

  function __underlyingToken(address _cToken) internal view returns (ERC20Detailed) {
    if (_cToken == CETH_ADDR) {
      // ETH
      return ETH_TOKEN_ADDRESS;
    }
    CERC20 ct = CERC20(_cToken);
    address underlyingToken = ct.underlying();
    ERC20Detailed t = ERC20Detailed(underlyingToken);
    return t;
  }

  function() external payable {}
}
pragma solidity ^0.5.0;

import "../GSN/Context.sol";
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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

pragma solidity ^0.5.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () internal { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

pragma solidity 0.5.17;

// Compound finance comptroller
interface Comptroller {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
    function markets(address cToken) external view returns (bool isListed, uint256 collateralFactorMantissa);
}
pragma solidity 0.5.17;

// Compound finance's price oracle
interface PriceOracle {
  // returns the price of the underlying token in USD, scaled by 10**(36 - underlyingPrecision)
  function getUnderlyingPrice(address cToken) external view returns (uint);
}
pragma solidity 0.5.17;

// Compound finance ERC20 market interface
interface CERC20 {
  function mint(uint mintAmount) external returns (uint);
  function redeemUnderlying(uint redeemAmount) external returns (uint);
  function borrow(uint borrowAmount) external returns (uint);
  function repayBorrow(uint repayAmount) external returns (uint);
  function borrowBalanceCurrent(address account) external returns (uint);
  function exchangeRateCurrent() external returns (uint);

  function balanceOf(address account) external view returns (uint);
  function decimals() external view returns (uint);
  function underlying() external view returns (address);
}
pragma solidity 0.5.17;

// Compound finance Ether market interface
interface CEther {
  function mint() external payable;
  function redeemUnderlying(uint redeemAmount) external returns (uint);
  function borrow(uint borrowAmount) external returns (uint);
  function repayBorrow() external payable;
  function borrowBalanceCurrent(address account) external returns (uint);
  function exchangeRateCurrent() external returns (uint);

  function balanceOf(address account) external view returns (uint);
  function decimals() external view returns (uint);
}
pragma solidity 0.5.17;

import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/KyberNetwork.sol";
import "./interfaces/OneInchExchange.sol";

/**
 * @title The smart contract for useful utility functions and constants.
 * @author Zefram Lou (Zebang Liu)
 */
contract Utils {
  using SafeMath for uint256;
  using SafeERC20 for ERC20Detailed;

  /**
   * @notice Checks if `_token` is a valid token.
   * @param _token the token's address
   */
  modifier isValidToken(address _token) {
    require(_token != address(0));
    if (_token != address(ETH_TOKEN_ADDRESS)) {
      require(isContract(_token));
    }
    _;
  }

  address public USDC_ADDR;
  address payable public KYBER_ADDR;
  address payable public ONEINCH_ADDR;

  bytes public constant PERM_HINT = "PERM";

  // The address Kyber Network uses to represent Ether
  ERC20Detailed internal constant ETH_TOKEN_ADDRESS = ERC20Detailed(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);
  ERC20Detailed internal usdc;
  KyberNetwork internal kyber;

  uint256 constant internal PRECISION = (10**18);
  uint256 constant internal MAX_QTY   = (10**28); // 10B tokens
  uint256 constant internal ETH_DECIMALS = 18;
  uint256 constant internal MAX_DECIMALS = 18;

  constructor(
    address _usdcAddr,
    address payable _kyberAddr,
    address payable _oneInchAddr
  ) public {
    USDC_ADDR = _usdcAddr;
    KYBER_ADDR = _kyberAddr;
    ONEINCH_ADDR = _oneInchAddr;

    usdc = ERC20Detailed(_usdcAddr);
    kyber = KyberNetwork(_kyberAddr);
  }

  /**
   * @notice Get the number of decimals of a token
   * @param _token the token to be queried
   * @return number of decimals
   */
  function getDecimals(ERC20Detailed _token) internal view returns(uint256) {
    if (address(_token) == address(ETH_TOKEN_ADDRESS)) {
      return uint256(ETH_DECIMALS);
    }
    return uint256(_token.decimals());
  }

  /**
   * @notice Get the token balance of an account
   * @param _token the token to be queried
   * @param _addr the account whose balance will be returned
   * @return token balance of the account
   */
  function getBalance(ERC20Detailed _token, address _addr) internal view returns(uint256) {
    if (address(_token) == address(ETH_TOKEN_ADDRESS)) {
      return uint256(_addr.balance);
    }
    return uint256(_token.balanceOf(_addr));
  }

  /**
   * @notice Calculates the rate of a trade. The rate is the price of the source token in the dest token, in 18 decimals.
   *         Note: the rate is on the token level, not the wei level, so for example if 1 Atoken = 10 Btoken, then the rate
   *         from A to B is 10 * 10**18, regardless of how many decimals each token uses.
   * @param srcAmount amount of source token
   * @param destAmount amount of dest token
   * @param srcDecimals decimals used by source token
   * @param dstDecimals decimals used by dest token
   */
  function calcRateFromQty(uint256 srcAmount, uint256 destAmount, uint256 srcDecimals, uint256 dstDecimals)
        internal pure returns(uint)
  {
    require(srcAmount <= MAX_QTY);
    require(destAmount <= MAX_QTY);

    if (dstDecimals >= srcDecimals) {
      require((dstDecimals - srcDecimals) <= MAX_DECIMALS);
      return (destAmount * PRECISION / ((10 ** (dstDecimals - srcDecimals)) * srcAmount));
    } else {
      require((srcDecimals - dstDecimals) <= MAX_DECIMALS);
      return (destAmount * PRECISION * (10 ** (srcDecimals - dstDecimals)) / srcAmount);
    }
  }

  /**
   * @notice Wrapper function for doing token conversion on Kyber Network
   * @param _srcToken the token to convert from
   * @param _srcAmount the amount of tokens to be converted
   * @param _destToken the destination token
   * @return _destPriceInSrc the price of the dest token, in terms of source tokens
   *         _srcPriceInDest the price of the source token, in terms of dest tokens
   *         _actualDestAmount actual amount of dest token traded
   *         _actualSrcAmount actual amount of src token traded
   */
  function __kyberTrade(ERC20Detailed _srcToken, uint256 _srcAmount, ERC20Detailed _destToken)
    internal
    returns(
      uint256 _destPriceInSrc,
      uint256 _srcPriceInDest,
      uint256 _actualDestAmount,
      uint256 _actualSrcAmount
    )
  {
    require(_srcToken != _destToken);

    uint256 beforeSrcBalance = getBalance(_srcToken, address(this));
    uint256 msgValue;
    if (_srcToken != ETH_TOKEN_ADDRESS) {
      msgValue = 0;
      _srcToken.safeApprove(KYBER_ADDR, 0);
      _srcToken.safeApprove(KYBER_ADDR, _srcAmount);
    } else {
      msgValue = _srcAmount;
    }
    _actualDestAmount = kyber.tradeWithHint.value(msgValue)(
      _srcToken,
      _srcAmount,
      _destToken,
      toPayableAddr(address(this)),
      MAX_QTY,
      1,
      address(0),
      PERM_HINT
    );
    _actualSrcAmount = beforeSrcBalance.sub(getBalance(_srcToken, address(this)));
    require(_actualDestAmount > 0 && _actualSrcAmount > 0);
    _destPriceInSrc = calcRateFromQty(_actualDestAmount, _actualSrcAmount, getDecimals(_destToken), getDecimals(_srcToken));
    _srcPriceInDest = calcRateFromQty(_actualSrcAmount, _actualDestAmount, getDecimals(_srcToken), getDecimals(_destToken));
  }

  /**
   * @notice Wrapper function for doing token conversion on 1inch
   * @param _srcToken the token to convert from
   * @param _srcAmount the amount of tokens to be converted
   * @param _destToken the destination token
   * @return _destPriceInSrc the price of the dest token, in terms of source tokens
   *         _srcPriceInDest the price of the source token, in terms of dest tokens
   *         _actualDestAmount actual amount of dest token traded
   *         _actualSrcAmount actual amount of src token traded
   */
  function __oneInchTrade(ERC20Detailed _srcToken, uint256 _srcAmount, ERC20Detailed _destToken, bytes memory _calldata)
    internal
    returns(
      uint256 _destPriceInSrc,
      uint256 _srcPriceInDest,
      uint256 _actualDestAmount,
      uint256 _actualSrcAmount
    )
  {
    require(_srcToken != _destToken);

    uint256 beforeSrcBalance = getBalance(_srcToken, address(this));
    uint256 beforeDestBalance = getBalance(_destToken, address(this));
    // Note: _actualSrcAmount is being used as msgValue here, because otherwise we'd run into the stack too deep error
    if (_srcToken != ETH_TOKEN_ADDRESS) {
      _actualSrcAmount = 0;
      OneInchExchange dex = OneInchExchange(ONEINCH_ADDR);
      address approvalHandler = dex.spender();
      _srcToken.safeApprove(approvalHandler, 0);
      _srcToken.safeApprove(approvalHandler, _srcAmount);
    } else {
      _actualSrcAmount = _srcAmount;
    }

    // trade through 1inch proxy
    (bool success,) = ONEINCH_ADDR.call.value(_actualSrcAmount)(_calldata);
    require(success);

    // calculate trade amounts and price
    _actualDestAmount = getBalance(_destToken, address(this)).sub(beforeDestBalance);
    _actualSrcAmount = beforeSrcBalance.sub(getBalance(_srcToken, address(this)));
    require(_actualDestAmount > 0 && _actualSrcAmount > 0);
    _destPriceInSrc = calcRateFromQty(_actualDestAmount, _actualSrcAmount, getDecimals(_destToken), getDecimals(_srcToken));
    _srcPriceInDest = calcRateFromQty(_actualSrcAmount, _actualDestAmount, getDecimals(_srcToken), getDecimals(_destToken));
  }

  /**
   * @notice Checks if an Ethereum account is a smart contract
   * @param _addr the account to be checked
   * @return True if the account is a smart contract, false otherwise
   */
  function isContract(address _addr) internal view returns(bool) {
    uint256 size;
    if (_addr == address(0)) return false;
    assembly {
        size := extcodesize(_addr)
    }
    return size>0;
  }

  function toPayableAddr(address _addr) internal pure returns (address payable) {
    return address(uint160(_addr));
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
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }
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

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves.

        // A Solidity high level call has three parts:
        //  1. The target address is checked to verify it contains contract code
        //  2. The call itself is made, and success asserted
        //  3. The return value is decoded, which in turn checks the size of the returned data.
        // solhint-disable-next-line max-line-length
        require(address(token).isContract(), "SafeERC20: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
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
     * _Available since v2.4.0._
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
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
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
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

pragma solidity ^0.5.5;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following 
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    /**
     * @dev Converts an `address` into `address payable`. Note that this is
     * simply a type cast: the actual underlying value is not changed.
     *
     * _Available since v2.4.0._
     */
    function toPayable(address account) internal pure returns (address payable) {
        return address(uint160(account));
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     *
     * _Available since v2.4.0._
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-call-value
        (bool success, ) = recipient.call.value(amount)("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}

pragma solidity 0.5.17;

import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

/**
 * @title The interface for the Kyber Network smart contract
 * @author Zefram Lou (Zebang Liu)
 */
interface KyberNetwork {
  function getExpectedRate(ERC20Detailed src, ERC20Detailed dest, uint srcQty) external view
      returns (uint expectedRate, uint slippageRate);

  function tradeWithHint(
    ERC20Detailed src, uint srcAmount, ERC20Detailed dest, address payable destAddress, uint maxDestAmount,
    uint minConversionRate, address walletId, bytes calldata hint) external payable returns(uint);
}

pragma solidity 0.5.17;

interface OneInchExchange {
    function spender() external view returns (address);
}
pragma solidity 0.5.17;

import "./LongCERC20Order.sol";
import "./LongCEtherOrder.sol";
import "./ShortCERC20Order.sol";
import "./ShortCEtherOrder.sol";
import "../lib/CloneFactory.sol";

contract CompoundOrderFactory is CloneFactory {
  address public SHORT_CERC20_LOGIC_CONTRACT;
  address public SHORT_CEther_LOGIC_CONTRACT;
  address public LONG_CERC20_LOGIC_CONTRACT;
  address public LONG_CEther_LOGIC_CONTRACT;

  address public USDC_ADDR;
  address payable public KYBER_ADDR;
  address public COMPTROLLER_ADDR;
  address public ORACLE_ADDR;
  address public CUSDC_ADDR;
  address public CETH_ADDR;

  constructor(
    address _shortCERC20LogicContract,
    address _shortCEtherLogicContract,
    address _longCERC20LogicContract,
    address _longCEtherLogicContract,
    address _usdcAddr,
    address payable _kyberAddr,
    address _comptrollerAddr,
    address _priceOracleAddr,
    address _cUSDCAddr,
    address _cETHAddr
  ) public {
    SHORT_CERC20_LOGIC_CONTRACT = _shortCERC20LogicContract;
    SHORT_CEther_LOGIC_CONTRACT = _shortCEtherLogicContract;
    LONG_CERC20_LOGIC_CONTRACT = _longCERC20LogicContract;
    LONG_CEther_LOGIC_CONTRACT = _longCEtherLogicContract;

    USDC_ADDR = _usdcAddr;
    KYBER_ADDR = _kyberAddr;
    COMPTROLLER_ADDR = _comptrollerAddr;
    ORACLE_ADDR = _priceOracleAddr;
    CUSDC_ADDR = _cUSDCAddr;
    CETH_ADDR = _cETHAddr;
  }

  function createOrder(
    address _compoundTokenAddr,
    uint256 _cycleNumber,
    uint256 _stake,
    uint256 _collateralAmountInUSDC,
    uint256 _loanAmountInUSDC,
    bool _orderType
  ) external returns (CompoundOrder) {
    require(_compoundTokenAddr != address(0));

    CompoundOrder order;

    address payable clone;
    if (_compoundTokenAddr != CETH_ADDR) {
      if (_orderType) {
        // Short CERC20 Order
        clone = toPayableAddr(createClone(SHORT_CERC20_LOGIC_CONTRACT));
      } else {
        // Long CERC20 Order
        clone = toPayableAddr(createClone(LONG_CERC20_LOGIC_CONTRACT));
      }
    } else {
      if (_orderType) {
        // Short CEther Order
        clone = toPayableAddr(createClone(SHORT_CEther_LOGIC_CONTRACT));
      } else {
        // Long CEther Order
        clone = toPayableAddr(createClone(LONG_CEther_LOGIC_CONTRACT));
      }
    }
    order = CompoundOrder(clone);
    order.init(_compoundTokenAddr, _cycleNumber, _stake, _collateralAmountInUSDC, _loanAmountInUSDC, _orderType,
      USDC_ADDR, KYBER_ADDR, COMPTROLLER_ADDR, ORACLE_ADDR, CUSDC_ADDR, CETH_ADDR);
    order.transferOwnership(msg.sender);
    return order;
  }

  function getMarketCollateralFactor(address _compoundTokenAddr) external view returns (uint256) {
    Comptroller troll = Comptroller(COMPTROLLER_ADDR);
    (, uint256 factor) = troll.markets(_compoundTokenAddr);
    return factor;
  }

  function tokenIsListed(address _compoundTokenAddr) external view returns (bool) {
    Comptroller troll = Comptroller(COMPTROLLER_ADDR);
    (bool isListed,) = troll.markets(_compoundTokenAddr);
    return isListed;
  }

  function toPayableAddr(address _addr) internal pure returns (address payable) {
    return address(uint160(_addr));
  }
}
pragma solidity 0.5.17;

import "./CompoundOrder.sol";

contract LongCERC20Order is CompoundOrder {
  modifier isValidPrice(uint256 _minPrice, uint256 _maxPrice) {
    // Ensure token's price is between _minPrice and _maxPrice
    uint256 tokenPrice = ORACLE.getUnderlyingPrice(compoundTokenAddr); // Get the longing token's price in USD
    require(tokenPrice > 0); // Ensure asset exists on Compound
    require(tokenPrice >= _minPrice && tokenPrice <= _maxPrice); // Ensure price is within range
    _;
  }

  function executeOrder(uint256 _minPrice, uint256 _maxPrice)
    public
    onlyOwner
    isValidToken(compoundTokenAddr)
    isValidPrice(_minPrice, _maxPrice)
  {
    buyTime = now;

    // Get funds in USDC from PeakDeFiFund
    usdc.safeTransferFrom(owner(), address(this), collateralAmountInUSDC); // Transfer USDC from PeakDeFiFund

    // Convert received USDC to longing token
    (,uint256 actualTokenAmount) = __sellUSDCForToken(collateralAmountInUSDC);

    // Enter Compound markets
    CERC20 market = CERC20(compoundTokenAddr);
    address[] memory markets = new address[](2);
    markets[0] = compoundTokenAddr;
    markets[1] = address(CUSDC);
    uint[] memory errors = COMPTROLLER.enterMarkets(markets);
    require(errors[0] == 0 && errors[1] == 0);

    // Get loan from Compound in USDC
    ERC20Detailed token = __underlyingToken(compoundTokenAddr);
    token.safeApprove(compoundTokenAddr, 0); // Clear token allowance of Compound
    token.safeApprove(compoundTokenAddr, actualTokenAmount); // Approve token transfer to Compound
    require(market.mint(actualTokenAmount) == 0); // Transfer tokens into Compound as supply
    token.safeApprove(compoundTokenAddr, 0); // Clear token allowance of Compound
    require(CUSDC.borrow(loanAmountInUSDC) == 0);// Take out loan in USDC
    (bool negLiquidity, ) = getCurrentLiquidityInUSDC();
    require(!negLiquidity); // Ensure account liquidity is positive

    // Convert borrowed USDC to longing token
    __sellUSDCForToken(loanAmountInUSDC);

    // Repay leftover USDC to avoid complications
    if (usdc.balanceOf(address(this)) > 0) {
      uint256 repayAmount = usdc.balanceOf(address(this));
      usdc.safeApprove(address(CUSDC), 0);
      usdc.safeApprove(address(CUSDC), repayAmount);
      require(CUSDC.repayBorrow(repayAmount) == 0);
      usdc.safeApprove(address(CUSDC), 0);
    }
  }

  function sellOrder(uint256 _minPrice, uint256 _maxPrice)
    public
    onlyOwner
    isValidPrice(_minPrice, _maxPrice)
    returns (uint256 _inputAmount, uint256 _outputAmount)
  {
    require(buyTime > 0); // Ensure the order has been executed
    require(isSold == false);
    isSold = true;
    
    // Siphon remaining collateral by repaying x USDC and getting back 1.5x USDC collateral
    // Repeat to ensure debt is exhausted
    CERC20 market = CERC20(compoundTokenAddr);
    ERC20Detailed token = __underlyingToken(compoundTokenAddr);
    for (uint256 i = 0; i < MAX_REPAY_STEPS; i++) {
      uint256 currentDebt = getCurrentBorrowInUSDC();
      if (currentDebt > NEGLIGIBLE_DEBT) {
        // Determine amount to be repaid this step
        uint256 currentBalance = getCurrentCashInUSDC();
        uint256 repayAmount = 0; // amount to be repaid in USDC
        if (currentDebt <= currentBalance) {
          // Has enough money, repay all debt
          repayAmount = currentDebt;
        } else {
          // Doesn't have enough money, repay whatever we can repay
          repayAmount = currentBalance;
        }

        // Repay debt
        repayLoan(repayAmount);
      }

      // Withdraw all available liquidity
      (bool isNeg, uint256 liquidity) = getCurrentLiquidityInUSDC();
      if (!isNeg) {
        liquidity = __usdcToToken(compoundTokenAddr, liquidity);
        uint256 errorCode = market.redeemUnderlying(liquidity.mul(PRECISION.sub(DEFAULT_LIQUIDITY_SLIPPAGE)).div(PRECISION));
        if (errorCode != 0) {
          // error
          // try again with fallback slippage
          errorCode = market.redeemUnderlying(liquidity.mul(PRECISION.sub(FALLBACK_LIQUIDITY_SLIPPAGE)).div(PRECISION));
          if (errorCode != 0) {
            // error
            // try again with max slippage
            market.redeemUnderlying(liquidity.mul(PRECISION.sub(MAX_LIQUIDITY_SLIPPAGE)).div(PRECISION));
          }
        }
      }

      if (currentDebt <= NEGLIGIBLE_DEBT) {
        break;
      }
    }

    // Sell all longing token to USDC
    __sellTokenForUSDC(token.balanceOf(address(this)));

    // Send USDC back to PeakDeFiFund and return
    _inputAmount = collateralAmountInUSDC;
    _outputAmount = usdc.balanceOf(address(this));
    outputAmount = _outputAmount;
    usdc.safeTransfer(owner(), usdc.balanceOf(address(this)));
    uint256 leftoverTokens = token.balanceOf(address(this));
    if (leftoverTokens > 0) {
      token.safeTransfer(owner(), leftoverTokens); // Send back potential leftover tokens
    }
  }

  // Allows manager to repay loan to avoid liquidation
  function repayLoan(uint256 _repayAmountInUSDC) public onlyOwner {
    require(buyTime > 0); // Ensure the order has been executed

    // Convert longing token to USDC
    uint256 repayAmountInToken = __usdcToToken(compoundTokenAddr, _repayAmountInUSDC);
    (uint256 actualUSDCAmount,) = __sellTokenForUSDC(repayAmountInToken);
    
    // Check if amount is greater than borrow balance
    uint256 currentDebt = CUSDC.borrowBalanceCurrent(address(this));
    if (actualUSDCAmount > currentDebt) {
      actualUSDCAmount = currentDebt;
    }
    
    // Repay loan to Compound
    usdc.safeApprove(address(CUSDC), 0);
    usdc.safeApprove(address(CUSDC), actualUSDCAmount);
    require(CUSDC.repayBorrow(actualUSDCAmount) == 0);
    usdc.safeApprove(address(CUSDC), 0);
  }

  function getMarketCollateralFactor() public view returns (uint256) {
    (, uint256 ratio) = COMPTROLLER.markets(address(compoundTokenAddr));
    return ratio;
  }

  function getCurrentCollateralInUSDC() public returns (uint256 _amount) {
    CERC20 market = CERC20(compoundTokenAddr);
    uint256 supply = __tokenToUSDC(compoundTokenAddr, market.balanceOf(address(this)).mul(market.exchangeRateCurrent()).div(PRECISION));
    return supply;
  }

  function getCurrentBorrowInUSDC() public returns (uint256 _amount) {
    uint256 borrow = CUSDC.borrowBalanceCurrent(address(this));
    return borrow;
  }

  function getCurrentCashInUSDC() public view returns (uint256 _amount) {
    ERC20Detailed token = __underlyingToken(compoundTokenAddr);
    uint256 cash = __tokenToUSDC(compoundTokenAddr, getBalance(token, address(this)));
    return cash;
  }
}
pragma solidity 0.5.17;

import "./CompoundOrder.sol";

contract LongCEtherOrder is CompoundOrder {
  modifier isValidPrice(uint256 _minPrice, uint256 _maxPrice) {
    // Ensure token's price is between _minPrice and _maxPrice
    uint256 tokenPrice = ORACLE.getUnderlyingPrice(compoundTokenAddr); // Get the longing token's price in USD
    require(tokenPrice > 0); // Ensure asset exists on Compound
    require(tokenPrice >= _minPrice && tokenPrice <= _maxPrice); // Ensure price is within range
    _;
  }

  function executeOrder(uint256 _minPrice, uint256 _maxPrice)
    public
    onlyOwner
    isValidToken(compoundTokenAddr)
    isValidPrice(_minPrice, _maxPrice)
  {
    buyTime = now;
    
    // Get funds in USDC from PeakDeFiFund
    usdc.safeTransferFrom(owner(), address(this), collateralAmountInUSDC); // Transfer USDC from PeakDeFiFund

    // Convert received USDC to longing token
    (,uint256 actualTokenAmount) = __sellUSDCForToken(collateralAmountInUSDC);

    // Enter Compound markets
    CEther market = CEther(compoundTokenAddr);
    address[] memory markets = new address[](2);
    markets[0] = compoundTokenAddr;
    markets[1] = address(CUSDC);
    uint[] memory errors = COMPTROLLER.enterMarkets(markets);
    require(errors[0] == 0 && errors[1] == 0);
    
    // Get loan from Compound in USDC
    market.mint.value(actualTokenAmount)(); // Transfer tokens into Compound as supply
    require(CUSDC.borrow(loanAmountInUSDC) == 0);// Take out loan in USDC
    (bool negLiquidity, ) = getCurrentLiquidityInUSDC();
    require(!negLiquidity); // Ensure account liquidity is positive

    // Convert borrowed USDC to longing token
    __sellUSDCForToken(loanAmountInUSDC);

    // Repay leftover USDC to avoid complications
    if (usdc.balanceOf(address(this)) > 0) {
      uint256 repayAmount = usdc.balanceOf(address(this));
      usdc.safeApprove(address(CUSDC), 0);
      usdc.safeApprove(address(CUSDC), repayAmount);
      require(CUSDC.repayBorrow(repayAmount) == 0);
      usdc.safeApprove(address(CUSDC), 0);
    }
  }

  function sellOrder(uint256 _minPrice, uint256 _maxPrice)
    public
    onlyOwner
    isValidPrice(_minPrice, _maxPrice)
    returns (uint256 _inputAmount, uint256 _outputAmount)
  {
    require(buyTime > 0); // Ensure the order has been executed
    require(isSold == false);
    isSold = true;

    // Siphon remaining collateral by repaying x USDC and getting back 1.5x USDC collateral
    // Repeat to ensure debt is exhausted
    CEther market = CEther(compoundTokenAddr);
    for (uint256 i = 0; i < MAX_REPAY_STEPS; i++) {
      uint256 currentDebt = getCurrentBorrowInUSDC();
      if (currentDebt > NEGLIGIBLE_DEBT) {
        // Determine amount to be repaid this step
        uint256 currentBalance = getCurrentCashInUSDC();
        uint256 repayAmount = 0; // amount to be repaid in USDC
        if (currentDebt <= currentBalance) {
          // Has enough money, repay all debt
          repayAmount = currentDebt;
        } else {
          // Doesn't have enough money, repay whatever we can repay
          repayAmount = currentBalance;
        }

        // Repay debt
        repayLoan(repayAmount);
      }

      // Withdraw all available liquidity
      (bool isNeg, uint256 liquidity) = getCurrentLiquidityInUSDC();
      if (!isNeg) {
        liquidity = __usdcToToken(compoundTokenAddr, liquidity);
        uint256 errorCode = market.redeemUnderlying(liquidity.mul(PRECISION.sub(DEFAULT_LIQUIDITY_SLIPPAGE)).div(PRECISION));
        if (errorCode != 0) {
          // error
          // try again with fallback slippage
          errorCode = market.redeemUnderlying(liquidity.mul(PRECISION.sub(FALLBACK_LIQUIDITY_SLIPPAGE)).div(PRECISION));
          if (errorCode != 0) {
            // error
            // try again with max slippage
            market.redeemUnderlying(liquidity.mul(PRECISION.sub(MAX_LIQUIDITY_SLIPPAGE)).div(PRECISION));
          }
        }
      }

      if (currentDebt <= NEGLIGIBLE_DEBT) {
        break;
      }
    }

    // Sell all longing token to USDC
    __sellTokenForUSDC(address(this).balance);

    // Send USDC back to PeakDeFiFund and return
    _inputAmount = collateralAmountInUSDC;
    _outputAmount = usdc.balanceOf(address(this));
    outputAmount = _outputAmount;
    usdc.safeTransfer(owner(), usdc.balanceOf(address(this)));
    toPayableAddr(owner()).transfer(address(this).balance); // Send back potential leftover tokens
  }

  // Allows manager to repay loan to avoid liquidation
  function repayLoan(uint256 _repayAmountInUSDC) public onlyOwner {
    require(buyTime > 0); // Ensure the order has been executed

    // Convert longing token to USDC
    uint256 repayAmountInToken = __usdcToToken(compoundTokenAddr, _repayAmountInUSDC);
    (uint256 actualUSDCAmount,) = __sellTokenForUSDC(repayAmountInToken);
    
    // Check if amount is greater than borrow balance
    uint256 currentDebt = CUSDC.borrowBalanceCurrent(address(this));
    if (actualUSDCAmount > currentDebt) {
      actualUSDCAmount = currentDebt;
    }

    // Repay loan to Compound
    usdc.safeApprove(address(CUSDC), 0);
    usdc.safeApprove(address(CUSDC), actualUSDCAmount);
    require(CUSDC.repayBorrow(actualUSDCAmount) == 0);
    usdc.safeApprove(address(CUSDC), 0);
  }

  function getMarketCollateralFactor() public view returns (uint256) {
    (, uint256 ratio) = COMPTROLLER.markets(address(compoundTokenAddr));
    return ratio;
  }

  function getCurrentCollateralInUSDC() public returns (uint256 _amount) {
    CEther market = CEther(compoundTokenAddr);
    uint256 supply = __tokenToUSDC(compoundTokenAddr, market.balanceOf(address(this)).mul(market.exchangeRateCurrent()).div(PRECISION));
    return supply;
  }

  function getCurrentBorrowInUSDC() public returns (uint256 _amount) {
    uint256 borrow = CUSDC.borrowBalanceCurrent(address(this));
    return borrow;
  }

  function getCurrentCashInUSDC() public view returns (uint256 _amount) {
    ERC20Detailed token = __underlyingToken(compoundTokenAddr);
    uint256 cash = __tokenToUSDC(compoundTokenAddr, getBalance(token, address(this)));
    return cash;
  }
}
pragma solidity 0.5.17;

import "./CompoundOrder.sol";

contract ShortCERC20Order is CompoundOrder {
  modifier isValidPrice(uint256 _minPrice, uint256 _maxPrice) {
    // Ensure token's price is between _minPrice and _maxPrice
    uint256 tokenPrice = ORACLE.getUnderlyingPrice(compoundTokenAddr); // Get the shorting token's price in USD
    require(tokenPrice > 0); // Ensure asset exists on Compound
    require(tokenPrice >= _minPrice && tokenPrice <= _maxPrice); // Ensure price is within range
    _;
  }

  function executeOrder(uint256 _minPrice, uint256 _maxPrice)
    public
    onlyOwner
    isValidToken(compoundTokenAddr)
    isValidPrice(_minPrice, _maxPrice)
  {
    buyTime = now;

    // Get funds in USDC from PeakDeFiFund
    usdc.safeTransferFrom(owner(), address(this), collateralAmountInUSDC); // Transfer USDC from PeakDeFiFund

    // Enter Compound markets
    CERC20 market = CERC20(compoundTokenAddr);
    address[] memory markets = new address[](2);
    markets[0] = compoundTokenAddr;
    markets[1] = address(CUSDC);
    uint[] memory errors = COMPTROLLER.enterMarkets(markets);
    require(errors[0] == 0 && errors[1] == 0);
    
    // Get loan from Compound in tokenAddr
    uint256 loanAmountInToken = __usdcToToken(compoundTokenAddr, loanAmountInUSDC);
    usdc.safeApprove(address(CUSDC), 0); // Clear USDC allowance of Compound USDC market
    usdc.safeApprove(address(CUSDC), collateralAmountInUSDC); // Approve USDC transfer to Compound USDC market
    require(CUSDC.mint(collateralAmountInUSDC) == 0); // Transfer USDC into Compound as supply
    usdc.safeApprove(address(CUSDC), 0);
    require(market.borrow(loanAmountInToken) == 0);// Take out loan
    (bool negLiquidity, ) = getCurrentLiquidityInUSDC();
    require(!negLiquidity); // Ensure account liquidity is positive

    // Convert loaned tokens to USDC
    (uint256 actualUSDCAmount,) = __sellTokenForUSDC(loanAmountInToken);
    loanAmountInUSDC = actualUSDCAmount; // Change loan amount to actual USDC received

    // Repay leftover tokens to avoid complications
    ERC20Detailed token = __underlyingToken(compoundTokenAddr);
    if (token.balanceOf(address(this)) > 0) {
      uint256 repayAmount = token.balanceOf(address(this));
      token.safeApprove(compoundTokenAddr, 0);
      token.safeApprove(compoundTokenAddr, repayAmount);
      require(market.repayBorrow(repayAmount) == 0);
      token.safeApprove(compoundTokenAddr, 0);
    }
  }

  function sellOrder(uint256 _minPrice, uint256 _maxPrice)
    public
    onlyOwner
    isValidPrice(_minPrice, _maxPrice)
    returns (uint256 _inputAmount, uint256 _outputAmount)
  {
    require(buyTime > 0); // Ensure the order has been executed
    require(isSold == false);
    isSold = true;

    // Siphon remaining collateral by repaying x USDC and getting back 1.5x USDC collateral
    // Repeat to ensure debt is exhausted
    for (uint256 i = 0; i < MAX_REPAY_STEPS; i++) {
      uint256 currentDebt = getCurrentBorrowInUSDC();
      if (currentDebt > NEGLIGIBLE_DEBT) {
        // Determine amount to be repaid this step
        uint256 currentBalance = getCurrentCashInUSDC();
        uint256 repayAmount = 0; // amount to be repaid in USDC
        if (currentDebt <= currentBalance) {
          // Has enough money, repay all debt
          repayAmount = currentDebt;
        } else {
          // Doesn't have enough money, repay whatever we can repay
          repayAmount = currentBalance;
        }

        // Repay debt
        repayLoan(repayAmount);
      }

      // Withdraw all available liquidity
      (bool isNeg, uint256 liquidity) = getCurrentLiquidityInUSDC();
      if (!isNeg) {
        uint256 errorCode = CUSDC.redeemUnderlying(liquidity.mul(PRECISION.sub(DEFAULT_LIQUIDITY_SLIPPAGE)).div(PRECISION));
        if (errorCode != 0) {
          // error
          // try again with fallback slippage
          errorCode = CUSDC.redeemUnderlying(liquidity.mul(PRECISION.sub(FALLBACK_LIQUIDITY_SLIPPAGE)).div(PRECISION));
          if (errorCode != 0) {
            // error
            // try again with max slippage
            CUSDC.redeemUnderlying(liquidity.mul(PRECISION.sub(MAX_LIQUIDITY_SLIPPAGE)).div(PRECISION));
          }
        }
      }

      if (currentDebt <= NEGLIGIBLE_DEBT) {
        break;
      }
    }

    // Send USDC back to PeakDeFiFund and return
    _inputAmount = collateralAmountInUSDC;
    _outputAmount = usdc.balanceOf(address(this));
    outputAmount = _outputAmount;
    usdc.safeTransfer(owner(), usdc.balanceOf(address(this)));
  }

  // Allows manager to repay loan to avoid liquidation
  function repayLoan(uint256 _repayAmountInUSDC) public onlyOwner {
    require(buyTime > 0); // Ensure the order has been executed

    // Convert USDC to shorting token
    (,uint256 actualTokenAmount) = __sellUSDCForToken(_repayAmountInUSDC);

    // Check if amount is greater than borrow balance
    CERC20 market = CERC20(compoundTokenAddr);
    uint256 currentDebt = market.borrowBalanceCurrent(address(this));
    if (actualTokenAmount > currentDebt) {
      actualTokenAmount = currentDebt;
    }

    // Repay loan to Compound
    ERC20Detailed token = __underlyingToken(compoundTokenAddr);
    token.safeApprove(compoundTokenAddr, 0);
    token.safeApprove(compoundTokenAddr, actualTokenAmount);
    require(market.repayBorrow(actualTokenAmount) == 0);
    token.safeApprove(compoundTokenAddr, 0);
  }

  function getMarketCollateralFactor() public view returns (uint256) {
    (, uint256 ratio) = COMPTROLLER.markets(address(CUSDC));
    return ratio;
  }

  function getCurrentCollateralInUSDC() public returns (uint256 _amount) {
    uint256 supply = CUSDC.balanceOf(address(this)).mul(CUSDC.exchangeRateCurrent()).div(PRECISION);
    return supply;
  }

  function getCurrentBorrowInUSDC() public returns (uint256 _amount) {
    CERC20 market = CERC20(compoundTokenAddr);
    uint256 borrow = __tokenToUSDC(compoundTokenAddr, market.borrowBalanceCurrent(address(this)));
    return borrow;
  }

  function getCurrentCashInUSDC() public view returns (uint256 _amount) {
    uint256 cash = getBalance(usdc, address(this));
    return cash;
  }
}
pragma solidity 0.5.17;

import "./CompoundOrder.sol";

contract ShortCEtherOrder is CompoundOrder {
  modifier isValidPrice(uint256 _minPrice, uint256 _maxPrice) {
    // Ensure token's price is between _minPrice and _maxPrice
    uint256 tokenPrice = ORACLE.getUnderlyingPrice(compoundTokenAddr); // Get the shorting token's price in USD
    require(tokenPrice > 0); // Ensure asset exists on Compound
    require(tokenPrice >= _minPrice && tokenPrice <= _maxPrice); // Ensure price is within range
    _;
  }

  function executeOrder(uint256 _minPrice, uint256 _maxPrice)
    public
    onlyOwner
    isValidToken(compoundTokenAddr)
    isValidPrice(_minPrice, _maxPrice)
  {
    buyTime = now;

    // Get funds in USDC from PeakDeFiFund
    usdc.safeTransferFrom(owner(), address(this), collateralAmountInUSDC); // Transfer USDC from PeakDeFiFund
    
    // Enter Compound markets
    CEther market = CEther(compoundTokenAddr);
    address[] memory markets = new address[](2);
    markets[0] = compoundTokenAddr;
    markets[1] = address(CUSDC);
    uint[] memory errors = COMPTROLLER.enterMarkets(markets);
    require(errors[0] == 0 && errors[1] == 0);

    // Get loan from Compound in tokenAddr
    uint256 loanAmountInToken = __usdcToToken(compoundTokenAddr, loanAmountInUSDC);
    usdc.safeApprove(address(CUSDC), 0); // Clear USDC allowance of Compound USDC market
    usdc.safeApprove(address(CUSDC), collateralAmountInUSDC); // Approve USDC transfer to Compound USDC market
    require(CUSDC.mint(collateralAmountInUSDC) == 0); // Transfer USDC into Compound as supply
    usdc.safeApprove(address(CUSDC), 0);
    require(market.borrow(loanAmountInToken) == 0);// Take out loan
    (bool negLiquidity, ) = getCurrentLiquidityInUSDC();
    require(!negLiquidity); // Ensure account liquidity is positive

    // Convert loaned tokens to USDC
    (uint256 actualUSDCAmount,) = __sellTokenForUSDC(loanAmountInToken);
    loanAmountInUSDC = actualUSDCAmount; // Change loan amount to actual USDC received

    // Repay leftover tokens to avoid complications
    if (address(this).balance > 0) {
      uint256 repayAmount = address(this).balance;
      market.repayBorrow.value(repayAmount)();
    }
  }

  function sellOrder(uint256 _minPrice, uint256 _maxPrice)
    public
    onlyOwner
    isValidPrice(_minPrice, _maxPrice)
    returns (uint256 _inputAmount, uint256 _outputAmount)
  {
    require(buyTime > 0); // Ensure the order has been executed
    require(isSold == false);
    isSold = true;

    // Siphon remaining collateral by repaying x USDC and getting back 1.5x USDC collateral
    // Repeat to ensure debt is exhausted
    for (uint256 i = 0; i < MAX_REPAY_STEPS; i = i++) {
      uint256 currentDebt = getCurrentBorrowInUSDC();
      if (currentDebt > NEGLIGIBLE_DEBT) {
        // Determine amount to be repaid this step
        uint256 currentBalance = getCurrentCashInUSDC();
        uint256 repayAmount = 0; // amount to be repaid in USDC
        if (currentDebt <= currentBalance) {
          // Has enough money, repay all debt
          repayAmount = currentDebt;
        } else {
          // Doesn't have enough money, repay whatever we can repay
          repayAmount = currentBalance;
        }

        // Repay debt
        repayLoan(repayAmount);
      }

      // Withdraw all available liquidity
      (bool isNeg, uint256 liquidity) = getCurrentLiquidityInUSDC();
      if (!isNeg) {
        uint256 errorCode = CUSDC.redeemUnderlying(liquidity.mul(PRECISION.sub(DEFAULT_LIQUIDITY_SLIPPAGE)).div(PRECISION));
        if (errorCode != 0) {
          // error
          // try again with fallback slippage
          errorCode = CUSDC.redeemUnderlying(liquidity.mul(PRECISION.sub(FALLBACK_LIQUIDITY_SLIPPAGE)).div(PRECISION));
          if (errorCode != 0) {
            // error
            // try again with max slippage
            CUSDC.redeemUnderlying(liquidity.mul(PRECISION.sub(MAX_LIQUIDITY_SLIPPAGE)).div(PRECISION));
          }
        }
      }

      if (currentDebt <= NEGLIGIBLE_DEBT) {
        break;
      }
    }

    // Send USDC back to PeakDeFiFund and return
    _inputAmount = collateralAmountInUSDC;
    _outputAmount = usdc.balanceOf(address(this));
    outputAmount = _outputAmount;
    usdc.safeTransfer(owner(), usdc.balanceOf(address(this)));
  }

  // Allows manager to repay loan to avoid liquidation
  function repayLoan(uint256 _repayAmountInUSDC) public onlyOwner {
    require(buyTime > 0); // Ensure the order has been executed

    // Convert USDC to shorting token
    (,uint256 actualTokenAmount) = __sellUSDCForToken(_repayAmountInUSDC);

    // Check if amount is greater than borrow balance
    CEther market = CEther(compoundTokenAddr);
    uint256 currentDebt = market.borrowBalanceCurrent(address(this));
    if (actualTokenAmount > currentDebt) {
      actualTokenAmount = currentDebt;
    }

    // Repay loan to Compound
    market.repayBorrow.value(actualTokenAmount)();
  }

  function getMarketCollateralFactor() public view returns (uint256) {
    (, uint256 ratio) = COMPTROLLER.markets(address(CUSDC));
    return ratio;
  }

  function getCurrentCollateralInUSDC() public returns (uint256 _amount) {
    uint256 supply = CUSDC.balanceOf(address(this)).mul(CUSDC.exchangeRateCurrent()).div(PRECISION);
    return supply;
  }

  function getCurrentBorrowInUSDC() public returns (uint256 _amount) {
    CEther market = CEther(compoundTokenAddr);
    uint256 borrow = __tokenToUSDC(compoundTokenAddr, market.borrowBalanceCurrent(address(this)));
    return borrow;
  }

  function getCurrentCashInUSDC() public view returns (uint256 _amount) {
    uint256 cash = getBalance(usdc, address(this));
    return cash;
  }
}
pragma solidity 0.5.17;

/*
The MIT License (MIT)

Copyright (c) 2018 Murray Software, LLC.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
//solhint-disable max-line-length
//solhint-disable no-inline-assembly

contract CloneFactory {

  function createClone(address target) internal returns (address result) {
    bytes20 targetBytes = bytes20(target);
    assembly {
      let clone := mload(0x40)
      mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
      mstore(add(clone, 0x14), targetBytes)
      mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
      result := create(0, clone, 0x37)
    }
  }

  function isClone(address target, address query) internal view returns (bool result) {
    bytes20 targetBytes = bytes20(target);
    assembly {
      let clone := mload(0x40)
      mstore(clone, 0x363d3d373d3d3d363d7300000000000000000000000000000000000000000000)
      mstore(add(clone, 0xa), targetBytes)
      mstore(add(clone, 0x1e), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)

      let other := add(clone, 0x40)
      extcodecopy(query, other, 0, 0x2d)
      result := and(
        eq(mload(clone), mload(other)),
        eq(mload(add(clone, 0xd)), mload(add(other, 0xd)))
      )
    }
  }
}

pragma solidity 0.5.17;

interface IMiniMeToken {
    function balanceOf(address _owner) external view returns (uint256 balance);
    function totalSupply() external view returns(uint);
    function generateTokens(address _owner, uint _amount) external returns (bool);
    function destroyTokens(address _owner, uint _amount) external returns (bool);
    function totalSupplyAt(uint _blockNumber) external view returns(uint);
    function balanceOfAt(address _holder, uint _blockNumber) external view returns (uint);
    function transferOwnership(address newOwner) external;
}
pragma solidity ^0.5.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 *
 * _Since v2.5.0:_ this module is now much more gas efficient, given net gas
 * metering changes introduced in the Istanbul hardfork.
 */
contract ReentrancyGuard {
    bool private _notEntered;

    function __initReentrancyGuard() internal {
        // Storing an initial non-zero value makes deployment a bit more
        // expensive, but in exchange the refund on every call to nonReentrant
        // will be lower in amount. Since refunds are capped to a percetange of
        // the total transaction's gas, it is best to keep them low in cases
        // like this one, to increase the likelihood of the full refund coming
        // into effect.
        _notEntered = true;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_notEntered, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _notEntered = false;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _notEntered = true;
    }
}

pragma solidity 0.5.17;

contract Migrations {
  address public owner;
  uint public last_completed_migration;

  modifier restricted() {
    if (msg.sender == owner) _;
  }

  constructor() public {
    owner = msg.sender;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }

  function upgrade(address new_address) public restricted {
    Migrations upgraded = Migrations(new_address);
    upgraded.setCompleted(last_completed_migration);
  }
}

pragma solidity 0.5.17;

// interface for contract_v6/UniswapOracle.sol
interface IUniswapOracle {
    function update() external returns (bool success);

    function consult(address token, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);
}

pragma solidity 0.5.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract PeakToken is ERC20, ERC20Detailed, ERC20Capped, ERC20Burnable {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 cap
    ) ERC20Detailed(name, symbol, decimals) ERC20Capped(cap) public {}
}
pragma solidity ^0.5.0;

import "../../GSN/Context.sol";
import "./IERC20.sol";
import "../../math/SafeMath.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20Mintable}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
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
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

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
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(_msgSender(), recipient, amount);
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
        _approve(_msgSender(), spender, amount);
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
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
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

    /**
     * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See {_burn} and {_approve}.
     */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "ERC20: burn amount exceeds allowance"));
    }
}

pragma solidity ^0.5.0;

import "./ERC20Mintable.sol";

/**
 * @dev Extension of {ERC20Mintable} that adds a cap to the supply of tokens.
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
     * @dev See {ERC20Mintable-mint}.
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

import "./ERC20.sol";
import "../../access/roles/MinterRole.sol";

/**
 * @dev Extension of {ERC20} that adds a set of accounts with the {MinterRole},
 * which have permission to mint (create) new tokens as they see fit.
 *
 * At construction, the deployer of the contract is the only minter.
 */
contract ERC20Mintable is ERC20, MinterRole {
    /**
     * @dev See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the {MinterRole}.
     */
    function mint(address account, uint256 amount) public onlyMinter returns (bool) {
        _mint(account, amount);
        return true;
    }
}

pragma solidity ^0.5.0;

import "../../GSN/Context.sol";
import "../Roles.sol";

contract MinterRole is Context {
    using Roles for Roles.Role;

    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);

    Roles.Role private _minters;

    constructor () internal {
        _addMinter(_msgSender());
    }

    modifier onlyMinter() {
        require(isMinter(_msgSender()), "MinterRole: caller does not have the Minter role");
        _;
    }

    function isMinter(address account) public view returns (bool) {
        return _minters.has(account);
    }

    function addMinter(address account) public onlyMinter {
        _addMinter(account);
    }

    function renounceMinter() public {
        _removeMinter(_msgSender());
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

import "../../GSN/Context.sol";
import "./ERC20.sol";

/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
contract ERC20Burnable is Context, ERC20 {
    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev See {ERC20-_burnFrom}.
     */
    function burnFrom(address account, uint256 amount) public {
        _burnFrom(account, amount);
    }
}

pragma solidity 0.5.17;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/roles/SignerRole.sol";
import "../staking/PeakStaking.sol";
import "../PeakToken.sol";
import "../IUniswapOracle.sol";

contract PeakReward is SignerRole {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Register(address user, address referrer);
    event RankChange(address user, uint256 oldRank, uint256 newRank);
    event PayCommission(
        address referrer,
        address recipient,
        address token,
        uint256 amount,
        uint8 level
    );
    event ChangedCareerValue(address user, uint256 changeAmount, bool positive);
    event ReceiveRankReward(address user, uint256 peakReward);

    modifier regUser(address user) {
        if (!isUser[user]) {
            isUser[user] = true;
            emit Register(user, address(0));
        }
        _;
    }

    uint256 public constant PEAK_MINT_CAP = 5 * 10**15; // 50 million PEAK

    uint256 internal constant COMMISSION_RATE = 20 * (10**16); // 20%
    uint256 internal constant PEAK_PRECISION = 10**8;
    uint256 internal constant USDC_PRECISION = 10**6;
    uint8 internal constant COMMISSION_LEVELS = 8;

    mapping(address => address) public referrerOf;
    mapping(address => bool) public isUser;
    mapping(address => uint256) public careerValue; // AKA DSV
    mapping(address => uint256) public rankOf;
    mapping(uint256 => mapping(uint256 => uint256)) public rankReward; // (beforeRank, afterRank) => rewardInPeak
    mapping(address => mapping(uint256 => uint256)) public downlineRanks; // (referrer, rank) => numReferredUsersWithRank

    uint256[] public commissionPercentages;
    uint256[] public commissionStakeRequirements;
    uint256 public mintedPeakTokens;

    address public marketPeakWallet;
    PeakStaking public peakStaking;
    PeakToken public peakToken;
    address public stablecoin;
    IUniswapOracle public oracle;

    constructor(
        address _marketPeakWallet,
        address _peakStaking,
        address _peakToken,
        address _stablecoin,
        address _oracle
    ) public {
        // initialize commission percentages for each level
        commissionPercentages.push(10 * (10**16)); // 10%
        commissionPercentages.push(4 * (10**16)); // 4%
        commissionPercentages.push(2 * (10**16)); // 2%
        commissionPercentages.push(1 * (10**16)); // 1%
        commissionPercentages.push(1 * (10**16)); // 1%
        commissionPercentages.push(1 * (10**16)); // 1%
        commissionPercentages.push(5 * (10**15)); // 0.5%
        commissionPercentages.push(5 * (10**15)); // 0.5%

        // initialize commission stake requirements for each level
        commissionStakeRequirements.push(0);
        commissionStakeRequirements.push(PEAK_PRECISION.mul(2000));
        commissionStakeRequirements.push(PEAK_PRECISION.mul(4000));
        commissionStakeRequirements.push(PEAK_PRECISION.mul(6000));
        commissionStakeRequirements.push(PEAK_PRECISION.mul(7000));
        commissionStakeRequirements.push(PEAK_PRECISION.mul(8000));
        commissionStakeRequirements.push(PEAK_PRECISION.mul(9000));
        commissionStakeRequirements.push(PEAK_PRECISION.mul(10000));

        // initialize rank rewards
        for (uint256 i = 0; i < 8; i = i.add(1)) {
            uint256 rewardInUSDC = 0;
            for (uint256 j = i.add(1); j <= 8; j = j.add(1)) {
                if (j == 1) {
                    rewardInUSDC = rewardInUSDC.add(USDC_PRECISION.mul(100));
                } else if (j == 2) {
                    rewardInUSDC = rewardInUSDC.add(USDC_PRECISION.mul(300));
                } else if (j == 3) {
                    rewardInUSDC = rewardInUSDC.add(USDC_PRECISION.mul(600));
                } else if (j == 4) {
                    rewardInUSDC = rewardInUSDC.add(USDC_PRECISION.mul(1200));
                } else if (j == 5) {
                    rewardInUSDC = rewardInUSDC.add(USDC_PRECISION.mul(2400));
                } else if (j == 6) {
                    rewardInUSDC = rewardInUSDC.add(USDC_PRECISION.mul(7500));
                } else if (j == 7) {
                    rewardInUSDC = rewardInUSDC.add(USDC_PRECISION.mul(15000));
                } else {
                    rewardInUSDC = rewardInUSDC.add(USDC_PRECISION.mul(50000));
                }
                rankReward[i][j] = rewardInUSDC;
            }
        }

        marketPeakWallet = _marketPeakWallet;
        peakStaking = PeakStaking(_peakStaking);
        peakToken = PeakToken(_peakToken);
        stablecoin = _stablecoin;
        oracle = IUniswapOracle(_oracle);
    }

      /**
        @notice Registers a group of referrals relationship.
        @param users The array of users
        @param referrers The group of referrers of `users`
     */
    function multiRefer(address[] calldata users, address[] calldata referrers) external onlySigner {
      require(users.length == referrers.length, "PeakReward: arrays length are not equal");
      for (uint256 i = 0; i < users.length; i++) {
        refer(users[i], referrers[i]);
      }
    }

    /**
        @notice Registers a referral relationship
        @param user The user who is being referred
        @param referrer The referrer of `user`
     */
    function refer(address user, address referrer) public onlySigner {
        require(!isUser[user], "PeakReward: referred is already a user");
        require(user != referrer, "PeakReward: can't refer self");
        require(
            user != address(0) && referrer != address(0),
            "PeakReward: 0 address"
        );

        isUser[user] = true;
        isUser[referrer] = true;

        referrerOf[user] = referrer;
        downlineRanks[referrer][0] = downlineRanks[referrer][0].add(1);

        emit Register(user, referrer);
    }

    function canRefer(address user, address referrer)
        public
        view
        returns (bool)
    {
        return
            !isUser[user] &&
            user != referrer &&
            user != address(0) &&
            referrer != address(0);
    }

    /**
        @notice Distributes commissions to a referrer and their referrers
        @param referrer The referrer who will receive commission
        @param commissionToken The ERC20 token that the commission is paid in
        @param rawCommission The raw commission that will be distributed amongst referrers
        @param returnLeftovers If true, leftover commission is returned to the sender. If false, leftovers will be paid to MarketPeak.
     */
    function payCommission(
        address referrer,
        address commissionToken,
        uint256 rawCommission,
        bool returnLeftovers
    ) public regUser(referrer) onlySigner returns (uint256 leftoverAmount) {
        // transfer the raw commission from `msg.sender`
        IERC20 token = IERC20(commissionToken);
        token.safeTransferFrom(msg.sender, address(this), rawCommission);

        // payout commissions to referrers of different levels
        address ptr = referrer;
        uint256 commissionLeft = rawCommission;
        uint8 i = 0;
        while (ptr != address(0) && i < COMMISSION_LEVELS) {
            if (_peakStakeOf(ptr) >= commissionStakeRequirements[i]) {
                // referrer has enough stake, give commission
                uint256 com = rawCommission.mul(commissionPercentages[i]).div(
                    COMMISSION_RATE
                );
                if (com > commissionLeft) {
                    com = commissionLeft;
                }
                token.safeTransfer(ptr, com);
                commissionLeft = commissionLeft.sub(com);
                if (commissionToken == address(peakToken)) {
                    incrementCareerValueInPeak(ptr, com);
                } else if (commissionToken == stablecoin) {
                    incrementCareerValueInUsdc(ptr, com);
                }
                emit PayCommission(referrer, ptr, commissionToken, com, i);
            }

            ptr = referrerOf[ptr];
            i += 1;
        }

        // handle leftovers
        if (returnLeftovers) {
            // return leftovers to `msg.sender`
            token.safeTransfer(msg.sender, commissionLeft);
            return commissionLeft;
        } else {
            // give leftovers to MarketPeak wallet
            token.safeTransfer(marketPeakWallet, commissionLeft);
            return 0;
        }
    }

    /**
        @notice Increments a user's career value
        @param user The user
        @param incCV The CV increase amount, in Usdc
     */
    function incrementCareerValueInUsdc(address user, uint256 incCV)
        public
        regUser(user)
        onlySigner
    {
        careerValue[user] = careerValue[user].add(incCV);
        emit ChangedCareerValue(user, incCV, true);
    }

    /**
        @notice Increments a user's career value
        @param user The user
        @param incCVInPeak The CV increase amount, in PEAK tokens
     */
    function incrementCareerValueInPeak(address user, uint256 incCVInPeak)
        public
        regUser(user)
        onlySigner
    {
        uint256 peakPriceInUsdc = _getPeakPriceInUsdc();
        uint256 incCVInUsdc = incCVInPeak.mul(peakPriceInUsdc).div(
            PEAK_PRECISION
        );
        careerValue[user] = careerValue[user].add(incCVInUsdc);
        emit ChangedCareerValue(user, incCVInUsdc, true);
    }

    /**
        @notice Returns a user's rank in the PeakDeFi system based only on career value
        @param user The user whose rank will be queried
     */
    function cvRankOf(address user) public view returns (uint256) {
        uint256 cv = careerValue[user];
        if (cv < USDC_PRECISION.mul(100)) {
            return 0;
        } else if (cv < USDC_PRECISION.mul(250)) {
            return 1;
        } else if (cv < USDC_PRECISION.mul(750)) {
            return 2;
        } else if (cv < USDC_PRECISION.mul(1500)) {
            return 3;
        } else if (cv < USDC_PRECISION.mul(3000)) {
            return 4;
        } else if (cv < USDC_PRECISION.mul(10000)) {
            return 5;
        } else if (cv < USDC_PRECISION.mul(50000)) {
            return 6;
        } else if (cv < USDC_PRECISION.mul(150000)) {
            return 7;
        } else {
            return 8;
        }
    }

    function rankUp(address user) external {
        // verify rank up conditions
        uint256 currentRank = rankOf[user];
        uint256 cvRank = cvRankOf(user);
        require(cvRank > currentRank, "PeakReward: career value is not enough!");
        require(downlineRanks[user][currentRank] >= 2 || currentRank == 0, "PeakReward: downlines count and requirement not passed!");

        // Target rank always should be +1 rank from current rank
        uint256 targetRank = currentRank + 1;

        // increase user rank
        rankOf[user] = targetRank;
        emit RankChange(user, currentRank, targetRank);

        address referrer = referrerOf[user];
        if (referrer != address(0)) {
            downlineRanks[referrer][targetRank] = downlineRanks[referrer][targetRank]
                .add(1);
            downlineRanks[referrer][currentRank] = downlineRanks[referrer][currentRank]
                .sub(1);
        }

        // give user rank reward
        uint256 rewardInPeak = rankReward[currentRank][targetRank]
            .mul(PEAK_PRECISION)
            .div(_getPeakPriceInUsdc());
        if (mintedPeakTokens.add(rewardInPeak) <= PEAK_MINT_CAP) {
            // mint if under cap, do nothing if over cap
            mintedPeakTokens = mintedPeakTokens.add(rewardInPeak);
            peakToken.mint(user, rewardInPeak);
            emit ReceiveRankReward(user, rewardInPeak);
        }
    }

    function canRankUp(address user) external view returns (bool) {
        uint256 currentRank = rankOf[user];
        uint256 cvRank = cvRankOf(user);
        return
            (cvRank > currentRank) &&
            (downlineRanks[user][currentRank] >= 2 || currentRank == 0);
    }

    /**
        @notice Returns a user's current staked PEAK amount, scaled by `PEAK_PRECISION`.
        @param user The user whose stake will be queried
     */
    function _peakStakeOf(address user) internal view returns (uint256) {
        return peakStaking.userStakeAmount(user);
    }

    /**
        @notice Returns the price of PEAK token in Usdc, scaled by `USDC_PRECISION`.
     */
    function _getPeakPriceInUsdc() internal returns (uint256) {
        oracle.update();
        uint256 priceInUSDC = oracle.consult(address(peakToken), PEAK_PRECISION);
        if (priceInUSDC == 0) {
            return USDC_PRECISION.mul(3).div(10);
        }
        return priceInUSDC;
    }
}

pragma solidity ^0.5.0;

import "../../GSN/Context.sol";
import "../Roles.sol";

contract SignerRole is Context {
    using Roles for Roles.Role;

    event SignerAdded(address indexed account);
    event SignerRemoved(address indexed account);

    Roles.Role private _signers;

    constructor () internal {
        _addSigner(_msgSender());
    }

    modifier onlySigner() {
        require(isSigner(_msgSender()), "SignerRole: caller does not have the Signer role");
        _;
    }

    function isSigner(address account) public view returns (bool) {
        return _signers.has(account);
    }

    function addSigner(address account) public onlySigner {
        _addSigner(account);
    }

    function renounceSigner() public {
        _removeSigner(_msgSender());
    }

    function _addSigner(address account) internal {
        _signers.add(account);
        emit SignerAdded(account);
    }

    function _removeSigner(address account) internal {
        _signers.remove(account);
        emit SignerRemoved(account);
    }
}

pragma solidity 0.5.17;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../reward/PeakReward.sol";
import "../PeakToken.sol";

contract PeakStaking {
    using SafeMath for uint256;
    using SafeERC20 for PeakToken;

    event CreateStake(
        uint256 idx,
        address user,
        address referrer,
        uint256 stakeAmount,
        uint256 stakeTimeInDays,
        uint256 interestAmount
    );
    event ReceiveStakeReward(uint256 idx, address user, uint256 rewardAmount);
    event WithdrawReward(uint256 idx, address user, uint256 rewardAmount);
    event WithdrawStake(uint256 idx, address user);

    uint256 internal constant PRECISION = 10**18;
    uint256 internal constant PEAK_PRECISION = 10**8;
    uint256 internal constant INTEREST_SLOPE = 2 * (10**8); // Interest rate factor drops to 0 at 5B mintedPeakTokens
    uint256 internal constant BIGGER_BONUS_DIVISOR = 10**15; // biggerBonus = stakeAmount / (10 million peak)
    uint256 internal constant MAX_BIGGER_BONUS = 10**17; // biggerBonus <= 10%
    uint256 internal constant DAILY_BASE_REWARD = 15 * (10**14); // dailyBaseReward = 0.0015
    uint256 internal constant DAILY_GROWING_REWARD = 10**12; // dailyGrowingReward = 1e-6
    uint256 internal constant MAX_STAKE_PERIOD = 1000; // Max staking time is 1000 days
    uint256 internal constant MIN_STAKE_PERIOD = 10; // Min staking time is 10 days
    uint256 internal constant DAY_IN_SECONDS = 86400;
    uint256 internal constant COMMISSION_RATE = 20 * (10**16); // 20%
    uint256 internal constant REFERRAL_STAKER_BONUS = 3 * (10**16); // 3%
    uint256 internal constant YEAR_IN_DAYS = 365;
    uint256 public constant PEAK_MINT_CAP = 7 * 10**16; // 700 million PEAK

    struct Stake {
        address staker;
        uint256 stakeAmount;
        uint256 interestAmount;
        uint256 withdrawnInterestAmount;
        uint256 stakeTimestamp;
        uint256 stakeTimeInDays;
        bool active;
    }
    Stake[] public stakeList;
    mapping(address => uint256) public userStakeAmount;
    uint256 public mintedPeakTokens;
    bool public initialized;

    PeakToken public peakToken;
    PeakReward public peakReward;

    constructor(address _peakToken) public {
        peakToken = PeakToken(_peakToken);
    }

    function init(address _peakReward) public {
        require(!initialized, "PeakStaking: Already initialized");
        initialized = true;

        peakReward = PeakReward(_peakReward);
    }

    function stake(
        uint256 stakeAmount,
        uint256 stakeTimeInDays,
        address referrer
    ) public returns (uint256 stakeIdx) {
        require(
            stakeTimeInDays >= MIN_STAKE_PERIOD,
            "PeakStaking: stakeTimeInDays < MIN_STAKE_PERIOD"
        );
        require(
            stakeTimeInDays <= MAX_STAKE_PERIOD,
            "PeakStaking: stakeTimeInDays > MAX_STAKE_PERIOD"
        );

        // record stake
        uint256 interestAmount = getInterestAmount(
            stakeAmount,
            stakeTimeInDays
        );
        stakeIdx = stakeList.length;
        stakeList.push(
            Stake({
                staker: msg.sender,
                stakeAmount: stakeAmount,
                interestAmount: interestAmount,
                withdrawnInterestAmount: 0,
                stakeTimestamp: now,
                stakeTimeInDays: stakeTimeInDays,
                active: true
            })
        );
        mintedPeakTokens = mintedPeakTokens.add(interestAmount);
        userStakeAmount[msg.sender] = userStakeAmount[msg.sender].add(
            stakeAmount
        );

        // transfer PEAK from msg.sender
        peakToken.safeTransferFrom(msg.sender, address(this), stakeAmount);

        // mint PEAK interest
        peakToken.mint(address(this), interestAmount);

        // handle referral
        if (peakReward.canRefer(msg.sender, referrer)) {
            peakReward.refer(msg.sender, referrer);
        }
        address actualReferrer = peakReward.referrerOf(msg.sender);
        if (actualReferrer != address(0)) {
            // pay referral bonus to referrer
            uint256 rawCommission = interestAmount.mul(COMMISSION_RATE).div(
                PRECISION
            );
            peakToken.mint(address(this), rawCommission);
            peakToken.safeApprove(address(peakReward), rawCommission);
            uint256 leftoverAmount = peakReward.payCommission(
                actualReferrer,
                address(peakToken),
                rawCommission,
                true
            );
            peakToken.burn(leftoverAmount);

            // pay referral bonus to staker
            uint256 referralStakerBonus = interestAmount
                .mul(REFERRAL_STAKER_BONUS)
                .div(PRECISION);
            peakToken.mint(msg.sender, referralStakerBonus);

            mintedPeakTokens = mintedPeakTokens.add(
                rawCommission.sub(leftoverAmount).add(referralStakerBonus)
            );

            emit ReceiveStakeReward(stakeIdx, msg.sender, referralStakerBonus);
        }

        require(mintedPeakTokens <= PEAK_MINT_CAP, "PeakStaking: reached cap");

        emit CreateStake(
            stakeIdx,
            msg.sender,
            actualReferrer,
            stakeAmount,
            stakeTimeInDays,
            interestAmount
        );
    }

    function withdraw(uint256 stakeIdx) public {
        Stake storage stakeObj = stakeList[stakeIdx];
        require(
            stakeObj.staker == msg.sender,
            "PeakStaking: Sender not staker"
        );
        require(stakeObj.active, "PeakStaking: Not active");

        // calculate amount that can be withdrawn
        uint256 stakeTimeInSeconds = stakeObj.stakeTimeInDays.mul(
            DAY_IN_SECONDS
        );
        uint256 withdrawAmount;
        if (now >= stakeObj.stakeTimestamp.add(stakeTimeInSeconds)) {
            // matured, withdraw all
            withdrawAmount = stakeObj
                .stakeAmount
                .add(stakeObj.interestAmount)
                .sub(stakeObj.withdrawnInterestAmount);
            stakeObj.active = false;
            stakeObj.withdrawnInterestAmount = stakeObj.interestAmount;
            userStakeAmount[msg.sender] = userStakeAmount[msg.sender].sub(
                stakeObj.stakeAmount
            );

            emit WithdrawReward(
                stakeIdx,
                msg.sender,
                stakeObj.interestAmount.sub(stakeObj.withdrawnInterestAmount)
            );
            emit WithdrawStake(stakeIdx, msg.sender);
        } else {
            // not mature, partial withdraw
            withdrawAmount = stakeObj
                .interestAmount
                .mul(uint256(now).sub(stakeObj.stakeTimestamp))
                .div(stakeTimeInSeconds)
                .sub(stakeObj.withdrawnInterestAmount);

            // record withdrawal
            stakeObj.withdrawnInterestAmount = stakeObj
                .withdrawnInterestAmount
                .add(withdrawAmount);

            emit WithdrawReward(stakeIdx, msg.sender, withdrawAmount);
        }

        // withdraw interest to sender
        peakToken.safeTransfer(msg.sender, withdrawAmount);
    }

    function getInterestAmount(uint256 stakeAmount, uint256 stakeTimeInDays)
        public
        view
        returns (uint256)
    {
        uint256 earlyFactor = _earlyFactor(mintedPeakTokens);
        uint256 biggerBonus = stakeAmount.mul(PRECISION).div(
            BIGGER_BONUS_DIVISOR
        );
        if (biggerBonus > MAX_BIGGER_BONUS) {
            biggerBonus = MAX_BIGGER_BONUS;
        }

        // convert yearly bigger bonus to stake time
        biggerBonus = biggerBonus.mul(stakeTimeInDays).div(YEAR_IN_DAYS);

        uint256 longerBonus = _longerBonus(stakeTimeInDays);
        uint256 interestRate = biggerBonus.add(longerBonus).mul(earlyFactor).div(
            PRECISION
        );
        uint256 interestAmount = stakeAmount.mul(interestRate).div(PRECISION);
        return interestAmount;
    }

    function _longerBonus(uint256 stakeTimeInDays)
        internal
        pure
        returns (uint256)
    {
        return
            DAILY_BASE_REWARD.mul(stakeTimeInDays).add(
                DAILY_GROWING_REWARD
                    .mul(stakeTimeInDays)
                    .mul(stakeTimeInDays.add(1))
                    .div(2)
            );
    }

    function _earlyFactor(uint256 _mintedPeakTokens)
        internal
        pure
        returns (uint256)
    {
        uint256 tmp = INTEREST_SLOPE.mul(_mintedPeakTokens).div(PEAK_PRECISION);
        if (tmp > PRECISION) {
            return 0;
        }
        return PRECISION.sub(tmp);
    }
}

pragma solidity 0.5.17;

import "./lib/CloneFactory.sol";
import "./tokens/minime/MiniMeToken.sol";
import "./PeakDeFiFund.sol";
import "./PeakDeFiProxy.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract PeakDeFiFactory is CloneFactory {
    using Address for address;

    event CreateFund(address fund);
    event InitFund(address fund, address proxy);

    address public usdcAddr;
    address payable public kyberAddr;
    address payable public oneInchAddr;
    address payable public peakdefiFund;
    address public peakdefiLogic;
    address public peakdefiLogic2;
    address public peakdefiLogic3;
    address public peakRewardAddr;
    address public peakStakingAddr;
    MiniMeTokenFactory public minimeFactory;
    mapping(address => address) public fundCreator;

    constructor(
        address _usdcAddr,
        address payable _kyberAddr,
        address payable _oneInchAddr,
        address payable _peakdefiFund,
        address _peakdefiLogic,
        address _peakdefiLogic2,
        address _peakdefiLogic3,
        address _peakRewardAddr,
        address _peakStakingAddr,
        address _minimeFactoryAddr
    ) public {
        usdcAddr = _usdcAddr;
        kyberAddr = _kyberAddr;
        oneInchAddr = _oneInchAddr;
        peakdefiFund = _peakdefiFund;
        peakdefiLogic = _peakdefiLogic;
        peakdefiLogic2 = _peakdefiLogic2;
        peakdefiLogic3 = _peakdefiLogic3;
        peakRewardAddr = _peakRewardAddr;
        peakStakingAddr = _peakStakingAddr;
        minimeFactory = MiniMeTokenFactory(_minimeFactoryAddr);
    }

    function createFund() external returns (PeakDeFiFund) {
        // create fund
        PeakDeFiFund fund = PeakDeFiFund(createClone(peakdefiFund).toPayable());
        fund.initOwner();

        // give PeakReward signer rights to fund
        PeakReward peakReward = PeakReward(peakRewardAddr);
        peakReward.addSigner(address(fund));

        fundCreator[address(fund)] = msg.sender;

        emit CreateFund(address(fund));

        return fund;
    }

    function initFund1(
        PeakDeFiFund fund,
        string calldata reptokenName,
        string calldata reptokenSymbol,
        string calldata sharesName,
        string calldata sharesSymbol
    ) external {
        require(
            fundCreator[address(fund)] == msg.sender,
            "PeakDeFiFactory: not creator"
        );

        // create tokens
        MiniMeToken reptoken = minimeFactory.createCloneToken(
            address(0),
            0,
            reptokenName,
            18,
            reptokenSymbol,
            false
        );
        MiniMeToken shares = minimeFactory.createCloneToken(
            address(0),
            0,
            sharesName,
            18,
            sharesSymbol,
            true
        );
        MiniMeToken peakReferralToken = minimeFactory.createCloneToken(
            address(0),
            0,
            "Peak Referral Token",
            18,
            "PRT",
            false
        );

        // transfer token ownerships to fund
        reptoken.transferOwnership(address(fund));
        shares.transferOwnership(address(fund));
        peakReferralToken.transferOwnership(address(fund));

        fund.initInternalTokens(
            address(reptoken),
            address(shares),
            address(peakReferralToken)
        );
    }

    function initFund2(
        PeakDeFiFund fund,
        address payable _devFundingAccount,
        uint256 _devFundingRate,
        uint256[2] calldata _phaseLengths,
        address _compoundFactoryAddr
    ) external {
        require(
            fundCreator[address(fund)] == msg.sender,
            "PeakDeFiFactory: not creator"
        );
        fund.initParams(
            _devFundingAccount,
            _phaseLengths,
            _devFundingRate,
            address(0),
            usdcAddr,
            kyberAddr,
            _compoundFactoryAddr,
            peakdefiLogic,
            peakdefiLogic2,
            peakdefiLogic3,
            1,
            oneInchAddr,
            peakRewardAddr,
            peakStakingAddr
        );
    }

    function initFund3(
        PeakDeFiFund fund,
        uint256 _newManagerRepToken,
        uint256 _maxNewManagersPerCycle,
        uint256 _reptokenPrice,
        uint256 _peakManagerStakeRequired,
        bool _isPermissioned
    ) external {
        require(
            fundCreator[address(fund)] == msg.sender,
            "PeakDeFiFactory: not creator"
        );
        fund.initRegistration(
            _newManagerRepToken,
            _maxNewManagersPerCycle,
            _reptokenPrice,
            _peakManagerStakeRequired,
            _isPermissioned
        );
    }

    function initFund4(
        PeakDeFiFund fund,
        address[] calldata _kyberTokens,
        address[] calldata _compoundTokens
    ) external {
        require(
            fundCreator[address(fund)] == msg.sender,
            "PeakDeFiFactory: not creator"
        );
        fund.initTokenListings(_kyberTokens, _compoundTokens);

        // deploy and set PeakDeFiProxy
        PeakDeFiProxy proxy = new PeakDeFiProxy(address(fund));
        fund.setProxy(address(proxy).toPayable());

        // transfer fund ownership to msg.sender
        fund.transferOwnership(msg.sender);

        emit InitFund(address(fund), address(proxy));
    }
}

pragma solidity 0.5.17;

/*
    Copyright 2016, Jordi Baylina

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/// @title MiniMeToken Contract
/// @author Jordi Baylina
/// @dev This token contract's goal is to make it easy for anyone to clone this
///  token using the token distribution at a given block, this will allow DAO's
///  and DApps to upgrade their features in a decentralized manner without
///  affecting the original token
/// @dev It is ERC20 compliant, but still needs to under go further testing.

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./TokenController.sol";

contract ApproveAndCallFallBack {
  function receiveApproval(address from, uint256 _amount, address _token, bytes memory _data) public;
}

/// @dev The actual token contract, the default owner is the msg.sender
///  that deploys the contract, so usually this token will be deployed by a
///  token owner contract, which Giveth will call a "Campaign"
contract MiniMeToken is Ownable {

  string public name;                //The Token's name: e.g. DigixDAO Tokens
  uint8 public decimals;             //Number of decimals of the smallest unit
  string public symbol;              //An identifier: e.g. REP
  string public version = "MMT_0.2"; //An arbitrary versioning scheme


  /// @dev `Checkpoint` is the structure that attaches a block number to a
  ///  given value, the block number attached is the one that last changed the
  ///  value
  struct  Checkpoint {

    // `fromBlock` is the block number that the value was generated from
    uint128 fromBlock;

    // `value` is the amount of tokens at a specific block number
    uint128 value;
  }

  // `parentToken` is the Token address that was cloned to produce this token;
  //  it will be 0x0 for a token that was not cloned
  MiniMeToken public parentToken;

  // `parentSnapShotBlock` is the block number from the Parent Token that was
  //  used to determine the initial distribution of the Clone Token
  uint public parentSnapShotBlock;

  // `creationBlock` is the block number that the Clone Token was created
  uint public creationBlock;

  // `balances` is the map that tracks the balance of each address, in this
  //  contract when the balance changes the block number that the change
  //  occurred is also included in the map
  mapping (address => Checkpoint[]) balances;

  // `allowed` tracks any extra transfer rights as in all ERC20 tokens
  mapping (address => mapping (address => uint256)) allowed;

  // Tracks the history of the `totalSupply` of the token
  Checkpoint[] totalSupplyHistory;

  // Flag that determines if the token is transferable or not.
  bool public transfersEnabled;

  // The factory used to create new clone tokens
  MiniMeTokenFactory public tokenFactory;

////////////////
// Constructor
////////////////

  /// @notice Constructor to create a MiniMeToken
  /// @param _tokenFactory The address of the MiniMeTokenFactory contract that
  ///  will create the Clone token contracts, the token factory needs to be
  ///  deployed first
  /// @param _parentToken Address of the parent token, set to 0x0 if it is a
  ///  new token
  /// @param _parentSnapShotBlock Block of the parent token that will
  ///  determine the initial distribution of the clone token, set to 0 if it
  ///  is a new token
  /// @param _tokenName Name of the new token
  /// @param _decimalUnits Number of decimals of the new token
  /// @param _tokenSymbol Token Symbol for the new token
  /// @param _transfersEnabled If true, tokens will be able to be transferred
  constructor(
      address _tokenFactory,
      address payable _parentToken,
      uint _parentSnapShotBlock,
      string memory _tokenName,
      uint8 _decimalUnits,
      string memory _tokenSymbol,
      bool _transfersEnabled
  ) public {
    tokenFactory = MiniMeTokenFactory(_tokenFactory);
    name = _tokenName;                                 // Set the name
    decimals = _decimalUnits;                          // Set the decimals
    symbol = _tokenSymbol;                             // Set the symbol
    parentToken = MiniMeToken(_parentToken);
    parentSnapShotBlock = _parentSnapShotBlock;
    transfersEnabled = _transfersEnabled;
    creationBlock = block.number;
  }


///////////////////
// ERC20 Methods
///////////////////

  /// @notice Send `_amount` tokens to `_to` from `msg.sender`
  /// @param _to The address of the recipient
  /// @param _amount The amount of tokens to be transferred
  /// @return Whether the transfer was successful or not
  function transfer(address _to, uint256 _amount) public returns (bool success) {
    require(transfersEnabled);
    doTransfer(msg.sender, _to, _amount);
    return true;
  }

  /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it
  ///  is approved by `_from`
  /// @param _from The address holding the tokens being transferred
  /// @param _to The address of the recipient
  /// @param _amount The amount of tokens to be transferred
  /// @return True if the transfer was successful
  function transferFrom(address _from, address _to, uint256 _amount
  ) public returns (bool success) {

    // The owner of this contract can move tokens around at will,
    //  this is important to recognize! Confirm that you trust the
    //  owner of this contract, which in most situations should be
    //  another open source smart contract or 0x0
    if (msg.sender != owner()) {
      require(transfersEnabled);

      // The standard ERC 20 transferFrom functionality
      require(allowed[_from][msg.sender] >= _amount);
      allowed[_from][msg.sender] -= _amount;
    }
    doTransfer(_from, _to, _amount);
    return true;
  }

  /// @dev This is the actual transfer function in the token contract, it can
  ///  only be called by other functions in this contract.
  /// @param _from The address holding the tokens being transferred
  /// @param _to The address of the recipient
  /// @param _amount The amount of tokens to be transferred
  /// @return True if the transfer was successful
  function doTransfer(address _from, address _to, uint _amount
  ) internal {
    if (_amount == 0) {
      emit Transfer(_from, _to, _amount);    // Follow the spec to louch the event when transfer 0
      return;
    }

    require(parentSnapShotBlock < block.number);

    // Do not allow transfer to 0x0 or the token contract itself
    require((_to != address(0)) && (_to != address(this)));

    // If the amount being transfered is more than the balance of the
    //  account the transfer throws
    uint previousBalanceFrom = balanceOfAt(_from, block.number);

    require(previousBalanceFrom >= _amount);

    // Alerts the token owner of the transfer
    if (isContract(owner())) {
      require(TokenController(owner()).onTransfer(_from, _to, _amount));
    }

    // First update the balance array with the new value for the address
    //  sending the tokens
    updateValueAtNow(balances[_from], previousBalanceFrom - _amount);

    // Then update the balance array with the new value for the address
    //  receiving the tokens
    uint previousBalanceTo = balanceOfAt(_to, block.number);
    require(previousBalanceTo + _amount >= previousBalanceTo); // Check for overflow
    updateValueAtNow(balances[_to], previousBalanceTo + _amount);

    // An event to make the transfer easy to find on the blockchain
    emit Transfer(_from, _to, _amount);
  }

  /// @param _owner The address that's balance is being requested
  /// @return The balance of `_owner` at the current block
  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balanceOfAt(_owner, block.number);
  }

  /// @notice `msg.sender` approves `_spender` to spend `_amount` tokens on
  ///  its behalf. This is a modified version of the ERC20 approve function
  ///  to be a little bit safer
  /// @param _spender The address of the account able to transfer the tokens
  /// @param _amount The amount of tokens to be approved for transfer
  /// @return True if the approval was successful
  function approve(address _spender, uint256 _amount) public returns (bool success) {
    require(transfersEnabled);

    // To change the approve amount you first have to reduce the addresses`
    //  allowance to zero by calling `approve(_spender,0)` if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    require((_amount == 0) || (allowed[msg.sender][_spender] == 0));

    // Alerts the token owner of the approve function call
    if (isContract(owner())) {
      require(TokenController(owner()).onApprove(msg.sender, _spender, _amount));
    }

    allowed[msg.sender][_spender] = _amount;
    emit Approval(msg.sender, _spender, _amount);
    return true;
  }

  /// @dev This function makes it easy to read the `allowed[]` map
  /// @param _owner The address of the account that owns the token
  /// @param _spender The address of the account able to transfer the tokens
  /// @return Amount of remaining tokens of _owner that _spender is allowed
  ///  to spend
  function allowance(address _owner, address _spender
  ) public view returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

  /// @notice `msg.sender` approves `_spender` to send `_amount` tokens on
  ///  its behalf, and then a function is triggered in the contract that is
  ///  being approved, `_spender`. This allows users to use their tokens to
  ///  interact with contracts in one function call instead of two
  /// @param _spender The address of the contract able to transfer the tokens
  /// @param _amount The amount of tokens to be approved for transfer
  /// @return True if the function call was successful
  function approveAndCall(address _spender, uint256 _amount, bytes memory _extraData
  ) public returns (bool success) {
    require(approve(_spender, _amount));

    ApproveAndCallFallBack(_spender).receiveApproval(
      msg.sender,
      _amount,
      address(this),
      _extraData
    );

    return true;
  }

  /// @dev This function makes it easy to get the total number of tokens
  /// @return The total number of tokens
  function totalSupply() public view returns (uint) {
    return totalSupplyAt(block.number);
  }


////////////////
// Query balance and totalSupply in History
////////////////

  /// @dev Queries the balance of `_owner` at a specific `_blockNumber`
  /// @param _owner The address from which the balance will be retrieved
  /// @param _blockNumber The block number when the balance is queried
  /// @return The balance at `_blockNumber`
  function balanceOfAt(address _owner, uint _blockNumber) public view
    returns (uint) {

    // These next few lines are used when the balance of the token is
    //  requested before a check point was ever created for this token, it
    //  requires that the `parentToken.balanceOfAt` be queried at the
    //  genesis block for that token as this contains initial balance of
    //  this token
    if ((balances[_owner].length == 0)
        || (balances[_owner][0].fromBlock > _blockNumber)) {
      if (address(parentToken) != address(0)) {
        return parentToken.balanceOfAt(_owner, min(_blockNumber, parentSnapShotBlock));
      } else {
          // Has no parent
        return 0;
      }

    // This will return the expected balance during normal situations
    } else {
      return getValueAt(balances[_owner], _blockNumber);
    }
  }

  /// @notice Total amount of tokens at a specific `_blockNumber`.
  /// @param _blockNumber The block number when the totalSupply is queried
  /// @return The total amount of tokens at `_blockNumber`
  function totalSupplyAt(uint _blockNumber) public view returns(uint) {

    // These next few lines are used when the totalSupply of the token is
    //  requested before a check point was ever created for this token, it
    //  requires that the `parentToken.totalSupplyAt` be queried at the
    //  genesis block for this token as that contains totalSupply of this
    //  token at this block number.
    if ((totalSupplyHistory.length == 0)
      || (totalSupplyHistory[0].fromBlock > _blockNumber)) {
      if (address(parentToken) != address(0)) {
        return parentToken.totalSupplyAt(min(_blockNumber, parentSnapShotBlock));
      } else {
        return 0;
      }

    // This will return the expected totalSupply during normal situations
    } else {
      return getValueAt(totalSupplyHistory, _blockNumber);
    }
  }

////////////////
// Clone Token Method
////////////////

  /// @notice Creates a new clone token with the initial distribution being
  ///  this token at `_snapshotBlock`
  /// @param _cloneTokenName Name of the clone token
  /// @param _cloneDecimalUnits Number of decimals of the smallest unit
  /// @param _cloneTokenSymbol Symbol of the clone token
  /// @param _snapshotBlock Block when the distribution of the parent token is
  ///  copied to set the initial distribution of the new clone token;
  ///  if the block is zero than the actual block, the current block is used
  /// @param _transfersEnabled True if transfers are allowed in the clone
  /// @return The address of the new MiniMeToken Contract
  function createCloneToken(
    string memory _cloneTokenName,
    uint8 _cloneDecimalUnits,
    string memory _cloneTokenSymbol,
    uint _snapshotBlock,
    bool _transfersEnabled
  ) public returns(address) {
    uint snapshotBlock = _snapshotBlock;
    if (snapshotBlock == 0) snapshotBlock = block.number;
    MiniMeToken cloneToken = tokenFactory.createCloneToken(
      address(this),
      snapshotBlock,
      _cloneTokenName,
      _cloneDecimalUnits,
      _cloneTokenSymbol,
      _transfersEnabled
    );

    cloneToken.transferOwnership(msg.sender);

    // An event to make the token easy to find on the blockchain
    emit NewCloneToken(address(cloneToken), snapshotBlock);
    return address(cloneToken);
  }

////////////////
// Generate and destroy tokens
////////////////

  /// @notice Generates `_amount` tokens that are assigned to `_owner`
  /// @param _owner The address that will be assigned the new tokens
  /// @param _amount The quantity of tokens generated
  /// @return True if the tokens are generated correctly
  function generateTokens(address _owner, uint _amount
  ) public onlyOwner returns (bool) {
    uint curTotalSupply = totalSupply();
    require(curTotalSupply + _amount >= curTotalSupply); // Check for overflow
    uint previousBalanceTo = balanceOf(_owner);
    require(previousBalanceTo + _amount >= previousBalanceTo); // Check for overflow
    updateValueAtNow(totalSupplyHistory, curTotalSupply + _amount);
    updateValueAtNow(balances[_owner], previousBalanceTo + _amount);
    emit Transfer(address(0), _owner, _amount);
    return true;
  }


  /// @notice Burns `_amount` tokens from `_owner`
  /// @param _owner The address that will lose the tokens
  /// @param _amount The quantity of tokens to burn
  /// @return True if the tokens are burned correctly
  function destroyTokens(address _owner, uint _amount
  ) onlyOwner public returns (bool) {
    uint curTotalSupply = totalSupply();
    require(curTotalSupply >= _amount);
    uint previousBalanceFrom = balanceOf(_owner);
    require(previousBalanceFrom >= _amount);
    updateValueAtNow(totalSupplyHistory, curTotalSupply - _amount);
    updateValueAtNow(balances[_owner], previousBalanceFrom - _amount);
    emit Transfer(_owner, address(0), _amount);
    return true;
  }

////////////////
// Enable tokens transfers
////////////////


  /// @notice Enables token holders to transfer their tokens freely if true
  /// @param _transfersEnabled True if transfers are allowed in the clone
  function enableTransfers(bool _transfersEnabled) public onlyOwner {
    transfersEnabled = _transfersEnabled;
  }

////////////////
// Internal helper functions to query and set a value in a snapshot array
////////////////

  /// @dev `getValueAt` retrieves the number of tokens at a given block number
  /// @param checkpoints The history of values being queried
  /// @param _block The block number to retrieve the value at
  /// @return The number of tokens being queried
  function getValueAt(Checkpoint[] storage checkpoints, uint _block
  ) view internal returns (uint) {
    if (checkpoints.length == 0) return 0;

    // Shortcut for the actual value
    if (_block >= checkpoints[checkpoints.length-1].fromBlock)
        return checkpoints[checkpoints.length-1].value;
    if (_block < checkpoints[0].fromBlock) return 0;

    // Binary search of the value in the array
    uint min = 0;
    uint max = checkpoints.length-1;
    while (max > min) {
      uint mid = (max + min + 1)/ 2;
      if (checkpoints[mid].fromBlock<=_block) {
        min = mid;
      } else {
        max = mid-1;
      }
    }
    return checkpoints[min].value;
  }

  /// @dev `updateValueAtNow` used to update the `balances` map and the
  ///  `totalSupplyHistory`
  /// @param checkpoints The history of data being updated
  /// @param _value The new number of tokens
  function updateValueAtNow(Checkpoint[] storage checkpoints, uint _value
  ) internal  {
    if ((checkpoints.length == 0)
    || (checkpoints[checkpoints.length -1].fromBlock < block.number)) {
      Checkpoint storage newCheckPoint = checkpoints[ checkpoints.length++ ];
      newCheckPoint.fromBlock =  uint128(block.number);
      newCheckPoint.value = uint128(_value);
    } else {
      Checkpoint storage oldCheckPoint = checkpoints[checkpoints.length-1];
      oldCheckPoint.value = uint128(_value);
    }
  }

  /// @dev Internal function to determine if an address is a contract
  /// @param _addr The address being queried
  /// @return True if `_addr` is a contract
  function isContract(address _addr) view internal returns(bool) {
    uint size;
    if (_addr == address(0)) return false;
    assembly {
        size := extcodesize(_addr)
    }
    return size>0;
  }

  /// @dev Helper function to return a min betwen the two uints
  function min(uint a, uint b) pure internal returns (uint) {
    return a < b ? a : b;
  }

  /// @notice The fallback function: If the contract's owner has not been
  ///  set to 0, then the `proxyPayment` method is called which relays the
  ///  ether and creates tokens as described in the token owner contract
  function () external payable {
    require(isContract(owner()));
    require(TokenController(owner()).proxyPayment.value(msg.value)(msg.sender));
  }

//////////
// Safety Methods
//////////

  /// @notice This method can be used by the owner to extract mistakenly
  ///  sent tokens to this contract.
  /// @param _token The address of the token contract that you want to recover
  ///  set to 0 in case you want to extract ether.
  function claimTokens(address payable _token) public onlyOwner {
    if (_token == address(0)) {
      address(uint160(owner())).transfer(address(this).balance);
      return;
    }

    MiniMeToken token = MiniMeToken(_token);
    uint balance = token.balanceOf(address(this));
    require(token.transfer(owner(), balance));
    emit ClaimedTokens(_token, owner(), balance);
  }

////////////////
// Events
////////////////
  event ClaimedTokens(address indexed _token, address indexed _owner, uint _amount);
  event Transfer(address indexed _from, address indexed _to, uint256 _amount);
  event NewCloneToken(address indexed _cloneToken, uint _snapshotBlock);
  event Approval(
      address indexed _owner,
      address indexed _spender,
      uint256 _amount
  );

}


////////////////
// MiniMeTokenFactory
////////////////

/// @dev This contract is used to generate clone contracts from a contract.
///  In solidity this is the way to create a contract from a contract of the
///  same class
contract MiniMeTokenFactory {
  event CreatedToken(string symbol, address addr);

  /// @notice Update the DApp by creating a new token with new functionalities
  ///  the msg.sender becomes the owner of this clone token
  /// @param _parentToken Address of the token being cloned
  /// @param _snapshotBlock Block of the parent token that will
  ///  determine the initial distribution of the clone token
  /// @param _tokenName Name of the new token
  /// @param _decimalUnits Number of decimals of the new token
  /// @param _tokenSymbol Token Symbol for the new token
  /// @param _transfersEnabled If true, tokens will be able to be transferred
  /// @return The address of the new token contract
  function createCloneToken(
    address payable _parentToken,
    uint _snapshotBlock,
    string memory _tokenName,
    uint8 _decimalUnits,
    string memory _tokenSymbol,
    bool _transfersEnabled
  ) public returns (MiniMeToken) {
    MiniMeToken newToken = new MiniMeToken(
      address(this),
      _parentToken,
      _snapshotBlock,
      _tokenName,
      _decimalUnits,
      _tokenSymbol,
      _transfersEnabled
    );

    newToken.transferOwnership(msg.sender);
    emit CreatedToken(_tokenSymbol, address(newToken));
    return newToken;
  }
}

pragma solidity 0.5.17;

/// @dev The token controller contract must implement these functions
contract TokenController {
  /// @notice Called when `_owner` sends ether to the MiniMe Token contract
  /// @param _owner The address that sent the ether to create tokens
  /// @return True if the ether is accepted, false if it throws
  function proxyPayment(address _owner) public payable returns(bool);

  /// @notice Notifies the controller about a token transfer allowing the
  ///  controller to react if desired
  /// @param _from The origin of the transfer
  /// @param _to The destination of the transfer
  /// @param _amount The amount of the transfer
  /// @return False if the controller does not authorize the transfer
  function onTransfer(address _from, address _to, uint _amount) public returns(bool);

  /// @notice Notifies the controller about an approval allowing the
  ///  controller to react if desired
  /// @param _owner The address that calls `approve()`
  /// @param _spender The spender in the `approve()` call
  /// @param _amount The amount in the `approve()` call
  /// @return False if the controller does not authorize the approval
  function onApprove(address _owner, address _spender, uint _amount) public
    returns(bool);
}

pragma solidity 0.5.17;

import "./PeakDeFiStorage.sol";
import "./derivatives/CompoundOrderFactory.sol";

/**
 * @title The main smart contract of the PeakDeFi hedge fund.
 * @author Zefram Lou (Zebang Liu)
 */
contract PeakDeFiFund is
    PeakDeFiStorage,
    Utils(address(0), address(0), address(0)),
    TokenController
{
    /**
     * @notice Passes if the fund is ready for migrating to the next version
     */
    modifier readyForUpgradeMigration {
        require(hasFinalizedNextVersion == true);
        require(
            now >
                startTimeOfCyclePhase.add(
                    phaseLengths[uint256(CyclePhase.Intermission)]
                )
        );
        _;
    }

    /**
     * Meta functions
     */

    function initParams(
        address payable _devFundingAccount,
        uint256[2] calldata _phaseLengths,
        uint256 _devFundingRate,
        address payable _previousVersion,
        address _usdcAddr,
        address payable _kyberAddr,
        address _compoundFactoryAddr,
        address _peakdefiLogic,
        address _peakdefiLogic2,
        address _peakdefiLogic3,
        uint256 _startCycleNumber,
        address payable _oneInchAddr,
        address _peakRewardAddr,
        address _peakStakingAddr
    ) external {
        require(proxyAddr == address(0));
        devFundingAccount = _devFundingAccount;
        phaseLengths = _phaseLengths;
        devFundingRate = _devFundingRate;
        cyclePhase = CyclePhase.Intermission;
        compoundFactoryAddr = _compoundFactoryAddr;
        peakdefiLogic = _peakdefiLogic;
        peakdefiLogic2 = _peakdefiLogic2;
        peakdefiLogic3 = _peakdefiLogic3;
        previousVersion = _previousVersion;
        cycleNumber = _startCycleNumber;

        peakReward = PeakReward(_peakRewardAddr);
        peakStaking = PeakStaking(_peakStakingAddr);

        USDC_ADDR = _usdcAddr;
        KYBER_ADDR = _kyberAddr;
        ONEINCH_ADDR = _oneInchAddr;

        usdc = ERC20Detailed(_usdcAddr);
        kyber = KyberNetwork(_kyberAddr);

        __initReentrancyGuard();
    }

    function initOwner() external {
        require(proxyAddr == address(0));
        _transferOwnership(msg.sender);
    }

    function initInternalTokens(
        address payable _repAddr,
        address payable _sTokenAddr,
        address payable _peakReferralTokenAddr
    ) external onlyOwner {
        require(controlTokenAddr == address(0));
        require(_repAddr != address(0));
        controlTokenAddr = _repAddr;
        shareTokenAddr = _sTokenAddr;
        cToken = IMiniMeToken(_repAddr);
        sToken = IMiniMeToken(_sTokenAddr);
        peakReferralToken = IMiniMeToken(_peakReferralTokenAddr);
    }

    function initRegistration(
        uint256 _newManagerRepToken,
        uint256 _maxNewManagersPerCycle,
        uint256 _reptokenPrice,
        uint256 _peakManagerStakeRequired,
        bool _isPermissioned
    ) external onlyOwner {
        require(_newManagerRepToken > 0 && newManagerRepToken == 0);
        newManagerRepToken = _newManagerRepToken;
        maxNewManagersPerCycle = _maxNewManagersPerCycle;
        reptokenPrice = _reptokenPrice;
        peakManagerStakeRequired = _peakManagerStakeRequired;
        isPermissioned = _isPermissioned;
    }

    function initTokenListings(
        address[] calldata _kyberTokens,
        address[] calldata _compoundTokens
    ) external onlyOwner {
        // May only initialize once
        require(!hasInitializedTokenListings);
        hasInitializedTokenListings = true;

        uint256 i;
        for (i = 0; i < _kyberTokens.length; i++) {
            isKyberToken[_kyberTokens[i]] = true;
        }
        CompoundOrderFactory factory = CompoundOrderFactory(compoundFactoryAddr);
        for (i = 0; i < _compoundTokens.length; i++) {
            require(factory.tokenIsListed(_compoundTokens[i]));
            isCompoundToken[_compoundTokens[i]] = true;
        }
    }

    /**
     * @notice Used during deployment to set the PeakDeFiProxy contract address.
     * @param _proxyAddr the proxy's address
     */
    function setProxy(address payable _proxyAddr) external onlyOwner {
        require(_proxyAddr != address(0));
        require(proxyAddr == address(0));
        proxyAddr = _proxyAddr;
        proxy = PeakDeFiProxyInterface(_proxyAddr);
    }

    /**
     * Upgrading functions
     */

    /**
     * @notice Allows the developer to propose a candidate smart contract for the fund to upgrade to.
     *          The developer may change the candidate during the Intermission phase.
     * @param _candidate the address of the candidate smart contract
     * @return True if successfully changed candidate, false otherwise.
     */
    function developerInitiateUpgrade(address payable _candidate)
        public
        returns (bool _success)
    {
        (bool success, bytes memory result) = peakdefiLogic3.delegatecall(
            abi.encodeWithSelector(
                this.developerInitiateUpgrade.selector,
                _candidate
            )
        );
        if (!success) {
            return false;
        }
        return abi.decode(result, (bool));
    }

    /**
     * @notice Transfers ownership of RepToken & Share token contracts to the next version. Also updates PeakDeFiFund's
     *         address in PeakDeFiProxy.
     */
    function migrateOwnedContractsToNextVersion()
        public
        nonReentrant
        readyForUpgradeMigration
    {
        cToken.transferOwnership(nextVersion);
        sToken.transferOwnership(nextVersion);
        peakReferralToken.transferOwnership(nextVersion);
        proxy.updatePeakDeFiFundAddress();
    }

    /**
     * @notice Transfers assets to the next version.
     * @param _assetAddress the address of the asset to be transferred. Use ETH_TOKEN_ADDRESS to transfer Ether.
     */
    function transferAssetToNextVersion(address _assetAddress)
        public
        nonReentrant
        readyForUpgradeMigration
        isValidToken(_assetAddress)
    {
        if (_assetAddress == address(ETH_TOKEN_ADDRESS)) {
            nextVersion.transfer(address(this).balance);
        } else {
            ERC20Detailed token = ERC20Detailed(_assetAddress);
            token.safeTransfer(nextVersion, token.balanceOf(address(this)));
        }
    }

    /**
     * Getters
     */

    /**
     * @notice Returns the length of the user's investments array.
     * @return length of the user's investments array
     */
    function investmentsCount(address _userAddr)
        public
        view
        returns (uint256 _count)
    {
        return userInvestments[_userAddr].length;
    }

    /**
     * @notice Returns the length of the user's compound orders array.
     * @return length of the user's compound orders array
     */
    function compoundOrdersCount(address _userAddr)
        public
        view
        returns (uint256 _count)
    {
        return userCompoundOrders[_userAddr].length;
    }

    /**
     * @notice Returns the phaseLengths array.
     * @return the phaseLengths array
     */
    function getPhaseLengths()
        public
        view
        returns (uint256[2] memory _phaseLengths)
    {
        return phaseLengths;
    }

    /**
     * @notice Returns the commission balance of `_manager`
     * @return the commission balance and the received penalty, denoted in USDC
     */
    function commissionBalanceOf(address _manager)
        public
        returns (uint256 _commission, uint256 _penalty)
    {
        (bool success, bytes memory result) = peakdefiLogic3.delegatecall(
            abi.encodeWithSelector(this.commissionBalanceOf.selector, _manager)
        );
        if (!success) {
            return (0, 0);
        }
        return abi.decode(result, (uint256, uint256));
    }

    /**
     * @notice Returns the commission amount received by `_manager` in the `_cycle`th cycle
     * @return the commission amount and the received penalty, denoted in USDC
     */
    function commissionOfAt(address _manager, uint256 _cycle)
        public
        returns (uint256 _commission, uint256 _penalty)
    {
        (bool success, bytes memory result) = peakdefiLogic3.delegatecall(
            abi.encodeWithSelector(
                this.commissionOfAt.selector,
                _manager,
                _cycle
            )
        );
        if (!success) {
            return (0, 0);
        }
        return abi.decode(result, (uint256, uint256));
    }

    /**
     * Parameter setters
     */

    /**
     * @notice Changes the address to which the developer fees will be sent. Only callable by owner.
     * @param _newAddr the new developer fee address
     */
    function changeDeveloperFeeAccount(address payable _newAddr)
        public
        onlyOwner
    {
        require(_newAddr != address(0) && _newAddr != address(this));
        devFundingAccount = _newAddr;
    }

    /**
     * @notice Changes the proportion of fund balance sent to the developers each cycle. May only decrease. Only callable by owner.
     * @param _newProp the new proportion, fixed point decimal
     */
    function changeDeveloperFeeRate(uint256 _newProp) public onlyOwner {
        require(_newProp < PRECISION);
        require(_newProp < devFundingRate);
        devFundingRate = _newProp;
    }

    /**
     * @notice Allows managers to invest in a token. Only callable by owner.
     * @param _token address of the token to be listed
     */
    function listKyberToken(address _token) public onlyOwner {
        isKyberToken[_token] = true;
    }

    /**
     * @notice Allows managers to invest in a Compound token. Only callable by owner.
     * @param _token address of the Compound token to be listed
     */
    function listCompoundToken(address _token) public onlyOwner {
        CompoundOrderFactory factory = CompoundOrderFactory(
            compoundFactoryAddr
        );
        require(factory.tokenIsListed(_token));
        isCompoundToken[_token] = true;
    }

    /**
     * @notice Moves the fund to the next phase in the investment cycle.
     */
    function nextPhase() public {
        (bool success, ) = peakdefiLogic3.delegatecall(
            abi.encodeWithSelector(this.nextPhase.selector)
        );
        if (!success) {
            revert();
        }
    }

    /**
     * Manager registration
     */

    /**
     * @notice Registers `msg.sender` as a manager, using USDC as payment. The more one pays, the more RepToken one gets.
     *         There's a max RepToken amount that can be bought, and excess payment will be sent back to sender.
     */
    function registerWithUSDC() public {
        (bool success, ) = peakdefiLogic2.delegatecall(
            abi.encodeWithSelector(this.registerWithUSDC.selector)
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Registers `msg.sender` as a manager, using ETH as payment. The more one pays, the more RepToken one gets.
     *         There's a max RepToken amount that can be bought, and excess payment will be sent back to sender.
     */
    function registerWithETH() public payable {
        (bool success, ) = peakdefiLogic2.delegatecall(
            abi.encodeWithSelector(this.registerWithETH.selector)
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Registers `msg.sender` as a manager, using tokens as payment. The more one pays, the more RepToken one gets.
     *         There's a max RepToken amount that can be bought, and excess payment will be sent back to sender.
     * @param _token the token to be used for payment
     * @param _donationInTokens the amount of tokens to be used for registration, should use the token's native decimals
     */
    function registerWithToken(address _token, uint256 _donationInTokens)
        public
    {
        (bool success, ) = peakdefiLogic2.delegatecall(
            abi.encodeWithSelector(
                this.registerWithToken.selector,
                _token,
                _donationInTokens
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * Intermission phase functions
     */

    /**
     * @notice Deposit Ether into the fund. Ether will be converted into USDC.
     */
    function depositEther(address _referrer) public payable {
        (bool success, ) = peakdefiLogic2.delegatecall(
            abi.encodeWithSelector(this.depositEther.selector, _referrer)
        );
        if (!success) {
            revert();
        }
    }

    function depositEtherAdvanced(
        bool _useKyber,
        bytes calldata _calldata,
        address _referrer
    ) external payable {
        (bool success, ) = peakdefiLogic2.delegatecall(
            abi.encodeWithSelector(
                this.depositEtherAdvanced.selector,
                _useKyber,
                _calldata,
                _referrer
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Deposit USDC Stablecoin into the fund.
     * @param _usdcAmount The amount of USDC to be deposited. May be different from actual deposited amount.
     */
    function depositUSDC(uint256 _usdcAmount, address _referrer) public {
        (bool success, ) = peakdefiLogic2.delegatecall(
            abi.encodeWithSelector(
                this.depositUSDC.selector,
                _usdcAmount,
                _referrer
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Deposit ERC20 tokens into the fund. Tokens will be converted into USDC.
     * @param _tokenAddr the address of the token to be deposited
     * @param _tokenAmount The amount of tokens to be deposited. May be different from actual deposited amount.
     */
    function depositToken(
        address _tokenAddr,
        uint256 _tokenAmount,
        address _referrer
    ) public {
        (bool success, ) = peakdefiLogic2.delegatecall(
            abi.encodeWithSelector(
                this.depositToken.selector,
                _tokenAddr,
                _tokenAmount,
                _referrer
            )
        );
        if (!success) {
            revert();
        }
    }

    function depositTokenAdvanced(
        address _tokenAddr,
        uint256 _tokenAmount,
        bool _useKyber,
        bytes calldata _calldata,
        address _referrer
    ) external {
        (bool success, ) = peakdefiLogic2.delegatecall(
            abi.encodeWithSelector(
                this.depositTokenAdvanced.selector,
                _tokenAddr,
                _tokenAmount,
                _useKyber,
                _calldata,
                _referrer
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Withdraws Ether by burning Shares.
     * @param _amountInUSDC Amount of funds to be withdrawn expressed in USDC. Fixed-point decimal. May be different from actual amount.
     */
    function withdrawEther(uint256 _amountInUSDC) external {
        (bool success, ) = peakdefiLogic2.delegatecall(
            abi.encodeWithSelector(this.withdrawEther.selector, _amountInUSDC)
        );
        if (!success) {
            revert();
        }
    }

    function withdrawEtherAdvanced(
        uint256 _amountInUSDC,
        bool _useKyber,
        bytes calldata _calldata
    ) external {
        (bool success, ) = peakdefiLogic2.delegatecall(
            abi.encodeWithSelector(
                this.withdrawEtherAdvanced.selector,
                _amountInUSDC,
                _useKyber,
                _calldata
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Withdraws Ether by burning Shares.
     * @param _amountInUSDC Amount of funds to be withdrawn expressed in USDC. Fixed-point decimal. May be different from actual amount.
     */
    function withdrawUSDC(uint256 _amountInUSDC) public {
        (bool success, ) = peakdefiLogic2.delegatecall(
            abi.encodeWithSelector(this.withdrawUSDC.selector, _amountInUSDC)
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Withdraws funds by burning Shares, and converts the funds into the specified token using Kyber Network.
     * @param _tokenAddr the address of the token to be withdrawn into the caller's account
     * @param _amountInUSDC The amount of funds to be withdrawn expressed in USDC. Fixed-point decimal. May be different from actual amount.
     */
    function withdrawToken(address _tokenAddr, uint256 _amountInUSDC) external {
        (bool success, ) = peakdefiLogic2.delegatecall(
            abi.encodeWithSelector(
                this.withdrawToken.selector,
                _tokenAddr,
                _amountInUSDC
            )
        );
        if (!success) {
            revert();
        }
    }

    function withdrawTokenAdvanced(
        address _tokenAddr,
        uint256 _amountInUSDC,
        bool _useKyber,
        bytes calldata _calldata
    ) external {
        (bool success, ) = peakdefiLogic2.delegatecall(
            abi.encodeWithSelector(
                this.withdrawTokenAdvanced.selector,
                _tokenAddr,
                _amountInUSDC,
                _useKyber,
                _calldata
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Redeems commission.
     */
    function redeemCommission(bool _inShares) public {
        (bool success, ) = peakdefiLogic3.delegatecall(
            abi.encodeWithSelector(this.redeemCommission.selector, _inShares)
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Redeems commission for a particular cycle.
     * @param _inShares true to redeem in PeakDeFi Shares, false to redeem in USDC
     * @param _cycle the cycle for which the commission will be redeemed.
     *        Commissions for a cycle will be redeemed during the Intermission phase of the next cycle, so _cycle must < cycleNumber.
     */
    function redeemCommissionForCycle(bool _inShares, uint256 _cycle) public {
        (bool success, ) = peakdefiLogic3.delegatecall(
            abi.encodeWithSelector(
                this.redeemCommissionForCycle.selector,
                _inShares,
                _cycle
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Sells tokens left over due to manager not selling or KyberNetwork not having enough volume. Callable by anyone. Money goes to developer.
     * @param _tokenAddr address of the token to be sold
     * @param _calldata the 1inch trade call data
     */
    function sellLeftoverToken(address _tokenAddr, bytes calldata _calldata)
        external
    {
        (bool success, ) = peakdefiLogic2.delegatecall(
            abi.encodeWithSelector(
                this.sellLeftoverToken.selector,
                _tokenAddr,
                _calldata
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Sells CompoundOrder left over due to manager not selling or KyberNetwork not having enough volume. Callable by anyone. Money goes to developer.
     * @param _orderAddress address of the CompoundOrder to be sold
     */
    function sellLeftoverCompoundOrder(address payable _orderAddress) public {
        (bool success, ) = peakdefiLogic2.delegatecall(
            abi.encodeWithSelector(
                this.sellLeftoverCompoundOrder.selector,
                _orderAddress
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Burns the RepToken balance of a manager who has been inactive for a certain number of cycles
     * @param _deadman the manager whose RepToken balance will be burned
     */
    function burnDeadman(address _deadman) public {
        (bool success, ) = peakdefiLogic.delegatecall(
            abi.encodeWithSelector(this.burnDeadman.selector, _deadman)
        );
        if (!success) {
            revert();
        }
    }

    /**
     * Manage phase functions
     */

    function createInvestmentWithSignature(
        address _tokenAddress,
        uint256 _stake,
        uint256 _maxPrice,
        bytes calldata _calldata,
        bool _useKyber,
        address _manager,
        uint256 _salt,
        bytes calldata _signature
    ) external {
        (bool success, ) = peakdefiLogic.delegatecall(
            abi.encodeWithSelector(
                this.createInvestmentWithSignature.selector,
                _tokenAddress,
                _stake,
                _maxPrice,
                _calldata,
                _useKyber,
                _manager,
                _salt,
                _signature
            )
        );
        if (!success) {
            revert();
        }
    }

    function sellInvestmentWithSignature(
        uint256 _investmentId,
        uint256 _tokenAmount,
        uint256 _minPrice,
        uint256 _maxPrice,
        bytes calldata _calldata,
        bool _useKyber,
        address _manager,
        uint256 _salt,
        bytes calldata _signature
    ) external {
        (bool success, ) = peakdefiLogic.delegatecall(
            abi.encodeWithSelector(
                this.sellInvestmentWithSignature.selector,
                _investmentId,
                _tokenAmount,
                _minPrice,
                _maxPrice,
                _calldata,
                _useKyber,
                _manager,
                _salt,
                _signature
            )
        );
        if (!success) {
            revert();
        }
    }

    function createCompoundOrderWithSignature(
        bool _orderType,
        address _tokenAddress,
        uint256 _stake,
        uint256 _minPrice,
        uint256 _maxPrice,
        address _manager,
        uint256 _salt,
        bytes calldata _signature
    ) external {
        (bool success, ) = peakdefiLogic.delegatecall(
            abi.encodeWithSelector(
                this.createCompoundOrderWithSignature.selector,
                _orderType,
                _tokenAddress,
                _stake,
                _minPrice,
                _maxPrice,
                _manager,
                _salt,
                _signature
            )
        );
        if (!success) {
            revert();
        }
    }

    function sellCompoundOrderWithSignature(
        uint256 _orderId,
        uint256 _minPrice,
        uint256 _maxPrice,
        address _manager,
        uint256 _salt,
        bytes calldata _signature
    ) external {
        (bool success, ) = peakdefiLogic.delegatecall(
            abi.encodeWithSelector(
                this.sellCompoundOrderWithSignature.selector,
                _orderId,
                _minPrice,
                _maxPrice,
                _manager,
                _salt,
                _signature
            )
        );
        if (!success) {
            revert();
        }
    }

    function repayCompoundOrderWithSignature(
        uint256 _orderId,
        uint256 _repayAmountInUSDC,
        address _manager,
        uint256 _salt,
        bytes calldata _signature
    ) external {
        (bool success, ) = peakdefiLogic.delegatecall(
            abi.encodeWithSelector(
                this.repayCompoundOrderWithSignature.selector,
                _orderId,
                _repayAmountInUSDC,
                _manager,
                _salt,
                _signature
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Creates a new investment for an ERC20 token.
     * @param _tokenAddress address of the ERC20 token contract
     * @param _stake amount of RepTokens to be staked in support of the investment
     * @param _maxPrice the maximum price for the trade
     */
    function createInvestment(
        address _tokenAddress,
        uint256 _stake,
        uint256 _maxPrice
    ) public {
        (bool success, ) = peakdefiLogic.delegatecall(
            abi.encodeWithSelector(
                this.createInvestment.selector,
                _tokenAddress,
                _stake,
                _maxPrice
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Creates a new investment for an ERC20 token.
     * @param _tokenAddress address of the ERC20 token contract
     * @param _stake amount of RepTokens to be staked in support of the investment
     * @param _maxPrice the maximum price for the trade
     * @param _calldata calldata for 1inch trading
     * @param _useKyber true for Kyber Network, false for 1inch
     */
    function createInvestmentV2(
        address _sender,
        address _tokenAddress,
        uint256 _stake,
        uint256 _maxPrice,
        bytes memory _calldata,
        bool _useKyber
    ) public {
        (bool success, ) = peakdefiLogic.delegatecall(
            abi.encodeWithSelector(
                this.createInvestmentV2.selector,
                _sender,
                _tokenAddress,
                _stake,
                _maxPrice,
                _calldata,
                _useKyber
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Called by user to sell the assets an investment invested in. Returns the staked RepToken plus rewards/penalties to the user.
     *         The user can sell only part of the investment by changing _tokenAmount.
     * @dev When selling only part of an investment, the old investment would be "fully" sold and a new investment would be created with
     *   the original buy price and however much tokens that are not sold.
     * @param _investmentId the ID of the investment
     * @param _tokenAmount the amount of tokens to be sold.
     * @param _minPrice the minimum price for the trade
     */
    function sellInvestmentAsset(
        uint256 _investmentId,
        uint256 _tokenAmount,
        uint256 _minPrice
    ) public {
        (bool success, ) = peakdefiLogic.delegatecall(
            abi.encodeWithSelector(
                this.sellInvestmentAsset.selector,
                _investmentId,
                _tokenAmount,
                _minPrice
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Called by user to sell the assets an investment invested in. Returns the staked RepToken plus rewards/penalties to the user.
     *         The user can sell only part of the investment by changing _tokenAmount.
     * @dev When selling only part of an investment, the old investment would be "fully" sold and a new investment would be created with
     *   the original buy price and however much tokens that are not sold.
     * @param _investmentId the ID of the investment
     * @param _tokenAmount the amount of tokens to be sold.
     * @param _minPrice the minimum price for the trade
     */
    function sellInvestmentAssetV2(
        address _sender,
        uint256 _investmentId,
        uint256 _tokenAmount,
        uint256 _minPrice,
        bytes memory _calldata,
        bool _useKyber
    ) public {
        (bool success, ) = peakdefiLogic.delegatecall(
            abi.encodeWithSelector(
                this.sellInvestmentAssetV2.selector,
                _sender,
                _investmentId,
                _tokenAmount,
                _minPrice,
                _calldata,
                _useKyber
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Creates a new Compound order to either short or leverage long a token.
     * @param _orderType true for a short order, false for a levarage long order
     * @param _tokenAddress address of the Compound token to be traded
     * @param _stake amount of RepTokens to be staked
     * @param _minPrice the minimum token price for the trade
     * @param _maxPrice the maximum token price for the trade
     */
    function createCompoundOrder(
        address _sender,
        bool _orderType,
        address _tokenAddress,
        uint256 _stake,
        uint256 _minPrice,
        uint256 _maxPrice
    ) public {
        (bool success, ) = peakdefiLogic.delegatecall(
            abi.encodeWithSelector(
                this.createCompoundOrder.selector,
                _sender,
                _orderType,
                _tokenAddress,
                _stake,
                _minPrice,
                _maxPrice
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Sells a compound order
     * @param _orderId the ID of the order to be sold (index in userCompoundOrders[msg.sender])
     * @param _minPrice the minimum token price for the trade
     * @param _maxPrice the maximum token price for the trade
     */
    function sellCompoundOrder(
        address _sender,
        uint256 _orderId,
        uint256 _minPrice,
        uint256 _maxPrice
    ) public {
        (bool success, ) = peakdefiLogic.delegatecall(
            abi.encodeWithSelector(
                this.sellCompoundOrder.selector,
                _sender,
                _orderId,
                _minPrice,
                _maxPrice
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Repys debt for a Compound order to prevent the collateral ratio from dropping below threshold.
     * @param _orderId the ID of the Compound order
     * @param _repayAmountInUSDC amount of USDC to use for repaying debt
     */
    function repayCompoundOrder(
        address _sender,
        uint256 _orderId,
        uint256 _repayAmountInUSDC
    ) public {
        (bool success, ) = peakdefiLogic.delegatecall(
            abi.encodeWithSelector(
                this.repayCompoundOrder.selector,
                _sender,
                _orderId,
                _repayAmountInUSDC
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Emergency exit the tokens from order contract during intermission stage
     * @param _sender the address of trader, who created the order
     * @param _orderId the ID of the Compound order
     * @param _tokenAddr the address of token which should be transferred
     * @param _receiver the address of receiver
     */
    function emergencyExitCompoundTokens(
        address _sender,
        uint256 _orderId,
        address _tokenAddr,
        address _receiver
    ) public onlyOwner {
        (bool success, ) = peakdefiLogic.delegatecall(
            abi.encodeWithSelector(
                this.emergencyExitCompoundTokens.selector,
                _sender,
                _orderId,
                _tokenAddr,
                _receiver
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * Internal use functions
     */

    // MiniMe TokenController functions, not used right now
    /**
     * @notice Called when `_owner` sends ether to the MiniMe Token contract
     * @return True if the ether is accepted, false if it throws
     */
    function proxyPayment(
        address /*_owner*/
    ) public payable returns (bool) {
        return false;
    }

    /**
     * @notice Notifies the controller about a token transfer allowing the
     *  controller to react if desired
     * @return False if the controller does not authorize the transfer
     */
    function onTransfer(
        address, /*_from*/
        address, /*_to*/
        uint256 /*_amount*/
    ) public returns (bool) {
        return true;
    }

    /**
     * @notice Notifies the controller about an approval allowing the
     *  controller to react if desired
     * @return False if the controller does not authorize the approval
     */
    function onApprove(
        address, /*_owner*/
        address, /*_spender*/
        uint256 /*_amount*/
    ) public returns (bool) {
        return true;
    }

    function() external payable {}

    /**
    PeakDeFi
   */

    /**
     * @notice Returns the commission balance of `_referrer`
     * @return the commission balance and the received penalty, denoted in USDC
     */
    function peakReferralCommissionBalanceOf(address _referrer)
        public
        returns (uint256 _commission)
    {
        (bool success, bytes memory result) = peakdefiLogic3.delegatecall(
            abi.encodeWithSelector(
                this.peakReferralCommissionBalanceOf.selector,
                _referrer
            )
        );
        if (!success) {
            return 0;
        }
        return abi.decode(result, (uint256));
    }

    /**
     * @notice Returns the commission amount received by `_referrer` in the `_cycle`th cycle
     * @return the commission amount and the received penalty, denoted in USDC
     */
    function peakReferralCommissionOfAt(address _referrer, uint256 _cycle)
        public
        returns (uint256 _commission)
    {
        (bool success, bytes memory result) = peakdefiLogic3.delegatecall(
            abi.encodeWithSelector(
                this.peakReferralCommissionOfAt.selector,
                _referrer,
                _cycle
            )
        );
        if (!success) {
            return 0;
        }
        return abi.decode(result, (uint256));
    }

    /**
     * @notice Redeems commission.
     */
    function peakReferralRedeemCommission() public {
        (bool success, ) = peakdefiLogic3.delegatecall(
            abi.encodeWithSelector(this.peakReferralRedeemCommission.selector)
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Redeems commission for a particular cycle.
     * @param _cycle the cycle for which the commission will be redeemed.
     *        Commissions for a cycle will be redeemed during the Intermission phase of the next cycle, so _cycle must < cycleNumber.
     */
    function peakReferralRedeemCommissionForCycle(uint256 _cycle) public {
        (bool success, ) = peakdefiLogic3.delegatecall(
            abi.encodeWithSelector(
                this.peakReferralRedeemCommissionForCycle.selector,
                _cycle
            )
        );
        if (!success) {
            revert();
        }
    }

    /**
     * @notice Changes the required PEAK stake of a new manager. Only callable by owner.
     * @param _newValue the new value
     */
    function peakChangeManagerStakeRequired(uint256 _newValue)
        public
        onlyOwner
    {
        peakManagerStakeRequired = _newValue;
    }
}

pragma solidity 0.5.17;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./lib/ReentrancyGuard.sol";
import "./interfaces/IMiniMeToken.sol";
import "./tokens/minime/TokenController.sol";
import "./Utils.sol";
import "./PeakDeFiProxyInterface.sol";
import "./peak/reward/PeakReward.sol";
import "./peak/staking/PeakStaking.sol";

/**
 * @title The storage layout of PeakDeFiFund
 * @author Zefram Lou (Zebang Liu)
 */
contract PeakDeFiStorage is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    enum CyclePhase {Intermission, Manage}
    enum VoteDirection {Empty, For, Against}
    enum Subchunk {Propose, Vote}

    struct Investment {
        address tokenAddress;
        uint256 cycleNumber;
        uint256 stake;
        uint256 tokenAmount;
        uint256 buyPrice; // token buy price in 18 decimals in USDC
        uint256 sellPrice; // token sell price in 18 decimals in USDC
        uint256 buyTime;
        uint256 buyCostInUSDC;
        bool isSold;
    }

    // Fund parameters
    uint256 public constant COMMISSION_RATE = 15 * (10**16); // The proportion of profits that gets distributed to RepToken holders every cycle.
    uint256 public constant ASSET_FEE_RATE = 1 * (10**15); // The proportion of fund balance that gets distributed to RepToken holders every cycle.
    uint256 public constant NEXT_PHASE_REWARD = 1 * (10**18); // Amount of RepToken rewarded to the user who calls nextPhase().
    uint256 public constant COLLATERAL_RATIO_MODIFIER = 75 * (10**16); // Modifies Compound's collateral ratio, gets 2:1 from 1.5:1 ratio
    uint256 public constant MIN_RISK_TIME = 3 days; // Mininum risk taken to get full commissions is 9 days * reptokenBalance
    uint256 public constant INACTIVE_THRESHOLD = 2; // Number of inactive cycles after which a manager's RepToken balance can be burned
    uint256 public constant ROI_PUNISH_THRESHOLD = 1 * (10**17); // ROI worse than 10% will see punishment in stake
    uint256 public constant ROI_BURN_THRESHOLD = 25 * (10**16); // ROI worse than 25% will see their stake all burned
    uint256 public constant ROI_PUNISH_SLOPE = 6; // repROI = -(6 * absROI - 0.5)
    uint256 public constant ROI_PUNISH_NEG_BIAS = 5 * (10**17); // repROI = -(6 * absROI - 0.5)
    uint256 public constant PEAK_COMMISSION_RATE = 20 * (10**16); // The proportion of profits that gets distributed to PeakDeFi referrers every cycle.

    // Instance variables

    // Checks if the token listing initialization has been completed.
    bool public hasInitializedTokenListings;

    // Checks if the fund has been initialized
    bool public isInitialized;

    // Address of the RepToken token contract.
    address public controlTokenAddr;

    // Address of the share token contract.
    address public shareTokenAddr;

    // Address of the PeakDeFiProxy contract.
    address payable public proxyAddr;

    // Address of the CompoundOrderFactory contract.
    address public compoundFactoryAddr;

    // Address of the PeakDeFiLogic contract.
    address public peakdefiLogic;
    address public peakdefiLogic2;
    address public peakdefiLogic3;

    // Address to which the development team funding will be sent.
    address payable public devFundingAccount;

    // Address of the previous version of PeakDeFiFund.
    address payable public previousVersion;

    // The number of the current investment cycle.
    uint256 public cycleNumber;

    // The amount of funds held by the fund.
    uint256 public totalFundsInUSDC;

    // The total funds at the beginning of the current management phase
    uint256 public totalFundsAtManagePhaseStart;

    // The start time for the current investment cycle phase, in seconds since Unix epoch.
    uint256 public startTimeOfCyclePhase;

    // The proportion of PeakDeFi Shares total supply to mint and use for funding the development team. Fixed point decimal.
    uint256 public devFundingRate;

    // Total amount of commission unclaimed by managers
    uint256 public totalCommissionLeft;

    // Stores the lengths of each cycle phase in seconds.
    uint256[2] public phaseLengths;

    // The number of managers onboarded during the current cycle
    uint256 public managersOnboardedThisCycle;

    // The amount of RepToken tokens a new manager receves
    uint256 public newManagerRepToken;

    // The max number of new managers that can be onboarded in one cycle
    uint256 public maxNewManagersPerCycle;

    // The price of RepToken in USDC
    uint256 public reptokenPrice;

    // The last cycle where a user redeemed all of their remaining commission.
    mapping(address => uint256) internal _lastCommissionRedemption;

    // Marks whether a manager has redeemed their commission for a certain cycle
    mapping(address => mapping(uint256 => bool))
        internal _hasRedeemedCommissionForCycle;

    // The stake-time measured risk that a manager has taken in a cycle
    mapping(address => mapping(uint256 => uint256)) internal _riskTakenInCycle;

    // In case a manager joined the fund during the current cycle, set the fallback base stake for risk threshold calculation
    mapping(address => uint256) internal _baseRiskStakeFallback;

    // List of investments of a manager in the current cycle.
    mapping(address => Investment[]) public userInvestments;

    // List of short/long orders of a manager in the current cycle.
    mapping(address => address payable[]) public userCompoundOrders;

    // Total commission to be paid for work done in a certain cycle (will be redeemed in the next cycle's Intermission)
    mapping(uint256 => uint256) internal _totalCommissionOfCycle;

    // The block number at which the Manage phase ended for a given cycle
    mapping(uint256 => uint256) internal _managePhaseEndBlock;

    // The last cycle where a manager made an investment
    mapping(address => uint256) internal _lastActiveCycle;

    // Checks if an address points to a whitelisted Kyber token.
    mapping(address => bool) public isKyberToken;

    // Checks if an address points to a whitelisted Compound token. Returns false for cUSDC and other stablecoin CompoundTokens.
    mapping(address => bool) public isCompoundToken;

    // The current cycle phase.
    CyclePhase public cyclePhase;

    // Upgrade governance related variables
    bool public hasFinalizedNextVersion; // Denotes if the address of the next smart contract version has been finalized
    address payable public nextVersion; // Address of the next version of PeakDeFiFund.

    // Contract instances
    IMiniMeToken internal cToken;
    IMiniMeToken internal sToken;
    PeakDeFiProxyInterface internal proxy;

    // PeakDeFi
    uint256 public peakReferralTotalCommissionLeft;
    uint256 public peakManagerStakeRequired;
    mapping(uint256 => uint256) internal _peakReferralTotalCommissionOfCycle;
    mapping(address => uint256) internal _peakReferralLastCommissionRedemption;
    mapping(address => mapping(uint256 => bool))
        internal _peakReferralHasRedeemedCommissionForCycle;
    IMiniMeToken public peakReferralToken;
    PeakReward public peakReward;
    PeakStaking public peakStaking;
    bool public isPermissioned;
    mapping(address => mapping(uint256 => bool)) public hasUsedSalt;

    // Events

    event ChangedPhase(
        uint256 indexed _cycleNumber,
        uint256 indexed _newPhase,
        uint256 _timestamp,
        uint256 _totalFundsInUSDC
    );

    event Deposit(
        uint256 indexed _cycleNumber,
        address indexed _sender,
        address _tokenAddress,
        uint256 _tokenAmount,
        uint256 _usdcAmount,
        uint256 _timestamp
    );
    event Withdraw(
        uint256 indexed _cycleNumber,
        address indexed _sender,
        address _tokenAddress,
        uint256 _tokenAmount,
        uint256 _usdcAmount,
        uint256 _timestamp
    );

    event CreatedInvestment(
        uint256 indexed _cycleNumber,
        address indexed _sender,
        uint256 _id,
        address _tokenAddress,
        uint256 _stakeInWeis,
        uint256 _buyPrice,
        uint256 _costUSDCAmount,
        uint256 _tokenAmount
    );
    event SoldInvestment(
        uint256 indexed _cycleNumber,
        address indexed _sender,
        uint256 _id,
        address _tokenAddress,
        uint256 _receivedRepToken,
        uint256 _sellPrice,
        uint256 _earnedUSDCAmount
    );

    event CreatedCompoundOrder(
        uint256 indexed _cycleNumber,
        address indexed _sender,
        uint256 _id,
        address _order,
        bool _orderType,
        address _tokenAddress,
        uint256 _stakeInWeis,
        uint256 _costUSDCAmount
    );
    event SoldCompoundOrder(
        uint256 indexed _cycleNumber,
        address indexed _sender,
        uint256 _id,
        address _order,
        bool _orderType,
        address _tokenAddress,
        uint256 _receivedRepToken,
        uint256 _earnedUSDCAmount
    );
    event RepaidCompoundOrder(
        uint256 indexed _cycleNumber,
        address indexed _sender,
        uint256 _id,
        address _order,
        uint256 _repaidUSDCAmount
    );

    event CommissionPaid(
        uint256 indexed _cycleNumber,
        address indexed _sender,
        uint256 _commission
    );
    event TotalCommissionPaid(
        uint256 indexed _cycleNumber,
        uint256 _totalCommissionInUSDC
    );

    event Register(
        address indexed _manager,
        uint256 _donationInUSDC,
        uint256 _reptokenReceived
    );
    event BurnDeadman(address indexed _manager, uint256 _reptokenBurned);

    event DeveloperInitiatedUpgrade(
        uint256 indexed _cycleNumber,
        address _candidate
    );
    event FinalizedNextVersion(
        uint256 indexed _cycleNumber,
        address _nextVersion
    );

    event PeakReferralCommissionPaid(
        uint256 indexed _cycleNumber,
        address indexed _sender,
        uint256 _commission
    );
    event PeakReferralTotalCommissionPaid(
        uint256 indexed _cycleNumber,
        uint256 _totalCommissionInUSDC
    );

    /*
  Helper functions shared by both PeakDeFiLogic & PeakDeFiFund
  */

    function lastCommissionRedemption(address _manager)
        public
        view
        returns (uint256)
    {
        if (_lastCommissionRedemption[_manager] == 0) {
            return
                previousVersion == address(0)
                    ? 0
                    : PeakDeFiStorage(previousVersion).lastCommissionRedemption(
                        _manager
                    );
        }
        return _lastCommissionRedemption[_manager];
    }

    function hasRedeemedCommissionForCycle(address _manager, uint256 _cycle)
        public
        view
        returns (bool)
    {
        if (_hasRedeemedCommissionForCycle[_manager][_cycle] == false) {
            return
                previousVersion == address(0)
                    ? false
                    : PeakDeFiStorage(previousVersion)
                        .hasRedeemedCommissionForCycle(_manager, _cycle);
        }
        return _hasRedeemedCommissionForCycle[_manager][_cycle];
    }

    function riskTakenInCycle(address _manager, uint256 _cycle)
        public
        view
        returns (uint256)
    {
        if (_riskTakenInCycle[_manager][_cycle] == 0) {
            return
                previousVersion == address(0)
                    ? 0
                    : PeakDeFiStorage(previousVersion).riskTakenInCycle(
                        _manager,
                        _cycle
                    );
        }
        return _riskTakenInCycle[_manager][_cycle];
    }

    function baseRiskStakeFallback(address _manager)
        public
        view
        returns (uint256)
    {
        if (_baseRiskStakeFallback[_manager] == 0) {
            return
                previousVersion == address(0)
                    ? 0
                    : PeakDeFiStorage(previousVersion).baseRiskStakeFallback(
                        _manager
                    );
        }
        return _baseRiskStakeFallback[_manager];
    }

    function totalCommissionOfCycle(uint256 _cycle)
        public
        view
        returns (uint256)
    {
        if (_totalCommissionOfCycle[_cycle] == 0) {
            return
                previousVersion == address(0)
                    ? 0
                    : PeakDeFiStorage(previousVersion).totalCommissionOfCycle(
                        _cycle
                    );
        }
        return _totalCommissionOfCycle[_cycle];
    }

    function managePhaseEndBlock(uint256 _cycle) public view returns (uint256) {
        if (_managePhaseEndBlock[_cycle] == 0) {
            return
                previousVersion == address(0)
                    ? 0
                    : PeakDeFiStorage(previousVersion).managePhaseEndBlock(
                        _cycle
                    );
        }
        return _managePhaseEndBlock[_cycle];
    }

    function lastActiveCycle(address _manager) public view returns (uint256) {
        if (_lastActiveCycle[_manager] == 0) {
            return
                previousVersion == address(0)
                    ? 0
                    : PeakDeFiStorage(previousVersion).lastActiveCycle(_manager);
        }
        return _lastActiveCycle[_manager];
    }

    /**
    PeakDeFi
   */
    function peakReferralLastCommissionRedemption(address _manager)
        public
        view
        returns (uint256)
    {
        if (_peakReferralLastCommissionRedemption[_manager] == 0) {
            return
                previousVersion == address(0)
                    ? 0
                    : PeakDeFiStorage(previousVersion)
                        .peakReferralLastCommissionRedemption(_manager);
        }
        return _peakReferralLastCommissionRedemption[_manager];
    }

    function peakReferralHasRedeemedCommissionForCycle(
        address _manager,
        uint256 _cycle
    ) public view returns (bool) {
        if (
            _peakReferralHasRedeemedCommissionForCycle[_manager][_cycle] ==
            false
        ) {
            return
                previousVersion == address(0)
                    ? false
                    : PeakDeFiStorage(previousVersion)
                        .peakReferralHasRedeemedCommissionForCycle(
                        _manager,
                        _cycle
                    );
        }
        return _peakReferralHasRedeemedCommissionForCycle[_manager][_cycle];
    }

    function peakReferralTotalCommissionOfCycle(uint256 _cycle)
        public
        view
        returns (uint256)
    {
        if (_peakReferralTotalCommissionOfCycle[_cycle] == 0) {
            return
                previousVersion == address(0)
                    ? 0
                    : PeakDeFiStorage(previousVersion)
                        .peakReferralTotalCommissionOfCycle(_cycle);
        }
        return _peakReferralTotalCommissionOfCycle[_cycle];
    }
}

pragma solidity 0.5.17;

interface PeakDeFiProxyInterface {
  function peakdefiFundAddress() external view returns (address payable);
  function updatePeakDeFiFundAddress() external;
}
pragma solidity 0.5.17;

import "./PeakDeFiFund.sol";

contract PeakDeFiProxy {
    address payable public peakdefiFundAddress;

    event UpdatedFundAddress(address payable _newFundAddr);

    constructor(address payable _fundAddr) public {
        peakdefiFundAddress = _fundAddr;
        emit UpdatedFundAddress(_fundAddr);
    }

    function updatePeakDeFiFundAddress() public {
        require(msg.sender == peakdefiFundAddress, "Sender not PeakDeFiFund");
        address payable nextVersion = PeakDeFiFund(peakdefiFundAddress)
            .nextVersion();
        require(nextVersion != address(0), "Next version can't be empty");
        peakdefiFundAddress = nextVersion;
        emit UpdatedFundAddress(peakdefiFundAddress);
    }
}

pragma solidity 0.5.17;

import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "./PeakDeFiStorage.sol";
import "./derivatives/CompoundOrderFactory.sol";

/**
 * @title Part of the functions for PeakDeFiFund
 * @author Zefram Lou (Zebang Liu)
 */
contract PeakDeFiLogic is
    PeakDeFiStorage,
    Utils(address(0), address(0), address(0))
{
    /**
     * @notice Executes function only during the given cycle phase.
     * @param phase the cycle phase during which the function may be called
     */
    modifier during(CyclePhase phase) {
        require(cyclePhase == phase);
        if (cyclePhase == CyclePhase.Intermission) {
            require(isInitialized);
        }
        _;
    }

    /**
     * @notice Returns the length of the user's investments array.
     * @return length of the user's investments array
     */
    function investmentsCount(address _userAddr)
        public
        view
        returns (uint256 _count)
    {
        return userInvestments[_userAddr].length;
    }

    /**
     * @notice Burns the RepToken balance of a manager who has been inactive for a certain number of cycles
     * @param _deadman the manager whose RepToken balance will be burned
     */
    function burnDeadman(address _deadman)
        public
        nonReentrant
        during(CyclePhase.Intermission)
    {
        require(_deadman != address(this));
        require(
            cycleNumber.sub(lastActiveCycle(_deadman)) > INACTIVE_THRESHOLD
        );
        uint256 balance = cToken.balanceOf(_deadman);
        require(cToken.destroyTokens(_deadman, balance));
        emit BurnDeadman(_deadman, balance);
    }

    /**
     * @notice Creates a new investment for an ERC20 token. Backwards compatible.
     * @param _tokenAddress address of the ERC20 token contract
     * @param _stake amount of RepTokens to be staked in support of the investment
     * @param _maxPrice the maximum price for the trade
     */
    function createInvestment(
        address _tokenAddress,
        uint256 _stake,
        uint256 _maxPrice
    ) public {
        bytes memory nil;
        createInvestmentV2(
            msg.sender,
            _tokenAddress,
            _stake,
            _maxPrice,
            nil,
            true
        );
    }

    function createInvestmentWithSignature(
        address _tokenAddress,
        uint256 _stake,
        uint256 _maxPrice,
        bytes calldata _calldata,
        bool _useKyber,
        address _manager,
        uint256 _salt,
        bytes calldata _signature
    ) external {
        require(!hasUsedSalt[_manager][_salt]);
        bytes32 naiveHash = keccak256(
            abi.encodeWithSelector(
                this.createInvestmentWithSignature.selector,
                abi.encode(
                    _tokenAddress,
                    _stake,
                    _maxPrice,
                    _calldata,
                    _useKyber
                ),
                "|END|",
                _salt,
                address(this)
            )
        );
        bytes32 msgHash = ECDSA.toEthSignedMessageHash(naiveHash);
        address recoveredAddress = ECDSA.recover(msgHash, _signature);
        require(recoveredAddress == _manager);

        // Signature valid, record use of salt
        hasUsedSalt[_manager][_salt] = true;

        this.createInvestmentV2(
            _manager,
            _tokenAddress,
            _stake,
            _maxPrice,
            _calldata,
            _useKyber
        );
    }

    /**
     * @notice Called by user to sell the assets an investment invested in. Returns the staked RepToken plus rewards/penalties to the user.
     *         The user can sell only part of the investment by changing _tokenAmount. Backwards compatible.
     * @dev When selling only part of an investment, the old investment would be "fully" sold and a new investment would be created with
     *   the original buy price and however much tokens that are not sold.
     * @param _investmentId the ID of the investment
     * @param _tokenAmount the amount of tokens to be sold.
     * @param _minPrice the minimum price for the trade
     */
    function sellInvestmentAsset(
        uint256 _investmentId,
        uint256 _tokenAmount,
        uint256 _minPrice
    ) public {
        bytes memory nil;
        sellInvestmentAssetV2(
            msg.sender,
            _investmentId,
            _tokenAmount,
            _minPrice,
            nil,
            true
        );
    }

    function sellInvestmentWithSignature(
        uint256 _investmentId,
        uint256 _tokenAmount,
        uint256 _minPrice,
        bytes calldata _calldata,
        bool _useKyber,
        address _manager,
        uint256 _salt,
        bytes calldata _signature
    ) external {
        require(!hasUsedSalt[_manager][_salt]);
        bytes32 naiveHash = keccak256(
            abi.encodeWithSelector(
                this.sellInvestmentWithSignature.selector,
                abi.encode(
                    _investmentId,
                    _tokenAmount,
                    _minPrice,
                    _calldata,
                    _useKyber
                ),
                "|END|",
                _salt,
                address(this)
            )
        );
        bytes32 msgHash = ECDSA.toEthSignedMessageHash(naiveHash);
        address recoveredAddress = ECDSA.recover(msgHash, _signature);
        require(recoveredAddress == _manager);

        // Signature valid, record use of salt
        hasUsedSalt[_manager][_salt] = true;

        this.sellInvestmentAssetV2(
            _manager,
            _investmentId,
            _tokenAmount,
            _minPrice,
            _calldata,
            _useKyber
        );
    }

    /**
     * @notice Creates a new investment for an ERC20 token.
     * @param _tokenAddress address of the ERC20 token contract
     * @param _stake amount of RepTokens to be staked in support of the investment
     * @param _maxPrice the maximum price for the trade
     * @param _calldata calldata for 1inch trading
     * @param _useKyber true for Kyber Network, false for 1inch
     */
    function createInvestmentV2(
        address _sender,
        address _tokenAddress,
        uint256 _stake,
        uint256 _maxPrice,
        bytes memory _calldata,
        bool _useKyber
    )
        public
        during(CyclePhase.Manage)
        nonReentrant
        isValidToken(_tokenAddress)
    {
        require(msg.sender == _sender || msg.sender == address(this));
        require(_stake > 0);
        require(isKyberToken[_tokenAddress]);

        // Verify user peak stake
        uint256 peakStake = peakStaking.userStakeAmount(_sender);
        require(peakStake >= peakManagerStakeRequired);

        // Collect stake
        require(cToken.generateTokens(address(this), _stake));
        require(cToken.destroyTokens(_sender, _stake));

        // Add investment to list
        userInvestments[_sender].push(
            Investment({
                tokenAddress: _tokenAddress,
                cycleNumber: cycleNumber,
                stake: _stake,
                tokenAmount: 0,
                buyPrice: 0,
                sellPrice: 0,
                buyTime: now,
                buyCostInUSDC: 0,
                isSold: false
            })
        );

        // Invest
        uint256 investmentId = investmentsCount(_sender).sub(1);
        __handleInvestment(
            _sender,
            investmentId,
            0,
            _maxPrice,
            true,
            _calldata,
            _useKyber
        );

        // Update last active cycle
        _lastActiveCycle[_sender] = cycleNumber;

        // Emit event
        __emitCreatedInvestmentEvent(_sender, investmentId);
    }

    /**
     * @notice Called by user to sell the assets an investment invested in. Returns the staked RepToken plus rewards/penalties to the user.
     *         The user can sell only part of the investment by changing _tokenAmount.
     * @dev When selling only part of an investment, the old investment would be "fully" sold and a new investment would be created with
     *   the original buy price and however much tokens that are not sold.
     * @param _investmentId the ID of the investment
     * @param _tokenAmount the amount of tokens to be sold.
     * @param _minPrice the minimum price for the trade
     */
    function sellInvestmentAssetV2(
        address _sender,
        uint256 _investmentId,
        uint256 _tokenAmount,
        uint256 _minPrice,
        bytes memory _calldata,
        bool _useKyber
    ) public nonReentrant during(CyclePhase.Manage) {
        require(msg.sender == _sender || msg.sender == address(this));
        Investment storage investment = userInvestments[_sender][_investmentId];
        require(
            investment.buyPrice > 0 &&
                investment.cycleNumber == cycleNumber &&
                !investment.isSold
        );
        require(_tokenAmount > 0 && _tokenAmount <= investment.tokenAmount);

        // Create new investment for leftover tokens
        bool isPartialSell = false;
        uint256 stakeOfSoldTokens = investment.stake.mul(_tokenAmount).div(
            investment.tokenAmount
        );
        if (_tokenAmount != investment.tokenAmount) {
            isPartialSell = true;

            __createInvestmentForLeftovers(
                _sender,
                _investmentId,
                _tokenAmount
            );

            __emitCreatedInvestmentEvent(
                _sender,
                investmentsCount(_sender).sub(1)
            );
        }

        // Update investment info
        investment.isSold = true;

        // Sell asset
        (
            uint256 actualDestAmount,
            uint256 actualSrcAmount
        ) = __handleInvestment(
            _sender,
            _investmentId,
            _minPrice,
            uint256(-1),
            false,
            _calldata,
            _useKyber
        );

        __sellInvestmentUpdate(
            _sender,
            _investmentId,
            stakeOfSoldTokens,
            actualDestAmount
        );
    }

    function __sellInvestmentUpdate(
        address _sender,
        uint256 _investmentId,
        uint256 stakeOfSoldTokens,
        uint256 actualDestAmount
    ) internal {
        Investment storage investment = userInvestments[_sender][_investmentId];

        // Return staked RepToken
        uint256 receiveRepTokenAmount = getReceiveRepTokenAmount(
            stakeOfSoldTokens,
            investment.sellPrice,
            investment.buyPrice
        );
        __returnStake(receiveRepTokenAmount, stakeOfSoldTokens);

        // Record risk taken in investment
        __recordRisk(_sender, investment.stake, investment.buyTime);

        // Update total funds
        totalFundsInUSDC = totalFundsInUSDC.sub(investment.buyCostInUSDC).add(
            actualDestAmount
        );

        // Emit event
        __emitSoldInvestmentEvent(
            _sender,
            _investmentId,
            receiveRepTokenAmount,
            actualDestAmount
        );
    }

    function __emitSoldInvestmentEvent(
        address _sender,
        uint256 _investmentId,
        uint256 _receiveRepTokenAmount,
        uint256 _actualDestAmount
    ) internal {
        Investment storage investment = userInvestments[_sender][_investmentId];
        emit SoldInvestment(
            cycleNumber,
            _sender,
            _investmentId,
            investment.tokenAddress,
            _receiveRepTokenAmount,
            investment.sellPrice,
            _actualDestAmount
        );
    }

    function __createInvestmentForLeftovers(
        address _sender,
        uint256 _investmentId,
        uint256 _tokenAmount
    ) internal {
        Investment storage investment = userInvestments[_sender][_investmentId];

        uint256 stakeOfSoldTokens = investment.stake.mul(_tokenAmount).div(
            investment.tokenAmount
        );

        // calculate the part of original USDC cost attributed to the sold tokens
        uint256 soldBuyCostInUSDC = investment
            .buyCostInUSDC
            .mul(_tokenAmount)
            .div(investment.tokenAmount);

        userInvestments[_sender].push(
            Investment({
                tokenAddress: investment.tokenAddress,
                cycleNumber: cycleNumber,
                stake: investment.stake.sub(stakeOfSoldTokens),
                tokenAmount: investment.tokenAmount.sub(_tokenAmount),
                buyPrice: investment.buyPrice,
                sellPrice: 0,
                buyTime: investment.buyTime,
                buyCostInUSDC: investment.buyCostInUSDC.sub(soldBuyCostInUSDC),
                isSold: false
            })
        );

        // update the investment object being sold
        investment.tokenAmount = _tokenAmount;
        investment.stake = stakeOfSoldTokens;
        investment.buyCostInUSDC = soldBuyCostInUSDC;
    }

    function __emitCreatedInvestmentEvent(address _sender, uint256 _id)
        internal
    {
        Investment storage investment = userInvestments[_sender][_id];
        emit CreatedInvestment(
            cycleNumber,
            _sender,
            _id,
            investment.tokenAddress,
            investment.stake,
            investment.buyPrice,
            investment.buyCostInUSDC,
            investment.tokenAmount
        );
    }

    function createCompoundOrderWithSignature(
        bool _orderType,
        address _tokenAddress,
        uint256 _stake,
        uint256 _minPrice,
        uint256 _maxPrice,
        address _manager,
        uint256 _salt,
        bytes calldata _signature
    ) external {
        require(!hasUsedSalt[_manager][_salt]);
        bytes32 naiveHash = keccak256(
            abi.encodeWithSelector(
                this.createCompoundOrderWithSignature.selector,
                abi.encode(
                    _orderType,
                    _tokenAddress,
                    _stake,
                    _minPrice,
                    _maxPrice
                ),
                "|END|",
                _salt,
                address(this)
            )
        );
        bytes32 msgHash = ECDSA.toEthSignedMessageHash(naiveHash);
        address recoveredAddress = ECDSA.recover(msgHash, _signature);
        require(recoveredAddress == _manager);

        // Signature valid, record use of salt
        hasUsedSalt[_manager][_salt] = true;

        this.createCompoundOrder(
            _manager,
            _orderType,
            _tokenAddress,
            _stake,
            _minPrice,
            _maxPrice
        );
    }

    function sellCompoundOrderWithSignature(
        uint256 _orderId,
        uint256 _minPrice,
        uint256 _maxPrice,
        address _manager,
        uint256 _salt,
        bytes calldata _signature
    ) external {
        require(!hasUsedSalt[_manager][_salt]);
        bytes32 naiveHash = keccak256(
            abi.encodeWithSelector(
                this.sellCompoundOrderWithSignature.selector,
                abi.encode(_orderId, _minPrice, _maxPrice),
                "|END|",
                _salt,
                address(this)
            )
        );
        bytes32 msgHash = ECDSA.toEthSignedMessageHash(naiveHash);
        address recoveredAddress = ECDSA.recover(msgHash, _signature);
        require(recoveredAddress == _manager);

        // Signature valid, record use of salt
        hasUsedSalt[_manager][_salt] = true;

        this.sellCompoundOrder(_manager, _orderId, _minPrice, _maxPrice);
    }

    function repayCompoundOrderWithSignature(
        uint256 _orderId,
        uint256 _repayAmountInUSDC,
        address _manager,
        uint256 _salt,
        bytes calldata _signature
    ) external {
        require(!hasUsedSalt[_manager][_salt]);
        bytes32 naiveHash = keccak256(
            abi.encodeWithSelector(
                this.repayCompoundOrderWithSignature.selector,
                abi.encode(_orderId, _repayAmountInUSDC),
                "|END|",
                _salt,
                address(this)
            )
        );
        bytes32 msgHash = ECDSA.toEthSignedMessageHash(naiveHash);
        address recoveredAddress = ECDSA.recover(msgHash, _signature);
        require(recoveredAddress == _manager);

        // Signature valid, record use of salt
        hasUsedSalt[_manager][_salt] = true;

        this.repayCompoundOrder(_manager, _orderId, _repayAmountInUSDC);
    }

    /**
     * @notice Creates a new Compound order to either short or leverage long a token.
     * @param _orderType true for a short order, false for a levarage long order
     * @param _tokenAddress address of the Compound token to be traded
     * @param _stake amount of RepTokens to be staked
     * @param _minPrice the minimum token price for the trade
     * @param _maxPrice the maximum token price for the trade
     */
    function createCompoundOrder(
        address _sender,
        bool _orderType,
        address _tokenAddress,
        uint256 _stake,
        uint256 _minPrice,
        uint256 _maxPrice
    )
        public
        during(CyclePhase.Manage)
        nonReentrant
        isValidToken(_tokenAddress)
    {
        require(msg.sender == _sender || msg.sender == address(this));
        require(_minPrice <= _maxPrice);
        require(_stake > 0);
        require(isCompoundToken[_tokenAddress]);

        // Verify user peak stake
        uint256 peakStake = peakStaking.userStakeAmount(_sender);
        require(peakStake >= peakManagerStakeRequired);

        // Collect stake
        require(cToken.generateTokens(address(this), _stake));
        require(cToken.destroyTokens(_sender, _stake));

        // Create compound order and execute
        uint256 collateralAmountInUSDC = totalFundsInUSDC.mul(_stake).div(
            cToken.totalSupply()
        );
        CompoundOrder order = __createCompoundOrder(
            _orderType,
            _tokenAddress,
            _stake,
            collateralAmountInUSDC
        );
        usdc.safeApprove(address(order), 0);
        usdc.safeApprove(address(order), collateralAmountInUSDC);
        order.executeOrder(_minPrice, _maxPrice);

        // Add order to list
        userCompoundOrders[_sender].push(address(order));

        // Update last active cycle
        _lastActiveCycle[_sender] = cycleNumber;

        __emitCreatedCompoundOrderEvent(
            _sender,
            address(order),
            _orderType,
            _tokenAddress,
            _stake,
            collateralAmountInUSDC
        );
    }

    function __emitCreatedCompoundOrderEvent(
        address _sender,
        address order,
        bool _orderType,
        address _tokenAddress,
        uint256 _stake,
        uint256 collateralAmountInUSDC
    ) internal {
        // Emit event
        emit CreatedCompoundOrder(
            cycleNumber,
            _sender,
            userCompoundOrders[_sender].length - 1,
            address(order),
            _orderType,
            _tokenAddress,
            _stake,
            collateralAmountInUSDC
        );
    }

    /**
     * @notice Sells a compound order
     * @param _orderId the ID of the order to be sold (index in userCompoundOrders[msg.sender])
     * @param _minPrice the minimum token price for the trade
     * @param _maxPrice the maximum token price for the trade
     */
    function sellCompoundOrder(
        address _sender,
        uint256 _orderId,
        uint256 _minPrice,
        uint256 _maxPrice
    ) public during(CyclePhase.Manage) nonReentrant {
        require(msg.sender == _sender || msg.sender == address(this));
        // Load order info
        require(userCompoundOrders[_sender][_orderId] != address(0));
        CompoundOrder order = CompoundOrder(
            userCompoundOrders[_sender][_orderId]
        );
        require(order.isSold() == false && order.cycleNumber() == cycleNumber);

        // Sell order
        (uint256 inputAmount, uint256 outputAmount) = order.sellOrder(
            _minPrice,
            _maxPrice
        );

        // Return staked RepToken
        uint256 stake = order.stake();
        uint256 receiveRepTokenAmount = getReceiveRepTokenAmount(
            stake,
            outputAmount,
            inputAmount
        );
        __returnStake(receiveRepTokenAmount, stake);

        // Record risk taken
        __recordRisk(_sender, stake, order.buyTime());

        // Update total funds
        totalFundsInUSDC = totalFundsInUSDC.sub(inputAmount).add(outputAmount);

        // Emit event
        emit SoldCompoundOrder(
            cycleNumber,
            _sender,
            userCompoundOrders[_sender].length - 1,
            address(order),
            order.orderType(),
            order.compoundTokenAddr(),
            receiveRepTokenAmount,
            outputAmount
        );
    }

    /**
     * @notice Repys debt for a Compound order to prevent the collateral ratio from dropping below threshold.
     * @param _orderId the ID of the Compound order
     * @param _repayAmountInUSDC amount of USDC to use for repaying debt
     */
    function repayCompoundOrder(
        address _sender,
        uint256 _orderId,
        uint256 _repayAmountInUSDC
    ) public during(CyclePhase.Manage) nonReentrant {
        require(msg.sender == _sender || msg.sender == address(this));
        // Load order info
        require(userCompoundOrders[_sender][_orderId] != address(0));
        CompoundOrder order = CompoundOrder(
            userCompoundOrders[_sender][_orderId]
        );
        require(order.isSold() == false && order.cycleNumber() == cycleNumber);

        // Repay loan
        order.repayLoan(_repayAmountInUSDC);

        // Emit event
        emit RepaidCompoundOrder(
            cycleNumber,
            _sender,
            userCompoundOrders[_sender].length - 1,
            address(order),
            _repayAmountInUSDC
        );
    }

    function emergencyExitCompoundTokens(
        address _sender,
        uint256 _orderId,
        address _tokenAddr,
        address _receiver
    ) public during(CyclePhase.Intermission) nonReentrant {
        CompoundOrder order = CompoundOrder(userCompoundOrders[_sender][_orderId]);
        order.emergencyExitTokens(_tokenAddr, _receiver);
    }

    function getReceiveRepTokenAmount(
        uint256 stake,
        uint256 output,
        uint256 input
    ) public pure returns (uint256 _amount) {
        if (output >= input) {
            // positive ROI, simply return stake * (1 + ROI)
            return stake.mul(output).div(input);
        } else {
            // negative ROI
            uint256 absROI = input.sub(output).mul(PRECISION).div(input);
            if (absROI <= ROI_PUNISH_THRESHOLD) {
                // ROI better than -10%, no punishment
                return stake.mul(output).div(input);
            } else if (
                absROI > ROI_PUNISH_THRESHOLD && absROI < ROI_BURN_THRESHOLD
            ) {
                // ROI between -10% and -25%, punish
                // return stake * (1 + roiWithPunishment) = stake * (1 + (-(6 * absROI - 0.5)))
                return
                    stake
                        .mul(
                        PRECISION.sub(
                            ROI_PUNISH_SLOPE.mul(absROI).sub(
                                ROI_PUNISH_NEG_BIAS
                            )
                        )
                    )
                        .div(PRECISION);
            } else {
                // ROI greater than 25%, burn all stake
                return 0;
            }
        }
    }

    /**
     * @notice Handles and investment by doing the necessary trades using __kyberTrade() or Fulcrum trading
     * @param _investmentId the ID of the investment to be handled
     * @param _minPrice the minimum price for the trade
     * @param _maxPrice the maximum price for the trade
     * @param _buy whether to buy or sell the given investment
     * @param _calldata calldata for 1inch trading
     * @param _useKyber true for Kyber Network, false for 1inch
     */
    function __handleInvestment(
        address _sender,
        uint256 _investmentId,
        uint256 _minPrice,
        uint256 _maxPrice,
        bool _buy,
        bytes memory _calldata,
        bool _useKyber
    ) internal returns (uint256 _actualDestAmount, uint256 _actualSrcAmount) {
        Investment storage investment = userInvestments[_sender][_investmentId];
        address token = investment.tokenAddress;
        // Basic trading
        uint256 dInS; // price of dest token denominated in src token
        uint256 sInD; // price of src token denominated in dest token
        if (_buy) {
            if (_useKyber) {
                (
                    dInS,
                    sInD,
                    _actualDestAmount,
                    _actualSrcAmount
                ) = __kyberTrade(
                    usdc,
                    totalFundsInUSDC.mul(investment.stake).div(
                        cToken.totalSupply()
                    ),
                    ERC20Detailed(token)
                );
            } else {
                // 1inch trading
                (
                    dInS,
                    sInD,
                    _actualDestAmount,
                    _actualSrcAmount
                ) = __oneInchTrade(
                    usdc,
                    totalFundsInUSDC.mul(investment.stake).div(
                        cToken.totalSupply()
                    ),
                    ERC20Detailed(token),
                    _calldata
                );
            }
            require(_minPrice <= dInS && dInS <= _maxPrice);
            investment.buyPrice = dInS;
            investment.tokenAmount = _actualDestAmount;
            investment.buyCostInUSDC = _actualSrcAmount;
        } else {
            if (_useKyber) {
                (
                    dInS,
                    sInD,
                    _actualDestAmount,
                    _actualSrcAmount
                ) = __kyberTrade(
                    ERC20Detailed(token),
                    investment.tokenAmount,
                    usdc
                );
            } else {
                (
                    dInS,
                    sInD,
                    _actualDestAmount,
                    _actualSrcAmount
                ) = __oneInchTrade(
                    ERC20Detailed(token),
                    investment.tokenAmount,
                    usdc,
                    _calldata
                );
            }

            require(_minPrice <= sInD && sInD <= _maxPrice);
            investment.sellPrice = sInD;
        }
    }

    /**
     * @notice Separated from createCompoundOrder() to avoid stack too deep error
     */
    function __createCompoundOrder(
        bool _orderType, // True for shorting, false for longing
        address _tokenAddress,
        uint256 _stake,
        uint256 _collateralAmountInUSDC
    ) internal returns (CompoundOrder) {
        CompoundOrderFactory factory = CompoundOrderFactory(
            compoundFactoryAddr
        );
        uint256 loanAmountInUSDC = _collateralAmountInUSDC
            .mul(COLLATERAL_RATIO_MODIFIER)
            .div(PRECISION)
            .mul(factory.getMarketCollateralFactor(_tokenAddress))
            .div(PRECISION);
        CompoundOrder order = factory.createOrder(
            _tokenAddress,
            cycleNumber,
            _stake,
            _collateralAmountInUSDC,
            loanAmountInUSDC,
            _orderType
        );
        return order;
    }

    /**
     * @notice Returns stake to manager after investment is sold, including reward/penalty based on performance
     */
    function __returnStake(uint256 _receiveRepTokenAmount, uint256 _stake)
        internal
    {
        require(cToken.destroyTokens(address(this), _stake));
        require(cToken.generateTokens(msg.sender, _receiveRepTokenAmount));
    }

    /**
     * @notice Records risk taken in a trade based on stake and time of investment
     */
    function __recordRisk(
        address _sender,
        uint256 _stake,
        uint256 _buyTime
    ) internal {
        _riskTakenInCycle[_sender][cycleNumber] = riskTakenInCycle(
            _sender,
            cycleNumber
        )
            .add(_stake.mul(now.sub(_buyTime)));
    }
}

pragma solidity ^0.5.0;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * NOTE: This call _does not revert_ if the signature is invalid, or
     * if the signer is otherwise unable to be retrieved. In those scenarios,
     * the zero address is returned.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        // Check the signature length
        if (signature.length != 65) {
            return (address(0));
        }

        // Divide the signature in r, s and v variables
        bytes32 r;
        bytes32 s;
        uint8 v;

        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return address(0);
        }

        if (v != 27 && v != 28) {
            return address(0);
        }

        // If the signature is valid (and not malleable), return the signer address
        return ecrecover(hash, v, r, s);
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * replicates the behavior of the
     * https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_sign[`eth_sign`]
     * JSON-RPC method.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}

pragma solidity 0.5.17;

import "./PeakDeFiStorage.sol";
import "./derivatives/CompoundOrderFactory.sol";
import "@nomiclabs/buidler/console.sol";

/**
 * @title Part of the functions for PeakDeFiFund
 * @author Zefram Lou (Zebang Liu)
 */
contract PeakDeFiLogic2 is
    PeakDeFiStorage,
    Utils(address(0), address(0), address(0))
{
    /**
     * @notice Passes if the fund has not finalized the next smart contract to upgrade to
     */
    modifier notReadyForUpgrade {
        require(hasFinalizedNextVersion == false);
        _;
    }

    /**
     * @notice Executes function only during the given cycle phase.
     * @param phase the cycle phase during which the function may be called
     */
    modifier during(CyclePhase phase) {
        require(cyclePhase == phase);
        if (cyclePhase == CyclePhase.Intermission) {
            require(isInitialized);
        }
        _;
    }

    /**
     * Deposit & Withdraw
     */

    function depositEther(address _referrer) public payable {
        bytes memory nil;
        depositEtherAdvanced(true, nil, _referrer);
    }

    /**
     * @notice Deposit Ether into the fund. Ether will be converted into USDC.
     * @param _useKyber true for Kyber Network, false for 1inch
     * @param _calldata calldata for 1inch trading
     * @param _referrer the referrer's address

     */
    function depositEtherAdvanced(
        bool _useKyber,
        bytes memory _calldata,
        address _referrer
    ) public payable nonReentrant notReadyForUpgrade {
        // Buy USDC with ETH
        uint256 actualUSDCDeposited;
        uint256 actualETHDeposited;
        if (_useKyber) {
            (, , actualUSDCDeposited, actualETHDeposited) = __kyberTrade(
                ETH_TOKEN_ADDRESS,
                msg.value,
                usdc
            );
        } else {
            (, , actualUSDCDeposited, actualETHDeposited) = __oneInchTrade(
                ETH_TOKEN_ADDRESS,
                msg.value,
                usdc,
                _calldata
            );
        }

        // Send back leftover ETH
        uint256 leftOverETH = msg.value.sub(actualETHDeposited);
        if (leftOverETH > 0) {
            msg.sender.transfer(leftOverETH);
        }

        // Register investment
        __deposit(actualUSDCDeposited, _referrer);

        // Emit event
        emit Deposit(
            cycleNumber,
            msg.sender,
            address(ETH_TOKEN_ADDRESS),
            actualETHDeposited,
            actualUSDCDeposited,
            now
        );
    }

    /**
     * @notice Deposit USDC Stablecoin into the fund.
     * @param _usdcAmount The amount of USDC to be deposited. May be different from actual deposited amount.
     * @param _referrer the referrer's address
     */
    function depositUSDC(uint256 _usdcAmount, address _referrer)
        public
        nonReentrant
        notReadyForUpgrade
    {
        usdc.safeTransferFrom(msg.sender, address(this), _usdcAmount);

        // Register investment
        __deposit(_usdcAmount, _referrer);

        // Emit event
        emit Deposit(
            cycleNumber,
            msg.sender,
            USDC_ADDR,
            _usdcAmount,
            _usdcAmount,
            now
        );
    }

    function depositToken(
        address _tokenAddr,
        uint256 _tokenAmount,
        address _referrer
    ) public {
        bytes memory nil;
        depositTokenAdvanced(_tokenAddr, _tokenAmount, true, nil, _referrer);
    }

    /**
     * @notice Deposit ERC20 tokens into the fund. Tokens will be converted into USDC.
     * @param _tokenAddr the address of the token to be deposited
     * @param _tokenAmount The amount of tokens to be deposited. May be different from actual deposited amount.
     * @param _useKyber true for Kyber Network, false for 1inch
     * @param _calldata calldata for 1inch trading
     * @param _referrer the referrer's address
     */
    function depositTokenAdvanced(
        address _tokenAddr,
        uint256 _tokenAmount,
        bool _useKyber,
        bytes memory _calldata,
        address _referrer
    ) public nonReentrant notReadyForUpgrade isValidToken(_tokenAddr) {
        require(
            _tokenAddr != USDC_ADDR && _tokenAddr != address(ETH_TOKEN_ADDRESS)
        );

        ERC20Detailed token = ERC20Detailed(_tokenAddr);

        token.safeTransferFrom(msg.sender, address(this), _tokenAmount);
        // Convert token into USDC
        uint256 actualUSDCDeposited;
        uint256 actualTokenDeposited;
        if (_useKyber) {
            (, , actualUSDCDeposited, actualTokenDeposited) = __kyberTrade(
                token,
                _tokenAmount,
                usdc
            );
        } else {
            (, , actualUSDCDeposited, actualTokenDeposited) = __oneInchTrade(
                token,
                _tokenAmount,
                usdc,
                _calldata
            );
        }
        // Give back leftover tokens
        uint256 leftOverTokens = _tokenAmount.sub(actualTokenDeposited);
        if (leftOverTokens > 0) {
            token.safeTransfer(msg.sender, leftOverTokens);
        }

        // Register investment
        __deposit(actualUSDCDeposited, _referrer);

        // Emit event
        emit Deposit(
            cycleNumber,
            msg.sender,
            _tokenAddr,
            actualTokenDeposited,
            actualUSDCDeposited,
            now
        );
    }

    function withdrawEther(uint256 _amountInUSDC) external {
        bytes memory nil;
        withdrawEtherAdvanced(_amountInUSDC, true, nil);
    }

    /**
     * @notice Withdraws Ether by burning Shares.
     * @param _amountInUSDC Amount of funds to be withdrawn expressed in USDC. Fixed-point decimal. May be different from actual amount.
     * @param _useKyber true for Kyber Network, false for 1inch
     * @param _calldata calldata for 1inch trading
     */
    function withdrawEtherAdvanced(
        uint256 _amountInUSDC,
        bool _useKyber,
        bytes memory _calldata
    ) public nonReentrant during(CyclePhase.Intermission) {
        // Buy ETH
        uint256 actualETHWithdrawn;
        uint256 actualUSDCWithdrawn;
        if (_useKyber) {
            (, , actualETHWithdrawn, actualUSDCWithdrawn) = __kyberTrade(
                usdc,
                _amountInUSDC,
                ETH_TOKEN_ADDRESS
            );
        } else {
            (, , actualETHWithdrawn, actualUSDCWithdrawn) = __oneInchTrade(
                usdc,
                _amountInUSDC,
                ETH_TOKEN_ADDRESS,
                _calldata
            );
        }

        __withdraw(actualUSDCWithdrawn);

        // Transfer Ether to user
        msg.sender.transfer(actualETHWithdrawn);

        // Emit event
        emit Withdraw(
            cycleNumber,
            msg.sender,
            address(ETH_TOKEN_ADDRESS),
            actualETHWithdrawn,
            actualUSDCWithdrawn,
            now
        );
    }

    /**
     * @notice Withdraws Ether by burning Shares.
     * @param _amountInUSDC Amount of funds to be withdrawn expressed in USDC. Fixed-point decimal. May be different from actual amount.
     */
    function withdrawUSDC(uint256 _amountInUSDC)
        external
        nonReentrant
        during(CyclePhase.Intermission)
    {
        __withdraw(_amountInUSDC);

        // Transfer USDC to user
        usdc.safeTransfer(msg.sender, _amountInUSDC);

        // Emit event
        emit Withdraw(
            cycleNumber,
            msg.sender,
            USDC_ADDR,
            _amountInUSDC,
            _amountInUSDC,
            now
        );
    }

    function withdrawToken(address _tokenAddr, uint256 _amountInUSDC) external {
        bytes memory nil;
        withdrawTokenAdvanced(_tokenAddr, _amountInUSDC, true, nil);
    }

    /**
     * @notice Withdraws funds by burning Shares, and converts the funds into the specified token using Kyber Network.
     * @param _tokenAddr the address of the token to be withdrawn into the caller's account
     * @param _amountInUSDC The amount of funds to be withdrawn expressed in USDC. Fixed-point decimal. May be different from actual amount.
     * @param _useKyber true for Kyber Network, false for 1inch
     * @param _calldata calldata for 1inch trading
     */
    function withdrawTokenAdvanced(
        address _tokenAddr,
        uint256 _amountInUSDC,
        bool _useKyber,
        bytes memory _calldata
    )
        public
        during(CyclePhase.Intermission)
        nonReentrant
        isValidToken(_tokenAddr)
    {
        require(
            _tokenAddr != USDC_ADDR && _tokenAddr != address(ETH_TOKEN_ADDRESS)
        );

        ERC20Detailed token = ERC20Detailed(_tokenAddr);

        // Convert USDC into desired tokens
        uint256 actualTokenWithdrawn;
        uint256 actualUSDCWithdrawn;
        if (_useKyber) {
            (, , actualTokenWithdrawn, actualUSDCWithdrawn) = __kyberTrade(
                usdc,
                _amountInUSDC,
                token
            );
        } else {
            (, , actualTokenWithdrawn, actualUSDCWithdrawn) = __oneInchTrade(
                usdc,
                _amountInUSDC,
                token,
                _calldata
            );
        }

        __withdraw(actualUSDCWithdrawn);

        // Transfer tokens to user
        token.safeTransfer(msg.sender, actualTokenWithdrawn);

        // Emit event
        emit Withdraw(
            cycleNumber,
            msg.sender,
            _tokenAddr,
            actualTokenWithdrawn,
            actualUSDCWithdrawn,
            now
        );
    }

    /**
     * Manager registration
     */

    /**
     * @notice Registers `msg.sender` as a manager, using USDC as payment. The more one pays, the more RepToken one gets.
     *         There's a max RepToken amount that can be bought, and excess payment will be sent back to sender.
     */
    function registerWithUSDC()
        public
        during(CyclePhase.Intermission)
        nonReentrant
    {
        require(!isPermissioned);
        require(managersOnboardedThisCycle < maxNewManagersPerCycle);
        managersOnboardedThisCycle = managersOnboardedThisCycle.add(1);

        uint256 peakStake = peakStaking.userStakeAmount(msg.sender);
        require(peakStake >= peakManagerStakeRequired);

        uint256 donationInUSDC = newManagerRepToken.mul(reptokenPrice).div(PRECISION);
        usdc.safeTransferFrom(msg.sender, address(this), donationInUSDC);
        __register(donationInUSDC);
    }

    /**
     * @notice Registers `msg.sender` as a manager, using ETH as payment. The more one pays, the more RepToken one gets.
     *         There's a max RepToken amount that can be bought, and excess payment will be sent back to sender.
     */
    function registerWithETH()
        public
        payable
        during(CyclePhase.Intermission)
        nonReentrant
    {
        require(!isPermissioned);
        require(managersOnboardedThisCycle < maxNewManagersPerCycle);
        managersOnboardedThisCycle = managersOnboardedThisCycle.add(1);

        uint256 peakStake = peakStaking.userStakeAmount(msg.sender);
        require(peakStake >= peakManagerStakeRequired);

        uint256 receivedUSDC;

        // trade ETH for USDC
        (, , receivedUSDC, ) = __kyberTrade(ETH_TOKEN_ADDRESS, msg.value, usdc);

        // if USDC value is greater than the amount required, return excess USDC to msg.sender
        uint256 donationInUSDC = newManagerRepToken.mul(reptokenPrice).div(PRECISION);
        if (receivedUSDC > donationInUSDC) {
            usdc.safeTransfer(msg.sender, receivedUSDC.sub(donationInUSDC));
            receivedUSDC = donationInUSDC;
        }

        // register new manager
        __register(receivedUSDC);
    }

    /**
     * @notice Registers `msg.sender` as a manager, using tokens as payment. The more one pays, the more RepToken one gets.
     *         There's a max RepToken amount that can be bought, and excess payment will be sent back to sender.
     * @param _token the token to be used for payment
     * @param _donationInTokens the amount of tokens to be used for registration, should use the token's native decimals
     */
    function registerWithToken(address _token, uint256 _donationInTokens)
        public
        during(CyclePhase.Intermission)
        nonReentrant
    {
        require(!isPermissioned);
        require(managersOnboardedThisCycle < maxNewManagersPerCycle);
        managersOnboardedThisCycle = managersOnboardedThisCycle.add(1);

        uint256 peakStake = peakStaking.userStakeAmount(msg.sender);
        require(peakStake >= peakManagerStakeRequired);

        require(
            _token != address(0) &&
                _token != address(ETH_TOKEN_ADDRESS) &&
                _token != USDC_ADDR
        );
        ERC20Detailed token = ERC20Detailed(_token);
        require(token.totalSupply() > 0);

        token.safeTransferFrom(msg.sender, address(this), _donationInTokens);

        uint256 receivedUSDC;

        (, , receivedUSDC, ) = __kyberTrade(token, _donationInTokens, usdc);

        // if USDC value is greater than the amount required, return excess USDC to msg.sender
        uint256 donationInUSDC = newManagerRepToken.mul(reptokenPrice).div(PRECISION);
        if (receivedUSDC > donationInUSDC) {
            usdc.safeTransfer(msg.sender, receivedUSDC.sub(donationInUSDC));
            receivedUSDC = donationInUSDC;
        }

        // register new manager
        __register(receivedUSDC);
    }

    function peakAdminRegisterManager(address _manager, uint256 _reptokenAmount)
        public
        during(CyclePhase.Intermission)
        nonReentrant
        onlyOwner
    {
        require(isPermissioned);

        // mint REP for msg.sender
        require(cToken.generateTokens(_manager, _reptokenAmount));

        // Set risk fallback base stake
        _baseRiskStakeFallback[_manager] = _baseRiskStakeFallback[_manager].add(
            _reptokenAmount
        );

        // Set last active cycle for msg.sender to be the current cycle
        _lastActiveCycle[_manager] = cycleNumber;

        // emit events
        emit Register(_manager, 0, _reptokenAmount);
    }

    /**
     * @notice Sells tokens left over due to manager not selling or KyberNetwork not having enough volume. Callable by anyone. Money goes to developer.
     * @param _tokenAddr address of the token to be sold
     * @param _calldata the 1inch trade call data
     */
    function sellLeftoverToken(address _tokenAddr, bytes calldata _calldata)
        external
        during(CyclePhase.Intermission)
        nonReentrant
        isValidToken(_tokenAddr)
    {
        ERC20Detailed token = ERC20Detailed(_tokenAddr);
        (, , uint256 actualUSDCReceived, ) = __oneInchTrade(
            token,
            getBalance(token, address(this)),
            usdc,
            _calldata
        );
        totalFundsInUSDC = totalFundsInUSDC.add(actualUSDCReceived);
    }

    /**
     * @notice Sells CompoundOrder left over due to manager not selling or KyberNetwork not having enough volume. Callable by anyone. Money goes to developer.
     * @param _orderAddress address of the CompoundOrder to be sold
     */
    function sellLeftoverCompoundOrder(address payable _orderAddress)
        public
        during(CyclePhase.Intermission)
        nonReentrant
    {
        // Load order info
        require(_orderAddress != address(0));
        CompoundOrder order = CompoundOrder(_orderAddress);
        require(order.isSold() == false && order.cycleNumber() < cycleNumber);

        // Sell short order
        // Not using outputAmount returned by order.sellOrder() because _orderAddress could point to a malicious contract
        uint256 beforeUSDCBalance = usdc.balanceOf(address(this));
        order.sellOrder(0, MAX_QTY);
        uint256 actualUSDCReceived = usdc.balanceOf(address(this)).sub(
            beforeUSDCBalance
        );

        totalFundsInUSDC = totalFundsInUSDC.add(actualUSDCReceived);
    }

    /**
     * @notice Registers `msg.sender` as a manager.
     * @param _donationInUSDC the amount of USDC to be used for registration
     */
    function __register(uint256 _donationInUSDC) internal {
        require(
            cToken.balanceOf(msg.sender) == 0 &&
                userInvestments[msg.sender].length == 0 &&
                userCompoundOrders[msg.sender].length == 0
        ); // each address can only join once

        // mint REP for msg.sender
        uint256 repAmount = _donationInUSDC.mul(PRECISION).div(reptokenPrice);
        require(cToken.generateTokens(msg.sender, repAmount));

        // Set risk fallback base stake
        _baseRiskStakeFallback[msg.sender] = repAmount;

        // Set last active cycle for msg.sender to be the current cycle
        _lastActiveCycle[msg.sender] = cycleNumber;

        // keep USDC in the fund
        totalFundsInUSDC = totalFundsInUSDC.add(_donationInUSDC);

        // emit events
        emit Register(msg.sender, _donationInUSDC, repAmount);
    }

    /**
     * @notice Handles deposits by minting PeakDeFi Shares & updating total funds.
     * @param _depositUSDCAmount The amount of the deposit in USDC
     * @param _referrer The deposit referrer
     */
    function __deposit(uint256 _depositUSDCAmount, address _referrer) internal {
        // Register investment and give shares
        uint256 shareAmount;
        if (sToken.totalSupply() == 0 || totalFundsInUSDC == 0) {
            uint256 usdcDecimals = getDecimals(usdc);
            shareAmount = _depositUSDCAmount.mul(PRECISION).div(10**usdcDecimals);
        } else {
            shareAmount = _depositUSDCAmount.mul(sToken.totalSupply()).div(
                totalFundsInUSDC
            );
        }
        require(sToken.generateTokens(msg.sender, shareAmount));
        totalFundsInUSDC = totalFundsInUSDC.add(_depositUSDCAmount);
        totalFundsAtManagePhaseStart = totalFundsAtManagePhaseStart.add(
            _depositUSDCAmount
        );

        // Handle peakReferralToken
        if (peakReward.canRefer(msg.sender, _referrer)) {
            peakReward.refer(msg.sender, _referrer);
        }
        address actualReferrer = peakReward.referrerOf(msg.sender);
        if (actualReferrer != address(0)) {
            require(
                peakReferralToken.generateTokens(actualReferrer, shareAmount)
            );
        }
    }

    /**
     * @notice Handles deposits by burning PeakDeFi Shares & updating total funds.
     * @param _withdrawUSDCAmount The amount of the withdrawal in USDC
     */
    function __withdraw(uint256 _withdrawUSDCAmount) internal {
        // Burn Shares
        uint256 shareAmount = _withdrawUSDCAmount.mul(sToken.totalSupply()).div(
            totalFundsInUSDC
        );
        require(sToken.destroyTokens(msg.sender, shareAmount));
        totalFundsInUSDC = totalFundsInUSDC.sub(_withdrawUSDCAmount);

        // Handle peakReferralToken
        address actualReferrer = peakReward.referrerOf(msg.sender);
        if (actualReferrer != address(0)) {
            uint256 balance = peakReferralToken.balanceOf(actualReferrer);
            uint256 burnReferralTokenAmount = shareAmount > balance
                ? balance
                : shareAmount;
            require(
                peakReferralToken.destroyTokens(
                    actualReferrer,
                    burnReferralTokenAmount
                )
            );
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >= 0.4.22 <0.8.0;

library console {
	address constant CONSOLE_ADDRESS = address(0x000000000000000000636F6e736F6c652e6c6f67);

	function _sendLogPayload(bytes memory payload) private view {
		uint256 payloadLength = payload.length;
		address consoleAddress = CONSOLE_ADDRESS;
		assembly {
			let payloadStart := add(payload, 32)
			let r := staticcall(gas(), consoleAddress, payloadStart, payloadLength, 0, 0)
		}
	}

	function log() internal view {
		_sendLogPayload(abi.encodeWithSignature("log()"));
	}

	function logInt(int p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(int)", p0));
	}

	function logUint(uint p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
	}

	function logString(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function logBool(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function logAddress(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function logBytes(bytes memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
	}

	function logByte(byte p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(byte)", p0));
	}

	function logBytes1(bytes1 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes1)", p0));
	}

	function logBytes2(bytes2 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes2)", p0));
	}

	function logBytes3(bytes3 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes3)", p0));
	}

	function logBytes4(bytes4 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes4)", p0));
	}

	function logBytes5(bytes5 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes5)", p0));
	}

	function logBytes6(bytes6 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes6)", p0));
	}

	function logBytes7(bytes7 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes7)", p0));
	}

	function logBytes8(bytes8 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes8)", p0));
	}

	function logBytes9(bytes9 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes9)", p0));
	}

	function logBytes10(bytes10 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes10)", p0));
	}

	function logBytes11(bytes11 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes11)", p0));
	}

	function logBytes12(bytes12 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes12)", p0));
	}

	function logBytes13(bytes13 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes13)", p0));
	}

	function logBytes14(bytes14 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes14)", p0));
	}

	function logBytes15(bytes15 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes15)", p0));
	}

	function logBytes16(bytes16 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes16)", p0));
	}

	function logBytes17(bytes17 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes17)", p0));
	}

	function logBytes18(bytes18 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes18)", p0));
	}

	function logBytes19(bytes19 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes19)", p0));
	}

	function logBytes20(bytes20 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes20)", p0));
	}

	function logBytes21(bytes21 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes21)", p0));
	}

	function logBytes22(bytes22 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes22)", p0));
	}

	function logBytes23(bytes23 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes23)", p0));
	}

	function logBytes24(bytes24 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes24)", p0));
	}

	function logBytes25(bytes25 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes25)", p0));
	}

	function logBytes26(bytes26 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes26)", p0));
	}

	function logBytes27(bytes27 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes27)", p0));
	}

	function logBytes28(bytes28 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes28)", p0));
	}

	function logBytes29(bytes29 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes29)", p0));
	}

	function logBytes30(bytes30 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes30)", p0));
	}

	function logBytes31(bytes31 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes31)", p0));
	}

	function logBytes32(bytes32 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes32)", p0));
	}

	function log(uint p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
	}

	function log(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function log(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function log(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function log(uint p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint)", p0, p1));
	}

	function log(uint p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string)", p0, p1));
	}

	function log(uint p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool)", p0, p1));
	}

	function log(uint p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address)", p0, p1));
	}

	function log(string memory p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint)", p0, p1));
	}

	function log(string memory p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
	}

	function log(string memory p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
	}

	function log(string memory p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address)", p0, p1));
	}

	function log(bool p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint)", p0, p1));
	}

	function log(bool p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string)", p0, p1));
	}

	function log(bool p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool)", p0, p1));
	}

	function log(bool p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address)", p0, p1));
	}

	function log(address p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint)", p0, p1));
	}

	function log(address p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string)", p0, p1));
	}

	function log(address p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool)", p0, p1));
	}

	function log(address p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address)", p0, p1));
	}

	function log(uint p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint)", p0, p1, p2));
	}

	function log(uint p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string)", p0, p1, p2));
	}

	function log(uint p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool)", p0, p1, p2));
	}

	function log(uint p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address)", p0, p1, p2));
	}

	function log(uint p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint)", p0, p1, p2));
	}

	function log(uint p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string)", p0, p1, p2));
	}

	function log(uint p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool)", p0, p1, p2));
	}

	function log(uint p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address)", p0, p1, p2));
	}

	function log(uint p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint)", p0, p1, p2));
	}

	function log(uint p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string)", p0, p1, p2));
	}

	function log(uint p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool)", p0, p1, p2));
	}

	function log(uint p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2));
	}

	function log(string memory p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint)", p0, p1, p2));
	}

	function log(string memory p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string)", p0, p1, p2));
	}

	function log(string memory p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2));
	}

	function log(string memory p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address)", p0, p1, p2));
	}

	function log(bool p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint)", p0, p1, p2));
	}

	function log(bool p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string)", p0, p1, p2));
	}

	function log(bool p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool)", p0, p1, p2));
	}

	function log(bool p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2));
	}

	function log(bool p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint)", p0, p1, p2));
	}

	function log(bool p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2));
	}

	function log(bool p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
	}

	function log(bool p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2));
	}

	function log(bool p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint)", p0, p1, p2));
	}

	function log(bool p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2));
	}

	function log(bool p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2));
	}

	function log(bool p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2));
	}

	function log(address p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint)", p0, p1, p2));
	}

	function log(address p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string)", p0, p1, p2));
	}

	function log(address p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool)", p0, p1, p2));
	}

	function log(address p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address)", p0, p1, p2));
	}

	function log(address p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint)", p0, p1, p2));
	}

	function log(address p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string)", p0, p1, p2));
	}

	function log(address p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2));
	}

	function log(address p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address)", p0, p1, p2));
	}

	function log(address p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint)", p0, p1, p2));
	}

	function log(address p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2));
	}

	function log(address p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2));
	}

	function log(address p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2));
	}

	function log(address p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint)", p0, p1, p2));
	}

	function log(address p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string)", p0, p1, p2));
	}

	function log(address p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2));
	}

	function log(address p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address)", p0, p1, p2));
	}

	function log(uint p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,address)", p0, p1, p2, p3));
	}

}

pragma solidity 0.5.17;

import "./PeakDeFiStorage.sol";

contract PeakDeFiLogic3 is
    PeakDeFiStorage,
    Utils(address(0), address(0), address(0))
{
    /**
     * @notice Passes if the fund has not finalized the next smart contract to upgrade to
     */
    modifier notReadyForUpgrade {
        require(hasFinalizedNextVersion == false);
        _;
    }

    /**
     * @notice Executes function only during the given cycle phase.
     * @param phase the cycle phase during which the function may be called
     */
    modifier during(CyclePhase phase) {
        require(cyclePhase == phase);
        if (cyclePhase == CyclePhase.Intermission) {
            require(isInitialized);
        }
        _;
    }

    /**
     * Next phase transition handler
     * @notice Moves the fund to the next phase in the investment cycle.
     */
    function nextPhase() public nonReentrant {
        require(
            now >= startTimeOfCyclePhase.add(phaseLengths[uint256(cyclePhase)])
        );

        if (isInitialized == false) {
            // first cycle of this smart contract deployment
            // check whether ready for starting cycle
            isInitialized = true;
            require(proxyAddr != address(0)); // has initialized proxy
            require(proxy.peakdefiFundAddress() == address(this)); // upgrade complete
            require(hasInitializedTokenListings); // has initialized token listings

            // execute initialization function
            __init();

            require(
                previousVersion == address(0) ||
                    (previousVersion != address(0) &&
                        getBalance(usdc, address(this)) > 0)
            ); // has transfered assets from previous version
        } else {
            // normal phase changing
            if (cyclePhase == CyclePhase.Intermission) {
                require(hasFinalizedNextVersion == false); // Shouldn't progress to next phase if upgrading

                // Update total funds at management phase's beginning
                totalFundsAtManagePhaseStart = totalFundsInUSDC;

                // reset number of managers onboarded
                managersOnboardedThisCycle = 0;
            } else if (cyclePhase == CyclePhase.Manage) {
                // Burn any RepToken left in PeakDeFiFund's account
                require(
                    cToken.destroyTokens(
                        address(this),
                        cToken.balanceOf(address(this))
                    )
                );

                // Pay out commissions and fees
                uint256 profit = 0;


                    uint256 usdcBalanceAtManagePhaseStart
                 = totalFundsAtManagePhaseStart.add(totalCommissionLeft);
                if (
                    getBalance(usdc, address(this)) >
                    usdcBalanceAtManagePhaseStart
                ) {
                    profit = getBalance(usdc, address(this)).sub(
                        usdcBalanceAtManagePhaseStart
                    );
                }

                totalFundsInUSDC = getBalance(usdc, address(this))
                    .sub(totalCommissionLeft)
                    .sub(peakReferralTotalCommissionLeft);

                // Calculate manager commissions
                uint256 commissionThisCycle = COMMISSION_RATE
                    .mul(profit)
                    .add(ASSET_FEE_RATE.mul(totalFundsInUSDC))
                    .div(PRECISION);
                _totalCommissionOfCycle[cycleNumber] = totalCommissionOfCycle(
                    cycleNumber
                )
                    .add(commissionThisCycle); // account for penalties
                totalCommissionLeft = totalCommissionLeft.add(
                    commissionThisCycle
                );

                // Calculate referrer commissions
                uint256 peakReferralCommissionThisCycle = PEAK_COMMISSION_RATE
                    .mul(profit)
                    .mul(peakReferralToken.totalSupply())
                    .div(sToken.totalSupply())
                    .div(PRECISION);
                _peakReferralTotalCommissionOfCycle[cycleNumber] = peakReferralTotalCommissionOfCycle(
                    cycleNumber
                )
                    .add(peakReferralCommissionThisCycle);
                peakReferralTotalCommissionLeft = peakReferralTotalCommissionLeft
                    .add(peakReferralCommissionThisCycle);

                totalFundsInUSDC = getBalance(usdc, address(this))
                    .sub(totalCommissionLeft)
                    .sub(peakReferralTotalCommissionLeft);

                // Give the developer PeakDeFi shares inflation funding
                uint256 devFunding = devFundingRate
                    .mul(sToken.totalSupply())
                    .div(PRECISION);
                require(sToken.generateTokens(devFundingAccount, devFunding));

                // Emit event
                emit TotalCommissionPaid(
                    cycleNumber,
                    totalCommissionOfCycle(cycleNumber)
                );
                emit PeakReferralTotalCommissionPaid(
                    cycleNumber,
                    peakReferralTotalCommissionOfCycle(cycleNumber)
                );

                _managePhaseEndBlock[cycleNumber] = block.number;

                // Clear/update upgrade related data
                if (nextVersion == address(this)) {
                    // The developer proposed a candidate, but the managers decide to not upgrade at all
                    // Reset upgrade process
                    delete nextVersion;
                    delete hasFinalizedNextVersion;
                }
                if (nextVersion != address(0)) {
                    hasFinalizedNextVersion = true;
                    emit FinalizedNextVersion(cycleNumber, nextVersion);
                }

                // Start new cycle
                cycleNumber = cycleNumber.add(1);
            }

            cyclePhase = CyclePhase(addmod(uint256(cyclePhase), 1, 2));
        }

        startTimeOfCyclePhase = now;

        // Reward caller if they're a manager
        if (cToken.balanceOf(msg.sender) > 0) {
            require(cToken.generateTokens(msg.sender, NEXT_PHASE_REWARD));
        }

        emit ChangedPhase(
            cycleNumber,
            uint256(cyclePhase),
            now,
            totalFundsInUSDC
        );
    }

    /**
     * @notice Initializes several important variables after smart contract upgrade
     */
    function __init() internal {
        _managePhaseEndBlock[cycleNumber.sub(1)] = block.number;

        // load values from previous version
        totalCommissionLeft = previousVersion == address(0)
            ? 0
            : PeakDeFiStorage(previousVersion).totalCommissionLeft();
        totalFundsInUSDC = getBalance(usdc, address(this)).sub(
            totalCommissionLeft
        );
    }

    /**
     * Upgrading functions
     */

    /**
     * @notice Allows the developer to propose a candidate smart contract for the fund to upgrade to.
     *          The developer may change the candidate during the Intermission phase.
     * @param _candidate the address of the candidate smart contract
     * @return True if successfully changed candidate, false otherwise.
     */
    function developerInitiateUpgrade(address payable _candidate)
        public
        onlyOwner
        notReadyForUpgrade
        during(CyclePhase.Intermission)
        nonReentrant
        returns (bool _success)
    {
        if (_candidate == address(0) || _candidate == address(this)) {
            return false;
        }
        nextVersion = _candidate;
        emit DeveloperInitiatedUpgrade(cycleNumber, _candidate);
        return true;
    }

    /**
        Commission functions
     */

    /**
     * @notice Returns the commission balance of `_manager`
     * @return the commission balance and the received penalty, denoted in USDC
     */
    function commissionBalanceOf(address _manager)
        public
        view
        returns (uint256 _commission, uint256 _penalty)
    {
        if (lastCommissionRedemption(_manager) >= cycleNumber) {
            return (0, 0);
        }
        uint256 cycle = lastCommissionRedemption(_manager) > 0
            ? lastCommissionRedemption(_manager)
            : 1;
        uint256 cycleCommission;
        uint256 cyclePenalty;
        for (; cycle < cycleNumber; cycle++) {
            (cycleCommission, cyclePenalty) = commissionOfAt(_manager, cycle);
            _commission = _commission.add(cycleCommission);
            _penalty = _penalty.add(cyclePenalty);
        }
    }

    /**
     * @notice Returns the commission amount received by `_manager` in the `_cycle`th cycle
     * @return the commission amount and the received penalty, denoted in USDC
     */
    function commissionOfAt(address _manager, uint256 _cycle)
        public
        view
        returns (uint256 _commission, uint256 _penalty)
    {
        if (hasRedeemedCommissionForCycle(_manager, _cycle)) {
            return (0, 0);
        }
        // take risk into account
        uint256 baseRepTokenBalance = cToken.balanceOfAt(
            _manager,
            managePhaseEndBlock(_cycle.sub(1))
        );
        uint256 baseStake = baseRepTokenBalance == 0
            ? baseRiskStakeFallback(_manager)
            : baseRepTokenBalance;
        if (baseRepTokenBalance == 0 && baseRiskStakeFallback(_manager) == 0) {
            return (0, 0);
        }
        uint256 riskTakenProportion = riskTakenInCycle(_manager, _cycle)
            .mul(PRECISION)
            .div(baseStake.mul(MIN_RISK_TIME)); // risk / threshold
        riskTakenProportion = riskTakenProportion > PRECISION
            ? PRECISION
            : riskTakenProportion; // max proportion is 1

        uint256 fullCommission = totalCommissionOfCycle(_cycle)
            .mul(cToken.balanceOfAt(_manager, managePhaseEndBlock(_cycle)))
            .div(cToken.totalSupplyAt(managePhaseEndBlock(_cycle)));

        _commission = fullCommission.mul(riskTakenProportion).div(PRECISION);
        _penalty = fullCommission.sub(_commission);
    }

    /**
     * @notice Redeems commission.
     */
    function redeemCommission(bool _inShares)
        public
        during(CyclePhase.Intermission)
        nonReentrant
    {
        uint256 commission = __redeemCommission();

        if (_inShares) {
            // Deposit commission into fund
            __deposit(commission);

            // Emit deposit event
            emit Deposit(
                cycleNumber,
                msg.sender,
                USDC_ADDR,
                commission,
                commission,
                now
            );
        } else {
            // Transfer the commission in USDC
            usdc.safeTransfer(msg.sender, commission);
        }
    }

    /**
     * @notice Redeems commission for a particular cycle.
     * @param _inShares true to redeem in PeakDeFi Shares, false to redeem in USDC
     * @param _cycle the cycle for which the commission will be redeemed.
     *        Commissions for a cycle will be redeemed during the Intermission phase of the next cycle, so _cycle must < cycleNumber.
     */
    function redeemCommissionForCycle(bool _inShares, uint256 _cycle)
        public
        during(CyclePhase.Intermission)
        nonReentrant
    {
        require(_cycle < cycleNumber);

        uint256 commission = __redeemCommissionForCycle(_cycle);

        if (_inShares) {
            // Deposit commission into fund
            __deposit(commission);

            // Emit deposit event
            emit Deposit(
                cycleNumber,
                msg.sender,
                USDC_ADDR,
                commission,
                commission,
                now
            );
        } else {
            // Transfer the commission in USDC
            usdc.safeTransfer(msg.sender, commission);
        }
    }

    /**
     * @notice Redeems the commission for all previous cycles. Updates the related variables.
     * @return the amount of commission to be redeemed
     */
    function __redeemCommission() internal returns (uint256 _commission) {
        require(lastCommissionRedemption(msg.sender) < cycleNumber);

        uint256 penalty; // penalty received for not taking enough risk
        (_commission, penalty) = commissionBalanceOf(msg.sender);

        // record the redemption to prevent double-redemption
        for (
            uint256 i = lastCommissionRedemption(msg.sender);
            i < cycleNumber;
            i++
        ) {
            _hasRedeemedCommissionForCycle[msg.sender][i] = true;
        }
        _lastCommissionRedemption[msg.sender] = cycleNumber;

        // record the decrease in commission pool
        totalCommissionLeft = totalCommissionLeft.sub(_commission);
        // include commission penalty to this cycle's total commission pool
        _totalCommissionOfCycle[cycleNumber] = totalCommissionOfCycle(
            cycleNumber
        )
            .add(penalty);
        // clear investment arrays to save space
        delete userInvestments[msg.sender];
        delete userCompoundOrders[msg.sender];

        emit CommissionPaid(cycleNumber, msg.sender, _commission);
    }

    /**
     * @notice Redeems commission for a particular cycle. Updates the related variables.
     * @param _cycle the cycle for which the commission will be redeemed
     * @return the amount of commission to be redeemed
     */
    function __redeemCommissionForCycle(uint256 _cycle)
        internal
        returns (uint256 _commission)
    {
        require(!hasRedeemedCommissionForCycle(msg.sender, _cycle));

        uint256 penalty; // penalty received for not taking enough risk
        (_commission, penalty) = commissionOfAt(msg.sender, _cycle);

        _hasRedeemedCommissionForCycle[msg.sender][_cycle] = true;

        // record the decrease in commission pool
        totalCommissionLeft = totalCommissionLeft.sub(_commission);
        // include commission penalty to this cycle's total commission pool
        _totalCommissionOfCycle[cycleNumber] = totalCommissionOfCycle(
            cycleNumber
        )
            .add(penalty);
        // clear investment arrays to save space
        delete userInvestments[msg.sender];
        delete userCompoundOrders[msg.sender];

        emit CommissionPaid(_cycle, msg.sender, _commission);
    }

    /**
     * @notice Handles deposits by minting PeakDeFi Shares & updating total funds.
     * @param _depositUSDCAmount The amount of the deposit in USDC
     */
    function __deposit(uint256 _depositUSDCAmount) internal {
        // Register investment and give shares
        if (sToken.totalSupply() == 0 || totalFundsInUSDC == 0) {
            require(sToken.generateTokens(msg.sender, _depositUSDCAmount));
        } else {
            require(
                sToken.generateTokens(
                    msg.sender,
                    _depositUSDCAmount.mul(sToken.totalSupply()).div(
                        totalFundsInUSDC
                    )
                )
            );
        }
        totalFundsInUSDC = totalFundsInUSDC.add(_depositUSDCAmount);
    }

    /**
    PeakDeFi
   */

    /**
     * @notice Returns the commission balance of `_referrer`
     * @return the commission balance, denoted in USDC
     */
    function peakReferralCommissionBalanceOf(address _referrer)
        public
        view
        returns (uint256 _commission)
    {
        if (peakReferralLastCommissionRedemption(_referrer) >= cycleNumber) {
            return (0);
        }
        uint256 cycle = peakReferralLastCommissionRedemption(_referrer) > 0
            ? peakReferralLastCommissionRedemption(_referrer)
            : 1;
        uint256 cycleCommission;
        for (; cycle < cycleNumber; cycle++) {
            (cycleCommission) = peakReferralCommissionOfAt(_referrer, cycle);
            _commission = _commission.add(cycleCommission);
        }
    }

    /**
     * @notice Returns the commission amount received by `_referrer` in the `_cycle`th cycle
     * @return the commission amount, denoted in USDC
     */
    function peakReferralCommissionOfAt(address _referrer, uint256 _cycle)
        public
        view
        returns (uint256 _commission)
    {
        _commission = peakReferralTotalCommissionOfCycle(_cycle)
            .mul(
            peakReferralToken.balanceOfAt(
                _referrer,
                managePhaseEndBlock(_cycle)
            )
        )
            .div(peakReferralToken.totalSupplyAt(managePhaseEndBlock(_cycle)));
    }

    /**
     * @notice Redeems commission.
     */
    function peakReferralRedeemCommission()
        public
        during(CyclePhase.Intermission)
        nonReentrant
    {
        uint256 commission = __peakReferralRedeemCommission();

        // Transfer the commission in USDC
        usdc.safeApprove(address(peakReward), commission);
        peakReward.payCommission(msg.sender, address(usdc), commission, false);
    }

    /**
     * @notice Redeems commission for a particular cycle.
     * @param _cycle the cycle for which the commission will be redeemed.
     *        Commissions for a cycle will be redeemed during the Intermission phase of the next cycle, so _cycle must < cycleNumber.
     */
    function peakReferralRedeemCommissionForCycle(uint256 _cycle)
        public
        during(CyclePhase.Intermission)
        nonReentrant
    {
        require(_cycle < cycleNumber);

        uint256 commission = __peakReferralRedeemCommissionForCycle(_cycle);

        // Transfer the commission in USDC
        usdc.safeApprove(address(peakReward), commission);
        peakReward.payCommission(msg.sender, address(usdc), commission, false);
    }

    /**
     * @notice Redeems the commission for all previous cycles. Updates the related variables.
     * @return the amount of commission to be redeemed
     */
    function __peakReferralRedeemCommission()
        internal
        returns (uint256 _commission)
    {
        require(peakReferralLastCommissionRedemption(msg.sender) < cycleNumber);

        _commission = peakReferralCommissionBalanceOf(msg.sender);

        // record the redemption to prevent double-redemption
        for (
            uint256 i = peakReferralLastCommissionRedemption(msg.sender);
            i < cycleNumber;
            i++
        ) {
            _peakReferralHasRedeemedCommissionForCycle[msg.sender][i] = true;
        }
        _peakReferralLastCommissionRedemption[msg.sender] = cycleNumber;

        // record the decrease in commission pool
        peakReferralTotalCommissionLeft = peakReferralTotalCommissionLeft.sub(
            _commission
        );

        emit PeakReferralCommissionPaid(cycleNumber, msg.sender, _commission);
    }

    /**
     * @notice Redeems commission for a particular cycle. Updates the related variables.
     * @param _cycle the cycle for which the commission will be redeemed
     * @return the amount of commission to be redeemed
     */
    function __peakReferralRedeemCommissionForCycle(uint256 _cycle)
        internal
        returns (uint256 _commission)
    {
        require(!peakReferralHasRedeemedCommissionForCycle(msg.sender, _cycle));

        _commission = peakReferralCommissionOfAt(msg.sender, _cycle);

        _peakReferralHasRedeemedCommissionForCycle[msg.sender][_cycle] = true;

        // record the decrease in commission pool
        peakReferralTotalCommissionLeft = peakReferralTotalCommissionLeft.sub(
            _commission
        );

        emit PeakReferralCommissionPaid(_cycle, msg.sender, _commission);
    }
}

pragma solidity 0.5.17;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "../interfaces/CERC20.sol";
import "../interfaces/Comptroller.sol";

contract TestCERC20 is CERC20 {
  using SafeMath for uint;

  uint public constant PRECISION = 10 ** 18;
  uint public constant MAX_UINT = 2 ** 256 - 1;

  address public _underlying;
  uint public _exchangeRateCurrent = 10 ** (18 - 8) * PRECISION;

  mapping(address => uint) public _balanceOf;
  mapping(address => uint) public _borrowBalanceCurrent;

  Comptroller public COMPTROLLER;

  constructor(address __underlying, address _comptrollerAddr) public {
    _underlying = __underlying;
    COMPTROLLER = Comptroller(_comptrollerAddr);
  }

  function mint(uint mintAmount) external returns (uint) {
    ERC20Detailed token = ERC20Detailed(_underlying);
    require(token.transferFrom(msg.sender, address(this), mintAmount));

    _balanceOf[msg.sender] = _balanceOf[msg.sender].add(mintAmount.mul(10 ** this.decimals()).div(PRECISION));
    
    return 0;
  }

  function redeemUnderlying(uint redeemAmount) external returns (uint) {
    _balanceOf[msg.sender] = _balanceOf[msg.sender].sub(redeemAmount.mul(10 ** this.decimals()).div(PRECISION));

    ERC20Detailed token = ERC20Detailed(_underlying);
    require(token.transfer(msg.sender, redeemAmount));

    return 0;
  }
  
  function borrow(uint amount) external returns (uint) {
    // add to borrow balance
    _borrowBalanceCurrent[msg.sender] = _borrowBalanceCurrent[msg.sender].add(amount);

    // transfer asset
    ERC20Detailed token = ERC20Detailed(_underlying);
    require(token.transfer(msg.sender, amount));

    return 0;
  }
  
  function repayBorrow(uint amount) external returns (uint) {
    // accept repayment
    ERC20Detailed token = ERC20Detailed(_underlying);
    uint256 repayAmount = amount == MAX_UINT ? _borrowBalanceCurrent[msg.sender] : amount;
    require(token.transferFrom(msg.sender, address(this), repayAmount));

    // subtract from borrow balance
    _borrowBalanceCurrent[msg.sender] = _borrowBalanceCurrent[msg.sender].sub(repayAmount);

    return 0;
  }

  function balanceOf(address account) external view returns (uint) { return _balanceOf[account]; }
  function borrowBalanceCurrent(address account) external returns (uint) { return _borrowBalanceCurrent[account]; }
  function underlying() external view returns (address) { return _underlying; }
  function exchangeRateCurrent() external returns (uint) { return _exchangeRateCurrent; }
  function decimals() external view returns (uint) { return 8; }
}
pragma solidity 0.5.17;

import "./TestCERC20.sol";

contract TestCERC20Factory {
  mapping(address => address) public createdTokens;

  event CreatedToken(address underlying, address cToken);

  function newToken(address underlying, address comptroller) public returns(address) {
    require(createdTokens[underlying] == address(0));
    
    TestCERC20 token = new TestCERC20(underlying, comptroller);
    createdTokens[underlying] = address(token);
    emit CreatedToken(underlying, address(token));
    return address(token);
  }
}
pragma solidity 0.5.17;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/CEther.sol";
import "../interfaces/Comptroller.sol";

contract TestCEther is CEther {
  using SafeMath for uint;

  uint public constant PRECISION = 10 ** 18;

  uint public _exchangeRateCurrent = 10 ** (18 - 8) * PRECISION;

  mapping(address => uint) public _balanceOf;
  mapping(address => uint) public _borrowBalanceCurrent;

  Comptroller public COMPTROLLER;

  constructor(address _comptrollerAddr) public {
    COMPTROLLER = Comptroller(_comptrollerAddr);
  }

  function mint() external payable {
    _balanceOf[msg.sender] = _balanceOf[msg.sender].add(msg.value.mul(10 ** this.decimals()).div(PRECISION));
  }

  function redeemUnderlying(uint redeemAmount) external returns (uint) {
    _balanceOf[msg.sender] = _balanceOf[msg.sender].sub(redeemAmount.mul(10 ** this.decimals()).div(PRECISION));

    msg.sender.transfer(redeemAmount);

    return 0;
  }
  
  function borrow(uint amount) external returns (uint) {
    // add to borrow balance
    _borrowBalanceCurrent[msg.sender] = _borrowBalanceCurrent[msg.sender].add(amount);

    // transfer asset
    msg.sender.transfer(amount);

    return 0;
  }
  
  function repayBorrow() external payable {
    _borrowBalanceCurrent[msg.sender] = _borrowBalanceCurrent[msg.sender].sub(msg.value);
  }

  function balanceOf(address account) external view returns (uint) { return _balanceOf[account]; }
  function borrowBalanceCurrent(address account) external returns (uint) { return _borrowBalanceCurrent[account]; }
  function exchangeRateCurrent() external returns (uint) { return _exchangeRateCurrent; }
  function decimals() external view returns (uint) { return 8; }

  function() external payable {}
}
pragma solidity 0.5.17;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/Comptroller.sol";
import "../interfaces/PriceOracle.sol";
import "../interfaces/CERC20.sol";

contract TestComptroller is Comptroller {
  using SafeMath for uint;

  uint256 internal constant PRECISION = 10 ** 18;

  mapping(address => address[]) public getAssetsIn;
  uint256 internal collateralFactor = 2 * PRECISION / 3;

  constructor() public {}

  function enterMarkets(address[] calldata cTokens) external returns (uint[] memory) {
    uint[] memory errors = new uint[](cTokens.length);
    for (uint256 i = 0; i < cTokens.length; i = i.add(1)) {
      getAssetsIn[msg.sender].push(cTokens[i]);
      errors[i] = 0;
    }
    return errors;
  }

  function markets(address /*cToken*/) external view returns (bool isListed, uint256 collateralFactorMantissa) {
    return (true, collateralFactor);
  }
}
pragma solidity 0.5.17;

import "../interfaces/KyberNetwork.sol";
import "../Utils.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

contract TestKyberNetwork is KyberNetwork, Utils(address(0), address(0), address(0)), Ownable {
  mapping(address => uint256) public priceInUSDC;

  constructor(address[] memory _tokens, uint256[] memory _pricesInUSDC) public {
    for (uint256 i = 0; i < _tokens.length; i = i.add(1)) {
      priceInUSDC[_tokens[i]] = _pricesInUSDC[i];
    }
  }

  function setTokenPrice(address _token, uint256 _priceInUSDC) public onlyOwner {
    priceInUSDC[_token] = _priceInUSDC;
  }

  function setAllTokenPrices(address[] memory _tokens, uint256[] memory _pricesInUSDC) public onlyOwner {
    for (uint256 i = 0; i < _tokens.length; i = i.add(1)) {
      priceInUSDC[_tokens[i]] = _pricesInUSDC[i];
    }
  }

  function getExpectedRate(ERC20Detailed src, ERC20Detailed dest, uint /*srcQty*/) external view returns (uint expectedRate, uint slippageRate) 
  {
    uint256 result = priceInUSDC[address(src)].mul(10**getDecimals(dest)).mul(PRECISION).div(priceInUSDC[address(dest)].mul(10**getDecimals(src)));
    return (result, result);
  }

  function tradeWithHint(
    ERC20Detailed src,
    uint srcAmount,
    ERC20Detailed dest,
    address payable destAddress,
    uint maxDestAmount,
    uint /*minConversionRate*/,
    address /*walletId*/,
    bytes calldata /*hint*/
  )
    external
    payable
    returns(uint)
  {
    require(calcDestAmount(src, srcAmount, dest) <= maxDestAmount);

    if (address(src) == address(ETH_TOKEN_ADDRESS)) {
      require(srcAmount == msg.value);
    } else {
      require(src.transferFrom(msg.sender, address(this), srcAmount));
    }

    if (address(dest) == address(ETH_TOKEN_ADDRESS)) {
      destAddress.transfer(calcDestAmount(src, srcAmount, dest));
    } else {
      require(dest.transfer(destAddress, calcDestAmount(src, srcAmount, dest)));
    }
    return calcDestAmount(src, srcAmount, dest);
  }

  function calcDestAmount(
    ERC20Detailed src,
    uint srcAmount,
    ERC20Detailed dest
  ) internal view returns (uint destAmount) {
    return srcAmount.mul(priceInUSDC[address(src)]).mul(10**getDecimals(dest)).div(priceInUSDC[address(dest)].mul(10**getDecimals(src)));
  }

  function() external payable {}
}

pragma solidity 0.5.17;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "../interfaces/PriceOracle.sol";
import "../interfaces/CERC20.sol";

contract TestPriceOracle is PriceOracle, Ownable {
  using SafeMath for uint;

  uint public constant PRECISION = 10 ** 18;
  address public CETH_ADDR;

  mapping(address => uint256) public priceInUSD;

  constructor(address[] memory _tokens, uint256[] memory _pricesInUSD, address _cETH) public {
    for (uint256 i = 0; i < _tokens.length; i = i.add(1)) {
      priceInUSD[_tokens[i]] = _pricesInUSD[i];
    }
    CETH_ADDR = _cETH;
  }

  function setTokenPrice(address _token, uint256 _priceInUSD) public onlyOwner {
    priceInUSD[_token] = _priceInUSD;
  }

  function getUnderlyingPrice(address _cToken) external view returns (uint) {
    if (_cToken == CETH_ADDR) {
      return priceInUSD[_cToken];
    }
    CERC20 cToken = CERC20(_cToken);
    ERC20Detailed underlying = ERC20Detailed(cToken.underlying());
    return priceInUSD[_cToken].mul(PRECISION).div(10 ** uint256(underlying.decimals()));
  }
}
pragma solidity 0.5.17;

import "@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

/**
 * @title An ERC20 token used for testing.
 * @author Zefram Lou (Zebang Liu)
 */
contract TestToken is ERC20Mintable, ERC20Burnable, ERC20Detailed {
  constructor(string memory name, string memory symbol, uint8 decimals)
    public
    ERC20Detailed(name, symbol, decimals)
  {}
}

pragma solidity 0.5.17;

import "./TestToken.sol";

contract TestTokenFactory {
  mapping(bytes32 => address) public createdTokens;

  event CreatedToken(string symbol, address addr);

  function newToken(string memory name, string memory symbol, uint8 decimals) public returns(address) {
    bytes32 symbolHash = keccak256(abi.encodePacked(symbol));
    require(createdTokens[symbolHash] == address(0));
    
    TestToken token = new TestToken(name, symbol, decimals);
    token.addMinter(msg.sender);
    token.renounceMinter();
    createdTokens[symbolHash] = address(token);
    emit CreatedToken(symbol, address(token));
    return address(token);
  }

  function getToken(string memory symbol) public view returns(address) {
    return createdTokens[keccak256(abi.encodePacked(symbol))];
  }
}

pragma solidity 0.5.17;

contract TestUniswapOracle {
    function update() external returns (bool success) {
        return true;
    }

    function consult(address token, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        return 3 * 10**5; // 1 PEAK = 0.30 USDC
    }
}
