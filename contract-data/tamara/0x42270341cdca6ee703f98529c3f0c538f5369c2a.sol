pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;

import 'RLP.sol';
import 'StorageStructure.sol';

/// @title CertiÐApp Smart Contract
/// @author Soham Zemse from The EraSwap Team
/// @notice This contract accepts certificates signed by multiple authorised signers
contract CertiDApp is StorageStructure {
  using RLP for bytes;
  using RLP for RLP.RLPItem;

  /// @notice Sets up the CertiDApp manager address when deployed
  constructor() public {
    _changeManager(msg.sender);
  }

  /// @notice Used by present manager to change the manager wallet address
  /// @param _newManagerAddress Address of next manager wallet
  function changeManager(address _newManagerAddress) public onlyManager {
    _changeManager(_newManagerAddress);
  }

  /// @notice Used by manager to for to update KYC / verification status of Certifying Authorities
  /// @param _authorityAddress Wallet address of certifying authority
  /// @param _data RLP encoded KYC details of certifying authority
  function updateCertifyingAuthority(
    address _authorityAddress,
    bytes memory _data,
    AuthorityStatus _status
  ) public onlyManager {
    if(_data.length > 0) {
      certifyingAuthorities[_authorityAddress].data = _data;
    }

    certifyingAuthorities[_authorityAddress].status = _status;

    emit AuthorityStatusUpdated(_authorityAddress, _status);
  }

  /// @notice Used by Certifying Authorities to change their wallet (in case of theft).
  ///   Migrating prevents any new certificate registrations signed by the old wallet.
  ///   Already registered certificates would be valid.
  /// @param _newAuthorityAddress Next wallet address of the same certifying authority
  function migrateCertifyingAuthority(
    address _newAuthorityAddress
  ) public onlyAuthorisedCertifier {
    require(
      certifyingAuthorities[_newAuthorityAddress].status == AuthorityStatus.NotAuthorised
      , 'cannot migrate to an already authorised address'
    );

    certifyingAuthorities[msg.sender].status = AuthorityStatus.Migrated;
    emit AuthorityStatusUpdated(msg.sender, AuthorityStatus.Migrated);

    certifyingAuthorities[_newAuthorityAddress] = CertifyingAuthority({
      data: certifyingAuthorities[msg.sender].data,
      status: AuthorityStatus.Authorised
    });
    emit AuthorityStatusUpdated(_newAuthorityAddress, AuthorityStatus.Authorised);

    emit AuthorityMigrated(msg.sender, _newAuthorityAddress);
  }

  /// @notice Used to submit a signed certificate to smart contract for adding it to storage.
  ///   Anyone can submit the certificate, the one submitting has to pay the nominal gas fee.
  /// @param _signedCertificate RLP encoded certificate according to CertiDApp Certificate standard.
  function registerCertificate(
    bytes memory _signedCertificate
  ) public returns (
    bytes32
  ) {
    (Certificate memory _certificateObj, bytes32 _certificateHash) = parseSignedCertificate(_signedCertificate, true);

    /// @notice Signers in this transaction
    bytes memory _newSigners = _certificateObj.signers;

    /// @notice If certificate already registered then signers can be updated.
    ///   Initializing _updatedSigners with existing signers on blockchain if any.
    ///   More signers would be appended to this in next 'for' loop.
    bytes memory _updatedSigners = certificates[_certificateHash].signers;

    /// @notice Check with every the new signer if it is not already included in storage.
    ///   This is helpful when a same certificate is submitted again with more signatures,
    ///   the contract will consider only new signers in that case.
    for(uint256 i = 0; i < _newSigners.length; i += 20) {
      address _signer;
      assembly {
        _signer := mload(add(_newSigners, add(0x14, i)))
      }
      if(_checkUniqueSigner(_signer, certificates[_certificateHash].signers)) {
        _updatedSigners = abi.encodePacked(_updatedSigners, _signer);
        emit Certified(
          _certificateHash,
          _signer
        );
      }
    }

    /// @notice check whether the certificate is freshly being registered.
    ///   For new certificates, directly proceed with adding it.
    ///   For existing certificates only update the signers if there are any new.
    if(certificates[_certificateHash].signers.length > 0) {
      require(_updatedSigners.length > certificates[_certificateHash].signers.length, 'need new signers');
      certificates[_certificateHash].signers = _updatedSigners;
    } else {
      certificates[_certificateHash] = _certificateObj;
    }

    return _certificateHash;
  }

  /// @notice Used by contract to seperate signers from certificate data.
  /// @param _signedCertificate RLP encoded certificate according to CertiDApp Certificate standard.
  /// @param _allowedSignersOnly Should it consider only KYC approved signers ?
  /// @return _certificateObj Seperation of certificate data and signers (computed from signatures)
  /// @return _certificateHash Unique identifier of the certificate data
  function parseSignedCertificate(
    bytes memory _signedCertificate,
    bool _allowedSignersOnly
  ) public view returns (
    Certificate memory _certificateObj,
    bytes32 _certificateHash
  ) {
    RLP.RLPItem[] memory _certificateRLP = _signedCertificate.toRlpItem().toList();

    _certificateObj.data = _certificateRLP[0].toRlpBytes();

    _certificateHash = keccak256(abi.encodePacked(
      PERSONAL_PREFIX,
      _getBytesStr(_certificateObj.data.length),
      _certificateObj.data
    ));

    /// @notice loop through every signature and use eliptic curves cryptography to recover the
    ///   address of the wallet used for signing the certificate.
    for(uint256 i = 1; i < _certificateRLP.length; i += 1) {
      bytes memory _signature = _certificateRLP[i].toBytes();

      bytes32 _r;
      bytes32 _s;
      uint8 _v;

      assembly {
        let _pointer := add(_signature, 0x20)
        _r := mload(_pointer)
        _s := mload(add(_pointer, 0x20))
        _v := byte(0, mload(add(_pointer, 0x40)))
        if lt(_v, 27) { _v := add(_v, 27) }
      }

      require(_v == 27 || _v == 28, 'invalid recovery value');

      address _signer = ecrecover(_certificateHash, _v, _r, _s);

      require(_checkUniqueSigner(_signer, _certificateObj.signers), 'each signer should be unique');

      if(_allowedSignersOnly) {
        require(certifyingAuthorities[_signer].status == AuthorityStatus.Authorised, 'certifier not authorised');
      }

      /// @dev packing every signer address into a single bytes value
      _certificateObj.signers = abi.encodePacked(_certificateObj.signers, _signer);
    }
  }

  /// @notice Used to change the manager
  /// @param _newManagerAddress Address of next manager wallet
  function _changeManager(address _newManagerAddress) private {
    manager = _newManagerAddress;
    emit ManagerUpdated(_newManagerAddress);
  }

  /// @notice Used to check whether an address exists in packed addresses bytes
  /// @param _signer Address of the signer wallet
  /// @param _packedSigners Bytes string of addressed packed together
  /// @return boolean value which means if _signer doesnot exist in _packedSigners bytes string
  function _checkUniqueSigner(
    address _signer,
    bytes memory _packedSigners
  ) private pure returns (bool){
    if(_packedSigners.length == 0) return true;

    require(_packedSigners.length % 20 == 0, 'invalid packed signers length');

    address _tempSigner;
    /// @notice loop through every packed signer and check if signer exists in the packed signers
    for(uint256 i = 0; i < _packedSigners.length; i += 20) {
      assembly {
        _tempSigner := mload(add(_packedSigners, add(0x14, i)))
      }
      if(_tempSigner == _signer) return false;
    }

    return true;
  }

  /// @notice Used to get a number's utf8 representation
  /// @param i Integer
  /// @return utf8 representation of i
  function _getBytesStr(uint i) private pure returns (bytes memory) {
    if (i == 0) {
      return "0";
    }
    uint j = i;
    uint len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint k = len - 1;
    while (i != 0) {
      bstr[k--] = byte(uint8(48 + i % 10));
      i /= 10;
    }
    return bstr;
  }
}

