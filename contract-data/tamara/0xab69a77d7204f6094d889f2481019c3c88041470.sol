pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./Ownable.sol";


contract EmalToken {
    // add function prototypes of only those used here
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool);
    
    function getBountyAmount() public view returns(uint256);
}


contract EmalBounty is Ownable {

    using SafeMath for uint256;

    // The token being sold
    EmalToken public token;

    // Bounty contract state Data structures
    enum State {
        Active,
        Closed
    }

    // contains current state of bounty contract
    State public state;

    // Bounty limit in EMAL tokens
    uint256 public bountyLimit;

    // Count of total number of EML tokens that have been currently allocated to bounty users
    uint256 public totalTokensAllocated = 0;

    // Count of allocated tokens (not issued only allocated) for each bounty user
    mapping(address => uint256) public allocatedTokens;

    // Count of allocated tokens issued to each bounty user.
    mapping(address => uint256) public amountOfAllocatedTokensGivenOut;


    /** @dev Event fired when tokens are allocated to a bounty user account
      * @param beneficiary Address that is allocated tokens
      * @param tokenCount The amount of tokens that were allocated
      */
    event TokensAllocated(address indexed beneficiary, uint256 tokenCount);
    event TokensDeallocated(address indexed beneficiary, uint256 tokenCount);

    /**
     * @dev Event fired when EML tokens are sent to a bounty user
     * @param beneficiary Address where the allocated tokens were sent
     * @param tokenCount The amount of tokens that were sent
     */
    event IssuedAllocatedTokens(address indexed beneficiary, uint256 tokenCount);



    /** @param _token Address of the token that will be rewarded for the investors
      */
    constructor(address _token) public {
        require(_token != address(0));
        owner = msg.sender;
        token = EmalToken(_token);
        state = State.Active;
        bountyLimit = token.getBountyAmount();
    }

    /* Do not accept ETH */
    function() external payable {
        revert();
    }

    function closeBounty() public onlyOwner returns(bool){
        require( state!=State.Closed );
        state = State.Closed;
        return true;
    }

    /** @dev Public function to check if bounty isActive or not
      * @return True if Bounty event has ended
      */
    function isBountyActive() public view returns(bool) {
        if (state==State.Active && totalTokensAllocated<bountyLimit){
            return true;
        } else {
            return false;
        }
    }

    /** @dev Allocates tokens to a bounty user
      * @param beneficiary The address of the bounty user
      * @param tokenCount The number of tokens to be allocated to this address
      */
    function allocateTokens(address beneficiary, uint256 tokenCount) public onlyOwner returns(bool success) {
        require(beneficiary != address(0));
        require(validAllocation(tokenCount));

        uint256 tokens = tokenCount;

        /* Allocate only the remaining tokens if final contribution exceeds hard cap */
        if (totalTokensAllocated.add(tokens) > bountyLimit) {
            tokens = bountyLimit.sub(totalTokensAllocated);
        }

        /* Update state and balances */
        allocatedTokens[beneficiary] = allocatedTokens[beneficiary].add(tokens);
        totalTokensAllocated = totalTokensAllocated.add(tokens);
        emit TokensAllocated(beneficiary, tokens);

        return true;
    }

    function validAllocation( uint256 tokenCount ) internal view returns(bool) {
        bool isActive = state==State.Active;
        bool positiveAllocation = tokenCount>0;
        bool bountyLimitNotReached = totalTokensAllocated<bountyLimit;
        return isActive && positiveAllocation && bountyLimitNotReached;
    }

    /** @dev Remove tokens from a bounty user's allocation.
      * @dev Used in game based bounty allocation, automatically called from the Sails app
      * @param beneficiary The address of the bounty user
      * @param tokenCount The number of tokens to be deallocated to this address
      */
    function deductAllocatedTokens(address beneficiary, uint256 tokenCount) public onlyOwner returns(bool success) {
        require(beneficiary != address(0));
        require(tokenCount>0 && tokenCount<=allocatedTokens[beneficiary]);

        allocatedTokens[beneficiary] = allocatedTokens[beneficiary].sub(tokenCount);
        totalTokensAllocated = totalTokensAllocated.sub(tokenCount);
        emit TokensDeallocated(beneficiary, tokenCount);

        return true;
    }

    /** @dev Getter function to check the amount of allocated tokens
      * @param beneficiary address of the investor or the bounty user
      */
    function getAllocatedTokens(address beneficiary) public view returns(uint256 tokenCount) {
        require(beneficiary != address(0));
        return allocatedTokens[beneficiary];
    }

    /** @dev Bounty users will be issued EML Tokens by the sails api,
      * @dev after the Bounty has ended to their address
      * @param beneficiary address of the bounty user
      */
    function issueTokensToAllocatedUsers(address beneficiary) public onlyOwner returns(bool success) {
        require(beneficiary!=address(0));
        require(allocatedTokens[beneficiary]>0);

        uint256 tokensToSend = allocatedTokens[beneficiary];
        allocatedTokens[beneficiary] = 0;
        amountOfAllocatedTokensGivenOut[beneficiary] = amountOfAllocatedTokensGivenOut[beneficiary].add(tokensToSend);
        assert(token.transferFrom(owner, beneficiary, tokensToSend));

        emit IssuedAllocatedTokens(beneficiary, tokensToSend);
        return true;
    }
}

pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./Pausable.sol";

contract EmalToken {
    // add function prototypes of only those used here
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool);
    function getCrowdsaleAmount() public view returns(uint256);
    function setStartTimeForTokenTransfers(uint256 _startTime) external;
}

contract EmalWhitelist {
    // add function prototypes of only those used here
    function isWhitelisted(address investorAddr) public view returns(bool whitelisted);
}


contract EmalCrowdsale is Ownable, Pausable {

    using SafeMath for uint256;

    // Start and end timestamps
    uint256 public startTime;
    uint256 public endTime;

    // The token being sold
    EmalToken public token;

    // Whitelist contract used to store whitelisted addresses
    EmalWhitelist public list;

    // Address where funds are collected
    address public multisigWallet;

    // Switched to true once token contract is notified of when to enable token transfers
    bool private isStartTimeSetForTokenTransfers = false;

    // Hard cap in EMAL tokens
    uint256 public hardCap;

    // Soft cap in EMAL tokens
    uint256 constant public soft_cap = 50000000 * (10 ** 18);

    // Amount of tokens that were sold to ether investors plus tokens allocated to investors for fiat and btc investments.
    uint256 public totalTokensSoldandAllocated = 0;



    // Investor contributions made in ether
    mapping(address => uint256) public etherInvestments;

    // Tokens given to investors who sent ether investments
    mapping(address => uint256) public tokensSoldForEther;

    // Total ether raised by the Crowdsale
    uint256 public totalEtherRaisedByCrowdsale = 0;

    // Total number of tokens sold to investors who made payments in ether
    uint256 public totalTokensSoldByEtherInvestments = 0;

    // Count of allocated tokens  for each investor or bounty user
    mapping(address => uint256) public allocatedTokens;

    // Count of total number of EML tokens that have been currently allocated to Crowdsale investors
    uint256 public totalTokensAllocated = 0;



   /** @dev Event for EML token purchase using ether
     * @param investorAddr Address that paid and got the tokens
     * @param paidAmount The amount that was paid (in wei)
     * @param tokenCount The amount of tokens that were bought
     */
    event TokenPurchasedUsingEther(address indexed investorAddr, uint256 paidAmount, uint256 tokenCount);

    /**
     * @dev Event for refund logging
     * @param receiver The address that received the refund
     * @param amount The amount that is being refunded (in wei)
     */
    event Refund(address indexed receiver, uint256 amount);

    /** @dev Event fired when EML tokens are allocated to an investor account
      * @param beneficiary Address that is allocated tokens
      * @param tokenCount The amount of tokens that were allocated
      */
    event TokensAllocated(address indexed beneficiary, uint256 tokenCount);
    event TokensDeallocated(address indexed beneficiary, uint256 tokenCount);


    /** @dev variables and functions which determine conversion rate from ETH to EML
      * based on bonuses and current timestamp.
      */
    uint256 priceOfEthInUSD = 450;
    uint256 bonusPercent1 = 25;
    uint256 bonusPercent2 = 15;
    uint256 bonusPercent3 = 0;
    uint256 priceOfEMLTokenInUSDPenny = 60;
    uint256 overridenBonusValue = 0;

    function setExchangeRate(uint256 overridenValue) public onlyOwner returns(bool) {
        require( overridenValue > 0 );
        require( overridenValue != priceOfEthInUSD);
        priceOfEthInUSD = overridenValue;
        return true;
    }

    function getExchangeRate() public view returns(uint256){
        return priceOfEthInUSD;
    }

    function setOverrideBonus(uint256 overridenValue) public onlyOwner returns(bool) {
        require( overridenValue > 0 );
        require( overridenValue != overridenBonusValue);
        overridenBonusValue = overridenValue;
        return true;
    }

    /**
     * @dev public function that is used to determine the current rate for token / ETH conversion
     * @dev there exists a case where rate cant be set to 0, which is fine.
     * @return The current token rate
     */
    function getRate() public view returns(uint256) {
        require( priceOfEMLTokenInUSDPenny !=0 );
        require( priceOfEthInUSD !=0 );
        uint256 rate;

        if(overridenBonusValue > 0){
            rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(overridenBonusValue.add(100)).div(100);
        } else {
            if (now <= (startTime + 1 days)) {
                rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(bonusPercent1.add(100)).div(100);
            } if (now > (startTime + 1 days) && now <= (startTime + 2 days)) {
                rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(bonusPercent2.add(100)).div(100);
            } else {
                rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(bonusPercent3.add(100)).div(100);
            }
        }
        return rate;
    }


    /** @dev Initialise the Crowdsale contract.
      * (can be removed for testing) _startTime Unix timestamp for the start of the token sale
      * (can be removed for testing) _endTime Unix timestamp for the end of the token sale
      * @param _multisigWallet Ethereum address to which the invested funds are forwarded
      * @param _token Address of the token that will be rewarded for the investors
      * @param _list contains a list of investors who completed KYC procedures.
      */
    constructor(uint256 _startTime, uint256 _endTime, address _multisigWallet, address _token, address _list) public {
        require(_startTime >= now);
        require(_endTime >= _startTime);
        require(_multisigWallet != address(0));
        require(_token != address(0));
        require(_list != address(0));

        startTime = _startTime;
        endTime = _endTime;
        multisigWallet = _multisigWallet;
        owner = msg.sender;
        token = EmalToken(_token);
        list = EmalWhitelist(_list);
        hardCap = token.getCrowdsaleAmount();
    }

    /** @dev Fallback function that can be used to buy EML tokens. Or in
      * case of the owner, return ether to allow refunds in case crowdsale
      * ended or paused and didnt reach soft_cap.
      */
    function() external payable {
        if (msg.sender == multisigWallet) {
            require( (!isCrowdsaleActive()) && totalTokensSoldandAllocated<soft_cap);
        } else {
            if (list.isWhitelisted(msg.sender)) {
                buyTokensUsingEther(msg.sender);
            } else {
                revert();
            }
        }
    }

    /** @dev Function for buying EML tokens using ether
      * @param _investorAddr The address that should receive bought tokens
      */
    function buyTokensUsingEther(address _investorAddr) internal whenNotPaused {
        require(_investorAddr != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;
        uint256 returnToSender = 0;

        // final rate after including rate value and bonus amount.
        uint256 finalConversionRate = getRate();

        // Calculate EML token amount to be transferred
        uint256 tokens = weiAmount.mul(finalConversionRate);

        // Distribute only the remaining tokens if final contribution exceeds hard cap
        if (totalTokensSoldandAllocated.add(tokens) > hardCap) {
            tokens = hardCap.sub(totalTokensSoldandAllocated);
            weiAmount = tokens.div(finalConversionRate);
            returnToSender = msg.value.sub(weiAmount);
        }

        // update state and balances
        etherInvestments[_investorAddr] = etherInvestments[_investorAddr].add(weiAmount);
        tokensSoldForEther[_investorAddr] = tokensSoldForEther[_investorAddr].add(tokens);
        totalTokensSoldByEtherInvestments = totalTokensSoldByEtherInvestments.add(tokens);
        totalEtherRaisedByCrowdsale = totalEtherRaisedByCrowdsale.add(weiAmount);
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.add(tokens);


        // assert implies it should never fail
        assert(token.transferFrom(owner, _investorAddr, tokens));
        emit TokenPurchasedUsingEther(_investorAddr, weiAmount, tokens);

        // Forward funds
        multisigWallet.transfer(weiAmount);

        // Update token contract.
        _postValidationUpdateTokenContract();

        // Return funds that are over hard cap
        if (returnToSender > 0) {
            msg.sender.transfer(returnToSender);
        }
    }

    function _postValidationUpdateTokenContract() internal {
       /** @dev If hard cap is reachde allow token transfers after two weeks
         * @dev Allow users to transfer tokens only after hardCap is reached
         * @dev Notiy token contract about startTime to start transfers
         */
        if (totalTokensSoldandAllocated == hardCap) {
            token.setStartTimeForTokenTransfers(now + 2 weeks);
        }

       /** @dev If its the first token sold or allocated then set s, allow after 2 weeks
         * @dev Allow users to transfer tokens only after ICO crowdsale ends.
         * @dev Notify token contract about sale end time
         */
        if (!isStartTimeSetForTokenTransfers) {
            isStartTimeSetForTokenTransfers = true;
            token.setStartTimeForTokenTransfers(endTime + 2 weeks);
        }
    }

    /** @dev Internal function that is used to check if the incoming purchase should be accepted.
      * @return True if the transaction can buy tokens
      */
    function validPurchase() internal view returns(bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool minimumPurchase = msg.value >= 1*(10**18);
        bool hardCapNotReached = totalTokensSoldandAllocated < hardCap;
        return withinPeriod && hardCapNotReached && minimumPurchase;
    }

    /** @dev Public function to check if Crowdsale isActive or not
      * @return True if Crowdsale event has ended
      */
    function isCrowdsaleActive() public view returns(bool) {
        if (!paused && now>startTime && now<endTime && totalTokensSoldandAllocated<=hardCap){
            return true;
        } else {
            return false;
        }
    }

    /** @dev Gets the balance of the specified address.
      * @param _owner The address to query the the balance of.
      * @return An uint256 representing the amount owned by the passed address.
      */
    function balanceOfEtherInvestor(address _owner) external view returns(uint256 balance) {
        require(_owner != address(0));
        return etherInvestments[_owner];
    }

    function getTokensSoldToEtherInvestor(address _owner) public view returns(uint256 balance) {
        require(_owner != address(0));
        return tokensSoldForEther[_owner];
    }

    /** @dev Returns ether to token holders in case soft cap is not reached.
      */
    function claimRefund() public whenNotPaused onlyOwner {
        require(now>endTime);
        require(totalTokensSoldandAllocated<soft_cap);
        uint256 amount = etherInvestments[msg.sender];

        if (address(this).balance >= amount) {
            etherInvestments[msg.sender] = 0;
            if (amount > 0) {
                msg.sender.transfer(amount);
                emit Refund(msg.sender, amount);
            }
        }
      }




    /** @dev BELOW ARE FUNCTIONS THAT HANDLE INVESTMENTS IN FIAT AND BTC.
      * functions are automatically called by ICO Sails.js app.
      */


    /** @dev Allocates EML tokens to an investor address called automatically
      * after receiving fiat or btc investments from KYC whitelisted investors.
      * @param beneficiary The address of the investor
      * @param tokenCount The number of tokens to be allocated to this address
      */
    function allocateTokens(address beneficiary, uint256 tokenCount) public onlyOwner returns(bool success) {
        require(beneficiary != address(0));
        require(validAllocation(tokenCount));

        uint256 tokens = tokenCount;

        /* Allocate only the remaining tokens if final contribution exceeds hard cap */
        if (totalTokensSoldandAllocated.add(tokens) > hardCap) {
            tokens = hardCap.sub(totalTokensSoldandAllocated);
        }

        /* Update state and balances */
        allocatedTokens[beneficiary] = allocatedTokens[beneficiary].add(tokens);
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.add(tokens);
        totalTokensAllocated = totalTokensAllocated.add(tokens);

        // assert implies it should never fail
        assert(token.transferFrom(owner, beneficiary, tokens));
        emit TokensAllocated(beneficiary, tokens);

        /* Update token contract. */
        _postValidationUpdateTokenContract();
        return true;
    }

    function validAllocation( uint256 tokenCount ) internal view returns(bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool positiveAllocation = tokenCount > 0;
        bool hardCapNotReached = totalTokensSoldandAllocated < hardCap;
        return withinPeriod && positiveAllocation && hardCapNotReached;
    }


    /** @dev Getter function to check the amount of allocated tokens
      * @param beneficiary address of the investor
      */
    function getAllocatedTokens(address beneficiary) public view returns(uint256 tokenCount) {
        require(beneficiary != address(0));
        return allocatedTokens[beneficiary];
    }

    function getSoldandAllocatedTokens(address _addr) public view returns (uint256) {
        require(_addr != address(0));
        uint256 totalTokenCount = getAllocatedTokens(_addr).add(getTokensSoldToEtherInvestor(_addr));
        return totalTokenCount;
    }

}

pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./Pausable.sol";

contract EmalToken {
    // add function prototypes of only those used here
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool);
    function getPresaleAmount() public view returns(uint256);
}

