pragma solidity ^0.5.8;

// https://github.com/pipermerriam/ethereum-datetime
contract DateTime {
  struct _DateTime {
    uint16 year;
    uint8 month;
    uint8 day;
    uint8 hour;
    uint8 minute;
    uint8 second;
    uint8 weekday;
  }

  uint constant DAY_IN_SECONDS = 86400;
  uint constant YEAR_IN_SECONDS = 31536000;
  uint constant LEAP_YEAR_IN_SECONDS = 31622400;

  uint constant HOUR_IN_SECONDS = 3600;
  uint constant MINUTE_IN_SECONDS = 60;

  uint16 constant ORIGIN_YEAR = 1970;

  function isLeapYear(uint16 year) internal pure returns (bool) {
    if (year % 4 != 0) {
      return false;
    }
    if (year % 100 != 0) {
      return true;
    }
    if (year % 400 != 0) {
      return false;
    }
    return true;
  }

  function leapYearsBefore(uint year) internal pure returns (uint) {
    year -= 1;
    return year / 4 - year / 100 + year / 400;
  }

  function getDaysInMonth(uint8 month, uint16 year) internal pure returns (uint8) {
    if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
      return 31;
    } else if (month == 4 || month == 6 || month == 9 || month == 11) {
      return 30;
    } else if (isLeapYear(year)) {
      return 29;
    } else {
      return 28;
    }
  }

  function parseTimestamp(uint timestamp) internal pure returns (_DateTime memory dt) {
    uint secondsAccountedFor = 0;
    uint buf;
    uint8 i;

    // Year
    dt.year = getYear(timestamp);
    buf = leapYearsBefore(dt.year) - leapYearsBefore(ORIGIN_YEAR);

    secondsAccountedFor += LEAP_YEAR_IN_SECONDS * buf;
    secondsAccountedFor += YEAR_IN_SECONDS * (dt.year - ORIGIN_YEAR - buf);

    // Month
    uint secondsInMonth;
    for (i = 1; i <= 12; i++) {
      secondsInMonth = DAY_IN_SECONDS * getDaysInMonth(i, dt.year);
      if (secondsInMonth + secondsAccountedFor > timestamp) {
        dt.month = i;
        break;
      }
      secondsAccountedFor += secondsInMonth;
    }

    // Day
    for (i = 1; i <= getDaysInMonth(dt.month, dt.year); i++) {
      if (DAY_IN_SECONDS + secondsAccountedFor > timestamp) {
        dt.day = i;
        break;
      }
      secondsAccountedFor += DAY_IN_SECONDS;
    }

    // Hour
    dt.hour = getHour(timestamp);

    // Minute
    dt.minute = getMinute(timestamp);

    // Second
    dt.second = getSecond(timestamp);
    dt.weekday = getWeekday(timestamp);
  }

  function getYear(uint timestamp) internal pure returns (uint16) {
    uint secondsAccountedFor = 0;
    uint16 year;
    uint numLeapYears;

    // Year
    year = uint16(ORIGIN_YEAR + timestamp / YEAR_IN_SECONDS);
    numLeapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);

    secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
    secondsAccountedFor += YEAR_IN_SECONDS * (year - ORIGIN_YEAR - numLeapYears);

    while (secondsAccountedFor > timestamp) {
      if (isLeapYear(uint16(year - 1))) {
        secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
      } else {
        secondsAccountedFor -= YEAR_IN_SECONDS;
      }
      year -= 1;
    }
    return year;
  }

  function getMonth(uint timestamp) internal pure returns (uint8) {
    return parseTimestamp(timestamp).month;
  }

  function getDay(uint timestamp) internal pure returns (uint8) {
    return parseTimestamp(timestamp).day;
  }

  function getHour(uint timestamp) internal pure returns (uint8) {
    return uint8((timestamp / 60 / 60) % 24);
  }

  function getMinute(uint timestamp) internal pure returns (uint8) {
    return uint8((timestamp / 60) % 60);
  }

  function getSecond(uint timestamp) internal pure returns (uint8) {
    return uint8(timestamp % 60);
  }

  function getWeekday(uint timestamp) internal pure returns (uint8) {
    return uint8((timestamp / DAY_IN_SECONDS + 4) % 7);
  }

  function toTimestamp(uint16 year, uint8 month, uint8 day) internal pure returns (uint timestamp) {
    return toTimestamp(year, month, day, 0, 0, 0);
  }

  function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour) internal pure returns (uint timestamp) {
    return toTimestamp(year, month, day, hour, 0, 0);
  }

  function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute)
    internal
    pure
    returns (uint timestamp)
  {
    return toTimestamp(year, month, day, hour, minute, 0);
  }

  function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute, uint8 second)
    internal
    pure
    returns (uint timestamp)
  {
    uint16 i;

    // Year
    for (i = ORIGIN_YEAR; i < year; i++) {
      if (isLeapYear(i)) {
        timestamp += LEAP_YEAR_IN_SECONDS;
      } else {
        timestamp += YEAR_IN_SECONDS;
      }
    }

    // Month
    uint8[12] memory monthDayCounts;
    monthDayCounts[0] = 31;
    if (isLeapYear(year)) {
      monthDayCounts[1] = 29;
    } else {
      monthDayCounts[1] = 28;
    }
    monthDayCounts[2] = 31;
    monthDayCounts[3] = 30;
    monthDayCounts[4] = 31;
    monthDayCounts[5] = 30;
    monthDayCounts[6] = 31;
    monthDayCounts[7] = 31;
    monthDayCounts[8] = 30;
    monthDayCounts[9] = 31;
    monthDayCounts[10] = 30;
    monthDayCounts[11] = 31;

    for (i = 1; i < month; i++) {
      timestamp += DAY_IN_SECONDS * monthDayCounts[i - 1];
    }

    // Day
    timestamp += DAY_IN_SECONDS * (day - 1);

    // Hour
    timestamp += HOUR_IN_SECONDS * (hour);

    // Minute
    timestamp += MINUTE_IN_SECONDS * (minute);

    // Second
    timestamp += second;

    return timestamp;
  }
}

pragma solidity ^0.5.8;