pragma solidity 0.6.2;

import 'StorageStructure.sol';

/**
 * https://eips.ethereum.org/EIPS/eip-897
 * Credits: OpenZeppelin Labs
 */
contract Proxy is StorageStructure {
  string public version;
  address public implementation;
  uint256 public constant proxyType = 2;

  /**
   * @dev This event will be emitted every time the implementation gets upgraded
   * @param version representing the version name of the upgraded implementation
   * @param implementation representing the address of the upgraded implementation
   */
  event Upgraded(string version, address indexed implementation);

  /**
   * @dev constructor that sets the manager address
   */
  constructor() public {
    manager = msg.sender;
  }

  /**
   * @dev Upgrades the implementation address
   * @param _newImplementation address of the new implementation
   */
  function upgradeTo(
    string calldata _version,
    address _newImplementation
  ) external onlyManager {
    require(implementation != _newImplementation);
    _setImplementation(_version, _newImplementation);
  }

  /**
   * @dev Fallback function allowing to perform a delegatecall
   * to the given implementation. This function will return
   * whatever the implementation call returns
   */
  fallback () external {
    address _impl = implementation;
    require(_impl != address(0));

    assembly {
      let ptr := mload(0x40)
      calldatacopy(ptr, 0, calldatasize())
      let result := delegatecall(gas(), _impl, ptr, calldatasize(), 0, 0)
      let size := returndatasize()
      returndatacopy(ptr, 0, size)

      switch result
      case 0 { revert(ptr, size) }
      default { return(ptr, size) }
    }
  }

  /**
   * @dev Sets the address of the current implementation
   * @param _newImp address of the new implementation
   */
  function _setImplementation(string memory _version, address _newImp) internal {
    version = _version;
    implementation = _newImp;
    emit Upgraded(version, implementation);
  }
}

/**
 * Credits: https://github.com/hamdiallam/Solidity-RLP/blob/master/contracts/RLPReader.sol
 */
pragma solidity ^0.6.2;

library RLP {
  uint8 constant STRING_SHORT_START = 0x80;
  uint8 constant STRING_LONG_START  = 0xb8;
  uint8 constant LIST_SHORT_START   = 0xc0;
  uint8 constant LIST_LONG_START    = 0xf8;
  uint8 constant WORD_SIZE = 32;

  struct RLPItem {
    uint len;
    uint memPtr;
  }

  struct Iterator {
    RLPItem item;   // Item that's being iterated over.
    uint nextPtr;   // Position of the next item in the list.
  }

  /*
  * @dev Returns the next element in the iteration. Reverts if it has not next element.
  * @param self The iterator.
  * @return The next element in the iteration.
  */
  function next(Iterator memory self) internal pure returns (RLPItem memory) {
    require(hasNext(self));

    uint ptr = self.nextPtr;
    uint itemLength = _itemLength(ptr);
    self.nextPtr = ptr + itemLength;

    return RLPItem(itemLength, ptr);
  }

  /*
  * @dev Returns true if the iteration has more elements.
  * @param self The iterator.
  * @return true if the iteration has more elements.
  */
  function hasNext(Iterator memory self) internal pure returns (bool) {
    RLPItem memory item = self.item;
    return self.nextPtr < item.memPtr + item.len;
  }

  /*
  * @param item RLP encoded bytes
  */
  function toRlpItem(bytes memory item) internal pure returns (RLPItem memory) {
    uint memPtr;
    assembly {
      memPtr := add(item, 0x20)
    }

    return RLPItem(item.length, memPtr);
  }

  /*
  * @dev Create an iterator. Reverts if item is not a list.
  * @param self The RLP item.
  * @return An 'Iterator' over the item.
  */
  function iterator(RLPItem memory self) internal pure returns (Iterator memory) {
    require(isList(self));

    uint ptr = self.memPtr + _payloadOffset(self.memPtr);
    return Iterator(self, ptr);
  }

  /*
  * @param item RLP encoded bytes
  */
  function rlpLen(RLPItem memory item) internal pure returns (uint) {
    return item.len;
  }

  /*
  * @param item RLP encoded bytes
  */
  function payloadLen(RLPItem memory item) internal pure returns (uint) {
    return item.len - _payloadOffset(item.memPtr);
  }

  /*
  * @param item RLP encoded list in bytes
  */
  function toList(RLPItem memory item) internal pure returns (RLPItem[] memory) {
    require(isList(item));

    uint items = numItems(item);
    RLPItem[] memory result = new RLPItem[](items);

    uint memPtr = item.memPtr + _payloadOffset(item.memPtr);
    uint dataLen;
    for (uint i = 0; i < items; i++) {
      dataLen = _itemLength(memPtr);
      result[i] = RLPItem(dataLen, memPtr);
      memPtr = memPtr + dataLen;
    }

    return result;
  }

  // @return indicator whether encoded payload is a list. negate this function call for isData.
  function isList(RLPItem memory item) internal pure returns (bool) {
    if(item.len == 0) return false;

    uint8 byte0;
    uint memPtr = item.memPtr;
    assembly {
      byte0 := byte(0, mload(memPtr))
    }

    if(byte0 < LIST_SHORT_START) return false;

    return true;
  }

  /** RLPItem conversions into data types **/

  // @returns raw rlp encoding in bytes
  function toRlpBytes(RLPItem memory item) internal pure returns (bytes memory) {
    bytes memory result = new bytes(item.len);
    if (result.length == 0) return result;

    uint ptr;
    assembly {
      ptr := add(0x20, result)
    }

    copy(item.memPtr, ptr, item.len);
    return result;
  }

  // any non-zero byte is considered true
  function toBoolean(RLPItem memory item) internal pure returns (bool) {
    require(item.len == 1);
    uint result;
    uint memPtr = item.memPtr;
    assembly {
      result := byte(0, mload(memPtr))
    }

    return result == 0 ? false : true;
  }

  function toAddress(RLPItem memory item) internal pure returns (address) {
    // 1 byte for the length prefix
    require(item.len == 21);

    return address(toUint(item));
  }

  function toUint(RLPItem memory item) internal pure returns (uint) {
    require(item.len > 0 && item.len <= 33);

    uint offset = _payloadOffset(item.memPtr);
    uint len = item.len - offset;

    uint result;
    uint memPtr = item.memPtr + offset;
    assembly {
      result := mload(memPtr)

      // shfit to the correct location if neccesary
      if lt(len, 32) {
          result := div(result, exp(256, sub(32, len)))
      }
    }

    return result;
  }

  // enforces 32 byte length
  function toUintStrict(RLPItem memory item) internal pure returns (uint) {
    // one byte prefix
    require(item.len == 33);

    uint result;
    uint memPtr = item.memPtr + 1;
    assembly {
      result := mload(memPtr)
    }

    return result;
  }

  function toBytes(RLPItem memory item) internal pure returns (bytes memory) {
    require(item.len > 0);

    uint offset = _payloadOffset(item.memPtr);
    uint len = item.len - offset; // data length
    bytes memory result = new bytes(len);

    uint destPtr;
    assembly {
      destPtr := add(0x20, result)
    }

    copy(item.memPtr + offset, destPtr, len);
    return result;
  }

  /*
  * Private Helpers
  */

  // @return number of payload items inside an encoded list.
  function numItems(RLPItem memory item) private pure returns (uint) {
    if (item.len == 0) return 0;

    uint count = 0;
    uint currPtr = item.memPtr + _payloadOffset(item.memPtr);
    uint endPtr = item.memPtr + item.len;
    while (currPtr < endPtr) {
      currPtr = currPtr + _itemLength(currPtr); // skip over an item
      count++;
    }

    return count;
  }

  // @return entire rlp item byte length
  function _itemLength(uint memPtr) private pure returns (uint) {
    uint itemLen;
    uint byte0;
    assembly {
      byte0 := byte(0, mload(memPtr))
    }

    if (byte0 < STRING_SHORT_START)
      itemLen = 1;

    else if (byte0 < STRING_LONG_START)
      itemLen = byte0 - STRING_SHORT_START + 1;

    else if (byte0 < LIST_SHORT_START) {
      assembly {
        let byteLen := sub(byte0, 0xb7) // # of bytes the actual length is
        memPtr := add(memPtr, 1) // skip over the first byte

        /* 32 byte word size */
        let dataLen := div(mload(memPtr), exp(256, sub(32, byteLen))) // right shifting to get the len
        itemLen := add(dataLen, add(byteLen, 1))
      }
    }

    else if (byte0 < LIST_LONG_START) {
      itemLen = byte0 - LIST_SHORT_START + 1;
    }

    else {
      assembly {
        let byteLen := sub(byte0, 0xf7)
        memPtr := add(memPtr, 1)

        let dataLen := div(mload(memPtr), exp(256, sub(32, byteLen))) // right shifting to the correct length
        itemLen := add(dataLen, add(byteLen, 1))
      }
    }

    return itemLen;
  }

  // @return number of bytes until the data
  function _payloadOffset(uint memPtr) private pure returns (uint) {
    uint byte0;
    assembly {
      byte0 := byte(0, mload(memPtr))
    }

    if (byte0 < STRING_SHORT_START)
      return 0;
    else if (byte0 < STRING_LONG_START || (byte0 >= LIST_SHORT_START && byte0 < LIST_LONG_START))
      return 1;
    else if (byte0 < LIST_SHORT_START)  // being explicit
      return byte0 - (STRING_LONG_START - 1) + 1;
    else
      return byte0 - (LIST_LONG_START - 1) + 1;
  }

  /*
  * @param src Pointer to source
  * @param dest Pointer to destination
  * @param len Amount of memory to copy from the source
  */
  function copy(uint src, uint dest, uint len) private pure {
    if (len == 0) return;

    // copy as many word sizes as possible
    for (; len >= WORD_SIZE; len -= WORD_SIZE) {
      assembly {
          mstore(dest, mload(src))
      }

      src += WORD_SIZE;
      dest += WORD_SIZE;
    }

    // left over bytes. Mask is used to remove unwanted bytes from the word
    uint mask = 256 ** (WORD_SIZE - len) - 1;
    assembly {
      let srcpart := and(mload(src), not(mask)) // zero out src
      let destpart := and(mload(dest), mask) // retrieve the bytes
      mstore(dest, or(destpart, srcpart))
    }
  }
}

