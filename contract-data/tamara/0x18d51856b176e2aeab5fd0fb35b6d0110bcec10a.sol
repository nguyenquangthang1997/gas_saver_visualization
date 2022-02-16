pragma solidity 0.5.15;

import "./Book.sol";
import "./Oracle.sol";


contract AssetSwap {

    constructor (address priceOracle, int _levRatio)
        public {
            administrators[msg.sender] = true;
            feeAddress = msg.sender;
            oracle = Oracle(priceOracle);
            leverageRatio = _levRatio;
        }

    Oracle public oracle;
    int[5][2] public assetReturns; /// these are   pushed by the oracle each week
    int public leverageRatio;
    uint public lastOracleSettleTime; /// updates at time of oracle settlement.
    /// Used a lot so this is written to the contract
    mapping(address => address) public books;  /// LP eth address to book contract address
    mapping(address => uint) public assetSwapBalance;  /// how ETH is ultimately withdrawn
    mapping(address => bool) public administrators;  /// gives user right to key functions
    address payable public feeAddress;   /// address for oracle fees PAYABLE!!

    event SubkTracker(
        address indexed eLP,
        address indexed eTaker,
        bytes32 eSubkID,
        bool eisOpen);

    event PauseOnTakes(
        bool openForNewTakes);

    event BurnHist(
        address eLP,
        bytes32 eSubkID,
        address eBurner,
        uint eTime);

    event LPNewBook(
        address indexed eLP,
        address eLPBook);

    event RatesUpdated(
        address indexed eLP,
        uint8 closefee,
        int16 longFundingRate,
        int16 shortFundingRate
        );

    modifier onlyAdmin() {
        require(administrators[msg.sender], "admin only");
        _;
    }

    function removeAdmin(address toRemove)
        external
        onlyAdmin
    {
        require(toRemove != msg.sender, "You may not remove yourself as an admin.");
        administrators[toRemove] = false;
    }

    /** Grant administrator priviledges to a user
    * @param newAdmin the address to promote
    */
    function addAdmin(address newAdmin)
        external
        onlyAdmin
    {
        administrators[newAdmin] = true;
    }

    function adjustMinRM(uint16 _min)
        external
    {
        require(books[msg.sender] != address(0), "User must have a book");
        require(_min >= 1);
        Book b = Book(books[msg.sender]);
        b.adjustMinRMBook(_min);
    }

    /** data are input in basis points as a percent of national
    * thus 10 is 0.1% of notional, which when applied to the crypto
    * with 2.5 leverage, generates a 0.25% of RM charge. funding rates
    * can be negative, which implies the taker receives a payment.
    */
    function updateFees(uint newClose, int frLong, int frShort)
        external
    {
        require(books[msg.sender] != address(0), "User must have a book");
        /// data are input as basis points of notional, adjusted to bps of RM to simplify calculations
        int longRate = frLong * leverageRatio / 1e2;
        int shortRate = frShort * leverageRatio / 1e2;
        uint closefee = newClose * uint(leverageRatio) / 1e2;
        /// fees are capped to avoid predatory pricing that would potentially besmirch OracleSwap's reputation
        require(closefee <= 250);
        require(longRate <= 250 && longRate >= -250);
        require(shortRate <= 250 && shortRate >= -250);
        Book b = Book(books[msg.sender]);
        b.updateFeesBook(uint8(closefee), int16(longRate), int16(shortRate));
        emit RatesUpdated(msg.sender, uint8(closefee), int16(longRate), int16(shortRate));
    }

    function changeFeeAddress(address payable newAddress)
        external
        onlyAdmin
    {
        feeAddress = newAddress;
    }

    function balanceInput(address recipient)
            external
            payable
    {
        assetSwapBalance[recipient] += msg.value;
    }

    /** fees are in basis points of national, as in the case when updating the fees
    * minimum RM is in ETH, so 4 would imply a minimum RM of 4 ETH
    */
    function createBook(uint16 _min, uint _closefee, int frLong, int frShort)
        external
        payable
        returns (address newBook)
    {
        require(books[msg.sender] == address(0), "User must not have a preexisting book");
        require(msg.value >= uint(_min) * 10 ether, "Must prep for book");
        require(_min >= 1);
        int16 longRate = int16(frLong * leverageRatio / 1e2);
        int16 shortRate = int16(frShort * leverageRatio / 1e2);
        uint8 closefee = uint8(_closefee * uint(leverageRatio) / 1e2);
        require(longRate <= 250 && longRate >= -250);
        require(shortRate <= 250 && shortRate >= -250);
        require(closefee <= 250);
        books[msg.sender] = address(new Book(msg.sender, address(this), _min, closefee, longRate, shortRate));
        Book b = Book(books[msg.sender]);
        b.fundLPBook.value(msg.value)();
        emit LPNewBook(msg.sender, books[msg.sender]);
        return books[msg.sender];
    }

    function fundLP(address _lp)
        external
        payable
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.fundLPBook.value(msg.value)();
    }

    function fundTaker(address _lp, bytes32 subkID)
        external
        payable
        {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.fundTakerBook.value(msg.value)(subkID);
    }

    function burnTaker(address _lp, bytes32 subkID)
        external
        payable
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        uint refund = b.burnTakerBook(subkID, msg.sender, msg.value);
        emit BurnHist(_lp, subkID, msg.sender, now);
        assetSwapBalance[msg.sender] += refund;
    }

    function burnLP()
        external
        payable
    {
        require(books[msg.sender] != address(0));
        Book b = Book(books[msg.sender]);
        uint refund = b.burnLPBook(msg.value);
        bytes32 abcnull;
        emit BurnHist(msg.sender, abcnull, msg.sender, now);
        assetSwapBalance[msg.sender] += refund;
    }

    function cancel(address _lp, bytes32 subkID, bool closeNow)
        external
        payable
    {
        Book b = Book(books[_lp]);
        uint8 priceDay = oracle.getStartDay();
        uint8 endDay = 5;
        if (closeNow)
            endDay = priceDay;
        b.cancelBook.value(msg.value)(lastOracleSettleTime, subkID, msg.sender, endDay);
    }

    function closeBook(address _lp)
        external
        payable
    {
        require(msg.sender == _lp);
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.closeBookBook.value(msg.value)();
    }

    function redeem(address _lp, bytes32 subkID)
        external
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.redeemBook(subkID, msg.sender);
        emit SubkTracker(_lp, msg.sender, subkID, false);
    }

    function settleParts(address _lp)
        external
        returns (bool isComplete)
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        uint lastBookSettleTime = b.lastBookSettleTime();
        require(now > (lastOracleSettleTime + 24 hours));
        require(lastOracleSettleTime > lastBookSettleTime, "one settle per week");
        uint settleNumb = b.settleNum();
        if (settleNumb < 1e4) {
            b.settleExpiring(assetReturns[1]);
        } else if (settleNumb < 2e4) {
            b.settleRolling(assetReturns[0][0]);
        } else if (settleNumb < 3e4) {
            b.settleNew(assetReturns[0]);
        } else if (settleNumb == 3e4) {
            b.settleFinal();
            isComplete = true;
        }
    }

    function settleBatch(address _lp)
        external
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        uint lastBookSettleTime = b.lastBookSettleTime();
        require(now > (lastOracleSettleTime + 24 hours));
        require(lastOracleSettleTime > lastBookSettleTime, "one settle per week");
        /// the 5x1 vector of returns in units of ether, where 0.6 is a +60% of RM payoff,
        /// -0.6 is a -60% of RM payoff. The refer to initial price days to settlement day
        b.settleExpiring(assetReturns[1]);
        /// this is the settle to settle return
        b.settleRolling(assetReturns[0][0]);
        /// this is the return from the last settlement day to the price day
        /// for regular closes, the price day == 5, so it is a settlement to settlement return
        b.settleNew(assetReturns[0]);
        b.settleFinal();
    }

    function take(address _lp, uint rm, bool isTakerLong)
        external
        payable
        returns (bytes32 newsubkID)
    {
        rm = rm * 1 ether;
        require(msg.value >= 3 * rm / 2, "Insuffient ETH for your RM");
        require(hourOfDay() != 16, "Cannot take during 4 PM ET hour");
        uint takerLong;
        if (isTakerLong)
            takerLong = 1;
        else
            takerLong = 0;
        /// starting price is taken from the oracle contract based on what the next price day is
        uint8 priceDay = oracle.getStartDay();
        Book book = Book(books[_lp]);
        newsubkID = book.takeBook.value(msg.value)(msg.sender, rm, lastOracleSettleTime, priceDay, takerLong);
        emit SubkTracker(_lp, msg.sender, newsubkID, true);
    }

    /** withdraw amounts are in finneys. Thus, 1234 is 1.234 ETH

    */
    function withdrawLP(uint amount)
        external
    {
        require(amount > 0);
        require(books[msg.sender] != address(0));
        Book b = Book(books[msg.sender]);
        amount = 1 finney * amount;
        b.withdrawLPBook(amount, lastOracleSettleTime);
    }

    function withdrawTaker(uint amount, address _lp, bytes32 subkID)
        external
    {
        require(amount > 0);
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        amount = 1 finney * amount;
        b.withdrawTakerBook(subkID, amount, lastOracleSettleTime, msg.sender);
    }
    /// one can withdraw from one's assetSwap balance at any time. It can only send the entire amount

    function withdrawFromAssetSwap()
        external
    {
        uint amount = assetSwapBalance[msg.sender];
        require(amount > 0);
        assetSwapBalance[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    function inactiveOracle(address _lp)
        external
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.inactiveOracleBook();
    }

    function inactiveLP(address _lp, bytes32 subkID)
        external
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.inactiveLPBook(subkID, msg.sender, lastOracleSettleTime);
    }

    function getBookData(address _lp)
        external
        view
        returns (address book,
            // balances in wei
            uint lpMargin,
            uint totalLpLong,
            uint totalLpShort,
            uint lpRM,
            /// in ETH
            uint bookMinimum,
            /// in basis points as a percent of RM
            /// to convert to notional, we multiply by the leverage ratio
            int16 longFundingRate,
            int16 shortFundingRate,
            uint8 lpCloseFee,
            /** 0 is fine, 1 means book cancels at next settlement
            * 2 means LP burned (which cancels the book at next settlement)
            * 3 book is inactive, no more settling or new positions
            */
            uint8 bookStatus
            )
    {
        book = books[_lp];
        if (book != address(0)) {
            Book b = Book(book);
            lpMargin = b.margin(0);
            totalLpLong = b.margin(1);
            totalLpShort = b.margin(2);
            lpRM = b.margin(3);
            bookMinimum = b.lpMinTakeRM();
            longFundingRate = b.fundingRates(1);
            shortFundingRate = b.fundingRates(0);
            lpCloseFee = b.bookCloseFee();
            bookStatus = b.bookStatus();
        }
    }

    function getSubkData1(address _lp, bytes32 subkID)
        external
        view
        returns (
            address taker,
            /// in wei
            uint takerMargin,
            uint reqMargin
            )
    {
        address book = books[_lp];
        if (book != address(0)) {
            Book b = Book(book);
            (taker, takerMargin, reqMargin) = b.getSubkData1Book(subkID);
        }
    }

    function getSubkData2(address _lp, bytes32 subkID)
        external
        view
        returns (
          /** 0 new, 1 active and rolled over, 2 taker cancelled, 3 LP cancelled,
          * 4 intraweek cancelled, 5 taker burned, 6 taker default/redeemable, 7 inactive/redeemable
          */
            uint8 subkStatus,
          /// for new and expiring subcontracts, either the start or end price that week
            uint8 priceDay,
          /** the LP's closing fee, in basis points as a percent of the RM. The total closing fee
          * is this plus 2.5% of RM, the oracle's fee
          */
            uint8 closeFee,
          /// the funding rate paid by the taker, which may be negative
            int16 fundingRate,
          /// true for taker is long (and thus LP is short)
            bool takerSide
            )
    {
        address book = books[_lp];
        if (book != address(0)) {
            Book b = Book(book);
            (subkStatus, priceDay, closeFee, fundingRate, takerSide)
                = b.getSubkData2Book(subkID);
        }
    }

    function getSettleInfo(address _lp)
        external
        view
        returns (
          /// total number of taker subcontracts, including new, rolled-over, cancelled, and inactive subcontracts
            uint totalLength,
          /// taker subcontracts that are expiring at next settlement
            uint expiringLength,
          /// taker subcontracts that have not yet settled. Such positions cannot be cancelled. The next week,
          /// they will be 'active', and cancelable.
            uint newLength,
          /// time of last book settlement, in hours from 1970, Greenwich Mean Time
            uint lastBookSettleUTC,
          /// this is used for assessing the progress of a settlement when it is too large to be
          /// executed in batch.
            uint settleNumber,
          /// amount of ETH in the LP book
            uint bookBalance,
          /// an LP can close they book en masse, which would push the maturity of the book to 28 days after
          /// the close is instantiated. Takers should take note. A taker does not pay a cancel fee when
          /// the LP cancels their book, but they must then wait until the final settlement
            uint bookMaturityUTC
            )
    {
        address book = books[_lp];
        if (book != address(0)) {
            Book b = Book(book);
            (totalLength, expiringLength, newLength, lastBookSettleUTC, settleNumber,
                bookBalance, bookMaturityUTC) = b.getSettleInfoBook();
        }
    }

    /**
    * This gives the raw asset returns for all potential start and end dates: 5 different returns
    * for new positions (price day to settlement day), and 5 for expiring positions (last settlement to price day)
    * these are posted by the Oracle at the settlemnet price update.
    * They are in % return * Leverage Ratio times 1 ETH,
    * this allows the books to simply apply these numbers to the RM of the various subcontracts to generate the
    * weekly PNL. They are capped at +/- 0.975e18, so that the extreme case of a maximum funding rate, the liability
    * is never greater than 1 ETH. This effectively caps player liability at their RM
    */
    function updateReturns(int[5] memory assetRetNew, int[5] memory assetRetExp)
            public
        {
        require(msg.sender == address(oracle));
        assetReturns[0] = assetRetNew;
        assetReturns[1] = assetRetExp;
        lastOracleSettleTime = now;
    }

    function hourOfDay()
        public
        view
        returns(uint hour1)
    {
        uint nowTemp = now;
    /**
    * 2020 Summer, 1583668800 = March 8 2020 through 1604232000 = November 1 2020
    * 2021 Summer, 1615705200 = March 14 2021 through 1636264800 = November 7 2021
    * 2022 summer, 1647154800 = March 13 2022 through 1667714400 = November 6 2022
    * summer is Daylight Savings Time in the US, where the hour is GMT - 5 in New York City
    * winter is Standard Time in the US, where the hour is GMT - 4 in New York City
    * No takes from 4-5 PM NYC time, so hour == 16 is the exclusion time
    */
        hour1 = (nowTemp % 86400) / 3600 - 5;
        if ((nowTemp > 1583668800 && nowTemp < 1604232000) || (nowTemp > 1615705200 && nowTemp < 1636264800) ||
            (nowTemp > 1647154800 && nowTemp < 1667714400))
            hour1 = hour1 + 1;
    }

    function subzero(uint _a, uint _b)
        internal
        pure
        returns (uint)
    {
        if (_b >= _a) {
            return 0;
        }
        return _a - _b;
    }


}

pragma solidity 0.5.15;

import "./AssetSwap.sol";