contract EmalWhitelist {
    // add function prototypes of only those used here
    function isWhitelisted(address investorAddr) public view returns(bool whitelisted);
}


contract EmalPresale is Ownable, Pausable {

    using SafeMath for uint256;

    // Start and end timestamps
    uint256 public startTime;
    uint256 public endTime;

    // The token being sold
    EmalToken public token;

    // Whitelist contract used to store whitelisted addresses
    EmalWhitelist public list;

    // Address where funds are collected
    address public multisigWallet;

    // Hard cap in EMAL tokens
    uint256 public hardCap;

    // Amount of tokens that were sold to ether investors plus tokens allocated to investors for fiat and btc investments.
    uint256 public totalTokensSoldandAllocated = 0;



    // Investor contributions made in ether
    mapping(address => uint256) public etherInvestments;

    // Tokens given to investors who sent ether investments
    mapping(address => uint256) public tokensSoldForEther;

    // Total ether raised by the Presale
    uint256 public totalEtherRaisedByPresale = 0;

    // Total number of tokens sold to investors who made payments in ether
    uint256 public totalTokensSoldByEtherInvestments = 0;

    // Count of allocated tokens  for each investor or bounty user
    mapping(address => uint256) public allocatedTokens;

    // Count of total number of EML tokens that have been currently allocated to Presale investors
    uint256 public totalTokensAllocated = 0;



   /** @dev Event for EML token purchase using ether
     * @param investorAddr Address that paid and got the tokens
     * @param paidAmount The amount that was paid (in wei)
     * @param tokenCount The amount of tokens that were bought
     */
    event TokenPurchasedUsingEther(address indexed investorAddr, uint256 paidAmount, uint256 tokenCount);

    /** @dev Event fired when EML tokens are allocated to an investor account
      * @param beneficiary Address that is allocated tokens
      * @param tokenCount The amount of tokens that were allocated
      */
    event TokensAllocated(address indexed beneficiary, uint256 tokenCount);
    event TokensDeallocated(address indexed beneficiary, uint256 tokenCount);


    /** @dev variables and functions which determine conversion rate from ETH to EML
      * based on bonuses and current timestamp.
      */
    uint256 priceOfEthInUSD = 450;
    uint256 bonusPercent1 = 35;
    uint256 priceOfEMLTokenInUSDPenny = 60;
    uint256 overridenBonusValue = 0;

    function setExchangeRate(uint256 overridenValue) public onlyOwner returns(bool) {
        require( overridenValue > 0 );
        require( overridenValue != priceOfEthInUSD);
        priceOfEthInUSD = overridenValue;
        return true;
    }

    function getExchangeRate() public view returns(uint256){
        return priceOfEthInUSD;
    }

    function setOverrideBonus(uint256 overridenValue) public onlyOwner returns(bool) {
        require( overridenValue > 0 );
        require( overridenValue != overridenBonusValue);
        overridenBonusValue = overridenValue;
        return true;
    }

    /** @dev public function that is used to determine the current rate for ETH to EML conversion
      * @return The current token rate
      */
    function getRate() public view returns(uint256) {
        require(priceOfEMLTokenInUSDPenny > 0 );
        require(priceOfEthInUSD > 0 );
        uint256 rate;

        if(overridenBonusValue > 0){
            rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(overridenBonusValue.add(100)).div(100);
        } else {
            rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(bonusPercent1.add(100)).div(100);
        }
        return rate;
    }


    /** @dev Initialise the Presale contract.
      * (can be removed for testing) _startTime Unix timestamp for the start of the token sale
      * (can be removed for testing) _endTime Unix timestamp for the end of the token sale
      * @param _multisigWallet Ethereum address to which the invested funds are forwarded
      * @param _token Address of the token that will be rewarded for the investors
      * @param _list contains a list of investors who completed KYC procedures.
      */
    constructor(uint256 _startTime, uint256 _endTime, address _multisigWallet, address _token, address _list) public {
        require(_startTime >= now);
        require(_endTime >= _startTime);
        require(_multisigWallet != address(0));
        require(_token != address(0));
        require(_list != address(0));

        startTime = _startTime;
        endTime = _endTime;
        multisigWallet = _multisigWallet;
        owner = msg.sender;
        token = EmalToken(_token);
        list = EmalWhitelist(_list);
        hardCap = token.getPresaleAmount();
    }

    /** @dev Fallback function that can be used to buy tokens.
      */
    function() external payable {
        if (list.isWhitelisted(msg.sender)) {
            buyTokensUsingEther(msg.sender);
        } else {
            /* Do not accept ETH */
            revert();
        }
    }

    /** @dev Function for buying EML tokens using ether
      * @param _investorAddr The address that should receive bought tokens
      */
    function buyTokensUsingEther(address _investorAddr) internal whenNotPaused {
        require(_investorAddr != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;
        uint256 returnToSender = 0;

        // final rate after including rate value and bonus amount.
        uint256 finalConversionRate = getRate();

        // Calculate EML token amount to be transferred
        uint256 tokens = weiAmount.mul(finalConversionRate);

        // Distribute only the remaining tokens if final contribution exceeds hard cap
        if (totalTokensSoldandAllocated.add(tokens) > hardCap) {
            tokens = hardCap.sub(totalTokensSoldandAllocated);
            weiAmount = tokens.div(finalConversionRate);
            returnToSender = msg.value.sub(weiAmount);
        }

        // update state and balances
        etherInvestments[_investorAddr] = etherInvestments[_investorAddr].add(weiAmount);
        tokensSoldForEther[_investorAddr] = tokensSoldForEther[_investorAddr].add(tokens);
        totalTokensSoldByEtherInvestments = totalTokensSoldByEtherInvestments.add(tokens);
        totalEtherRaisedByPresale = totalEtherRaisedByPresale.add(weiAmount);
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.add(tokens);


        // assert implies it should never fail
        assert(token.transferFrom(owner, _investorAddr, tokens));
        emit TokenPurchasedUsingEther(_investorAddr, weiAmount, tokens);

        // Forward funds
        multisigWallet.transfer(weiAmount);

        // Return funds that are over hard cap
        if (returnToSender > 0) {
            msg.sender.transfer(returnToSender);
        }
    }

    /**
     * @dev Internal function that is used to check if the incoming purchase should be accepted.
     * @return True if the transaction can buy tokens
     */
    function validPurchase() internal view returns(bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool minimumPurchase = msg.value >= 1*(10**18);
        bool hardCapNotReached = totalTokensSoldandAllocated < hardCap;
        return withinPeriod && hardCapNotReached && minimumPurchase;
    }

    /** @dev Public function to check if Presale isActive or not
      * @return True if Presale event has ended
      */
    function isPresaleActive() public view returns(bool) {
        if (!paused && now>startTime && now<endTime && totalTokensSoldandAllocated<=hardCap){
            return true;
        } else {
            return false;
        }
    }

    /** @dev Gets the balance of the specified address.
      * @param _owner The address to query the the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOfEtherInvestor(address _owner) external view returns(uint256 balance) {
        require(_owner != address(0));
        return etherInvestments[_owner];
    }

    function getTokensSoldToEtherInvestor(address _owner) public view returns(uint256 balance) {
        require(_owner != address(0));
        return tokensSoldForEther[_owner];
    }




    /** @dev BELOW ARE FUNCTIONS THAT HANDLE INVESTMENTS IN FIAT AND BTC.
      * functions are automatically called by ICO Sails.js app.
      */


    /** @dev Allocates EML tokens to an investor address called automatically
      * after receiving fiat or btc investments from KYC whitelisted investors.
      * @param beneficiary The address of the investor
      * @param tokenCount The number of tokens to be allocated to this address
      */
    function allocateTokens(address beneficiary, uint256 tokenCount) public onlyOwner returns(bool success) {
        require(beneficiary != address(0));
        require(validAllocation(tokenCount));

        uint256 tokens = tokenCount;

        /* Allocate only the remaining tokens if final contribution exceeds hard cap */
        if (totalTokensSoldandAllocated.add(tokens) > hardCap) {
            tokens = hardCap.sub(totalTokensSoldandAllocated);
        }

        /* Update state and balances */
        allocatedTokens[beneficiary] = allocatedTokens[beneficiary].add(tokens);
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.add(tokens);
        totalTokensAllocated = totalTokensAllocated.add(tokens);

        // assert implies it should never fail
        assert(token.transferFrom(owner, beneficiary, tokens));
        emit TokensAllocated(beneficiary, tokens);

        return true;
    }

    function validAllocation( uint256 tokenCount ) internal view returns(bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool positiveAllocation = tokenCount > 0;
        bool hardCapNotReached = totalTokensSoldandAllocated < hardCap;
        return withinPeriod && positiveAllocation && hardCapNotReached;
    }


    /** @dev Getter function to check the amount of allocated tokens
      * @param beneficiary address of the investor
      */
    function getAllocatedTokens(address beneficiary) public view returns(uint256 tokenCount) {
        require(beneficiary != address(0));
        return allocatedTokens[beneficiary];
    }

    function getSoldandAllocatedTokens(address _addr) public view returns (uint256) {
        require(_addr != address(0));
        uint256 totalTokenCount = getAllocatedTokens(_addr).add(getTokensSoldToEtherInvestor(_addr));
        return totalTokenCount;
    }

}

pragma solidity 0.4.24;

import "./SafeMath.sol";
import './StandardToken.sol';
import './Ownable.sol';

contract EmalToken is StandardToken, Ownable {

    using SafeMath for uint256;

    string public constant symbol = "EML";
    string public constant name = "e-Mal Token";
    uint8 public constant decimals = 18;

    // Total Number of tokens ever goint to be minted. 1 BILLION EML tokens.
    uint256 private constant minting_capped_amount = 1000000000 * 10 ** uint256(decimals);

    // 24% of initial supply
    uint256 constant presale_amount = 120000000 * 10 ** uint256(decimals);
    // 60% of inital supply
    uint256 constant crowdsale_amount = 300000000 * 10 ** uint256(decimals);
    // 8% of inital supply.
    uint256  constant vesting_amount = 40000000 * 10 ** uint256(decimals);
    // 8% of inital supply.
    uint256 constant bounty_amount = 40000000 * 10 ** uint256(decimals);
    
    uint256 private initialSupply = minting_capped_amount;

    address public presaleAddress;
    address public crowdsaleAddress;
    address public vestingAddress;
    address public bountyAddress;



    /** @dev Defines the start time after which transferring of EML tokens
      * will be allowed done so as to prevent early buyers from clearing out
      * of their EML balance during the presale and publicsale.
      */
    uint256 public startTimeForTransfers;

    /** @dev to cap the total number of tokens that will ever be newly minted
      * owner has to stop the minting by setting this variable to true.
      */
    bool public mintingFinished = false;

    /** @dev Miniting Essentials functions as per OpenZeppelin standards
      */
    modifier canMint() {
      require(!mintingFinished);
      _;
    }
    modifier hasMintPermission() {
      require(msg.sender == owner);
      _;
    }

    /** @dev to prevent malicious use of EML tokens and to comply with Anti
      * Money laundering regulations EML tokens can be frozen.
      */
    mapping (address => bool) public frozenAccount;

    /** @dev This generates a public event on the blockchain that will notify clients
      */
    event FrozenFunds(address target, bool frozen);
    event Mint(address indexed to, uint256 amount);
    event MintFinished();
    event Burn(address indexed burner, uint256 value);


    constructor() public {
        startTimeForTransfers = now - 210 days;

        _totalSupply = initialSupply;
        owner = msg.sender;
        balances[owner] = _totalSupply;
        emit Transfer(address(0), owner, balances[owner]);
    }

    /* Do not accept ETH */
    function() public payable {
        revert();
    }


    /** @dev Basic setters and getters to allocate tokens for vesting factory, presale
      * crowdsale and bounty this is done so that no need of actually transferring EML
      * tokens to sale contracts and hence preventing EML tokens from the risk of being
      * locked out in future inside the subcontracts.
      */
    function setPresaleAddress(address _presaleAddress) external onlyOwner {
        presaleAddress = _presaleAddress;
        assert(approve(presaleAddress, presale_amount));
    }
    function setCrowdsaleAddress(address _crowdsaleAddress) external onlyOwner {
        crowdsaleAddress = _crowdsaleAddress;
        assert(approve(crowdsaleAddress, crowdsale_amount));
    }
    function setVestingAddress(address _vestingAddress) external onlyOwner {
        vestingAddress = _vestingAddress;
        assert(approve(vestingAddress, vesting_amount));
    }
    function setBountyAddress(address _bountyAddress) external onlyOwner {
        bountyAddress = _bountyAddress;
        assert(approve(bountyAddress, bounty_amount));
    }
    


    function getPresaleAmount()  internal pure returns(uint256) {
        return presale_amount;
    }
    function getCrowdsaleAmount() internal pure  returns(uint256) {
        return crowdsale_amount;
    }
    function getVestingAmount() internal pure  returns(uint256) {
        return vesting_amount;
    }
    function getBountyAmount() internal pure  returns(uint256) {
        return bounty_amount;
    }

    /** @dev Sets the start time after which transferring of EML tokens
      * will be allowed done so as to prevent early buyers from clearing out
      * of their EML balance during the presale and publicsale.
      */
    function setStartTimeForTokenTransfers(uint256 _startTimeForTransfers) external {
        require(msg.sender == crowdsaleAddress);
        if (_startTimeForTransfers < startTimeForTransfers) {
            startTimeForTransfers = _startTimeForTransfers;
        }
    }


    /** @dev Transfer possible only after ICO ends and Frozen accounts
      * wont be able to transfer funds to other any other account and viz.
      * @notice added safeTransfer functionality
      */
    function transfer(address _to, uint256 _value) public returns(bool) {
        require(now >= startTimeForTransfers);
        require(!frozenAccount[msg.sender]);
        require(!frozenAccount[_to]);

        require(super.transfer(_to, _value));
        return true;
    }

    /** @dev Only owner's tokens can be transferred before Crowdsale ends.
      * beacuse the inital supply of EML is allocated to owners acc and later
      * distributed to various subcontracts.
      * @notice added safeTransferFrom functionality
      */
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool) {
        require(!frozenAccount[_from]);
        require(!frozenAccount[_to]);
        require(!frozenAccount[msg.sender]);

        if (now < startTimeForTransfers) {
            require(_from == owner);
        }

        require(super.transferFrom(_from, _to, _value));
        return true;
    }

    /** @notice added safeApprove functionality
      */
    function approve(address spender, uint256 tokens) public returns (bool){
        require(super.approve(spender, tokens));
        return true;
    }

   /** @notice `freeze? Prevent | Allow` `target` from sending & receiving tokens
     * @param target Address to be frozen
     * @param freeze either to freeze it or not
     */
    function freezeAccount(address target, bool freeze) public onlyOwner {
        require(frozenAccount[target] != freeze);

        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }


    /** @dev Function to mint tokens
      * @param _to The address that will receive the minted tokens.
      * @param _amount The amount of tokens to mint.
      * @return A boolean that indicates if the operation was successful.
      */
    function mint(address _to, uint256 _amount) public hasMintPermission canMint returns (bool) {
      require(_totalSupply.add(_amount) <= minting_capped_amount);

      _totalSupply = _totalSupply.add(_amount);
      balances[_to] = balances[_to].add(_amount);
      emit Mint(_to, _amount);
      emit Transfer(address(0), _to, _amount);
      return true;
    }

   /** @dev Function to stop minting new tokens.
     * @return True if the operation was successful.
     */
    function finishMinting() public onlyOwner canMint returns (bool) {
      mintingFinished = true;
      emit MintFinished();
      return true;
    }

    /** @dev Burns a specific amount of tokens.
      * @param _value The amount of token to be burned.
      */
     function burn(uint256 _value) public {
       _burn(msg.sender, _value);
     }

     function _burn(address _who, uint256 _value) internal {
       require(_value <= balances[_who]);
       // no need to require value <= totalSupply, since that would imply the
       // sender's balance is greater than the totalSupply, which *should* be an assertion failure

       balances[_who] = balances[_who].sub(_value);
       _totalSupply = _totalSupply.sub(_value);
       emit Burn(_who, _value);
       emit Transfer(_who, address(0), _value);
     }
}

pragma solidity 0.4.24;

import "./EmalToken.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

/** @title StandardTokenVesting
  * @dev A token holder contract that can release its token balance gradually like a
  * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the owner.
  */
