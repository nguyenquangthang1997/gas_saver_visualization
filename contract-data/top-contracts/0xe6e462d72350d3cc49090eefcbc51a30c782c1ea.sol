
// SPDX-License-Identifier: GPL-2.0
pragma solidity 0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address);
}

interface IUniswapV2Pair {
    function token0() external pure returns (address);

    function token1() external pure returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        );
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

abstract contract Zap {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 public immutable koromaru; // Koromaru token
    IERC20 public immutable koromaruUniV2; // Uniswap V2 LP token for Koromaru

    IUniswapV2Factory public immutable UniSwapV2FactoryAddress;
    IUniswapV2Router02 public uniswapRouter;
    address public immutable WETHAddress;

    uint256 private constant swapDeadline =
        0xf000000000000000000000000000000000000000000000000000000000000000;

    struct ZapVariables {
        uint256 LP;
        uint256 koroAmount;
        uint256 wethAmount;
        address tokenToZap;
        uint256 amountToZap;
    }

    event ZappedIn(address indexed account, uint256 amount);
    event ZappedOut(
        address indexed account,
        uint256 amount,
        uint256 koroAmount,
        uint256 Eth
    );

    constructor(
        address _koromaru,
        address _koromaruUniV2,
        address _UniSwapV2FactoryAddress,
        address _uniswapRouter
    ) {
        koromaru = IERC20(_koromaru);
        koromaruUniV2 = IERC20(_koromaruUniV2);

        UniSwapV2FactoryAddress = IUniswapV2Factory(_UniSwapV2FactoryAddress);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);

        WETHAddress = uniswapRouter.WETH();
    }

    function ZapIn(uint256 _amount, bool _multi)
        internal
        returns (
            uint256 _LP,
            uint256 _WETHBalance,
            uint256 _KoromaruBalance
        )
    {
        (uint256 _koroAmount, uint256 _ethAmount) = _moveTokensToContract(
            _amount
        );
        _approveRouterIfNotApproved();

        (_LP, _WETHBalance, _KoromaruBalance) = !_multi
            ? _zapIn(_koroAmount, _ethAmount)
            : _zapInMulti(_koroAmount, _ethAmount);
        require(_LP > 0, "ZapIn: Invalid LP amount");

        emit ZappedIn(msg.sender, _LP);
    }

    function zapOut(uint256 _koroLPAmount)
        internal
        returns (uint256 _koroTokens, uint256 _ether)
    {
        _approveRouterIfNotApproved();

        uint256 balanceBefore = koromaru.balanceOf(address(this));
        _ether = uniswapRouter.removeLiquidityETHSupportingFeeOnTransferTokens(
            address(koromaru),
            _koroLPAmount,
            1,
            1,
            address(this),
            swapDeadline
        );
        require(_ether > 0, "ZapOut: Eth Output Low");

        uint256 balanceAfter = koromaru.balanceOf(address(this));
        require(balanceAfter > balanceBefore, "ZapOut: Nothing to ZapOut");
        _koroTokens = balanceAfter.sub(balanceBefore);

        emit ZappedOut(msg.sender, _koroLPAmount, _koroTokens, _ether);
    }

    //-------------------- Zap Utils -------------------------
    function _zapIn(uint256 _koroAmount, uint256 _wethAmount)
        internal
        returns (
            uint256 _LP,
            uint256 _WETHBalance,
            uint256 _KoromaruBalance
        )
    {
        ZapVariables memory zapVars;

        zapVars.tokenToZap; // koro or eth
        zapVars.amountToZap; // koro or weth

        (address _Token0, address _Token1) = _getKoroLPPairs(
            address(koromaruUniV2)
        );

        if (_koroAmount > 0 && _wethAmount < 1) {
            // if only koro
            zapVars.amountToZap = _koroAmount;
            zapVars.tokenToZap = address(koromaru);
        } else if (_wethAmount > 0 && _koroAmount < 1) {
            // if only weth
            zapVars.amountToZap = _wethAmount;
            zapVars.tokenToZap = WETHAddress;
        }

        (uint256 token0Out, uint256 token1Out) = _executeSwapForPairs(
            zapVars.tokenToZap,
            _Token0,
            _Token1,
            zapVars.amountToZap
        );

        (_LP, _WETHBalance, _KoromaruBalance) = _toLiquidity(
            _Token0,
            _Token1,
            token0Out,
            token1Out
        );
    }

    function _zapInMulti(uint256 _koroAmount, uint256 _wethAmount)
        internal
        returns (
            uint256 _LPToken,
            uint256 _WETHBalance,
            uint256 _KoromaruBalance
        )
    {
        ZapVariables memory zapVars;

        zapVars.koroAmount = _koroAmount;
        zapVars.wethAmount = _wethAmount;

        zapVars.tokenToZap; // koro or eth
        zapVars.amountToZap; // koro or weth

        {
            (
                uint256 _kLP,
                uint256 _kWETHBalance,
                uint256 _kKoromaruBalance
            ) = _zapIn(zapVars.koroAmount, 0);
            _LPToken += _kLP;
            _WETHBalance += _kWETHBalance;
            _KoromaruBalance += _kKoromaruBalance;
        }
        {
            (
                uint256 _kLP,
                uint256 _kWETHBalance,
                uint256 _kKoromaruBalance
            ) = _zapIn(0, zapVars.wethAmount);
            _LPToken += _kLP;
            _WETHBalance += _kWETHBalance;
            _KoromaruBalance += _kKoromaruBalance;
        }
    }

    function _toLiquidity(
        address _Token0,
        address _Token1,
        uint256 token0Out,
        uint256 token1Out
    )
        internal
        returns (
            uint256 _LP,
            uint256 _WETHBalance,
            uint256 _KoromaruBalance
        )
    {
        _approveToken(_Token0, address(uniswapRouter), token0Out);
        _approveToken(_Token1, address(uniswapRouter), token1Out);

        (uint256 amountA, uint256 amountB, uint256 LP) = uniswapRouter
            .addLiquidity(
                _Token0,
                _Token1,
                token0Out,
                token1Out,
                1,
                1,
                address(this),
                swapDeadline
            );

        _LP = LP;
        _WETHBalance = token0Out.sub(amountA);
        _KoromaruBalance = token1Out.sub(amountB);
    }

    function _approveRouterIfNotApproved() private {
        if (koromaru.allowance(address(this), address(uniswapRouter)) == 0) {
            koromaru.approve(address(uniswapRouter), type(uint256).max);
        }

        if (
            koromaruUniV2.allowance(address(this), address(uniswapRouter)) == 0
        ) {
            koromaruUniV2.approve(address(uniswapRouter), type(uint256).max);
        }
    }

    function _moveTokensToContract(uint256 _amount)
        internal
        returns (uint256 _koroAmount, uint256 _ethAmount)
    {
        _ethAmount = msg.value;

        if (msg.value > 0) IWETH(WETHAddress).deposit{value: _ethAmount}();

        if (msg.value < 1) {
            // ZapIn must have either both Koro and Eth, just Eth or just Koro
            require(_amount > 0, "KOROFARM: Invalid ZapIn Call");
        }

        if (_amount > 0) {
            koromaru.safeTransferFrom(msg.sender, address(this), _amount);
        }

        _koroAmount = _amount;
    }

    function _getKoroLPPairs(address _pairAddress)
        internal
        pure
        returns (address token0, address token1)
    {
        IUniswapV2Pair uniPair = IUniswapV2Pair(_pairAddress);
        token0 = uniPair.token0();
        token1 = uniPair.token1();
    }

    function _executeSwapForPairs(
        address _inToken,
        address _token0,
        address _token1,
        uint256 _amount
    ) internal returns (uint256 _token0Out, uint256 _token1Out) {
        IUniswapV2Pair koroPair = IUniswapV2Pair(address(koromaruUniV2));

        (uint256 resv0, uint256 resv1, ) = koroPair.getReserves();

        if (_inToken == _token0) {
            uint256 swapAmount = determineSwapInAmount(resv0, _amount);
            if (swapAmount < 1) swapAmount = _amount.div(2);
            // swap Weth tokens to koro
            _token1Out = _swapTokenForToken(_inToken, _token1, swapAmount);
            _token0Out = _amount.sub(swapAmount);
        } else {
            uint256 swapAmount = determineSwapInAmount(resv1, _amount);
            if (swapAmount < 1) swapAmount = _amount.div(2);
            _token0Out = _swapTokenForToken(_inToken, _token0, swapAmount);
            _token1Out = _amount.sub(swapAmount);
        }
    }

    function _swapTokenForToken(
        address _swapFrom,
        address _swapTo,
        uint256 _tokensToSwap
    ) internal returns (uint256 tokenBought) {
        if (_swapFrom == _swapTo) {
            return _tokensToSwap;
        }

        _approveToken(
            _swapFrom,
            address(uniswapRouter),
            _tokensToSwap.mul(1e12)
        );

        address pair = UniSwapV2FactoryAddress.getPair(_swapFrom, _swapTo);

        require(pair != address(0), "SwapTokenForToken: Swap path error");
        address[] memory path = new address[](2);
        path[0] = _swapFrom;
        path[1] = _swapTo;

        uint256 balanceBefore = IERC20(_swapTo).balanceOf(address(this));
        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _tokensToSwap,
            0,
            path,
            address(this),
            swapDeadline
        );
        uint256 balanceAfter = IERC20(_swapTo).balanceOf(address(this));

        tokenBought = balanceAfter.sub(balanceBefore);

        // Ideal, but fails to work with Koromary due to fees
        // tokenBought = uniswapRouter.swapExactTokensForTokens(
        //     _tokensToSwap,
        //     1,
        //     path,
        //     address(this),
        //     swapDeadline
        // )[path.length - 1];
        // }

        require(tokenBought > 0, "SwapTokenForToken: Error Swapping Tokens 2");
    }

    function determineSwapInAmount(uint256 _pairResIn, uint256 _userAmountIn)
        internal
        pure
        returns (uint256)
    {
        return
            (_sqrt(
                _pairResIn *
                    ((_userAmountIn * 3988000) + (_pairResIn * 3988009))
            ) - (_pairResIn * 1997)) / 1994;
    }

    function _sqrt(uint256 _val) internal pure returns (uint256 z) {
        if (_val > 3) {
            z = _val;
            uint256 x = _val / 2 + 1;
            while (x < z) {
                z = x;
                x = (_val / x + x) / 2;
            }
        } else if (_val != 0) {
            z = 1;
        }
    }

    function _approveToken(
        address token,
        address spender,
        uint256 amount
    ) internal {
        IERC20 _token = IERC20(token);
        _token.safeApprove(spender, 0);
        _token.safeApprove(spender, amount);
    }

    //---------------- End of Zap Utils ----------------------
}