/*
 * 'Bolton Holding Group' CORPORATE BOND Subscription contract
 *
 * Token                : Bolton Coin (BFCL)
 * Interest rate        : 22% yearly
 * Duration subscription: 24 months
 *
 * Copyright (C) 2019 Raffaele Bini - 5esse Informatica (https://www.5esse.it)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import "./ReentrancyGuard.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
import "./Whitelist.sol";
import "./Vault.sol";
import "./PriceManagerRole.sol";
import "./DateTime.sol";

contract DepositPlan is Ownable, ReentrancyGuard, PriceManagerRole, DateTime {
  using SafeMath for uint;

  enum Currency {BFCL, EURO}

  event AddInvestor(address indexed investor);
  event CloseAccount(address indexed investor);
  event InvestorDeposit(address indexed investor, uint bfclAmount, uint euroAmount, uint depositTime);
  event Reinvest(
    uint oldBfcl,
    uint oldEuro,
    uint oldLastWithdrawTime,
    uint bfclDividends,
    uint euroDividends,
    uint lastWithdrawTime
  );
  event DeleteDebt(address indexed investor, uint index);
  event DeleteDeposit(address indexed investor, uint index);
  event AddDebt(address indexed investor, uint bfclDebt, uint euroDebt);

  uint internal constant RATE_MULTIPLIER = 10 ** 18;
  uint internal constant MIN_INVESTMENT_EURO_CENT = 50000 * RATE_MULTIPLIER; // 50k EURO in cents
  uint internal constant MIN_REPLENISH_EURO_CENT = 1000 * RATE_MULTIPLIER; // 1k EURO in cents
  uint internal HUNDRED_PERCENTS = 10000; // 100%
  uint internal PERCENT_PER_YEAR = 2200; // 22%

  IERC20 public bfclToken;
  IERC20 public euroToken;
  Whitelist public whitelist;
  address public tokensWallet;
  uint public bfclEuroRateFor72h; // 1 EUR = bfclEuroRateFor72h BFCL / 10^18
  bool public isStopped;

  mapping(address => Account) public accounts;
  mapping(address => Deposit[]) public deposits;
  mapping(address => Debt[]) public debts;

  struct Account {
    Vault vault;
    uint firstDepositTimestamp;
    uint stopTime;
  }

  struct Deposit {
    uint bfcl;
    uint euro;
    uint lastWithdrawTime;
  }

  struct Debt {
    uint bfcl;
    uint euro;
  }

  constructor(IERC20 _bfclToken, Whitelist _whitelist, address _tokensWallet, uint _initialBfclEuroRateFor72h) public {
    bfclToken = _bfclToken;
    whitelist = _whitelist;
    tokensWallet = _tokensWallet;
    bfclEuroRateFor72h = _initialBfclEuroRateFor72h;
  }

  modifier onlyIfWhitelisted() {
    require(whitelist.isWhitelisted(msg.sender), "Not whitelisted");
    _;
  }

  // reverts ETH transfers
  function() external {
    revert();
  }

  // reverts erc223 token transfers
  function tokenFallback(address, uint, bytes calldata) external pure {
    revert();
  }

  function transferErc20(IERC20 _token, address _to, uint _value) external onlyOwner nonReentrant {
    _token.transfer(_to, _value);
  }

  function transferBfcl(address _to, uint _value) external onlyOwner nonReentrant {
    bfclToken.transfer(_to, _value);
  }

  function stop() external onlyOwner {
    isStopped = true;
  }

  function invest(uint _bfclAmount) external onlyIfWhitelisted nonReentrant {
    require(!isStopped, "Contract stopped. You can no longer invest.");

    uint bfclAmount;
    uint euroAmount;

    address investor = msg.sender;
    Account storage account = accounts[investor];
    if (account.vault == Vault(0)) {
      // first deposit
      bfclAmount = _bfclAmount;
      euroAmount = _bfclAmount.mul(RATE_MULTIPLIER).div(bfclEuroRateFor72h);
      require(euroAmount >= MIN_INVESTMENT_EURO_CENT, "Should be more than minimum");
      account.vault = new Vault(investor, bfclToken);
      account.firstDepositTimestamp = now;
      account.stopTime = now + 730 days;

      emit AddInvestor(investor);
    } else {
      // replenish
      require(now < account.stopTime, "2 years have passed. You can no longer replenish.");
      uint oneKEuroInBfcl = bfclEuroRateFor72h.mul(MIN_REPLENISH_EURO_CENT).div(RATE_MULTIPLIER);
      uint times = _bfclAmount.div(oneKEuroInBfcl);
      bfclAmount = times.mul(oneKEuroInBfcl);
      euroAmount = times.mul(MIN_REPLENISH_EURO_CENT);
      require(euroAmount >= MIN_REPLENISH_EURO_CENT, "Should be more than minimum");
    }

    require(bfclToken.allowance(investor, address(this)) >= bfclAmount, "Allowance should not be less than amount");
    bfclToken.transferFrom(investor, address(account.vault), bfclAmount);

    deposits[investor].push(Deposit(bfclAmount, euroAmount, now));

    emit InvestorDeposit(investor, bfclAmount, euroAmount, now);
  }

  function withdraw() external nonReentrant {
    address investor = msg.sender;
    Account storage account = accounts[investor];
    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;
    uint result;
    result += _tryToWithdrawDividends(investor, account, currency);
    result += _tryToWithdrawDebts(investor, currency);
    require(result > 0, "Nothing to withdraw");
    _checkAndCloseAccount(investor);
  }

  function _tryToWithdrawDividends(address _investor, Account storage _account, Currency _currency)
    internal
    returns (uint result)
  {
    if (isInIntervals(now) || now >= _account.stopTime) {
      uint depositCount = deposits[_investor].length;
      if (depositCount > 0) {
        for (uint i = 0; i < depositCount; i++) {
          if (_withdrawOneDividend(_investor, _account, _currency, i)) {
            result++;
          }
        }

        if (now >= _account.stopTime) {
          for (uint i = depositCount; i > 0; i--) {
            _withdrawDeposit(_investor, i - 1);
          }
        }
      }
    }
  }

  function _tryToWithdrawDebts(address _investor, Currency _currency) internal returns (uint result) {
    uint debtCount = debts[_investor].length;
    if (debtCount > 0) {
      for (uint i = 0; i < debtCount; i++) {
        if (_withdrawOneDebt(_investor, _currency, i)) {
          result++;
        }
      }

      for (uint i = debtCount; i > 0; i--) {
        _deleteDebt(_investor, i - 1);
      }
    }
  }

  function _withdrawDeposit(address _investor, uint _index) internal {
    Vault vault = accounts[_investor].vault;
    Deposit storage deposit = deposits[_investor][_index];
    uint mustPay = deposit.bfcl;

    uint toPayFromVault;
    uint toPayFromWallet;
    if (vault.getBalance() >= mustPay) {
      toPayFromVault = mustPay;
    } else {
      toPayFromVault = vault.getBalance();
      toPayFromWallet = mustPay.sub(toPayFromVault);
    }

    _deleteDeposit(_investor, _index);

    if (toPayFromVault > 0) {
      vault.withdrawToInvestor(toPayFromVault);
    }

    if (toPayFromWallet > 0) {
      _send(_investor, toPayFromWallet, 0, Currency.BFCL);
    }
  }

  function withdrawDividends() external nonReentrant {
    address investor = msg.sender;
    Account storage account = accounts[investor];
    require(isInIntervals(now) || now >= account.stopTime, "Should be in interval or after 2 years");
    require(deposits[investor].length > 0, "There is no deposits for your address");
    uint result;
    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;
    result += _tryToWithdrawDividends(investor, account, currency);
    require(result > 0, "Nothing to withdraw");
    _checkAndCloseAccount(investor);
  }

  function withdrawOneDividend(uint index) external nonReentrant {
    address investor = msg.sender;
    Account storage account = accounts[investor];
    require(isInIntervals(now) || now >= account.stopTime, "Should be in interval or after 2 years");
    require(deposits[investor].length > 0, "There is no deposits for your address");

    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;
    require(_withdrawOneDividend(investor, account, currency, index), "Nothing to withdraw");
    if (now >= account.stopTime) {
      _withdrawDeposit(investor, index);
    }
    _checkAndCloseAccount(investor);
  }

  function withdrawDebts() external nonReentrant {
    address investor = msg.sender;
    require(debts[investor].length > 0, "There is no deposits for your address");

    uint result;
    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;
    result += _tryToWithdrawDebts(investor, currency);
    require(result > 0, "Nothing to withdraw");
    _checkAndCloseAccount(investor);
  }

  function withdrawOneDebt(uint index) external nonReentrant {
    address investor = msg.sender;
    require(debts[investor].length > 0, "There is no deposits for your address");

    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;
    require(_withdrawOneDebt(investor, currency, index), "Nothing to withdraw");
    _deleteDebt(investor, index);
    _checkAndCloseAccount(investor);
  }

  function setBfclEuroRateFor72h(uint _rate) public onlyPriceManager {
    bfclEuroRateFor72h = _rate;
  }

  function switchToBfcl() public onlyOwner {
    require(address(euroToken) != address(0), "You are already using BFCL");
    euroToken = IERC20(address(0));
  }

  function switchToEuro(IERC20 _euro) public onlyOwner {
    require(address(_euro) != address(euroToken), "Trying to change euro token to same address");
    euroToken = _euro;
  }

  function calculateDividendsForTimestamp(address _investor, uint _timestamp)
    public
    view
    returns (uint bfcl, uint euro)
  {
    Account storage account = accounts[_investor];
    uint withdrawingTimestamp = _findIntervalStart(account, _timestamp);

    for (uint i = 0; i < deposits[_investor].length; i++) {
      (uint bfclDiv, uint euroDiv) = _calculateDividendForTimestamp(_investor, withdrawingTimestamp, i);
      bfcl = bfcl.add(bfclDiv);
      euro = euro.add(euroDiv);
    }

    if (withdrawingTimestamp >= account.stopTime) {
      bfcl = bfcl.sub(account.vault.getBalance());
    }
  }

  function calculateGroupDividendsForTimestamp(address[] memory _investors, uint _timestamp)
    public
    view
    returns (uint bfcl, uint euro)
  {
    for (uint i = 0; i < _investors.length; i++) {
      address investor = _investors[i];
      Account storage account = accounts[investor];
      uint withdrawingTimestamp = _findIntervalStart(account, _timestamp);

      for (uint d = 0; d < deposits[investor].length; d++) {
        (uint bfclDiv, uint euroDiv) = _calculateDividendForTimestamp(investor, withdrawingTimestamp, d);
        bfcl = bfcl.add(bfclDiv);
        euro = euro.add(euroDiv);
      }

      if (withdrawingTimestamp >= account.stopTime) {
        bfcl = bfcl.sub(account.vault.getBalance());
      }
    }
  }

  function calculateDividendsWithDebtsForTimestamp(address _investor, uint _timestamp)
    public
    view
    returns (uint bfcl, uint euro)
  {
    (bfcl, euro) = calculateDividendsForTimestamp(_investor, _timestamp);
    for (uint d = 0; d < debts[_investor].length; d++) {
      Debt storage debt = debts[_investor][d];
      bfcl = bfcl.add(debt.bfcl);
      euro = euro.add(debt.euro);
    }
  }

  function calculateGroupDividendsWithDebtsForTimestamp(address[] memory _investors, uint _timestamp)
    public
    view
    returns (uint bfcl, uint euro)
  {
    (bfcl, euro) = calculateGroupDividendsForTimestamp(_investors, _timestamp);
    for (uint i = 0; i < _investors.length; i++) {
      address investor = _investors[i];
      for (uint d = 0; d < debts[investor].length; d++) {
        Debt storage debt = debts[investor][d];
        bfcl = bfcl.add(debt.bfcl);
        euro = euro.add(debt.euro);
      }
    }
  }

  function isInIntervals(uint _timestamp) public pure returns (bool) {
    uint8[4] memory months = [1, 4, 7, 10];

    _DateTime memory dt = parseTimestamp(_timestamp);
    for (uint i = 0; i < months.length; i++) {
      if (dt.month == months[i]) {
        return 1 <= dt.day && dt.day <= 5;
      }
    }

    return false;
  }

  function _getNextDate(uint _timestamp) internal pure returns (uint) {
    _DateTime memory dt = parseTimestamp(_timestamp);

    uint16 year;
    uint8 month;

    uint8[4] memory months = [1, 4, 7, 10];
    for (uint i = months.length; i > 0; --i) {
      if (dt.month >= months[i - 1]) {
        if (i == months.length) {
          year = dt.year + 1;
          month = months[0];
        } else {
          year = dt.year;
          month = months[i];
        }
        break;
      }
    }

    return toTimestamp(year, month, 1);
  }

  // implies that the timestamp is exactly in any of the intervals or after stopTime
  function _findIntervalStart(Account storage _account, uint _timestamp) internal view returns (uint) {
    if (_timestamp >= _account.stopTime) {
      return _account.stopTime;
    } else {
      _DateTime memory dt = parseTimestamp(_timestamp);
      return toTimestamp(dt.year, dt.month, 1);
    }
  }

  function _getBalance(Currency _currency) internal view returns (uint) {
    IERC20 token = _currency == Currency.BFCL ? bfclToken : euroToken;
    uint balance = token.balanceOf(tokensWallet);
    uint allowance = token.allowance(tokensWallet, address(this));
    return balance < allowance ? balance : allowance;
  }

  function _checkAndCloseAccount(address _investor) internal {
    bool isDepositWithdrawn = accounts[_investor].vault.getBalance() == 0;
    bool isDividendsWithdrawn = deposits[_investor].length == 0;
    bool isDebtsWithdrawn = debts[_investor].length == 0;
    if (isDepositWithdrawn && isDividendsWithdrawn && isDebtsWithdrawn) {
      delete accounts[_investor];
      emit CloseAccount(_investor);
    }
  }

  function _withdrawOneDebt(address _investor, Currency _currency, uint _index) internal returns (bool) {
    Debt storage debt = debts[_investor][_index];
    return _send(_investor, debt.bfcl, debt.euro, _currency);
  }

  function _deleteDebt(address _investor, uint _index) internal {
    uint lastIndex = debts[_investor].length - 1;
    if (_index == lastIndex) {
      delete debts[_investor][_index];
    } else {
      debts[_investor][_index] = debts[_investor][lastIndex];
      delete debts[_investor][lastIndex];
    }
    emit DeleteDebt(_investor, _index);
    debts[_investor].length--;
  }

  function _checkAndReinvest(Deposit storage _deposit, uint _currentIntervalStart) internal {
    while (true) {
      uint nextDate = _getNextDate(_deposit.lastWithdrawTime);
      if (nextDate >= _currentIntervalStart) {
        return;
      }

      uint periodSeconds = nextDate.sub(_deposit.lastWithdrawTime);
      (uint bfclDividends, uint euroDividends) = _calculateDividendForPeriod(_deposit, periodSeconds);

      emit Reinvest(_deposit.bfcl, _deposit.euro, _deposit.lastWithdrawTime, bfclDividends, euroDividends, nextDate);

      _deposit.bfcl = _deposit.bfcl.add(bfclDividends);
      _deposit.euro = _deposit.euro.add(euroDividends);
      _deposit.lastWithdrawTime = nextDate;
    }
  }

  function _withdrawOneDividend(address _investor, Account storage _account, Currency _currency, uint _index)
    internal
    returns (bool result)
  {
    Deposit storage deposit = deposits[_investor][_index];
    uint intervalStart = _findIntervalStart(_account, now);
    if (deposit.lastWithdrawTime > intervalStart) {
      return false;
    }
    _checkAndReinvest(deposit, intervalStart);
    uint periodSeconds = intervalStart.sub(deposit.lastWithdrawTime);
    deposit.lastWithdrawTime = intervalStart;
    (uint bfclDividends, uint euroDividends) = _calculateDividendForPeriod(deposit, periodSeconds);
    result = _send(_investor, bfclDividends, euroDividends, _currency);
  }

  function _deleteDeposit(address _investor, uint _index) internal {
    uint lastIndex = deposits[_investor].length - 1;
    if (_index == lastIndex) {
      delete deposits[_investor][_index];
    } else {
      deposits[_investor][_index] = deposits[_investor][lastIndex];
      delete deposits[_investor][lastIndex];
    }
    emit DeleteDeposit(_investor, _index);
    deposits[_investor].length--;
  }

  function _calculateDividendForTimestamp(address _investor, uint _withdrawingTimestamp, uint _depositIndex)
    internal
    view
    returns (uint bfcl, uint euro)
  {
    Deposit storage deposit = deposits[_investor][_depositIndex];
    if (deposit.lastWithdrawTime >= _withdrawingTimestamp) {
      return (0, 0);
    }

    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;

    uint b = deposit.bfcl;
    uint e = deposit.euro;

    // check reinvestment
    uint lastWithdrawTime = deposit.lastWithdrawTime;
    while (true) {
      uint nextDate = _getNextDate(lastWithdrawTime);
      if (nextDate >= _withdrawingTimestamp) {
        break;
      }

      uint periodSeconds = nextDate.sub(lastWithdrawTime);
      (uint bfclDividends, uint euroDividends) = _calculateDividendForPeriod(b, e, periodSeconds);

      b = b.add(bfclDividends);
      e = e.add(euroDividends);

      lastWithdrawTime = nextDate;
    }

    // calculate dividends for last interval
    uint periodSeconds = _withdrawingTimestamp.sub(lastWithdrawTime);
    (bfcl, euro) = _calculateDividendForPeriod(b, e, periodSeconds);
    if (currency == Currency.BFCL) {
      euro = 0;
    } else if (_withdrawingTimestamp < accounts[_investor].stopTime) {
      bfcl = 0;
    }

    if (_withdrawingTimestamp >= accounts[_investor].stopTime) {
      if (currency == Currency.BFCL) {
        bfcl = bfcl.add(b);
      } else {
        bfcl = b;
      }
    }
  }

  function _calculateDividendForPeriod(Deposit storage _deposit, uint _periodSeconds)
    internal
    view
    returns (uint bfcl, uint euro)
  {
    (bfcl, euro) = _calculateDividendForPeriod(_deposit.bfcl, _deposit.euro, _periodSeconds);
  }

  function _calculateDividendForPeriod(uint _bfcl, uint _euro, uint _periodSeconds)
    internal
    view
    returns (uint bfcl, uint euro)
  {
    bfcl = _bfcl.mul(_periodSeconds).mul(PERCENT_PER_YEAR).div(HUNDRED_PERCENTS).div(365 days);
    euro = _euro.mul(_periodSeconds).mul(PERCENT_PER_YEAR).div(HUNDRED_PERCENTS).div(365 days);
  }

  function _send(address _investor, uint _bfclAmount, uint _euroAmount, Currency _currency) internal returns (bool) {
    if (_bfclAmount == 0 && _euroAmount == 0) {
      return false;
    }

    uint balance = _getBalance(_currency);
    if (_currency == Currency.EURO) {
      balance = balance.mul(RATE_MULTIPLIER).div(10 ** euroToken.decimals());
    }

    uint canPay;

    if ((_currency == Currency.BFCL && balance >= _bfclAmount) || (_currency == Currency.EURO && balance >= _euroAmount)) {
      if (_currency == Currency.BFCL) {
        canPay = _bfclAmount;
      } else {
        canPay = _euroAmount;
      }
    } else {
      canPay = balance;
      uint bfclDebt;
      uint euroDebt;
      if (_currency == Currency.BFCL) {
        bfclDebt = _bfclAmount.sub(canPay);
        euroDebt = bfclDebt.mul(_euroAmount).div(_bfclAmount);
      } else {
        euroDebt = _euroAmount.sub(canPay);
        bfclDebt = euroDebt.mul(_bfclAmount).div(_euroAmount);
      }

      debts[_investor].push(Debt(bfclDebt, euroDebt));
      emit AddDebt(_investor, bfclDebt, euroDebt);
    }

    if (canPay == 0) {
      return true;
    }

    uint toPay;
    IERC20 token;
    if (_currency == Currency.BFCL) {
      toPay = canPay;
      token = bfclToken;
    } else {
      toPay = canPay.mul(10 ** euroToken.decimals()).div(RATE_MULTIPLIER);
      token = euroToken;
    }

    token.transferFrom(tokensWallet, _investor, toPay);
    return true;
  }
}

pragma solidity ^0.5.8;

/**
 * @title ERC20 interface without bool returns
 * @dev see https://eips.ethereum.org/EIPS/eip-20
 */