contract StandardTokenVesting is Ownable {
  using SafeMath for uint256;

  event Released(uint256 amount);
  event Revoked();

  // beneficiary of tokens after they are released
  address public beneficiary;

  uint256 public cliff;
  uint256 public start;
  uint256 public duration;

  bool public revocable;

  mapping (address => uint256) public released;
  mapping (address => bool) public revoked;


  /** @dev Creates a vesting contract that vests its balance of any ERC20 token to the
   * _beneficiary, gradually in a linear fashion until _start + _duration. By then all
   * of the balance will have vested.
   * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
   * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
   * @param _start the time (as Unix time) at which point vesting starts
   * @param _duration duration in seconds of the period in which the tokens will vest
   * @param _revocable whether the vesting is revocable or not
   */
  constructor(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration, bool _revocable) public {
    require(_beneficiary != address(0));
    require(_cliff <= _duration);

    beneficiary = _beneficiary;
    revocable = _revocable;
    duration = _duration;
    owner = msg.sender;
    cliff = _start.add(_cliff);
    start = _start;
  }

  /** @notice Transfers vested tokens to beneficiary.
    * @param token ERC20 token which is being vested
    */
  function release(EmalToken token) public returns (bool){
    uint256 unreleased = releasableAmount(token);
    require(unreleased > 0);
    released[token] = released[token].add(unreleased);

    token.transfer(beneficiary, unreleased);
    emit Released(unreleased);
    return true;
  }

  /** @notice Allows the owner to revoke the vesting. Tokens already vested
    * remain in the contract, the rest are returned to the owner.
    * @param token ERC20 token which is being vested
    */
  function revoke(EmalToken token) public onlyOwner returns(bool) {
    require(revocable);
    require(!revoked[token]);
    uint256 balance = token.balanceOf(this);
    uint256 unreleased = releasableAmount(token);
    uint256 refund = balance.sub(unreleased);

    revoked[token] = true;
    token.transfer(owner, refund);
    emit Revoked();

    return true;
  }

  /** @dev Calculates the amount that has already vested but hasn't been released yet.
    * @param token ERC20 token which is being vested
    */
  function releasableAmount(EmalToken token) public view returns (uint256) {
    return vestedAmount(token).sub(released[token]);
  }

  /** @dev Calculates the amount that has already vested.
    * @param token Emal token which is being vested
    */
  function vestedAmount(EmalToken token) public view returns (uint256) {
    uint256 currentBalance = token.balanceOf(this);
    uint256 totalBalance = currentBalance.add(released[token]);

    if (block.timestamp < cliff) {
      return 0;
    } else if (block.timestamp >= start.add(duration) || revoked[token]) {
      return totalBalance;
    } else {
      return totalBalance.mul(block.timestamp.sub(start)).div(duration);
    }
  }
}

pragma solidity 0.4.24;

import './Ownable.sol';

/** @notice This contract provides support for whitelisting addresses.
 * only whitelisted addresses are allowed to send ether and buy tokens
 * during preSale and Pulic crowdsale.
 * @dev after deploying contract, deploy Presale / Crowdsale contract using
 * EmalWhitelist address. To allow claim refund functionality and allow wallet
 * owner efatoora to send ether to Crowdsale contract for refunds add wallet
 * address to whitelist.
 */
contract EmalWhitelist is Ownable {

    mapping(address => bool) whitelist;

    event AddToWhitelist(address investorAddr);
    event RemoveFromWhitelist(address investorAddr);


    /** @dev Throws if operator is not whitelisted.
     */
    modifier onlyIfWhitelisted(address investorAddr) {
        require(whitelist[investorAddr]);
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    /** @dev Returns if an address is whitelisted or not
     */
    function isWhitelisted(address investorAddr) public view returns(bool whitelisted) {
        return whitelist[investorAddr];
    }

    /**
     * @dev Adds an investor to whitelist
     * @param investorAddr The address to user to be added to the whitelist, signifies that the user completed KYC requirements.
     */
    function addToWhitelist(address investorAddr) public onlyOwner returns(bool success) {
        require(investorAddr!= address(0));
        whitelist[investorAddr] = true;
        return true;
    }

    /**
     * @dev Removes an investor's address from whitelist
     * @param investorAddr The address to user to be added to the whitelist, signifies that the user completed KYC requirements.
     */
    function removeFromWhitelist(address investorAddr) public onlyOwner returns(bool success) {
        require(investorAddr!= address(0));
        whitelist[investorAddr] = false;
        return true;
    }


}

pragma solidity 0.4.24;

contract ERC20Token {
  function totalSupply() public constant returns (uint);
  function balanceOf(address tokenOwner) public constant returns (uint balance);
  function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
  function transfer(address to, uint256 tokens) public returns (bool success);
  function approve(address spender, uint256 tokens) public returns (bool success);
  function transferFrom(address from, address to, uint256 tokens) public returns (bool success);

  event Transfer(address indexed from, address indexed to, uint tokens);
  event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

pragma solidity 0.4.24;

contract Ownable {

    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}

pragma solidity 0.4.24;

import "./Ownable.sol";

/* Pausable contract */
contract Pausable is Ownable {

    event Pause();
    event Unpause();

    bool public paused = false;

    /** @dev Modifier to make a function callable only when the contract is not paused.
      */
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    /** @dev Modifier to make a function callable only when the contract is paused.
      */
    modifier whenPaused() {
        require(paused);
        _;
    }

    /** @dev called by the owner to pause, triggers stopped state
      */
    function pause() onlyOwner whenNotPaused public {
        paused = true;
        emit Pause();
    }

    /** @dev called by the owner to unpause, returns to normal state
      */
    function unpause() onlyOwner whenPaused public {
        paused = false;
        emit Unpause();
    }

}

pragma solidity 0.4.24;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

pragma solidity 0.4.24;

import './ERC20Token.sol';
import './SafeMath.sol';

contract StandardToken is ERC20Token {

  using SafeMath for uint256;

  // Global variable to store total number of tokens passed from EmalToken.sol
  uint256 _totalSupply;

  mapping(address => uint256) balances;
  mapping(address => mapping(address => uint256)) allowed;


  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address tokenOwner) public view returns (uint256){
        return balances[tokenOwner];
  }



  function transfer(address to, uint256 tokens) public returns (bool){
      require(to != address(0));
      require(tokens > 0 && tokens <= balances[msg.sender]);

      balances[msg.sender] = balances[msg.sender].sub(tokens);
      balances[to] = balances[to].add(tokens);
      emit Transfer(msg.sender, to, tokens);
      return true;
  }

  // Transfer tokens from one address to another
  function transferFrom(address from, address to, uint256 tokens) public returns (bool success){
      require(to != address(0));
      require(tokens > 0 && tokens <= balances[from]);
      require(tokens <= allowed[from][msg.sender]);

      balances[from] = balances[from].sub(tokens);
      balances[to] = balances[to].add(tokens);
      allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
      emit Transfer(from, to, tokens);

      return true;
  }

  // Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
  function approve(address spender, uint256 tokens) public returns (bool success){
      allowed[msg.sender][spender] = tokens;
      emit Approval(msg.sender, spender, tokens);
      return true;
  }

  // Function to check the amount of tokens that an owner allowed to a spender.
  function allowance(address tokenOwner, address spender) public view returns (uint256 remaining){
      return allowed[tokenOwner][spender];
  }

  // Increase the amount of tokens that an owner allowed to a spender.
  // approve should be called when allowed[spender] == 0.
  // To increment allowed value is better to use this function to avoid 2 calls (and wait until the first transaction is mined)
  function increaseApproval(address spender, uint256 addedValue) public returns (bool) {
    allowed[msg.sender][spender] = (allowed[msg.sender][spender].add(addedValue));
    emit Approval(msg.sender, spender, allowed[msg.sender][spender]);
    return true;
  }

  // Decrease the amount of tokens that an owner allowed to a spender.
  // approve should be called when allowed[spender] == 0.
  // To decrement allowed value is better to use this function to avoid 2 calls (and wait until the first transaction is mined)
  function decreaseApproval(address spender, uint256 subtractedValue ) public returns (bool){
    uint256 oldValue = allowed[msg.sender][spender];
    if (subtractedValue >= oldValue) {
      allowed[msg.sender][spender] = 0;
    } else {
      allowed[msg.sender][spender] = oldValue.sub(subtractedValue);
    }
    emit Approval(msg.sender, spender, allowed[msg.sender][spender]);
    return true;
  }

}

pragma solidity 0.4.24;

import "./EmalToken.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

/** @title StandardTokenVesting
  * @dev A token holder contract that can release its token balance gradually like a
  * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the owner.
  */
contract StandardTokenVesting is Ownable {
  using SafeMath for uint256;

  event Released(uint256 amount);
  event Revoked();

  // beneficiary of tokens after they are released
  address public beneficiary;

  uint256 public cliff;
  uint256 public start;
  uint256 public duration;

  bool public revocable;

  mapping (address => uint256) public released;
  mapping (address => bool) public revoked;


  /** @dev Creates a vesting contract that vests its balance of any ERC20 token to the
   * _beneficiary, gradually in a linear fashion until _start + _duration. By then all
   * of the balance will have vested.
   * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
   * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
   * @param _start the time (as Unix time) at which point vesting starts
   * @param _duration duration in seconds of the period in which the tokens will vest
   * @param _revocable whether the vesting is revocable or not
   */
  constructor(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration, bool _revocable) public {
    require(_beneficiary != address(0));
    require(_cliff <= _duration);

    beneficiary = _beneficiary;
    revocable = _revocable;
    duration = _duration;
    owner = msg.sender;
    cliff = _start.add(_cliff);
    start = _start;
  }

  /** @notice Transfers vested tokens to beneficiary.
    * @param token ERC20 token which is being vested
    */
  function release(EmalToken token) public returns (bool){
    uint256 unreleased = releasableAmount(token);
    require(unreleased > 0);
    released[token] = released[token].add(unreleased);

    token.transfer(beneficiary, unreleased);
    emit Released(unreleased);
    return true;
  }

  /** @notice Allows the owner to revoke the vesting. Tokens already vested
    * remain in the contract, the rest are returned to the owner.
    * @param token ERC20 token which is being vested
    */
  function revoke(EmalToken token) public onlyOwner returns(bool) {
    require(revocable);
    require(!revoked[token]);
    uint256 balance = token.balanceOf(this);
    uint256 unreleased = releasableAmount(token);
    uint256 refund = balance.sub(unreleased);

    revoked[token] = true;
    token.transfer(owner, refund);
    emit Revoked();

    return true;
  }

  /** @dev Calculates the amount that has already vested but hasn't been released yet.
    * @param token ERC20 token which is being vested
    */
  function releasableAmount(EmalToken token) public view returns (uint256) {
    return vestedAmount(token).sub(released[token]);
  }

  /** @dev Calculates the amount that has already vested.
    * @param token Emal token which is being vested
    */
  function vestedAmount(EmalToken token) public view returns (uint256) {
    uint256 currentBalance = token.balanceOf(this);
    uint256 totalBalance = currentBalance.add(released[token]);

    if (block.timestamp < cliff) {
      return 0;
    } else if (block.timestamp >= start.add(duration) || revoked[token]) {
      return totalBalance;
    } else {
      return totalBalance.mul(block.timestamp.sub(start)).div(duration);
    }
  }
}

pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./Ownable.sol";


contract EmalToken {
    // add function prototypes of only those used here
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool);
    
    function getBountyAmount() public view returns(uint256);
}


contract EmalBounty is Ownable {

    using SafeMath for uint256;

    // The token being sold
    EmalToken public token;

    // Bounty contract state Data structures
    enum State {
        Active,
        Closed
    }

    // contains current state of bounty contract
    State public state;

    // Bounty limit in EMAL tokens
    uint256 public bountyLimit;

    // Count of total number of EML tokens that have been currently allocated to bounty users
    uint256 public totalTokensAllocated = 0;

    // Count of allocated tokens (not issued only allocated) for each bounty user
    mapping(address => uint256) public allocatedTokens;

    // Count of allocated tokens issued to each bounty user.
    mapping(address => uint256) public amountOfAllocatedTokensGivenOut;


    /** @dev Event fired when tokens are allocated to a bounty user account
      * @param beneficiary Address that is allocated tokens
      * @param tokenCount The amount of tokens that were allocated
      */
    event TokensAllocated(address indexed beneficiary, uint256 tokenCount);
    event TokensDeallocated(address indexed beneficiary, uint256 tokenCount);

    /**
     * @dev Event fired when EML tokens are sent to a bounty user
     * @param beneficiary Address where the allocated tokens were sent
     * @param tokenCount The amount of tokens that were sent
     */
    event IssuedAllocatedTokens(address indexed beneficiary, uint256 tokenCount);



    /** @param _token Address of the token that will be rewarded for the investors
      */
    constructor(address _token) public {
        require(_token != address(0));
        owner = msg.sender;
        token = EmalToken(_token);
        state = State.Active;
        bountyLimit = token.getBountyAmount();
    }

    /* Do not accept ETH */
    function() external payable {
        revert();
    }

    function closeBounty() public onlyOwner returns(bool){
        require( state!=State.Closed );
        state = State.Closed;
        return true;
    }

    /** @dev Public function to check if bounty isActive or not
      * @return True if Bounty event has ended
      */
    function isBountyActive() public view returns(bool) {
        if (state==State.Active && totalTokensAllocated<bountyLimit){
            return true;
        } else {
            return false;
        }
    }

    /** @dev Allocates tokens to a bounty user
      * @param beneficiary The address of the bounty user
      * @param tokenCount The number of tokens to be allocated to this address
      */
    function allocateTokens(address beneficiary, uint256 tokenCount) public onlyOwner returns(bool success) {
        require(beneficiary != address(0));
        require(validAllocation(tokenCount));

        uint256 tokens = tokenCount;

        /* Allocate only the remaining tokens if final contribution exceeds hard cap */
        if (totalTokensAllocated.add(tokens) > bountyLimit) {
            tokens = bountyLimit.sub(totalTokensAllocated);
        }

        /* Update state and balances */
        allocatedTokens[beneficiary] = allocatedTokens[beneficiary].add(tokens);
        totalTokensAllocated = totalTokensAllocated.add(tokens);
        emit TokensAllocated(beneficiary, tokens);

        return true;
    }

    function validAllocation( uint256 tokenCount ) internal view returns(bool) {
        bool isActive = state==State.Active;
        bool positiveAllocation = tokenCount>0;
        bool bountyLimitNotReached = totalTokensAllocated<bountyLimit;
        return isActive && positiveAllocation && bountyLimitNotReached;
    }

    /** @dev Remove tokens from a bounty user's allocation.
      * @dev Used in game based bounty allocation, automatically called from the Sails app
      * @param beneficiary The address of the bounty user
      * @param tokenCount The number of tokens to be deallocated to this address
      */
    function deductAllocatedTokens(address beneficiary, uint256 tokenCount) public onlyOwner returns(bool success) {
        require(beneficiary != address(0));
        require(tokenCount>0 && tokenCount<=allocatedTokens[beneficiary]);

        allocatedTokens[beneficiary] = allocatedTokens[beneficiary].sub(tokenCount);
        totalTokensAllocated = totalTokensAllocated.sub(tokenCount);
        emit TokensDeallocated(beneficiary, tokenCount);

        return true;
    }

    /** @dev Getter function to check the amount of allocated tokens
      * @param beneficiary address of the investor or the bounty user
      */
    function getAllocatedTokens(address beneficiary) public view returns(uint256 tokenCount) {
        require(beneficiary != address(0));
        return allocatedTokens[beneficiary];
    }

    /** @dev Bounty users will be issued EML Tokens by the sails api,
      * @dev after the Bounty has ended to their address
      * @param beneficiary address of the bounty user
      */
    function issueTokensToAllocatedUsers(address beneficiary) public onlyOwner returns(bool success) {
        require(beneficiary!=address(0));
        require(allocatedTokens[beneficiary]>0);

        uint256 tokensToSend = allocatedTokens[beneficiary];
        allocatedTokens[beneficiary] = 0;
        amountOfAllocatedTokensGivenOut[beneficiary] = amountOfAllocatedTokensGivenOut[beneficiary].add(tokensToSend);
        assert(token.transferFrom(owner, beneficiary, tokensToSend));

        emit IssuedAllocatedTokens(beneficiary, tokensToSend);
        return true;
    }
}

pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./Pausable.sol";

contract EmalToken {
    // add function prototypes of only those used here
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool);
    function getCrowdsaleAmount() public view returns(uint256);
    function setStartTimeForTokenTransfers(uint256 _startTime) external;
}

contract EmalWhitelist {
    // add function prototypes of only those used here
    function isWhitelisted(address investorAddr) public view returns(bool whitelisted);
}