pragma solidity 0.6.2;

/// @title Storage Structure for CertiÐApp Certificate Contract
/// @dev This contract is intended to be inherited in Proxy and Implementation contracts.
contract StorageStructure {
  enum AuthorityStatus { NotAuthorised, Authorised, Migrated, Suspended }

  struct Certificate {
    bytes data;
    bytes signers;
  }

  struct CertifyingAuthority {
    bytes data;
    AuthorityStatus status;
  }

  mapping(bytes32 => Certificate) public certificates;
  mapping(address => CertifyingAuthority) public certifyingAuthorities;
  mapping(bytes32 => bytes32) extraData;

  address public manager;

  bytes constant public PERSONAL_PREFIX = "\x19Ethereum Signed Message:\n";

  event ManagerUpdated(
    address _newManager
  );

  event Certified(
    bytes32 indexed _certificateHash,
    address indexed _certifyingAuthority
  );

  event AuthorityStatusUpdated(
    address indexed _certifyingAuthority,
    AuthorityStatus _newStatus
  );

  event AuthorityMigrated(
    address indexed _oldAddress,
    address indexed _newAddress
  );

  modifier onlyManager() {
    require(msg.sender == manager, 'only manager can call');
    _;
  }

  modifier onlyAuthorisedCertifier() {
    require(
      certifyingAuthorities[msg.sender].status == AuthorityStatus.Authorised
      , 'only authorised certifier can call'
    );
    _;
  }
}

pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;

import 'RLP.sol';
import 'StorageStructure.sol';