interface IERC20 {
  function transfer(address to, uint256 value) external;

  function transferFrom(address from, address to, uint256 value) external;

  function decimals() external view returns (uint256);

  function balanceOf(address who) external view returns (uint256);

  function allowance(address owner, address spender) external view returns (uint256);
}

pragma solidity ^0.5.2;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     * @notice Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

pragma solidity ^0.5.8;

import "./Roles.sol";

contract PriceManagerRole {
  using Roles for Roles.Role;

  event PriceManagerAdded(address indexed account);
  event PriceManagerRemoved(address indexed account);

  Roles.Role private managers;

  constructor() internal {
    _addPriceManager(msg.sender);
  }

  modifier onlyPriceManager() {
    require(isPriceManager(msg.sender), "Only for price manager");
    _;
  }

  function isPriceManager(address account) public view returns (bool) {
    return managers.has(account);
  }

  function addPriceManager(address account) public onlyPriceManager {
    _addPriceManager(account);
  }

  function renouncePriceManager() public {
    _removePriceManager(msg.sender);
  }

  function _addPriceManager(address account) internal {
    managers.add(account);
    emit PriceManagerAdded(account);
  }

  function _removePriceManager(address account) internal {
    managers.remove(account);
    emit PriceManagerRemoved(account);
  }
}

pragma solidity ^0.5.2;

/**
 * @title Helps contracts guard against reentrancy attacks.
 * @author Remco Bloemen <remco@2π.com>, Eenae <alexey@mixbytes.io>
 * @dev If you mark a function `nonReentrant`, you should also
 * mark it `external`.
 */
contract ReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;

    constructor () internal {
        // The counter starts at one to prevent changing it from zero to a non-zero
        // value, which is a more expensive operation.
        _guardCounter = 1;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter);
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

pragma solidity ^0.5.8;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./IERC20.sol";

contract Vault is Ownable {
  using SafeMath for uint;

  address public investor;
  IERC20 internal bfclToken;

  constructor(address _investor, IERC20 _bfclToken) public {
    investor = _investor;
    bfclToken = _bfclToken;
  }

  // reverts erc223 transfers
  function tokenFallback(address, uint, bytes calldata) external pure {
    revert("ERC223 tokens not allowed in Vault");
  }

  function withdrawToInvestor(uint _amount) external onlyOwner returns (bool) {
    bfclToken.transfer(investor, _amount);
    return true;
  }

  function getBalance() public view returns (uint) {
    return bfclToken.balanceOf(address(this));
  }
}

pragma solidity ^0.5.8;

import "./Roles.sol";
import "./Ownable.sol";

contract Whitelist is Ownable {
  using Roles for Roles.Role;

  Roles.Role private whitelist;

  event WhitelistedAddressAdded(address indexed _address);

  function isWhitelisted(address _address) public view returns (bool) {
    return whitelist.has(_address);
  }

  function addAddressToWhitelist(address _address) external onlyOwner {
    _addAddressToWhitelist(_address);
  }

  function addAddressesToWhitelist(address[] calldata _addresses) external onlyOwner {
    for (uint i = 0; i < _addresses.length; i++) {
      _addAddressToWhitelist(_addresses[i]);
    }
  }

  function _addAddressToWhitelist(address _address) internal {
    whitelist.add(_address);
    emit WhitelistedAddressAdded(_address);
  }
}

pragma solidity ^0.5.8;

// https://github.com/pipermerriam/ethereum-datetime
contract DateTime {
  struct _DateTime {
    uint16 year;
    uint8 month;
    uint8 day;
    uint8 hour;
    uint8 minute;
    uint8 second;
    uint8 weekday;
  }

  uint constant DAY_IN_SECONDS = 86400;
  uint constant YEAR_IN_SECONDS = 31536000;
  uint constant LEAP_YEAR_IN_SECONDS = 31622400;

  uint constant HOUR_IN_SECONDS = 3600;
  uint constant MINUTE_IN_SECONDS = 60;

  uint16 constant ORIGIN_YEAR = 1970;

  function isLeapYear(uint16 year) internal pure returns (bool) {
    if (year % 4 != 0) {
      return false;
    }
    if (year % 100 != 0) {
      return true;
    }
    if (year % 400 != 0) {
      return false;
    }
    return true;
  }

  function leapYearsBefore(uint year) internal pure returns (uint) {
    year -= 1;
    return year / 4 - year / 100 + year / 400;
  }

  function getDaysInMonth(uint8 month, uint16 year) internal pure returns (uint8) {
    if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
      return 31;
    } else if (month == 4 || month == 6 || month == 9 || month == 11) {
      return 30;
    } else if (isLeapYear(year)) {
      return 29;
    } else {
      return 28;
    }
  }

  function parseTimestamp(uint timestamp) internal pure returns (_DateTime memory dt) {
    uint secondsAccountedFor = 0;
    uint buf;
    uint8 i;

    // Year
    dt.year = getYear(timestamp);
    buf = leapYearsBefore(dt.year) - leapYearsBefore(ORIGIN_YEAR);

    secondsAccountedFor += LEAP_YEAR_IN_SECONDS * buf;
    secondsAccountedFor += YEAR_IN_SECONDS * (dt.year - ORIGIN_YEAR - buf);

    // Month
    uint secondsInMonth;
    for (i = 1; i <= 12; i++) {
      secondsInMonth = DAY_IN_SECONDS * getDaysInMonth(i, dt.year);
      if (secondsInMonth + secondsAccountedFor > timestamp) {
        dt.month = i;
        break;
      }
      secondsAccountedFor += secondsInMonth;
    }

    // Day
    for (i = 1; i <= getDaysInMonth(dt.month, dt.year); i++) {
      if (DAY_IN_SECONDS + secondsAccountedFor > timestamp) {
        dt.day = i;
        break;
      }
      secondsAccountedFor += DAY_IN_SECONDS;
    }

    // Hour
    dt.hour = getHour(timestamp);

    // Minute
    dt.minute = getMinute(timestamp);

    // Second
    dt.second = getSecond(timestamp);
    dt.weekday = getWeekday(timestamp);
  }

  function getYear(uint timestamp) internal pure returns (uint16) {
    uint secondsAccountedFor = 0;
    uint16 year;
    uint numLeapYears;

    // Year
    year = uint16(ORIGIN_YEAR + timestamp / YEAR_IN_SECONDS);
    numLeapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);

    secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
    secondsAccountedFor += YEAR_IN_SECONDS * (year - ORIGIN_YEAR - numLeapYears);

    while (secondsAccountedFor > timestamp) {
      if (isLeapYear(uint16(year - 1))) {
        secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
      } else {
        secondsAccountedFor -= YEAR_IN_SECONDS;
      }
      year -= 1;
    }
    return year;
  }

  function getMonth(uint timestamp) internal pure returns (uint8) {
    return parseTimestamp(timestamp).month;
  }

  function getDay(uint timestamp) internal pure returns (uint8) {
    return parseTimestamp(timestamp).day;
  }

  function getHour(uint timestamp) internal pure returns (uint8) {
    return uint8((timestamp / 60 / 60) % 24);
  }

  function getMinute(uint timestamp) internal pure returns (uint8) {
    return uint8((timestamp / 60) % 60);
  }

  function getSecond(uint timestamp) internal pure returns (uint8) {
    return uint8(timestamp % 60);
  }

  function getWeekday(uint timestamp) internal pure returns (uint8) {
    return uint8((timestamp / DAY_IN_SECONDS + 4) % 7);
  }

  function toTimestamp(uint16 year, uint8 month, uint8 day) internal pure returns (uint timestamp) {
    return toTimestamp(year, month, day, 0, 0, 0);
  }

  function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour) internal pure returns (uint timestamp) {
    return toTimestamp(year, month, day, hour, 0, 0);
  }

  function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute)
    internal
    pure
    returns (uint timestamp)
  {
    return toTimestamp(year, month, day, hour, minute, 0);
  }

  function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute, uint8 second)
    internal
    pure
    returns (uint timestamp)
  {
    uint16 i;

    // Year
    for (i = ORIGIN_YEAR; i < year; i++) {
      if (isLeapYear(i)) {
        timestamp += LEAP_YEAR_IN_SECONDS;
      } else {
        timestamp += YEAR_IN_SECONDS;
      }
    }

    // Month
    uint8[12] memory monthDayCounts;
    monthDayCounts[0] = 31;
    if (isLeapYear(year)) {
      monthDayCounts[1] = 29;
    } else {
      monthDayCounts[1] = 28;
    }
    monthDayCounts[2] = 31;
    monthDayCounts[3] = 30;
    monthDayCounts[4] = 31;
    monthDayCounts[5] = 30;
    monthDayCounts[6] = 31;
    monthDayCounts[7] = 31;
    monthDayCounts[8] = 30;
    monthDayCounts[9] = 31;
    monthDayCounts[10] = 30;
    monthDayCounts[11] = 31;

    for (i = 1; i < month; i++) {
      timestamp += DAY_IN_SECONDS * monthDayCounts[i - 1];
    }

    // Day
    timestamp += DAY_IN_SECONDS * (day - 1);

    // Hour
    timestamp += HOUR_IN_SECONDS * (hour);

    // Minute
    timestamp += MINUTE_IN_SECONDS * (minute);

    // Second
    timestamp += second;

    return timestamp;
  }
}

