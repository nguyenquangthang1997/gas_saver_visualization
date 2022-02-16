{"CErc20Delegator.sol":{"content":"pragma solidity ^0.5.16;\r\n\r\nimport \"./CTokenInterfaces.sol\";\r\n\r\n/**\r\n * @title Compound\u0027s CErc20Delegator Contract\r\n * @notice CTokens which wrap an EIP-20 underlying and delegate to an implementation\r\n * @author Compound\r\n */\r\ncontract CErc20Delegator is CDelegatorInterface, CTokenAdminStorage {\r\n    /**\r\n     * @notice Construct a new money market\r\n     * @param underlying_ The address of the underlying asset\r\n     * @param comptroller_ The address of the Comptroller\r\n     * @param interestRateModel_ The address of the interest rate model\r\n     * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18\r\n     * @param name_ ERC-20 name of this token\r\n     * @param symbol_ ERC-20 symbol of this token\r\n     * @param decimals_ ERC-20 decimal precision of this token\r\n     * @param admin_ Address of the administrator of this token\r\n     * @param implementation_ The address of the implementation the contract delegates to\r\n     * @param becomeImplementationData The encoded args for becomeImplementation\r\n     */\r\n    constructor(address underlying_,\r\n                ComptrollerInterface comptroller_,\r\n                InterestRateModel interestRateModel_,\r\n                uint initialExchangeRateMantissa_,\r\n                string memory name_,\r\n                string memory symbol_,\r\n                uint8 decimals_,\r\n                address payable admin_,\r\n                address implementation_,\r\n                bytes memory becomeImplementationData,\r\n                uint256 reserveFactorMantissa_,\r\n                uint256 adminFeeMantissa_) public {\r\n        // Creator of the contract is admin during initialization\r\n        admin = msg.sender;\r\n\r\n        // First delegate gets to initialize the delegator (i.e. storage contract)\r\n        delegateTo(implementation_, abi.encodeWithSignature(\"initialize(address,address,address,uint256,string,string,uint8,uint256,uint256)\",\r\n                                                            underlying_,\r\n                                                            comptroller_,\r\n                                                            interestRateModel_,\r\n                                                            initialExchangeRateMantissa_,\r\n                                                            name_,\r\n                                                            symbol_,\r\n                                                            decimals_,\r\n                                                            reserveFactorMantissa_,\r\n                                                            adminFeeMantissa_));\r\n\r\n        // New implementations always get set via the settor (post-initialize)\r\n        _setImplementation(implementation_, false, becomeImplementationData);\r\n\r\n        // Set the proper admin now that initialization is done\r\n        admin = admin_;\r\n    }\r\n\r\n    /**\r\n     * @notice Called by the admin to update the implementation of the delegator\r\n     * @param implementation_ The address of the new implementation for delegation\r\n     * @param allowResign Flag to indicate whether to call _resignImplementation on the old implementation\r\n     * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation\r\n     */\r\n    function _setImplementation(address implementation_, bool allowResign, bytes memory becomeImplementationData) public {\r\n        require(hasAdminRights(), \"CErc20Delegator::_setImplementation: Caller must be admin\");\r\n\r\n        if (allowResign) {\r\n            delegateToImplementation(abi.encodeWithSignature(\"_resignImplementation()\"));\r\n        }\r\n\r\n        address oldImplementation = implementation;\r\n        implementation = implementation_;\r\n\r\n        delegateToImplementation(abi.encodeWithSignature(\"_becomeImplementation(bytes)\", becomeImplementationData));\r\n\r\n        emit NewImplementation(oldImplementation, implementation);\r\n    }\r\n\r\n    /**\r\n     * @notice Internal method to delegate execution to another contract\r\n     * @dev It returns to the external caller whatever the implementation returns or forwards reverts\r\n     * @param callee The contract to delegatecall\r\n     * @param data The raw data to delegatecall\r\n     * @return The returned bytes from the delegatecall\r\n     */\r\n    function delegateTo(address callee, bytes memory data) internal returns (bytes memory) {\r\n        (bool success, bytes memory returnData) = callee.delegatecall(data);\r\n        assembly {\r\n            if eq(success, 0) {\r\n                revert(add(returnData, 0x20), returndatasize)\r\n            }\r\n        }\r\n        return returnData;\r\n    }\r\n\r\n    /**\r\n     * @notice Delegates execution to the implementation contract\r\n     * @dev It returns to the external caller whatever the implementation returns or forwards reverts\r\n     * @param data The raw data to delegatecall\r\n     * @return The returned bytes from the delegatecall\r\n     */\r\n    function delegateToImplementation(bytes memory data) public returns (bytes memory) {\r\n        return delegateTo(implementation, data);\r\n    }\r\n\r\n    /**\r\n     * @notice Delegates execution to an implementation contract\r\n     * @dev It returns to the external caller whatever the implementation returns or forwards reverts\r\n     */\r\n    function () external payable {\r\n        require(msg.value == 0,\"CErc20Delegator:fallback: cannot send value to fallback\");\r\n\r\n        // delegate all other functions to current implementation\r\n        (bool success, ) = implementation.delegatecall(msg.data);\r\n\r\n        assembly {\r\n            let free_mem_ptr := mload(0x40)\r\n            returndatacopy(free_mem_ptr, 0, returndatasize)\r\n\r\n            switch success\r\n            case 0 { revert(free_mem_ptr, returndatasize) }\r\n            default { return(free_mem_ptr, returndatasize) }\r\n        }\r\n    }\r\n}\r\n"},"ComptrollerInterface.sol":{"content":"pragma solidity ^0.5.16;\r\n\r\ncontract ComptrollerInterface {\r\n    /// @notice Indicator that this is a Comptroller contract (for inspection)\r\n    bool public constant isComptroller = true;\r\n\r\n    /*** Assets You Are In ***/\r\n\r\n    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);\r\n    function exitMarket(address cToken) external returns (uint);\r\n\r\n    /*** Policy Hooks ***/\r\n\r\n    function mintAllowed(address cToken, address minter, uint mintAmount) external returns (uint);\r\n    function mintWithinLimits(address cToken, uint exchangeRateMantissa, uint accountTokens, uint mintAmount) external returns (uint);\r\n    function mintVerify(address cToken, address minter, uint mintAmount, uint mintTokens) external;\r\n\r\n    function redeemAllowed(address cToken, address redeemer, uint redeemTokens) external returns (uint);\r\n    function redeemVerify(address cToken, address redeemer, uint redeemAmount, uint redeemTokens) external;\r\n\r\n    function borrowAllowed(address cToken, address borrower, uint borrowAmount) external returns (uint);\r\n    function borrowWithinLimits(address cToken, uint accountBorrowsNew) external returns (uint);\r\n    function borrowVerify(address cToken, address borrower, uint borrowAmount) external;\r\n\r\n    function repayBorrowAllowed(\r\n        address cToken,\r\n        address payer,\r\n        address borrower,\r\n        uint repayAmount) external returns (uint);\r\n    function repayBorrowVerify(\r\n        address cToken,\r\n        address payer,\r\n        address borrower,\r\n        uint repayAmount,\r\n        uint borrowerIndex) external;\r\n\r\n    function liquidateBorrowAllowed(\r\n        address cTokenBorrowed,\r\n        address cTokenCollateral,\r\n        address liquidator,\r\n        address borrower,\r\n        uint repayAmount) external returns (uint);\r\n    function liquidateBorrowVerify(\r\n        address cTokenBorrowed,\r\n        address cTokenCollateral,\r\n        address liquidator,\r\n        address borrower,\r\n        uint repayAmount,\r\n        uint seizeTokens) external;\r\n\r\n    function seizeAllowed(\r\n        address cTokenCollateral,\r\n        address cTokenBorrowed,\r\n        address liquidator,\r\n        address borrower,\r\n        uint seizeTokens) external returns (uint);\r\n    function seizeVerify(\r\n        address cTokenCollateral,\r\n        address cTokenBorrowed,\r\n        address liquidator,\r\n        address borrower,\r\n        uint seizeTokens) external;\r\n\r\n    function transferAllowed(address cToken, address src, address dst, uint transferTokens) external returns (uint);\r\n    function transferVerify(address cToken, address src, address dst, uint transferTokens) external;\r\n\r\n    /*** Liquidity/Liquidation Calculations ***/\r\n\r\n    function liquidateCalculateSeizeTokens(\r\n        address cTokenBorrowed,\r\n        address cTokenCollateral,\r\n        uint repayAmount) external view returns (uint, uint);\r\n}\r\n"},"CTokenInterfaces.sol":{"content":"pragma solidity ^0.5.16;\r\n\r\nimport \"./IFuseFeeDistributor.sol\";\r\nimport \"./ComptrollerInterface.sol\";\r\nimport \"./InterestRateModel.sol\";\r\n\r\ncontract CTokenAdminStorage {\r\n    /**\r\n     * @notice Administrator for Fuse\r\n     */\r\n    IFuseFeeDistributor internal constant fuseAdmin = IFuseFeeDistributor(0xa731585ab05fC9f83555cf9Bff8F58ee94e18F85);\r\n\r\n    /**\r\n     * @notice Administrator for this contract\r\n     */\r\n    address payable public admin;\r\n\r\n    /**\r\n     * @notice Whether or not the Fuse admin has admin rights\r\n     */\r\n    bool public fuseAdminHasRights = true;\r\n\r\n    /**\r\n     * @notice Whether or not the admin has admin rights\r\n     */\r\n    bool public adminHasRights = true;\r\n\r\n    /**\r\n     * @notice Returns a boolean indicating if the sender has admin rights\r\n     */\r\n    function hasAdminRights() internal view returns (bool) {\r\n        return (msg.sender == admin \u0026\u0026 adminHasRights) || (msg.sender == address(fuseAdmin) \u0026\u0026 fuseAdminHasRights);\r\n    }\r\n}\r\n\r\ncontract CTokenStorage is CTokenAdminStorage {\r\n    /**\r\n     * @dev Guard variable for re-entrancy checks\r\n     */\r\n    bool internal _notEntered;\r\n\r\n    /**\r\n     * @notice EIP-20 token name for this token\r\n     */\r\n    string public name;\r\n\r\n    /**\r\n     * @notice EIP-20 token symbol for this token\r\n     */\r\n    string public symbol;\r\n\r\n    /**\r\n     * @notice EIP-20 token decimals for this token\r\n     */\r\n    uint8 public decimals;\r\n\r\n    /**\r\n     * @notice Maximum borrow rate that can ever be applied (.0005% / block)\r\n     */\r\n    uint internal constant borrowRateMaxMantissa = 0.0005e16;\r\n\r\n    /**\r\n     * @notice Maximum fraction of interest that can be set aside for reserves + fees\r\n     */\r\n    uint internal constant reserveFactorPlusFeesMaxMantissa = 1e18;\r\n\r\n    /**\r\n     * @notice Pending administrator for this contract\r\n     */\r\n    address payable public pendingAdmin;\r\n\r\n    /**\r\n     * @notice Contract which oversees inter-cToken operations\r\n     */\r\n    ComptrollerInterface public comptroller;\r\n\r\n    /**\r\n     * @notice Model which tells what the current interest rate should be\r\n     */\r\n    InterestRateModel public interestRateModel;\r\n\r\n    /**\r\n     * @notice Initial exchange rate used when minting the first CTokens (used when totalSupply = 0)\r\n     */\r\n    uint internal initialExchangeRateMantissa;\r\n\r\n    /**\r\n     * @notice Fraction of interest currently set aside for admin fees\r\n     */\r\n    uint public adminFeeMantissa;\r\n\r\n    /**\r\n     * @notice Fraction of interest currently set aside for Fuse fees\r\n     */\r\n    uint public fuseFeeMantissa;\r\n\r\n    /**\r\n     * @notice Fraction of interest currently set aside for reserves\r\n     */\r\n    uint public reserveFactorMantissa;\r\n\r\n    /**\r\n     * @notice Block number that interest was last accrued at\r\n     */\r\n    uint public accrualBlockNumber;\r\n\r\n    /**\r\n     * @notice Accumulator of the total earned interest rate since the opening of the market\r\n     */\r\n    uint public borrowIndex;\r\n\r\n    /**\r\n     * @notice Total amount of outstanding borrows of the underlying in this market\r\n     */\r\n    uint public totalBorrows;\r\n\r\n    /**\r\n     * @notice Total amount of reserves of the underlying held in this market\r\n     */\r\n    uint public totalReserves;\r\n\r\n    /**\r\n     * @notice Total amount of admin fees of the underlying held in this market\r\n     */\r\n    uint public totalAdminFees;\r\n\r\n    /**\r\n     * @notice Total amount of Fuse fees of the underlying held in this market\r\n     */\r\n    uint public totalFuseFees;\r\n\r\n    /**\r\n     * @notice Total number of tokens in circulation\r\n     */\r\n    uint public totalSupply;\r\n\r\n    /**\r\n     * @notice Official record of token balances for each account\r\n     */\r\n    mapping (address =\u003e uint) internal accountTokens;\r\n\r\n    /**\r\n     * @notice Approved token transfer amounts on behalf of others\r\n     */\r\n    mapping (address =\u003e mapping (address =\u003e uint)) internal transferAllowances;\r\n\r\n    /**\r\n     * @notice Container for borrow balance information\r\n     * @member principal Total balance (with accrued interest), after applying the most recent balance-changing action\r\n     * @member interestIndex Global borrowIndex as of the most recent balance-changing action\r\n     */\r\n    struct BorrowSnapshot {\r\n        uint principal;\r\n        uint interestIndex;\r\n    }\r\n\r\n    /**\r\n     * @notice Mapping of account addresses to outstanding borrow balances\r\n     */\r\n    mapping(address =\u003e BorrowSnapshot) internal accountBorrows;\r\n}\r\n\r\ncontract CTokenInterface is CTokenStorage {\r\n    /**\r\n     * @notice Indicator that this is a CToken contract (for inspection)\r\n     */\r\n    bool public constant isCToken = true;\r\n\r\n    /**\r\n     * @notice Indicator that this is or is not a CEther contract (for inspection)\r\n     */\r\n    bool public constant isCEther = false;\r\n\r\n\r\n    /*** Market Events ***/\r\n\r\n    /**\r\n     * @notice Event emitted when interest is accrued\r\n     */\r\n    event AccrueInterest(uint cashPrior, uint interestAccumulated, uint borrowIndex, uint totalBorrows);\r\n\r\n    /**\r\n     * @notice Event emitted when tokens are minted\r\n     */\r\n    event Mint(address minter, uint mintAmount, uint mintTokens);\r\n\r\n    /**\r\n     * @notice Event emitted when tokens are redeemed\r\n     */\r\n    event Redeem(address redeemer, uint redeemAmount, uint redeemTokens);\r\n\r\n    /**\r\n     * @notice Event emitted when underlying is borrowed\r\n     */\r\n    event Borrow(address borrower, uint borrowAmount, uint accountBorrows, uint totalBorrows);\r\n\r\n    /**\r\n     * @notice Event emitted when a borrow is repaid\r\n     */\r\n    event RepayBorrow(address payer, address borrower, uint repayAmount, uint accountBorrows, uint totalBorrows);\r\n\r\n    /**\r\n     * @notice Event emitted when a borrow is liquidated\r\n     */\r\n    event LiquidateBorrow(address liquidator, address borrower, uint repayAmount, address cTokenCollateral, uint seizeTokens);\r\n\r\n\r\n    /*** Admin Events ***/\r\n\r\n    /**\r\n     * @notice Event emitted when the Fuse admin renounces their rights\r\n     */\r\n    event FuseAdminRightsRenounced();\r\n\r\n    /**\r\n     * @notice Event emitted when the admin renounces their rights\r\n     */\r\n    event AdminRightsRenounced();\r\n\r\n    /**\r\n     * @notice Event emitted when pendingAdmin is changed\r\n     */\r\n    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);\r\n\r\n    /**\r\n     * @notice Event emitted when pendingAdmin is accepted, which means admin is updated\r\n     */\r\n    event NewAdmin(address oldAdmin, address newAdmin);\r\n\r\n    /**\r\n     * @notice Event emitted when comptroller is changed\r\n     */\r\n    event NewComptroller(ComptrollerInterface oldComptroller, ComptrollerInterface newComptroller);\r\n\r\n    /**\r\n     * @notice Event emitted when interestRateModel is changed\r\n     */\r\n    event NewMarketInterestRateModel(InterestRateModel oldInterestRateModel, InterestRateModel newInterestRateModel);\r\n\r\n    /**\r\n     * @notice Event emitted when the reserve factor is changed\r\n     */\r\n    event NewReserveFactor(uint oldReserveFactorMantissa, uint newReserveFactorMantissa);\r\n\r\n    /**\r\n     * @notice Event emitted when the reserves are added\r\n     */\r\n    event ReservesAdded(address benefactor, uint addAmount, uint newTotalReserves);\r\n\r\n    /**\r\n     * @notice Event emitted when the reserves are reduced\r\n     */\r\n    event ReservesReduced(address admin, uint reduceAmount, uint newTotalReserves);\r\n\r\n    /**\r\n     * @notice Event emitted when the admin fee is changed\r\n     */\r\n    event NewAdminFee(uint oldAdminFeeMantissa, uint newAdminFeeMantissa);\r\n\r\n    /**\r\n     * @notice Event emitted when the Fuse fee is changed\r\n     */\r\n    event NewFuseFee(uint oldFuseFeeMantissa, uint newFuseFeeMantissa);\r\n\r\n    /**\r\n     * @notice EIP20 Transfer event\r\n     */\r\n    event Transfer(address indexed from, address indexed to, uint amount);\r\n\r\n    /**\r\n     * @notice EIP20 Approval event\r\n     */\r\n    event Approval(address indexed owner, address indexed spender, uint amount);\r\n\r\n    /**\r\n     * @notice Failure event\r\n     */\r\n    event Failure(uint error, uint info, uint detail);\r\n\r\n\r\n    /*** User Interface ***/\r\n\r\n    function transfer(address dst, uint amount) external returns (bool);\r\n    function transferFrom(address src, address dst, uint amount) external returns (bool);\r\n    function approve(address spender, uint amount) external returns (bool);\r\n    function allowance(address owner, address spender) external view returns (uint);\r\n    function balanceOf(address owner) external view returns (uint);\r\n    function balanceOfUnderlying(address owner) external returns (uint);\r\n    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);\r\n    function borrowRatePerBlock() external view returns (uint);\r\n    function supplyRatePerBlock() external view returns (uint);\r\n    function totalBorrowsCurrent() external returns (uint);\r\n    function borrowBalanceCurrent(address account) external returns (uint);\r\n    function borrowBalanceStored(address account) public view returns (uint);\r\n    function exchangeRateCurrent() public returns (uint);\r\n    function exchangeRateStored() public view returns (uint);\r\n    function getCash() external view returns (uint);\r\n    function accrueInterest() public returns (uint);\r\n    function seize(address liquidator, address borrower, uint seizeTokens) external returns (uint);\r\n\r\n\r\n    /*** Admin Functions ***/\r\n\r\n    function _setPendingAdmin(address payable newPendingAdmin) external returns (uint);\r\n    function _acceptAdmin() external returns (uint);\r\n    function _setComptroller(ComptrollerInterface newComptroller) public returns (uint);\r\n    function _setReserveFactor(uint newReserveFactorMantissa) external returns (uint);\r\n    function _reduceReserves(uint reduceAmount) external returns (uint);\r\n    function _setInterestRateModel(InterestRateModel newInterestRateModel) public returns (uint);\r\n}\r\n\r\ncontract CErc20Storage {\r\n    /**\r\n     * @notice Underlying asset for this CToken\r\n     */\r\n    address public underlying;\r\n}\r\n\r\ncontract CErc20Interface is CErc20Storage {\r\n\r\n    /*** User Interface ***/\r\n\r\n    function mint(uint mintAmount) external returns (uint);\r\n    function redeem(uint redeemTokens) external returns (uint);\r\n    function redeemUnderlying(uint redeemAmount) external returns (uint);\r\n    function borrow(uint borrowAmount) external returns (uint);\r\n    function repayBorrow(uint repayAmount) external returns (uint);\r\n    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint);\r\n    function liquidateBorrow(address borrower, uint repayAmount, CTokenInterface cTokenCollateral) external returns (uint);\r\n\r\n\r\n    /*** Admin Functions ***/\r\n\r\n    function _addReserves(uint addAmount) external returns (uint);\r\n}\r\n\r\ncontract CEtherInterface is CErc20Storage {\r\n    /**\r\n     * @notice Indicator that this is a CEther contract (for inspection)\r\n     */\r\n    bool public constant isCEther = true;\r\n}\r\n\r\ncontract CDelegationStorage {\r\n    /**\r\n     * @notice Implementation address for this contract\r\n     */\r\n    address public implementation;\r\n}\r\n\r\ncontract CDelegatorInterface is CDelegationStorage {\r\n    /**\r\n     * @notice Emitted when implementation is changed\r\n     */\r\n    event NewImplementation(address oldImplementation, address newImplementation);\r\n\r\n    /**\r\n     * @notice Called by the admin to update the implementation of the delegator\r\n     * @param implementation_ The address of the new implementation for delegation\r\n     * @param allowResign Flag to indicate whether to call _resignImplementation on the old implementation\r\n     * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation\r\n     */\r\n    function _setImplementation(address implementation_, bool allowResign, bytes memory becomeImplementationData) public;\r\n}\r\n\r\ncontract CDelegateInterface is CDelegationStorage {\r\n    /**\r\n     * @notice Called by the delegator on a delegate to initialize it for duty\r\n     * @dev Should revert if any issues arise which make it unfit for delegation\r\n     * @param data The encoded bytes data for any initialization\r\n     */\r\n    function _becomeImplementation(bytes memory data) public;\r\n\r\n    /**\r\n     * @notice Called by the delegator on a delegate to forfeit its responsibility\r\n     */\r\n    function _resignImplementation() public;\r\n}\r\n"},"IFuseFeeDistributor.sol":{"content":"pragma solidity ^0.5.16;\r\n\r\ninterface IFuseFeeDistributor {\r\n    function minBorrowEth() external view returns (uint256);\r\n    function maxSupplyEth() external view returns (uint256);\r\n    function maxUtilizationRate() external view returns (uint256);\r\n    function interestFeeRate() external view returns (uint256);\r\n    function () external payable;\r\n}\r\n"},"InterestRateModel.sol":{"content":"pragma solidity ^0.5.16;\r\n\r\n/**\r\n  * @title Compound\u0027s InterestRateModel Interface\r\n  * @author Compound\r\n  */\r\ncontract InterestRateModel {\r\n    /// @notice Indicator that this is an InterestRateModel contract (for inspection)\r\n    bool public constant isInterestRateModel = true;\r\n\r\n    /**\r\n      * @notice Calculates the current borrow interest rate per block\r\n      * @param cash The total amount of cash the market has\r\n      * @param borrows The total amount of borrows the market has outstanding\r\n      * @param reserves The total amnount of reserves the market has\r\n      * @return The borrow rate per block (as a percentage, and scaled by 1e18)\r\n      */\r\n    function getBorrowRate(uint cash, uint borrows, uint reserves) external view returns (uint);\r\n\r\n    /**\r\n      * @notice Calculates the current supply interest rate per block\r\n      * @param cash The total amount of cash the market has\r\n      * @param borrows The total amount of borrows the market has outstanding\r\n      * @param reserves The total amnount of reserves the market has\r\n      * @param reserveFactorMantissa The current reserve factor the market has\r\n      * @return The supply rate per block (as a percentage, and scaled by 1e18)\r\n      */\r\n    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) external view returns (uint);\r\n\r\n}\r\n"}}