/// @title CertiÐApp Smart Contract
/// @author Soham Zemse from The EraSwap Team
/// @notice This contract accepts certificates signed by multiple authorised signers
contract CertiDApp is StorageStructure {
  using RLP for bytes;
  using RLP for RLP.RLPItem;

  /// @notice Sets up the CertiDApp manager address when deployed
  constructor() public {
    _changeManager(msg.sender);
  }

  /// @notice Used by present manager to change the manager wallet address
  /// @param _newManagerAddress Address of next manager wallet
  function changeManager(address _newManagerAddress) public onlyManager {
    _changeManager(_newManagerAddress);
  }

  /// @notice Used by manager to for to update KYC / verification status of Certifying Authorities
  /// @param _authorityAddress Wallet address of certifying authority
  /// @param _data RLP encoded KYC details of certifying authority
  function updateCertifyingAuthority(
    address _authorityAddress,
    bytes memory _data,
    AuthorityStatus _status
  ) public onlyManager {
    if(_data.length > 0) {
      certifyingAuthorities[_authorityAddress].data = _data;
    }

    certifyingAuthorities[_authorityAddress].status = _status;

    emit AuthorityStatusUpdated(_authorityAddress, _status);
  }

  /// @notice Used by Certifying Authorities to change their wallet (in case of theft).
  ///   Migrating prevents any new certificate registrations signed by the old wallet.
  ///   Already registered certificates would be valid.
  /// @param _newAuthorityAddress Next wallet address of the same certifying authority
  function migrateCertifyingAuthority(
    address _newAuthorityAddress
  ) public onlyAuthorisedCertifier {
    require(
      certifyingAuthorities[_newAuthorityAddress].status == AuthorityStatus.NotAuthorised
      , 'cannot migrate to an already authorised address'
    );

    certifyingAuthorities[msg.sender].status = AuthorityStatus.Migrated;
    emit AuthorityStatusUpdated(msg.sender, AuthorityStatus.Migrated);

    certifyingAuthorities[_newAuthorityAddress] = CertifyingAuthority({
      data: certifyingAuthorities[msg.sender].data,
      status: AuthorityStatus.Authorised
    });
    emit AuthorityStatusUpdated(_newAuthorityAddress, AuthorityStatus.Authorised);

    emit AuthorityMigrated(msg.sender, _newAuthorityAddress);
  }

  /// @notice Used to submit a signed certificate to smart contract for adding it to storage.
  ///   Anyone can submit the certificate, the one submitting has to pay the nominal gas fee.
  /// @param _signedCertificate RLP encoded certificate according to CertiDApp Certificate standard.
  function registerCertificate(
    bytes memory _signedCertificate
  ) public returns (
    bytes32
  ) {
    (Certificate memory _certificateObj, bytes32 _certificateHash) = parseSignedCertificate(_signedCertificate, true);

    /// @notice Signers in this transaction
    bytes memory _newSigners = _certificateObj.signers;

    /// @notice If certificate already registered then signers can be updated.
    ///   Initializing _updatedSigners with existing signers on blockchain if any.
    ///   More signers would be appended to this in next 'for' loop.
    bytes memory _updatedSigners = certificates[_certificateHash].signers;

    /// @notice Check with every the new signer if it is not already included in storage.
    ///   This is helpful when a same certificate is submitted again with more signatures,
    ///   the contract will consider only new signers in that case.
    for(uint256 i = 0; i < _newSigners.length; i += 20) {
      address _signer;
      assembly {
        _signer := mload(add(_newSigners, add(0x14, i)))
      }
      if(_checkUniqueSigner(_signer, certificates[_certificateHash].signers)) {
        _updatedSigners = abi.encodePacked(_updatedSigners, _signer);
        emit Certified(
          _certificateHash,
          _signer
        );
      }
    }

    /// @notice check whether the certificate is freshly being registered.
    ///   For new certificates, directly proceed with adding it.
    ///   For existing certificates only update the signers if there are any new.
    if(certificates[_certificateHash].signers.length > 0) {
      require(_updatedSigners.length > certificates[_certificateHash].signers.length, 'need new signers');
      certificates[_certificateHash].signers = _updatedSigners;
    } else {
      certificates[_certificateHash] = _certificateObj;
    }

    return _certificateHash;
  }

  /// @notice Used by contract to seperate signers from certificate data.
  /// @param _signedCertificate RLP encoded certificate according to CertiDApp Certificate standard.
  /// @param _allowedSignersOnly Should it consider only KYC approved signers ?
  /// @return _certificateObj Seperation of certificate data and signers (computed from signatures)
  /// @return _certificateHash Unique identifier of the certificate data
  function parseSignedCertificate(
    bytes memory _signedCertificate,
    bool _allowedSignersOnly
  ) public view returns (
    Certificate memory _certificateObj,
    bytes32 _certificateHash
  ) {
    RLP.RLPItem[] memory _certificateRLP = _signedCertificate.toRlpItem().toList();

    _certificateObj.data = _certificateRLP[0].toRlpBytes();

    _certificateHash = keccak256(abi.encodePacked(
      PERSONAL_PREFIX,
      _getBytesStr(_certificateObj.data.length),
      _certificateObj.data
    ));

    /// @notice loop through every signature and use eliptic curves cryptography to recover the
    ///   address of the wallet used for signing the certificate.
    for(uint256 i = 1; i < _certificateRLP.length; i += 1) {
      bytes memory _signature = _certificateRLP[i].toBytes();

      bytes32 _r;
      bytes32 _s;
      uint8 _v;

      assembly {
        let _pointer := add(_signature, 0x20)
        _r := mload(_pointer)
        _s := mload(add(_pointer, 0x20))
        _v := byte(0, mload(add(_pointer, 0x40)))
        if lt(_v, 27) { _v := add(_v, 27) }
      }

      require(_v == 27 || _v == 28, 'invalid recovery value');

      address _signer = ecrecover(_certificateHash, _v, _r, _s);

      require(_checkUniqueSigner(_signer, _certificateObj.signers), 'each signer should be unique');

      if(_allowedSignersOnly) {
        require(certifyingAuthorities[_signer].status == AuthorityStatus.Authorised, 'certifier not authorised');
      }

      /// @dev packing every signer address into a single bytes value
      _certificateObj.signers = abi.encodePacked(_certificateObj.signers, _signer);
    }
  }

  /// @notice Used to change the manager
  /// @param _newManagerAddress Address of next manager wallet
  function _changeManager(address _newManagerAddress) private {
    manager = _newManagerAddress;
    emit ManagerUpdated(_newManagerAddress);
  }

  /// @notice Used to check whether an address exists in packed addresses bytes
  /// @param _signer Address of the signer wallet
  /// @param _packedSigners Bytes string of addressed packed together
  /// @return boolean value which means if _signer doesnot exist in _packedSigners bytes string
  function _checkUniqueSigner(
    address _signer,
    bytes memory _packedSigners
  ) private pure returns (bool){
    if(_packedSigners.length == 0) return true;

    require(_packedSigners.length % 20 == 0, 'invalid packed signers length');

    address _tempSigner;
    /// @notice loop through every packed signer and check if signer exists in the packed signers
    for(uint256 i = 0; i < _packedSigners.length; i += 20) {
      assembly {
        _tempSigner := mload(add(_packedSigners, add(0x14, i)))
      }
      if(_tempSigner == _signer) return false;
    }

    return true;
  }

  /// @notice Used to get a number's utf8 representation
  /// @param i Integer
  /// @return utf8 representation of i
  function _getBytesStr(uint i) private pure returns (bytes memory) {
    if (i == 0) {
      return "0";
    }
    uint j = i;
    uint len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint k = len - 1;
    while (i != 0) {
      bstr[k--] = byte(uint8(48 + i % 10));
      i /= 10;
    }
    return bstr;
  }
}

pragma solidity 0.6.2;

import 'StorageStructure.sol';

/**
 * https://eips.ethereum.org/EIPS/eip-897
 * Credits: OpenZeppelin Labs
 */
contract Proxy is StorageStructure {
  string public version;
  address public implementation;
  uint256 public constant proxyType = 2;

  /**
   * @dev This event will be emitted every time the implementation gets upgraded
   * @param version representing the version name of the upgraded implementation
   * @param implementation representing the address of the upgraded implementation
   */
  event Upgraded(string version, address indexed implementation);

  /**
   * @dev constructor that sets the manager address
   */
  constructor() public {
    manager = msg.sender;
  }

  /**
   * @dev Upgrades the implementation address
   * @param _newImplementation address of the new implementation
   */
  function upgradeTo(
    string calldata _version,
    address _newImplementation
  ) external onlyManager {
    require(implementation != _newImplementation);
    _setImplementation(_version, _newImplementation);
  }

  /**
   * @dev Fallback function allowing to perform a delegatecall
   * to the given implementation. This function will return
   * whatever the implementation call returns
   */
  fallback () external {
    address _impl = implementation;
    require(_impl != address(0));

    assembly {
      let ptr := mload(0x40)
      calldatacopy(ptr, 0, calldatasize())
      let result := delegatecall(gas(), _impl, ptr, calldatasize(), 0, 0)
      let size := returndatasize()
      returndatacopy(ptr, 0, size)

      switch result
      case 0 { revert(ptr, size) }
      default { return(ptr, size) }
    }
  }

  /**
   * @dev Sets the address of the current implementation
   * @param _newImp address of the new implementation
   */
  function _setImplementation(string memory _version, address _newImp) internal {
    version = _version;
    implementation = _newImp;
    emit Upgraded(version, implementation);
  }
}

/**
 * Credits: https://github.com/hamdiallam/Solidity-RLP/blob/master/contracts/RLPReader.sol
 */
