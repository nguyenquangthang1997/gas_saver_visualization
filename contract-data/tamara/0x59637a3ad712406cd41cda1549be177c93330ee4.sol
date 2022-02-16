pragma solidity ^0.5.8;

import "./Ownable.sol";

contract FeeCalcInterface {
    function getFee() public view returns(uint256);
    function getCompanyFee() public view returns(uint256);
    function getNetworkGrowthFee() public view returns(uint256);
}

contract ERC20Interface {
    function transfer(address, uint256) public returns (bool);
}

contract DocumentRegistryInterface {
    function register(address) public;
    function feeCalc() public view returns(address);

    function companyWallet() public view returns(address);
    function networkGrowthPoolWallet() public view returns(address);
    function token() public view returns(address);
}

contract Agent is Ownable {

    DocumentRegistryInterface public documentRegistry;
    string public name;

    address public user;

    event Error(string msg);

    modifier onlyRegisteredUser() {
        uint256 code = 0;
        address _sender = msg.sender;
        if (_sender == user) {
            _;
        }
        else {
            emit Error("User does not registered");
        }
    }

    constructor(address _documentRegistry, address _owner, address _user) public {
        documentRegistry = DocumentRegistryInterface(_documentRegistry);
        owner = _owner;
        user = _user;
    }

    function setDocumentRegistry(address _documentRegistry) public onlyOwner {
        documentRegistry = DocumentRegistryInterface(_documentRegistry);
    }

    function setName(string memory _name) public onlyOwner {
        name = _name;
    }

    function setUser(address _user) public onlyOwner {
        user = _user;
    }

    function register(address _document) public onlyRegisteredUser {
        FeeCalcInterface feeCalc = FeeCalcInterface(documentRegistry.feeCalc());

        documentRegistry.register(_document);

        // Transfer fee to company wallet
        address companyWallet = documentRegistry.companyWallet();
        assert(companyWallet != address(0));
        uint256 companyFee = feeCalc.getCompanyFee();
        assert(ERC20Interface(documentRegistry.token()).transfer(companyWallet, companyFee));

        // Transfer fee to network wallet
        address networkGrowthPoolWallet = documentRegistry.networkGrowthPoolWallet();
        assert(networkGrowthPoolWallet != address(0));
        uint256 networkGrowthFee = feeCalc.getNetworkGrowthFee();
        assert(ERC20Interface(documentRegistry.token()).transfer(networkGrowthPoolWallet, networkGrowthFee));
    }

}


pragma solidity 0.5.8;

import "./Owned.sol";

contract BaseDocument is Owned {

    bytes32 public hash;
    string[] public tags;

    bool public finalized;

    modifier isNotFinalized() {
        require(!finalized, "Contract is finalized");
        _;
    }

    constructor(bytes32 _hash) public {
        hash = _hash;
    }

    function proxy_init(address _owner, bytes32 _hash) public {
        require(contractOwner == address(0));
        contractOwner = _owner;
        hash = _hash;
    }

    function setHash(bytes32 _hash) public isNotFinalized onlyContractOwner {
        hash = _hash;
    }

    function addTag(string memory _key) public isNotFinalized onlyContractOwner {
        require(tagsLength() < 32, "Tags is too many!");
        tags.push(_key);
    }

    function setFinalized() public isNotFinalized onlyContractOwner {
        finalized = true;
    }

    function tagsLength() public view returns(uint256) {
        return tags.length;
    }

    function documentType() public pure returns(bytes32) {
        return keccak256("basic");
    }

}


pragma solidity 0.5.8;

import "./Storage.sol";
import "./StorageAdapter.sol";
import "./RolesLibraryAdapter.sol";
import "./BaseDocument.sol";

contract DocumentRegistry is StorageAdapter, RolesLibraryAdapter {

    address public companyWallet;
    address public networkGrowthPoolWallet;
    address public feeCalc;
    address public token;

    StorageInterface.Bytes32AddressMapping documents;
    StorageInterface.StringAddressSetMapping tags;
    StorageInterface.AddressBytes32Bytes32Mapping documentsv2;

    event DocumentRegistered(address _document, bytes32 _hash, bytes32 _type);
    event DocumentRegisteredv2(bytes32 _hash, bytes32 _metahash);
    event Error(string _message);

    modifier isDocumentFinalized(BaseDocument _document) {
        if(!_document.finalized()) {
            emit Error("Document is not finalized");
            return;
        }
        _;
    }

    constructor(
        Storage _store,
        bytes32 _crate,
        address _companyWallet,
        address _networkGrowthPoolWallet,
        address _feeCalc,
        address _token,
        address _rolesLibrary
    ) public StorageAdapter(_store, _crate) RolesLibraryAdapter(_rolesLibrary) {
        companyWallet = _companyWallet;
        networkGrowthPoolWallet = _networkGrowthPoolWallet;
        feeCalc = _feeCalc;
        token = _token;
        documents.init("RegisteredDocuments");
        tags.init("ContainsTagDocuments");
    }

    function proxy_init(
        Storage _store,
        bytes32 _crate,
        address _companyWallet,
        address _networkGrowthPoolWallet,
        address _feeCalc,
        address _token,
        address _rolesLibrary
    ) public {
        require(address(rolesLibrary) == address(0));
        store.init(_store, _crate);
        rolesLibrary = RolesLibraryInterface(_rolesLibrary);
        companyWallet = _companyWallet;
        networkGrowthPoolWallet = _networkGrowthPoolWallet;
        feeCalc = _feeCalc;
        token = _token;
        documents.init("RegisteredDocuments");
        tags.init("ContainsTagDocuments");
        documentsv2.init("RegisteredDocumentsv2");
    }

    function setWallets(address _companyWallet, address _networkGrowthPoolWallet) public auth {
        companyWallet = _companyWallet;
        networkGrowthPoolWallet = _networkGrowthPoolWallet;
    }

    function setFeeCalc(address _feeCalc) public auth {
        feeCalc = _feeCalc;
    }

    function register(BaseDocument _document) public auth isDocumentFinalized(_document) {
        require(!exists(_document.hash()), "Document is already exists!");
        store.set(documents, _document.hash(), address(_document));
        for(uint256 i = 0; i < _document.tagsLength(); ++i) {
            store.add(tags, _document.tags(i), address(_document));
        }
        emit DocumentRegistered(address(_document), _document.hash(), _document.documentType());
    }

    function getDocument(bytes32 _hash) public view returns(address) {
        return store.get(documents, _hash);
    }

    function getDocumentsByTag(string memory _tag) public view returns(address[] memory) {
        return store.get(tags, _tag);
    }

    function exists(bytes32 _hash) public view returns(bool) {
        return store.get(documents, _hash) != address(0);
    }
    
    // Access methods for version 2 (only hash)
    // Here we don't deploy contract for document but just store physical(electronic) document hash
    // and metadata hash which is just JSON with all the data related to registration.
    
    function registerv2(bytes32 _hash, bytes32 _metahash) public auth {
        require(!existsv2(_hash), "Document already exists!");
        store.set(documentsv2, address(0), _hash, _metahash);
        emit DocumentRegisteredv2(_hash, _metahash);
    }
    
     function existsv2(bytes32 _hash) public view returns(bool) {
        return store.get(documentsv2, address(0), _hash) != bytes32(0);
    }
    
    function getMetahash(bytes32 _hash) public view returns(bytes32) {
        return store.get(documentsv2, address(0), _hash);
    }

}

pragma solidity ^0.5.8;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {

    address public owner;

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
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }

}



pragma solidity ^0.5.8;


/**
 * @title Owned contract with safe ownership pass.
 *
 * Note: all the non constant functions return false instead of throwing in case if state change
 * didn't happen yet.
 */
contract Owned {
    address public contractOwner;
    address public pendingContractOwner;

    constructor () public {
        contractOwner = msg.sender;
    }

    modifier onlyContractOwner() {
        if (contractOwner == msg.sender || contractOwner == address(0)) {
            _;
        }
    }

    /**
     * Prepares ownership pass.
     *
     * Can only be called by current owner.
     *
     * @param _to address of the next owner.
     *
     * @return success.
     */
    function changeContractOwnership(address _to) public onlyContractOwner returns(bool) {
        pendingContractOwner = _to;
        return true;
    }

    /**
     * Finalize ownership pass.
     *
     * Can only be called by pending owner.
     *
     * @return success.
     */
    function claimContractOwnership() public returns(bool) {
        if (pendingContractOwner != msg.sender) {
            return false;
        }
        contractOwner = pendingContractOwner;
        delete pendingContractOwner;
        return true;
    }

    /**
     * Force ownership pass.
     *
     * Can only be called by current owner.
     *
     * @param _to address of the next owner.
     *
     * @return success.
     */
    function forceChangeContractOwnership(address _to) public onlyContractOwner returns(bool) {
        contractOwner = _to;
        return true;
    }

}


pragma solidity 0.5.8;


contract RolesLibraryInterface {
    function canCall(address, address, bytes4) public view returns(bool);
}

contract RolesLibraryAdapter {
    RolesLibraryInterface rolesLibrary;

    event Unauthorized(address user);

    modifier auth() {
        if (!_isAuthorized(msg.sender, msg.sig)) {
            emit Unauthorized(msg.sender);
            return;
        }
        _;
    }

    constructor(address _rolesLibrary) public {
        rolesLibrary = RolesLibraryInterface(_rolesLibrary);
    }

    function setRolesLibrary(RolesLibraryInterface _rolesLibrary) auth() public returns(bool) {
        rolesLibrary = _rolesLibrary;
        return true;
    }

    function _isAuthorized(address _src, bytes4 _sig) internal view returns(bool) {
        if (_src == address(this)) {
            return true;
        }
        if (address(rolesLibrary) == address(0)) {
            return false;
        }
        return rolesLibrary.canCall(_src, address(this), _sig);
    }
}


pragma solidity 0.5.8;

import "./Owned.sol";


contract Manager {
    function isAllowed(address _actor, bytes32 _role) view public returns(bool);
}

contract Storage is Owned {

    struct Crate {
        mapping(bytes32 => uint) uints;
        mapping(bytes32 => address) addresses;
        mapping(bytes32 => bool) bools;
        mapping(bytes32 => int) ints;
        mapping(bytes32 => uint8) uint8s;
        mapping(bytes32 => bytes32) bytes32s;
    }

    mapping(bytes32 => Crate) crates;
    Manager public manager;

    modifier onlyAllowed(bytes32 _role) {
        if (!manager.isAllowed(msg.sender, _role)) {
            revert();
        }
        _;
    }

    function setManager(Manager _manager) onlyContractOwner public returns(bool) {
        manager = _manager;
        return true;
    }

    function setUInt(bytes32 _crate, bytes32 _key, uint _value) onlyAllowed(_crate) public {
        crates[_crate].uints[_key] = _value;
    }

    function getUInt(bytes32 _crate, bytes32 _key) view public returns(uint) {
        return crates[_crate].uints[_key];
    }

    function setUInt8(bytes32 _crate, bytes32 _key, uint8 _value) onlyAllowed(_crate) public {
        crates[_crate].uint8s[_key] = _value;
    }

    function getUInt8(bytes32 _crate, bytes32 _key) view public returns(uint8) {
        return crates[_crate].uint8s[_key];
    }

    function setInt(bytes32 _crate, bytes32 _key, int _value) onlyAllowed(_crate) public {
        crates[_crate].ints[_key] = _value;
    }

    function getInt(bytes32 _crate, bytes32 _key) view public returns(int) {
        return crates[_crate].ints[_key];
    }

    function setAddress(bytes32 _crate, bytes32 _key, address _value) onlyAllowed(_crate) public {
        crates[_crate].addresses[_key] = _value;
    }

    function getAddress(bytes32 _crate, bytes32 _key) view public returns(address) {
        return crates[_crate].addresses[_key];
    }

    function setBool(bytes32 _crate, bytes32 _key, bool _value) onlyAllowed(_crate) public {
        crates[_crate].bools[_key] = _value;
    }

    function getBool(bytes32 _crate, bytes32 _key) view public returns(bool) {
        return crates[_crate].bools[_key];
    }

    function setBytes32(bytes32 _crate, bytes32 _key, bytes32 _value) onlyAllowed(_crate) public {
        crates[_crate].bytes32s[_key] = _value;
    }

    function getBytes32(bytes32 _crate, bytes32 _key) view public returns(bytes32) {
        return crates[_crate].bytes32s[_key];
    }


    /// RESTRICTIONS & DISASTER RECOVERY ///

    function kill() public onlyContractOwner {
        selfdestruct(msg.sender);
    }

    // FIXME: Add maintenance mode


}


pragma solidity 0.5.8;

import "./StorageInterface.sol";


contract StorageAdapter {
    using StorageInterface for *;

    StorageInterface.Config store;

    constructor(Storage _store, bytes32 _crate) public {
        assert(_crate != bytes32(0));
        store.init(_store, _crate);
    }
}
pragma solidity 0.5.8;

import "./Storage.sol";

/*
contract StorageMethods {
    function setUInt(bytes32, bytes32, uint);
    function setUInt8(bytes32, bytes32, uint8);
    function setInt(bytes32, bytes32, int);
    function setAddress(bytes32, bytes32, address);
    function setBool(bytes32, bytes32, bool);
    function setBytes32(bytes32, bytes32, bytes32);

    function getUInt(bytes32, bytes32) returns(uint) ;
    function getUInt8(bytes32, bytes32) returns(uint8) ;
    function getInt(bytes32, bytes32) returns(int) ;
    function getAddress(bytes32, bytes32) returns(address) ;
    function getBool(bytes32, bytes32) returns(bool) ;
    function getBytes32(bytes32, bytes32) returns(bytes32) ;
}
*/