pragma solidity ^0.5.8;

/*
 * 'Bolton Holding Group' CORPORATE BOND Subscription contract
 *
 * Token                : Bolton Coin (BFCL)
 * Interest rate        : 22% yearly
 * Duration subscription: 24 months
 *
 * Copyright (C) 2019 Raffaele Bini - 5esse Informatica (https://www.5esse.it)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import "./ReentrancyGuard.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
import "./Whitelist.sol";
import "./Vault.sol";
import "./PriceManagerRole.sol";
import "./DateTime.sol";

contract DepositPlan is Ownable, ReentrancyGuard, PriceManagerRole, DateTime {
  using SafeMath for uint;

  enum Currency {BFCL, EURO}

  event AddInvestor(address indexed investor);
  event CloseAccount(address indexed investor);
  event InvestorDeposit(address indexed investor, uint bfclAmount, uint euroAmount, uint depositTime);
  event Reinvest(
    uint oldBfcl,
    uint oldEuro,
    uint oldLastWithdrawTime,
    uint bfclDividends,
    uint euroDividends,
    uint lastWithdrawTime
  );
  event DeleteDebt(address indexed investor, uint index);
  event DeleteDeposit(address indexed investor, uint index);
  event AddDebt(address indexed investor, uint bfclDebt, uint euroDebt);

  uint internal constant RATE_MULTIPLIER = 10 ** 18;
  uint internal constant MIN_INVESTMENT_EURO_CENT = 50000 * RATE_MULTIPLIER; // 50k EURO in cents
  uint internal constant MIN_REPLENISH_EURO_CENT = 1000 * RATE_MULTIPLIER; // 1k EURO in cents
  uint internal HUNDRED_PERCENTS = 10000; // 100%
  uint internal PERCENT_PER_YEAR = 2200; // 22%

  IERC20 public bfclToken;
  IERC20 public euroToken;
  Whitelist public whitelist;
  address public tokensWallet;
  uint public bfclEuroRateFor72h; // 1 EUR = bfclEuroRateFor72h BFCL / 10^18
  bool public isStopped;

  mapping(address => Account) public accounts;
  mapping(address => Deposit[]) public deposits;
  mapping(address => Debt[]) public debts;

  struct Account {
    Vault vault;
    uint firstDepositTimestamp;
    uint stopTime;
  }

  struct Deposit {
    uint bfcl;
    uint euro;
    uint lastWithdrawTime;
  }

  struct Debt {
    uint bfcl;
    uint euro;
  }

  constructor(IERC20 _bfclToken, Whitelist _whitelist, address _tokensWallet, uint _initialBfclEuroRateFor72h) public {
    bfclToken = _bfclToken;
    whitelist = _whitelist;
    tokensWallet = _tokensWallet;
    bfclEuroRateFor72h = _initialBfclEuroRateFor72h;
  }

  modifier onlyIfWhitelisted() {
    require(whitelist.isWhitelisted(msg.sender), "Not whitelisted");
    _;
  }

  // reverts ETH transfers
  function() external {
    revert();
  }

  // reverts erc223 token transfers
  function tokenFallback(address, uint, bytes calldata) external pure {
    revert();
  }

  function transferErc20(IERC20 _token, address _to, uint _value) external onlyOwner nonReentrant {
    _token.transfer(_to, _value);
  }

  function transferBfcl(address _to, uint _value) external onlyOwner nonReentrant {
    bfclToken.transfer(_to, _value);
  }

  function stop() external onlyOwner {
    isStopped = true;
  }

  function invest(uint _bfclAmount) external onlyIfWhitelisted nonReentrant {
    require(!isStopped, "Contract stopped. You can no longer invest.");

    uint bfclAmount;
    uint euroAmount;

    address investor = msg.sender;
    Account storage account = accounts[investor];
    if (account.vault == Vault(0)) {
      // first deposit
      bfclAmount = _bfclAmount;
      euroAmount = _bfclAmount.mul(RATE_MULTIPLIER).div(bfclEuroRateFor72h);
      require(euroAmount >= MIN_INVESTMENT_EURO_CENT, "Should be more than minimum");
      account.vault = new Vault(investor, bfclToken);
      account.firstDepositTimestamp = now;
      account.stopTime = now + 730 days;

      emit AddInvestor(investor);
    } else {
      // replenish
      require(now < account.stopTime, "2 years have passed. You can no longer replenish.");
      uint oneKEuroInBfcl = bfclEuroRateFor72h.mul(MIN_REPLENISH_EURO_CENT).div(RATE_MULTIPLIER);
      uint times = _bfclAmount.div(oneKEuroInBfcl);
      bfclAmount = times.mul(oneKEuroInBfcl);
      euroAmount = times.mul(MIN_REPLENISH_EURO_CENT);
      require(euroAmount >= MIN_REPLENISH_EURO_CENT, "Should be more than minimum");
    }

    require(bfclToken.allowance(investor, address(this)) >= bfclAmount, "Allowance should not be less than amount");
    bfclToken.transferFrom(investor, address(account.vault), bfclAmount);

    deposits[investor].push(Deposit(bfclAmount, euroAmount, now));

    emit InvestorDeposit(investor, bfclAmount, euroAmount, now);
  }

  function withdraw() external nonReentrant {
    address investor = msg.sender;
    Account storage account = accounts[investor];
    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;
    uint result;
    result += _tryToWithdrawDividends(investor, account, currency);
    result += _tryToWithdrawDebts(investor, currency);
    require(result > 0, "Nothing to withdraw");
    _checkAndCloseAccount(investor);
  }

  function _tryToWithdrawDividends(address _investor, Account storage _account, Currency _currency)
    internal
    returns (uint result)
  {
    if (isInIntervals(now) || now >= _account.stopTime) {
      uint depositCount = deposits[_investor].length;
      if (depositCount > 0) {
        for (uint i = 0; i < depositCount; i++) {
          if (_withdrawOneDividend(_investor, _account, _currency, i)) {
            result++;
          }
        }

        if (now >= _account.stopTime) {
          for (uint i = depositCount; i > 0; i--) {
            _withdrawDeposit(_investor, i - 1);
          }
        }
      }
    }
  }

  function _tryToWithdrawDebts(address _investor, Currency _currency) internal returns (uint result) {
    uint debtCount = debts[_investor].length;
    if (debtCount > 0) {
      for (uint i = 0; i < debtCount; i++) {
        if (_withdrawOneDebt(_investor, _currency, i)) {
          result++;
        }
      }

      for (uint i = debtCount; i > 0; i--) {
        _deleteDebt(_investor, i - 1);
      }
    }
  }

  function _withdrawDeposit(address _investor, uint _index) internal {
    Vault vault = accounts[_investor].vault;
    Deposit storage deposit = deposits[_investor][_index];
    uint mustPay = deposit.bfcl;

    uint toPayFromVault;
    uint toPayFromWallet;
    if (vault.getBalance() >= mustPay) {
      toPayFromVault = mustPay;
    } else {
      toPayFromVault = vault.getBalance();
      toPayFromWallet = mustPay.sub(toPayFromVault);
    }

    _deleteDeposit(_investor, _index);

    if (toPayFromVault > 0) {
      vault.withdrawToInvestor(toPayFromVault);
    }

    if (toPayFromWallet > 0) {
      _send(_investor, toPayFromWallet, 0, Currency.BFCL);
    }
  }

  function withdrawDividends() external nonReentrant {
    address investor = msg.sender;
    Account storage account = accounts[investor];
    require(isInIntervals(now) || now >= account.stopTime, "Should be in interval or after 2 years");
    require(deposits[investor].length > 0, "There is no deposits for your address");
    uint result;
    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;
    result += _tryToWithdrawDividends(investor, account, currency);
    require(result > 0, "Nothing to withdraw");
    _checkAndCloseAccount(investor);
  }

  function withdrawOneDividend(uint index) external nonReentrant {
    address investor = msg.sender;
    Account storage account = accounts[investor];
    require(isInIntervals(now) || now >= account.stopTime, "Should be in interval or after 2 years");
    require(deposits[investor].length > 0, "There is no deposits for your address");

    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;
    require(_withdrawOneDividend(investor, account, currency, index), "Nothing to withdraw");
    if (now >= account.stopTime) {
      _withdrawDeposit(investor, index);
    }
    _checkAndCloseAccount(investor);
  }

  function withdrawDebts() external nonReentrant {
    address investor = msg.sender;
    require(debts[investor].length > 0, "There is no deposits for your address");

    uint result;
    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;
    result += _tryToWithdrawDebts(investor, currency);
    require(result > 0, "Nothing to withdraw");
    _checkAndCloseAccount(investor);
  }

  function withdrawOneDebt(uint index) external nonReentrant {
    address investor = msg.sender;
    require(debts[investor].length > 0, "There is no deposits for your address");

    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;
    require(_withdrawOneDebt(investor, currency, index), "Nothing to withdraw");
    _deleteDebt(investor, index);
    _checkAndCloseAccount(investor);
  }

  function setBfclEuroRateFor72h(uint _rate) public onlyPriceManager {
    bfclEuroRateFor72h = _rate;
  }

  function switchToBfcl() public onlyOwner {
    require(address(euroToken) != address(0), "You are already using BFCL");
    euroToken = IERC20(address(0));
  }

  function switchToEuro(IERC20 _euro) public onlyOwner {
    require(address(_euro) != address(euroToken), "Trying to change euro token to same address");
    euroToken = _euro;
  }

  function calculateDividendsForTimestamp(address _investor, uint _timestamp)
    public
    view
    returns (uint bfcl, uint euro)
  {
    Account storage account = accounts[_investor];
    uint withdrawingTimestamp = _findIntervalStart(account, _timestamp);

    for (uint i = 0; i < deposits[_investor].length; i++) {
      (uint bfclDiv, uint euroDiv) = _calculateDividendForTimestamp(_investor, withdrawingTimestamp, i);
      bfcl = bfcl.add(bfclDiv);
      euro = euro.add(euroDiv);
    }

    if (withdrawingTimestamp >= account.stopTime) {
      bfcl = bfcl.sub(account.vault.getBalance());
    }
  }

  function calculateGroupDividendsForTimestamp(address[] memory _investors, uint _timestamp)
    public
    view
    returns (uint bfcl, uint euro)
  {
    for (uint i = 0; i < _investors.length; i++) {
      address investor = _investors[i];
      Account storage account = accounts[investor];
      uint withdrawingTimestamp = _findIntervalStart(account, _timestamp);

      for (uint d = 0; d < deposits[investor].length; d++) {
        (uint bfclDiv, uint euroDiv) = _calculateDividendForTimestamp(investor, withdrawingTimestamp, d);
        bfcl = bfcl.add(bfclDiv);
        euro = euro.add(euroDiv);
      }

      if (withdrawingTimestamp >= account.stopTime) {
        bfcl = bfcl.sub(account.vault.getBalance());
      }
    }
  }

  function calculateDividendsWithDebtsForTimestamp(address _investor, uint _timestamp)
    public
    view
    returns (uint bfcl, uint euro)
  {
    (bfcl, euro) = calculateDividendsForTimestamp(_investor, _timestamp);
    for (uint d = 0; d < debts[_investor].length; d++) {
      Debt storage debt = debts[_investor][d];
      bfcl = bfcl.add(debt.bfcl);
      euro = euro.add(debt.euro);
    }
  }

  function calculateGroupDividendsWithDebtsForTimestamp(address[] memory _investors, uint _timestamp)
    public
    view
    returns (uint bfcl, uint euro)
  {
    (bfcl, euro) = calculateGroupDividendsForTimestamp(_investors, _timestamp);
    for (uint i = 0; i < _investors.length; i++) {
      address investor = _investors[i];
      for (uint d = 0; d < debts[investor].length; d++) {
        Debt storage debt = debts[investor][d];
        bfcl = bfcl.add(debt.bfcl);
        euro = euro.add(debt.euro);
      }
    }
  }

  function isInIntervals(uint _timestamp) public pure returns (bool) {
    uint8[4] memory months = [1, 4, 7, 10];

    _DateTime memory dt = parseTimestamp(_timestamp);
    for (uint i = 0; i < months.length; i++) {
      if (dt.month == months[i]) {
        return 1 <= dt.day && dt.day <= 5;
      }
    }

    return false;
  }

  function _getNextDate(uint _timestamp) internal pure returns (uint) {
    _DateTime memory dt = parseTimestamp(_timestamp);

    uint16 year;
    uint8 month;

    uint8[4] memory months = [1, 4, 7, 10];
    for (uint i = months.length; i > 0; --i) {
      if (dt.month >= months[i - 1]) {
        if (i == months.length) {
          year = dt.year + 1;
          month = months[0];
        } else {
          year = dt.year;
          month = months[i];
        }
        break;
      }
    }

    return toTimestamp(year, month, 1);
  }

  // implies that the timestamp is exactly in any of the intervals or after stopTime
  function _findIntervalStart(Account storage _account, uint _timestamp) internal view returns (uint) {
    if (_timestamp >= _account.stopTime) {
      return _account.stopTime;
    } else {
      _DateTime memory dt = parseTimestamp(_timestamp);
      return toTimestamp(dt.year, dt.month, 1);
    }
  }

  function _getBalance(Currency _currency) internal view returns (uint) {
    IERC20 token = _currency == Currency.BFCL ? bfclToken : euroToken;
    uint balance = token.balanceOf(tokensWallet);
    uint allowance = token.allowance(tokensWallet, address(this));
    return balance < allowance ? balance : allowance;
  }

  function _checkAndCloseAccount(address _investor) internal {
    bool isDepositWithdrawn = accounts[_investor].vault.getBalance() == 0;
    bool isDividendsWithdrawn = deposits[_investor].length == 0;
    bool isDebtsWithdrawn = debts[_investor].length == 0;
    if (isDepositWithdrawn && isDividendsWithdrawn && isDebtsWithdrawn) {
      delete accounts[_investor];
      emit CloseAccount(_investor);
    }
  }

  function _withdrawOneDebt(address _investor, Currency _currency, uint _index) internal returns (bool) {
    Debt storage debt = debts[_investor][_index];
    return _send(_investor, debt.bfcl, debt.euro, _currency);
  }

  function _deleteDebt(address _investor, uint _index) internal {
    uint lastIndex = debts[_investor].length - 1;
    if (_index == lastIndex) {
      delete debts[_investor][_index];
    } else {
      debts[_investor][_index] = debts[_investor][lastIndex];
      delete debts[_investor][lastIndex];
    }
    emit DeleteDebt(_investor, _index);
    debts[_investor].length--;
  }

  function _checkAndReinvest(Deposit storage _deposit, uint _currentIntervalStart) internal {
    while (true) {
      uint nextDate = _getNextDate(_deposit.lastWithdrawTime);
      if (nextDate >= _currentIntervalStart) {
        return;
      }

      uint periodSeconds = nextDate.sub(_deposit.lastWithdrawTime);
      (uint bfclDividends, uint euroDividends) = _calculateDividendForPeriod(_deposit, periodSeconds);

      emit Reinvest(_deposit.bfcl, _deposit.euro, _deposit.lastWithdrawTime, bfclDividends, euroDividends, nextDate);

      _deposit.bfcl = _deposit.bfcl.add(bfclDividends);
      _deposit.euro = _deposit.euro.add(euroDividends);
      _deposit.lastWithdrawTime = nextDate;
    }
  }

  function _withdrawOneDividend(address _investor, Account storage _account, Currency _currency, uint _index)
    internal
    returns (bool result)
  {
    Deposit storage deposit = deposits[_investor][_index];
    uint intervalStart = _findIntervalStart(_account, now);
    if (deposit.lastWithdrawTime > intervalStart) {
      return false;
    }
    _checkAndReinvest(deposit, intervalStart);
    uint periodSeconds = intervalStart.sub(deposit.lastWithdrawTime);
    deposit.lastWithdrawTime = intervalStart;
    (uint bfclDividends, uint euroDividends) = _calculateDividendForPeriod(deposit, periodSeconds);
    result = _send(_investor, bfclDividends, euroDividends, _currency);
  }

  function _deleteDeposit(address _investor, uint _index) internal {
    uint lastIndex = deposits[_investor].length - 1;
    if (_index == lastIndex) {
      delete deposits[_investor][_index];
    } else {
      deposits[_investor][_index] = deposits[_investor][lastIndex];
      delete deposits[_investor][lastIndex];
    }
    emit DeleteDeposit(_investor, _index);
    deposits[_investor].length--;
  }

  function _calculateDividendForTimestamp(address _investor, uint _withdrawingTimestamp, uint _depositIndex)
    internal
    view
    returns (uint bfcl, uint euro)
  {
    Deposit storage deposit = deposits[_investor][_depositIndex];
    if (deposit.lastWithdrawTime >= _withdrawingTimestamp) {
      return (0, 0);
    }

    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;

    uint b = deposit.bfcl;
    uint e = deposit.euro;

    // check reinvestment
    uint lastWithdrawTime = deposit.lastWithdrawTime;
    while (true) {
      uint nextDate = _getNextDate(lastWithdrawTime);
      if (nextDate >= _withdrawingTimestamp) {
        break;
      }

      uint periodSeconds = nextDate.sub(lastWithdrawTime);
      (uint bfclDividends, uint euroDividends) = _calculateDividendForPeriod(b, e, periodSeconds);

      b = b.add(bfclDividends);
      e = e.add(euroDividends);

      lastWithdrawTime = nextDate;
    }

    // calculate dividends for last interval
    uint periodSeconds = _withdrawingTimestamp.sub(lastWithdrawTime);
    (bfcl, euro) = _calculateDividendForPeriod(b, e, periodSeconds);
    if (currency == Currency.BFCL) {
      euro = 0;
    } else if (_withdrawingTimestamp < accounts[_investor].stopTime) {
      bfcl = 0;
    }

    if (_withdrawingTimestamp >= accounts[_investor].stopTime) {
      if (currency == Currency.BFCL) {
        bfcl = bfcl.add(b);
      } else {
        bfcl = b;
      }
    }
  }

  function _calculateDividendForPeriod(Deposit storage _deposit, uint _periodSeconds)
    internal
    view
    returns (uint bfcl, uint euro)
  {
    (bfcl, euro) = _calculateDividendForPeriod(_deposit.bfcl, _deposit.euro, _periodSeconds);
  }

  function _calculateDividendForPeriod(uint _bfcl, uint _euro, uint _periodSeconds)
    internal
    view
    returns (uint bfcl, uint euro)
  {
    bfcl = _bfcl.mul(_periodSeconds).mul(PERCENT_PER_YEAR).div(HUNDRED_PERCENTS).div(365 days);
    euro = _euro.mul(_periodSeconds).mul(PERCENT_PER_YEAR).div(HUNDRED_PERCENTS).div(365 days);
  }

  function _send(address _investor, uint _bfclAmount, uint _euroAmount, Currency _currency) internal returns (bool) {
    if (_bfclAmount == 0 && _euroAmount == 0) {
      return false;
    }

    uint balance = _getBalance(_currency);
    if (_currency == Currency.EURO) {
      balance = balance.mul(RATE_MULTIPLIER).div(10 ** euroToken.decimals());
    }

    uint canPay;

    if ((_currency == Currency.BFCL && balance >= _bfclAmount) || (_currency == Currency.EURO && balance >= _euroAmount)) {
      if (_currency == Currency.BFCL) {
        canPay = _bfclAmount;
      } else {
        canPay = _euroAmount;
      }
    } else {
      canPay = balance;
      uint bfclDebt;
      uint euroDebt;
      if (_currency == Currency.BFCL) {
        bfclDebt = _bfclAmount.sub(canPay);
        euroDebt = bfclDebt.mul(_euroAmount).div(_bfclAmount);
      } else {
        euroDebt = _euroAmount.sub(canPay);
        bfclDebt = euroDebt.mul(_bfclAmount).div(_euroAmount);
      }

      debts[_investor].push(Debt(bfclDebt, euroDebt));
      emit AddDebt(_investor, bfclDebt, euroDebt);
    }

    if (canPay == 0) {
      return true;
    }

    uint toPay;
    IERC20 token;
    if (_currency == Currency.BFCL) {
      toPay = canPay;
      token = bfclToken;
    } else {
      toPay = canPay.mul(10 ** euroToken.decimals()).div(RATE_MULTIPLIER);
      token = euroToken;
    }

    token.transferFrom(tokensWallet, _investor, toPay);
    return true;
  }
}

pragma solidity ^0.5.8;

/**
 * @title ERC20 interface without bool returns
 * @dev see https://eips.ethereum.org/EIPS/eip-20
 */