contract EmalCrowdsale is Ownable, Pausable {

    using SafeMath for uint256;

    // Start and end timestamps
    uint256 public startTime;
    uint256 public endTime;

    // The token being sold
    EmalToken public token;

    // Whitelist contract used to store whitelisted addresses
    EmalWhitelist public list;

    // Address where funds are collected
    address public multisigWallet;

    // Switched to true once token contract is notified of when to enable token transfers
    bool private isStartTimeSetForTokenTransfers = false;

    // Hard cap in EMAL tokens
    uint256 public hardCap;

    // Soft cap in EMAL tokens
    uint256 constant public soft_cap = 50000000 * (10 ** 18);

    // Amount of tokens that were sold to ether investors plus tokens allocated to investors for fiat and btc investments.
    uint256 public totalTokensSoldandAllocated = 0;



    // Investor contributions made in ether
    mapping(address => uint256) public etherInvestments;

    // Tokens given to investors who sent ether investments
    mapping(address => uint256) public tokensSoldForEther;

    // Total ether raised by the Crowdsale
    uint256 public totalEtherRaisedByCrowdsale = 0;

    // Total number of tokens sold to investors who made payments in ether
    uint256 public totalTokensSoldByEtherInvestments = 0;

    // Count of allocated tokens  for each investor or bounty user
    mapping(address => uint256) public allocatedTokens;

    // Count of total number of EML tokens that have been currently allocated to Crowdsale investors
    uint256 public totalTokensAllocated = 0;



   /** @dev Event for EML token purchase using ether
     * @param investorAddr Address that paid and got the tokens
     * @param paidAmount The amount that was paid (in wei)
     * @param tokenCount The amount of tokens that were bought
     */
    event TokenPurchasedUsingEther(address indexed investorAddr, uint256 paidAmount, uint256 tokenCount);

    /**
     * @dev Event for refund logging
     * @param receiver The address that received the refund
     * @param amount The amount that is being refunded (in wei)
     */
    event Refund(address indexed receiver, uint256 amount);

    /** @dev Event fired when EML tokens are allocated to an investor account
      * @param beneficiary Address that is allocated tokens
      * @param tokenCount The amount of tokens that were allocated
      */
    event TokensAllocated(address indexed beneficiary, uint256 tokenCount);
    event TokensDeallocated(address indexed beneficiary, uint256 tokenCount);


    /** @dev variables and functions which determine conversion rate from ETH to EML
      * based on bonuses and current timestamp.
      */
    uint256 priceOfEthInUSD = 450;
    uint256 bonusPercent1 = 25;
    uint256 bonusPercent2 = 15;
    uint256 bonusPercent3 = 0;
    uint256 priceOfEMLTokenInUSDPenny = 60;
    uint256 overridenBonusValue = 0;

    function setExchangeRate(uint256 overridenValue) public onlyOwner returns(bool) {
        require( overridenValue > 0 );
        require( overridenValue != priceOfEthInUSD);
        priceOfEthInUSD = overridenValue;
        return true;
    }

    function getExchangeRate() public view returns(uint256){
        return priceOfEthInUSD;
    }

    function setOverrideBonus(uint256 overridenValue) public onlyOwner returns(bool) {
        require( overridenValue > 0 );
        require( overridenValue != overridenBonusValue);
        overridenBonusValue = overridenValue;
        return true;
    }

    /**
     * @dev public function that is used to determine the current rate for token / ETH conversion
     * @dev there exists a case where rate cant be set to 0, which is fine.
     * @return The current token rate
     */
    function getRate() public view returns(uint256) {
        require( priceOfEMLTokenInUSDPenny !=0 );
        require( priceOfEthInUSD !=0 );
        uint256 rate;

        if(overridenBonusValue > 0){
            rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(overridenBonusValue.add(100)).div(100);
        } else {
            if (now <= (startTime + 1 days)) {
                rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(bonusPercent1.add(100)).div(100);
            } if (now > (startTime + 1 days) && now <= (startTime + 2 days)) {
                rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(bonusPercent2.add(100)).div(100);
            } else {
                rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(bonusPercent3.add(100)).div(100);
            }
        }
        return rate;
    }


    /** @dev Initialise the Crowdsale contract.
      * (can be removed for testing) _startTime Unix timestamp for the start of the token sale
      * (can be removed for testing) _endTime Unix timestamp for the end of the token sale
      * @param _multisigWallet Ethereum address to which the invested funds are forwarded
      * @param _token Address of the token that will be rewarded for the investors
      * @param _list contains a list of investors who completed KYC procedures.
      */
    constructor(uint256 _startTime, uint256 _endTime, address _multisigWallet, address _token, address _list) public {
        require(_startTime >= now);
        require(_endTime >= _startTime);
        require(_multisigWallet != address(0));
        require(_token != address(0));
        require(_list != address(0));

        startTime = _startTime;
        endTime = _endTime;
        multisigWallet = _multisigWallet;
        owner = msg.sender;
        token = EmalToken(_token);
        list = EmalWhitelist(_list);
        hardCap = token.getCrowdsaleAmount();
    }

    /** @dev Fallback function that can be used to buy EML tokens. Or in
      * case of the owner, return ether to allow refunds in case crowdsale
      * ended or paused and didnt reach soft_cap.
      */
    function() external payable {
        if (msg.sender == multisigWallet) {
            require( (!isCrowdsaleActive()) && totalTokensSoldandAllocated<soft_cap);
        } else {
            if (list.isWhitelisted(msg.sender)) {
                buyTokensUsingEther(msg.sender);
            } else {
                revert();
            }
        }
    }

    /** @dev Function for buying EML tokens using ether
      * @param _investorAddr The address that should receive bought tokens
      */
    function buyTokensUsingEther(address _investorAddr) internal whenNotPaused {
        require(_investorAddr != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;
        uint256 returnToSender = 0;

        // final rate after including rate value and bonus amount.
        uint256 finalConversionRate = getRate();

        // Calculate EML token amount to be transferred
        uint256 tokens = weiAmount.mul(finalConversionRate);

        // Distribute only the remaining tokens if final contribution exceeds hard cap
        if (totalTokensSoldandAllocated.add(tokens) > hardCap) {
            tokens = hardCap.sub(totalTokensSoldandAllocated);
            weiAmount = tokens.div(finalConversionRate);
            returnToSender = msg.value.sub(weiAmount);
        }

        // update state and balances
        etherInvestments[_investorAddr] = etherInvestments[_investorAddr].add(weiAmount);
        tokensSoldForEther[_investorAddr] = tokensSoldForEther[_investorAddr].add(tokens);
        totalTokensSoldByEtherInvestments = totalTokensSoldByEtherInvestments.add(tokens);
        totalEtherRaisedByCrowdsale = totalEtherRaisedByCrowdsale.add(weiAmount);
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.add(tokens);


        // assert implies it should never fail
        assert(token.transferFrom(owner, _investorAddr, tokens));
        emit TokenPurchasedUsingEther(_investorAddr, weiAmount, tokens);

        // Forward funds
        multisigWallet.transfer(weiAmount);

        // Update token contract.
        _postValidationUpdateTokenContract();

        // Return funds that are over hard cap
        if (returnToSender > 0) {
            msg.sender.transfer(returnToSender);
        }
    }

    function _postValidationUpdateTokenContract() internal {
       /** @dev If hard cap is reachde allow token transfers after two weeks
         * @dev Allow users to transfer tokens only after hardCap is reached
         * @dev Notiy token contract about startTime to start transfers
         */
        if (totalTokensSoldandAllocated == hardCap) {
            token.setStartTimeForTokenTransfers(now + 2 weeks);
        }

       /** @dev If its the first token sold or allocated then set s, allow after 2 weeks
         * @dev Allow users to transfer tokens only after ICO crowdsale ends.
         * @dev Notify token contract about sale end time
         */
        if (!isStartTimeSetForTokenTransfers) {
            isStartTimeSetForTokenTransfers = true;
            token.setStartTimeForTokenTransfers(endTime + 2 weeks);
        }
    }

    /** @dev Internal function that is used to check if the incoming purchase should be accepted.
      * @return True if the transaction can buy tokens
      */
    function validPurchase() internal view returns(bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool minimumPurchase = msg.value >= 1*(10**18);
        bool hardCapNotReached = totalTokensSoldandAllocated < hardCap;
        return withinPeriod && hardCapNotReached && minimumPurchase;
    }

    /** @dev Public function to check if Crowdsale isActive or not
      * @return True if Crowdsale event has ended
      */
    function isCrowdsaleActive() public view returns(bool) {
        if (!paused && now>startTime && now<endTime && totalTokensSoldandAllocated<=hardCap){
            return true;
        } else {
            return false;
        }
    }

    /** @dev Gets the balance of the specified address.
      * @param _owner The address to query the the balance of.
      * @return An uint256 representing the amount owned by the passed address.
      */
    function balanceOfEtherInvestor(address _owner) external view returns(uint256 balance) {
        require(_owner != address(0));
        return etherInvestments[_owner];
    }

    function getTokensSoldToEtherInvestor(address _owner) public view returns(uint256 balance) {
        require(_owner != address(0));
        return tokensSoldForEther[_owner];
    }

    /** @dev Returns ether to token holders in case soft cap is not reached.
      */
    function claimRefund() public whenNotPaused onlyOwner {
        require(now>endTime);
        require(totalTokensSoldandAllocated<soft_cap);
        uint256 amount = etherInvestments[msg.sender];

        if (address(this).balance >= amount) {
            etherInvestments[msg.sender] = 0;
            if (amount > 0) {
                msg.sender.transfer(amount);
                emit Refund(msg.sender, amount);
            }
        }
      }




    /** @dev BELOW ARE FUNCTIONS THAT HANDLE INVESTMENTS IN FIAT AND BTC.
      * functions are automatically called by ICO Sails.js app.
      */


    /** @dev Allocates EML tokens to an investor address called automatically
      * after receiving fiat or btc investments from KYC whitelisted investors.
      * @param beneficiary The address of the investor
      * @param tokenCount The number of tokens to be allocated to this address
      */
    function allocateTokens(address beneficiary, uint256 tokenCount) public onlyOwner returns(bool success) {
        require(beneficiary != address(0));
        require(validAllocation(tokenCount));

        uint256 tokens = tokenCount;

        /* Allocate only the remaining tokens if final contribution exceeds hard cap */
        if (totalTokensSoldandAllocated.add(tokens) > hardCap) {
            tokens = hardCap.sub(totalTokensSoldandAllocated);
        }

        /* Update state and balances */
        allocatedTokens[beneficiary] = allocatedTokens[beneficiary].add(tokens);
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.add(tokens);
        totalTokensAllocated = totalTokensAllocated.add(tokens);

        // assert implies it should never fail
        assert(token.transferFrom(owner, beneficiary, tokens));
        emit TokensAllocated(beneficiary, tokens);

        /* Update token contract. */
        _postValidationUpdateTokenContract();
        return true;
    }

    function validAllocation( uint256 tokenCount ) internal view returns(bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool positiveAllocation = tokenCount > 0;
        bool hardCapNotReached = totalTokensSoldandAllocated < hardCap;
        return withinPeriod && positiveAllocation && hardCapNotReached;
    }


    /** @dev Getter function to check the amount of allocated tokens
      * @param beneficiary address of the investor
      */
    function getAllocatedTokens(address beneficiary) public view returns(uint256 tokenCount) {
        require(beneficiary != address(0));
        return allocatedTokens[beneficiary];
    }

    function getSoldandAllocatedTokens(address _addr) public view returns (uint256) {
        require(_addr != address(0));
        uint256 totalTokenCount = getAllocatedTokens(_addr).add(getTokensSoldToEtherInvestor(_addr));
        return totalTokenCount;
    }

}

pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./Pausable.sol";

contract EmalToken {
    // add function prototypes of only those used here
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool);
    function getPresaleAmount() public view returns(uint256);
}

contract EmalWhitelist {
    // add function prototypes of only those used here
    function isWhitelisted(address investorAddr) public view returns(bool whitelisted);
}