library StorageInterface {

    // DEFINE STORAGE LINK //

    struct Config {
        Storage store;
        bytes32 crate;
    }


    // DEFINE PRIMITIVES //

    struct UInt {
        bytes32 id;
    }

    struct UInt8 {
        bytes32 id;
    }

    struct Int {
        bytes32 id;
    }

    struct Address {
        bytes32 id;
    }

    struct Bool {
        bytes32 id;
    }

    struct Bytes32 {
        bytes32 id;
    }

    struct Mapping {
        bytes32 id;
    }


    // DEFINE MAPPINGS //

    struct AddressAddressMapping {
        Mapping innerMapping;
    }

    struct AddressBoolMapping {
        Mapping innerMapping;
    }

    struct UintAddressBoolMapping {
        Mapping innerMapping;
    }

    struct AddressBytes32Mapping {
        Mapping innerMapping;
    }

    struct AddressUInt8Mapping {
        bytes32 id;
    }

    struct AddressUIntMapping {
        Mapping innerMapping;
    }

    struct AddressUIntUInt8Mapping {
        Mapping innerMapping;
    }

    struct UIntUIntBoolMapping {
        Mapping innerMapping;
    }

    struct AddressBytes4BoolMapping {
        Mapping innerMapping;
    }

    struct AddressBytes4Bytes32Mapping {
        Mapping innerMapping;
    }

    struct AddressUIntUIntMapping {
        Mapping innerMapping;
    }

    struct AddressUIntUIntUIntMapping {
        Mapping innerMapping;
    }

    struct AddressAddressUIntMapping {
        Mapping innerMapping;
    }

    struct AddressAddressUInt8Mapping {
        Mapping innerMapping;
    }

    struct AddressBytes32Bytes32Mapping {
        Mapping innerMapping;
    }

    struct UIntAddressMapping {
        Mapping innerMapping;
    }

    struct UIntAddressAddressMapping {
        Mapping innerMapping;
    }

    struct UIntAddressUIntMapping {
        Mapping innerMapping;
    }

    struct UIntBoolMapping {
        Mapping innerMapping;
    }

    struct UIntUIntMapping {
        Mapping innerMapping;
    }

    struct UIntEnumMapping {
        Mapping innerMapping;
    }

    struct AddressUIntAddressUInt8Mapping {
        Mapping innerMapping;
    }

    struct AddressUIntUIntAddressUInt8Mapping {
        Mapping innerMapping;
    }

    struct AddressUIntUIntUIntAddressUInt8Mapping {
        Mapping innerMapping;
    }

    struct UIntBytes32Mapping {
        Mapping innerMapping;
    }

    struct UIntUIntBytes32Mapping {
        Mapping innerMapping;
    }

    struct UIntUIntUIntBytes32Mapping {
        Mapping innerMapping;
    }

    struct Bytes32UIntMapping {
        Mapping innerMapping;
    }

    struct Bytes32AddressMapping {
        Mapping innerMapping;
    }

    struct Set {
        UInt count;
        Mapping indexes;
        Mapping values;
    }

    struct AddressesSet {
        Set innerSet;
    }

    struct StringAddressSetMapping {
        Set innerSet;
    }

    // Can't use modifier due to a Solidity bug.
    function sanityCheck(bytes32 _currentId, bytes32 _newId) internal pure {
        if (_currentId != 0 || _newId == 0) {
            revert();
        }
    }

    /// INITIATION ///

    function init(Config storage self, Storage _store, bytes32 _crate) internal {
        self.store = _store;
        self.crate = _crate;
    }


    /// INIT PRIMITIVES ///

    function init(UInt storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(UInt8 storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(Int storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(Address storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(Bool storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(Bytes32 storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    /// INIT LOW-LEVEL MAPPING ///

    function init(Mapping storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }


    /// INIT HIGH-LEVEL MAPPINGS ///

    function init(AddressAddressMapping storage self, bytes32 _id) internal {
        // TODO : TESTING
        init(self.innerMapping, _id);
    }

    function init(AddressBoolMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UintAddressBoolMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressBytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUInt8Mapping storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(AddressUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntUInt8Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntUIntBoolMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressBytes4BoolMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressBytes4Bytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntUIntUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressAddressUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressAddressUInt8Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressBytes32Bytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntBytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntAddressMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntAddressAddressMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntAddressUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntBoolMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntEnumMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntAddressUInt8Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntUIntAddressUInt8Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntUIntUIntAddressUInt8Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntUIntBytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntUIntUIntBytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(Bytes32UIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(Bytes32AddressMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    /// INIT SETS ///

    function init(Set storage self, bytes32 _id) internal {
        init(self.count, keccak256(abi.encodePacked(_id, 'count')));
        init(self.indexes, keccak256(abi.encodePacked(_id, 'indexes')));
        init(self.values, keccak256(abi.encodePacked(_id, 'values')));
    }

    function init(AddressesSet storage self, bytes32 _id) internal {
        init(self.innerSet, _id);
    }

    function init(StringAddressSetMapping storage self, bytes32 _id) internal {
        init(self.innerSet, _id);
    }

    /// SET PRIMITIVES ///

    function set(Config storage self, UInt storage item, uint _value) internal {
        self.store.setUInt(self.crate, item.id, _value);
    }

    function set(Config storage self, UInt storage item, bytes32 _key, uint _value) internal {
        self.store.setUInt(self.crate, keccak256(abi.encodePacked(item.id, _key)), _value);
    }

    function set(Config storage self, UInt8 storage item, uint8 _value) internal {
        self.store.setUInt8(self.crate, item.id, _value);
    }

    function set(Config storage self, Int storage item, int _value) internal {
        self.store.setInt(self.crate, item.id, _value);
    }

    function set(Config storage self, Address storage item, address _value) internal {
        self.store.setAddress(self.crate, item.id, _value);
    }

    function set(Config storage self, Bool storage item, bool _value) internal {
        self.store.setBool(self.crate, item.id, _value);
    }

    function set(Config storage self, Bytes32 storage item, bytes32 _value) internal {
        self.store.setBytes32(self.crate, item.id, _value);
    }


    /// SET LOW-LEVEL MAPPINGS ///

    function set(Config storage self, Mapping storage item, bytes32 _key, bytes32 _value) internal {
        self.store.setBytes32(self.crate, keccak256(abi.encodePacked(item.id, _key)), _value);
    }

    function set(Config storage self, Mapping storage item, bytes32 _key, bytes32 _key2, bytes32 _value) internal {
        set(self, item, keccak256(abi.encodePacked(_key, _key2)), _value);
    }

    function set(Config storage self, Mapping storage item, bytes32 _key, bytes32 _key2, bytes32 _key3, bytes32 _value) internal {
        set(self, item, keccak256(abi.encodePacked(_key, _key2, _key3)), _value);
    }



    /// SET HIGH-LEVEL MAPPINGS ///

    function set(Config storage self, AddressAddressMapping storage item, address _key, address _value) internal {
        // TODO : TESTING
        set(self, item.innerMapping, addressToBytes32(_key), addressToBytes32(_value));
    }

    function set(Config storage self, AddressBoolMapping storage item, address _key, bool _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), toBytes32(_value));
    }

    function set(Config storage self, UintAddressBoolMapping storage item, uint _key, address _key2, bool _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(uint256(_key2)), toBytes32(_value));
    }

    function set(Config storage self, AddressBytes32Mapping storage item, address _key, bytes32 _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), _value);
    }

    function set(Config storage self, AddressUIntMapping storage item, address _key, uint _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_value));
    }

    function set(Config storage self, AddressUIntUInt8Mapping storage item, address _key, uint _key2, uint8 _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), bytes32(uint256(_value)));
    }

    function set(Config storage self, UIntUIntBoolMapping storage item, uint _key, uint _key2, bool _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(_key2), toBytes32(_value));
    }

    function set(Config storage self, AddressBytes4BoolMapping storage item, address _key, bytes4 _key2, bool _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), toBytes32(_value));
    }

    function set(Config storage self, AddressBytes4Bytes32Mapping storage item, address _key, bytes4 _key2, bytes32 _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), _value);
    }

    function set(Config storage self, AddressUIntUIntMapping storage item, address _key, uint _key2, uint _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), bytes32(_value));
    }

    function set(Config storage self, AddressUIntUIntUIntMapping storage item, address _key, uint _key2,  uint _key3, uint _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), bytes32(_key3), bytes32(_value));
    }

    function set(Config storage self, AddressAddressUIntMapping storage item, address _key, address _key2, uint _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), addressToBytes32(_key2), bytes32(_value));
    }

    function set(Config storage self, AddressAddressUInt8Mapping storage item, address _key, address _key2, uint8 _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), addressToBytes32(_key2), bytes32(uint256(_value)));
    }

    function set(Config storage self, AddressBytes32Bytes32Mapping storage item, address _key, bytes32 _key2, bytes32 _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), _key2, _value);
    }

    function set(Config storage self, UIntBytes32Mapping storage item, uint _key, bytes32 _value) internal {
        set(self, item.innerMapping, bytes32(_key), _value);
    }

    function set(Config storage self, UIntAddressMapping storage item, uint _key, address _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(uint256(_value)));
    }

    function set(Config storage self, UIntBoolMapping storage item, uint _key, bool _value) internal {
        set(self, item.innerMapping, bytes32(_key), toBytes32(_value));
    }

    function set(Config storage self, UIntAddressAddressMapping storage item, uint _key, address _key2, address _value) internal {
        set(self, item.innerMapping, bytes32(_key), addressToBytes32(_key2), addressToBytes32(_value));
    }

    function set(Config storage self, UIntAddressUIntMapping storage item, uint _key, address _key2, uint _value) internal {
        set(self, item.innerMapping, bytes32(_key), addressToBytes32(_key2), bytes32(_value));
    }

    function set(Config storage self, UIntUIntMapping storage item, uint _key, uint _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(_value));
    }

    function set(Config storage self, UIntEnumMapping storage item, uint _key, uint8 _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(uint256(_value)));
    }

    function set(Config storage self, AddressUIntAddressUInt8Mapping storage item, address _key, uint _key2, address _key3, uint8 _value) internal {
        set(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3)), bytes32(uint256(_value)));
    }

    function set(Config storage self, AddressUIntUIntAddressUInt8Mapping storage item, address _key, uint _key2, uint _key3, address _key4, uint8 _value) internal {
        set(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3, _key4)), bytes32(uint256(_value)));
    }

    function set(Config storage self, AddressUIntUIntUIntAddressUInt8Mapping storage item, address _key, uint _key2,  uint _key3, uint _key4, address _key5, uint8 _value) internal {
        set(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3, _key4, _key5)), bytes32(uint256(_value)));
    }

    function set(Config storage self, UIntUIntBytes32Mapping storage item, uint _key, uint _key2, bytes32 _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(_key2), _value);
    }

    function set(Config storage self, UIntUIntUIntBytes32Mapping storage item, uint _key, uint _key2,  uint _key3, bytes32 _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(_key2), bytes32(_key3), _value);
    }

    function set(Config storage self, Bytes32UIntMapping storage item, bytes32 _key, uint _value) internal {
        set(self, item.innerMapping, _key, bytes32(_value));
    }

    function set(Config storage self, Bytes32AddressMapping storage item, bytes32 _key, address _value) internal {
        set(self, item.innerMapping, _key, bytes32(uint256(_value)));
    }


    /// OPERATIONS ON SETS ///
    
    function add(Config storage self, Set storage item, bytes32 _value) internal {
        if (includes(self, item, _value)) {
            return;
        }
        uint newCount = count(self, item) + 1;
        set(self, item.values, bytes32(newCount), _value);
        set(self, item.indexes, _value, bytes32(newCount));
        set(self, item.count, newCount);
    }

    function add(Config storage self, AddressesSet storage item, address _value) internal {
        add(self, item.innerSet, addressToBytes32(_value));
    }

    function add(Config storage self, StringAddressSetMapping storage item, string memory _key, address _value) internal {
        if (includes(self, item, _key, _value)) {
            return;
        }
        uint newCount = count(self, item, _key) + 1;
        set(self, item.innerSet.values, keccak256(abi.encodePacked(_key, newCount)), addressToBytes32(_value));
        set(self, item.innerSet.indexes, keccak256(abi.encodePacked(_key)), addressToBytes32(_value), bytes32(newCount));
        set(self, item.innerSet.count, keccak256(abi.encodePacked(_key)), newCount);
    }

    function remove(Config storage self, Set storage item, bytes32 _value) internal {
        if (!includes(self, item, _value)) {
            return;
        }
        uint lastIndex = count(self, item);
        bytes32 lastValue = get(self, item.values, bytes32(lastIndex));
        uint index = uint(get(self, item.indexes, _value));
        if (index < lastIndex) {
            set(self, item.indexes, lastValue, bytes32(index));
            set(self, item.values, bytes32(index), lastValue);
        }
        set(self, item.indexes, _value, bytes32(0));
        set(self, item.values, bytes32(lastIndex), bytes32(0));
        set(self, item.count, lastIndex - 1);
    }

    function remove(Config storage self, AddressesSet storage item, address _value) internal {
        remove(self, item.innerSet, addressToBytes32(_value));
    }


    /// GET PRIMITIVES ///

    function get(Config storage self, UInt storage item) internal view returns(uint) {
        return self.store.getUInt(self.crate, item.id);
    }

    function get(Config storage self, UInt storage item, bytes32 _key) internal view returns(uint) {
        return self.store.getUInt(self.crate, keccak256(abi.encodePacked(item.id, _key)));
    }

    function get(Config storage self, UInt8 storage item) internal view returns(uint8) {
        return self.store.getUInt8(self.crate, item.id);
    }

    function get(Config storage self, Int storage item) internal view returns(int) {
        return self.store.getInt(self.crate, item.id);
    }

    function get(Config storage self, Address storage item) internal view returns(address) {
        return self.store.getAddress(self.crate, item.id);
    }

    function get(Config storage self, Bool storage item) internal view returns(bool) {
        return self.store.getBool(self.crate, item.id);
    }

    function get(Config storage self, Bytes32 storage item) internal view returns(bytes32) {
        return self.store.getBytes32(self.crate, item.id);
    }


    /// GET LOW-LEVEL MAPPINGS ///

    function get(Config storage self, Mapping storage item, bytes32 _key) internal view returns(bytes32) {
        return self.store.getBytes32(self.crate, keccak256(abi.encodePacked(item.id, _key)));
    }

    function get(Config storage self, Mapping storage item, bytes32 _key, bytes32 _key2) internal view returns(bytes32) {
        return get(self, item, keccak256(abi.encodePacked(_key, _key2)));
    }

    function get(Config storage self, Mapping storage item, bytes32 _key, bytes32 _key2, bytes32 _key3) internal view returns(bytes32) {
        return get(self, item, keccak256(abi.encodePacked(_key, _key2, _key3)));
    }


    /// GET HIGH-LEVEL MAPPINGS ///

    function get(Config storage self, AddressAddressMapping storage item, address _key) internal view returns(address) {
        // TODO : TESTING
        return bytes32ToAddress(get(self, item.innerMapping, addressToBytes32(_key)));
    }

    function get(Config storage self, AddressBoolMapping storage item, address _key) internal view returns(bool) {
        return toBool(get(self, item.innerMapping, addressToBytes32(_key)));
    }

    function get(Config storage self, UintAddressBoolMapping storage item, uint _key, address _key2) internal view returns(bool) {
        return toBool(get(self, item.innerMapping, bytes32(_key), addressToBytes32(_key2)));
    }

    function get(Config storage self, AddressBytes32Mapping storage item, address _key) internal view returns(bytes32) {
        return get(self, item.innerMapping, addressToBytes32(_key));
    }

    function get(Config storage self, AddressUIntMapping storage item, address _key) internal view returns(uint) {
        return uint(get(self, item.innerMapping, addressToBytes32(_key)));
    }

    function get(Config storage self, AddressUIntUInt8Mapping storage item, address _key, uint _key2) internal view returns(uint) {
        return uint8(uint256(get(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2))));
    }

    function get(Config storage self, UIntUIntBoolMapping storage item, uint _key, uint _key2) internal view returns(bool) {
        return toBool(get(self, item.innerMapping, bytes32(_key), bytes32(_key2)));
    }

    function get(Config storage self, AddressBytes4BoolMapping storage item, address _key, bytes4 _key2) internal view returns(bool) {
        return toBool(get(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2)));
    }

    function get(Config storage self, AddressBytes4Bytes32Mapping storage item, address _key, bytes4 _key2) internal view returns(bytes32) {
        return get(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2));
    }

    function get(Config storage self, AddressUIntUIntMapping storage item, address _key, uint _key2) internal view returns(uint) {
        return uint(get(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2)));
    }

    function get(Config storage self, AddressUIntUIntUIntMapping storage item, address _key, uint _key2, uint _key3) internal view returns(uint) {
        return uint(get(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), bytes32(_key3)));
    }

    function get(Config storage self, AddressAddressUIntMapping storage item, address _key, address _key2) internal view returns(uint) {
        return uint(get(self, item.innerMapping, addressToBytes32(_key), addressToBytes32(_key2)));
    }

    function get(Config storage self, AddressAddressUInt8Mapping storage item, address _key, address _key2) internal view returns(uint8) {
        return uint8(uint256(get(self, item.innerMapping, addressToBytes32(_key), addressToBytes32(_key2))));
    }

    function get(Config storage self, AddressBytes32Bytes32Mapping storage item, address _key, bytes32 _key2) internal view returns(bytes32) {
        return get(self, item.innerMapping, addressToBytes32(_key), _key2);
    }

    function get(Config storage self, UIntBytes32Mapping storage item, uint _key) internal view returns(bytes32) {
        return get(self, item.innerMapping, bytes32(_key));
    }

    function get(Config storage self, UIntAddressMapping storage item, uint _key) internal view returns(address) {
        return bytes32ToAddress(get(self, item.innerMapping, bytes32(_key)));
    }

    function get(Config storage self, UIntBoolMapping storage item, uint _key) internal view returns(bool) {
        return toBool(get(self, item.innerMapping, bytes32(_key)));
    }

    function get(Config storage self, UIntAddressAddressMapping storage item, uint _key, address _key2) internal view returns(address) {
        return bytes32ToAddress(get(self, item.innerMapping, bytes32(_key), addressToBytes32(_key2)));
    }

    function get(Config storage self, UIntAddressUIntMapping storage item, uint _key, address _key2) internal view returns(uint) {
        return uint(get(self, item.innerMapping, bytes32(_key), addressToBytes32(_key2)));
    }

    function get(Config storage self, UIntUIntMapping storage item, uint _key) internal view returns(uint) {
        return uint(get(self, item.innerMapping, bytes32(_key)));
    }

    function get(Config storage self, UIntEnumMapping storage item, uint _key) internal view returns(uint8) {
        return uint8(uint256(get(self, item.innerMapping, bytes32(_key))));
    }

    function get(Config storage self, AddressUIntAddressUInt8Mapping storage item, address _key, uint _key2, address _key3) internal view returns(uint8) {
        return uint8(uint256(get(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3)))));
    }

    function get(Config storage self, AddressUIntUIntAddressUInt8Mapping storage item, address _key, uint _key2, uint _key3, address _key4) internal view returns(uint8) {
        return uint8(uint256(get(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3, _key4)))));
    }

    function get(Config storage self, AddressUIntUIntUIntAddressUInt8Mapping storage item, address _key, uint _key2, uint _key3, uint _key4, address _key5) internal view returns(uint8) {
        return uint8(uint256(get(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3, _key4, _key5)))));
    }

    function get(Config storage self, UIntUIntBytes32Mapping storage item, uint _key, uint _key2) internal view returns(bytes32) {
        return get(self, item.innerMapping, bytes32(_key), bytes32(_key2));
    }

    function get(Config storage self, UIntUIntUIntBytes32Mapping storage item, uint _key, uint _key2, uint _key3) internal view returns(bytes32) {
        return get(self, item.innerMapping, bytes32(_key), bytes32(_key2), bytes32(_key3));
    }

    function get(Config storage self, Bytes32UIntMapping storage item, bytes32 _key) internal view returns(uint) {
        return uint(get(self, item.innerMapping, _key));
    }

    function get(Config storage self, Bytes32AddressMapping storage item, bytes32 _key) internal view returns(address) {
        return bytes32ToAddress(get(self, item.innerMapping, _key));
    }


    /// OPERATIONS ON SETS ///

    function includes(Config storage self, Set storage item, bytes32 _value) internal view returns(bool) {
        return get(self, item.indexes, _value) != 0;
    }

    function includes(Config storage self, StringAddressSetMapping storage item, string memory _key, address _value) internal view returns(bool) {
        return get(self, item.innerSet.indexes, keccak256(abi.encodePacked(_key)), addressToBytes32(_value)) != 0;
    }

    function includes(Config storage self, AddressesSet storage item, address _value) internal view returns(bool) {
        return includes(self, item.innerSet, addressToBytes32(_value));
    }

    function count(Config storage self, Set storage item) internal view returns(uint) {
        return get(self, item.count);
    }

    function count(Config storage self, AddressesSet storage item) internal view returns(uint) {
        return count(self, item.innerSet);
    }

    function count(Config storage self, StringAddressSetMapping storage item, string memory _key) internal view returns(uint) {
        return get(self, item.innerSet.count, keccak256(abi.encodePacked(_key)));
    }

    function get(Config storage self, Set storage item) internal view returns(bytes32[] memory) {
        uint valuesCount = count(self, item);
        bytes32[] memory result = new bytes32[](valuesCount);
        for (uint i = 0; i < valuesCount; i++) {
            result[i] = get(self, item, i);
        }
        return result;
    }

    function get(Config storage self, StringAddressSetMapping storage item, string memory _key) internal view returns(address[] memory) {
        uint valuesCount = count(self, item, _key);
        bytes32[] memory result = new bytes32[](valuesCount);
        for (uint i = 0; i < valuesCount; i++) {
            result[i] = get(self, item, _key, i);
        }
        return toAddresses(result);
    }

    function get(Config storage self, AddressesSet storage item) internal view returns(address[] memory) {
        return toAddresses(get(self, item.innerSet));
    }

    function get(Config storage self, Set storage item, uint _index) internal view returns(bytes32) {
        return get(self, item.values, bytes32(_index + 1));
    }

    function get(Config storage self, StringAddressSetMapping storage item, string memory _key, uint _index) internal view returns(bytes32) {
        return get(self, item.innerSet.values, keccak256(abi.encodePacked(_key, bytes32(_index + 1))));
    }

    function get(Config storage self, AddressesSet storage item, uint _index) internal view returns(address) {
        return bytes32ToAddress(get(self, item.innerSet, _index));
    }


    /// HELPERS ///

    function toBool(bytes32 self) pure public returns(bool) {
        return self != bytes32(0);
    }

    function toBytes32(bool self) pure public returns(bytes32) {
        return bytes32(self ? uint256(1) : 0);
    }

    function toAddresses(bytes32[] memory self) pure public returns(address[] memory) {
        address[] memory result = new address[](self.length);
        for (uint i = 0; i < self.length; i++) {
            result[i] = bytes32ToAddress(self[i]);
        }
        return result;
    }
    
    // These helpers introduced after moving to solidity v.0.5 since
    // types with different size now cannot be casted implicitly
    function bytes32ToAddress(bytes32 b) pure private returns(address) {
        return address(uint160(uint256(b)));
    }
    
    function addressToBytes32(address addr) pure private returns(bytes32) {
        return bytes32(uint256(addr));
    }
}

