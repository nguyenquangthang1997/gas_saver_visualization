
// SPDX-License-Identifier: BSD 3-Clause

pragma solidity ^0.6.10;

import "./EndaomentAdminStorage.sol";
import "./Org.sol";
import "./ProxyFactory.sol";

//ORG FACTORY CONTRACT
/**
 * @title OrgFactory
 * @author rheeger
 * @notice OrgFactory is a contract that allows the EndaomentAdmin to
 * instantiate new Org contracts. It also provides for fetching of
 * individual Org contract addresses as well as a list of all
 * allowedOrgs.
 */
contract OrgFactory is ProxyFactory, EndaomentAdminStorage {
  // ========== EVENTS===================

  event OrgCreated(address indexed newAddress);
  event OrgStatusChanged(address indexed orgAddress, bool indexed isAllowed);
  event OrgLogicDeployed(address logicAddress);

  // ========== STATE VARIABLES==========

  mapping(address => bool) public allowedOrgs;
  address public immutable orgLogic; // logic template for all Org contracts

  // ========== CONSTRUCTOR ==========
  /**
   * @notice Creates new Org Factory and emits a `EndaomentAdminChanged` event
   * @param adminContractAddress Address of EndaomentAdmin contract.
   */
  constructor(address adminContractAddress) public {
    // Set endaoment admin
    require(adminContractAddress != address(0), "OrgFactory: Admin cannot be the zero address");
    endaomentAdmin = adminContractAddress;
    emit EndaomentAdminChanged(address(0), adminContractAddress);

    // Deploy and initialize Org logic contract (used to deploy minimal proxies in createOrg)
    // We set the EIN to 999999999, since it is unlikely to be a real EIN. Even if it is a real
    // EIN, that is ok because (1) there is no check against duplicate EINs, and (2) this instance
    // is not used as anything other than a logic template, so the EIN value doesn't matter
    Org orgLogicContract = new Org();
    orgLogicContract.initializeOrg(999999999, address(this));

    // Save off address so we can reference for all future deployments
    orgLogic = address(orgLogicContract);
    emit OrgLogicDeployed(address(orgLogicContract));
  }

  // ========== Org Creation & Management ==========
  /**
   * @notice Creates new Org Contract and emits a `OrgCreated` event
   * @param ein The U.S. Tax Identification Number for the Organization
   */
  function createOrg(uint256 ein)
    public
    onlyAdminOrRole(endaomentAdmin, IEndaomentAdmin.Role.ACCOUNTANT)
  {
    require(ein >= 10000000 && ein <= 999999999, "Org: Must provide a valid EIN");
    bytes memory payload = abi.encodeWithSignature(
      "initializeOrg(uint256,address)",
      ein,
      address(this)
    );
    address newOrg = deployMinimal(orgLogic, payload);

    allowedOrgs[newOrg] = true;
    emit OrgCreated(newOrg);
  }

  /**
   * @notice Toggles whether Org is allowed and emits a `OrgStatusChanged` event
   * @param orgAddress THe address of the Org contract.
   */
  function toggleOrg(address orgAddress)
    public
    onlyAdminOrRole(endaomentAdmin, IEndaomentAdmin.Role.REVIEWER)
  {
    require(Org(orgAddress).taxId() != 0, "OrgFactory: Not a valid org.");
    allowedOrgs[orgAddress] = !allowedOrgs[orgAddress];
    emit OrgStatusChanged(orgAddress, allowedOrgs[orgAddress]);
  }
}

// SPDX-License-Identifier: BSD 3-Clause

pragma solidity ^0.6.10;

import "./Administratable.sol";

// ENDAOMENT ADMIN STORAGE CONTRACT
/**
 * @title EndaomentAdminStorage
 * @author rheeger
 * @notice Stores the contract address of the EndaomentAdmin,
 * for use in references by the Org and Fund factories and
 * subsequently deployed Org and Fund contracts.
 */