contract KoroFarms is Ownable, Pausable, ReentrancyGuard, Zap {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct UserInfo {
        uint256 amount;
        uint256 koroDebt;
        uint256 ethDebt;
        uint256 unpaidKoro;
        uint256 unpaidEth;
        uint256 lastRewardHarvestedTime;
    }

    struct FarmInfo {
        uint256 accKoroRewardsPerShare;
        uint256 accEthRewardsPerShare;
        uint256 lastRewardTimestamp;
    }

    AggregatorV3Interface internal priceFeed;
    uint256 internal immutable koromaruDecimals;
    uint256 internal constant EthPriceFeedDecimal = 1e8;
    uint256 internal constant precisionScaleUp = 1e30;
    uint256 internal constant secsPerDay = 1 days / 1 seconds;
    uint256 private taxRefundPercentage;
    uint256 internal constant _1hundred_Percent = 10000;
    uint256 public APR; // 100% = 10000, 50% = 5000, 15% = 1500
    uint256 rewardHarvestingInterval;
    uint256 public koroRewardAllocation;
    uint256 public ethRewardAllocation;
    uint256 internal maxLPLimit;
    uint256 internal zapKoroLimit;

    FarmInfo public farmInfo;
    mapping(address => UserInfo) public userInfo;

    uint256 public totalEthRewarded; // total amount of eth given as rewards
    uint256 public totalKoroRewarded; // total amount of Koro given as rewards

    //---------------- Contract Events -------------------

    event Compound(address indexed account, uint256 koro, uint256 eth);
    event Withdraw(address indexed account, uint256 amount);
    event Deposit(address indexed account, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event KoroRewardsHarvested(address indexed account, uint256 Kororewards);
    event EthRewardsHarvested(address indexed account, uint256 Ethrewards);
    event APRUpdated(uint256 OldAPR, uint256 NewAPR);
    event Paused();
    event Unpaused();
    event IncreaseKoroRewardPool(uint256 amount);
    event IncreaseEthRewardPool(uint256 amount);

    //------------- End of Contract Events ----------------

    constructor(
        address _koromaru,
        address _koromaruUniV2,
        address _UniSwapV2FactoryAddress,
        address _uniswapRouter,
        uint256 _apr,
        uint256 _taxToRefund,
        uint256 _koromaruTokenDecimals,
        uint256 _koroRewardAllocation,
        uint256 _rewardHarvestingInterval,
        uint256 _zapKoroLimit
    ) Zap(_koromaru, _koromaruUniV2, _UniSwapV2FactoryAddress, _uniswapRouter) {
        require(
            _koroRewardAllocation <= 10000,
            "setRewardAllocations: Invalid rewards allocation"
        );
        require(_apr <= 10000, "SetDailyAPR: Invalid APR Value");

        approveRouterIfNotApproved();

        koromaruDecimals = 10**_koromaruTokenDecimals;
        zapKoroLimit = _zapKoroLimit * 10**_koromaruTokenDecimals;
        APR = _apr;
        koroRewardAllocation = _koroRewardAllocation;
        ethRewardAllocation = _1hundred_Percent.sub(_koroRewardAllocation);
        taxRefundPercentage = _taxToRefund;

        farmInfo = FarmInfo({
            lastRewardTimestamp: block.timestamp,
            accKoroRewardsPerShare: 0,
            accEthRewardsPerShare: 0
        });

        rewardHarvestingInterval = _rewardHarvestingInterval * 1 seconds;
        priceFeed = AggregatorV3Interface(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
    }

    //---------------- Contract Owner  ----------------------
    /**
     * @notice Update chainLink Eth Price feed
     */
    function updatePriceFeed(address _usdt_eth_aggregator) external onlyOwner {
        priceFeed = AggregatorV3Interface(_usdt_eth_aggregator);
    }

    /**
     * @notice Set's tax refund percentage for Koromaru
     * @dev User 100% = 10000, 50% = 5000, 15% = 1500 etc.
     */
    function setTaxRefundPercent(uint256 _taxToRefund) external onlyOwner {
        taxRefundPercentage = _taxToRefund;
    }

    /**
     * @notice Set's max koromaru per transaction
     * @dev Decimals will be added automatically
     */
    function setZapLimit(uint256 _limit) external onlyOwner {
        zapKoroLimit = _limit * koromaruDecimals;
    }

    /**
     * @notice Set's daily ROI percentage for the farm
     * @dev User 100% = 10000, 50% = 5000, 15% = 1500 etc.
     */
    function setDailyAPR(uint256 _dailyAPR) external onlyOwner {
        updateFarm();
        require(_dailyAPR <= 10000, "SetDailyAPR: Invalid APR Value");
        uint256 oldAPr = APR;
        APR = _dailyAPR;
        emit APRUpdated(oldAPr, APR);
    }

    /**
     * @notice Set's reward allocation for reward pool
     * @dev Set for Koromaru only, eth's allocation will be calcuated. User 100% = 10000, 50% = 5000, 15% = 1500 etc.
     */
    function setRewardAllocations(uint256 _koroAllocation) external onlyOwner {
        // setting 10000 (100%) will set eth rewards to 0.
        require(
            _koroAllocation <= 10000,
            "setRewardAllocations: Invalid rewards allocation"
        );
        koroRewardAllocation = _koroAllocation;
        ethRewardAllocation = _1hundred_Percent.sub(_koroAllocation);
    }

    /**
     * @notice Set's maximum amount of LPs that can be staked in this farm
     * @dev When 0, no limit is imposed. When max is reached farmers cannot stake more LPs or compound.
     */
    function setMaxLPLimit(uint256 _maxLPLimit) external onlyOwner {
        // A new user’s stake cannot cause the amount of LP tokens in the farm to exceed this value
        // MaxLP can be set to 0(nomax)
        maxLPLimit = _maxLPLimit;
    }

    /**
     * @notice Reset's the chainLink price feed to the default price feed
     */
    function resetPriceFeed() external onlyOwner {
        priceFeed = AggregatorV3Interface(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
    }

    /**
     * @notice Withdraw foreign tokens sent to this contract
     * @dev Can only withdraw none koromaru tokens and KoroV2 tokens
     */
    function withdrawForeignToken(address _token)
        external
        nonReentrant
        onlyOwner
    {
        require(_token != address(0), "KOROFARM: Invalid Token");
        require(
            _token != address(koromaru),
            "KOROFARM: Token cannot be same as koromaru tokens"
        );
        require(
            _token != address(koromaruUniV2),
            "KOROFARM: Token cannot be same as farmed tokens"
        );

        uint256 amount = IERC20(_token).balanceOf(address(this));
        if (amount > 0) {
            IERC20(_token).safeTransfer(msg.sender, amount);
        }
    }

    /**
     * @notice Deposit Koromaru tokens into reward pool
     */
    function depositKoroRewards(uint256 _amount)
        external
        onlyOwner
        nonReentrant
    {
        require(_amount > 0, "KOROFARM: Invalid Koro Amount");

        koromaru.safeTransferFrom(msg.sender, address(this), _amount);
        emit IncreaseKoroRewardPool(_amount);
    }

    /**
     * @notice Deposit Eth tokens into reward pool
     */
    function depositEthRewards() external payable onlyOwner nonReentrant {
        require(msg.value > 0, "KOROFARM: Invalid Eth Amount");
        emit IncreaseEthRewardPool(msg.value);
    }

    /**
     * @notice This function will pause the farm and withdraw all rewards in case of failure or emergency
     */
    function pauseAndRemoveRewardPools() external onlyOwner whenNotPaused {
        // only to be used by admin in critical situations
        uint256 koroBalance = koromaru.balanceOf(address(this));
        uint256 ethBalance = payable(address(this)).balance;
        if (koroBalance > 0) {
            koromaru.safeTransfer(msg.sender, koroBalance);
        }

        if (ethBalance > 0) {
            (bool sent, ) = payable(msg.sender).call{value: ethBalance}("");
            require(sent, "Failed to send Ether");
        }
    }

    /**
     * @notice Initiate stopped state
     * @dev Only possible when contract not paused.
     */
    function pause() external onlyOwner whenNotPaused {
        _pause();
        emit Paused();
    }

    /**
     * @notice Initiate normal state
     * @dev Only possible when contract is paused.
     */
    function unpause() external onlyOwner whenPaused {
        _unpause();
        emit Unpaused();
    }

    //-------------- End Contract Owner  --------------------

    //---------------- Contract Farmer  ----------------------
    /**
     * @notice Calculates and returns pending rewards for a farmer
     */
    function getPendingRewards(address _farmer)
        public
        view
        returns (uint256 pendinKoroTokens, uint256 pendingEthWei)
    {
        UserInfo storage user = userInfo[_farmer];
        uint256 accKoroRewardsPerShare = farmInfo.accKoroRewardsPerShare;
        uint256 accEthRewardsPerShare = farmInfo.accEthRewardsPerShare;
        uint256 stakedTVL = getStakedTVL();

        if (block.timestamp > farmInfo.lastRewardTimestamp && stakedTVL != 0) {
            uint256 timeElapsed = block.timestamp.sub(
                farmInfo.lastRewardTimestamp
            );
            uint256 koroReward = timeElapsed.mul(
                getNumberOfKoroRewardsPerSecond(koroRewardAllocation)
            );
            uint256 ethReward = timeElapsed.mul(
                getAmountOfEthRewardsPerSecond(ethRewardAllocation)
            );

            accKoroRewardsPerShare = accKoroRewardsPerShare.add(
                koroReward.mul(precisionScaleUp).div(stakedTVL)
            );
            accEthRewardsPerShare = accEthRewardsPerShare.add(
                ethReward.mul(precisionScaleUp).div(stakedTVL)
            );
        }

        pendinKoroTokens = user
            .amount
            .mul(accKoroRewardsPerShare)
            .div(precisionScaleUp)
            .sub(user.koroDebt)
            .add(user.unpaidKoro);

        pendingEthWei = user
            .amount
            .mul(accEthRewardsPerShare)
            .div(precisionScaleUp)
            .sub(user.ethDebt)
            .add(user.unpaidEth);
    }

    /**
     * @notice Calculates and returns the TVL in USD staked in the farm
     * @dev Uses the price of 1 Koromaru to calculate the TVL in USD
     */
    function getStakedTVL() public view returns (uint256) {
        uint256 stakedLP = koromaruUniV2.balanceOf(address(this));
        uint256 totalLPsupply = koromaruUniV2.totalSupply();
        return stakedLP.mul(getTVLUsingKoro()).div(totalLPsupply);
    }

    /**
     * @notice Calculates and updates the farm's rewards per share
     * @dev Called by other function to update the function state
     */
    function updateFarm() public whenNotPaused returns (FarmInfo memory farm) {
        farm = farmInfo;

        uint256 WETHBalance = IERC20(WETHAddress).balanceOf(address(this));
        if (WETHBalance > 0) IWETH(WETHAddress).withdraw(WETHBalance);

        if (block.timestamp > farm.lastRewardTimestamp) {
            uint256 stakedTVL = getStakedTVL();

            if (stakedTVL > 0) {
                uint256 timeElapsed = block.timestamp.sub(
                    farm.lastRewardTimestamp
                );
                uint256 koroReward = timeElapsed.mul(
                    getNumberOfKoroRewardsPerSecond(koroRewardAllocation)
                );
                uint256 ethReward = timeElapsed.mul(
                    getAmountOfEthRewardsPerSecond(ethRewardAllocation)
                );
                farm.accKoroRewardsPerShare = farm.accKoroRewardsPerShare.add(
                    (koroReward.mul(precisionScaleUp) / stakedTVL)
                );
                farm.accEthRewardsPerShare = farm.accEthRewardsPerShare.add(
                    (ethReward.mul(precisionScaleUp) / stakedTVL)
                );
            }

            farm.lastRewardTimestamp = block.timestamp;
            farmInfo = farm;
        }
    }

    /**
     * @notice Deposit Koromaru tokens into farm
     * @dev Deposited Koromaru will zap into Koro/WETH LP tokens, a refund of TX fee % will be issued
     */
    function depositKoroTokensOnly(uint256 _amount)
        external
        whenNotPaused
        nonReentrant
    {
        require(_amount > 0, "KOROFARM: Invalid Koro Amount");
        require(
            _amount <= zapKoroLimit,
            "KOROFARM: Can't deposit more than Zap Limit"
        );

        (uint256 lpZappedIn, , ) = ZapIn(_amount, false);

        // do tax refund
        userInfo[msg.sender].unpaidKoro += _amount.mul(taxRefundPercentage).div(
            _1hundred_Percent
        );

        onDeposit(msg.sender, lpZappedIn);
    }

    /**
     * @notice Deposit Koro/WETH LP tokens into farm
     */
    function depositKoroLPTokensOnly(uint256 _amount)
        external
        whenNotPaused
        nonReentrant
    {
        require(_amount > 0, "KOROFARM: Invalid KoroLP Amount");
        koromaruUniV2.safeTransferFrom(msg.sender, address(this), _amount);
        onDeposit(msg.sender, _amount);
    }

    /**
     * @notice Deposit Koromaru, Koromaru/Eth LP and Eth at once into farm requires all 3
     */
    function depositMultipleAssets(uint256 _koro, uint256 _koroLp)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        // require(_koro > 0, "KOROFARM: Invalid Koro Amount");
        // require(_koroLp > 0, "KOROFARM: Invalid LP Amount");
        require(
            _koro <= zapKoroLimit,
            "KOROFARM: Can't deposit more than Zap Limit"
        );

        // execute the zap
        // (uint256 lpZappedIn,uint256 wethBalance, uint256 korobalance)= ZapIn(_koro, true);
        (uint256 lpZappedIn, , ) = msg.value > 0
            ? ZapIn(_koro, true)
            : ZapIn(_koro, false);

        // transfer the lp in
        if (_koroLp > 0)
            koromaruUniV2.safeTransferFrom(
                address(msg.sender),
                address(this),
                _koroLp
            );

        uint256 sumOfLps = lpZappedIn + _koroLp;

        // do tax refund
        userInfo[msg.sender].unpaidKoro += _koro.mul(taxRefundPercentage).div(
            _1hundred_Percent
        );

        onDeposit(msg.sender, sumOfLps);
    }

    /**
     * @notice Deposit Eth only into farm
     * @dev Deposited Eth will zap into Koro/WETH LP tokens
     */
    function depositEthOnly() external payable whenNotPaused nonReentrant {
        require(msg.value > 0, "KOROFARM: Invalid Eth Amount");

        // (uint256 lpZappedIn, uint256 wethBalance, uint256 korobalance)= ZapIn(0, false);
        (uint256 lpZappedIn, , ) = ZapIn(0, false);

        onDeposit(msg.sender, lpZappedIn);
    }

    /**
     * @notice Withdraw all staked LP tokens + rewards from farm. Only possilbe after harvest interval.
      Use emergency withdraw if you want to withdraw before harvest interval. No rewards will be returned.
     * @dev Farmer's can choose to get back LP tokens or Zap out to get Koromaru and Eth
     */
    function withdraw(bool _useZapOut) external whenNotPaused nonReentrant {
        uint256 balance = userInfo[msg.sender].amount;
        require(balance > 0, "Withdraw: You have no balance");
        updateFarm();

        if (_useZapOut) {
            zapLPOut(balance);
        } else {
            koromaruUniV2.transfer(msg.sender, balance);
        }

        onWithdraw(msg.sender);
        emit Withdraw(msg.sender, balance);
    }

    /**
     * @notice Harvest all rewards from farm
     */
    function harvest() external whenNotPaused nonReentrant {
        updateFarm();
        harvestRewards(msg.sender);
    }

    /**
     * @notice Compounds rewards from farm. Only available after harvest interval is reached for farmer.
     */
    function compound() external whenNotPaused nonReentrant {
        updateFarm();
        UserInfo storage user = userInfo[msg.sender];
        require(
            block.timestamp - user.lastRewardHarvestedTime >=
                rewardHarvestingInterval,
            "HarvestRewards: Not yet ripe"
        );

        uint256 koroCompounded;
        uint256 ethCompounded;

        uint256 pendinKoroTokens = user
            .amount
            .mul(farmInfo.accKoroRewardsPerShare)
            .div(precisionScaleUp)
            .sub(user.koroDebt)
            .add(user.unpaidKoro);

        uint256 pendingEthWei = user
            .amount
            .mul(farmInfo.accEthRewardsPerShare)
            .div(precisionScaleUp)
            .sub(user.ethDebt)
            .add(user.unpaidEth);
        {
            uint256 koromaruBalance = koromaru.balanceOf(address(this));
            if (pendinKoroTokens > 0) {
                if (pendinKoroTokens > koromaruBalance) {
                    // not enough koro balance to reward farmer
                    user.unpaidKoro = pendinKoroTokens.sub(koromaruBalance);
                    totalKoroRewarded = totalKoroRewarded.add(koromaruBalance);
                    koroCompounded = koromaruBalance;
                } else {
                    user.unpaidKoro = 0;
                    totalKoroRewarded = totalKoroRewarded.add(pendinKoroTokens);
                    koroCompounded = pendinKoroTokens;
                }
            }
        }

        {
            uint256 ethBalance = getEthBalance();
            if (pendingEthWei > ethBalance) {
                // not enough Eth balance to reward farmer
                user.unpaidEth = pendingEthWei.sub(ethBalance);
                totalEthRewarded = totalEthRewarded.add(ethBalance);
                IWETH(WETHAddress).deposit{value: ethBalance}();
                ethCompounded = ethBalance;
            } else {
                user.unpaidEth = 0;
                totalEthRewarded = totalEthRewarded.add(pendingEthWei);
                IWETH(WETHAddress).deposit{value: pendingEthWei}();
                ethCompounded = pendingEthWei;
            }
        }
        (uint256 LP, , ) = _zapInMulti(koroCompounded, ethCompounded);

        onCompound(msg.sender, LP);
        emit Compound(msg.sender, koroCompounded, ethCompounded);
    }

    /**
     * @notice Returns time in seconds to next harvest.
     */
    function timeToHarvest(address _user)
        public
        view
        whenNotPaused
        returns (uint256)
    {
        UserInfo storage user = userInfo[_user];
        if (
            block.timestamp - user.lastRewardHarvestedTime >=
            rewardHarvestingInterval
        ) {
            return 0;
        }
        return
            user.lastRewardHarvestedTime.sub(
                block.timestamp.sub(rewardHarvestingInterval)
            );
    }

    /**
     * @notice Withdraw all staked LP tokens without rewards.
     */
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        koromaruUniV2.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, user.amount);

        userInfo[msg.sender] = UserInfo(0, 0, 0, 0, 0, 0);
    }

    //--------------- End Contract Farmer  -------------------

    //---------------- Contract Utils  ----------------------

    /**
     * @notice Calculates the total amount of rewards per day in USD
     * @dev The returned value is in USD * 1e18 (WETH decimals), actual USD value is calculated by dividing the value by 1e18
     */
    function getUSDDailyRewards() public view whenNotPaused returns (uint256) {
        uint256 stakedLP = koromaruUniV2.balanceOf(address(this));
        uint256 totalLPsupply = koromaruUniV2.totalSupply();
        uint256 stakedTVL = stakedLP.mul(getTVLUsingKoro()).div(totalLPsupply);
        return APR.mul(stakedTVL).div(_1hundred_Percent);
    }

    /**
     * @notice Calculates the total amount of rewards per second in USD
     * @dev The returned value is in USD * 1e18 (WETH decimals), actual USD value is calculated by dividing the value by 1e18
     */
    function getUSDRewardsPerSecond() internal view returns (uint256) {
        // final return value should be divided by (1e18) (i.e WETH decimals) to get USD value
        uint256 dailyRewards = getUSDDailyRewards();
        return dailyRewards.div(secsPerDay);
    }

    /**
     * @notice Calculates the total number of koromaru token rewards per second
     * @dev The returned value must be divided by the koromaru token decimals to get the actual value
     */
    function getNumberOfKoroRewardsPerSecond(uint256 _koroRewardAllocation)
        internal
        view
        returns (uint256)
    {
        uint256 priceOfUintKoro = getLatestKoroPrice(); // 1e18
        uint256 rewardsPerSecond = getUSDRewardsPerSecond(); // 1e18

        return
            rewardsPerSecond
                .mul(_koroRewardAllocation)
                .mul(koromaruDecimals)
                .div(priceOfUintKoro)
                .div(_1hundred_Percent); //to be div by koro decimals (i.e 1**(18-18+korodecimals)
    }

    /**
     * @notice Calculates the total amount of Eth rewards per second
     * @dev The returned value must be divided by the 1e18 to get the actual value
     */
    function getAmountOfEthRewardsPerSecond(uint256 _ethRewardAllocation)
        internal
        view
        returns (uint256)
    {
        uint256 priceOfUintEth = getLatestEthPrice(); // 1e8
        uint256 rewardsPerSecond = getUSDRewardsPerSecond(); // 1e18
        uint256 scaleUpToWei = 1e8;

        return
            rewardsPerSecond
                .mul(_ethRewardAllocation)
                .mul(scaleUpToWei)
                .div(priceOfUintEth)
                .div(_1hundred_Percent); // to be div by 1e18 (i.e 1**(18-8+8)
    }

    /**
     * @notice Returns the rewards rate/second for both koromaru and eth
     */
    function getRewardsPerSecond()
        public
        view
        whenNotPaused
        returns (uint256 koroRewards, uint256 ethRewards)
    {
        require(
            koroRewardAllocation.add(ethRewardAllocation) == _1hundred_Percent,
            "getRewardsPerSecond: Invalid reward allocation ratio"
        );

        koroRewards = getNumberOfKoroRewardsPerSecond(koroRewardAllocation);
        ethRewards = getAmountOfEthRewardsPerSecond(ethRewardAllocation);
    }

    /**
     * @notice Calculates and returns the TVL in USD (actaul TVL, not staked TVL)
     * @dev Uses Eth price from price feed to calculate the TVL in USD
     */
    function getTVL() public view returns (uint256 tvl) {
        // final return value should be divided by (1e18) (i.e WETH decimals) to get USD value
        IUniswapV2Pair koroPair = IUniswapV2Pair(address(koromaruUniV2));
        address token0 = koroPair.token0();
        (uint256 resv0, uint256 resv1, ) = koroPair.getReserves();
        uint256 TVLEth = 2 *
            (address(token0) == address(koromaru) ? resv1 : resv0);
        uint256 priceOfEth = getLatestEthPrice();

        tvl = TVLEth.mul(priceOfEth).div(EthPriceFeedDecimal);
    }

    /**
     * @notice Calculates and returns the TVL in USD (actaul TVL, not staked TVL)
     * @dev Uses minimum Eth price in USD for 1 koromaru token to calculate the TVL in USD
     */
    function getTVLUsingKoro() public view whenNotPaused returns (uint256 tvl) {
        // returned value should be divided by (1e18) (i.e WETH decimals) to get USD value
        IUniswapV2Pair koroPair = IUniswapV2Pair(address(koromaruUniV2));
        address token0 = koroPair.token0();
        (uint256 resv0, uint256 resv1, ) = koroPair.getReserves();
        uint256 TVLKoro = 2 *
            (address(token0) == address(koromaru) ? resv0 : resv1);
        uint256 priceOfKoro = getLatestKoroPrice();

        tvl = TVLKoro.mul(priceOfKoro).div(koromaruDecimals);
    }

    /**
     * @notice Get's the latest Eth price in USD
     * @dev Uses ChainLink price feed to get the latest Eth price in USD
     */
    function getLatestEthPrice() internal view returns (uint256) {
        // final return value should be divided by 1e8 to get USD value
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    /**
     * @notice Get's the latest Unit Koro price in USD
     * @dev Uses estimated price per koromaru token in USD
     */
    function getLatestKoroPrice() internal view returns (uint256) {
        // returned value must be divided by 1e18 (i.e WETH decimals) to get USD value
        IUniswapV2Pair koroPair = IUniswapV2Pair(address(koromaruUniV2));
        address token0 = koroPair.token0();
        bool isKoro = address(token0) == address(koromaru);

        (uint256 resv0, uint256 resv1, ) = koroPair.getReserves();
        uint256 oneKoro = 1 * koromaruDecimals;

        uint256 optimalWethAmount = uniswapRouter.getAmountOut(
            oneKoro,
            isKoro ? resv0 : resv1,
            isKoro ? resv1 : resv0
        ); //uniswapRouter.quote(oneKoro, isKoro ? resv1 : resv0, isKoro ? resv0 : resv1);
        uint256 priceOfEth = getLatestEthPrice();

        return optimalWethAmount.mul(priceOfEth).div(EthPriceFeedDecimal);
    }

    function onDeposit(address _user, uint256 _amount) internal {
        require(!reachedMaxLimit(), "KOROFARM: Farm is full");
        UserInfo storage user = userInfo[_user];
        updateFarm();

        if (user.amount > 0) {
            // record as unpaid
            user.unpaidKoro = user
                .amount
                .mul(farmInfo.accKoroRewardsPerShare)
                .div(precisionScaleUp)
                .sub(user.koroDebt)
                .add(user.unpaidKoro);

            user.unpaidEth = user
                .amount
                .mul(farmInfo.accEthRewardsPerShare)
                .div(precisionScaleUp)
                .sub(user.ethDebt)
                .add(user.unpaidEth);
        }

        user.amount = user.amount.add(_amount);
        user.koroDebt = user.amount.mul(farmInfo.accKoroRewardsPerShare).div(
            precisionScaleUp
        );
        user.ethDebt = user.amount.mul(farmInfo.accEthRewardsPerShare).div(
            precisionScaleUp
        );

        if (
            (block.timestamp - user.lastRewardHarvestedTime >=
                rewardHarvestingInterval) || (rewardHarvestingInterval == 0)
        ) {
            user.lastRewardHarvestedTime = block.timestamp;
        }

        emit Deposit(_user, _amount);
    }

    function onWithdraw(address _user) internal {
        harvestRewards(_user);
        userInfo[msg.sender].amount = 0;

        userInfo[msg.sender].koroDebt = 0;
        userInfo[msg.sender].ethDebt = 0;
    }

    function onCompound(address _user, uint256 _amount) internal {
        require(!reachedMaxLimit(), "KOROFARM: Farm is full");
        UserInfo storage user = userInfo[_user];

        user.amount = user.amount.add(_amount);
        user.koroDebt = user.amount.mul(farmInfo.accKoroRewardsPerShare).div(
            precisionScaleUp
        );
        user.ethDebt = user.amount.mul(farmInfo.accEthRewardsPerShare).div(
            precisionScaleUp
        );

        user.lastRewardHarvestedTime = block.timestamp;
    }

    function harvestRewards(address _user) internal {
        UserInfo storage user = userInfo[_user];
        require(
            block.timestamp - user.lastRewardHarvestedTime >=
                rewardHarvestingInterval,
            "HarvestRewards: Not yet ripe"
        );

        uint256 pendinKoroTokens = user
            .amount
            .mul(farmInfo.accKoroRewardsPerShare)
            .div(precisionScaleUp)
            .sub(user.koroDebt)
            .add(user.unpaidKoro);

        uint256 pendingEthWei = user
            .amount
            .mul(farmInfo.accEthRewardsPerShare)
            .div(precisionScaleUp)
            .sub(user.ethDebt)
            .add(user.unpaidEth);

        {
            uint256 koromaruBalance = koromaru.balanceOf(address(this));
            if (pendinKoroTokens > 0) {
                if (pendinKoroTokens > koromaruBalance) {
                    // not enough koro balance to reward farmer
                    koromaru.safeTransfer(_user, koromaruBalance);
                    user.unpaidKoro = pendinKoroTokens.sub(koromaruBalance);
                    totalKoroRewarded = totalKoroRewarded.add(koromaruBalance);
                    emit KoroRewardsHarvested(_user, koromaruBalance);
                } else {
                    koromaru.safeTransfer(_user, pendinKoroTokens);
                    user.unpaidKoro = 0;
                    totalKoroRewarded = totalKoroRewarded.add(pendinKoroTokens);
                    emit KoroRewardsHarvested(_user, pendinKoroTokens);
                }
            }
        }
        {
            uint256 ethBalance = getEthBalance();
            if (pendingEthWei > ethBalance) {
                // not enough Eth balance to reward farmer
                (bool sent, ) = _user.call{value: ethBalance}("");
                require(sent, "Failed to send Ether");
                user.unpaidEth = pendingEthWei.sub(ethBalance);
                totalEthRewarded = totalEthRewarded.add(ethBalance);
                emit EthRewardsHarvested(_user, ethBalance);
            } else {
                (bool sent, ) = _user.call{value: pendingEthWei}("");
                require(sent, "Failed to send Ether");
                user.unpaidEth = 0;
                totalEthRewarded = totalEthRewarded.add(pendingEthWei);
                emit EthRewardsHarvested(_user, pendingEthWei);
            }
        }
        user.koroDebt = user.amount.mul(farmInfo.accKoroRewardsPerShare).div(
            precisionScaleUp
        );
        user.ethDebt = user.amount.mul(farmInfo.accEthRewardsPerShare).div(
            precisionScaleUp
        );
        user.lastRewardHarvestedTime = block.timestamp;
    }

    /**
     * @notice Convert's Koro LP tokens back to Koro and Eth
     */
    function zapLPOut(uint256 _amount)
        private
        returns (uint256 _koroTokens, uint256 _ether)
    {
        (_koroTokens, _ether) = zapOut(_amount);
        (bool sent, ) = msg.sender.call{value: _ether}("");
        require(sent, "Failed to send Ether");
        koromaru.safeTransfer(msg.sender, _koroTokens);
    }

    function getEthBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getUserInfo(address _user)
        public
        view
        returns (
            uint256 amount,
            uint256 stakedInUsd,
            uint256 timeToHarves,
            uint256 pendingKoro,
            uint256 pendingEth
        )
    {
        amount = userInfo[_user].amount;
        timeToHarves = timeToHarvest(_user);
        (pendingKoro, pendingEth) = getPendingRewards(_user);

        uint256 stakedLP = koromaruUniV2.balanceOf(address(this));
        stakedInUsd = stakedLP > 0
            ? userInfo[_user].amount.mul(getStakedTVL()).div(stakedLP)
            : 0;
    }

    function getFarmInfo()
        public
        view
        returns (
            uint256 tvl,
            uint256 totalStaked,
            uint256 circSupply,
            uint256 dailyROI,
            uint256 ethDistribution,
            uint256 koroDistribution
        )
    {
        tvl = getStakedTVL();
        totalStaked = koromaruUniV2.balanceOf(address(this));
        circSupply = getCirculatingSupplyLocked();
        dailyROI = APR;
        ethDistribution = ethRewardAllocation;
        koroDistribution = koroRewardAllocation;
    }

    function getCirculatingSupplyLocked() public view returns (uint256) {
        address deadWallet = address(
            0x000000000000000000000000000000000000dEaD
        );
        IUniswapV2Pair koroPair = IUniswapV2Pair(address(koromaruUniV2));
        address token0 = koroPair.token0();
        (uint256 resv0, uint256 resv1, ) = koroPair.getReserves();
        uint256 koroResv = address(token0) == address(koromaru) ? resv0 : resv1;
        uint256 lpSupply = koromaruUniV2.totalSupply();
        uint256 koroCirculatingSupply = koromaru.totalSupply().sub(
            koromaru.balanceOf(deadWallet)
        );
        uint256 stakedLp = koromaruUniV2.balanceOf(address(this));

        return
            (stakedLp.mul(koroResv).mul(1e18).div(lpSupply)).div(
                koroCirculatingSupply
            ); // divide by 1e18
    }

    function approveRouterIfNotApproved() private {
        if (koromaru.allowance(address(this), address(uniswapRouter)) == 0) {
            koromaru.safeApprove(address(uniswapRouter), type(uint256).max);
        }

        if (
            koromaruUniV2.allowance(address(this), address(uniswapRouter)) == 0
        ) {
            koromaruUniV2.approve(address(uniswapRouter), type(uint256).max);
        }
    }

    function reachedMaxLimit() public view returns (bool) {
        uint256 lockedLP = koromaruUniV2.balanceOf(address(this));
        if (maxLPLimit < 1) return false; // unlimited

        if (lockedLP >= maxLPLimit) return true;

        return false;
    }

    //--------------- End Contract Utils  -------------------

    receive() external payable {
        emit IncreaseEthRewardPool(msg.value);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/structs/EnumerableSet.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastvalue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                set._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC20/IERC20.sol)

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
// OpenZeppelin Contracts v4.4.0 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (access/Ownable.sol)

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
        _transferOwnership(_msgSender());
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
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Address.sol)

pragma solidity ^0.8.0;

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
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
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
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Context.sol)

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