pragma solidity ^0.5.8;

import "./Ownable.sol";

contract FeeCalcInterface {
    function getFee() public view returns(uint256);
    function getCompanyFee() public view returns(uint256);
    function getNetworkGrowthFee() public view returns(uint256);
}

contract ERC20Interface {
    function transfer(address, uint256) public returns (bool);
}

contract DocumentRegistryInterface {
    function register(address) public;
    function feeCalc() public view returns(address);

    function companyWallet() public view returns(address);
    function networkGrowthPoolWallet() public view returns(address);
    function token() public view returns(address);
}

contract Agent is Ownable {

    DocumentRegistryInterface public documentRegistry;
    string public name;

    address public user;

    event Error(string msg);

    modifier onlyRegisteredUser() {
        uint256 code = 0;
        address _sender = msg.sender;
        if (_sender == user) {
            _;
        }
        else {
            emit Error("User does not registered");
        }
    }

    constructor(address _documentRegistry, address _owner, address _user) public {
        documentRegistry = DocumentRegistryInterface(_documentRegistry);
        owner = _owner;
        user = _user;
    }

    function setDocumentRegistry(address _documentRegistry) public onlyOwner {
        documentRegistry = DocumentRegistryInterface(_documentRegistry);
    }

    function setName(string memory _name) public onlyOwner {
        name = _name;
    }

    function setUser(address _user) public onlyOwner {
        user = _user;
    }

    function register(address _document) public onlyRegisteredUser {
        FeeCalcInterface feeCalc = FeeCalcInterface(documentRegistry.feeCalc());

        documentRegistry.register(_document);

        // Transfer fee to company wallet
        address companyWallet = documentRegistry.companyWallet();
        assert(companyWallet != address(0));
        uint256 companyFee = feeCalc.getCompanyFee();
        assert(ERC20Interface(documentRegistry.token()).transfer(companyWallet, companyFee));

        // Transfer fee to network wallet
        address networkGrowthPoolWallet = documentRegistry.networkGrowthPoolWallet();
        assert(networkGrowthPoolWallet != address(0));
        uint256 networkGrowthFee = feeCalc.getNetworkGrowthFee();
        assert(ERC20Interface(documentRegistry.token()).transfer(networkGrowthPoolWallet, networkGrowthFee));
    }

}


pragma solidity 0.5.8;

import "./Owned.sol";

contract BaseDocument is Owned {

    bytes32 public hash;
    string[] public tags;

    bool public finalized;

    modifier isNotFinalized() {
        require(!finalized, "Contract is finalized");
        _;
    }

    constructor(bytes32 _hash) public {
        hash = _hash;
    }

    function proxy_init(address _owner, bytes32 _hash) public {
        require(contractOwner == address(0));
        contractOwner = _owner;
        hash = _hash;
    }

    function setHash(bytes32 _hash) public isNotFinalized onlyContractOwner {
        hash = _hash;
    }

    function addTag(string memory _key) public isNotFinalized onlyContractOwner {
        require(tagsLength() < 32, "Tags is too many!");
        tags.push(_key);
    }

    function setFinalized() public isNotFinalized onlyContractOwner {
        finalized = true;
    }

    function tagsLength() public view returns(uint256) {
        return tags.length;
    }

    function documentType() public pure returns(bytes32) {
        return keccak256("basic");
    }

}


pragma solidity 0.5.8;

import "./Storage.sol";
import "./StorageAdapter.sol";
import "./RolesLibraryAdapter.sol";
import "./BaseDocument.sol";