pragma solidity ^0.6.2;

library RLP {
  uint8 constant STRING_SHORT_START = 0x80;
  uint8 constant STRING_LONG_START  = 0xb8;
  uint8 constant LIST_SHORT_START   = 0xc0;
  uint8 constant LIST_LONG_START    = 0xf8;
  uint8 constant WORD_SIZE = 32;

  struct RLPItem {
    uint len;
    uint memPtr;
  }

  struct Iterator {
    RLPItem item;   // Item that's being iterated over.
    uint nextPtr;   // Position of the next item in the list.
  }

  /*
  * @dev Returns the next element in the iteration. Reverts if it has not next element.
  * @param self The iterator.
  * @return The next element in the iteration.
  */
  function next(Iterator memory self) internal pure returns (RLPItem memory) {
    require(hasNext(self));

    uint ptr = self.nextPtr;
    uint itemLength = _itemLength(ptr);
    self.nextPtr = ptr + itemLength;

    return RLPItem(itemLength, ptr);
  }

  /*
  * @dev Returns true if the iteration has more elements.
  * @param self The iterator.
  * @return true if the iteration has more elements.
  */
  function hasNext(Iterator memory self) internal pure returns (bool) {
    RLPItem memory item = self.item;
    return self.nextPtr < item.memPtr + item.len;
  }

  /*
  * @param item RLP encoded bytes
  */
  function toRlpItem(bytes memory item) internal pure returns (RLPItem memory) {
    uint memPtr;
    assembly {
      memPtr := add(item, 0x20)
    }

    return RLPItem(item.length, memPtr);
  }

  /*
  * @dev Create an iterator. Reverts if item is not a list.
  * @param self The RLP item.
  * @return An 'Iterator' over the item.
  */
  function iterator(RLPItem memory self) internal pure returns (Iterator memory) {
    require(isList(self));

    uint ptr = self.memPtr + _payloadOffset(self.memPtr);
    return Iterator(self, ptr);
  }

  /*
  * @param item RLP encoded bytes
  */
  function rlpLen(RLPItem memory item) internal pure returns (uint) {
    return item.len;
  }

  /*
  * @param item RLP encoded bytes
  */
  function payloadLen(RLPItem memory item) internal pure returns (uint) {
    return item.len - _payloadOffset(item.memPtr);
  }

  /*
  * @param item RLP encoded list in bytes
  */
  function toList(RLPItem memory item) internal pure returns (RLPItem[] memory) {
    require(isList(item));

    uint items = numItems(item);
    RLPItem[] memory result = new RLPItem[](items);

    uint memPtr = item.memPtr + _payloadOffset(item.memPtr);
    uint dataLen;
    for (uint i = 0; i < items; i++) {
      dataLen = _itemLength(memPtr);
      result[i] = RLPItem(dataLen, memPtr);
      memPtr = memPtr + dataLen;
    }

    return result;
  }

  // @return indicator whether encoded payload is a list. negate this function call for isData.
  function isList(RLPItem memory item) internal pure returns (bool) {
    if(item.len == 0) return false;

    uint8 byte0;
    uint memPtr = item.memPtr;
    assembly {
      byte0 := byte(0, mload(memPtr))
    }

    if(byte0 < LIST_SHORT_START) return false;

    return true;
  }

  /** RLPItem conversions into data types **/

  // @returns raw rlp encoding in bytes
  function toRlpBytes(RLPItem memory item) internal pure returns (bytes memory) {
    bytes memory result = new bytes(item.len);
    if (result.length == 0) return result;

    uint ptr;
    assembly {
      ptr := add(0x20, result)
    }

    copy(item.memPtr, ptr, item.len);
    return result;
  }

  // any non-zero byte is considered true
  function toBoolean(RLPItem memory item) internal pure returns (bool) {
    require(item.len == 1);
    uint result;
    uint memPtr = item.memPtr;
    assembly {
      result := byte(0, mload(memPtr))
    }

    return result == 0 ? false : true;
  }

  function toAddress(RLPItem memory item) internal pure returns (address) {
    // 1 byte for the length prefix
    require(item.len == 21);

    return address(toUint(item));
  }

  function toUint(RLPItem memory item) internal pure returns (uint) {
    require(item.len > 0 && item.len <= 33);

    uint offset = _payloadOffset(item.memPtr);
    uint len = item.len - offset;

    uint result;
    uint memPtr = item.memPtr + offset;
    assembly {
      result := mload(memPtr)

      // shfit to the correct location if neccesary
      if lt(len, 32) {
          result := div(result, exp(256, sub(32, len)))
      }
    }

    return result;
  }

  // enforces 32 byte length
  function toUintStrict(RLPItem memory item) internal pure returns (uint) {
    // one byte prefix
    require(item.len == 33);

    uint result;
    uint memPtr = item.memPtr + 1;
    assembly {
      result := mload(memPtr)
    }

    return result;
  }

  function toBytes(RLPItem memory item) internal pure returns (bytes memory) {
    require(item.len > 0);

    uint offset = _payloadOffset(item.memPtr);
    uint len = item.len - offset; // data length
    bytes memory result = new bytes(len);

    uint destPtr;
    assembly {
      destPtr := add(0x20, result)
    }

    copy(item.memPtr + offset, destPtr, len);
    return result;
  }

  /*
  * Private Helpers
  */

  // @return number of payload items inside an encoded list.
  function numItems(RLPItem memory item) private pure returns (uint) {
    if (item.len == 0) return 0;

    uint count = 0;
    uint currPtr = item.memPtr + _payloadOffset(item.memPtr);
    uint endPtr = item.memPtr + item.len;
    while (currPtr < endPtr) {
      currPtr = currPtr + _itemLength(currPtr); // skip over an item
      count++;
    }

    return count;
  }

  // @return entire rlp item byte length
  function _itemLength(uint memPtr) private pure returns (uint) {
    uint itemLen;
    uint byte0;
    assembly {
      byte0 := byte(0, mload(memPtr))
    }

    if (byte0 < STRING_SHORT_START)
      itemLen = 1;

    else if (byte0 < STRING_LONG_START)
      itemLen = byte0 - STRING_SHORT_START + 1;

    else if (byte0 < LIST_SHORT_START) {
      assembly {
        let byteLen := sub(byte0, 0xb7) // # of bytes the actual length is
        memPtr := add(memPtr, 1) // skip over the first byte

        /* 32 byte word size */
        let dataLen := div(mload(memPtr), exp(256, sub(32, byteLen))) // right shifting to get the len
        itemLen := add(dataLen, add(byteLen, 1))
      }
    }

    else if (byte0 < LIST_LONG_START) {
      itemLen = byte0 - LIST_SHORT_START + 1;
    }

    else {
      assembly {
        let byteLen := sub(byte0, 0xf7)
        memPtr := add(memPtr, 1)

        let dataLen := div(mload(memPtr), exp(256, sub(32, byteLen))) // right shifting to the correct length
        itemLen := add(dataLen, add(byteLen, 1))
      }
    }

    return itemLen;
  }

  // @return number of bytes until the data
  function _payloadOffset(uint memPtr) private pure returns (uint) {
    uint byte0;
    assembly {
      byte0 := byte(0, mload(memPtr))
    }

    if (byte0 < STRING_SHORT_START)
      return 0;
    else if (byte0 < STRING_LONG_START || (byte0 >= LIST_SHORT_START && byte0 < LIST_LONG_START))
      return 1;
    else if (byte0 < LIST_SHORT_START)  // being explicit
      return byte0 - (STRING_LONG_START - 1) + 1;
    else
      return byte0 - (LIST_LONG_START - 1) + 1;
  }

  /*
  * @param src Pointer to source
  * @param dest Pointer to destination
  * @param len Amount of memory to copy from the source
  */
  function copy(uint src, uint dest, uint len) private pure {
    if (len == 0) return;

    // copy as many word sizes as possible
    for (; len >= WORD_SIZE; len -= WORD_SIZE) {
      assembly {
          mstore(dest, mload(src))
      }

      src += WORD_SIZE;
      dest += WORD_SIZE;
    }

    // left over bytes. Mask is used to remove unwanted bytes from the word
    uint mask = 256 ** (WORD_SIZE - len) - 1;
    assembly {
      let srcpart := and(mload(src), not(mask)) // zero out src
      let destpart := and(mload(dest), mask) // retrieve the bytes
      mstore(dest, or(destpart, srcpart))
    }
  }
}

