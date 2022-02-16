
// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { LibDiamondCut } from "./diamond/LibDiamondCut.sol";
import { DiamondFacet } from "./diamond/DiamondFacet.sol";
import { OwnershipFacet } from "./diamond/OwnershipFacet.sol";
import { LibDiamondStorage } from "./diamond/LibDiamondStorage.sol";
import { IDiamondCut } from "./diamond/IDiamondCut.sol";
import { IDiamondLoupe } from "./diamond/IDiamondLoupe.sol";
import { IERC165 } from "./diamond/IERC165.sol";
import { LibDiamondStorageDerivaDEX } from "./storage/LibDiamondStorageDerivaDEX.sol";
import { IDDX } from "./tokens/interfaces/IDDX.sol";

/**
 * @title DerivaDEX
 * @author DerivaDEX
 * @notice This is the diamond for DerivaDEX. All current
 *         and future logic runs by way of this contract.
 * @dev This diamond implements the Diamond Standard (EIP #2535).
 */
contract DerivaDEX {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @notice This constructor initializes the upgrade machinery (as
     *         per the Diamond Standard), sets the admin of the proxy
     *         to be the deploying address (very temporary), and sets
     *         the native DDX governance/operational token.
     * @param _ddxToken The native DDX token address.
     */
    constructor(IDDX _ddxToken) public {
        LibDiamondStorage.DiamondStorage storage ds = LibDiamondStorage.diamondStorage();
        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();

        // Temporarily set admin to the deploying address to facilitate
        // adding the Diamond functions
        dsDerivaDEX.admin = msg.sender;

        // Set DDX token address for token logic in facet contracts
        require(address(_ddxToken) != address(0), "DerivaDEX: ddx token is zero address.");
        dsDerivaDEX.ddxToken = _ddxToken;

        emit OwnershipTransferred(address(0), msg.sender);

        // Create DiamondFacet contract -
        // implements DiamondCut interface and DiamondLoupe interface
        DiamondFacet diamondFacet = new DiamondFacet();

        // Create OwnershipFacet contract which implements ownership
        // functions and supportsInterface function
        OwnershipFacet ownershipFacet = new OwnershipFacet();

        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](2);

        // adding diamondCut function and diamond loupe functions
        diamondCut[0].facetAddress = address(diamondFacet);
        diamondCut[0].action = IDiamondCut.FacetCutAction.Add;
        diamondCut[0].functionSelectors = new bytes4[](6);
        diamondCut[0].functionSelectors[0] = DiamondFacet.diamondCut.selector;
        diamondCut[0].functionSelectors[1] = DiamondFacet.facetFunctionSelectors.selector;
        diamondCut[0].functionSelectors[2] = DiamondFacet.facets.selector;
        diamondCut[0].functionSelectors[3] = DiamondFacet.facetAddress.selector;
        diamondCut[0].functionSelectors[4] = DiamondFacet.facetAddresses.selector;
        diamondCut[0].functionSelectors[5] = DiamondFacet.supportsInterface.selector;

        // adding ownership functions
        diamondCut[1].facetAddress = address(ownershipFacet);
        diamondCut[1].action = IDiamondCut.FacetCutAction.Add;
        diamondCut[1].functionSelectors = new bytes4[](2);
        diamondCut[1].functionSelectors[0] = OwnershipFacet.transferOwnershipToSelf.selector;
        diamondCut[1].functionSelectors[1] = OwnershipFacet.getAdmin.selector;

        // execute internal diamondCut function to add functions
        LibDiamondCut.diamondCut(diamondCut, address(0), new bytes(0));

        // adding ERC165 data
        ds.supportedInterfaces[IERC165.supportsInterface.selector] = true;
        ds.supportedInterfaces[IDiamondCut.diamondCut.selector] = true;
        bytes4 interfaceID =
            IDiamondLoupe.facets.selector ^
                IDiamondLoupe.facetFunctionSelectors.selector ^
                IDiamondLoupe.facetAddresses.selector ^
                IDiamondLoupe.facetAddress.selector;
        ds.supportedInterfaces[interfaceID] = true;
    }

    // TODO(jalextowle): Remove this linter directive when
    // https://github.com/protofire/solhint/issues/248 is merged and released.
    /* solhint-disable ordering */
    receive() external payable {
        revert("DerivaDEX does not directly accept ether.");
    }

    // Finds facet for function that is called and executes the
    // function if it is found and returns any value.
    fallback() external payable {
        LibDiamondStorage.DiamondStorage storage ds;
        bytes32 position = LibDiamondStorage.DIAMOND_STORAGE_POSITION;
        assembly {
            ds_slot := position
        }
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Function does not exist.");
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(0, 0, size)
            switch result
                case 0 {
                    revert(0, size)
                }
                default {
                    return(0, size)
                }
        }
    }
    /* solhint-enable ordering */
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
*
* Implementation of internal diamondCut function.
/******************************************************************************/

import "./LibDiamondStorage.sol";
import "./IDiamondCut.sol";