contract DocumentRegistry is StorageAdapter, RolesLibraryAdapter {

    address public companyWallet;
    address public networkGrowthPoolWallet;
    address public feeCalc;
    address public token;

    StorageInterface.Bytes32AddressMapping documents;
    StorageInterface.StringAddressSetMapping tags;
    StorageInterface.AddressBytes32Bytes32Mapping documentsv2;

    event DocumentRegistered(address _document, bytes32 _hash, bytes32 _type);
    event DocumentRegisteredv2(bytes32 _hash, bytes32 _metahash);
    event Error(string _message);

    modifier isDocumentFinalized(BaseDocument _document) {
        if(!_document.finalized()) {
            emit Error("Document is not finalized");
            return;
        }
        _;
    }

    constructor(
        Storage _store,
        bytes32 _crate,
        address _companyWallet,
        address _networkGrowthPoolWallet,
        address _feeCalc,
        address _token,
        address _rolesLibrary
    ) public StorageAdapter(_store, _crate) RolesLibraryAdapter(_rolesLibrary) {
        companyWallet = _companyWallet;
        networkGrowthPoolWallet = _networkGrowthPoolWallet;
        feeCalc = _feeCalc;
        token = _token;
        documents.init("RegisteredDocuments");
        tags.init("ContainsTagDocuments");
    }

    function proxy_init(
        Storage _store,
        bytes32 _crate,
        address _companyWallet,
        address _networkGrowthPoolWallet,
        address _feeCalc,
        address _token,
        address _rolesLibrary
    ) public {
        require(address(rolesLibrary) == address(0));
        store.init(_store, _crate);
        rolesLibrary = RolesLibraryInterface(_rolesLibrary);
        companyWallet = _companyWallet;
        networkGrowthPoolWallet = _networkGrowthPoolWallet;
        feeCalc = _feeCalc;
        token = _token;
        documents.init("RegisteredDocuments");
        tags.init("ContainsTagDocuments");
        documentsv2.init("RegisteredDocumentsv2");
    }

    function setWallets(address _companyWallet, address _networkGrowthPoolWallet) public auth {
        companyWallet = _companyWallet;
        networkGrowthPoolWallet = _networkGrowthPoolWallet;
    }

    function setFeeCalc(address _feeCalc) public auth {
        feeCalc = _feeCalc;
    }

    function register(BaseDocument _document) public auth isDocumentFinalized(_document) {
        require(!exists(_document.hash()), "Document is already exists!");
        store.set(documents, _document.hash(), address(_document));
        for(uint256 i = 0; i < _document.tagsLength(); ++i) {
            store.add(tags, _document.tags(i), address(_document));
        }
        emit DocumentRegistered(address(_document), _document.hash(), _document.documentType());
    }

    function getDocument(bytes32 _hash) public view returns(address) {
        return store.get(documents, _hash);
    }

    function getDocumentsByTag(string memory _tag) public view returns(address[] memory) {
        return store.get(tags, _tag);
    }

    function exists(bytes32 _hash) public view returns(bool) {
        return store.get(documents, _hash) != address(0);
    }
    
    // Access methods for version 2 (only hash)
    // Here we don't deploy contract for document but just store physical(electronic) document hash
    // and metadata hash which is just JSON with all the data related to registration.
    
    function registerv2(bytes32 _hash, bytes32 _metahash) public auth {
        require(!existsv2(_hash), "Document already exists!");
        store.set(documentsv2, address(0), _hash, _metahash);
        emit DocumentRegisteredv2(_hash, _metahash);
    }
    
     function existsv2(bytes32 _hash) public view returns(bool) {
        return store.get(documentsv2, address(0), _hash) != bytes32(0);
    }
    
    function getMetahash(bytes32 _hash) public view returns(bytes32) {
        return store.get(documentsv2, address(0), _hash);
    }

}

pragma solidity ^0.5.8;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {

    address public owner;

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
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }

}



pragma solidity ^0.5.8;


/**
 * @title Owned contract with safe ownership pass.
 *
 * Note: all the non constant functions return false instead of throwing in case if state change
 * didn't happen yet.
 */
contract Owned {
    address public contractOwner;
    address public pendingContractOwner;

    constructor () public {
        contractOwner = msg.sender;
    }

    modifier onlyContractOwner() {
        if (contractOwner == msg.sender || contractOwner == address(0)) {
            _;
        }
    }

    /**
     * Prepares ownership pass.
     *
     * Can only be called by current owner.
     *
     * @param _to address of the next owner.
     *
     * @return success.
     */
    function changeContractOwnership(address _to) public onlyContractOwner returns(bool) {
        pendingContractOwner = _to;
        return true;
    }

    /**
     * Finalize ownership pass.
     *
     * Can only be called by pending owner.
     *
     * @return success.
     */
    function claimContractOwnership() public returns(bool) {
        if (pendingContractOwner != msg.sender) {
            return false;
        }
        contractOwner = pendingContractOwner;
        delete pendingContractOwner;
        return true;
    }

    /**
     * Force ownership pass.
     *
     * Can only be called by current owner.
     *
     * @param _to address of the next owner.
     *
     * @return success.
     */
    function forceChangeContractOwnership(address _to) public onlyContractOwner returns(bool) {
        contractOwner = _to;
        return true;
    }

}


pragma solidity 0.5.8;


contract RolesLibraryInterface {
    function canCall(address, address, bytes4) public view returns(bool);
}

contract RolesLibraryAdapter {
    RolesLibraryInterface rolesLibrary;

    event Unauthorized(address user);

    modifier auth() {
        if (!_isAuthorized(msg.sender, msg.sig)) {
            emit Unauthorized(msg.sender);
            return;
        }
        _;
    }

    constructor(address _rolesLibrary) public {
        rolesLibrary = RolesLibraryInterface(_rolesLibrary);
    }

    function setRolesLibrary(RolesLibraryInterface _rolesLibrary) auth() public returns(bool) {
        rolesLibrary = _rolesLibrary;
        return true;
    }

    function _isAuthorized(address _src, bytes4 _sig) internal view returns(bool) {
        if (_src == address(this)) {
            return true;
        }
        if (address(rolesLibrary) == address(0)) {
            return false;
        }
        return rolesLibrary.canCall(_src, address(this), _sig);
    }
}


pragma solidity 0.5.8;

import "./Owned.sol";


contract Manager {
    function isAllowed(address _actor, bytes32 _role) view public returns(bool);
}

contract Storage is Owned {

    struct Crate {
        mapping(bytes32 => uint) uints;
        mapping(bytes32 => address) addresses;
        mapping(bytes32 => bool) bools;
        mapping(bytes32 => int) ints;
        mapping(bytes32 => uint8) uint8s;
        mapping(bytes32 => bytes32) bytes32s;
    }

    mapping(bytes32 => Crate) crates;
    Manager public manager;

    modifier onlyAllowed(bytes32 _role) {
        if (!manager.isAllowed(msg.sender, _role)) {
            revert();
        }
        _;
    }

    function setManager(Manager _manager) onlyContractOwner public returns(bool) {
        manager = _manager;
        return true;
    }

    function setUInt(bytes32 _crate, bytes32 _key, uint _value) onlyAllowed(_crate) public {
        crates[_crate].uints[_key] = _value;
    }

    function getUInt(bytes32 _crate, bytes32 _key) view public returns(uint) {
        return crates[_crate].uints[_key];
    }

    function setUInt8(bytes32 _crate, bytes32 _key, uint8 _value) onlyAllowed(_crate) public {
        crates[_crate].uint8s[_key] = _value;
    }

    function getUInt8(bytes32 _crate, bytes32 _key) view public returns(uint8) {
        return crates[_crate].uint8s[_key];
    }

    function setInt(bytes32 _crate, bytes32 _key, int _value) onlyAllowed(_crate) public {
        crates[_crate].ints[_key] = _value;
    }

    function getInt(bytes32 _crate, bytes32 _key) view public returns(int) {
        return crates[_crate].ints[_key];
    }

    function setAddress(bytes32 _crate, bytes32 _key, address _value) onlyAllowed(_crate) public {
        crates[_crate].addresses[_key] = _value;
    }

    function getAddress(bytes32 _crate, bytes32 _key) view public returns(address) {
        return crates[_crate].addresses[_key];
    }

    function setBool(bytes32 _crate, bytes32 _key, bool _value) onlyAllowed(_crate) public {
        crates[_crate].bools[_key] = _value;
    }

    function getBool(bytes32 _crate, bytes32 _key) view public returns(bool) {
        return crates[_crate].bools[_key];
    }

    function setBytes32(bytes32 _crate, bytes32 _key, bytes32 _value) onlyAllowed(_crate) public {
        crates[_crate].bytes32s[_key] = _value;
    }

    function getBytes32(bytes32 _crate, bytes32 _key) view public returns(bytes32) {
        return crates[_crate].bytes32s[_key];
    }


    /// RESTRICTIONS & DISASTER RECOVERY ///

    function kill() public onlyContractOwner {
        selfdestruct(msg.sender);
    }

    // FIXME: Add maintenance mode


}


pragma solidity 0.5.8;

import "./StorageInterface.sol";


contract StorageAdapter {
    using StorageInterface for *;

    StorageInterface.Config store;

    constructor(Storage _store, bytes32 _crate) public {
        assert(_crate != bytes32(0));
        store.init(_store, _crate);
    }
}
pragma solidity 0.5.8;

import "./Storage.sol";

/*
contract StorageMethods {
    function setUInt(bytes32, bytes32, uint);
    function setUInt8(bytes32, bytes32, uint8);
    function setInt(bytes32, bytes32, int);
    function setAddress(bytes32, bytes32, address);
    function setBool(bytes32, bytes32, bool);
    function setBytes32(bytes32, bytes32, bytes32);

    function getUInt(bytes32, bytes32) returns(uint) ;
    function getUInt8(bytes32, bytes32) returns(uint8) ;
    function getInt(bytes32, bytes32) returns(int) ;
    function getAddress(bytes32, bytes32) returns(address) ;
    function getBool(bytes32, bytes32) returns(bool) ;
    function getBytes32(bytes32, bytes32) returns(bytes32) ;
}
*/

