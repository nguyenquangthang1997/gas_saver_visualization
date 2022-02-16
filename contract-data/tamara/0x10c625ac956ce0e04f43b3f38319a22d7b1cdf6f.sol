pragma solidity ^0.4.24;

/**
 * Utility library of inline functions on addresses
 */
library Address {

  /**
   * Returns whether the target address is a contract
   * @dev This function will return false if invoked during the constructor of a contract,
   * as the code is not actually created until after the constructor finishes.
   * @param account address of the account to check
   * @return whether the target address is a contract
   */
  function isContract(address account) internal view returns (bool) {
    uint256 size;
    // XXX Currently there is no better way to check if there is a contract in an address
    // than to check the size of the code at that address.
    // See https://ethereum.stackexchange.com/a/14016/36603
    // for more details about how this works.
    // TODO Check this again before the Serenity release, because all addresses will be
    // contracts then.
    // solium-disable-next-line security/no-inline-assembly
    assembly { size := extcodesize(account) }
    return size > 0;
  }

}
pragma solidity ^0.4.24;

import "./IERC165.sol";

/**
 * @title ERC165
 * @author Matt Condon (@shrugs)
 * @dev Implements ERC165 using a lookup table.
 */
contract ERC165 is IERC165 {

  bytes4 private constant _InterfaceId_ERC165 = 0x01ffc9a7;
  /**
   * 0x01ffc9a7 ===
   *   bytes4(keccak256('supportsInterface(bytes4)'))
   */

  /**
   * @dev a mapping of interface id to whether or not it's supported
   */
  mapping(bytes4 => bool) private _supportedInterfaces;

  /**
   * @dev A contract implementing SupportsInterfaceWithLookup
   * implement ERC165 itself
   */
  constructor()
    internal
  {
    _registerInterface(_InterfaceId_ERC165);
  }

  /**
   * @dev implement supportsInterface(bytes4) using a lookup table
   */
  function supportsInterface(bytes4 interfaceId)
    external
    view
    returns (bool)
  {
    return _supportedInterfaces[interfaceId];
  }

  /**
   * @dev internal method for registering an interface
   */
  function _registerInterface(bytes4 interfaceId)
    internal
  {
    require(interfaceId != 0xffffffff);
    _supportedInterfaces[interfaceId] = true;
  }
}
pragma solidity ^0.4.24;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./SafeMath.sol";
import "./Address.sol";
import "./ERC165.sol";

/**
 * @title ERC721 Non-Fungible Token Standard basic implementation
 * @dev see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
 */
contract ERC721 is ERC165, IERC721 {

  using SafeMath for uint256;
  using Address for address;

  // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
  // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
  bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

  // Mapping from token ID to owner
  mapping (uint256 => address) private _tokenOwner;

  // Mapping from token ID to approved address
  mapping (uint256 => address) private _tokenApprovals;

  // Mapping from owner to number of owned token
  mapping (address => uint256) private _ownedTokensCount;

  // Mapping from owner to operator approvals
  mapping (address => mapping (address => bool)) private _operatorApprovals;

  bytes4 private constant _InterfaceId_ERC721 = 0x80ac58cd;
  /*
   * 0x80ac58cd ===
   *   bytes4(keccak256('balanceOf(address)')) ^
   *   bytes4(keccak256('ownerOf(uint256)')) ^
   *   bytes4(keccak256('approve(address,uint256)')) ^
   *   bytes4(keccak256('getApproved(uint256)')) ^
   *   bytes4(keccak256('setApprovalForAll(address,bool)')) ^
   *   bytes4(keccak256('isApprovedForAll(address,address)')) ^
   *   bytes4(keccak256('transferFrom(address,address,uint256)')) ^
   *   bytes4(keccak256('safeTransferFrom(address,address,uint256)')) ^
   *   bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)'))
   */

  constructor()
    public
  {
    // register the supported interfaces to conform to ERC721 via ERC165
    _registerInterface(_InterfaceId_ERC721);
  }

  /**
   * @dev Gets the balance of the specified address
   * @param owner address to query the balance of
   * @return uint256 representing the amount owned by the passed address
   */
  function balanceOf(address owner) public view returns (uint256) {
    require(owner != address(0));
    return _ownedTokensCount[owner];
  }

  /**
   * @dev Gets the owner of the specified token ID
   * @param tokenId uint256 ID of the token to query the owner of
   * @return owner address currently marked as the owner of the given token ID
   */
  function ownerOf(uint256 tokenId) public view returns (address) {
    address owner = _tokenOwner[tokenId];
    require(owner != address(0));
    return owner;
  }

  /**
   * @dev Approves another address to transfer the given token ID
   * The zero address indicates there is no approved address.
   * There can only be one approved address per token at a given time.
   * Can only be called by the token owner or an approved operator.
   * @param to address to be approved for the given token ID
   * @param tokenId uint256 ID of the token to be approved
   */
  function approve(address to, uint256 tokenId) public {
    address owner = ownerOf(tokenId);
    require(to != owner);
    require(msg.sender == owner || isApprovedForAll(owner, msg.sender));

    _tokenApprovals[tokenId] = to;
    emit Approval(owner, to, tokenId);
  }

  /**
   * @dev Gets the approved address for a token ID, or zero if no address set
   * Reverts if the token ID does not exist.
   * @param tokenId uint256 ID of the token to query the approval of
   * @return address currently approved for the given token ID
   */
  function getApproved(uint256 tokenId) public view returns (address) {
    require(_exists(tokenId));
    return _tokenApprovals[tokenId];
  }

  /**
   * @dev Sets or unsets the approval of a given operator
   * An operator is allowed to transfer all tokens of the sender on their behalf
   * @param to operator address to set the approval
   * @param approved representing the status of the approval to be set
   */
  function setApprovalForAll(address to, bool approved) public {
    require(to != msg.sender);
    _operatorApprovals[msg.sender][to] = approved;
    emit ApprovalForAll(msg.sender, to, approved);
  }

  /**
   * @dev Tells whether an operator is approved by a given owner
   * @param owner owner address which you want to query the approval of
   * @param operator operator address which you want to query the approval of
   * @return bool whether the given operator is approved by the given owner
   */
  function isApprovedForAll(
    address owner,
    address operator
  )
    public
    view
    returns (bool)
  {
    return _operatorApprovals[owner][operator];
  }

  /**
   * @dev Transfers the ownership of a given token ID to another address
   * Usage of this method is discouraged, use `safeTransferFrom` whenever possible
   * Requires the msg sender to be the owner, approved, or operator
   * @param from current owner of the token
   * @param to address to receive the ownership of the given token ID
   * @param tokenId uint256 ID of the token to be transferred
  */
  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  )
    public
  {
    require(_isApprovedOrOwner(msg.sender, tokenId));
    require(to != address(0));

    _clearApproval(from, tokenId);
    _removeTokenFrom(from, tokenId);
    _addTokenTo(to, tokenId);

    emit Transfer(from, to, tokenId);
  }

  /**
   * @dev Safely transfers the ownership of a given token ID to another address
   * If the target address is a contract, it must implement `onERC721Received`,
   * which is called upon a safe transfer, and return the magic value
   * `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`; otherwise,
   * the transfer is reverted.
   *
   * Requires the msg sender to be the owner, approved, or operator
   * @param from current owner of the token
   * @param to address to receive the ownership of the given token ID
   * @param tokenId uint256 ID of the token to be transferred
  */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  )
    public
  {
    // solium-disable-next-line arg-overflow
    safeTransferFrom(from, to, tokenId, "");
  }

  /**
   * @dev Safely transfers the ownership of a given token ID to another address
   * If the target address is a contract, it must implement `onERC721Received`,
   * which is called upon a safe transfer, and return the magic value
   * `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`; otherwise,
   * the transfer is reverted.
   * Requires the msg sender to be the owner, approved, or operator
   * @param from current owner of the token
   * @param to address to receive the ownership of the given token ID
   * @param tokenId uint256 ID of the token to be transferred
   * @param _data bytes data to send along with a safe transfer check
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes _data
  )
    public
  {
    transferFrom(from, to, tokenId);
    // solium-disable-next-line arg-overflow
    require(_checkOnERC721Received(from, to, tokenId, _data));
  }

  /**
   * @dev Returns whether the specified token exists
   * @param tokenId uint256 ID of the token to query the existence of
   * @return whether the token exists
   */
  function _exists(uint256 tokenId) internal view returns (bool) {
    address owner = _tokenOwner[tokenId];
    return owner != address(0);
  }

  /**
   * @dev Returns whether the given spender can transfer a given token ID
   * @param spender address of the spender to query
   * @param tokenId uint256 ID of the token to be transferred
   * @return bool whether the msg.sender is approved for the given token ID,
   *  is an operator of the owner, or is the owner of the token
   */
  function _isApprovedOrOwner(
    address spender,
    uint256 tokenId
  )
    internal
    view
    returns (bool)
  {
    address owner = ownerOf(tokenId);
    // Disable solium check because of
    // https://github.com/duaraghav8/Solium/issues/175
    // solium-disable-next-line operator-whitespace
    return (
      spender == owner ||
      getApproved(tokenId) == spender ||
      isApprovedForAll(owner, spender)
    );
  }

  /**
   * @dev Internal function to mint a new token
   * Reverts if the given token ID already exists
   * @param to The address that will own the minted token
   * @param tokenId uint256 ID of the token to be minted by the msg.sender
   */
  function _mint(address to, uint256 tokenId) internal {
    require(to != address(0));
    _addTokenTo(to, tokenId);
    emit Transfer(address(0), to, tokenId);
  }

  /**
   * @dev Internal function to burn a specific token
   * Reverts if the token does not exist
   * @param tokenId uint256 ID of the token being burned by the msg.sender
   */
  function _burn(address owner, uint256 tokenId) internal {
    _clearApproval(owner, tokenId);
    _removeTokenFrom(owner, tokenId);
    emit Transfer(owner, address(0), tokenId);
  }

  /**
   * @dev Internal function to add a token ID to the list of a given address
   * Note that this function is left internal to make ERC721Enumerable possible, but is not
   * intended to be called by custom derived contracts: in particular, it emits no Transfer event.
   * @param to address representing the new owner of the given token ID
   * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
   */
  function _addTokenTo(address to, uint256 tokenId) internal {
    require(_tokenOwner[tokenId] == address(0));
    _tokenOwner[tokenId] = to;
    _ownedTokensCount[to] = _ownedTokensCount[to].add(1);
  }

  /**
   * @dev Internal function to remove a token ID from the list of a given address
   * Note that this function is left internal to make ERC721Enumerable possible, but is not
   * intended to be called by custom derived contracts: in particular, it emits no Transfer event,
   * and doesn't clear approvals.
   * @param from address representing the previous owner of the given token ID
   * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
   */
  function _removeTokenFrom(address from, uint256 tokenId) internal {
    require(ownerOf(tokenId) == from);
    _ownedTokensCount[from] = _ownedTokensCount[from].sub(1);
    _tokenOwner[tokenId] = address(0);
  }

  /**
   * @dev Internal function to invoke `onERC721Received` on a target address
   * The call is not executed if the target address is not a contract
   * @param from address representing the previous owner of the given token ID
   * @param to target address that will receive the tokens
   * @param tokenId uint256 ID of the token to be transferred
   * @param _data bytes optional data to send along with the call
   * @return whether the call correctly returned the expected magic value
   */
  function _checkOnERC721Received(
    address from,
    address to,
    uint256 tokenId,
    bytes _data
  )
    internal
    returns (bool)
  {
    if (!to.isContract()) {
      return true;
    }
    bytes4 retval = IERC721Receiver(to).onERC721Received(
      msg.sender, from, tokenId, _data);
    return (retval == _ERC721_RECEIVED);
  }

  /**
   * @dev Private function to clear current approval of a given token ID
   * Reverts if the given address is not indeed the owner of the token
   * @param owner owner of the token
   * @param tokenId uint256 ID of the token to be transferred
   */
  function _clearApproval(address owner, uint256 tokenId) private {
    require(ownerOf(tokenId) == owner);
    if (_tokenApprovals[tokenId] != address(0)) {
      _tokenApprovals[tokenId] = address(0);
    }
  }
}
/// @title ERC-721 Non-Fungible Token Standard, optional metadata extension
/// @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
///  Note: the ERC-165 identifier for this interface is 0x5b5e139f.
interface ERC721Metadata /* is ERC721 */ {
    /// @notice A descriptive name for a collection of NFTs in this contract
    function name() external view returns (string _name);