library LibDiamondCut {
    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    // Internal function version of diamondCut
    // This code is almost the same as the external diamondCut,
    // except it is using 'FacetCut[] memory _diamondCut' instead of
    // 'FacetCut[] calldata _diamondCut'.
    // The code is duplicated to prevent copying calldata to memory which
    // causes an error for a two dimensional array.
    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        require(_diamondCut.length > 0, "LibDiamondCut: No facets to cut");
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            addReplaceRemoveFacetSelectors(
                _diamondCut[facetIndex].facetAddress,
                _diamondCut[facetIndex].action,
                _diamondCut[facetIndex].functionSelectors
            );
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addReplaceRemoveFacetSelectors(
        address _newFacetAddress,
        IDiamondCut.FacetCutAction _action,
        bytes4[] memory _selectors
    ) internal {
        LibDiamondStorage.DiamondStorage storage ds = LibDiamondStorage.diamondStorage();
        require(_selectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        // add or replace functions
        if (_newFacetAddress != address(0)) {
            uint256 facetAddressPosition = ds.facetFunctionSelectors[_newFacetAddress].facetAddressPosition;
            // add new facet address if it does not exist
            if (
                facetAddressPosition == 0 && ds.facetFunctionSelectors[_newFacetAddress].functionSelectors.length == 0
            ) {
                ensureHasContractCode(_newFacetAddress, "LibDiamondCut: New facet has no code");
                facetAddressPosition = ds.facetAddresses.length;
                ds.facetAddresses.push(_newFacetAddress);
                ds.facetFunctionSelectors[_newFacetAddress].facetAddressPosition = uint16(facetAddressPosition);
            }
            // add or replace selectors
            for (uint256 selectorIndex; selectorIndex < _selectors.length; selectorIndex++) {
                bytes4 selector = _selectors[selectorIndex];
                address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
                // add
                if (_action == IDiamondCut.FacetCutAction.Add) {
                    require(oldFacetAddress == address(0), "LibDiamondCut: Can't add function that already exists");
                    addSelector(_newFacetAddress, selector);
                } else if (_action == IDiamondCut.FacetCutAction.Replace) {
                    // replace
                    require(
                        oldFacetAddress != _newFacetAddress,
                        "LibDiamondCut: Can't replace function with same function"
                    );
                    removeSelector(oldFacetAddress, selector);
                    addSelector(_newFacetAddress, selector);
                } else {
                    revert("LibDiamondCut: Incorrect FacetCutAction");
                }
            }
        } else {
            require(
                _action == IDiamondCut.FacetCutAction.Remove,
                "LibDiamondCut: action not set to FacetCutAction.Remove"
            );
            // remove selectors
            for (uint256 selectorIndex; selectorIndex < _selectors.length; selectorIndex++) {
                bytes4 selector = _selectors[selectorIndex];
                removeSelector(ds.selectorToFacetAndPosition[selector].facetAddress, selector);
            }
        }
    }

    function addSelector(address _newFacet, bytes4 _selector) internal {
        LibDiamondStorage.DiamondStorage storage ds = LibDiamondStorage.diamondStorage();
        uint256 selectorPosition = ds.facetFunctionSelectors[_newFacet].functionSelectors.length;
        ds.facetFunctionSelectors[_newFacet].functionSelectors.push(_selector);
        ds.selectorToFacetAndPosition[_selector].facetAddress = _newFacet;
        ds.selectorToFacetAndPosition[_selector].functionSelectorPosition = uint16(selectorPosition);
    }

    function removeSelector(address _oldFacetAddress, bytes4 _selector) internal {
        LibDiamondStorage.DiamondStorage storage ds = LibDiamondStorage.diamondStorage();
        require(_oldFacetAddress != address(0), "LibDiamondCut: Can't remove or replace function that doesn't exist");
        // replace selector with last selector, then delete last selector
        uint256 selectorPosition = ds.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = ds.facetFunctionSelectors[_oldFacetAddress].functionSelectors.length - 1;
        bytes4 lastSelector = ds.facetFunctionSelectors[_oldFacetAddress].functionSelectors[lastSelectorPosition];
        // if not the same then replace _selector with lastSelector
        if (lastSelector != _selector) {
            ds.facetFunctionSelectors[_oldFacetAddress].functionSelectors[selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint16(selectorPosition);
        }
        // delete the last selector
        ds.facetFunctionSelectors[_oldFacetAddress].functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[_selector];

        // if no more selectors for facet address then delete the facet address
        if (lastSelectorPosition == 0) {
            // replace facet address with last facet address and delete last facet address
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            address lastFacetAddress = ds.facetAddresses[lastFacetAddressPosition];
            uint256 facetAddressPosition = ds.facetFunctionSelectors[_oldFacetAddress].facetAddressPosition;
            if (_oldFacetAddress != lastFacetAddress) {
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = uint16(facetAddressPosition);
            }
            ds.facetAddresses.pop();
            delete ds.facetFunctionSelectors[_oldFacetAddress];
        }
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            require(_calldata.length == 0, "LibDiamondCut: _init is address(0) but_calldata is not empty");
        } else {
            require(_calldata.length > 0, "LibDiamondCut: _calldata is empty but _init is not address(0)");
            if (_init != address(this)) {
                LibDiamondCut.ensureHasContractCode(_init, "LibDiamondCut: _init address has no code");
            }
            (bool success, bytes memory error) = _init.delegatecall(_calldata);
            if (!success) {
                if (error.length > 0) {
                    // bubble up the error
                    revert(string(error));
                } else {
                    revert("LibDiamondCut: _init function reverted");
                }
            }
        }
    }

    function ensureHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize > 0, _errorMessage);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
*
* Implementation of diamondCut external function and DiamondLoupe interface.
/******************************************************************************/

import "./LibDiamondStorage.sol";
import "./LibDiamondCut.sol";
import "../storage/LibDiamondStorageDerivaDEX.sol";
import "./IDiamondCut.sol";
import "./IDiamondLoupe.sol";
import "./IERC165.sol";

contract DiamondFacet is IDiamondCut, IDiamondLoupe, IERC165 {
    // Standard diamondCut external function
    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {
        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();
        require(msg.sender == dsDerivaDEX.admin, "DiamondFacet: Must own the contract");
        require(_diamondCut.length > 0, "DiamondFacet: No facets to cut");
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            LibDiamondCut.addReplaceRemoveFacetSelectors(
                _diamondCut[facetIndex].facetAddress,
                _diamondCut[facetIndex].action,
                _diamondCut[facetIndex].functionSelectors
            );
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        LibDiamondCut.initializeDiamondCut(_init, _calldata);
    }

    // Diamond Loupe Functions
    ////////////////////////////////////////////////////////////////////
    /// These functions are expected to be called frequently by tools.
    //
    // struct Facet {
    //     address facetAddress;
    //     bytes4[] functionSelectors;
    // }
    //
    /// @notice Gets all facets and their selectors.
    /// @return facets_ Facet
    function facets() external view override returns (Facet[] memory facets_) {
        LibDiamondStorage.DiamondStorage storage ds = LibDiamondStorage.diamondStorage();
        uint256 numFacets = ds.facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i; i < numFacets; i++) {
            address facetAddress_ = ds.facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = ds.facetFunctionSelectors[facetAddress_].functionSelectors;
        }
    }

    /// @notice Gets all the function selectors provided by a facet.
    /// @param _facet The facet address.
    /// @return facetFunctionSelectors_
    function facetFunctionSelectors(address _facet)
        external
        view
        override
        returns (bytes4[] memory facetFunctionSelectors_)
    {
        LibDiamondStorage.DiamondStorage storage ds = LibDiamondStorage.diamondStorage();
        facetFunctionSelectors_ = ds.facetFunctionSelectors[_facet].functionSelectors;
    }

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses() external view override returns (address[] memory facetAddresses_) {
        LibDiamondStorage.DiamondStorage storage ds = LibDiamondStorage.diamondStorage();
        facetAddresses_ = ds.facetAddresses;
    }

    /// @notice Gets the facet that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(bytes4 _functionSelector) external view override returns (address facetAddress_) {
        LibDiamondStorage.DiamondStorage storage ds = LibDiamondStorage.diamondStorage();
        facetAddress_ = ds.selectorToFacetAndPosition[_functionSelector].facetAddress;
    }

    // This implements ERC-165.
    function supportsInterface(bytes4 _interfaceId) external view override returns (bool) {
        LibDiamondStorage.DiamondStorage storage ds = LibDiamondStorage.diamondStorage();
        return ds.supportedInterfaces[_interfaceId];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import { LibDiamondStorageDerivaDEX } from "../storage/LibDiamondStorageDerivaDEX.sol";
import { LibDiamondStorage } from "../diamond/LibDiamondStorage.sol";
import { IERC165 } from "./IERC165.sol";

contract OwnershipFacet {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @notice This function transfers ownership to self. This is done
     *         so that we can ensure upgrades (using diamondCut) and
     *         various other critical parameter changing scenarios
     *         can only be done via governance (a facet).
     */
    function transferOwnershipToSelf() external {
        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();
        require(msg.sender == dsDerivaDEX.admin, "Not authorized");
        dsDerivaDEX.admin = address(this);

        emit OwnershipTransferred(msg.sender, address(this));
    }

    /**
     * @notice This gets the admin for the diamond.
     * @return Admin address.
     */
    function getAdmin() external view returns (address) {
        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();
        return dsDerivaDEX.admin;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
/******************************************************************************/

library LibDiamondStorage {
    struct FacetAddressAndPosition {
        address facetAddress;
        uint16 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint16 facetAddressPosition; // position of facetAddress in facetAddresses array
    }

    struct DiamondStorage {
        // maps function selector to the facet address and
        // the position of the facet address in the facetAddresses array
        // and the position of the selector in the facetSelectors.selectors array
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // maps facet addresses to function selectors
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        // facet addresses
        address[] facetAddresses;
        // Used to query if a contract implements an interface.
        // Used to implement ERC-165.
        mapping(bytes4 => bool) supportedInterfaces;
    }

    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds_slot := position
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
/******************************************************************************/

interface IDiamondCut {
    enum FacetCutAction { Add, Replace, Remove }

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
/******************************************************************************/

import "./IDiamondCut.sol";

// A loupe is a small magnifying glass used to look at diamonds.
// These functions look at diamonds
interface IDiamondLoupe {
    /// These functions are expected to be called frequently
    /// by tools.

    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Gets all facet addresses and their four byte function selectors.
    /// @return facets_ Facet
    function facets() external view returns (Facet[] memory facets_);

    /// @notice Gets all the function selectors supported by a specific facet.
    /// @param _facet The facet address.
    /// @return facetFunctionSelectors_
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_);

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses() external view returns (address[] memory facetAddresses_);

    /// @notice Gets the facet that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface IERC165 {
    /// @notice Query if a contract implements an interface
    /// @param interfaceId The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    ///  uses less than 30,000 gas.
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { IDDX } from "../tokens/interfaces/IDDX.sol";

library LibDiamondStorageDerivaDEX {
    struct DiamondStorageDerivaDEX {
        string name;
        address admin;
        IDDX ddxToken;
    }

    bytes32 constant DIAMOND_STORAGE_POSITION_DERIVADEX =
        keccak256("diamond.standard.diamond.storage.DerivaDEX.DerivaDEX");

    function diamondStorageDerivaDEX() internal pure returns (DiamondStorageDerivaDEX storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION_DERIVADEX;
        assembly {
            ds_slot := position
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface IDDX {
    function transfer(address _recipient, uint256 _amount) external returns (bool);

    function mint(address _recipient, uint256 _amount) external;

    function delegate(address _delegatee) external;

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external returns (bool);

    function approve(address _spender, uint256 _amount) external returns (bool);

    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);

    function totalSupply() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { IDDX } from "./interfaces/IDDX.sol";

/**
 * @title DDXWalletCloneable
 * @author DerivaDEX
 * @notice This is a cloneable on-chain DDX wallet that holds a trader's
 *         stakes and issued rewards.
 */
contract DDXWalletCloneable {
    // Whether contract has already been initialized once before
    bool initialized;

    /**
     * @notice This function initializes the on-chain DDX wallet
     *         for a given trader.
     * @param _trader Trader address.
     * @param _ddxToken DDX token address.
     * @param _derivaDEX DerivaDEX Proxy address.
     */
    function initialize(
        address _trader,
        IDDX _ddxToken,
        address _derivaDEX
    ) external {
        // Prevent initializing more than once
        require(!initialized, "DDXWalletCloneable: already init.");
        initialized = true;

        // Automatically delegate the holdings of this contract/wallet
        // back to the trader.
        _ddxToken.delegate(_trader);

        // Approve the DerivaDEX Proxy contract for unlimited transfers
        _ddxToken.approve(_derivaDEX, uint96(-1));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { SafeMath } from "openzeppelin-solidity/contracts/math/SafeMath.sol";
import { IERC20 } from "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";
import { SafeMath96 } from "../../libs/SafeMath96.sol";
import { TraderDefs } from "../../libs/defs/TraderDefs.sol";
import { LibDiamondStorageDerivaDEX } from "../../storage/LibDiamondStorageDerivaDEX.sol";
import { LibDiamondStorageTrader } from "../../storage/LibDiamondStorageTrader.sol";
import { DDXWalletCloneable } from "../../tokens/DDXWalletCloneable.sol";
import { IDDX } from "../../tokens/interfaces/IDDX.sol";
import { IDDXWalletCloneable } from "../../tokens/interfaces/IDDXWalletCloneable.sol";
import { LibTraderInternal } from "./LibTraderInternal.sol";

/**
 * @title Trader
 * @author DerivaDEX
 * @notice This is a facet to the DerivaDEX proxy contract that handles
 *         the logic pertaining to traders - staking DDX, withdrawing
 *         DDX, receiving DDX rewards, etc.
 */
contract Trader {
    using SafeMath96 for uint96;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event RewardCliffSet(bool rewardCliffSet);

    event DDXRewardIssued(address trader, uint96 amount);

    /**
     * @notice Limits functions to only be called via governance.
     */
    modifier onlyAdmin {
        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();
        require(msg.sender == dsDerivaDEX.admin, "Trader: must be called by Gov.");
        _;
    }

    /**
     * @notice Limits functions to only be called post reward cliff.
     */
    modifier postRewardCliff {
        LibDiamondStorageTrader.DiamondStorageTrader storage dsTrader = LibDiamondStorageTrader.diamondStorageTrader();
        require(dsTrader.rewardCliff, "Trader: prior to reward cliff.");
        _;
    }

    /**
     * @notice This function initializes the state with some critical
     *         information, including the on-chain wallet cloneable
     *         contract address. This can only be called via governance.
     * @dev This function is best called as a parameter to the
     *      diamond cut function. This is removed prior to the selectors
     *      being added to the diamond, meaning it cannot be called
     *      again.
     * @dev This function is best called as a parameter to the
     *      diamond cut function. This is removed prior to the selectors
     *      being added to the diamond, meaning it cannot be called
     *      again.
     */
    function initialize(IDDXWalletCloneable _ddxWalletCloneable) external onlyAdmin {
        LibDiamondStorageTrader.DiamondStorageTrader storage dsTrader = LibDiamondStorageTrader.diamondStorageTrader();

        // Set the on-chain DDX wallet cloneable contract address
        dsTrader.ddxWalletCloneable = _ddxWalletCloneable;
    }

    /**
     * @notice This function sets the reward cliff.
     * @param _rewardCliff Reward cliff.
     */
    function setRewardCliff(bool _rewardCliff) external onlyAdmin {
        LibDiamondStorageTrader.DiamondStorageTrader storage dsTrader = LibDiamondStorageTrader.diamondStorageTrader();

        // Set the reward cliff (boolean value)
        dsTrader.rewardCliff = _rewardCliff;

        emit RewardCliffSet(_rewardCliff);
    }

    /**
     * @notice This function issues DDX rewards to a trader. It can
     *         only be called via governance.
     * @param _amount DDX tokens to be rewarded.
     * @param _trader Trader recipient address.
     */
    function issueDDXReward(uint96 _amount, address _trader) external onlyAdmin {
        // Call the internal function to issue DDX rewards. This
        // internal function is shareable with other facets that import
        // the LibTraderInternal library.
        LibTraderInternal.issueDDXReward(_amount, _trader);
    }

    /**
     * @notice This function issues DDX rewards to an external address.
     *         It can only be called via governance.
     * @param _amount DDX tokens to be rewarded.
     * @param _recipient External recipient address.
     */
    function issueDDXToRecipient(uint96 _amount, address _recipient) external onlyAdmin {
        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();

        // Transfer DDX from trader to trader's on-chain wallet
        dsDerivaDEX.ddxToken.mint(_recipient, _amount);

        emit DDXRewardIssued(_recipient, _amount);
    }

    /**
     * @notice This function lets traders take DDX from their wallet
     *         into their on-chain DDX wallet. It's important to note
     *         that any DDX staked from the trader to this wallet
     *         delegates the voting rights of that stake back to the
     *         user. To be more explicit, if Alice's personal wallet is
     *         delegating to Bob, and she now stakes a portion of her
     *         DDX into this on-chain DDX wallet of hers, those tokens
     *         will now count towards her voting power, not Bob's, since
     *         her on-chain wallet is automatically delegating back to
     *         her.
     * @param _amount The DDX tokens to be staked.
     */
    function stakeDDXFromTrader(uint96 _amount) external {
        transferDDXToWallet(msg.sender, _amount);
    }

    /**
     * @notice This function lets traders send DDX from their wallet
     *         into another trader's on-chain DDX wallet. It's
     *         important to note that any DDX staked to this wallet
     *         delegates the voting rights of that stake back to the
     *         user.
     * @param _trader Trader address to receive DDX (inside their
     *        wallet, which will be created if it does not already
     *        exist).
     * @param _amount The DDX tokens to be staked.
     */
    function sendDDXFromTraderToTraderWallet(address _trader, uint96 _amount) external {
        transferDDXToWallet(_trader, _amount);
    }

    /**
     * @notice This function lets traders withdraw DDX from their
     *         on-chain DDX wallet to their personal wallet. It's
     *         important to note that the voting rights for any DDX
     *         withdrawn are returned back to the delegatee of the
     *         user's personal wallet. To be more explicit, if Alice is
     *         personal wallet is delegating to Bob, and she now
     *         withdraws a portion of her DDX from this on-chain DDX
     *         wallet of hers, those tokens will now count towards Bob's
     *         voting power, not her's, since her on-chain wallet is
     *         automatically delegating back to her, but her personal
     *         wallet is delegating to Bob. Withdrawals can only happen
     *         when the governance cliff is lifted.
     * @param _amount The DDX tokens to be withdrawn.
     */
    function withdrawDDXToTrader(uint96 _amount) external postRewardCliff {
        LibDiamondStorageTrader.DiamondStorageTrader storage dsTrader = LibDiamondStorageTrader.diamondStorageTrader();

        TraderDefs.Trader storage trader = dsTrader.traders[msg.sender];

        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();

        // Subtract trader's DDX balance in the contract
        trader.ddxBalance = trader.ddxBalance.sub96(_amount);

        // Transfer DDX from trader's on-chain wallet to the trader
        dsDerivaDEX.ddxToken.transferFrom(trader.ddxWalletContract, msg.sender, _amount);
    }

    /**
     * @notice This function gets the attributes for a given trader.
     * @param _trader Trader address.
     */
    function getTrader(address _trader) external view returns (TraderDefs.Trader memory) {
        LibDiamondStorageTrader.DiamondStorageTrader storage dsTrader = LibDiamondStorageTrader.diamondStorageTrader();

        return dsTrader.traders[_trader];
    }

    /**
     * @notice This function transfers DDX from the sender
     *         to another trader's DDX wallet.
     * @param _trader Trader address' DDX wallet address to transfer
     *        into.
     * @param _amount Amount of DDX to transfer.
     */
    function transferDDXToWallet(address _trader, uint96 _amount) internal {
        LibDiamondStorageTrader.DiamondStorageTrader storage dsTrader = LibDiamondStorageTrader.diamondStorageTrader();

        TraderDefs.Trader storage trader = dsTrader.traders[_trader];

        // If trader does not have a DDX on-chain wallet yet, create one
        if (trader.ddxWalletContract == address(0)) {
            LibTraderInternal.createDDXWallet(_trader);
        }

        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();

        // Add trader's DDX balance in the contract
        trader.ddxBalance = trader.ddxBalance.add96(_amount);

        // Transfer DDX from trader to trader's on-chain wallet
        dsDerivaDEX.ddxToken.transferFrom(msg.sender, trader.ddxWalletContract, _amount);
    }
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
     *
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
     *
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
     *
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
     *
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
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
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
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

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
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
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

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
library SafeMath96 {
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
    function add96(uint96 a, uint96 b) internal pure returns (uint96) {
        uint96 c = a + b;
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
     *
     * - Subtraction cannot overflow.
     */
    function sub96(uint96 a, uint96 b) internal pure returns (uint96) {
        return sub96(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub96(
        uint96 a,
        uint96 b,
        string memory errorMessage
    ) internal pure returns (uint96) {
        require(b <= a, errorMessage);
        uint96 c = a - b;

        return c;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/**
 * @title TraderDefs
 * @author DerivaDEX
 *
 * This library contains the common structs and enums pertaining to
 * traders.
 */
library TraderDefs {
    // Consists of trader attributes, including the DDX balance and
    // the onchain DDX wallet contract address
    struct Trader {
        uint96 ddxBalance;
        address ddxWalletContract;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { TraderDefs } from "../libs/defs/TraderDefs.sol";
import { IDDXWalletCloneable } from "../tokens/interfaces/IDDXWalletCloneable.sol";

library LibDiamondStorageTrader {
    struct DiamondStorageTrader {
        mapping(address => TraderDefs.Trader) traders;
        bool rewardCliff;
        IDDXWalletCloneable ddxWalletCloneable;
    }

    bytes32 constant DIAMOND_STORAGE_POSITION_TRADER = keccak256("diamond.standard.diamond.storage.DerivaDEX.Trader");

    function diamondStorageTrader() internal pure returns (DiamondStorageTrader storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION_TRADER;
        assembly {
            ds_slot := position
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import { IDDX } from "./IDDX.sol";

interface IDDXWalletCloneable {
    function initialize(
        address _trader,
        IDDX _ddxToken,
        address _derivaDEX
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { SafeMath } from "openzeppelin-solidity/contracts/math/SafeMath.sol";
import { IERC20 } from "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";
import { LibClone } from "../../libs/LibClone.sol";
import { SafeMath96 } from "../../libs/SafeMath96.sol";
import { TraderDefs } from "../../libs/defs/TraderDefs.sol";
import { LibDiamondStorageDerivaDEX } from "../../storage/LibDiamondStorageDerivaDEX.sol";
import { LibDiamondStorageTrader } from "../../storage/LibDiamondStorageTrader.sol";
import { IDDX } from "../../tokens/interfaces/IDDX.sol";
import { IDDXWalletCloneable } from "../../tokens/interfaces/IDDXWalletCloneable.sol";

/**
 * @title TraderInternalLib
 * @author DerivaDEX
 * @notice This is a library of internal functions mainly defined in
 *         the Trader facet, but used in other facets.
 */
library LibTraderInternal {
    using SafeMath96 for uint96;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event DDXRewardIssued(address trader, uint96 amount);

    /**
     * @notice This function creates a new DDX wallet for a trader.
     * @param _trader Trader address.
     */
    function createDDXWallet(address _trader) internal {
        LibDiamondStorageTrader.DiamondStorageTrader storage dsTrader = LibDiamondStorageTrader.diamondStorageTrader();

        // Leveraging the minimal proxy contract/clone factory pattern
        // as described here (https://eips.ethereum.org/EIPS/eip-1167)
        IDDXWalletCloneable ddxWallet = IDDXWalletCloneable(LibClone.createClone(address(dsTrader.ddxWalletCloneable)));

        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();

        // Cloneable contracts have no constructor, so instead we use
        // an initialize function. This initialize delegates this
        // on-chain DDX wallet back to the trader and sets the allowance
        // for the DerivaDEX Proxy contract to be unlimited.
        ddxWallet.initialize(_trader, dsDerivaDEX.ddxToken, address(this));

        // Store the on-chain wallet address in the trader's storage
        dsTrader.traders[_trader].ddxWalletContract = address(ddxWallet);
    }

    /**
     * @notice This function issues DDX rewards to a trader. It can be
     *         called by any facet part of the diamond.
     * @param _amount DDX tokens to be rewarded.
     * @param _trader Trader address.
     */
    function issueDDXReward(uint96 _amount, address _trader) internal {
        LibDiamondStorageTrader.DiamondStorageTrader storage dsTrader = LibDiamondStorageTrader.diamondStorageTrader();

        TraderDefs.Trader storage trader = dsTrader.traders[_trader];

        // If trader does not have a DDX on-chain wallet yet, create one
        if (trader.ddxWalletContract == address(0)) {
            createDDXWallet(_trader);
        }

        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();

        // Add trader's DDX balance in the contract
        trader.ddxBalance = trader.ddxBalance.add96(_amount);

        // Transfer DDX from trader to trader's on-chain wallet
        dsDerivaDEX.ddxToken.mint(trader.ddxWalletContract, _amount);

        emit DDXRewardIssued(_trader, _amount);
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
        // This method relies in extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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
pragma solidity 0.6.12;

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

library LibClone {
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
            result := and(eq(mload(clone), mload(other)), eq(mload(add(clone, 0xd)), mload(add(other, 0xd))))
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { SafeMath } from "openzeppelin-solidity/contracts/math/SafeMath.sol";
import { Math } from "openzeppelin-solidity/contracts/math/Math.sol";
import { IERC20 } from "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";
import { SafeMath32 } from "../../libs/SafeMath32.sol";
import { SafeMath96 } from "../../libs/SafeMath96.sol";
import { MathHelpers } from "../../libs/MathHelpers.sol";
import { InsuranceFundDefs } from "../../libs/defs/InsuranceFundDefs.sol";
import { LibDiamondStorageDerivaDEX } from "../../storage/LibDiamondStorageDerivaDEX.sol";
import { LibDiamondStorageInsuranceFund } from "../../storage/LibDiamondStorageInsuranceFund.sol";
import { LibDiamondStorageTrader } from "../../storage/LibDiamondStorageTrader.sol";
import { LibDiamondStoragePause } from "../../storage/LibDiamondStoragePause.sol";
import { IDDX } from "../../tokens/interfaces/IDDX.sol";
import { LibTraderInternal } from "../trader/LibTraderInternal.sol";
import { IAToken } from "../interfaces/IAToken.sol";
import { IComptroller } from "../interfaces/IComptroller.sol";
import { ICToken } from "../interfaces/ICToken.sol";
import { IDIFundToken } from "../../tokens/interfaces/IDIFundToken.sol";
import { IDIFundTokenFactory } from "../../tokens/interfaces/IDIFundTokenFactory.sol";

interface IERCCustom {
    function decimals() external view returns (uint8);
}

/**
 * @title InsuranceFund
 * @author DerivaDEX
 * @notice This is a facet to the DerivaDEX proxy contract that handles
 *         the logic pertaining to insurance mining - staking directly
 *         into the insurance fund and receiving a DDX issuance to be
 *         used in governance/operations.
 * @dev This facet at the moment only handles insurance mining. It can
 *      and will grow to handle the remaining functions of the insurance
 *      fund, such as receiving quote-denominated fees and liquidation
 *      spreads, among others. The Diamond storage will only be
 *      affected when facet functions are called via the proxy
 *      contract, no checks are necessary.
 */
contract InsuranceFund {
    using SafeMath32 for uint32;
    using SafeMath96 for uint96;
    using SafeMath for uint96;
    using SafeMath for uint256;
    using MathHelpers for uint32;
    using MathHelpers for uint96;
    using MathHelpers for uint224;
    using MathHelpers for uint256;
    using SafeERC20 for IERC20;

    // Compound-related constant variables
    // kovan: 0x5eAe89DC1C671724A672ff0630122ee834098657
    IComptroller public constant COMPTROLLER = IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    // kovan: 0x61460874a7196d6a22D1eE4922473664b3E95270
    IERC20 public constant COMP_TOKEN = IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888);

    event InsuranceFundInitialized(
        uint32 interval,
        uint32 withdrawalFactor,
        uint96 mineRatePerBlock,
        uint96 advanceIntervalReward,
        uint256 miningFinalBlockNumber
    );

    event InsuranceFundCollateralAdded(
        bytes32 collateralName,
        address underlyingToken,
        address collateralToken,
        InsuranceFundDefs.Flavor flavor
    );

    event StakedToInsuranceFund(address staker, uint96 amount, bytes32 collateralName);

    event WithdrawnFromInsuranceFund(address withdrawer, uint96 amount, bytes32 collateralName);

    event AdvancedOtherRewards(address intervalAdvancer, uint96 advanceReward);

    event InsuranceMineRewardsClaimed(address claimant, uint96 minedAmount);

    event MineRatePerBlockSet(uint96 mineRatePerBlock);

    event AdvanceIntervalRewardSet(uint96 advanceIntervalReward);

    event WithdrawalFactorSet(uint32 withdrawalFactor);

    event InsuranceMiningExtended(uint256 miningFinalBlockNumber);

    /**
     * @notice Limits functions to only be called via governance.
     */
    modifier onlyAdmin {
        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();
        require(msg.sender == dsDerivaDEX.admin, "IFund: must be called by Gov.");
        _;
    }

    /**
     * @notice Limits functions to only be called while insurance
     *         mining is ongoing.
     */
    modifier insuranceMiningOngoing {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();
        require(block.number < dsInsuranceFund.miningFinalBlockNumber, "IFund: mining ended.");
        _;
    }

    /**
     * @notice Limits functions to only be called while other
     *         rewards checkpointing is ongoing.
     */
    modifier otherRewardsOngoing {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();
        require(
            dsInsuranceFund.otherRewardsCheckpointBlock < dsInsuranceFund.miningFinalBlockNumber,
            "IFund: other rewards checkpointing ended."
        );
        _;
    }

    /**
     * @notice Limits functions to only be called via governance.
     */
    modifier isNotPaused {
        LibDiamondStoragePause.DiamondStoragePause storage dsPause = LibDiamondStoragePause.diamondStoragePause();
        require(!dsPause.isPaused, "IFund: paused.");
        _;
    }

    /**
     * @notice This function initializes the state with some critical
     *         information. This can only be called via governance.
     * @dev This function is best called as a parameter to the
     *      diamond cut function. This is removed prior to the selectors
     *      being added to the diamond, meaning it cannot be called
     *      again.
     * @param _interval The interval length (blocks) for other rewards
     *        claiming checkpoints (i.e. COMP and extra aTokens).
     * @param _withdrawalFactor Specifies the withdrawal fee if users
     *        redeem their insurance tokens.
     * @param _mineRatePerBlock The DDX tokens to be mined each interval
     *        for insurance mining.
     * @param _advanceIntervalReward DDX reward for participant who
     *        advances the insurance mining interval.
     * @param _insuranceMiningLength Insurance mining length (blocks).
     */
    function initialize(
        uint32 _interval,
        uint32 _withdrawalFactor,
        uint96 _mineRatePerBlock,
        uint96 _advanceIntervalReward,
        uint256 _insuranceMiningLength,
        IDIFundTokenFactory _diFundTokenFactory
    ) external onlyAdmin {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();

        // Set the interval for other rewards claiming checkpoints
        // (i.e. COMP and aTokens that accrue to the contract)
        // (e.g. 40320 ~ 1 week = 7 * 24 * 60 * 60 / 15 blocks)
        dsInsuranceFund.interval = _interval;

        // Keep track of the block number for other rewards checkpoint,
        // which is initialized to the block number the insurance fund
        // facet is added to the diamond
        dsInsuranceFund.otherRewardsCheckpointBlock = block.number;

        // Set the withdrawal factor, capped at 1000, implying 0% fee
        require(_withdrawalFactor <= 1000, "IFund: withdrawal fee too high.");
        // Set withdrawal ratio, which will be used with a 1e3 scaling
        // factor, meaning a value of 995 implies a withdrawal fee of
        // 0.5% since 995/1e3 => 0.995
        dsInsuranceFund.withdrawalFactor = _withdrawalFactor;

        // Set the insurance mine rate per block.
        // (e.g. 1.189e18 ~ 5% liquidity mine (50mm tokens))
        dsInsuranceFund.mineRatePerBlock = _mineRatePerBlock;

        // Incentive to advance the other rewards interval
        // (e.g. 100e18 = 100 DDX)
        dsInsuranceFund.advanceIntervalReward = _advanceIntervalReward;

        // Set the final block number for insurance mining
        dsInsuranceFund.miningFinalBlockNumber = block.number.add(_insuranceMiningLength);

        // DIFundToken factory to deploy DerivaDEX Insurance Fund token
        // contracts pertaining to each supported collateral
        dsInsuranceFund.diFundTokenFactory = _diFundTokenFactory;

        // Initialize the DDX market state index and block. These values
        // are critical for computing the DDX continuously issued per
        // block
        dsInsuranceFund.ddxMarketState.index = 1e36;
        dsInsuranceFund.ddxMarketState.block = block.number.safe32("IFund: exceeds 32 bits");

        emit InsuranceFundInitialized(
            _interval,
            _withdrawalFactor,
            _mineRatePerBlock,
            _advanceIntervalReward,
            dsInsuranceFund.miningFinalBlockNumber
        );
    }

    /**
     * @notice This function sets the DDX mine rate per block.
     * @param _mineRatePerBlock The DDX tokens mine rate per block.
     */
    function setMineRatePerBlock(uint96 _mineRatePerBlock) external onlyAdmin insuranceMiningOngoing isNotPaused {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();

        // NOTE(jalextowle): We must update the DDX Market State prior to
        // changing the mine rate per block in order to lock in earned rewards
        // for insurance mining participants.
        updateDDXMarketState(dsInsuranceFund);

        require(_mineRatePerBlock != dsInsuranceFund.mineRatePerBlock, "IFund: same as current value.");
        // Set the insurance mine rate per block.
        // (e.g. 1.189e18 ~ 5% liquidity mine (50mm tokens))
        dsInsuranceFund.mineRatePerBlock = _mineRatePerBlock;

        emit MineRatePerBlockSet(_mineRatePerBlock);
    }

    /**
     * @notice This function sets the advance interval reward.
     * @param _advanceIntervalReward DDX reward for advancing interval.
     */
    function setAdvanceIntervalReward(uint96 _advanceIntervalReward)
        external
        onlyAdmin
        insuranceMiningOngoing
        isNotPaused
    {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();

        require(_advanceIntervalReward != dsInsuranceFund.advanceIntervalReward, "IFund: same as current value.");
        // Set the advance interval reward
        dsInsuranceFund.advanceIntervalReward = _advanceIntervalReward;

        emit AdvanceIntervalRewardSet(_advanceIntervalReward);
    }

    /**
     * @notice This function sets the withdrawal factor.
     * @param _withdrawalFactor Withdrawal factor.
     */
    function setWithdrawalFactor(uint32 _withdrawalFactor) external onlyAdmin insuranceMiningOngoing isNotPaused {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();

        require(_withdrawalFactor != dsInsuranceFund.withdrawalFactor, "IFund: same as current value.");
        // Set the withdrawal factor, capped at 1000, implying 0% fee
        require(dsInsuranceFund.withdrawalFactor <= 1000, "IFund: withdrawal fee too high.");
        dsInsuranceFund.withdrawalFactor = _withdrawalFactor;

        emit WithdrawalFactorSet(_withdrawalFactor);
    }

    /**
     * @notice This function extends insurance mining.
     * @param _insuranceMiningExtension Insurance mining extension
     *         (blocks).
     */
    function extendInsuranceMining(uint256 _insuranceMiningExtension)
        external
        onlyAdmin
        insuranceMiningOngoing
        isNotPaused
    {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();

        require(_insuranceMiningExtension != 0, "IFund: invalid extension.");
        // Extend the mining final block number
        dsInsuranceFund.miningFinalBlockNumber = dsInsuranceFund.miningFinalBlockNumber.add(_insuranceMiningExtension);

        emit InsuranceMiningExtended(dsInsuranceFund.miningFinalBlockNumber);
    }

    /**
     * @notice This function adds a new supported collateral type that
     *         can be staked to the insurance fund. It can only
     *         be called via governance.
     * @dev For vanilla contracts (e.g. USDT, USDC, etc.), the
     *      underlying token equals address(0).
     * @param _collateralName Name of collateral.
     * @param _collateralSymbol Symbol of collateral.
     * @param _underlyingToken Deployed address of underlying token.
     * @param _collateralToken Deployed address of collateral token.
     * @param _flavor Collateral flavor (Vanilla, Compound, Aave, etc.).
     */
    function addInsuranceFundCollateral(
        string memory _collateralName,
        string memory _collateralSymbol,
        address _underlyingToken,
        address _collateralToken,
        InsuranceFundDefs.Flavor _flavor
    ) external onlyAdmin insuranceMiningOngoing isNotPaused {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();

        // Obtain bytes32 representation of collateral name
        bytes32 result;
        assembly {
            result := mload(add(_collateralName, 32))
        }

        // Ensure collateral has not already been added
        require(
            dsInsuranceFund.stakeCollaterals[result].collateralToken == address(0),
            "IFund: collateral already added."
        );

        require(_collateralToken != address(0), "IFund: collateral address must be non-zero.");
        require(!isCollateralTokenPresent(_collateralToken), "IFund: collateral token already present.");
        require(_underlyingToken != _collateralToken, "IFund: token addresses are same.");
        if (_flavor == InsuranceFundDefs.Flavor.Vanilla) {
            // If collateral is of vanilla flavor, there should only be
            // a value for collateral token, and underlying token should
            // be empty
            require(_underlyingToken == address(0), "IFund: underlying address non-zero for Vanilla.");
        }

        // Add collateral type to storage, including its underlying
        // token and collateral token addresses, and its flavor
        dsInsuranceFund.stakeCollaterals[result].underlyingToken = _underlyingToken;
        dsInsuranceFund.stakeCollaterals[result].collateralToken = _collateralToken;
        dsInsuranceFund.stakeCollaterals[result].flavor = _flavor;

        // Create a DerivaDEX Insurance Fund token contract associated
        // with this supported collateral
        dsInsuranceFund.stakeCollaterals[result].diFundToken = IDIFundToken(
            dsInsuranceFund.diFundTokenFactory.createNewDIFundToken(
                _collateralName,
                _collateralSymbol,
                IERCCustom(_collateralToken).decimals()
            )
        );
        dsInsuranceFund.collateralNames.push(result);

        emit InsuranceFundCollateralAdded(result, _underlyingToken, _collateralToken, _flavor);
    }

    /**
     * @notice This function allows participants to stake a supported
     *         collateral type to the insurance fund.
     * @param _collateralName Name of collateral.
     * @param _amount Amount to stake.
     */
    function stakeToInsuranceFund(bytes32 _collateralName, uint96 _amount) external insuranceMiningOngoing isNotPaused {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();

        // Obtain the collateral struct for the collateral type
        // participant is staking
        InsuranceFundDefs.StakeCollateral storage stakeCollateral = dsInsuranceFund.stakeCollaterals[_collateralName];

        // Ensure this is a supported collateral type and that the user
        // has approved the proxy contract for transfer
        require(stakeCollateral.collateralToken != address(0), "IFund: invalid collateral.");

        // Ensure non-zero stake amount
        require(_amount > 0, "IFund: non-zero amount.");

        // Claim DDX for staking user. We do this prior to the stake
        // taking effect, thereby preventing someone from being rewarded
        // instantly for the stake.
        claimDDXFromInsuranceMining(msg.sender);

        // Increment the underlying capitalization
        stakeCollateral.cap = stakeCollateral.cap.add96(_amount);

        // Transfer collateral amount from user to proxy contract
        IERC20(stakeCollateral.collateralToken).safeTransferFrom(msg.sender, address(this), _amount);

        // Mint DIFund tokens to user
        stakeCollateral.diFundToken.mint(msg.sender, _amount);

        emit StakedToInsuranceFund(msg.sender, _amount, _collateralName);
    }

    /**
     * @notice This function allows participants to withdraw a supported
     *         collateral type from the insurance fund.
     * @param _collateralName Name of collateral.
     * @param _amount Amount to stake.
     */
    function withdrawFromInsuranceFund(bytes32 _collateralName, uint96 _amount) external isNotPaused {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();

        // Obtain the collateral struct for the collateral type
        // participant is staking
        InsuranceFundDefs.StakeCollateral storage stakeCollateral = dsInsuranceFund.stakeCollaterals[_collateralName];

        // Ensure this is a supported collateral type and that the user
        // has approved the proxy contract for transfer
        require(stakeCollateral.collateralToken != address(0), "IFund: invalid collateral.");

        // Ensure non-zero withdraw amount
        require(_amount > 0, "IFund: non-zero amount.");

        // Claim DDX for withdrawing user. We do this prior to the
        // redeem taking effect.
        claimDDXFromInsuranceMining(msg.sender);

        // Determine underlying to transfer based on how much underlying
        // can be redeemed given the current underlying capitalization
        // and how many DIFund tokens are globally available. This
        // theoretically fails in the scenario where globally there are
        // 0 insurance fund tokens, however that would mean the user
        // also has 0 tokens in their possession, and thus would have
        // nothing to be redeemed anyways.
        uint96 underlyingToTransferNoFee =
            _amount.proportion96(stakeCollateral.cap, stakeCollateral.diFundToken.totalSupply());
        uint96 underlyingToTransfer = underlyingToTransferNoFee.proportion96(dsInsuranceFund.withdrawalFactor, 1e3);

        // Decrement the capitalization
        stakeCollateral.cap = stakeCollateral.cap.sub96(underlyingToTransferNoFee);

        // Increment the withdrawal fee cap
        stakeCollateral.withdrawalFeeCap = stakeCollateral.withdrawalFeeCap.add96(
            underlyingToTransferNoFee.sub96(underlyingToTransfer)
        );

        // Transfer collateral amount from proxy contract to user
        IERC20(stakeCollateral.collateralToken).safeTransfer(msg.sender, underlyingToTransfer);

        // Burn DIFund tokens being redeemed from user
        stakeCollateral.diFundToken.burnFrom(msg.sender, _amount);

        emit WithdrawnFromInsuranceFund(msg.sender, _amount, _collateralName);
    }

    /**
     * @notice Advance other rewards interval
     */
    function advanceOtherRewardsInterval() external otherRewardsOngoing isNotPaused {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();

        // Check if the current block has exceeded the interval bounds,
        // allowing for a new other rewards interval to be checkpointed
        require(
            block.number >= dsInsuranceFund.otherRewardsCheckpointBlock.add(dsInsuranceFund.interval),
            "IFund: advance too soon."
        );

        // Maintain the USD-denominated sum of all Compound-flavor
        // assets. This needs to be stored separately than the rest
        // due to the way COMP tokens are rewarded to the contract in
        // order to properly disseminate to the user.
        uint96 normalizedCapCheckpointSumCompound;

        // Loop through each of the supported collateral types
        for (uint256 i = 0; i < dsInsuranceFund.collateralNames.length; i++) {
            // Obtain collateral struct under consideration
            InsuranceFundDefs.StakeCollateral storage stakeCollateral =
                dsInsuranceFund.stakeCollaterals[dsInsuranceFund.collateralNames[i]];
            if (stakeCollateral.flavor == InsuranceFundDefs.Flavor.Compound) {
                // If collateral is of type Compound, set the exchange
                // rate at this point in time. We do this so later on,
                // when claiming rewards, we know the exchange rate
                // checkpointed balances should be converted to
                // determine the USD-denominated value of holdings
                // needed to compute fair share of DDX rewards.
                stakeCollateral.exchangeRate = ICToken(stakeCollateral.collateralToken).exchangeRateStored().safe96(
                    "IFund: amount exceeds 96 bits"
                );

                // Set checkpoint cap for this Compound flavor
                // collateral to handle COMP distribution lookbacks
                stakeCollateral.checkpointCap = stakeCollateral.cap;

                // Increment the normalized Compound checkpoint cap
                // with the USD-denominated value
                normalizedCapCheckpointSumCompound = normalizedCapCheckpointSumCompound.add96(
                    getUnderlyingTokenAmountForCompound(stakeCollateral.cap, stakeCollateral.exchangeRate)
                );
            } else if (stakeCollateral.flavor == InsuranceFundDefs.Flavor.Aave) {
                // If collateral is of type Aave, we need to do some
                // custom Aave aToken reward distribution. We first
                // determine the contract's aToken balance for this
                // collateral type and subtract the underlying
                // aToken capitalization that are due to users. This
                // leaves us with the excess that has been rewarded
                // to the contract due to Aave's mechanisms, but
                // belong to the users.
                uint96 myATokenBalance =
                    uint96(IAToken(stakeCollateral.collateralToken).balanceOf(address(this)).sub(stakeCollateral.cap));

                // Store the aToken yield information
                dsInsuranceFund.aTokenYields[dsInsuranceFund.collateralNames[i]] = InsuranceFundDefs
                    .ExternalYieldCheckpoint({ accrued: myATokenBalance, totalNormalizedCap: 0 });
            }
        }

        // Ensure that the normalized cap sum is non-zero
        if (normalizedCapCheckpointSumCompound > 0) {
            // If there's Compound-type asset capitalization in the
            // system, claim COMP accrued to this contract. This COMP is
            // a result of holding all the cToken deposits from users.
            // We claim COMP via Compound's Comptroller contract.
            COMPTROLLER.claimComp(address(this));

            // Obtain contract's balance of COMP
            uint96 myCompBalance = COMP_TOKEN.balanceOf(address(this)).safe96("IFund: amount exceeds 96 bits.");

            // Store the updated value as the checkpointed COMP yield owed
            // for this interval
            dsInsuranceFund.compYields = InsuranceFundDefs.ExternalYieldCheckpoint({
                accrued: myCompBalance,
                totalNormalizedCap: normalizedCapCheckpointSumCompound
            });
        }

        // Set other rewards checkpoint block to current block
        dsInsuranceFund.otherRewardsCheckpointBlock = block.number;

        // Issue DDX reward to trader's on-chain DDX wallet as an
        // incentive to users calling this function
        LibTraderInternal.issueDDXReward(dsInsuranceFund.advanceIntervalReward, msg.sender);

        emit AdvancedOtherRewards(msg.sender, dsInsuranceFund.advanceIntervalReward);
    }

    /**
     * @notice This function gets some high level insurance mining
     *         details.
     * @return The interval length (blocks) for other rewards
     *         claiming checkpoints (i.e. COMP and extra aTokens).
     * @return Current insurance mine withdrawal factor.
     * @return DDX reward for advancing interval.
     * @return Total global insurance mined amount in DDX.
     * @return Current insurance mine rate per block.
     * @return Insurance mining final block number.
     * @return DDX market state used for continuous DDX payouts.
     * @return Supported collateral names supported.
     */
    function getInsuranceMineInfo()
        external
        view
        returns (
            uint32,
            uint32,
            uint96,
            uint96,
            uint96,
            uint256,
            InsuranceFundDefs.DDXMarketState memory,
            bytes32[] memory
        )
    {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();
        return (
            dsInsuranceFund.interval,
            dsInsuranceFund.withdrawalFactor,
            dsInsuranceFund.advanceIntervalReward,
            dsInsuranceFund.minedAmount,
            dsInsuranceFund.mineRatePerBlock,
            dsInsuranceFund.miningFinalBlockNumber,
            dsInsuranceFund.ddxMarketState,
            dsInsuranceFund.collateralNames
        );
    }

    /**
     * @notice This function gets the current claimant state for a user.
     * @param _claimant Claimant address.
     * @return Claimant state.
     */
    function getDDXClaimantState(address _claimant) external view returns (InsuranceFundDefs.DDXClaimantState memory) {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();
        return dsInsuranceFund.ddxClaimantState[_claimant];
    }

    /**
     * @notice This function gets a supported collateral type's data,
     *         including collateral's token addresses, collateral
     *         flavor/type, current cap and withdrawal amounts, the
     *         latest checkpointed cap, and exchange rate (for cTokens).
     *         An interface for the DerivaDEX Insurance Fund token
     *         corresponding to this collateral is also maintained.
     * @param _collateralName Name of collateral.
     * @return Stake collateral.
     */
    function getStakeCollateralByCollateralName(bytes32 _collateralName)
        external
        view
        returns (InsuranceFundDefs.StakeCollateral memory)
    {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();
        return dsInsuranceFund.stakeCollaterals[_collateralName];
    }

    /**
     * @notice This function gets unclaimed DDX rewards for a claimant.
     * @param _claimant Claimant address.
     * @return Unclaimed DDX rewards.
     */
    function getUnclaimedDDXRewards(address _claimant) external view returns (uint96) {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();

        // Number of blocks that have elapsed from the last protocol
        // interaction resulting in DDX accrual. If insurance mining
        // has ended, we use this as the reference point, so deltaBlocks
        // will be 0 from the second time onwards.
        uint256 deltaBlocks =
            Math.min(block.number, dsInsuranceFund.miningFinalBlockNumber).sub(dsInsuranceFund.ddxMarketState.block);

        // Save off last index value
        uint256 index = dsInsuranceFund.ddxMarketState.index;

        // If number of blocks elapsed and mine rate per block are
        // non-zero
        if (deltaBlocks > 0 && dsInsuranceFund.mineRatePerBlock > 0) {
            // Maintain a running total of USDT-normalized claim tokens
            // (i.e. 1e6 multiplier)
            uint256 claimTokens;

            // Loop through each of the supported collateral types
            for (uint256 i = 0; i < dsInsuranceFund.collateralNames.length; i++) {
                // Obtain the collateral struct for the collateral type
                // participant is staking
                InsuranceFundDefs.StakeCollateral storage stakeCollateral =
                    dsInsuranceFund.stakeCollaterals[dsInsuranceFund.collateralNames[i]];

                // Increment the USDT-normalized claim tokens count with
                // the current total supply
                claimTokens = claimTokens.add(
                    getNormalizedCollateralValue(
                        dsInsuranceFund.collateralNames[i],
                        stakeCollateral.diFundToken.totalSupply().safe96("IFund: exceeds 96 bits")
                    )
                );
            }

            // Compute DDX accrued during the time elapsed and the
            // number of tokens accrued per claim token outstanding
            uint256 ddxAccrued = deltaBlocks.mul(dsInsuranceFund.mineRatePerBlock);
            uint256 ratio = claimTokens > 0 ? ddxAccrued.mul(1e36).div(claimTokens) : 0;

            // Increment the index
            index = index.add(ratio);
        }

        // Obtain the most recent claimant index
        uint256 ddxClaimantIndex = dsInsuranceFund.ddxClaimantState[_claimant].index;

        // If the claimant index is 0, i.e. it's the user's first time
        // interacting with the protocol, initialize it to this starting
        // value
        if ((ddxClaimantIndex == 0) && (index > 0)) {
            ddxClaimantIndex = 1e36;
        }

        // Maintain a running total of USDT-normalized claimant tokens
        // (i.e. 1e6 multiplier)
        uint256 claimantTokens;

        // Loop through each of the supported collateral types
        for (uint256 i = 0; i < dsInsuranceFund.collateralNames.length; i++) {
            // Obtain the collateral struct for the collateral type
            // participant is staking
            InsuranceFundDefs.StakeCollateral storage stakeCollateral =
                dsInsuranceFund.stakeCollaterals[dsInsuranceFund.collateralNames[i]];

            // Increment the USDT-normalized claimant tokens count with
            // the current balance
            claimantTokens = claimantTokens.add(
                getNormalizedCollateralValue(
                    dsInsuranceFund.collateralNames[i],
                    stakeCollateral.diFundToken.balanceOf(_claimant).safe96("IFund: exceeds 96 bits")
                )
            );
        }

        // Compute the unclaimed DDX based on the number of claimant
        // tokens and the difference between the user's index and the
        // claimant index computed above
        return claimantTokens.mul(index.sub(ddxClaimantIndex)).div(1e36).safe96("IFund: exceeds 96 bits");
    }

    /**
     * @notice Calculate DDX accrued by a claimant and possibly transfer
     *         it to them.
     * @param _claimant The address of the claimant.
     */
    function claimDDXFromInsuranceMining(address _claimant) public {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();

        // Update the DDX Market State in order to determine the amount of
        // rewards that should be paid to the claimant.
        updateDDXMarketState(dsInsuranceFund);

        // Obtain the most recent claimant index
        uint256 ddxClaimantIndex = dsInsuranceFund.ddxClaimantState[_claimant].index;
        dsInsuranceFund.ddxClaimantState[_claimant].index = dsInsuranceFund.ddxMarketState.index;

        // If the claimant index is 0, i.e. it's the user's first time
        // interacting with the protocol, initialize it to this starting
        // value
        if ((ddxClaimantIndex == 0) && (dsInsuranceFund.ddxMarketState.index > 0)) {
            ddxClaimantIndex = 1e36;
        }

        // Compute the difference between the latest DDX market state
        // index and the claimant's index
        uint256 deltaIndex = uint256(dsInsuranceFund.ddxMarketState.index).sub(ddxClaimantIndex);

        // Maintain a running total of USDT-normalized claimant tokens
        // (i.e. 1e6 multiplier)
        uint256 claimantTokens;

        // Loop through each of the supported collateral types
        for (uint256 i = 0; i < dsInsuranceFund.collateralNames.length; i++) {
            // Obtain the collateral struct for the collateral type
            // participant is staking
            InsuranceFundDefs.StakeCollateral storage stakeCollateral =
                dsInsuranceFund.stakeCollaterals[dsInsuranceFund.collateralNames[i]];

            // Increment the USDT-normalized claimant tokens count with
            // the current balance
            claimantTokens = claimantTokens.add(
                getNormalizedCollateralValue(
                    dsInsuranceFund.collateralNames[i],
                    stakeCollateral.diFundToken.balanceOf(_claimant).safe96("IFund: exceeds 96 bits")
                )
            );
        }

        // Compute the claimed DDX based on the number of claimant
        // tokens and the difference between the user's index and the
        // claimant index computed above
        uint96 claimantDelta = claimantTokens.mul(deltaIndex).div(1e36).safe96("IFund: exceeds 96 bits");

        if (claimantDelta != 0) {
            // Adjust insurance mined amount
            dsInsuranceFund.minedAmount = dsInsuranceFund.minedAmount.add96(claimantDelta);

            // Increment the insurance mined claimed DDX for claimant
            dsInsuranceFund.ddxClaimantState[_claimant].claimedDDX = dsInsuranceFund.ddxClaimantState[_claimant]
                .claimedDDX
                .add96(claimantDelta);

            // Mint the DDX governance/operational token claimed reward
            // from the proxy contract to the participant
            LibTraderInternal.issueDDXReward(claimantDelta, _claimant);
        }

        // Check if COMP or aTokens have not already been claimed
        if (dsInsuranceFund.stakerToOtherRewardsClaims[_claimant] < dsInsuranceFund.otherRewardsCheckpointBlock) {
            // Record the current block number preventing a user from
            // reclaiming the COMP reward unfairly
            dsInsuranceFund.stakerToOtherRewardsClaims[_claimant] = block.number;

            // Claim COMP and extra aTokens
            claimOtherRewardsFromInsuranceMining(_claimant);
        }

        emit InsuranceMineRewardsClaimed(_claimant, claimantDelta);
    }

    /**
     * @notice Get USDT-normalized collateral token amount.
     * @param _collateralName The collateral name.
     * @param _value The number of tokens.
     */
    function getNormalizedCollateralValue(bytes32 _collateralName, uint96 _value) public view returns (uint96) {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();
        InsuranceFundDefs.StakeCollateral storage stakeCollateral = dsInsuranceFund.stakeCollaterals[_collateralName];

        return
            (stakeCollateral.flavor != InsuranceFundDefs.Flavor.Compound)
                ? getUnderlyingTokenAmountForVanilla(_value, stakeCollateral.collateralToken)
                : getUnderlyingTokenAmountForCompound(
                    _value,
                    ICToken(stakeCollateral.collateralToken).exchangeRateStored()
                );
    }

    /**
     * @notice This function gets a participant's current
     *         USD-normalized/denominated stake and global
     *         USD-normalized/denominated stake across all supported
     *         collateral types.
     * @param _staker Participant's address.
     * @return Current USD redemption value of DIFund tokens staked.
     * @return Current USD global cap.
     */
    function getCurrentTotalStakes(address _staker) public view returns (uint96, uint96) {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();

        // Maintain running totals
        uint96 normalizedStakerStakeSum;
        uint96 normalizedGlobalCapSum;

        // Loop through each supported collateral
        for (uint256 i = 0; i < dsInsuranceFund.collateralNames.length; i++) {
            (, , uint96 normalizedStakerStake, uint96 normalizedGlobalCap) =
                getCurrentStakeByCollateralNameAndStaker(dsInsuranceFund.collateralNames[i], _staker);
            normalizedStakerStakeSum = normalizedStakerStakeSum.add96(normalizedStakerStake);
            normalizedGlobalCapSum = normalizedGlobalCapSum.add96(normalizedGlobalCap);
        }

        return (normalizedStakerStakeSum, normalizedGlobalCapSum);
    }

    /**
     * @notice This function gets a participant's current DIFund token
     *         holdings and global DIFund token holdings for a
     *         collateral type and staker, in addition to the
     *         USD-normalized collateral in the system and the
     *         redemption value for the staker.
     * @param _collateralName Name of collateral.
     * @param _staker Participant's address.
     * @return DIFund tokens for staker.
     * @return DIFund tokens globally.
     * @return Redemption value for staker (USD-denominated).
     * @return Underlying collateral (USD-denominated) in staking system.
     */
    function getCurrentStakeByCollateralNameAndStaker(bytes32 _collateralName, address _staker)
        public
        view
        returns (
            uint96,
            uint96,
            uint96,
            uint96
        )
    {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();
        InsuranceFundDefs.StakeCollateral storage stakeCollateral = dsInsuranceFund.stakeCollaterals[_collateralName];

        // Get DIFund tokens for staker
        uint96 stakerStake = stakeCollateral.diFundToken.balanceOf(_staker).safe96("IFund: exceeds 96 bits.");

        // Get DIFund tokens globally
        uint96 globalCap = stakeCollateral.diFundToken.totalSupply().safe96("IFund: exceeds 96 bits.");

        // Compute global USD-denominated stake capitalization. This is
        // is straightforward for non-Compound assets, but requires
        // exchange rate conversion for Compound assets.
        uint96 normalizedGlobalCap =
            (stakeCollateral.flavor != InsuranceFundDefs.Flavor.Compound)
                ? getUnderlyingTokenAmountForVanilla(stakeCollateral.cap, stakeCollateral.collateralToken)
                : getUnderlyingTokenAmountForCompound(
                    stakeCollateral.cap,
                    ICToken(stakeCollateral.collateralToken).exchangeRateStored()
                );

        // Compute the redemption value (USD-normalized) for staker
        // given DIFund token holdings
        uint96 normalizedStakerStake = globalCap > 0 ? normalizedGlobalCap.proportion96(stakerStake, globalCap) : 0;
        return (stakerStake, globalCap, normalizedStakerStake, normalizedGlobalCap);
    }

    /**
     * @notice This function gets a participant's DIFund token
     *         holdings and global DIFund token holdings for Compound
     *         and Aave tokens for a collateral type and staker as of
     *         the checkpointed block, in addition to the
     *         USD-normalized collateral in the system and the
     *         redemption value for the staker.
     * @param _collateralName Name of collateral.
     * @param _staker Participant's address.
     * @return DIFund tokens for staker.
     * @return DIFund tokens globally.
     * @return Redemption value for staker (USD-denominated).
     * @return Underlying collateral (USD-denominated) in staking system.
     */
    function getOtherRewardsStakeByCollateralNameAndStaker(bytes32 _collateralName, address _staker)
        public
        view
        returns (
            uint96,
            uint96,
            uint96,
            uint96
        )
    {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();
        InsuranceFundDefs.StakeCollateral storage stakeCollateral = dsInsuranceFund.stakeCollaterals[_collateralName];

        // Get DIFund tokens for staker as of the checkpointed block
        uint96 stakerStake =
            stakeCollateral.diFundToken.getPriorValues(_staker, dsInsuranceFund.otherRewardsCheckpointBlock.sub(1));

        // Get DIFund tokens globally as of the checkpointed block
        uint96 globalCap =
            stakeCollateral.diFundToken.getTotalPriorValues(dsInsuranceFund.otherRewardsCheckpointBlock.sub(1));

        // If Aave, don't worry about the normalized values since 1-1
        if (stakeCollateral.flavor == InsuranceFundDefs.Flavor.Aave) {
            return (stakerStake, globalCap, 0, 0);
        }

        // Compute global USD-denominated stake capitalization. This is
        // is straightforward for non-Compound assets, but requires
        // exchange rate conversion for Compound assets.
        uint96 normalizedGlobalCap =
            getUnderlyingTokenAmountForCompound(stakeCollateral.checkpointCap, stakeCollateral.exchangeRate);

        // Compute the redemption value (USD-normalized) for staker
        // given DIFund token holdings
        uint96 normalizedStakerStake = globalCap > 0 ? normalizedGlobalCap.proportion96(stakerStake, globalCap) : 0;
        return (stakerStake, globalCap, normalizedStakerStake, normalizedGlobalCap);
    }

    /**
     * @notice Claim other rewards (COMP and aTokens) for a claimant.
     * @param _claimant The address for the claimant.
     */
    function claimOtherRewardsFromInsuranceMining(address _claimant) internal {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();

        // Maintain a running total of COMP to be claimed from
        // insurance mining contract as a by product of cToken deposits
        uint96 compClaimedAmountSum;

        // Loop through collateral names that are supported
        for (uint256 i = 0; i < dsInsuranceFund.collateralNames.length; i++) {
            // Obtain collateral struct under consideration
            InsuranceFundDefs.StakeCollateral storage stakeCollateral =
                dsInsuranceFund.stakeCollaterals[dsInsuranceFund.collateralNames[i]];

            if (stakeCollateral.flavor == InsuranceFundDefs.Flavor.Vanilla) {
                // If collateral is of Vanilla flavor, we just
                // continue...
                continue;
            }

            // Compute the DIFund token holdings and the normalized,
            // USDT-normalized collateral value for the user
            (uint96 collateralStaker, uint96 collateralTotal, uint96 normalizedCollateralStaker, ) =
                getOtherRewardsStakeByCollateralNameAndStaker(dsInsuranceFund.collateralNames[i], _claimant);

            if ((collateralTotal == 0) || (collateralStaker == 0)) {
                // If there are no DIFund tokens, there is no reason to
                // claim rewards, so we continue...
                continue;
            }

            if (stakeCollateral.flavor == InsuranceFundDefs.Flavor.Aave) {
                // Aave has a special circumstance, where every
                // aToken results in additional aTokens accruing
                // to the holder's wallet. In this case, this is
                // the DerivaDEX contract. Therefore, we must
                // appropriately distribute the extra aTokens to
                // users claiming DDX for their aToken deposits.
                transferTokensAave(_claimant, dsInsuranceFund.collateralNames[i], collateralStaker, collateralTotal);
            } else if (stakeCollateral.flavor == InsuranceFundDefs.Flavor.Compound) {
                // If collateral is of type Compound, determine the
                // COMP claimant is entitled to based on the COMP
                // yield for this interval, the claimant's
                // DIFundToken share, and the USD-denominated
                // share for this market.
                uint96 compClaimedAmount =
                    dsInsuranceFund.compYields.accrued.proportion96(
                        normalizedCollateralStaker,
                        dsInsuranceFund.compYields.totalNormalizedCap
                    );

                // Increment the COMP claimed sum to be paid out
                // later
                compClaimedAmountSum = compClaimedAmountSum.add96(compClaimedAmount);
            }
        }

        // Distribute any COMP to be shared with the user
        if (compClaimedAmountSum > 0) {
            transferTokensCompound(_claimant, compClaimedAmountSum);
        }
    }

    /**
     * @notice This function transfers extra Aave aTokens to claimant.
     */
    function transferTokensAave(
        address _claimant,
        bytes32 _collateralName,
        uint96 _aaveStaker,
        uint96 _aaveTotal
    ) internal {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();
        // Obtain collateral struct under consideration
        InsuranceFundDefs.StakeCollateral storage stakeCollateral = dsInsuranceFund.stakeCollaterals[_collateralName];

        uint96 aTokenClaimedAmount =
            dsInsuranceFund.aTokenYields[_collateralName].accrued.proportion96(_aaveStaker, _aaveTotal);

        // Continues in scenarios token transfer fails (such as
        // transferring 0 tokens)
        try IAToken(stakeCollateral.collateralToken).transfer(_claimant, aTokenClaimedAmount) {} catch {}
    }

    /**
     * @notice This function transfers COMP tokens from the contract to
     *         a recipient.
     * @param _amount Amount of COMP to receive.
     */
    function transferTokensCompound(address _claimant, uint96 _amount) internal {
        // Continues in scenarios token transfer fails (such as
        // transferring 0 tokens)
        try COMP_TOKEN.transfer(_claimant, _amount) {} catch {}
    }

    /**
     * @notice Updates the DDX market state to ensure that claimants can receive
     *         their earned DDX rewards.
     */
    function updateDDXMarketState(LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund)
        internal
    {
        // Number of blocks that have elapsed from the last protocol
        // interaction resulting in DDX accrual. If insurance mining
        // has ended, we use this as the reference point, so deltaBlocks
        // will be 0 from the second time onwards.
        uint256 endBlock = Math.min(block.number, dsInsuranceFund.miningFinalBlockNumber);
        uint256 deltaBlocks = endBlock.sub(dsInsuranceFund.ddxMarketState.block);

        // If number of blocks elapsed and mine rate per block are
        // non-zero
        if (deltaBlocks > 0 && dsInsuranceFund.mineRatePerBlock > 0) {
            // Maintain a running total of USDT-normalized claim tokens
            // (i.e. 1e6 multiplier)
            uint256 claimTokens;

            // Loop through each of the supported collateral types
            for (uint256 i = 0; i < dsInsuranceFund.collateralNames.length; i++) {
                // Obtain the collateral struct for the collateral type
                // participant is staking
                InsuranceFundDefs.StakeCollateral storage stakeCollateral =
                    dsInsuranceFund.stakeCollaterals[dsInsuranceFund.collateralNames[i]];

                // Increment the USDT-normalized claim tokens count with
                // the current total supply
                claimTokens = claimTokens.add(
                    getNormalizedCollateralValue(
                        dsInsuranceFund.collateralNames[i],
                        stakeCollateral.diFundToken.totalSupply().safe96("IFund: exceeds 96 bits")
                    )
                );
            }

            // Compute DDX accrued during the time elapsed and the
            // number of tokens accrued per claim token outstanding
            uint256 ddxAccrued = deltaBlocks.mul(dsInsuranceFund.mineRatePerBlock);
            uint256 ratio = claimTokens > 0 ? ddxAccrued.mul(1e36).div(claimTokens) : 0;

            // Increment the index
            uint256 index = uint256(dsInsuranceFund.ddxMarketState.index).add(ratio);

            // Update the claim ddx market state with the new index
            // and block
            dsInsuranceFund.ddxMarketState.index = index.safe224("IFund: exceeds 224 bits");
            dsInsuranceFund.ddxMarketState.block = endBlock.safe32("IFund: exceeds 32 bits");
        } else if (deltaBlocks > 0) {
            dsInsuranceFund.ddxMarketState.block = endBlock.safe32("IFund: exceeds 32 bits");
        }
    }

    /**
     * @notice This function checks if a collateral token is present.
     * @param _collateralToken Collateral token address.
     * @return Whether collateral token is present or not.
     */
    function isCollateralTokenPresent(address _collateralToken) internal view returns (bool) {
        LibDiamondStorageInsuranceFund.DiamondStorageInsuranceFund storage dsInsuranceFund =
            LibDiamondStorageInsuranceFund.diamondStorageInsuranceFund();
        for (uint256 i = 0; i < dsInsuranceFund.collateralNames.length; i++) {
            // Return true if collateral token has been added
            if (
                dsInsuranceFund.stakeCollaterals[dsInsuranceFund.collateralNames[i]].collateralToken == _collateralToken
            ) {
                return true;
            }
        }

        // Collateral token has not been added, return false
        return false;
    }

    /**
     * @notice This function computes the underlying token amount for a
     *         vanilla token.
     * @param _vanillaAmount Number of vanilla tokens.
     * @param _collateral Address of vanilla collateral.
     * @return Underlying token amount.
     */
    function getUnderlyingTokenAmountForVanilla(uint96 _vanillaAmount, address _collateral)
        internal
        view
        returns (uint96)
    {
        uint256 vanillaDecimals = uint256(IERCCustom(_collateral).decimals());
        if (vanillaDecimals >= 6) {
            return uint256(_vanillaAmount).div(10**(vanillaDecimals.sub(6))).safe96("IFund: amount exceeds 96 bits");
        }
        return
            uint256(_vanillaAmount).mul(10**(uint256(6).sub(vanillaDecimals))).safe96("IFund: amount exceeds 96 bits");
    }

    /**
     * @notice This function computes the underlying token amount for a
     *         cToken amount by computing the current exchange rate.
     * @param _cTokenAmount Number of cTokens.
     * @param _exchangeRate Exchange rate derived from Compound.
     * @return Underlying token amount.
     */
    function getUnderlyingTokenAmountForCompound(uint96 _cTokenAmount, uint256 _exchangeRate)
        internal
        pure
        returns (uint96)
    {
        return _exchangeRate.mul(_cTokenAmount).div(1e18).safe96("IFund: amount exceeds 96 bits.");
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

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
library SafeMath32 {
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
    function add32(uint32 a, uint32 b) internal pure returns (uint32) {
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
     *
     * - Subtraction cannot overflow.
     */
    function sub32(uint32 a, uint32 b) internal pure returns (uint32) {
        return sub32(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub32(
        uint32 a,
        uint32 b,
        string memory errorMessage
    ) internal pure returns (uint32) {
        require(b <= a, errorMessage);
        uint32 c = a - b;

        return c;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import { SafeMath } from "openzeppelin-solidity/contracts/math/SafeMath.sol";
import { Math } from "openzeppelin-solidity/contracts/math/Math.sol";
import { SafeMath96 } from "./SafeMath96.sol";

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
library MathHelpers {
    using SafeMath96 for uint96;
    using SafeMath for uint256;

    function proportion96(
        uint96 a,
        uint256 b,
        uint256 c
    ) internal pure returns (uint96) {
        return safe96(uint256(a).mul(b).div(c), "Amount exceeds 96 bits");
    }

    function safe96(uint256 n, string memory errorMessage) internal pure returns (uint96) {
        require(n < 2**96, errorMessage);
        return uint96(n);
    }

    function safe32(uint256 n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function safe224(uint256 n, string memory errorMessage) internal pure returns (uint224) {
        require(n < 2**224, errorMessage);
        return uint224(n);
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function clamp96(
        uint96 a,
        uint256 b,
        uint256 c
    ) internal pure returns (uint96) {
        return safe96(Math.min(Math.max(a, b), c), "Amount exceeds 96 bits");
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { IDIFundToken } from "../../tokens/interfaces/IDIFundToken.sol";

/**
 * @title InsuranceFundDefs
 * @author DerivaDEX
 *
 * This library contains the common structs and enums pertaining to
 * the insurance fund.
 */
library InsuranceFundDefs {
    // DDX market state maintaining claim index and last updated block
    struct DDXMarketState {
        uint224 index;
        uint32 block;
    }

    // DDX claimant state maintaining claim index and claimed DDX
    struct DDXClaimantState {
        uint256 index;
        uint96 claimedDDX;
    }

    // Supported collateral struct consisting of the collateral's token
    // addresses, collateral flavor/type, current cap and withdrawal
    // amounts, the latest checkpointed cap, and exchange rate (for
    // cTokens). An interface for the DerivaDEX Insurance Fund token
    // corresponding to this collateral is also maintained.
    struct StakeCollateral {
        address underlyingToken;
        address collateralToken;
        IDIFundToken diFundToken;
        uint96 cap;
        uint96 withdrawalFeeCap;
        uint96 checkpointCap;
        uint96 exchangeRate;
        Flavor flavor;
    }

    // Contains the yield accrued and the total normalized cap.
    // Total normalized cap is maintained for Compound flavors so COMP
    // distribution can be paid out properly
    struct ExternalYieldCheckpoint {
        uint96 accrued;
        uint96 totalNormalizedCap;
    }

    // Type of collateral
    enum Flavor { Vanilla, Compound, Aave }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { InsuranceFundDefs } from "../libs/defs/InsuranceFundDefs.sol";
import { IDIFundTokenFactory } from "../tokens/interfaces/IDIFundTokenFactory.sol";

library LibDiamondStorageInsuranceFund {
    struct DiamondStorageInsuranceFund {
        // List of supported collateral names
        bytes32[] collateralNames;
        // Collateral name to stake collateral struct
        mapping(bytes32 => InsuranceFundDefs.StakeCollateral) stakeCollaterals;
        mapping(address => InsuranceFundDefs.DDXClaimantState) ddxClaimantState;
        // aToken name to yield checkpoints
        mapping(bytes32 => InsuranceFundDefs.ExternalYieldCheckpoint) aTokenYields;
        mapping(address => uint256) stakerToOtherRewardsClaims;
        // Interval to COMP yield checkpoint
        InsuranceFundDefs.ExternalYieldCheckpoint compYields;
        // Set the interval for other rewards claiming checkpoints
        // (i.e. COMP and aTokens that accrue to the contract)
        // (e.g. 40320 ~ 1 week = 7 * 24 * 60 * 60 / 15 blocks)
        uint32 interval;
        // Current insurance mining withdrawal factor
        uint32 withdrawalFactor;
        // DDX to be issued per block as insurance mining reward
        uint96 mineRatePerBlock;
        // Incentive to advance the insurance mining interval
        // (e.g. 100e18 = 100 DDX)
        uint96 advanceIntervalReward;
        // Total DDX insurance mined
        uint96 minedAmount;
        // Insurance fund capitalization due to liquidations and fees
        uint96 liqAndFeeCapitalization;
        // Checkpoint block for other rewards
        uint256 otherRewardsCheckpointBlock;
        // Insurance mining final block number
        uint256 miningFinalBlockNumber;
        InsuranceFundDefs.DDXMarketState ddxMarketState;
        IDIFundTokenFactory diFundTokenFactory;
    }

    bytes32 constant DIAMOND_STORAGE_POSITION_INSURANCE_FUND =
        keccak256("diamond.standard.diamond.storage.DerivaDEX.InsuranceFund");

    function diamondStorageInsuranceFund() internal pure returns (DiamondStorageInsuranceFund storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION_INSURANCE_FUND;
        assembly {
            ds_slot := position
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

library LibDiamondStoragePause {
    struct DiamondStoragePause {
        bool isPaused;
    }

    bytes32 constant DIAMOND_STORAGE_POSITION_PAUSE = keccak256("diamond.standard.diamond.storage.DerivaDEX.Pause");

    function diamondStoragePause() internal pure returns (DiamondStoragePause storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION_PAUSE;
        assembly {
            ds_slot := position
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IAToken {
    function decimals() external returns (uint256);

    function transfer(address _recipient, uint256 _amount) external;

    function balanceOf(address _user) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

abstract contract IComptroller {
    struct CompMarketState {
        uint224 index;
        uint32 block;
    }

    /// @notice Indicator that this is a Comptroller contract (for inspection)
    bool public constant isComptroller = true; // solhint-disable-line const-name-snakecase

    // @notice The COMP market supply state for each market
    mapping(address => CompMarketState) public compSupplyState;

    /// @notice The COMP borrow index for each market for each supplier as of the last time they accrued COMP
    mapping(address => mapping(address => uint256)) public compSupplierIndex;

    /// @notice The portion of compRate that each market currently receives
    mapping(address => uint256) public compSpeeds;

    /// @notice The COMP accrued but not yet transferred to each user
    mapping(address => uint256) public compAccrued;

    /*** Assets You Are In ***/

    function enterMarkets(address[] calldata cTokens) external virtual returns (uint256[] memory);

    function exitMarket(address cToken) external virtual returns (uint256);

    /*** Policy Hooks ***/

    function mintAllowed(
        address cToken,
        address minter,
        uint256 mintAmount
    ) external virtual returns (uint256);

    function mintVerify(
        address cToken,
        address minter,
        uint256 mintAmount,
        uint256 mintTokens
    ) external virtual;

    function redeemAllowed(
        address cToken,
        address redeemer,
        uint256 redeemTokens
    ) external virtual returns (uint256);

    function redeemVerify(
        address cToken,
        address redeemer,
        uint256 redeemAmount,
        uint256 redeemTokens
    ) external virtual;

    function borrowAllowed(
        address cToken,
        address borrower,
        uint256 borrowAmount
    ) external virtual returns (uint256);

    function borrowVerify(
        address cToken,
        address borrower,
        uint256 borrowAmount
    ) external virtual;

    function repayBorrowAllowed(
        address cToken,
        address payer,
        address borrower,
        uint256 repayAmount
    ) external virtual returns (uint256);

    function repayBorrowVerify(
        address cToken,
        address payer,
        address borrower,
        uint256 repayAmount,
        uint256 borrowerIndex
    ) external virtual;

    function liquidateBorrowAllowed(
        address cTokenBorrowed,
        address cTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount
    ) external virtual returns (uint256);

    function liquidateBorrowVerify(
        address cTokenBorrowed,
        address cTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount,
        uint256 seizeTokens
    ) external virtual;

    function seizeAllowed(
        address cTokenCollateral,
        address cTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external virtual returns (uint256);

    function seizeVerify(
        address cTokenCollateral,
        address cTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external virtual;

    function transferAllowed(
        address cToken,
        address src,
        address dst,
        uint256 transferTokens
    ) external virtual returns (uint256);

    function transferVerify(
        address cToken,
        address src,
        address dst,
        uint256 transferTokens
    ) external virtual;

    /*** Liquidity/Liquidation Calculations ***/

    function liquidateCalculateSeizeTokens(
        address cTokenBorrowed,
        address cTokenCollateral,
        uint256 repayAmount
    ) external virtual returns (uint256, uint256);

    function claimComp(address holder) public virtual;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface ICToken {
    function accrueInterest() external returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function seize(
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external returns (uint256);

    function totalBorrowsCurrent() external returns (uint256);

    function transfer(address dst, uint256 amount) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function borrowBalanceStored(address account) external view returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function decimals() external view returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function getAccountSnapshot(address account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    function getCash() external view returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/**
 * @title IDIFundToken
 * @author DerivaDEX (Borrowed/inspired from Compound)
 * @notice This is the native token contract for DerivaDEX. It
 *         implements the ERC-20 standard, with additional
 *         functionality to efficiently handle the governance aspect of
 *         the DerivaDEX ecosystem.
 * @dev The contract makes use of some nonstandard types not seen in
 *      the ERC-20 standard. The DDX token makes frequent use of the
 *      uint96 data type, as opposed to the more standard uint256 type.
 *      Given the maintenance of arrays of balances, allowances, and
 *      voting checkpoints, this allows us to more efficiently pack
 *      data together, thereby resulting in cheaper transactions.
 */
interface IDIFundToken {
    function transfer(address _recipient, uint256 _amount) external returns (bool);

    function mint(address _recipient, uint256 _amount) external;

    function burnFrom(address _account, uint256 _amount) external;

    function delegate(address _delegatee) external;

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external returns (bool);

    function approve(address _spender, uint256 _amount) external returns (bool);

    function getPriorValues(address account, uint256 blockNumber) external view returns (uint96);

    function getTotalPriorValues(uint256 blockNumber) external view returns (uint96);

    function balanceOf(address _account) external view returns (uint256);

    function totalSupply() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { DIFundToken } from "../DIFundToken.sol";

/**
 * @title DIFundToken
 * @author DerivaDEX (Borrowed/inspired from Compound)
 * @notice This is the token contract for tokenized DerivaDEX insurance
 *         fund positions. It implements the ERC-20 standard, with
 *         additional functionality around snapshotting user and global
 *         balances.
 * @dev The contract makes use of some nonstandard types not seen in
 *      the ERC-20 standard. The DIFundToken makes frequent use of the
 *      uint96 data type, as opposed to the more standard uint256 type.
 *      Given the maintenance of arrays of balances and allowances, this
 *      allows us to more efficiently pack data together, thereby
 *      resulting in cheaper transactions.
 */
interface IDIFundTokenFactory {
    function createNewDIFundToken(
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals
    ) external returns (address);

    function diFundTokens(uint256 index) external returns (DIFundToken);

    function issuer() external view returns (address);

    function getDIFundTokens() external view returns (DIFundToken[] memory);

    function getDIFundTokensLength() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { SafeMath } from "openzeppelin-solidity/contracts/math/SafeMath.sol";
import { LibBytes } from "../libs/LibBytes.sol";
import { LibEIP712 } from "../libs/LibEIP712.sol";
import { LibPermit } from "../libs/LibPermit.sol";
import { SafeMath96 } from "../libs/SafeMath96.sol";
import { IInsuranceFund } from "../facets/interfaces/IInsuranceFund.sol";

/**
 * @title DIFundToken
 * @author DerivaDEX (Borrowed/inspired from Compound)
 * @notice This is the token contract for tokenized DerivaDEX insurance
 *         fund positions. It implements the ERC-20 standard, with
 *         additional functionality around snapshotting user and global
 *         balances.
 * @dev The contract makes use of some nonstandard types not seen in
 *      the ERC-20 standard. The DIFundToken makes frequent use of the
 *      uint96 data type, as opposed to the more standard uint256 type.
 *      Given the maintenance of arrays of balances and allowances, this
 *      allows us to more efficiently pack data together, thereby
 *      resulting in cheaper transactions.
 */
contract DIFundToken {
    using SafeMath96 for uint96;
    using SafeMath for uint256;
    using LibBytes for bytes;

    uint256 internal _totalSupply;

    string private _name;
    string private _symbol;
    string private _version;
    uint8 private _decimals;

    /// @notice Address authorized to issue/mint DDX tokens
    address public issuer;

    mapping(address => mapping(address => uint96)) internal allowances;

    mapping(address => uint96) internal balances;

    /// @notice A checkpoint for marking vote count from given block
    struct Checkpoint {
        uint32 id;
        uint96 values;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping(address => mapping(uint256 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping(address => uint256) public numCheckpoints;

    mapping(uint256 => Checkpoint) totalCheckpoints;

    uint256 numTotalCheckpoints;

    /// @notice A record of states for signing / validating signatures
    mapping(address => uint256) public nonces;

    /// @notice Emitted when a user account's balance changes
    event ValuesChanged(address indexed user, uint96 previousValue, uint96 newValue);

    /// @notice Emitted when a user account's balance changes
    event TotalValuesChanged(uint96 previousValue, uint96 newValue);

    /// @notice Emitted when transfer takes place
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when approval takes place
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /**
     * @notice Construct a new DIFundToken token
     */
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address _issuer
    ) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
        _version = "1";

        // Set issuer to deploying address
        issuer = _issuer;
    }

    /**
     * @notice Returns the name of the token.
     * @return Name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of the token.
     * @return Symbol of the token.
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
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     * @return Number of decimals.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param _spender The address of the account which may transfer tokens
     * @param _amount The number of tokens that are approved (2^256-1 means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(address _spender, uint256 _amount) external returns (bool) {
        require(_spender != address(0), "DIFT: approve to the zero address.");

        // Convert amount to uint96
        uint96 amount;
        if (_amount == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_amount, "DIFT: amount exceeds 96 bits.");
        }

        // Set allowance
        allowances[msg.sender][_spender] = amount;

        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     * Emits an {Approval} event indicating the updated allowance.
     * Requirements:
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address _spender, uint256 _addedValue) external returns (bool) {
        require(_spender != address(0), "DIFT: approve to the zero address.");

        // Convert amount to uint96
        uint96 amount;
        if (_addedValue == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_addedValue, "DIFT: amount exceeds 96 bits.");
        }

        // Increase allowance
        allowances[msg.sender][_spender] = allowances[msg.sender][_spender].add96(amount);

        emit Approval(msg.sender, _spender, allowances[msg.sender][_spender]);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     * Emits an {Approval} event indicating the updated allowance.
     * Requirements:
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address _spender, uint256 _subtractedValue) external returns (bool) {
        require(_spender != address(0), "DIFT: approve to the zero address.");

        // Convert amount to uint96
        uint96 amount;
        if (_subtractedValue == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_subtractedValue, "DIFT: amount exceeds 96 bits.");
        }

        // Decrease allowance
        allowances[msg.sender][_spender] = allowances[msg.sender][_spender].sub96(
            amount,
            "DIFT: decreased allowance below zero."
        );

        emit Approval(msg.sender, _spender, allowances[msg.sender][_spender]);
        return true;
    }

    /**
     * @notice Get the number of tokens held by the `account`
     * @param _account The address of the account to get the balance of
     * @return The number of tokens held
     */
    function balanceOf(address _account) external view returns (uint256) {
        return balances[_account];
    }

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param _recipient The address of the destination account
     * @param _amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(address _recipient, uint256 _amount) external returns (bool) {
        // Convert amount to uint96
        uint96 amount;
        if (_amount == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_amount, "DIFT: amount exceeds 96 bits.");
        }

        // Claim DDX rewards on behalf of the sender
        IInsuranceFund(issuer).claimDDXFromInsuranceMining(msg.sender);

        // Claim DDX rewards on behalf of the recipient
        IInsuranceFund(issuer).claimDDXFromInsuranceMining(_recipient);

        // Transfer tokens from sender to recipient
        _transferTokens(msg.sender, _recipient, amount);

        return true;
    }

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param _sender The address of the source account
     * @param _recipient The address of the destination account
     * @param _amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external returns (bool) {
        uint96 spenderAllowance = allowances[_sender][msg.sender];

        // Convert amount to uint96
        uint96 amount;
        if (_amount == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_amount, "DIFT: amount exceeds 96 bits.");
        }

        if (msg.sender != _sender && spenderAllowance != uint96(-1)) {
            // Tx sender is not the same as transfer sender and doesn't
            // have unlimited allowance.
            // Reduce allowance by amount being transferred
            uint96 newAllowance = spenderAllowance.sub96(amount);
            allowances[_sender][msg.sender] = newAllowance;

            emit Approval(_sender, msg.sender, newAllowance);
        }

        // Claim DDX rewards on behalf of the sender
        IInsuranceFund(issuer).claimDDXFromInsuranceMining(_sender);

        // Claim DDX rewards on behalf of the recipient
        IInsuranceFund(issuer).claimDDXFromInsuranceMining(_recipient);

        // Transfer tokens from sender to recipient
        _transferTokens(_sender, _recipient, amount);

        return true;
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     *      the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function mint(address _recipient, uint256 _amount) external {
        require(msg.sender == issuer, "DIFT: unauthorized mint.");

        // Convert amount to uint96
        uint96 amount;
        if (_amount == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_amount, "DIFT: amount exceeds 96 bits.");
        }

        // Mint tokens to recipient
        _transferTokensMint(_recipient, amount);
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, decreasing
     *      the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function burn(uint256 _amount) external {
        // Convert amount to uint96
        uint96 amount;
        if (_amount == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_amount, "DIFT: amount exceeds 96 bits.");
        }

        // Burn tokens from sender
        _transferTokensBurn(msg.sender, amount);
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     *      the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function burnFrom(address _account, uint256 _amount) external {
        uint96 spenderAllowance = allowances[_account][msg.sender];

        // Convert amount to uint96
        uint96 amount;
        if (_amount == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_amount, "DIFT: amount exceeds 96 bits.");
        }

        if (msg.sender != _account && spenderAllowance != uint96(-1) && msg.sender != issuer) {
            // Tx sender is not the same as burn account and doesn't
            // have unlimited allowance.
            // Reduce allowance by amount being transferred
            uint96 newAllowance = spenderAllowance.sub96(amount, "DIFT: burn amount exceeds allowance.");
            allowances[_account][msg.sender] = newAllowance;

            emit Approval(_account, msg.sender, newAllowance);
        }

        // Burn tokens from account
        _transferTokensBurn(_account, amount);
    }

    /**
     * @notice Permits allowance from signatory to `spender`
     * @param _spender The spender being approved
     * @param _value The value being approved
     * @param _nonce The contract state required to match the signature
     * @param _expiry The time at which to expire the signature
     * @param _signature Signature
     */
    function permit(
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 _expiry,
        bytes memory _signature
    ) external {
        // Perform EIP712 hashing logic
        bytes32 eip712OrderParamsDomainHash = LibEIP712.hashEIP712Domain(_name, _version, getChainId(), address(this));
        bytes32 permitHash =
            LibPermit.getPermitHash(
                LibPermit.Permit({ spender: _spender, value: _value, nonce: _nonce, expiry: _expiry }),
                eip712OrderParamsDomainHash
            );

        // Perform sig recovery
        uint8 v = uint8(_signature[0]);
        bytes32 r = _signature.readBytes32(1);
        bytes32 s = _signature.readBytes32(33);

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
            revert("ECDSA: invalid signature 's' value");
        }

        if (v != 27 && v != 28) {
            revert("ECDSA: invalid signature 'v' value");
        }

        address recovered = ecrecover(permitHash, v, r, s);

        require(recovered != address(0), "DIFT: invalid signature.");
        require(_nonce == nonces[recovered]++, "DIFT: invalid nonce.");
        require(block.timestamp <= _expiry, "DIFT: signature expired.");

        // Convert amount to uint96
        uint96 amount;
        if (_value == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_value, "DIFT: amount exceeds 96 bits.");
        }

        // Set allowance
        allowances[recovered][_spender] = amount;
        emit Approval(recovered, _spender, _value);
    }

    /**
     * @notice Get the number of tokens `spender` is approved to spend on behalf of `account`
     * @param _account The address of the account holding the funds
     * @param _spender The address of the account spending the funds
     * @return The number of tokens approved
     */
    function allowance(address _account, address _spender) external view returns (uint256) {
        return allowances[_account][_spender];
    }

    /**
     * @notice Get the total max supply of DDX tokens
     * @return The total max supply of DDX
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice Determine the prior number of values for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param _account The address of the account to check
     * @param _blockNumber The block number to get the vote balance at
     * @return The number of values the account had as of the given block
     */
    function getPriorValues(address _account, uint256 _blockNumber) external view returns (uint96) {
        require(_blockNumber < block.number, "DIFT: block not yet determined.");

        uint256 numCheckpointsAccount = numCheckpoints[_account];
        if (numCheckpointsAccount == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[_account][numCheckpointsAccount - 1].id <= _blockNumber) {
            return checkpoints[_account][numCheckpointsAccount - 1].values;
        }

        // Next check implicit zero balance
        if (checkpoints[_account][0].id > _blockNumber) {
            return 0;
        }

        // Perform binary search to find the most recent token holdings
        uint256 lower = 0;
        uint256 upper = numCheckpointsAccount - 1;
        while (upper > lower) {
            // ceil, avoiding overflow
            uint256 center = upper - (upper - lower) / 2;
            Checkpoint memory cp = checkpoints[_account][center];
            if (cp.id == _blockNumber) {
                return cp.values;
            } else if (cp.id < _blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[_account][lower].values;
    }

    /**
     * @notice Determine the prior number of values for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param _blockNumber The block number to get the vote balance at
     * @return The number of values the account had as of the given block
     */
    function getTotalPriorValues(uint256 _blockNumber) external view returns (uint96) {
        require(_blockNumber < block.number, "DIFT: block not yet determined.");

        if (numTotalCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (totalCheckpoints[numTotalCheckpoints - 1].id <= _blockNumber) {
            return totalCheckpoints[numTotalCheckpoints - 1].values;
        }

        // Next check implicit zero balance
        if (totalCheckpoints[0].id > _blockNumber) {
            return 0;
        }

        // Perform binary search to find the most recent token holdings
        // leading to a measure of voting power
        uint256 lower = 0;
        uint256 upper = numTotalCheckpoints - 1;
        while (upper > lower) {
            // ceil, avoiding overflow
            uint256 center = upper - (upper - lower) / 2;
            Checkpoint memory cp = totalCheckpoints[center];
            if (cp.id == _blockNumber) {
                return cp.values;
            } else if (cp.id < _blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return totalCheckpoints[lower].values;
    }

    function _transferTokens(
        address _spender,
        address _recipient,
        uint96 _amount
    ) internal {
        require(_spender != address(0), "DIFT: cannot transfer from the zero address.");
        require(_recipient != address(0), "DIFT: cannot transfer to the zero address.");

        // Reduce spender's balance and increase recipient balance
        balances[_spender] = balances[_spender].sub96(_amount);
        balances[_recipient] = balances[_recipient].add96(_amount);
        emit Transfer(_spender, _recipient, _amount);

        // Move values from spender to recipient
        _moveTokens(_spender, _recipient, _amount);
    }

    function _transferTokensMint(address _recipient, uint96 _amount) internal {
        require(_recipient != address(0), "DIFT: cannot transfer to the zero address.");

        // Add to recipient's balance
        balances[_recipient] = balances[_recipient].add96(_amount);

        _totalSupply = _totalSupply.add(_amount);

        emit Transfer(address(0), _recipient, _amount);

        // Add value to recipient's checkpoint
        _moveTokens(address(0), _recipient, _amount);
        _writeTotalCheckpoint(_amount, true);
    }

    function _transferTokensBurn(address _spender, uint96 _amount) internal {
        require(_spender != address(0), "DIFT: cannot transfer from the zero address.");

        // Reduce the spender/burner's balance
        balances[_spender] = balances[_spender].sub96(_amount, "DIFT: not enough balance to burn.");

        // Reduce the circulating supply
        _totalSupply = _totalSupply.sub(_amount);
        emit Transfer(_spender, address(0), _amount);

        // Reduce value from spender's checkpoint
        _moveTokens(_spender, address(0), _amount);
        _writeTotalCheckpoint(_amount, false);
    }

    function _moveTokens(
        address _initUser,
        address _finUser,
        uint96 _amount
    ) internal {
        if (_initUser != _finUser && _amount > 0) {
            // Initial user address is different than final
            // user address and nonzero number of values moved
            if (_initUser != address(0)) {
                uint256 initUserNum = numCheckpoints[_initUser];

                // Retrieve and compute the old and new initial user
                // address' values
                uint96 initUserOld = initUserNum > 0 ? checkpoints[_initUser][initUserNum - 1].values : 0;
                uint96 initUserNew = initUserOld.sub96(_amount);
                _writeCheckpoint(_initUser, initUserOld, initUserNew);
            }

            if (_finUser != address(0)) {
                uint256 finUserNum = numCheckpoints[_finUser];

                // Retrieve and compute the old and new final user
                // address' values
                uint96 finUserOld = finUserNum > 0 ? checkpoints[_finUser][finUserNum - 1].values : 0;
                uint96 finUserNew = finUserOld.add96(_amount);
                _writeCheckpoint(_finUser, finUserOld, finUserNew);
            }
        }
    }

    function _writeCheckpoint(
        address _user,
        uint96 _oldValues,
        uint96 _newValues
    ) internal {
        uint32 blockNumber = safe32(block.number, "DIFT: exceeds 32 bits.");
        uint256 userNum = numCheckpoints[_user];
        if (userNum > 0 && checkpoints[_user][userNum - 1].id == blockNumber) {
            // If latest checkpoint is current block, edit in place
            checkpoints[_user][userNum - 1].values = _newValues;
        } else {
            // Create a new id, value pair
            checkpoints[_user][userNum] = Checkpoint({ id: blockNumber, values: _newValues });
            numCheckpoints[_user] = userNum.add(1);
        }

        emit ValuesChanged(_user, _oldValues, _newValues);
    }

    function _writeTotalCheckpoint(uint96 _amount, bool increase) internal {
        if (_amount > 0) {
            uint32 blockNumber = safe32(block.number, "DIFT: exceeds 32 bits.");
            uint96 oldValues = numTotalCheckpoints > 0 ? totalCheckpoints[numTotalCheckpoints - 1].values : 0;
            uint96 newValues = increase ? oldValues.add96(_amount) : oldValues.sub96(_amount);

            if (numTotalCheckpoints > 0 && totalCheckpoints[numTotalCheckpoints - 1].id == block.number) {
                // If latest checkpoint is current block, edit in place
                totalCheckpoints[numTotalCheckpoints - 1].values = newValues;
            } else {
                // Create a new id, value pair
                totalCheckpoints[numTotalCheckpoints].id = blockNumber;
                totalCheckpoints[numTotalCheckpoints].values = newValues;
                numTotalCheckpoints = numTotalCheckpoints.add(1);
            }

            emit TotalValuesChanged(oldValues, newValues);
        }
    }

    function safe32(uint256 n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function safe96(uint256 n, string memory errorMessage) internal pure returns (uint96) {
        require(n < 2**96, errorMessage);
        return uint96(n);
    }

    function getChainId() internal pure returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}

// SPDX-License-Identifier: MIT
/*

  Copyright 2018 ZeroEx Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity 0.6.12;

library LibBytes {
    using LibBytes for bytes;

    /// @dev Gets the memory address for a byte array.
    /// @param input Byte array to lookup.
    /// @return memoryAddress Memory address of byte array. This
    ///         points to the header of the byte array which contains
    ///         the length.
    function rawAddress(bytes memory input) internal pure returns (uint256 memoryAddress) {
        assembly {
            memoryAddress := input
        }
        return memoryAddress;
    }

    /// @dev Gets the memory address for the contents of a byte array.
    /// @param input Byte array to lookup.
    /// @return memoryAddress Memory address of the contents of the byte array.
    function contentAddress(bytes memory input) internal pure returns (uint256 memoryAddress) {
        assembly {
            memoryAddress := add(input, 32)
        }
        return memoryAddress;
    }

    /// @dev Copies `length` bytes from memory location `source` to `dest`.
    /// @param dest memory address to copy bytes to.
    /// @param source memory address to copy bytes from.
    /// @param length number of bytes to copy.
    function memCopy(
        uint256 dest,
        uint256 source,
        uint256 length
    ) internal pure {
        if (length < 32) {
            // Handle a partial word by reading destination and masking
            // off the bits we are interested in.
            // This correctly handles overlap, zero lengths and source == dest
            assembly {
                let mask := sub(exp(256, sub(32, length)), 1)
                let s := and(mload(source), not(mask))
                let d := and(mload(dest), mask)
                mstore(dest, or(s, d))
            }
        } else {
            // Skip the O(length) loop when source == dest.
            if (source == dest) {
                return;
            }

            // For large copies we copy whole words at a time. The final
            // word is aligned to the end of the range (instead of after the
            // previous) to handle partial words. So a copy will look like this:
            //
            //  ####
            //      ####
            //          ####
            //            ####
            //
            // We handle overlap in the source and destination range by
            // changing the copying direction. This prevents us from
            // overwriting parts of source that we still need to copy.
            //
            // This correctly handles source == dest
            //
            if (source > dest) {
                assembly {
                    // We subtract 32 from `sEnd` and `dEnd` because it
                    // is easier to compare with in the loop, and these
                    // are also the addresses we need for copying the
                    // last bytes.
                    length := sub(length, 32)
                    let sEnd := add(source, length)
                    let dEnd := add(dest, length)

                    // Remember the last 32 bytes of source
                    // This needs to be done here and not after the loop
                    // because we may have overwritten the last bytes in
                    // source already due to overlap.
                    let last := mload(sEnd)

                    // Copy whole words front to back
                    // Note: the first check is always true,
                    // this could have been a do-while loop.
                    // solhint-disable-next-line no-empty-blocks
                    for {

                    } lt(source, sEnd) {

                    } {
                        mstore(dest, mload(source))
                        source := add(source, 32)
                        dest := add(dest, 32)
                    }

                    // Write the last 32 bytes
                    mstore(dEnd, last)
                }
            } else {
                assembly {
                    // We subtract 32 from `sEnd` and `dEnd` because those
                    // are the starting points when copying a word at the end.
                    length := sub(length, 32)
                    let sEnd := add(source, length)
                    let dEnd := add(dest, length)

                    // Remember the first 32 bytes of source
                    // This needs to be done here and not after the loop
                    // because we may have overwritten the first bytes in
                    // source already due to overlap.
                    let first := mload(source)

                    // Copy whole words back to front
                    // We use a signed comparisson here to allow dEnd to become
                    // negative (happens when source and dest < 32). Valid
                    // addresses in local memory will never be larger than
                    // 2**255, so they can be safely re-interpreted as signed.
                    // Note: the first check is always true,
                    // this could have been a do-while loop.
                    // solhint-disable-next-line no-empty-blocks
                    for {

                    } slt(dest, dEnd) {

                    } {
                        mstore(dEnd, mload(sEnd))
                        sEnd := sub(sEnd, 32)
                        dEnd := sub(dEnd, 32)
                    }

                    // Write the first 32 bytes
                    mstore(dest, first)
                }
            }
        }
    }

    /// @dev Returns a slices from a byte array.
    /// @param b The byte array to take a slice from.
    /// @param from The starting index for the slice (inclusive).
    /// @param to The final index for the slice (exclusive).
    /// @return result The slice containing bytes at indices [from, to)
    function slice(
        bytes memory b,
        uint256 from,
        uint256 to
    ) internal pure returns (bytes memory result) {
        require(from <= to, "FROM_LESS_THAN_TO_REQUIRED");
        require(to <= b.length, "TO_LESS_THAN_LENGTH_REQUIRED");

        // Create a new bytes structure and copy contents
        result = new bytes(to - from);
        memCopy(result.contentAddress(), b.contentAddress() + from, result.length);
        return result;
    }

    /// @dev Returns a slice from a byte array without preserving the input.
    /// @param b The byte array to take a slice from. Will be destroyed in the process.
    /// @param from The starting index for the slice (inclusive).
    /// @param to The final index for the slice (exclusive).
    /// @return result The slice containing bytes at indices [from, to)
    /// @dev When `from == 0`, the original array will match the slice. In other cases its state will be corrupted.
    function sliceDestructive(
        bytes memory b,
        uint256 from,
        uint256 to
    ) internal pure returns (bytes memory result) {
        require(from <= to, "FROM_LESS_THAN_TO_REQUIRED");
        require(to <= b.length, "TO_LESS_THAN_LENGTH_REQUIRED");

        // Create a new bytes structure around [from, to) in-place.
        assembly {
            result := add(b, from)
            mstore(result, sub(to, from))
        }
        return result;
    }

    /// @dev Pops the last byte off of a byte array by modifying its length.
    /// @param b Byte array that will be modified.
    /// @return result The byte that was popped off.
    function popLastByte(bytes memory b) internal pure returns (bytes1 result) {
        require(b.length > 0, "GREATER_THAN_ZERO_LENGTH_REQUIRED");

        // Store last byte.
        result = b[b.length - 1];

        assembly {
            // Decrement length of byte array.
            let newLen := sub(mload(b), 1)
            mstore(b, newLen)
        }
        return result;
    }

    /// @dev Pops the last 20 bytes off of a byte array by modifying its length.
    /// @param b Byte array that will be modified.
    /// @return result The 20 byte address that was popped off.
    function popLast20Bytes(bytes memory b) internal pure returns (address result) {
        require(b.length >= 20, "GREATER_OR_EQUAL_TO_20_LENGTH_REQUIRED");

        // Store last 20 bytes.
        result = readAddress(b, b.length - 20);

        assembly {
            // Subtract 20 from byte array length.
            let newLen := sub(mload(b), 20)
            mstore(b, newLen)
        }
        return result;
    }

    /// @dev Tests equality of two byte arrays.
    /// @param lhs First byte array to compare.
    /// @param rhs Second byte array to compare.
    /// @return equal True if arrays are the same. False otherwise.
    function equals(bytes memory lhs, bytes memory rhs) internal pure returns (bool equal) {
        // Keccak gas cost is 30 + numWords * 6. This is a cheap way to compare.
        // We early exit on unequal lengths, but keccak would also correctly
        // handle this.
        return lhs.length == rhs.length && keccak256(lhs) == keccak256(rhs);
    }

    /// @dev Reads an address from a position in a byte array.
    /// @param b Byte array containing an address.
    /// @param index Index in byte array of address.
    /// @return result address from byte array.
    function readAddress(bytes memory b, uint256 index) internal pure returns (address result) {
        require(
            b.length >= index + 20, // 20 is length of address
            "GREATER_OR_EQUAL_TO_20_LENGTH_REQUIRED"
        );

        // Add offset to index:
        // 1. Arrays are prefixed by 32-byte length parameter (add 32 to index)
        // 2. Account for size difference between address length and 32-byte storage word (subtract 12 from index)
        index += 20;

        // Read address from array memory
        assembly {
            // 1. Add index to address of bytes array
            // 2. Load 32-byte word from memory
            // 3. Apply 20-byte mask to obtain address
            result := and(mload(add(b, index)), 0xffffffffffffffffffffffffffffffffffffffff)
        }
        return result;
    }

    /// @dev Writes an address into a specific position in a byte array.
    /// @param b Byte array to insert address into.
    /// @param index Index in byte array of address.
    /// @param input Address to put into byte array.
    function writeAddress(
        bytes memory b,
        uint256 index,
        address input
    ) internal pure {
        require(
            b.length >= index + 20, // 20 is length of address
            "GREATER_OR_EQUAL_TO_20_LENGTH_REQUIRED"
        );

        // Add offset to index:
        // 1. Arrays are prefixed by 32-byte length parameter (add 32 to index)
        // 2. Account for size difference between address length and 32-byte storage word (subtract 12 from index)
        index += 20;

        // Store address into array memory
        assembly {
            // The address occupies 20 bytes and mstore stores 32 bytes.
            // First fetch the 32-byte word where we'll be storing the address, then
            // apply a mask so we have only the bytes in the word that the address will not occupy.
            // Then combine these bytes with the address and store the 32 bytes back to memory with mstore.

            // 1. Add index to address of bytes array
            // 2. Load 32-byte word from memory
            // 3. Apply 12-byte mask to obtain extra bytes occupying word of memory where we'll store the address
            let neighbors := and(
                mload(add(b, index)),
                0xffffffffffffffffffffffff0000000000000000000000000000000000000000
            )

            // Make sure input address is clean.
            // (Solidity does not guarantee this)
            input := and(input, 0xffffffffffffffffffffffffffffffffffffffff)

            // Store the neighbors and address into memory
            mstore(add(b, index), xor(input, neighbors))
        }
    }

    /// @dev Reads a bytes32 value from a position in a byte array.
    /// @param b Byte array containing a bytes32 value.
    /// @param index Index in byte array of bytes32 value.
    /// @return result bytes32 value from byte array.
    function readBytes32(bytes memory b, uint256 index) internal pure returns (bytes32 result) {
        require(b.length >= index + 32, "GREATER_OR_EQUAL_TO_32_LENGTH_REQUIRED");

        // Arrays are prefixed by a 256 bit length parameter
        index += 32;

        // Read the bytes32 from array memory
        assembly {
            result := mload(add(b, index))
        }
        return result;
    }

    /// @dev Writes a bytes32 into a specific position in a byte array.
    /// @param b Byte array to insert <input> into.
    /// @param index Index in byte array of <input>.
    /// @param input bytes32 to put into byte array.
    function writeBytes32(
        bytes memory b,
        uint256 index,
        bytes32 input
    ) internal pure {
        require(b.length >= index + 32, "GREATER_OR_EQUAL_TO_32_LENGTH_REQUIRED");

        // Arrays are prefixed by a 256 bit length parameter
        index += 32;

        // Read the bytes32 from array memory
        assembly {
            mstore(add(b, index), input)
        }
    }

    /// @dev Reads a uint256 value from a position in a byte array.
    /// @param b Byte array containing a uint256 value.
    /// @param index Index in byte array of uint256 value.
    /// @return result uint256 value from byte array.
    function readUint256(bytes memory b, uint256 index) internal pure returns (uint256 result) {
        result = uint256(readBytes32(b, index));
        return result;
    }

    /// @dev Writes a uint256 into a specific position in a byte array.
    /// @param b Byte array to insert <input> into.
    /// @param index Index in byte array of <input>.
    /// @param input uint256 to put into byte array.
    function writeUint256(
        bytes memory b,
        uint256 index,
        uint256 input
    ) internal pure {
        writeBytes32(b, index, bytes32(input));
    }

    /// @dev Reads an unpadded bytes4 value from a position in a byte array.
    /// @param b Byte array containing a bytes4 value.
    /// @param index Index in byte array of bytes4 value.
    /// @return result bytes4 value from byte array.
    function readBytes4(bytes memory b, uint256 index) internal pure returns (bytes4 result) {
        require(b.length >= index + 4, "GREATER_OR_EQUAL_TO_4_LENGTH_REQUIRED");

        // Arrays are prefixed by a 32 byte length field
        index += 32;

        // Read the bytes4 from array memory
        assembly {
            result := mload(add(b, index))
            // Solidity does not require us to clean the trailing bytes.
            // We do it anyway
            result := and(result, 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000)
        }
        return result;
    }

    /// @dev Reads nested bytes from a specific position.
    /// @dev NOTE: the returned value overlaps with the input value.
    ///            Both should be treated as immutable.
    /// @param b Byte array containing nested bytes.
    /// @param index Index of nested bytes.
    /// @return result Nested bytes.
    function readBytesWithLength(bytes memory b, uint256 index) internal pure returns (bytes memory result) {
        // Read length of nested bytes
        uint256 nestedBytesLength = readUint256(b, index);
        index += 32;

        // Assert length of <b> is valid, given
        // length of nested bytes
        require(b.length >= index + nestedBytesLength, "GREATER_OR_EQUAL_TO_NESTED_BYTES_LENGTH_REQUIRED");

        // Return a pointer to the byte array as it exists inside `b`
        assembly {
            result := add(b, index)
        }
        return result;
    }

    /// @dev Inserts bytes at a specific position in a byte array.
    /// @param b Byte array to insert <input> into.
    /// @param index Index in byte array of <input>.
    /// @param input bytes to insert.
    function writeBytesWithLength(
        bytes memory b,
        uint256 index,
        bytes memory input
    ) internal pure {
        // Assert length of <b> is valid, given
        // length of input
        require(
            b.length >= index + 32 + input.length, // 32 bytes to store length
            "GREATER_OR_EQUAL_TO_NESTED_BYTES_LENGTH_REQUIRED"
        );

        // Copy <input> into <b>
        memCopy(
            b.contentAddress() + index,
            input.rawAddress(), // includes length of <input>
            input.length + 32 // +32 bytes to store <input> length
        );
    }

    /// @dev Performs a deep copy of a byte array onto another byte array of greater than or equal length.
    /// @param dest Byte array that will be overwritten with source bytes.
    /// @param source Byte array to copy onto dest bytes.
    function deepCopyBytes(bytes memory dest, bytes memory source) internal pure {
        uint256 sourceLen = source.length;
        // Dest length must be >= source length, or some bytes would not be copied.
        require(dest.length >= sourceLen, "GREATER_OR_EQUAL_TO_SOURCE_BYTES_LENGTH_REQUIRED");
        memCopy(dest.contentAddress(), source.contentAddress(), sourceLen);
    }
}

// SPDX-License-Identifier: MIT
/*

  Copyright 2019 ZeroEx Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity 0.6.12;

library LibEIP712 {
    // Hash of the EIP712 Domain Separator Schema
    // keccak256(abi.encodePacked(
    //     "EIP712Domain(",
    //     "string name,",
    //     "string version,",
    //     "uint256 chainId,",
    //     "address verifyingContract",
    //     ")"
    // ))
    bytes32 internal constant _EIP712_DOMAIN_SEPARATOR_SCHEMA_HASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    /// @dev Calculates a EIP712 domain separator.
    /// @param name The EIP712 domain name.
    /// @param version The EIP712 domain version.
    /// @param verifyingContract The EIP712 verifying contract.
    /// @return result EIP712 domain separator.
    function hashEIP712Domain(
        string memory name,
        string memory version,
        uint256 chainId,
        address verifyingContract
    ) internal pure returns (bytes32 result) {
        bytes32 schemaHash = _EIP712_DOMAIN_SEPARATOR_SCHEMA_HASH;

        // Assembly for more efficient computing:
        // keccak256(abi.encodePacked(
        //     _EIP712_DOMAIN_SEPARATOR_SCHEMA_HASH,
        //     keccak256(bytes(name)),
        //     keccak256(bytes(version)),
        //     chainId,
        //     uint256(verifyingContract)
        // ))

        assembly {
            // Calculate hashes of dynamic data
            let nameHash := keccak256(add(name, 32), mload(name))
            let versionHash := keccak256(add(version, 32), mload(version))

            // Load free memory pointer
            let memPtr := mload(64)

            // Store params in memory
            mstore(memPtr, schemaHash)
            mstore(add(memPtr, 32), nameHash)
            mstore(add(memPtr, 64), versionHash)
            mstore(add(memPtr, 96), chainId)
            mstore(add(memPtr, 128), verifyingContract)

            // Compute hash
            result := keccak256(memPtr, 160)
        }
        return result;
    }

    /// @dev Calculates EIP712 encoding for a hash struct with a given domain hash.
    /// @param eip712DomainHash Hash of the domain domain separator data, computed
    ///                         with getDomainHash().
    /// @param hashStruct The EIP712 hash struct.
    /// @return result EIP712 hash applied to the given EIP712 Domain.
    function hashEIP712Message(bytes32 eip712DomainHash, bytes32 hashStruct) internal pure returns (bytes32 result) {
        // Assembly for more efficient computing:
        // keccak256(abi.encodePacked(
        //     EIP191_HEADER,
        //     EIP712_DOMAIN_HASH,
        //     hashStruct
        // ));

        assembly {
            // Load free memory pointer
            let memPtr := mload(64)

            mstore(memPtr, 0x1901000000000000000000000000000000000000000000000000000000000000) // EIP191 header
            mstore(add(memPtr, 2), eip712DomainHash) // EIP712 domain hash
            mstore(add(memPtr, 34), hashStruct) // Hash of struct

            // Compute hash
            result := keccak256(memPtr, 66)
        }
        return result;
    }
}

// SPDX-License-Identifier: MIT
/*

  Copyright 2018 ZeroEx Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity 0.6.12;

import { LibEIP712 } from "./LibEIP712.sol";

library LibPermit {
    struct Permit {
        address spender; // Spender
        uint256 value; // Value
        uint256 nonce; // Nonce
        uint256 expiry; // Expiry
    }

    // Hash for the EIP712 LibPermit Schema
    //    bytes32 constant internal EIP712_PERMIT_SCHEMA_HASH = keccak256(abi.encodePacked(
    //        "Permit(",
    //        "address spender,",
    //        "uint256 value,",
    //        "uint256 nonce,",
    //        "uint256 expiry",
    //        ")"
    //    ));
    bytes32 internal constant EIP712_PERMIT_SCHEMA_HASH =
        0x58e19c95adc541dea238d3211d11e11e7def7d0c7fda4e10e0c45eb224ef2fb7;

    /// @dev Calculates Keccak-256 hash of the permit.
    /// @param permit The permit structure.
    /// @return permitHash Keccak-256 EIP712 hash of the permit.
    function getPermitHash(Permit memory permit, bytes32 eip712ExchangeDomainHash)
        internal
        pure
        returns (bytes32 permitHash)
    {
        permitHash = LibEIP712.hashEIP712Message(eip712ExchangeDomainHash, hashPermit(permit));
        return permitHash;
    }

    /// @dev Calculates EIP712 hash of the permit.
    /// @param permit The permit structure.
    /// @return result EIP712 hash of the permit.
    function hashPermit(Permit memory permit) internal pure returns (bytes32 result) {
        // Assembly for more efficiently computing:
        bytes32 schemaHash = EIP712_PERMIT_SCHEMA_HASH;

        assembly {
            // Assert permit offset (this is an internal error that should never be triggered)
            if lt(permit, 32) {
                invalid()
            }

            // Calculate memory addresses that will be swapped out before hashing
            let pos1 := sub(permit, 32)

            // Backup
            let temp1 := mload(pos1)

            // Hash in place
            mstore(pos1, schemaHash)
            result := keccak256(pos1, 160)

            // Restore
            mstore(pos1, temp1)
        }
        return result;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IInsuranceFund {
    function claimDDXFromInsuranceMining(address _claimant) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { SafeMath } from "openzeppelin-solidity/contracts/math/SafeMath.sol";
import { LibBytes } from "../libs/LibBytes.sol";
import { LibEIP712 } from "../libs/LibEIP712.sol";
import { LibPermit } from "../libs/LibPermit.sol";
import { SafeMath96 } from "../libs/SafeMath96.sol";
import { DIFundToken } from "./DIFundToken.sol";

/**
 * @title DIFundTokenFactory
 * @author DerivaDEX (Borrowed/inspired from Compound)
 * @notice This is the native token contract for DerivaDEX. It
 *         implements the ERC-20 standard, with additional
 *         functionality to efficiently handle the governance aspect of
 *         the DerivaDEX ecosystem.
 * @dev The contract makes use of some nonstandard types not seen in
 *      the ERC-20 standard. The DDX token makes frequent use of the
 *      uint96 data type, as opposed to the more standard uint256 type.
 *      Given the maintenance of arrays of balances, allowances, and
 *      voting checkpoints, this allows us to more efficiently pack
 *      data together, thereby resulting in cheaper transactions.
 */
contract DIFundTokenFactory {
    DIFundToken[] public diFundTokens;

    address public issuer;

    /**
     * @notice Construct a new DDX token
     */
    constructor(address _issuer) public {
        // Set issuer to deploying address
        issuer = _issuer;
    }

    function createNewDIFundToken(
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals
    ) external returns (address) {
        require(msg.sender == issuer, "DIFTF: unauthorized.");
        DIFundToken diFundToken = new DIFundToken(_name, _symbol, _decimals, issuer);
        diFundTokens.push(diFundToken);
        return address(diFundToken);
    }

    function getDIFundTokens() external view returns (DIFundToken[] memory) {
        return diFundTokens;
    }

    function getDIFundTokensLength() external view returns (uint256) {
        return diFundTokens.length;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { SafeMath } from "openzeppelin-solidity/contracts/math/SafeMath.sol";
import { LibBytes } from "../libs/LibBytes.sol";
import { LibEIP712 } from "../libs/LibEIP712.sol";
import { LibDelegation } from "../libs/LibDelegation.sol";
import { LibPermit } from "../libs/LibPermit.sol";
import { SafeMath96 } from "../libs/SafeMath96.sol";

/**
 * @title DDX
 * @author DerivaDEX (Borrowed/inspired from Compound)
 * @notice This is the native token contract for DerivaDEX. It
 *         implements the ERC-20 standard, with additional
 *         functionality to efficiently handle the governance aspect of
 *         the DerivaDEX ecosystem.
 * @dev The contract makes use of some nonstandard types not seen in
 *      the ERC-20 standard. The DDX token makes frequent use of the
 *      uint96 data type, as opposed to the more standard uint256 type.
 *      Given the maintenance of arrays of balances, allowances, and
 *      voting checkpoints, this allows us to more efficiently pack
 *      data together, thereby resulting in cheaper transactions.
 */
contract DDX {
    using SafeMath96 for uint96;
    using SafeMath for uint256;
    using LibBytes for bytes;

    /// @notice ERC20 token name for this token
    string public constant name = "DerivaDAO"; // solhint-disable-line const-name-snakecase

    /// @notice ERC20 token symbol for this token
    string public constant symbol = "DDX"; // solhint-disable-line const-name-snakecase

    /// @notice ERC20 token decimals for this token
    uint8 public constant decimals = 18; // solhint-disable-line const-name-snakecase

    /// @notice Version number for this token. Used for EIP712 hashing.
    string public constant version = "1"; // solhint-disable-line const-name-snakecase

    /// @notice Max number of tokens to be issued (100 million DDX)
    uint96 public constant MAX_SUPPLY = 100000000e18;

    /// @notice Total number of tokens in circulation (50 million DDX)
    uint96 public constant PRE_MINE_SUPPLY = 50000000e18;

    /// @notice Issued supply of tokens
    uint96 public issuedSupply;

    /// @notice Current total/circulating supply of tokens
    uint96 public totalSupply;

    /// @notice Whether ownership has been transferred to the DAO
    bool public ownershipTransferred;

    /// @notice Address authorized to issue/mint DDX tokens
    address public issuer;

    mapping(address => mapping(address => uint96)) internal allowances;

    mapping(address => uint96) internal balances;

    /// @notice A record of each accounts delegate
    mapping(address => address) public delegates;

    /// @notice A checkpoint for marking vote count from given block
    struct Checkpoint {
        uint32 id;
        uint96 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping(address => mapping(uint256 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping(address => uint256) public numCheckpoints;

    /// @notice A record of states for signing / validating signatures
    mapping(address => uint256) public nonces;

    /// @notice Emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice Emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint96 previousBalance, uint96 newBalance);

    /// @notice Emitted when transfer takes place
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when approval takes place
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /**
     * @notice Construct a new DDX token
     */
    constructor() public {
        // Set issuer to deploying address
        issuer = msg.sender;

        // Issue pre-mine token supply to deploying address and
        // set the issued and circulating supplies to pre-mine amount
        _transferTokensMint(msg.sender, PRE_MINE_SUPPLY);
    }

    /**
     * @notice Transfer ownership of DDX token from the deploying
     *         address to the DerivaDEX Proxy/DAO
     * @param _derivaDEXProxy DerivaDEX Proxy address
     */
    function transferOwnershipToDerivaDEXProxy(address _derivaDEXProxy) external {
        // Ensure deploying address is calling this, destination is not
        // the zero address, and that ownership has never been
        // transferred thus far
        require(msg.sender == issuer, "DDX: unauthorized transfer of ownership.");
        require(_derivaDEXProxy != address(0), "DDX: transferring to zero address.");
        require(!ownershipTransferred, "DDX: ownership already transferred.");

        // Set ownership transferred boolean flag and the new authorized
        // issuer
        ownershipTransferred = true;
        issuer = _derivaDEXProxy;
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param _spender The address of the account which may transfer tokens
     * @param _amount The number of tokens that are approved (2^256-1 means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(address _spender, uint256 _amount) external returns (bool) {
        require(_spender != address(0), "DDX: approve to the zero address.");

        // Convert amount to uint96
        uint96 amount;
        if (_amount == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_amount, "DDX: amount exceeds 96 bits.");
        }

        // Set allowance
        allowances[msg.sender][_spender] = amount;

        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     * Emits an {Approval} event indicating the updated allowance.
     * Requirements:
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address _spender, uint256 _addedValue) external returns (bool) {
        require(_spender != address(0), "DDX: approve to the zero address.");

        // Convert amount to uint96
        uint96 amount;
        if (_addedValue == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_addedValue, "DDX: amount exceeds 96 bits.");
        }

        // Increase allowance
        allowances[msg.sender][_spender] = allowances[msg.sender][_spender].add96(amount);

        emit Approval(msg.sender, _spender, allowances[msg.sender][_spender]);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     * Emits an {Approval} event indicating the updated allowance.
     * Requirements:
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address _spender, uint256 _subtractedValue) external returns (bool) {
        require(_spender != address(0), "DDX: approve to the zero address.");

        // Convert amount to uint96
        uint96 amount;
        if (_subtractedValue == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_subtractedValue, "DDX: amount exceeds 96 bits.");
        }

        // Decrease allowance
        allowances[msg.sender][_spender] = allowances[msg.sender][_spender].sub96(
            amount,
            "DDX: decreased allowance below zero."
        );

        emit Approval(msg.sender, _spender, allowances[msg.sender][_spender]);
        return true;
    }

    /**
     * @notice Get the number of tokens held by the `account`
     * @param _account The address of the account to get the balance of
     * @return The number of tokens held
     */
    function balanceOf(address _account) external view returns (uint256) {
        return balances[_account];
    }

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param _recipient The address of the destination account
     * @param _amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(address _recipient, uint256 _amount) external returns (bool) {
        // Convert amount to uint96
        uint96 amount;
        if (_amount == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_amount, "DDX: amount exceeds 96 bits.");
        }

        // Transfer tokens from sender to recipient
        _transferTokens(msg.sender, _recipient, amount);
        return true;
    }

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param _from The address of the source account
     * @param _recipient The address of the destination account
     * @param _amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(
        address _from,
        address _recipient,
        uint256 _amount
    ) external returns (bool) {
        uint96 spenderAllowance = allowances[_from][msg.sender];

        // Convert amount to uint96
        uint96 amount;
        if (_amount == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_amount, "DDX: amount exceeds 96 bits.");
        }

        if (msg.sender != _from && spenderAllowance != uint96(-1)) {
            // Tx sender is not the same as transfer sender and doesn't
            // have unlimited allowance.
            // Reduce allowance by amount being transferred
            uint96 newAllowance = spenderAllowance.sub96(amount);
            allowances[_from][msg.sender] = newAllowance;

            emit Approval(_from, msg.sender, newAllowance);
        }

        // Transfer tokens from sender to recipient
        _transferTokens(_from, _recipient, amount);
        return true;
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     *      the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function mint(address _recipient, uint256 _amount) external {
        require(msg.sender == issuer, "DDX: unauthorized mint.");

        // Convert amount to uint96
        uint96 amount;
        if (_amount == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_amount, "DDX: amount exceeds 96 bits.");
        }

        // Ensure the mint doesn't cause the issued supply to exceed
        // the total supply that could ever be issued
        require(issuedSupply.add96(amount) <= MAX_SUPPLY, "DDX: cap exceeded.");

        // Mint tokens to recipient
        _transferTokensMint(_recipient, amount);
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, decreasing
     *      the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function burn(uint256 _amount) external {
        // Convert amount to uint96
        uint96 amount;
        if (_amount == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_amount, "DDX: amount exceeds 96 bits.");
        }

        // Burn tokens from sender
        _transferTokensBurn(msg.sender, amount);
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     *      the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function burnFrom(address _account, uint256 _amount) external {
        uint96 spenderAllowance = allowances[_account][msg.sender];

        // Convert amount to uint96
        uint96 amount;
        if (_amount == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_amount, "DDX: amount exceeds 96 bits.");
        }

        if (msg.sender != _account && spenderAllowance != uint96(-1)) {
            // Tx sender is not the same as burn account and doesn't
            // have unlimited allowance.
            // Reduce allowance by amount being transferred
            uint96 newAllowance = spenderAllowance.sub96(amount, "DDX: burn amount exceeds allowance.");
            allowances[_account][msg.sender] = newAllowance;

            emit Approval(_account, msg.sender, newAllowance);
        }

        // Burn tokens from account
        _transferTokensBurn(_account, amount);
    }

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param _delegatee The address to delegate votes to
     */
    function delegate(address _delegatee) external {
        _delegate(msg.sender, _delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param _delegatee The address to delegate votes to
     * @param _nonce The contract state required to match the signature
     * @param _expiry The time at which to expire the signature
     * @param _signature Signature
     */
    function delegateBySig(
        address _delegatee,
        uint256 _nonce,
        uint256 _expiry,
        bytes memory _signature
    ) external {
        // Perform EIP712 hashing logic
        bytes32 eip712OrderParamsDomainHash = LibEIP712.hashEIP712Domain(name, version, getChainId(), address(this));
        bytes32 delegationHash =
            LibDelegation.getDelegationHash(
                LibDelegation.Delegation({ delegatee: _delegatee, nonce: _nonce, expiry: _expiry }),
                eip712OrderParamsDomainHash
            );

        // Perform sig recovery
        uint8 v = uint8(_signature[0]);
        bytes32 r = _signature.readBytes32(1);
        bytes32 s = _signature.readBytes32(33);
        address recovered = ecrecover(delegationHash, v, r, s);

        require(recovered != address(0), "DDX: invalid signature.");
        require(_nonce == nonces[recovered]++, "DDX: invalid nonce.");
        require(block.timestamp <= _expiry, "DDX: signature expired.");

        // Delegate votes from recovered address to delegatee
        _delegate(recovered, _delegatee);
    }

    /**
     * @notice Permits allowance from signatory to `spender`
     * @param _spender The spender being approved
     * @param _value The value being approved
     * @param _nonce The contract state required to match the signature
     * @param _expiry The time at which to expire the signature
     * @param _signature Signature
     */
    function permit(
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 _expiry,
        bytes memory _signature
    ) external {
        // Perform EIP712 hashing logic
        bytes32 eip712OrderParamsDomainHash = LibEIP712.hashEIP712Domain(name, version, getChainId(), address(this));
        bytes32 permitHash =
            LibPermit.getPermitHash(
                LibPermit.Permit({ spender: _spender, value: _value, nonce: _nonce, expiry: _expiry }),
                eip712OrderParamsDomainHash
            );

        // Perform sig recovery
        uint8 v = uint8(_signature[0]);
        bytes32 r = _signature.readBytes32(1);
        bytes32 s = _signature.readBytes32(33);

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
            revert("ECDSA: invalid signature 's' value");
        }

        if (v != 27 && v != 28) {
            revert("ECDSA: invalid signature 'v' value");
        }

        address recovered = ecrecover(permitHash, v, r, s);

        require(recovered != address(0), "DDX: invalid signature.");
        require(_nonce == nonces[recovered]++, "DDX: invalid nonce.");
        require(block.timestamp <= _expiry, "DDX: signature expired.");

        // Convert amount to uint96
        uint96 amount;
        if (_value == uint256(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(_value, "DDX: amount exceeds 96 bits.");
        }

        // Set allowance
        allowances[recovered][_spender] = amount;
        emit Approval(recovered, _spender, _value);
    }

    /**
     * @notice Get the number of tokens `spender` is approved to spend on behalf of `account`
     * @param _account The address of the account holding the funds
     * @param _spender The address of the account spending the funds
     * @return The number of tokens approved
     */
    function allowance(address _account, address _spender) external view returns (uint256) {
        return allowances[_account][_spender];
    }

    /**
     * @notice Gets the current votes balance.
     * @param _account The address to get votes balance.
     * @return The number of current votes.
     */
    function getCurrentVotes(address _account) external view returns (uint96) {
        uint256 numCheckpointsAccount = numCheckpoints[_account];
        return numCheckpointsAccount > 0 ? checkpoints[_account][numCheckpointsAccount - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param _account The address of the account to check
     * @param _blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address _account, uint256 _blockNumber) external view returns (uint96) {
        require(_blockNumber < block.number, "DDX: block not yet determined.");

        uint256 numCheckpointsAccount = numCheckpoints[_account];
        if (numCheckpointsAccount == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[_account][numCheckpointsAccount - 1].id <= _blockNumber) {
            return checkpoints[_account][numCheckpointsAccount - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[_account][0].id > _blockNumber) {
            return 0;
        }

        // Perform binary search to find the most recent token holdings
        // leading to a measure of voting power
        uint256 lower = 0;
        uint256 upper = numCheckpointsAccount - 1;
        while (upper > lower) {
            // ceil, avoiding overflow
            uint256 center = upper - (upper - lower) / 2;
            Checkpoint memory cp = checkpoints[_account][center];
            if (cp.id == _blockNumber) {
                return cp.votes;
            } else if (cp.id < _blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[_account][lower].votes;
    }

    function _delegate(address _delegator, address _delegatee) internal {
        // Get the current address delegator has delegated
        address currentDelegate = _getDelegatee(_delegator);

        // Get delegator's DDX balance
        uint96 delegatorBalance = balances[_delegator];

        // Set delegator's new delegatee address
        delegates[_delegator] = _delegatee;

        emit DelegateChanged(_delegator, currentDelegate, _delegatee);

        // Move votes from currently-delegated address to
        // new address
        _moveDelegates(currentDelegate, _delegatee, delegatorBalance);
    }

    function _transferTokens(
        address _spender,
        address _recipient,
        uint96 _amount
    ) internal {
        require(_spender != address(0), "DDX: cannot transfer from the zero address.");
        require(_recipient != address(0), "DDX: cannot transfer to the zero address.");

        // Reduce spender's balance and increase recipient balance
        balances[_spender] = balances[_spender].sub96(_amount);
        balances[_recipient] = balances[_recipient].add96(_amount);
        emit Transfer(_spender, _recipient, _amount);

        // Move votes from currently-delegated address to
        // recipient's delegated address
        _moveDelegates(_getDelegatee(_spender), _getDelegatee(_recipient), _amount);
    }

    function _transferTokensMint(address _recipient, uint96 _amount) internal {
        require(_recipient != address(0), "DDX: cannot transfer to the zero address.");

        // Add to recipient's balance
        balances[_recipient] = balances[_recipient].add96(_amount);

        // Increase the issued supply and circulating supply
        issuedSupply = issuedSupply.add96(_amount);
        totalSupply = totalSupply.add96(_amount);

        emit Transfer(address(0), _recipient, _amount);

        // Add delegates to recipient's delegated address
        _moveDelegates(address(0), _getDelegatee(_recipient), _amount);
    }

    function _transferTokensBurn(address _spender, uint96 _amount) internal {
        require(_spender != address(0), "DDX: cannot transfer from the zero address.");

        // Reduce the spender/burner's balance
        balances[_spender] = balances[_spender].sub96(_amount, "DDX: not enough balance to burn.");

        // Reduce the total supply
        totalSupply = totalSupply.sub96(_amount);
        emit Transfer(_spender, address(0), _amount);

        // MRedduce delegates from spender's delegated address
        _moveDelegates(_getDelegatee(_spender), address(0), _amount);
    }

    function _moveDelegates(
        address _initDel,
        address _finDel,
        uint96 _amount
    ) internal {
        if (_initDel != _finDel && _amount > 0) {
            // Initial delegated address is different than final
            // delegated address and nonzero number of votes moved
            if (_initDel != address(0)) {
                uint256 initDelNum = numCheckpoints[_initDel];

                // Retrieve and compute the old and new initial delegate
                // address' votes
                uint96 initDelOld = initDelNum > 0 ? checkpoints[_initDel][initDelNum - 1].votes : 0;
                uint96 initDelNew = initDelOld.sub96(_amount);
                _writeCheckpoint(_initDel, initDelOld, initDelNew);
            }

            if (_finDel != address(0)) {
                uint256 finDelNum = numCheckpoints[_finDel];

                // Retrieve and compute the old and new final delegate
                // address' votes
                uint96 finDelOld = finDelNum > 0 ? checkpoints[_finDel][finDelNum - 1].votes : 0;
                uint96 finDelNew = finDelOld.add96(_amount);
                _writeCheckpoint(_finDel, finDelOld, finDelNew);
            }
        }
    }

    function _writeCheckpoint(
        address _delegatee,
        uint96 _oldVotes,
        uint96 _newVotes
    ) internal {
        uint32 blockNumber = safe32(block.number, "DDX: exceeds 32 bits.");
        uint256 delNum = numCheckpoints[_delegatee];
        if (delNum > 0 && checkpoints[_delegatee][delNum - 1].id == blockNumber) {
            // If latest checkpoint is current block, edit in place
            checkpoints[_delegatee][delNum - 1].votes = _newVotes;
        } else {
            // Create a new id, vote pair
            checkpoints[_delegatee][delNum] = Checkpoint({ id: blockNumber, votes: _newVotes });
            numCheckpoints[_delegatee] = delNum.add(1);
        }

        emit DelegateVotesChanged(_delegatee, _oldVotes, _newVotes);
    }

    function _getDelegatee(address _delegator) internal view returns (address) {
        if (delegates[_delegator] == address(0)) {
            return _delegator;
        }
        return delegates[_delegator];
    }

    function safe32(uint256 n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function safe96(uint256 n, string memory errorMessage) internal pure returns (uint96) {
        require(n < 2**96, errorMessage);
        return uint96(n);
    }

    function getChainId() internal pure returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}

// SPDX-License-Identifier: MIT
/*

  Copyright 2018 ZeroEx Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity 0.6.12;

import { LibEIP712 } from "./LibEIP712.sol";

library LibDelegation {
    struct Delegation {
        address delegatee; // Delegatee
        uint256 nonce; // Nonce
        uint256 expiry; // Expiry
    }

    // Hash for the EIP712 OrderParams Schema
    //    bytes32 constant internal EIP712_DELEGATION_SCHEMA_HASH = keccak256(abi.encodePacked(
    //        "Delegation(",
    //        "address delegatee,",
    //        "uint256 nonce,",
    //        "uint256 expiry",
    //        ")"
    //    ));
    bytes32 internal constant EIP712_DELEGATION_SCHEMA_HASH =
        0xe48329057bfd03d55e49b547132e39cffd9c1820ad7b9d4c5307691425d15adf;

    /// @dev Calculates Keccak-256 hash of the delegation.
    /// @param delegation The delegation structure.
    /// @return delegationHash Keccak-256 EIP712 hash of the delegation.
    function getDelegationHash(Delegation memory delegation, bytes32 eip712ExchangeDomainHash)
        internal
        pure
        returns (bytes32 delegationHash)
    {
        delegationHash = LibEIP712.hashEIP712Message(eip712ExchangeDomainHash, hashDelegation(delegation));
        return delegationHash;
    }

    /// @dev Calculates EIP712 hash of the delegation.
    /// @param delegation The delegation structure.
    /// @return result EIP712 hash of the delegation.
    function hashDelegation(Delegation memory delegation) internal pure returns (bytes32 result) {
        // Assembly for more efficiently computing:
        bytes32 schemaHash = EIP712_DELEGATION_SCHEMA_HASH;

        assembly {
            // Assert delegation offset (this is an internal error that should never be triggered)
            if lt(delegation, 32) {
                invalid()
            }

            // Calculate memory addresses that will be swapped out before hashing
            let pos1 := sub(delegation, 32)

            // Backup
            let temp1 := mload(pos1)

            // Hash in place
            mstore(pos1, schemaHash)
            result := keccak256(pos1, 128)

            // Restore
            mstore(pos1, temp1)
        }
        return result;
    }
}

// SPDX-License-Identifier: MIT
/*

  Copyright 2018 ZeroEx Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity 0.6.12;

import { LibEIP712 } from "./LibEIP712.sol";

library LibVoteCast {
    struct VoteCast {
        uint128 proposalId; // Proposal ID
        bool support; // Support
    }

    // Hash for the EIP712 OrderParams Schema
    //    bytes32 constant internal EIP712_VOTE_CAST_SCHEMA_HASH = keccak256(abi.encodePacked(
    //        "VoteCast(",
    //        "uint128 proposalId,",
    //        "bool support",
    //        ")"
    //    ));
    bytes32 internal constant EIP712_VOTE_CAST_SCHEMA_HASH =
        0x4abb8ae9facc09d5584ac64f616551bfc03c3ac63e5c431132305bd9bc8f8246;

    /// @dev Calculates Keccak-256 hash of the vote cast.
    /// @param voteCast The vote cast structure.
    /// @return voteCastHash Keccak-256 EIP712 hash of the vote cast.
    function getVoteCastHash(VoteCast memory voteCast, bytes32 eip712ExchangeDomainHash)
        internal
        pure
        returns (bytes32 voteCastHash)
    {
        voteCastHash = LibEIP712.hashEIP712Message(eip712ExchangeDomainHash, hashVoteCast(voteCast));
        return voteCastHash;
    }

    /// @dev Calculates EIP712 hash of the vote cast.
    /// @param voteCast The vote cast structure.
    /// @return result EIP712 hash of the vote cast.
    function hashVoteCast(VoteCast memory voteCast) internal pure returns (bytes32 result) {
        // Assembly for more efficiently computing:
        bytes32 schemaHash = EIP712_VOTE_CAST_SCHEMA_HASH;

        assembly {
            // Assert vote cast offset (this is an internal error that should never be triggered)
            if lt(voteCast, 32) {
                invalid()
            }

            // Calculate memory addresses that will be swapped out before hashing
            let pos1 := sub(voteCast, 32)

            // Backup
            let temp1 := mload(pos1)

            // Hash in place
            mstore(pos1, schemaHash)
            result := keccak256(pos1, 96)

            // Restore
            mstore(pos1, temp1)
        }
        return result;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { SafeMath } from "openzeppelin-solidity/contracts/math/SafeMath.sol";
import { GovernanceDefs } from "../../libs/defs/GovernanceDefs.sol";
import { LibEIP712 } from "../../libs/LibEIP712.sol";
import { LibVoteCast } from "../../libs/LibVoteCast.sol";
import { LibBytes } from "../../libs/LibBytes.sol";
import { SafeMath32 } from "../../libs/SafeMath32.sol";
import { SafeMath96 } from "../../libs/SafeMath96.sol";
import { SafeMath128 } from "../../libs/SafeMath128.sol";
import { MathHelpers } from "../../libs/MathHelpers.sol";
import { LibDiamondStorageDerivaDEX } from "../../storage/LibDiamondStorageDerivaDEX.sol";
import { LibDiamondStorageGovernance } from "../../storage/LibDiamondStorageGovernance.sol";

/**
 * @title Governance
 * @author DerivaDEX (Borrowed/inspired from Compound)
 * @notice This is a facet to the DerivaDEX proxy contract that handles
 *         the logic pertaining to governance. The Diamond storage
 *         will only be affected when facet functions are called via
 *         the proxy contract, no checks are necessary.
 * @dev The Diamond storage will only be affected when facet functions
 *      are called via the proxy contract, no checks are necessary.
 */
contract Governance {
    using SafeMath32 for uint32;
    using SafeMath96 for uint96;
    using SafeMath128 for uint128;
    using SafeMath for uint256;
    using MathHelpers for uint96;
    using MathHelpers for uint256;
    using LibBytes for bytes;

    /// @notice name for this Governance contract
    string public constant name = "DDX Governance"; // solhint-disable-line const-name-snakecase

    /// @notice version for this Governance contract
    string public constant version = "1"; // solhint-disable-line const-name-snakecase

    /// @notice Emitted when a new proposal is created
    event ProposalCreated(
        uint128 indexed id,
        address indexed proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    /// @notice Emitted when a vote has been cast on a proposal
    event VoteCast(address indexed voter, uint128 indexed proposalId, bool support, uint96 votes);

    /// @notice Emitted when a proposal has been canceled
    event ProposalCanceled(uint128 indexed id);

    /// @notice Emitted when a proposal has been queued
    event ProposalQueued(uint128 indexed id, uint256 eta);

    /// @notice Emitted when a proposal has been executed
    event ProposalExecuted(uint128 indexed id);

    /// @notice Emitted when a proposal action has been canceled
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    /// @notice Emitted when a proposal action has been executed
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    /// @notice Emitted when a proposal action has been queued
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    /**
     * @notice Limits functions to only be called via governance.
     */
    modifier onlyAdmin {
        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();
        require(msg.sender == dsDerivaDEX.admin, "Governance: must be called by Governance admin.");
        _;
    }

    /**
     * @notice This function initializes the state with some critical
     *         information. This can only be called once and must be
     *         done via governance.
     * @dev This function is best called as a parameter to the
     *      diamond cut function. This is removed prior to the selectors
     *      being added to the diamond, meaning it cannot be called
     *      again.
     * @param _quorumVotes Minimum number of for votes required, even
     *        if there's a majority in favor.
     * @param _proposalThreshold Minimum DDX token holdings required
     *        to create a proposal
     * @param _proposalMaxOperations Max number of operations/actions a
     *        proposal can have
     * @param _votingDelay Number of blocks after a proposal is made
     *        that voting begins.
     * @param _votingPeriod Number of blocks voting will be held.
     * @param _skipRemainingVotingThreshold Number of for or against
     *        votes that are necessary to skip the remainder of the
     *        voting period.
     * @param _gracePeriod Period in which a successful proposal must be
     *        executed, otherwise will be expired.
     * @param _timelockDelay Time (s) in which a successful proposal
     *        must be in the queue before it can be executed.
     */
    function initialize(
        uint32 _proposalMaxOperations,
        uint32 _votingDelay,
        uint32 _votingPeriod,
        uint32 _gracePeriod,
        uint32 _timelockDelay,
        uint32 _quorumVotes,
        uint32 _proposalThreshold,
        uint32 _skipRemainingVotingThreshold
    ) external onlyAdmin {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();

        // Ensure state variable comparisons are valid
        requireValidSkipRemainingVotingThreshold(_skipRemainingVotingThreshold);
        requireSkipRemainingVotingThresholdGtQuorumVotes(_skipRemainingVotingThreshold, _quorumVotes);

        // Set initial variable values
        dsGovernance.proposalMaxOperations = _proposalMaxOperations;
        dsGovernance.votingDelay = _votingDelay;
        dsGovernance.votingPeriod = _votingPeriod;
        dsGovernance.gracePeriod = _gracePeriod;
        dsGovernance.timelockDelay = _timelockDelay;
        dsGovernance.quorumVotes = _quorumVotes;
        dsGovernance.proposalThreshold = _proposalThreshold;
        dsGovernance.skipRemainingVotingThreshold = _skipRemainingVotingThreshold;
        dsGovernance.fastPathFunctionSignatures["setIsPaused(bool)"] = true;
    }

    /**
     * @notice This function allows participants who have sufficient
     *         DDX holdings to create new proposals up for vote. The
     *         proposals contain the ordered lists of on-chain
     *         executable calldata.
     * @param _targets Addresses of contracts involved.
     * @param _values Values to be passed along with the calls.
     * @param _signatures Function signatures.
     * @param _calldatas Calldata passed to the function.
     * @param _description Text description of proposal.
     */
    function propose(
        address[] memory _targets,
        uint256[] memory _values,
        string[] memory _signatures,
        bytes[] memory _calldatas,
        string memory _description
    ) external returns (uint128) {
        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();

        // Ensure proposer has sufficient token holdings to propose
        require(
            dsDerivaDEX.ddxToken.getPriorVotes(msg.sender, block.number.sub(1)) >= getProposerThresholdCount(),
            "Governance: proposer votes below proposal threshold."
        );
        require(
            _targets.length == _values.length &&
                _targets.length == _signatures.length &&
                _targets.length == _calldatas.length,
            "Governance: proposal function information parity mismatch."
        );
        require(_targets.length != 0, "Governance: must provide actions.");
        require(_targets.length <= dsGovernance.proposalMaxOperations, "Governance: too many actions.");

        if (dsGovernance.latestProposalIds[msg.sender] != 0) {
            // Ensure proposer doesn't already have one active/pending
            GovernanceDefs.ProposalState proposersLatestProposalState =
                state(dsGovernance.latestProposalIds[msg.sender]);
            require(
                proposersLatestProposalState != GovernanceDefs.ProposalState.Active,
                "Governance: one live proposal per proposer, found an already active proposal."
            );
            require(
                proposersLatestProposalState != GovernanceDefs.ProposalState.Pending,
                "Governance: one live proposal per proposer, found an already pending proposal."
            );
        }

        // Proposal voting starts votingDelay after proposal is made
        uint256 startBlock = block.number.add(dsGovernance.votingDelay);

        // Increment count of proposals
        dsGovernance.proposalCount++;

        // Create new proposal struct and add to mapping
        GovernanceDefs.Proposal memory newProposal =
            GovernanceDefs.Proposal({
                id: dsGovernance.proposalCount,
                proposer: msg.sender,
                delay: getTimelockDelayForSignatures(_signatures),
                eta: 0,
                targets: _targets,
                values: _values,
                signatures: _signatures,
                calldatas: _calldatas,
                startBlock: startBlock,
                endBlock: startBlock.add(dsGovernance.votingPeriod),
                forVotes: 0,
                againstVotes: 0,
                canceled: false,
                executed: false
            });

        dsGovernance.proposals[newProposal.id] = newProposal;

        // Update proposer's latest proposal
        dsGovernance.latestProposalIds[newProposal.proposer] = newProposal.id;

        emit ProposalCreated(
            newProposal.id,
            msg.sender,
            _targets,
            _values,
            _signatures,
            _calldatas,
            startBlock,
            startBlock.add(dsGovernance.votingPeriod),
            _description
        );
        return newProposal.id;
    }

    /**
     * @notice This function allows any participant to queue a
     *         successful proposal for execution. Proposals are deemed
     *         successful if at any point the number of for votes has
     *         exceeded the skip remaining voting threshold or if there
     *         is a simple majority (and more for votes than the
     *         minimum quorum) at the end of voting.
     * @param _proposalId Proposal id.
     */
    function queue(uint128 _proposalId) external {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();

        // Ensure proposal has succeeded (i.e. it has either enough for
        // votes to skip the remainder of the voting period or the
        // voting period has ended and there is a simple majority in
        // favor and also above the quorum
        require(
            state(_proposalId) == GovernanceDefs.ProposalState.Succeeded,
            "Governance: proposal can only be queued if it is succeeded."
        );
        GovernanceDefs.Proposal storage proposal = dsGovernance.proposals[_proposalId];

        // Establish eta of execution, which is a number of seconds
        // after queuing at which point proposal can actually execute
        uint256 eta = block.timestamp.add(proposal.delay);
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            // Ensure proposal action is not already in the queue
            bytes32 txHash =
                keccak256(
                    abi.encode(
                        proposal.targets[i],
                        proposal.values[i],
                        proposal.signatures[i],
                        proposal.calldatas[i],
                        eta
                    )
                );
            require(!dsGovernance.queuedTransactions[txHash], "Governance: proposal action already queued at eta.");
            dsGovernance.queuedTransactions[txHash] = true;
            emit QueueTransaction(
                txHash,
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                eta
            );
        }
        // Set proposal eta timestamp after which it can be executed
        proposal.eta = eta;
        emit ProposalQueued(_proposalId, eta);
    }

    /**
     * @notice This function allows any participant to execute a
     *         queued proposal. A proposal in the queue must be in the
     *         queue for the delay period it was proposed with prior to
     *         executing, allowing the community to position itself
     *         accordingly.
     * @param _proposalId Proposal id.
     */
    function execute(uint128 _proposalId) external payable {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        // Ensure proposal is queued
        require(
            state(_proposalId) == GovernanceDefs.ProposalState.Queued,
            "Governance: proposal can only be executed if it is queued."
        );
        GovernanceDefs.Proposal storage proposal = dsGovernance.proposals[_proposalId];
        // Ensure proposal has been in the queue long enough
        require(block.timestamp >= proposal.eta, "Governance: proposal hasn't finished queue time length.");

        // Ensure proposal hasn't been in the queue for too long
        require(block.timestamp <= proposal.eta.add(dsGovernance.gracePeriod), "Governance: transaction is stale.");

        proposal.executed = true;

        // Loop through each of the actions in the proposal
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            bytes32 txHash =
                keccak256(
                    abi.encode(
                        proposal.targets[i],
                        proposal.values[i],
                        proposal.signatures[i],
                        proposal.calldatas[i],
                        proposal.eta
                    )
                );
            require(dsGovernance.queuedTransactions[txHash], "Governance: transaction hasn't been queued.");

            dsGovernance.queuedTransactions[txHash] = false;

            // Execute action
            bytes memory callData;
            require(bytes(proposal.signatures[i]).length != 0, "Governance: Invalid function signature.");
            callData = abi.encodePacked(bytes4(keccak256(bytes(proposal.signatures[i]))), proposal.calldatas[i]);
            // solium-disable-next-line security/no-call-value
            (bool success, ) = proposal.targets[i].call{ value: proposal.values[i] }(callData);

            require(success, "Governance: transaction execution reverted.");

            emit ExecuteTransaction(
                txHash,
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }
        emit ProposalExecuted(_proposalId);
    }

    /**
     * @notice This function allows any participant to cancel any non-
     *         executed proposal. It can be canceled if the proposer's
     *         token holdings has dipped below the proposal threshold
     *         at the time of cancellation.
     * @param _proposalId Proposal id.
     */
    function cancel(uint128 _proposalId) external {
        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        GovernanceDefs.ProposalState state = state(_proposalId);

        // Ensure proposal hasn't executed
        require(state != GovernanceDefs.ProposalState.Executed, "Governance: cannot cancel executed proposal.");

        GovernanceDefs.Proposal storage proposal = dsGovernance.proposals[_proposalId];

        // Ensure proposer's token holdings has dipped below the
        // proposer threshold, leaving their proposal subject to
        // cancellation
        require(
            dsDerivaDEX.ddxToken.getPriorVotes(proposal.proposer, block.number.sub(1)) < getProposerThresholdCount(),
            "Governance: proposer above threshold."
        );

        proposal.canceled = true;

        // Loop through each of the proposal's actions
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            bytes32 txHash =
                keccak256(
                    abi.encode(
                        proposal.targets[i],
                        proposal.values[i],
                        proposal.signatures[i],
                        proposal.calldatas[i],
                        proposal.eta
                    )
                );
            dsGovernance.queuedTransactions[txHash] = false;
            emit CancelTransaction(
                txHash,
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }

        emit ProposalCanceled(_proposalId);
    }

    /**
     * @notice This function allows participants to cast either in
     *         favor or against a particular proposal.
     * @param _proposalId Proposal id.
     * @param _support In favor (true) or against (false).
     */
    function castVote(uint128 _proposalId, bool _support) external {
        return _castVote(msg.sender, _proposalId, _support);
    }

    /**
     * @notice This function allows participants to cast votes with
     *         offline signatures in favor or against a particular
     *         proposal.
     * @param _proposalId Proposal id.
     * @param _support In favor (true) or against (false).
     * @param _signature Signature
     */
    function castVoteBySig(
        uint128 _proposalId,
        bool _support,
        bytes memory _signature
    ) external {
        // EIP712 hashing logic
        bytes32 eip712OrderParamsDomainHash = LibEIP712.hashEIP712Domain(name, version, getChainId(), address(this));
        bytes32 voteCastHash =
            LibVoteCast.getVoteCastHash(
                LibVoteCast.VoteCast({ proposalId: _proposalId, support: _support }),
                eip712OrderParamsDomainHash
            );

        // Recover the signature and EIP712 hash
        uint8 v = uint8(_signature[0]);
        bytes32 r = _signature.readBytes32(1);
        bytes32 s = _signature.readBytes32(33);
        address recovered = ecrecover(voteCastHash, v, r, s);

        require(recovered != address(0), "Governance: invalid signature.");
        return _castVote(recovered, _proposalId, _support);
    }

    /**
     * @notice This function sets the quorum votes required for a
     *         proposal to pass. It must be called via
     *         governance.
     * @param _quorumVotes Quorum votes threshold.
     */
    function setQuorumVotes(uint32 _quorumVotes) external onlyAdmin {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        requireSkipRemainingVotingThresholdGtQuorumVotes(dsGovernance.skipRemainingVotingThreshold, _quorumVotes);
        dsGovernance.quorumVotes = _quorumVotes;
    }

    /**
     * @notice This function sets the token holdings threshold required
     *         to propose something. It must be called via
     *         governance.
     * @param _proposalThreshold Proposal threshold.
     */
    function setProposalThreshold(uint32 _proposalThreshold) external onlyAdmin {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        dsGovernance.proposalThreshold = _proposalThreshold;
    }

    /**
     * @notice This function sets the max operations a proposal can
     *         carry out. It must be called via governance.
     * @param _proposalMaxOperations Proposal's max operations.
     */
    function setProposalMaxOperations(uint32 _proposalMaxOperations) external onlyAdmin {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        dsGovernance.proposalMaxOperations = _proposalMaxOperations;
    }

    /**
     * @notice This function sets the voting delay in blocks from when
     *         a proposal is made and voting begins. It must be called
     *         via governance.
     * @param _votingDelay Voting delay (blocks).
     */
    function setVotingDelay(uint32 _votingDelay) external onlyAdmin {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        dsGovernance.votingDelay = _votingDelay;
    }

    /**
     * @notice This function sets the voting period in blocks that a
     *         vote will last. It must be called via
     *         governance.
     * @param _votingPeriod Voting period (blocks).
     */
    function setVotingPeriod(uint32 _votingPeriod) external onlyAdmin {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        dsGovernance.votingPeriod = _votingPeriod;
    }

    /**
     * @notice This function sets the threshold at which a proposal can
     *         immediately be deemed successful or rejected if the for
     *         or against votes exceeds this threshold, even if the
     *         voting period is still ongoing. It must be called
     *         governance.
     * @param _skipRemainingVotingThreshold Threshold for or against
     *        votes must reach to skip remainder of voting period.
     */
    function setSkipRemainingVotingThreshold(uint32 _skipRemainingVotingThreshold) external onlyAdmin {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        requireValidSkipRemainingVotingThreshold(_skipRemainingVotingThreshold);
        requireSkipRemainingVotingThresholdGtQuorumVotes(_skipRemainingVotingThreshold, dsGovernance.quorumVotes);
        dsGovernance.skipRemainingVotingThreshold = _skipRemainingVotingThreshold;
    }

    /**
     * @notice This function sets the grace period in seconds that a
     *         queued proposal can last before expiring. It must be
     *         called via governance.
     * @param _gracePeriod Grace period (seconds).
     */
    function setGracePeriod(uint32 _gracePeriod) external onlyAdmin {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        dsGovernance.gracePeriod = _gracePeriod;
    }

    /**
     * @notice This function sets the timelock delay (s) a proposal
     *         must be queued before execution.
     * @param _timelockDelay Timelock delay (seconds).
     */
    function setTimelockDelay(uint32 _timelockDelay) external onlyAdmin {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        dsGovernance.timelockDelay = _timelockDelay;
    }

    /**
     * @notice This function allows any participant to retrieve
     *         the actions involved in a given proposal.
     * @param _proposalId Proposal id.
     * @return targets Addresses of contracts involved.
     * @return values Values to be passed along with the calls.
     * @return signatures Function signatures.
     * @return calldatas Calldata passed to the function.
     */
    function getActions(uint128 _proposalId)
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        )
    {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        GovernanceDefs.Proposal storage p = dsGovernance.proposals[_proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    /**
     * @notice This function allows any participant to retrieve
     *         the receipt for a given proposal and voter.
     * @param _proposalId Proposal id.
     * @param _voter Voter address.
     * @return Voter receipt.
     */
    function getReceipt(uint128 _proposalId, address _voter) external view returns (GovernanceDefs.Receipt memory) {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        return dsGovernance.proposals[_proposalId].receipts[_voter];
    }

    /**
     * @notice This function gets a proposal from an ID.
     * @param _proposalId Proposal id.
     * @return Proposal attributes.
     */
    function getProposal(uint128 _proposalId)
        external
        view
        returns (
            bool,
            bool,
            address,
            uint32,
            uint96,
            uint96,
            uint128,
            uint256,
            uint256,
            uint256
        )
    {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        GovernanceDefs.Proposal memory proposal = dsGovernance.proposals[_proposalId];
        return (
            proposal.canceled,
            proposal.executed,
            proposal.proposer,
            proposal.delay,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.id,
            proposal.eta,
            proposal.startBlock,
            proposal.endBlock
        );
    }

    /**
     * @notice This function gets whether a proposal action transaction
     *         hash is queued or not.
     * @param _txHash Proposal action tx hash.
     * @return Is proposal action transaction hash queued or not.
     */
    function getIsQueuedTransaction(bytes32 _txHash) external view returns (bool) {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        return dsGovernance.queuedTransactions[_txHash];
    }

    /**
     * @notice This function gets the Governance facet's current
     *         parameters.
     * @return Proposal max operations.
     * @return Voting delay.
     * @return Voting period.
     * @return Grace period.
     * @return Timelock delay.
     * @return Quorum votes threshold.
     * @return Proposal threshold.
     * @return Skip remaining voting threshold.
     */
    function getGovernanceParameters()
        external
        view
        returns (
            uint32,
            uint32,
            uint32,
            uint32,
            uint32,
            uint32,
            uint32,
            uint32
        )
    {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        return (
            dsGovernance.proposalMaxOperations,
            dsGovernance.votingDelay,
            dsGovernance.votingPeriod,
            dsGovernance.gracePeriod,
            dsGovernance.timelockDelay,
            dsGovernance.quorumVotes,
            dsGovernance.proposalThreshold,
            dsGovernance.skipRemainingVotingThreshold
        );
    }

    /**
     * @notice This function gets the proposal count.
     * @return Proposal count.
     */
    function getProposalCount() external view returns (uint128) {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        return dsGovernance.proposalCount;
    }

    /**
     * @notice This function gets the latest proposal ID for a user.
     * @param _proposer Proposer's address.
     * @return Proposal ID.
     */
    function getLatestProposalId(address _proposer) external view returns (uint128) {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        return dsGovernance.latestProposalIds[_proposer];
    }

    /**
     * @notice This function gets the quorum vote count given the
     *         quorum vote percentage relative to the total DDX supply.
     * @return Quorum vote count.
     */
    function getQuorumVoteCount() public view returns (uint96) {
        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();

        uint96 totalSupply = dsDerivaDEX.ddxToken.totalSupply().safe96("Governance: amount exceeds 96 bits");
        return totalSupply.proportion96(dsGovernance.quorumVotes, 100);
    }

    /**
     * @notice This function gets the quorum vote count given the
     *         quorum vote percentage relative to the total DDX supply.
     * @return Quorum vote count.
     */
    function getProposerThresholdCount() public view returns (uint96) {
        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();

        uint96 totalSupply = dsDerivaDEX.ddxToken.totalSupply().safe96("Governance: amount exceeds 96 bits");
        return totalSupply.proportion96(dsGovernance.proposalThreshold, 100);
    }

    /**
     * @notice This function gets the quorum vote count given the
     *         quorum vote percentage relative to the total DDX supply.
     * @return Quorum vote count.
     */
    function getSkipRemainingVotingThresholdCount() public view returns (uint96) {
        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();

        uint96 totalSupply = dsDerivaDEX.ddxToken.totalSupply().safe96("Governance: amount exceeds 96 bits");
        return totalSupply.proportion96(dsGovernance.skipRemainingVotingThreshold, 100);
    }

    /**
     * @notice This function retrieves the status for any given
     *         proposal.
     * @param _proposalId Proposal id.
     * @return Status of proposal.
     */
    function state(uint128 _proposalId) public view returns (GovernanceDefs.ProposalState) {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        require(dsGovernance.proposalCount >= _proposalId && _proposalId > 0, "Governance: invalid proposal id.");
        GovernanceDefs.Proposal storage proposal = dsGovernance.proposals[_proposalId];

        // Note the 3rd conditional where we can escape out of the vote
        // phase if the for or against votes exceeds the skip remaining
        // voting threshold
        if (proposal.canceled) {
            return GovernanceDefs.ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return GovernanceDefs.ProposalState.Pending;
        } else if (
            (block.number <= proposal.endBlock) &&
            (proposal.forVotes < getSkipRemainingVotingThresholdCount()) &&
            (proposal.againstVotes < getSkipRemainingVotingThresholdCount())
        ) {
            return GovernanceDefs.ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < getQuorumVoteCount()) {
            return GovernanceDefs.ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return GovernanceDefs.ProposalState.Succeeded;
        } else if (proposal.executed) {
            return GovernanceDefs.ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta.add(dsGovernance.gracePeriod)) {
            return GovernanceDefs.ProposalState.Expired;
        } else {
            return GovernanceDefs.ProposalState.Queued;
        }
    }

    function _castVote(
        address _voter,
        uint128 _proposalId,
        bool _support
    ) internal {
        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();
        require(state(_proposalId) == GovernanceDefs.ProposalState.Active, "Governance: voting is closed.");
        GovernanceDefs.Proposal storage proposal = dsGovernance.proposals[_proposalId];
        GovernanceDefs.Receipt storage receipt = proposal.receipts[_voter];

        // Ensure voter has not already voted
        require(!receipt.hasVoted, "Governance: voter already voted.");

        // Obtain the token holdings (voting power) for participant at
        // the time voting started. They may have gained or lost tokens
        // since then, doesn't matter.
        uint96 votes = dsDerivaDEX.ddxToken.getPriorVotes(_voter, proposal.startBlock);

        // Ensure voter has nonzero voting power
        require(votes > 0, "Governance: voter has no voting power.");
        if (_support) {
            // Increment the for votes in favor
            proposal.forVotes = proposal.forVotes.add96(votes);
        } else {
            // Increment the against votes
            proposal.againstVotes = proposal.againstVotes.add96(votes);
        }

        // Set receipt attributes based on cast vote parameters
        receipt.hasVoted = true;
        receipt.support = _support;
        receipt.votes = votes;

        emit VoteCast(_voter, _proposalId, _support, votes);
    }

    function getTimelockDelayForSignatures(string[] memory _signatures) internal view returns (uint32) {
        LibDiamondStorageGovernance.DiamondStorageGovernance storage dsGovernance =
            LibDiamondStorageGovernance.diamondStorageGovernance();

        for (uint256 i = 0; i < _signatures.length; i++) {
            if (!dsGovernance.fastPathFunctionSignatures[_signatures[i]]) {
                return dsGovernance.timelockDelay;
            }
        }
        return 1;
    }

    function requireSkipRemainingVotingThresholdGtQuorumVotes(uint32 _skipRemainingVotingThreshold, uint32 _quorumVotes)
        internal
        pure
    {
        require(_skipRemainingVotingThreshold > _quorumVotes, "Governance: skip rem votes must be higher than quorum.");
    }

    function requireValidSkipRemainingVotingThreshold(uint32 _skipRemainingVotingThreshold) internal pure {
        require(_skipRemainingVotingThreshold >= 50, "Governance: skip rem votes must be higher than 50pct.");
    }

    function getChainId() internal pure returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/**
 * @title GovernanceDefs
 * @author DerivaDEX
 *
 * This library contains the common structs and enums pertaining to
 * the governance.
 */
library GovernanceDefs {
    struct Proposal {
        bool canceled;
        bool executed;
        address proposer;
        uint32 delay;
        uint96 forVotes;
        uint96 againstVotes;
        uint128 id;
        uint256 eta;
        address[] targets;
        string[] signatures;
        bytes[] calldatas;
        uint256[] values;
        uint256 startBlock;
        uint256 endBlock;
        mapping(address => Receipt) receipts;
    }

    struct Receipt {
        bool hasVoted;
        bool support;
        uint96 votes;
    }

    enum ProposalState { Pending, Active, Canceled, Defeated, Succeeded, Queued, Expired, Executed }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

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
library SafeMath128 {
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
    function add(uint128 a, uint128 b) internal pure returns (uint128) {
        uint128 c = a + b;
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
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint128 a, uint128 b) internal pure returns (uint128) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint128 a,
        uint128 b,
        string memory errorMessage
    ) internal pure returns (uint128) {
        require(b <= a, errorMessage);
        uint128 c = a - b;

        return c;
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
    function mul(uint128 a, uint128 b) internal pure returns (uint128) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint128 c = a * b;
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
     *
     * - The divisor cannot be zero.
     */
    function div(uint128 a, uint128 b) internal pure returns (uint128) {
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
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint128 a,
        uint128 b,
        string memory errorMessage
    ) internal pure returns (uint128) {
        require(b > 0, errorMessage);
        uint128 c = a / b;
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
     *
     * - The divisor cannot be zero.
     */
    function mod(uint128 a, uint128 b) internal pure returns (uint128) {
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
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint128 a,
        uint128 b,
        string memory errorMessage
    ) internal pure returns (uint128) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { GovernanceDefs } from "../libs/defs/GovernanceDefs.sol";

library LibDiamondStorageGovernance {
    struct DiamondStorageGovernance {
        // Proposal struct by ID
        mapping(uint256 => GovernanceDefs.Proposal) proposals;
        // Latest proposal IDs by proposer address
        mapping(address => uint128) latestProposalIds;
        // Whether transaction hash is currently queued
        mapping(bytes32 => bool) queuedTransactions;
        // Fast path for governance
        mapping(string => bool) fastPathFunctionSignatures;
        // Max number of operations/actions a proposal can have
        uint32 proposalMaxOperations;
        // Number of blocks after a proposal is made that voting begins
        // (e.g. 1 block)
        uint32 votingDelay;
        // Number of blocks voting will be held
        // (e.g. 17280 blocks ~ 3 days of blocks)
        uint32 votingPeriod;
        // Time window (s) a successful proposal must be executed,
        // otherwise will be expired, measured in seconds
        // (e.g. 1209600 seconds)
        uint32 gracePeriod;
        // Minimum time (s) in which a successful proposal must be
        // in the queue before it can be executed
        // (e.g. 0 seconds)
        uint32 minimumDelay;
        // Maximum time (s) in which a successful proposal must be
        // in the queue before it can be executed
        // (e.g. 2592000 seconds ~ 30 days)
        uint32 maximumDelay;
        // Minimum number of for votes required, even if there's a
        // majority in favor
        // (e.g. 2000000e18 ~ 4% of pre-mine DDX supply)
        uint32 quorumVotes;
        // Minimum DDX token holdings required to create a proposal
        // (e.g. 500000e18 ~ 1% of pre-mine DDX supply)
        uint32 proposalThreshold;
        // Number of for or against votes that are necessary to skip
        // the remainder of the voting period
        // (e.g. 25000000e18 tokens/votes)
        uint32 skipRemainingVotingThreshold;
        // Time (s) proposals must be queued before executing
        uint32 timelockDelay;
        // Total number of proposals
        uint128 proposalCount;
    }

    bytes32 constant DIAMOND_STORAGE_POSITION_GOVERNANCE =
        keccak256("diamond.standard.diamond.storage.DerivaDEX.Governance");

    function diamondStorageGovernance() internal pure returns (DiamondStorageGovernance storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION_GOVERNANCE;
        assembly {
            ds_slot := position
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { LibDiamondStorageDerivaDEX } from "../../storage/LibDiamondStorageDerivaDEX.sol";
import { LibDiamondStoragePause } from "../../storage/LibDiamondStoragePause.sol";

/**
 * @title Pause
 * @author DerivaDEX
 * @notice This is a facet to the DerivaDEX proxy contract that handles
 *         the logic pertaining to pausing functionality. The purpose
 *         of this is to ensure the system can pause in the unlikely
 *         scenario of a bug or issue materially jeopardizing users'
 *         funds or experience. This facet will be removed entirely
 *         as the system stabilizes shortly. It's important to note that
 *         unlike the vast majority of projects, even during this
 *         short-lived period of time in which the system can be paused,
 *         no single admin address can wield this power, but rather
 *         pausing must be carried out via governance.
 */
contract Pause {
    event PauseInitialized();

    event IsPausedSet(bool isPaused);

    /**
     * @notice Limits functions to only be called via governance.
     */
    modifier onlyAdmin {
        LibDiamondStorageDerivaDEX.DiamondStorageDerivaDEX storage dsDerivaDEX =
            LibDiamondStorageDerivaDEX.diamondStorageDerivaDEX();
        require(msg.sender == dsDerivaDEX.admin, "Pause: must be called by Gov.");
        _;
    }

    /**
     * @notice This function initializes the facet.
     */
    function initialize() external onlyAdmin {
        emit PauseInitialized();
    }

    /**
     * @notice This function sets the paused status.
     * @param _isPaused Whether contracts are paused or not.
     */
    function setIsPaused(bool _isPaused) external onlyAdmin {
        LibDiamondStoragePause.DiamondStoragePause storage dsPause = LibDiamondStoragePause.diamondStoragePause();

        dsPause.isPaused = _isPaused;

        emit IsPausedSet(_isPaused);
    }

    /**
     * @notice This function gets whether the contract ecosystem is
     *         currently paused.
     * @return Whether contracts are paused or not.
     */
    function getIsPaused() public view returns (bool) {
        LibDiamondStoragePause.DiamondStoragePause storage dsPause = LibDiamondStoragePause.diamondStoragePause();

        return dsPause.isPaused;
    }
}

// SPDX-License-Identifier: MIT
/**
 *Submitted for verification at Etherscan.io on 2019-07-18
 */

pragma solidity 0.6.12;

import { SafeMath } from "openzeppelin-solidity/contracts/math/SafeMath.sol";
import { Ownable } from "openzeppelin-solidity/contracts/access/Ownable.sol";
import { IERC20 } from "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

library Roles {
    struct Role {
        mapping(address => bool) bearer;
    }

    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}

contract PauserRole is Ownable {
    using Roles for Roles.Role;

    Roles.Role private _pausers;

    event PauserAdded(address indexed account);

    event PauserRemoved(address indexed account);

    constructor() internal {
        _addPauser(msg.sender);
    }

    modifier onlyPauser() {
        require(isPauser(msg.sender), "PauserRole: caller does not have the Pauser role");
        _;
    }

    function isPauser(address account) public view returns (bool) {
        return _pausers.has(account);
    }

    function addPauser(address account) public onlyOwner {
        _addPauser(account);
    }

    function removePauser(address account) public onlyOwner {
        _removePauser(account);
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

contract Pausable is PauserRole {
    bool private _paused;

    event Paused(address account);

    event Unpaused(address account);

    constructor() internal {
        _paused = false;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    function pause() public onlyPauser whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyPauser whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

contract ERC20 is IERC20, Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    event Issue(address indexed account, uint256 amount);

    event Redeem(address indexed account, uint256 value);

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public virtual override returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _issue(address account, uint256 amount) internal {
        require(account != address(0), "CoinFactory: issue to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
        emit Issue(account, amount);
    }

    function _redeem(address account, uint256 value) internal {
        require(account != address(0), "CoinFactory: redeem from the zero address");

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
        emit Redeem(account, value);
    }
}

contract ERC20Pausable is ERC20, Pausable {
    function transfer(address to, uint256 value) public virtual override whenNotPaused returns (bool) {
        return super.transfer(to, value);
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual override whenNotPaused returns (bool) {
        return super.transferFrom(from, to, value);
    }

    function approve(address spender, uint256 value) public virtual override whenNotPaused returns (bool) {
        return super.approve(spender, value);
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        return super.increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        return super.decreaseAllowance(spender, subtractedValue);
    }
}

contract CoinFactoryAdminRole is Ownable {
    using Roles for Roles.Role;

    event CoinFactoryAdminRoleAdded(address indexed account);

    event CoinFactoryAdminRoleRemoved(address indexed account);

    Roles.Role private _coinFactoryAdmins;

    constructor() internal {
        _addCoinFactoryAdmin(msg.sender);
    }

    modifier onlyCoinFactoryAdmin() {
        require(isCoinFactoryAdmin(msg.sender), "CoinFactoryAdminRole: caller does not have the CoinFactoryAdmin role");
        _;
    }

    function isCoinFactoryAdmin(address account) public view returns (bool) {
        return _coinFactoryAdmins.has(account);
    }

    function addCoinFactoryAdmin(address account) public onlyOwner {
        _addCoinFactoryAdmin(account);
    }

    function removeCoinFactoryAdmin(address account) public onlyOwner {
        _removeCoinFactoryAdmin(account);
    }

    function renounceCoinFactoryAdmin() public {
        _removeCoinFactoryAdmin(msg.sender);
    }

    function _addCoinFactoryAdmin(address account) internal {
        _coinFactoryAdmins.add(account);
        emit CoinFactoryAdminRoleAdded(account);
    }

    function _removeCoinFactoryAdmin(address account) internal {
        _coinFactoryAdmins.remove(account);
        emit CoinFactoryAdminRoleRemoved(account);
    }
}

contract CoinFactory is ERC20, CoinFactoryAdminRole {
    function issue(address account, uint256 amount) public onlyCoinFactoryAdmin returns (bool) {
        _issue(account, amount);
        return true;
    }

    function redeem(address account, uint256 amount) public onlyCoinFactoryAdmin returns (bool) {
        _redeem(account, amount);
        return true;
    }
}

contract BlacklistAdminRole is Ownable {
    using Roles for Roles.Role;

    event BlacklistAdminAdded(address indexed account);
    event BlacklistAdminRemoved(address indexed account);

    Roles.Role private _blacklistAdmins;

    constructor() internal {
        _addBlacklistAdmin(msg.sender);
    }

    modifier onlyBlacklistAdmin() {
        require(isBlacklistAdmin(msg.sender), "BlacklistAdminRole: caller does not have the BlacklistAdmin role");
        _;
    }

    function isBlacklistAdmin(address account) public view returns (bool) {
        return _blacklistAdmins.has(account);
    }

    function addBlacklistAdmin(address account) public onlyOwner {
        _addBlacklistAdmin(account);
    }

    function removeBlacklistAdmin(address account) public onlyOwner {
        _removeBlacklistAdmin(account);
    }

    function renounceBlacklistAdmin() public {
        _removeBlacklistAdmin(msg.sender);
    }

    function _addBlacklistAdmin(address account) internal {
        _blacklistAdmins.add(account);
        emit BlacklistAdminAdded(account);
    }

    function _removeBlacklistAdmin(address account) internal {
        _blacklistAdmins.remove(account);
        emit BlacklistAdminRemoved(account);
    }
}

contract Blacklist is ERC20, BlacklistAdminRole {
    mapping(address => bool) private _blacklist;

    event BlacklistAdded(address indexed account);

    event BlacklistRemoved(address indexed account);

    function addBlacklist(address[] memory accounts) public onlyBlacklistAdmin returns (bool) {
        for (uint256 i = 0; i < accounts.length; i++) {
            _addBlacklist(accounts[i]);
        }
    }

    function removeBlacklist(address[] memory accounts) public onlyBlacklistAdmin returns (bool) {
        for (uint256 i = 0; i < accounts.length; i++) {
            _removeBlacklist(accounts[i]);
        }
    }

    function isBlacklist(address account) public view returns (bool) {
        return _blacklist[account];
    }

    function _addBlacklist(address account) internal {
        _blacklist[account] = true;
        emit BlacklistAdded(account);
    }

    function _removeBlacklist(address account) internal {
        _blacklist[account] = false;
        emit BlacklistRemoved(account);
    }
}

contract HDUMToken is ERC20, ERC20Pausable, CoinFactory, Blacklist {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 private _totalSupply;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) public {
        _totalSupply = 0;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function transfer(address to, uint256 value) public override(ERC20, ERC20Pausable) whenNotPaused returns (bool) {
        require(!isBlacklist(msg.sender), "HDUMToken: caller in blacklist can't transfer");
        require(!isBlacklist(to), "HDUMToken: not allow to transfer to recipient address in blacklist");
        return super.transfer(to, value);
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override(ERC20, ERC20Pausable) whenNotPaused returns (bool) {
        require(!isBlacklist(msg.sender), "HDUMToken: caller in blacklist can't transferFrom");
        require(!isBlacklist(from), "HDUMToken: from in blacklist can't transfer");
        require(!isBlacklist(to), "HDUMToken: not allow to transfer to recipient address in blacklist");
        return super.transferFrom(from, to, value);
    }

    function approve(address spender, uint256 value) public virtual override(ERC20, ERC20Pausable) returns (bool) {
        return super.approve(spender, value);
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        override(ERC20, ERC20Pausable)
        returns (bool)
    {
        return super.increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        override(ERC20, ERC20Pausable)
        returns (bool)
    {
        return super.decreaseAllowance(spender, subtractedValue);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../GSN/Context.sol";
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
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

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
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import { Context } from "openzeppelin-solidity/contracts/GSN/Context.sol";
import { IERC20 } from "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

contract SafeERC20Wrapper is Context {
    using SafeERC20 for IERC20;

    IERC20 private _token;

    constructor(IERC20 token) public {
        _token = token;
    }

    function transfer(address recipient, uint256 amount) public {
        _token.safeTransfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public {
        _token.safeTransferFrom(sender, recipient, amount);
    }

    function approve(address spender, uint256 amount) public {
        _token.safeApprove(spender, amount);
    }

    function increaseAllowance(address spender, uint256 amount) public {
        _token.safeIncreaseAllowance(spender, amount);
    }

    function decreaseAllowance(address spender, uint256 amount) public {
        _token.safeDecreaseAllowance(spender, amount);
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _token.allowance(owner, spender);
    }

    function balanceOf(address account) public view returns (uint256) {
        return _token.balanceOf(account);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../../GSN/Context.sol";
import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
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
    using Address for address;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name, string memory symbol) public {
        _name = name;
        _symbol = symbol;
        _decimals = 18;
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
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
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
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
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
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
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
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
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
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
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
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

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
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

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
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

// mock class using ERC20
contract DummyToken is ERC20 {
    uint256 public constant INITIAL_SUPPLY = 100000000 * (10**18);

    constructor(string memory name, string memory symbol) public payable ERC20(name, symbol) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }

    function transferInternal(
        address from,
        address to,
        uint256 value
    ) public {
        _transfer(from, to, value);
    }

    function approveInternal(
        address owner,
        address spender,
        uint256 value
    ) public {
        _approve(owner, spender, value);
    }
}
