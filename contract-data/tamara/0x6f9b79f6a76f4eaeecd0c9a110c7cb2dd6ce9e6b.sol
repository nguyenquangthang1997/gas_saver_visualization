pragma solidity ^0.5.0;
/// @title A facet of KittyCore that manages special access privileges.
/// @author Axiom Zen (https://www.axiomzen.co)
/// @dev See the KittyCore contract documentation to understand how the various contract facets are arranged.

contract AccessControl {
    // This facet controls access control for CryptoKitties. There are four roles managed here:
    //
    //     - The CEO: The CEO can reassign other roles and change the addresses of our dependent smart
    //         contracts. It is also the only role that can unpause the smart contract. It is initially
    //         set to the address that created the smart contract in the KittyCore constructor.
    //
    //     - The CFO: The CFO can withdraw funds from KittyCore and its auction contracts.
    //
    //     - The COO: The COO can release gen0 kitties to auction, and mint promo cats.
    //
    // It should be noted that these roles are distinct without overlap in their access abilities, the
    // abilities listed for each role above are exhaustive. In particular, while the CEO can assign any
    // address to any role, the CEO address itself doesn't have the ability to act in those roles. This
    // restriction is intentional so that we aren't tempted to use the CEO address frequently out of
    // convenience. The less we use an address, the less likely it is that we somehow compromise the
    // account.

    /// @dev Emited when contract is upgraded - See README.md for updgrade plan
    event ContractUpgrade(address newContract);

    // The addresses of the accounts (or contracts) that can execute actions within each roles.
    address public ceoAddress;
    address public cfoAddress;
    address public cooAddress;

    // @dev Keeps track whether the contract is paused. When that is true, most actions are blocked
    bool public paused = false;

    /// @dev Access modifier for CEO-only functionality
    modifier onlyCEO() {
        require(msg.sender == ceoAddress, "only CEO");
        _;
    }

    /// @dev Access modifier for CFO-only functionality
    modifier onlyCFO() {
        require(msg.sender == cfoAddress, "only CFO");
        _;
    }

    /// @dev Access modifier for COO-only functionality
    modifier onlyCOO() {
        require(msg.sender == cooAddress, "only COO");
        _;
    }

    modifier onlyCLevel() {
        require(
            msg.sender == cooAddress ||
            msg.sender == ceoAddress ||
            msg.sender == cfoAddress, "only CLevel"
        );
        _;
    }

    /// @dev Assigns a new address to act as the CEO. Only available to the current CEO.
    /// @param _newCEO The address of the new CEO
    function setCEO(address _newCEO) external onlyCEO {
        require(_newCEO != address(0), "newCEO looks like no changes");

        ceoAddress = _newCEO;
    }

    /// @dev Assigns a new address to act as the CFO. Only available to the current CEO.
    /// @param _newCFO The address of the new CFO
    function setCFO(address _newCFO) external onlyCEO {
        require(_newCFO != address(0), "newCFO looks like no changes");

        cfoAddress = _newCFO;
    }

    /// @dev Assigns a new address to act as the COO. Only available to the current CEO.
    /// @param _newCOO The address of the new COO
    function setCOO(address _newCOO) external onlyCEO {
        require(_newCOO != address(0), "newCOO looks like no changes");

        cooAddress = _newCOO;
    }

    /*** Pausable functionality adapted from OpenZeppelin ***/

    /// @dev Modifier to allow actions only when the contract IS NOT paused
    modifier whenNotPaused() {
        require(!paused, "current contract is paused");
        _;
    }

    /// @dev Modifier to allow actions only when the contract IS paused
    modifier whenPaused {
        require(paused, "current contract is not paused");
        _;
    }

    /// @dev Called by any "C-level" role to pause the contract. Used only when
    ///  a bug or exploit is detected and we need to limit damage.
    function pause() external onlyCLevel whenNotPaused {
        paused = true;
    }

    /// @dev Unpauses the smart contract. Can only be called by the CEO, since
    ///  one reason we may pause the contract is when CFO or COO accounts are
    ///  compromised.
    /// @notice This is public rather than external so it can be called by
    ///  derived contracts.
    function unpause() public onlyCEO whenPaused {
        // can't unpause if contract was upgraded
        paused = false;
    }
}

pragma solidity ^0.5.11;

contract ERC721 {
    event Transfer(address indexed _from, address indexed _to, uint256 _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 _tokenId);

    function balanceOf(address _owner) public view returns (uint256 _balance);
    function ownerOf(uint256 _tokenId) public view returns (address _owner);
    function transfer(address payable _to, uint256 _tokenId) external;
    function approve(address payable _to, uint256 _tokenId) external;
    function takeOwnership(uint256 _tokenId) public;
}

pragma solidity ^0.5.11;

import "./ownable.sol";
import "./AccessControl.sol";
//import "./GridOwnership.sol";
//import "./safemath.sol";
//import "./console.sol";

contract GridBase is Ownable, AccessControl {

    //using SafeMath for uint256;

    uint public levelUpFee = 0.01 ether;
    uint public limitGridsEachtime = 100;
    uint public discountGridsCount = 0;

    //uint fee;

    struct structGird {
        uint16 x;
        uint16 y;
        uint level;
        address payable owner;
        address payable inviter;
    }

    structGird[] public arr_struct_grid;

    mapping (address => uint) public mappingOwnerGridCount;
    mapping (uint16 => uint) public mappingPositionToGirdId;

    // Set in case the core contract is broken and an upgrade is required
    address public newContractAddress;

    address payable public authorAddress;
    address payable public foundationAddress;

    /// @notice Creates the main CryptoKitties smart contract instance.
    constructor () public {
        // Starts paused.
        paused = true;

        // the creator of the contract is the initial CEO
        ceoAddress = msg.sender;
        // the creator of the contract is also the initial COO
        cooAddress = msg.sender;
        cfoAddress = msg.sender;
    }

    /// @dev Used to mark the smart contract as upgraded, in case there is a serious
    ///  breaking bug. This method does nothing but keep track of the new contract and
    ///  emit a message indicating that the new address is set. It's up to clients of this
    ///  contract to update to the new contract address in that case. (This contract will
    ///  be paused indefinitely if such an upgrade takes place.)
    /// @param _v2Address new address
    function setNewContractAddress(address _v2Address) external onlyCEO whenPaused {
        // See README.md for updgrade plan
        newContractAddress = _v2Address;
        emit ContractUpgrade(_v2Address);
    }

    function setAuthorAddress(address payable _address) external onlyCEO whenPaused {
        require(_address != address(0), "authorAddress can not be empty");
        authorAddress = _address;
    }

    function setFoundationAddress(address payable _address) external onlyCEO whenPaused {
        require(_address != address(0), "foundationAddress can not be empty");
        foundationAddress = _address;
    }

    /*/// @notice Returns all the relevant information about a specific kitty.
    /// @param _id The ID of the kitty of interest.
    function getGrid(uint256 _id)
        external
        view
        returns (
        uint16 x,
        uint16 y,
        uint256 level
    ) {
        structGird memory _grid = arr_struct_grid[_id];

        x = uint16(_grid.x);
        y = uint16(_grid.y);
        level = uint256(_grid.level);
    }*/

    /// @dev Override unpause so it requires all external contract addresses
    ///  to be set before contract can be unpaused. Also, we can't have
    ///  newContractAddress set either, because then the contract was upgraded.
    /// @notice This is public rather than external so we can call super.unpause
    ///  without using an expensive CALL.
    function unpause() public onlyCEO whenPaused {
        require(newContractAddress == address(0), "set newContractAddress first");
        require(authorAddress != address(0), "set authorAddress first");
        require(foundationAddress != address(0), "set foundationAddress first");

        // Actually unpause the contract.
        super.unpause();
    }

    function withdraw() external onlyOwner whenPaused {
        owner.transfer(address(this).balance);
    }

    function setLevelUpFee(uint _fee) external onlyCLevel whenPaused {
        levelUpFee = _fee;
    }

    function setlimitGridsEachtime(uint _limit) external onlyCLevel whenPaused {
        limitGridsEachtime = _limit;
    }


  function getContractStatus() external view onlyCLevel returns(uint, uint, uint) {
    return (levelUpFee, limitGridsEachtime, address(this).balance);
  }

  function getLevelUpFee() external view whenNotPaused returns(uint) {
    return levelUpFee;
  }

  function getLimitGridsEachtime() external view whenNotPaused returns(uint) {
    return limitGridsEachtime;
  }

  function getContractBalance() external view onlyCLevel returns(uint) {
    return address(this).balance;
  }
}