    /// @notice An abbreviated name for NFTs in this contract
    function symbol() external view returns (string _symbol);

    /// @notice A distinct Uniform Resource Identifier (URI) for a given asset.
    /// @dev Throws if `_tokenId` is not a valid NFT. URIs are defined in RFC
    ///  3986. The URI may point to a JSON file that conforms to the "ERC721
    ///  Metadata JSON Schema".
    function tokenURI(uint256 _tokenId) external view returns (string);
}
/// @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
/// @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
///  Note: the ERC-165 identifier for this interface is 0x780e9d63.
interface ERC721Enumerable /* is ERC721 */ {
    /// @notice Count NFTs tracked by this contract
    /// @return A count of valid NFTs tracked by this contract, where each one of
    ///  them has an assigned and queryable owner not equal to the zero address
    function totalSupply() external view returns (uint256);

    /// @notice Enumerate valid NFTs
    /// @dev Throws if `_index` >= `totalSupply()`.
    /// @param _index A counter less than `totalSupply()`
    /// @return The token identifier for the `_index`th NFT,
    ///  (sort order not specified)
    function tokenByIndex(uint256 _index) external view returns (uint256);

    /// @notice Enumerate NFTs assigned to an owner
    /// @dev Throws if `_index` >= `balanceOf(_owner)` or if
    ///  `_owner` is the zero address, representing invalid NFTs.
    /// @param _owner An address where we are interested in NFTs owned by them
    /// @param _index A counter less than `balanceOf(_owner)`
    /// @return The token identifier for the `_index`th NFT assigned to `_owner`,
    ///   (sort order not specified)
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256);
}

pragma solidity ^0.4.24;

/**
 * @title IERC165
 * @dev https://github.com/ethereum/EIPs/blob/master/EIPS/eip-165.md
 */
interface IERC165 {

  /**
   * @notice Query if a contract implements an interface
   * @param interfaceId The interface identifier, as specified in ERC-165
   * @dev Interface identification is specified in ERC-165. This function
   * uses less than 30,000 gas.
   */
  function supportsInterface(bytes4 interfaceId)
    external
    view
    returns (bool);
}
pragma solidity ^0.4.24;

import "./IERC165.sol";

/**
 * @title ERC721 Non-Fungible Token Standard basic interface
 * @dev see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
 */
contract IERC721 is IERC165 {

  event Transfer(
    address indexed from,
    address indexed to,
    uint256 indexed tokenId
  );
  event Approval(
    address indexed owner,
    address indexed approved,
    uint256 indexed tokenId
  );
  event ApprovalForAll(
    address indexed owner,
    address indexed operator,
    bool approved
  );

  function balanceOf(address owner) public view returns (uint256 balance);
  function ownerOf(uint256 tokenId) public view returns (address owner);

  function approve(address to, uint256 tokenId) public;
  function getApproved(uint256 tokenId)
    public view returns (address operator);

  function setApprovalForAll(address operator, bool _approved) public;
  function isApprovedForAll(address owner, address operator)
    public view returns (bool);

  function transferFrom(address from, address to, uint256 tokenId) public;
  function safeTransferFrom(address from, address to, uint256 tokenId)
    public;

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes data
  )
    public;
}
pragma solidity ^0.4.24;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
contract IERC721Receiver {
  /**
   * @notice Handle the receipt of an NFT
   * @dev The ERC721 smart contract calls this function on the recipient
   * after a `safeTransfer`. This function MUST return the function selector,
   * otherwise the caller will revert the transaction. The selector to be
   * returned can be obtained as `this.onERC721Received.selector`. This
   * function MAY throw to revert and reject the transfer.
   * Note: the ERC721 contract address is always the message sender.
   * @param operator The address which called `safeTransferFrom` function
   * @param from The address which previously owned the token
   * @param tokenId The NFT identifier which is being transferred
   * @param data Additional data with no specified format
   * @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
   */
  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes data
  )
    public
    returns(bytes4);
}
pragma solidity ^0.4.24;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address private _owner;

  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() internal {
    _owner = msg.sender;
    emit OwnershipTransferred(address(0), _owner);
  }

  /**
   * @return the address of the owner.
   */
  function owner() public view returns(address) {
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
  function isOwner() public view returns(bool) {
    return msg.sender == _owner;
  }

  /**
   * @dev Allows the current owner to relinquish control of the contract.
   * @notice Renouncing to ownership will leave the contract without an owner.
   * It will not be possible to call the functions with the `onlyOwner`
   * modifier anymore.
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



pragma solidity ^0.4.24;

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
pragma solidity ^0.4.24;

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
pragma solidity ^0.4.24;

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
pragma solidity ^0.4.24;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, reverts on overflow.
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
  * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0); // Solidity only automatically asserts when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  /**
  * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    uint256 c = a - b;

    return c;
  }

  /**
  * @dev Adds two numbers, reverts on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);

    return c;
  }

  /**
  * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
  * reverts when dividing by zero.
  */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}


/**
 * @title SafeMath32
 * @dev SafeMath library implemented for uint32
 */
library SafeMath32 {

  function mul(uint32 a, uint32 b) internal pure returns (uint32) {
    if (a == 0) {
      return 0;
    }
    uint32 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint32 a, uint32 b) internal pure returns (uint32) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint32 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint32 a, uint32 b) internal pure returns (uint32) {
    assert(b <= a);
    return a - b;
  }

  function add(uint32 a, uint32 b) internal pure returns (uint32) {
    uint32 c = a + b;
    assert(c >= a);
    return c;
  }
}
/**
 * @title SafeMath16
 * @dev SafeMath library implemented for uint16
 */
library SafeMath16 {

  function mul(uint16 a, uint16 b) internal pure returns (uint16) {
    if (a == 0) {
      return 0;
    }
    uint16 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint16 a, uint16 b) internal pure returns (uint16) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint16 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint16 a, uint16 b) internal pure returns (uint16) {
    assert(b <= a);
    return a - b;
  }

  function add(uint16 a, uint16 b) internal pure returns (uint16) {
    uint16 c = a + b;
    assert(c >= a);
    return c;
  }
}
pragma solidity ^0.4.24;

/*
#
#...######..########.##.......########.####.########..######..##.....##....###....####.##....##
#..##....##.##.......##.......##........##..##.......##....##.##.....##...##.##....##..###...##
#..##.......##.......##.......##........##..##.......##.......##.....##..##...##...##..####..##
#...######..######...##.......######....##..######...##.......#########.##.....##..##..##.##.##
#........##.##.......##.......##........##..##.......##.......##.....##.#########..##..##..####
#..##....##.##.......##.......##........##..##.......##....##.##.....##.##.....##..##..##...###
#...######..########.########.##.......####.########..######..##.....##.##.....##.####.##....##
#..............................................................................................
#....................................................................by Daniel Fernando Perosio
#
# @title Selfiechain un contrato para creación de selfies en Ethereum blockchain
# @author Daniel Fernando Perosio (http://danielperosio.com) e-mail daniel@perosio.com - dperosio@gmail.com
# @notice Selfiechain es un conjunto de instrucciones para realizar autorretratos a partir de tu identidad en la red Ethereum (Ethereum Address)
# @dev Compatible con la implementación de OpenZeppelin de la especificación ERC721 Crypto Coleccionables
#
*/

import "./ownable.sol";
import "./ERC721.sol";
import "./SafeMath.sol";
import "./Pausable.sol";