contract Book {

    constructor(address user, address admin, uint16 minReqMarg, uint8 closefee,
        int16 frlong, int16 frshort)
        public {
            assetSwap = AssetSwap(admin);
            lp = user;
            lpMinTakeRM = minReqMarg;
            lastBookSettleTime = now;
            bookCloseFee = closefee;
            fundingRates[0] = frshort;
            fundingRates[1] = frlong;
            endOfBookTime = now + 1100 days;
        }

    address public lp;
    AssetSwap public assetSwap;
    /// 0 is actual or total margin, 1 is sum of LP's short takers
    /// 2 is sum of LP's long takers, 3 is the LP's required margin
    /// units an in wei, and refer to the RM, not the notional
    uint[4] public margin;
    uint public lastBookSettleTime;
    uint public burnFactor = 1 ether;
    uint public settleNum;
    int public lpSettleDebitAcct;
    uint public endOfBookTime;
    int16[2] public fundingRates;
    uint16 public lpMinTakeRM;
    uint8 public bookStatus;
    uint8 public bookCloseFee;
    bytes32[][2] public tempContracts;
    bytes32[] public takerContracts;
    mapping(bytes32 => Subcontract) public subcontracts;

    struct Subcontract {
        address taker;
        uint takerMargin;   /// in wei
        uint requiredMargin;     /// in wei
        uint16 index;
        int16 fundingRate;
        uint8 closeFee;
        uint8 subkStatus;
        uint8 priceDay;
        int8 takerSide; /// 1 if long, -1 if short
    }

    modifier onlyAdmin() {
        require(msg.sender == address(assetSwap));
        _;
    }

    function adjustMinRMBook(uint16 _min)
        external
        onlyAdmin
    {
        lpMinTakeRM = _min;
    }

    function updateFeesBook(uint8 newClose, int16 longrate, int16 shortrate)
        external
        onlyAdmin
    {
        fundingRates[0] = shortrate;
        fundingRates[1] = longrate;
        bookCloseFee = newClose;
    }

    function burnTakerBook(bytes32 subkID, address sender, uint msgval)
        external
        onlyAdmin
        returns (uint)
    {
        Subcontract storage k = subcontracts[subkID];
        require(sender == k.taker, "must by party to his subcontract");
        require(settleNum == 0, "not during settlement process");
        require(k.subkStatus < 5, "can only burn active subcontract");
        uint burnFee = k.requiredMargin / 2;
        require(msgval >= burnFee, "Insufficient burn fee");
        burnFee = subzero(msgval, burnFee);
        if (margin[1] > margin[2]) {
            burnFactor = subzero(burnFactor, 1 ether * k.requiredMargin / margin[1]);
        } else {
            burnFactor = subzero(burnFactor, 1 ether * k.requiredMargin / margin[2]);
        }
        k.subkStatus = 5;
        return burnFee;
    }

    function burnLPBook(uint msgval)
        external
        onlyAdmin
        returns (uint)
    {
        require(bookStatus != 2, "can only burn once");
        /// burn fee is 50% of RM
        uint burnFee = margin[3] / 2;
        require(msgval >= burnFee, "Insufficient burn fee");
        burnFee = subzero(msgval, burnFee);
        /** The entire LP RM as a percent of the larger of the long or short
        * side is used to decrement the credits of those at the upcoming settlement
        */
        if (margin[2] > margin[1]) {
            burnFactor = subzero(burnFactor, 1 ether * margin[3] / margin[2]);
        } else {
            burnFactor = subzero(burnFactor, 1 ether * margin[3] / margin[1]);
        }
        bookStatus = 2;
        return burnFee;
    }

    function cancelBook(uint lastOracleSettle, bytes32 subkID, address sender, uint8 _endDay)
        external
        payable
        onlyAdmin
    {
        Subcontract storage k = subcontracts[subkID];
        require(lastOracleSettle < lastBookSettleTime, "Cannot do during settle period");
        require(sender == k.taker || sender == lp, "Canceller not LP or taker");
        /// checks to see if subk already cancelled, as otherwise redundant
        require(k.subkStatus == 1, "redundant or too new");
        uint feeOracle = 250 * k.requiredMargin / 1e4;
        require(msg.value >= (2 * feeOracle), "Insufficient cancel fee");
        uint feeLP = uint(k.closeFee) * k.requiredMargin / 1e4;
        if (sender == k.taker && _endDay == 5) {
            k.subkStatus = 2;  /// regular taker cancel
        } else if (sender == k.taker) {
            require(k.requiredMargin < subzero(margin[0], margin[3]), "Insuff LP RM for immed cancel");
            feeLP = feeOracle;  /// close fee is now max close fee, overriding initial close fee
            k.subkStatus = 4;  /// immediate taker cancel
            k.priceDay = _endDay;  /// this is the end-day of the subcontract's last week
        } else {
            feeOracle = 2 * feeOracle;
            feeLP = subzero(msg.value, feeOracle); /// this is really a refund to the LP, not a fee
            k.subkStatus = 3;  /// LP cancel
        }
        balanceSend(feeOracle, assetSwap.feeAddress());
        tempContracts[1].push(subkID);  /// sets this up to settle as an expiring subcontract
        margin[0] += feeLP;
        k.takerMargin += subzero(msg.value, feeLP + feeOracle);
    }

    function fundLPBook()
        external
        onlyAdmin
        payable
    {
        margin[0] += msg.value;
    }

    function fundTakerBook(bytes32 subkID)
        external
        onlyAdmin
        payable
    {
        Subcontract storage k = subcontracts[subkID];
        require(k.subkStatus < 2);
        k.takerMargin += msg.value;
    }

    function closeBookBook()
        external
        payable
        onlyAdmin
    { /// pays the close fee on the larger side of her book
        uint feeOracle = 250 * (margin[1] + margin[2] - min(margin[1], margin[2])) / 1e4;
        require(msg.value >= feeOracle, "Insufficient cancel fee");
        uint feeOverpay = msg.value - feeOracle;
        balanceSend(feeOracle, assetSwap.feeAddress());
        if (now > endOfBookTime)
        /// this means the next settlement ends this book's activity
            bookStatus = 1;
        else
        /// if initial, needs to be run again in 28 days to complete the shut down
            endOfBookTime = now + 28 days;
        margin[0] += feeOverpay;
    }

    /**
    *We only need look at when the last book settlement because
    * if the LP was at fault, someone could have inactivatedthe LP
    * and received a reward. Thus, the only scenario where a book
    * can be active and the LP not inactivated, is when the oracle has been
    * absent for a week
    */
    function inactiveOracleBook()
        external
        onlyAdmin
        {
        require(now > (lastBookSettleTime + 10 days));
        bookStatus = 3;
    }

    /** if the book was not settled, the LP is held accountable
     * the first counterparty to execute this function will then get a bonus credit of their RM from  *the LP
     * if the LP's total margin is zero, they will get whatever is there
     * after the book is in default all players can redeem their subcontracts
     * After a book is in default, this cannot be executed
     */
    function inactiveLPBook(bytes32 subkID, address sender, uint _lastOracleSettle)
        external
        onlyAdmin
    {

        require(bookStatus != 3);
        Subcontract storage k = subcontracts[subkID];
        require(k.taker == sender);
        require(_lastOracleSettle > lastBookSettleTime);
        require(subzero(now, _lastOracleSettle) > 48 hours);
        uint lpDefFee = min(margin[0], margin[3] / 2);
        margin[0] = subzero(margin[0], lpDefFee);
        margin[3] = 0;
        bookStatus = 3;
        /// annoying, but at least someone good get the negligent LP's money
        k.takerMargin += lpDefFee;
    }

    function redeemBook(bytes32 subkid, address sender)
        external
        onlyAdmin
    {
        Subcontract storage k = subcontracts[subkid];
        require(k.subkStatus > 5 || bookStatus == 3);
        /// redemption can happen if the subcontract has defaulted subkStatus = 6, is inactive subkStatus = 7
        /// or if the book is inactive (bookStatus == 3)
        uint tMargin = k.takerMargin;
        k.takerMargin = 0;
        uint16 index = k.index;
        /// iff the taker defaulted on an active book, they are penalized by
        /// burning RM/2 of their margin
        bool isDefaulted = (k.subkStatus == 6 && bookStatus == 0);
        uint defPay = k.requiredMargin / 2;
        uint lpPayment;
        address tAddress = k.taker;
        /// this pays the lp for the gas and effort of redeeming for the taker
        /// it's just 2 finney. The investor should now see their margin in the
        /// assetSwapBalance, and withdraw from there
        if (sender == lp) {
            lpPayment = tMargin - subzero(tMargin, 2 finney);
            tMargin -= lpPayment;
            margin[0] += lpPayment;
        }
        /** we have to pop the takerLong/Short lists to free up space
        * this involves this little trick, moving the last row to the row we are
        * redeeming and writing it over the redeemed subcontract
        * then we remove the duplicate.
        */
        Subcontract storage lastTaker = subcontracts[takerContracts[takerContracts.length - 1]];
        lastTaker.index = index;
        takerContracts[index] = takerContracts[takerContracts.length - 1];
        takerContracts.pop();
        delete subcontracts[subkid];
        // we only take what is there. It goes to the oracle, so if he's a cheater, you can punish
        /// him more by withholding this payment as well as the fraudulent PNL. If he's not a cheater
        /// then you are just negligent for defaulting and probably were not paying attention, as
        /// you should have know you couldn't cure your margin Friday afternoon before close.
        if (isDefaulted) {
            tMargin = subzero(tMargin, defPay);
            balanceSend(defPay, assetSwap.feeAddress());
        }
        /// money is sent to AssetSwapContract
        balanceSend(tMargin, tAddress);

    }

    /** Settle the rolled over taker sukcontracts
    * @param assetRet the returns for a long contract for a taker for only one
    * start day, as they are all starting on the prior settlement price
    */
    function settleRolling(int assetRet)
        external
        onlyAdmin
    {
        require(settleNum < 2e4, "done with rolling settle");
        int takerRetTemp;
        int lpTemp;
        /// the first settlement function set the settleNum = 1e4, so that is subtracted to
        /// see where we are in the total number of takers in the LP's book
        uint loopCap = min(settleNum - 1e4 + 250, takerContracts.length);
        for (uint i = (settleNum - 1e4); i < loopCap; i++) {
            Subcontract storage k = subcontracts[takerContracts[i]];
            if (k.subkStatus == 1) {
                takerRetTemp = int(k.takerSide) * assetRet * int(k.requiredMargin) / 1
                ether - (int(k.fundingRate) * int(k.requiredMargin) / 1e4);
                lpTemp = lpTemp - takerRetTemp;
                if (takerRetTemp < 0) {
                    k.takerMargin = subzero(k.takerMargin, uint(-takerRetTemp));
                } else {
                    k.takerMargin += uint(takerRetTemp) * burnFactor / 1 ether;
                }
                if (k.takerMargin < k.requiredMargin) {
                    k.subkStatus = 6;
                    if (k.takerSide == 1)
                        margin[2] = subzero(margin[2], k.requiredMargin);
                    else
                        margin[1] = subzero(margin[1], k.requiredMargin);
                }
            }
        }
        settleNum += 250;
        if ((settleNum - 1e4) >= takerContracts.length)
            settleNum = 2e4;
        lpSettleDebitAcct += lpTemp;
    }

    /// this is the fourth and the final of the settlement functions
    function settleFinal()
        external
        onlyAdmin
    {
        require(settleNum == 3e4, "not done with all the subcontracts");
        /// this take absolute value of (long - short) to update the LP's RM
        if (margin[2] > margin[1])
            margin[3] = margin[2] - margin[1];
        else
            margin[3] = margin[1] - margin[2];
        if (lpSettleDebitAcct < 0)
            margin[0] = subzero(margin[0], uint(-lpSettleDebitAcct));
        else
        /// if the lpSettleDebitAcct is positive, we add it, but first apply the burnFactor
        /// to remove the burner's pnl in a pro-rata way
            margin[0] = margin[0] + uint(lpSettleDebitAcct) * burnFactor / 1 ether;
        if (bookStatus != 0) {
            bookStatus = 3;
            margin[3] = 0;
        } else if (margin[0] < margin[3]) {
            // default scenario for LP
            bookStatus = 3;
            uint defPay = min(margin[0], margin[3] / 2);
            margin[0] = subzero(margin[0], defPay);
            balanceSend(defPay, assetSwap.feeAddress());
            margin[3] = 0;
        }
        // resets for our next book settlement
        lpSettleDebitAcct = 0;
        lastBookSettleTime = now;
        settleNum = 0;
        delete tempContracts[1];
        delete tempContracts[0];
        burnFactor = 1 ether;
    }

    /** Create a new Taker long subcontract of the given parameters
    * @param taker the address of the party on the other side of the contract
    * @param rM the ETH amount in the required margin
    * isTakerLong is +1 if taker is long, 0 if taker is short
    * @return subkID the id of the newly created subcontract
    */
    function takeBook(address taker, uint rM, uint lastOracleSettle, uint8 _priceDay, uint isTakerLong)
        external
        payable
        onlyAdmin
        returns (bytes32 subkID)
    {
        require(bookStatus == 0, "book is no longer taking positions");
        require((now + 28 days) < endOfBookTime, "book closing soon");
        require(rM >= uint(lpMinTakeRM) * 1 ether, "must be greater than book min");
        require(lastOracleSettle < lastBookSettleTime, "Cannot do during settle period");
        uint availableMargin = subzero(margin[0] / 2 + margin[2 - isTakerLong], margin[1 + isTakerLong]);
        require(rM <= availableMargin && (margin[0] - margin[3]) > rM);
        require(rM <= availableMargin);
        margin[1 + isTakerLong] += rM;
        Subcontract memory order;
        order.requiredMargin = rM;
        order.takerMargin = msg.value;
        order.taker = taker;
        order.takerSide = int8(2 * isTakerLong - 1);
        margin[3] += rM;
        subkID = keccak256(abi.encodePacked(now, takerContracts.length));
        order.index = uint16(takerContracts.length);
        order.priceDay = _priceDay;
        order.fundingRate = fundingRates[isTakerLong];
        order.closeFee = bookCloseFee;
        subcontracts[subkID] = order;
        takerContracts.push(subkID);
        tempContracts[0].push(subkID);
        return subkID;
    }

    /** Withdrawing margin
    * reverts if during the settle period, oracleSettleTime > book settle time
    * also must leave total margin greater than the required margin
    */
    function withdrawLPBook(uint amount, uint lastOracleSettle)
        external
        onlyAdmin
    {
        require(margin[0] >= amount, "Cannot withdraw more than the margin");
         // if book is dead LP can take everything left, if not dead, can only take up to RM
        if (bookStatus != 3) {
            require(subzero(margin[0], amount) >= margin[3], "Cannot w/d more than excess margin");
            require(lastOracleSettle < lastBookSettleTime, "Cannot w/d during settle period");
        }
        margin[0] = subzero(margin[0], amount);
        balanceSend(amount, lp);
    }

    function withdrawTakerBook(bytes32 subkID, uint amount, uint lastOracleSettle, address sender)
        external
        onlyAdmin
    {
        require(lastOracleSettle < lastBookSettleTime, "Cannot w/d during settle period");
        Subcontract storage k = subcontracts[subkID];
        require(k.subkStatus < 6, "subk dead, must redeem");
        require(sender == k.taker, "Must be taker to call this function");
        require(subzero(k.takerMargin, amount) >= k.requiredMargin, "cannot w/d more than excess margin");
        k.takerMargin = subzero(k.takerMargin, amount);
        balanceSend(amount, k.taker);
    }

    function getSubkData1Book(bytes32 subkID)
        external
        view
        returns (address takerAddress, uint takerMargin, uint requiredMargin)
    {   Subcontract memory k = subcontracts[subkID];
        takerAddress = k.taker;
        takerMargin = k.takerMargin;
        requiredMargin = k.requiredMargin;
    }

    function getSubkData2Book(bytes32 subkID)
        external
        view
        returns (uint8 kStatus, uint8 priceDay, uint8 closeFee, int16 fundingRate, bool takerSide)
    {   Subcontract memory k = subcontracts[subkID];
        kStatus = k.subkStatus;
        priceDay = k.priceDay;
        closeFee = k.closeFee;
        fundingRate = k.fundingRate;
        if (k.takerSide == 1)
            takerSide = true;
    }

    function getSettleInfoBook()
        external
        view
        returns (uint totalLength, uint expiringLength, uint newLength, uint lastBookSettleUTC, uint settleNumber,
            uint bookBalance, uint bookMaturityUTC)
    {
        totalLength = takerContracts.length;
        expiringLength = tempContracts[1].length;
        newLength = tempContracts[0].length;
        lastBookSettleUTC = lastBookSettleTime;
        settleNumber = settleNum;
        bookMaturityUTC = endOfBookTime;
        bookBalance = address(this).balance;
    }

    /** Settle the taker long sukcontracts
    * priceDay Expiring returns use the return from the last settle to the priceDay, which
    * for regular cancels is just 5, the most recent settlement price
    * this is the first of 4 settlement functions
    * */
    function settleExpiring(int[5] memory assetRetExp)
        public
        onlyAdmin
        {
        require(bookStatus != 3 && settleNum < 1e4, "done with expiry settle");
        int takerRetTemp;
        int lpTemp;
        uint loopCap = min(settleNum + 200, tempContracts[1].length);
        for (uint i = settleNum; i < loopCap; i++) {
            Subcontract storage k = subcontracts[tempContracts[1][i]];
            takerRetTemp = int(k.takerSide) * assetRetExp[k.priceDay - 1] * int(k.requiredMargin) / 1 ether -
            (int(k.fundingRate) * int(k.requiredMargin) / 1e4);
            lpTemp -= takerRetTemp;
            if (takerRetTemp < 0) {
                k.takerMargin = subzero(k.takerMargin, uint(-takerRetTemp));
            } else {
                k.takerMargin += uint(takerRetTemp) * burnFactor / 1 ether;
            }
            if (k.takerSide == 1)
                margin[2] = subzero(margin[2], k.requiredMargin);
            else
                margin[1] = subzero(margin[1], k.requiredMargin);
            k.subkStatus = 7;
        }
        settleNum += 200;
        if (settleNum >= tempContracts[1].length)
            settleNum = 1e4;
        lpSettleDebitAcct += lpTemp;
    }

    /// this is the third of the settlement functions
    function settleNew(int[5] memory assetRets)
        public
        onlyAdmin
    {
        require(settleNum < 3e4, "done with new settle");
        int takerRetTemp;
        int lpTemp;
        /// after running the second settlement function, settleRolling, it is set to 2e4
        uint loopCap = min(settleNum - 2e4 + 200, tempContracts[0].length);
        for (uint i = (settleNum - 2e4); i < loopCap; i++) {
            Subcontract storage k = subcontracts[tempContracts[0][i]];
            /// subkStatus set to 'active' which means it can be cancelled
            /// it will also be settled in the settleRolling if not cancelled
            /// using the more efficient settlement that uses just one return, from last to most recent settlement
            k.subkStatus = 1;
            if (k.priceDay != 5) {
                takerRetTemp = int(k.takerSide) * assetRets[k.priceDay] * int(k.requiredMargin) / 1
                ether - (int(k.fundingRate) * int(k.requiredMargin) / 1e4);
                lpTemp = lpTemp - takerRetTemp;
                if (takerRetTemp < 0) {
                    k.takerMargin = subzero(k.takerMargin, uint(-takerRetTemp));
                } else {
                    k.takerMargin += uint(takerRetTemp) * burnFactor / 1 ether;
                }
                if (k.takerMargin < k.requiredMargin) {
                    k.subkStatus = 6;
                    if (k.takerSide == 1)
                        margin[2] = subzero(margin[2], k.requiredMargin);
                    else
                        margin[1] = subzero(margin[1], k.requiredMargin);
                }
                k.priceDay = 5;
            }
        }
        settleNum += 200;
        if (settleNum >= tempContracts[0].length)
            settleNum = 3e4;
        lpSettleDebitAcct += lpTemp;
    }

    /// Function to send balances back to the Assetswap contract
    function balanceSend(uint amount, address recipient)
        internal
    {
        assetSwap.balanceInput.value(amount)(recipient);
    }

    /** Utility function to find the minimum of two unsigned values
    * @notice returns the first parameter if they are equal
    */
    function min(uint a, uint b)
        internal
        pure
        returns (uint)
    {
        if (a <= b)
            return a;
        else
            return b;
    }

    function subzero(uint _a, uint _b)
        internal
        pure
        returns (uint)
    {
        if (_b >= _a)
            return 0;
        else
            return _a - _b;
    }


}