pragma solidity 0.6.2;

/// @title Storage Structure for CertiÐApp Certificate Contract
/// @dev This contract is intended to be inherited in Proxy and Implementation contracts.
contract StorageStructure {
  enum AuthorityStatus { NotAuthorised, Authorised, Migrated, Suspended }

  struct Certificate {
    bytes data;
    bytes signers;
  }

  struct CertifyingAuthority {
    bytes data;
    AuthorityStatus status;
  }

  mapping(bytes32 => Certificate) public certificates;
  mapping(address => CertifyingAuthority) public certifyingAuthorities;
  mapping(bytes32 => bytes32) extraData;

  address public manager;

  bytes constant public PERSONAL_PREFIX = "\x19Ethereum Signed Message:\n";

  event ManagerUpdated(
    address _newManager
  );

  event Certified(
    bytes32 indexed _certificateHash,
    address indexed _certifyingAuthority
  );

  event AuthorityStatusUpdated(
    address indexed _certifyingAuthority,
    AuthorityStatus _newStatus
  );

  event AuthorityMigrated(
    address indexed _oldAddress,
    address indexed _newAddress
  );

  modifier onlyManager() {
    require(msg.sender == manager, 'only manager can call');
    _;
  }

  modifier onlyAuthorisedCertifier() {
    require(
      certifyingAuthorities[msg.sender].status == AuthorityStatus.Authorised
      , 'only authorised certifier can call'
    );
    _;
  }
}

pragma solidity 0.6.2;
pragma experimental ABIEncoderV2;

import 'RLP.sol';
import 'StorageStructure.sol';

/// @title CertiÐApp Smart Contract
/// @author Soham Zemse from The EraSwap Team
/// @notice This contract accepts certificates signed by multiple authorised signers
contract CertiDApp is StorageStructure {
  using RLP for bytes;
  using RLP for RLP.RLPItem;

  /// @notice Sets up the CertiDApp manager address when deployed
  constructor() public {
    _changeManager(msg.sender);
  }

  /// @notice Used by present manager to change the manager wallet address
  /// @param _newManagerAddress Address of next manager wallet
  function changeManager(address _newManagerAddress) public onlyManager {
    _changeManager(_newManagerAddress);
  }

  /// @notice Used by manager to for to update KYC / verification status of Certifying Authorities
  /// @param _authorityAddress Wallet address of certifying authority
  /// @param _data RLP encoded KYC details of certifying authority
  function updateCertifyingAuthority(
    address _authorityAddress,
    bytes memory _data,
    AuthorityStatus _status
  ) public onlyManager {
    if(_data.length > 0) {
      certifyingAuthorities[_authorityAddress].data = _data;
    }

    certifyingAuthorities[_authorityAddress].status = _status;

    emit AuthorityStatusUpdated(_authorityAddress, _status);
  }

  /// @notice Used by Certifying Authorities to change their wallet (in case of theft).
  ///   Migrating prevents any new certificate registrations signed by the old wallet.
  ///   Already registered certificates would be valid.
  /// @param _newAuthorityAddress Next wallet address of the same certifying authority
  function migrateCertifyingAuthority(
    address _newAuthorityAddress
  ) public onlyAuthorisedCertifier {
    require(
      certifyingAuthorities[_newAuthorityAddress].status == AuthorityStatus.NotAuthorised
      , 'cannot migrate to an already authorised address'
    );

    certifyingAuthorities[msg.sender].status = AuthorityStatus.Migrated;
    emit AuthorityStatusUpdated(msg.sender, AuthorityStatus.Migrated);

    certifyingAuthorities[_newAuthorityAddress] = CertifyingAuthority({
      data: certifyingAuthorities[msg.sender].data,
      status: AuthorityStatus.Authorised
    });
    emit AuthorityStatusUpdated(_newAuthorityAddress, AuthorityStatus.Authorised);

    emit AuthorityMigrated(msg.sender, _newAuthorityAddress);
  }

  /// @notice Used to submit a signed certificate to smart contract for adding it to storage.
  ///   Anyone can submit the certificate, the one submitting has to pay the nominal gas fee.
  /// @param _signedCertificate RLP encoded certificate according to CertiDApp Certificate standard.
  function registerCertificate(
    bytes memory _signedCertificate
  ) public returns (
    bytes32
  ) {
    (Certificate memory _certificateObj, bytes32 _certificateHash) = parseSignedCertificate(_signedCertificate, true);

    /// @notice Signers in this transaction
    bytes memory _newSigners = _certificateObj.signers;

    /// @notice If certificate already registered then signers can be updated.
    ///   Initializing _updatedSigners with existing signers on blockchain if any.
    ///   More signers would be appended to this in next 'for' loop.
    bytes memory _updatedSigners = certificates[_certificateHash].signers;

    /// @notice Check with every the new signer if it is not already included in storage.
    ///   This is helpful when a same certificate is submitted again with more signatures,
    ///   the contract will consider only new signers in that case.
    for(uint256 i = 0; i < _newSigners.length; i += 20) {
      address _signer;
      assembly {
        _signer := mload(add(_newSigners, add(0x14, i)))
      }
      if(_checkUniqueSigner(_signer, certificates[_certificateHash].signers)) {
        _updatedSigners = abi.encodePacked(_updatedSigners, _signer);
        emit Certified(
          _certificateHash,
          _signer
        );
      }
    }

    /// @notice check whether the certificate is freshly being registered.
    ///   For new certificates, directly proceed with adding it.
    ///   For existing certificates only update the signers if there are any new.
    if(certificates[_certificateHash].signers.length > 0) {
      require(_updatedSigners.length > certificates[_certificateHash].signers.length, 'need new signers');
      certificates[_certificateHash].signers = _updatedSigners;
    } else {
      certificates[_certificateHash] = _certificateObj;
    }

    return _certificateHash;
  }

  /// @notice Used by contract to seperate signers from certificate data.
  /// @param _signedCertificate RLP encoded certificate according to CertiDApp Certificate standard.
  /// @param _allowedSignersOnly Should it consider only KYC approved signers ?
  /// @return _certificateObj Seperation of certificate data and signers (computed from signatures)
  /// @return _certificateHash Unique identifier of the certificate data
  function parseSignedCertificate(
    bytes memory _signedCertificate,
    bool _allowedSignersOnly
  ) public view returns (
    Certificate memory _certificateObj,
    bytes32 _certificateHash
  ) {
    RLP.RLPItem[] memory _certificateRLP = _signedCertificate.toRlpItem().toList();

    _certificateObj.data = _certificateRLP[0].toRlpBytes();

    _certificateHash = keccak256(abi.encodePacked(
      PERSONAL_PREFIX,
      _getBytesStr(_certificateObj.data.length),
      _certificateObj.data
    ));

    /// @notice loop through every signature and use eliptic curves cryptography to recover the
    ///   address of the wallet used for signing the certificate.
    for(uint256 i = 1; i < _certificateRLP.length; i += 1) {
      bytes memory _signature = _certificateRLP[i].toBytes();

      bytes32 _r;
      bytes32 _s;
      uint8 _v;

      assembly {
        let _pointer := add(_signature, 0x20)
        _r := mload(_pointer)
        _s := mload(add(_pointer, 0x20))
        _v := byte(0, mload(add(_pointer, 0x40)))
        if lt(_v, 27) { _v := add(_v, 27) }
      }

      require(_v == 27 || _v == 28, 'invalid recovery value');

      address _signer = ecrecover(_certificateHash, _v, _r, _s);

      require(_checkUniqueSigner(_signer, _certificateObj.signers), 'each signer should be unique');

      if(_allowedSignersOnly) {
        require(certifyingAuthorities[_signer].status == AuthorityStatus.Authorised, 'certifier not authorised');
      }

      /// @dev packing every signer address into a single bytes value
      _certificateObj.signers = abi.encodePacked(_certificateObj.signers, _signer);
    }
  }

  /// @notice Used to change the manager
  /// @param _newManagerAddress Address of next manager wallet
  function _changeManager(address _newManagerAddress) private {
    manager = _newManagerAddress;
    emit ManagerUpdated(_newManagerAddress);
  }

  /// @notice Used to check whether an address exists in packed addresses bytes
  /// @param _signer Address of the signer wallet
  /// @param _packedSigners Bytes string of addressed packed together
  /// @return boolean value which means if _signer doesnot exist in _packedSigners bytes string
  function _checkUniqueSigner(
    address _signer,
    bytes memory _packedSigners
  ) private pure returns (bool){
    if(_packedSigners.length == 0) return true;

    require(_packedSigners.length % 20 == 0, 'invalid packed signers length');

    address _tempSigner;
    /// @notice loop through every packed signer and check if signer exists in the packed signers
    for(uint256 i = 0; i < _packedSigners.length; i += 20) {
      assembly {
        _tempSigner := mload(add(_packedSigners, add(0x14, i)))
      }
      if(_tempSigner == _signer) return false;
    }

    return true;
  }

  /// @notice Used to get a number's utf8 representation
  /// @param i Integer
  /// @return utf8 representation of i
  function _getBytesStr(uint i) private pure returns (bytes memory) {
    if (i == 0) {
      return "0";
    }
    uint j = i;
    uint len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint k = len - 1;
    while (i != 0) {
      bstr[k--] = byte(uint8(48 + i % 10));
      i /= 10;
    }
    return bstr;
  }
}

