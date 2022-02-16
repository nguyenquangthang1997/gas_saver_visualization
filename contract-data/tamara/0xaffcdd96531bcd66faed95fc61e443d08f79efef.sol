pragma solidity ^0.4.24;

/**
 * @title Address
 *
 * @dev Utility library of inline functions on addresses.
 */
library Address {
    /**
     * @dev Returns whether the target address is a contract.
     * This function will return false if invoked during the constructor of a contract, as the code is not actually
     * created until after the constructor finishes.
     *
     * @param account The address of the account to check
     * @return True if the target address is a contract, otherwise false
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // XXX Currently there is no better way to check if there is a contract in an address
        // than to check the size of the code at that address.
        // See https://ethereum.stackexchange.com/a/14016/36603
        // for more details about how this works.
        // TODO Check this again before the Serenity release, because all addresses will be
        // contracts then.
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

pragma solidity ^0.4.24;

import './UpgradeabilityProxy.sol';

/**
 * @title AdminUpgradeabilityProxy
 *
 * @dev This contract combines an upgradeability proxy with an authorization mechanism for administrative tasks.
 * All external functions in this contract must be guarded by the `ifAdmin` modifier.
 * See ethereum/solidity#3864 for a Solidity feature proposal that would enable this to be done automatically.
 */
contract AdminUpgradeabilityProxy is UpgradeabilityProxy {
    /**
     * @dev Event emitted whenever the administration has been transferred.
     *
     * @param previousAdmin Address of the previous admin.
     * @param newAdmin Address of the new admin.
     *
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "infinigold.proxy.admin", and is validated in the constructor.
     */
    bytes32 private constant ADMIN_SLOT = 0x0d28943014d3bfed6af9cab5e6024c23fa2da10f7a6373bcd56c37313c24d93a;

    /**
     * @dev Modifier to check whether the `msg.sender` is the admin.
     * If it is, it will run the function. Otherwise, it will delegate the call to the implementation.
     */
    modifier ifAdmin() {
        if (msg.sender == _admin()) {
            _;
        } else {
            _fallback();
        }
    }

    /**
     * @dev Contract constructor.
     * @dev It sets the `msg.sender` as the proxy administrator.
     *
     * @param _implementation address of the initial implementation.
     */
    constructor(address _implementation) UpgradeabilityProxy(_implementation) public {
        assert(ADMIN_SLOT == keccak256("infinigold.proxy.admin"));

        _setAdmin(msg.sender);
    }

    /**
     * @return The address of the proxy admin.
     */
    function admin() external view ifAdmin returns (address) {
        return _admin();
    }

    /**
     * @return The address of the implementation.
     */
    function implementation() external view ifAdmin returns (address) {
        return _implementation();
    }

    /**
     * @dev Changes the admin of the proxy.
     * Only the current admin can call this function.
     *
     * @param newAdmin Address to transfer proxy administration to.
     */
    function changeAdmin(address newAdmin) external ifAdmin {
        require(newAdmin != address(0), "Cannot change the admin of a proxy to the zero address");
        emit AdminChanged(_admin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev Upgrade the backing implementation of the proxy.
     * Only the admin can call this function.
     *
     * @param newImplementation Address of the new implementation.
     */
    function upgradeTo(address newImplementation) external ifAdmin {
        _upgradeTo(newImplementation);
    }

    /**
     * @dev Upgrade the backing implementation of the proxy and call a function on the new implementation.
     * This is useful to initialize the proxied contract.
     *
     * The given `data` should include the signature and parameters of the function to be called.
     * See https://solidity.readthedocs.io/en/v0.4.24/abi-spec.html#function-selector-and-argument-encoding
     *
     * @param newImplementation Address of the new implementation.
     * @param data Data to send as msg.data in the low level call.
     */
    function upgradeToAndCall(address newImplementation, bytes data) payable external ifAdmin {
        _upgradeTo(newImplementation);
        require(address(this).call.value(msg.value)(data));
    }

    /**
     * @return The admin slot.
     */
    function _admin() internal view returns (address adm) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }

    /**
     * @dev Sets the address of the proxy admin.
     *
     * @param newAdmin Address of the new proxy admin.
     */
    function _setAdmin(address newAdmin) internal {
        bytes32 slot = ADMIN_SLOT;

        assembly {
            sstore(slot, newAdmin)
        }
    }

    /**
     * @dev Only fall back when the sender is not the admin.
     */
    function _willFallback() internal {
        require(msg.sender != _admin(), "Cannot call fallback function from the proxy admin");
        super._willFallback();
    }
}
pragma solidity ^0.4.24;

/**
 * @title Proxy
 *
 * @dev Implements delegation of calls to other contracts, with proper forwarding of return values and bubbling of
 * failures.
 * It defines a fallback function that delegates all calls to the address returned by the abstract `_implementation()`
 * internal function.
 */
contract Proxy {
    /**
     * @dev Fallback function.
     * Implemented entirely in `_fallback`.
     */
    function () payable external {
        _fallback();
    }

    /**
     * @return The Address of the implementation.
     */
    function _implementation() internal view returns (address);

    /**
     * @dev Delegates execution to an implementation contract.
     * This is a low level function that doesn't return to its internal call site.
     * It will return to the external caller whatever the implementation returns.
     *
     * @param implementation Address to delegate.
     */
    function _delegate(address implementation) internal {
        assembly {
            // Copy msg.data.
            // We take full control of memory in this inline assembly block because it will not return to Solidity code.
            // We overwrite the Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize)

            // Call the implementation.
            // The out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas, implementation, 0, calldatasize, 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize)

            switch result
            // delegatecall returns 0 on error.
            case 0 { revert(0, returndatasize) }
            default { return(0, returndatasize) }
        }
    }

    /**
     * @dev Function that is run as the first thing in the fallback function.
     * Can be redefined in derived contracts to add functionality.
     * Redefinitions must call super._willFallback().
     */
    function _willFallback() internal {
    }

    /**
     * @dev fallback implementation.
     * Extracted to enable manual triggering.
     */
    function _fallback() internal {
        _willFallback();
        _delegate(_implementation());
    }
}
pragma solidity ^0.4.24;

import './Proxy.sol';
import './Address.sol';

/**
 * @title UpgradeabilityProxy
 *
 * @dev This contract implements a proxy that allows to change the implementation address to which it will delegate.
 * Such a change is called an implementation upgrade.
 */
contract UpgradeabilityProxy is Proxy {
    /**
     * @dev Emitted when the implementation is upgraded.
     *
     * @param implementation Address of the new implementation.
     */
    event Upgraded(address implementation);

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "infinigold.proxy.implementation", and is validated in the constructor.
     */
    bytes32 private constant IMPLEMENTATION_SLOT = 0x17a1a1520654e435f06928e17f36680bf83a0dd9ed240ed37d78f8289a559c70;

    /**
     * @dev Contract constructor.
     *
     * @param _implementation Address of the initial implementation.
     */
    constructor(address _implementation) public {
        assert(IMPLEMENTATION_SLOT == keccak256("infinigold.proxy.implementation"));

        _setImplementation(_implementation);
    }

    /**
     * @dev Returns the current implementation.
     *
     * @return Address of the current implementation
     */
    function _implementation() internal view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    /**
     * @dev Upgrades the proxy to a new implementation.
     *
     * @param newImplementation Address of the new implementation.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Sets the implementation address of the proxy.
     *
     * @param newImplementation Address of the new implementation.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "Cannot set a proxy implementation to a non-contract address");

        bytes32 slot = IMPLEMENTATION_SLOT;

        assembly {
            sstore(slot, newImplementation)
        }
    }
}

pragma solidity ^0.4.24;

/**
 * @title Address
 *
 * @dev Utility library of inline functions on addresses.
 */
library Address {
    /**
     * @dev Returns whether the target address is a contract.
     * This function will return false if invoked during the constructor of a contract, as the code is not actually
     * created until after the constructor finishes.
     *
     * @param account The address of the account to check
     * @return True if the target address is a contract, otherwise false
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // XXX Currently there is no better way to check if there is a contract in an address
        // than to check the size of the code at that address.
        // See https://ethereum.stackexchange.com/a/14016/36603
        // for more details about how this works.
        // TODO Check this again before the Serenity release, because all addresses will be
        // contracts then.
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

pragma solidity ^0.4.24;

import './UpgradeabilityProxy.sol';

/**
 * @title AdminUpgradeabilityProxy
 *
 * @dev This contract combines an upgradeability proxy with an authorization mechanism for administrative tasks.
 * All external functions in this contract must be guarded by the `ifAdmin` modifier.
 * See ethereum/solidity#3864 for a Solidity feature proposal that would enable this to be done automatically.
 */
contract AdminUpgradeabilityProxy is UpgradeabilityProxy {
    /**
     * @dev Event emitted whenever the administration has been transferred.
     *
     * @param previousAdmin Address of the previous admin.
     * @param newAdmin Address of the new admin.
     *
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "infinigold.proxy.admin", and is validated in the constructor.
     */
    bytes32 private constant ADMIN_SLOT = 0x0d28943014d3bfed6af9cab5e6024c23fa2da10f7a6373bcd56c37313c24d93a;

    /**
     * @dev Modifier to check whether the `msg.sender` is the admin.
     * If it is, it will run the function. Otherwise, it will delegate the call to the implementation.
     */
    modifier ifAdmin() {
        if (msg.sender == _admin()) {
            _;
        } else {
            _fallback();
        }
    }

    /**
     * @dev Contract constructor.
     * @dev It sets the `msg.sender` as the proxy administrator.
     *
     * @param _implementation address of the initial implementation.
     */
    constructor(address _implementation) UpgradeabilityProxy(_implementation) public {
        assert(ADMIN_SLOT == keccak256("infinigold.proxy.admin"));

        _setAdmin(msg.sender);
    }

    /**
     * @return The address of the proxy admin.
     */
    function admin() external view ifAdmin returns (address) {
        return _admin();
    }

    /**
     * @return The address of the implementation.
     */
    function implementation() external view ifAdmin returns (address) {
        return _implementation();
    }

    /**
     * @dev Changes the admin of the proxy.
     * Only the current admin can call this function.
     *
     * @param newAdmin Address to transfer proxy administration to.
     */
    function changeAdmin(address newAdmin) external ifAdmin {
        require(newAdmin != address(0), "Cannot change the admin of a proxy to the zero address");
        emit AdminChanged(_admin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev Upgrade the backing implementation of the proxy.
     * Only the admin can call this function.
     *
     * @param newImplementation Address of the new implementation.
     */
    function upgradeTo(address newImplementation) external ifAdmin {
        _upgradeTo(newImplementation);
    }

    /**
     * @dev Upgrade the backing implementation of the proxy and call a function on the new implementation.
     * This is useful to initialize the proxied contract.
     *
     * The given `data` should include the signature and parameters of the function to be called.
     * See https://solidity.readthedocs.io/en/v0.4.24/abi-spec.html#function-selector-and-argument-encoding
     *
     * @param newImplementation Address of the new implementation.
     * @param data Data to send as msg.data in the low level call.
     */
    function upgradeToAndCall(address newImplementation, bytes data) payable external ifAdmin {
        _upgradeTo(newImplementation);
        require(address(this).call.value(msg.value)(data));
    }

    /**
     * @return The admin slot.
     */
    function _admin() internal view returns (address adm) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }

    /**
     * @dev Sets the address of the proxy admin.
     *
     * @param newAdmin Address of the new proxy admin.
     */
    function _setAdmin(address newAdmin) internal {
        bytes32 slot = ADMIN_SLOT;

        assembly {
            sstore(slot, newAdmin)
        }
    }

    /**
     * @dev Only fall back when the sender is not the admin.
     */
    function _willFallback() internal {
        require(msg.sender != _admin(), "Cannot call fallback function from the proxy admin");
        super._willFallback();
    }
}
pragma solidity ^0.4.24;

/**
 * @title Proxy
 *
 * @dev Implements delegation of calls to other contracts, with proper forwarding of return values and bubbling of
 * failures.
 * It defines a fallback function that delegates all calls to the address returned by the abstract `_implementation()`
 * internal function.
 */
contract Proxy {
    /**
     * @dev Fallback function.
     * Implemented entirely in `_fallback`.
     */
    function () payable external {
        _fallback();
    }

    /**
     * @return The Address of the implementation.
     */
    function _implementation() internal view returns (address);

    /**
     * @dev Delegates execution to an implementation contract.
     * This is a low level function that doesn't return to its internal call site.
     * It will return to the external caller whatever the implementation returns.
     *
     * @param implementation Address to delegate.
     */
    function _delegate(address implementation) internal {
        assembly {
            // Copy msg.data.
            // We take full control of memory in this inline assembly block because it will not return to Solidity code.
            // We overwrite the Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize)

            // Call the implementation.
            // The out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas, implementation, 0, calldatasize, 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize)

            switch result
            // delegatecall returns 0 on error.
            case 0 { revert(0, returndatasize) }
            default { return(0, returndatasize) }
        }
    }

    /**
     * @dev Function that is run as the first thing in the fallback function.
     * Can be redefined in derived contracts to add functionality.
     * Redefinitions must call super._willFallback().
     */
    function _willFallback() internal {
    }

    /**
     * @dev fallback implementation.
     * Extracted to enable manual triggering.
     */
    function _fallback() internal {
        _willFallback();
        _delegate(_implementation());
    }
}
pragma solidity ^0.4.24;

import './Proxy.sol';
import './Address.sol';

/**
 * @title UpgradeabilityProxy
 *
 * @dev This contract implements a proxy that allows to change the implementation address to which it will delegate.
 * Such a change is called an implementation upgrade.
 */
contract UpgradeabilityProxy is Proxy {
    /**
     * @dev Emitted when the implementation is upgraded.
     *
     * @param implementation Address of the new implementation.
     */
    event Upgraded(address implementation);

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "infinigold.proxy.implementation", and is validated in the constructor.
     */
    bytes32 private constant IMPLEMENTATION_SLOT = 0x17a1a1520654e435f06928e17f36680bf83a0dd9ed240ed37d78f8289a559c70;

    /**
     * @dev Contract constructor.
     *
     * @param _implementation Address of the initial implementation.
     */
    constructor(address _implementation) public {
        assert(IMPLEMENTATION_SLOT == keccak256("infinigold.proxy.implementation"));

        _setImplementation(_implementation);
    }

    /**
     * @dev Returns the current implementation.
     *
     * @return Address of the current implementation
     */
    function _implementation() internal view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    /**
     * @dev Upgrades the proxy to a new implementation.
     *
     * @param newImplementation Address of the new implementation.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Sets the implementation address of the proxy.
     *
     * @param newImplementation Address of the new implementation.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "Cannot set a proxy implementation to a non-contract address");

        bytes32 slot = IMPLEMENTATION_SLOT;

        assembly {
            sstore(slot, newImplementation)
        }
    }
}

pragma solidity ^0.4.24;

/**
 * @title Address
 *
 * @dev Utility library of inline functions on addresses.
 */
library Address {
    /**
     * @dev Returns whether the target address is a contract.
     * This function will return false if invoked during the constructor of a contract, as the code is not actually
     * created until after the constructor finishes.
     *
     * @param account The address of the account to check
     * @return True if the target address is a contract, otherwise false
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // XXX Currently there is no better way to check if there is a contract in an address
        // than to check the size of the code at that address.
        // See https://ethereum.stackexchange.com/a/14016/36603
        // for more details about how this works.
        // TODO Check this again before the Serenity release, because all addresses will be
        // contracts then.
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

pragma solidity ^0.4.24;

import './UpgradeabilityProxy.sol';

/**
 * @title AdminUpgradeabilityProxy
 *
 * @dev This contract combines an upgradeability proxy with an authorization mechanism for administrative tasks.
 * All external functions in this contract must be guarded by the `ifAdmin` modifier.
 * See ethereum/solidity#3864 for a Solidity feature proposal that would enable this to be done automatically.
 */
contract AdminUpgradeabilityProxy is UpgradeabilityProxy {
    /**
     * @dev Event emitted whenever the administration has been transferred.
     *
     * @param previousAdmin Address of the previous admin.
     * @param newAdmin Address of the new admin.
     *
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "infinigold.proxy.admin", and is validated in the constructor.
     */
    bytes32 private constant ADMIN_SLOT = 0x0d28943014d3bfed6af9cab5e6024c23fa2da10f7a6373bcd56c37313c24d93a;

    /**
     * @dev Modifier to check whether the `msg.sender` is the admin.
     * If it is, it will run the function. Otherwise, it will delegate the call to the implementation.
     */
    modifier ifAdmin() {
        if (msg.sender == _admin()) {
            _;
        } else {
            _fallback();
        }
    }

    /**
     * @dev Contract constructor.
     * @dev It sets the `msg.sender` as the proxy administrator.
     *
     * @param _implementation address of the initial implementation.
     */
    constructor(address _implementation) UpgradeabilityProxy(_implementation) public {
        assert(ADMIN_SLOT == keccak256("infinigold.proxy.admin"));

        _setAdmin(msg.sender);
    }

    /**
     * @return The address of the proxy admin.
     */
    function admin() external view ifAdmin returns (address) {
        return _admin();
    }

    /**
     * @return The address of the implementation.
     */
    function implementation() external view ifAdmin returns (address) {
        return _implementation();
    }

    /**
     * @dev Changes the admin of the proxy.
     * Only the current admin can call this function.
     *
     * @param newAdmin Address to transfer proxy administration to.
     */
    function changeAdmin(address newAdmin) external ifAdmin {
        require(newAdmin != address(0), "Cannot change the admin of a proxy to the zero address");
        emit AdminChanged(_admin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev Upgrade the backing implementation of the proxy.
     * Only the admin can call this function.
     *
     * @param newImplementation Address of the new implementation.
     */
    function upgradeTo(address newImplementation) external ifAdmin {
        _upgradeTo(newImplementation);
    }

    /**
     * @dev Upgrade the backing implementation of the proxy and call a function on the new implementation.
     * This is useful to initialize the proxied contract.
     *
     * The given `data` should include the signature and parameters of the function to be called.
     * See https://solidity.readthedocs.io/en/v0.4.24/abi-spec.html#function-selector-and-argument-encoding
     *
     * @param newImplementation Address of the new implementation.
     * @param data Data to send as msg.data in the low level call.
     */
    function upgradeToAndCall(address newImplementation, bytes data) payable external ifAdmin {
        _upgradeTo(newImplementation);
        require(address(this).call.value(msg.value)(data));
    }

    /**
     * @return The admin slot.
     */
    function _admin() internal view returns (address adm) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }

    /**
     * @dev Sets the address of the proxy admin.
     *
     * @param newAdmin Address of the new proxy admin.
     */
    function _setAdmin(address newAdmin) internal {
        bytes32 slot = ADMIN_SLOT;

        assembly {
            sstore(slot, newAdmin)
        }
    }

    /**
     * @dev Only fall back when the sender is not the admin.
     */
    function _willFallback() internal {
        require(msg.sender != _admin(), "Cannot call fallback function from the proxy admin");
        super._willFallback();
    }
}
pragma solidity ^0.4.24;

/**
 * @title Proxy
 *
 * @dev Implements delegation of calls to other contracts, with proper forwarding of return values and bubbling of
 * failures.
 * It defines a fallback function that delegates all calls to the address returned by the abstract `_implementation()`
 * internal function.
 */
contract Proxy {
    /**
     * @dev Fallback function.
     * Implemented entirely in `_fallback`.
     */
    function () payable external {
        _fallback();
    }

    /**
     * @return The Address of the implementation.
     */
    function _implementation() internal view returns (address);

    /**
     * @dev Delegates execution to an implementation contract.
     * This is a low level function that doesn't return to its internal call site.
     * It will return to the external caller whatever the implementation returns.
     *
     * @param implementation Address to delegate.
     */
    function _delegate(address implementation) internal {
        assembly {
            // Copy msg.data.
            // We take full control of memory in this inline assembly block because it will not return to Solidity code.
            // We overwrite the Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize)

            // Call the implementation.
            // The out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas, implementation, 0, calldatasize, 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize)

            switch result
            // delegatecall returns 0 on error.
            case 0 { revert(0, returndatasize) }
            default { return(0, returndatasize) }
        }
    }

    /**
     * @dev Function that is run as the first thing in the fallback function.
     * Can be redefined in derived contracts to add functionality.
     * Redefinitions must call super._willFallback().
     */
    function _willFallback() internal {
    }

    /**
     * @dev fallback implementation.
     * Extracted to enable manual triggering.
     */
    function _fallback() internal {
        _willFallback();
        _delegate(_implementation());
    }
}
pragma solidity ^0.4.24;

import './Proxy.sol';
import './Address.sol';

/**
 * @title UpgradeabilityProxy
 *
 * @dev This contract implements a proxy that allows to change the implementation address to which it will delegate.
 * Such a change is called an implementation upgrade.
 */
contract UpgradeabilityProxy is Proxy {
    /**
     * @dev Emitted when the implementation is upgraded.
     *
     * @param implementation Address of the new implementation.
     */
    event Upgraded(address implementation);

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "infinigold.proxy.implementation", and is validated in the constructor.
     */
    bytes32 private constant IMPLEMENTATION_SLOT = 0x17a1a1520654e435f06928e17f36680bf83a0dd9ed240ed37d78f8289a559c70;

    /**
     * @dev Contract constructor.
     *
     * @param _implementation Address of the initial implementation.
     */
    constructor(address _implementation) public {
        assert(IMPLEMENTATION_SLOT == keccak256("infinigold.proxy.implementation"));

        _setImplementation(_implementation);
    }

    /**
     * @dev Returns the current implementation.
     *
     * @return Address of the current implementation
     */
    function _implementation() internal view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    /**
     * @dev Upgrades the proxy to a new implementation.
     *
     * @param newImplementation Address of the new implementation.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Sets the implementation address of the proxy.
     *
     * @param newImplementation Address of the new implementation.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "Cannot set a proxy implementation to a non-contract address");

        bytes32 slot = IMPLEMENTATION_SLOT;

        assembly {
            sstore(slot, newImplementation)
        }
    }
}