pragma solidity 0.5.15;

import "./AssetSwap.sol";


contract Oracle {

    constructor (uint ethPrice, uint spxPrice, uint btcPrice) public {
        admins[msg.sender] = true;
        prices[0][5] = ethPrice;
        prices[1][5] = spxPrice;
        prices[2][5] = btcPrice;
        lastUpdateTime = now;
        lastSettleTime = now;
        currentDay = 5;
        levRatio[0] = 250;  // ETH contract 2.5 leverage
        levRatio[1] = 1000; /// SPX contract 10.0 leverage
        levRatio[2] = 250;  // BTC contract 2.5 leverage
    }

    address[3] public assetSwaps;
    uint[6][3] private prices;
    uint public lastUpdateTime;
    uint public lastSettleTime;
    int[3] public levRatio;
    uint8 public currentDay;
    bool public nextUpdateSettle;
    mapping(address => bool) public admins;
    mapping(address => bool) public readers;

    event PriceUpdated(
        uint ethPrice,
        uint spxPrice,
        uint btcPrice,
        uint eUTCTime,
        uint eDayNumber,
        bool eisCorrection
    );

    modifier onlyAdmin() {
        require(admins[msg.sender]);
        _;
    }
    /** Grant write priviledges to a user,
    * mainly intended for when the admin wants to switch accounts, ie, paired with a removal
    */

    function addAdmin(address newAdmin)
        external
        onlyAdmin
    {
        admins[newAdmin] = true;
    }

    /** Grant priviledges to a user accessing price data on the blockchain
    * @param newReader the address. Any reader is thus approved by the oracle/admin
    * useful for new contracts that use this oracle, in that the oracle would not
    * need to create a new oracle contract for ETH prices
    */
    function addReaders(address newReader)
        external
        onlyAdmin
    {
        readers[newReader] = true;
    }
    /** this can only be done once, so this oracle is solely for working with
    * three AssetSwap contracts
    * assetswap 0 is the ETH, at 2.5 leverage
    * assetswap 1 is the SPX, at 10x leverage
    * assetswap 2 is the BTC, at 2.5 leverage
    */

    function addAssetSwaps(address newAS0, address newAS1, address newAS2)
        external
        onlyAdmin
    {
        require(assetSwaps[0] == address(0));
        assetSwaps[0] = newAS0;
        assetSwaps[1] = newAS1;
        assetSwaps[2] = newAS2;
        readers[newAS0] = true;
        readers[newAS1] = true;
        readers[newAS2] = true;
    }

    function removeAdmin(address toRemove)
        external
        onlyAdmin
    {
        require(toRemove != msg.sender);
        admins[toRemove] = false;
    }
    /** Quickly fix an erroneous price, or correct the fact that 50% movements are
    * not allowed in the standard price input
    * this must be called within 60 minutes of the initial price update occurence
    */

    function editPrice(uint _ethprice, uint _spxprice, uint _btcprice)
        external
        onlyAdmin
    {
        require(now < lastUpdateTime + 60 minutes);
        prices[0][currentDay] = _ethprice;
        prices[1][currentDay] = _spxprice;
        prices[2][currentDay] = _btcprice;
        emit PriceUpdated(_ethprice, _spxprice, _btcprice, now, currentDay, true);
    }

    function updatePrices(uint ethp, uint spxp, uint btcp, bool _newFinalDay)
        external
        onlyAdmin
    {

             /// no updates within 20 hours per day
        require(now > lastUpdateTime + 20 hours);
            /** can't be executed if the next price should be a settlement price
            * settlement prices are special because they need to update the asset returns
            * and sent to the AssetSwap contracts
            */
        require(!nextUpdateSettle);
         /// after settlement update, at least 48 hours until new prices are posted
        require(now > lastSettleTime + 48 hours, "too soon after last settle");
          /// prevents faulty prices, as stale prices are a common source of bad prices.
        require(ethp != prices[0][currentDay] && spxp != prices[1][currentDay] && btcp != prices[2][currentDay]);
            /// extreme price movements are probably mistakes. They can be posted
          /// but only via a 'price edit' that must be done within 60 minutes of the initial update
        require((ethp * 10 < prices[0][currentDay] * 15) && (ethp * 10 > prices[0][currentDay] * 5));
        require((spxp * 10 < prices[1][currentDay] * 15) && (spxp * 10 > prices[1][currentDay] * 5));
        require((btcp * 10 < prices[2][currentDay] * 15) && (btcp * 10 > prices[2][currentDay] * 5));
        if (currentDay == 5) {
            currentDay = 1;
            nextUpdateSettle = false;
        } else {
            currentDay += 1;
            nextUpdateSettle = _newFinalDay;
        }
        if (currentDay == 4)
            nextUpdateSettle = true;
        updatePriceSingle(0, ethp);
        updatePriceSingle(1, spxp);
        updatePriceSingle(2, btcp);
        emit PriceUpdated(ethp, spxp, btcp, now, currentDay, false);
        lastUpdateTime = now;
    }

    function settlePrice(uint ethp, uint spxp, uint btcp)
        external
        onlyAdmin
    {
        require(nextUpdateSettle);
        require(now > lastUpdateTime + 20 hours);
        require(ethp != prices[0][currentDay] && spxp != prices[1][currentDay] && btcp != prices[2][currentDay]);
        require((ethp * 10 < prices[0][currentDay] * 15) && (ethp * 10 > prices[0][currentDay] * 5));
        require((spxp * 10 < prices[1][currentDay] * 15) && (spxp * 10 > prices[1][currentDay] * 5));
        require((btcp * 10 < prices[2][currentDay] * 15) && (btcp * 10 > prices[2][currentDay] * 5));
        currentDay = 5;
        nextUpdateSettle = false;
        updatePriceSingle(0, ethp);
        updatePriceSingle(1, spxp);
        updatePriceSingle(2, btcp);
        int[5] memory assetReturnsNew;
        int[5] memory assetReturnsExpiring;
        int cap = 975 * 1 ether / 1000;
        for (uint j = 0; j < 3; j++) {
                  /**  asset return from start day j to settle day (ie, day 5),
                  * and also the prior settle day (day 0) to the end day.
                  * returns are normalized from 0.975 ether to - 0.975 ether
                  * where 0.9 ether is a 90% RM profit for the long taker,
                  * 0.2 ether means a 20% of RM profit for the long taker.
                  */
            for (uint i = 0; i < 5; i++) {
                if (prices[0][i] != 0) {
                    int assetRetFwd = int(prices[j][5] * 1 ether / prices[j][i]) - 1 ether;
                    assetReturnsNew[i] = assetRetFwd * int(prices[0][i]) * levRatio[j] /
                        int(prices[0][5]) / 100;
                /** as funding rates are maxed out at 2.5% of RM, the return must
                * max out at 97.5% of RM so that required margins cover all
                * potential payment scenarios
                */
                    assetReturnsNew[i] = bound(assetReturnsNew[i], cap);
                }
                if (prices[0][i+1] != 0) {
                    int assetRetBack = int(prices[j][i+1] * 1 ether / prices[j][0]) - 1 ether;
                    assetReturnsExpiring[i] = assetRetBack * int(prices[0][0]) * levRatio[j] /
                        int(prices[0][i+1]) / 100;

                    assetReturnsExpiring[i] = bound(assetReturnsExpiring[i], cap);
                }
            }
    /// this updates the AssetSwap contract with the vector of returns,
    /// one for each day of the week
            AssetSwap asw = AssetSwap(assetSwaps[j]);
            asw.updateReturns(assetReturnsNew, assetReturnsExpiring);
        }
        lastSettleTime = now;
        emit PriceUpdated(ethp, spxp, btcp, now, currentDay, false);
        lastUpdateTime = now;
    }
    /** Return the entire current price array for a given asset
    * @param _assetID the asset id of the desired asset
    * @return _priceHist the price array in USD for the asset
    * @dev only the admin and addresses granted readership may call this function
    * While only an admin or reader can access this within the EVM
    * anyone can access these prices outside the EVM
    * eg, in javascript: OracleAddress.methods.getUsdPrices.cacheCall(0, { 'from': 'AdminAddress' }
    */

    function getUsdPrices(uint _assetID)
        public
        view
        returns (uint[6] memory _priceHist)
    {
        require(admins[msg.sender] || readers[msg.sender]);
        _priceHist = prices[_assetID];
    }

        /** Return only the latest prices
        * @param _assetID the asset id of the desired asset
        * @return _price the latest price of the given asset
        * @dev only the admin or a designated reader may call this function within the EVM
        */
    function getCurrentPrice(uint _assetID)
        public
        view
        returns (uint _price)
    {
        require(admins[msg.sender] || readers[msg.sender]);
        _price = prices[_assetID][currentDay];
    }

    /**
    * @return startDay relevant for trades done now
    * pulls the day relevant for new AssetSwap subcontracts
    * startDay 2 means the 2 slot (ie, the third) of prices will be the initial
    * price for the subcontract. As 5 is the top slot, and rolls into slot 0
    * the next week, the next pricing day is 1 when the current day == 5
    * (this would be a weekend or Monday morning)
    */
    function getStartDay()
        public
        view
        returns (uint8 _startDay)
    {
        if (nextUpdateSettle) {
            _startDay = 5;
        } else if (currentDay == 5) {
            _startDay = 1;
        } else {
            _startDay = currentDay + 1;
        }
    }

    function updatePriceSingle(uint _assetID, uint _price)
        internal
    {
        if (currentDay == 1) {
            uint[6] memory newPrices;
            newPrices[0] = prices[_assetID][5];
            newPrices[1] = _price;
            prices[_assetID] = newPrices;
        } else {
            prices[_assetID][currentDay] = _price;
        }
    }

    function bound(int a, int b)
        internal
        pure
        returns (int)
    {
        if (a > b)
            a = b;
        if (a < -b)
            a = -b;
        return a;
    }

}

pragma solidity 0.5.15;

import "./Book.sol";
import "./Oracle.sol";