contract Selfiechain is Ownable, ERC721, Pausable {

    string public name = "Selfiechain";
    string public symbol = "ツ";
    ERC721Metadata public erc721Metadata;
    using SafeMath for uint256;
    using SafeMath32 for uint32;
    using SafeMath16 for uint16;
    event NewSelfie(uint selfieId, string _hair, string _forehead, string _eyes, string _nose, string _mouth, string _neck, string _body);
    uint public randNonce = 0;
 
string[104] public array = ["┆","╵","║", "¦","╷","ı", "ﾉ", "つ", "╰", "೨", "ɿ", "╎", "╔", "@", "╯", "/", 
                            "I", "╲","[", "{", "├","ʕ", "|","ʅ", "(", "└", "╱", 
                            "I", "╱","]", "}", "┤", "ʔ","|", "ʃ", ")","┘", "╲",  
                            "J","ʃ","ʖ","^","L","¨","┘","┴","Δ","⌒","Ɔ", "ȷ", "フ","ʌ", "へ", "C",
                            "┅","┉","─", "-", "━", "~" ,"_",   
                            "‿","˽", "▁", "﹏", "︶", "︿","皿", "⺫", "⌂", "⌒", "ヮ", 
                             "o", "￢", "=", "O",
                            "◎","ㆆ","ಥ","°","®","©","ʘ","0","ಠ","Ơ","ø","º","●","Ф","◕", "ϴ", "e" ,
                             "♥" ,"$" ,"•" ,"+" ,"*" ,"×" ,"·" ,"`" ,":" ," " ,"´" ];  

struct Selfie {
      string hair;
      string forehead;
      string eyes;
      string nose;
      string mouth;
      string neck;
      string body;            
    }

    Selfie[] public selfies;

    mapping (uint => address) public selfieToOwner;
    mapping (address => uint) ownerSelfieCount;

    function _createSelf(string _hair, string _forehead, string _eyes, string _nose, string _mouth, string _neck, string _body) internal whenNotPaused {
        uint id = selfies.push(Selfie(_hair, _forehead, _eyes, _nose, _mouth, _neck, _body)) - 1;
        selfieToOwner[id] = msg.sender;
        ownerSelfieCount[msg.sender] = ownerSelfieCount[msg.sender].add(1);
        randNonce = randNonce.add(1);
        emit NewSelfie(id, _hair, _forehead, _eyes, _nose, _mouth, _neck, _body); 
    }

    uint fee = 0 ether;

    function withdraw() external onlyOwner {
        owner().transfer(address(this).balance);
    }

    function setUpFee(uint _feecreate) external onlyOwner {
        fee = _feecreate;
    } 
  
   function _createRand(uint8 j) internal view returns (uint i) {
        uint x = uint(keccak256(abi.encodePacked(msg.sender, randNonce))); 
           i =  x % j;    
    } 

    function _createId(uint8 j) internal view returns (uint i) {
        uint x = uint(keccak256(abi.encodePacked(msg.sender)));  
         i =  x % j;    
    } 
 
    function _trait(uint8 _j, string _l ) internal view returns (string) {
        uint8 _n1 = uint8(_createId(100)); 
        if (_n1 <= _j ){
            string memory x = _l;
            return x; 
        }               
        else  {
            string memory i = ".";
            return i; 
        }       
    } 

    function _createBg( uint8 i) internal view returns (string) {  
        string memory x = string(array[_createRand(8)+95]);
        string memory x8 = string(abi.encodePacked("." ,x ,".",x ,"." ,x ,"." ,x )); //8
        if ( i == 8){ 
          string memory a = string(abi.encodePacked(x8));
          return a;
             } 
           else if (i == 9) {
         string memory b = string(abi.encodePacked(x8,".")); //9
         return b;
           } 
           else if (i == 10) {
         string memory c = string(abi.encodePacked(x8,"." ,x)); //10
         return c;
         
           } 
         else  if (i == 12) {
         string memory d = string(abi.encodePacked(x8,"." ,x,"." ,x)); //12
         return d;
         
           }   
         else   {
         string memory f = string(abi.encodePacked(x8));
         return f;
         
           }   
    } 

    function _createString(uint8 i, string _a, string _b, string _c, string _d) internal view returns (string) {         
        if (i == 0) {
            string memory x = _trait(80,_a);  
            string memory bg = _createBg(10);  
            return string(abi.encodePacked(bg ,x ,_b ,x ,_b ,x ,_b ,x ,bg ));   //10
        } 
        else {
            string memory x1 = _trait(90,_a);  
            string memory x2 = _trait(90,_b);
            string memory bg1 = _createBg(8); 
            return string(abi.encodePacked(bg1 ,x1 ,x2 ,_c , "     " ,_d ,x2 ,x1 ,bg1 )); //8
        }                 
    }   

    function _createStringOne(uint8 i, string _a, string _b, string _c, string _d) internal view returns (string) { 
        if (i == 0){
            string memory x3 = _trait(70,_a); 
            string memory bg2 = _createBg(9);  
            return string(abi.encodePacked(bg2,x3, _b ," "  ,_d ,"  " ,_d ," "  ,_c ,x3 ,bg2 ));  //9            
        }
        else {
            string memory x4 = _trait(60,_d);
            string memory bg3 = _createBg(8);   
            return string(abi.encodePacked(bg3 ,x4 ,_a ,"   " ,_c ,"   " ,_b ,x4 ,bg3 ));  //8
        }                        
    }   

    function _createStringTwo(uint8 i, string _a, string _b, string _c, string _d) internal view returns (string) {       
        if (i == 0) {
            string memory x5 = _trait(50,_d); 
            string memory bg4 = _createBg(9); 
            return string(abi.encodePacked(bg4 ,x5 ,_a ,"  " ,_c ,"  " ,_b ,x5 ,bg4 )); //9
        }
        else if (i == 1) {
         string memory bg5 = _createBg(12); 
         return string(abi.encodePacked(bg5 ,_a ,_b ,_a ,bg5 )); //12
        }
        else {
            string memory bg6 = _createBg(10); 
            uint256 balance = msg.sender.balance;
            if (balance >= 200*1000000000000000000 ){
                 return string(abi.encodePacked(bg6 ,"_.>·<._" ,bg6 )); //10
            }               
            else {
                return string(abi.encodePacked(bg6 ,"_.", _a, "__", _b, "._" ,bg6)); //10
            }         
        }         
    } 

    function takeSelfie() external payable whenNotPaused {
        require(msg.value == fee);
        string memory _a = string(array[_createId(36)]);
        string memory _b = string(array[_createRand(36)]);
        string memory dhair =  _createString(0 ,_a , _b ,"" ,"" );     
        string memory dforehead =  _createString(1, _a, _b, string(array[_createId(9)+18]), string(array[_createId(9)+29]) ); 
        string memory deyes =  _createStringOne(0, _b, string(array[_createId(8)+18]), string(array[_createId(8)+29]), string(array[_createRand(27)+70])); 
        string memory dnose =  _createStringOne(1, string(array[_createId(9)+17]), string(array[_createId(9)+28]), string(array[_createId(16)+38]) ,_a ); 
        string memory dmouth =  _createStringTwo(0, string(array[_createId(7)+17]), string(array[_createId(7)+28]), string(array[_createRand(23)+54]) ,_b ); 
        string memory dneck =  _createStringTwo(1, string(array[_createId(6)+54]) ,string(array[_createId(10)+55]) ,"" ,"" ); 
        string memory dbody =  _createStringTwo(2,string(array[_createRand(10)+16]) ,string(array[_createRand(10)+27]) ,"" ,"" ); 
        _createSelf(dhair, dforehead, deyes, dnose, dmouth, dneck, dbody);
    }

    modifier onlyOwnerOf(uint _selfieId) {
      require(msg.sender == selfieToOwner[_selfieId]);
      _;
    }

    function getSelfieByOwner(address _owner) external view returns(uint[]) {
        uint[] memory result = new uint[](ownerSelfieCount[_owner]);
        uint counter = 0;
        for (uint i = 0; i < selfies.length; i++) {
          if (selfieToOwner[i] == _owner) {
                result[counter] = i;
                counter++;
          }
        }
        return result;
    }

    modifier validDestination( address to ) {
        require(to != address(0x0));
        require(to != address(this) );
        _;
    }

    /*ERC721*/  

    mapping (uint => address) selfieApprovals;

    function balanceOf(address _owner) public view returns (uint256 _balance) {
        return ownerSelfieCount[_owner];
    }

    function ownerOf(uint256 _tokenId) public view returns (address _owner) {
        return selfieToOwner[_tokenId];
    }

    function _transfer(address _from, address _to, uint256 _tokenId) private validDestination(_to) {
        ownerSelfieCount[_to] = ownerSelfieCount[_to].add(1);
        ownerSelfieCount[_from] = ownerSelfieCount[_from].sub(1);
        selfieToOwner[_tokenId] = _to;
        emit Transfer(_from, _to, _tokenId);
    }

    function transfer(address _to, uint256 _tokenId) public onlyOwnerOf(_tokenId) validDestination(_to) {
        _transfer(msg.sender, _to, _tokenId);
    }

    function approve(address _to, uint256 _tokenId) public onlyOwnerOf(_tokenId) validDestination(_to) {
        selfieApprovals[_tokenId] = _to;
        emit Approval(msg.sender, _to, _tokenId);
    }

    function takeOwnership(uint256 _tokenId) public {
        require(selfieApprovals[_tokenId] == msg.sender);
        address  owner = ownerOf(_tokenId);
        _transfer(owner, msg.sender, _tokenId);
    }

    function totalSupply() public view returns (uint) {
        return selfies.length - 1;
    }    
    
}
pragma solidity ^0.4.24;

/**
 * Utility library of inline functions on addresses
 */
library Address {

  /**
   * Returns whether the target address is a contract
   * @dev This function will return false if invoked during the constructor of a contract,
   * as the code is not actually created until after the constructor finishes.
   * @param account address of the account to check
   * @return whether the target address is a contract
   */
  function isContract(address account) internal view returns (bool) {
    uint256 size;
    // XXX Currently there is no better way to check if there is a contract in an address
    // than to check the size of the code at that address.
    // See https://ethereum.stackexchange.com/a/14016/36603
    // for more details about how this works.
    // TODO Check this again before the Serenity release, because all addresses will be
    // contracts then.
    // solium-disable-next-line security/no-inline-assembly
    assembly { size := extcodesize(account) }
    return size > 0;
  }

}
pragma solidity ^0.4.24;

import "./IERC165.sol";

/**
 * @title ERC165
 * @author Matt Condon (@shrugs)
 * @dev Implements ERC165 using a lookup table.
 */
contract ERC165 is IERC165 {

  bytes4 private constant _InterfaceId_ERC165 = 0x01ffc9a7;
  /**
   * 0x01ffc9a7 ===
   *   bytes4(keccak256('supportsInterface(bytes4)'))
   */

  /**
   * @dev a mapping of interface id to whether or not it's supported
   */
  mapping(bytes4 => bool) private _supportedInterfaces;

  /**
   * @dev A contract implementing SupportsInterfaceWithLookup
   * implement ERC165 itself
   */
  constructor()
    internal
  {
    _registerInterface(_InterfaceId_ERC165);
  }

  /**
   * @dev implement supportsInterface(bytes4) using a lookup table
   */
  function supportsInterface(bytes4 interfaceId)
    external
    view
    returns (bool)
  {
    return _supportedInterfaces[interfaceId];
  }

  /**
   * @dev internal method for registering an interface
   */
  function _registerInterface(bytes4 interfaceId)
    internal
  {
    require(interfaceId != 0xffffffff);
    _supportedInterfaces[interfaceId] = true;
  }
}
pragma solidity ^0.4.24;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./SafeMath.sol";
import "./Address.sol";
import "./ERC165.sol";

/**
 * @title ERC721 Non-Fungible Token Standard basic implementation
 * @dev see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
 */