library StorageInterface {

    // DEFINE STORAGE LINK //

    struct Config {
        Storage store;
        bytes32 crate;
    }


    // DEFINE PRIMITIVES //

    struct UInt {
        bytes32 id;
    }

    struct UInt8 {
        bytes32 id;
    }

    struct Int {
        bytes32 id;
    }

    struct Address {
        bytes32 id;
    }

    struct Bool {
        bytes32 id;
    }

    struct Bytes32 {
        bytes32 id;
    }

    struct Mapping {
        bytes32 id;
    }


    // DEFINE MAPPINGS //

    struct AddressAddressMapping {
        Mapping innerMapping;
    }

    struct AddressBoolMapping {
        Mapping innerMapping;
    }

    struct UintAddressBoolMapping {
        Mapping innerMapping;
    }

    struct AddressBytes32Mapping {
        Mapping innerMapping;
    }

    struct AddressUInt8Mapping {
        bytes32 id;
    }

    struct AddressUIntMapping {
        Mapping innerMapping;
    }

    struct AddressUIntUInt8Mapping {
        Mapping innerMapping;
    }

    struct UIntUIntBoolMapping {
        Mapping innerMapping;
    }

    struct AddressBytes4BoolMapping {
        Mapping innerMapping;
    }

    struct AddressBytes4Bytes32Mapping {
        Mapping innerMapping;
    }

    struct AddressUIntUIntMapping {
        Mapping innerMapping;
    }

    struct AddressUIntUIntUIntMapping {
        Mapping innerMapping;
    }

    struct AddressAddressUIntMapping {
        Mapping innerMapping;
    }

    struct AddressAddressUInt8Mapping {
        Mapping innerMapping;
    }

    struct AddressBytes32Bytes32Mapping {
        Mapping innerMapping;
    }

    struct UIntAddressMapping {
        Mapping innerMapping;
    }

    struct UIntAddressAddressMapping {
        Mapping innerMapping;
    }

    struct UIntAddressUIntMapping {
        Mapping innerMapping;
    }

    struct UIntBoolMapping {
        Mapping innerMapping;
    }

    struct UIntUIntMapping {
        Mapping innerMapping;
    }

    struct UIntEnumMapping {
        Mapping innerMapping;
    }

    struct AddressUIntAddressUInt8Mapping {
        Mapping innerMapping;
    }

    struct AddressUIntUIntAddressUInt8Mapping {
        Mapping innerMapping;
    }

    struct AddressUIntUIntUIntAddressUInt8Mapping {
        Mapping innerMapping;
    }

    struct UIntBytes32Mapping {
        Mapping innerMapping;
    }

    struct UIntUIntBytes32Mapping {
        Mapping innerMapping;
    }

    struct UIntUIntUIntBytes32Mapping {
        Mapping innerMapping;
    }

    struct Bytes32UIntMapping {
        Mapping innerMapping;
    }

    struct Bytes32AddressMapping {
        Mapping innerMapping;
    }

    struct Set {
        UInt count;
        Mapping indexes;
        Mapping values;
    }

    struct AddressesSet {
        Set innerSet;
    }

    struct StringAddressSetMapping {
        Set innerSet;
    }

    // Can't use modifier due to a Solidity bug.
    function sanityCheck(bytes32 _currentId, bytes32 _newId) internal pure {
        if (_currentId != 0 || _newId == 0) {
            revert();
        }
    }

    /// INITIATION ///

    function init(Config storage self, Storage _store, bytes32 _crate) internal {
        self.store = _store;
        self.crate = _crate;
    }


    /// INIT PRIMITIVES ///

    function init(UInt storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(UInt8 storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(Int storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(Address storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(Bool storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(Bytes32 storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    /// INIT LOW-LEVEL MAPPING ///

    function init(Mapping storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }


    /// INIT HIGH-LEVEL MAPPINGS ///

    function init(AddressAddressMapping storage self, bytes32 _id) internal {
        // TODO : TESTING
        init(self.innerMapping, _id);
    }

    function init(AddressBoolMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UintAddressBoolMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressBytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUInt8Mapping storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(AddressUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntUInt8Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntUIntBoolMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressBytes4BoolMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressBytes4Bytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntUIntUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressAddressUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressAddressUInt8Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressBytes32Bytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntBytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntAddressMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntAddressAddressMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntAddressUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntBoolMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntEnumMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntAddressUInt8Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntUIntAddressUInt8Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntUIntUIntAddressUInt8Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntUIntBytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntUIntUIntBytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(Bytes32UIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(Bytes32AddressMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    /// INIT SETS ///

    function init(Set storage self, bytes32 _id) internal {
        init(self.count, keccak256(abi.encodePacked(_id, 'count')));
        init(self.indexes, keccak256(abi.encodePacked(_id, 'indexes')));
        init(self.values, keccak256(abi.encodePacked(_id, 'values')));
    }

    function init(AddressesSet storage self, bytes32 _id) internal {
        init(self.innerSet, _id);
    }

    function init(StringAddressSetMapping storage self, bytes32 _id) internal {
        init(self.innerSet, _id);
    }

    /// SET PRIMITIVES ///

    function set(Config storage self, UInt storage item, uint _value) internal {
        self.store.setUInt(self.crate, item.id, _value);
    }

    function set(Config storage self, UInt storage item, bytes32 _key, uint _value) internal {
        self.store.setUInt(self.crate, keccak256(abi.encodePacked(item.id, _key)), _value);
    }

    function set(Config storage self, UInt8 storage item, uint8 _value) internal {
        self.store.setUInt8(self.crate, item.id, _value);
    }

    function set(Config storage self, Int storage item, int _value) internal {
        self.store.setInt(self.crate, item.id, _value);
    }

    function set(Config storage self, Address storage item, address _value) internal {
        self.store.setAddress(self.crate, item.id, _value);
    }

    function set(Config storage self, Bool storage item, bool _value) internal {
        self.store.setBool(self.crate, item.id, _value);
    }

    function set(Config storage self, Bytes32 storage item, bytes32 _value) internal {
        self.store.setBytes32(self.crate, item.id, _value);
    }


    /// SET LOW-LEVEL MAPPINGS ///

    function set(Config storage self, Mapping storage item, bytes32 _key, bytes32 _value) internal {
        self.store.setBytes32(self.crate, keccak256(abi.encodePacked(item.id, _key)), _value);
    }

    function set(Config storage self, Mapping storage item, bytes32 _key, bytes32 _key2, bytes32 _value) internal {
        set(self, item, keccak256(abi.encodePacked(_key, _key2)), _value);
    }

    function set(Config storage self, Mapping storage item, bytes32 _key, bytes32 _key2, bytes32 _key3, bytes32 _value) internal {
        set(self, item, keccak256(abi.encodePacked(_key, _key2, _key3)), _value);
    }



    /// SET HIGH-LEVEL MAPPINGS ///

    function set(Config storage self, AddressAddressMapping storage item, address _key, address _value) internal {
        // TODO : TESTING
        set(self, item.innerMapping, addressToBytes32(_key), addressToBytes32(_value));
    }

    function set(Config storage self, AddressBoolMapping storage item, address _key, bool _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), toBytes32(_value));
    }

    function set(Config storage self, UintAddressBoolMapping storage item, uint _key, address _key2, bool _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(uint256(_key2)), toBytes32(_value));
    }

    function set(Config storage self, AddressBytes32Mapping storage item, address _key, bytes32 _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), _value);
    }

    function set(Config storage self, AddressUIntMapping storage item, address _key, uint _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_value));
    }

    function set(Config storage self, AddressUIntUInt8Mapping storage item, address _key, uint _key2, uint8 _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), bytes32(uint256(_value)));
    }

    function set(Config storage self, UIntUIntBoolMapping storage item, uint _key, uint _key2, bool _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(_key2), toBytes32(_value));
    }

    function set(Config storage self, AddressBytes4BoolMapping storage item, address _key, bytes4 _key2, bool _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), toBytes32(_value));
    }

    function set(Config storage self, AddressBytes4Bytes32Mapping storage item, address _key, bytes4 _key2, bytes32 _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), _value);
    }

    function set(Config storage self, AddressUIntUIntMapping storage item, address _key, uint _key2, uint _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), bytes32(_value));
    }

    function set(Config storage self, AddressUIntUIntUIntMapping storage item, address _key, uint _key2,  uint _key3, uint _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), bytes32(_key3), bytes32(_value));
    }

    function set(Config storage self, AddressAddressUIntMapping storage item, address _key, address _key2, uint _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), addressToBytes32(_key2), bytes32(_value));
    }

    function set(Config storage self, AddressAddressUInt8Mapping storage item, address _key, address _key2, uint8 _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), addressToBytes32(_key2), bytes32(uint256(_value)));
    }

    function set(Config storage self, AddressBytes32Bytes32Mapping storage item, address _key, bytes32 _key2, bytes32 _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), _key2, _value);
    }

    function set(Config storage self, UIntBytes32Mapping storage item, uint _key, bytes32 _value) internal {
        set(self, item.innerMapping, bytes32(_key), _value);
    }

    function set(Config storage self, UIntAddressMapping storage item, uint _key, address _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(uint256(_value)));
    }

    function set(Config storage self, UIntBoolMapping storage item, uint _key, bool _value) internal {
        set(self, item.innerMapping, bytes32(_key), toBytes32(_value));
    }

    function set(Config storage self, UIntAddressAddressMapping storage item, uint _key, address _key2, address _value) internal {
        set(self, item.innerMapping, bytes32(_key), addressToBytes32(_key2), addressToBytes32(_value));
    }

    function set(Config storage self, UIntAddressUIntMapping storage item, uint _key, address _key2, uint _value) internal {
        set(self, item.innerMapping, bytes32(_key), addressToBytes32(_key2), bytes32(_value));
    }

    function set(Config storage self, UIntUIntMapping storage item, uint _key, uint _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(_value));
    }

    function set(Config storage self, UIntEnumMapping storage item, uint _key, uint8 _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(uint256(_value)));
    }

    function set(Config storage self, AddressUIntAddressUInt8Mapping storage item, address _key, uint _key2, address _key3, uint8 _value) internal {
        set(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3)), bytes32(uint256(_value)));
    }

    function set(Config storage self, AddressUIntUIntAddressUInt8Mapping storage item, address _key, uint _key2, uint _key3, address _key4, uint8 _value) internal {
        set(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3, _key4)), bytes32(uint256(_value)));
    }

    function set(Config storage self, AddressUIntUIntUIntAddressUInt8Mapping storage item, address _key, uint _key2,  uint _key3, uint _key4, address _key5, uint8 _value) internal {
        set(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3, _key4, _key5)), bytes32(uint256(_value)));
    }

    function set(Config storage self, UIntUIntBytes32Mapping storage item, uint _key, uint _key2, bytes32 _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(_key2), _value);
    }

    function set(Config storage self, UIntUIntUIntBytes32Mapping storage item, uint _key, uint _key2,  uint _key3, bytes32 _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(_key2), bytes32(_key3), _value);
    }

    function set(Config storage self, Bytes32UIntMapping storage item, bytes32 _key, uint _value) internal {
        set(self, item.innerMapping, _key, bytes32(_value));
    }

    function set(Config storage self, Bytes32AddressMapping storage item, bytes32 _key, address _value) internal {
        set(self, item.innerMapping, _key, bytes32(uint256(_value)));
    }


    /// OPERATIONS ON SETS ///
    
    function add(Config storage self, Set storage item, bytes32 _value) internal {
        if (includes(self, item, _value)) {
            return;
        }
        uint newCount = count(self, item) + 1;
        set(self, item.values, bytes32(newCount), _value);
        set(self, item.indexes, _value, bytes32(newCount));
        set(self, item.count, newCount);
    }

    function add(Config storage self, AddressesSet storage item, address _value) internal {
        add(self, item.innerSet, addressToBytes32(_value));
    }

    function add(Config storage self, StringAddressSetMapping storage item, string memory _key, address _value) internal {
        if (includes(self, item, _key, _value)) {
            return;
        }
        uint newCount = count(self, item, _key) + 1;
        set(self, item.innerSet.values, keccak256(abi.encodePacked(_key, newCount)), addressToBytes32(_value));
        set(self, item.innerSet.indexes, keccak256(abi.encodePacked(_key)), addressToBytes32(_value), bytes32(newCount));
        set(self, item.innerSet.count, keccak256(abi.encodePacked(_key)), newCount);
    }

    function remove(Config storage self, Set storage item, bytes32 _value) internal {
        if (!includes(self, item, _value)) {
            return;
        }
        uint lastIndex = count(self, item);
        bytes32 lastValue = get(self, item.values, bytes32(lastIndex));
        uint index = uint(get(self, item.indexes, _value));
        if (index < lastIndex) {
            set(self, item.indexes, lastValue, bytes32(index));
            set(self, item.values, bytes32(index), lastValue);
        }
        set(self, item.indexes, _value, bytes32(0));
        set(self, item.values, bytes32(lastIndex), bytes32(0));
        set(self, item.count, lastIndex - 1);
    }

    function remove(Config storage self, AddressesSet storage item, address _value) internal {
        remove(self, item.innerSet, addressToBytes32(_value));
    }


    /// GET PRIMITIVES ///

    function get(Config storage self, UInt storage item) internal view returns(uint) {
        return self.store.getUInt(self.crate, item.id);
    }

    function get(Config storage self, UInt storage item, bytes32 _key) internal view returns(uint) {
        return self.store.getUInt(self.crate, keccak256(abi.encodePacked(item.id, _key)));
    }

    function get(Config storage self, UInt8 storage item) internal view returns(uint8) {
        return self.store.getUInt8(self.crate, item.id);
    }

    function get(Config storage self, Int storage item) internal view returns(int) {
        return self.store.getInt(self.crate, item.id);
    }

    function get(Config storage self, Address storage item) internal view returns(address) {
        return self.store.getAddress(self.crate, item.id);
    }

    function get(Config storage self, Bool storage item) internal view returns(bool) {
        return self.store.getBool(self.crate, item.id);
    }

    function get(Config storage self, Bytes32 storage item) internal view returns(bytes32) {
        return self.store.getBytes32(self.crate, item.id);
    }


    /// GET LOW-LEVEL MAPPINGS ///

    function get(Config storage self, Mapping storage item, bytes32 _key) internal view returns(bytes32) {
        return self.store.getBytes32(self.crate, keccak256(abi.encodePacked(item.id, _key)));
    }

    function get(Config storage self, Mapping storage item, bytes32 _key, bytes32 _key2) internal view returns(bytes32) {
        return get(self, item, keccak256(abi.encodePacked(_key, _key2)));
    }

    function get(Config storage self, Mapping storage item, bytes32 _key, bytes32 _key2, bytes32 _key3) internal view returns(bytes32) {
        return get(self, item, keccak256(abi.encodePacked(_key, _key2, _key3)));
    }


    /// GET HIGH-LEVEL MAPPINGS ///

    function get(Config storage self, AddressAddressMapping storage item, address _key) internal view returns(address) {
        // TODO : TESTING
        return bytes32ToAddress(get(self, item.innerMapping, addressToBytes32(_key)));
    }

    function get(Config storage self, AddressBoolMapping storage item, address _key) internal view returns(bool) {
        return toBool(get(self, item.innerMapping, addressToBytes32(_key)));
    }

    function get(Config storage self, UintAddressBoolMapping storage item, uint _key, address _key2) internal view returns(bool) {
        return toBool(get(self, item.innerMapping, bytes32(_key), addressToBytes32(_key2)));
    }

    function get(Config storage self, AddressBytes32Mapping storage item, address _key) internal view returns(bytes32) {
        return get(self, item.innerMapping, addressToBytes32(_key));
    }

    function get(Config storage self, AddressUIntMapping storage item, address _key) internal view returns(uint) {
        return uint(get(self, item.innerMapping, addressToBytes32(_key)));
    }

    function get(Config storage self, AddressUIntUInt8Mapping storage item, address _key, uint _key2) internal view returns(uint) {
        return uint8(uint256(get(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2))));
    }

    function get(Config storage self, UIntUIntBoolMapping storage item, uint _key, uint _key2) internal view returns(bool) {
        return toBool(get(self, item.innerMapping, bytes32(_key), bytes32(_key2)));
    }

    function get(Config storage self, AddressBytes4BoolMapping storage item, address _key, bytes4 _key2) internal view returns(bool) {
        return toBool(get(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2)));
    }

    function get(Config storage self, AddressBytes4Bytes32Mapping storage item, address _key, bytes4 _key2) internal view returns(bytes32) {
        return get(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2));
    }

    function get(Config storage self, AddressUIntUIntMapping storage item, address _key, uint _key2) internal view returns(uint) {
        return uint(get(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2)));
    }

    function get(Config storage self, AddressUIntUIntUIntMapping storage item, address _key, uint _key2, uint _key3) internal view returns(uint) {
        return uint(get(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), bytes32(_key3)));
    }

    function get(Config storage self, AddressAddressUIntMapping storage item, address _key, address _key2) internal view returns(uint) {
        return uint(get(self, item.innerMapping, addressToBytes32(_key), addressToBytes32(_key2)));
    }

    function get(Config storage self, AddressAddressUInt8Mapping storage item, address _key, address _key2) internal view returns(uint8) {
        return uint8(uint256(get(self, item.innerMapping, addressToBytes32(_key), addressToBytes32(_key2))));
    }

    function get(Config storage self, AddressBytes32Bytes32Mapping storage item, address _key, bytes32 _key2) internal view returns(bytes32) {
        return get(self, item.innerMapping, addressToBytes32(_key), _key2);
    }

    function get(Config storage self, UIntBytes32Mapping storage item, uint _key) internal view returns(bytes32) {
        return get(self, item.innerMapping, bytes32(_key));
    }

    function get(Config storage self, UIntAddressMapping storage item, uint _key) internal view returns(address) {
        return bytes32ToAddress(get(self, item.innerMapping, bytes32(_key)));
    }

    function get(Config storage self, UIntBoolMapping storage item, uint _key) internal view returns(bool) {
        return toBool(get(self, item.innerMapping, bytes32(_key)));
    }

    function get(Config storage self, UIntAddressAddressMapping storage item, uint _key, address _key2) internal view returns(address) {
        return bytes32ToAddress(get(self, item.innerMapping, bytes32(_key), addressToBytes32(_key2)));
    }

    function get(Config storage self, UIntAddressUIntMapping storage item, uint _key, address _key2) internal view returns(uint) {
        return uint(get(self, item.innerMapping, bytes32(_key), addressToBytes32(_key2)));
    }

    function get(Config storage self, UIntUIntMapping storage item, uint _key) internal view returns(uint) {
        return uint(get(self, item.innerMapping, bytes32(_key)));
    }

    function get(Config storage self, UIntEnumMapping storage item, uint _key) internal view returns(uint8) {
        return uint8(uint256(get(self, item.innerMapping, bytes32(_key))));
    }

    function get(Config storage self, AddressUIntAddressUInt8Mapping storage item, address _key, uint _key2, address _key3) internal view returns(uint8) {
        return uint8(uint256(get(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3)))));
    }

    function get(Config storage self, AddressUIntUIntAddressUInt8Mapping storage item, address _key, uint _key2, uint _key3, address _key4) internal view returns(uint8) {
        return uint8(uint256(get(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3, _key4)))));
    }

    function get(Config storage self, AddressUIntUIntUIntAddressUInt8Mapping storage item, address _key, uint _key2, uint _key3, uint _key4, address _key5) internal view returns(uint8) {
        return uint8(uint256(get(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3, _key4, _key5)))));
    }

    function get(Config storage self, UIntUIntBytes32Mapping storage item, uint _key, uint _key2) internal view returns(bytes32) {
        return get(self, item.innerMapping, bytes32(_key), bytes32(_key2));
    }

    function get(Config storage self, UIntUIntUIntBytes32Mapping storage item, uint _key, uint _key2, uint _key3) internal view returns(bytes32) {
        return get(self, item.innerMapping, bytes32(_key), bytes32(_key2), bytes32(_key3));
    }

    function get(Config storage self, Bytes32UIntMapping storage item, bytes32 _key) internal view returns(uint) {
        return uint(get(self, item.innerMapping, _key));
    }

    function get(Config storage self, Bytes32AddressMapping storage item, bytes32 _key) internal view returns(address) {
        return bytes32ToAddress(get(self, item.innerMapping, _key));
    }


    /// OPERATIONS ON SETS ///

    function includes(Config storage self, Set storage item, bytes32 _value) internal view returns(bool) {
        return get(self, item.indexes, _value) != 0;
    }

    function includes(Config storage self, StringAddressSetMapping storage item, string memory _key, address _value) internal view returns(bool) {
        return get(self, item.innerSet.indexes, keccak256(abi.encodePacked(_key)), addressToBytes32(_value)) != 0;
    }

    function includes(Config storage self, AddressesSet storage item, address _value) internal view returns(bool) {
        return includes(self, item.innerSet, addressToBytes32(_value));
    }

    function count(Config storage self, Set storage item) internal view returns(uint) {
        return get(self, item.count);
    }

    function count(Config storage self, AddressesSet storage item) internal view returns(uint) {
        return count(self, item.innerSet);
    }

    function count(Config storage self, StringAddressSetMapping storage item, string memory _key) internal view returns(uint) {
        return get(self, item.innerSet.count, keccak256(abi.encodePacked(_key)));
    }

    function get(Config storage self, Set storage item) internal view returns(bytes32[] memory) {
        uint valuesCount = count(self, item);
        bytes32[] memory result = new bytes32[](valuesCount);
        for (uint i = 0; i < valuesCount; i++) {
            result[i] = get(self, item, i);
        }
        return result;
    }

    function get(Config storage self, StringAddressSetMapping storage item, string memory _key) internal view returns(address[] memory) {
        uint valuesCount = count(self, item, _key);
        bytes32[] memory result = new bytes32[](valuesCount);
        for (uint i = 0; i < valuesCount; i++) {
            result[i] = get(self, item, _key, i);
        }
        return toAddresses(result);
    }

    function get(Config storage self, AddressesSet storage item) internal view returns(address[] memory) {
        return toAddresses(get(self, item.innerSet));
    }

    function get(Config storage self, Set storage item, uint _index) internal view returns(bytes32) {
        return get(self, item.values, bytes32(_index + 1));
    }

    function get(Config storage self, StringAddressSetMapping storage item, string memory _key, uint _index) internal view returns(bytes32) {
        return get(self, item.innerSet.values, keccak256(abi.encodePacked(_key, bytes32(_index + 1))));
    }

    function get(Config storage self, AddressesSet storage item, uint _index) internal view returns(address) {
        return bytes32ToAddress(get(self, item.innerSet, _index));
    }


    /// HELPERS ///

    function toBool(bytes32 self) pure public returns(bool) {
        return self != bytes32(0);
    }

    function toBytes32(bool self) pure public returns(bytes32) {
        return bytes32(self ? uint256(1) : 0);
    }

    function toAddresses(bytes32[] memory self) pure public returns(address[] memory) {
        address[] memory result = new address[](self.length);
        for (uint i = 0; i < self.length; i++) {
            result[i] = bytes32ToAddress(self[i]);
        }
        return result;
    }
    
    // These helpers introduced after moving to solidity v.0.5 since
    // types with different size now cannot be casted implicitly
    function bytes32ToAddress(bytes32 b) pure private returns(address) {
        return address(uint160(uint256(b)));
    }
    
    function addressToBytes32(address addr) pure private returns(bytes32) {
        return bytes32(uint256(addr));
    }
}