pragma solidity ^0.5.11;

import "./GridOwnership.sol";
import "./safemath.sol";
//import "./console.sol";

contract GridMain is GridOwnership {

    using SafeMath for uint256;
    using SafeMath32 for uint32;
    using SafeMath16 for uint16;

    //uint16 public version = 101;

    function buyGird(uint16 _i, uint16 _j, uint16 _k, uint16 _l, address payable _inviter) external payable whenNotPaused {
        require(_i >= 1 && _i <= 100, "value invalid");
        require(_j >= 1 && _j <= 100, "value invalid");
        require(_k >= _i && _k <= 100, "value invalid");
        require(_l >= _j && _l <= 100, "value invalid");
        //require(_k >= _i && _l >= _j, "value invalid");
        require((_k-_i+1)*(_l-_j+1) <= limitGridsEachtime, "too many grids you selected, that may cause problems.");
        uint16 _x;
        uint16 _y;
        //string memory position;
        uint16 position;
        uint256 currentPrice = 0;
        uint256 gridId = 0;
        uint256 tempLevelUpFee = 0;
        address payable inviter;

        if(_inviter == address(0)){
            inviter = owner;
        }else{
            inviter = _inviter;
        }

        //log("mappingPositionToGirdId[position]: ", mappingPositionToGirdId[position]);
        //log("arr_struct_grid[1].level: ", arr_struct_grid[1].level);
        //log("msg.value: ", msg.value);
        //uint fee = msg.value;
        //address acc = msg.sender;

        for(_x = _i; _x<=_k; _x++){
            for(_y = _j; _y<=_l; _y++){
                //position = strConcat(uint2str(_x),uint2str(_y));
                //log("position: ", position);
                position = (_x-1)*100+_y;
                gridId = mappingPositionToGirdId[position];
                if(gridId > 0){
                    structGird storage _grid = arr_struct_grid[gridId-1];
                    //if(_grid.level > 0){
                        //uint16 id = arr_struct_grid.push(structGird(_x, _y, 1)) - 1;
                        //mappingPositionToOwner[position] = msg.sender;
                        currentPrice += _grid.level * levelUpFee + levelUpFee;
                        _grid.owner.transfer(_grid.level * levelUpFee + levelUpFee / 5);
                    _grid.inviter.transfer(levelUpFee / 10);
                    authorAddress.transfer(levelUpFee / 10);
                    foundationAddress.transfer(levelUpFee / 10);
                    owner.transfer(levelUpFee/50);
                    mappingOwnerGridCount[_grid.owner] = mappingOwnerGridCount[_grid.owner].sub(1);
                    mappingOwnerGridCount[msg.sender] = mappingOwnerGridCount[msg.sender].add(1);
                    _grid.level = _grid.level.add(1);
                    _grid.owner = msg.sender;
                    if(_grid.inviter != inviter){
                        _grid.inviter = inviter;
                    }
                    //}
                }else{
                    //uint16 id = arr_struct_grid.push(structGird(_x, _y, 1)) - 1;
                    //mappingGirdPositionToOwner[position] = msg.sender;
                    //tempLevelUpFee = levelUpFee;
                    if(discountGridsCount < 1000){
                        //currentPrice += levelUpFee;
                    }else if(discountGridsCount < 3000){
                        tempLevelUpFee = levelUpFee*1/10;
                    }else if(discountGridsCount < 6000){
                        tempLevelUpFee = levelUpFee*3/10;
                    }else if(discountGridsCount < 10000){
                        tempLevelUpFee = levelUpFee*6/10;
                    }else{
                        tempLevelUpFee = levelUpFee;
                    }
                    discountGridsCount = discountGridsCount.add(1);
                    currentPrice += tempLevelUpFee;
                    uint id = arr_struct_grid.push(structGird(_x, _y, 1, msg.sender, inviter));
                    mappingPositionToGirdId[position] = id;
                    mappingOwnerGridCount[msg.sender] = mappingOwnerGridCount[msg.sender].add(1);
                    owner.transfer(tempLevelUpFee);
                }
            }
        }
        require(msg.value >= currentPrice, "out of your balance");
        //require(address(this).balance >= currentPrice, "out of contract balance, please buy level0 grids");
        /*for(_x = _i; _x<=_k; _x++){
            for(_y = _j; _y<=_l; _y++){
                //position = strConcat(uint2str(_x),uint2str(_y));
                position = (_x-1)*100+_y;
                gridId = mappingPositionToGirdId[position];
                if(gridId > 0){
                    structGird memory _grid = arr_struct_grid[gridId-1];
                 //&& _grid.level > 0){
                    //uint16 id = arr_struct_grid.push(structGird(_x, _y, 1)) - 1;
                    //mappingPositionToOwner[position] = msg.sender;
                    //mappingPositionToGird[position].level = mappingPositionToGird[position].level.add(1);
                    //mappingPositionToGird[position].owner = msg.sender;
                    _grid.owner.transfer(_grid.level * levelUpFee + levelUpFee / 5);
                    _grid.inviter.transfer(levelUpFee / 10);
                    authorAddress.transfer(levelUpFee / 10);
                    foundationAddress.transfer(levelUpFee / 10);
                    owner.transfer(levelUpFee/50);

                    mappingOwnerGridCount[_grid.owner] = mappingOwnerGridCount[_grid.owner].sub(1);
                    mappingOwnerGridCount[msg.sender] = mappingOwnerGridCount[msg.sender].add(1);
                    _grid.level = _grid.level.add(1);
                    _grid.owner = msg.sender;
                    _grid.inviter = inviter;
                }else{
                    uint id = arr_struct_grid.push(structGird(_x, _y, 1, msg.sender, inviter));
                    mappingPositionToGirdId[position] = id;
                    mappingOwnerGridCount[msg.sender] = mappingOwnerGridCount[msg.sender].add(1);
                    owner.transfer(levelUpFee);
                    //mappingGirdPositionToOwner[position] = msg.sender;
                    //mappingPositionToGird[position] = structGird(_x, _y, 1, msg.sender);
                }
            }
        }*/
        msg.sender.transfer(msg.value.sub(currentPrice));
    }

    function getGridPrice(uint16 _i, uint16 _j, uint16 _k, uint16 _l) external view whenNotPaused returns(uint256){
        require(_i >= 1 && _i <= 100, "value invalid");
        require(_j >= 1 && _j <= 100, "value invalid");
        require(_k >= _i && _k <= 100, "value invalid");
        require(_l >= _j && _l <= 100, "value invalid");
        //require(_k >= _i && _l >= _j, "value invalid");
        require((_k-_i+1)*(_l-_j+1) <= limitGridsEachtime, "too many grids you selected, that may cause problems.");
        uint16 _x;
        uint16 _y;
        //string memory position;
        uint16 position;

        //log("mappingPositionToGirdId[position]: ", mappingPositionToGirdId[position]);
        //log("arr_struct_grid[1].level: ", arr_struct_grid[1].level);
        //log("msg.value: ", msg.value);
        //uint fee = msg.value;
        //address acc = msg.sender;

        uint256 currentPrice = 0;
        uint256 gridId = 0;
        uint256 tempLevelUpFee = 0;
        for(_x = _i; _x<=_k; _x++){
            for(_y = _j; _y<=_l; _y++){
                //position = strConcat(uint2str(_x),uint2str(_y));
                //log("position: ", position);
                position = (_x-1)*100+_y;
                gridId = mappingPositionToGirdId[position];
                if(gridId > 0){
                    structGird memory _grid = arr_struct_grid[gridId-1];
                    //if(_grid.level > 0){
                        //uint16 id = arr_struct_grid.push(structGird(_x, _y, 1)) - 1;
                        //mappingPositionToOwner[position] = msg.sender;
                        currentPrice += _grid.level * levelUpFee + levelUpFee;
                    //}
                }else{
                    //uint16 id = arr_struct_grid.push(structGird(_x, _y, 1)) - 1;
                    //mappingGirdPositionToOwner[position] = msg.sender;
                    if(discountGridsCount < 1000){
                        //currentPrice += levelUpFee;
                    }else if(discountGridsCount < 3000){
                        tempLevelUpFee = levelUpFee*1/10;
                    }else if(discountGridsCount < 6000){
                        tempLevelUpFee = levelUpFee*3/10;
                    }else if(discountGridsCount < 10000){
                        tempLevelUpFee = levelUpFee*6/10;
                    }else{
                        tempLevelUpFee = levelUpFee;
                    }
                    //discountGridsCount = discountGridsCount.add(1);
                    currentPrice += tempLevelUpFee;
                    //currentPrice += levelUpFee;
                }
            }
        }

        return currentPrice;
    }
}