contract EndaomentAdminStorage is Administratable {
  address public endaomentAdmin;
  event EndaomentAdminChanged(address indexed oldAddress, address indexed newAddress);

  /**
   * @notice Updates address of the endaomentAdmin contract and emits `EndaomentAdminChanged` event.
   * @param newAdmin New address of the endaomentAdmin contract
   */
  function updateEndaomentAdmin(address newAdmin) public onlyAdmin(endaomentAdmin) {
    // Validate that contract has a valid admin address set
    require(newAdmin != address(0), "EndaomentAdminStorage: New admin cannot be the zero address");
    EndaomentAdmin endaomentAdminContract = EndaomentAdmin(newAdmin);

    address admin = endaomentAdminContract.getRoleAddress(IEndaomentAdmin.Role.ADMIN);
    require(admin != address(0), "EndaomentAdminStorage: Admin cannot be the zero address");

    emit EndaomentAdminChanged(endaomentAdmin, newAdmin);
    endaomentAdmin = newAdmin;
  }
}

// SPDX-License-Identifier: BSD 3-Clause

pragma solidity ^0.6.10;
pragma experimental ABIEncoderV2;

import "./Administratable.sol";
import "./interfaces/IFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";

//ORG CONTRACT
/**
 * @title Org
 * @author rheeger
 * @notice Org is a contract that serves as a smart wallet for US nonprofit
 * organizations. It holds the organization's federal Tax ID number as taxID,
 * and allows for an address to submit a Claim struct to the contract whereby
 * the organization can directly receive grant awards from Endaoment Funds.
 */