contract AssetSwap {

    constructor (address priceOracle, int _levRatio)
        public {
            administrators[msg.sender] = true;
            feeAddress = msg.sender;
            oracle = Oracle(priceOracle);
            leverageRatio = _levRatio;
        }

    Oracle public oracle;
    int[5][2] public assetReturns; /// these are   pushed by the oracle each week
    int public leverageRatio;
    uint public lastOracleSettleTime; /// updates at time of oracle settlement.
    /// Used a lot so this is written to the contract
    mapping(address => address) public books;  /// LP eth address to book contract address
    mapping(address => uint) public assetSwapBalance;  /// how ETH is ultimately withdrawn
    mapping(address => bool) public administrators;  /// gives user right to key functions
    address payable public feeAddress;   /// address for oracle fees PAYABLE!!

    event SubkTracker(
        address indexed eLP,
        address indexed eTaker,
        bytes32 eSubkID,
        bool eisOpen);

    event PauseOnTakes(
        bool openForNewTakes);

    event BurnHist(
        address eLP,
        bytes32 eSubkID,
        address eBurner,
        uint eTime);

    event LPNewBook(
        address indexed eLP,
        address eLPBook);

    event RatesUpdated(
        address indexed eLP,
        uint8 closefee,
        int16 longFundingRate,
        int16 shortFundingRate
        );

    modifier onlyAdmin() {
        require(administrators[msg.sender], "admin only");
        _;
    }

    function removeAdmin(address toRemove)
        external
        onlyAdmin
    {
        require(toRemove != msg.sender, "You may not remove yourself as an admin.");
        administrators[toRemove] = false;
    }

    /** Grant administrator priviledges to a user
    * @param newAdmin the address to promote
    */
    function addAdmin(address newAdmin)
        external
        onlyAdmin
    {
        administrators[newAdmin] = true;
    }

    function adjustMinRM(uint16 _min)
        external
    {
        require(books[msg.sender] != address(0), "User must have a book");
        require(_min >= 1);
        Book b = Book(books[msg.sender]);
        b.adjustMinRMBook(_min);
    }

    /** data are input in basis points as a percent of national
    * thus 10 is 0.1% of notional, which when applied to the crypto
    * with 2.5 leverage, generates a 0.25% of RM charge. funding rates
    * can be negative, which implies the taker receives a payment.
    */
    function updateFees(uint newClose, int frLong, int frShort)
        external
    {
        require(books[msg.sender] != address(0), "User must have a book");
        /// data are input as basis points of notional, adjusted to bps of RM to simplify calculations
        int longRate = frLong * leverageRatio / 1e2;
        int shortRate = frShort * leverageRatio / 1e2;
        uint closefee = newClose * uint(leverageRatio) / 1e2;
        /// fees are capped to avoid predatory pricing that would potentially besmirch OracleSwap's reputation
        require(closefee <= 250);
        require(longRate <= 250 && longRate >= -250);
        require(shortRate <= 250 && shortRate >= -250);
        Book b = Book(books[msg.sender]);
        b.updateFeesBook(uint8(closefee), int16(longRate), int16(shortRate));
        emit RatesUpdated(msg.sender, uint8(closefee), int16(longRate), int16(shortRate));
    }

    function changeFeeAddress(address payable newAddress)
        external
        onlyAdmin
    {
        feeAddress = newAddress;
    }

    function balanceInput(address recipient)
            external
            payable
    {
        assetSwapBalance[recipient] += msg.value;
    }

    /** fees are in basis points of national, as in the case when updating the fees
    * minimum RM is in ETH, so 4 would imply a minimum RM of 4 ETH
    */
    function createBook(uint16 _min, uint _closefee, int frLong, int frShort)
        external
        payable
        returns (address newBook)
    {
        require(books[msg.sender] == address(0), "User must not have a preexisting book");
        require(msg.value >= uint(_min) * 10 ether, "Must prep for book");
        require(_min >= 1);
        int16 longRate = int16(frLong * leverageRatio / 1e2);
        int16 shortRate = int16(frShort * leverageRatio / 1e2);
        uint8 closefee = uint8(_closefee * uint(leverageRatio) / 1e2);
        require(longRate <= 250 && longRate >= -250);
        require(shortRate <= 250 && shortRate >= -250);
        require(closefee <= 250);
        books[msg.sender] = address(new Book(msg.sender, address(this), _min, closefee, longRate, shortRate));
        Book b = Book(books[msg.sender]);
        b.fundLPBook.value(msg.value)();
        emit LPNewBook(msg.sender, books[msg.sender]);
        return books[msg.sender];
    }

    function fundLP(address _lp)
        external
        payable
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.fundLPBook.value(msg.value)();
    }

    function fundTaker(address _lp, bytes32 subkID)
        external
        payable
        {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.fundTakerBook.value(msg.value)(subkID);
    }

    function burnTaker(address _lp, bytes32 subkID)
        external
        payable
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        uint refund = b.burnTakerBook(subkID, msg.sender, msg.value);
        emit BurnHist(_lp, subkID, msg.sender, now);
        assetSwapBalance[msg.sender] += refund;
    }

    function burnLP()
        external
        payable
    {
        require(books[msg.sender] != address(0));
        Book b = Book(books[msg.sender]);
        uint refund = b.burnLPBook(msg.value);
        bytes32 abcnull;
        emit BurnHist(msg.sender, abcnull, msg.sender, now);
        assetSwapBalance[msg.sender] += refund;
    }

    function cancel(address _lp, bytes32 subkID, bool closeNow)
        external
        payable
    {
        Book b = Book(books[_lp]);
        uint8 priceDay = oracle.getStartDay();
        uint8 endDay = 5;
        if (closeNow)
            endDay = priceDay;
        b.cancelBook.value(msg.value)(lastOracleSettleTime, subkID, msg.sender, endDay);
    }

    function closeBook(address _lp)
        external
        payable
    {
        require(msg.sender == _lp);
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.closeBookBook.value(msg.value)();
    }

    function redeem(address _lp, bytes32 subkID)
        external
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.redeemBook(subkID, msg.sender);
        emit SubkTracker(_lp, msg.sender, subkID, false);
    }

    function settleParts(address _lp)
        external
        returns (bool isComplete)
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        uint lastBookSettleTime = b.lastBookSettleTime();
        require(now > (lastOracleSettleTime + 24 hours));
        require(lastOracleSettleTime > lastBookSettleTime, "one settle per week");
        uint settleNumb = b.settleNum();
        if (settleNumb < 1e4) {
            b.settleExpiring(assetReturns[1]);
        } else if (settleNumb < 2e4) {
            b.settleRolling(assetReturns[0][0]);
        } else if (settleNumb < 3e4) {
            b.settleNew(assetReturns[0]);
        } else if (settleNumb == 3e4) {
            b.settleFinal();
            isComplete = true;
        }
    }

    function settleBatch(address _lp)
        external
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        uint lastBookSettleTime = b.lastBookSettleTime();
        require(now > (lastOracleSettleTime + 24 hours));
        require(lastOracleSettleTime > lastBookSettleTime, "one settle per week");
        /// the 5x1 vector of returns in units of ether, where 0.6 is a +60% of RM payoff,
        /// -0.6 is a -60% of RM payoff. The refer to initial price days to settlement day
        b.settleExpiring(assetReturns[1]);
        /// this is the settle to settle return
        b.settleRolling(assetReturns[0][0]);
        /// this is the return from the last settlement day to the price day
        /// for regular closes, the price day == 5, so it is a settlement to settlement return
        b.settleNew(assetReturns[0]);
        b.settleFinal();
    }

    function take(address _lp, uint rm, bool isTakerLong)
        external
        payable
        returns (bytes32 newsubkID)
    {
        rm = rm * 1 ether;
        require(msg.value >= 3 * rm / 2, "Insuffient ETH for your RM");
        require(hourOfDay() != 16, "Cannot take during 4 PM ET hour");
        uint takerLong;
        if (isTakerLong)
            takerLong = 1;
        else
            takerLong = 0;
        /// starting price is taken from the oracle contract based on what the next price day is
        uint8 priceDay = oracle.getStartDay();
        Book book = Book(books[_lp]);
        newsubkID = book.takeBook.value(msg.value)(msg.sender, rm, lastOracleSettleTime, priceDay, takerLong);
        emit SubkTracker(_lp, msg.sender, newsubkID, true);
    }

    /** withdraw amounts are in finneys. Thus, 1234 is 1.234 ETH

    */
    function withdrawLP(uint amount)
        external
    {
        require(amount > 0);
        require(books[msg.sender] != address(0));
        Book b = Book(books[msg.sender]);
        amount = 1 finney * amount;
        b.withdrawLPBook(amount, lastOracleSettleTime);
    }

    function withdrawTaker(uint amount, address _lp, bytes32 subkID)
        external
    {
        require(amount > 0);
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        amount = 1 finney * amount;
        b.withdrawTakerBook(subkID, amount, lastOracleSettleTime, msg.sender);
    }
    /// one can withdraw from one's assetSwap balance at any time. It can only send the entire amount

    function withdrawFromAssetSwap()
        external
    {
        uint amount = assetSwapBalance[msg.sender];
        require(amount > 0);
        assetSwapBalance[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    function inactiveOracle(address _lp)
        external
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.inactiveOracleBook();
    }

    function inactiveLP(address _lp, bytes32 subkID)
        external
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.inactiveLPBook(subkID, msg.sender, lastOracleSettleTime);
    }

    function getBookData(address _lp)
        external
        view
        returns (address book,
            // balances in wei
            uint lpMargin,
            uint totalLpLong,
            uint totalLpShort,
            uint lpRM,
            /// in ETH
            uint bookMinimum,
            /// in basis points as a percent of RM
            /// to convert to notional, we multiply by the leverage ratio
            int16 longFundingRate,
            int16 shortFundingRate,
            uint8 lpCloseFee,
            /** 0 is fine, 1 means book cancels at next settlement
            * 2 means LP burned (which cancels the book at next settlement)
            * 3 book is inactive, no more settling or new positions
            */
            uint8 bookStatus
            )
    {
        book = books[_lp];
        if (book != address(0)) {
            Book b = Book(book);
            lpMargin = b.margin(0);
            totalLpLong = b.margin(1);
            totalLpShort = b.margin(2);
            lpRM = b.margin(3);
            bookMinimum = b.lpMinTakeRM();
            longFundingRate = b.fundingRates(1);
            shortFundingRate = b.fundingRates(0);
            lpCloseFee = b.bookCloseFee();
            bookStatus = b.bookStatus();
        }
    }

    function getSubkData1(address _lp, bytes32 subkID)
        external
        view
        returns (
            address taker,
            /// in wei
            uint takerMargin,
            uint reqMargin
            )
    {
        address book = books[_lp];
        if (book != address(0)) {
            Book b = Book(book);
            (taker, takerMargin, reqMargin) = b.getSubkData1Book(subkID);
        }
    }

    function getSubkData2(address _lp, bytes32 subkID)
        external
        view
        returns (
          /** 0 new, 1 active and rolled over, 2 taker cancelled, 3 LP cancelled,
          * 4 intraweek cancelled, 5 taker burned, 6 taker default/redeemable, 7 inactive/redeemable
          */
            uint8 subkStatus,
          /// for new and expiring subcontracts, either the start or end price that week
            uint8 priceDay,
          /** the LP's closing fee, in basis points as a percent of the RM. The total closing fee
          * is this plus 2.5% of RM, the oracle's fee
          */
            uint8 closeFee,
          /// the funding rate paid by the taker, which may be negative
            int16 fundingRate,
          /// true for taker is long (and thus LP is short)
            bool takerSide
            )
    {
        address book = books[_lp];
        if (book != address(0)) {
            Book b = Book(book);
            (subkStatus, priceDay, closeFee, fundingRate, takerSide)
                = b.getSubkData2Book(subkID);
        }
    }

    function getSettleInfo(address _lp)
        external
        view
        returns (
          /// total number of taker subcontracts, including new, rolled-over, cancelled, and inactive subcontracts
            uint totalLength,
          /// taker subcontracts that are expiring at next settlement
            uint expiringLength,
          /// taker subcontracts that have not yet settled. Such positions cannot be cancelled. The next week,
          /// they will be 'active', and cancelable.
            uint newLength,
          /// time of last book settlement, in hours from 1970, Greenwich Mean Time
            uint lastBookSettleUTC,
          /// this is used for assessing the progress of a settlement when it is too large to be
          /// executed in batch.
            uint settleNumber,
          /// amount of ETH in the LP book
            uint bookBalance,
          /// an LP can close they book en masse, which would push the maturity of the book to 28 days after
          /// the close is instantiated. Takers should take note. A taker does not pay a cancel fee when
          /// the LP cancels their book, but they must then wait until the final settlement
            uint bookMaturityUTC
            )
    {
        address book = books[_lp];
        if (book != address(0)) {
            Book b = Book(book);
            (totalLength, expiringLength, newLength, lastBookSettleUTC, settleNumber,
                bookBalance, bookMaturityUTC) = b.getSettleInfoBook();
        }
    }

    /**
    * This gives the raw asset returns for all potential start and end dates: 5 different returns
    * for new positions (price day to settlement day), and 5 for expiring positions (last settlement to price day)
    * these are posted by the Oracle at the settlemnet price update.
    * They are in % return * Leverage Ratio times 1 ETH,
    * this allows the books to simply apply these numbers to the RM of the various subcontracts to generate the
    * weekly PNL. They are capped at +/- 0.975e18, so that the extreme case of a maximum funding rate, the liability
    * is never greater than 1 ETH. This effectively caps player liability at their RM
    */
    function updateReturns(int[5] memory assetRetNew, int[5] memory assetRetExp)
            public
        {
        require(msg.sender == address(oracle));
        assetReturns[0] = assetRetNew;
        assetReturns[1] = assetRetExp;
        lastOracleSettleTime = now;
    }

    function hourOfDay()
        public
        view
        returns(uint hour1)
    {
        uint nowTemp = now;
    /**
    * 2020 Summer, 1583668800 = March 8 2020 through 1604232000 = November 1 2020
    * 2021 Summer, 1615705200 = March 14 2021 through 1636264800 = November 7 2021
    * 2022 summer, 1647154800 = March 13 2022 through 1667714400 = November 6 2022
    * summer is Daylight Savings Time in the US, where the hour is GMT - 5 in New York City
    * winter is Standard Time in the US, where the hour is GMT - 4 in New York City
    * No takes from 4-5 PM NYC time, so hour == 16 is the exclusion time
    */
        hour1 = (nowTemp % 86400) / 3600 - 5;
        if ((nowTemp > 1583668800 && nowTemp < 1604232000) || (nowTemp > 1615705200 && nowTemp < 1636264800) ||
            (nowTemp > 1647154800 && nowTemp < 1667714400))
            hour1 = hour1 + 1;
    }

    function subzero(uint _a, uint _b)
        internal
        pure
        returns (uint)
    {
        if (_b >= _a) {
            return 0;
        }
        return _a - _b;
    }


}

pragma solidity 0.5.15;

import "./AssetSwap.sol";