contract ERC721 is ERC165, IERC721 {

  using SafeMath for uint256;
  using Address for address;

  // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
  // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
  bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

  // Mapping from token ID to owner
  mapping (uint256 => address) private _tokenOwner;

  // Mapping from token ID to approved address
  mapping (uint256 => address) private _tokenApprovals;

  // Mapping from owner to number of owned token
  mapping (address => uint256) private _ownedTokensCount;

  // Mapping from owner to operator approvals
  mapping (address => mapping (address => bool)) private _operatorApprovals;

  bytes4 private constant _InterfaceId_ERC721 = 0x80ac58cd;
  /*
   * 0x80ac58cd ===
   *   bytes4(keccak256('balanceOf(address)')) ^
   *   bytes4(keccak256('ownerOf(uint256)')) ^
   *   bytes4(keccak256('approve(address,uint256)')) ^
   *   bytes4(keccak256('getApproved(uint256)')) ^
   *   bytes4(keccak256('setApprovalForAll(address,bool)')) ^
   *   bytes4(keccak256('isApprovedForAll(address,address)')) ^
   *   bytes4(keccak256('transferFrom(address,address,uint256)')) ^
   *   bytes4(keccak256('safeTransferFrom(address,address,uint256)')) ^
   *   bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)'))
   */

  constructor()
    public
  {
    // register the supported interfaces to conform to ERC721 via ERC165
    _registerInterface(_InterfaceId_ERC721);
  }

  /**
   * @dev Gets the balance of the specified address
   * @param owner address to query the balance of
   * @return uint256 representing the amount owned by the passed address
   */
  function balanceOf(address owner) public view returns (uint256) {
    require(owner != address(0));
    return _ownedTokensCount[owner];
  }

  /**
   * @dev Gets the owner of the specified token ID
   * @param tokenId uint256 ID of the token to query the owner of
   * @return owner address currently marked as the owner of the given token ID
   */
  function ownerOf(uint256 tokenId) public view returns (address) {
    address owner = _tokenOwner[tokenId];
    require(owner != address(0));
    return owner;
  }

  /**
   * @dev Approves another address to transfer the given token ID
   * The zero address indicates there is no approved address.
   * There can only be one approved address per token at a given time.
   * Can only be called by the token owner or an approved operator.
   * @param to address to be approved for the given token ID
   * @param tokenId uint256 ID of the token to be approved
   */
  function approve(address to, uint256 tokenId) public {
    address owner = ownerOf(tokenId);
    require(to != owner);
    require(msg.sender == owner || isApprovedForAll(owner, msg.sender));

    _tokenApprovals[tokenId] = to;
    emit Approval(owner, to, tokenId);
  }

  /**
   * @dev Gets the approved address for a token ID, or zero if no address set
   * Reverts if the token ID does not exist.
   * @param tokenId uint256 ID of the token to query the approval of
   * @return address currently approved for the given token ID
   */
  function getApproved(uint256 tokenId) public view returns (address) {
    require(_exists(tokenId));
    return _tokenApprovals[tokenId];
  }

  /**
   * @dev Sets or unsets the approval of a given operator
   * An operator is allowed to transfer all tokens of the sender on their behalf
   * @param to operator address to set the approval
   * @param approved representing the status of the approval to be set
   */
  function setApprovalForAll(address to, bool approved) public {
    require(to != msg.sender);
    _operatorApprovals[msg.sender][to] = approved;
    emit ApprovalForAll(msg.sender, to, approved);
  }

  /**
   * @dev Tells whether an operator is approved by a given owner
   * @param owner owner address which you want to query the approval of
   * @param operator operator address which you want to query the approval of
   * @return bool whether the given operator is approved by the given owner
   */
  function isApprovedForAll(
    address owner,
    address operator
  )
    public
    view
    returns (bool)
  {
    return _operatorApprovals[owner][operator];
  }

  /**
   * @dev Transfers the ownership of a given token ID to another address
   * Usage of this method is discouraged, use `safeTransferFrom` whenever possible
   * Requires the msg sender to be the owner, approved, or operator
   * @param from current owner of the token
   * @param to address to receive the ownership of the given token ID
   * @param tokenId uint256 ID of the token to be transferred
  */
  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  )
    public
  {
    require(_isApprovedOrOwner(msg.sender, tokenId));
    require(to != address(0));

    _clearApproval(from, tokenId);
    _removeTokenFrom(from, tokenId);
    _addTokenTo(to, tokenId);

    emit Transfer(from, to, tokenId);
  }

  /**
   * @dev Safely transfers the ownership of a given token ID to another address
   * If the target address is a contract, it must implement `onERC721Received`,
   * which is called upon a safe transfer, and return the magic value
   * `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`; otherwise,
   * the transfer is reverted.
   *
   * Requires the msg sender to be the owner, approved, or operator
   * @param from current owner of the token
   * @param to address to receive the ownership of the given token ID
   * @param tokenId uint256 ID of the token to be transferred
  */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  )
    public
  {
    // solium-disable-next-line arg-overflow
    safeTransferFrom(from, to, tokenId, "");
  }

  /**
   * @dev Safely transfers the ownership of a given token ID to another address
   * If the target address is a contract, it must implement `onERC721Received`,
   * which is called upon a safe transfer, and return the magic value
   * `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`; otherwise,
   * the transfer is reverted.
   * Requires the msg sender to be the owner, approved, or operator
   * @param from current owner of the token
   * @param to address to receive the ownership of the given token ID
   * @param tokenId uint256 ID of the token to be transferred
   * @param _data bytes data to send along with a safe transfer check
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes _data
  )
    public
  {
    transferFrom(from, to, tokenId);
    // solium-disable-next-line arg-overflow
    require(_checkOnERC721Received(from, to, tokenId, _data));
  }

  /**
   * @dev Returns whether the specified token exists
   * @param tokenId uint256 ID of the token to query the existence of
   * @return whether the token exists
   */
  function _exists(uint256 tokenId) internal view returns (bool) {
    address owner = _tokenOwner[tokenId];
    return owner != address(0);
  }

  /**
   * @dev Returns whether the given spender can transfer a given token ID
   * @param spender address of the spender to query
   * @param tokenId uint256 ID of the token to be transferred
   * @return bool whether the msg.sender is approved for the given token ID,
   *  is an operator of the owner, or is the owner of the token
   */
  function _isApprovedOrOwner(
    address spender,
    uint256 tokenId
  )
    internal
    view
    returns (bool)
  {
    address owner = ownerOf(tokenId);
    // Disable solium check because of
    // https://github.com/duaraghav8/Solium/issues/175
    // solium-disable-next-line operator-whitespace
    return (
      spender == owner ||
      getApproved(tokenId) == spender ||
      isApprovedForAll(owner, spender)
    );
  }

  /**
   * @dev Internal function to mint a new token
   * Reverts if the given token ID already exists
   * @param to The address that will own the minted token
   * @param tokenId uint256 ID of the token to be minted by the msg.sender
   */
  function _mint(address to, uint256 tokenId) internal {
    require(to != address(0));
    _addTokenTo(to, tokenId);
    emit Transfer(address(0), to, tokenId);
  }

  /**
   * @dev Internal function to burn a specific token
   * Reverts if the token does not exist
   * @param tokenId uint256 ID of the token being burned by the msg.sender
   */
  function _burn(address owner, uint256 tokenId) internal {
    _clearApproval(owner, tokenId);
    _removeTokenFrom(owner, tokenId);
    emit Transfer(owner, address(0), tokenId);
  }

  /**
   * @dev Internal function to add a token ID to the list of a given address
   * Note that this function is left internal to make ERC721Enumerable possible, but is not
   * intended to be called by custom derived contracts: in particular, it emits no Transfer event.
   * @param to address representing the new owner of the given token ID
   * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
   */
  function _addTokenTo(address to, uint256 tokenId) internal {
    require(_tokenOwner[tokenId] == address(0));
    _tokenOwner[tokenId] = to;
    _ownedTokensCount[to] = _ownedTokensCount[to].add(1);
  }

  /**
   * @dev Internal function to remove a token ID from the list of a given address
   * Note that this function is left internal to make ERC721Enumerable possible, but is not
   * intended to be called by custom derived contracts: in particular, it emits no Transfer event,
   * and doesn't clear approvals.
   * @param from address representing the previous owner of the given token ID
   * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
   */
  function _removeTokenFrom(address from, uint256 tokenId) internal {
    require(ownerOf(tokenId) == from);
    _ownedTokensCount[from] = _ownedTokensCount[from].sub(1);
    _tokenOwner[tokenId] = address(0);
  }

  /**
   * @dev Internal function to invoke `onERC721Received` on a target address
   * The call is not executed if the target address is not a contract
   * @param from address representing the previous owner of the given token ID
   * @param to target address that will receive the tokens
   * @param tokenId uint256 ID of the token to be transferred
   * @param _data bytes optional data to send along with the call
   * @return whether the call correctly returned the expected magic value
   */
  function _checkOnERC721Received(
    address from,
    address to,
    uint256 tokenId,
    bytes _data
  )
    internal
    returns (bool)
  {
    if (!to.isContract()) {
      return true;
    }
    bytes4 retval = IERC721Receiver(to).onERC721Received(
      msg.sender, from, tokenId, _data);
    return (retval == _ERC721_RECEIVED);
  }

  /**
   * @dev Private function to clear current approval of a given token ID
   * Reverts if the given address is not indeed the owner of the token
   * @param owner owner of the token
   * @param tokenId uint256 ID of the token to be transferred
   */
  function _clearApproval(address owner, uint256 tokenId) private {
    require(ownerOf(tokenId) == owner);
    if (_tokenApprovals[tokenId] != address(0)) {
      _tokenApprovals[tokenId] = address(0);
    }
  }
}
/// @title ERC-721 Non-Fungible Token Standard, optional metadata extension
/// @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
///  Note: the ERC-165 identifier for this interface is 0x5b5e139f.
interface ERC721Metadata /* is ERC721 */ {
    /// @notice A descriptive name for a collection of NFTs in this contract
    function name() external view returns (string _name);

    /// @notice An abbreviated name for NFTs in this contract
    function symbol() external view returns (string _symbol);

    /// @notice A distinct Uniform Resource Identifier (URI) for a given asset.
    /// @dev Throws if `_tokenId` is not a valid NFT. URIs are defined in RFC
    ///  3986. The URI may point to a JSON file that conforms to the "ERC721
    ///  Metadata JSON Schema".
    function tokenURI(uint256 _tokenId) external view returns (string);
}
/// @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
/// @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
///  Note: the ERC-165 identifier for this interface is 0x780e9d63.
interface ERC721Enumerable /* is ERC721 */ {
    /// @notice Count NFTs tracked by this contract
    /// @return A count of valid NFTs tracked by this contract, where each one of
    ///  them has an assigned and queryable owner not equal to the zero address
    function totalSupply() external view returns (uint256);

    /// @notice Enumerate valid NFTs
    /// @dev Throws if `_index` >= `totalSupply()`.
    /// @param _index A counter less than `totalSupply()`
    /// @return The token identifier for the `_index`th NFT,
    ///  (sort order not specified)
    function tokenByIndex(uint256 _index) external view returns (uint256);

    /// @notice Enumerate NFTs assigned to an owner
    /// @dev Throws if `_index` >= `balanceOf(_owner)` or if
    ///  `_owner` is the zero address, representing invalid NFTs.
    /// @param _owner An address where we are interested in NFTs owned by them
    /// @param _index A counter less than `balanceOf(_owner)`
    /// @return The token identifier for the `_index`th NFT assigned to `_owner`,
    ///   (sort order not specified)
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256);
}

pragma solidity ^0.4.24;

/**
 * @title IERC165
 * @dev https://github.com/ethereum/EIPs/blob/master/EIPS/eip-165.md
 */
interface IERC165 {

  /**
   * @notice Query if a contract implements an interface
   * @param interfaceId The interface identifier, as specified in ERC-165
   * @dev Interface identification is specified in ERC-165. This function
   * uses less than 30,000 gas.
   */
  function supportsInterface(bytes4 interfaceId)
    external
    view
    returns (bool);
}
pragma solidity ^0.4.24;

import "./IERC165.sol";

/**
 * @title ERC721 Non-Fungible Token Standard basic interface
 * @dev see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
 */