pragma solidity 0.6.2;

import 'StorageStructure.sol';

/**
 * https://eips.ethereum.org/EIPS/eip-897
 * Credits: OpenZeppelin Labs
 */
contract Proxy is StorageStructure {
  string public version;
  address public implementation;
  uint256 public constant proxyType = 2;

  /**
   * @dev This event will be emitted every time the implementation gets upgraded
   * @param version representing the version name of the upgraded implementation
   * @param implementation representing the address of the upgraded implementation
   */
  event Upgraded(string version, address indexed implementation);

  /**
   * @dev constructor that sets the manager address
   */
  constructor() public {
    manager = msg.sender;
  }

  /**
   * @dev Upgrades the implementation address
   * @param _newImplementation address of the new implementation
   */
  function upgradeTo(
    string calldata _version,
    address _newImplementation
  ) external onlyManager {
    require(implementation != _newImplementation);
    _setImplementation(_version, _newImplementation);
  }

  /**
   * @dev Fallback function allowing to perform a delegatecall
   * to the given implementation. This function will return
   * whatever the implementation call returns
   */
  fallback () external {
    address _impl = implementation;
    require(_impl != address(0));

    assembly {
      let ptr := mload(0x40)
      calldatacopy(ptr, 0, calldatasize())
      let result := delegatecall(gas(), _impl, ptr, calldatasize(), 0, 0)
      let size := returndatasize()
      returndatacopy(ptr, 0, size)

      switch result
      case 0 { revert(ptr, size) }
      default { return(ptr, size) }
    }
  }

  /**
   * @dev Sets the address of the current implementation
   * @param _newImp address of the new implementation
   */
  function _setImplementation(string memory _version, address _newImp) internal {
    version = _version;
    implementation = _newImp;
    emit Upgraded(version, implementation);
  }
}

/**
 * Credits: https://github.com/hamdiallam/Solidity-RLP/blob/master/contracts/RLPReader.sol
 */
pragma solidity ^0.6.2;