contract Book {

    constructor(address user, address admin, uint16 minReqMarg, uint8 closefee,
        int16 frlong, int16 frshort)
        public {
            assetSwap = AssetSwap(admin);
            lp = user;
            lpMinTakeRM = minReqMarg;
            lastBookSettleTime = now;
            bookCloseFee = closefee;
            fundingRates[0] = frshort;
            fundingRates[1] = frlong;
            endOfBookTime = now + 1100 days;
        }

    address public lp;
    AssetSwap public assetSwap;
    /// 0 is actual or total margin, 1 is sum of LP's short takers
    /// 2 is sum of LP's long takers, 3 is the LP's required margin
    /// units an in wei, and refer to the RM, not the notional
    uint[4] public margin;
    uint public lastBookSettleTime;
    uint public burnFactor = 1 ether;
    uint public settleNum;
    int public lpSettleDebitAcct;
    uint public endOfBookTime;
    int16[2] public fundingRates;
    uint16 public lpMinTakeRM;
    uint8 public bookStatus;
    uint8 public bookCloseFee;
    bytes32[][2] public tempContracts;
    bytes32[] public takerContracts;
    mapping(bytes32 => Subcontract) public subcontracts;

    struct Subcontract {
        address taker;
        uint takerMargin;   /// in wei
        uint requiredMargin;     /// in wei
        uint16 index;
        int16 fundingRate;
        uint8 closeFee;
        uint8 subkStatus;
        uint8 priceDay;
        int8 takerSide; /// 1 if long, -1 if short
    }

    modifier onlyAdmin() {
        require(msg.sender == address(assetSwap));
        _;
    }

    function adjustMinRMBook(uint16 _min)
        external
        onlyAdmin
    {
        lpMinTakeRM = _min;
    }

    function updateFeesBook(uint8 newClose, int16 longrate, int16 shortrate)
        external
        onlyAdmin
    {
        fundingRates[0] = shortrate;
        fundingRates[1] = longrate;
        bookCloseFee = newClose;
    }

    function burnTakerBook(bytes32 subkID, address sender, uint msgval)
        external
        onlyAdmin
        returns (uint)
    {
        Subcontract storage k = subcontracts[subkID];
        require(sender == k.taker, "must by party to his subcontract");
        require(settleNum == 0, "not during settlement process");
        require(k.subkStatus < 5, "can only burn active subcontract");
        uint burnFee = k.requiredMargin / 2;
        require(msgval >= burnFee, "Insufficient burn fee");
        burnFee = subzero(msgval, burnFee);
        if (margin[1] > margin[2]) {
            burnFactor = subzero(burnFactor, 1 ether * k.requiredMargin / margin[1]);
        } else {
            burnFactor = subzero(burnFactor, 1 ether * k.requiredMargin / margin[2]);
        }
        k.subkStatus = 5;
        return burnFee;
    }

    function burnLPBook(uint msgval)
        external
        onlyAdmin
        returns (uint)
    {
        require(bookStatus != 2, "can only burn once");
        /// burn fee is 50% of RM
        uint burnFee = margin[3] / 2;
        require(msgval >= burnFee, "Insufficient burn fee");
        burnFee = subzero(msgval, burnFee);
        /** The entire LP RM as a percent of the larger of the long or short
        * side is used to decrement the credits of those at the upcoming settlement
        */
        if (margin[2] > margin[1]) {
            burnFactor = subzero(burnFactor, 1 ether * margin[3] / margin[2]);
        } else {
            burnFactor = subzero(burnFactor, 1 ether * margin[3] / margin[1]);
        }
        bookStatus = 2;
        return burnFee;
    }

    function cancelBook(uint lastOracleSettle, bytes32 subkID, address sender, uint8 _endDay)
        external
        payable
        onlyAdmin
    {
        Subcontract storage k = subcontracts[subkID];
        require(lastOracleSettle < lastBookSettleTime, "Cannot do during settle period");
        require(sender == k.taker || sender == lp, "Canceller not LP or taker");
        /// checks to see if subk already cancelled, as otherwise redundant
        require(k.subkStatus == 1, "redundant or too new");
        uint feeOracle = 250 * k.requiredMargin / 1e4;
        require(msg.value >= (2 * feeOracle), "Insufficient cancel fee");
        uint feeLP = uint(k.closeFee) * k.requiredMargin / 1e4;
        if (sender == k.taker && _endDay == 5) {
            k.subkStatus = 2;  /// regular taker cancel
        } else if (sender == k.taker) {
            require(k.requiredMargin < subzero(margin[0], margin[3]), "Insuff LP RM for immed cancel");
            feeLP = feeOracle;  /// close fee is now max close fee, overriding initial close fee
            k.subkStatus = 4;  /// immediate taker cancel
            k.priceDay = _endDay;  /// this is the end-day of the subcontract's last week
        } else {
            feeOracle = 2 * feeOracle;
            feeLP = subzero(msg.value, feeOracle); /// this is really a refund to the LP, not a fee
            k.subkStatus = 3;  /// LP cancel
        }
        balanceSend(feeOracle, assetSwap.feeAddress());
        tempContracts[1].push(subkID);  /// sets this up to settle as an expiring subcontract
        margin[0] += feeLP;
        k.takerMargin += subzero(msg.value, feeLP + feeOracle);
    }

    function fundLPBook()
        external
        onlyAdmin
        payable
    {
        margin[0] += msg.value;
    }

    function fundTakerBook(bytes32 subkID)
        external
        onlyAdmin
        payable
    {
        Subcontract storage k = subcontracts[subkID];
        require(k.subkStatus < 2);
        k.takerMargin += msg.value;
    }

    function closeBookBook()
        external
        payable
        onlyAdmin
    { /// pays the close fee on the larger side of her book
        uint feeOracle = 250 * (margin[1] + margin[2] - min(margin[1], margin[2])) / 1e4;
        require(msg.value >= feeOracle, "Insufficient cancel fee");
        uint feeOverpay = msg.value - feeOracle;
        balanceSend(feeOracle, assetSwap.feeAddress());
        if (now > endOfBookTime)
        /// this means the next settlement ends this book's activity
            bookStatus = 1;
        else
        /// if initial, needs to be run again in 28 days to complete the shut down
            endOfBookTime = now + 28 days;
        margin[0] += feeOverpay;
    }

    /**
    *We only need look at when the last book settlement because
    * if the LP was at fault, someone could have inactivatedthe LP
    * and received a reward. Thus, the only scenario where a book
    * can be active and the LP not inactivated, is when the oracle has been
    * absent for a week
    */
    function inactiveOracleBook()
        external
        onlyAdmin
        {
        require(now > (lastBookSettleTime + 10 days));
        bookStatus = 3;
    }

    /** if the book was not settled, the LP is held accountable
     * the first counterparty to execute this function will then get a bonus credit of their RM from  *the LP
     * if the LP's total margin is zero, they will get whatever is there
     * after the book is in default all players can redeem their subcontracts
     * After a book is in default, this cannot be executed
     */
    function inactiveLPBook(bytes32 subkID, address sender, uint _lastOracleSettle)
        external
        onlyAdmin
    {

        require(bookStatus != 3);
        Subcontract storage k = subcontracts[subkID];
        require(k.taker == sender);
        require(_lastOracleSettle > lastBookSettleTime);
        require(subzero(now, _lastOracleSettle) > 48 hours);
        uint lpDefFee = min(margin[0], margin[3] / 2);
        margin[0] = subzero(margin[0], lpDefFee);
        margin[3] = 0;
        bookStatus = 3;
        /// annoying, but at least someone good get the negligent LP's money
        k.takerMargin += lpDefFee;
    }

    function redeemBook(bytes32 subkid, address sender)
        external
        onlyAdmin
    {
        Subcontract storage k = subcontracts[subkid];
        require(k.subkStatus > 5 || bookStatus == 3);
        /// redemption can happen if the subcontract has defaulted subkStatus = 6, is inactive subkStatus = 7
        /// or if the book is inactive (bookStatus == 3)
        uint tMargin = k.takerMargin;
        k.takerMargin = 0;
        uint16 index = k.index;
        /// iff the taker defaulted on an active book, they are penalized by
        /// burning RM/2 of their margin
        bool isDefaulted = (k.subkStatus == 6 && bookStatus == 0);
        uint defPay = k.requiredMargin / 2;
        uint lpPayment;
        address tAddress = k.taker;
        /// this pays the lp for the gas and effort of redeeming for the taker
        /// it's just 2 finney. The investor should now see their margin in the
        /// assetSwapBalance, and withdraw from there
        if (sender == lp) {
            lpPayment = tMargin - subzero(tMargin, 2 finney);
            tMargin -= lpPayment;
            margin[0] += lpPayment;
        }
        /** we have to pop the takerLong/Short lists to free up space
        * this involves this little trick, moving the last row to the row we are
        * redeeming and writing it over the redeemed subcontract
        * then we remove the duplicate.
        */
        Subcontract storage lastTaker = subcontracts[takerContracts[takerContracts.length - 1]];
        lastTaker.index = index;
        takerContracts[index] = takerContracts[takerContracts.length - 1];
        takerContracts.pop();
        delete subcontracts[subkid];
        // we only take what is there. It goes to the oracle, so if he's a cheater, you can punish
        /// him more by withholding this payment as well as the fraudulent PNL. If he's not a cheater
        /// then you are just negligent for defaulting and probably were not paying attention, as
        /// you should have know you couldn't cure your margin Friday afternoon before close.
        if (isDefaulted) {
            tMargin = subzero(tMargin, defPay);
            balanceSend(defPay, assetSwap.feeAddress());
        }
        /// money is sent to AssetSwapContract
        balanceSend(tMargin, tAddress);

    }

    /** Settle the rolled over taker sukcontracts
    * @param assetRet the returns for a long contract for a taker for only one
    * start day, as they are all starting on the prior settlement price
    */
    function settleRolling(int assetRet)
        external
        onlyAdmin
    {
        require(settleNum < 2e4, "done with rolling settle");
        int takerRetTemp;
        int lpTemp;
        /// the first settlement function set the settleNum = 1e4, so that is subtracted to
        /// see where we are in the total number of takers in the LP's book
        uint loopCap = min(settleNum - 1e4 + 250, takerContracts.length);
        for (uint i = (settleNum - 1e4); i < loopCap; i++) {
            Subcontract storage k = subcontracts[takerContracts[i]];
            if (k.subkStatus == 1) {
                takerRetTemp = int(k.takerSide) * assetRet * int(k.requiredMargin) / 1
                ether - (int(k.fundingRate) * int(k.requiredMargin) / 1e4);
                lpTemp = lpTemp - takerRetTemp;
                if (takerRetTemp < 0) {
                    k.takerMargin = subzero(k.takerMargin, uint(-takerRetTemp));
                } else {
                    k.takerMargin += uint(takerRetTemp) * burnFactor / 1 ether;
                }
                if (k.takerMargin < k.requiredMargin) {
                    k.subkStatus = 6;
                    if (k.takerSide == 1)
                        margin[2] = subzero(margin[2], k.requiredMargin);
                    else
                        margin[1] = subzero(margin[1], k.requiredMargin);
                }
            }
        }
        settleNum += 250;
        if ((settleNum - 1e4) >= takerContracts.length)
            settleNum = 2e4;
        lpSettleDebitAcct += lpTemp;
    }

    /// this is the fourth and the final of the settlement functions
    function settleFinal()
        external
        onlyAdmin
    {
        require(settleNum == 3e4, "not done with all the subcontracts");
        /// this take absolute value of (long - short) to update the LP's RM
        if (margin[2] > margin[1])
            margin[3] = margin[2] - margin[1];
        else
            margin[3] = margin[1] - margin[2];
        if (lpSettleDebitAcct < 0)
            margin[0] = subzero(margin[0], uint(-lpSettleDebitAcct));
        else
        /// if the lpSettleDebitAcct is positive, we add it, but first apply the burnFactor
        /// to remove the burner's pnl in a pro-rata way
            margin[0] = margin[0] + uint(lpSettleDebitAcct) * burnFactor / 1 ether;
        if (bookStatus != 0) {
            bookStatus = 3;
            margin[3] = 0;
        } else if (margin[0] < margin[3]) {
            // default scenario for LP
            bookStatus = 3;
            uint defPay = min(margin[0], margin[3] / 2);
            margin[0] = subzero(margin[0], defPay);
            balanceSend(defPay, assetSwap.feeAddress());
            margin[3] = 0;
        }
        // resets for our next book settlement
        lpSettleDebitAcct = 0;
        lastBookSettleTime = now;
        settleNum = 0;
        delete tempContracts[1];
        delete tempContracts[0];
        burnFactor = 1 ether;
    }

    /** Create a new Taker long subcontract of the given parameters
    * @param taker the address of the party on the other side of the contract
    * @param rM the ETH amount in the required margin
    * isTakerLong is +1 if taker is long, 0 if taker is short
    * @return subkID the id of the newly created subcontract
    */
    function takeBook(address taker, uint rM, uint lastOracleSettle, uint8 _priceDay, uint isTakerLong)
        external
        payable
        onlyAdmin
        returns (bytes32 subkID)
    {
        require(bookStatus == 0, "book is no longer taking positions");
        require((now + 28 days) < endOfBookTime, "book closing soon");
        require(rM >= uint(lpMinTakeRM) * 1 ether, "must be greater than book min");
        require(lastOracleSettle < lastBookSettleTime, "Cannot do during settle period");
        uint availableMargin = subzero(margin[0] / 2 + margin[2 - isTakerLong], margin[1 + isTakerLong]);
        require(rM <= availableMargin && (margin[0] - margin[3]) > rM);
        require(rM <= availableMargin);
        margin[1 + isTakerLong] += rM;
        Subcontract memory order;
        order.requiredMargin = rM;
        order.takerMargin = msg.value;
        order.taker = taker;
        order.takerSide = int8(2 * isTakerLong - 1);
        margin[3] += rM;
        subkID = keccak256(abi.encodePacked(now, takerContracts.length));
        order.index = uint16(takerContracts.length);
        order.priceDay = _priceDay;
        order.fundingRate = fundingRates[isTakerLong];
        order.closeFee = bookCloseFee;
        subcontracts[subkID] = order;
        takerContracts.push(subkID);
        tempContracts[0].push(subkID);
        return subkID;
    }

    /** Withdrawing margin
    * reverts if during the settle period, oracleSettleTime > book settle time
    * also must leave total margin greater than the required margin
    */
    function withdrawLPBook(uint amount, uint lastOracleSettle)
        external
        onlyAdmin
    {
        require(margin[0] >= amount, "Cannot withdraw more than the margin");
         // if book is dead LP can take everything left, if not dead, can only take up to RM
        if (bookStatus != 3) {
            require(subzero(margin[0], amount) >= margin[3], "Cannot w/d more than excess margin");
            require(lastOracleSettle < lastBookSettleTime, "Cannot w/d during settle period");
        }
        margin[0] = subzero(margin[0], amount);
        balanceSend(amount, lp);
    }

    function withdrawTakerBook(bytes32 subkID, uint amount, uint lastOracleSettle, address sender)
        external
        onlyAdmin
    {
        require(lastOracleSettle < lastBookSettleTime, "Cannot w/d during settle period");
        Subcontract storage k = subcontracts[subkID];
        require(k.subkStatus < 6, "subk dead, must redeem");
        require(sender == k.taker, "Must be taker to call this function");
        require(subzero(k.takerMargin, amount) >= k.requiredMargin, "cannot w/d more than excess margin");
        k.takerMargin = subzero(k.takerMargin, amount);
        balanceSend(amount, k.taker);
    }

    function getSubkData1Book(bytes32 subkID)
        external
        view
        returns (address takerAddress, uint takerMargin, uint requiredMargin)
    {   Subcontract memory k = subcontracts[subkID];
        takerAddress = k.taker;
        takerMargin = k.takerMargin;
        requiredMargin = k.requiredMargin;
    }

    function getSubkData2Book(bytes32 subkID)
        external
        view
        returns (uint8 kStatus, uint8 priceDay, uint8 closeFee, int16 fundingRate, bool takerSide)
    {   Subcontract memory k = subcontracts[subkID];
        kStatus = k.subkStatus;
        priceDay = k.priceDay;
        closeFee = k.closeFee;
        fundingRate = k.fundingRate;
        if (k.takerSide == 1)
            takerSide = true;
    }

    function getSettleInfoBook()
        external
        view
        returns (uint totalLength, uint expiringLength, uint newLength, uint lastBookSettleUTC, uint settleNumber,
            uint bookBalance, uint bookMaturityUTC)
    {
        totalLength = takerContracts.length;
        expiringLength = tempContracts[1].length;
        newLength = tempContracts[0].length;
        lastBookSettleUTC = lastBookSettleTime;
        settleNumber = settleNum;
        bookMaturityUTC = endOfBookTime;
        bookBalance = address(this).balance;
    }

    /** Settle the taker long sukcontracts
    * priceDay Expiring returns use the return from the last settle to the priceDay, which
    * for regular cancels is just 5, the most recent settlement price
    * this is the first of 4 settlement functions
    * */
    function settleExpiring(int[5] memory assetRetExp)
        public
        onlyAdmin
        {
        require(bookStatus != 3 && settleNum < 1e4, "done with expiry settle");
        int takerRetTemp;
        int lpTemp;
        uint loopCap = min(settleNum + 200, tempContracts[1].length);
        for (uint i = settleNum; i < loopCap; i++) {
            Subcontract storage k = subcontracts[tempContracts[1][i]];
            takerRetTemp = int(k.takerSide) * assetRetExp[k.priceDay - 1] * int(k.requiredMargin) / 1 ether -
            (int(k.fundingRate) * int(k.requiredMargin) / 1e4);
            lpTemp -= takerRetTemp;
            if (takerRetTemp < 0) {
                k.takerMargin = subzero(k.takerMargin, uint(-takerRetTemp));
            } else {
                k.takerMargin += uint(takerRetTemp) * burnFactor / 1 ether;
            }
            if (k.takerSide == 1)
                margin[2] = subzero(margin[2], k.requiredMargin);
            else
                margin[1] = subzero(margin[1], k.requiredMargin);
            k.subkStatus = 7;
        }
        settleNum += 200;
        if (settleNum >= tempContracts[1].length)
            settleNum = 1e4;
        lpSettleDebitAcct += lpTemp;
    }

    /// this is the third of the settlement functions
    function settleNew(int[5] memory assetRets)
        public
        onlyAdmin
    {
        require(settleNum < 3e4, "done with new settle");
        int takerRetTemp;
        int lpTemp;
        /// after running the second settlement function, settleRolling, it is set to 2e4
        uint loopCap = min(settleNum - 2e4 + 200, tempContracts[0].length);
        for (uint i = (settleNum - 2e4); i < loopCap; i++) {
            Subcontract storage k = subcontracts[tempContracts[0][i]];
            /// subkStatus set to 'active' which means it can be cancelled
            /// it will also be settled in the settleRolling if not cancelled
            /// using the more efficient settlement that uses just one return, from last to most recent settlement
            k.subkStatus = 1;
            if (k.priceDay != 5) {
                takerRetTemp = int(k.takerSide) * assetRets[k.priceDay] * int(k.requiredMargin) / 1
                ether - (int(k.fundingRate) * int(k.requiredMargin) / 1e4);
                lpTemp = lpTemp - takerRetTemp;
                if (takerRetTemp < 0) {
                    k.takerMargin = subzero(k.takerMargin, uint(-takerRetTemp));
                } else {
                    k.takerMargin += uint(takerRetTemp) * burnFactor / 1 ether;
                }
                if (k.takerMargin < k.requiredMargin) {
                    k.subkStatus = 6;
                    if (k.takerSide == 1)
                        margin[2] = subzero(margin[2], k.requiredMargin);
                    else
                        margin[1] = subzero(margin[1], k.requiredMargin);
                }
                k.priceDay = 5;
            }
        }
        settleNum += 200;
        if (settleNum >= tempContracts[0].length)
            settleNum = 3e4;
        lpSettleDebitAcct += lpTemp;
    }

    /// Function to send balances back to the Assetswap contract
    function balanceSend(uint amount, address recipient)
        internal
    {
        assetSwap.balanceInput.value(amount)(recipient);
    }

    /** Utility function to find the minimum of two unsigned values
    * @notice returns the first parameter if they are equal
    */
    function min(uint a, uint b)
        internal
        pure
        returns (uint)
    {
        if (a <= b)
            return a;
        else
            return b;
    }

    function subzero(uint _a, uint _b)
        internal
        pure
        returns (uint)
    {
        if (_b >= _a)
            return 0;
        else
            return _a - _b;
    }


}

pragma solidity 0.5.15;

import "./AssetSwap.sol";