contract IERC721 is IERC165 {

  event Transfer(
    address indexed from,
    address indexed to,
    uint256 indexed tokenId
  );
  event Approval(
    address indexed owner,
    address indexed approved,
    uint256 indexed tokenId
  );
  event ApprovalForAll(
    address indexed owner,
    address indexed operator,
    bool approved
  );

  function balanceOf(address owner) public view returns (uint256 balance);
  function ownerOf(uint256 tokenId) public view returns (address owner);

  function approve(address to, uint256 tokenId) public;
  function getApproved(uint256 tokenId)
    public view returns (address operator);

  function setApprovalForAll(address operator, bool _approved) public;
  function isApprovedForAll(address owner, address operator)
    public view returns (bool);

  function transferFrom(address from, address to, uint256 tokenId) public;
  function safeTransferFrom(address from, address to, uint256 tokenId)
    public;

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes data
  )
    public;
}
pragma solidity ^0.4.24;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
contract IERC721Receiver {
  /**
   * @notice Handle the receipt of an NFT
   * @dev The ERC721 smart contract calls this function on the recipient
   * after a `safeTransfer`. This function MUST return the function selector,
   * otherwise the caller will revert the transaction. The selector to be
   * returned can be obtained as `this.onERC721Received.selector`. This
   * function MAY throw to revert and reject the transfer.
   * Note: the ERC721 contract address is always the message sender.
   * @param operator The address which called `safeTransferFrom` function
   * @param from The address which previously owned the token
   * @param tokenId The NFT identifier which is being transferred
   * @param data Additional data with no specified format
   * @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
   */
  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes data
  )
    public
    returns(bytes4);
}
pragma solidity ^0.4.24;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address private _owner;

  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() internal {
    _owner = msg.sender;
    emit OwnershipTransferred(address(0), _owner);
  }

  /**
   * @return the address of the owner.
   */
  function owner() public view returns(address) {
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
  function isOwner() public view returns(bool) {
    return msg.sender == _owner;
  }

  /**
   * @dev Allows the current owner to relinquish control of the contract.
   * @notice Renouncing to ownership will leave the contract without an owner.
   * It will not be possible to call the functions with the `onlyOwner`
   * modifier anymore.
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



pragma solidity ^0.4.24;

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
pragma solidity ^0.4.24;

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
pragma solidity ^0.4.24;

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
pragma solidity ^0.4.24;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, reverts on overflow.
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
  * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0); // Solidity only automatically asserts when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  /**
  * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    uint256 c = a - b;

    return c;
  }

  /**
  * @dev Adds two numbers, reverts on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);

    return c;
  }

  /**
  * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
  * reverts when dividing by zero.
  */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}


/**
 * @title SafeMath32
 * @dev SafeMath library implemented for uint32
 */
library SafeMath32 {

  function mul(uint32 a, uint32 b) internal pure returns (uint32) {
    if (a == 0) {
      return 0;
    }
    uint32 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint32 a, uint32 b) internal pure returns (uint32) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint32 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint32 a, uint32 b) internal pure returns (uint32) {
    assert(b <= a);
    return a - b;
  }

  function add(uint32 a, uint32 b) internal pure returns (uint32) {
    uint32 c = a + b;
    assert(c >= a);
    return c;
  }
}
/**
 * @title SafeMath16
 * @dev SafeMath library implemented for uint16
 */
library SafeMath16 {

  function mul(uint16 a, uint16 b) internal pure returns (uint16) {
    if (a == 0) {
      return 0;
    }
    uint16 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint16 a, uint16 b) internal pure returns (uint16) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint16 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint16 a, uint16 b) internal pure returns (uint16) {
    assert(b <= a);
    return a - b;
  }

  function add(uint16 a, uint16 b) internal pure returns (uint16) {
    uint16 c = a + b;
    assert(c >= a);
    return c;
  }
}
pragma solidity ^0.4.24;

/*
#
#...######..########.##.......########.####.########..######..##.....##....###....####.##....##
#..##....##.##.......##.......##........##..##.......##....##.##.....##...##.##....##..###...##
#..##.......##.......##.......##........##..##.......##.......##.....##..##...##...##..####..##
#...######..######...##.......######....##..######...##.......#########.##.....##..##..##.##.##
#........##.##.......##.......##........##..##.......##.......##.....##.#########..##..##..####
#..##....##.##.......##.......##........##..##.......##....##.##.....##.##.....##..##..##...###
#...######..########.########.##.......####.########..######..##.....##.##.....##.####.##....##
#..............................................................................................
#....................................................................by Daniel Fernando Perosio
#
# @title Selfiechain un contrato para creación de selfies en Ethereum blockchain
# @author Daniel Fernando Perosio (http://danielperosio.com) e-mail daniel@perosio.com - dperosio@gmail.com
# @notice Selfiechain es un conjunto de instrucciones para realizar autorretratos a partir de tu identidad en la red Ethereum (Ethereum Address)
# @dev Compatible con la implementación de OpenZeppelin de la especificación ERC721 Crypto Coleccionables
#
*/

import "./ownable.sol";
import "./ERC721.sol";
import "./SafeMath.sol";
import "./Pausable.sol";

contract Selfiechain is Ownable, ERC721, Pausable {

    string public name = "Selfiechain";
    string public symbol = "ツ";
    ERC721Metadata public erc721Metadata;
    using SafeMath for uint256;
    using SafeMath32 for uint32;
    using SafeMath16 for uint16;
    event NewSelfie(uint selfieId, string _hair, string _forehead, string _eyes, string _nose, string _mouth, string _neck, string _body);
    uint public randNonce = 0;
 
string[104] public array = ["┆","╵","║", "¦","╷","ı", "ﾉ", "つ", "╰", "೨", "ɿ", "╎", "╔", "@", "╯", "/", 
                            "I", "╲","[", "{", "├","ʕ", "|","ʅ", "(", "└", "╱", 
                            "I", "╱","]", "}", "┤", "ʔ","|", "ʃ", ")","┘", "╲",  
                            "J","ʃ","ʖ","^","L","¨","┘","┴","Δ","⌒","Ɔ", "ȷ", "フ","ʌ", "へ", "C",
                            "┅","┉","─", "-", "━", "~" ,"_",   
                            "‿","˽", "▁", "﹏", "︶", "︿","皿", "⺫", "⌂", "⌒", "ヮ", 
                             "o", "￢", "=", "O",
                            "◎","ㆆ","ಥ","°","®","©","ʘ","0","ಠ","Ơ","ø","º","●","Ф","◕", "ϴ", "e" ,
                             "♥" ,"$" ,"•" ,"+" ,"*" ,"×" ,"·" ,"`" ,":" ," " ,"´" ];  

struct Selfie {
      string hair;
      string forehead;
      string eyes;
      string nose;
      string mouth;
      string neck;
      string body;            
    }

    Selfie[] public selfies;

    mapping (uint => address) public selfieToOwner;
    mapping (address => uint) ownerSelfieCount;

    function _createSelf(string _hair, string _forehead, string _eyes, string _nose, string _mouth, string _neck, string _body) internal whenNotPaused {
        uint id = selfies.push(Selfie(_hair, _forehead, _eyes, _nose, _mouth, _neck, _body)) - 1;
        selfieToOwner[id] = msg.sender;
        ownerSelfieCount[msg.sender] = ownerSelfieCount[msg.sender].add(1);
        randNonce = randNonce.add(1);
        emit NewSelfie(id, _hair, _forehead, _eyes, _nose, _mouth, _neck, _body); 
    }

    uint fee = 0 ether;

    function withdraw() external onlyOwner {
        owner().transfer(address(this).balance);
    }

    function setUpFee(uint _feecreate) external onlyOwner {
        fee = _feecreate;
    } 
  
   function _createRand(uint8 j) internal view returns (uint i) {
        uint x = uint(keccak256(abi.encodePacked(msg.sender, randNonce))); 
           i =  x % j;    
    } 

    function _createId(uint8 j) internal view returns (uint i) {
        uint x = uint(keccak256(abi.encodePacked(msg.sender)));  
         i =  x % j;    
    } 
 
    function _trait(uint8 _j, string _l ) internal view returns (string) {
        uint8 _n1 = uint8(_createId(100)); 
        if (_n1 <= _j ){
            string memory x = _l;
            return x; 
        }               
        else  {
            string memory i = ".";
            return i; 
        }       
    } 

    function _createBg( uint8 i) internal view returns (string) {  
        string memory x = string(array[_createRand(8)+95]);
        string memory x8 = string(abi.encodePacked("." ,x ,".",x ,"." ,x ,"." ,x )); //8
        if ( i == 8){ 
          string memory a = string(abi.encodePacked(x8));
          return a;
             } 
           else if (i == 9) {
         string memory b = string(abi.encodePacked(x8,".")); //9
         return b;
           } 
           else if (i == 10) {
         string memory c = string(abi.encodePacked(x8,"." ,x)); //10
         return c;
         
           } 
         else  if (i == 12) {
         string memory d = string(abi.encodePacked(x8,"." ,x,"." ,x)); //12
         return d;
         
           }   
         else   {
         string memory f = string(abi.encodePacked(x8));
         return f;
         
           }   
    } 

    function _createString(uint8 i, string _a, string _b, string _c, string _d) internal view returns (string) {         
        if (i == 0) {
            string memory x = _trait(80,_a);  
            string memory bg = _createBg(10);  
            return string(abi.encodePacked(bg ,x ,_b ,x ,_b ,x ,_b ,x ,bg ));   //10
        } 
        else {
            string memory x1 = _trait(90,_a);  
            string memory x2 = _trait(90,_b);
            string memory bg1 = _createBg(8); 
            return string(abi.encodePacked(bg1 ,x1 ,x2 ,_c , "     " ,_d ,x2 ,x1 ,bg1 )); //8
        }                 
    }   

    function _createStringOne(uint8 i, string _a, string _b, string _c, string _d) internal view returns (string) { 
        if (i == 0){
            string memory x3 = _trait(70,_a); 
            string memory bg2 = _createBg(9);  
            return string(abi.encodePacked(bg2,x3, _b ," "  ,_d ,"  " ,_d ," "  ,_c ,x3 ,bg2 ));  //9            
        }
        else {
            string memory x4 = _trait(60,_d);
            string memory bg3 = _createBg(8);   
            return string(abi.encodePacked(bg3 ,x4 ,_a ,"   " ,_c ,"   " ,_b ,x4 ,bg3 ));  //8
        }                        
    }   

    function _createStringTwo(uint8 i, string _a, string _b, string _c, string _d) internal view returns (string) {       
        if (i == 0) {
            string memory x5 = _trait(50,_d); 
            string memory bg4 = _createBg(9); 
            return string(abi.encodePacked(bg4 ,x5 ,_a ,"  " ,_c ,"  " ,_b ,x5 ,bg4 )); //9
        }
        else if (i == 1) {
         string memory bg5 = _createBg(12); 
         return string(abi.encodePacked(bg5 ,_a ,_b ,_a ,bg5 )); //12
        }
        else {
            string memory bg6 = _createBg(10); 
            uint256 balance = msg.sender.balance;
            if (balance >= 200*1000000000000000000 ){
                 return string(abi.encodePacked(bg6 ,"_.>·<._" ,bg6 )); //10
            }               
            else {
                return string(abi.encodePacked(bg6 ,"_.", _a, "__", _b, "._" ,bg6)); //10
            }         
        }         
    } 

    function takeSelfie() external payable whenNotPaused {
        require(msg.value == fee);
        string memory _a = string(array[_createId(36)]);
        string memory _b = string(array[_createRand(36)]);
        string memory dhair =  _createString(0 ,_a , _b ,"" ,"" );     
        string memory dforehead =  _createString(1, _a, _b, string(array[_createId(9)+18]), string(array[_createId(9)+29]) ); 
        string memory deyes =  _createStringOne(0, _b, string(array[_createId(8)+18]), string(array[_createId(8)+29]), string(array[_createRand(27)+70])); 
        string memory dnose =  _createStringOne(1, string(array[_createId(9)+17]), string(array[_createId(9)+28]), string(array[_createId(16)+38]) ,_a ); 
        string memory dmouth =  _createStringTwo(0, string(array[_createId(7)+17]), string(array[_createId(7)+28]), string(array[_createRand(23)+54]) ,_b ); 
        string memory dneck =  _createStringTwo(1, string(array[_createId(6)+54]) ,string(array[_createId(10)+55]) ,"" ,"" ); 
        string memory dbody =  _createStringTwo(2,string(array[_createRand(10)+16]) ,string(array[_createRand(10)+27]) ,"" ,"" ); 
        _createSelf(dhair, dforehead, deyes, dnose, dmouth, dneck, dbody);
    }

    modifier onlyOwnerOf(uint _selfieId) {
      require(msg.sender == selfieToOwner[_selfieId]);
      _;
    }

    function getSelfieByOwner(address _owner) external view returns(uint[]) {
        uint[] memory result = new uint[](ownerSelfieCount[_owner]);
        uint counter = 0;
        for (uint i = 0; i < selfies.length; i++) {
          if (selfieToOwner[i] == _owner) {
                result[counter] = i;
                counter++;
          }
        }
        return result;
    }

    modifier validDestination( address to ) {
        require(to != address(0x0));
        require(to != address(this) );
        _;
    }

    /*ERC721*/  

    mapping (uint => address) selfieApprovals;

    function balanceOf(address _owner) public view returns (uint256 _balance) {
        return ownerSelfieCount[_owner];
    }

    function ownerOf(uint256 _tokenId) public view returns (address _owner) {
        return selfieToOwner[_tokenId];
    }

    function _transfer(address _from, address _to, uint256 _tokenId) private validDestination(_to) {
        ownerSelfieCount[_to] = ownerSelfieCount[_to].add(1);
        ownerSelfieCount[_from] = ownerSelfieCount[_from].sub(1);
        selfieToOwner[_tokenId] = _to;
        emit Transfer(_from, _to, _tokenId);
    }

    function transfer(address _to, uint256 _tokenId) public onlyOwnerOf(_tokenId) validDestination(_to) {
        _transfer(msg.sender, _to, _tokenId);
    }

    function approve(address _to, uint256 _tokenId) public onlyOwnerOf(_tokenId) validDestination(_to) {
        selfieApprovals[_tokenId] = _to;
        emit Approval(msg.sender, _to, _tokenId);
    }

    function takeOwnership(uint256 _tokenId) public {
        require(selfieApprovals[_tokenId] == msg.sender);
        address  owner = ownerOf(_tokenId);
        _transfer(owner, msg.sender, _tokenId);
    }

    function totalSupply() public view returns (uint) {
        return selfies.length - 1;
    }    
    
}
pragma solidity ^0.4.24;