pragma solidity ^0.5.0;

import "./GridBase.sol";
import "./ERC721.sol";
import "./safemath.sol";

contract GridOwnership is ERC721, GridBase {

  using SafeMath for uint256;

  mapping (uint => address) gridApprovals;

  modifier onlyOwnerOf(uint _gridId) {
    require(msg.sender == arr_struct_grid[_gridId].owner, "you are not owner of this grid");
    _;
  }

  function balanceOf(address _owner) public view returns (uint256 _balance) {
    return mappingOwnerGridCount[_owner];
  }

  function ownerOf(uint256 _tokenId) public view returns (address _owner) {
    _owner = arr_struct_grid[_tokenId].owner;
    require(_owner != address(0), "address invalid");
  }

  function _transfer(address _from, address payable _to, uint256 _tokenId) private {
    mappingOwnerGridCount[_to] = mappingOwnerGridCount[_to].add(1);
    mappingOwnerGridCount[msg.sender] = mappingOwnerGridCount[msg.sender].sub(1);
    arr_struct_grid[_tokenId].owner = _to;
    emit Transfer(_from, _to, _tokenId);
  }

  function transfer(address payable _to, uint256 _tokenId) external onlyOwnerOf(_tokenId) whenNotPaused {
    // Safety check to prevent against an unexpected 0x0 default.
    require(_to != address(0), "address invalid");
    // Disallow transfers to this contract to prevent accidental misuse.
    // The contract should never own any kitties (except very briefly
    // after a gen0 cat is created and before it goes on auction).
    require(_to != address(this), "address invalid");
    // Disallow transfers to the auction contracts to prevent accidental
    // misuse. Auction contracts should only take ownership of kitties
    // through the allow + transferFrom flow.
    //require(_to != address(saleAuction));
    //require(_to != address(siringAuction));
    _transfer(msg.sender, _to, _tokenId);
  }

  function approve(address payable _to, uint256 _tokenId) external onlyOwnerOf(_tokenId) whenNotPaused {
    gridApprovals[_tokenId] = _to;
    emit Approval(msg.sender, _to, _tokenId);
  }

  function takeOwnership(uint256 _tokenId) public {
    require(gridApprovals[_tokenId] == msg.sender, "you are not that guy");
    address owner = ownerOf(_tokenId);
    _transfer(owner, msg.sender, _tokenId);
  }
}
pragma solidity ^0.5.11;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address payable public owner;

    event ContractOwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
    constructor () public {
        owner = msg.sender;
    }


  /**
   * @dev Throws if called by any account other than the owner.
   */
    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
    function transferContractOwnership(address payable newOwner) public onlyOwner {
        require(newOwner != address(0), "new owner can not be empty");
        emit ContractOwnershipTransferred(owner, newOwner);
        owner = newOwner;
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

     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
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
     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

/**
 * @title SafeMath32
 * @dev SafeMath library implemented for uint32
 */
library SafeMath32 {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint32 a, uint32 b) internal pure returns (uint32) {
        uint32 c = a + b;
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
    function sub(uint32 a, uint32 b) internal pure returns (uint32) {
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
    function sub(uint32 a, uint32 b, string memory errorMessage) internal pure returns (uint32) {
        require(b <= a, errorMessage);
        uint32 c = a - b;

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
    function mul(uint32 a, uint32 b) internal pure returns (uint32) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint32 c = a * b;
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
    function div(uint32 a, uint32 b) internal pure returns (uint32) {
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
    function div(uint32 a, uint32 b, string memory errorMessage) internal pure returns (uint32) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint32 c = a / b;
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
    function mod(uint32 a, uint32 b) internal pure returns (uint32) {
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
    function mod(uint32 a, uint32 b, string memory errorMessage) internal pure returns (uint32) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

/**
 * @title SafeMath16
 * @dev SafeMath library implemented for uint16
 */
library SafeMath16 {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint16 a, uint16 b) internal pure returns (uint16) {
        uint16 c = a + b;
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
    function sub(uint16 a, uint16 b) internal pure returns (uint16) {
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
    function sub(uint16 a, uint16 b, string memory errorMessage) internal pure returns (uint16) {
        require(b <= a, errorMessage);
        uint16 c = a - b;

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
    function mul(uint16 a, uint16 b) internal pure returns (uint16) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint16 c = a * b;
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
    function div(uint16 a, uint16 b) internal pure returns (uint16) {
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
    function div(uint16 a, uint16 b, string memory errorMessage) internal pure returns (uint16) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint16 c = a / b;
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
    function mod(uint16 a, uint16 b) internal pure returns (uint16) {
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
    function mod(uint16 a, uint16 b, string memory errorMessage) internal pure returns (uint16) {
        require(b != 0, errorMessage);
        return a % b;
    }
}


pragma solidity ^0.5.0;
/// @title A facet of KittyCore that manages special access privileges.
/// @author Axiom Zen (https://www.axiomzen.co)
/// @dev See the KittyCore contract documentation to understand how the various contract facets are arranged.

contract AccessControl {
    // This facet controls access control for CryptoKitties. There are four roles managed here:
    //
    //     - The CEO: The CEO can reassign other roles and change the addresses of our dependent smart
    //         contracts. It is also the only role that can unpause the smart contract. It is initially
    //         set to the address that created the smart contract in the KittyCore constructor.
    //
    //     - The CFO: The CFO can withdraw funds from KittyCore and its auction contracts.
    //
    //     - The COO: The COO can release gen0 kitties to auction, and mint promo cats.
    //
    // It should be noted that these roles are distinct without overlap in their access abilities, the
    // abilities listed for each role above are exhaustive. In particular, while the CEO can assign any
    // address to any role, the CEO address itself doesn't have the ability to act in those roles. This
    // restriction is intentional so that we aren't tempted to use the CEO address frequently out of
    // convenience. The less we use an address, the less likely it is that we somehow compromise the
    // account.

    /// @dev Emited when contract is upgraded - See README.md for updgrade plan
    event ContractUpgrade(address newContract);

    // The addresses of the accounts (or contracts) that can execute actions within each roles.
    address public ceoAddress;
    address public cfoAddress;
    address public cooAddress;

    // @dev Keeps track whether the contract is paused. When that is true, most actions are blocked
    bool public paused = false;

    /// @dev Access modifier for CEO-only functionality
    modifier onlyCEO() {
        require(msg.sender == ceoAddress, "only CEO");
        _;
    }

    /// @dev Access modifier for CFO-only functionality
    modifier onlyCFO() {
        require(msg.sender == cfoAddress, "only CFO");
        _;
    }

    /// @dev Access modifier for COO-only functionality
    modifier onlyCOO() {
        require(msg.sender == cooAddress, "only COO");
        _;
    }

    modifier onlyCLevel() {
        require(
            msg.sender == cooAddress ||
            msg.sender == ceoAddress ||
            msg.sender == cfoAddress, "only CLevel"
        );
        _;
    }

    /// @dev Assigns a new address to act as the CEO. Only available to the current CEO.
    /// @param _newCEO The address of the new CEO
    function setCEO(address _newCEO) external onlyCEO {
        require(_newCEO != address(0), "newCEO looks like no changes");

        ceoAddress = _newCEO;
    }

    /// @dev Assigns a new address to act as the CFO. Only available to the current CEO.
    /// @param _newCFO The address of the new CFO
    function setCFO(address _newCFO) external onlyCEO {
        require(_newCFO != address(0), "newCFO looks like no changes");

        cfoAddress = _newCFO;
    }

    /// @dev Assigns a new address to act as the COO. Only available to the current CEO.
    /// @param _newCOO The address of the new COO
    function setCOO(address _newCOO) external onlyCEO {
        require(_newCOO != address(0), "newCOO looks like no changes");

        cooAddress = _newCOO;
    }

    /*** Pausable functionality adapted from OpenZeppelin ***/

    /// @dev Modifier to allow actions only when the contract IS NOT paused
    modifier whenNotPaused() {
        require(!paused, "current contract is paused");
        _;
    }

    /// @dev Modifier to allow actions only when the contract IS paused
    modifier whenPaused {
        require(paused, "current contract is not paused");
        _;
    }

    /// @dev Called by any "C-level" role to pause the contract. Used only when
    ///  a bug or exploit is detected and we need to limit damage.
    function pause() external onlyCLevel whenNotPaused {
        paused = true;
    }

    /// @dev Unpauses the smart contract. Can only be called by the CEO, since
    ///  one reason we may pause the contract is when CFO or COO accounts are
    ///  compromised.
    /// @notice This is public rather than external so it can be called by
    ///  derived contracts.
    function unpause() public onlyCEO whenPaused {
        // can't unpause if contract was upgraded
        paused = false;
    }
}

pragma solidity ^0.5.11;

contract ERC721 {
    event Transfer(address indexed _from, address indexed _to, uint256 _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 _tokenId);

    function balanceOf(address _owner) public view returns (uint256 _balance);
    function ownerOf(uint256 _tokenId) public view returns (address _owner);
    function transfer(address payable _to, uint256 _tokenId) external;
    function approve(address payable _to, uint256 _tokenId) external;
    function takeOwnership(uint256 _tokenId) public;
}

pragma solidity ^0.5.11;

import "./ownable.sol";
import "./AccessControl.sol";
//import "./GridOwnership.sol";
//import "./safemath.sol";
//import "./console.sol";

contract GridBase is Ownable, AccessControl {

    //using SafeMath for uint256;

    uint public levelUpFee = 0.01 ether;
    uint public limitGridsEachtime = 100;
    uint public discountGridsCount = 0;

    //uint fee;

    struct structGird {
        uint16 x;
        uint16 y;
        uint level;
        address payable owner;
        address payable inviter;
    }

    structGird[] public arr_struct_grid;

    mapping (address => uint) public mappingOwnerGridCount;
    mapping (uint16 => uint) public mappingPositionToGirdId;

    // Set in case the core contract is broken and an upgrade is required
    address public newContractAddress;

    address payable public authorAddress;
    address payable public foundationAddress;

    /// @notice Creates the main CryptoKitties smart contract instance.
    constructor () public {
        // Starts paused.
        paused = true;

        // the creator of the contract is the initial CEO
        ceoAddress = msg.sender;
        // the creator of the contract is also the initial COO
        cooAddress = msg.sender;
        cfoAddress = msg.sender;
    }

    /// @dev Used to mark the smart contract as upgraded, in case there is a serious
    ///  breaking bug. This method does nothing but keep track of the new contract and
    ///  emit a message indicating that the new address is set. It's up to clients of this
    ///  contract to update to the new contract address in that case. (This contract will
    ///  be paused indefinitely if such an upgrade takes place.)
    /// @param _v2Address new address
    function setNewContractAddress(address _v2Address) external onlyCEO whenPaused {
        // See README.md for updgrade plan
        newContractAddress = _v2Address;
        emit ContractUpgrade(_v2Address);
    }

    function setAuthorAddress(address payable _address) external onlyCEO whenPaused {
        require(_address != address(0), "authorAddress can not be empty");
        authorAddress = _address;
    }

    function setFoundationAddress(address payable _address) external onlyCEO whenPaused {
        require(_address != address(0), "foundationAddress can not be empty");
        foundationAddress = _address;
    }

    /*/// @notice Returns all the relevant information about a specific kitty.
    /// @param _id The ID of the kitty of interest.
    function getGrid(uint256 _id)
        external
        view
        returns (
        uint16 x,
        uint16 y,
        uint256 level
    ) {
        structGird memory _grid = arr_struct_grid[_id];

        x = uint16(_grid.x);
        y = uint16(_grid.y);
        level = uint256(_grid.level);
    }*/

    /// @dev Override unpause so it requires all external contract addresses
    ///  to be set before contract can be unpaused. Also, we can't have
    ///  newContractAddress set either, because then the contract was upgraded.
    /// @notice This is public rather than external so we can call super.unpause
    ///  without using an expensive CALL.
    function unpause() public onlyCEO whenPaused {
        require(newContractAddress == address(0), "set newContractAddress first");
        require(authorAddress != address(0), "set authorAddress first");
        require(foundationAddress != address(0), "set foundationAddress first");

        // Actually unpause the contract.
        super.unpause();
    }

    function withdraw() external onlyOwner whenPaused {
        owner.transfer(address(this).balance);
    }

    function setLevelUpFee(uint _fee) external onlyCLevel whenPaused {
        levelUpFee = _fee;
    }

    function setlimitGridsEachtime(uint _limit) external onlyCLevel whenPaused {
        limitGridsEachtime = _limit;
    }


  function getContractStatus() external view onlyCLevel returns(uint, uint, uint) {
    return (levelUpFee, limitGridsEachtime, address(this).balance);
  }

  function getLevelUpFee() external view whenNotPaused returns(uint) {
    return levelUpFee;
  }

  function getLimitGridsEachtime() external view whenNotPaused returns(uint) {
    return limitGridsEachtime;
  }

  function getContractBalance() external view onlyCLevel returns(uint) {
    return address(this).balance;
  }
}

pragma solidity ^0.5.11;

import "./GridOwnership.sol";
import "./safemath.sol";
//import "./console.sol";

contract GridMain is GridOwnership {

    using SafeMath for uint256;
    using SafeMath32 for uint32;
    using SafeMath16 for uint16;

    //uint16 public version = 101;

    function buyGird(uint16 _i, uint16 _j, uint16 _k, uint16 _l, address payable _inviter) external payable whenNotPaused {
        require(_i >= 1 && _i <= 100, "value invalid");
        require(_j >= 1 && _j <= 100, "value invalid");
        require(_k >= _i && _k <= 100, "value invalid");
        require(_l >= _j && _l <= 100, "value invalid");
        //require(_k >= _i && _l >= _j, "value invalid");
        require((_k-_i+1)*(_l-_j+1) <= limitGridsEachtime, "too many grids you selected, that may cause problems.");
        uint16 _x;
        uint16 _y;
        //string memory position;
        uint16 position;
        uint256 currentPrice = 0;
        uint256 gridId = 0;
        uint256 tempLevelUpFee = 0;
        address payable inviter;

        if(_inviter == address(0)){
            inviter = owner;
        }else{
            inviter = _inviter;
        }

        //log("mappingPositionToGirdId[position]: ", mappingPositionToGirdId[position]);
        //log("arr_struct_grid[1].level: ", arr_struct_grid[1].level);
        //log("msg.value: ", msg.value);
        //uint fee = msg.value;
        //address acc = msg.sender;

        for(_x = _i; _x<=_k; _x++){
            for(_y = _j; _y<=_l; _y++){
                //position = strConcat(uint2str(_x),uint2str(_y));
                //log("position: ", position);
                position = (_x-1)*100+_y;
                gridId = mappingPositionToGirdId[position];
                if(gridId > 0){
                    structGird storage _grid = arr_struct_grid[gridId-1];
                    //if(_grid.level > 0){
                        //uint16 id = arr_struct_grid.push(structGird(_x, _y, 1)) - 1;
                        //mappingPositionToOwner[position] = msg.sender;
                        currentPrice += _grid.level * levelUpFee + levelUpFee;
                        _grid.owner.transfer(_grid.level * levelUpFee + levelUpFee / 5);
                    _grid.inviter.transfer(levelUpFee / 10);
                    authorAddress.transfer(levelUpFee / 10);
                    foundationAddress.transfer(levelUpFee / 10);
                    owner.transfer(levelUpFee/50);
                    mappingOwnerGridCount[_grid.owner] = mappingOwnerGridCount[_grid.owner].sub(1);
                    mappingOwnerGridCount[msg.sender] = mappingOwnerGridCount[msg.sender].add(1);
                    _grid.level = _grid.level.add(1);
                    _grid.owner = msg.sender;
                    if(_grid.inviter != inviter){
                        _grid.inviter = inviter;
                    }
                    //}
                }else{
                    //uint16 id = arr_struct_grid.push(structGird(_x, _y, 1)) - 1;
                    //mappingGirdPositionToOwner[position] = msg.sender;
                    //tempLevelUpFee = levelUpFee;
                    if(discountGridsCount < 1000){
                        //currentPrice += levelUpFee;
                    }else if(discountGridsCount < 3000){
                        tempLevelUpFee = levelUpFee*1/10;
                    }else if(discountGridsCount < 6000){
                        tempLevelUpFee = levelUpFee*3/10;
                    }else if(discountGridsCount < 10000){
                        tempLevelUpFee = levelUpFee*6/10;
                    }else{
                        tempLevelUpFee = levelUpFee;
                    }
                    discountGridsCount = discountGridsCount.add(1);
                    currentPrice += tempLevelUpFee;
                    uint id = arr_struct_grid.push(structGird(_x, _y, 1, msg.sender, inviter));
                    mappingPositionToGirdId[position] = id;
                    mappingOwnerGridCount[msg.sender] = mappingOwnerGridCount[msg.sender].add(1);
                    owner.transfer(tempLevelUpFee);
                }
            }
        }
        require(msg.value >= currentPrice, "out of your balance");
        //require(address(this).balance >= currentPrice, "out of contract balance, please buy level0 grids");
        /*for(_x = _i; _x<=_k; _x++){
            for(_y = _j; _y<=_l; _y++){
                //position = strConcat(uint2str(_x),uint2str(_y));
                position = (_x-1)*100+_y;
                gridId = mappingPositionToGirdId[position];
                if(gridId > 0){
                    structGird memory _grid = arr_struct_grid[gridId-1];
                 //&& _grid.level > 0){
                    //uint16 id = arr_struct_grid.push(structGird(_x, _y, 1)) - 1;
                    //mappingPositionToOwner[position] = msg.sender;
                    //mappingPositionToGird[position].level = mappingPositionToGird[position].level.add(1);
                    //mappingPositionToGird[position].owner = msg.sender;
                    _grid.owner.transfer(_grid.level * levelUpFee + levelUpFee / 5);
                    _grid.inviter.transfer(levelUpFee / 10);
                    authorAddress.transfer(levelUpFee / 10);
                    foundationAddress.transfer(levelUpFee / 10);
                    owner.transfer(levelUpFee/50);

                    mappingOwnerGridCount[_grid.owner] = mappingOwnerGridCount[_grid.owner].sub(1);
                    mappingOwnerGridCount[msg.sender] = mappingOwnerGridCount[msg.sender].add(1);
                    _grid.level = _grid.level.add(1);
                    _grid.owner = msg.sender;
                    _grid.inviter = inviter;
                }else{
                    uint id = arr_struct_grid.push(structGird(_x, _y, 1, msg.sender, inviter));
                    mappingPositionToGirdId[position] = id;
                    mappingOwnerGridCount[msg.sender] = mappingOwnerGridCount[msg.sender].add(1);
                    owner.transfer(levelUpFee);
                    //mappingGirdPositionToOwner[position] = msg.sender;
                    //mappingPositionToGird[position] = structGird(_x, _y, 1, msg.sender);
                }
            }
        }*/
        msg.sender.transfer(msg.value.sub(currentPrice));
    }

    function getGridPrice(uint16 _i, uint16 _j, uint16 _k, uint16 _l) external view whenNotPaused returns(uint256){
        require(_i >= 1 && _i <= 100, "value invalid");
        require(_j >= 1 && _j <= 100, "value invalid");
        require(_k >= _i && _k <= 100, "value invalid");
        require(_l >= _j && _l <= 100, "value invalid");
        //require(_k >= _i && _l >= _j, "value invalid");
        require((_k-_i+1)*(_l-_j+1) <= limitGridsEachtime, "too many grids you selected, that may cause problems.");
        uint16 _x;
        uint16 _y;
        //string memory position;
        uint16 position;

        //log("mappingPositionToGirdId[position]: ", mappingPositionToGirdId[position]);
        //log("arr_struct_grid[1].level: ", arr_struct_grid[1].level);
        //log("msg.value: ", msg.value);
        //uint fee = msg.value;
        //address acc = msg.sender;

        uint256 currentPrice = 0;
        uint256 gridId = 0;
        uint256 tempLevelUpFee = 0;
        for(_x = _i; _x<=_k; _x++){
            for(_y = _j; _y<=_l; _y++){
                //position = strConcat(uint2str(_x),uint2str(_y));
                //log("position: ", position);
                position = (_x-1)*100+_y;
                gridId = mappingPositionToGirdId[position];
                if(gridId > 0){
                    structGird memory _grid = arr_struct_grid[gridId-1];
                    //if(_grid.level > 0){
                        //uint16 id = arr_struct_grid.push(structGird(_x, _y, 1)) - 1;
                        //mappingPositionToOwner[position] = msg.sender;
                        currentPrice += _grid.level * levelUpFee + levelUpFee;
                    //}
                }else{
                    //uint16 id = arr_struct_grid.push(structGird(_x, _y, 1)) - 1;
                    //mappingGirdPositionToOwner[position] = msg.sender;
                    if(discountGridsCount < 1000){
                        //currentPrice += levelUpFee;
                    }else if(discountGridsCount < 3000){
                        tempLevelUpFee = levelUpFee*1/10;
                    }else if(discountGridsCount < 6000){
                        tempLevelUpFee = levelUpFee*3/10;
                    }else if(discountGridsCount < 10000){
                        tempLevelUpFee = levelUpFee*6/10;
                    }else{
                        tempLevelUpFee = levelUpFee;
                    }
                    //discountGridsCount = discountGridsCount.add(1);
                    currentPrice += tempLevelUpFee;
                    //currentPrice += levelUpFee;
                }
            }
        }

        return currentPrice;
    }
}

pragma solidity ^0.5.0;

import "./GridBase.sol";
import "./ERC721.sol";
import "./safemath.sol";

contract GridOwnership is ERC721, GridBase {

  using SafeMath for uint256;

  mapping (uint => address) gridApprovals;

  modifier onlyOwnerOf(uint _gridId) {
    require(msg.sender == arr_struct_grid[_gridId].owner, "you are not owner of this grid");
    _;
  }

  function balanceOf(address _owner) public view returns (uint256 _balance) {
    return mappingOwnerGridCount[_owner];
  }

  function ownerOf(uint256 _tokenId) public view returns (address _owner) {
    _owner = arr_struct_grid[_tokenId].owner;
    require(_owner != address(0), "address invalid");
  }

  function _transfer(address _from, address payable _to, uint256 _tokenId) private {
    mappingOwnerGridCount[_to] = mappingOwnerGridCount[_to].add(1);
    mappingOwnerGridCount[msg.sender] = mappingOwnerGridCount[msg.sender].sub(1);
    arr_struct_grid[_tokenId].owner = _to;
    emit Transfer(_from, _to, _tokenId);
  }

  function transfer(address payable _to, uint256 _tokenId) external onlyOwnerOf(_tokenId) whenNotPaused {
    // Safety check to prevent against an unexpected 0x0 default.
    require(_to != address(0), "address invalid");
    // Disallow transfers to this contract to prevent accidental misuse.
    // The contract should never own any kitties (except very briefly
    // after a gen0 cat is created and before it goes on auction).
    require(_to != address(this), "address invalid");
    // Disallow transfers to the auction contracts to prevent accidental
    // misuse. Auction contracts should only take ownership of kitties
    // through the allow + transferFrom flow.
    //require(_to != address(saleAuction));
    //require(_to != address(siringAuction));
    _transfer(msg.sender, _to, _tokenId);
  }

  function approve(address payable _to, uint256 _tokenId) external onlyOwnerOf(_tokenId) whenNotPaused {
    gridApprovals[_tokenId] = _to;
    emit Approval(msg.sender, _to, _tokenId);
  }

  function takeOwnership(uint256 _tokenId) public {
    require(gridApprovals[_tokenId] == msg.sender, "you are not that guy");
    address owner = ownerOf(_tokenId);
    _transfer(owner, msg.sender, _tokenId);
  }
}
pragma solidity ^0.5.11;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address payable public owner;

    event ContractOwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
    constructor () public {
        owner = msg.sender;
    }


  /**
   * @dev Throws if called by any account other than the owner.
   */
    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
    function transferContractOwnership(address payable newOwner) public onlyOwner {
        require(newOwner != address(0), "new owner can not be empty");
        emit ContractOwnershipTransferred(owner, newOwner);
        owner = newOwner;
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

     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
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
     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

/**
 * @title SafeMath32
 * @dev SafeMath library implemented for uint32
 */
library SafeMath32 {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint32 a, uint32 b) internal pure returns (uint32) {
        uint32 c = a + b;
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
    function sub(uint32 a, uint32 b) internal pure returns (uint32) {
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
    function sub(uint32 a, uint32 b, string memory errorMessage) internal pure returns (uint32) {
        require(b <= a, errorMessage);
        uint32 c = a - b;

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
    function mul(uint32 a, uint32 b) internal pure returns (uint32) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint32 c = a * b;
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
    function div(uint32 a, uint32 b) internal pure returns (uint32) {
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
    function div(uint32 a, uint32 b, string memory errorMessage) internal pure returns (uint32) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint32 c = a / b;
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
    function mod(uint32 a, uint32 b) internal pure returns (uint32) {
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
    function mod(uint32 a, uint32 b, string memory errorMessage) internal pure returns (uint32) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

/**
 * @title SafeMath16
 * @dev SafeMath library implemented for uint16
 */
library SafeMath16 {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint16 a, uint16 b) internal pure returns (uint16) {
        uint16 c = a + b;
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
    function sub(uint16 a, uint16 b) internal pure returns (uint16) {
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
    function sub(uint16 a, uint16 b, string memory errorMessage) internal pure returns (uint16) {
        require(b <= a, errorMessage);
        uint16 c = a - b;

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
    function mul(uint16 a, uint16 b) internal pure returns (uint16) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint16 c = a * b;
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
    function div(uint16 a, uint16 b) internal pure returns (uint16) {
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
    function div(uint16 a, uint16 b, string memory errorMessage) internal pure returns (uint16) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint16 c = a / b;
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
    function mod(uint16 a, uint16 b) internal pure returns (uint16) {
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
    function mod(uint16 a, uint16 b, string memory errorMessage) internal pure returns (uint16) {
        require(b != 0, errorMessage);
        return a % b;
    }
}


pragma solidity ^0.5.0;
/// @title A facet of KittyCore that manages special access privileges.
/// @author Axiom Zen (https://www.axiomzen.co)
/// @dev See the KittyCore contract documentation to understand how the various contract facets are arranged.

contract AccessControl {
    // This facet controls access control for CryptoKitties. There are four roles managed here:
    //
    //     - The CEO: The CEO can reassign other roles and change the addresses of our dependent smart
    //         contracts. It is also the only role that can unpause the smart contract. It is initially
    //         set to the address that created the smart contract in the KittyCore constructor.
    //
    //     - The CFO: The CFO can withdraw funds from KittyCore and its auction contracts.
    //
    //     - The COO: The COO can release gen0 kitties to auction, and mint promo cats.
    //
    // It should be noted that these roles are distinct without overlap in their access abilities, the
    // abilities listed for each role above are exhaustive. In particular, while the CEO can assign any
    // address to any role, the CEO address itself doesn't have the ability to act in those roles. This
    // restriction is intentional so that we aren't tempted to use the CEO address frequently out of
    // convenience. The less we use an address, the less likely it is that we somehow compromise the
    // account.

    /// @dev Emited when contract is upgraded - See README.md for updgrade plan
    event ContractUpgrade(address newContract);

    // The addresses of the accounts (or contracts) that can execute actions within each roles.
    address public ceoAddress;
    address public cfoAddress;
    address public cooAddress;

    // @dev Keeps track whether the contract is paused. When that is true, most actions are blocked
    bool public paused = false;

    /// @dev Access modifier for CEO-only functionality
    modifier onlyCEO() {
        require(msg.sender == ceoAddress, "only CEO");
        _;
    }

    /// @dev Access modifier for CFO-only functionality
    modifier onlyCFO() {
        require(msg.sender == cfoAddress, "only CFO");
        _;
    }

    /// @dev Access modifier for COO-only functionality
    modifier onlyCOO() {
        require(msg.sender == cooAddress, "only COO");
        _;
    }

    modifier onlyCLevel() {
        require(
            msg.sender == cooAddress ||
            msg.sender == ceoAddress ||
            msg.sender == cfoAddress, "only CLevel"
        );
        _;
    }

    /// @dev Assigns a new address to act as the CEO. Only available to the current CEO.
    /// @param _newCEO The address of the new CEO
    function setCEO(address _newCEO) external onlyCEO {
        require(_newCEO != address(0), "newCEO looks like no changes");

        ceoAddress = _newCEO;
    }

    /// @dev Assigns a new address to act as the CFO. Only available to the current CEO.
    /// @param _newCFO The address of the new CFO
    function setCFO(address _newCFO) external onlyCEO {
        require(_newCFO != address(0), "newCFO looks like no changes");

        cfoAddress = _newCFO;
    }

    /// @dev Assigns a new address to act as the COO. Only available to the current CEO.
    /// @param _newCOO The address of the new COO
    function setCOO(address _newCOO) external onlyCEO {
        require(_newCOO != address(0), "newCOO looks like no changes");

        cooAddress = _newCOO;
    }

    /*** Pausable functionality adapted from OpenZeppelin ***/

    /// @dev Modifier to allow actions only when the contract IS NOT paused
    modifier whenNotPaused() {
        require(!paused, "current contract is paused");
        _;
    }

    /// @dev Modifier to allow actions only when the contract IS paused
    modifier whenPaused {
        require(paused, "current contract is not paused");
        _;
    }

    /// @dev Called by any "C-level" role to pause the contract. Used only when
    ///  a bug or exploit is detected and we need to limit damage.
    function pause() external onlyCLevel whenNotPaused {
        paused = true;
    }

    /// @dev Unpauses the smart contract. Can only be called by the CEO, since
    ///  one reason we may pause the contract is when CFO or COO accounts are
    ///  compromised.
    /// @notice This is public rather than external so it can be called by
    ///  derived contracts.
    function unpause() public onlyCEO whenPaused {
        // can't unpause if contract was upgraded
        paused = false;
    }
}

pragma solidity ^0.5.11;

contract ERC721 {
    event Transfer(address indexed _from, address indexed _to, uint256 _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 _tokenId);

    function balanceOf(address _owner) public view returns (uint256 _balance);
    function ownerOf(uint256 _tokenId) public view returns (address _owner);
    function transfer(address payable _to, uint256 _tokenId) external;
    function approve(address payable _to, uint256 _tokenId) external;
    function takeOwnership(uint256 _tokenId) public;
}

pragma solidity ^0.5.11;

import "./ownable.sol";
import "./AccessControl.sol";
//import "./GridOwnership.sol";
//import "./safemath.sol";
//import "./console.sol";

contract GridBase is Ownable, AccessControl {

    //using SafeMath for uint256;

    uint public levelUpFee = 0.01 ether;
    uint public limitGridsEachtime = 100;
    uint public discountGridsCount = 0;

    //uint fee;

    struct structGird {
        uint16 x;
        uint16 y;
        uint level;
        address payable owner;
        address payable inviter;
    }

    structGird[] public arr_struct_grid;

    mapping (address => uint) public mappingOwnerGridCount;
    mapping (uint16 => uint) public mappingPositionToGirdId;

    // Set in case the core contract is broken and an upgrade is required
    address public newContractAddress;

    address payable public authorAddress;
    address payable public foundationAddress;

    /// @notice Creates the main CryptoKitties smart contract instance.
    constructor () public {
        // Starts paused.
        paused = true;

        // the creator of the contract is the initial CEO
        ceoAddress = msg.sender;
        // the creator of the contract is also the initial COO
        cooAddress = msg.sender;
        cfoAddress = msg.sender;
    }

    /// @dev Used to mark the smart contract as upgraded, in case there is a serious
    ///  breaking bug. This method does nothing but keep track of the new contract and
    ///  emit a message indicating that the new address is set. It's up to clients of this
    ///  contract to update to the new contract address in that case. (This contract will
    ///  be paused indefinitely if such an upgrade takes place.)
    /// @param _v2Address new address
    function setNewContractAddress(address _v2Address) external onlyCEO whenPaused {
        // See README.md for updgrade plan
        newContractAddress = _v2Address;
        emit ContractUpgrade(_v2Address);
    }

    function setAuthorAddress(address payable _address) external onlyCEO whenPaused {
        require(_address != address(0), "authorAddress can not be empty");
        authorAddress = _address;
    }

    function setFoundationAddress(address payable _address) external onlyCEO whenPaused {
        require(_address != address(0), "foundationAddress can not be empty");
        foundationAddress = _address;
    }

    /*/// @notice Returns all the relevant information about a specific kitty.
    /// @param _id The ID of the kitty of interest.
    function getGrid(uint256 _id)
        external
        view
        returns (
        uint16 x,
        uint16 y,
        uint256 level
    ) {
        structGird memory _grid = arr_struct_grid[_id];

        x = uint16(_grid.x);
        y = uint16(_grid.y);
        level = uint256(_grid.level);
    }*/

    /// @dev Override unpause so it requires all external contract addresses
    ///  to be set before contract can be unpaused. Also, we can't have
    ///  newContractAddress set either, because then the contract was upgraded.
    /// @notice This is public rather than external so we can call super.unpause
    ///  without using an expensive CALL.
    function unpause() public onlyCEO whenPaused {
        require(newContractAddress == address(0), "set newContractAddress first");
        require(authorAddress != address(0), "set authorAddress first");
        require(foundationAddress != address(0), "set foundationAddress first");

        // Actually unpause the contract.
        super.unpause();
    }

    function withdraw() external onlyOwner whenPaused {
        owner.transfer(address(this).balance);
    }

    function setLevelUpFee(uint _fee) external onlyCLevel whenPaused {
        levelUpFee = _fee;
    }

    function setlimitGridsEachtime(uint _limit) external onlyCLevel whenPaused {
        limitGridsEachtime = _limit;
    }


  function getContractStatus() external view onlyCLevel returns(uint, uint, uint) {
    return (levelUpFee, limitGridsEachtime, address(this).balance);
  }

  function getLevelUpFee() external view whenNotPaused returns(uint) {
    return levelUpFee;
  }

  function getLimitGridsEachtime() external view whenNotPaused returns(uint) {
    return limitGridsEachtime;
  }

  function getContractBalance() external view onlyCLevel returns(uint) {
    return address(this).balance;
  }
}

pragma solidity ^0.5.11;

import "./GridOwnership.sol";
import "./safemath.sol";
//import "./console.sol";

contract GridMain is GridOwnership {

    using SafeMath for uint256;
    using SafeMath32 for uint32;
    using SafeMath16 for uint16;

    //uint16 public version = 101;

    function buyGird(uint16 _i, uint16 _j, uint16 _k, uint16 _l, address payable _inviter) external payable whenNotPaused {
        require(_i >= 1 && _i <= 100, "value invalid");
        require(_j >= 1 && _j <= 100, "value invalid");
        require(_k >= _i && _k <= 100, "value invalid");
        require(_l >= _j && _l <= 100, "value invalid");
        //require(_k >= _i && _l >= _j, "value invalid");
        require((_k-_i+1)*(_l-_j+1) <= limitGridsEachtime, "too many grids you selected, that may cause problems.");
        uint16 _x;
        uint16 _y;
        //string memory position;
        uint16 position;
        uint256 currentPrice = 0;
        uint256 gridId = 0;
        uint256 tempLevelUpFee = 0;
        address payable inviter;

        if(_inviter == address(0)){
            inviter = owner;
        }else{
            inviter = _inviter;
        }

        //log("mappingPositionToGirdId[position]: ", mappingPositionToGirdId[position]);
        //log("arr_struct_grid[1].level: ", arr_struct_grid[1].level);
        //log("msg.value: ", msg.value);
        //uint fee = msg.value;
        //address acc = msg.sender;

        for(_x = _i; _x<=_k; _x++){
            for(_y = _j; _y<=_l; _y++){
                //position = strConcat(uint2str(_x),uint2str(_y));
                //log("position: ", position);
                position = (_x-1)*100+_y;
                gridId = mappingPositionToGirdId[position];
                if(gridId > 0){
                    structGird storage _grid = arr_struct_grid[gridId-1];
                    //if(_grid.level > 0){
                        //uint16 id = arr_struct_grid.push(structGird(_x, _y, 1)) - 1;
                        //mappingPositionToOwner[position] = msg.sender;
                        currentPrice += _grid.level * levelUpFee + levelUpFee;
                        _grid.owner.transfer(_grid.level * levelUpFee + levelUpFee / 5);
                    _grid.inviter.transfer(levelUpFee / 10);
                    authorAddress.transfer(levelUpFee / 10);
                    foundationAddress.transfer(levelUpFee / 10);
                    owner.transfer(levelUpFee/50);
                    mappingOwnerGridCount[_grid.owner] = mappingOwnerGridCount[_grid.owner].sub(1);
                    mappingOwnerGridCount[msg.sender] = mappingOwnerGridCount[msg.sender].add(1);
                    _grid.level = _grid.level.add(1);
                    _grid.owner = msg.sender;
                    if(_grid.inviter != inviter){
                        _grid.inviter = inviter;
                    }
                    //}
                }else{
                    //uint16 id = arr_struct_grid.push(structGird(_x, _y, 1)) - 1;
                    //mappingGirdPositionToOwner[position] = msg.sender;
                    //tempLevelUpFee = levelUpFee;
                    if(discountGridsCount < 1000){
                        //currentPrice += levelUpFee;
                    }else if(discountGridsCount < 3000){
                        tempLevelUpFee = levelUpFee*1/10;
                    }else if(discountGridsCount < 6000){
                        tempLevelUpFee = levelUpFee*3/10;
                    }else if(discountGridsCount < 10000){
                        tempLevelUpFee = levelUpFee*6/10;
                    }else{
                        tempLevelUpFee = levelUpFee;
                    }
                    discountGridsCount = discountGridsCount.add(1);
                    currentPrice += tempLevelUpFee;
                    uint id = arr_struct_grid.push(structGird(_x, _y, 1, msg.sender, inviter));
                    mappingPositionToGirdId[position] = id;
                    mappingOwnerGridCount[msg.sender] = mappingOwnerGridCount[msg.sender].add(1);
                    owner.transfer(tempLevelUpFee);
                }
            }
        }
        require(msg.value >= currentPrice, "out of your balance");
        //require(address(this).balance >= currentPrice, "out of contract balance, please buy level0 grids");
        /*for(_x = _i; _x<=_k; _x++){
            for(_y = _j; _y<=_l; _y++){
                //position = strConcat(uint2str(_x),uint2str(_y));
                position = (_x-1)*100+_y;
                gridId = mappingPositionToGirdId[position];
                if(gridId > 0){
                    structGird memory _grid = arr_struct_grid[gridId-1];
                 //&& _grid.level > 0){
                    //uint16 id = arr_struct_grid.push(structGird(_x, _y, 1)) - 1;
                    //mappingPositionToOwner[position] = msg.sender;
                    //mappingPositionToGird[position].level = mappingPositionToGird[position].level.add(1);
                    //mappingPositionToGird[position].owner = msg.sender;
                    _grid.owner.transfer(_grid.level * levelUpFee + levelUpFee / 5);
                    _grid.inviter.transfer(levelUpFee / 10);
                    authorAddress.transfer(levelUpFee / 10);
                    foundationAddress.transfer(levelUpFee / 10);
                    owner.transfer(levelUpFee/50);

                    mappingOwnerGridCount[_grid.owner] = mappingOwnerGridCount[_grid.owner].sub(1);
                    mappingOwnerGridCount[msg.sender] = mappingOwnerGridCount[msg.sender].add(1);
                    _grid.level = _grid.level.add(1);
                    _grid.owner = msg.sender;
                    _grid.inviter = inviter;
                }else{
                    uint id = arr_struct_grid.push(structGird(_x, _y, 1, msg.sender, inviter));
                    mappingPositionToGirdId[position] = id;
                    mappingOwnerGridCount[msg.sender] = mappingOwnerGridCount[msg.sender].add(1);
                    owner.transfer(levelUpFee);
                    //mappingGirdPositionToOwner[position] = msg.sender;
                    //mappingPositionToGird[position] = structGird(_x, _y, 1, msg.sender);
                }
            }
        }*/
        msg.sender.transfer(msg.value.sub(currentPrice));
    }

    function getGridPrice(uint16 _i, uint16 _j, uint16 _k, uint16 _l) external view whenNotPaused returns(uint256){
        require(_i >= 1 && _i <= 100, "value invalid");
        require(_j >= 1 && _j <= 100, "value invalid");
        require(_k >= _i && _k <= 100, "value invalid");
        require(_l >= _j && _l <= 100, "value invalid");
        //require(_k >= _i && _l >= _j, "value invalid");
        require((_k-_i+1)*(_l-_j+1) <= limitGridsEachtime, "too many grids you selected, that may cause problems.");
        uint16 _x;
        uint16 _y;
        //string memory position;
        uint16 position;

        //log("mappingPositionToGirdId[position]: ", mappingPositionToGirdId[position]);
        //log("arr_struct_grid[1].level: ", arr_struct_grid[1].level);
        //log("msg.value: ", msg.value);
        //uint fee = msg.value;
        //address acc = msg.sender;

        uint256 currentPrice = 0;
        uint256 gridId = 0;
        uint256 tempLevelUpFee = 0;
        for(_x = _i; _x<=_k; _x++){
            for(_y = _j; _y<=_l; _y++){
                //position = strConcat(uint2str(_x),uint2str(_y));
                //log("position: ", position);
                position = (_x-1)*100+_y;
                gridId = mappingPositionToGirdId[position];
                if(gridId > 0){
                    structGird memory _grid = arr_struct_grid[gridId-1];
                    //if(_grid.level > 0){
                        //uint16 id = arr_struct_grid.push(structGird(_x, _y, 1)) - 1;
                        //mappingPositionToOwner[position] = msg.sender;
                        currentPrice += _grid.level * levelUpFee + levelUpFee;
                    //}
                }else{
                    //uint16 id = arr_struct_grid.push(structGird(_x, _y, 1)) - 1;
                    //mappingGirdPositionToOwner[position] = msg.sender;
                    if(discountGridsCount < 1000){
                        //currentPrice += levelUpFee;
                    }else if(discountGridsCount < 3000){
                        tempLevelUpFee = levelUpFee*1/10;
                    }else if(discountGridsCount < 6000){
                        tempLevelUpFee = levelUpFee*3/10;
                    }else if(discountGridsCount < 10000){
                        tempLevelUpFee = levelUpFee*6/10;
                    }else{
                        tempLevelUpFee = levelUpFee;
                    }
                    //discountGridsCount = discountGridsCount.add(1);
                    currentPrice += tempLevelUpFee;
                    //currentPrice += levelUpFee;
                }
            }
        }

        return currentPrice;
    }
}

pragma solidity ^0.5.0;

import "./GridBase.sol";
import "./ERC721.sol";
import "./safemath.sol";

contract GridOwnership is ERC721, GridBase {

  using SafeMath for uint256;

  mapping (uint => address) gridApprovals;

  modifier onlyOwnerOf(uint _gridId) {
    require(msg.sender == arr_struct_grid[_gridId].owner, "you are not owner of this grid");
    _;
  }

  function balanceOf(address _owner) public view returns (uint256 _balance) {
    return mappingOwnerGridCount[_owner];
  }

  function ownerOf(uint256 _tokenId) public view returns (address _owner) {
    _owner = arr_struct_grid[_tokenId].owner;
    require(_owner != address(0), "address invalid");
  }

  function _transfer(address _from, address payable _to, uint256 _tokenId) private {
    mappingOwnerGridCount[_to] = mappingOwnerGridCount[_to].add(1);
    mappingOwnerGridCount[msg.sender] = mappingOwnerGridCount[msg.sender].sub(1);
    arr_struct_grid[_tokenId].owner = _to;
    emit Transfer(_from, _to, _tokenId);
  }

  function transfer(address payable _to, uint256 _tokenId) external onlyOwnerOf(_tokenId) whenNotPaused {
    // Safety check to prevent against an unexpected 0x0 default.
    require(_to != address(0), "address invalid");
    // Disallow transfers to this contract to prevent accidental misuse.
    // The contract should never own any kitties (except very briefly
    // after a gen0 cat is created and before it goes on auction).
    require(_to != address(this), "address invalid");
    // Disallow transfers to the auction contracts to prevent accidental
    // misuse. Auction contracts should only take ownership of kitties
    // through the allow + transferFrom flow.
    //require(_to != address(saleAuction));
    //require(_to != address(siringAuction));
    _transfer(msg.sender, _to, _tokenId);
  }

  function approve(address payable _to, uint256 _tokenId) external onlyOwnerOf(_tokenId) whenNotPaused {
    gridApprovals[_tokenId] = _to;
    emit Approval(msg.sender, _to, _tokenId);
  }

  function takeOwnership(uint256 _tokenId) public {
    require(gridApprovals[_tokenId] == msg.sender, "you are not that guy");
    address owner = ownerOf(_tokenId);
    _transfer(owner, msg.sender, _tokenId);
  }
}
pragma solidity ^0.5.11;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address payable public owner;

    event ContractOwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
    constructor () public {
        owner = msg.sender;
    }


  /**
   * @dev Throws if called by any account other than the owner.
   */
    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
    function transferContractOwnership(address payable newOwner) public onlyOwner {
        require(newOwner != address(0), "new owner can not be empty");
        emit ContractOwnershipTransferred(owner, newOwner);
        owner = newOwner;
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

     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
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
     * NOTE: This is a feature of the next version of OpenZeppelin Contracts.
     * @dev Get it via `npm install @openzeppelin/contracts@next`.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

/**
 * @title SafeMath32
 * @dev SafeMath library implemented for uint32
 */
library SafeMath32 {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint32 a, uint32 b) internal pure returns (uint32) {
        uint32 c = a + b;
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
    function sub(uint32 a, uint32 b) internal pure returns (uint32) {
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
    function sub(uint32 a, uint32 b, string memory errorMessage) internal pure returns (uint32) {
        require(b <= a, errorMessage);
        uint32 c = a - b;

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
    function mul(uint32 a, uint32 b) internal pure returns (uint32) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint32 c = a * b;
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
    function div(uint32 a, uint32 b) internal pure returns (uint32) {
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
    function div(uint32 a, uint32 b, string memory errorMessage) internal pure returns (uint32) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint32 c = a / b;
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
    function mod(uint32 a, uint32 b) internal pure returns (uint32) {
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
    function mod(uint32 a, uint32 b, string memory errorMessage) internal pure returns (uint32) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

/**
 * @title SafeMath16
 * @dev SafeMath library implemented for uint16
 */
library SafeMath16 {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint16 a, uint16 b) internal pure returns (uint16) {
        uint16 c = a + b;
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
    function sub(uint16 a, uint16 b) internal pure returns (uint16) {
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
    function sub(uint16 a, uint16 b, string memory errorMessage) internal pure returns (uint16) {
        require(b <= a, errorMessage);
        uint16 c = a - b;

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
    function mul(uint16 a, uint16 b) internal pure returns (uint16) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint16 c = a * b;
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
    function div(uint16 a, uint16 b) internal pure returns (uint16) {
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
    function div(uint16 a, uint16 b, string memory errorMessage) internal pure returns (uint16) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint16 c = a / b;
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
    function mod(uint16 a, uint16 b) internal pure returns (uint16) {
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
    function mod(uint16 a, uint16 b, string memory errorMessage) internal pure returns (uint16) {
        require(b != 0, errorMessage);
        return a % b;
    }
}