library RLP {
  uint8 constant STRING_SHORT_START = 0x80;
  uint8 constant STRING_LONG_START  = 0xb8;
  uint8 constant LIST_SHORT_START   = 0xc0;
  uint8 constant LIST_LONG_START    = 0xf8;
  uint8 constant WORD_SIZE = 32;

  struct RLPItem {
    uint len;
    uint memPtr;
  }

  struct Iterator {
    RLPItem item;   // Item that's being iterated over.
    uint nextPtr;   // Position of the next item in the list.
  }

  /*
  * @dev Returns the next element in the iteration. Reverts if it has not next element.
  * @param self The iterator.
  * @return The next element in the iteration.
  */
  function next(Iterator memory self) internal pure returns (RLPItem memory) {
    require(hasNext(self));

    uint ptr = self.nextPtr;
    uint itemLength = _itemLength(ptr);
    self.nextPtr = ptr + itemLength;

    return RLPItem(itemLength, ptr);
  }

  /*
  * @dev Returns true if the iteration has more elements.
  * @param self The iterator.
  * @return true if the iteration has more elements.
  */
  function hasNext(Iterator memory self) internal pure returns (bool) {
    RLPItem memory item = self.item;
    return self.nextPtr < item.memPtr + item.len;
  }

  /*
  * @param item RLP encoded bytes
  */
  function toRlpItem(bytes memory item) internal pure returns (RLPItem memory) {
    uint memPtr;
    assembly {
      memPtr := add(item, 0x20)
    }

    return RLPItem(item.length, memPtr);
  }

  /*
  * @dev Create an iterator. Reverts if item is not a list.
  * @param self The RLP item.
  * @return An 'Iterator' over the item.
  */
  function iterator(RLPItem memory self) internal pure returns (Iterator memory) {
    require(isList(self));

    uint ptr = self.memPtr + _payloadOffset(self.memPtr);
    return Iterator(self, ptr);
  }

  /*
  * @param item RLP encoded bytes
  */
  function rlpLen(RLPItem memory item) internal pure returns (uint) {
    return item.len;
  }

  /*
  * @param item RLP encoded bytes
  */
  function payloadLen(RLPItem memory item) internal pure returns (uint) {
    return item.len - _payloadOffset(item.memPtr);
  }

  /*
  * @param item RLP encoded list in bytes
  */
  function toList(RLPItem memory item) internal pure returns (RLPItem[] memory) {
    require(isList(item));

    uint items = numItems(item);
    RLPItem[] memory result = new RLPItem[](items);

    uint memPtr = item.memPtr + _payloadOffset(item.memPtr);
    uint dataLen;
    for (uint i = 0; i < items; i++) {
      dataLen = _itemLength(memPtr);
      result[i] = RLPItem(dataLen, memPtr);
      memPtr = memPtr + dataLen;
    }

    return result;
  }

  // @return indicator whether encoded payload is a list. negate this function call for isData.
  function isList(RLPItem memory item) internal pure returns (bool) {
    if(item.len == 0) return false;

    uint8 byte0;
    uint memPtr = item.memPtr;
    assembly {
      byte0 := byte(0, mload(memPtr))
    }

    if(byte0 < LIST_SHORT_START) return false;

    return true;
  }

  /** RLPItem conversions into data types **/

  // @returns raw rlp encoding in bytes
  function toRlpBytes(RLPItem memory item) internal pure returns (bytes memory) {
    bytes memory result = new bytes(item.len);
    if (result.length == 0) return result;

    uint ptr;
    assembly {
      ptr := add(0x20, result)
    }

    copy(item.memPtr, ptr, item.len);
    return result;
  }

  // any non-zero byte is considered true
  function toBoolean(RLPItem memory item) internal pure returns (bool) {
    require(item.len == 1);
    uint result;
    uint memPtr = item.memPtr;
    assembly {
      result := byte(0, mload(memPtr))
    }

    return result == 0 ? false : true;
  }

  function toAddress(RLPItem memory item) internal pure returns (address) {
    // 1 byte for the length prefix
    require(item.len == 21);

    return address(toUint(item));
  }

  function toUint(RLPItem memory item) internal pure returns (uint) {
    require(item.len > 0 && item.len <= 33);

    uint offset = _payloadOffset(item.memPtr);
    uint len = item.len - offset;

    uint result;
    uint memPtr = item.memPtr + offset;
    assembly {
      result := mload(memPtr)

      // shfit to the correct location if neccesary
      if lt(len, 32) {
          result := div(result, exp(256, sub(32, len)))
      }
    }

    return result;
  }

  // enforces 32 byte length
  function toUintStrict(RLPItem memory item) internal pure returns (uint) {
    // one byte prefix
    require(item.len == 33);

    uint result;
    uint memPtr = item.memPtr + 1;
    assembly {
      result := mload(memPtr)
    }

    return result;
  }

  function toBytes(RLPItem memory item) internal pure returns (bytes memory) {
    require(item.len > 0);

    uint offset = _payloadOffset(item.memPtr);
    uint len = item.len - offset; // data length
    bytes memory result = new bytes(len);

    uint destPtr;
    assembly {
      destPtr := add(0x20, result)
    }

    copy(item.memPtr + offset, destPtr, len);
    return result;
  }

  /*
  * Private Helpers
  */

  // @return number of payload items inside an encoded list.
  function numItems(RLPItem memory item) private pure returns (uint) {
    if (item.len == 0) return 0;

    uint count = 0;
    uint currPtr = item.memPtr + _payloadOffset(item.memPtr);
    uint endPtr = item.memPtr + item.len;
    while (currPtr < endPtr) {
      currPtr = currPtr + _itemLength(currPtr); // skip over an item
      count++;
    }

    return count;
  }

  // @return entire rlp item byte length
  function _itemLength(uint memPtr) private pure returns (uint) {
    uint itemLen;
    uint byte0;
    assembly {
      byte0 := byte(0, mload(memPtr))
    }

    if (byte0 < STRING_SHORT_START)
      itemLen = 1;

    else if (byte0 < STRING_LONG_START)
      itemLen = byte0 - STRING_SHORT_START + 1;

    else if (byte0 < LIST_SHORT_START) {
      assembly {
        let byteLen := sub(byte0, 0xb7) // # of bytes the actual length is
        memPtr := add(memPtr, 1) // skip over the first byte

        /* 32 byte word size */
        let dataLen := div(mload(memPtr), exp(256, sub(32, byteLen))) // right shifting to get the len
        itemLen := add(dataLen, add(byteLen, 1))
      }
    }

    else if (byte0 < LIST_LONG_START) {
      itemLen = byte0 - LIST_SHORT_START + 1;
    }

    else {
      assembly {
        let byteLen := sub(byte0, 0xf7)
        memPtr := add(memPtr, 1)

        let dataLen := div(mload(memPtr), exp(256, sub(32, byteLen))) // right shifting to the correct length
        itemLen := add(dataLen, add(byteLen, 1))
      }
    }

    return itemLen;
  }

  // @return number of bytes until the data
  function _payloadOffset(uint memPtr) private pure returns (uint) {
    uint byte0;
    assembly {
      byte0 := byte(0, mload(memPtr))
    }

    if (byte0 < STRING_SHORT_START)
      return 0;
    else if (byte0 < STRING_LONG_START || (byte0 >= LIST_SHORT_START && byte0 < LIST_LONG_START))
      return 1;
    else if (byte0 < LIST_SHORT_START)  // being explicit
      return byte0 - (STRING_LONG_START - 1) + 1;
    else
      return byte0 - (LIST_LONG_START - 1) + 1;
  }

  /*
  * @param src Pointer to source
  * @param dest Pointer to destination
  * @param len Amount of memory to copy from the source
  */
  function copy(uint src, uint dest, uint len) private pure {
    if (len == 0) return;

    // copy as many word sizes as possible
    for (; len >= WORD_SIZE; len -= WORD_SIZE) {
      assembly {
          mstore(dest, mload(src))
      }

      src += WORD_SIZE;
      dest += WORD_SIZE;
    }

    // left over bytes. Mask is used to remove unwanted bytes from the word
    uint mask = 256 ** (WORD_SIZE - len) - 1;
    assembly {
      let srcpart := and(mload(src), not(mask)) // zero out src
      let destpart := and(mload(dest), mask) // retrieve the bytes
      mstore(dest, or(destpart, srcpart))
    }
  }
}

pragma solidity 0.6.2;

/// @title Storage Structure for CertiÐApp Certificate Contract
/// @dev This contract is intended to be inherited in Proxy and Implementation contracts.
contract StorageStructure {
  enum AuthorityStatus { NotAuthorised, Authorised, Migrated, Suspended }

  struct Certificate {
    bytes data;
    bytes signers;
  }

  struct CertifyingAuthority {
    bytes data;
    AuthorityStatus status;
  }

  mapping(bytes32 => Certificate) public certificates;
  mapping(address => CertifyingAuthority) public certifyingAuthorities;
  mapping(bytes32 => bytes32) extraData;

  address public manager;

  bytes constant public PERSONAL_PREFIX = "\x19Ethereum Signed Message:\n";

  event ManagerUpdated(
    address _newManager
  );

  event Certified(
    bytes32 indexed _certificateHash,
    address indexed _certifyingAuthority
  );

  event AuthorityStatusUpdated(
    address indexed _certifyingAuthority,
    AuthorityStatus _newStatus
  );

  event AuthorityMigrated(
    address indexed _oldAddress,
    address indexed _newAddress
  );

  modifier onlyManager() {
    require(msg.sender == manager, 'only manager can call');
    _;
  }

  modifier onlyAuthorisedCertifier() {
    require(
      certifyingAuthorities[msg.sender].status == AuthorityStatus.Authorised
      , 'only authorised certifier can call'
    );
    _;
  }
}