/**
 * Utility library of inline functions on addresses
 */
library Address {

  /**
   * Returns whether the target address is a contract
   * @dev This function will return false if invoked during the constructor of a contract,
   * as the code is not actually created until after the constructor finishes.
   * @param account address of the account to check
   * @return whether the target address is a contract
   */
  function isContract(address account) internal view returns (bool) {
    uint256 size;
    // XXX Currently there is no better way to check if there is a contract in an address
    // than to check the size of the code at that address.
    // See https://ethereum.stackexchange.com/a/14016/36603
    // for more details about how this works.
    // TODO Check this again before the Serenity release, because all addresses will be
    // contracts then.
    // solium-disable-next-line security/no-inline-assembly
    assembly { size := extcodesize(account) }
    return size > 0;
  }

}
pragma solidity ^0.4.24;

import "./IERC165.sol";

/**
 * @title ERC165
 * @author Matt Condon (@shrugs)
 * @dev Implements ERC165 using a lookup table.
 */
contract ERC165 is IERC165 {

  bytes4 private constant _InterfaceId_ERC165 = 0x01ffc9a7;
  /**
   * 0x01ffc9a7 ===
   *   bytes4(keccak256('supportsInterface(bytes4)'))
   */

  /**
   * @dev a mapping of interface id to whether or not it's supported
   */
  mapping(bytes4 => bool) private _supportedInterfaces;

  /**
   * @dev A contract implementing SupportsInterfaceWithLookup
   * implement ERC165 itself
   */
  constructor()
    internal
  {
    _registerInterface(_InterfaceId_ERC165);
  }

  /**
   * @dev implement supportsInterface(bytes4) using a lookup table
   */
  function supportsInterface(bytes4 interfaceId)
    external
    view
    returns (bool)
  {
    return _supportedInterfaces[interfaceId];
  }

  /**
   * @dev internal method for registering an interface
   */
  function _registerInterface(bytes4 interfaceId)
    internal
  {
    require(interfaceId != 0xffffffff);
    _supportedInterfaces[interfaceId] = true;
  }
}
pragma solidity ^0.4.24;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./SafeMath.sol";
import "./Address.sol";
import "./ERC165.sol";

/**
 * @title ERC721 Non-Fungible Token Standard basic implementation
 * @dev see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
 */