pragma solidity ^0.5.8;

import "./Ownable.sol";

contract FeeCalcInterface {
    function getFee() public view returns(uint256);
    function getCompanyFee() public view returns(uint256);
    function getNetworkGrowthFee() public view returns(uint256);
}

contract ERC20Interface {
    function transfer(address, uint256) public returns (bool);
}

contract DocumentRegistryInterface {
    function register(address) public;
    function feeCalc() public view returns(address);

    function companyWallet() public view returns(address);
    function networkGrowthPoolWallet() public view returns(address);
    function token() public view returns(address);
}

contract Agent is Ownable {

    DocumentRegistryInterface public documentRegistry;
    string public name;

    address public user;

    event Error(string msg);

    modifier onlyRegisteredUser() {
        uint256 code = 0;
        address _sender = msg.sender;
        if (_sender == user) {
            _;
        }
        else {
            emit Error("User does not registered");
        }
    }

    constructor(address _documentRegistry, address _owner, address _user) public {
        documentRegistry = DocumentRegistryInterface(_documentRegistry);
        owner = _owner;
        user = _user;
    }

    function setDocumentRegistry(address _documentRegistry) public onlyOwner {
        documentRegistry = DocumentRegistryInterface(_documentRegistry);
    }

    function setName(string memory _name) public onlyOwner {
        name = _name;
    }

    function setUser(address _user) public onlyOwner {
        user = _user;
    }

    function register(address _document) public onlyRegisteredUser {
        FeeCalcInterface feeCalc = FeeCalcInterface(documentRegistry.feeCalc());

        documentRegistry.register(_document);

        // Transfer fee to company wallet
        address companyWallet = documentRegistry.companyWallet();
        assert(companyWallet != address(0));
        uint256 companyFee = feeCalc.getCompanyFee();
        assert(ERC20Interface(documentRegistry.token()).transfer(companyWallet, companyFee));

        // Transfer fee to network wallet
        address networkGrowthPoolWallet = documentRegistry.networkGrowthPoolWallet();
        assert(networkGrowthPoolWallet != address(0));
        uint256 networkGrowthFee = feeCalc.getNetworkGrowthFee();
        assert(ERC20Interface(documentRegistry.token()).transfer(networkGrowthPoolWallet, networkGrowthFee));
    }

}


pragma solidity 0.5.8;

import "./Owned.sol";

contract BaseDocument is Owned {

    bytes32 public hash;
    string[] public tags;

    bool public finalized;

    modifier isNotFinalized() {
        require(!finalized, "Contract is finalized");
        _;
    }

    constructor(bytes32 _hash) public {
        hash = _hash;
    }

    function proxy_init(address _owner, bytes32 _hash) public {
        require(contractOwner == address(0));
        contractOwner = _owner;
        hash = _hash;
    }

    function setHash(bytes32 _hash) public isNotFinalized onlyContractOwner {
        hash = _hash;
    }

    function addTag(string memory _key) public isNotFinalized onlyContractOwner {
        require(tagsLength() < 32, "Tags is too many!");
        tags.push(_key);
    }

    function setFinalized() public isNotFinalized onlyContractOwner {
        finalized = true;
    }

    function tagsLength() public view returns(uint256) {
        return tags.length;
    }

    function documentType() public pure returns(bytes32) {
        return keccak256("basic");
    }

}


pragma solidity 0.5.8;

import "./Storage.sol";
import "./StorageAdapter.sol";
import "./RolesLibraryAdapter.sol";
import "./BaseDocument.sol";

contract DocumentRegistry is StorageAdapter, RolesLibraryAdapter {

    address public companyWallet;
    address public networkGrowthPoolWallet;
    address public feeCalc;
    address public token;

    StorageInterface.Bytes32AddressMapping documents;
    StorageInterface.StringAddressSetMapping tags;
    StorageInterface.AddressBytes32Bytes32Mapping documentsv2;

    event DocumentRegistered(address _document, bytes32 _hash, bytes32 _type);
    event DocumentRegisteredv2(bytes32 _hash, bytes32 _metahash);
    event Error(string _message);

    modifier isDocumentFinalized(BaseDocument _document) {
        if(!_document.finalized()) {
            emit Error("Document is not finalized");
            return;
        }
        _;
    }

    constructor(
        Storage _store,
        bytes32 _crate,
        address _companyWallet,
        address _networkGrowthPoolWallet,
        address _feeCalc,
        address _token,
        address _rolesLibrary
    ) public StorageAdapter(_store, _crate) RolesLibraryAdapter(_rolesLibrary) {
        companyWallet = _companyWallet;
        networkGrowthPoolWallet = _networkGrowthPoolWallet;
        feeCalc = _feeCalc;
        token = _token;
        documents.init("RegisteredDocuments");
        tags.init("ContainsTagDocuments");
    }

    function proxy_init(
        Storage _store,
        bytes32 _crate,
        address _companyWallet,
        address _networkGrowthPoolWallet,
        address _feeCalc,
        address _token,
        address _rolesLibrary
    ) public {
        require(address(rolesLibrary) == address(0));
        store.init(_store, _crate);
        rolesLibrary = RolesLibraryInterface(_rolesLibrary);
        companyWallet = _companyWallet;
        networkGrowthPoolWallet = _networkGrowthPoolWallet;
        feeCalc = _feeCalc;
        token = _token;
        documents.init("RegisteredDocuments");
        tags.init("ContainsTagDocuments");
        documentsv2.init("RegisteredDocumentsv2");
    }

    function setWallets(address _companyWallet, address _networkGrowthPoolWallet) public auth {
        companyWallet = _companyWallet;
        networkGrowthPoolWallet = _networkGrowthPoolWallet;
    }

    function setFeeCalc(address _feeCalc) public auth {
        feeCalc = _feeCalc;
    }

    function register(BaseDocument _document) public auth isDocumentFinalized(_document) {
        require(!exists(_document.hash()), "Document is already exists!");
        store.set(documents, _document.hash(), address(_document));
        for(uint256 i = 0; i < _document.tagsLength(); ++i) {
            store.add(tags, _document.tags(i), address(_document));
        }
        emit DocumentRegistered(address(_document), _document.hash(), _document.documentType());
    }

    function getDocument(bytes32 _hash) public view returns(address) {
        return store.get(documents, _hash);
    }

    function getDocumentsByTag(string memory _tag) public view returns(address[] memory) {
        return store.get(tags, _tag);
    }

    function exists(bytes32 _hash) public view returns(bool) {
        return store.get(documents, _hash) != address(0);
    }
    
    // Access methods for version 2 (only hash)
    // Here we don't deploy contract for document but just store physical(electronic) document hash
    // and metadata hash which is just JSON with all the data related to registration.
    
    function registerv2(bytes32 _hash, bytes32 _metahash) public auth {
        require(!existsv2(_hash), "Document already exists!");
        store.set(documentsv2, address(0), _hash, _metahash);
        emit DocumentRegisteredv2(_hash, _metahash);
    }
    
     function existsv2(bytes32 _hash) public view returns(bool) {
        return store.get(documentsv2, address(0), _hash) != bytes32(0);
    }
    
    function getMetahash(bytes32 _hash) public view returns(bytes32) {
        return store.get(documentsv2, address(0), _hash);
    }

}

pragma solidity ^0.5.8;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {

    address public owner;

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
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }

}



pragma solidity ^0.5.8;


/**
 * @title Owned contract with safe ownership pass.
 *
 * Note: all the non constant functions return false instead of throwing in case if state change
 * didn't happen yet.
 */
contract Owned {
    address public contractOwner;
    address public pendingContractOwner;

    constructor () public {
        contractOwner = msg.sender;
    }

    modifier onlyContractOwner() {
        if (contractOwner == msg.sender || contractOwner == address(0)) {
            _;
        }
    }

    /**
     * Prepares ownership pass.
     *
     * Can only be called by current owner.
     *
     * @param _to address of the next owner.
     *
     * @return success.
     */
    function changeContractOwnership(address _to) public onlyContractOwner returns(bool) {
        pendingContractOwner = _to;
        return true;
    }

    /**
     * Finalize ownership pass.
     *
     * Can only be called by pending owner.
     *
     * @return success.
     */
    function claimContractOwnership() public returns(bool) {
        if (pendingContractOwner != msg.sender) {
            return false;
        }
        contractOwner = pendingContractOwner;
        delete pendingContractOwner;
        return true;
    }

    /**
     * Force ownership pass.
     *
     * Can only be called by current owner.
     *
     * @param _to address of the next owner.
     *
     * @return success.
     */
    function forceChangeContractOwnership(address _to) public onlyContractOwner returns(bool) {
        contractOwner = _to;
        return true;
    }

}


pragma solidity 0.5.8;


contract RolesLibraryInterface {
    function canCall(address, address, bytes4) public view returns(bool);
}

contract RolesLibraryAdapter {
    RolesLibraryInterface rolesLibrary;

    event Unauthorized(address user);

    modifier auth() {
        if (!_isAuthorized(msg.sender, msg.sig)) {
            emit Unauthorized(msg.sender);
            return;
        }
        _;
    }

    constructor(address _rolesLibrary) public {
        rolesLibrary = RolesLibraryInterface(_rolesLibrary);
    }

    function setRolesLibrary(RolesLibraryInterface _rolesLibrary) auth() public returns(bool) {
        rolesLibrary = _rolesLibrary;
        return true;
    }

    function _isAuthorized(address _src, bytes4 _sig) internal view returns(bool) {
        if (_src == address(this)) {
            return true;
        }
        if (address(rolesLibrary) == address(0)) {
            return false;
        }
        return rolesLibrary.canCall(_src, address(this), _sig);
    }
}


pragma solidity 0.5.8;

import "./Owned.sol";