interface IERC20 {
  function transfer(address to, uint256 value) external;

  function transferFrom(address from, address to, uint256 value) external;

  function decimals() external view returns (uint256);

  function balanceOf(address who) external view returns (uint256);

  function allowance(address owner, address spender) external view returns (uint256);
}

pragma solidity ^0.5.2;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     * @notice Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

pragma solidity ^0.5.8;

import "./Roles.sol";

contract PriceManagerRole {
  using Roles for Roles.Role;

  event PriceManagerAdded(address indexed account);
  event PriceManagerRemoved(address indexed account);

  Roles.Role private managers;

  constructor() internal {
    _addPriceManager(msg.sender);
  }

  modifier onlyPriceManager() {
    require(isPriceManager(msg.sender), "Only for price manager");
    _;
  }

  function isPriceManager(address account) public view returns (bool) {
    return managers.has(account);
  }

  function addPriceManager(address account) public onlyPriceManager {
    _addPriceManager(account);
  }

  function renouncePriceManager() public {
    _removePriceManager(msg.sender);
  }

  function _addPriceManager(address account) internal {
    managers.add(account);
    emit PriceManagerAdded(account);
  }

  function _removePriceManager(address account) internal {
    managers.remove(account);
    emit PriceManagerRemoved(account);
  }
}