contract Oracle {

    constructor (uint ethPrice, uint spxPrice, uint btcPrice) public {
        admins[msg.sender] = true;
        prices[0][5] = ethPrice;
        prices[1][5] = spxPrice;
        prices[2][5] = btcPrice;
        lastUpdateTime = now;
        lastSettleTime = now;
        currentDay = 5;
        levRatio[0] = 250;  // ETH contract 2.5 leverage
        levRatio[1] = 1000; /// SPX contract 10.0 leverage
        levRatio[2] = 250;  // BTC contract 2.5 leverage
    }

    address[3] public assetSwaps;
    uint[6][3] private prices;
    uint public lastUpdateTime;
    uint public lastSettleTime;
    int[3] public levRatio;
    uint8 public currentDay;
    bool public nextUpdateSettle;
    mapping(address => bool) public admins;
    mapping(address => bool) public readers;

    event PriceUpdated(
        uint ethPrice,
        uint spxPrice,
        uint btcPrice,
        uint eUTCTime,
        uint eDayNumber,
        bool eisCorrection
    );

    modifier onlyAdmin() {
        require(admins[msg.sender]);
        _;
    }
    /** Grant write priviledges to a user,
    * mainly intended for when the admin wants to switch accounts, ie, paired with a removal
    */

    function addAdmin(address newAdmin)
        external
        onlyAdmin
    {
        admins[newAdmin] = true;
    }

    /** Grant priviledges to a user accessing price data on the blockchain
    * @param newReader the address. Any reader is thus approved by the oracle/admin
    * useful for new contracts that use this oracle, in that the oracle would not
    * need to create a new oracle contract for ETH prices
    */
    function addReaders(address newReader)
        external
        onlyAdmin
    {
        readers[newReader] = true;
    }
    /** this can only be done once, so this oracle is solely for working with
    * three AssetSwap contracts
    * assetswap 0 is the ETH, at 2.5 leverage
    * assetswap 1 is the SPX, at 10x leverage
    * assetswap 2 is the BTC, at 2.5 leverage
    */

    function addAssetSwaps(address newAS0, address newAS1, address newAS2)
        external
        onlyAdmin
    {
        require(assetSwaps[0] == address(0));
        assetSwaps[0] = newAS0;
        assetSwaps[1] = newAS1;
        assetSwaps[2] = newAS2;
        readers[newAS0] = true;
        readers[newAS1] = true;
        readers[newAS2] = true;
    }

    function removeAdmin(address toRemove)
        external
        onlyAdmin
    {
        require(toRemove != msg.sender);
        admins[toRemove] = false;
    }
    /** Quickly fix an erroneous price, or correct the fact that 50% movements are
    * not allowed in the standard price input
    * this must be called within 60 minutes of the initial price update occurence
    */

    function editPrice(uint _ethprice, uint _spxprice, uint _btcprice)
        external
        onlyAdmin
    {
        require(now < lastUpdateTime + 60 minutes);
        prices[0][currentDay] = _ethprice;
        prices[1][currentDay] = _spxprice;
        prices[2][currentDay] = _btcprice;
        emit PriceUpdated(_ethprice, _spxprice, _btcprice, now, currentDay, true);
    }

    function updatePrices(uint ethp, uint spxp, uint btcp, bool _newFinalDay)
        external
        onlyAdmin
    {

             /// no updates within 20 hours per day
        require(now > lastUpdateTime + 20 hours);
            /** can't be executed if the next price should be a settlement price
            * settlement prices are special because they need to update the asset returns
            * and sent to the AssetSwap contracts
            */
        require(!nextUpdateSettle);
         /// after settlement update, at least 48 hours until new prices are posted
        require(now > lastSettleTime + 48 hours, "too soon after last settle");
          /// prevents faulty prices, as stale prices are a common source of bad prices.
        require(ethp != prices[0][currentDay] && spxp != prices[1][currentDay] && btcp != prices[2][currentDay]);
            /// extreme price movements are probably mistakes. They can be posted
          /// but only via a 'price edit' that must be done within 60 minutes of the initial update
        require((ethp * 10 < prices[0][currentDay] * 15) && (ethp * 10 > prices[0][currentDay] * 5));
        require((spxp * 10 < prices[1][currentDay] * 15) && (spxp * 10 > prices[1][currentDay] * 5));
        require((btcp * 10 < prices[2][currentDay] * 15) && (btcp * 10 > prices[2][currentDay] * 5));
        if (currentDay == 5) {
            currentDay = 1;
            nextUpdateSettle = false;
        } else {
            currentDay += 1;
            nextUpdateSettle = _newFinalDay;
        }
        if (currentDay == 4)
            nextUpdateSettle = true;
        updatePriceSingle(0, ethp);
        updatePriceSingle(1, spxp);
        updatePriceSingle(2, btcp);
        emit PriceUpdated(ethp, spxp, btcp, now, currentDay, false);
        lastUpdateTime = now;
    }

    function settlePrice(uint ethp, uint spxp, uint btcp)
        external
        onlyAdmin
    {
        require(nextUpdateSettle);
        require(now > lastUpdateTime + 20 hours);
        require(ethp != prices[0][currentDay] && spxp != prices[1][currentDay] && btcp != prices[2][currentDay]);
        require((ethp * 10 < prices[0][currentDay] * 15) && (ethp * 10 > prices[0][currentDay] * 5));
        require((spxp * 10 < prices[1][currentDay] * 15) && (spxp * 10 > prices[1][currentDay] * 5));
        require((btcp * 10 < prices[2][currentDay] * 15) && (btcp * 10 > prices[2][currentDay] * 5));
        currentDay = 5;
        nextUpdateSettle = false;
        updatePriceSingle(0, ethp);
        updatePriceSingle(1, spxp);
        updatePriceSingle(2, btcp);
        int[5] memory assetReturnsNew;
        int[5] memory assetReturnsExpiring;
        int cap = 975 * 1 ether / 1000;
        for (uint j = 0; j < 3; j++) {
                  /**  asset return from start day j to settle day (ie, day 5),
                  * and also the prior settle day (day 0) to the end day.
                  * returns are normalized from 0.975 ether to - 0.975 ether
                  * where 0.9 ether is a 90% RM profit for the long taker,
                  * 0.2 ether means a 20% of RM profit for the long taker.
                  */
            for (uint i = 0; i < 5; i++) {
                if (prices[0][i] != 0) {
                    int assetRetFwd = int(prices[j][5] * 1 ether / prices[j][i]) - 1 ether;
                    assetReturnsNew[i] = assetRetFwd * int(prices[0][i]) * levRatio[j] /
                        int(prices[0][5]) / 100;
                /** as funding rates are maxed out at 2.5% of RM, the return must
                * max out at 97.5% of RM so that required margins cover all
                * potential payment scenarios
                */
                    assetReturnsNew[i] = bound(assetReturnsNew[i], cap);
                }
                if (prices[0][i+1] != 0) {
                    int assetRetBack = int(prices[j][i+1] * 1 ether / prices[j][0]) - 1 ether;
                    assetReturnsExpiring[i] = assetRetBack * int(prices[0][0]) * levRatio[j] /
                        int(prices[0][i+1]) / 100;

                    assetReturnsExpiring[i] = bound(assetReturnsExpiring[i], cap);
                }
            }
    /// this updates the AssetSwap contract with the vector of returns,
    /// one for each day of the week
            AssetSwap asw = AssetSwap(assetSwaps[j]);
            asw.updateReturns(assetReturnsNew, assetReturnsExpiring);
        }
        lastSettleTime = now;
        emit PriceUpdated(ethp, spxp, btcp, now, currentDay, false);
        lastUpdateTime = now;
    }
    /** Return the entire current price array for a given asset
    * @param _assetID the asset id of the desired asset
    * @return _priceHist the price array in USD for the asset
    * @dev only the admin and addresses granted readership may call this function
    * While only an admin or reader can access this within the EVM
    * anyone can access these prices outside the EVM
    * eg, in javascript: OracleAddress.methods.getUsdPrices.cacheCall(0, { 'from': 'AdminAddress' }
    */

    function getUsdPrices(uint _assetID)
        public
        view
        returns (uint[6] memory _priceHist)
    {
        require(admins[msg.sender] || readers[msg.sender]);
        _priceHist = prices[_assetID];
    }

        /** Return only the latest prices
        * @param _assetID the asset id of the desired asset
        * @return _price the latest price of the given asset
        * @dev only the admin or a designated reader may call this function within the EVM
        */
    function getCurrentPrice(uint _assetID)
        public
        view
        returns (uint _price)
    {
        require(admins[msg.sender] || readers[msg.sender]);
        _price = prices[_assetID][currentDay];
    }

    /**
    * @return startDay relevant for trades done now
    * pulls the day relevant for new AssetSwap subcontracts
    * startDay 2 means the 2 slot (ie, the third) of prices will be the initial
    * price for the subcontract. As 5 is the top slot, and rolls into slot 0
    * the next week, the next pricing day is 1 when the current day == 5
    * (this would be a weekend or Monday morning)
    */
    function getStartDay()
        public
        view
        returns (uint8 _startDay)
    {
        if (nextUpdateSettle) {
            _startDay = 5;
        } else if (currentDay == 5) {
            _startDay = 1;
        } else {
            _startDay = currentDay + 1;
        }
    }

    function updatePriceSingle(uint _assetID, uint _price)
        internal
    {
        if (currentDay == 1) {
            uint[6] memory newPrices;
            newPrices[0] = prices[_assetID][5];
            newPrices[1] = _price;
            prices[_assetID] = newPrices;
        } else {
            prices[_assetID][currentDay] = _price;
        }
    }

    function bound(int a, int b)
        internal
        pure
        returns (int)
    {
        if (a > b)
            a = b;
        if (a < -b)
            a = -b;
        return a;
    }

}

pragma solidity 0.5.15;

import "./Book.sol";
import "./Oracle.sol";


contract AssetSwap {

    constructor (address priceOracle, int _levRatio)
        public {
            administrators[msg.sender] = true;
            feeAddress = msg.sender;
            oracle = Oracle(priceOracle);
            leverageRatio = _levRatio;
        }

    Oracle public oracle;
    int[5][2] public assetReturns; /// these are   pushed by the oracle each week
    int public leverageRatio;
    uint public lastOracleSettleTime; /// updates at time of oracle settlement.
    /// Used a lot so this is written to the contract
    mapping(address => address) public books;  /// LP eth address to book contract address
    mapping(address => uint) public assetSwapBalance;  /// how ETH is ultimately withdrawn
    mapping(address => bool) public administrators;  /// gives user right to key functions
    address payable public feeAddress;   /// address for oracle fees PAYABLE!!

    event SubkTracker(
        address indexed eLP,
        address indexed eTaker,
        bytes32 eSubkID,
        bool eisOpen);

    event PauseOnTakes(
        bool openForNewTakes);

    event BurnHist(
        address eLP,
        bytes32 eSubkID,
        address eBurner,
        uint eTime);

    event LPNewBook(
        address indexed eLP,
        address eLPBook);

    event RatesUpdated(
        address indexed eLP,
        uint8 closefee,
        int16 longFundingRate,
        int16 shortFundingRate
        );

    modifier onlyAdmin() {
        require(administrators[msg.sender], "admin only");
        _;
    }

    function removeAdmin(address toRemove)
        external
        onlyAdmin
    {
        require(toRemove != msg.sender, "You may not remove yourself as an admin.");
        administrators[toRemove] = false;
    }

    /** Grant administrator priviledges to a user
    * @param newAdmin the address to promote
    */
    function addAdmin(address newAdmin)
        external
        onlyAdmin
    {
        administrators[newAdmin] = true;
    }

    function adjustMinRM(uint16 _min)
        external
    {
        require(books[msg.sender] != address(0), "User must have a book");
        require(_min >= 1);
        Book b = Book(books[msg.sender]);
        b.adjustMinRMBook(_min);
    }

    /** data are input in basis points as a percent of national
    * thus 10 is 0.1% of notional, which when applied to the crypto
    * with 2.5 leverage, generates a 0.25% of RM charge. funding rates
    * can be negative, which implies the taker receives a payment.
    */
    function updateFees(uint newClose, int frLong, int frShort)
        external
    {
        require(books[msg.sender] != address(0), "User must have a book");
        /// data are input as basis points of notional, adjusted to bps of RM to simplify calculations
        int longRate = frLong * leverageRatio / 1e2;
        int shortRate = frShort * leverageRatio / 1e2;
        uint closefee = newClose * uint(leverageRatio) / 1e2;
        /// fees are capped to avoid predatory pricing that would potentially besmirch OracleSwap's reputation
        require(closefee <= 250);
        require(longRate <= 250 && longRate >= -250);
        require(shortRate <= 250 && shortRate >= -250);
        Book b = Book(books[msg.sender]);
        b.updateFeesBook(uint8(closefee), int16(longRate), int16(shortRate));
        emit RatesUpdated(msg.sender, uint8(closefee), int16(longRate), int16(shortRate));
    }

    function changeFeeAddress(address payable newAddress)
        external
        onlyAdmin
    {
        feeAddress = newAddress;
    }

    function balanceInput(address recipient)
            external
            payable
    {
        assetSwapBalance[recipient] += msg.value;
    }

    /** fees are in basis points of national, as in the case when updating the fees
    * minimum RM is in ETH, so 4 would imply a minimum RM of 4 ETH
    */
    function createBook(uint16 _min, uint _closefee, int frLong, int frShort)
        external
        payable
        returns (address newBook)
    {
        require(books[msg.sender] == address(0), "User must not have a preexisting book");
        require(msg.value >= uint(_min) * 10 ether, "Must prep for book");
        require(_min >= 1);
        int16 longRate = int16(frLong * leverageRatio / 1e2);
        int16 shortRate = int16(frShort * leverageRatio / 1e2);
        uint8 closefee = uint8(_closefee * uint(leverageRatio) / 1e2);
        require(longRate <= 250 && longRate >= -250);
        require(shortRate <= 250 && shortRate >= -250);
        require(closefee <= 250);
        books[msg.sender] = address(new Book(msg.sender, address(this), _min, closefee, longRate, shortRate));
        Book b = Book(books[msg.sender]);
        b.fundLPBook.value(msg.value)();
        emit LPNewBook(msg.sender, books[msg.sender]);
        return books[msg.sender];
    }

    function fundLP(address _lp)
        external
        payable
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.fundLPBook.value(msg.value)();
    }

    function fundTaker(address _lp, bytes32 subkID)
        external
        payable
        {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.fundTakerBook.value(msg.value)(subkID);
    }

    function burnTaker(address _lp, bytes32 subkID)
        external
        payable
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        uint refund = b.burnTakerBook(subkID, msg.sender, msg.value);
        emit BurnHist(_lp, subkID, msg.sender, now);
        assetSwapBalance[msg.sender] += refund;
    }

    function burnLP()
        external
        payable
    {
        require(books[msg.sender] != address(0));
        Book b = Book(books[msg.sender]);
        uint refund = b.burnLPBook(msg.value);
        bytes32 abcnull;
        emit BurnHist(msg.sender, abcnull, msg.sender, now);
        assetSwapBalance[msg.sender] += refund;
    }

    function cancel(address _lp, bytes32 subkID, bool closeNow)
        external
        payable
    {
        Book b = Book(books[_lp]);
        uint8 priceDay = oracle.getStartDay();
        uint8 endDay = 5;
        if (closeNow)
            endDay = priceDay;
        b.cancelBook.value(msg.value)(lastOracleSettleTime, subkID, msg.sender, endDay);
    }

    function closeBook(address _lp)
        external
        payable
    {
        require(msg.sender == _lp);
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.closeBookBook.value(msg.value)();
    }

    function redeem(address _lp, bytes32 subkID)
        external
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.redeemBook(subkID, msg.sender);
        emit SubkTracker(_lp, msg.sender, subkID, false);
    }

    function settleParts(address _lp)
        external
        returns (bool isComplete)
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        uint lastBookSettleTime = b.lastBookSettleTime();
        require(now > (lastOracleSettleTime + 24 hours));
        require(lastOracleSettleTime > lastBookSettleTime, "one settle per week");
        uint settleNumb = b.settleNum();
        if (settleNumb < 1e4) {
            b.settleExpiring(assetReturns[1]);
        } else if (settleNumb < 2e4) {
            b.settleRolling(assetReturns[0][0]);
        } else if (settleNumb < 3e4) {
            b.settleNew(assetReturns[0]);
        } else if (settleNumb == 3e4) {
            b.settleFinal();
            isComplete = true;
        }
    }

    function settleBatch(address _lp)
        external
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        uint lastBookSettleTime = b.lastBookSettleTime();
        require(now > (lastOracleSettleTime + 24 hours));
        require(lastOracleSettleTime > lastBookSettleTime, "one settle per week");
        /// the 5x1 vector of returns in units of ether, where 0.6 is a +60% of RM payoff,
        /// -0.6 is a -60% of RM payoff. The refer to initial price days to settlement day
        b.settleExpiring(assetReturns[1]);
        /// this is the settle to settle return
        b.settleRolling(assetReturns[0][0]);
        /// this is the return from the last settlement day to the price day
        /// for regular closes, the price day == 5, so it is a settlement to settlement return
        b.settleNew(assetReturns[0]);
        b.settleFinal();
    }

    function take(address _lp, uint rm, bool isTakerLong)
        external
        payable
        returns (bytes32 newsubkID)
    {
        rm = rm * 1 ether;
        require(msg.value >= 3 * rm / 2, "Insuffient ETH for your RM");
        require(hourOfDay() != 16, "Cannot take during 4 PM ET hour");
        uint takerLong;
        if (isTakerLong)
            takerLong = 1;
        else
            takerLong = 0;
        /// starting price is taken from the oracle contract based on what the next price day is
        uint8 priceDay = oracle.getStartDay();
        Book book = Book(books[_lp]);
        newsubkID = book.takeBook.value(msg.value)(msg.sender, rm, lastOracleSettleTime, priceDay, takerLong);
        emit SubkTracker(_lp, msg.sender, newsubkID, true);
    }

    /** withdraw amounts are in finneys. Thus, 1234 is 1.234 ETH

    */
    function withdrawLP(uint amount)
        external
    {
        require(amount > 0);
        require(books[msg.sender] != address(0));
        Book b = Book(books[msg.sender]);
        amount = 1 finney * amount;
        b.withdrawLPBook(amount, lastOracleSettleTime);
    }

    function withdrawTaker(uint amount, address _lp, bytes32 subkID)
        external
    {
        require(amount > 0);
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        amount = 1 finney * amount;
        b.withdrawTakerBook(subkID, amount, lastOracleSettleTime, msg.sender);
    }
    /// one can withdraw from one's assetSwap balance at any time. It can only send the entire amount

    function withdrawFromAssetSwap()
        external
    {
        uint amount = assetSwapBalance[msg.sender];
        require(amount > 0);
        assetSwapBalance[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    function inactiveOracle(address _lp)
        external
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.inactiveOracleBook();
    }

    function inactiveLP(address _lp, bytes32 subkID)
        external
    {
        require(books[_lp] != address(0));
        Book b = Book(books[_lp]);
        b.inactiveLPBook(subkID, msg.sender, lastOracleSettleTime);
    }

    function getBookData(address _lp)
        external
        view
        returns (address book,
            // balances in wei
            uint lpMargin,
            uint totalLpLong,
            uint totalLpShort,
            uint lpRM,
            /// in ETH
            uint bookMinimum,
            /// in basis points as a percent of RM
            /// to convert to notional, we multiply by the leverage ratio
            int16 longFundingRate,
            int16 shortFundingRate,
            uint8 lpCloseFee,
            /** 0 is fine, 1 means book cancels at next settlement
            * 2 means LP burned (which cancels the book at next settlement)
            * 3 book is inactive, no more settling or new positions
            */
            uint8 bookStatus
            )
    {
        book = books[_lp];
        if (book != address(0)) {
            Book b = Book(book);
            lpMargin = b.margin(0);
            totalLpLong = b.margin(1);
            totalLpShort = b.margin(2);
            lpRM = b.margin(3);
            bookMinimum = b.lpMinTakeRM();
            longFundingRate = b.fundingRates(1);
            shortFundingRate = b.fundingRates(0);
            lpCloseFee = b.bookCloseFee();
            bookStatus = b.bookStatus();
        }
    }

    function getSubkData1(address _lp, bytes32 subkID)
        external
        view
        returns (
            address taker,
            /// in wei
            uint takerMargin,
            uint reqMargin
            )
    {
        address book = books[_lp];
        if (book != address(0)) {
            Book b = Book(book);
            (taker, takerMargin, reqMargin) = b.getSubkData1Book(subkID);
        }
    }

    function getSubkData2(address _lp, bytes32 subkID)
        external
        view
        returns (
          /** 0 new, 1 active and rolled over, 2 taker cancelled, 3 LP cancelled,
          * 4 intraweek cancelled, 5 taker burned, 6 taker default/redeemable, 7 inactive/redeemable
          */
            uint8 subkStatus,
          /// for new and expiring subcontracts, either the start or end price that week
            uint8 priceDay,
          /** the LP's closing fee, in basis points as a percent of the RM. The total closing fee
          * is this plus 2.5% of RM, the oracle's fee
          */
            uint8 closeFee,
          /// the funding rate paid by the taker, which may be negative
            int16 fundingRate,
          /// true for taker is long (and thus LP is short)
            bool takerSide
            )
    {
        address book = books[_lp];
        if (book != address(0)) {
            Book b = Book(book);
            (subkStatus, priceDay, closeFee, fundingRate, takerSide)
                = b.getSubkData2Book(subkID);
        }
    }

    function getSettleInfo(address _lp)
        external
        view
        returns (
          /// total number of taker subcontracts, including new, rolled-over, cancelled, and inactive subcontracts
            uint totalLength,
          /// taker subcontracts that are expiring at next settlement
            uint expiringLength,
          /// taker subcontracts that have not yet settled. Such positions cannot be cancelled. The next week,
          /// they will be 'active', and cancelable.
            uint newLength,
          /// time of last book settlement, in hours from 1970, Greenwich Mean Time
            uint lastBookSettleUTC,
          /// this is used for assessing the progress of a settlement when it is too large to be
          /// executed in batch.
            uint settleNumber,
          /// amount of ETH in the LP book
            uint bookBalance,
          /// an LP can close they book en masse, which would push the maturity of the book to 28 days after
          /// the close is instantiated. Takers should take note. A taker does not pay a cancel fee when
          /// the LP cancels their book, but they must then wait until the final settlement
            uint bookMaturityUTC
            )
    {
        address book = books[_lp];
        if (book != address(0)) {
            Book b = Book(book);
            (totalLength, expiringLength, newLength, lastBookSettleUTC, settleNumber,
                bookBalance, bookMaturityUTC) = b.getSettleInfoBook();
        }
    }

    /**
    * This gives the raw asset returns for all potential start and end dates: 5 different returns
    * for new positions (price day to settlement day), and 5 for expiring positions (last settlement to price day)
    * these are posted by the Oracle at the settlemnet price update.
    * They are in % return * Leverage Ratio times 1 ETH,
    * this allows the books to simply apply these numbers to the RM of the various subcontracts to generate the
    * weekly PNL. They are capped at +/- 0.975e18, so that the extreme case of a maximum funding rate, the liability
    * is never greater than 1 ETH. This effectively caps player liability at their RM
    */
    function updateReturns(int[5] memory assetRetNew, int[5] memory assetRetExp)
            public
        {
        require(msg.sender == address(oracle));
        assetReturns[0] = assetRetNew;
        assetReturns[1] = assetRetExp;
        lastOracleSettleTime = now;
    }

    function hourOfDay()
        public
        view
        returns(uint hour1)
    {
        uint nowTemp = now;
    /**
    * 2020 Summer, 1583668800 = March 8 2020 through 1604232000 = November 1 2020
    * 2021 Summer, 1615705200 = March 14 2021 through 1636264800 = November 7 2021
    * 2022 summer, 1647154800 = March 13 2022 through 1667714400 = November 6 2022
    * summer is Daylight Savings Time in the US, where the hour is GMT - 5 in New York City
    * winter is Standard Time in the US, where the hour is GMT - 4 in New York City
    * No takes from 4-5 PM NYC time, so hour == 16 is the exclusion time
    */
        hour1 = (nowTemp % 86400) / 3600 - 5;
        if ((nowTemp > 1583668800 && nowTemp < 1604232000) || (nowTemp > 1615705200 && nowTemp < 1636264800) ||
            (nowTemp > 1647154800 && nowTemp < 1667714400))
            hour1 = hour1 + 1;
    }

    function subzero(uint _a, uint _b)
        internal
        pure
        returns (uint)
    {
        if (_b >= _a) {
            return 0;
        }
        return _a - _b;
    }


}