contract Manager {
    function isAllowed(address _actor, bytes32 _role) view public returns(bool);
}

contract Storage is Owned {

    struct Crate {
        mapping(bytes32 => uint) uints;
        mapping(bytes32 => address) addresses;
        mapping(bytes32 => bool) bools;
        mapping(bytes32 => int) ints;
        mapping(bytes32 => uint8) uint8s;
        mapping(bytes32 => bytes32) bytes32s;
    }

    mapping(bytes32 => Crate) crates;
    Manager public manager;

    modifier onlyAllowed(bytes32 _role) {
        if (!manager.isAllowed(msg.sender, _role)) {
            revert();
        }
        _;
    }

    function setManager(Manager _manager) onlyContractOwner public returns(bool) {
        manager = _manager;
        return true;
    }

    function setUInt(bytes32 _crate, bytes32 _key, uint _value) onlyAllowed(_crate) public {
        crates[_crate].uints[_key] = _value;
    }

    function getUInt(bytes32 _crate, bytes32 _key) view public returns(uint) {
        return crates[_crate].uints[_key];
    }

    function setUInt8(bytes32 _crate, bytes32 _key, uint8 _value) onlyAllowed(_crate) public {
        crates[_crate].uint8s[_key] = _value;
    }

    function getUInt8(bytes32 _crate, bytes32 _key) view public returns(uint8) {
        return crates[_crate].uint8s[_key];
    }

    function setInt(bytes32 _crate, bytes32 _key, int _value) onlyAllowed(_crate) public {
        crates[_crate].ints[_key] = _value;
    }

    function getInt(bytes32 _crate, bytes32 _key) view public returns(int) {
        return crates[_crate].ints[_key];
    }

    function setAddress(bytes32 _crate, bytes32 _key, address _value) onlyAllowed(_crate) public {
        crates[_crate].addresses[_key] = _value;
    }

    function getAddress(bytes32 _crate, bytes32 _key) view public returns(address) {
        return crates[_crate].addresses[_key];
    }

    function setBool(bytes32 _crate, bytes32 _key, bool _value) onlyAllowed(_crate) public {
        crates[_crate].bools[_key] = _value;
    }

    function getBool(bytes32 _crate, bytes32 _key) view public returns(bool) {
        return crates[_crate].bools[_key];
    }

    function setBytes32(bytes32 _crate, bytes32 _key, bytes32 _value) onlyAllowed(_crate) public {
        crates[_crate].bytes32s[_key] = _value;
    }

    function getBytes32(bytes32 _crate, bytes32 _key) view public returns(bytes32) {
        return crates[_crate].bytes32s[_key];
    }


    /// RESTRICTIONS & DISASTER RECOVERY ///

    function kill() public onlyContractOwner {
        selfdestruct(msg.sender);
    }

    // FIXME: Add maintenance mode


}


pragma solidity 0.5.8;

import "./StorageInterface.sol";


contract StorageAdapter {
    using StorageInterface for *;

    StorageInterface.Config store;

    constructor(Storage _store, bytes32 _crate) public {
        assert(_crate != bytes32(0));
        store.init(_store, _crate);
    }
}
pragma solidity 0.5.8;

import "./Storage.sol";

/*
contract StorageMethods {
    function setUInt(bytes32, bytes32, uint);
    function setUInt8(bytes32, bytes32, uint8);
    function setInt(bytes32, bytes32, int);
    function setAddress(bytes32, bytes32, address);
    function setBool(bytes32, bytes32, bool);
    function setBytes32(bytes32, bytes32, bytes32);

    function getUInt(bytes32, bytes32) returns(uint) ;
    function getUInt8(bytes32, bytes32) returns(uint8) ;
    function getInt(bytes32, bytes32) returns(int) ;
    function getAddress(bytes32, bytes32) returns(address) ;
    function getBool(bytes32, bytes32) returns(bool) ;
    function getBytes32(bytes32, bytes32) returns(bytes32) ;
}
*/