contract EmalPresale is Ownable, Pausable {

    using SafeMath for uint256;

    // Start and end timestamps
    uint256 public startTime;
    uint256 public endTime;

    // The token being sold
    EmalToken public token;

    // Whitelist contract used to store whitelisted addresses
    EmalWhitelist public list;

    // Address where funds are collected
    address public multisigWallet;

    // Hard cap in EMAL tokens
    uint256 public hardCap;

    // Amount of tokens that were sold to ether investors plus tokens allocated to investors for fiat and btc investments.
    uint256 public totalTokensSoldandAllocated = 0;



    // Investor contributions made in ether
    mapping(address => uint256) public etherInvestments;

    // Tokens given to investors who sent ether investments
    mapping(address => uint256) public tokensSoldForEther;

    // Total ether raised by the Presale
    uint256 public totalEtherRaisedByPresale = 0;

    // Total number of tokens sold to investors who made payments in ether
    uint256 public totalTokensSoldByEtherInvestments = 0;

    // Count of allocated tokens  for each investor or bounty user
    mapping(address => uint256) public allocatedTokens;

    // Count of total number of EML tokens that have been currently allocated to Presale investors
    uint256 public totalTokensAllocated = 0;



   /** @dev Event for EML token purchase using ether
     * @param investorAddr Address that paid and got the tokens
     * @param paidAmount The amount that was paid (in wei)
     * @param tokenCount The amount of tokens that were bought
     */
    event TokenPurchasedUsingEther(address indexed investorAddr, uint256 paidAmount, uint256 tokenCount);

    /** @dev Event fired when EML tokens are allocated to an investor account
      * @param beneficiary Address that is allocated tokens
      * @param tokenCount The amount of tokens that were allocated
      */
    event TokensAllocated(address indexed beneficiary, uint256 tokenCount);
    event TokensDeallocated(address indexed beneficiary, uint256 tokenCount);


    /** @dev variables and functions which determine conversion rate from ETH to EML
      * based on bonuses and current timestamp.
      */
    uint256 priceOfEthInUSD = 450;
    uint256 bonusPercent1 = 35;
    uint256 priceOfEMLTokenInUSDPenny = 60;
    uint256 overridenBonusValue = 0;

    function setExchangeRate(uint256 overridenValue) public onlyOwner returns(bool) {
        require( overridenValue > 0 );
        require( overridenValue != priceOfEthInUSD);
        priceOfEthInUSD = overridenValue;
        return true;
    }

    function getExchangeRate() public view returns(uint256){
        return priceOfEthInUSD;
    }

    function setOverrideBonus(uint256 overridenValue) public onlyOwner returns(bool) {
        require( overridenValue > 0 );
        require( overridenValue != overridenBonusValue);
        overridenBonusValue = overridenValue;
        return true;
    }

    /** @dev public function that is used to determine the current rate for ETH to EML conversion
      * @return The current token rate
      */
    function getRate() public view returns(uint256) {
        require(priceOfEMLTokenInUSDPenny > 0 );
        require(priceOfEthInUSD > 0 );
        uint256 rate;

        if(overridenBonusValue > 0){
            rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(overridenBonusValue.add(100)).div(100);
        } else {
            rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(bonusPercent1.add(100)).div(100);
        }
        return rate;
    }


    /** @dev Initialise the Presale contract.
      * (can be removed for testing) _startTime Unix timestamp for the start of the token sale
      * (can be removed for testing) _endTime Unix timestamp for the end of the token sale
      * @param _multisigWallet Ethereum address to which the invested funds are forwarded
      * @param _token Address of the token that will be rewarded for the investors
      * @param _list contains a list of investors who completed KYC procedures.
      */
    constructor(uint256 _startTime, uint256 _endTime, address _multisigWallet, address _token, address _list) public {
        require(_startTime >= now);
        require(_endTime >= _startTime);
        require(_multisigWallet != address(0));
        require(_token != address(0));
        require(_list != address(0));

        startTime = _startTime;
        endTime = _endTime;
        multisigWallet = _multisigWallet;
        owner = msg.sender;
        token = EmalToken(_token);
        list = EmalWhitelist(_list);
        hardCap = token.getPresaleAmount();
    }

    /** @dev Fallback function that can be used to buy tokens.
      */
    function() external payable {
        if (list.isWhitelisted(msg.sender)) {
            buyTokensUsingEther(msg.sender);
        } else {
            /* Do not accept ETH */
            revert();
        }
    }

    /** @dev Function for buying EML tokens using ether
      * @param _investorAddr The address that should receive bought tokens
      */
    function buyTokensUsingEther(address _investorAddr) internal whenNotPaused {
        require(_investorAddr != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;
        uint256 returnToSender = 0;

        // final rate after including rate value and bonus amount.
        uint256 finalConversionRate = getRate();

        // Calculate EML token amount to be transferred
        uint256 tokens = weiAmount.mul(finalConversionRate);

        // Distribute only the remaining tokens if final contribution exceeds hard cap
        if (totalTokensSoldandAllocated.add(tokens) > hardCap) {
            tokens = hardCap.sub(totalTokensSoldandAllocated);
            weiAmount = tokens.div(finalConversionRate);
            returnToSender = msg.value.sub(weiAmount);
        }

        // update state and balances
        etherInvestments[_investorAddr] = etherInvestments[_investorAddr].add(weiAmount);
        tokensSoldForEther[_investorAddr] = tokensSoldForEther[_investorAddr].add(tokens);
        totalTokensSoldByEtherInvestments = totalTokensSoldByEtherInvestments.add(tokens);
        totalEtherRaisedByPresale = totalEtherRaisedByPresale.add(weiAmount);
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.add(tokens);


        // assert implies it should never fail
        assert(token.transferFrom(owner, _investorAddr, tokens));
        emit TokenPurchasedUsingEther(_investorAddr, weiAmount, tokens);

        // Forward funds
        multisigWallet.transfer(weiAmount);

        // Return funds that are over hard cap
        if (returnToSender > 0) {
            msg.sender.transfer(returnToSender);
        }
    }

    /**
     * @dev Internal function that is used to check if the incoming purchase should be accepted.
     * @return True if the transaction can buy tokens
     */
    function validPurchase() internal view returns(bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool minimumPurchase = msg.value >= 1*(10**18);
        bool hardCapNotReached = totalTokensSoldandAllocated < hardCap;
        return withinPeriod && hardCapNotReached && minimumPurchase;
    }

    /** @dev Public function to check if Presale isActive or not
      * @return True if Presale event has ended
      */
    function isPresaleActive() public view returns(bool) {
        if (!paused && now>startTime && now<endTime && totalTokensSoldandAllocated<=hardCap){
            return true;
        } else {
            return false;
        }
    }

    /** @dev Gets the balance of the specified address.
      * @param _owner The address to query the the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOfEtherInvestor(address _owner) external view returns(uint256 balance) {
        require(_owner != address(0));
        return etherInvestments[_owner];
    }

    function getTokensSoldToEtherInvestor(address _owner) public view returns(uint256 balance) {
        require(_owner != address(0));
        return tokensSoldForEther[_owner];
    }




    /** @dev BELOW ARE FUNCTIONS THAT HANDLE INVESTMENTS IN FIAT AND BTC.
      * functions are automatically called by ICO Sails.js app.
      */


    /** @dev Allocates EML tokens to an investor address called automatically
      * after receiving fiat or btc investments from KYC whitelisted investors.
      * @param beneficiary The address of the investor
      * @param tokenCount The number of tokens to be allocated to this address
      */
    function allocateTokens(address beneficiary, uint256 tokenCount) public onlyOwner returns(bool success) {
        require(beneficiary != address(0));
        require(validAllocation(tokenCount));

        uint256 tokens = tokenCount;

        /* Allocate only the remaining tokens if final contribution exceeds hard cap */
        if (totalTokensSoldandAllocated.add(tokens) > hardCap) {
            tokens = hardCap.sub(totalTokensSoldandAllocated);
        }

        /* Update state and balances */
        allocatedTokens[beneficiary] = allocatedTokens[beneficiary].add(tokens);
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.add(tokens);
        totalTokensAllocated = totalTokensAllocated.add(tokens);

        // assert implies it should never fail
        assert(token.transferFrom(owner, beneficiary, tokens));
        emit TokensAllocated(beneficiary, tokens);

        return true;
    }

    function validAllocation( uint256 tokenCount ) internal view returns(bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool positiveAllocation = tokenCount > 0;
        bool hardCapNotReached = totalTokensSoldandAllocated < hardCap;
        return withinPeriod && positiveAllocation && hardCapNotReached;
    }


    /** @dev Getter function to check the amount of allocated tokens
      * @param beneficiary address of the investor
      */
    function getAllocatedTokens(address beneficiary) public view returns(uint256 tokenCount) {
        require(beneficiary != address(0));
        return allocatedTokens[beneficiary];
    }

    function getSoldandAllocatedTokens(address _addr) public view returns (uint256) {
        require(_addr != address(0));
        uint256 totalTokenCount = getAllocatedTokens(_addr).add(getTokensSoldToEtherInvestor(_addr));
        return totalTokenCount;
    }

}

pragma solidity 0.4.24;

import "./SafeMath.sol";
import './StandardToken.sol';
import './Ownable.sol';

contract EmalToken is StandardToken, Ownable {

    using SafeMath for uint256;

    string public constant symbol = "EML";
    string public constant name = "e-Mal Token";
    uint8 public constant decimals = 18;

    // Total Number of tokens ever goint to be minted. 1 BILLION EML tokens.
    uint256 private constant minting_capped_amount = 1000000000 * 10 ** uint256(decimals);

    // 24% of initial supply
    uint256 constant presale_amount = 120000000 * 10 ** uint256(decimals);
    // 60% of inital supply
    uint256 constant crowdsale_amount = 300000000 * 10 ** uint256(decimals);
    // 8% of inital supply.
    uint256  constant vesting_amount = 40000000 * 10 ** uint256(decimals);
    // 8% of inital supply.
    uint256 constant bounty_amount = 40000000 * 10 ** uint256(decimals);
    
    uint256 private initialSupply = minting_capped_amount;

    address public presaleAddress;
    address public crowdsaleAddress;
    address public vestingAddress;
    address public bountyAddress;



    /** @dev Defines the start time after which transferring of EML tokens
      * will be allowed done so as to prevent early buyers from clearing out
      * of their EML balance during the presale and publicsale.
      */
    uint256 public startTimeForTransfers;

    /** @dev to cap the total number of tokens that will ever be newly minted
      * owner has to stop the minting by setting this variable to true.
      */
    bool public mintingFinished = false;

    /** @dev Miniting Essentials functions as per OpenZeppelin standards
      */
    modifier canMint() {
      require(!mintingFinished);
      _;
    }
    modifier hasMintPermission() {
      require(msg.sender == owner);
      _;
    }

    /** @dev to prevent malicious use of EML tokens and to comply with Anti
      * Money laundering regulations EML tokens can be frozen.
      */
    mapping (address => bool) public frozenAccount;

    /** @dev This generates a public event on the blockchain that will notify clients
      */
    event FrozenFunds(address target, bool frozen);
    event Mint(address indexed to, uint256 amount);
    event MintFinished();
    event Burn(address indexed burner, uint256 value);


    constructor() public {
        startTimeForTransfers = now - 210 days;

        _totalSupply = initialSupply;
        owner = msg.sender;
        balances[owner] = _totalSupply;
        emit Transfer(address(0), owner, balances[owner]);
    }

    /* Do not accept ETH */
    function() public payable {
        revert();
    }


    /** @dev Basic setters and getters to allocate tokens for vesting factory, presale
      * crowdsale and bounty this is done so that no need of actually transferring EML
      * tokens to sale contracts and hence preventing EML tokens from the risk of being
      * locked out in future inside the subcontracts.
      */
    function setPresaleAddress(address _presaleAddress) external onlyOwner {
        presaleAddress = _presaleAddress;
        assert(approve(presaleAddress, presale_amount));
    }
    function setCrowdsaleAddress(address _crowdsaleAddress) external onlyOwner {
        crowdsaleAddress = _crowdsaleAddress;
        assert(approve(crowdsaleAddress, crowdsale_amount));
    }
    function setVestingAddress(address _vestingAddress) external onlyOwner {
        vestingAddress = _vestingAddress;
        assert(approve(vestingAddress, vesting_amount));
    }
    function setBountyAddress(address _bountyAddress) external onlyOwner {
        bountyAddress = _bountyAddress;
        assert(approve(bountyAddress, bounty_amount));
    }
    


    function getPresaleAmount()  internal pure returns(uint256) {
        return presale_amount;
    }
    function getCrowdsaleAmount() internal pure  returns(uint256) {
        return crowdsale_amount;
    }
    function getVestingAmount() internal pure  returns(uint256) {
        return vesting_amount;
    }
    function getBountyAmount() internal pure  returns(uint256) {
        return bounty_amount;
    }

    /** @dev Sets the start time after which transferring of EML tokens
      * will be allowed done so as to prevent early buyers from clearing out
      * of their EML balance during the presale and publicsale.
      */
    function setStartTimeForTokenTransfers(uint256 _startTimeForTransfers) external {
        require(msg.sender == crowdsaleAddress);
        if (_startTimeForTransfers < startTimeForTransfers) {
            startTimeForTransfers = _startTimeForTransfers;
        }
    }


    /** @dev Transfer possible only after ICO ends and Frozen accounts
      * wont be able to transfer funds to other any other account and viz.
      * @notice added safeTransfer functionality
      */
    function transfer(address _to, uint256 _value) public returns(bool) {
        require(now >= startTimeForTransfers);
        require(!frozenAccount[msg.sender]);
        require(!frozenAccount[_to]);

        require(super.transfer(_to, _value));
        return true;
    }

    /** @dev Only owner's tokens can be transferred before Crowdsale ends.
      * beacuse the inital supply of EML is allocated to owners acc and later
      * distributed to various subcontracts.
      * @notice added safeTransferFrom functionality
      */
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool) {
        require(!frozenAccount[_from]);
        require(!frozenAccount[_to]);
        require(!frozenAccount[msg.sender]);

        if (now < startTimeForTransfers) {
            require(_from == owner);
        }

        require(super.transferFrom(_from, _to, _value));
        return true;
    }

    /** @notice added safeApprove functionality
      */
    function approve(address spender, uint256 tokens) public returns (bool){
        require(super.approve(spender, tokens));
        return true;
    }

   /** @notice `freeze? Prevent | Allow` `target` from sending & receiving tokens
     * @param target Address to be frozen
     * @param freeze either to freeze it or not
     */
    function freezeAccount(address target, bool freeze) public onlyOwner {
        require(frozenAccount[target] != freeze);

        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }


    /** @dev Function to mint tokens
      * @param _to The address that will receive the minted tokens.
      * @param _amount The amount of tokens to mint.
      * @return A boolean that indicates if the operation was successful.
      */
    function mint(address _to, uint256 _amount) public hasMintPermission canMint returns (bool) {
      require(_totalSupply.add(_amount) <= minting_capped_amount);

      _totalSupply = _totalSupply.add(_amount);
      balances[_to] = balances[_to].add(_amount);
      emit Mint(_to, _amount);
      emit Transfer(address(0), _to, _amount);
      return true;
    }

   /** @dev Function to stop minting new tokens.
     * @return True if the operation was successful.
     */
    function finishMinting() public onlyOwner canMint returns (bool) {
      mintingFinished = true;
      emit MintFinished();
      return true;
    }

    /** @dev Burns a specific amount of tokens.
      * @param _value The amount of token to be burned.
      */
     function burn(uint256 _value) public {
       _burn(msg.sender, _value);
     }

     function _burn(address _who, uint256 _value) internal {
       require(_value <= balances[_who]);
       // no need to require value <= totalSupply, since that would imply the
       // sender's balance is greater than the totalSupply, which *should* be an assertion failure

       balances[_who] = balances[_who].sub(_value);
       _totalSupply = _totalSupply.sub(_value);
       emit Burn(_who, _value);
       emit Transfer(_who, address(0), _value);
     }
}

pragma solidity 0.4.24;

import "./EmalToken.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

/** @title StandardTokenVesting
  * @dev A token holder contract that can release its token balance gradually like a
  * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the owner.
  */
contract StandardTokenVesting is Ownable {
  using SafeMath for uint256;

  event Released(uint256 amount);
  event Revoked();

  // beneficiary of tokens after they are released
  address public beneficiary;

  uint256 public cliff;
  uint256 public start;
  uint256 public duration;

  bool public revocable;

  mapping (address => uint256) public released;
  mapping (address => bool) public revoked;


  /** @dev Creates a vesting contract that vests its balance of any ERC20 token to the
   * _beneficiary, gradually in a linear fashion until _start + _duration. By then all
   * of the balance will have vested.
   * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
   * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
   * @param _start the time (as Unix time) at which point vesting starts
   * @param _duration duration in seconds of the period in which the tokens will vest
   * @param _revocable whether the vesting is revocable or not
   */
  constructor(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration, bool _revocable) public {
    require(_beneficiary != address(0));
    require(_cliff <= _duration);

    beneficiary = _beneficiary;
    revocable = _revocable;
    duration = _duration;
    owner = msg.sender;
    cliff = _start.add(_cliff);
    start = _start;
  }

  /** @notice Transfers vested tokens to beneficiary.
    * @param token ERC20 token which is being vested
    */
  function release(EmalToken token) public returns (bool){
    uint256 unreleased = releasableAmount(token);
    require(unreleased > 0);
    released[token] = released[token].add(unreleased);

    token.transfer(beneficiary, unreleased);
    emit Released(unreleased);
    return true;
  }

  /** @notice Allows the owner to revoke the vesting. Tokens already vested
    * remain in the contract, the rest are returned to the owner.
    * @param token ERC20 token which is being vested
    */
  function revoke(EmalToken token) public onlyOwner returns(bool) {
    require(revocable);
    require(!revoked[token]);
    uint256 balance = token.balanceOf(this);
    uint256 unreleased = releasableAmount(token);
    uint256 refund = balance.sub(unreleased);

    revoked[token] = true;
    token.transfer(owner, refund);
    emit Revoked();

    return true;
  }

  /** @dev Calculates the amount that has already vested but hasn't been released yet.
    * @param token ERC20 token which is being vested
    */
  function releasableAmount(EmalToken token) public view returns (uint256) {
    return vestedAmount(token).sub(released[token]);
  }

  /** @dev Calculates the amount that has already vested.
    * @param token Emal token which is being vested
    */
  function vestedAmount(EmalToken token) public view returns (uint256) {
    uint256 currentBalance = token.balanceOf(this);
    uint256 totalBalance = currentBalance.add(released[token]);

    if (block.timestamp < cliff) {
      return 0;
    } else if (block.timestamp >= start.add(duration) || revoked[token]) {
      return totalBalance;
    } else {
      return totalBalance.mul(block.timestamp.sub(start)).div(duration);
    }
  }
}

pragma solidity 0.4.24;

import './Ownable.sol';

/** @notice This contract provides support for whitelisting addresses.
 * only whitelisted addresses are allowed to send ether and buy tokens
 * during preSale and Pulic crowdsale.
 * @dev after deploying contract, deploy Presale / Crowdsale contract using
 * EmalWhitelist address. To allow claim refund functionality and allow wallet
 * owner efatoora to send ether to Crowdsale contract for refunds add wallet
 * address to whitelist.
 */
