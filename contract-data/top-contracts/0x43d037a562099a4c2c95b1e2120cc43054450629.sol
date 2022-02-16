{"proxy.sol":{"content":"// SPDX-License-Identifier: MIT\n\npragma solidity ^0.6.12;\n\n/**\n * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM\n * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to\n * be specified by overriding the virtual {_implementation} function.\n * \n * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a\n * different contract through the {_delegate} function.\n * \n * The success and return data of the delegated call will be returned back to the caller of the proxy.\n */\nabstract contract Proxy {\n    /**\n     * @dev Delegates the current call to `implementation`.\n     * \n     * This function does not return to its internall call site, it will return directly to the external caller.\n     */\n    function _delegate(address implementation) internal {\n        assembly {\n            // Copy msg.data. We take full control of memory in this inline assembly\n            // block because it will not return to Solidity code. We overwrite the\n            // Solidity scratch pad at memory position 0.\n            calldatacopy(0, 0, calldatasize())\n\n            // Call the implementation.\n            // out and outsize are 0 because we don\u0027t know the size yet.\n            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)\n\n            // Copy the returned data.\n            returndatacopy(0, 0, returndatasize())\n\n            switch result\n            // delegatecall returns 0 on error.\n            case 0 { revert(0, returndatasize()) }\n            default { return(0, returndatasize()) }\n        }\n    }\n\n    /**\n     * @dev This is a virtual function that should be overriden so it returns the address to which the fallback function\n     * and {_fallback} should delegate.\n     */\n    function _implementation() internal virtual view returns (address);\n\n    /**\n     * @dev Delegates the current call to the address returned by `_implementation()`.\n     * \n     * This function does not return to its internall call site, it will return directly to the external caller.\n     */\n    function _fallback() internal {\n        _beforeFallback();\n        _delegate(_implementation());\n    }\n\n    /**\n     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other\n     * function in the contract matches the call data.\n     */\n    fallback () payable external {\n        _fallback();\n    }\n\n    /**\n     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data\n     * is empty.\n     */\n    receive () payable external {\n        _fallback();\n    }\n\n    /**\n     * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`\n     * call, or as part of the Solidity `fallback` or `receive` functions.\n     * \n     * If overriden should call `super._beforeFallback()`.\n     */\n    function _beforeFallback() internal virtual {\n    }\n}"},"transparentUpgraded.sol":{"content":"// SPDX-License-Identifier: MIT\n\npragma solidity ^0.6.12;\n\nimport \"./upgradableProxy.sol\";\n\n/**\n * @dev This contract implements a proxy that is upgradeable by an admin.\n * \n * To avoid https://medium.com/nomic-labs-blog/malicious-backdoors-in-ethereum-proxies-62629adf3357[proxy selector\n * clashing], which can potentially be used in an attack, this contract uses the\n * https://blog.openzeppelin.com/the-transparent-proxy-pattern/[transparent proxy pattern]. This pattern implies two\n * things that go hand in hand:\n * \n * 1. If any account other than the admin calls the proxy, the call will be forwarded to the implementation, even if\n * that call matches one of the admin functions exposed by the proxy itself.\n * 2. If the admin calls the proxy, it can access the admin functions, but its calls will never be forwarded to the\n * implementation. If the admin tries to call a function on the implementation it will fail with an error that says\n * \"admin cannot fallback to proxy target\".\n * \n * These properties mean that the admin account can only be used for admin actions like upgrading the proxy or changing\n * the admin, so it\u0027s best if it\u0027s a dedicated account that is not used for anything else. This will avoid headaches due\n * to sudden errors when trying to call a function from the proxy implementation.\n * \n * Our recommendation is for the dedicated account to be an instance of the {ProxyAdmin} contract. If set up this way,\n * you should think of the `ProxyAdmin` instance as the real administrative interface of your proxy.\n */\ncontract TransparentUpgradeableProxy is UpgradeableProxy {\n    /**\n     * @dev Initializes an upgradeable proxy managed by `_admin`, backed by the implementation at `_logic`, and\n     * optionally initialized with `_data` as explained in {UpgradeableProxy-constructor}.\n     */\n    constructor(address _logic, address _admin, address _incognito, bytes memory _data) public payable UpgradeableProxy(_logic, _data) {\n        assert(_ADMIN_SLOT == bytes32(uint256(keccak256(\"eip1967.proxy.admin\")) - 1));\n        assert(_SUCCESSOR_SLOT == bytes32(uint256(keccak256(\"eip1967.proxy.successor\")) - 1));\n        assert(_PAUSED_SLOT == bytes32(uint256(keccak256(\"eip1967.proxy.paused\")) - 1));\n        assert(_INCOGNITO_SLOT == bytes32(uint256(keccak256(\"eip1967.proxy.incognito.\")) - 1));\n        _setAdmin(_admin);\n        _setIncognito(_incognito);\n    }\n\n    /**\n     * @dev Emitted when the successor account has changed.\n     */\n    event SuccessorChanged(address previousSuccessor, address newSuccessor);\n    \n    /**\n     * @dev Emitted when the incognito proxy has changed.\n     */\n    event IncognitoChanged(address previousIncognito, address newIncognito);\n\n    /**\n     * @dev Emitted when the successor claimed thronze.\n     **/\n    event Claim(address claimer);\n    \n    /**\n     * @dev Emitted when the admin pause contract.\n     **/\n    event Paused(address admin);\n    \n    /**\n     * @dev Emitted when the admin unpaused contract.\n     **/\n    event Unpaused(address admin);\n\n    /**\n     * @dev Storage slot with the admin of the contract.\n     * This is the keccak-256 hash of \"eip1967.proxy.admin\" subtracted by 1, and is\n     * validated in the constructor.\n     */\n    bytes32 private constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;\n\n    /**\n     * @dev Storage slot with the admin of the contract.\n     * This is the keccak-256 hash of \"eip1967.proxy.successor\" subtracted by 1, and is\n     * validated in the constructor.\n     */\n    bytes32 private constant _SUCCESSOR_SLOT = 0x7b13fc932b1063ca775d428558b73e20eab6804d4d9b5a148d7cbae4488973f8;\n\n    /**\n     * @dev Storage slot with status paused or not.\n     * This is the keccak-256 hash of \"eip1967.proxy.paused\" subtracted by 1, and is\n     * validated in the constructor.\n     */\n    bytes32 private constant _PAUSED_SLOT = 0x8dea8703c3cf94703383ce38a9c894669dccd4ca8e65ddb43267aa0248711450;\n    \n    /**\n     * @dev Storage slot with the incognito proxy.\n     * This is the keccak-256 hash of \"eip1967.proxy.incognito.\" subtracted by 1, and is\n     * validated in the constructor.\n     */\n    bytes32 private constant _INCOGNITO_SLOT = 0x62135fc083646fdb4e1a9d700e351b886a4a5a39da980650269edd1ade91ffd2;\n\n    /**\n     * @dev Modifier used internally that will delegate the call to the implementation unless the sender is the admin.\n     */\n    modifier ifAdmin() {\n        if (msg.sender == _admin()) {\n            _;\n        } else {\n            _fallback();\n        }\n    }\n\n    /**\n     * @dev Returns the current admin.\n     * \n     * NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyAdmin}.\n     * \n     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the\n     * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.\n     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`\n     */\n    function admin() external ifAdmin returns (address) {\n        return _admin();\n    }\n\n    /**\n     * @dev Returns the current implementation.\n     * \n     * NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyImplementation}.\n     * \n     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the\n     * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.\n     * `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`\n     */\n    function implementation() external ifAdmin returns (address) {\n        return _implementation();\n    }\n\n    /**\n     * @dev Returns the current successor.\n     * \n     * NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyImplementation}.\n     * \n     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the\n     * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.\n     * `0x7b13fc932b1063ca775d428558b73e20eab6804d4d9b5a148d7cbae4488973f8`\n     */\n    function successor() external ifAdmin returns (address) {\n        return _successor();\n    }\n\n    /**\n     * @dev Returns the current paused value.\n     * \n     * NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyImplementation}.\n     * \n     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the\n     * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.\n     * `0x8dea8703c3cf94703383ce38a9c894669dccd4ca8e65ddb43267aa0248711450`\n     */\n    function paused() external ifAdmin returns (bool) {\n        return _paused();\n    }\n    \n    /**\n     * @dev Returns the current incognito proxy.\n     * \n     * NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyImplementation}.\n     * \n     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the\n     * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.\n     * `0x6c1fc16c781d41e11abf5619c272a94b10ccafab380060da4bd63325467b854e`\n     */\n    function incognito() external ifAdmin returns (address) {\n        return _incognito();\n    }\n\n    /**\n     * @dev Upgrade the implementation of the proxy.\n     * \n     * NOTE: Only the admin can call this function. See {ProxyAdmin-upgrade}.\n     */\n    function upgradeTo(address newImplementation) external ifAdmin {\n        _upgradeTo(newImplementation);\n    }\n\n    /**\n     * @dev Upgrade the implementation of the proxy, and then call a function from the new implementation as specified\n     * by `data`, which should be an encoded function call. This is useful to initialize new storage variables in the\n     * proxied contract.\n     * \n     * NOTE: Only the admin can call this function. See {ProxyAdmin-upgradeAndCall}.\n     */\n    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable ifAdmin {\n        _upgradeTo(newImplementation);\n        // solhint-disable-next-line avoid-low-level-calls\n        (bool success,) = newImplementation.delegatecall(data);\n        require(success, \"DELEGATECALL failed\");\n    }\n\n    /**\n     * @dev Returns the current admin.\n     */\n    function _admin() internal view returns (address adm) {\n        bytes32 slot = _ADMIN_SLOT;\n        // solhint-disable-next-line no-inline-assembly\n        assembly {\n            adm := sload(slot)\n        }\n    }\n\n    /**\n     * @dev Stores a new address in the EIP1967 admin slot.\n     */\n    function _setAdmin(address newAdmin) private {\n        bytes32 slot = _ADMIN_SLOT;\n\n        // solhint-disable-next-line no-inline-assembly\n        assembly {\n            sstore(slot, newAdmin)\n        }\n    }\n\n    /**\n     * @dev Returns the current successor.\n     */\n    function _successor() internal view returns (address sor) {\n        bytes32 slot = _SUCCESSOR_SLOT;\n        // solhint-disable-next-line no-inline-assembly\n        assembly {\n            sor := sload(slot)\n        }\n    }\n\n    /**\n     * @dev Stores a new address in the EIP1967 successor slot.\n     */\n    function _setSuccesor(address newSuccessor) private {\n        bytes32 slot = _SUCCESSOR_SLOT;\n\n        // solhint-disable-next-line no-inline-assembly\n        assembly {\n            sstore(slot, newSuccessor)\n        }\n    }\n\n    /**\n     * @dev Returns the current paused value.\n     */\n    function _paused() internal view returns (bool psd) {\n        bytes32 slot = _PAUSED_SLOT;\n        // solhint-disable-next-line no-inline-assembly\n        assembly {\n            psd := sload(slot)\n        }\n    }\n\n    /**\n     * @dev Stores a new paused value in the EIP1967 paused slot.\n     */\n    function _setPaused(bool psd) private {\n        bytes32 slot = _PAUSED_SLOT;\n\n        // solhint-disable-next-line no-inline-assembly\n        assembly {\n            sstore(slot, psd)\n        }\n    }\n    \n    /**\n     * @dev Returns the current incognito proxy.\n     */\n    function _incognito() internal view returns (address icg) {\n        bytes32 slot = _INCOGNITO_SLOT;\n        // solhint-disable-next-line no-inline-assembly\n        assembly {\n            icg := sload(slot)\n        }\n    }\n\n    /**\n     * @dev Stores a new address in the EIP1967 incognito proxy slot.\n     */\n    function _setIncognito(address newIncognito) private {\n        bytes32 slot = _INCOGNITO_SLOT;\n\n        // solhint-disable-next-line no-inline-assembly\n        assembly {\n            sstore(slot, newIncognito)\n        }\n    }\n\n    /**\n     * @dev Admin retire to prepare transfer thronze to successor.\n     */\n    function retire(address newSuccessor) external ifAdmin {\n        require(newSuccessor != address(0), \"TransparentUpgradeableProxy: successor is the zero address\");\n        emit SuccessorChanged(_successor(), newSuccessor);\n        _setSuccesor(newSuccessor);\n    }\n\n    /**\n     * @dev Successor claims thronze.\n     */\n    function claim() external {\n        if (msg.sender == _successor()) {\n            emit Claim(_successor());\n            _setAdmin(_successor());\n        } else{\n            _fallback();\n        }\n    }\n    \n    /**\n     * @dev Admin pause contract.\n     */\n    function pause() external ifAdmin {\n        require(!_paused(), \"TransparentUpgradeableProxy: contract paused already\");\n        _setPaused(true);\n    }\n    \n    /**\n     * @dev Admin unpause contract.\n     */\n    function unpause() external ifAdmin {\n        require(_paused(), \"TransparentUpgradeableProxy: contract not paused\");\n        _setPaused(false);\n    }\n    \n     /**\n     * @dev Admin upgrade incognito proxy.\n     */\n    function upgradeIncognito(address newIncognito) external ifAdmin {\n        require(newIncognito != address(0), \"TransparentUpgradeableProxy: incognito proxy is the zero address\");\n        emit IncognitoChanged(_incognito(), newIncognito);\n        _setIncognito(newIncognito);\n    }\n    \n    /**\n     * @dev Makes sure the admin cannot access the fallback function. See {Proxy-_beforeFallback}.\n     */\n    function _beforeFallback() internal override virtual {\n        require(msg.sender != _admin(), \"TransparentUpgradeableProxy: admin cannot fallback to proxy target\");\n        require(!_paused(), \"TransparentUpgradeableProxy: contract is paused\");\n        super._beforeFallback();\n    }\n}"},"upgradableProxy.sol":{"content":"// SPDX-License-Identifier: MIT\n\npragma solidity ^0.6.12;\n\nimport \"./proxy.sol\";\n\n/**\n * @dev This contract implements an upgradeable proxy. It is upgradeable because calls are delegated to an\n * implementation address that can be changed. This address is stored in storage in the location specified by\n * https://eips.ethereum.org/EIPS/eip-1967[EIP1967], so that it doesn\u0027t conflict with the storage layout of the\n * implementation behind the proxy.\n * \n * Upgradeability is only provided internally through {_upgradeTo}. For an externally upgradeable proxy see\n * {TransparentUpgradeableProxy}.\n */\ncontract UpgradeableProxy is Proxy {\n    /**\n     * @dev Initializes the upgradeable proxy with an initial implementation specified by `_logic`.\n     * \n     * If `_data` is nonempty, it\u0027s used as data in a delegate call to `_logic`. This will typically be an encoded\n     * function call, and allows initializating the storage of the proxy like a Solidity constructor.\n     */\n    constructor(address _logic, bytes memory _data) public payable {\n        assert(_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256(\"eip1967.proxy.implementation\")) - 1));\n        _setImplementation(_logic);\n        if(_data.length \u003e 0) {\n            // solhint-disable-next-line avoid-low-level-calls\n            (bool success,) = _logic.delegatecall(_data);\n            require(success, \"DELEGATECALL failed\");\n        }\n    }\n\n    /**\n     * @dev Emitted when the implementation is upgraded.\n     */\n    event Upgraded(address indexed implementation);\n\n    /**\n     * @dev Storage slot with the address of the current implementation.\n     * This is the keccak-256 hash of \"eip1967.proxy.implementation\" subtracted by 1, and is\n     * validated in the constructor.\n     */\n    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;\n\n    /**\n     * @dev Returns the current implementation address.\n     */\n    function _implementation() internal override view returns (address impl) {\n        bytes32 slot = _IMPLEMENTATION_SLOT;\n        // solhint-disable-next-line no-inline-assembly\n        assembly {\n            impl := sload(slot)\n        }\n    }\n\n    /**\n     * @dev Upgrades the proxy to a new implementation.\n     * \n     * Emits an {Upgraded} event.\n     */\n    function _upgradeTo(address newImplementation) internal {\n        _setImplementation(newImplementation);\n        emit Upgraded(newImplementation);\n    }\n\n    /**\n     * @dev Stores a new address in the EIP1967 implementation slot.\n     */\n    function _setImplementation(address newImplementation) private {\n        require(isContract(newImplementation), \"UpgradeableProxy: new implementation is not a contract\");\n\n        bytes32 slot = _IMPLEMENTATION_SLOT;\n\n        // solhint-disable-next-line no-inline-assembly\n        assembly {\n            sstore(slot, newImplementation)\n        }\n    }\n    \n    /**\n     * @dev Returns true if `account` is a contract.\n     *\n     * [IMPORTANT]\n     * ====\n     * It is unsafe to assume that an address for which this function returns\n     * false is an externally-owned account (EOA) and not a contract.\n     *\n     * Among others, `isContract` will return false for the following\n     * types of addresses:\n     *\n     *  - an externally-owned account\n     *  - a contract in construction\n     *  - an address where a contract will be created\n     *  - an address where a contract lived, but was destroyed\n     * ====\n     */\n    function isContract(address account) internal view returns (bool) {\n        // This method relies on extcodesize, which returns 0 for contracts in\n        // construction, since the code is only stored at the end of the\n        // constructor execution.\n\n        uint256 size;\n        // solhint-disable-next-line no-inline-assembly\n        assembly { size := extcodesize(account) }\n        return size \u003e 0;\n    }\n}"}}