pragma solidity 0.5.15;

import "./AssetSwap.sol";


contract Book {

    constructor(address user, address admin, uint16 minReqMarg, uint8 closefee,
        int16 frlong, int16 frshort)
        public {
            assetSwap = AssetSwap(admin);
            lp = user;
            lpMinTakeRM = minReqMarg;
            lastBookSettleTime = now;
            bookCloseFee = closefee;
            fundingRates[0] = frshort;
            fundingRates[1] = frlong;
            endOfBookTime = now + 1100 days;
        }

    address public lp;
    AssetSwap public assetSwap;
    /// 0 is actual or total margin, 1 is sum of LP's short takers
    /// 2 is sum of LP's long takers, 3 is the LP's required margin
    /// units an in wei, and refer to the RM, not the notional
    uint[4] public margin;
    uint public lastBookSettleTime;
    uint public burnFactor = 1 ether;
    uint public settleNum;
    int public lpSettleDebitAcct;
    uint public endOfBookTime;
    int16[2] public fundingRates;
    uint16 public lpMinTakeRM;
    uint8 public bookStatus;
    uint8 public bookCloseFee;
    bytes32[][2] public tempContracts;
    bytes32[] public takerContracts;
    mapping(bytes32 => Subcontract) public subcontracts;

    struct Subcontract {
        address taker;
        uint takerMargin;   /// in wei
        uint requiredMargin;     /// in wei
        uint16 index;
        int16 fundingRate;
        uint8 closeFee;
        uint8 subkStatus;
        uint8 priceDay;
        int8 takerSide; /// 1 if long, -1 if short
    }

    modifier onlyAdmin() {
        require(msg.sender == address(assetSwap));
        _;
    }

    function adjustMinRMBook(uint16 _min)
        external
        onlyAdmin
    {
        lpMinTakeRM = _min;
    }

    function updateFeesBook(uint8 newClose, int16 longrate, int16 shortrate)
        external
        onlyAdmin
    {
        fundingRates[0] = shortrate;
        fundingRates[1] = longrate;
        bookCloseFee = newClose;
    }

    function burnTakerBook(bytes32 subkID, address sender, uint msgval)
        external
        onlyAdmin
        returns (uint)
    {
        Subcontract storage k = subcontracts[subkID];
        require(sender == k.taker, "must by party to his subcontract");
        require(settleNum == 0, "not during settlement process");
        require(k.subkStatus < 5, "can only burn active subcontract");
        uint burnFee = k.requiredMargin / 2;
        require(msgval >= burnFee, "Insufficient burn fee");
        burnFee = subzero(msgval, burnFee);
        if (margin[1] > margin[2]) {
            burnFactor = subzero(burnFactor, 1 ether * k.requiredMargin / margin[1]);
        } else {
            burnFactor = subzero(burnFactor, 1 ether * k.requiredMargin / margin[2]);
        }
        k.subkStatus = 5;
        return burnFee;
    }

    function burnLPBook(uint msgval)
        external
        onlyAdmin
        returns (uint)
    {
        require(bookStatus != 2, "can only burn once");
        /// burn fee is 50% of RM
        uint burnFee = margin[3] / 2;
        require(msgval >= burnFee, "Insufficient burn fee");
        burnFee = subzero(msgval, burnFee);
        /** The entire LP RM as a percent of the larger of the long or short
        * side is used to decrement the credits of those at the upcoming settlement
        */
        if (margin[2] > margin[1]) {
            burnFactor = subzero(burnFactor, 1 ether * margin[3] / margin[2]);
        } else {
            burnFactor = subzero(burnFactor, 1 ether * margin[3] / margin[1]);
        }
        bookStatus = 2;
        return burnFee;
    }

    function cancelBook(uint lastOracleSettle, bytes32 subkID, address sender, uint8 _endDay)
        external
        payable
        onlyAdmin
    {
        Subcontract storage k = subcontracts[subkID];
        require(lastOracleSettle < lastBookSettleTime, "Cannot do during settle period");
        require(sender == k.taker || sender == lp, "Canceller not LP or taker");
        /// checks to see if subk already cancelled, as otherwise redundant
        require(k.subkStatus == 1, "redundant or too new");
        uint feeOracle = 250 * k.requiredMargin / 1e4;
        require(msg.value >= (2 * feeOracle), "Insufficient cancel fee");
        uint feeLP = uint(k.closeFee) * k.requiredMargin / 1e4;
        if (sender == k.taker && _endDay == 5) {
            k.subkStatus = 2;  /// regular taker cancel
        } else if (sender == k.taker) {
            require(k.requiredMargin < subzero(margin[0], margin[3]), "Insuff LP RM for immed cancel");
            feeLP = feeOracle;  /// close fee is now max close fee, overriding initial close fee
            k.subkStatus = 4;  /// immediate taker cancel
            k.priceDay = _endDay;  /// this is the end-day of the subcontract's last week
        } else {
            feeOracle = 2 * feeOracle;
            feeLP = subzero(msg.value, feeOracle); /// this is really a refund to the LP, not a fee
            k.subkStatus = 3;  /// LP cancel
        }
        balanceSend(feeOracle, assetSwap.feeAddress());
        tempContracts[1].push(subkID);  /// sets this up to settle as an expiring subcontract
        margin[0] += feeLP;
        k.takerMargin += subzero(msg.value, feeLP + feeOracle);
    }

    function fundLPBook()
        external
        onlyAdmin
        payable
    {
        margin[0] += msg.value;
    }

    function fundTakerBook(bytes32 subkID)
        external
        onlyAdmin
        payable
    {
        Subcontract storage k = subcontracts[subkID];
        require(k.subkStatus < 2);
        k.takerMargin += msg.value;
    }

    function closeBookBook()
        external
        payable
        onlyAdmin
    { /// pays the close fee on the larger side of her book
        uint feeOracle = 250 * (margin[1] + margin[2] - min(margin[1], margin[2])) / 1e4;
        require(msg.value >= feeOracle, "Insufficient cancel fee");
        uint feeOverpay = msg.value - feeOracle;
        balanceSend(feeOracle, assetSwap.feeAddress());
        if (now > endOfBookTime)
        /// this means the next settlement ends this book's activity
            bookStatus = 1;
        else
        /// if initial, needs to be run again in 28 days to complete the shut down
            endOfBookTime = now + 28 days;
        margin[0] += feeOverpay;
    }

    /**
    *We only need look at when the last book settlement because
    * if the LP was at fault, someone could have inactivatedthe LP
    * and received a reward. Thus, the only scenario where a book
    * can be active and the LP not inactivated, is when the oracle has been
    * absent for a week
    */
    function inactiveOracleBook()
        external
        onlyAdmin
        {
        require(now > (lastBookSettleTime + 10 days));
        bookStatus = 3;
    }

    /** if the book was not settled, the LP is held accountable
     * the first counterparty to execute this function will then get a bonus credit of their RM from  *the LP
     * if the LP's total margin is zero, they will get whatever is there
     * after the book is in default all players can redeem their subcontracts
     * After a book is in default, this cannot be executed
     */
    function inactiveLPBook(bytes32 subkID, address sender, uint _lastOracleSettle)
        external
        onlyAdmin
    {

        require(bookStatus != 3);
        Subcontract storage k = subcontracts[subkID];
        require(k.taker == sender);
        require(_lastOracleSettle > lastBookSettleTime);
        require(subzero(now, _lastOracleSettle) > 48 hours);
        uint lpDefFee = min(margin[0], margin[3] / 2);
        margin[0] = subzero(margin[0], lpDefFee);
        margin[3] = 0;
        bookStatus = 3;
        /// annoying, but at least someone good get the negligent LP's money
        k.takerMargin += lpDefFee;
    }

    function redeemBook(bytes32 subkid, address sender)
        external
        onlyAdmin
    {
        Subcontract storage k = subcontracts[subkid];
        require(k.subkStatus > 5 || bookStatus == 3);
        /// redemption can happen if the subcontract has defaulted subkStatus = 6, is inactive subkStatus = 7
        /// or if the book is inactive (bookStatus == 3)
        uint tMargin = k.takerMargin;
        k.takerMargin = 0;
        uint16 index = k.index;
        /// iff the taker defaulted on an active book, they are penalized by
        /// burning RM/2 of their margin
        bool isDefaulted = (k.subkStatus == 6 && bookStatus == 0);
        uint defPay = k.requiredMargin / 2;
        uint lpPayment;
        address tAddress = k.taker;
        /// this pays the lp for the gas and effort of redeeming for the taker
        /// it's just 2 finney. The investor should now see their margin in the
        /// assetSwapBalance, and withdraw from there
        if (sender == lp) {
            lpPayment = tMargin - subzero(tMargin, 2 finney);
            tMargin -= lpPayment;
            margin[0] += lpPayment;
        }
        /** we have to pop the takerLong/Short lists to free up space
        * this involves this little trick, moving the last row to the row we are
        * redeeming and writing it over the redeemed subcontract
        * then we remove the duplicate.
        */
        Subcontract storage lastTaker = subcontracts[takerContracts[takerContracts.length - 1]];
        lastTaker.index = index;
        takerContracts[index] = takerContracts[takerContracts.length - 1];
        takerContracts.pop();
        delete subcontracts[subkid];
        // we only take what is there. It goes to the oracle, so if he's a cheater, you can punish
        /// him more by withholding this payment as well as the fraudulent PNL. If he's not a cheater
        /// then you are just negligent for defaulting and probably were not paying attention, as
        /// you should have know you couldn't cure your margin Friday afternoon before close.
        if (isDefaulted) {
            tMargin = subzero(tMargin, defPay);
            balanceSend(defPay, assetSwap.feeAddress());
        }
        /// money is sent to AssetSwapContract
        balanceSend(tMargin, tAddress);

    }

    /** Settle the rolled over taker sukcontracts
    * @param assetRet the returns for a long contract for a taker for only one
    * start day, as they are all starting on the prior settlement price
    */
    function settleRolling(int assetRet)
        external
        onlyAdmin
    {
        require(settleNum < 2e4, "done with rolling settle");
        int takerRetTemp;
        int lpTemp;
        /// the first settlement function set the settleNum = 1e4, so that is subtracted to
        /// see where we are in the total number of takers in the LP's book
        uint loopCap = min(settleNum - 1e4 + 250, takerContracts.length);
        for (uint i = (settleNum - 1e4); i < loopCap; i++) {
            Subcontract storage k = subcontracts[takerContracts[i]];
            if (k.subkStatus == 1) {
                takerRetTemp = int(k.takerSide) * assetRet * int(k.requiredMargin) / 1
                ether - (int(k.fundingRate) * int(k.requiredMargin) / 1e4);
                lpTemp = lpTemp - takerRetTemp;
                if (takerRetTemp < 0) {
                    k.takerMargin = subzero(k.takerMargin, uint(-takerRetTemp));
                } else {
                    k.takerMargin += uint(takerRetTemp) * burnFactor / 1 ether;
                }
                if (k.takerMargin < k.requiredMargin) {
                    k.subkStatus = 6;
                    if (k.takerSide == 1)
                        margin[2] = subzero(margin[2], k.requiredMargin);
                    else
                        margin[1] = subzero(margin[1], k.requiredMargin);
                }
            }
        }
        settleNum += 250;
        if ((settleNum - 1e4) >= takerContracts.length)
            settleNum = 2e4;
        lpSettleDebitAcct += lpTemp;
    }

    /// this is the fourth and the final of the settlement functions
    function settleFinal()
        external
        onlyAdmin
    {
        require(settleNum == 3e4, "not done with all the subcontracts");
        /// this take absolute value of (long - short) to update the LP's RM
        if (margin[2] > margin[1])
            margin[3] = margin[2] - margin[1];
        else
            margin[3] = margin[1] - margin[2];
        if (lpSettleDebitAcct < 0)
            margin[0] = subzero(margin[0], uint(-lpSettleDebitAcct));
        else
        /// if the lpSettleDebitAcct is positive, we add it, but first apply the burnFactor
        /// to remove the burner's pnl in a pro-rata way
            margin[0] = margin[0] + uint(lpSettleDebitAcct) * burnFactor / 1 ether;
        if (bookStatus != 0) {
            bookStatus = 3;
            margin[3] = 0;
        } else if (margin[0] < margin[3]) {
            // default scenario for LP
            bookStatus = 3;
            uint defPay = min(margin[0], margin[3] / 2);
            margin[0] = subzero(margin[0], defPay);
            balanceSend(defPay, assetSwap.feeAddress());
            margin[3] = 0;
        }
        // resets for our next book settlement
        lpSettleDebitAcct = 0;
        lastBookSettleTime = now;
        settleNum = 0;
        delete tempContracts[1];
        delete tempContracts[0];
        burnFactor = 1 ether;
    }

    /** Create a new Taker long subcontract of the given parameters
    * @param taker the address of the party on the other side of the contract
    * @param rM the ETH amount in the required margin
    * isTakerLong is +1 if taker is long, 0 if taker is short
    * @return subkID the id of the newly created subcontract
    */
    function takeBook(address taker, uint rM, uint lastOracleSettle, uint8 _priceDay, uint isTakerLong)
        external
        payable
        onlyAdmin
        returns (bytes32 subkID)
    {
        require(bookStatus == 0, "book is no longer taking positions");
        require((now + 28 days) < endOfBookTime, "book closing soon");
        require(rM >= uint(lpMinTakeRM) * 1 ether, "must be greater than book min");
        require(lastOracleSettle < lastBookSettleTime, "Cannot do during settle period");
        uint availableMargin = subzero(margin[0] / 2 + margin[2 - isTakerLong], margin[1 + isTakerLong]);
        require(rM <= availableMargin && (margin[0] - margin[3]) > rM);
        require(rM <= availableMargin);
        margin[1 + isTakerLong] += rM;
        Subcontract memory order;
        order.requiredMargin = rM;
        order.takerMargin = msg.value;
        order.taker = taker;
        order.takerSide = int8(2 * isTakerLong - 1);
        margin[3] += rM;
        subkID = keccak256(abi.encodePacked(now, takerContracts.length));
        order.index = uint16(takerContracts.length);
        order.priceDay = _priceDay;
        order.fundingRate = fundingRates[isTakerLong];
        order.closeFee = bookCloseFee;
        subcontracts[subkID] = order;
        takerContracts.push(subkID);
        tempContracts[0].push(subkID);
        return subkID;
    }

    /** Withdrawing margin
    * reverts if during the settle period, oracleSettleTime > book settle time
    * also must leave total margin greater than the required margin
    */
    function withdrawLPBook(uint amount, uint lastOracleSettle)
        external
        onlyAdmin
    {
        require(margin[0] >= amount, "Cannot withdraw more than the margin");
         // if book is dead LP can take everything left, if not dead, can only take up to RM
        if (bookStatus != 3) {
            require(subzero(margin[0], amount) >= margin[3], "Cannot w/d more than excess margin");
            require(lastOracleSettle < lastBookSettleTime, "Cannot w/d during settle period");
        }
        margin[0] = subzero(margin[0], amount);
        balanceSend(amount, lp);
    }

    function withdrawTakerBook(bytes32 subkID, uint amount, uint lastOracleSettle, address sender)
        external
        onlyAdmin
    {
        require(lastOracleSettle < lastBookSettleTime, "Cannot w/d during settle period");
        Subcontract storage k = subcontracts[subkID];
        require(k.subkStatus < 6, "subk dead, must redeem");
        require(sender == k.taker, "Must be taker to call this function");
        require(subzero(k.takerMargin, amount) >= k.requiredMargin, "cannot w/d more than excess margin");
        k.takerMargin = subzero(k.takerMargin, amount);
        balanceSend(amount, k.taker);
    }

    function getSubkData1Book(bytes32 subkID)
        external
        view
        returns (address takerAddress, uint takerMargin, uint requiredMargin)
    {   Subcontract memory k = subcontracts[subkID];
        takerAddress = k.taker;
        takerMargin = k.takerMargin;
        requiredMargin = k.requiredMargin;
    }

    function getSubkData2Book(bytes32 subkID)
        external
        view
        returns (uint8 kStatus, uint8 priceDay, uint8 closeFee, int16 fundingRate, bool takerSide)
    {   Subcontract memory k = subcontracts[subkID];
        kStatus = k.subkStatus;
        priceDay = k.priceDay;
        closeFee = k.closeFee;
        fundingRate = k.fundingRate;
        if (k.takerSide == 1)
            takerSide = true;
    }

    function getSettleInfoBook()
        external
        view
        returns (uint totalLength, uint expiringLength, uint newLength, uint lastBookSettleUTC, uint settleNumber,
            uint bookBalance, uint bookMaturityUTC)
    {
        totalLength = takerContracts.length;
        expiringLength = tempContracts[1].length;
        newLength = tempContracts[0].length;
        lastBookSettleUTC = lastBookSettleTime;
        settleNumber = settleNum;
        bookMaturityUTC = endOfBookTime;
        bookBalance = address(this).balance;
    }

    /** Settle the taker long sukcontracts
    * priceDay Expiring returns use the return from the last settle to the priceDay, which
    * for regular cancels is just 5, the most recent settlement price
    * this is the first of 4 settlement functions
    * */
    function settleExpiring(int[5] memory assetRetExp)
        public
        onlyAdmin
        {
        require(bookStatus != 3 && settleNum < 1e4, "done with expiry settle");
        int takerRetTemp;
        int lpTemp;
        uint loopCap = min(settleNum + 200, tempContracts[1].length);
        for (uint i = settleNum; i < loopCap; i++) {
            Subcontract storage k = subcontracts[tempContracts[1][i]];
            takerRetTemp = int(k.takerSide) * assetRetExp[k.priceDay - 1] * int(k.requiredMargin) / 1 ether -
            (int(k.fundingRate) * int(k.requiredMargin) / 1e4);
            lpTemp -= takerRetTemp;
            if (takerRetTemp < 0) {
                k.takerMargin = subzero(k.takerMargin, uint(-takerRetTemp));
            } else {
                k.takerMargin += uint(takerRetTemp) * burnFactor / 1 ether;
            }
            if (k.takerSide == 1)
                margin[2] = subzero(margin[2], k.requiredMargin);
            else
                margin[1] = subzero(margin[1], k.requiredMargin);
            k.subkStatus = 7;
        }
        settleNum += 200;
        if (settleNum >= tempContracts[1].length)
            settleNum = 1e4;
        lpSettleDebitAcct += lpTemp;
    }

    /// this is the third of the settlement functions
    function settleNew(int[5] memory assetRets)
        public
        onlyAdmin
    {
        require(settleNum < 3e4, "done with new settle");
        int takerRetTemp;
        int lpTemp;
        /// after running the second settlement function, settleRolling, it is set to 2e4
        uint loopCap = min(settleNum - 2e4 + 200, tempContracts[0].length);
        for (uint i = (settleNum - 2e4); i < loopCap; i++) {
            Subcontract storage k = subcontracts[tempContracts[0][i]];
            /// subkStatus set to 'active' which means it can be cancelled
            /// it will also be settled in the settleRolling if not cancelled
            /// using the more efficient settlement that uses just one return, from last to most recent settlement
            k.subkStatus = 1;
            if (k.priceDay != 5) {
                takerRetTemp = int(k.takerSide) * assetRets[k.priceDay] * int(k.requiredMargin) / 1
                ether - (int(k.fundingRate) * int(k.requiredMargin) / 1e4);
                lpTemp = lpTemp - takerRetTemp;
                if (takerRetTemp < 0) {
                    k.takerMargin = subzero(k.takerMargin, uint(-takerRetTemp));
                } else {
                    k.takerMargin += uint(takerRetTemp) * burnFactor / 1 ether;
                }
                if (k.takerMargin < k.requiredMargin) {
                    k.subkStatus = 6;
                    if (k.takerSide == 1)
                        margin[2] = subzero(margin[2], k.requiredMargin);
                    else
                        margin[1] = subzero(margin[1], k.requiredMargin);
                }
                k.priceDay = 5;
            }
        }
        settleNum += 200;
        if (settleNum >= tempContracts[0].length)
            settleNum = 3e4;
        lpSettleDebitAcct += lpTemp;
    }

    /// Function to send balances back to the Assetswap contract
    function balanceSend(uint amount, address recipient)
        internal
    {
        assetSwap.balanceInput.value(amount)(recipient);
    }

    /** Utility function to find the minimum of two unsigned values
    * @notice returns the first parameter if they are equal
    */
    function min(uint a, uint b)
        internal
        pure
        returns (uint)
    {
        if (a <= b)
            return a;
        else
            return b;
    }

    function subzero(uint _a, uint _b)
        internal
        pure
        returns (uint)
    {
        if (_b >= _a)
            return 0;
        else
            return _a - _b;
    }


}