pragma solidity ^0.5.2;

/**
 * @title Helps contracts guard against reentrancy attacks.
 * @author Remco Bloemen <remco@2π.com>, Eenae <alexey@mixbytes.io>
 * @dev If you mark a function `nonReentrant`, you should also
 * mark it `external`.
 */
contract ReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;

    constructor () internal {
        // The counter starts at one to prevent changing it from zero to a non-zero
        // value, which is a more expensive operation.
        _guardCounter = 1;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter);
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

pragma solidity ^0.5.8;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./IERC20.sol";

contract Vault is Ownable {
  using SafeMath for uint;

  address public investor;
  IERC20 internal bfclToken;

  constructor(address _investor, IERC20 _bfclToken) public {
    investor = _investor;
    bfclToken = _bfclToken;
  }

  // reverts erc223 transfers
  function tokenFallback(address, uint, bytes calldata) external pure {
    revert("ERC223 tokens not allowed in Vault");
  }

  function withdrawToInvestor(uint _amount) external onlyOwner returns (bool) {
    bfclToken.transfer(investor, _amount);
    return true;
  }

  function getBalance() public view returns (uint) {
    return bfclToken.balanceOf(address(this));
  }
}

pragma solidity ^0.5.8;

import "./Roles.sol";
import "./Ownable.sol";

contract Whitelist is Ownable {
  using Roles for Roles.Role;

  Roles.Role private whitelist;

  event WhitelistedAddressAdded(address indexed _address);

  function isWhitelisted(address _address) public view returns (bool) {
    return whitelist.has(_address);
  }

  function addAddressToWhitelist(address _address) external onlyOwner {
    _addAddressToWhitelist(_address);
  }

  function addAddressesToWhitelist(address[] calldata _addresses) external onlyOwner {
    for (uint i = 0; i < _addresses.length; i++) {
      _addAddressToWhitelist(_addresses[i]);
    }
  }

  function _addAddressToWhitelist(address _address) internal {
    whitelist.add(_address);
    emit WhitelistedAddressAdded(_address);
  }
}

pragma solidity ^0.5.8;

// https://github.com/pipermerriam/ethereum-datetime
contract DateTime {
  struct _DateTime {
    uint16 year;
    uint8 month;
    uint8 day;
    uint8 hour;
    uint8 minute;
    uint8 second;
    uint8 weekday;
  }

  uint constant DAY_IN_SECONDS = 86400;
  uint constant YEAR_IN_SECONDS = 31536000;
  uint constant LEAP_YEAR_IN_SECONDS = 31622400;

  uint constant HOUR_IN_SECONDS = 3600;
  uint constant MINUTE_IN_SECONDS = 60;

  uint16 constant ORIGIN_YEAR = 1970;

  function isLeapYear(uint16 year) internal pure returns (bool) {
    if (year % 4 != 0) {
      return false;
    }
    if (year % 100 != 0) {
      return true;
    }
    if (year % 400 != 0) {
      return false;
    }
    return true;
  }

  function leapYearsBefore(uint year) internal pure returns (uint) {
    year -= 1;
    return year / 4 - year / 100 + year / 400;
  }

  function getDaysInMonth(uint8 month, uint16 year) internal pure returns (uint8) {
    if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
      return 31;
    } else if (month == 4 || month == 6 || month == 9 || month == 11) {
      return 30;
    } else if (isLeapYear(year)) {
      return 29;
    } else {
      return 28;
    }
  }

  function parseTimestamp(uint timestamp) internal pure returns (_DateTime memory dt) {
    uint secondsAccountedFor = 0;
    uint buf;
    uint8 i;

    // Year
    dt.year = getYear(timestamp);
    buf = leapYearsBefore(dt.year) - leapYearsBefore(ORIGIN_YEAR);

    secondsAccountedFor += LEAP_YEAR_IN_SECONDS * buf;
    secondsAccountedFor += YEAR_IN_SECONDS * (dt.year - ORIGIN_YEAR - buf);

    // Month
    uint secondsInMonth;
    for (i = 1; i <= 12; i++) {
      secondsInMonth = DAY_IN_SECONDS * getDaysInMonth(i, dt.year);
      if (secondsInMonth + secondsAccountedFor > timestamp) {
        dt.month = i;
        break;
      }
      secondsAccountedFor += secondsInMonth;
    }

    // Day
    for (i = 1; i <= getDaysInMonth(dt.month, dt.year); i++) {
      if (DAY_IN_SECONDS + secondsAccountedFor > timestamp) {
        dt.day = i;
        break;
      }
      secondsAccountedFor += DAY_IN_SECONDS;
    }

    // Hour
    dt.hour = getHour(timestamp);

    // Minute
    dt.minute = getMinute(timestamp);

    // Second
    dt.second = getSecond(timestamp);
    dt.weekday = getWeekday(timestamp);
  }

  function getYear(uint timestamp) internal pure returns (uint16) {
    uint secondsAccountedFor = 0;
    uint16 year;
    uint numLeapYears;

    // Year
    year = uint16(ORIGIN_YEAR + timestamp / YEAR_IN_SECONDS);
    numLeapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);

    secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
    secondsAccountedFor += YEAR_IN_SECONDS * (year - ORIGIN_YEAR - numLeapYears);

    while (secondsAccountedFor > timestamp) {
      if (isLeapYear(uint16(year - 1))) {
        secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
      } else {
        secondsAccountedFor -= YEAR_IN_SECONDS;
      }
      year -= 1;
    }
    return year;
  }

  function getMonth(uint timestamp) internal pure returns (uint8) {
    return parseTimestamp(timestamp).month;
  }

  function getDay(uint timestamp) internal pure returns (uint8) {
    return parseTimestamp(timestamp).day;
  }

  function getHour(uint timestamp) internal pure returns (uint8) {
    return uint8((timestamp / 60 / 60) % 24);
  }

  function getMinute(uint timestamp) internal pure returns (uint8) {
    return uint8((timestamp / 60) % 60);
  }

  function getSecond(uint timestamp) internal pure returns (uint8) {
    return uint8(timestamp % 60);
  }

  function getWeekday(uint timestamp) internal pure returns (uint8) {
    return uint8((timestamp / DAY_IN_SECONDS + 4) % 7);
  }

  function toTimestamp(uint16 year, uint8 month, uint8 day) internal pure returns (uint timestamp) {
    return toTimestamp(year, month, day, 0, 0, 0);
  }

  function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour) internal pure returns (uint timestamp) {
    return toTimestamp(year, month, day, hour, 0, 0);
  }

  function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute)
    internal
    pure
    returns (uint timestamp)
  {
    return toTimestamp(year, month, day, hour, minute, 0);
  }

  function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute, uint8 second)
    internal
    pure
    returns (uint timestamp)
  {
    uint16 i;

    // Year
    for (i = ORIGIN_YEAR; i < year; i++) {
      if (isLeapYear(i)) {
        timestamp += LEAP_YEAR_IN_SECONDS;
      } else {
        timestamp += YEAR_IN_SECONDS;
      }
    }

    // Month
    uint8[12] memory monthDayCounts;
    monthDayCounts[0] = 31;
    if (isLeapYear(year)) {
      monthDayCounts[1] = 29;
    } else {
      monthDayCounts[1] = 28;
    }
    monthDayCounts[2] = 31;
    monthDayCounts[3] = 30;
    monthDayCounts[4] = 31;
    monthDayCounts[5] = 30;
    monthDayCounts[6] = 31;
    monthDayCounts[7] = 31;
    monthDayCounts[8] = 30;
    monthDayCounts[9] = 31;
    monthDayCounts[10] = 30;
    monthDayCounts[11] = 31;

    for (i = 1; i < month; i++) {
      timestamp += DAY_IN_SECONDS * monthDayCounts[i - 1];
    }

    // Day
    timestamp += DAY_IN_SECONDS * (day - 1);

    // Hour
    timestamp += HOUR_IN_SECONDS * (hour);

    // Minute
    timestamp += MINUTE_IN_SECONDS * (minute);

    // Second
    timestamp += second;

    return timestamp;
  }
}

pragma solidity ^0.5.8;