contract Org is Initializable, Administratable {
  using SafeERC20 for IERC20;

  // ========== STRUCTS & EVENTS ==========

  struct Claim {
    string firstName;
    string lastName;
    string eMail;
    address desiredWallet;
  }
  event CashOutComplete(uint256 cashOutAmount);
  event ClaimCreated(string claimId, Claim claim);
  event ClaimApproved(string claimId, Claim claim);
  event ClaimRejected(string claimId, Claim claim);

  // ========== STATE VARIABLES ==========

  IFactory public orgFactoryContract;
  uint256 public taxId;
  mapping(string => Claim) public pendingClaims; // claim UUID to Claim
  Claim public activeClaim;

  // ========== CONSTRUCTOR ==========

  /**
   * @notice Create new Organization Contract
   * @dev Using initializer instead of constructor for minimal proxy support. This function
   * can only be called once in the contract's lifetime
   * @param ein The U.S. Tax Identification Number for the Organization
   * @param orgFactory Address of the Factory contract.
   */
  function initializeOrg(uint256 ein, address orgFactory) public initializer {
    require(orgFactory != address(0), "Org: Factory cannot be null address.");
    taxId = ein;
    orgFactoryContract = IFactory(orgFactory);
  }

  // ========== Org Management & Info ==========

  /**
   * @notice Creates Organization Claim and emits a `ClaimCreated` event
   * @param  claimId UUID representing this claim
   * @param  fName First name of Administrator
   * @param  lName Last name of Administrator
   * @param  eMail Email contact for Organization Administrator.
   * @param  orgAdminWalletAddress Wallet address of Organization's Administrator.
   */
  function claimRequest(
    string calldata claimId,
    string calldata fName,
    string calldata lName,
    string calldata eMail,
    address orgAdminWalletAddress
  ) public {
    require(!isEqual(claimId, ""), "Org: Must provide claimId");
    require(!isEqual(fName, ""), "Org: Must provide the first name of the administrator");
    require(!isEqual(lName, ""), "Org: Must provide the last name of the administrator");
    require(!isEqual(eMail, ""), "Org: Must provide the email address of the administrator");
    require(orgAdminWalletAddress != address(0), "Org: Wallet address cannot be the zero address");
    require(
      pendingClaims[claimId].desiredWallet == address(0),
      "Org: Pending Claim with Id already exists"
    );

    Claim memory newClaim = Claim({
      firstName: fName,
      lastName: lName,
      eMail: eMail,
      desiredWallet: orgAdminWalletAddress
    });

    emit ClaimCreated(claimId, newClaim);
    pendingClaims[claimId] = newClaim;
  }

  /**
   * @notice Approves an Organization Claim and emits a `ClaimApproved` event
   * @param claimId UUID of the claim being approved
   */
  function approveClaim(string calldata claimId)
    public
    onlyAdminOrRole(orgFactoryContract.endaomentAdmin(), IEndaomentAdmin.Role.REVIEWER)
  {
    require(!isEqual(claimId, ""), "Fund: Must provide a claimId");
    Claim storage claim = pendingClaims[claimId];
    require(claim.desiredWallet != address(0), "Org: claim does not exist");
    emit ClaimApproved(claimId, claim);
    activeClaim = claim;
    delete pendingClaims[claimId];
  }

  /**
   * @notice Rejects an Organization Claim and emits a 'ClaimRejected` event
   * @param claimId UUID of the claim being rejected
   */
  function rejectClaim(string calldata claimId)
    public
    onlyAdminOrRole(orgFactoryContract.endaomentAdmin(), IEndaomentAdmin.Role.REVIEWER)
  {
    require(!isEqual(claimId, ""), "Fund: Must provide a claimId");
    Claim storage claim = pendingClaims[claimId];
    require(claim.desiredWallet != address(0), "Org: claim does not exist");

    emit ClaimRejected(claimId, claim);

    delete pendingClaims[claimId];
  }

  /**
   * @notice Cashes out Organization Contract and emits a `CashOutComplete` event
   * @param tokenAddress ERC20 address of desired token withdrawal
   */
  function cashOutOrg(address tokenAddress)
    public
    onlyAdminOrRole(orgFactoryContract.endaomentAdmin(), IEndaomentAdmin.Role.ACCOUNTANT)
  {
    require(tokenAddress != address(0), "Org: Token address cannot be the zero address");
    address payoutAddr = orgWallet();
    require(payoutAddr != address(0), "Org: Cannot cashout unclaimed Org");

    IERC20 tokenContract = IERC20(tokenAddress);
    uint256 cashOutAmount = tokenContract.balanceOf(address(this));

    tokenContract.safeTransfer(orgWallet(), cashOutAmount);
    emit CashOutComplete(cashOutAmount);
  }

  /**
   * @notice Retrieves Token Balance of Org Contract
   * @param tokenAddress Address of desired token to query for balance
   * @return Balance of conract in token base unit of provided tokenAddress
   */
  function getTokenBalance(address tokenAddress) external view returns (uint256) {
    IERC20 tokenContract = IERC20(tokenAddress);
    uint256 balance = tokenContract.balanceOf(address(this));

    return balance;
  }

  /**
   * @notice Org Wallet convenience accessor
   * @return The wallet specified in the active, approved claim
   */
  function orgWallet() public view returns (address) {
    return activeClaim.desiredWallet;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.7;

contract ProxyFactory {
  /**
   * @dev This function enables deployment of EIP-1167 minimal proxies. The code below
   * was copied from the OpenZeppelin ProxyFactory.sol contract, as there is currently
   * no package that has a version compatible with Solidity ^0.6.0. At the time of writing
   * copy/pasting the file in this manner is considered the best practice for ^0.6.0:
   *   https://forum.openzeppelin.com/t/best-practice-for-using-proxyfactory-sol-in-a-solidity-0-6-project-deploying-minimal-proxies/3478
   *
   * EIP-1167 references:
   *   The EIP and associated CloneFactory repo
   *     - https://eips.ethereum.org/EIPS/eip-1167
   *   Open Zeppelin blog post and discussion
   *     - https://blog.openzeppelin.com/deep-dive-into-the-minimal-proxy-contract/
   *     - https://forum.openzeppelin.com/t/deep-dive-into-the-minimal-proxy-contract/1928
   */
  function deployMinimal(address _logic, bytes memory _data) public returns (address proxy) {
    // Adapted from https://github.com/optionality/clone-factory/blob/32782f82dfc5a00d103a7e61a17a5dedbd1e8e9d/contracts/CloneFactory.sol
    bytes20 targetBytes = bytes20(_logic);
    assembly {
      let clone := mload(0x40)
      mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
      mstore(add(clone, 0x14), targetBytes)
      mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
      proxy := create(0, clone, 0x37)
    }

    if (_data.length > 0) {
      (bool success, ) = proxy.call(_data);
      require(success, "ProxyFactory: Initialization of proxy failed");
    }
  }
}

// SPDX-License-Identifier: BSD 3-Clause

pragma solidity ^0.6.10;

import "./EndaomentAdmin.sol";

//ADMINISTRATABLE
/**
 * @title Administratable
 * @author rheeger
 * @notice Provides two modifiers allowing contracts administered
 * by the EndaomentAdmin contract to properly restrict method calls
 * based on the a given role. Also provides a utility function for
 * validating string input arguments.
 */
contract Administratable {
  /**
   * @notice onlyAdmin checks that the caller is the EndaomentAdmin
   * @param adminContractAddress is the supplied EndaomentAdmin contract address
   */
  modifier onlyAdmin(address adminContractAddress) {
    require(
      adminContractAddress != address(0),
      "Administratable: Admin must not be the zero address"
    );
    EndaomentAdmin endaomentAdmin = EndaomentAdmin(adminContractAddress);

    require(
      msg.sender == endaomentAdmin.getRoleAddress(IEndaomentAdmin.Role.ADMIN),
      "Administratable: only ADMIN can access."
    );
    _;
  }

  /**
   * @notice onlyAdminOrRole checks that the caller is either the Admin or the provided role.
   * @param adminContractAddress supplied EndaomentAdmin address
   * @param role The role to require unless the caller is the owner. Permitted
   * roles are ADMIN (6), ACCOUNTANT (2), REVIEWER (3), FUND_FACTORY (4) and ORG_FACTORY(5).
   */
  modifier onlyAdminOrRole(address adminContractAddress, IEndaomentAdmin.Role role) {
    _onlyAdminOrRole(adminContractAddress, role);
    _;
  }

  /**
   * @notice _onlyAdminOrRole checks that the caller is either the Admin or the provided role.
   * @param adminContractAddress supplied EndaomentAdmin address
   * @param role The role to require unless the caller is the owner. Permitted
   * roles are ADMIN (6), ACCOUNTANT (2), REVIEWER (3), FUND_FACTORY (4) and ORG_FACTORY(5).
   */
  function _onlyAdminOrRole(address adminContractAddress, IEndaomentAdmin.Role role) private view {
    require(
      adminContractAddress != address(0),
      "Administratable: Admin must not be the zero address"
    );
    EndaomentAdmin endaomentAdmin = EndaomentAdmin(adminContractAddress);
    bool isAdmin = (msg.sender == endaomentAdmin.getRoleAddress(IEndaomentAdmin.Role.ADMIN));

    if (!isAdmin) {
      if (endaomentAdmin.isPaused(role)) {
        revert("Administratable: requested role is paused");
      }

      if (role == IEndaomentAdmin.Role.ACCOUNTANT) {
        require(
          msg.sender == endaomentAdmin.getRoleAddress(IEndaomentAdmin.Role.ACCOUNTANT),
          "Administratable: only ACCOUNTANT can access"
        );
      }
      if (role == IEndaomentAdmin.Role.REVIEWER) {
        require(
          msg.sender == endaomentAdmin.getRoleAddress(IEndaomentAdmin.Role.REVIEWER),
          "Administratable: only REVIEWER can access"
        );
      }
      if (role == IEndaomentAdmin.Role.FUND_FACTORY) {
        require(
          msg.sender == endaomentAdmin.getRoleAddress(IEndaomentAdmin.Role.FUND_FACTORY),
          "Administratable: only FUND_FACTORY can access"
        );
      }
      if (role == IEndaomentAdmin.Role.ORG_FACTORY) {
        require(
          msg.sender == endaomentAdmin.getRoleAddress(IEndaomentAdmin.Role.ORG_FACTORY),
          "Administratable: only ORG_FACTORY can access"
        );
      }
    }
  }

  /**
   * @notice Checks that the caller is either a provided address, admin or role.
   * @param allowedAddress An exempt address provided that shall be allowed to proceed.
   * @param adminContractAddress The EndaomentAdmin contract address.
   * @param role The desired IEndaomentAdmin.Role to check against. Permitted
   * roles are ADMIN (6), ACCOUNTANT (2), REVIEWER (3), FUND_FACTORY (4) and ORG_FACTORY(5).
   */
  modifier onlyAddressOrAdminOrRole(
    address allowedAddress,
    address adminContractAddress,
    IEndaomentAdmin.Role role
  ) {
    require(
      allowedAddress != address(0),
      "Administratable: Allowed address must not be the zero address"
    );

    bool isAllowed = (msg.sender == allowedAddress);

    if (!isAllowed) {
      _onlyAdminOrRole(adminContractAddress, role);
    }
    _;
  }

  /**
   * @notice Returns true if two strings are equal, false otherwise
   * @param s1 First string to compare
   * @param s2 Second string to compare
   */
  function isEqual(string memory s1, string memory s2) internal pure returns (bool) {
    return keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
  }
}

// SPDX-License-Identifier: BSD 3-Clause

pragma solidity ^0.6.10;

import "./interfaces/IEndaomentAdmin.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 *
 * In order to transfer ownership, a recipient must be specified, at which point
 * the specified recipient can call `acceptOwnership` and take ownership.
 */
contract TwoStepOwnable {
  address private _owner;
  address private _newPotentialOwner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  event TransferInitiated(address indexed newOwner);

  event TransferCancelled(address indexed newPotentialOwner);

  /**
   * @dev Initialize contract by setting transaction submitter as initial owner.
   */
  constructor() internal {
    _owner = tx.origin;
    emit OwnershipTransferred(address(0), _owner);
  }

  /**
   * @dev Returns the address of the current owner.
   */
  function getOwner() external view returns (address) {
    return _owner;
  }

  /**
   * @dev Returns the address of the current potential new owner.
   */
  function getNewPotentialOwner() external view returns (address) {
    return _newPotentialOwner;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(isOwner(), "TwoStepOwnable: caller is not the owner.");
    _;
  }

  /**
   * @dev Returns true if the caller is the current owner.
   */
  function isOwner() public view returns (bool) {
    return msg.sender == _owner;
  }

  /**
   * @dev Allows a new account (`newOwner`) to accept ownership.
   * Can only be called by the current owner.
   */
  function transferOwnership(address newPotentialOwner) public onlyOwner {
    require(
      newPotentialOwner != address(0),
      "TwoStepOwnable: new potential owner is the zero address."
    );

    _newPotentialOwner = newPotentialOwner;
    emit TransferInitiated(address(newPotentialOwner));
  }

  /**
   * @dev Cancel a transfer of ownership to a new account.
   * Can only be called by the current owner.
   */
  function cancelOwnershipTransfer() public onlyOwner {
    emit TransferCancelled(address(_newPotentialOwner));
    delete _newPotentialOwner;
  }

  /**
   * @dev Transfers ownership of the contract to the caller.
   * Can only be called by a new potential owner set by the current owner.
   */
  function acceptOwnership() public {
    require(
      msg.sender == _newPotentialOwner,
      "TwoStepOwnable: current owner must set caller as new potential owner."
    );

    delete _newPotentialOwner;

    emit OwnershipTransferred(_owner, msg.sender);

    _owner = msg.sender;
  }
}

/**
 * @title EndaomentAdmin
 * @author rheeger
 * @notice Provides admin controls for the Endaoment contract ecosystem using
 * a roles-based system. Available roles are PAUSER (1), ACCOUNTANT (2),
 * REVIEWER (3), FUND_FACTORY (4), ORG_FACTORY (5), and ADMIN (6).
 */
contract EndaomentAdmin is IEndaomentAdmin, TwoStepOwnable {
  // Maintain a role status mapping with assigned accounts and paused states.
  mapping(uint256 => RoleStatus) private _roles;

  /**
   * @notice Set a new account on a given role and emit a `RoleModified` event
   * if the role holder has changed. Only the owner may call this function.
   * @param role The role that the account will be set for.
   * @param account The account to set as the designated role bearer.
   */
  function setRole(Role role, address account) public override onlyOwner {
    require(account != address(0), "EndaomentAdmin: Must supply an account.");
    _setRole(role, account);
  }

  /**
   * @notice Remove any current role bearer for a given role and emit a
   * `RoleModified` event if a role holder was previously set. Only the owner
   * may call this function.
   * @param role The role that the account will be removed from.
   */
  function removeRole(Role role) public override onlyOwner {
    _setRole(role, address(0));
  }

  /**
   * @notice Pause a currently unpaused role and emit a `RolePaused` event. Only
   * the owner or the designated pauser may call this function. Also, bear in
   * mind that only the owner may unpause a role once paused.
   * @param role The role to pause.
   */
  function pause(Role role) public override onlyAdminOr(Role.PAUSER) {
    RoleStatus storage storedRoleStatus = _roles[uint256(role)];
    require(!storedRoleStatus.paused, "EndaomentAdmin: Role in question is already paused.");
    storedRoleStatus.paused = true;
    emit RolePaused(role);
  }

  /**
   * @notice Unpause a currently paused role and emit a `RoleUnpaused` event.
   * Only the owner may call this function.
   * @param role The role to pause.
   */
  function unpause(Role role) public override onlyOwner {
    RoleStatus storage storedRoleStatus = _roles[uint256(role)];
    require(storedRoleStatus.paused, "EndaomentAdmin: Role in question is already unpaused.");
    storedRoleStatus.paused = false;
    emit RoleUnpaused(role);
  }

  /**
   * @notice External view function to check whether or not the functionality
   * associated with a given role is currently paused or not. The owner or the
   * pauser may pause any given role (including the pauser itself), but only the
   * owner may unpause functionality. Additionally, the owner may call paused
   * functions directly.
   * @param role The role to check the pause status on.
   * @return A boolean to indicate if the functionality associated with
   * the role in question is currently paused.
   */
  function isPaused(Role role) external override view returns (bool) {
    return _isPaused(role);
  }

  /**
   * @notice External view function to check whether the caller is the current
   * role holder.
   * @param role The role to check for.
   * @return A boolean indicating if the caller has the specified role.
   */
  function isRole(Role role) external override view returns (bool) {
    return _isRole(role);
  }

  /**
   * @notice External view function to check the account currently holding the
   * given role.
   * @param role The desired role to fetch the current address of.
   * @return The address of the requested role, or the null
   * address if none is set.
   */
  function getRoleAddress(Role role) external override view returns (address) {
    require(
      _roles[uint256(role)].account != address(0),
      "EndaomentAdmin: Role bearer is null address."
    );
    return _roles[uint256(role)].account;
  }

  /**
   * @notice Private function to set a new account on a given role and emit a
   * `RoleModified` event if the role holder has changed.
   * @param role The role that the account will be set for.
   * @param account The account to set as the designated role bearer.
   */
  function _setRole(Role role, address account) private {
    RoleStatus storage storedRoleStatus = _roles[uint256(role)];

    if (account != storedRoleStatus.account) {
      storedRoleStatus.account = account;
      emit RoleModified(role, account);
    }
  }

  /**
   * @notice Private view function to check whether the caller is the current
   * role holder.
   * @param role The role to check for.
   * @return A boolean indicating if the caller has the specified role.
   */
  function _isRole(Role role) private view returns (bool) {
    return msg.sender == _roles[uint256(role)].account;
  }

  /**
   * @notice Private view function to check whether the given role is paused or
   * not.
   * @param role The role to check for.
   * @return A boolean indicating if the specified role is paused or not.
   */
  function _isPaused(Role role) private view returns (bool) {
    return _roles[uint256(role)].paused;
  }

  /**
   * @notice Modifier that throws if called by any account other than the owner
   * or the supplied role, or if the caller is not the owner and the role in
   * question is paused.
   * @param role The role to require unless the caller is the owner.
   */
  modifier onlyAdminOr(Role role) {
    if (!isOwner()) {
      require(_isRole(role), "EndaomentAdmin: Caller does not have a required role.");
      require(!_isPaused(role), "EndaomentAdmin: Role in question is currently paused.");
    }
    _;
  }
}

// SPDX-License-Identifier: BSD 3-Clause

pragma solidity ^0.6.10;

/**
 * @dev Interface of the EndaomentAdmin contract
 */
interface IEndaomentAdmin {
  event RoleModified(Role indexed role, address account);
  event RolePaused(Role indexed role);
  event RoleUnpaused(Role indexed role);

  enum Role {
    EMPTY,
    PAUSER,
    ACCOUNTANT,
    REVIEWER,
    FUND_FACTORY,
    ORG_FACTORY,
    ADMIN
  }

  struct RoleStatus {
    address account;
    bool paused;
  }

  function setRole(Role role, address account) external;

  function removeRole(Role role) external;

  function pause(Role role) external;

  function unpause(Role role) external;

  function isPaused(Role role) external view returns (bool);

  function isRole(Role role) external view returns (bool);

  function getRoleAddress(Role role) external view returns (address);
}

// SPDX-License-Identifier: BSD 3-Clause

pragma solidity ^0.6.10;

interface IFactory {
  function endaomentAdmin() external view returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

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

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

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
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
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

pragma solidity >=0.4.24 <0.7.0;


/**
 * @title Initializable
 *
 * @dev Helper contract to support initializer functions. To use it, replace
 * the constructor with a function that has the `initializer` modifier.
 * WARNING: Unlike constructors, initializer functions must be manually
 * invoked. This applies both to deploying an Initializable contract, as well
 * as extending an Initializable contract via inheritance.
 * WARNING: When used with inheritance, manual care must be taken to not invoke
 * a parent initializer twice, or ensure that all initializers are idempotent,
 * because this is not dealt with automatically as with constructors.
 */
contract Initializable {

  /**
   * @dev Indicates that the contract has been initialized.
   */
  bool private initialized;

  /**
   * @dev Indicates that the contract is in the process of being initialized.
   */
  bool private initializing;

  /**
   * @dev Modifier to use in the initializer function of a contract.
   */
  modifier initializer() {
    require(initializing || isConstructor() || !initialized, "Contract instance has already been initialized");

    bool isTopLevelCall = !initializing;
    if (isTopLevelCall) {
      initializing = true;
      initialized = true;
    }

    _;

    if (isTopLevelCall) {
      initializing = false;
    }
  }

  /// @dev Returns true if and only if the function is running in the constructor
  function isConstructor() private view returns (bool) {
    // extcodesize checks the size of the code stored in an address, and
    // address returns the current address. Since the code is still not
    // deployed when running a constructor, any checks on its code size will
    // yield zero, making it an effective way to detect if a contract is
    // under construction or not.
    address self = address(this);
    uint256 cs;
    assembly { cs := extcodesize(self) }
    return cs == 0;
  }

  // Reserved storage space to allow for layout changes in the future.
  uint256[50] private ______gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

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
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}
