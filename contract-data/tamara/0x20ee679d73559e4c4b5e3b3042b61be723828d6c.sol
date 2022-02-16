
pragma solidity ^0.5.2;

import "./ERC20Capped.sol";
import "./ERC20Burnable.sol";
import "./ERC20Detailed.sol";
import "./ERC20Pausable.sol";


contract Eraswap is ERC20Detailed,ERC20Burnable,ERC20Capped,ERC20Pausable {


    event NRTManagerAdded(address NRTManager);

    constructor()
        public
         ERC20Detailed ("Era Swap", "ES", 18) ERC20Capped(9100000000000000000000000000) {
             mint(msg.sender, 910000000000000000000000000);
        }

    int256 public timeMachineDepth;


    // gives the time machine time
    function mou() public view returns(uint256) {
        if(timeMachineDepth < 0) {
            return now - uint256(timeMachineDepth);
        } else {
            return now + uint256(timeMachineDepth);
        }
    }

    // sets the time machine depth
    function setTimeMachineDepth(int256 _timeMachineDepth) public {
        timeMachineDepth = _timeMachineDepth;
    }

    function goToFuture(uint256 _seconds) public {
        timeMachineDepth += int256(_seconds);
    }

    function goToPast(uint256 _seconds) public {
        timeMachineDepth -= int256(_seconds);
    }


    /**
    * @dev Function to add NRT Manager to have minting rights
    * It will transfer the minting rights to NRTManager and revokes it from existing minter
    * @param NRTManager Address of NRT Manager C ontract
    */
    function AddNRTManager(address NRTManager) public onlyMinter returns (bool) {
        addMinter(NRTManager);
        addPauser(NRTManager);
        renounceMinter();
        renouncePauser();
        emit NRTManagerAdded(NRTManager);
        return true;
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

import "./ERC20.sol";
import "./Pausable.sol";

/**
 * @title Pausable token
 * @dev ERC20 modified with pausable transfers.
 */
contract ERC20Pausable is ERC20, Pausable {
    function transfer(address to, uint256 value) public whenNotPaused returns (bool) {
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public whenNotPaused returns (bool) {
        return super.transferFrom(from, to, value);
    }

    function approve(address spender, uint256 value) public whenNotPaused returns (bool) {
        return super.approve(spender, value);
    }

    function increaseAllowance(address spender, uint addedValue) public whenNotPaused returns (bool success) {
        return super.increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint subtractedValue) public whenNotPaused returns (bool success) {
        return super.decreaseAllowance(spender, subtractedValue);
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

import "./Eraswap.sol";
import "./TimeAlly.sol";


contract NRTManager {

    using SafeMath for uint256;

    uint256 public lastNRTRelease;              // variable to store last release date
    uint256 public monthlyNRTAmount;            // variable to store Monthly NRT amount to be released
    uint256 public annualNRTAmount;             // variable to store Annual NRT amount to be released
    uint256 public monthCount;                  // variable to store the count of months from the intial date
    uint256 public luckPoolBal;                 // Luckpool Balance
    uint256 public burnTokenBal;                // tokens to be burned
    Eraswap token;
    address Owner;
    //Eraswap public eraswapToken;

    // different pool address
    address public newTalentsAndPartnerships = 0xb4024468D052B36b6904a47541dDE69E44594607;
    address public platformMaintenance = 0x922a2d6B0B2A24779B0623452AdB28233B456D9c;
    address public marketingAndRNR = 0xDFBC0aE48f3DAb5b0A1B154849Ee963430AA0c3E;
    address public kmPards = 0x4881964ac9AD9480585425716A8708f0EE66DA88;
    address public contingencyFunds = 0xF4E731a107D7FFb2785f696543dE8BF6EB558167;
    address public researchAndDevelopment = 0xb209B4cec04cE9C0E1Fa741dE0a8566bf70aDbe9;
    address public powerToken = 0xbc24BfAC401860ce536aeF9dE10EF0104b09f657;
    address public timeSwappers = 0x4b65109E11CF0Ff8fA58A7122a5E84e397C6Ceb8;                 // which include powerToken , curators ,timeTraders , daySwappers
    address public timeAlly;   /// @dev address of timeAlly Contract set when called UpdateAddresses function on this contract


    uint256 public newTalentsAndPartnershipsBal; // variable to store last NRT released to the address;
    uint256 public platformMaintenanceBal;       // variable to store last NRT released to the address;
    uint256 public marketingAndRNRBal;           // variable to store last NRT released to the address;
    uint256 public kmPardsBal;                   // variable to store last NRT released to the address;
    uint256 public contingencyFundsBal;          // variable to store last NRT released to the address;
    uint256 public researchAndDevelopmentBal;    // variable to store last NRT released to the address;
    uint256 public powerTokenNRT;                  // variable to store last NRT released to the address;
    uint256 public timeAllyNRT;                   // variable to store last NRT released to the address;
    uint256 public timeSwappersNRT;              // variable to store last NRT released to the address;


      // Event to watch NRT distribution
      // @param NRTReleased The amount of NRT released in the month
      event NRTDistributed(uint256 NRTReleased);

      /**
      * Event to watch Transfer of NRT to different Pool
      * @param pool - The pool name
      * @param sendAddress - The address of pool
      * @param value - The value of NRT released
      **/
      event NRTTransfer(string pool, address sendAddress, uint256 value);


      // Event to watch Tokens Burned
      // @param amount The amount burned
      event TokensBurned(uint256 amount);

    /**
      * Event to watch the addition of pool address
      * @param pool - The pool name
      * @param sendAddress - The address of pool
      **/
      event PoolAddressAdded(string pool, address sendAddress);

      // Event to watch LuckPool Updation
      // @param luckPoolBal The current luckPoolBal
      event LuckPoolUpdated(uint256 luckPoolBal);

      // Event to watch BurnTokenBal Updation
      // @param burnTokenBal The current burnTokenBal
      event BurnTokenBalUpdated(uint256 burnTokenBal);




      /**
      * @dev Throws if caller is not timeAlly
      */
      modifier OnlyAllowed() {
        require(msg.sender == timeAlly || msg.sender == timeSwappers,"Only TimeAlly and Timeswapper is authorised");
        _;
      }

          /**
      * @dev Throws if caller is not owner
      */
      modifier OnlyOwner() {
        require(msg.sender == Owner,"Only Owner is authorised");
        _;
      }



      /**
      * @dev Should burn tokens according to the total circulation
      * @return true if success
      */

      function burnTokens() internal returns (bool){
        if(burnTokenBal == 0){
          return true;
        }
        else{
          uint MaxAmount = ((token.totalSupply()).mul(2)).div(100);   // max amount permitted to burn in a month
          if(MaxAmount >= burnTokenBal ){
            token.burn(burnTokenBal);
            burnTokenBal = 0;
          }
          else{
            burnTokenBal = burnTokenBal.sub(MaxAmount);
            token.burn(MaxAmount);
          }
          return true;
        }
      }


      /**
      * @dev To update pool addresses
      * @param  pool - A List of pool addresses
      * Updates if pool address is not already set and if given address is not zero
      * @return true if success
      */

      function UpdateAddresses (address[9] calldata pool) external OnlyOwner  returns(bool){

        if((pool[0] != address(0)) && (newTalentsAndPartnerships == address(0))){
          newTalentsAndPartnerships = pool[0];
          emit PoolAddressAdded( "NewTalentsAndPartnerships", newTalentsAndPartnerships);
        }
        if((pool[1] != address(0)) && (platformMaintenance == address(0))){
          platformMaintenance = pool[1];
          emit PoolAddressAdded( "PlatformMaintenance", platformMaintenance);
        }
        if((pool[2] != address(0)) && (marketingAndRNR == address(0))){
          marketingAndRNR = pool[2];
          emit PoolAddressAdded( "MarketingAndRNR", marketingAndRNR);
        }
        if((pool[3] != address(0)) && (kmPards == address(0))){
          kmPards = pool[3];
          emit PoolAddressAdded( "KmPards", kmPards);
        }
        if((pool[4] != address(0)) && (contingencyFunds == address(0))){
          contingencyFunds = pool[4];
          emit PoolAddressAdded( "ContingencyFunds", contingencyFunds);
        }
        if((pool[5] != address(0)) && (researchAndDevelopment == address(0))){
          researchAndDevelopment = pool[5];
          emit PoolAddressAdded( "ResearchAndDevelopment", researchAndDevelopment);
        }
        if((pool[6] != address(0)) && (powerToken == address(0))){
          powerToken = pool[6];
          emit PoolAddressAdded( "PowerToken", powerToken);
        }
        if((pool[7] != address(0)) && (timeSwappers == address(0))){
          timeSwappers = pool[7];
          emit PoolAddressAdded( "TimeSwapper", timeSwappers);
        }
        if((pool[8] != address(0)) && (timeAlly == address(0))){
          timeAlly = pool[8];
          emit PoolAddressAdded( "TimeAlly", timeAlly);
        }

        return true;
      }


      /**
      * @dev Function to update luckpool balance
      * @param amount Amount to be updated
      */
      function UpdateLuckpool(uint256 amount) external OnlyAllowed returns(bool){
              luckPoolBal = luckPoolBal.add(amount);
        emit LuckPoolUpdated(luckPoolBal);
        return true;
      }

      /**
      * @dev Function to trigger to update  for burning of tokens
      * @param amount Amount to be updated
      */
      function UpdateBurnBal(uint256 amount) external OnlyAllowed returns(bool){
             burnTokenBal = burnTokenBal.add(amount);
        emit BurnTokenBalUpdated(burnTokenBal);
        return true;
      }

      /**
      * @dev To invoke monthly release
      * @return true if success
      */

      function MonthlyNRTRelease() external returns (bool) {
        require(now.sub(lastNRTRelease)> 2629744,"NRT release happens once every month");
        uint256 NRTBal = monthlyNRTAmount.add(luckPoolBal);        // Total NRT available.

        // Calculating NRT to be released to each of the pools
        newTalentsAndPartnershipsBal = (NRTBal.mul(5)).div(100);
        platformMaintenanceBal = (NRTBal.mul(10)).div(100);
        marketingAndRNRBal = (NRTBal.mul(10)).div(100);
        kmPardsBal = (NRTBal.mul(10)).div(100);
        contingencyFundsBal = (NRTBal.mul(10)).div(100);
        researchAndDevelopmentBal = (NRTBal.mul(5)).div(100);

        powerTokenNRT = (NRTBal.mul(10)).div(100);
        timeAllyNRT = (NRTBal.mul(15)).div(100);
        timeSwappersNRT = (NRTBal.mul(25)).div(100);

        // sending tokens to respective wallets and emitting events
        token.mint(newTalentsAndPartnerships,newTalentsAndPartnershipsBal);
        emit NRTTransfer("newTalentsAndPartnerships", newTalentsAndPartnerships, newTalentsAndPartnershipsBal);

        token.mint(platformMaintenance,platformMaintenanceBal);
        emit NRTTransfer("platformMaintenance", platformMaintenance, platformMaintenanceBal);

        token.mint(marketingAndRNR,marketingAndRNRBal);
        emit NRTTransfer("marketingAndRNR", marketingAndRNR, marketingAndRNRBal);

        token.mint(kmPards,kmPardsBal);
        emit NRTTransfer("kmPards", kmPards, kmPardsBal);

        token.mint(contingencyFunds,contingencyFundsBal);
        emit NRTTransfer("contingencyFunds", contingencyFunds, contingencyFundsBal);

        token.mint(researchAndDevelopment,researchAndDevelopmentBal);
        emit NRTTransfer("researchAndDevelopment", researchAndDevelopment, researchAndDevelopmentBal);

        token.mint(powerToken,powerTokenNRT);
        emit NRTTransfer("powerToken", powerToken, powerTokenNRT);

        token.mint(timeAlly,timeAllyNRT);
        TimeAlly timeAllyContract = TimeAlly(timeAlly);
        timeAllyContract.increaseMonth(timeAllyNRT);
        emit NRTTransfer("stakingContract", timeAlly, timeAllyNRT);

        token.mint(timeSwappers,timeSwappersNRT);
        emit NRTTransfer("timeSwappers", timeSwappers, timeSwappersNRT);

        // Reseting NRT
        emit NRTDistributed(NRTBal);
        luckPoolBal = 0;
        lastNRTRelease = lastNRTRelease.add(2629744); // @dev adding seconds according to 1 Year = 365.242 days
        burnTokens();                                 // burning burnTokenBal
        emit TokensBurned(burnTokenBal);


        if(monthCount == 11){
          monthCount = 0;
          annualNRTAmount = (annualNRTAmount.mul(90)).div(100);
          monthlyNRTAmount = annualNRTAmount.div(12);
        }
        else{
          monthCount = monthCount.add(1);
        }
        return true;
      }


    /**
    * @dev Constructor
    */

    constructor(address eraswaptoken) public{
      token = Eraswap(eraswaptoken);
      lastNRTRelease = now;
      annualNRTAmount = 819000000000000000000000000;
      monthlyNRTAmount = annualNRTAmount.div(uint256(12));
      monthCount = 0;
      Owner = msg.sender;
    }

}

pragma solidity ^0.5.2;

import "./PauserRole.sol";

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is PauserRole {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    constructor () internal {
        _paused = false;
    }

    /**
     * @return true if the contract is paused, false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!_paused);
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(_paused);
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() public onlyPauser whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() public onlyPauser whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

pragma solidity ^0.5.2;

import "./Roles.sol";

contract PauserRole {
    using Roles for Roles.Role;

    event PauserAdded(address indexed account);
    event PauserRemoved(address indexed account);

    Roles.Role private _pausers;

    constructor () internal {
        _addPauser(msg.sender);
    }

    modifier onlyPauser() {
        require(isPauser(msg.sender));
        _;
    }

    function isPauser(address account) public view returns (bool) {
        return _pausers.has(account);
    }

    function addPauser(address account) public onlyPauser {
        _addPauser(account);
    }

    function renouncePauser() public {
        _removePauser(msg.sender);
    }

    function _addPauser(address account) internal {
        _pausers.add(account);
        emit PauserAdded(account);
    }

    function _removePauser(address account) internal {
        _pausers.remove(account);
        emit PauserRemoved(account);
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

pragma solidity 0.5.10;

import './SafeMath.sol';
import './Eraswap.sol';
import './NRTManager.sol';

/*

Potential bugs: this contract is designed assuming NRT Release will happen every month.
There might be issues when the NRT scheduled
- added stakingMonth property in Staking struct

fix withdraw fractionFrom15 luck pool
- done

add loanactive contition to take loan
- done

ensure stakingMonth in the struct is being used every where instead of calculation
- done

remove local variables uncesessary

final the earthSecondsInMonth amount in TimeAlly as well in NRT

add events for required functions
*/

/// @author The EraSwap Team
/// @title TimeAlly Smart Contract
/// @dev all require statement message strings are commented to make contract deployable by lower the deploying gas fee
contract TimeAlly {
    using SafeMath for uint256;

    struct Staking {
        uint256 exaEsAmount;
        uint256 timestamp;
        uint256 stakingMonth;
        uint256 stakingPlanId;
        uint256 status; /// @dev 1 => active; 2 => loaned; 3 => withdrawed; 4 => cancelled; 5 => nomination mode
        uint256 loanId;
        uint256 totalNominationShares;
        mapping (uint256 => bool) isMonthClaimed;
        mapping (address => uint256) nomination;
    }

    struct StakingPlan {
        uint256 months;
        uint256 fractionFrom15; /// @dev fraction of NRT released. Alotted to TimeAlly is 15% of NRT
        // bool isPlanActive; /// @dev when plan is inactive, new stakings must not be able to select this plan. Old stakings which already selected this plan will continue themselves as per plan.
        bool isUrgentLoanAllowed; /// @dev if urgent loan is not allowed then staker can take loan only after 75% (hard coded) of staking months
    }

    struct Loan {
        uint256 exaEsAmount;
        uint256 timestamp;
        uint256 loanPlanId;
        uint256 status; // @dev 1 => not repayed yet; 2 => repayed
        uint256[] stakingIds;
    }

    struct LoanPlan {
        uint256 loanMonths;
        uint256 loanRate; // @dev amount of charge to pay, this will be sent to luck pool
        uint256 maxLoanAmountPercent; /// @dev max loan user can take depends on this percent of the plan and the stakings user wishes to put for the loan
    }

    uint256 public deployedTimestamp;
    address public owner;
    Eraswap public token;
    NRTManager public nrtManager;

    /// @dev 1 Year = 365.242 days for taking care of leap years
    uint256 public earthSecondsInMonth = 2629744;
    // uint256 earthSecondsInMonth = 30 * 12 * 60 * 60; /// @dev there was a decision for following 360 day year

    StakingPlan[] public stakingPlans;
    LoanPlan[] public loanPlans;

    // user activity details:
    mapping(address => Staking[]) public stakings;
    mapping(address => Loan[]) public loans;
    mapping(address => uint256) public launchReward;

    /// @dev TimeAlly month to exaEsAmount mapping.
    mapping (uint256 => uint256) public totalActiveStakings;

    /// @notice NRT being received from NRT Manager every month is stored in this array
    /// @dev current month is the length of this array
    uint256[] public timeAllyMonthlyNRT;

    event NewStaking (
        address indexed _userAddress,
        uint256 indexed _stakePlanId,
        uint256 _exaEsAmount,
        uint256 _stakingId
    );

    event PrincipalWithdrawl (
        address indexed _userAddress,
        uint256 _stakingId
    );

    event NomineeNew (
        address indexed _userAddress,
        uint256 indexed _stakingId,
        address indexed _nomineeAddress
    );

    event NomineeWithdraw (
        address indexed _userAddress,
        uint256 indexed _stakingId,
        address indexed _nomineeAddress,
        uint256 _liquid,
        uint256 _accrued
    );

    event BenefitWithdrawl (
        address indexed _userAddress,
        uint256 _stakingId,
        uint256[] _months,
        uint256 _halfBenefit
    );

    event NewLoan (
        address indexed _userAddress,
        uint256 indexed _loanPlanId,
        uint256 _exaEsAmount,
        uint256 _loanInterest,
        uint256 _loanId
    );

    event RepayLoan (
        address indexed _userAddress,
        uint256 _loanId
    );


    modifier onlyNRTManager() {
        require(
          msg.sender == address(nrtManager)
          // , 'only NRT manager can call'
        );
        _;
    }

    modifier onlyOwner() {
        require(
          msg.sender == owner
          // , 'only deployer can call'
        );
        _;
    }

    /// @notice sets up TimeAlly contract when deployed
    /// @param _tokenAddress - is EraSwap contract address
    /// @param _nrtAddress - is NRT Manager contract address
    constructor(address _tokenAddress, address _nrtAddress) public {
        owner = msg.sender;
        token = Eraswap(_tokenAddress);
        nrtManager = NRTManager(_nrtAddress);
        deployedTimestamp = now;
        timeAllyMonthlyNRT.push(0); /// @dev first month there is no NRT released
    }

    /// @notice this function is used by NRT manager to communicate NRT release to TimeAlly
    function increaseMonth(uint256 _timeAllyNRT) public onlyNRTManager {
        timeAllyMonthlyNRT.push(_timeAllyNRT);
    }

    /// @notice TimeAlly month is dependent on the monthly NRT release
    /// @return current month is the TimeAlly month
    function getCurrentMonth() public view returns (uint256) {
        return timeAllyMonthlyNRT.length - 1;
    }

    /// @notice this function is used by owner to create plans for new stakings
    /// @param _months - is number of staking months of a plan. for eg. 12 months
    /// @param _fractionFrom15 - NRT fraction (max 15%) benefit to be given to user. rest is sent back to NRT in Luck Pool
    /// @param _isUrgentLoanAllowed - if urgent loan is not allowed then staker can take loan only after 75% of time elapsed
    function createStakingPlan(uint256 _months, uint256 _fractionFrom15, bool _isUrgentLoanAllowed) public onlyOwner {
        stakingPlans.push(StakingPlan({
            months: _months,
            fractionFrom15: _fractionFrom15,
            // isPlanActive: true,
            isUrgentLoanAllowed: _isUrgentLoanAllowed
        }));
    }

    /// @notice this function is used by owner to create plans for new loans
    /// @param _loanMonths - number of months or duration of loan, loan taker must repay the loan before this period
    /// @param _loanRate - this is total % of loaning amount charged while taking loan, this charge is sent to luckpool in NRT manager which ends up distributed back to the community again
    function createLoanPlan(uint256 _loanMonths, uint256 _loanRate, uint256 _maxLoanAmountPercent) public onlyOwner {
        require(_maxLoanAmountPercent <= 100
            // , 'everyone should not be able to take loan more than 100 percent of their stakings'
        );
        loanPlans.push(LoanPlan({
            loanMonths: _loanMonths,
            loanRate: _loanRate,
            maxLoanAmountPercent: _maxLoanAmountPercent
        }));
    }



    /// @notice takes ES from user and locks it for a time according to plan selected by user
    /// @param _exaEsAmount - amount of ES tokens (in 18 decimals thats why 'exa') that user wishes to stake
    /// @param _stakingPlanId - plan for staking
    function newStaking(uint256 _exaEsAmount, uint256 _stakingPlanId) public {

        /// @dev 0 ES stakings would get 0 ES benefits and might cause confusions as transaction would confirm but total active stakings will not increase
        require(_exaEsAmount > 0
            // , 'staking amount should be non zero'
        );

        require(token.transferFrom(msg.sender, address(this), _exaEsAmount)
          // , 'could not transfer tokens'
        );
        uint256 stakeEndMonth = getCurrentMonth() + stakingPlans[_stakingPlanId].months;

        // @dev update the totalActiveStakings array so that staking would be automatically inactive after the stakingPlanMonthhs
        for(
          uint256 month = getCurrentMonth() + 1;
          month <= stakeEndMonth;
          month++
        ) {
            totalActiveStakings[month] = totalActiveStakings[month].add(_exaEsAmount);
        }

        stakings[msg.sender].push(Staking({
            exaEsAmount: _exaEsAmount,
            timestamp: now,
            stakingMonth: getCurrentMonth(),
            stakingPlanId: _stakingPlanId,
            status: 1,
            loanId: 0,
            totalNominationShares: 0
        }));

        emit NewStaking(msg.sender, _stakingPlanId, _exaEsAmount, stakings[msg.sender].length - 1);
    }

    /// @notice this function is used to see total stakings of any user of TimeAlly
    /// @param _userAddress - address of user
    /// @return number of stakings of _userAddress
    function getNumberOfStakingsByUser(address _userAddress) public view returns (uint256) {
        return stakings[_userAddress].length;
    }

    /// @notice this function is used to topup reward balance in smart contract. Rewards are transferable. Anyone with reward balance can only claim it as a new staking.
    /// @dev Allowance is required before topup.
    /// @param _exaEsAmount - amount to add to your rewards for sending rewards to others
    function topupRewardBucket(uint256 _exaEsAmount) public {
        require(token.transferFrom(msg.sender, address(this), _exaEsAmount));
        launchReward[msg.sender] = launchReward[msg.sender].add(_exaEsAmount);
    }

    /// @notice this function is used to send rewards to multiple users
    /// @param _addresses - array of address to send rewards
    /// @param _exaEsAmountArray - array of ExaES amounts sent to each address of _addresses with same index
    function giveLaunchReward(address[] memory _addresses, uint256[] memory _exaEsAmountArray) public onlyOwner {
        for(uint256 i = 0; i < _addresses.length; i++) {
            launchReward[msg.sender] = launchReward[msg.sender].sub(_exaEsAmountArray[i]);
            launchReward[_addresses[i]] = launchReward[_addresses[i]].add(_exaEsAmountArray[i]);
        }
    }

    /// @notice this function is used by rewardees to claim their accrued rewards. This is also used by stakers to restake their 50% benefit received as rewards
    /// @param _stakingPlanId - rewardee can choose plan while claiming rewards as stakings
    function claimLaunchReward(uint256 _stakingPlanId) public {
        // require(stakingPlans[_stakingPlanId].isPlanActive
        //     // , 'selected plan is not active'
        // );

        require(launchReward[msg.sender] > 0
            // , 'launch reward should be non zero'
        );
        uint256 reward = launchReward[msg.sender];
        launchReward[msg.sender] = 0;

        // @dev logic similar to newStaking function
        uint256 stakeEndMonth = getCurrentMonth() + stakingPlans[_stakingPlanId].months;

        // @dev update the totalActiveStakings array so that staking would be automatically inactive after the stakingPlanMonthhs
        for(
          uint256 month = getCurrentMonth() + 1;
          month <= stakeEndMonth;
          month++
        ) {
            totalActiveStakings[month] = totalActiveStakings[month].add(reward); /// @dev reward means locked ES which only staking option
        }

        stakings[msg.sender].push(Staking({
            exaEsAmount: reward,
            timestamp: now,
            stakingMonth: getCurrentMonth(),
            stakingPlanId: _stakingPlanId,
            status: 1,
            loanId: 0,
            totalNominationShares: 0
        }));

        emit NewStaking(msg.sender, _stakingPlanId, reward, stakings[msg.sender].length - 1);
    }


    /// @notice used internally to see if staking is active or not. does not include if staking is claimed.
    /// @param _userAddress - address of user
    /// @param _stakingId - staking id
    /// @param _atMonth - particular month to check staking active
    /// @return true is staking is in correct time frame and also no loan on it
    function isStakingActive(
        address _userAddress,
        uint256 _stakingId,
        uint256 _atMonth
    ) public view returns (bool) {
        //uint256 stakingMonth = stakings[_userAddress][_stakingId].timestamp.sub(deployedTimestamp).div(earthSecondsInMonth);

        return (
            /// @dev _atMonth should be a month after which staking starts
            stakings[_userAddress][_stakingId].stakingMonth + 1 <= _atMonth

            /// @dev _atMonth should be a month before which staking ends
            && stakings[_userAddress][_stakingId].stakingMonth + stakingPlans[ stakings[_userAddress][_stakingId].stakingPlanId ].months >= _atMonth

            /// @dev staking should have active status
            && stakings[_userAddress][_stakingId].status == 1

            /// @dev if _atMonth is current Month, then withdrawal should be allowed only after 30 days interval since staking
            && (
              getCurrentMonth() != _atMonth
              || now >= stakings[_userAddress][_stakingId].timestamp
                          .add(
                            getCurrentMonth()
                              .sub(stakings[_userAddress][_stakingId].stakingMonth)
                              .mul(earthSecondsInMonth)
                          )
              )
            );
    }


    /// @notice this function is used for seeing the benefits of a staking of any user
    /// @param _userAddress - address of user
    /// @param _stakingId - staking id
    /// @param _months - array of months user is interested to see benefits.
    /// @return amount of ExaES of benefits of entered months
    function seeBenefitOfAStakingByMonths(
        address _userAddress,
        uint256 _stakingId,
        uint256[] memory _months
    ) public view returns (uint256) {
        uint256 benefitOfAllMonths;
        for(uint256 i = 0; i < _months.length; i++) {
            /// @dev this require statement is converted into if statement for easier UI fetching. If there is no benefit for a month or already claimed, it will consider benefit of that month as 0 ES. But same is not done for withdraw function.
            // require(
            //   isStakingActive(_userAddress, _stakingId, _months[i])
            //   && !stakings[_userAddress][_stakingId].isMonthClaimed[_months[i]]
            //   // , 'staking must be active'
            // );
            if(isStakingActive(_userAddress, _stakingId, _months[i])
            && !stakings[_userAddress][_stakingId].isMonthClaimed[_months[i]]) {
                uint256 benefit = stakings[_userAddress][_stakingId].exaEsAmount
                                  .mul(timeAllyMonthlyNRT[ _months[i] ])
                                  .div(totalActiveStakings[ _months[i] ]);
                benefitOfAllMonths = benefitOfAllMonths.add(benefit);
            }
        }
        return benefitOfAllMonths.mul(
          stakingPlans[stakings[_userAddress][_stakingId].stakingPlanId].fractionFrom15
        ).div(15);
    }

    /// @notice this function is used for withdrawing the benefits of a staking of any user
    /// @param _stakingId - staking id
    /// @param _months - array of months user is interested to withdraw benefits of staking.
    function withdrawBenefitOfAStakingByMonths(
        uint256 _stakingId,
        uint256[] memory _months
    ) public {
        uint256 _benefitOfAllMonths;
        for(uint256 i = 0; i < _months.length; i++) {
            // require(
            //   isStakingActive(msg.sender, _stakingId, _months[i])
            //   && !stakings[msg.sender][_stakingId].isMonthClaimed[_months[i]]
            //   // , 'staking must be active'
            // );
            if(isStakingActive(msg.sender, _stakingId, _months[i])
            && !stakings[msg.sender][_stakingId].isMonthClaimed[_months[i]]) {
                uint256 _benefit = stakings[msg.sender][_stakingId].exaEsAmount
                                  .mul(timeAllyMonthlyNRT[ _months[i] ])
                                  .div(totalActiveStakings[ _months[i] ]);

                _benefitOfAllMonths = _benefitOfAllMonths.add(_benefit);
                stakings[msg.sender][_stakingId].isMonthClaimed[_months[i]] = true;
            }
        }

        uint256 _luckPool = _benefitOfAllMonths
                        .mul( uint256(15).sub(stakingPlans[stakings[msg.sender][_stakingId].stakingPlanId].fractionFrom15) )
                        .div( 15 );

        require( token.transfer(address(nrtManager), _luckPool) );
        require( nrtManager.UpdateLuckpool(_luckPool) );

        _benefitOfAllMonths = _benefitOfAllMonths.sub(_luckPool);

        uint256 _halfBenefit = _benefitOfAllMonths.div(2);
        require( token.transfer(msg.sender, _halfBenefit) );

        launchReward[msg.sender] = launchReward[msg.sender].add(_halfBenefit);

        // emit event
        emit BenefitWithdrawl(msg.sender, _stakingId, _months, _halfBenefit);
    }


    /// @notice this function is used to withdraw the principle amount of multiple stakings which have their tenure completed
    /// @param _stakingIds - input which stakings to withdraw
    function withdrawExpiredStakings(uint256[] memory _stakingIds) public {
        for(uint256 i = 0; i < _stakingIds.length; i++) {
            require(now >= stakings[msg.sender][_stakingIds[i]].timestamp
                    .add(stakingPlans[ stakings[msg.sender][_stakingIds[i]].stakingPlanId ].months.mul(earthSecondsInMonth))
              // , 'cannot withdraw before staking ends'
            );
            stakings[msg.sender][_stakingIds[i]].status = 3;

            token.transfer(msg.sender, stakings[msg.sender][_stakingIds[i]].exaEsAmount);

            emit PrincipalWithdrawl(msg.sender, _stakingIds[i]);
        }
    }

    /// @notice this function is used to estimate the maximum amount of loan that any user can take with their stakings
    /// @param _userAddress - address of user
    /// @param _stakingIds - array of staking ids which should be used to estimate max loan amount
    /// @param _loanPlanId - the loan plan user wishes to take loan.
    /// @return max loaning amount
    function seeMaxLoaningAmountOnUserStakings(address _userAddress, uint256[] memory _stakingIds, uint256 _loanPlanId) public view returns (uint256) {
        uint256 _currentMonth = getCurrentMonth();
        //require(_currentMonth >= _atMonth, 'cannot see future stakings');

        uint256 userStakingsExaEsAmount;

        for(uint256 i = 0; i < _stakingIds.length; i++) {

            if(isStakingActive(_userAddress, _stakingIds[i], _currentMonth)
                && (
                  // @dev if urgent loan is not allowed then loan can be taken only after staking period is completed 75%
                  stakingPlans[ stakings[_userAddress][_stakingIds[i]].stakingPlanId ].isUrgentLoanAllowed
                  || now > stakings[_userAddress][_stakingIds[i]].timestamp + stakingPlans[ stakings[_userAddress][_stakingIds[i]].stakingPlanId ].months.mul(earthSecondsInMonth).mul(75).div(100)
                )
            ) {
                userStakingsExaEsAmount = userStakingsExaEsAmount
                    .add(stakings[_userAddress][_stakingIds[i]].exaEsAmount
                      .mul(loanPlans[_loanPlanId].maxLoanAmountPercent)
                      .div(100)
                      // .mul(stakingPlans[ stakings[_userAddress][_stakingIds[i]].stakingPlanId ].fractionFrom15)
                      // .div(15)
                    );
            }
        }

        return userStakingsExaEsAmount;
            //.mul( uint256(100).sub(loanPlans[_loanPlanId].loanRate) ).div(100);
    }

    /// @notice this function is used to take loan on multiple stakings
    /// @param _loanPlanId - user can select this plan which defines loan duration and loan interest
    /// @param _exaEsAmount - loan amount, this will also be the loan repay amount, the interest will first be deducted from this and then amount will be credited
    /// @param _stakingIds - staking ids user wishes to encash for taking the loan
    function takeLoanOnSelfStaking(uint256 _loanPlanId, uint256 _exaEsAmount, uint256[] memory _stakingIds) public {
        // @dev when loan is to be taken, first calculate active stakings from given stakings array. this way we can get how much loan user can take and simultaneously mark stakings as claimed for next months number loan period
        uint256 _currentMonth = getCurrentMonth();
        uint256 _userStakingsExaEsAmount;

        for(uint256 i = 0; i < _stakingIds.length; i++) {

            if( isStakingActive(msg.sender, _stakingIds[i], _currentMonth)
                && (
                  // @dev if urgent loan is not allowed then loan can be taken only after staking period is completed 75%
                  stakingPlans[ stakings[msg.sender][_stakingIds[i]].stakingPlanId ].isUrgentLoanAllowed
                  || now > stakings[msg.sender][_stakingIds[i]].timestamp + stakingPlans[ stakings[msg.sender][_stakingIds[i]].stakingPlanId ].months.mul(earthSecondsInMonth).mul(75).div(100)
                )
            ) {

                // @dev store sum in a number
                _userStakingsExaEsAmount = _userStakingsExaEsAmount
                    .add(
                        stakings[msg.sender][ _stakingIds[i] ].exaEsAmount
                          .mul(loanPlans[_loanPlanId].maxLoanAmountPercent)
                          .div(100)
                );

                // @dev subtract total active stakings
                uint256 stakingStartMonth = stakings[msg.sender][_stakingIds[i]].stakingMonth;

                uint256 stakeEndMonth = stakingStartMonth + stakingPlans[stakings[msg.sender][_stakingIds[i]].stakingPlanId].months;

                for(uint256 j = _currentMonth + 1; j <= stakeEndMonth; j++) {
                    totalActiveStakings[j] = totalActiveStakings[j].sub(_userStakingsExaEsAmount);
                }

                // @dev make stakings inactive
                for(uint256 j = 1; j <= loanPlans[_loanPlanId].loanMonths; j++) {
                    stakings[msg.sender][ _stakingIds[i] ].isMonthClaimed[ _currentMonth + j ] = true;
                    stakings[msg.sender][ _stakingIds[i] ].status = 2; // means in loan
                }
            }
        }

        uint256 _maxLoaningAmount = _userStakingsExaEsAmount;

        if(_exaEsAmount > _maxLoaningAmount) {
            require(false
              // , 'cannot loan more than maxLoaningAmount'
            );
        }


        uint256 _loanInterest = _exaEsAmount.mul(loanPlans[_loanPlanId].loanRate).div(100);
        uint256 _loanAmountToTransfer = _exaEsAmount.sub(_loanInterest);

        require( token.transfer(address(nrtManager), _loanInterest) );
        require( nrtManager.UpdateLuckpool(_loanInterest) );

        loans[msg.sender].push(Loan({
            exaEsAmount: _exaEsAmount,
            timestamp: now,
            loanPlanId: _loanPlanId,
            status: 1,
            stakingIds: _stakingIds
        }));

        // @dev send user amount
        require( token.transfer(msg.sender, _loanAmountToTransfer) );

        emit NewLoan(msg.sender, _loanPlanId, _exaEsAmount, _loanInterest, loans[msg.sender].length - 1);
    }

    /// @notice repay loan functionality
    /// @dev need to give allowance before this
    /// @param _loanId - select loan to repay
    function repayLoanSelf(uint256 _loanId) public {
        require(loans[msg.sender][_loanId].status == 1
          // , 'can only repay pending loans'
        );

        require(loans[msg.sender][_loanId].timestamp + loanPlans[ loans[msg.sender][_loanId].loanPlanId ].loanMonths.mul(earthSecondsInMonth) > now
          // , 'cannot repay expired loan'
        );

        require(token.transferFrom(msg.sender, address(this), loans[msg.sender][_loanId].exaEsAmount)
          // , 'cannot receive enough tokens, please check if allowance is there'
        );

        loans[msg.sender][_loanId].status = 2;

        // @dev get all stakings associated with this loan. and set next unclaimed months. then set status to 1 and also add to totalActiveStakings
        for(uint256 i = 0; i < loans[msg.sender][_loanId].stakingIds.length; i++) {
            uint256 _stakingId = loans[msg.sender][_loanId].stakingIds[i];

            stakings[msg.sender][_stakingId].status = 1;

            uint256 stakingStartMonth = stakings[msg.sender][_stakingId].timestamp.sub(deployedTimestamp).div(earthSecondsInMonth);

            uint256 stakeEndMonth = stakingStartMonth + stakingPlans[stakings[msg.sender][_stakingId].stakingPlanId].months;

            for(uint256 j = getCurrentMonth() + 1; j <= stakeEndMonth; j++) {
                stakings[msg.sender][_stakingId].isMonthClaimed[i] = false;

                totalActiveStakings[j] = totalActiveStakings[j].add(stakings[msg.sender][_stakingId].exaEsAmount);
            }
        }
        // add repay event
        emit RepayLoan(msg.sender, _loanId);
    }

    function burnDefaultedLoans(address[] memory _addressArray, uint256[] memory _loanIdArray) public {
        uint256 _amountToBurn;
        for(uint256 i = 0; i < _addressArray.length; i++) {
            require(
                loans[ _addressArray[i] ][ _loanIdArray[i] ].status == 1
                // , 'loan should not be repayed'
            );
            require(
                now >
                loans[ _addressArray[i] ][ _loanIdArray[i] ].timestamp
                + loanPlans[ loans[ _addressArray[i] ][ _loanIdArray[i] ].loanPlanId ].loanMonths.mul(earthSecondsInMonth)
                // , 'loan should have crossed its loan period'
            );
            uint256[] storage _stakingIdsOfLoan = loans[ _addressArray[i] ][ _loanIdArray[i] ].stakingIds;

            /// @dev add staking amounts of all stakings on which loan is taken
            for(uint256 j = 0; j < _stakingIdsOfLoan.length; j++) {
                _amountToBurn = _amountToBurn.add(
                    stakings[ _addressArray[i] ][ _stakingIdsOfLoan[j] ].exaEsAmount
                );
            }
            /// @dev sub loan amount
            _amountToBurn = _amountToBurn.sub(
                loans[ _addressArray[i] ][ _loanIdArray[i] ].exaEsAmount
            );
        }
        require(token.transfer(address(nrtManager), _amountToBurn));
        require(nrtManager.UpdateBurnBal(_amountToBurn));

        // emit event
    }

    /// @notice this function is used to add nominee to a staking
    /// @param _stakingId - staking id
    /// @param _nomineeAddress - address of nominee to be added to staking
    /// @param _shares - amount of shares of the staking to the nominee
    /// @dev shares is compared with total shares issued in a staking to see the percent nominee can withdraw. Nominee can withdraw only after one year past the end of tenure of staking. Upto 1 year past the end of tenure of staking, owner can withdraw principle amount of staking as well as can CRUD nominees. Owner of staking is has this time to withdraw their staking, if they fail to do so, after that nominees are allowed to withdraw. Withdrawl by first nominee will trigger staking into nomination mode and owner of staking cannot withdraw the principle amount as it will be distributed with only nominees and only they can withdraw it.
    function addNominee(uint256 _stakingId, address _nomineeAddress, uint256 _shares) public {
        require(stakings[msg.sender][_stakingId].status == 1
          // , 'staking should active'
        );
        require(stakings[msg.sender][_stakingId].nomination[_nomineeAddress] == 0
          // , 'should not be nominee already'
        );
        stakings[msg.sender][_stakingId].totalNominationShares = stakings[msg.sender][_stakingId].totalNominationShares.add(_shares);
        stakings[msg.sender][_stakingId].nomination[_nomineeAddress] = _shares;
        emit NomineeNew(msg.sender, _stakingId, _nomineeAddress);
    }

    /// @notice this function is used to read the nomination of a nominee address of a staking of a user
    /// @param _userAddress - address of staking owner
    /// @param _stakingId - staking id
    /// @param _nomineeAddress - address of nominee
    /// @return nomination of the nominee
    function viewNomination(address _userAddress, uint256 _stakingId, address _nomineeAddress) public view returns (uint256) {
        return stakings[_userAddress][_stakingId].nomination[_nomineeAddress];
    }

    // /// @notice this function is used to update nomination of a nominee of sender's staking
    // /// @param _stakingId - staking id
    // /// @param _nomineeAddress - address of nominee
    // /// @param _shares - shares to be updated for the nominee
    // function updateNominee(uint256 _stakingId, address _nomineeAddress, uint256 _shares) public {
    //     require(stakings[msg.sender][_stakingId].status == 1
    //       // , 'staking should active'
    //     );
    //     uint256 _oldShares = stakings[msg.sender][_stakingId].nomination[_nomineeAddress];
    //     if(_shares > _oldShares) {
    //         uint256 _diff = _shares.sub(_oldShares);
    //         stakings[msg.sender][_stakingId].totalNominationShares = stakings[msg.sender][_stakingId].totalNominationShares.add(_diff);
    //         stakings[msg.sender][_stakingId].nomination[_nomineeAddress] = stakings[msg.sender][_stakingId].nomination[_nomineeAddress].add(_diff);
    //     } else if(_shares < _oldShares) {
    //       uint256 _diff = _oldShares.sub(_shares);
    //         stakings[msg.sender][_stakingId].nomination[_nomineeAddress] = stakings[msg.sender][_stakingId].nomination[_nomineeAddress].sub(_diff);
    //         stakings[msg.sender][_stakingId].totalNominationShares = stakings[msg.sender][_stakingId].totalNominationShares.sub(_diff);
    //     }
    // }

    /// @notice this function is used to remove nomination of a address
    /// @param _stakingId - staking id
    /// @param _nomineeAddress - address of nominee
    function removeNominee(uint256 _stakingId, address _nomineeAddress) public {
        require(stakings[msg.sender][_stakingId].status == 1, 'staking should active');
        uint256 _oldShares = stakings[msg.sender][_stakingId].nomination[msg.sender];
        stakings[msg.sender][_stakingId].nomination[_nomineeAddress] = 0;
        stakings[msg.sender][_stakingId].totalNominationShares = stakings[msg.sender][_stakingId].totalNominationShares.sub(_oldShares);
    }

    /// @notice this function is used by nominee to withdraw their share of a staking after 1 year of the end of tenure of staking
    /// @param _userAddress - address of user
    /// @param _stakingId - staking id
    function nomineeWithdraw(address _userAddress, uint256 _stakingId) public {
        // end time stamp > 0
        uint256 currentTime = now;
        require( currentTime > (stakings[_userAddress][_stakingId].timestamp
                    + stakingPlans[stakings[_userAddress][_stakingId].stakingPlanId].months * earthSecondsInMonth
                    + 12 * earthSecondsInMonth )
                    // , 'cannot nominee withdraw before '
            );

        uint256 _nomineeShares = stakings[_userAddress][_stakingId].nomination[msg.sender];
        require(_nomineeShares > 0
          // , 'Not a nominee of this staking'
        );

        //uint256 _totalShares = ;

        // set staking to nomination mode if it isn't.
        if(stakings[_userAddress][_stakingId].status != 5) {
            stakings[_userAddress][_stakingId].status = 5;
        }

        // adding principal account
        uint256 _pendingLiquidAmountInStaking = stakings[_userAddress][_stakingId].exaEsAmount;
        uint256 _pendingAccruedAmountInStaking;

        // uint256 _stakingStartMonth = stakings[_userAddress][_stakingId].timestamp.sub(deployedTimestamp).div(earthSecondsInMonth);
        uint256 _stakeEndMonth = stakings[_userAddress][_stakingId].stakingMonth + stakingPlans[stakings[_userAddress][_stakingId].stakingPlanId].months;

        // adding monthly benefits which are not claimed
        for(
          uint256 i = stakings[_userAddress][_stakingId].stakingMonth; //_stakingStartMonth;
          i < _stakeEndMonth;
          i++
        ) {
            if( stakings[_userAddress][_stakingId].isMonthClaimed[i] ) {
                uint256 _effectiveAmount = stakings[_userAddress][_stakingId].exaEsAmount
                  .mul(stakingPlans[stakings[_userAddress][_stakingId].stakingPlanId].fractionFrom15)
                  .div(15);
                uint256 _monthlyBenefit = _effectiveAmount
                                          .mul(timeAllyMonthlyNRT[i])
                                          .div(totalActiveStakings[i]);
                _pendingLiquidAmountInStaking = _pendingLiquidAmountInStaking.add(_monthlyBenefit.div(2));
                _pendingAccruedAmountInStaking = _pendingAccruedAmountInStaking.add(_monthlyBenefit.div(2));
            }
        }

        // now we have _pendingLiquidAmountInStaking && _pendingAccruedAmountInStaking
        // on which user's share will be calculated and sent

        // marking nominee as claimed by removing his shares
        stakings[_userAddress][_stakingId].nomination[msg.sender] = 0;

        uint256 _nomineeLiquidShare = _pendingLiquidAmountInStaking
                                        .mul(_nomineeShares)
                                        .div(stakings[_userAddress][_stakingId].totalNominationShares);
        token.transfer(msg.sender, _nomineeLiquidShare);

        uint256 _nomineeAccruedShare = _pendingAccruedAmountInStaking
                                          .mul(_nomineeShares)
                                          .div(stakings[_userAddress][_stakingId].totalNominationShares);
        launchReward[msg.sender] = launchReward[msg.sender].add(_nomineeAccruedShare);

        // emit a event
        emit NomineeWithdraw(_userAddress, _stakingId, msg.sender, _nomineeLiquidShare, _nomineeAccruedShare);
    }
}


pragma solidity ^0.5.2;

import "./ERC20Capped.sol";
import "./ERC20Burnable.sol";
import "./ERC20Detailed.sol";
import "./ERC20Pausable.sol";


contract Eraswap is ERC20Detailed,ERC20Burnable,ERC20Capped,ERC20Pausable {


    event NRTManagerAdded(address NRTManager);

    constructor()
        public
         ERC20Detailed ("Era Swap", "ES", 18) ERC20Capped(9100000000000000000000000000) {
             mint(msg.sender, 910000000000000000000000000);
        }

    int256 public timeMachineDepth;


    // gives the time machine time
    function mou() public view returns(uint256) {
        if(timeMachineDepth < 0) {
            return now - uint256(timeMachineDepth);
        } else {
            return now + uint256(timeMachineDepth);
        }
    }

    // sets the time machine depth
    function setTimeMachineDepth(int256 _timeMachineDepth) public {
        timeMachineDepth = _timeMachineDepth;
    }

    function goToFuture(uint256 _seconds) public {
        timeMachineDepth += int256(_seconds);
    }

    function goToPast(uint256 _seconds) public {
        timeMachineDepth -= int256(_seconds);
    }


    /**
    * @dev Function to add NRT Manager to have minting rights
    * It will transfer the minting rights to NRTManager and revokes it from existing minter
    * @param NRTManager Address of NRT Manager C ontract
    */
    function AddNRTManager(address NRTManager) public onlyMinter returns (bool) {
        addMinter(NRTManager);
        addPauser(NRTManager);
        renounceMinter();
        renouncePauser();
        emit NRTManagerAdded(NRTManager);
        return true;
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

import "./ERC20.sol";
import "./Pausable.sol";

/**
 * @title Pausable token
 * @dev ERC20 modified with pausable transfers.
 */
contract ERC20Pausable is ERC20, Pausable {
    function transfer(address to, uint256 value) public whenNotPaused returns (bool) {
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public whenNotPaused returns (bool) {
        return super.transferFrom(from, to, value);
    }

    function approve(address spender, uint256 value) public whenNotPaused returns (bool) {
        return super.approve(spender, value);
    }

    function increaseAllowance(address spender, uint addedValue) public whenNotPaused returns (bool success) {
        return super.increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint subtractedValue) public whenNotPaused returns (bool success) {
        return super.decreaseAllowance(spender, subtractedValue);
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

import "./Eraswap.sol";
import "./TimeAlly.sol";


contract NRTManager {

    using SafeMath for uint256;

    uint256 public lastNRTRelease;              // variable to store last release date
    uint256 public monthlyNRTAmount;            // variable to store Monthly NRT amount to be released
    uint256 public annualNRTAmount;             // variable to store Annual NRT amount to be released
    uint256 public monthCount;                  // variable to store the count of months from the intial date
    uint256 public luckPoolBal;                 // Luckpool Balance
    uint256 public burnTokenBal;                // tokens to be burned
    Eraswap token;
    address Owner;
    //Eraswap public eraswapToken;

    // different pool address
    address public newTalentsAndPartnerships = 0xb4024468D052B36b6904a47541dDE69E44594607;
    address public platformMaintenance = 0x922a2d6B0B2A24779B0623452AdB28233B456D9c;
    address public marketingAndRNR = 0xDFBC0aE48f3DAb5b0A1B154849Ee963430AA0c3E;
    address public kmPards = 0x4881964ac9AD9480585425716A8708f0EE66DA88;
    address public contingencyFunds = 0xF4E731a107D7FFb2785f696543dE8BF6EB558167;
    address public researchAndDevelopment = 0xb209B4cec04cE9C0E1Fa741dE0a8566bf70aDbe9;
    address public powerToken = 0xbc24BfAC401860ce536aeF9dE10EF0104b09f657;
    address public timeSwappers = 0x4b65109E11CF0Ff8fA58A7122a5E84e397C6Ceb8;                 // which include powerToken , curators ,timeTraders , daySwappers
    address public timeAlly;   /// @dev address of timeAlly Contract set when called UpdateAddresses function on this contract


    uint256 public newTalentsAndPartnershipsBal; // variable to store last NRT released to the address;
    uint256 public platformMaintenanceBal;       // variable to store last NRT released to the address;
    uint256 public marketingAndRNRBal;           // variable to store last NRT released to the address;
    uint256 public kmPardsBal;                   // variable to store last NRT released to the address;
    uint256 public contingencyFundsBal;          // variable to store last NRT released to the address;
    uint256 public researchAndDevelopmentBal;    // variable to store last NRT released to the address;
    uint256 public powerTokenNRT;                  // variable to store last NRT released to the address;
    uint256 public timeAllyNRT;                   // variable to store last NRT released to the address;
    uint256 public timeSwappersNRT;              // variable to store last NRT released to the address;


      // Event to watch NRT distribution
      // @param NRTReleased The amount of NRT released in the month
      event NRTDistributed(uint256 NRTReleased);

      /**
      * Event to watch Transfer of NRT to different Pool
      * @param pool - The pool name
      * @param sendAddress - The address of pool
      * @param value - The value of NRT released
      **/
      event NRTTransfer(string pool, address sendAddress, uint256 value);


      // Event to watch Tokens Burned
      // @param amount The amount burned
      event TokensBurned(uint256 amount);

    /**
      * Event to watch the addition of pool address
      * @param pool - The pool name
      * @param sendAddress - The address of pool
      **/
      event PoolAddressAdded(string pool, address sendAddress);

      // Event to watch LuckPool Updation
      // @param luckPoolBal The current luckPoolBal
      event LuckPoolUpdated(uint256 luckPoolBal);

      // Event to watch BurnTokenBal Updation
      // @param burnTokenBal The current burnTokenBal
      event BurnTokenBalUpdated(uint256 burnTokenBal);




      /**
      * @dev Throws if caller is not timeAlly
      */
      modifier OnlyAllowed() {
        require(msg.sender == timeAlly || msg.sender == timeSwappers,"Only TimeAlly and Timeswapper is authorised");
        _;
      }

          /**
      * @dev Throws if caller is not owner
      */
      modifier OnlyOwner() {
        require(msg.sender == Owner,"Only Owner is authorised");
        _;
      }



      /**
      * @dev Should burn tokens according to the total circulation
      * @return true if success
      */

      function burnTokens() internal returns (bool){
        if(burnTokenBal == 0){
          return true;
        }
        else{
          uint MaxAmount = ((token.totalSupply()).mul(2)).div(100);   // max amount permitted to burn in a month
          if(MaxAmount >= burnTokenBal ){
            token.burn(burnTokenBal);
            burnTokenBal = 0;
          }
          else{
            burnTokenBal = burnTokenBal.sub(MaxAmount);
            token.burn(MaxAmount);
          }
          return true;
        }
      }


      /**
      * @dev To update pool addresses
      * @param  pool - A List of pool addresses
      * Updates if pool address is not already set and if given address is not zero
      * @return true if success
      */

      function UpdateAddresses (address[9] calldata pool) external OnlyOwner  returns(bool){

        if((pool[0] != address(0)) && (newTalentsAndPartnerships == address(0))){
          newTalentsAndPartnerships = pool[0];
          emit PoolAddressAdded( "NewTalentsAndPartnerships", newTalentsAndPartnerships);
        }
        if((pool[1] != address(0)) && (platformMaintenance == address(0))){
          platformMaintenance = pool[1];
          emit PoolAddressAdded( "PlatformMaintenance", platformMaintenance);
        }
        if((pool[2] != address(0)) && (marketingAndRNR == address(0))){
          marketingAndRNR = pool[2];
          emit PoolAddressAdded( "MarketingAndRNR", marketingAndRNR);
        }
        if((pool[3] != address(0)) && (kmPards == address(0))){
          kmPards = pool[3];
          emit PoolAddressAdded( "KmPards", kmPards);
        }
        if((pool[4] != address(0)) && (contingencyFunds == address(0))){
          contingencyFunds = pool[4];
          emit PoolAddressAdded( "ContingencyFunds", contingencyFunds);
        }
        if((pool[5] != address(0)) && (researchAndDevelopment == address(0))){
          researchAndDevelopment = pool[5];
          emit PoolAddressAdded( "ResearchAndDevelopment", researchAndDevelopment);
        }
        if((pool[6] != address(0)) && (powerToken == address(0))){
          powerToken = pool[6];
          emit PoolAddressAdded( "PowerToken", powerToken);
        }
        if((pool[7] != address(0)) && (timeSwappers == address(0))){
          timeSwappers = pool[7];
          emit PoolAddressAdded( "TimeSwapper", timeSwappers);
        }
        if((pool[8] != address(0)) && (timeAlly == address(0))){
          timeAlly = pool[8];
          emit PoolAddressAdded( "TimeAlly", timeAlly);
        }

        return true;
      }


      /**
      * @dev Function to update luckpool balance
      * @param amount Amount to be updated
      */
      function UpdateLuckpool(uint256 amount) external OnlyAllowed returns(bool){
              luckPoolBal = luckPoolBal.add(amount);
        emit LuckPoolUpdated(luckPoolBal);
        return true;
      }

      /**
      * @dev Function to trigger to update  for burning of tokens
      * @param amount Amount to be updated
      */
      function UpdateBurnBal(uint256 amount) external OnlyAllowed returns(bool){
             burnTokenBal = burnTokenBal.add(amount);
        emit BurnTokenBalUpdated(burnTokenBal);
        return true;
      }

      /**
      * @dev To invoke monthly release
      * @return true if success
      */

      function MonthlyNRTRelease() external returns (bool) {
        require(now.sub(lastNRTRelease)> 2629744,"NRT release happens once every month");
        uint256 NRTBal = monthlyNRTAmount.add(luckPoolBal);        // Total NRT available.

        // Calculating NRT to be released to each of the pools
        newTalentsAndPartnershipsBal = (NRTBal.mul(5)).div(100);
        platformMaintenanceBal = (NRTBal.mul(10)).div(100);
        marketingAndRNRBal = (NRTBal.mul(10)).div(100);
        kmPardsBal = (NRTBal.mul(10)).div(100);
        contingencyFundsBal = (NRTBal.mul(10)).div(100);
        researchAndDevelopmentBal = (NRTBal.mul(5)).div(100);

        powerTokenNRT = (NRTBal.mul(10)).div(100);
        timeAllyNRT = (NRTBal.mul(15)).div(100);
        timeSwappersNRT = (NRTBal.mul(25)).div(100);

        // sending tokens to respective wallets and emitting events
        token.mint(newTalentsAndPartnerships,newTalentsAndPartnershipsBal);
        emit NRTTransfer("newTalentsAndPartnerships", newTalentsAndPartnerships, newTalentsAndPartnershipsBal);

        token.mint(platformMaintenance,platformMaintenanceBal);
        emit NRTTransfer("platformMaintenance", platformMaintenance, platformMaintenanceBal);

        token.mint(marketingAndRNR,marketingAndRNRBal);
        emit NRTTransfer("marketingAndRNR", marketingAndRNR, marketingAndRNRBal);

        token.mint(kmPards,kmPardsBal);
        emit NRTTransfer("kmPards", kmPards, kmPardsBal);

        token.mint(contingencyFunds,contingencyFundsBal);
        emit NRTTransfer("contingencyFunds", contingencyFunds, contingencyFundsBal);

        token.mint(researchAndDevelopment,researchAndDevelopmentBal);
        emit NRTTransfer("researchAndDevelopment", researchAndDevelopment, researchAndDevelopmentBal);

        token.mint(powerToken,powerTokenNRT);
        emit NRTTransfer("powerToken", powerToken, powerTokenNRT);

        token.mint(timeAlly,timeAllyNRT);
        TimeAlly timeAllyContract = TimeAlly(timeAlly);
        timeAllyContract.increaseMonth(timeAllyNRT);
        emit NRTTransfer("stakingContract", timeAlly, timeAllyNRT);

        token.mint(timeSwappers,timeSwappersNRT);
        emit NRTTransfer("timeSwappers", timeSwappers, timeSwappersNRT);

        // Reseting NRT
        emit NRTDistributed(NRTBal);
        luckPoolBal = 0;
        lastNRTRelease = lastNRTRelease.add(2629744); // @dev adding seconds according to 1 Year = 365.242 days
        burnTokens();                                 // burning burnTokenBal
        emit TokensBurned(burnTokenBal);


        if(monthCount == 11){
          monthCount = 0;
          annualNRTAmount = (annualNRTAmount.mul(90)).div(100);
          monthlyNRTAmount = annualNRTAmount.div(12);
        }
        else{
          monthCount = monthCount.add(1);
        }
        return true;
      }


    /**
    * @dev Constructor
    */

    constructor(address eraswaptoken) public{
      token = Eraswap(eraswaptoken);
      lastNRTRelease = now;
      annualNRTAmount = 819000000000000000000000000;
      monthlyNRTAmount = annualNRTAmount.div(uint256(12));
      monthCount = 0;
      Owner = msg.sender;
    }

}

pragma solidity ^0.5.2;

import "./PauserRole.sol";

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is PauserRole {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    constructor () internal {
        _paused = false;
    }

    /**
     * @return true if the contract is paused, false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!_paused);
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(_paused);
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() public onlyPauser whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() public onlyPauser whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

pragma solidity ^0.5.2;

import "./Roles.sol";

contract PauserRole {
    using Roles for Roles.Role;

    event PauserAdded(address indexed account);
    event PauserRemoved(address indexed account);

    Roles.Role private _pausers;

    constructor () internal {
        _addPauser(msg.sender);
    }

    modifier onlyPauser() {
        require(isPauser(msg.sender));
        _;
    }

    function isPauser(address account) public view returns (bool) {
        return _pausers.has(account);
    }

    function addPauser(address account) public onlyPauser {
        _addPauser(account);
    }

    function renouncePauser() public {
        _removePauser(msg.sender);
    }

    function _addPauser(address account) internal {
        _pausers.add(account);
        emit PauserAdded(account);
    }

    function _removePauser(address account) internal {
        _pausers.remove(account);
        emit PauserRemoved(account);
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

pragma solidity 0.5.10;

import './SafeMath.sol';
import './Eraswap.sol';
import './NRTManager.sol';

/*

Potential bugs: this contract is designed assuming NRT Release will happen every month.
There might be issues when the NRT scheduled
- added stakingMonth property in Staking struct

fix withdraw fractionFrom15 luck pool
- done

add loanactive contition to take loan
- done

ensure stakingMonth in the struct is being used every where instead of calculation
- done

remove local variables uncesessary

final the earthSecondsInMonth amount in TimeAlly as well in NRT

add events for required functions
*/

/// @author The EraSwap Team
/// @title TimeAlly Smart Contract
/// @dev all require statement message strings are commented to make contract deployable by lower the deploying gas fee
contract TimeAlly {
    using SafeMath for uint256;

    struct Staking {
        uint256 exaEsAmount;
        uint256 timestamp;
        uint256 stakingMonth;
        uint256 stakingPlanId;
        uint256 status; /// @dev 1 => active; 2 => loaned; 3 => withdrawed; 4 => cancelled; 5 => nomination mode
        uint256 loanId;
        uint256 totalNominationShares;
        mapping (uint256 => bool) isMonthClaimed;
        mapping (address => uint256) nomination;
    }

    struct StakingPlan {
        uint256 months;
        uint256 fractionFrom15; /// @dev fraction of NRT released. Alotted to TimeAlly is 15% of NRT
        // bool isPlanActive; /// @dev when plan is inactive, new stakings must not be able to select this plan. Old stakings which already selected this plan will continue themselves as per plan.
        bool isUrgentLoanAllowed; /// @dev if urgent loan is not allowed then staker can take loan only after 75% (hard coded) of staking months
    }

    struct Loan {
        uint256 exaEsAmount;
        uint256 timestamp;
        uint256 loanPlanId;
        uint256 status; // @dev 1 => not repayed yet; 2 => repayed
        uint256[] stakingIds;
    }

    struct LoanPlan {
        uint256 loanMonths;
        uint256 loanRate; // @dev amount of charge to pay, this will be sent to luck pool
        uint256 maxLoanAmountPercent; /// @dev max loan user can take depends on this percent of the plan and the stakings user wishes to put for the loan
    }

    uint256 public deployedTimestamp;
    address public owner;
    Eraswap public token;
    NRTManager public nrtManager;

    /// @dev 1 Year = 365.242 days for taking care of leap years
    uint256 public earthSecondsInMonth = 2629744;
    // uint256 earthSecondsInMonth = 30 * 12 * 60 * 60; /// @dev there was a decision for following 360 day year

    StakingPlan[] public stakingPlans;
    LoanPlan[] public loanPlans;

    // user activity details:
    mapping(address => Staking[]) public stakings;
    mapping(address => Loan[]) public loans;
    mapping(address => uint256) public launchReward;

    /// @dev TimeAlly month to exaEsAmount mapping.
    mapping (uint256 => uint256) public totalActiveStakings;

    /// @notice NRT being received from NRT Manager every month is stored in this array
    /// @dev current month is the length of this array
    uint256[] public timeAllyMonthlyNRT;

    event NewStaking (
        address indexed _userAddress,
        uint256 indexed _stakePlanId,
        uint256 _exaEsAmount,
        uint256 _stakingId
    );

    event PrincipalWithdrawl (
        address indexed _userAddress,
        uint256 _stakingId
    );

    event NomineeNew (
        address indexed _userAddress,
        uint256 indexed _stakingId,
        address indexed _nomineeAddress
    );

    event NomineeWithdraw (
        address indexed _userAddress,
        uint256 indexed _stakingId,
        address indexed _nomineeAddress,
        uint256 _liquid,
        uint256 _accrued
    );

    event BenefitWithdrawl (
        address indexed _userAddress,
        uint256 _stakingId,
        uint256[] _months,
        uint256 _halfBenefit
    );

    event NewLoan (
        address indexed _userAddress,
        uint256 indexed _loanPlanId,
        uint256 _exaEsAmount,
        uint256 _loanInterest,
        uint256 _loanId
    );

    event RepayLoan (
        address indexed _userAddress,
        uint256 _loanId
    );


    modifier onlyNRTManager() {
        require(
          msg.sender == address(nrtManager)
          // , 'only NRT manager can call'
        );
        _;
    }

    modifier onlyOwner() {
        require(
          msg.sender == owner
          // , 'only deployer can call'
        );
        _;
    }

    /// @notice sets up TimeAlly contract when deployed
    /// @param _tokenAddress - is EraSwap contract address
    /// @param _nrtAddress - is NRT Manager contract address
    constructor(address _tokenAddress, address _nrtAddress) public {
        owner = msg.sender;
        token = Eraswap(_tokenAddress);
        nrtManager = NRTManager(_nrtAddress);
        deployedTimestamp = now;
        timeAllyMonthlyNRT.push(0); /// @dev first month there is no NRT released
    }

    /// @notice this function is used by NRT manager to communicate NRT release to TimeAlly
    function increaseMonth(uint256 _timeAllyNRT) public onlyNRTManager {
        timeAllyMonthlyNRT.push(_timeAllyNRT);
    }

    /// @notice TimeAlly month is dependent on the monthly NRT release
    /// @return current month is the TimeAlly month
    function getCurrentMonth() public view returns (uint256) {
        return timeAllyMonthlyNRT.length - 1;
    }

    /// @notice this function is used by owner to create plans for new stakings
    /// @param _months - is number of staking months of a plan. for eg. 12 months
    /// @param _fractionFrom15 - NRT fraction (max 15%) benefit to be given to user. rest is sent back to NRT in Luck Pool
    /// @param _isUrgentLoanAllowed - if urgent loan is not allowed then staker can take loan only after 75% of time elapsed
    function createStakingPlan(uint256 _months, uint256 _fractionFrom15, bool _isUrgentLoanAllowed) public onlyOwner {
        stakingPlans.push(StakingPlan({
            months: _months,
            fractionFrom15: _fractionFrom15,
            // isPlanActive: true,
            isUrgentLoanAllowed: _isUrgentLoanAllowed
        }));
    }

    /// @notice this function is used by owner to create plans for new loans
    /// @param _loanMonths - number of months or duration of loan, loan taker must repay the loan before this period
    /// @param _loanRate - this is total % of loaning amount charged while taking loan, this charge is sent to luckpool in NRT manager which ends up distributed back to the community again
    function createLoanPlan(uint256 _loanMonths, uint256 _loanRate, uint256 _maxLoanAmountPercent) public onlyOwner {
        require(_maxLoanAmountPercent <= 100
            // , 'everyone should not be able to take loan more than 100 percent of their stakings'
        );
        loanPlans.push(LoanPlan({
            loanMonths: _loanMonths,
            loanRate: _loanRate,
            maxLoanAmountPercent: _maxLoanAmountPercent
        }));
    }



    /// @notice takes ES from user and locks it for a time according to plan selected by user
    /// @param _exaEsAmount - amount of ES tokens (in 18 decimals thats why 'exa') that user wishes to stake
    /// @param _stakingPlanId - plan for staking
    function newStaking(uint256 _exaEsAmount, uint256 _stakingPlanId) public {

        /// @dev 0 ES stakings would get 0 ES benefits and might cause confusions as transaction would confirm but total active stakings will not increase
        require(_exaEsAmount > 0
            // , 'staking amount should be non zero'
        );

        require(token.transferFrom(msg.sender, address(this), _exaEsAmount)
          // , 'could not transfer tokens'
        );
        uint256 stakeEndMonth = getCurrentMonth() + stakingPlans[_stakingPlanId].months;

        // @dev update the totalActiveStakings array so that staking would be automatically inactive after the stakingPlanMonthhs
        for(
          uint256 month = getCurrentMonth() + 1;
          month <= stakeEndMonth;
          month++
        ) {
            totalActiveStakings[month] = totalActiveStakings[month].add(_exaEsAmount);
        }

        stakings[msg.sender].push(Staking({
            exaEsAmount: _exaEsAmount,
            timestamp: now,
            stakingMonth: getCurrentMonth(),
            stakingPlanId: _stakingPlanId,
            status: 1,
            loanId: 0,
            totalNominationShares: 0
        }));

        emit NewStaking(msg.sender, _stakingPlanId, _exaEsAmount, stakings[msg.sender].length - 1);
    }

    /// @notice this function is used to see total stakings of any user of TimeAlly
    /// @param _userAddress - address of user
    /// @return number of stakings of _userAddress
    function getNumberOfStakingsByUser(address _userAddress) public view returns (uint256) {
        return stakings[_userAddress].length;
    }

    /// @notice this function is used to topup reward balance in smart contract. Rewards are transferable. Anyone with reward balance can only claim it as a new staking.
    /// @dev Allowance is required before topup.
    /// @param _exaEsAmount - amount to add to your rewards for sending rewards to others
    function topupRewardBucket(uint256 _exaEsAmount) public {
        require(token.transferFrom(msg.sender, address(this), _exaEsAmount));
        launchReward[msg.sender] = launchReward[msg.sender].add(_exaEsAmount);
    }

    /// @notice this function is used to send rewards to multiple users
    /// @param _addresses - array of address to send rewards
    /// @param _exaEsAmountArray - array of ExaES amounts sent to each address of _addresses with same index
    function giveLaunchReward(address[] memory _addresses, uint256[] memory _exaEsAmountArray) public onlyOwner {
        for(uint256 i = 0; i < _addresses.length; i++) {
            launchReward[msg.sender] = launchReward[msg.sender].sub(_exaEsAmountArray[i]);
            launchReward[_addresses[i]] = launchReward[_addresses[i]].add(_exaEsAmountArray[i]);
        }
    }

    /// @notice this function is used by rewardees to claim their accrued rewards. This is also used by stakers to restake their 50% benefit received as rewards
    /// @param _stakingPlanId - rewardee can choose plan while claiming rewards as stakings
    function claimLaunchReward(uint256 _stakingPlanId) public {
        // require(stakingPlans[_stakingPlanId].isPlanActive
        //     // , 'selected plan is not active'
        // );

        require(launchReward[msg.sender] > 0
            // , 'launch reward should be non zero'
        );
        uint256 reward = launchReward[msg.sender];
        launchReward[msg.sender] = 0;

        // @dev logic similar to newStaking function
        uint256 stakeEndMonth = getCurrentMonth() + stakingPlans[_stakingPlanId].months;

        // @dev update the totalActiveStakings array so that staking would be automatically inactive after the stakingPlanMonthhs
        for(
          uint256 month = getCurrentMonth() + 1;
          month <= stakeEndMonth;
          month++
        ) {
            totalActiveStakings[month] = totalActiveStakings[month].add(reward); /// @dev reward means locked ES which only staking option
        }

        stakings[msg.sender].push(Staking({
            exaEsAmount: reward,
            timestamp: now,
            stakingMonth: getCurrentMonth(),
            stakingPlanId: _stakingPlanId,
            status: 1,
            loanId: 0,
            totalNominationShares: 0
        }));

        emit NewStaking(msg.sender, _stakingPlanId, reward, stakings[msg.sender].length - 1);
    }


    /// @notice used internally to see if staking is active or not. does not include if staking is claimed.
    /// @param _userAddress - address of user
    /// @param _stakingId - staking id
    /// @param _atMonth - particular month to check staking active
    /// @return true is staking is in correct time frame and also no loan on it
    function isStakingActive(
        address _userAddress,
        uint256 _stakingId,
        uint256 _atMonth
    ) public view returns (bool) {
        //uint256 stakingMonth = stakings[_userAddress][_stakingId].timestamp.sub(deployedTimestamp).div(earthSecondsInMonth);

        return (
            /// @dev _atMonth should be a month after which staking starts
            stakings[_userAddress][_stakingId].stakingMonth + 1 <= _atMonth

            /// @dev _atMonth should be a month before which staking ends
            && stakings[_userAddress][_stakingId].stakingMonth + stakingPlans[ stakings[_userAddress][_stakingId].stakingPlanId ].months >= _atMonth

            /// @dev staking should have active status
            && stakings[_userAddress][_stakingId].status == 1

            /// @dev if _atMonth is current Month, then withdrawal should be allowed only after 30 days interval since staking
            && (
              getCurrentMonth() != _atMonth
              || now >= stakings[_userAddress][_stakingId].timestamp
                          .add(
                            getCurrentMonth()
                              .sub(stakings[_userAddress][_stakingId].stakingMonth)
                              .mul(earthSecondsInMonth)
                          )
              )
            );
    }


    /// @notice this function is used for seeing the benefits of a staking of any user
    /// @param _userAddress - address of user
    /// @param _stakingId - staking id
    /// @param _months - array of months user is interested to see benefits.
    /// @return amount of ExaES of benefits of entered months
    function seeBenefitOfAStakingByMonths(
        address _userAddress,
        uint256 _stakingId,
        uint256[] memory _months
    ) public view returns (uint256) {
        uint256 benefitOfAllMonths;
        for(uint256 i = 0; i < _months.length; i++) {
            /// @dev this require statement is converted into if statement for easier UI fetching. If there is no benefit for a month or already claimed, it will consider benefit of that month as 0 ES. But same is not done for withdraw function.
            // require(
            //   isStakingActive(_userAddress, _stakingId, _months[i])
            //   && !stakings[_userAddress][_stakingId].isMonthClaimed[_months[i]]
            //   // , 'staking must be active'
            // );
            if(isStakingActive(_userAddress, _stakingId, _months[i])
            && !stakings[_userAddress][_stakingId].isMonthClaimed[_months[i]]) {
                uint256 benefit = stakings[_userAddress][_stakingId].exaEsAmount
                                  .mul(timeAllyMonthlyNRT[ _months[i] ])
                                  .div(totalActiveStakings[ _months[i] ]);
                benefitOfAllMonths = benefitOfAllMonths.add(benefit);
            }
        }
        return benefitOfAllMonths.mul(
          stakingPlans[stakings[_userAddress][_stakingId].stakingPlanId].fractionFrom15
        ).div(15);
    }

    /// @notice this function is used for withdrawing the benefits of a staking of any user
    /// @param _stakingId - staking id
    /// @param _months - array of months user is interested to withdraw benefits of staking.
    function withdrawBenefitOfAStakingByMonths(
        uint256 _stakingId,
        uint256[] memory _months
    ) public {
        uint256 _benefitOfAllMonths;
        for(uint256 i = 0; i < _months.length; i++) {
            // require(
            //   isStakingActive(msg.sender, _stakingId, _months[i])
            //   && !stakings[msg.sender][_stakingId].isMonthClaimed[_months[i]]
            //   // , 'staking must be active'
            // );
            if(isStakingActive(msg.sender, _stakingId, _months[i])
            && !stakings[msg.sender][_stakingId].isMonthClaimed[_months[i]]) {
                uint256 _benefit = stakings[msg.sender][_stakingId].exaEsAmount
                                  .mul(timeAllyMonthlyNRT[ _months[i] ])
                                  .div(totalActiveStakings[ _months[i] ]);

                _benefitOfAllMonths = _benefitOfAllMonths.add(_benefit);
                stakings[msg.sender][_stakingId].isMonthClaimed[_months[i]] = true;
            }
        }

        uint256 _luckPool = _benefitOfAllMonths
                        .mul( uint256(15).sub(stakingPlans[stakings[msg.sender][_stakingId].stakingPlanId].fractionFrom15) )
                        .div( 15 );

        require( token.transfer(address(nrtManager), _luckPool) );
        require( nrtManager.UpdateLuckpool(_luckPool) );

        _benefitOfAllMonths = _benefitOfAllMonths.sub(_luckPool);

        uint256 _halfBenefit = _benefitOfAllMonths.div(2);
        require( token.transfer(msg.sender, _halfBenefit) );

        launchReward[msg.sender] = launchReward[msg.sender].add(_halfBenefit);

        // emit event
        emit BenefitWithdrawl(msg.sender, _stakingId, _months, _halfBenefit);
    }


    /// @notice this function is used to withdraw the principle amount of multiple stakings which have their tenure completed
    /// @param _stakingIds - input which stakings to withdraw
    function withdrawExpiredStakings(uint256[] memory _stakingIds) public {
        for(uint256 i = 0; i < _stakingIds.length; i++) {
            require(now >= stakings[msg.sender][_stakingIds[i]].timestamp
                    .add(stakingPlans[ stakings[msg.sender][_stakingIds[i]].stakingPlanId ].months.mul(earthSecondsInMonth))
              // , 'cannot withdraw before staking ends'
            );
            stakings[msg.sender][_stakingIds[i]].status = 3;

            token.transfer(msg.sender, stakings[msg.sender][_stakingIds[i]].exaEsAmount);

            emit PrincipalWithdrawl(msg.sender, _stakingIds[i]);
        }
    }

    /// @notice this function is used to estimate the maximum amount of loan that any user can take with their stakings
    /// @param _userAddress - address of user
    /// @param _stakingIds - array of staking ids which should be used to estimate max loan amount
    /// @param _loanPlanId - the loan plan user wishes to take loan.
    /// @return max loaning amount
    function seeMaxLoaningAmountOnUserStakings(address _userAddress, uint256[] memory _stakingIds, uint256 _loanPlanId) public view returns (uint256) {
        uint256 _currentMonth = getCurrentMonth();
        //require(_currentMonth >= _atMonth, 'cannot see future stakings');

        uint256 userStakingsExaEsAmount;

        for(uint256 i = 0; i < _stakingIds.length; i++) {

            if(isStakingActive(_userAddress, _stakingIds[i], _currentMonth)
                && (
                  // @dev if urgent loan is not allowed then loan can be taken only after staking period is completed 75%
                  stakingPlans[ stakings[_userAddress][_stakingIds[i]].stakingPlanId ].isUrgentLoanAllowed
                  || now > stakings[_userAddress][_stakingIds[i]].timestamp + stakingPlans[ stakings[_userAddress][_stakingIds[i]].stakingPlanId ].months.mul(earthSecondsInMonth).mul(75).div(100)
                )
            ) {
                userStakingsExaEsAmount = userStakingsExaEsAmount
                    .add(stakings[_userAddress][_stakingIds[i]].exaEsAmount
                      .mul(loanPlans[_loanPlanId].maxLoanAmountPercent)
                      .div(100)
                      // .mul(stakingPlans[ stakings[_userAddress][_stakingIds[i]].stakingPlanId ].fractionFrom15)
                      // .div(15)
                    );
            }
        }

        return userStakingsExaEsAmount;
            //.mul( uint256(100).sub(loanPlans[_loanPlanId].loanRate) ).div(100);
    }

    /// @notice this function is used to take loan on multiple stakings
    /// @param _loanPlanId - user can select this plan which defines loan duration and loan interest
    /// @param _exaEsAmount - loan amount, this will also be the loan repay amount, the interest will first be deducted from this and then amount will be credited
    /// @param _stakingIds - staking ids user wishes to encash for taking the loan
    function takeLoanOnSelfStaking(uint256 _loanPlanId, uint256 _exaEsAmount, uint256[] memory _stakingIds) public {
        // @dev when loan is to be taken, first calculate active stakings from given stakings array. this way we can get how much loan user can take and simultaneously mark stakings as claimed for next months number loan period
        uint256 _currentMonth = getCurrentMonth();
        uint256 _userStakingsExaEsAmount;

        for(uint256 i = 0; i < _stakingIds.length; i++) {

            if( isStakingActive(msg.sender, _stakingIds[i], _currentMonth)
                && (
                  // @dev if urgent loan is not allowed then loan can be taken only after staking period is completed 75%
                  stakingPlans[ stakings[msg.sender][_stakingIds[i]].stakingPlanId ].isUrgentLoanAllowed
                  || now > stakings[msg.sender][_stakingIds[i]].timestamp + stakingPlans[ stakings[msg.sender][_stakingIds[i]].stakingPlanId ].months.mul(earthSecondsInMonth).mul(75).div(100)
                )
            ) {

                // @dev store sum in a number
                _userStakingsExaEsAmount = _userStakingsExaEsAmount
                    .add(
                        stakings[msg.sender][ _stakingIds[i] ].exaEsAmount
                          .mul(loanPlans[_loanPlanId].maxLoanAmountPercent)
                          .div(100)
                );

                // @dev subtract total active stakings
                uint256 stakingStartMonth = stakings[msg.sender][_stakingIds[i]].stakingMonth;

                uint256 stakeEndMonth = stakingStartMonth + stakingPlans[stakings[msg.sender][_stakingIds[i]].stakingPlanId].months;

                for(uint256 j = _currentMonth + 1; j <= stakeEndMonth; j++) {
                    totalActiveStakings[j] = totalActiveStakings[j].sub(_userStakingsExaEsAmount);
                }

                // @dev make stakings inactive
                for(uint256 j = 1; j <= loanPlans[_loanPlanId].loanMonths; j++) {
                    stakings[msg.sender][ _stakingIds[i] ].isMonthClaimed[ _currentMonth + j ] = true;
                    stakings[msg.sender][ _stakingIds[i] ].status = 2; // means in loan
                }
            }
        }

        uint256 _maxLoaningAmount = _userStakingsExaEsAmount;

        if(_exaEsAmount > _maxLoaningAmount) {
            require(false
              // , 'cannot loan more than maxLoaningAmount'
            );
        }


        uint256 _loanInterest = _exaEsAmount.mul(loanPlans[_loanPlanId].loanRate).div(100);
        uint256 _loanAmountToTransfer = _exaEsAmount.sub(_loanInterest);

        require( token.transfer(address(nrtManager), _loanInterest) );
        require( nrtManager.UpdateLuckpool(_loanInterest) );

        loans[msg.sender].push(Loan({
            exaEsAmount: _exaEsAmount,
            timestamp: now,
            loanPlanId: _loanPlanId,
            status: 1,
            stakingIds: _stakingIds
        }));

        // @dev send user amount
        require( token.transfer(msg.sender, _loanAmountToTransfer) );

        emit NewLoan(msg.sender, _loanPlanId, _exaEsAmount, _loanInterest, loans[msg.sender].length - 1);
    }

    /// @notice repay loan functionality
    /// @dev need to give allowance before this
    /// @param _loanId - select loan to repay
    function repayLoanSelf(uint256 _loanId) public {
        require(loans[msg.sender][_loanId].status == 1
          // , 'can only repay pending loans'
        );

        require(loans[msg.sender][_loanId].timestamp + loanPlans[ loans[msg.sender][_loanId].loanPlanId ].loanMonths.mul(earthSecondsInMonth) > now
          // , 'cannot repay expired loan'
        );

        require(token.transferFrom(msg.sender, address(this), loans[msg.sender][_loanId].exaEsAmount)
          // , 'cannot receive enough tokens, please check if allowance is there'
        );

        loans[msg.sender][_loanId].status = 2;

        // @dev get all stakings associated with this loan. and set next unclaimed months. then set status to 1 and also add to totalActiveStakings
        for(uint256 i = 0; i < loans[msg.sender][_loanId].stakingIds.length; i++) {
            uint256 _stakingId = loans[msg.sender][_loanId].stakingIds[i];

            stakings[msg.sender][_stakingId].status = 1;

            uint256 stakingStartMonth = stakings[msg.sender][_stakingId].timestamp.sub(deployedTimestamp).div(earthSecondsInMonth);

            uint256 stakeEndMonth = stakingStartMonth + stakingPlans[stakings[msg.sender][_stakingId].stakingPlanId].months;

            for(uint256 j = getCurrentMonth() + 1; j <= stakeEndMonth; j++) {
                stakings[msg.sender][_stakingId].isMonthClaimed[i] = false;

                totalActiveStakings[j] = totalActiveStakings[j].add(stakings[msg.sender][_stakingId].exaEsAmount);
            }
        }
        // add repay event
        emit RepayLoan(msg.sender, _loanId);
    }

    function burnDefaultedLoans(address[] memory _addressArray, uint256[] memory _loanIdArray) public {
        uint256 _amountToBurn;
        for(uint256 i = 0; i < _addressArray.length; i++) {
            require(
                loans[ _addressArray[i] ][ _loanIdArray[i] ].status == 1
                // , 'loan should not be repayed'
            );
            require(
                now >
                loans[ _addressArray[i] ][ _loanIdArray[i] ].timestamp
                + loanPlans[ loans[ _addressArray[i] ][ _loanIdArray[i] ].loanPlanId ].loanMonths.mul(earthSecondsInMonth)
                // , 'loan should have crossed its loan period'
            );
            uint256[] storage _stakingIdsOfLoan = loans[ _addressArray[i] ][ _loanIdArray[i] ].stakingIds;

            /// @dev add staking amounts of all stakings on which loan is taken
            for(uint256 j = 0; j < _stakingIdsOfLoan.length; j++) {
                _amountToBurn = _amountToBurn.add(
                    stakings[ _addressArray[i] ][ _stakingIdsOfLoan[j] ].exaEsAmount
                );
            }
            /// @dev sub loan amount
            _amountToBurn = _amountToBurn.sub(
                loans[ _addressArray[i] ][ _loanIdArray[i] ].exaEsAmount
            );
        }
        require(token.transfer(address(nrtManager), _amountToBurn));
        require(nrtManager.UpdateBurnBal(_amountToBurn));

        // emit event
    }

    /// @notice this function is used to add nominee to a staking
    /// @param _stakingId - staking id
    /// @param _nomineeAddress - address of nominee to be added to staking
    /// @param _shares - amount of shares of the staking to the nominee
    /// @dev shares is compared with total shares issued in a staking to see the percent nominee can withdraw. Nominee can withdraw only after one year past the end of tenure of staking. Upto 1 year past the end of tenure of staking, owner can withdraw principle amount of staking as well as can CRUD nominees. Owner of staking is has this time to withdraw their staking, if they fail to do so, after that nominees are allowed to withdraw. Withdrawl by first nominee will trigger staking into nomination mode and owner of staking cannot withdraw the principle amount as it will be distributed with only nominees and only they can withdraw it.
    function addNominee(uint256 _stakingId, address _nomineeAddress, uint256 _shares) public {
        require(stakings[msg.sender][_stakingId].status == 1
          // , 'staking should active'
        );
        require(stakings[msg.sender][_stakingId].nomination[_nomineeAddress] == 0
          // , 'should not be nominee already'
        );
        stakings[msg.sender][_stakingId].totalNominationShares = stakings[msg.sender][_stakingId].totalNominationShares.add(_shares);
        stakings[msg.sender][_stakingId].nomination[_nomineeAddress] = _shares;
        emit NomineeNew(msg.sender, _stakingId, _nomineeAddress);
    }

    /// @notice this function is used to read the nomination of a nominee address of a staking of a user
    /// @param _userAddress - address of staking owner
    /// @param _stakingId - staking id
    /// @param _nomineeAddress - address of nominee
    /// @return nomination of the nominee
    function viewNomination(address _userAddress, uint256 _stakingId, address _nomineeAddress) public view returns (uint256) {
        return stakings[_userAddress][_stakingId].nomination[_nomineeAddress];
    }

    // /// @notice this function is used to update nomination of a nominee of sender's staking
    // /// @param _stakingId - staking id
    // /// @param _nomineeAddress - address of nominee
    // /// @param _shares - shares to be updated for the nominee
    // function updateNominee(uint256 _stakingId, address _nomineeAddress, uint256 _shares) public {
    //     require(stakings[msg.sender][_stakingId].status == 1
    //       // , 'staking should active'
    //     );
    //     uint256 _oldShares = stakings[msg.sender][_stakingId].nomination[_nomineeAddress];
    //     if(_shares > _oldShares) {
    //         uint256 _diff = _shares.sub(_oldShares);
    //         stakings[msg.sender][_stakingId].totalNominationShares = stakings[msg.sender][_stakingId].totalNominationShares.add(_diff);
    //         stakings[msg.sender][_stakingId].nomination[_nomineeAddress] = stakings[msg.sender][_stakingId].nomination[_nomineeAddress].add(_diff);
    //     } else if(_shares < _oldShares) {
    //       uint256 _diff = _oldShares.sub(_shares);
    //         stakings[msg.sender][_stakingId].nomination[_nomineeAddress] = stakings[msg.sender][_stakingId].nomination[_nomineeAddress].sub(_diff);
    //         stakings[msg.sender][_stakingId].totalNominationShares = stakings[msg.sender][_stakingId].totalNominationShares.sub(_diff);
    //     }
    // }

    /// @notice this function is used to remove nomination of a address
    /// @param _stakingId - staking id
    /// @param _nomineeAddress - address of nominee
    function removeNominee(uint256 _stakingId, address _nomineeAddress) public {
        require(stakings[msg.sender][_stakingId].status == 1, 'staking should active');
        uint256 _oldShares = stakings[msg.sender][_stakingId].nomination[msg.sender];
        stakings[msg.sender][_stakingId].nomination[_nomineeAddress] = 0;
        stakings[msg.sender][_stakingId].totalNominationShares = stakings[msg.sender][_stakingId].totalNominationShares.sub(_oldShares);
    }

    /// @notice this function is used by nominee to withdraw their share of a staking after 1 year of the end of tenure of staking
    /// @param _userAddress - address of user
    /// @param _stakingId - staking id
    function nomineeWithdraw(address _userAddress, uint256 _stakingId) public {
        // end time stamp > 0
        uint256 currentTime = now;
        require( currentTime > (stakings[_userAddress][_stakingId].timestamp
                    + stakingPlans[stakings[_userAddress][_stakingId].stakingPlanId].months * earthSecondsInMonth
                    + 12 * earthSecondsInMonth )
                    // , 'cannot nominee withdraw before '
            );

        uint256 _nomineeShares = stakings[_userAddress][_stakingId].nomination[msg.sender];
        require(_nomineeShares > 0
          // , 'Not a nominee of this staking'
        );

        //uint256 _totalShares = ;

        // set staking to nomination mode if it isn't.
        if(stakings[_userAddress][_stakingId].status != 5) {
            stakings[_userAddress][_stakingId].status = 5;
        }

        // adding principal account
        uint256 _pendingLiquidAmountInStaking = stakings[_userAddress][_stakingId].exaEsAmount;
        uint256 _pendingAccruedAmountInStaking;

        // uint256 _stakingStartMonth = stakings[_userAddress][_stakingId].timestamp.sub(deployedTimestamp).div(earthSecondsInMonth);
        uint256 _stakeEndMonth = stakings[_userAddress][_stakingId].stakingMonth + stakingPlans[stakings[_userAddress][_stakingId].stakingPlanId].months;

        // adding monthly benefits which are not claimed
        for(
          uint256 i = stakings[_userAddress][_stakingId].stakingMonth; //_stakingStartMonth;
          i < _stakeEndMonth;
          i++
        ) {
            if( stakings[_userAddress][_stakingId].isMonthClaimed[i] ) {
                uint256 _effectiveAmount = stakings[_userAddress][_stakingId].exaEsAmount
                  .mul(stakingPlans[stakings[_userAddress][_stakingId].stakingPlanId].fractionFrom15)
                  .div(15);
                uint256 _monthlyBenefit = _effectiveAmount
                                          .mul(timeAllyMonthlyNRT[i])
                                          .div(totalActiveStakings[i]);
                _pendingLiquidAmountInStaking = _pendingLiquidAmountInStaking.add(_monthlyBenefit.div(2));
                _pendingAccruedAmountInStaking = _pendingAccruedAmountInStaking.add(_monthlyBenefit.div(2));
            }
        }

        // now we have _pendingLiquidAmountInStaking && _pendingAccruedAmountInStaking
        // on which user's share will be calculated and sent

        // marking nominee as claimed by removing his shares
        stakings[_userAddress][_stakingId].nomination[msg.sender] = 0;

        uint256 _nomineeLiquidShare = _pendingLiquidAmountInStaking
                                        .mul(_nomineeShares)
                                        .div(stakings[_userAddress][_stakingId].totalNominationShares);
        token.transfer(msg.sender, _nomineeLiquidShare);

        uint256 _nomineeAccruedShare = _pendingAccruedAmountInStaking
                                          .mul(_nomineeShares)
                                          .div(stakings[_userAddress][_stakingId].totalNominationShares);
        launchReward[msg.sender] = launchReward[msg.sender].add(_nomineeAccruedShare);

        // emit a event
        emit NomineeWithdraw(_userAddress, _stakingId, msg.sender, _nomineeLiquidShare, _nomineeAccruedShare);
    }
}


pragma solidity ^0.5.2;

import "./ERC20Capped.sol";
import "./ERC20Burnable.sol";
import "./ERC20Detailed.sol";
import "./ERC20Pausable.sol";


contract Eraswap is ERC20Detailed,ERC20Burnable,ERC20Capped,ERC20Pausable {


    event NRTManagerAdded(address NRTManager);

    constructor()
        public
         ERC20Detailed ("Era Swap", "ES", 18) ERC20Capped(9100000000000000000000000000) {
             mint(msg.sender, 910000000000000000000000000);
        }

    int256 public timeMachineDepth;


    // gives the time machine time
    function mou() public view returns(uint256) {
        if(timeMachineDepth < 0) {
            return now - uint256(timeMachineDepth);
        } else {
            return now + uint256(timeMachineDepth);
        }
    }

    // sets the time machine depth
    function setTimeMachineDepth(int256 _timeMachineDepth) public {
        timeMachineDepth = _timeMachineDepth;
    }

    function goToFuture(uint256 _seconds) public {
        timeMachineDepth += int256(_seconds);
    }

    function goToPast(uint256 _seconds) public {
        timeMachineDepth -= int256(_seconds);
    }


    /**
    * @dev Function to add NRT Manager to have minting rights
    * It will transfer the minting rights to NRTManager and revokes it from existing minter
    * @param NRTManager Address of NRT Manager C ontract
    */
    function AddNRTManager(address NRTManager) public onlyMinter returns (bool) {
        addMinter(NRTManager);
        addPauser(NRTManager);
        renounceMinter();
        renouncePauser();
        emit NRTManagerAdded(NRTManager);
        return true;
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

import "./ERC20.sol";
import "./Pausable.sol";

/**
 * @title Pausable token
 * @dev ERC20 modified with pausable transfers.
 */
contract ERC20Pausable is ERC20, Pausable {
    function transfer(address to, uint256 value) public whenNotPaused returns (bool) {
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public whenNotPaused returns (bool) {
        return super.transferFrom(from, to, value);
    }

    function approve(address spender, uint256 value) public whenNotPaused returns (bool) {
        return super.approve(spender, value);
    }

    function increaseAllowance(address spender, uint addedValue) public whenNotPaused returns (bool success) {
        return super.increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint subtractedValue) public whenNotPaused returns (bool success) {
        return super.decreaseAllowance(spender, subtractedValue);
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

import "./Eraswap.sol";
import "./TimeAlly.sol";


contract NRTManager {

    using SafeMath for uint256;

    uint256 public lastNRTRelease;              // variable to store last release date
    uint256 public monthlyNRTAmount;            // variable to store Monthly NRT amount to be released
    uint256 public annualNRTAmount;             // variable to store Annual NRT amount to be released
    uint256 public monthCount;                  // variable to store the count of months from the intial date
    uint256 public luckPoolBal;                 // Luckpool Balance
    uint256 public burnTokenBal;                // tokens to be burned
    Eraswap token;
    address Owner;
    //Eraswap public eraswapToken;

    // different pool address
    address public newTalentsAndPartnerships = 0xb4024468D052B36b6904a47541dDE69E44594607;
    address public platformMaintenance = 0x922a2d6B0B2A24779B0623452AdB28233B456D9c;
    address public marketingAndRNR = 0xDFBC0aE48f3DAb5b0A1B154849Ee963430AA0c3E;
    address public kmPards = 0x4881964ac9AD9480585425716A8708f0EE66DA88;
    address public contingencyFunds = 0xF4E731a107D7FFb2785f696543dE8BF6EB558167;
    address public researchAndDevelopment = 0xb209B4cec04cE9C0E1Fa741dE0a8566bf70aDbe9;
    address public powerToken = 0xbc24BfAC401860ce536aeF9dE10EF0104b09f657;
    address public timeSwappers = 0x4b65109E11CF0Ff8fA58A7122a5E84e397C6Ceb8;                 // which include powerToken , curators ,timeTraders , daySwappers
    address public timeAlly;   /// @dev address of timeAlly Contract set when called UpdateAddresses function on this contract


    uint256 public newTalentsAndPartnershipsBal; // variable to store last NRT released to the address;
    uint256 public platformMaintenanceBal;       // variable to store last NRT released to the address;
    uint256 public marketingAndRNRBal;           // variable to store last NRT released to the address;
    uint256 public kmPardsBal;                   // variable to store last NRT released to the address;
    uint256 public contingencyFundsBal;          // variable to store last NRT released to the address;
    uint256 public researchAndDevelopmentBal;    // variable to store last NRT released to the address;
    uint256 public powerTokenNRT;                  // variable to store last NRT released to the address;
    uint256 public timeAllyNRT;                   // variable to store last NRT released to the address;
    uint256 public timeSwappersNRT;              // variable to store last NRT released to the address;


      // Event to watch NRT distribution
      // @param NRTReleased The amount of NRT released in the month
      event NRTDistributed(uint256 NRTReleased);

      /**
      * Event to watch Transfer of NRT to different Pool
      * @param pool - The pool name
      * @param sendAddress - The address of pool
      * @param value - The value of NRT released
      **/
      event NRTTransfer(string pool, address sendAddress, uint256 value);


      // Event to watch Tokens Burned
      // @param amount The amount burned
      event TokensBurned(uint256 amount);

    /**
      * Event to watch the addition of pool address
      * @param pool - The pool name
      * @param sendAddress - The address of pool
      **/
      event PoolAddressAdded(string pool, address sendAddress);

      // Event to watch LuckPool Updation
      // @param luckPoolBal The current luckPoolBal
      event LuckPoolUpdated(uint256 luckPoolBal);

      // Event to watch BurnTokenBal Updation
      // @param burnTokenBal The current burnTokenBal
      event BurnTokenBalUpdated(uint256 burnTokenBal);




      /**
      * @dev Throws if caller is not timeAlly
      */
      modifier OnlyAllowed() {
        require(msg.sender == timeAlly || msg.sender == timeSwappers,"Only TimeAlly and Timeswapper is authorised");
        _;
      }

          /**
      * @dev Throws if caller is not owner
      */
      modifier OnlyOwner() {
        require(msg.sender == Owner,"Only Owner is authorised");
        _;
      }



      /**
      * @dev Should burn tokens according to the total circulation
      * @return true if success
      */

      function burnTokens() internal returns (bool){
        if(burnTokenBal == 0){
          return true;
        }
        else{
          uint MaxAmount = ((token.totalSupply()).mul(2)).div(100);   // max amount permitted to burn in a month
          if(MaxAmount >= burnTokenBal ){
            token.burn(burnTokenBal);
            burnTokenBal = 0;
          }
          else{
            burnTokenBal = burnTokenBal.sub(MaxAmount);
            token.burn(MaxAmount);
          }
          return true;
        }
      }


      /**
      * @dev To update pool addresses
      * @param  pool - A List of pool addresses
      * Updates if pool address is not already set and if given address is not zero
      * @return true if success
      */

      function UpdateAddresses (address[9] calldata pool) external OnlyOwner  returns(bool){

        if((pool[0] != address(0)) && (newTalentsAndPartnerships == address(0))){
          newTalentsAndPartnerships = pool[0];
          emit PoolAddressAdded( "NewTalentsAndPartnerships", newTalentsAndPartnerships);
        }
        if((pool[1] != address(0)) && (platformMaintenance == address(0))){
          platformMaintenance = pool[1];
          emit PoolAddressAdded( "PlatformMaintenance", platformMaintenance);
        }
        if((pool[2] != address(0)) && (marketingAndRNR == address(0))){
          marketingAndRNR = pool[2];
          emit PoolAddressAdded( "MarketingAndRNR", marketingAndRNR);
        }
        if((pool[3] != address(0)) && (kmPards == address(0))){
          kmPards = pool[3];
          emit PoolAddressAdded( "KmPards", kmPards);
        }
        if((pool[4] != address(0)) && (contingencyFunds == address(0))){
          contingencyFunds = pool[4];
          emit PoolAddressAdded( "ContingencyFunds", contingencyFunds);
        }
        if((pool[5] != address(0)) && (researchAndDevelopment == address(0))){
          researchAndDevelopment = pool[5];
          emit PoolAddressAdded( "ResearchAndDevelopment", researchAndDevelopment);
        }
        if((pool[6] != address(0)) && (powerToken == address(0))){
          powerToken = pool[6];
          emit PoolAddressAdded( "PowerToken", powerToken);
        }
        if((pool[7] != address(0)) && (timeSwappers == address(0))){
          timeSwappers = pool[7];
          emit PoolAddressAdded( "TimeSwapper", timeSwappers);
        }
        if((pool[8] != address(0)) && (timeAlly == address(0))){
          timeAlly = pool[8];
          emit PoolAddressAdded( "TimeAlly", timeAlly);
        }

        return true;
      }


      /**
      * @dev Function to update luckpool balance
      * @param amount Amount to be updated
      */
      function UpdateLuckpool(uint256 amount) external OnlyAllowed returns(bool){
              luckPoolBal = luckPoolBal.add(amount);
        emit LuckPoolUpdated(luckPoolBal);
        return true;
      }

      /**
      * @dev Function to trigger to update  for burning of tokens
      * @param amount Amount to be updated
      */
      function UpdateBurnBal(uint256 amount) external OnlyAllowed returns(bool){
             burnTokenBal = burnTokenBal.add(amount);
        emit BurnTokenBalUpdated(burnTokenBal);
        return true;
      }

      /**
      * @dev To invoke monthly release
      * @return true if success
      */

      function MonthlyNRTRelease() external returns (bool) {
        require(now.sub(lastNRTRelease)> 2629744,"NRT release happens once every month");
        uint256 NRTBal = monthlyNRTAmount.add(luckPoolBal);        // Total NRT available.

        // Calculating NRT to be released to each of the pools
        newTalentsAndPartnershipsBal = (NRTBal.mul(5)).div(100);
        platformMaintenanceBal = (NRTBal.mul(10)).div(100);
        marketingAndRNRBal = (NRTBal.mul(10)).div(100);
        kmPardsBal = (NRTBal.mul(10)).div(100);
        contingencyFundsBal = (NRTBal.mul(10)).div(100);
        researchAndDevelopmentBal = (NRTBal.mul(5)).div(100);

        powerTokenNRT = (NRTBal.mul(10)).div(100);
        timeAllyNRT = (NRTBal.mul(15)).div(100);
        timeSwappersNRT = (NRTBal.mul(25)).div(100);

        // sending tokens to respective wallets and emitting events
        token.mint(newTalentsAndPartnerships,newTalentsAndPartnershipsBal);
        emit NRTTransfer("newTalentsAndPartnerships", newTalentsAndPartnerships, newTalentsAndPartnershipsBal);

        token.mint(platformMaintenance,platformMaintenanceBal);
        emit NRTTransfer("platformMaintenance", platformMaintenance, platformMaintenanceBal);

        token.mint(marketingAndRNR,marketingAndRNRBal);
        emit NRTTransfer("marketingAndRNR", marketingAndRNR, marketingAndRNRBal);

        token.mint(kmPards,kmPardsBal);
        emit NRTTransfer("kmPards", kmPards, kmPardsBal);

        token.mint(contingencyFunds,contingencyFundsBal);
        emit NRTTransfer("contingencyFunds", contingencyFunds, contingencyFundsBal);

        token.mint(researchAndDevelopment,researchAndDevelopmentBal);
        emit NRTTransfer("researchAndDevelopment", researchAndDevelopment, researchAndDevelopmentBal);

        token.mint(powerToken,powerTokenNRT);
        emit NRTTransfer("powerToken", powerToken, powerTokenNRT);

        token.mint(timeAlly,timeAllyNRT);
        TimeAlly timeAllyContract = TimeAlly(timeAlly);
        timeAllyContract.increaseMonth(timeAllyNRT);
        emit NRTTransfer("stakingContract", timeAlly, timeAllyNRT);

        token.mint(timeSwappers,timeSwappersNRT);
        emit NRTTransfer("timeSwappers", timeSwappers, timeSwappersNRT);

        // Reseting NRT
        emit NRTDistributed(NRTBal);
        luckPoolBal = 0;
        lastNRTRelease = lastNRTRelease.add(2629744); // @dev adding seconds according to 1 Year = 365.242 days
        burnTokens();                                 // burning burnTokenBal
        emit TokensBurned(burnTokenBal);


        if(monthCount == 11){
          monthCount = 0;
          annualNRTAmount = (annualNRTAmount.mul(90)).div(100);
          monthlyNRTAmount = annualNRTAmount.div(12);
        }
        else{
          monthCount = monthCount.add(1);
        }
        return true;
      }


    /**
    * @dev Constructor
    */

    constructor(address eraswaptoken) public{
      token = Eraswap(eraswaptoken);
      lastNRTRelease = now;
      annualNRTAmount = 819000000000000000000000000;
      monthlyNRTAmount = annualNRTAmount.div(uint256(12));
      monthCount = 0;
      Owner = msg.sender;
    }

}

pragma solidity ^0.5.2;

import "./PauserRole.sol";

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is PauserRole {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    constructor () internal {
        _paused = false;
    }

    /**
     * @return true if the contract is paused, false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!_paused);
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(_paused);
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() public onlyPauser whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() public onlyPauser whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

pragma solidity ^0.5.2;

import "./Roles.sol";

contract PauserRole {
    using Roles for Roles.Role;

    event PauserAdded(address indexed account);
    event PauserRemoved(address indexed account);

    Roles.Role private _pausers;

    constructor () internal {
        _addPauser(msg.sender);
    }

    modifier onlyPauser() {
        require(isPauser(msg.sender));
        _;
    }

    function isPauser(address account) public view returns (bool) {
        return _pausers.has(account);
    }

    function addPauser(address account) public onlyPauser {
        _addPauser(account);
    }

    function renouncePauser() public {
        _removePauser(msg.sender);
    }

    function _addPauser(address account) internal {
        _pausers.add(account);
        emit PauserAdded(account);
    }

    function _removePauser(address account) internal {
        _pausers.remove(account);
        emit PauserRemoved(account);
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

pragma solidity 0.5.10;

import './SafeMath.sol';
import './Eraswap.sol';
import './NRTManager.sol';

/*

Potential bugs: this contract is designed assuming NRT Release will happen every month.
There might be issues when the NRT scheduled
- added stakingMonth property in Staking struct

fix withdraw fractionFrom15 luck pool
- done

add loanactive contition to take loan
- done

ensure stakingMonth in the struct is being used every where instead of calculation
- done

remove local variables uncesessary

final the earthSecondsInMonth amount in TimeAlly as well in NRT

add events for required functions
*/

/// @author The EraSwap Team
/// @title TimeAlly Smart Contract
/// @dev all require statement message strings are commented to make contract deployable by lower the deploying gas fee
contract TimeAlly {
    using SafeMath for uint256;

    struct Staking {
        uint256 exaEsAmount;
        uint256 timestamp;
        uint256 stakingMonth;
        uint256 stakingPlanId;
        uint256 status; /// @dev 1 => active; 2 => loaned; 3 => withdrawed; 4 => cancelled; 5 => nomination mode
        uint256 loanId;
        uint256 totalNominationShares;
        mapping (uint256 => bool) isMonthClaimed;
        mapping (address => uint256) nomination;
    }

    struct StakingPlan {
        uint256 months;
        uint256 fractionFrom15; /// @dev fraction of NRT released. Alotted to TimeAlly is 15% of NRT
        // bool isPlanActive; /// @dev when plan is inactive, new stakings must not be able to select this plan. Old stakings which already selected this plan will continue themselves as per plan.
        bool isUrgentLoanAllowed; /// @dev if urgent loan is not allowed then staker can take loan only after 75% (hard coded) of staking months
    }

    struct Loan {
        uint256 exaEsAmount;
        uint256 timestamp;
        uint256 loanPlanId;
        uint256 status; // @dev 1 => not repayed yet; 2 => repayed
        uint256[] stakingIds;
    }

    struct LoanPlan {
        uint256 loanMonths;
        uint256 loanRate; // @dev amount of charge to pay, this will be sent to luck pool
        uint256 maxLoanAmountPercent; /// @dev max loan user can take depends on this percent of the plan and the stakings user wishes to put for the loan
    }

    uint256 public deployedTimestamp;
    address public owner;
    Eraswap public token;
    NRTManager public nrtManager;

    /// @dev 1 Year = 365.242 days for taking care of leap years
    uint256 public earthSecondsInMonth = 2629744;
    // uint256 earthSecondsInMonth = 30 * 12 * 60 * 60; /// @dev there was a decision for following 360 day year

    StakingPlan[] public stakingPlans;
    LoanPlan[] public loanPlans;

    // user activity details:
    mapping(address => Staking[]) public stakings;
    mapping(address => Loan[]) public loans;
    mapping(address => uint256) public launchReward;

    /// @dev TimeAlly month to exaEsAmount mapping.
    mapping (uint256 => uint256) public totalActiveStakings;

    /// @notice NRT being received from NRT Manager every month is stored in this array
    /// @dev current month is the length of this array
    uint256[] public timeAllyMonthlyNRT;

    event NewStaking (
        address indexed _userAddress,
        uint256 indexed _stakePlanId,
        uint256 _exaEsAmount,
        uint256 _stakingId
    );

    event PrincipalWithdrawl (
        address indexed _userAddress,
        uint256 _stakingId
    );

    event NomineeNew (
        address indexed _userAddress,
        uint256 indexed _stakingId,
        address indexed _nomineeAddress
    );

    event NomineeWithdraw (
        address indexed _userAddress,
        uint256 indexed _stakingId,
        address indexed _nomineeAddress,
        uint256 _liquid,
        uint256 _accrued
    );

    event BenefitWithdrawl (
        address indexed _userAddress,
        uint256 _stakingId,
        uint256[] _months,
        uint256 _halfBenefit
    );

    event NewLoan (
        address indexed _userAddress,
        uint256 indexed _loanPlanId,
        uint256 _exaEsAmount,
        uint256 _loanInterest,
        uint256 _loanId
    );

    event RepayLoan (
        address indexed _userAddress,
        uint256 _loanId
    );


    modifier onlyNRTManager() {
        require(
          msg.sender == address(nrtManager)
          // , 'only NRT manager can call'
        );
        _;
    }

    modifier onlyOwner() {
        require(
          msg.sender == owner
          // , 'only deployer can call'
        );
        _;
    }

    /// @notice sets up TimeAlly contract when deployed
    /// @param _tokenAddress - is EraSwap contract address
    /// @param _nrtAddress - is NRT Manager contract address
    constructor(address _tokenAddress, address _nrtAddress) public {
        owner = msg.sender;
        token = Eraswap(_tokenAddress);
        nrtManager = NRTManager(_nrtAddress);
        deployedTimestamp = now;
        timeAllyMonthlyNRT.push(0); /// @dev first month there is no NRT released
    }

    /// @notice this function is used by NRT manager to communicate NRT release to TimeAlly
    function increaseMonth(uint256 _timeAllyNRT) public onlyNRTManager {
        timeAllyMonthlyNRT.push(_timeAllyNRT);
    }

    /// @notice TimeAlly month is dependent on the monthly NRT release
    /// @return current month is the TimeAlly month
    function getCurrentMonth() public view returns (uint256) {
        return timeAllyMonthlyNRT.length - 1;
    }

    /// @notice this function is used by owner to create plans for new stakings
    /// @param _months - is number of staking months of a plan. for eg. 12 months
    /// @param _fractionFrom15 - NRT fraction (max 15%) benefit to be given to user. rest is sent back to NRT in Luck Pool
    /// @param _isUrgentLoanAllowed - if urgent loan is not allowed then staker can take loan only after 75% of time elapsed
    function createStakingPlan(uint256 _months, uint256 _fractionFrom15, bool _isUrgentLoanAllowed) public onlyOwner {
        stakingPlans.push(StakingPlan({
            months: _months,
            fractionFrom15: _fractionFrom15,
            // isPlanActive: true,
            isUrgentLoanAllowed: _isUrgentLoanAllowed
        }));
    }

    /// @notice this function is used by owner to create plans for new loans
    /// @param _loanMonths - number of months or duration of loan, loan taker must repay the loan before this period
    /// @param _loanRate - this is total % of loaning amount charged while taking loan, this charge is sent to luckpool in NRT manager which ends up distributed back to the community again
    function createLoanPlan(uint256 _loanMonths, uint256 _loanRate, uint256 _maxLoanAmountPercent) public onlyOwner {
        require(_maxLoanAmountPercent <= 100
            // , 'everyone should not be able to take loan more than 100 percent of their stakings'
        );
        loanPlans.push(LoanPlan({
            loanMonths: _loanMonths,
            loanRate: _loanRate,
            maxLoanAmountPercent: _maxLoanAmountPercent
        }));
    }



    /// @notice takes ES from user and locks it for a time according to plan selected by user
    /// @param _exaEsAmount - amount of ES tokens (in 18 decimals thats why 'exa') that user wishes to stake
    /// @param _stakingPlanId - plan for staking
    function newStaking(uint256 _exaEsAmount, uint256 _stakingPlanId) public {

        /// @dev 0 ES stakings would get 0 ES benefits and might cause confusions as transaction would confirm but total active stakings will not increase
        require(_exaEsAmount > 0
            // , 'staking amount should be non zero'
        );

        require(token.transferFrom(msg.sender, address(this), _exaEsAmount)
          // , 'could not transfer tokens'
        );
        uint256 stakeEndMonth = getCurrentMonth() + stakingPlans[_stakingPlanId].months;

        // @dev update the totalActiveStakings array so that staking would be automatically inactive after the stakingPlanMonthhs
        for(
          uint256 month = getCurrentMonth() + 1;
          month <= stakeEndMonth;
          month++
        ) {
            totalActiveStakings[month] = totalActiveStakings[month].add(_exaEsAmount);
        }

        stakings[msg.sender].push(Staking({
            exaEsAmount: _exaEsAmount,
            timestamp: now,
            stakingMonth: getCurrentMonth(),
            stakingPlanId: _stakingPlanId,
            status: 1,
            loanId: 0,
            totalNominationShares: 0
        }));

        emit NewStaking(msg.sender, _stakingPlanId, _exaEsAmount, stakings[msg.sender].length - 1);
    }

    /// @notice this function is used to see total stakings of any user of TimeAlly
    /// @param _userAddress - address of user
    /// @return number of stakings of _userAddress
    function getNumberOfStakingsByUser(address _userAddress) public view returns (uint256) {
        return stakings[_userAddress].length;
    }

    /// @notice this function is used to topup reward balance in smart contract. Rewards are transferable. Anyone with reward balance can only claim it as a new staking.
    /// @dev Allowance is required before topup.
    /// @param _exaEsAmount - amount to add to your rewards for sending rewards to others
    function topupRewardBucket(uint256 _exaEsAmount) public {
        require(token.transferFrom(msg.sender, address(this), _exaEsAmount));
        launchReward[msg.sender] = launchReward[msg.sender].add(_exaEsAmount);
    }

    /// @notice this function is used to send rewards to multiple users
    /// @param _addresses - array of address to send rewards
    /// @param _exaEsAmountArray - array of ExaES amounts sent to each address of _addresses with same index
    function giveLaunchReward(address[] memory _addresses, uint256[] memory _exaEsAmountArray) public onlyOwner {
        for(uint256 i = 0; i < _addresses.length; i++) {
            launchReward[msg.sender] = launchReward[msg.sender].sub(_exaEsAmountArray[i]);
            launchReward[_addresses[i]] = launchReward[_addresses[i]].add(_exaEsAmountArray[i]);
        }
    }

    /// @notice this function is used by rewardees to claim their accrued rewards. This is also used by stakers to restake their 50% benefit received as rewards
    /// @param _stakingPlanId - rewardee can choose plan while claiming rewards as stakings
    function claimLaunchReward(uint256 _stakingPlanId) public {
        // require(stakingPlans[_stakingPlanId].isPlanActive
        //     // , 'selected plan is not active'
        // );

        require(launchReward[msg.sender] > 0
            // , 'launch reward should be non zero'
        );
        uint256 reward = launchReward[msg.sender];
        launchReward[msg.sender] = 0;

        // @dev logic similar to newStaking function
        uint256 stakeEndMonth = getCurrentMonth() + stakingPlans[_stakingPlanId].months;

        // @dev update the totalActiveStakings array so that staking would be automatically inactive after the stakingPlanMonthhs
        for(
          uint256 month = getCurrentMonth() + 1;
          month <= stakeEndMonth;
          month++
        ) {
            totalActiveStakings[month] = totalActiveStakings[month].add(reward); /// @dev reward means locked ES which only staking option
        }

        stakings[msg.sender].push(Staking({
            exaEsAmount: reward,
            timestamp: now,
            stakingMonth: getCurrentMonth(),
            stakingPlanId: _stakingPlanId,
            status: 1,
            loanId: 0,
            totalNominationShares: 0
        }));

        emit NewStaking(msg.sender, _stakingPlanId, reward, stakings[msg.sender].length - 1);
    }


    /// @notice used internally to see if staking is active or not. does not include if staking is claimed.
    /// @param _userAddress - address of user
    /// @param _stakingId - staking id
    /// @param _atMonth - particular month to check staking active
    /// @return true is staking is in correct time frame and also no loan on it
    function isStakingActive(
        address _userAddress,
        uint256 _stakingId,
        uint256 _atMonth
    ) public view returns (bool) {
        //uint256 stakingMonth = stakings[_userAddress][_stakingId].timestamp.sub(deployedTimestamp).div(earthSecondsInMonth);

        return (
            /// @dev _atMonth should be a month after which staking starts
            stakings[_userAddress][_stakingId].stakingMonth + 1 <= _atMonth

            /// @dev _atMonth should be a month before which staking ends
            && stakings[_userAddress][_stakingId].stakingMonth + stakingPlans[ stakings[_userAddress][_stakingId].stakingPlanId ].months >= _atMonth

            /// @dev staking should have active status
            && stakings[_userAddress][_stakingId].status == 1

            /// @dev if _atMonth is current Month, then withdrawal should be allowed only after 30 days interval since staking
            && (
              getCurrentMonth() != _atMonth
              || now >= stakings[_userAddress][_stakingId].timestamp
                          .add(
                            getCurrentMonth()
                              .sub(stakings[_userAddress][_stakingId].stakingMonth)
                              .mul(earthSecondsInMonth)
                          )
              )
            );
    }


    /// @notice this function is used for seeing the benefits of a staking of any user
    /// @param _userAddress - address of user
    /// @param _stakingId - staking id
    /// @param _months - array of months user is interested to see benefits.
    /// @return amount of ExaES of benefits of entered months
    function seeBenefitOfAStakingByMonths(
        address _userAddress,
        uint256 _stakingId,
        uint256[] memory _months
    ) public view returns (uint256) {
        uint256 benefitOfAllMonths;
        for(uint256 i = 0; i < _months.length; i++) {
            /// @dev this require statement is converted into if statement for easier UI fetching. If there is no benefit for a month or already claimed, it will consider benefit of that month as 0 ES. But same is not done for withdraw function.
            // require(
            //   isStakingActive(_userAddress, _stakingId, _months[i])
            //   && !stakings[_userAddress][_stakingId].isMonthClaimed[_months[i]]
            //   // , 'staking must be active'
            // );
            if(isStakingActive(_userAddress, _stakingId, _months[i])
            && !stakings[_userAddress][_stakingId].isMonthClaimed[_months[i]]) {
                uint256 benefit = stakings[_userAddress][_stakingId].exaEsAmount
                                  .mul(timeAllyMonthlyNRT[ _months[i] ])
                                  .div(totalActiveStakings[ _months[i] ]);
                benefitOfAllMonths = benefitOfAllMonths.add(benefit);
            }
        }
        return benefitOfAllMonths.mul(
          stakingPlans[stakings[_userAddress][_stakingId].stakingPlanId].fractionFrom15
        ).div(15);
    }

    /// @notice this function is used for withdrawing the benefits of a staking of any user
    /// @param _stakingId - staking id
    /// @param _months - array of months user is interested to withdraw benefits of staking.
    function withdrawBenefitOfAStakingByMonths(
        uint256 _stakingId,
        uint256[] memory _months
    ) public {
        uint256 _benefitOfAllMonths;
        for(uint256 i = 0; i < _months.length; i++) {
            // require(
            //   isStakingActive(msg.sender, _stakingId, _months[i])
            //   && !stakings[msg.sender][_stakingId].isMonthClaimed[_months[i]]
            //   // , 'staking must be active'
            // );
            if(isStakingActive(msg.sender, _stakingId, _months[i])
            && !stakings[msg.sender][_stakingId].isMonthClaimed[_months[i]]) {
                uint256 _benefit = stakings[msg.sender][_stakingId].exaEsAmount
                                  .mul(timeAllyMonthlyNRT[ _months[i] ])
                                  .div(totalActiveStakings[ _months[i] ]);

                _benefitOfAllMonths = _benefitOfAllMonths.add(_benefit);
                stakings[msg.sender][_stakingId].isMonthClaimed[_months[i]] = true;
            }
        }

        uint256 _luckPool = _benefitOfAllMonths
                        .mul( uint256(15).sub(stakingPlans[stakings[msg.sender][_stakingId].stakingPlanId].fractionFrom15) )
                        .div( 15 );

        require( token.transfer(address(nrtManager), _luckPool) );
        require( nrtManager.UpdateLuckpool(_luckPool) );

        _benefitOfAllMonths = _benefitOfAllMonths.sub(_luckPool);

        uint256 _halfBenefit = _benefitOfAllMonths.div(2);
        require( token.transfer(msg.sender, _halfBenefit) );

        launchReward[msg.sender] = launchReward[msg.sender].add(_halfBenefit);

        // emit event
        emit BenefitWithdrawl(msg.sender, _stakingId, _months, _halfBenefit);
    }


    /// @notice this function is used to withdraw the principle amount of multiple stakings which have their tenure completed
    /// @param _stakingIds - input which stakings to withdraw
    function withdrawExpiredStakings(uint256[] memory _stakingIds) public {
        for(uint256 i = 0; i < _stakingIds.length; i++) {
            require(now >= stakings[msg.sender][_stakingIds[i]].timestamp
                    .add(stakingPlans[ stakings[msg.sender][_stakingIds[i]].stakingPlanId ].months.mul(earthSecondsInMonth))
              // , 'cannot withdraw before staking ends'
            );
            stakings[msg.sender][_stakingIds[i]].status = 3;

            token.transfer(msg.sender, stakings[msg.sender][_stakingIds[i]].exaEsAmount);

            emit PrincipalWithdrawl(msg.sender, _stakingIds[i]);
        }
    }

    /// @notice this function is used to estimate the maximum amount of loan that any user can take with their stakings
    /// @param _userAddress - address of user
    /// @param _stakingIds - array of staking ids which should be used to estimate max loan amount
    /// @param _loanPlanId - the loan plan user wishes to take loan.
    /// @return max loaning amount
    function seeMaxLoaningAmountOnUserStakings(address _userAddress, uint256[] memory _stakingIds, uint256 _loanPlanId) public view returns (uint256) {
        uint256 _currentMonth = getCurrentMonth();
        //require(_currentMonth >= _atMonth, 'cannot see future stakings');

        uint256 userStakingsExaEsAmount;

        for(uint256 i = 0; i < _stakingIds.length; i++) {

            if(isStakingActive(_userAddress, _stakingIds[i], _currentMonth)
                && (
                  // @dev if urgent loan is not allowed then loan can be taken only after staking period is completed 75%
                  stakingPlans[ stakings[_userAddress][_stakingIds[i]].stakingPlanId ].isUrgentLoanAllowed
                  || now > stakings[_userAddress][_stakingIds[i]].timestamp + stakingPlans[ stakings[_userAddress][_stakingIds[i]].stakingPlanId ].months.mul(earthSecondsInMonth).mul(75).div(100)
                )
            ) {
                userStakingsExaEsAmount = userStakingsExaEsAmount
                    .add(stakings[_userAddress][_stakingIds[i]].exaEsAmount
                      .mul(loanPlans[_loanPlanId].maxLoanAmountPercent)
                      .div(100)
                      // .mul(stakingPlans[ stakings[_userAddress][_stakingIds[i]].stakingPlanId ].fractionFrom15)
                      // .div(15)
                    );
            }
        }

        return userStakingsExaEsAmount;
            //.mul( uint256(100).sub(loanPlans[_loanPlanId].loanRate) ).div(100);
    }

    /// @notice this function is used to take loan on multiple stakings
    /// @param _loanPlanId - user can select this plan which defines loan duration and loan interest
    /// @param _exaEsAmount - loan amount, this will also be the loan repay amount, the interest will first be deducted from this and then amount will be credited
    /// @param _stakingIds - staking ids user wishes to encash for taking the loan
    function takeLoanOnSelfStaking(uint256 _loanPlanId, uint256 _exaEsAmount, uint256[] memory _stakingIds) public {
        // @dev when loan is to be taken, first calculate active stakings from given stakings array. this way we can get how much loan user can take and simultaneously mark stakings as claimed for next months number loan period
        uint256 _currentMonth = getCurrentMonth();
        uint256 _userStakingsExaEsAmount;

        for(uint256 i = 0; i < _stakingIds.length; i++) {

            if( isStakingActive(msg.sender, _stakingIds[i], _currentMonth)
                && (
                  // @dev if urgent loan is not allowed then loan can be taken only after staking period is completed 75%
                  stakingPlans[ stakings[msg.sender][_stakingIds[i]].stakingPlanId ].isUrgentLoanAllowed
                  || now > stakings[msg.sender][_stakingIds[i]].timestamp + stakingPlans[ stakings[msg.sender][_stakingIds[i]].stakingPlanId ].months.mul(earthSecondsInMonth).mul(75).div(100)
                )
            ) {

                // @dev store sum in a number
                _userStakingsExaEsAmount = _userStakingsExaEsAmount
                    .add(
                        stakings[msg.sender][ _stakingIds[i] ].exaEsAmount
                          .mul(loanPlans[_loanPlanId].maxLoanAmountPercent)
                          .div(100)
                );

                // @dev subtract total active stakings
                uint256 stakingStartMonth = stakings[msg.sender][_stakingIds[i]].stakingMonth;

                uint256 stakeEndMonth = stakingStartMonth + stakingPlans[stakings[msg.sender][_stakingIds[i]].stakingPlanId].months;

                for(uint256 j = _currentMonth + 1; j <= stakeEndMonth; j++) {
                    totalActiveStakings[j] = totalActiveStakings[j].sub(_userStakingsExaEsAmount);
                }

                // @dev make stakings inactive
                for(uint256 j = 1; j <= loanPlans[_loanPlanId].loanMonths; j++) {
                    stakings[msg.sender][ _stakingIds[i] ].isMonthClaimed[ _currentMonth + j ] = true;
                    stakings[msg.sender][ _stakingIds[i] ].status = 2; // means in loan
                }
            }
        }

        uint256 _maxLoaningAmount = _userStakingsExaEsAmount;

        if(_exaEsAmount > _maxLoaningAmount) {
            require(false
              // , 'cannot loan more than maxLoaningAmount'
            );
        }


        uint256 _loanInterest = _exaEsAmount.mul(loanPlans[_loanPlanId].loanRate).div(100);
        uint256 _loanAmountToTransfer = _exaEsAmount.sub(_loanInterest);

        require( token.transfer(address(nrtManager), _loanInterest) );
        require( nrtManager.UpdateLuckpool(_loanInterest) );

        loans[msg.sender].push(Loan({
            exaEsAmount: _exaEsAmount,
            timestamp: now,
            loanPlanId: _loanPlanId,
            status: 1,
            stakingIds: _stakingIds
        }));

        // @dev send user amount
        require( token.transfer(msg.sender, _loanAmountToTransfer) );

        emit NewLoan(msg.sender, _loanPlanId, _exaEsAmount, _loanInterest, loans[msg.sender].length - 1);
    }

    /// @notice repay loan functionality
    /// @dev need to give allowance before this
    /// @param _loanId - select loan to repay
    function repayLoanSelf(uint256 _loanId) public {
        require(loans[msg.sender][_loanId].status == 1
          // , 'can only repay pending loans'
        );

        require(loans[msg.sender][_loanId].timestamp + loanPlans[ loans[msg.sender][_loanId].loanPlanId ].loanMonths.mul(earthSecondsInMonth) > now
          // , 'cannot repay expired loan'
        );

        require(token.transferFrom(msg.sender, address(this), loans[msg.sender][_loanId].exaEsAmount)
          // , 'cannot receive enough tokens, please check if allowance is there'
        );

        loans[msg.sender][_loanId].status = 2;

        // @dev get all stakings associated with this loan. and set next unclaimed months. then set status to 1 and also add to totalActiveStakings
        for(uint256 i = 0; i < loans[msg.sender][_loanId].stakingIds.length; i++) {
            uint256 _stakingId = loans[msg.sender][_loanId].stakingIds[i];

            stakings[msg.sender][_stakingId].status = 1;

            uint256 stakingStartMonth = stakings[msg.sender][_stakingId].timestamp.sub(deployedTimestamp).div(earthSecondsInMonth);

            uint256 stakeEndMonth = stakingStartMonth + stakingPlans[stakings[msg.sender][_stakingId].stakingPlanId].months;

            for(uint256 j = getCurrentMonth() + 1; j <= stakeEndMonth; j++) {
                stakings[msg.sender][_stakingId].isMonthClaimed[i] = false;

                totalActiveStakings[j] = totalActiveStakings[j].add(stakings[msg.sender][_stakingId].exaEsAmount);
            }
        }
        // add repay event
        emit RepayLoan(msg.sender, _loanId);
    }

    function burnDefaultedLoans(address[] memory _addressArray, uint256[] memory _loanIdArray) public {
        uint256 _amountToBurn;
        for(uint256 i = 0; i < _addressArray.length; i++) {
            require(
                loans[ _addressArray[i] ][ _loanIdArray[i] ].status == 1
                // , 'loan should not be repayed'
            );
            require(
                now >
                loans[ _addressArray[i] ][ _loanIdArray[i] ].timestamp
                + loanPlans[ loans[ _addressArray[i] ][ _loanIdArray[i] ].loanPlanId ].loanMonths.mul(earthSecondsInMonth)
                // , 'loan should have crossed its loan period'
            );
            uint256[] storage _stakingIdsOfLoan = loans[ _addressArray[i] ][ _loanIdArray[i] ].stakingIds;

            /// @dev add staking amounts of all stakings on which loan is taken
            for(uint256 j = 0; j < _stakingIdsOfLoan.length; j++) {
                _amountToBurn = _amountToBurn.add(
                    stakings[ _addressArray[i] ][ _stakingIdsOfLoan[j] ].exaEsAmount
                );
            }
            /// @dev sub loan amount
            _amountToBurn = _amountToBurn.sub(
                loans[ _addressArray[i] ][ _loanIdArray[i] ].exaEsAmount
            );
        }
        require(token.transfer(address(nrtManager), _amountToBurn));
        require(nrtManager.UpdateBurnBal(_amountToBurn));

        // emit event
    }

    /// @notice this function is used to add nominee to a staking
    /// @param _stakingId - staking id
    /// @param _nomineeAddress - address of nominee to be added to staking
    /// @param _shares - amount of shares of the staking to the nominee
    /// @dev shares is compared with total shares issued in a staking to see the percent nominee can withdraw. Nominee can withdraw only after one year past the end of tenure of staking. Upto 1 year past the end of tenure of staking, owner can withdraw principle amount of staking as well as can CRUD nominees. Owner of staking is has this time to withdraw their staking, if they fail to do so, after that nominees are allowed to withdraw. Withdrawl by first nominee will trigger staking into nomination mode and owner of staking cannot withdraw the principle amount as it will be distributed with only nominees and only they can withdraw it.
    function addNominee(uint256 _stakingId, address _nomineeAddress, uint256 _shares) public {
        require(stakings[msg.sender][_stakingId].status == 1
          // , 'staking should active'
        );
        require(stakings[msg.sender][_stakingId].nomination[_nomineeAddress] == 0
          // , 'should not be nominee already'
        );
        stakings[msg.sender][_stakingId].totalNominationShares = stakings[msg.sender][_stakingId].totalNominationShares.add(_shares);
        stakings[msg.sender][_stakingId].nomination[_nomineeAddress] = _shares;
        emit NomineeNew(msg.sender, _stakingId, _nomineeAddress);
    }

    /// @notice this function is used to read the nomination of a nominee address of a staking of a user
    /// @param _userAddress - address of staking owner
    /// @param _stakingId - staking id
    /// @param _nomineeAddress - address of nominee
    /// @return nomination of the nominee
    function viewNomination(address _userAddress, uint256 _stakingId, address _nomineeAddress) public view returns (uint256) {
        return stakings[_userAddress][_stakingId].nomination[_nomineeAddress];
    }

    // /// @notice this function is used to update nomination of a nominee of sender's staking
    // /// @param _stakingId - staking id
    // /// @param _nomineeAddress - address of nominee
    // /// @param _shares - shares to be updated for the nominee
    // function updateNominee(uint256 _stakingId, address _nomineeAddress, uint256 _shares) public {
    //     require(stakings[msg.sender][_stakingId].status == 1
    //       // , 'staking should active'
    //     );
    //     uint256 _oldShares = stakings[msg.sender][_stakingId].nomination[_nomineeAddress];
    //     if(_shares > _oldShares) {
    //         uint256 _diff = _shares.sub(_oldShares);
    //         stakings[msg.sender][_stakingId].totalNominationShares = stakings[msg.sender][_stakingId].totalNominationShares.add(_diff);
    //         stakings[msg.sender][_stakingId].nomination[_nomineeAddress] = stakings[msg.sender][_stakingId].nomination[_nomineeAddress].add(_diff);
    //     } else if(_shares < _oldShares) {
    //       uint256 _diff = _oldShares.sub(_shares);
    //         stakings[msg.sender][_stakingId].nomination[_nomineeAddress] = stakings[msg.sender][_stakingId].nomination[_nomineeAddress].sub(_diff);
    //         stakings[msg.sender][_stakingId].totalNominationShares = stakings[msg.sender][_stakingId].totalNominationShares.sub(_diff);
    //     }
    // }

    /// @notice this function is used to remove nomination of a address
    /// @param _stakingId - staking id
    /// @param _nomineeAddress - address of nominee
    function removeNominee(uint256 _stakingId, address _nomineeAddress) public {
        require(stakings[msg.sender][_stakingId].status == 1, 'staking should active');
        uint256 _oldShares = stakings[msg.sender][_stakingId].nomination[msg.sender];
        stakings[msg.sender][_stakingId].nomination[_nomineeAddress] = 0;
        stakings[msg.sender][_stakingId].totalNominationShares = stakings[msg.sender][_stakingId].totalNominationShares.sub(_oldShares);
    }

    /// @notice this function is used by nominee to withdraw their share of a staking after 1 year of the end of tenure of staking
    /// @param _userAddress - address of user
    /// @param _stakingId - staking id
    function nomineeWithdraw(address _userAddress, uint256 _stakingId) public {
        // end time stamp > 0
        uint256 currentTime = now;
        require( currentTime > (stakings[_userAddress][_stakingId].timestamp
                    + stakingPlans[stakings[_userAddress][_stakingId].stakingPlanId].months * earthSecondsInMonth
                    + 12 * earthSecondsInMonth )
                    // , 'cannot nominee withdraw before '
            );

        uint256 _nomineeShares = stakings[_userAddress][_stakingId].nomination[msg.sender];
        require(_nomineeShares > 0
          // , 'Not a nominee of this staking'
        );

        //uint256 _totalShares = ;

        // set staking to nomination mode if it isn't.
        if(stakings[_userAddress][_stakingId].status != 5) {
            stakings[_userAddress][_stakingId].status = 5;
        }

        // adding principal account
        uint256 _pendingLiquidAmountInStaking = stakings[_userAddress][_stakingId].exaEsAmount;
        uint256 _pendingAccruedAmountInStaking;

        // uint256 _stakingStartMonth = stakings[_userAddress][_stakingId].timestamp.sub(deployedTimestamp).div(earthSecondsInMonth);
        uint256 _stakeEndMonth = stakings[_userAddress][_stakingId].stakingMonth + stakingPlans[stakings[_userAddress][_stakingId].stakingPlanId].months;

        // adding monthly benefits which are not claimed
        for(
          uint256 i = stakings[_userAddress][_stakingId].stakingMonth; //_stakingStartMonth;
          i < _stakeEndMonth;
          i++
        ) {
            if( stakings[_userAddress][_stakingId].isMonthClaimed[i] ) {
                uint256 _effectiveAmount = stakings[_userAddress][_stakingId].exaEsAmount
                  .mul(stakingPlans[stakings[_userAddress][_stakingId].stakingPlanId].fractionFrom15)
                  .div(15);
                uint256 _monthlyBenefit = _effectiveAmount
                                          .mul(timeAllyMonthlyNRT[i])
                                          .div(totalActiveStakings[i]);
                _pendingLiquidAmountInStaking = _pendingLiquidAmountInStaking.add(_monthlyBenefit.div(2));
                _pendingAccruedAmountInStaking = _pendingAccruedAmountInStaking.add(_monthlyBenefit.div(2));
            }
        }

        // now we have _pendingLiquidAmountInStaking && _pendingAccruedAmountInStaking
        // on which user's share will be calculated and sent

        // marking nominee as claimed by removing his shares
        stakings[_userAddress][_stakingId].nomination[msg.sender] = 0;

        uint256 _nomineeLiquidShare = _pendingLiquidAmountInStaking
                                        .mul(_nomineeShares)
                                        .div(stakings[_userAddress][_stakingId].totalNominationShares);
        token.transfer(msg.sender, _nomineeLiquidShare);

        uint256 _nomineeAccruedShare = _pendingAccruedAmountInStaking
                                          .mul(_nomineeShares)
                                          .div(stakings[_userAddress][_stakingId].totalNominationShares);
        launchReward[msg.sender] = launchReward[msg.sender].add(_nomineeAccruedShare);

        // emit a event
        emit NomineeWithdraw(_userAddress, _stakingId, msg.sender, _nomineeLiquidShare, _nomineeAccruedShare);
    }
}