library StorageInterface {

    // DEFINE STORAGE LINK //

    struct Config {
        Storage store;
        bytes32 crate;
    }


    // DEFINE PRIMITIVES //

    struct UInt {
        bytes32 id;
    }

    struct UInt8 {
        bytes32 id;
    }

    struct Int {
        bytes32 id;
    }

    struct Address {
        bytes32 id;
    }

    struct Bool {
        bytes32 id;
    }

    struct Bytes32 {
        bytes32 id;
    }

    struct Mapping {
        bytes32 id;
    }


    // DEFINE MAPPINGS //

    struct AddressAddressMapping {
        Mapping innerMapping;
    }

    struct AddressBoolMapping {
        Mapping innerMapping;
    }

    struct UintAddressBoolMapping {
        Mapping innerMapping;
    }

    struct AddressBytes32Mapping {
        Mapping innerMapping;
    }

    struct AddressUInt8Mapping {
        bytes32 id;
    }

    struct AddressUIntMapping {
        Mapping innerMapping;
    }

    struct AddressUIntUInt8Mapping {
        Mapping innerMapping;
    }

    struct UIntUIntBoolMapping {
        Mapping innerMapping;
    }

    struct AddressBytes4BoolMapping {
        Mapping innerMapping;
    }

    struct AddressBytes4Bytes32Mapping {
        Mapping innerMapping;
    }

    struct AddressUIntUIntMapping {
        Mapping innerMapping;
    }

    struct AddressUIntUIntUIntMapping {
        Mapping innerMapping;
    }

    struct AddressAddressUIntMapping {
        Mapping innerMapping;
    }

    struct AddressAddressUInt8Mapping {
        Mapping innerMapping;
    }

    struct AddressBytes32Bytes32Mapping {
        Mapping innerMapping;
    }

    struct UIntAddressMapping {
        Mapping innerMapping;
    }

    struct UIntAddressAddressMapping {
        Mapping innerMapping;
    }

    struct UIntAddressUIntMapping {
        Mapping innerMapping;
    }

    struct UIntBoolMapping {
        Mapping innerMapping;
    }

    struct UIntUIntMapping {
        Mapping innerMapping;
    }

    struct UIntEnumMapping {
        Mapping innerMapping;
    }

    struct AddressUIntAddressUInt8Mapping {
        Mapping innerMapping;
    }

    struct AddressUIntUIntAddressUInt8Mapping {
        Mapping innerMapping;
    }

    struct AddressUIntUIntUIntAddressUInt8Mapping {
        Mapping innerMapping;
    }

    struct UIntBytes32Mapping {
        Mapping innerMapping;
    }

    struct UIntUIntBytes32Mapping {
        Mapping innerMapping;
    }

    struct UIntUIntUIntBytes32Mapping {
        Mapping innerMapping;
    }

    struct Bytes32UIntMapping {
        Mapping innerMapping;
    }

    struct Bytes32AddressMapping {
        Mapping innerMapping;
    }

    struct Set {
        UInt count;
        Mapping indexes;
        Mapping values;
    }

    struct AddressesSet {
        Set innerSet;
    }

    struct StringAddressSetMapping {
        Set innerSet;
    }

    // Can't use modifier due to a Solidity bug.
    function sanityCheck(bytes32 _currentId, bytes32 _newId) internal pure {
        if (_currentId != 0 || _newId == 0) {
            revert();
        }
    }

    /// INITIATION ///

    function init(Config storage self, Storage _store, bytes32 _crate) internal {
        self.store = _store;
        self.crate = _crate;
    }


    /// INIT PRIMITIVES ///

    function init(UInt storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(UInt8 storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(Int storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(Address storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(Bool storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(Bytes32 storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    /// INIT LOW-LEVEL MAPPING ///

    function init(Mapping storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }


    /// INIT HIGH-LEVEL MAPPINGS ///

    function init(AddressAddressMapping storage self, bytes32 _id) internal {
        // TODO : TESTING
        init(self.innerMapping, _id);
    }

    function init(AddressBoolMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UintAddressBoolMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressBytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUInt8Mapping storage self, bytes32 _id) internal {
        sanityCheck(self.id, _id);
        self.id = _id;
    }

    function init(AddressUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntUInt8Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntUIntBoolMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressBytes4BoolMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressBytes4Bytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntUIntUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressAddressUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressAddressUInt8Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressBytes32Bytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntBytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntAddressMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntAddressAddressMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntAddressUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntBoolMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntUIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntEnumMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntAddressUInt8Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntUIntAddressUInt8Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(AddressUIntUIntUIntAddressUInt8Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntUIntBytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(UIntUIntUIntBytes32Mapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(Bytes32UIntMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    function init(Bytes32AddressMapping storage self, bytes32 _id) internal {
        init(self.innerMapping, _id);
    }

    /// INIT SETS ///

    function init(Set storage self, bytes32 _id) internal {
        init(self.count, keccak256(abi.encodePacked(_id, 'count')));
        init(self.indexes, keccak256(abi.encodePacked(_id, 'indexes')));
        init(self.values, keccak256(abi.encodePacked(_id, 'values')));
    }

    function init(AddressesSet storage self, bytes32 _id) internal {
        init(self.innerSet, _id);
    }

    function init(StringAddressSetMapping storage self, bytes32 _id) internal {
        init(self.innerSet, _id);
    }

    /// SET PRIMITIVES ///

    function set(Config storage self, UInt storage item, uint _value) internal {
        self.store.setUInt(self.crate, item.id, _value);
    }

    function set(Config storage self, UInt storage item, bytes32 _key, uint _value) internal {
        self.store.setUInt(self.crate, keccak256(abi.encodePacked(item.id, _key)), _value);
    }

    function set(Config storage self, UInt8 storage item, uint8 _value) internal {
        self.store.setUInt8(self.crate, item.id, _value);
    }

    function set(Config storage self, Int storage item, int _value) internal {
        self.store.setInt(self.crate, item.id, _value);
    }

    function set(Config storage self, Address storage item, address _value) internal {
        self.store.setAddress(self.crate, item.id, _value);
    }

    function set(Config storage self, Bool storage item, bool _value) internal {
        self.store.setBool(self.crate, item.id, _value);
    }

    function set(Config storage self, Bytes32 storage item, bytes32 _value) internal {
        self.store.setBytes32(self.crate, item.id, _value);
    }


    /// SET LOW-LEVEL MAPPINGS ///

    function set(Config storage self, Mapping storage item, bytes32 _key, bytes32 _value) internal {
        self.store.setBytes32(self.crate, keccak256(abi.encodePacked(item.id, _key)), _value);
    }

    function set(Config storage self, Mapping storage item, bytes32 _key, bytes32 _key2, bytes32 _value) internal {
        set(self, item, keccak256(abi.encodePacked(_key, _key2)), _value);
    }

    function set(Config storage self, Mapping storage item, bytes32 _key, bytes32 _key2, bytes32 _key3, bytes32 _value) internal {
        set(self, item, keccak256(abi.encodePacked(_key, _key2, _key3)), _value);
    }



    /// SET HIGH-LEVEL MAPPINGS ///

    function set(Config storage self, AddressAddressMapping storage item, address _key, address _value) internal {
        // TODO : TESTING
        set(self, item.innerMapping, addressToBytes32(_key), addressToBytes32(_value));
    }

    function set(Config storage self, AddressBoolMapping storage item, address _key, bool _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), toBytes32(_value));
    }

    function set(Config storage self, UintAddressBoolMapping storage item, uint _key, address _key2, bool _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(uint256(_key2)), toBytes32(_value));
    }

    function set(Config storage self, AddressBytes32Mapping storage item, address _key, bytes32 _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), _value);
    }

    function set(Config storage self, AddressUIntMapping storage item, address _key, uint _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_value));
    }

    function set(Config storage self, AddressUIntUInt8Mapping storage item, address _key, uint _key2, uint8 _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), bytes32(uint256(_value)));
    }

    function set(Config storage self, UIntUIntBoolMapping storage item, uint _key, uint _key2, bool _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(_key2), toBytes32(_value));
    }

    function set(Config storage self, AddressBytes4BoolMapping storage item, address _key, bytes4 _key2, bool _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), toBytes32(_value));
    }

    function set(Config storage self, AddressBytes4Bytes32Mapping storage item, address _key, bytes4 _key2, bytes32 _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), _value);
    }

    function set(Config storage self, AddressUIntUIntMapping storage item, address _key, uint _key2, uint _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), bytes32(_value));
    }

    function set(Config storage self, AddressUIntUIntUIntMapping storage item, address _key, uint _key2,  uint _key3, uint _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), bytes32(_key3), bytes32(_value));
    }

    function set(Config storage self, AddressAddressUIntMapping storage item, address _key, address _key2, uint _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), addressToBytes32(_key2), bytes32(_value));
    }

    function set(Config storage self, AddressAddressUInt8Mapping storage item, address _key, address _key2, uint8 _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), addressToBytes32(_key2), bytes32(uint256(_value)));
    }

    function set(Config storage self, AddressBytes32Bytes32Mapping storage item, address _key, bytes32 _key2, bytes32 _value) internal {
        set(self, item.innerMapping, addressToBytes32(_key), _key2, _value);
    }

    function set(Config storage self, UIntBytes32Mapping storage item, uint _key, bytes32 _value) internal {
        set(self, item.innerMapping, bytes32(_key), _value);
    }

    function set(Config storage self, UIntAddressMapping storage item, uint _key, address _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(uint256(_value)));
    }

    function set(Config storage self, UIntBoolMapping storage item, uint _key, bool _value) internal {
        set(self, item.innerMapping, bytes32(_key), toBytes32(_value));
    }

    function set(Config storage self, UIntAddressAddressMapping storage item, uint _key, address _key2, address _value) internal {
        set(self, item.innerMapping, bytes32(_key), addressToBytes32(_key2), addressToBytes32(_value));
    }

    function set(Config storage self, UIntAddressUIntMapping storage item, uint _key, address _key2, uint _value) internal {
        set(self, item.innerMapping, bytes32(_key), addressToBytes32(_key2), bytes32(_value));
    }

    function set(Config storage self, UIntUIntMapping storage item, uint _key, uint _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(_value));
    }

    function set(Config storage self, UIntEnumMapping storage item, uint _key, uint8 _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(uint256(_value)));
    }

    function set(Config storage self, AddressUIntAddressUInt8Mapping storage item, address _key, uint _key2, address _key3, uint8 _value) internal {
        set(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3)), bytes32(uint256(_value)));
    }

    function set(Config storage self, AddressUIntUIntAddressUInt8Mapping storage item, address _key, uint _key2, uint _key3, address _key4, uint8 _value) internal {
        set(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3, _key4)), bytes32(uint256(_value)));
    }

    function set(Config storage self, AddressUIntUIntUIntAddressUInt8Mapping storage item, address _key, uint _key2,  uint _key3, uint _key4, address _key5, uint8 _value) internal {
        set(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3, _key4, _key5)), bytes32(uint256(_value)));
    }

    function set(Config storage self, UIntUIntBytes32Mapping storage item, uint _key, uint _key2, bytes32 _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(_key2), _value);
    }

    function set(Config storage self, UIntUIntUIntBytes32Mapping storage item, uint _key, uint _key2,  uint _key3, bytes32 _value) internal {
        set(self, item.innerMapping, bytes32(_key), bytes32(_key2), bytes32(_key3), _value);
    }

    function set(Config storage self, Bytes32UIntMapping storage item, bytes32 _key, uint _value) internal {
        set(self, item.innerMapping, _key, bytes32(_value));
    }

    function set(Config storage self, Bytes32AddressMapping storage item, bytes32 _key, address _value) internal {
        set(self, item.innerMapping, _key, bytes32(uint256(_value)));
    }


    /// OPERATIONS ON SETS ///
    
    function add(Config storage self, Set storage item, bytes32 _value) internal {
        if (includes(self, item, _value)) {
            return;
        }
        uint newCount = count(self, item) + 1;
        set(self, item.values, bytes32(newCount), _value);
        set(self, item.indexes, _value, bytes32(newCount));
        set(self, item.count, newCount);
    }

    function add(Config storage self, AddressesSet storage item, address _value) internal {
        add(self, item.innerSet, addressToBytes32(_value));
    }

    function add(Config storage self, StringAddressSetMapping storage item, string memory _key, address _value) internal {
        if (includes(self, item, _key, _value)) {
            return;
        }
        uint newCount = count(self, item, _key) + 1;
        set(self, item.innerSet.values, keccak256(abi.encodePacked(_key, newCount)), addressToBytes32(_value));
        set(self, item.innerSet.indexes, keccak256(abi.encodePacked(_key)), addressToBytes32(_value), bytes32(newCount));
        set(self, item.innerSet.count, keccak256(abi.encodePacked(_key)), newCount);
    }

    function remove(Config storage self, Set storage item, bytes32 _value) internal {
        if (!includes(self, item, _value)) {
            return;
        }
        uint lastIndex = count(self, item);
        bytes32 lastValue = get(self, item.values, bytes32(lastIndex));
        uint index = uint(get(self, item.indexes, _value));
        if (index < lastIndex) {
            set(self, item.indexes, lastValue, bytes32(index));
            set(self, item.values, bytes32(index), lastValue);
        }
        set(self, item.indexes, _value, bytes32(0));
        set(self, item.values, bytes32(lastIndex), bytes32(0));
        set(self, item.count, lastIndex - 1);
    }

    function remove(Config storage self, AddressesSet storage item, address _value) internal {
        remove(self, item.innerSet, addressToBytes32(_value));
    }


    /// GET PRIMITIVES ///

    function get(Config storage self, UInt storage item) internal view returns(uint) {
        return self.store.getUInt(self.crate, item.id);
    }

    function get(Config storage self, UInt storage item, bytes32 _key) internal view returns(uint) {
        return self.store.getUInt(self.crate, keccak256(abi.encodePacked(item.id, _key)));
    }

    function get(Config storage self, UInt8 storage item) internal view returns(uint8) {
        return self.store.getUInt8(self.crate, item.id);
    }

    function get(Config storage self, Int storage item) internal view returns(int) {
        return self.store.getInt(self.crate, item.id);
    }

    function get(Config storage self, Address storage item) internal view returns(address) {
        return self.store.getAddress(self.crate, item.id);
    }

    function get(Config storage self, Bool storage item) internal view returns(bool) {
        return self.store.getBool(self.crate, item.id);
    }

    function get(Config storage self, Bytes32 storage item) internal view returns(bytes32) {
        return self.store.getBytes32(self.crate, item.id);
    }


    /// GET LOW-LEVEL MAPPINGS ///

    function get(Config storage self, Mapping storage item, bytes32 _key) internal view returns(bytes32) {
        return self.store.getBytes32(self.crate, keccak256(abi.encodePacked(item.id, _key)));
    }

    function get(Config storage self, Mapping storage item, bytes32 _key, bytes32 _key2) internal view returns(bytes32) {
        return get(self, item, keccak256(abi.encodePacked(_key, _key2)));
    }

    function get(Config storage self, Mapping storage item, bytes32 _key, bytes32 _key2, bytes32 _key3) internal view returns(bytes32) {
        return get(self, item, keccak256(abi.encodePacked(_key, _key2, _key3)));
    }


    /// GET HIGH-LEVEL MAPPINGS ///

    function get(Config storage self, AddressAddressMapping storage item, address _key) internal view returns(address) {
        // TODO : TESTING
        return bytes32ToAddress(get(self, item.innerMapping, addressToBytes32(_key)));
    }

    function get(Config storage self, AddressBoolMapping storage item, address _key) internal view returns(bool) {
        return toBool(get(self, item.innerMapping, addressToBytes32(_key)));
    }

    function get(Config storage self, UintAddressBoolMapping storage item, uint _key, address _key2) internal view returns(bool) {
        return toBool(get(self, item.innerMapping, bytes32(_key), addressToBytes32(_key2)));
    }

    function get(Config storage self, AddressBytes32Mapping storage item, address _key) internal view returns(bytes32) {
        return get(self, item.innerMapping, addressToBytes32(_key));
    }

    function get(Config storage self, AddressUIntMapping storage item, address _key) internal view returns(uint) {
        return uint(get(self, item.innerMapping, addressToBytes32(_key)));
    }

    function get(Config storage self, AddressUIntUInt8Mapping storage item, address _key, uint _key2) internal view returns(uint) {
        return uint8(uint256(get(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2))));
    }

    function get(Config storage self, UIntUIntBoolMapping storage item, uint _key, uint _key2) internal view returns(bool) {
        return toBool(get(self, item.innerMapping, bytes32(_key), bytes32(_key2)));
    }

    function get(Config storage self, AddressBytes4BoolMapping storage item, address _key, bytes4 _key2) internal view returns(bool) {
        return toBool(get(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2)));
    }

    function get(Config storage self, AddressBytes4Bytes32Mapping storage item, address _key, bytes4 _key2) internal view returns(bytes32) {
        return get(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2));
    }

    function get(Config storage self, AddressUIntUIntMapping storage item, address _key, uint _key2) internal view returns(uint) {
        return uint(get(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2)));
    }

    function get(Config storage self, AddressUIntUIntUIntMapping storage item, address _key, uint _key2, uint _key3) internal view returns(uint) {
        return uint(get(self, item.innerMapping, addressToBytes32(_key), bytes32(_key2), bytes32(_key3)));
    }

    function get(Config storage self, AddressAddressUIntMapping storage item, address _key, address _key2) internal view returns(uint) {
        return uint(get(self, item.innerMapping, addressToBytes32(_key), addressToBytes32(_key2)));
    }

    function get(Config storage self, AddressAddressUInt8Mapping storage item, address _key, address _key2) internal view returns(uint8) {
        return uint8(uint256(get(self, item.innerMapping, addressToBytes32(_key), addressToBytes32(_key2))));
    }

    function get(Config storage self, AddressBytes32Bytes32Mapping storage item, address _key, bytes32 _key2) internal view returns(bytes32) {
        return get(self, item.innerMapping, addressToBytes32(_key), _key2);
    }

    function get(Config storage self, UIntBytes32Mapping storage item, uint _key) internal view returns(bytes32) {
        return get(self, item.innerMapping, bytes32(_key));
    }

    function get(Config storage self, UIntAddressMapping storage item, uint _key) internal view returns(address) {
        return bytes32ToAddress(get(self, item.innerMapping, bytes32(_key)));
    }

    function get(Config storage self, UIntBoolMapping storage item, uint _key) internal view returns(bool) {
        return toBool(get(self, item.innerMapping, bytes32(_key)));
    }

    function get(Config storage self, UIntAddressAddressMapping storage item, uint _key, address _key2) internal view returns(address) {
        return bytes32ToAddress(get(self, item.innerMapping, bytes32(_key), addressToBytes32(_key2)));
    }

    function get(Config storage self, UIntAddressUIntMapping storage item, uint _key, address _key2) internal view returns(uint) {
        return uint(get(self, item.innerMapping, bytes32(_key), addressToBytes32(_key2)));
    }

    function get(Config storage self, UIntUIntMapping storage item, uint _key) internal view returns(uint) {
        return uint(get(self, item.innerMapping, bytes32(_key)));
    }

    function get(Config storage self, UIntEnumMapping storage item, uint _key) internal view returns(uint8) {
        return uint8(uint256(get(self, item.innerMapping, bytes32(_key))));
    }

    function get(Config storage self, AddressUIntAddressUInt8Mapping storage item, address _key, uint _key2, address _key3) internal view returns(uint8) {
        return uint8(uint256(get(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3)))));
    }

    function get(Config storage self, AddressUIntUIntAddressUInt8Mapping storage item, address _key, uint _key2, uint _key3, address _key4) internal view returns(uint8) {
        return uint8(uint256(get(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3, _key4)))));
    }

    function get(Config storage self, AddressUIntUIntUIntAddressUInt8Mapping storage item, address _key, uint _key2, uint _key3, uint _key4, address _key5) internal view returns(uint8) {
        return uint8(uint256(get(self, item.innerMapping, keccak256(abi.encodePacked(_key, _key2, _key3, _key4, _key5)))));
    }

    function get(Config storage self, UIntUIntBytes32Mapping storage item, uint _key, uint _key2) internal view returns(bytes32) {
        return get(self, item.innerMapping, bytes32(_key), bytes32(_key2));
    }

    function get(Config storage self, UIntUIntUIntBytes32Mapping storage item, uint _key, uint _key2, uint _key3) internal view returns(bytes32) {
        return get(self, item.innerMapping, bytes32(_key), bytes32(_key2), bytes32(_key3));
    }

    function get(Config storage self, Bytes32UIntMapping storage item, bytes32 _key) internal view returns(uint) {
        return uint(get(self, item.innerMapping, _key));
    }

    function get(Config storage self, Bytes32AddressMapping storage item, bytes32 _key) internal view returns(address) {
        return bytes32ToAddress(get(self, item.innerMapping, _key));
    }


    /// OPERATIONS ON SETS ///

    function includes(Config storage self, Set storage item, bytes32 _value) internal view returns(bool) {
        return get(self, item.indexes, _value) != 0;
    }

    function includes(Config storage self, StringAddressSetMapping storage item, string memory _key, address _value) internal view returns(bool) {
        return get(self, item.innerSet.indexes, keccak256(abi.encodePacked(_key)), addressToBytes32(_value)) != 0;
    }

    function includes(Config storage self, AddressesSet storage item, address _value) internal view returns(bool) {
        return includes(self, item.innerSet, addressToBytes32(_value));
    }

    function count(Config storage self, Set storage item) internal view returns(uint) {
        return get(self, item.count);
    }

    function count(Config storage self, AddressesSet storage item) internal view returns(uint) {
        return count(self, item.innerSet);
    }

    function count(Config storage self, StringAddressSetMapping storage item, string memory _key) internal view returns(uint) {
        return get(self, item.innerSet.count, keccak256(abi.encodePacked(_key)));
    }

    function get(Config storage self, Set storage item) internal view returns(bytes32[] memory) {
        uint valuesCount = count(self, item);
        bytes32[] memory result = new bytes32[](valuesCount);
        for (uint i = 0; i < valuesCount; i++) {
            result[i] = get(self, item, i);
        }
        return result;
    }

    function get(Config storage self, StringAddressSetMapping storage item, string memory _key) internal view returns(address[] memory) {
        uint valuesCount = count(self, item, _key);
        bytes32[] memory result = new bytes32[](valuesCount);
        for (uint i = 0; i < valuesCount; i++) {
            result[i] = get(self, item, _key, i);
        }
        return toAddresses(result);
    }

    function get(Config storage self, AddressesSet storage item) internal view returns(address[] memory) {
        return toAddresses(get(self, item.innerSet));
    }

    function get(Config storage self, Set storage item, uint _index) internal view returns(bytes32) {
        return get(self, item.values, bytes32(_index + 1));
    }

    function get(Config storage self, StringAddressSetMapping storage item, string memory _key, uint _index) internal view returns(bytes32) {
        return get(self, item.innerSet.values, keccak256(abi.encodePacked(_key, bytes32(_index + 1))));
    }

    function get(Config storage self, AddressesSet storage item, uint _index) internal view returns(address) {
        return bytes32ToAddress(get(self, item.innerSet, _index));
    }


    /// HELPERS ///

    function toBool(bytes32 self) pure public returns(bool) {
        return self != bytes32(0);
    }

    function toBytes32(bool self) pure public returns(bytes32) {
        return bytes32(self ? uint256(1) : 0);
    }

    function toAddresses(bytes32[] memory self) pure public returns(address[] memory) {
        address[] memory result = new address[](self.length);
        for (uint i = 0; i < self.length; i++) {
            result[i] = bytes32ToAddress(self[i]);
        }
        return result;
    }
    
    // These helpers introduced after moving to solidity v.0.5 since
    // types with different size now cannot be casted implicitly
    function bytes32ToAddress(bytes32 b) pure private returns(address) {
        return address(uint160(uint256(b)));
    }
    
    function addressToBytes32(address addr) pure private returns(bytes32) {
        return bytes32(uint256(addr));
    }
}