/*
 * 'Bolton Holding Group' CORPORATE BOND Subscription contract
 *
 * Token                : Bolton Coin (BFCL)
 * Interest rate        : 22% yearly
 * Duration subscription: 24 months
 *
 * Copyright (C) 2019 Raffaele Bini - 5esse Informatica (https://www.5esse.it)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import "./ReentrancyGuard.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
import "./Whitelist.sol";
import "./Vault.sol";
import "./PriceManagerRole.sol";
import "./DateTime.sol";

contract DepositPlan is Ownable, ReentrancyGuard, PriceManagerRole, DateTime {
  using SafeMath for uint;

  enum Currency {BFCL, EURO}

  event AddInvestor(address indexed investor);
  event CloseAccount(address indexed investor);
  event InvestorDeposit(address indexed investor, uint bfclAmount, uint euroAmount, uint depositTime);
  event Reinvest(
    uint oldBfcl,
    uint oldEuro,
    uint oldLastWithdrawTime,
    uint bfclDividends,
    uint euroDividends,
    uint lastWithdrawTime
  );
  event DeleteDebt(address indexed investor, uint index);
  event DeleteDeposit(address indexed investor, uint index);
  event AddDebt(address indexed investor, uint bfclDebt, uint euroDebt);

  uint internal constant RATE_MULTIPLIER = 10 ** 18;
  uint internal constant MIN_INVESTMENT_EURO_CENT = 50000 * RATE_MULTIPLIER; // 50k EURO in cents
  uint internal constant MIN_REPLENISH_EURO_CENT = 1000 * RATE_MULTIPLIER; // 1k EURO in cents
  uint internal HUNDRED_PERCENTS = 10000; // 100%
  uint internal PERCENT_PER_YEAR = 2200; // 22%

  IERC20 public bfclToken;
  IERC20 public euroToken;
  Whitelist public whitelist;
  address public tokensWallet;
  uint public bfclEuroRateFor72h; // 1 EUR = bfclEuroRateFor72h BFCL / 10^18
  bool public isStopped;

  mapping(address => Account) public accounts;
  mapping(address => Deposit[]) public deposits;
  mapping(address => Debt[]) public debts;

  struct Account {
    Vault vault;
    uint firstDepositTimestamp;
    uint stopTime;
  }

  struct Deposit {
    uint bfcl;
    uint euro;
    uint lastWithdrawTime;
  }

  struct Debt {
    uint bfcl;
    uint euro;
  }

  constructor(IERC20 _bfclToken, Whitelist _whitelist, address _tokensWallet, uint _initialBfclEuroRateFor72h) public {
    bfclToken = _bfclToken;
    whitelist = _whitelist;
    tokensWallet = _tokensWallet;
    bfclEuroRateFor72h = _initialBfclEuroRateFor72h;
  }

  modifier onlyIfWhitelisted() {
    require(whitelist.isWhitelisted(msg.sender), "Not whitelisted");
    _;
  }

  // reverts ETH transfers
  function() external {
    revert();
  }

  // reverts erc223 token transfers
  function tokenFallback(address, uint, bytes calldata) external pure {
    revert();
  }

  function transferErc20(IERC20 _token, address _to, uint _value) external onlyOwner nonReentrant {
    _token.transfer(_to, _value);
  }

  function transferBfcl(address _to, uint _value) external onlyOwner nonReentrant {
    bfclToken.transfer(_to, _value);
  }

  function stop() external onlyOwner {
    isStopped = true;
  }

  function invest(uint _bfclAmount) external onlyIfWhitelisted nonReentrant {
    require(!isStopped, "Contract stopped. You can no longer invest.");

    uint bfclAmount;
    uint euroAmount;

    address investor = msg.sender;
    Account storage account = accounts[investor];
    if (account.vault == Vault(0)) {
      // first deposit
      bfclAmount = _bfclAmount;
      euroAmount = _bfclAmount.mul(RATE_MULTIPLIER).div(bfclEuroRateFor72h);
      require(euroAmount >= MIN_INVESTMENT_EURO_CENT, "Should be more than minimum");
      account.vault = new Vault(investor, bfclToken);
      account.firstDepositTimestamp = now;
      account.stopTime = now + 730 days;

      emit AddInvestor(investor);
    } else {
      // replenish
      require(now < account.stopTime, "2 years have passed. You can no longer replenish.");
      uint oneKEuroInBfcl = bfclEuroRateFor72h.mul(MIN_REPLENISH_EURO_CENT).div(RATE_MULTIPLIER);
      uint times = _bfclAmount.div(oneKEuroInBfcl);
      bfclAmount = times.mul(oneKEuroInBfcl);
      euroAmount = times.mul(MIN_REPLENISH_EURO_CENT);
      require(euroAmount >= MIN_REPLENISH_EURO_CENT, "Should be more than minimum");
    }

    require(bfclToken.allowance(investor, address(this)) >= bfclAmount, "Allowance should not be less than amount");
    bfclToken.transferFrom(investor, address(account.vault), bfclAmount);

    deposits[investor].push(Deposit(bfclAmount, euroAmount, now));

    emit InvestorDeposit(investor, bfclAmount, euroAmount, now);
  }

  function withdraw() external nonReentrant {
    address investor = msg.sender;
    Account storage account = accounts[investor];
    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;
    uint result;
    result += _tryToWithdrawDividends(investor, account, currency);
    result += _tryToWithdrawDebts(investor, currency);
    require(result > 0, "Nothing to withdraw");
    _checkAndCloseAccount(investor);
  }

  function _tryToWithdrawDividends(address _investor, Account storage _account, Currency _currency)
    internal
    returns (uint result)
  {
    if (isInIntervals(now) || now >= _account.stopTime) {
      uint depositCount = deposits[_investor].length;
      if (depositCount > 0) {
        for (uint i = 0; i < depositCount; i++) {
          if (_withdrawOneDividend(_investor, _account, _currency, i)) {
            result++;
          }
        }

        if (now >= _account.stopTime) {
          for (uint i = depositCount; i > 0; i--) {
            _withdrawDeposit(_investor, i - 1);
          }
        }
      }
    }
  }

  function _tryToWithdrawDebts(address _investor, Currency _currency) internal returns (uint result) {
    uint debtCount = debts[_investor].length;
    if (debtCount > 0) {
      for (uint i = 0; i < debtCount; i++) {
        if (_withdrawOneDebt(_investor, _currency, i)) {
          result++;
        }
      }

      for (uint i = debtCount; i > 0; i--) {
        _deleteDebt(_investor, i - 1);
      }
    }
  }

  function _withdrawDeposit(address _investor, uint _index) internal {
    Vault vault = accounts[_investor].vault;
    Deposit storage deposit = deposits[_investor][_index];
    uint mustPay = deposit.bfcl;

    uint toPayFromVault;
    uint toPayFromWallet;
    if (vault.getBalance() >= mustPay) {
      toPayFromVault = mustPay;
    } else {
      toPayFromVault = vault.getBalance();
      toPayFromWallet = mustPay.sub(toPayFromVault);
    }

    _deleteDeposit(_investor, _index);

    if (toPayFromVault > 0) {
      vault.withdrawToInvestor(toPayFromVault);
    }

    if (toPayFromWallet > 0) {
      _send(_investor, toPayFromWallet, 0, Currency.BFCL);
    }
  }

  function withdrawDividends() external nonReentrant {
    address investor = msg.sender;
    Account storage account = accounts[investor];
    require(isInIntervals(now) || now >= account.stopTime, "Should be in interval or after 2 years");
    require(deposits[investor].length > 0, "There is no deposits for your address");
    uint result;
    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;
    result += _tryToWithdrawDividends(investor, account, currency);
    require(result > 0, "Nothing to withdraw");
    _checkAndCloseAccount(investor);
  }

  function withdrawOneDividend(uint index) external nonReentrant {
    address investor = msg.sender;
    Account storage account = accounts[investor];
    require(isInIntervals(now) || now >= account.stopTime, "Should be in interval or after 2 years");
    require(deposits[investor].length > 0, "There is no deposits for your address");

    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;
    require(_withdrawOneDividend(investor, account, currency, index), "Nothing to withdraw");
    if (now >= account.stopTime) {
      _withdrawDeposit(investor, index);
    }
    _checkAndCloseAccount(investor);
  }

  function withdrawDebts() external nonReentrant {
    address investor = msg.sender;
    require(debts[investor].length > 0, "There is no deposits for your address");

    uint result;
    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;
    result += _tryToWithdrawDebts(investor, currency);
    require(result > 0, "Nothing to withdraw");
    _checkAndCloseAccount(investor);
  }

  function withdrawOneDebt(uint index) external nonReentrant {
    address investor = msg.sender;
    require(debts[investor].length > 0, "There is no deposits for your address");

    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;
    require(_withdrawOneDebt(investor, currency, index), "Nothing to withdraw");
    _deleteDebt(investor, index);
    _checkAndCloseAccount(investor);
  }

  function setBfclEuroRateFor72h(uint _rate) public onlyPriceManager {
    bfclEuroRateFor72h = _rate;
  }

  function switchToBfcl() public onlyOwner {
    require(address(euroToken) != address(0), "You are already using BFCL");
    euroToken = IERC20(address(0));
  }

  function switchToEuro(IERC20 _euro) public onlyOwner {
    require(address(_euro) != address(euroToken), "Trying to change euro token to same address");
    euroToken = _euro;
  }

  function calculateDividendsForTimestamp(address _investor, uint _timestamp)
    public
    view
    returns (uint bfcl, uint euro)
  {
    Account storage account = accounts[_investor];
    uint withdrawingTimestamp = _findIntervalStart(account, _timestamp);

    for (uint i = 0; i < deposits[_investor].length; i++) {
      (uint bfclDiv, uint euroDiv) = _calculateDividendForTimestamp(_investor, withdrawingTimestamp, i);
      bfcl = bfcl.add(bfclDiv);
      euro = euro.add(euroDiv);
    }

    if (withdrawingTimestamp >= account.stopTime) {
      bfcl = bfcl.sub(account.vault.getBalance());
    }
  }

  function calculateGroupDividendsForTimestamp(address[] memory _investors, uint _timestamp)
    public
    view
    returns (uint bfcl, uint euro)
  {
    for (uint i = 0; i < _investors.length; i++) {
      address investor = _investors[i];
      Account storage account = accounts[investor];
      uint withdrawingTimestamp = _findIntervalStart(account, _timestamp);

      for (uint d = 0; d < deposits[investor].length; d++) {
        (uint bfclDiv, uint euroDiv) = _calculateDividendForTimestamp(investor, withdrawingTimestamp, d);
        bfcl = bfcl.add(bfclDiv);
        euro = euro.add(euroDiv);
      }

      if (withdrawingTimestamp >= account.stopTime) {
        bfcl = bfcl.sub(account.vault.getBalance());
      }
    }
  }

  function calculateDividendsWithDebtsForTimestamp(address _investor, uint _timestamp)
    public
    view
    returns (uint bfcl, uint euro)
  {
    (bfcl, euro) = calculateDividendsForTimestamp(_investor, _timestamp);
    for (uint d = 0; d < debts[_investor].length; d++) {
      Debt storage debt = debts[_investor][d];
      bfcl = bfcl.add(debt.bfcl);
      euro = euro.add(debt.euro);
    }
  }

  function calculateGroupDividendsWithDebtsForTimestamp(address[] memory _investors, uint _timestamp)
    public
    view
    returns (uint bfcl, uint euro)
  {
    (bfcl, euro) = calculateGroupDividendsForTimestamp(_investors, _timestamp);
    for (uint i = 0; i < _investors.length; i++) {
      address investor = _investors[i];
      for (uint d = 0; d < debts[investor].length; d++) {
        Debt storage debt = debts[investor][d];
        bfcl = bfcl.add(debt.bfcl);
        euro = euro.add(debt.euro);
      }
    }
  }

  function isInIntervals(uint _timestamp) public pure returns (bool) {
    uint8[4] memory months = [1, 4, 7, 10];

    _DateTime memory dt = parseTimestamp(_timestamp);
    for (uint i = 0; i < months.length; i++) {
      if (dt.month == months[i]) {
        return 1 <= dt.day && dt.day <= 5;
      }
    }

    return false;
  }

  function _getNextDate(uint _timestamp) internal pure returns (uint) {
    _DateTime memory dt = parseTimestamp(_timestamp);

    uint16 year;
    uint8 month;

    uint8[4] memory months = [1, 4, 7, 10];
    for (uint i = months.length; i > 0; --i) {
      if (dt.month >= months[i - 1]) {
        if (i == months.length) {
          year = dt.year + 1;
          month = months[0];
        } else {
          year = dt.year;
          month = months[i];
        }
        break;
      }
    }

    return toTimestamp(year, month, 1);
  }

  // implies that the timestamp is exactly in any of the intervals or after stopTime
  function _findIntervalStart(Account storage _account, uint _timestamp) internal view returns (uint) {
    if (_timestamp >= _account.stopTime) {
      return _account.stopTime;
    } else {
      _DateTime memory dt = parseTimestamp(_timestamp);
      return toTimestamp(dt.year, dt.month, 1);
    }
  }

  function _getBalance(Currency _currency) internal view returns (uint) {
    IERC20 token = _currency == Currency.BFCL ? bfclToken : euroToken;
    uint balance = token.balanceOf(tokensWallet);
    uint allowance = token.allowance(tokensWallet, address(this));
    return balance < allowance ? balance : allowance;
  }

  function _checkAndCloseAccount(address _investor) internal {
    bool isDepositWithdrawn = accounts[_investor].vault.getBalance() == 0;
    bool isDividendsWithdrawn = deposits[_investor].length == 0;
    bool isDebtsWithdrawn = debts[_investor].length == 0;
    if (isDepositWithdrawn && isDividendsWithdrawn && isDebtsWithdrawn) {
      delete accounts[_investor];
      emit CloseAccount(_investor);
    }
  }

  function _withdrawOneDebt(address _investor, Currency _currency, uint _index) internal returns (bool) {
    Debt storage debt = debts[_investor][_index];
    return _send(_investor, debt.bfcl, debt.euro, _currency);
  }

  function _deleteDebt(address _investor, uint _index) internal {
    uint lastIndex = debts[_investor].length - 1;
    if (_index == lastIndex) {
      delete debts[_investor][_index];
    } else {
      debts[_investor][_index] = debts[_investor][lastIndex];
      delete debts[_investor][lastIndex];
    }
    emit DeleteDebt(_investor, _index);
    debts[_investor].length--;
  }

  function _checkAndReinvest(Deposit storage _deposit, uint _currentIntervalStart) internal {
    while (true) {
      uint nextDate = _getNextDate(_deposit.lastWithdrawTime);
      if (nextDate >= _currentIntervalStart) {
        return;
      }

      uint periodSeconds = nextDate.sub(_deposit.lastWithdrawTime);
      (uint bfclDividends, uint euroDividends) = _calculateDividendForPeriod(_deposit, periodSeconds);

      emit Reinvest(_deposit.bfcl, _deposit.euro, _deposit.lastWithdrawTime, bfclDividends, euroDividends, nextDate);

      _deposit.bfcl = _deposit.bfcl.add(bfclDividends);
      _deposit.euro = _deposit.euro.add(euroDividends);
      _deposit.lastWithdrawTime = nextDate;
    }
  }

  function _withdrawOneDividend(address _investor, Account storage _account, Currency _currency, uint _index)
    internal
    returns (bool result)
  {
    Deposit storage deposit = deposits[_investor][_index];
    uint intervalStart = _findIntervalStart(_account, now);
    if (deposit.lastWithdrawTime > intervalStart) {
      return false;
    }
    _checkAndReinvest(deposit, intervalStart);
    uint periodSeconds = intervalStart.sub(deposit.lastWithdrawTime);
    deposit.lastWithdrawTime = intervalStart;
    (uint bfclDividends, uint euroDividends) = _calculateDividendForPeriod(deposit, periodSeconds);
    result = _send(_investor, bfclDividends, euroDividends, _currency);
  }

  function _deleteDeposit(address _investor, uint _index) internal {
    uint lastIndex = deposits[_investor].length - 1;
    if (_index == lastIndex) {
      delete deposits[_investor][_index];
    } else {
      deposits[_investor][_index] = deposits[_investor][lastIndex];
      delete deposits[_investor][lastIndex];
    }
    emit DeleteDeposit(_investor, _index);
    deposits[_investor].length--;
  }

  function _calculateDividendForTimestamp(address _investor, uint _withdrawingTimestamp, uint _depositIndex)
    internal
    view
    returns (uint bfcl, uint euro)
  {
    Deposit storage deposit = deposits[_investor][_depositIndex];
    if (deposit.lastWithdrawTime >= _withdrawingTimestamp) {
      return (0, 0);
    }

    Currency currency = address(euroToken) == address(0) ? Currency.BFCL : Currency.EURO;

    uint b = deposit.bfcl;
    uint e = deposit.euro;

    // check reinvestment
    uint lastWithdrawTime = deposit.lastWithdrawTime;
    while (true) {
      uint nextDate = _getNextDate(lastWithdrawTime);
      if (nextDate >= _withdrawingTimestamp) {
        break;
      }

      uint periodSeconds = nextDate.sub(lastWithdrawTime);
      (uint bfclDividends, uint euroDividends) = _calculateDividendForPeriod(b, e, periodSeconds);

      b = b.add(bfclDividends);
      e = e.add(euroDividends);

      lastWithdrawTime = nextDate;
    }

    // calculate dividends for last interval
    uint periodSeconds = _withdrawingTimestamp.sub(lastWithdrawTime);
    (bfcl, euro) = _calculateDividendForPeriod(b, e, periodSeconds);
    if (currency == Currency.BFCL) {
      euro = 0;
    } else if (_withdrawingTimestamp < accounts[_investor].stopTime) {
      bfcl = 0;
    }

    if (_withdrawingTimestamp >= accounts[_investor].stopTime) {
      if (currency == Currency.BFCL) {
        bfcl = bfcl.add(b);
      } else {
        bfcl = b;
      }
    }
  }

  function _calculateDividendForPeriod(Deposit storage _deposit, uint _periodSeconds)
    internal
    view
    returns (uint bfcl, uint euro)
  {
    (bfcl, euro) = _calculateDividendForPeriod(_deposit.bfcl, _deposit.euro, _periodSeconds);
  }

  function _calculateDividendForPeriod(uint _bfcl, uint _euro, uint _periodSeconds)
    internal
    view
    returns (uint bfcl, uint euro)
  {
    bfcl = _bfcl.mul(_periodSeconds).mul(PERCENT_PER_YEAR).div(HUNDRED_PERCENTS).div(365 days);
    euro = _euro.mul(_periodSeconds).mul(PERCENT_PER_YEAR).div(HUNDRED_PERCENTS).div(365 days);
  }

  function _send(address _investor, uint _bfclAmount, uint _euroAmount, Currency _currency) internal returns (bool) {
    if (_bfclAmount == 0 && _euroAmount == 0) {
      return false;
    }

    uint balance = _getBalance(_currency);
    if (_currency == Currency.EURO) {
      balance = balance.mul(RATE_MULTIPLIER).div(10 ** euroToken.decimals());
    }

    uint canPay;

    if ((_currency == Currency.BFCL && balance >= _bfclAmount) || (_currency == Currency.EURO && balance >= _euroAmount)) {
      if (_currency == Currency.BFCL) {
        canPay = _bfclAmount;
      } else {
        canPay = _euroAmount;
      }
    } else {
      canPay = balance;
      uint bfclDebt;
      uint euroDebt;
      if (_currency == Currency.BFCL) {
        bfclDebt = _bfclAmount.sub(canPay);
        euroDebt = bfclDebt.mul(_euroAmount).div(_bfclAmount);
      } else {
        euroDebt = _euroAmount.sub(canPay);
        bfclDebt = euroDebt.mul(_bfclAmount).div(_euroAmount);
      }

      debts[_investor].push(Debt(bfclDebt, euroDebt));
      emit AddDebt(_investor, bfclDebt, euroDebt);
    }

    if (canPay == 0) {
      return true;
    }

    uint toPay;
    IERC20 token;
    if (_currency == Currency.BFCL) {
      toPay = canPay;
      token = bfclToken;
    } else {
      toPay = canPay.mul(10 ** euroToken.decimals()).div(RATE_MULTIPLIER);
      token = euroToken;
    }

    token.transferFrom(tokensWallet, _investor, toPay);
    return true;
  }
}

pragma solidity ^0.5.8;

/**
 * @title ERC20 interface without bool returns
 * @dev see https://eips.ethereum.org/EIPS/eip-20
 */