pragma solidity 0.5.15;

import "./AssetSwap.sol";


contract Oracle {

    constructor (uint ethPrice, uint spxPrice, uint btcPrice) public {
        admins[msg.sender] = true;
        prices[0][5] = ethPrice;
        prices[1][5] = spxPrice;
        prices[2][5] = btcPrice;
        lastUpdateTime = now;
        lastSettleTime = now;
        currentDay = 5;
        levRatio[0] = 250;  // ETH contract 2.5 leverage
        levRatio[1] = 1000; /// SPX contract 10.0 leverage
        levRatio[2] = 250;  // BTC contract 2.5 leverage
    }

    address[3] public assetSwaps;
    uint[6][3] private prices;
    uint public lastUpdateTime;
    uint public lastSettleTime;
    int[3] public levRatio;
    uint8 public currentDay;
    bool public nextUpdateSettle;
    mapping(address => bool) public admins;
    mapping(address => bool) public readers;

    event PriceUpdated(
        uint ethPrice,
        uint spxPrice,
        uint btcPrice,
        uint eUTCTime,
        uint eDayNumber,
        bool eisCorrection
    );

    modifier onlyAdmin() {
        require(admins[msg.sender]);
        _;
    }
    /** Grant write priviledges to a user,
    * mainly intended for when the admin wants to switch accounts, ie, paired with a removal
    */

    function addAdmin(address newAdmin)
        external
        onlyAdmin
    {
        admins[newAdmin] = true;
    }

    /** Grant priviledges to a user accessing price data on the blockchain
    * @param newReader the address. Any reader is thus approved by the oracle/admin
    * useful for new contracts that use this oracle, in that the oracle would not
    * need to create a new oracle contract for ETH prices
    */
    function addReaders(address newReader)
        external
        onlyAdmin
    {
        readers[newReader] = true;
    }
    /** this can only be done once, so this oracle is solely for working with
    * three AssetSwap contracts
    * assetswap 0 is the ETH, at 2.5 leverage
    * assetswap 1 is the SPX, at 10x leverage
    * assetswap 2 is the BTC, at 2.5 leverage
    */

    function addAssetSwaps(address newAS0, address newAS1, address newAS2)
        external
        onlyAdmin
    {
        require(assetSwaps[0] == address(0));
        assetSwaps[0] = newAS0;
        assetSwaps[1] = newAS1;
        assetSwaps[2] = newAS2;
        readers[newAS0] = true;
        readers[newAS1] = true;
        readers[newAS2] = true;
    }

    function removeAdmin(address toRemove)
        external
        onlyAdmin
    {
        require(toRemove != msg.sender);
        admins[toRemove] = false;
    }
    /** Quickly fix an erroneous price, or correct the fact that 50% movements are
    * not allowed in the standard price input
    * this must be called within 60 minutes of the initial price update occurence
    */

    function editPrice(uint _ethprice, uint _spxprice, uint _btcprice)
        external
        onlyAdmin
    {
        require(now < lastUpdateTime + 60 minutes);
        prices[0][currentDay] = _ethprice;
        prices[1][currentDay] = _spxprice;
        prices[2][currentDay] = _btcprice;
        emit PriceUpdated(_ethprice, _spxprice, _btcprice, now, currentDay, true);
    }

    function updatePrices(uint ethp, uint spxp, uint btcp, bool _newFinalDay)
        external
        onlyAdmin
    {

             /// no updates within 20 hours per day
        require(now > lastUpdateTime + 20 hours);
            /** can't be executed if the next price should be a settlement price
            * settlement prices are special because they need to update the asset returns
            * and sent to the AssetSwap contracts
            */
        require(!nextUpdateSettle);
         /// after settlement update, at least 48 hours until new prices are posted
        require(now > lastSettleTime + 48 hours, "too soon after last settle");
          /// prevents faulty prices, as stale prices are a common source of bad prices.
        require(ethp != prices[0][currentDay] && spxp != prices[1][currentDay] && btcp != prices[2][currentDay]);
            /// extreme price movements are probably mistakes. They can be posted
          /// but only via a 'price edit' that must be done within 60 minutes of the initial update
        require((ethp * 10 < prices[0][currentDay] * 15) && (ethp * 10 > prices[0][currentDay] * 5));
        require((spxp * 10 < prices[1][currentDay] * 15) && (spxp * 10 > prices[1][currentDay] * 5));
        require((btcp * 10 < prices[2][currentDay] * 15) && (btcp * 10 > prices[2][currentDay] * 5));
        if (currentDay == 5) {
            currentDay = 1;
            nextUpdateSettle = false;
        } else {
            currentDay += 1;
            nextUpdateSettle = _newFinalDay;
        }
        if (currentDay == 4)
            nextUpdateSettle = true;
        updatePriceSingle(0, ethp);
        updatePriceSingle(1, spxp);
        updatePriceSingle(2, btcp);
        emit PriceUpdated(ethp, spxp, btcp, now, currentDay, false);
        lastUpdateTime = now;
    }

    function settlePrice(uint ethp, uint spxp, uint btcp)
        external
        onlyAdmin
    {
        require(nextUpdateSettle);
        require(now > lastUpdateTime + 20 hours);
        require(ethp != prices[0][currentDay] && spxp != prices[1][currentDay] && btcp != prices[2][currentDay]);
        require((ethp * 10 < prices[0][currentDay] * 15) && (ethp * 10 > prices[0][currentDay] * 5));
        require((spxp * 10 < prices[1][currentDay] * 15) && (spxp * 10 > prices[1][currentDay] * 5));
        require((btcp * 10 < prices[2][currentDay] * 15) && (btcp * 10 > prices[2][currentDay] * 5));
        currentDay = 5;
        nextUpdateSettle = false;
        updatePriceSingle(0, ethp);
        updatePriceSingle(1, spxp);
        updatePriceSingle(2, btcp);
        int[5] memory assetReturnsNew;
        int[5] memory assetReturnsExpiring;
        int cap = 975 * 1 ether / 1000;
        for (uint j = 0; j < 3; j++) {
                  /**  asset return from start day j to settle day (ie, day 5),
                  * and also the prior settle day (day 0) to the end day.
                  * returns are normalized from 0.975 ether to - 0.975 ether
                  * where 0.9 ether is a 90% RM profit for the long taker,
                  * 0.2 ether means a 20% of RM profit for the long taker.
                  */
            for (uint i = 0; i < 5; i++) {
                if (prices[0][i] != 0) {
                    int assetRetFwd = int(prices[j][5] * 1 ether / prices[j][i]) - 1 ether;
                    assetReturnsNew[i] = assetRetFwd * int(prices[0][i]) * levRatio[j] /
                        int(prices[0][5]) / 100;
                /** as funding rates are maxed out at 2.5% of RM, the return must
                * max out at 97.5% of RM so that required margins cover all
                * potential payment scenarios
                */
                    assetReturnsNew[i] = bound(assetReturnsNew[i], cap);
                }
                if (prices[0][i+1] != 0) {
                    int assetRetBack = int(prices[j][i+1] * 1 ether / prices[j][0]) - 1 ether;
                    assetReturnsExpiring[i] = assetRetBack * int(prices[0][0]) * levRatio[j] /
                        int(prices[0][i+1]) / 100;

                    assetReturnsExpiring[i] = bound(assetReturnsExpiring[i], cap);
                }
            }
    /// this updates the AssetSwap contract with the vector of returns,
    /// one for each day of the week
            AssetSwap asw = AssetSwap(assetSwaps[j]);
            asw.updateReturns(assetReturnsNew, assetReturnsExpiring);
        }
        lastSettleTime = now;
        emit PriceUpdated(ethp, spxp, btcp, now, currentDay, false);
        lastUpdateTime = now;
    }
    /** Return the entire current price array for a given asset
    * @param _assetID the asset id of the desired asset
    * @return _priceHist the price array in USD for the asset
    * @dev only the admin and addresses granted readership may call this function
    * While only an admin or reader can access this within the EVM
    * anyone can access these prices outside the EVM
    * eg, in javascript: OracleAddress.methods.getUsdPrices.cacheCall(0, { 'from': 'AdminAddress' }
    */

    function getUsdPrices(uint _assetID)
        public
        view
        returns (uint[6] memory _priceHist)
    {
        require(admins[msg.sender] || readers[msg.sender]);
        _priceHist = prices[_assetID];
    }

        /** Return only the latest prices
        * @param _assetID the asset id of the desired asset
        * @return _price the latest price of the given asset
        * @dev only the admin or a designated reader may call this function within the EVM
        */
    function getCurrentPrice(uint _assetID)
        public
        view
        returns (uint _price)
    {
        require(admins[msg.sender] || readers[msg.sender]);
        _price = prices[_assetID][currentDay];
    }

    /**
    * @return startDay relevant for trades done now
    * pulls the day relevant for new AssetSwap subcontracts
    * startDay 2 means the 2 slot (ie, the third) of prices will be the initial
    * price for the subcontract. As 5 is the top slot, and rolls into slot 0
    * the next week, the next pricing day is 1 when the current day == 5
    * (this would be a weekend or Monday morning)
    */
    function getStartDay()
        public
        view
        returns (uint8 _startDay)
    {
        if (nextUpdateSettle) {
            _startDay = 5;
        } else if (currentDay == 5) {
            _startDay = 1;
        } else {
            _startDay = currentDay + 1;
        }
    }

    function updatePriceSingle(uint _assetID, uint _price)
        internal
    {
        if (currentDay == 1) {
            uint[6] memory newPrices;
            newPrices[0] = prices[_assetID][5];
            newPrices[1] = _price;
            prices[_assetID] = newPrices;
        } else {
            prices[_assetID][currentDay] = _price;
        }
    }

    function bound(int a, int b)
        internal
        pure
        returns (int)
    {
        if (a > b)
            a = b;
        if (a < -b)
            a = -b;
        return a;
    }

}