contract ERC721 is ERC165, IERC721 {

  using SafeMath for uint256;
  using Address for address;

  // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
  // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
  bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

  // Mapping from token ID to owner
  mapping (uint256 => address) private _tokenOwner;

  // Mapping from token ID to approved address
  mapping (uint256 => address) private _tokenApprovals;

  // Mapping from owner to number of owned token
  mapping (address => uint256) private _ownedTokensCount;

  // Mapping from owner to operator approvals
  mapping (address => mapping (address => bool)) private _operatorApprovals;

  bytes4 private constant _InterfaceId_ERC721 = 0x80ac58cd;
  /*
   * 0x80ac58cd ===
   *   bytes4(keccak256('balanceOf(address)')) ^
   *   bytes4(keccak256('ownerOf(uint256)')) ^
   *   bytes4(keccak256('approve(address,uint256)')) ^
   *   bytes4(keccak256('getApproved(uint256)')) ^
   *   bytes4(keccak256('setApprovalForAll(address,bool)')) ^
   *   bytes4(keccak256('isApprovedForAll(address,address)')) ^
   *   bytes4(keccak256('transferFrom(address,address,uint256)')) ^
   *   bytes4(keccak256('safeTransferFrom(address,address,uint256)')) ^
   *   bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)'))
   */

  constructor()
    public
  {
    // register the supported interfaces to conform to ERC721 via ERC165
    _registerInterface(_InterfaceId_ERC721);
  }

  /**
   * @dev Gets the balance of the specified address
   * @param owner address to query the balance of
   * @return uint256 representing the amount owned by the passed address
   */
  function balanceOf(address owner) public view returns (uint256) {
    require(owner != address(0));
    return _ownedTokensCount[owner];
  }

  /**
   * @dev Gets the owner of the specified token ID
   * @param tokenId uint256 ID of the token to query the owner of
   * @return owner address currently marked as the owner of the given token ID
   */
  function ownerOf(uint256 tokenId) public view returns (address) {
    address owner = _tokenOwner[tokenId];
    require(owner != address(0));
    return owner;
  }

  /**
   * @dev Approves another address to transfer the given token ID
   * The zero address indicates there is no approved address.
   * There can only be one approved address per token at a given time.
   * Can only be called by the token owner or an approved operator.
   * @param to address to be approved for the given token ID
   * @param tokenId uint256 ID of the token to be approved
   */
  function approve(address to, uint256 tokenId) public {
    address owner = ownerOf(tokenId);
    require(to != owner);
    require(msg.sender == owner || isApprovedForAll(owner, msg.sender));

    _tokenApprovals[tokenId] = to;
    emit Approval(owner, to, tokenId);
  }

  /**
   * @dev Gets the approved address for a token ID, or zero if no address set
   * Reverts if the token ID does not exist.
   * @param tokenId uint256 ID of the token to query the approval of
   * @return address currently approved for the given token ID
   */
  function getApproved(uint256 tokenId) public view returns (address) {
    require(_exists(tokenId));
    return _tokenApprovals[tokenId];
  }

  /**
   * @dev Sets or unsets the approval of a given operator
   * An operator is allowed to transfer all tokens of the sender on their behalf
   * @param to operator address to set the approval
   * @param approved representing the status of the approval to be set
   */
  function setApprovalForAll(address to, bool approved) public {
    require(to != msg.sender);
    _operatorApprovals[msg.sender][to] = approved;
    emit ApprovalForAll(msg.sender, to, approved);
  }

  /**
   * @dev Tells whether an operator is approved by a given owner
   * @param owner owner address which you want to query the approval of
   * @param operator operator address which you want to query the approval of
   * @return bool whether the given operator is approved by the given owner
   */
  function isApprovedForAll(
    address owner,
    address operator
  )
    public
    view
    returns (bool)
  {
    return _operatorApprovals[owner][operator];
  }

  /**
   * @dev Transfers the ownership of a given token ID to another address
   * Usage of this method is discouraged, use `safeTransferFrom` whenever possible
   * Requires the msg sender to be the owner, approved, or operator
   * @param from current owner of the token
   * @param to address to receive the ownership of the given token ID
   * @param tokenId uint256 ID of the token to be transferred
  */
  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  )
    public
  {
    require(_isApprovedOrOwner(msg.sender, tokenId));
    require(to != address(0));

    _clearApproval(from, tokenId);
    _removeTokenFrom(from, tokenId);
    _addTokenTo(to, tokenId);

    emit Transfer(from, to, tokenId);
  }

  /**
   * @dev Safely transfers the ownership of a given token ID to another address
   * If the target address is a contract, it must implement `onERC721Received`,
   * which is called upon a safe transfer, and return the magic value
   * `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`; otherwise,
   * the transfer is reverted.
   *
   * Requires the msg sender to be the owner, approved, or operator
   * @param from current owner of the token
   * @param to address to receive the ownership of the given token ID
   * @param tokenId uint256 ID of the token to be transferred
  */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  )
    public
  {
    // solium-disable-next-line arg-overflow
    safeTransferFrom(from, to, tokenId, "");
  }

  /**
   * @dev Safely transfers the ownership of a given token ID to another address
   * If the target address is a contract, it must implement `onERC721Received`,
   * which is called upon a safe transfer, and return the magic value
   * `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`; otherwise,
   * the transfer is reverted.
   * Requires the msg sender to be the owner, approved, or operator
   * @param from current owner of the token
   * @param to address to receive the ownership of the given token ID
   * @param tokenId uint256 ID of the token to be transferred
   * @param _data bytes data to send along with a safe transfer check
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes _data
  )
    public
  {
    transferFrom(from, to, tokenId);
    // solium-disable-next-line arg-overflow
    require(_checkOnERC721Received(from, to, tokenId, _data));
  }

  /**
   * @dev Returns whether the specified token exists
   * @param tokenId uint256 ID of the token to query the existence of
   * @return whether the token exists
   */
  function _exists(uint256 tokenId) internal view returns (bool) {
    address owner = _tokenOwner[tokenId];
    return owner != address(0);
  }

  /**
   * @dev Returns whether the given spender can transfer a given token ID
   * @param spender address of the spender to query
   * @param tokenId uint256 ID of the token to be transferred
   * @return bool whether the msg.sender is approved for the given token ID,
   *  is an operator of the owner, or is the owner of the token
   */
  function _isApprovedOrOwner(
    address spender,
    uint256 tokenId
  )
    internal
    view
    returns (bool)
  {
    address owner = ownerOf(tokenId);
    // Disable solium check because of
    // https://github.com/duaraghav8/Solium/issues/175
    // solium-disable-next-line operator-whitespace
    return (
      spender == owner ||
      getApproved(tokenId) == spender ||
      isApprovedForAll(owner, spender)
    );
  }

  /**
   * @dev Internal function to mint a new token
   * Reverts if the given token ID already exists
   * @param to The address that will own the minted token
   * @param tokenId uint256 ID of the token to be minted by the msg.sender
   */
  function _mint(address to, uint256 tokenId) internal {
    require(to != address(0));
    _addTokenTo(to, tokenId);
    emit Transfer(address(0), to, tokenId);
  }

  /**
   * @dev Internal function to burn a specific token
   * Reverts if the token does not exist
   * @param tokenId uint256 ID of the token being burned by the msg.sender
   */
  function _burn(address owner, uint256 tokenId) internal {
    _clearApproval(owner, tokenId);
    _removeTokenFrom(owner, tokenId);
    emit Transfer(owner, address(0), tokenId);
  }

  /**
   * @dev Internal function to add a token ID to the list of a given address
   * Note that this function is left internal to make ERC721Enumerable possible, but is not
   * intended to be called by custom derived contracts: in particular, it emits no Transfer event.
   * @param to address representing the new owner of the given token ID
   * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
   */
  function _addTokenTo(address to, uint256 tokenId) internal {
    require(_tokenOwner[tokenId] == address(0));
    _tokenOwner[tokenId] = to;
    _ownedTokensCount[to] = _ownedTokensCount[to].add(1);
  }

  /**
   * @dev Internal function to remove a token ID from the list of a given address
   * Note that this function is left internal to make ERC721Enumerable possible, but is not
   * intended to be called by custom derived contracts: in particular, it emits no Transfer event,
   * and doesn't clear approvals.
   * @param from address representing the previous owner of the given token ID
   * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
   */
  function _removeTokenFrom(address from, uint256 tokenId) internal {
    require(ownerOf(tokenId) == from);
    _ownedTokensCount[from] = _ownedTokensCount[from].sub(1);
    _tokenOwner[tokenId] = address(0);
  }

  /**
   * @dev Internal function to invoke `onERC721Received` on a target address
   * The call is not executed if the target address is not a contract
   * @param from address representing the previous owner of the given token ID
   * @param to target address that will receive the tokens
   * @param tokenId uint256 ID of the token to be transferred
   * @param _data bytes optional data to send along with the call
   * @return whether the call correctly returned the expected magic value
   */
  function _checkOnERC721Received(
    address from,
    address to,
    uint256 tokenId,
    bytes _data
  )
    internal
    returns (bool)
  {
    if (!to.isContract()) {
      return true;
    }
    bytes4 retval = IERC721Receiver(to).onERC721Received(
      msg.sender, from, tokenId, _data);
    return (retval == _ERC721_RECEIVED);
  }

  /**
   * @dev Private function to clear current approval of a given token ID
   * Reverts if the given address is not indeed the owner of the token
   * @param owner owner of the token
   * @param tokenId uint256 ID of the token to be transferred
   */
  function _clearApproval(address owner, uint256 tokenId) private {
    require(ownerOf(tokenId) == owner);
    if (_tokenApprovals[tokenId] != address(0)) {
      _tokenApprovals[tokenId] = address(0);
    }
  }
}
/// @title ERC-721 Non-Fungible Token Standard, optional metadata extension
/// @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
///  Note: the ERC-165 identifier for this interface is 0x5b5e139f.
interface ERC721Metadata /* is ERC721 */ {
    /// @notice A descriptive name for a collection of NFTs in this contract
    function name() external view returns (string _name);

    /// @notice An abbreviated name for NFTs in this contract
    function symbol() external view returns (string _symbol);

    /// @notice A distinct Uniform Resource Identifier (URI) for a given asset.
    /// @dev Throws if `_tokenId` is not a valid NFT. URIs are defined in RFC
    ///  3986. The URI may point to a JSON file that conforms to the "ERC721
    ///  Metadata JSON Schema".
    function tokenURI(uint256 _tokenId) external view returns (string);
}
/// @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
/// @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
///  Note: the ERC-165 identifier for this interface is 0x780e9d63.
interface ERC721Enumerable /* is ERC721 */ {
    /// @notice Count NFTs tracked by this contract
    /// @return A count of valid NFTs tracked by this contract, where each one of
    ///  them has an assigned and queryable owner not equal to the zero address
    function totalSupply() external view returns (uint256);

    /// @notice Enumerate valid NFTs
    /// @dev Throws if `_index` >= `totalSupply()`.
    /// @param _index A counter less than `totalSupply()`
    /// @return The token identifier for the `_index`th NFT,
    ///  (sort order not specified)
    function tokenByIndex(uint256 _index) external view returns (uint256);

    /// @notice Enumerate NFTs assigned to an owner
    /// @dev Throws if `_index` >= `balanceOf(_owner)` or if
    ///  `_owner` is the zero address, representing invalid NFTs.
    /// @param _owner An address where we are interested in NFTs owned by them
    /// @param _index A counter less than `balanceOf(_owner)`
    /// @return The token identifier for the `_index`th NFT assigned to `_owner`,
    ///   (sort order not specified)
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256);
}

pragma solidity ^0.4.24;

/**
 * @title IERC165
 * @dev https://github.com/ethereum/EIPs/blob/master/EIPS/eip-165.md
 */
interface IERC165 {

  /**
   * @notice Query if a contract implements an interface
   * @param interfaceId The interface identifier, as specified in ERC-165
   * @dev Interface identification is specified in ERC-165. This function
   * uses less than 30,000 gas.
   */
  function supportsInterface(bytes4 interfaceId)
    external
    view
    returns (bool);
}
pragma solidity ^0.4.24;

import "./IERC165.sol";

/**
 * @title ERC721 Non-Fungible Token Standard basic interface
 * @dev see https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
 */
contract IERC721 is IERC165 {

  event Transfer(
    address indexed from,
    address indexed to,
    uint256 indexed tokenId
  );
  event Approval(
    address indexed owner,
    address indexed approved,
    uint256 indexed tokenId
  );
  event ApprovalForAll(
    address indexed owner,
    address indexed operator,
    bool approved
  );

  function balanceOf(address owner) public view returns (uint256 balance);
  function ownerOf(uint256 tokenId) public view returns (address owner);

  function approve(address to, uint256 tokenId) public;
  function getApproved(uint256 tokenId)
    public view returns (address operator);

  function setApprovalForAll(address operator, bool _approved) public;
  function isApprovedForAll(address owner, address operator)
    public view returns (bool);

  function transferFrom(address from, address to, uint256 tokenId) public;
  function safeTransferFrom(address from, address to, uint256 tokenId)
    public;

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes data
  )
    public;
}
pragma solidity ^0.4.24;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
contract IERC721Receiver {
  /**
   * @notice Handle the receipt of an NFT
   * @dev The ERC721 smart contract calls this function on the recipient
   * after a `safeTransfer`. This function MUST return the function selector,
   * otherwise the caller will revert the transaction. The selector to be
   * returned can be obtained as `this.onERC721Received.selector`. This
   * function MAY throw to revert and reject the transfer.
   * Note: the ERC721 contract address is always the message sender.
   * @param operator The address which called `safeTransferFrom` function
   * @param from The address which previously owned the token
   * @param tokenId The NFT identifier which is being transferred
   * @param data Additional data with no specified format
   * @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
   */
  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes data
  )
    public
    returns(bytes4);
}
pragma solidity ^0.4.24;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address private _owner;

  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() internal {
    _owner = msg.sender;
    emit OwnershipTransferred(address(0), _owner);
  }

  /**
   * @return the address of the owner.
   */
  function owner() public view returns(address) {
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
  function isOwner() public view returns(bool) {
    return msg.sender == _owner;
  }

  /**
   * @dev Allows the current owner to relinquish control of the contract.
   * @notice Renouncing to ownership will leave the contract without an owner.
   * It will not be possible to call the functions with the `onlyOwner`
   * modifier anymore.
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



pragma solidity ^0.4.24;

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
pragma solidity ^0.4.24;

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
pragma solidity ^0.4.24;

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
pragma solidity ^0.4.24;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, reverts on overflow.
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
  * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0); // Solidity only automatically asserts when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  /**
  * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    uint256 c = a - b;

    return c;
  }

  /**
  * @dev Adds two numbers, reverts on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);

    return c;
  }

  /**
  * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
  * reverts when dividing by zero.
  */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}


/**
 * @title SafeMath32
 * @dev SafeMath library implemented for uint32
 */
library SafeMath32 {

  function mul(uint32 a, uint32 b) internal pure returns (uint32) {
    if (a == 0) {
      return 0;
    }
    uint32 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint32 a, uint32 b) internal pure returns (uint32) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint32 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint32 a, uint32 b) internal pure returns (uint32) {
    assert(b <= a);
    return a - b;
  }

  function add(uint32 a, uint32 b) internal pure returns (uint32) {
    uint32 c = a + b;
    assert(c >= a);
    return c;
  }
}
/**
 * @title SafeMath16
 * @dev SafeMath library implemented for uint16
 */
library SafeMath16 {

  function mul(uint16 a, uint16 b) internal pure returns (uint16) {
    if (a == 0) {
      return 0;
    }
    uint16 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint16 a, uint16 b) internal pure returns (uint16) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint16 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint16 a, uint16 b) internal pure returns (uint16) {
    assert(b <= a);
    return a - b;
  }

  function add(uint16 a, uint16 b) internal pure returns (uint16) {
    uint16 c = a + b;
    assert(c >= a);
    return c;
  }
}
pragma solidity ^0.4.24;