interface IERC20 {
  function transfer(address to, uint256 value) external;

  function transferFrom(address from, address to, uint256 value) external;

  function decimals() external view returns (uint256);

  function balanceOf(address who) external view returns (uint256);

  function allowance(address owner, address spender) external view returns (uint256);
}

pragma solidity ^0.5.2;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     * @notice Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

pragma solidity ^0.5.8;

import "./Roles.sol";

contract PriceManagerRole {
  using Roles for Roles.Role;

  event PriceManagerAdded(address indexed account);
  event PriceManagerRemoved(address indexed account);

  Roles.Role private managers;

  constructor() internal {
    _addPriceManager(msg.sender);
  }

  modifier onlyPriceManager() {
    require(isPriceManager(msg.sender), "Only for price manager");
    _;
  }

  function isPriceManager(address account) public view returns (bool) {
    return managers.has(account);
  }

  function addPriceManager(address account) public onlyPriceManager {
    _addPriceManager(account);
  }

  function renouncePriceManager() public {
    _removePriceManager(msg.sender);
  }

  function _addPriceManager(address account) internal {
    managers.add(account);
    emit PriceManagerAdded(account);
  }

  function _removePriceManager(address account) internal {
    managers.remove(account);
    emit PriceManagerRemoved(account);
  }
}

pragma solidity ^0.5.2;

/**
 * @title Helps contracts guard against reentrancy attacks.
 * @author Remco Bloemen <remco@2π.com>, Eenae <alexey@mixbytes.io>
 * @dev If you mark a function `nonReentrant`, you should also
 * mark it `external`.
 */
contract ReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;

    constructor () internal {
        // The counter starts at one to prevent changing it from zero to a non-zero
        // value, which is a more expensive operation.
        _guardCounter = 1;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter);
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

pragma solidity ^0.5.8;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./IERC20.sol";

contract Vault is Ownable {
  using SafeMath for uint;

  address public investor;
  IERC20 internal bfclToken;

  constructor(address _investor, IERC20 _bfclToken) public {
    investor = _investor;
    bfclToken = _bfclToken;
  }

  // reverts erc223 transfers
  function tokenFallback(address, uint, bytes calldata) external pure {
    revert("ERC223 tokens not allowed in Vault");
  }

  function withdrawToInvestor(uint _amount) external onlyOwner returns (bool) {
    bfclToken.transfer(investor, _amount);
    return true;
  }

  function getBalance() public view returns (uint) {
    return bfclToken.balanceOf(address(this));
  }
}

pragma solidity ^0.5.8;

import "./Roles.sol";
import "./Ownable.sol";

contract Whitelist is Ownable {
  using Roles for Roles.Role;

  Roles.Role private whitelist;

  event WhitelistedAddressAdded(address indexed _address);

  function isWhitelisted(address _address) public view returns (bool) {
    return whitelist.has(_address);
  }

  function addAddressToWhitelist(address _address) external onlyOwner {
    _addAddressToWhitelist(_address);
  }

  function addAddressesToWhitelist(address[] calldata _addresses) external onlyOwner {
    for (uint i = 0; i < _addresses.length; i++) {
      _addAddressToWhitelist(_addresses[i]);
    }
  }

  function _addAddressToWhitelist(address _address) internal {
    whitelist.add(_address);
    emit WhitelistedAddressAdded(_address);
  }
}