contract EmalWhitelist is Ownable {

    mapping(address => bool) whitelist;

    event AddToWhitelist(address investorAddr);
    event RemoveFromWhitelist(address investorAddr);


    /** @dev Throws if operator is not whitelisted.
     */
    modifier onlyIfWhitelisted(address investorAddr) {
        require(whitelist[investorAddr]);
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    /** @dev Returns if an address is whitelisted or not
     */
    function isWhitelisted(address investorAddr) public view returns(bool whitelisted) {
        return whitelist[investorAddr];
    }

    /**
     * @dev Adds an investor to whitelist
     * @param investorAddr The address to user to be added to the whitelist, signifies that the user completed KYC requirements.
     */
    function addToWhitelist(address investorAddr) public onlyOwner returns(bool success) {
        require(investorAddr!= address(0));
        whitelist[investorAddr] = true;
        return true;
    }

    /**
     * @dev Removes an investor's address from whitelist
     * @param investorAddr The address to user to be added to the whitelist, signifies that the user completed KYC requirements.
     */
    function removeFromWhitelist(address investorAddr) public onlyOwner returns(bool success) {
        require(investorAddr!= address(0));
        whitelist[investorAddr] = false;
        return true;
    }


}

pragma solidity 0.4.24;

contract ERC20Token {
  function totalSupply() public constant returns (uint);
  function balanceOf(address tokenOwner) public constant returns (uint balance);
  function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
  function transfer(address to, uint256 tokens) public returns (bool success);
  function approve(address spender, uint256 tokens) public returns (bool success);
  function transferFrom(address from, address to, uint256 tokens) public returns (bool success);

  event Transfer(address indexed from, address indexed to, uint tokens);
  event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

pragma solidity 0.4.24;

contract Ownable {

    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}

pragma solidity 0.4.24;

import "./Ownable.sol";

/* Pausable contract */
contract Pausable is Ownable {

    event Pause();
    event Unpause();

    bool public paused = false;

    /** @dev Modifier to make a function callable only when the contract is not paused.
      */
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    /** @dev Modifier to make a function callable only when the contract is paused.
      */
    modifier whenPaused() {
        require(paused);
        _;
    }

    /** @dev called by the owner to pause, triggers stopped state
      */
    function pause() onlyOwner whenNotPaused public {
        paused = true;
        emit Pause();
    }

    /** @dev called by the owner to unpause, returns to normal state
      */
    function unpause() onlyOwner whenPaused public {
        paused = false;
        emit Unpause();
    }

}

pragma solidity 0.4.24;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

pragma solidity 0.4.24;

import './ERC20Token.sol';
import './SafeMath.sol';

contract StandardToken is ERC20Token {

  using SafeMath for uint256;

  // Global variable to store total number of tokens passed from EmalToken.sol
  uint256 _totalSupply;

  mapping(address => uint256) balances;
  mapping(address => mapping(address => uint256)) allowed;


  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address tokenOwner) public view returns (uint256){
        return balances[tokenOwner];
  }



  function transfer(address to, uint256 tokens) public returns (bool){
      require(to != address(0));
      require(tokens > 0 && tokens <= balances[msg.sender]);

      balances[msg.sender] = balances[msg.sender].sub(tokens);
      balances[to] = balances[to].add(tokens);
      emit Transfer(msg.sender, to, tokens);
      return true;
  }

  // Transfer tokens from one address to another
  function transferFrom(address from, address to, uint256 tokens) public returns (bool success){
      require(to != address(0));
      require(tokens > 0 && tokens <= balances[from]);
      require(tokens <= allowed[from][msg.sender]);

      balances[from] = balances[from].sub(tokens);
      balances[to] = balances[to].add(tokens);
      allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
      emit Transfer(from, to, tokens);

      return true;
  }

  // Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
  function approve(address spender, uint256 tokens) public returns (bool success){
      allowed[msg.sender][spender] = tokens;
      emit Approval(msg.sender, spender, tokens);
      return true;
  }

  // Function to check the amount of tokens that an owner allowed to a spender.
  function allowance(address tokenOwner, address spender) public view returns (uint256 remaining){
      return allowed[tokenOwner][spender];
  }

  // Increase the amount of tokens that an owner allowed to a spender.
  // approve should be called when allowed[spender] == 0.
  // To increment allowed value is better to use this function to avoid 2 calls (and wait until the first transaction is mined)
  function increaseApproval(address spender, uint256 addedValue) public returns (bool) {
    allowed[msg.sender][spender] = (allowed[msg.sender][spender].add(addedValue));
    emit Approval(msg.sender, spender, allowed[msg.sender][spender]);
    return true;
  }

  // Decrease the amount of tokens that an owner allowed to a spender.
  // approve should be called when allowed[spender] == 0.
  // To decrement allowed value is better to use this function to avoid 2 calls (and wait until the first transaction is mined)
  function decreaseApproval(address spender, uint256 subtractedValue ) public returns (bool){
    uint256 oldValue = allowed[msg.sender][spender];
    if (subtractedValue >= oldValue) {
      allowed[msg.sender][spender] = 0;
    } else {
      allowed[msg.sender][spender] = oldValue.sub(subtractedValue);
    }
    emit Approval(msg.sender, spender, allowed[msg.sender][spender]);
    return true;
  }

}

pragma solidity 0.4.24;

import "./EmalToken.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

/** @title StandardTokenVesting
  * @dev A token holder contract that can release its token balance gradually like a
  * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the owner.
  */
contract StandardTokenVesting is Ownable {
  using SafeMath for uint256;

  event Released(uint256 amount);
  event Revoked();

  // beneficiary of tokens after they are released
  address public beneficiary;

  uint256 public cliff;
  uint256 public start;
  uint256 public duration;

  bool public revocable;

  mapping (address => uint256) public released;
  mapping (address => bool) public revoked;


  /** @dev Creates a vesting contract that vests its balance of any ERC20 token to the
   * _beneficiary, gradually in a linear fashion until _start + _duration. By then all
   * of the balance will have vested.
   * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
   * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
   * @param _start the time (as Unix time) at which point vesting starts
   * @param _duration duration in seconds of the period in which the tokens will vest
   * @param _revocable whether the vesting is revocable or not
   */
  constructor(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration, bool _revocable) public {
    require(_beneficiary != address(0));
    require(_cliff <= _duration);

    beneficiary = _beneficiary;
    revocable = _revocable;
    duration = _duration;
    owner = msg.sender;
    cliff = _start.add(_cliff);
    start = _start;
  }

  /** @notice Transfers vested tokens to beneficiary.
    * @param token ERC20 token which is being vested
    */
  function release(EmalToken token) public returns (bool){
    uint256 unreleased = releasableAmount(token);
    require(unreleased > 0);
    released[token] = released[token].add(unreleased);

    token.transfer(beneficiary, unreleased);
    emit Released(unreleased);
    return true;
  }

  /** @notice Allows the owner to revoke the vesting. Tokens already vested
    * remain in the contract, the rest are returned to the owner.
    * @param token ERC20 token which is being vested
    */
  function revoke(EmalToken token) public onlyOwner returns(bool) {
    require(revocable);
    require(!revoked[token]);
    uint256 balance = token.balanceOf(this);
    uint256 unreleased = releasableAmount(token);
    uint256 refund = balance.sub(unreleased);

    revoked[token] = true;
    token.transfer(owner, refund);
    emit Revoked();

    return true;
  }

  /** @dev Calculates the amount that has already vested but hasn't been released yet.
    * @param token ERC20 token which is being vested
    */
  function releasableAmount(EmalToken token) public view returns (uint256) {
    return vestedAmount(token).sub(released[token]);
  }

  /** @dev Calculates the amount that has already vested.
    * @param token Emal token which is being vested
    */
  function vestedAmount(EmalToken token) public view returns (uint256) {
    uint256 currentBalance = token.balanceOf(this);
    uint256 totalBalance = currentBalance.add(released[token]);

    if (block.timestamp < cliff) {
      return 0;
    } else if (block.timestamp >= start.add(duration) || revoked[token]) {
      return totalBalance;
    } else {
      return totalBalance.mul(block.timestamp.sub(start)).div(duration);
    }
  }
}

pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./Ownable.sol";


contract EmalToken {
    // add function prototypes of only those used here
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool);
    
    function getBountyAmount() public view returns(uint256);
}


contract EmalBounty is Ownable {

    using SafeMath for uint256;

    // The token being sold
    EmalToken public token;

    // Bounty contract state Data structures
    enum State {
        Active,
        Closed
    }

    // contains current state of bounty contract
    State public state;

    // Bounty limit in EMAL tokens
    uint256 public bountyLimit;

    // Count of total number of EML tokens that have been currently allocated to bounty users
    uint256 public totalTokensAllocated = 0;

    // Count of allocated tokens (not issued only allocated) for each bounty user
    mapping(address => uint256) public allocatedTokens;

    // Count of allocated tokens issued to each bounty user.
    mapping(address => uint256) public amountOfAllocatedTokensGivenOut;


    /** @dev Event fired when tokens are allocated to a bounty user account
      * @param beneficiary Address that is allocated tokens
      * @param tokenCount The amount of tokens that were allocated
      */
    event TokensAllocated(address indexed beneficiary, uint256 tokenCount);
    event TokensDeallocated(address indexed beneficiary, uint256 tokenCount);

    /**
     * @dev Event fired when EML tokens are sent to a bounty user
     * @param beneficiary Address where the allocated tokens were sent
     * @param tokenCount The amount of tokens that were sent
     */
    event IssuedAllocatedTokens(address indexed beneficiary, uint256 tokenCount);



    /** @param _token Address of the token that will be rewarded for the investors
      */
    constructor(address _token) public {
        require(_token != address(0));
        owner = msg.sender;
        token = EmalToken(_token);
        state = State.Active;
        bountyLimit = token.getBountyAmount();
    }

    /* Do not accept ETH */
    function() external payable {
        revert();
    }

    function closeBounty() public onlyOwner returns(bool){
        require( state!=State.Closed );
        state = State.Closed;
        return true;
    }

    /** @dev Public function to check if bounty isActive or not
      * @return True if Bounty event has ended
      */
    function isBountyActive() public view returns(bool) {
        if (state==State.Active && totalTokensAllocated<bountyLimit){
            return true;
        } else {
            return false;
        }
    }

    /** @dev Allocates tokens to a bounty user
      * @param beneficiary The address of the bounty user
      * @param tokenCount The number of tokens to be allocated to this address
      */
    function allocateTokens(address beneficiary, uint256 tokenCount) public onlyOwner returns(bool success) {
        require(beneficiary != address(0));
        require(validAllocation(tokenCount));

        uint256 tokens = tokenCount;

        /* Allocate only the remaining tokens if final contribution exceeds hard cap */
        if (totalTokensAllocated.add(tokens) > bountyLimit) {
            tokens = bountyLimit.sub(totalTokensAllocated);
        }

        /* Update state and balances */
        allocatedTokens[beneficiary] = allocatedTokens[beneficiary].add(tokens);
        totalTokensAllocated = totalTokensAllocated.add(tokens);
        emit TokensAllocated(beneficiary, tokens);

        return true;
    }

    function validAllocation( uint256 tokenCount ) internal view returns(bool) {
        bool isActive = state==State.Active;
        bool positiveAllocation = tokenCount>0;
        bool bountyLimitNotReached = totalTokensAllocated<bountyLimit;
        return isActive && positiveAllocation && bountyLimitNotReached;
    }

    /** @dev Remove tokens from a bounty user's allocation.
      * @dev Used in game based bounty allocation, automatically called from the Sails app
      * @param beneficiary The address of the bounty user
      * @param tokenCount The number of tokens to be deallocated to this address
      */
    function deductAllocatedTokens(address beneficiary, uint256 tokenCount) public onlyOwner returns(bool success) {
        require(beneficiary != address(0));
        require(tokenCount>0 && tokenCount<=allocatedTokens[beneficiary]);

        allocatedTokens[beneficiary] = allocatedTokens[beneficiary].sub(tokenCount);
        totalTokensAllocated = totalTokensAllocated.sub(tokenCount);
        emit TokensDeallocated(beneficiary, tokenCount);

        return true;
    }

    /** @dev Getter function to check the amount of allocated tokens
      * @param beneficiary address of the investor or the bounty user
      */
    function getAllocatedTokens(address beneficiary) public view returns(uint256 tokenCount) {
        require(beneficiary != address(0));
        return allocatedTokens[beneficiary];
    }

    /** @dev Bounty users will be issued EML Tokens by the sails api,
      * @dev after the Bounty has ended to their address
      * @param beneficiary address of the bounty user
      */
    function issueTokensToAllocatedUsers(address beneficiary) public onlyOwner returns(bool success) {
        require(beneficiary!=address(0));
        require(allocatedTokens[beneficiary]>0);

        uint256 tokensToSend = allocatedTokens[beneficiary];
        allocatedTokens[beneficiary] = 0;
        amountOfAllocatedTokensGivenOut[beneficiary] = amountOfAllocatedTokensGivenOut[beneficiary].add(tokensToSend);
        assert(token.transferFrom(owner, beneficiary, tokensToSend));

        emit IssuedAllocatedTokens(beneficiary, tokensToSend);
        return true;
    }
}

pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./Pausable.sol";

contract EmalToken {
    // add function prototypes of only those used here
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool);
    function getCrowdsaleAmount() public view returns(uint256);
    function setStartTimeForTokenTransfers(uint256 _startTime) external;
}

contract EmalWhitelist {
    // add function prototypes of only those used here
    function isWhitelisted(address investorAddr) public view returns(bool whitelisted);
}


contract EmalCrowdsale is Ownable, Pausable {

    using SafeMath for uint256;

    // Start and end timestamps
    uint256 public startTime;
    uint256 public endTime;

    // The token being sold
    EmalToken public token;

    // Whitelist contract used to store whitelisted addresses
    EmalWhitelist public list;

    // Address where funds are collected
    address public multisigWallet;

    // Switched to true once token contract is notified of when to enable token transfers
    bool private isStartTimeSetForTokenTransfers = false;

    // Hard cap in EMAL tokens
    uint256 public hardCap;

    // Soft cap in EMAL tokens
    uint256 constant public soft_cap = 50000000 * (10 ** 18);

    // Amount of tokens that were sold to ether investors plus tokens allocated to investors for fiat and btc investments.
    uint256 public totalTokensSoldandAllocated = 0;



    // Investor contributions made in ether
    mapping(address => uint256) public etherInvestments;

    // Tokens given to investors who sent ether investments
    mapping(address => uint256) public tokensSoldForEther;

    // Total ether raised by the Crowdsale
    uint256 public totalEtherRaisedByCrowdsale = 0;

    // Total number of tokens sold to investors who made payments in ether
    uint256 public totalTokensSoldByEtherInvestments = 0;

    // Count of allocated tokens  for each investor or bounty user
    mapping(address => uint256) public allocatedTokens;

    // Count of total number of EML tokens that have been currently allocated to Crowdsale investors
    uint256 public totalTokensAllocated = 0;



   /** @dev Event for EML token purchase using ether
     * @param investorAddr Address that paid and got the tokens
     * @param paidAmount The amount that was paid (in wei)
     * @param tokenCount The amount of tokens that were bought
     */
    event TokenPurchasedUsingEther(address indexed investorAddr, uint256 paidAmount, uint256 tokenCount);

    /**
     * @dev Event for refund logging
     * @param receiver The address that received the refund
     * @param amount The amount that is being refunded (in wei)
     */
    event Refund(address indexed receiver, uint256 amount);

    /** @dev Event fired when EML tokens are allocated to an investor account
      * @param beneficiary Address that is allocated tokens
      * @param tokenCount The amount of tokens that were allocated
      */
    event TokensAllocated(address indexed beneficiary, uint256 tokenCount);
    event TokensDeallocated(address indexed beneficiary, uint256 tokenCount);


    /** @dev variables and functions which determine conversion rate from ETH to EML
      * based on bonuses and current timestamp.
      */
    uint256 priceOfEthInUSD = 450;
    uint256 bonusPercent1 = 25;
    uint256 bonusPercent2 = 15;
    uint256 bonusPercent3 = 0;
    uint256 priceOfEMLTokenInUSDPenny = 60;
    uint256 overridenBonusValue = 0;

    function setExchangeRate(uint256 overridenValue) public onlyOwner returns(bool) {
        require( overridenValue > 0 );
        require( overridenValue != priceOfEthInUSD);
        priceOfEthInUSD = overridenValue;
        return true;
    }

    function getExchangeRate() public view returns(uint256){
        return priceOfEthInUSD;
    }

    function setOverrideBonus(uint256 overridenValue) public onlyOwner returns(bool) {
        require( overridenValue > 0 );
        require( overridenValue != overridenBonusValue);
        overridenBonusValue = overridenValue;
        return true;
    }

    /**
     * @dev public function that is used to determine the current rate for token / ETH conversion
     * @dev there exists a case where rate cant be set to 0, which is fine.
     * @return The current token rate
     */
    function getRate() public view returns(uint256) {
        require( priceOfEMLTokenInUSDPenny !=0 );
        require( priceOfEthInUSD !=0 );
        uint256 rate;

        if(overridenBonusValue > 0){
            rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(overridenBonusValue.add(100)).div(100);
        } else {
            if (now <= (startTime + 1 days)) {
                rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(bonusPercent1.add(100)).div(100);
            } if (now > (startTime + 1 days) && now <= (startTime + 2 days)) {
                rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(bonusPercent2.add(100)).div(100);
            } else {
                rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(bonusPercent3.add(100)).div(100);
            }
        }
        return rate;
    }


    /** @dev Initialise the Crowdsale contract.
      * (can be removed for testing) _startTime Unix timestamp for the start of the token sale
      * (can be removed for testing) _endTime Unix timestamp for the end of the token sale
      * @param _multisigWallet Ethereum address to which the invested funds are forwarded
      * @param _token Address of the token that will be rewarded for the investors
      * @param _list contains a list of investors who completed KYC procedures.
      */
    constructor(uint256 _startTime, uint256 _endTime, address _multisigWallet, address _token, address _list) public {
        require(_startTime >= now);
        require(_endTime >= _startTime);
        require(_multisigWallet != address(0));
        require(_token != address(0));
        require(_list != address(0));

        startTime = _startTime;
        endTime = _endTime;
        multisigWallet = _multisigWallet;
        owner = msg.sender;
        token = EmalToken(_token);
        list = EmalWhitelist(_list);
        hardCap = token.getCrowdsaleAmount();
    }

    /** @dev Fallback function that can be used to buy EML tokens. Or in
      * case of the owner, return ether to allow refunds in case crowdsale
      * ended or paused and didnt reach soft_cap.
      */
    function() external payable {
        if (msg.sender == multisigWallet) {
            require( (!isCrowdsaleActive()) && totalTokensSoldandAllocated<soft_cap);
        } else {
            if (list.isWhitelisted(msg.sender)) {
                buyTokensUsingEther(msg.sender);
            } else {
                revert();
            }
        }
    }

    /** @dev Function for buying EML tokens using ether
      * @param _investorAddr The address that should receive bought tokens
      */
    function buyTokensUsingEther(address _investorAddr) internal whenNotPaused {
        require(_investorAddr != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;
        uint256 returnToSender = 0;

        // final rate after including rate value and bonus amount.
        uint256 finalConversionRate = getRate();

        // Calculate EML token amount to be transferred
        uint256 tokens = weiAmount.mul(finalConversionRate);

        // Distribute only the remaining tokens if final contribution exceeds hard cap
        if (totalTokensSoldandAllocated.add(tokens) > hardCap) {
            tokens = hardCap.sub(totalTokensSoldandAllocated);
            weiAmount = tokens.div(finalConversionRate);
            returnToSender = msg.value.sub(weiAmount);
        }

        // update state and balances
        etherInvestments[_investorAddr] = etherInvestments[_investorAddr].add(weiAmount);
        tokensSoldForEther[_investorAddr] = tokensSoldForEther[_investorAddr].add(tokens);
        totalTokensSoldByEtherInvestments = totalTokensSoldByEtherInvestments.add(tokens);
        totalEtherRaisedByCrowdsale = totalEtherRaisedByCrowdsale.add(weiAmount);
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.add(tokens);


        // assert implies it should never fail
        assert(token.transferFrom(owner, _investorAddr, tokens));
        emit TokenPurchasedUsingEther(_investorAddr, weiAmount, tokens);

        // Forward funds
        multisigWallet.transfer(weiAmount);

        // Update token contract.
        _postValidationUpdateTokenContract();

        // Return funds that are over hard cap
        if (returnToSender > 0) {
            msg.sender.transfer(returnToSender);
        }
    }

    function _postValidationUpdateTokenContract() internal {
       /** @dev If hard cap is reachde allow token transfers after two weeks
         * @dev Allow users to transfer tokens only after hardCap is reached
         * @dev Notiy token contract about startTime to start transfers
         */
        if (totalTokensSoldandAllocated == hardCap) {
            token.setStartTimeForTokenTransfers(now + 2 weeks);
        }

       /** @dev If its the first token sold or allocated then set s, allow after 2 weeks
         * @dev Allow users to transfer tokens only after ICO crowdsale ends.
         * @dev Notify token contract about sale end time
         */
        if (!isStartTimeSetForTokenTransfers) {
            isStartTimeSetForTokenTransfers = true;
            token.setStartTimeForTokenTransfers(endTime + 2 weeks);
        }
    }

    /** @dev Internal function that is used to check if the incoming purchase should be accepted.
      * @return True if the transaction can buy tokens
      */
    function validPurchase() internal view returns(bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool minimumPurchase = msg.value >= 1*(10**18);
        bool hardCapNotReached = totalTokensSoldandAllocated < hardCap;
        return withinPeriod && hardCapNotReached && minimumPurchase;
    }

    /** @dev Public function to check if Crowdsale isActive or not
      * @return True if Crowdsale event has ended
      */
    function isCrowdsaleActive() public view returns(bool) {
        if (!paused && now>startTime && now<endTime && totalTokensSoldandAllocated<=hardCap){
            return true;
        } else {
            return false;
        }
    }

    /** @dev Gets the balance of the specified address.
      * @param _owner The address to query the the balance of.
      * @return An uint256 representing the amount owned by the passed address.
      */
    function balanceOfEtherInvestor(address _owner) external view returns(uint256 balance) {
        require(_owner != address(0));
        return etherInvestments[_owner];
    }

    function getTokensSoldToEtherInvestor(address _owner) public view returns(uint256 balance) {
        require(_owner != address(0));
        return tokensSoldForEther[_owner];
    }

    /** @dev Returns ether to token holders in case soft cap is not reached.
      */
    function claimRefund() public whenNotPaused onlyOwner {
        require(now>endTime);
        require(totalTokensSoldandAllocated<soft_cap);
        uint256 amount = etherInvestments[msg.sender];

        if (address(this).balance >= amount) {
            etherInvestments[msg.sender] = 0;
            if (amount > 0) {
                msg.sender.transfer(amount);
                emit Refund(msg.sender, amount);
            }
        }
      }




    /** @dev BELOW ARE FUNCTIONS THAT HANDLE INVESTMENTS IN FIAT AND BTC.
      * functions are automatically called by ICO Sails.js app.
      */


    /** @dev Allocates EML tokens to an investor address called automatically
      * after receiving fiat or btc investments from KYC whitelisted investors.
      * @param beneficiary The address of the investor
      * @param tokenCount The number of tokens to be allocated to this address
      */
    function allocateTokens(address beneficiary, uint256 tokenCount) public onlyOwner returns(bool success) {
        require(beneficiary != address(0));
        require(validAllocation(tokenCount));

        uint256 tokens = tokenCount;

        /* Allocate only the remaining tokens if final contribution exceeds hard cap */
        if (totalTokensSoldandAllocated.add(tokens) > hardCap) {
            tokens = hardCap.sub(totalTokensSoldandAllocated);
        }

        /* Update state and balances */
        allocatedTokens[beneficiary] = allocatedTokens[beneficiary].add(tokens);
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.add(tokens);
        totalTokensAllocated = totalTokensAllocated.add(tokens);

        // assert implies it should never fail
        assert(token.transferFrom(owner, beneficiary, tokens));
        emit TokensAllocated(beneficiary, tokens);

        /* Update token contract. */
        _postValidationUpdateTokenContract();
        return true;
    }

    function validAllocation( uint256 tokenCount ) internal view returns(bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool positiveAllocation = tokenCount > 0;
        bool hardCapNotReached = totalTokensSoldandAllocated < hardCap;
        return withinPeriod && positiveAllocation && hardCapNotReached;
    }


    /** @dev Getter function to check the amount of allocated tokens
      * @param beneficiary address of the investor
      */
    function getAllocatedTokens(address beneficiary) public view returns(uint256 tokenCount) {
        require(beneficiary != address(0));
        return allocatedTokens[beneficiary];
    }

    function getSoldandAllocatedTokens(address _addr) public view returns (uint256) {
        require(_addr != address(0));
        uint256 totalTokenCount = getAllocatedTokens(_addr).add(getTokensSoldToEtherInvestor(_addr));
        return totalTokenCount;
    }

}

pragma solidity 0.4.24;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./Pausable.sol";

contract EmalToken {
    // add function prototypes of only those used here
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool);
    function getPresaleAmount() public view returns(uint256);
}