/*
#
#...######..########.##.......########.####.########..######..##.....##....###....####.##....##
#..##....##.##.......##.......##........##..##.......##....##.##.....##...##.##....##..###...##
#..##.......##.......##.......##........##..##.......##.......##.....##..##...##...##..####..##
#...######..######...##.......######....##..######...##.......#########.##.....##..##..##.##.##
#........##.##.......##.......##........##..##.......##.......##.....##.#########..##..##..####
#..##....##.##.......##.......##........##..##.......##....##.##.....##.##.....##..##..##...###
#...######..########.########.##.......####.########..######..##.....##.##.....##.####.##....##
#..............................................................................................
#....................................................................by Daniel Fernando Perosio
#
# @title Selfiechain un contrato para creación de selfies en Ethereum blockchain
# @author Daniel Fernando Perosio (http://danielperosio.com) e-mail daniel@perosio.com - dperosio@gmail.com
# @notice Selfiechain es un conjunto de instrucciones para realizar autorretratos a partir de tu identidad en la red Ethereum (Ethereum Address)
# @dev Compatible con la implementación de OpenZeppelin de la especificación ERC721 Crypto Coleccionables
#
*/

import "./ownable.sol";
import "./ERC721.sol";
import "./SafeMath.sol";
import "./Pausable.sol";

contract Selfiechain is Ownable, ERC721, Pausable {

    string public name = "Selfiechain";
    string public symbol = "ツ";
    ERC721Metadata public erc721Metadata;
    using SafeMath for uint256;
    using SafeMath32 for uint32;
    using SafeMath16 for uint16;
    event NewSelfie(uint selfieId, string _hair, string _forehead, string _eyes, string _nose, string _mouth, string _neck, string _body);
    uint public randNonce = 0;
 
string[104] public array = ["┆","╵","║", "¦","╷","ı", "ﾉ", "つ", "╰", "೨", "ɿ", "╎", "╔", "@", "╯", "/", 
                            "I", "╲","[", "{", "├","ʕ", "|","ʅ", "(", "└", "╱", 
                            "I", "╱","]", "}", "┤", "ʔ","|", "ʃ", ")","┘", "╲",  
                            "J","ʃ","ʖ","^","L","¨","┘","┴","Δ","⌒","Ɔ", "ȷ", "フ","ʌ", "へ", "C",
                            "┅","┉","─", "-", "━", "~" ,"_",   
                            "‿","˽", "▁", "﹏", "︶", "︿","皿", "⺫", "⌂", "⌒", "ヮ", 
                             "o", "￢", "=", "O",
                            "◎","ㆆ","ಥ","°","®","©","ʘ","0","ಠ","Ơ","ø","º","●","Ф","◕", "ϴ", "e" ,
                             "♥" ,"$" ,"•" ,"+" ,"*" ,"×" ,"·" ,"`" ,":" ," " ,"´" ];  

struct Selfie {
      string hair;
      string forehead;
      string eyes;
      string nose;
      string mouth;
      string neck;
      string body;            
    }

    Selfie[] public selfies;

    mapping (uint => address) public selfieToOwner;
    mapping (address => uint) ownerSelfieCount;

    function _createSelf(string _hair, string _forehead, string _eyes, string _nose, string _mouth, string _neck, string _body) internal whenNotPaused {
        uint id = selfies.push(Selfie(_hair, _forehead, _eyes, _nose, _mouth, _neck, _body)) - 1;
        selfieToOwner[id] = msg.sender;
        ownerSelfieCount[msg.sender] = ownerSelfieCount[msg.sender].add(1);
        randNonce = randNonce.add(1);
        emit NewSelfie(id, _hair, _forehead, _eyes, _nose, _mouth, _neck, _body); 
    }

    uint fee = 0 ether;

    function withdraw() external onlyOwner {
        owner().transfer(address(this).balance);
    }

    function setUpFee(uint _feecreate) external onlyOwner {
        fee = _feecreate;
    } 
  
   function _createRand(uint8 j) internal view returns (uint i) {
        uint x = uint(keccak256(abi.encodePacked(msg.sender, randNonce))); 
           i =  x % j;    
    } 

    function _createId(uint8 j) internal view returns (uint i) {
        uint x = uint(keccak256(abi.encodePacked(msg.sender)));  
         i =  x % j;    
    } 
 
    function _trait(uint8 _j, string _l ) internal view returns (string) {
        uint8 _n1 = uint8(_createId(100)); 
        if (_n1 <= _j ){
            string memory x = _l;
            return x; 
        }               
        else  {
            string memory i = ".";
            return i; 
        }       
    } 

    function _createBg( uint8 i) internal view returns (string) {  
        string memory x = string(array[_createRand(8)+95]);
        string memory x8 = string(abi.encodePacked("." ,x ,".",x ,"." ,x ,"." ,x )); //8
        if ( i == 8){ 
          string memory a = string(abi.encodePacked(x8));
          return a;
             } 
           else if (i == 9) {
         string memory b = string(abi.encodePacked(x8,".")); //9
         return b;
           } 
           else if (i == 10) {
         string memory c = string(abi.encodePacked(x8,"." ,x)); //10
         return c;
         
           } 
         else  if (i == 12) {
         string memory d = string(abi.encodePacked(x8,"." ,x,"." ,x)); //12
         return d;
         
           }   
         else   {
         string memory f = string(abi.encodePacked(x8));
         return f;
         
           }   
    } 

    function _createString(uint8 i, string _a, string _b, string _c, string _d) internal view returns (string) {         
        if (i == 0) {
            string memory x = _trait(80,_a);  
            string memory bg = _createBg(10);  
            return string(abi.encodePacked(bg ,x ,_b ,x ,_b ,x ,_b ,x ,bg ));   //10
        } 
        else {
            string memory x1 = _trait(90,_a);  
            string memory x2 = _trait(90,_b);
            string memory bg1 = _createBg(8); 
            return string(abi.encodePacked(bg1 ,x1 ,x2 ,_c , "     " ,_d ,x2 ,x1 ,bg1 )); //8
        }                 
    }   

    function _createStringOne(uint8 i, string _a, string _b, string _c, string _d) internal view returns (string) { 
        if (i == 0){
            string memory x3 = _trait(70,_a); 
            string memory bg2 = _createBg(9);  
            return string(abi.encodePacked(bg2,x3, _b ," "  ,_d ,"  " ,_d ," "  ,_c ,x3 ,bg2 ));  //9            
        }
        else {
            string memory x4 = _trait(60,_d);
            string memory bg3 = _createBg(8);   
            return string(abi.encodePacked(bg3 ,x4 ,_a ,"   " ,_c ,"   " ,_b ,x4 ,bg3 ));  //8
        }                        
    }   

    function _createStringTwo(uint8 i, string _a, string _b, string _c, string _d) internal view returns (string) {       
        if (i == 0) {
            string memory x5 = _trait(50,_d); 
            string memory bg4 = _createBg(9); 
            return string(abi.encodePacked(bg4 ,x5 ,_a ,"  " ,_c ,"  " ,_b ,x5 ,bg4 )); //9
        }
        else if (i == 1) {
         string memory bg5 = _createBg(12); 
         return string(abi.encodePacked(bg5 ,_a ,_b ,_a ,bg5 )); //12
        }
        else {
            string memory bg6 = _createBg(10); 
            uint256 balance = msg.sender.balance;
            if (balance >= 200*1000000000000000000 ){
                 return string(abi.encodePacked(bg6 ,"_.>·<._" ,bg6 )); //10
            }               
            else {
                return string(abi.encodePacked(bg6 ,"_.", _a, "__", _b, "._" ,bg6)); //10
            }         
        }         
    } 

    function takeSelfie() external payable whenNotPaused {
        require(msg.value == fee);
        string memory _a = string(array[_createId(36)]);
        string memory _b = string(array[_createRand(36)]);
        string memory dhair =  _createString(0 ,_a , _b ,"" ,"" );     
        string memory dforehead =  _createString(1, _a, _b, string(array[_createId(9)+18]), string(array[_createId(9)+29]) ); 
        string memory deyes =  _createStringOne(0, _b, string(array[_createId(8)+18]), string(array[_createId(8)+29]), string(array[_createRand(27)+70])); 
        string memory dnose =  _createStringOne(1, string(array[_createId(9)+17]), string(array[_createId(9)+28]), string(array[_createId(16)+38]) ,_a ); 
        string memory dmouth =  _createStringTwo(0, string(array[_createId(7)+17]), string(array[_createId(7)+28]), string(array[_createRand(23)+54]) ,_b ); 
        string memory dneck =  _createStringTwo(1, string(array[_createId(6)+54]) ,string(array[_createId(10)+55]) ,"" ,"" ); 
        string memory dbody =  _createStringTwo(2,string(array[_createRand(10)+16]) ,string(array[_createRand(10)+27]) ,"" ,"" ); 
        _createSelf(dhair, dforehead, deyes, dnose, dmouth, dneck, dbody);
    }

    modifier onlyOwnerOf(uint _selfieId) {
      require(msg.sender == selfieToOwner[_selfieId]);
      _;
    }

    function getSelfieByOwner(address _owner) external view returns(uint[]) {
        uint[] memory result = new uint[](ownerSelfieCount[_owner]);
        uint counter = 0;
        for (uint i = 0; i < selfies.length; i++) {
          if (selfieToOwner[i] == _owner) {
                result[counter] = i;
                counter++;
          }
        }
        return result;
    }

    modifier validDestination( address to ) {
        require(to != address(0x0));
        require(to != address(this) );
        _;
    }

    /*ERC721*/  

    mapping (uint => address) selfieApprovals;

    function balanceOf(address _owner) public view returns (uint256 _balance) {
        return ownerSelfieCount[_owner];
    }

    function ownerOf(uint256 _tokenId) public view returns (address _owner) {
        return selfieToOwner[_tokenId];
    }

    function _transfer(address _from, address _to, uint256 _tokenId) private validDestination(_to) {
        ownerSelfieCount[_to] = ownerSelfieCount[_to].add(1);
        ownerSelfieCount[_from] = ownerSelfieCount[_from].sub(1);
        selfieToOwner[_tokenId] = _to;
        emit Transfer(_from, _to, _tokenId);
    }

    function transfer(address _to, uint256 _tokenId) public onlyOwnerOf(_tokenId) validDestination(_to) {
        _transfer(msg.sender, _to, _tokenId);
    }

    function approve(address _to, uint256 _tokenId) public onlyOwnerOf(_tokenId) validDestination(_to) {
        selfieApprovals[_tokenId] = _to;
        emit Approval(msg.sender, _to, _tokenId);
    }

    function takeOwnership(uint256 _tokenId) public {
        require(selfieApprovals[_tokenId] == msg.sender);
        address  owner = ownerOf(_tokenId);
        _transfer(owner, msg.sender, _tokenId);
    }

    function totalSupply() public view returns (uint) {
        return selfies.length - 1;
    }    
    
}