contract EmalWhitelist {
    // add function prototypes of only those used here
    function isWhitelisted(address investorAddr) public view returns(bool whitelisted);
}


contract EmalPresale is Ownable, Pausable {

    using SafeMath for uint256;

    // Start and end timestamps
    uint256 public startTime;
    uint256 public endTime;

    // The token being sold
    EmalToken public token;

    // Whitelist contract used to store whitelisted addresses
    EmalWhitelist public list;

    // Address where funds are collected
    address public multisigWallet;

    // Hard cap in EMAL tokens
    uint256 public hardCap;

    // Amount of tokens that were sold to ether investors plus tokens allocated to investors for fiat and btc investments.
    uint256 public totalTokensSoldandAllocated = 0;



    // Investor contributions made in ether
    mapping(address => uint256) public etherInvestments;

    // Tokens given to investors who sent ether investments
    mapping(address => uint256) public tokensSoldForEther;

    // Total ether raised by the Presale
    uint256 public totalEtherRaisedByPresale = 0;

    // Total number of tokens sold to investors who made payments in ether
    uint256 public totalTokensSoldByEtherInvestments = 0;

    // Count of allocated tokens  for each investor or bounty user
    mapping(address => uint256) public allocatedTokens;

    // Count of total number of EML tokens that have been currently allocated to Presale investors
    uint256 public totalTokensAllocated = 0;



   /** @dev Event for EML token purchase using ether
     * @param investorAddr Address that paid and got the tokens
     * @param paidAmount The amount that was paid (in wei)
     * @param tokenCount The amount of tokens that were bought
     */
    event TokenPurchasedUsingEther(address indexed investorAddr, uint256 paidAmount, uint256 tokenCount);

    /** @dev Event fired when EML tokens are allocated to an investor account
      * @param beneficiary Address that is allocated tokens
      * @param tokenCount The amount of tokens that were allocated
      */
    event TokensAllocated(address indexed beneficiary, uint256 tokenCount);
    event TokensDeallocated(address indexed beneficiary, uint256 tokenCount);


    /** @dev variables and functions which determine conversion rate from ETH to EML
      * based on bonuses and current timestamp.
      */
    uint256 priceOfEthInUSD = 450;
    uint256 bonusPercent1 = 35;
    uint256 priceOfEMLTokenInUSDPenny = 60;
    uint256 overridenBonusValue = 0;

    function setExchangeRate(uint256 overridenValue) public onlyOwner returns(bool) {
        require( overridenValue > 0 );
        require( overridenValue != priceOfEthInUSD);
        priceOfEthInUSD = overridenValue;
        return true;
    }

    function getExchangeRate() public view returns(uint256){
        return priceOfEthInUSD;
    }

    function setOverrideBonus(uint256 overridenValue) public onlyOwner returns(bool) {
        require( overridenValue > 0 );
        require( overridenValue != overridenBonusValue);
        overridenBonusValue = overridenValue;
        return true;
    }

    /** @dev public function that is used to determine the current rate for ETH to EML conversion
      * @return The current token rate
      */
    function getRate() public view returns(uint256) {
        require(priceOfEMLTokenInUSDPenny > 0 );
        require(priceOfEthInUSD > 0 );
        uint256 rate;

        if(overridenBonusValue > 0){
            rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(overridenBonusValue.add(100)).div(100);
        } else {
            rate = priceOfEthInUSD.mul(100).div(priceOfEMLTokenInUSDPenny).mul(bonusPercent1.add(100)).div(100);
        }
        return rate;
    }


    /** @dev Initialise the Presale contract.
      * (can be removed for testing) _startTime Unix timestamp for the start of the token sale
      * (can be removed for testing) _endTime Unix timestamp for the end of the token sale
      * @param _multisigWallet Ethereum address to which the invested funds are forwarded
      * @param _token Address of the token that will be rewarded for the investors
      * @param _list contains a list of investors who completed KYC procedures.
      */
    constructor(uint256 _startTime, uint256 _endTime, address _multisigWallet, address _token, address _list) public {
        require(_startTime >= now);
        require(_endTime >= _startTime);
        require(_multisigWallet != address(0));
        require(_token != address(0));
        require(_list != address(0));

        startTime = _startTime;
        endTime = _endTime;
        multisigWallet = _multisigWallet;
        owner = msg.sender;
        token = EmalToken(_token);
        list = EmalWhitelist(_list);
        hardCap = token.getPresaleAmount();
    }

    /** @dev Fallback function that can be used to buy tokens.
      */
    function() external payable {
        if (list.isWhitelisted(msg.sender)) {
            buyTokensUsingEther(msg.sender);
        } else {
            /* Do not accept ETH */
            revert();
        }
    }

    /** @dev Function for buying EML tokens using ether
      * @param _investorAddr The address that should receive bought tokens
      */
    function buyTokensUsingEther(address _investorAddr) internal whenNotPaused {
        require(_investorAddr != address(0));
        require(validPurchase());

        uint256 weiAmount = msg.value;
        uint256 returnToSender = 0;

        // final rate after including rate value and bonus amount.
        uint256 finalConversionRate = getRate();

        // Calculate EML token amount to be transferred
        uint256 tokens = weiAmount.mul(finalConversionRate);

        // Distribute only the remaining tokens if final contribution exceeds hard cap
        if (totalTokensSoldandAllocated.add(tokens) > hardCap) {
            tokens = hardCap.sub(totalTokensSoldandAllocated);
            weiAmount = tokens.div(finalConversionRate);
            returnToSender = msg.value.sub(weiAmount);
        }

        // update state and balances
        etherInvestments[_investorAddr] = etherInvestments[_investorAddr].add(weiAmount);
        tokensSoldForEther[_investorAddr] = tokensSoldForEther[_investorAddr].add(tokens);
        totalTokensSoldByEtherInvestments = totalTokensSoldByEtherInvestments.add(tokens);
        totalEtherRaisedByPresale = totalEtherRaisedByPresale.add(weiAmount);
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.add(tokens);


        // assert implies it should never fail
        assert(token.transferFrom(owner, _investorAddr, tokens));
        emit TokenPurchasedUsingEther(_investorAddr, weiAmount, tokens);

        // Forward funds
        multisigWallet.transfer(weiAmount);

        // Return funds that are over hard cap
        if (returnToSender > 0) {
            msg.sender.transfer(returnToSender);
        }
    }

    /**
     * @dev Internal function that is used to check if the incoming purchase should be accepted.
     * @return True if the transaction can buy tokens
     */
    function validPurchase() internal view returns(bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool minimumPurchase = msg.value >= 1*(10**18);
        bool hardCapNotReached = totalTokensSoldandAllocated < hardCap;
        return withinPeriod && hardCapNotReached && minimumPurchase;
    }

    /** @dev Public function to check if Presale isActive or not
      * @return True if Presale event has ended
      */
    function isPresaleActive() public view returns(bool) {
        if (!paused && now>startTime && now<endTime && totalTokensSoldandAllocated<=hardCap){
            return true;
        } else {
            return false;
        }
    }

    /** @dev Gets the balance of the specified address.
      * @param _owner The address to query the the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOfEtherInvestor(address _owner) external view returns(uint256 balance) {
        require(_owner != address(0));
        return etherInvestments[_owner];
    }

    function getTokensSoldToEtherInvestor(address _owner) public view returns(uint256 balance) {
        require(_owner != address(0));
        return tokensSoldForEther[_owner];
    }




    /** @dev BELOW ARE FUNCTIONS THAT HANDLE INVESTMENTS IN FIAT AND BTC.
      * functions are automatically called by ICO Sails.js app.
      */


    /** @dev Allocates EML tokens to an investor address called automatically
      * after receiving fiat or btc investments from KYC whitelisted investors.
      * @param beneficiary The address of the investor
      * @param tokenCount The number of tokens to be allocated to this address
      */
    function allocateTokens(address beneficiary, uint256 tokenCount) public onlyOwner returns(bool success) {
        require(beneficiary != address(0));
        require(validAllocation(tokenCount));

        uint256 tokens = tokenCount;

        /* Allocate only the remaining tokens if final contribution exceeds hard cap */
        if (totalTokensSoldandAllocated.add(tokens) > hardCap) {
            tokens = hardCap.sub(totalTokensSoldandAllocated);
        }

        /* Update state and balances */
        allocatedTokens[beneficiary] = allocatedTokens[beneficiary].add(tokens);
        totalTokensSoldandAllocated = totalTokensSoldandAllocated.add(tokens);
        totalTokensAllocated = totalTokensAllocated.add(tokens);

        // assert implies it should never fail
        assert(token.transferFrom(owner, beneficiary, tokens));
        emit TokensAllocated(beneficiary, tokens);

        return true;
    }

    function validAllocation( uint256 tokenCount ) internal view returns(bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool positiveAllocation = tokenCount > 0;
        bool hardCapNotReached = totalTokensSoldandAllocated < hardCap;
        return withinPeriod && positiveAllocation && hardCapNotReached;
    }


    /** @dev Getter function to check the amount of allocated tokens
      * @param beneficiary address of the investor
      */
    function getAllocatedTokens(address beneficiary) public view returns(uint256 tokenCount) {
        require(beneficiary != address(0));
        return allocatedTokens[beneficiary];
    }

    function getSoldandAllocatedTokens(address _addr) public view returns (uint256) {
        require(_addr != address(0));
        uint256 totalTokenCount = getAllocatedTokens(_addr).add(getTokensSoldToEtherInvestor(_addr));
        return totalTokenCount;
    }

}

pragma solidity 0.4.24;

import "./SafeMath.sol";
import './StandardToken.sol';
import './Ownable.sol';

contract EmalToken is StandardToken, Ownable {

    using SafeMath for uint256;

    string public constant symbol = "EML";
    string public constant name = "e-Mal Token";
    uint8 public constant decimals = 18;

    // Total Number of tokens ever goint to be minted. 1 BILLION EML tokens.
    uint256 private constant minting_capped_amount = 1000000000 * 10 ** uint256(decimals);

    // 24% of initial supply
    uint256 constant presale_amount = 120000000 * 10 ** uint256(decimals);
    // 60% of inital supply
    uint256 constant crowdsale_amount = 300000000 * 10 ** uint256(decimals);
    // 8% of inital supply.
    uint256  constant vesting_amount = 40000000 * 10 ** uint256(decimals);
    // 8% of inital supply.
    uint256 constant bounty_amount = 40000000 * 10 ** uint256(decimals);
    
    uint256 private initialSupply = minting_capped_amount;

    address public presaleAddress;
    address public crowdsaleAddress;
    address public vestingAddress;
    address public bountyAddress;



    /** @dev Defines the start time after which transferring of EML tokens
      * will be allowed done so as to prevent early buyers from clearing out
      * of their EML balance during the presale and publicsale.
      */
    uint256 public startTimeForTransfers;

    /** @dev to cap the total number of tokens that will ever be newly minted
      * owner has to stop the minting by setting this variable to true.
      */
    bool public mintingFinished = false;

    /** @dev Miniting Essentials functions as per OpenZeppelin standards
      */
    modifier canMint() {
      require(!mintingFinished);
      _;
    }
    modifier hasMintPermission() {
      require(msg.sender == owner);
      _;
    }

    /** @dev to prevent malicious use of EML tokens and to comply with Anti
      * Money laundering regulations EML tokens can be frozen.
      */
    mapping (address => bool) public frozenAccount;

    /** @dev This generates a public event on the blockchain that will notify clients
      */
    event FrozenFunds(address target, bool frozen);
    event Mint(address indexed to, uint256 amount);
    event MintFinished();
    event Burn(address indexed burner, uint256 value);


    constructor() public {
        startTimeForTransfers = now - 210 days;

        _totalSupply = initialSupply;
        owner = msg.sender;
        balances[owner] = _totalSupply;
        emit Transfer(address(0), owner, balances[owner]);
    }

    /* Do not accept ETH */
    function() public payable {
        revert();
    }


    /** @dev Basic setters and getters to allocate tokens for vesting factory, presale
      * crowdsale and bounty this is done so that no need of actually transferring EML
      * tokens to sale contracts and hence preventing EML tokens from the risk of being
      * locked out in future inside the subcontracts.
      */
    function setPresaleAddress(address _presaleAddress) external onlyOwner {
        presaleAddress = _presaleAddress;
        assert(approve(presaleAddress, presale_amount));
    }
    function setCrowdsaleAddress(address _crowdsaleAddress) external onlyOwner {
        crowdsaleAddress = _crowdsaleAddress;
        assert(approve(crowdsaleAddress, crowdsale_amount));
    }
    function setVestingAddress(address _vestingAddress) external onlyOwner {
        vestingAddress = _vestingAddress;
        assert(approve(vestingAddress, vesting_amount));
    }
    function setBountyAddress(address _bountyAddress) external onlyOwner {
        bountyAddress = _bountyAddress;
        assert(approve(bountyAddress, bounty_amount));
    }
    


    function getPresaleAmount()  internal pure returns(uint256) {
        return presale_amount;
    }
    function getCrowdsaleAmount() internal pure  returns(uint256) {
        return crowdsale_amount;
    }
    function getVestingAmount() internal pure  returns(uint256) {
        return vesting_amount;
    }
    function getBountyAmount() internal pure  returns(uint256) {
        return bounty_amount;
    }

    /** @dev Sets the start time after which transferring of EML tokens
      * will be allowed done so as to prevent early buyers from clearing out
      * of their EML balance during the presale and publicsale.
      */
    function setStartTimeForTokenTransfers(uint256 _startTimeForTransfers) external {
        require(msg.sender == crowdsaleAddress);
        if (_startTimeForTransfers < startTimeForTransfers) {
            startTimeForTransfers = _startTimeForTransfers;
        }
    }


    /** @dev Transfer possible only after ICO ends and Frozen accounts
      * wont be able to transfer funds to other any other account and viz.
      * @notice added safeTransfer functionality
      */
    function transfer(address _to, uint256 _value) public returns(bool) {
        require(now >= startTimeForTransfers);
        require(!frozenAccount[msg.sender]);
        require(!frozenAccount[_to]);

        require(super.transfer(_to, _value));
        return true;
    }

    /** @dev Only owner's tokens can be transferred before Crowdsale ends.
      * beacuse the inital supply of EML is allocated to owners acc and later
      * distributed to various subcontracts.
      * @notice added safeTransferFrom functionality
      */
    function transferFrom(address _from, address _to, uint256 _value) public returns(bool) {
        require(!frozenAccount[_from]);
        require(!frozenAccount[_to]);
        require(!frozenAccount[msg.sender]);

        if (now < startTimeForTransfers) {
            require(_from == owner);
        }

        require(super.transferFrom(_from, _to, _value));
        return true;
    }

    /** @notice added safeApprove functionality
      */
    function approve(address spender, uint256 tokens) public returns (bool){
        require(super.approve(spender, tokens));
        return true;
    }

   /** @notice `freeze? Prevent | Allow` `target` from sending & receiving tokens
     * @param target Address to be frozen
     * @param freeze either to freeze it or not
     */
    function freezeAccount(address target, bool freeze) public onlyOwner {
        require(frozenAccount[target] != freeze);

        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }


    /** @dev Function to mint tokens
      * @param _to The address that will receive the minted tokens.
      * @param _amount The amount of tokens to mint.
      * @return A boolean that indicates if the operation was successful.
      */
    function mint(address _to, uint256 _amount) public hasMintPermission canMint returns (bool) {
      require(_totalSupply.add(_amount) <= minting_capped_amount);

      _totalSupply = _totalSupply.add(_amount);
      balances[_to] = balances[_to].add(_amount);
      emit Mint(_to, _amount);
      emit Transfer(address(0), _to, _amount);
      return true;
    }

   /** @dev Function to stop minting new tokens.
     * @return True if the operation was successful.
     */
    function finishMinting() public onlyOwner canMint returns (bool) {
      mintingFinished = true;
      emit MintFinished();
      return true;
    }

    /** @dev Burns a specific amount of tokens.
      * @param _value The amount of token to be burned.
      */
     function burn(uint256 _value) public {
       _burn(msg.sender, _value);
     }

     function _burn(address _who, uint256 _value) internal {
       require(_value <= balances[_who]);
       // no need to require value <= totalSupply, since that would imply the
       // sender's balance is greater than the totalSupply, which *should* be an assertion failure

       balances[_who] = balances[_who].sub(_value);
       _totalSupply = _totalSupply.sub(_value);
       emit Burn(_who, _value);
       emit Transfer(_who, address(0), _value);
     }
}

pragma solidity 0.4.24;

import "./EmalToken.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

/** @title StandardTokenVesting
  * @dev A token holder contract that can release its token balance gradually like a
  * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the owner.
  */
contract StandardTokenVesting is Ownable {
  using SafeMath for uint256;

  event Released(uint256 amount);
  event Revoked();

  // beneficiary of tokens after they are released
  address public beneficiary;

  uint256 public cliff;
  uint256 public start;
  uint256 public duration;

  bool public revocable;

  mapping (address => uint256) public released;
  mapping (address => bool) public revoked;


  /** @dev Creates a vesting contract that vests its balance of any ERC20 token to the
   * _beneficiary, gradually in a linear fashion until _start + _duration. By then all
   * of the balance will have vested.
   * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
   * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
   * @param _start the time (as Unix time) at which point vesting starts
   * @param _duration duration in seconds of the period in which the tokens will vest
   * @param _revocable whether the vesting is revocable or not
   */
  constructor(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration, bool _revocable) public {
    require(_beneficiary != address(0));
    require(_cliff <= _duration);

    beneficiary = _beneficiary;
    revocable = _revocable;
    duration = _duration;
    owner = msg.sender;
    cliff = _start.add(_cliff);
    start = _start;
  }

  /** @notice Transfers vested tokens to beneficiary.
    * @param token ERC20 token which is being vested
    */
  function release(EmalToken token) public returns (bool){
    uint256 unreleased = releasableAmount(token);
    require(unreleased > 0);
    released[token] = released[token].add(unreleased);

    token.transfer(beneficiary, unreleased);
    emit Released(unreleased);
    return true;
  }

  /** @notice Allows the owner to revoke the vesting. Tokens already vested
    * remain in the contract, the rest are returned to the owner.
    * @param token ERC20 token which is being vested
    */
  function revoke(EmalToken token) public onlyOwner returns(bool) {
    require(revocable);
    require(!revoked[token]);
    uint256 balance = token.balanceOf(this);
    uint256 unreleased = releasableAmount(token);
    uint256 refund = balance.sub(unreleased);

    revoked[token] = true;
    token.transfer(owner, refund);
    emit Revoked();

    return true;
  }

  /** @dev Calculates the amount that has already vested but hasn't been released yet.
    * @param token ERC20 token which is being vested
    */
  function releasableAmount(EmalToken token) public view returns (uint256) {
    return vestedAmount(token).sub(released[token]);
  }

  /** @dev Calculates the amount that has already vested.
    * @param token Emal token which is being vested
    */
  function vestedAmount(EmalToken token) public view returns (uint256) {
    uint256 currentBalance = token.balanceOf(this);
    uint256 totalBalance = currentBalance.add(released[token]);

    if (block.timestamp < cliff) {
      return 0;
    } else if (block.timestamp >= start.add(duration) || revoked[token]) {
      return totalBalance;
    } else {
      return totalBalance.mul(block.timestamp.sub(start)).div(duration);
    }
  }
}

pragma solidity 0.4.24;

import './Ownable.sol';

/** @notice This contract provides support for whitelisting addresses.
 * only whitelisted addresses are allowed to send ether and buy tokens
 * during preSale and Pulic crowdsale.
 * @dev after deploying contract, deploy Presale / Crowdsale contract using
 * EmalWhitelist address. To allow claim refund functionality and allow wallet
 * owner efatoora to send ether to Crowdsale contract for refunds add wallet
 * address to whitelist.
 */
contract EmalWhitelist is Ownable {

    mapping(address => bool) whitelist;

    event AddToWhitelist(address investorAddr);
    event RemoveFromWhitelist(address investorAddr);


    /** @dev Throws if operator is not whitelisted.
     */
    modifier onlyIfWhitelisted(address investorAddr) {
        require(whitelist[investorAddr]);
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    /** @dev Returns if an address is whitelisted or not
     */
    function isWhitelisted(address investorAddr) public view returns(bool whitelisted) {
        return whitelist[investorAddr];
    }

    /**
     * @dev Adds an investor to whitelist
     * @param investorAddr The address to user to be added to the whitelist, signifies that the user completed KYC requirements.
     */
    function addToWhitelist(address investorAddr) public onlyOwner returns(bool success) {
        require(investorAddr!= address(0));
        whitelist[investorAddr] = true;
        return true;
    }

    /**
     * @dev Removes an investor's address from whitelist
     * @param investorAddr The address to user to be added to the whitelist, signifies that the user completed KYC requirements.
     */
    function removeFromWhitelist(address investorAddr) public onlyOwner returns(bool success) {
        require(investorAddr!= address(0));
        whitelist[investorAddr] = false;
        return true;
    }


}

pragma solidity 0.4.24;

contract ERC20Token {
  function totalSupply() public constant returns (uint);
  function balanceOf(address tokenOwner) public constant returns (uint balance);
  function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
  function transfer(address to, uint256 tokens) public returns (bool success);
  function approve(address spender, uint256 tokens) public returns (bool success);
  function transferFrom(address from, address to, uint256 tokens) public returns (bool success);

  event Transfer(address indexed from, address indexed to, uint tokens);
  event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

pragma solidity 0.4.24;

contract Ownable {

    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}

pragma solidity 0.4.24;

import "./Ownable.sol";

/* Pausable contract */
contract Pausable is Ownable {

    event Pause();
    event Unpause();

    bool public paused = false;

    /** @dev Modifier to make a function callable only when the contract is not paused.
      */
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    /** @dev Modifier to make a function callable only when the contract is paused.
      */
    modifier whenPaused() {
        require(paused);
        _;
    }

    /** @dev called by the owner to pause, triggers stopped state
      */
    function pause() onlyOwner whenNotPaused public {
        paused = true;
        emit Pause();
    }

    /** @dev called by the owner to unpause, returns to normal state
      */
    function unpause() onlyOwner whenPaused public {
        paused = false;
        emit Unpause();
    }

}

pragma solidity 0.4.24;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

pragma solidity 0.4.24;

import './ERC20Token.sol';
import './SafeMath.sol';

contract StandardToken is ERC20Token {

  using SafeMath for uint256;

  // Global variable to store total number of tokens passed from EmalToken.sol
  uint256 _totalSupply;

  mapping(address => uint256) balances;
  mapping(address => mapping(address => uint256)) allowed;


  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address tokenOwner) public view returns (uint256){
        return balances[tokenOwner];
  }



  function transfer(address to, uint256 tokens) public returns (bool){
      require(to != address(0));
      require(tokens > 0 && tokens <= balances[msg.sender]);

      balances[msg.sender] = balances[msg.sender].sub(tokens);
      balances[to] = balances[to].add(tokens);
      emit Transfer(msg.sender, to, tokens);
      return true;
  }

  // Transfer tokens from one address to another
  function transferFrom(address from, address to, uint256 tokens) public returns (bool success){
      require(to != address(0));
      require(tokens > 0 && tokens <= balances[from]);
      require(tokens <= allowed[from][msg.sender]);

      balances[from] = balances[from].sub(tokens);
      balances[to] = balances[to].add(tokens);
      allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
      emit Transfer(from, to, tokens);

      return true;
  }

  // Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
  function approve(address spender, uint256 tokens) public returns (bool success){
      allowed[msg.sender][spender] = tokens;
      emit Approval(msg.sender, spender, tokens);
      return true;
  }

  // Function to check the amount of tokens that an owner allowed to a spender.
  function allowance(address tokenOwner, address spender) public view returns (uint256 remaining){
      return allowed[tokenOwner][spender];
  }

  // Increase the amount of tokens that an owner allowed to a spender.
  // approve should be called when allowed[spender] == 0.
  // To increment allowed value is better to use this function to avoid 2 calls (and wait until the first transaction is mined)
  function increaseApproval(address spender, uint256 addedValue) public returns (bool) {
    allowed[msg.sender][spender] = (allowed[msg.sender][spender].add(addedValue));
    emit Approval(msg.sender, spender, allowed[msg.sender][spender]);
    return true;
  }

  // Decrease the amount of tokens that an owner allowed to a spender.
  // approve should be called when allowed[spender] == 0.
  // To decrement allowed value is better to use this function to avoid 2 calls (and wait until the first transaction is mined)
  function decreaseApproval(address spender, uint256 subtractedValue ) public returns (bool){
    uint256 oldValue = allowed[msg.sender][spender];
    if (subtractedValue >= oldValue) {
      allowed[msg.sender][spender] = 0;
    } else {
      allowed[msg.sender][spender] = oldValue.sub(subtractedValue);
    }
    emit Approval(msg.sender, spender, allowed[msg.sender][spender]);
    return true;
  }

}

pragma solidity 0.4.24;

import "./EmalToken.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

/** @title StandardTokenVesting
  * @dev A token holder contract that can release its token balance gradually like a
  * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the owner.
  */
contract StandardTokenVesting is Ownable {
  using SafeMath for uint256;

  event Released(uint256 amount);
  event Revoked();

  // beneficiary of tokens after they are released
  address public beneficiary;

  uint256 public cliff;
  uint256 public start;
  uint256 public duration;

  bool public revocable;

  mapping (address => uint256) public released;
  mapping (address => bool) public revoked;


  /** @dev Creates a vesting contract that vests its balance of any ERC20 token to the
   * _beneficiary, gradually in a linear fashion until _start + _duration. By then all
   * of the balance will have vested.
   * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
   * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
   * @param _start the time (as Unix time) at which point vesting starts
   * @param _duration duration in seconds of the period in which the tokens will vest
   * @param _revocable whether the vesting is revocable or not
   */
  constructor(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration, bool _revocable) public {
    require(_beneficiary != address(0));
    require(_cliff <= _duration);

    beneficiary = _beneficiary;
    revocable = _revocable;
    duration = _duration;
    owner = msg.sender;
    cliff = _start.add(_cliff);
    start = _start;
  }

  /** @notice Transfers vested tokens to beneficiary.
    * @param token ERC20 token which is being vested
    */
  function release(EmalToken token) public returns (bool){
    uint256 unreleased = releasableAmount(token);
    require(unreleased > 0);
    released[token] = released[token].add(unreleased);

    token.transfer(beneficiary, unreleased);
    emit Released(unreleased);
    return true;
  }

  /** @notice Allows the owner to revoke the vesting. Tokens already vested
    * remain in the contract, the rest are returned to the owner.
    * @param token ERC20 token which is being vested
    */
  function revoke(EmalToken token) public onlyOwner returns(bool) {
    require(revocable);
    require(!revoked[token]);
    uint256 balance = token.balanceOf(this);
    uint256 unreleased = releasableAmount(token);
    uint256 refund = balance.sub(unreleased);

    revoked[token] = true;
    token.transfer(owner, refund);
    emit Revoked();

    return true;
  }

  /** @dev Calculates the amount that has already vested but hasn't been released yet.
    * @param token ERC20 token which is being vested
    */
  function releasableAmount(EmalToken token) public view returns (uint256) {
    return vestedAmount(token).sub(released[token]);
  }

  /** @dev Calculates the amount that has already vested.
    * @param token Emal token which is being vested
    */
  function vestedAmount(EmalToken token) public view returns (uint256) {
    uint256 currentBalance = token.balanceOf(this);
    uint256 totalBalance = currentBalance.add(released[token]);

    if (block.timestamp < cliff) {
      return 0;
    } else if (block.timestamp >= start.add(duration) || revoked[token]) {
      return totalBalance;
    } else {
      return totalBalance.mul(block.timestamp.sub(start)).div(duration);
    }
  }
}

