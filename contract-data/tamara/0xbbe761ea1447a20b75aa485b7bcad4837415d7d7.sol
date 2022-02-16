pragma solidity 0.5.8;

import "./ERC777ERC20Compat.sol";
import "./SafeGuard.sol";
import { CStore } from "./CStore.sol"; //TODO: Convert all imports like this

contract CALL is ERC777ERC20Compat, SafeGuard {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _granularity,
        uint256 _totalSupply,
        address _initialOwner,
        address[] memory _defaultOperators
    )
    public ERC777ERC20Compat(_name, _symbol, _granularity, _totalSupply, _initialOwner, _defaultOperators)
    {
        requireMultiple(_totalSupply);
        require(balancesDB.setModule(address(this), true), "Cannot enable access to the database.");
        balancesDB.transferOwnership(_initialOwner);

        callRecipient(msg.sender, address(0), _initialOwner, _totalSupply, "", "", true);

        emit Minted(msg.sender, _initialOwner, _totalSupply, "", "");
        if (mErc20compatible) { emit Transfer(address(0), _initialOwner, _totalSupply); }
    }

    /**
     * @notice change the balances database to `_newDB`
     * @param _newDB The new balances database address
     */
    function changeBalancesDB(address _newDB) public onlyOwner {
        balancesDB = CStore(_newDB);
    }

    /**
     * @notice Disables the ERC20 interface. This function can only be called
     * by the owner.
     */
    function disableERC20() public onlyOwner {
        mErc20compatible = false;
        setInterfaceImplementation("ERC20Token", address(0));
    }

    /**
     * @notice Re enables the ERC20 interface. This function can only be called
     *  by the owner.
     */
    function enableERC20() public onlyOwner {
        mErc20compatible = true;
        setInterfaceImplementation("ERC20Token", address(this));
    }

    /**
     * @dev Transfer the specified amounts of tokens to the specified addresses.
     * @dev Be aware that there is no check for duplicate recipients.
     * @param _toAddresses Receiver addresses.
     * @param _amounts Amounts of tokens that will be transferred.
     */
    function multiPartyTransfer(address[] calldata _toAddresses, uint256[] calldata _amounts) external erc20 {
        /* Ensures _toAddresses array is less than or equal to 255 */
        require(_toAddresses.length <= 255, "Unsupported number of addresses.");
        /* Ensures _toAddress and _amounts have the same number of entries. */
        require(_toAddresses.length == _amounts.length, "Provided addresses does not equal to provided sums.");

        for (uint8 i = 0; i < _toAddresses.length; i++) {
            transfer(_toAddresses[i], _amounts[i]);
        }
    }

    /**
    * @dev Transfer the specified amounts of tokens to the specified addresses from authorized balance of sender.
    * @dev Be aware that there is no check for duplicate recipients.
    * @param _from The address of the sender
    * @param _toAddresses The addresses of the recipients (MAX 255)
    * @param _amounts The amounts of tokens to be transferred
    */
    function multiPartyTransferFrom(address _from, address[] calldata _toAddresses, uint256[] calldata _amounts) external erc20 {
        /* Ensures _toAddresses array is less than or equal to 255 */
        require(_toAddresses.length <= 255, "Unsupported number of addresses.");
        /* Ensures _toAddress and _amounts have the same number of entries. */
        require(_toAddresses.length == _amounts.length, "Provided addresses does not equal to provided sums.");

        for (uint8 i = 0; i < _toAddresses.length; i++) {
            transferFrom(_from, _toAddresses[i], _amounts[i]);
        }
    }

    /**
     * @dev Transfer the specified amounts of tokens to the specified addresses.
     * @dev Be aware that there is no check for duplicate recipients.
     * @param _toAddresses Receiver addresses.
     * @param _amounts Amounts of tokens that will be transferred.
     * @param _userData User supplied data
     */
    function multiPartySend(address[] memory _toAddresses, uint256[] memory _amounts, bytes memory _userData) public {
        /* Ensures _toAddresses array is less than or equal to 255 */
        require(_toAddresses.length <= 255, "Unsupported number of addresses.");
        /* Ensures _toAddress and _amounts have the same number of entries. */
        require(_toAddresses.length == _amounts.length, "Provided addresses does not equal to provided sums.");

        for (uint8 i = 0; i < _toAddresses.length; i++) {
            doSend(msg.sender,  msg.sender, _toAddresses[i], _amounts[i], _userData, "", true);
        }
    }

    /**
    * @dev Transfer the specified amounts of tokens to the specified addresses as `_from`.
    * @dev Be aware that there is no check for duplicate recipients.
    * @param _from Address to use as sender
    * @param _to Receiver addresses.
    * @param _amounts Amounts of tokens that will be transferred.
    * @param _userData User supplied data
    * @param _operatorData Operator supplied data
    */
    function multiOperatorSend(address _from, address[] calldata _to, uint256[] calldata _amounts, bytes calldata _userData, bytes calldata _operatorData)
    external {
        /* Ensures _toAddresses array is less than or equal to 255 */
        require(_to.length <= 255, "Unsupported number of addresses.");
        /* Ensures _toAddress and _amounts have the same number of entries. */
        require(_to.length == _amounts.length, "Provided addresses does not equal to provided sums.");

        for (uint8 i = 0; i < _to.length; i++) {
            require(isOperatorFor(msg.sender, _from), "Not an operator"); //TODO check for denial of service
            doSend(msg.sender, _from, _to[i], _amounts[i], _userData, _operatorData, true);
        }
    }
}


pragma solidity ^0.5.0;

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
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () internal { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

pragma solidity 0.5.8;

import "./ERC644Balances.sol";
import { ERC1820Client } from "./ERC1820Client.sol";


/**
 * @title ERC644 Database Contract
 * @author Panos
 */
contract CStore is ERC644Balances, ERC1820Client {

    address[] internal mDefaultOperators;
    mapping(address => bool) internal mIsDefaultOperator;
    mapping(address => mapping(address => bool)) internal mRevokedDefaultOperator;
    mapping(address => mapping(address => bool)) internal mAuthorizedOperators;

    /**
     * @notice Database construction
     * @param _totalSupply The total supply of the token
     */
    constructor(uint256 _totalSupply, address _initialOwner, address[] memory _defaultOperators) public
    {
        balances[_initialOwner] = _totalSupply;
        totalSupply = _totalSupply;
        mDefaultOperators = _defaultOperators;
        for (uint256 i = 0; i < mDefaultOperators.length; i++) { mIsDefaultOperator[mDefaultOperators[i]] = true; }

        setInterfaceImplementation("ERC644Balances", address(this));
    }

    /**
     * @notice Increase total supply by `_val`
     * @param _val Value to increase
     * @return Operation status
     */
    // solhint-disable-next-line no-unused-vars
    function incTotalSupply(uint _val) external onlyModule returns (bool) {
        return false;
    }

    /**
     * @notice Decrease total supply by `_val`
     * @param _val Value to decrease
     * @return Operation status
     */
     // solhint-disable-next-line no-unused-vars
     function decTotalSupply(uint _val) external onlyModule returns (bool) {
         return false;
     }

    /**
     * @notice moving `_amount` from `_from` to `_to`
     * @param _from The sender address
     * @param _to The receiving address
     * @param _amount The moving amount
     * @return bool The move result
     */
    function move(address _from, address _to, uint256 _amount) external
    onlyModule
    returns (bool) {
        balances[_from] = balances[_from].sub(_amount);
        emit BalanceAdj(msg.sender, _from, _amount, "-");
        balances[_to] = balances[_to].add(_amount);
        emit BalanceAdj(msg.sender, _to, _amount, "+");
        return true;
    }

    /**
     * @notice Setting operator `_operator` for `_tokenHolder`
     * @param _operator The operator to set status
     * @param _tokenHolder The token holder to set operator
     * @param _status The operator status
     * @return bool Status of operation
     */
    function setAuthorizedOperator(address _operator, address _tokenHolder, bool _status) external
    onlyModule
    returns (bool) {
        mAuthorizedOperators[_operator][_tokenHolder] = _status;
        return true;
    }

    /**
     * @notice Set revoke status for default operator `_operator` for `_tokenHolder`
     * @param _operator The default operator to set status
     * @param _tokenHolder The token holder to set operator
     * @param _status The operator status
     * @return bool Status of operation
     */
    function setRevokedDefaultOperator(address _operator, address _tokenHolder, bool _status) external
    onlyModule
    returns (bool) {
    mRevokedDefaultOperator[_operator][_tokenHolder] = _status;
        return true;
    }

    /**
     * @notice Getting operator `_operator` for `_tokenHolder`
     * @param _operator The operator address to get status
     * @param _tokenHolder The token holder address
     * @return bool Operator status
     */
    function getAuthorizedOperator(address _operator, address _tokenHolder) external
    view
    returns (bool) {
        return mAuthorizedOperators[_operator][_tokenHolder];
    }

    /**
     * @notice Getting default operator `_operator`
     * @param _operator The default operator address to get status
     * @return bool Default operator status
     */
    function getDefaultOperator(address _operator) external view returns (bool) {
        return mIsDefaultOperator[_operator];
    }

    /**
     * @notice Getting default operators
     * @return address[] Default operator addresses
     */
    function getDefaultOperators() external view returns (address[] memory) {
        return mDefaultOperators;
    }

    function getRevokedDefaultOperator(address _operator, address _tokenHolder) external view returns (bool) {
        return mRevokedDefaultOperator[_operator][_tokenHolder];
    }

    /**
     * @notice Increment `_acct` balance by `_val`
     * @param _acct Target account to increment balance.
     * @param _val Value to increment
     * @return Operation status
     */
    // solhint-disable-next-line no-unused-vars
    function incBalance(address _acct, uint _val) public onlyModule returns (bool) {
        return false;
    }

    /**
     * @notice Decrement `_acct` balance by `_val`
     * @param _acct Target account to decrement balance.
     * @param _val Value to decrement
     * @return Operation status
     */
     // solhint-disable-next-line no-unused-vars
     function decBalance(address _acct, uint _val) public onlyModule returns (bool) {
         return false;
     }
}


pragma solidity ^0.5.3;


contract ERC1820Registry {
    function setInterfaceImplementer(address _addr, bytes32 _interfaceHash, address _implementer) external;
    function getInterfaceImplementer(address _addr, bytes32 _interfaceHash) external view returns (address);
    function setManager(address _addr, address _newManager) external;
    function getManager(address _addr) public view returns (address);
}


/// Base client to interact with the registry.
contract ERC1820Client {
    ERC1820Registry constant ERC1820REGISTRY = ERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    function setInterfaceImplementation(string memory _interfaceLabel, address _implementation) internal {
        bytes32 interfaceHash = keccak256(abi.encodePacked(_interfaceLabel));
        ERC1820REGISTRY.setInterfaceImplementer(address(this), interfaceHash, _implementation);
    }

    function interfaceAddr(address addr, string memory _interfaceLabel) internal view returns(address) {
        bytes32 interfaceHash = keccak256(abi.encodePacked(_interfaceLabel));
        return ERC1820REGISTRY.getInterfaceImplementer(addr, interfaceHash);
    }

    function delegateManagement(address _newManager) internal {
        ERC1820REGISTRY.setManager(address(this), _newManager);
    }
}

pragma solidity 0.5.8;

import "./SafeMath.sol";
import "./SafeGuard.sol";
import "./IERC644.sol";


/**
 * @title ERC644 Standard Balances Contract
 * @author chrisfranko
 */
contract ERC644Balances is IERC644, SafeGuard {
    using SafeMath for uint256;

    uint256 public totalSupply;

    event BalanceAdj(address indexed module, address indexed account, uint amount, string polarity);
    event ModuleSet(address indexed module, bool indexed set);

    mapping(address => bool) public modules;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowed;

    modifier onlyModule() {
        require(modules[msg.sender], "ERC644Balances: caller is not a module");
        _;
    }

    /**
     * @notice Set allowance of `_spender` in behalf of `_sender` at `_value`
     * @param _sender Owner account
     * @param _spender Spender account
     * @param _value Value to approve
     * @return Operation status
     */
    function setApprove(address _sender, address _spender, uint256 _value) external onlyModule returns (bool) {
        allowed[_sender][_spender] = _value;
        return true;
    }

    /**
     * @notice Decrease allowance of `_spender` in behalf of `_from` at `_value`
     * @param _from Owner account
     * @param _spender Spender account
     * @param _value Value to decrease
     * @return Operation status
     */
    function decApprove(address _from, address _spender, uint _value) external onlyModule returns (bool) {
        allowed[_from][_spender] = allowed[_from][_spender].sub(_value);
        return true;
    }

    /**
    * @notice Increase total supply by `_val`
    * @param _val Value to increase
    * @return Operation status
    */
    function incTotalSupply(uint _val) external onlyModule returns (bool) {
        totalSupply = totalSupply.add(_val);
        return true;
    }

    /**
     * @notice Decrease total supply by `_val`
     * @param _val Value to decrease
     * @return Operation status
     */
    function decTotalSupply(uint _val) external onlyModule returns (bool) {
        totalSupply = totalSupply.sub(_val);
        return true;
    }

    /**
     * @notice Set/Unset `_acct` as an authorized module
     * @param _acct Module address
     * @param _set Module set status
     * @return Operation status
     */
    function setModule(address _acct, bool _set) external onlyOwner returns (bool) {
        modules[_acct] = _set;
        emit ModuleSet(_acct, _set);
        return true;
    }

    /**
     * @notice Get `_acct` balance
     * @param _acct Target account to get balance.
     * @return The account balance
     */
    function getBalance(address _acct) external view returns (uint256) {
        return balances[_acct];
    }

    /**
     * @notice Get allowance of `_spender` in behalf of `_owner`
     * @param _owner Owner account
     * @param _spender Spender account
     * @return Allowance
     */
    function getAllowance(address _owner, address _spender) external view returns (uint256) {
        return allowed[_owner][_spender];
    }

    /**
     * @notice Get if `_acct` is an authorized module
     * @param _acct Module address
     * @return Operation status
     */
    function getModule(address _acct) external view returns (bool) {
        return modules[_acct];
    }

    /**
     * @notice Get total supply
     * @return Total supply
     */
    function getTotalSupply() external view returns (uint256) {
        return totalSupply;
    }

    /**
     * @notice Increment `_acct` balance by `_val`
     * @param _acct Target account to increment balance.
     * @param _val Value to increment
     * @return Operation status
     */
    function incBalance(address _acct, uint _val) public onlyModule returns (bool) {
        balances[_acct] = balances[_acct].add(_val);
        emit BalanceAdj(msg.sender, _acct, _val, "+");
        return true;
    }

    /**
     * @notice Decrement `_acct` balance by `_val`
     * @param _acct Target account to decrement balance.
     * @param _val Value to decrement
     * @return Operation status
     */
    function decBalance(address _acct, uint _val) public onlyModule returns (bool) {
        balances[_acct] = balances[_acct].sub(_val);
        emit BalanceAdj(msg.sender, _acct, _val, "-");
        return true;
    }

    function transferRoot(address _new) external returns (bool) {
        return false;
    }
}


/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */
pragma solidity 0.5.8;

import { ERC1820Client } from "./ERC1820Client.sol";
import { SafeMath } from "./SafeMath.sol";
import { IERC777 } from "./IERC777.sol";
import { IERC777TokensSender } from "./IERC777TokensSender.sol";
import { IERC777TokensRecipient } from "./IERC777TokensRecipient.sol";


contract ERC777 is IERC777, ERC1820Client {
    using SafeMath for uint256;

    string internal mName;
    string internal mSymbol;
    uint256 internal mGranularity;
    uint256 internal mTotalSupply;


    mapping(address => uint) internal mBalances;

    address[] internal mDefaultOperators;
    mapping(address => bool) internal mIsDefaultOperator;
    mapping(address => mapping(address => bool)) internal mRevokedDefaultOperator;
    mapping(address => mapping(address => bool)) internal mAuthorizedOperators;

    /* -- Constructor -- */
    //
    /// @notice Constructor to create a ReferenceToken
    /// @param _name Name of the new token
    /// @param _symbol Symbol of the new token.
    /// @param _granularity Minimum transferable chunk.
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _granularity,
        address[] memory _defaultOperators
    ) internal {
        mName = _name;
        mSymbol = _symbol;
        mTotalSupply = 0;
        require(_granularity >= 1, "Granularity must be > 1");
        mGranularity = _granularity;

        mDefaultOperators = _defaultOperators;
        for (uint256 i = 0; i < mDefaultOperators.length; i++) { mIsDefaultOperator[mDefaultOperators[i]] = true; }

        setInterfaceImplementation("ERC777Token", address(this));
    }

    /* -- ERC777 Interface Implementation -- */
    //
    /// @return the name of the token
    function name() public view returns (string memory) { return mName; }

    /// @return the symbol of the token
    function symbol() public view returns (string memory) { return mSymbol; }

    /// @return the granularity of the token
    function granularity() public view returns (uint256) { return mGranularity; }

    /// @return the total supply of the token
    function totalSupply() public view returns (uint256) { return mTotalSupply; }

    /// @notice Return the account balance of some account
    /// @param _tokenHolder Address for which the balance is returned
    /// @return the balance of `_tokenAddress`.
    function balanceOf(address _tokenHolder) public view returns (uint256) { return mBalances[_tokenHolder]; }

    /// @notice Return the list of default operators
    /// @return the list of all the default operators
    function defaultOperators() public view returns (address[] memory) { return mDefaultOperators; }

    /// @notice Send `_amount` of tokens to address `_to` passing `_data` to the recipient
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be sent
    function send(address _to, uint256 _amount, bytes calldata _data) external {
        doSend(msg.sender, msg.sender, _to, _amount, _data, "", true);
    }

    /// @notice Authorize a third party `_operator` to manage (send) `msg.sender`'s tokens.
    /// @param _operator The operator that wants to be Authorized
    function authorizeOperator(address _operator) external {
        require(_operator != msg.sender, "Cannot authorize yourself as an operator");
        if (mIsDefaultOperator[_operator]) {
            mRevokedDefaultOperator[_operator][msg.sender] = false;
        } else {
            mAuthorizedOperators[_operator][msg.sender] = true;
        }
        emit AuthorizedOperator(_operator, msg.sender);
    }

    /// @notice Revoke a third party `_operator`'s rights to manage (send) `msg.sender`'s tokens.
    /// @param _operator The operator that wants to be Revoked
    function revokeOperator(address _operator) external {
        require(_operator != msg.sender, "Cannot revoke yourself as an operator");
        if (mIsDefaultOperator[_operator]) {
            mRevokedDefaultOperator[_operator][msg.sender] = true;
        } else {
            mAuthorizedOperators[_operator][msg.sender] = false;
        }
        emit RevokedOperator(_operator, msg.sender);
    }

    /// @notice Check whether the `_operator` address is allowed to manage the tokens held by `_tokenHolder` address.
    /// @param _operator address to check if it has the right to manage the tokens
    /// @param _tokenHolder address which holds the tokens to be managed
    /// @return `true` if `_operator` is authorized for `_tokenHolder`
    function isOperatorFor(address _operator, address _tokenHolder) public view returns (bool) {
        return (_operator == _tokenHolder // solium-disable-line operator-whitespace
        || mAuthorizedOperators[_operator][_tokenHolder]
        || (mIsDefaultOperator[_operator] && !mRevokedDefaultOperator[_operator][_tokenHolder]));
    }

    /// @notice Send `_amount` of tokens on behalf of the address `from` to the address `to`.
    /// @param _from The address holding the tokens being sent
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be sent
    /// @param _data Data generated by the user to be sent to the recipient
    /// @param _operatorData Data generated by the operator to be sent to the recipient
    function operatorSend(
        address _from,
        address _to,
        uint256 _amount,
        bytes calldata _data,
        bytes calldata _operatorData
    )
    external
    {
        require(isOperatorFor(msg.sender, _from), "Not an operator.");
        doSend(msg.sender, _from, _to, _amount, _data, _operatorData, true);
    }

    function burn(uint256 _amount, bytes calldata _data) external {
        doBurn(msg.sender, msg.sender, _amount, _data, "");
    }

    function operatorBurn(
        address _tokenHolder,
        uint256 _amount,
        bytes calldata _data,
        bytes calldata _operatorData
    )
    external
    {
        require(isOperatorFor(msg.sender, _tokenHolder), "Not an operator");
        doBurn(msg.sender, _tokenHolder, _amount, _data, _operatorData);
    }

    /* -- Helper Functions -- */
    //
    /// @notice Internal function that ensures `_amount` is multiple of the granularity
    /// @param _amount The quantity that want's to be checked
    function requireMultiple(uint256 _amount) internal view {
        require(_amount % mGranularity == 0, "Amount is not a multiple of granularity");
    }

    /// @notice Check whether an address is a regular address or not.
    /// @param _addr Address of the contract that has to be checked
    /// @return `true` if `_addr` is a regular address (not a contract)
    function isRegularAddress(address _addr) internal view returns(bool) {
        if (_addr == address(0)) { return false; }
        uint size;
        assembly { size := extcodesize(_addr) } // solium-disable-line security/no-inline-assembly
        return size == 0;
    }

    /// @notice Helper function actually performing the sending of tokens.
    /// @param _operator The address performing the send
    /// @param _from The address holding the tokens being sent
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be sent
    /// @param _data Data generated by the user to be passed to the recipient
    /// @param _operatorData Data generated by the operator to be passed to the recipient
    /// @param _preventLocking `true` if you want this function to throw when tokens are sent to a contract not
    ///  implementing `ERC777tokensRecipient`.
    ///  ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
    ///  functions SHOULD set this parameter to `false`.
    function doSend(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData,
        bool _preventLocking
    )
    internal
    {
        requireMultiple(_amount);

        callSender(_operator, _from, _to, _amount, _data, _operatorData);

        require(_to != address(0), "Cannot send to 0x0");
        require(mBalances[_from] >= _amount, "Not enough funds");

        mBalances[_from] = mBalances[_from].sub(_amount);
        mBalances[_to] = mBalances[_to].add(_amount);

        callRecipient(_operator, _from, _to, _amount, _data, _operatorData, _preventLocking);

        emit Sent(_operator, _from, _to, _amount, _data, _operatorData);
    }

    /// @notice Helper function actually performing the burning of tokens.
    /// @param _operator The address performing the burn
    /// @param _tokenHolder The address holding the tokens being burn
    /// @param _amount The number of tokens to be burnt
    /// @param _data Data generated by the token holder
    /// @param _operatorData Data generated by the operator
    function doBurn(
        address _operator,
        address _tokenHolder,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData
    )
    internal
    {
        callSender(_operator, _tokenHolder, address(0), _amount, _data, _operatorData);

        requireMultiple(_amount);
        require(balanceOf(_tokenHolder) >= _amount, "Not enough funds");

        mBalances[_tokenHolder] = mBalances[_tokenHolder].sub(_amount);
        mTotalSupply = mTotalSupply.sub(_amount);

        emit Burned(_operator, _tokenHolder, _amount, _data, _operatorData);
    }

    /// @notice Helper function that checks for ERC777TokensRecipient on the recipient and calls it.
    ///  May throw according to `_preventLocking`
    /// @param _operator The address performing the send or mint
    /// @param _from The address holding the tokens being sent
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be sent
    /// @param _data Data generated by the user to be passed to the recipient
    /// @param _operatorData Data generated by the operator to be passed to the recipient
    /// @param _preventLocking `true` if you want this function to throw when tokens are sent to a contract not
    ///  implementing `ERC777TokensRecipient`.
    ///  ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
    ///  functions SHOULD set this parameter to `false`.
    function callRecipient(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData,
        bool _preventLocking
    )
    internal
    {
        address recipientImplementation = interfaceAddr(_to, "ERC777TokensRecipient");
        if (recipientImplementation != address(0)) {
            IERC777TokensRecipient(recipientImplementation).tokensReceived(
                _operator, _from, _to, _amount, _data, _operatorData);
        } else if (_preventLocking) {
            require(isRegularAddress(_to), "Cannot send to contract without ERC777TokensRecipient");
        }
    }

    /// @notice Helper function that checks for ERC777TokensSender on the sender and calls it.
    ///  May throw according to `_preventLocking`
    /// @param _from The address holding the tokens being sent
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be sent
    /// @param _data Data generated by the user to be passed to the recipient
    /// @param _operatorData Data generated by the operator to be passed to the recipient
    ///  implementing `ERC777TokensSender`.
    ///  ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
    ///  functions SHOULD set this parameter to `false`.
    function callSender(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData
    )
    internal
    {
        address senderImplementation = interfaceAddr(_from, "ERC777TokensSender");
        if (senderImplementation == address(0)) { return; }
        IERC777TokensSender(senderImplementation).tokensToSend(
            _operator, _from, _to, _amount, _data, _operatorData);
    }
}


/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
pragma solidity 0.5.8;


import { IERC20 } from "./IERC20.sol";
import { ERC777RemoteBridge } from "./ERC777RemoteBridge.sol";


contract ERC777ERC20Compat is IERC20, ERC777RemoteBridge {
    bool internal mErc20compatible;

    mapping(address => mapping(address => uint256)) internal mAllowed;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _granularity,
        uint256 _totalSupply,
        address _initialOwner,
        address[] memory _defaultOperators
    )
    internal ERC777RemoteBridge(_name, _symbol, _granularity, _totalSupply, _initialOwner, _defaultOperators)
    {
        mErc20compatible = true;
        setInterfaceImplementation("ERC20Token", address(this));
    }

    /// @notice This modifier is applied to erc20 obsolete methods that are
    ///  implemented only to maintain backwards compatibility. When the erc20
    ///  compatibility is disabled, this methods will fail.
    modifier erc20 () {
        require(mErc20compatible, "ERC20 is disabled");
        _;
    }

    /// @notice For Backwards compatibility
    /// @return The decimals of the token. Forced to 18 in ERC777.
    function decimals() public erc20 view returns (uint8) { return uint8(18); }

    /// @notice ERC20 backwards compatible transfer.
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be transferred
    /// @return `true`, if the transfer can't be done, it should fail.
    function transfer(address _to, uint256 _amount) public erc20 returns (bool success) {
        doSend(msg.sender, msg.sender, _to, _amount, "", "", false);
        return true;
    }

    /// @notice ERC20 backwards compatible transferFrom.
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be transferred
    /// @return `true`, if the transfer can't be done, it should fail.
    function transferFrom(address _from, address _to, uint256 _amount) public erc20 returns (bool success) {
        uint256 allowance = balancesDB.getAllowance(_from, msg.sender);
        require(_amount <= allowance, "Not enough allowance.");

        // Cannot be after doSend because of tokensReceived re-entry
        require(balancesDB.decApprove(_from, msg.sender, _amount));
        doSend(msg.sender, _from, _to, _amount, "", "", false);
        return true;
    }

    /// @notice ERC20 backwards compatible approve.
    ///  `msg.sender` approves `_spender` to spend `_amount` tokens on its behalf.
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _amount The number of tokens to be approved for transfer
    /// @return `true`, if the approve can't be done, it should fail.
    function approve(address _spender, uint256 _amount) public erc20 returns (bool success) {
        require(balancesDB.setApprove(msg.sender, _spender, _amount));
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    /// @notice ERC20 backwards compatible allowance.
    ///  This function makes it easy to read the `allowed[]` map
    /// @param _owner The address of the account that owns the token
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens of _owner that _spender is allowed
    ///  to spend
    function allowance(address _owner, address _spender) public erc20 view returns (uint256 remaining) {
        return balancesDB.getAllowance(_owner, _spender);
    }

    function doSend(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData,
        bool _preventLocking
    )
    internal
    {
        super.doSend(_operator, _from, _to, _amount, _data, _operatorData, _preventLocking);
        if (mErc20compatible) { emit Transfer(_from, _to, _amount); }
    }

    function doBurn(
        address _operator,
        address _tokenHolder,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData
    )
    internal
    {
        super.doBurn(_operator, _tokenHolder, _amount, _data, _operatorData);
        if (mErc20compatible) { emit Transfer(_tokenHolder, address(0), _amount); }
    }
}


/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
pragma solidity 0.5.8;


import { ERC777 } from "./ERC777.sol";
import { CStore } from "./CStore.sol";


contract ERC777RemoteBridge is ERC777 {

    CStore public balancesDB;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _granularity,
        uint256 _totalSupply,
        address _initialOwner,
        address[] memory _defaultOperators
    )
    public ERC777(_name, _symbol, _granularity, new address[](0))
    {
        balancesDB = new CStore(_totalSupply, _initialOwner, _defaultOperators);
    }

    /**
     * @return the total supply of the token
     */
    function totalSupply() public view returns (uint256) {
        return balancesDB.getTotalSupply();
    }

    /**
     * @notice Return the account balance of some account
     * @param _tokenHolder Address for which the balance is returned
     * @return the balance of `_tokenAddress`.
     */
    function balanceOf(address _tokenHolder) public view returns (uint256) {
        return balancesDB.getBalance(_tokenHolder);
    }

    /**
     * @notice Return the list of default operators
     * @return the list of all the default operators
     */
    function defaultOperators() public view returns (address[] memory) {
        return balancesDB.getDefaultOperators();
    }

    /**
     * @notice Authorize a third party `_operator` to manage (send) `msg.sender`'s tokens at remote database.
     * @param _operator The operator that wants to be Authorized
     */
    function authorizeOperator(address _operator) external {
        require(_operator != msg.sender, "Cannot authorize yourself as an operator");
        if (balancesDB.getDefaultOperator(_operator)) {
            require(balancesDB.setRevokedDefaultOperator(_operator, msg.sender, false));
        } else {
            require(balancesDB.setAuthorizedOperator(_operator, msg.sender, true));
        }
        emit AuthorizedOperator(_operator, msg.sender);
    }

    /**
     * @notice Revoke a third party `_operator`'s rights to manage (send) `msg.sender`'s tokens at remote database.
     * @param _operator The operator that wants to be Revoked
     */
    function revokeOperator(address _operator) external {
        require(_operator != msg.sender, "Cannot revoke yourself as an operator");
        if (balancesDB.getDefaultOperator(_operator)) {
            require(balancesDB.setRevokedDefaultOperator(_operator, msg.sender, true));
        } else {
            require(balancesDB.setAuthorizedOperator(_operator, msg.sender, false));
        }
        emit RevokedOperator(_operator, msg.sender);
    }

    /**
    * @notice Check whether the `_operator` address is allowed to manage the tokens held by `_tokenHolder`
    *  address at remote database.
    * @param _operator address to check if it has the right to manage the tokens
    * @param _tokenHolder address which holds the tokens to be managed
    * @return `true` if `_operator` is authorized for `_tokenHolder`
    */
    function isOperatorFor(address _operator, address _tokenHolder) public view returns (bool) {
        return _operator == _tokenHolder || balancesDB.getAuthorizedOperator(_operator, _tokenHolder);
        return (_operator == _tokenHolder // solium-disable-line operator-whitespace
        || balancesDB.getAuthorizedOperator(_operator, _tokenHolder)
        || (balancesDB.getDefaultOperator(_operator) && !balancesDB.getRevokedDefaultOperator(_operator, _tokenHolder)));
    }

    /**
     * @notice Helper function actually performing the sending of tokens using a backend database.
     * @param _from The address holding the tokens being sent
     * @param _to The address of the recipient
     * @param _amount The number of tokens to be sent
     * @param _data Data generated by the user to be passed to the recipient
     * @param _operatorData Data generated by the operator to be passed to the recipient
     * @param _preventLocking `true` if you want this function to throw when tokens are sent to a contract not
     *  implementing `erc777_tokenHolder`.
     *  ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
     *  functions SHOULD set this parameter to `false`.
     */
    function doSend(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData,
        bool _preventLocking
    )
    internal
    {
        requireMultiple(_amount);

        callSender(_operator, _from, _to, _amount, _data, _operatorData);

        require(_to != address(0), "Cannot send to 0x0");          // forbid sending to 0x0 (=burning)
        // require(mBalances[_from] >= _amount); // ensure enough funds
        // (Not Required due to SafeMath throw if underflow in database and false check)

        require(balancesDB.move(_from, _to, _amount));

        callRecipient(_operator, _from, _to, _amount, _data, _operatorData, _preventLocking);

        emit Sent(_operator, _from, _to, _amount, _data, _operatorData);
        //if (mErc20compatible) { emit Transfer(_from, _to, _amount); }
    }

    /**
     * @notice Helper function actually performing the burning of tokens.
     * @param _operator The address performing the burn
     * @param _tokenHolder The address holding the tokens being burn
     * @param _amount The number of tokens to be burnt
     * @param _data Data generated by the token holder
     * @param _operatorData Data generated by the operator
     */
    function doBurn(
        address _operator,
        address _tokenHolder,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData
    )
    internal
    {
        revert("Burning functionality is disabled.");
    }
}


pragma solidity ^0.5.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
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

pragma solidity 0.5.8;


interface IERC644 {
    function getBalance(address _acct) external view returns(uint);
    function incBalance(address _acct, uint _val) external returns(bool);
    function decBalance(address _acct, uint _val) external returns(bool);
    function getAllowance(address _owner, address _spender) external view returns(uint);
    function setApprove(address _sender, address _spender, uint256 _value) external returns(bool);
    function decApprove(address _from, address _spender, uint _value) external returns(bool);
    function getModule(address _acct) external view returns (bool);
    function setModule(address _acct, bool _set) external returns(bool);
    function getTotalSupply() external view returns(uint);
    function incTotalSupply(uint _val) external returns(bool);
    function decTotalSupply(uint _val) external returns(bool);
    function transferRoot(address _new) external returns(bool);

    event BalanceAdj(address indexed Module, address indexed Account, uint Amount, string Polarity);
    event ModuleSet(address indexed Module, bool indexed Set);
}


/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
// solhint-disable-next-line compiler-fixed
pragma solidity 0.5.8;


interface IERC777 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function granularity() external view returns (uint256);

    function defaultOperators() external view returns (address[] memory);
    function isOperatorFor(address operator, address tokenHolder) external view returns (bool);
    function authorizeOperator(address operator) external;
    function revokeOperator(address operator) external;

    function send(address to, uint256 amount, bytes calldata data) external;
    function operatorSend(
        address from,
        address to,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;

    function burn(uint256 amount, bytes calldata data) external;
    function operatorBurn(address from, uint256 amount, bytes calldata data, bytes calldata operatorData) external;

    event Sent(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );
    event Minted(address indexed operator, address indexed to, uint256 amount, bytes data, bytes operatorData);
    event Burned(address indexed operator, address indexed from, uint256 amount, bytes data, bytes operatorData);
    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    event RevokedOperator(address indexed operator, address indexed tokenHolder);
}


/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
// solhint-disable-next-line compiler-fixed
pragma solidity 0.5.8;


interface IERC777TokensRecipient {
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;
}


/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
// solhint-disable-next-line compiler-fixed
pragma solidity 0.5.8;


interface IERC777TokensSender {
    function tokensToSend(
        address operator,
        address from,
        address to,
        uint amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;
}


pragma solidity ^0.5.0;

import "./Context.sol";
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
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
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

pragma solidity 0.5.8;

import "./Ownable.sol";


/**
 * @title Safe Guard Contract
 * @author Panos
 */
contract SafeGuard is Ownable {

    event Transaction(address indexed destination, uint value, bytes data);

    /**
     * @dev Allows owner to execute a transaction.
     */
    function executeTransaction(address destination, uint value, bytes memory data)
    public
    onlyOwner
    {
        require(externalCall(destination, value, data.length, data));
        emit Transaction(destination, value, data);
    }

    /**
     * @dev call has been separated into its own function in order to take advantage
     *  of the Solidity's code generator to produce a loop that copies tx.data into memory.
     */
    function externalCall(address destination, uint value, uint dataLength, bytes memory data)
    private
    returns (bool) {
        bool result;
        assembly { // solhint-disable-line no-inline-assembly
        let x := mload(0x40)   // "Allocate" memory for output
            // (0x40 is where "free memory" pointer is stored by convention)
            let d := add(data, 32) // First 32 bytes are the padded length of data, so exclude that
            result := call(
            sub(gas, 34710), // 34710 is the value that solidity is currently emitting
            // It includes callGas (700) + callVeryLow (3, to pay for SUB) + callValueTransferGas (9000) +
            // callNewAccountGas (25000, in case the destination address does not exist and needs creating)
            destination,
            value,
            d,
            dataLength, // Size of the input (in bytes) - this is what fixes the padding problem
            x,
            0                  // Output is ignored, therefore the output size is zero
            )
        }
        return result;
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

pragma solidity 0.5.8;

import "./ERC777ERC20Compat.sol";
import "./SafeGuard.sol";
import { CStore } from "./CStore.sol"; //TODO: Convert all imports like this

contract CALL is ERC777ERC20Compat, SafeGuard {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _granularity,
        uint256 _totalSupply,
        address _initialOwner,
        address[] memory _defaultOperators
    )
    public ERC777ERC20Compat(_name, _symbol, _granularity, _totalSupply, _initialOwner, _defaultOperators)
    {
        requireMultiple(_totalSupply);
        require(balancesDB.setModule(address(this), true), "Cannot enable access to the database.");
        balancesDB.transferOwnership(_initialOwner);

        callRecipient(msg.sender, address(0), _initialOwner, _totalSupply, "", "", true);

        emit Minted(msg.sender, _initialOwner, _totalSupply, "", "");
        if (mErc20compatible) { emit Transfer(address(0), _initialOwner, _totalSupply); }
    }

    /**
     * @notice change the balances database to `_newDB`
     * @param _newDB The new balances database address
     */
    function changeBalancesDB(address _newDB) public onlyOwner {
        balancesDB = CStore(_newDB);
    }

    /**
     * @notice Disables the ERC20 interface. This function can only be called
     * by the owner.
     */
    function disableERC20() public onlyOwner {
        mErc20compatible = false;
        setInterfaceImplementation("ERC20Token", address(0));
    }

    /**
     * @notice Re enables the ERC20 interface. This function can only be called
     *  by the owner.
     */
    function enableERC20() public onlyOwner {
        mErc20compatible = true;
        setInterfaceImplementation("ERC20Token", address(this));
    }

    /**
     * @dev Transfer the specified amounts of tokens to the specified addresses.
     * @dev Be aware that there is no check for duplicate recipients.
     * @param _toAddresses Receiver addresses.
     * @param _amounts Amounts of tokens that will be transferred.
     */
    function multiPartyTransfer(address[] calldata _toAddresses, uint256[] calldata _amounts) external erc20 {
        /* Ensures _toAddresses array is less than or equal to 255 */
        require(_toAddresses.length <= 255, "Unsupported number of addresses.");
        /* Ensures _toAddress and _amounts have the same number of entries. */
        require(_toAddresses.length == _amounts.length, "Provided addresses does not equal to provided sums.");

        for (uint8 i = 0; i < _toAddresses.length; i++) {
            transfer(_toAddresses[i], _amounts[i]);
        }
    }

    /**
    * @dev Transfer the specified amounts of tokens to the specified addresses from authorized balance of sender.
    * @dev Be aware that there is no check for duplicate recipients.
    * @param _from The address of the sender
    * @param _toAddresses The addresses of the recipients (MAX 255)
    * @param _amounts The amounts of tokens to be transferred
    */
    function multiPartyTransferFrom(address _from, address[] calldata _toAddresses, uint256[] calldata _amounts) external erc20 {
        /* Ensures _toAddresses array is less than or equal to 255 */
        require(_toAddresses.length <= 255, "Unsupported number of addresses.");
        /* Ensures _toAddress and _amounts have the same number of entries. */
        require(_toAddresses.length == _amounts.length, "Provided addresses does not equal to provided sums.");

        for (uint8 i = 0; i < _toAddresses.length; i++) {
            transferFrom(_from, _toAddresses[i], _amounts[i]);
        }
    }

    /**
     * @dev Transfer the specified amounts of tokens to the specified addresses.
     * @dev Be aware that there is no check for duplicate recipients.
     * @param _toAddresses Receiver addresses.
     * @param _amounts Amounts of tokens that will be transferred.
     * @param _userData User supplied data
     */
    function multiPartySend(address[] memory _toAddresses, uint256[] memory _amounts, bytes memory _userData) public {
        /* Ensures _toAddresses array is less than or equal to 255 */
        require(_toAddresses.length <= 255, "Unsupported number of addresses.");
        /* Ensures _toAddress and _amounts have the same number of entries. */
        require(_toAddresses.length == _amounts.length, "Provided addresses does not equal to provided sums.");

        for (uint8 i = 0; i < _toAddresses.length; i++) {
            doSend(msg.sender,  msg.sender, _toAddresses[i], _amounts[i], _userData, "", true);
        }
    }

    /**
    * @dev Transfer the specified amounts of tokens to the specified addresses as `_from`.
    * @dev Be aware that there is no check for duplicate recipients.
    * @param _from Address to use as sender
    * @param _to Receiver addresses.
    * @param _amounts Amounts of tokens that will be transferred.
    * @param _userData User supplied data
    * @param _operatorData Operator supplied data
    */
    function multiOperatorSend(address _from, address[] calldata _to, uint256[] calldata _amounts, bytes calldata _userData, bytes calldata _operatorData)
    external {
        /* Ensures _toAddresses array is less than or equal to 255 */
        require(_to.length <= 255, "Unsupported number of addresses.");
        /* Ensures _toAddress and _amounts have the same number of entries. */
        require(_to.length == _amounts.length, "Provided addresses does not equal to provided sums.");

        for (uint8 i = 0; i < _to.length; i++) {
            require(isOperatorFor(msg.sender, _from), "Not an operator"); //TODO check for denial of service
            doSend(msg.sender, _from, _to[i], _amounts[i], _userData, _operatorData, true);
        }
    }
}


pragma solidity ^0.5.0;

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
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () internal { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

pragma solidity 0.5.8;

import "./ERC644Balances.sol";
import { ERC1820Client } from "./ERC1820Client.sol";


/**
 * @title ERC644 Database Contract
 * @author Panos
 */
contract CStore is ERC644Balances, ERC1820Client {

    address[] internal mDefaultOperators;
    mapping(address => bool) internal mIsDefaultOperator;
    mapping(address => mapping(address => bool)) internal mRevokedDefaultOperator;
    mapping(address => mapping(address => bool)) internal mAuthorizedOperators;

    /**
     * @notice Database construction
     * @param _totalSupply The total supply of the token
     */
    constructor(uint256 _totalSupply, address _initialOwner, address[] memory _defaultOperators) public
    {
        balances[_initialOwner] = _totalSupply;
        totalSupply = _totalSupply;
        mDefaultOperators = _defaultOperators;
        for (uint256 i = 0; i < mDefaultOperators.length; i++) { mIsDefaultOperator[mDefaultOperators[i]] = true; }

        setInterfaceImplementation("ERC644Balances", address(this));
    }

    /**
     * @notice Increase total supply by `_val`
     * @param _val Value to increase
     * @return Operation status
     */
    // solhint-disable-next-line no-unused-vars
    function incTotalSupply(uint _val) external onlyModule returns (bool) {
        return false;
    }

    /**
     * @notice Decrease total supply by `_val`
     * @param _val Value to decrease
     * @return Operation status
     */
     // solhint-disable-next-line no-unused-vars
     function decTotalSupply(uint _val) external onlyModule returns (bool) {
         return false;
     }

    /**
     * @notice moving `_amount` from `_from` to `_to`
     * @param _from The sender address
     * @param _to The receiving address
     * @param _amount The moving amount
     * @return bool The move result
     */
    function move(address _from, address _to, uint256 _amount) external
    onlyModule
    returns (bool) {
        balances[_from] = balances[_from].sub(_amount);
        emit BalanceAdj(msg.sender, _from, _amount, "-");
        balances[_to] = balances[_to].add(_amount);
        emit BalanceAdj(msg.sender, _to, _amount, "+");
        return true;
    }

    /**
     * @notice Setting operator `_operator` for `_tokenHolder`
     * @param _operator The operator to set status
     * @param _tokenHolder The token holder to set operator
     * @param _status The operator status
     * @return bool Status of operation
     */
    function setAuthorizedOperator(address _operator, address _tokenHolder, bool _status) external
    onlyModule
    returns (bool) {
        mAuthorizedOperators[_operator][_tokenHolder] = _status;
        return true;
    }

    /**
     * @notice Set revoke status for default operator `_operator` for `_tokenHolder`
     * @param _operator The default operator to set status
     * @param _tokenHolder The token holder to set operator
     * @param _status The operator status
     * @return bool Status of operation
     */
    function setRevokedDefaultOperator(address _operator, address _tokenHolder, bool _status) external
    onlyModule
    returns (bool) {
    mRevokedDefaultOperator[_operator][_tokenHolder] = _status;
        return true;
    }

    /**
     * @notice Getting operator `_operator` for `_tokenHolder`
     * @param _operator The operator address to get status
     * @param _tokenHolder The token holder address
     * @return bool Operator status
     */
    function getAuthorizedOperator(address _operator, address _tokenHolder) external
    view
    returns (bool) {
        return mAuthorizedOperators[_operator][_tokenHolder];
    }

    /**
     * @notice Getting default operator `_operator`
     * @param _operator The default operator address to get status
     * @return bool Default operator status
     */
    function getDefaultOperator(address _operator) external view returns (bool) {
        return mIsDefaultOperator[_operator];
    }

    /**
     * @notice Getting default operators
     * @return address[] Default operator addresses
     */
    function getDefaultOperators() external view returns (address[] memory) {
        return mDefaultOperators;
    }

    function getRevokedDefaultOperator(address _operator, address _tokenHolder) external view returns (bool) {
        return mRevokedDefaultOperator[_operator][_tokenHolder];
    }

    /**
     * @notice Increment `_acct` balance by `_val`
     * @param _acct Target account to increment balance.
     * @param _val Value to increment
     * @return Operation status
     */
    // solhint-disable-next-line no-unused-vars
    function incBalance(address _acct, uint _val) public onlyModule returns (bool) {
        return false;
    }

    /**
     * @notice Decrement `_acct` balance by `_val`
     * @param _acct Target account to decrement balance.
     * @param _val Value to decrement
     * @return Operation status
     */
     // solhint-disable-next-line no-unused-vars
     function decBalance(address _acct, uint _val) public onlyModule returns (bool) {
         return false;
     }
}


pragma solidity ^0.5.3;


contract ERC1820Registry {
    function setInterfaceImplementer(address _addr, bytes32 _interfaceHash, address _implementer) external;
    function getInterfaceImplementer(address _addr, bytes32 _interfaceHash) external view returns (address);
    function setManager(address _addr, address _newManager) external;
    function getManager(address _addr) public view returns (address);
}


/// Base client to interact with the registry.
contract ERC1820Client {
    ERC1820Registry constant ERC1820REGISTRY = ERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    function setInterfaceImplementation(string memory _interfaceLabel, address _implementation) internal {
        bytes32 interfaceHash = keccak256(abi.encodePacked(_interfaceLabel));
        ERC1820REGISTRY.setInterfaceImplementer(address(this), interfaceHash, _implementation);
    }

    function interfaceAddr(address addr, string memory _interfaceLabel) internal view returns(address) {
        bytes32 interfaceHash = keccak256(abi.encodePacked(_interfaceLabel));
        return ERC1820REGISTRY.getInterfaceImplementer(addr, interfaceHash);
    }

    function delegateManagement(address _newManager) internal {
        ERC1820REGISTRY.setManager(address(this), _newManager);
    }
}

pragma solidity 0.5.8;

import "./SafeMath.sol";
import "./SafeGuard.sol";
import "./IERC644.sol";


/**
 * @title ERC644 Standard Balances Contract
 * @author chrisfranko
 */
contract ERC644Balances is IERC644, SafeGuard {
    using SafeMath for uint256;

    uint256 public totalSupply;

    event BalanceAdj(address indexed module, address indexed account, uint amount, string polarity);
    event ModuleSet(address indexed module, bool indexed set);

    mapping(address => bool) public modules;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowed;

    modifier onlyModule() {
        require(modules[msg.sender], "ERC644Balances: caller is not a module");
        _;
    }

    /**
     * @notice Set allowance of `_spender` in behalf of `_sender` at `_value`
     * @param _sender Owner account
     * @param _spender Spender account
     * @param _value Value to approve
     * @return Operation status
     */
    function setApprove(address _sender, address _spender, uint256 _value) external onlyModule returns (bool) {
        allowed[_sender][_spender] = _value;
        return true;
    }

    /**
     * @notice Decrease allowance of `_spender` in behalf of `_from` at `_value`
     * @param _from Owner account
     * @param _spender Spender account
     * @param _value Value to decrease
     * @return Operation status
     */
    function decApprove(address _from, address _spender, uint _value) external onlyModule returns (bool) {
        allowed[_from][_spender] = allowed[_from][_spender].sub(_value);
        return true;
    }

    /**
    * @notice Increase total supply by `_val`
    * @param _val Value to increase
    * @return Operation status
    */
    function incTotalSupply(uint _val) external onlyModule returns (bool) {
        totalSupply = totalSupply.add(_val);
        return true;
    }

    /**
     * @notice Decrease total supply by `_val`
     * @param _val Value to decrease
     * @return Operation status
     */
    function decTotalSupply(uint _val) external onlyModule returns (bool) {
        totalSupply = totalSupply.sub(_val);
        return true;
    }

    /**
     * @notice Set/Unset `_acct` as an authorized module
     * @param _acct Module address
     * @param _set Module set status
     * @return Operation status
     */
    function setModule(address _acct, bool _set) external onlyOwner returns (bool) {
        modules[_acct] = _set;
        emit ModuleSet(_acct, _set);
        return true;
    }

    /**
     * @notice Get `_acct` balance
     * @param _acct Target account to get balance.
     * @return The account balance
     */
    function getBalance(address _acct) external view returns (uint256) {
        return balances[_acct];
    }

    /**
     * @notice Get allowance of `_spender` in behalf of `_owner`
     * @param _owner Owner account
     * @param _spender Spender account
     * @return Allowance
     */
    function getAllowance(address _owner, address _spender) external view returns (uint256) {
        return allowed[_owner][_spender];
    }

    /**
     * @notice Get if `_acct` is an authorized module
     * @param _acct Module address
     * @return Operation status
     */
    function getModule(address _acct) external view returns (bool) {
        return modules[_acct];
    }

    /**
     * @notice Get total supply
     * @return Total supply
     */
    function getTotalSupply() external view returns (uint256) {
        return totalSupply;
    }

    /**
     * @notice Increment `_acct` balance by `_val`
     * @param _acct Target account to increment balance.
     * @param _val Value to increment
     * @return Operation status
     */
    function incBalance(address _acct, uint _val) public onlyModule returns (bool) {
        balances[_acct] = balances[_acct].add(_val);
        emit BalanceAdj(msg.sender, _acct, _val, "+");
        return true;
    }

    /**
     * @notice Decrement `_acct` balance by `_val`
     * @param _acct Target account to decrement balance.
     * @param _val Value to decrement
     * @return Operation status
     */
    function decBalance(address _acct, uint _val) public onlyModule returns (bool) {
        balances[_acct] = balances[_acct].sub(_val);
        emit BalanceAdj(msg.sender, _acct, _val, "-");
        return true;
    }

    function transferRoot(address _new) external returns (bool) {
        return false;
    }
}


/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */
pragma solidity 0.5.8;

import { ERC1820Client } from "./ERC1820Client.sol";
import { SafeMath } from "./SafeMath.sol";
import { IERC777 } from "./IERC777.sol";
import { IERC777TokensSender } from "./IERC777TokensSender.sol";
import { IERC777TokensRecipient } from "./IERC777TokensRecipient.sol";


contract ERC777 is IERC777, ERC1820Client {
    using SafeMath for uint256;

    string internal mName;
    string internal mSymbol;
    uint256 internal mGranularity;
    uint256 internal mTotalSupply;


    mapping(address => uint) internal mBalances;

    address[] internal mDefaultOperators;
    mapping(address => bool) internal mIsDefaultOperator;
    mapping(address => mapping(address => bool)) internal mRevokedDefaultOperator;
    mapping(address => mapping(address => bool)) internal mAuthorizedOperators;

    /* -- Constructor -- */
    //
    /// @notice Constructor to create a ReferenceToken
    /// @param _name Name of the new token
    /// @param _symbol Symbol of the new token.
    /// @param _granularity Minimum transferable chunk.
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _granularity,
        address[] memory _defaultOperators
    ) internal {
        mName = _name;
        mSymbol = _symbol;
        mTotalSupply = 0;
        require(_granularity >= 1, "Granularity must be > 1");
        mGranularity = _granularity;

        mDefaultOperators = _defaultOperators;
        for (uint256 i = 0; i < mDefaultOperators.length; i++) { mIsDefaultOperator[mDefaultOperators[i]] = true; }

        setInterfaceImplementation("ERC777Token", address(this));
    }

    /* -- ERC777 Interface Implementation -- */
    //
    /// @return the name of the token
    function name() public view returns (string memory) { return mName; }

    /// @return the symbol of the token
    function symbol() public view returns (string memory) { return mSymbol; }

    /// @return the granularity of the token
    function granularity() public view returns (uint256) { return mGranularity; }

    /// @return the total supply of the token
    function totalSupply() public view returns (uint256) { return mTotalSupply; }

    /// @notice Return the account balance of some account
    /// @param _tokenHolder Address for which the balance is returned
    /// @return the balance of `_tokenAddress`.
    function balanceOf(address _tokenHolder) public view returns (uint256) { return mBalances[_tokenHolder]; }

    /// @notice Return the list of default operators
    /// @return the list of all the default operators
    function defaultOperators() public view returns (address[] memory) { return mDefaultOperators; }

    /// @notice Send `_amount` of tokens to address `_to` passing `_data` to the recipient
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be sent
    function send(address _to, uint256 _amount, bytes calldata _data) external {
        doSend(msg.sender, msg.sender, _to, _amount, _data, "", true);
    }

    /// @notice Authorize a third party `_operator` to manage (send) `msg.sender`'s tokens.
    /// @param _operator The operator that wants to be Authorized
    function authorizeOperator(address _operator) external {
        require(_operator != msg.sender, "Cannot authorize yourself as an operator");
        if (mIsDefaultOperator[_operator]) {
            mRevokedDefaultOperator[_operator][msg.sender] = false;
        } else {
            mAuthorizedOperators[_operator][msg.sender] = true;
        }
        emit AuthorizedOperator(_operator, msg.sender);
    }

    /// @notice Revoke a third party `_operator`'s rights to manage (send) `msg.sender`'s tokens.
    /// @param _operator The operator that wants to be Revoked
    function revokeOperator(address _operator) external {
        require(_operator != msg.sender, "Cannot revoke yourself as an operator");
        if (mIsDefaultOperator[_operator]) {
            mRevokedDefaultOperator[_operator][msg.sender] = true;
        } else {
            mAuthorizedOperators[_operator][msg.sender] = false;
        }
        emit RevokedOperator(_operator, msg.sender);
    }

    /// @notice Check whether the `_operator` address is allowed to manage the tokens held by `_tokenHolder` address.
    /// @param _operator address to check if it has the right to manage the tokens
    /// @param _tokenHolder address which holds the tokens to be managed
    /// @return `true` if `_operator` is authorized for `_tokenHolder`
    function isOperatorFor(address _operator, address _tokenHolder) public view returns (bool) {
        return (_operator == _tokenHolder // solium-disable-line operator-whitespace
        || mAuthorizedOperators[_operator][_tokenHolder]
        || (mIsDefaultOperator[_operator] && !mRevokedDefaultOperator[_operator][_tokenHolder]));
    }

    /// @notice Send `_amount` of tokens on behalf of the address `from` to the address `to`.
    /// @param _from The address holding the tokens being sent
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be sent
    /// @param _data Data generated by the user to be sent to the recipient
    /// @param _operatorData Data generated by the operator to be sent to the recipient
    function operatorSend(
        address _from,
        address _to,
        uint256 _amount,
        bytes calldata _data,
        bytes calldata _operatorData
    )
    external
    {
        require(isOperatorFor(msg.sender, _from), "Not an operator.");
        doSend(msg.sender, _from, _to, _amount, _data, _operatorData, true);
    }

    function burn(uint256 _amount, bytes calldata _data) external {
        doBurn(msg.sender, msg.sender, _amount, _data, "");
    }

    function operatorBurn(
        address _tokenHolder,
        uint256 _amount,
        bytes calldata _data,
        bytes calldata _operatorData
    )
    external
    {
        require(isOperatorFor(msg.sender, _tokenHolder), "Not an operator");
        doBurn(msg.sender, _tokenHolder, _amount, _data, _operatorData);
    }

    /* -- Helper Functions -- */
    //
    /// @notice Internal function that ensures `_amount` is multiple of the granularity
    /// @param _amount The quantity that want's to be checked
    function requireMultiple(uint256 _amount) internal view {
        require(_amount % mGranularity == 0, "Amount is not a multiple of granularity");
    }

    /// @notice Check whether an address is a regular address or not.
    /// @param _addr Address of the contract that has to be checked
    /// @return `true` if `_addr` is a regular address (not a contract)
    function isRegularAddress(address _addr) internal view returns(bool) {
        if (_addr == address(0)) { return false; }
        uint size;
        assembly { size := extcodesize(_addr) } // solium-disable-line security/no-inline-assembly
        return size == 0;
    }

    /// @notice Helper function actually performing the sending of tokens.
    /// @param _operator The address performing the send
    /// @param _from The address holding the tokens being sent
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be sent
    /// @param _data Data generated by the user to be passed to the recipient
    /// @param _operatorData Data generated by the operator to be passed to the recipient
    /// @param _preventLocking `true` if you want this function to throw when tokens are sent to a contract not
    ///  implementing `ERC777tokensRecipient`.
    ///  ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
    ///  functions SHOULD set this parameter to `false`.
    function doSend(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData,
        bool _preventLocking
    )
    internal
    {
        requireMultiple(_amount);

        callSender(_operator, _from, _to, _amount, _data, _operatorData);

        require(_to != address(0), "Cannot send to 0x0");
        require(mBalances[_from] >= _amount, "Not enough funds");

        mBalances[_from] = mBalances[_from].sub(_amount);
        mBalances[_to] = mBalances[_to].add(_amount);

        callRecipient(_operator, _from, _to, _amount, _data, _operatorData, _preventLocking);

        emit Sent(_operator, _from, _to, _amount, _data, _operatorData);
    }

    /// @notice Helper function actually performing the burning of tokens.
    /// @param _operator The address performing the burn
    /// @param _tokenHolder The address holding the tokens being burn
    /// @param _amount The number of tokens to be burnt
    /// @param _data Data generated by the token holder
    /// @param _operatorData Data generated by the operator
    function doBurn(
        address _operator,
        address _tokenHolder,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData
    )
    internal
    {
        callSender(_operator, _tokenHolder, address(0), _amount, _data, _operatorData);

        requireMultiple(_amount);
        require(balanceOf(_tokenHolder) >= _amount, "Not enough funds");

        mBalances[_tokenHolder] = mBalances[_tokenHolder].sub(_amount);
        mTotalSupply = mTotalSupply.sub(_amount);

        emit Burned(_operator, _tokenHolder, _amount, _data, _operatorData);
    }

    /// @notice Helper function that checks for ERC777TokensRecipient on the recipient and calls it.
    ///  May throw according to `_preventLocking`
    /// @param _operator The address performing the send or mint
    /// @param _from The address holding the tokens being sent
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be sent
    /// @param _data Data generated by the user to be passed to the recipient
    /// @param _operatorData Data generated by the operator to be passed to the recipient
    /// @param _preventLocking `true` if you want this function to throw when tokens are sent to a contract not
    ///  implementing `ERC777TokensRecipient`.
    ///  ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
    ///  functions SHOULD set this parameter to `false`.
    function callRecipient(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData,
        bool _preventLocking
    )
    internal
    {
        address recipientImplementation = interfaceAddr(_to, "ERC777TokensRecipient");
        if (recipientImplementation != address(0)) {
            IERC777TokensRecipient(recipientImplementation).tokensReceived(
                _operator, _from, _to, _amount, _data, _operatorData);
        } else if (_preventLocking) {
            require(isRegularAddress(_to), "Cannot send to contract without ERC777TokensRecipient");
        }
    }

    /// @notice Helper function that checks for ERC777TokensSender on the sender and calls it.
    ///  May throw according to `_preventLocking`
    /// @param _from The address holding the tokens being sent
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be sent
    /// @param _data Data generated by the user to be passed to the recipient
    /// @param _operatorData Data generated by the operator to be passed to the recipient
    ///  implementing `ERC777TokensSender`.
    ///  ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
    ///  functions SHOULD set this parameter to `false`.
    function callSender(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData
    )
    internal
    {
        address senderImplementation = interfaceAddr(_from, "ERC777TokensSender");
        if (senderImplementation == address(0)) { return; }
        IERC777TokensSender(senderImplementation).tokensToSend(
            _operator, _from, _to, _amount, _data, _operatorData);
    }
}


/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
pragma solidity 0.5.8;


import { IERC20 } from "./IERC20.sol";
import { ERC777RemoteBridge } from "./ERC777RemoteBridge.sol";


contract ERC777ERC20Compat is IERC20, ERC777RemoteBridge {
    bool internal mErc20compatible;

    mapping(address => mapping(address => uint256)) internal mAllowed;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _granularity,
        uint256 _totalSupply,
        address _initialOwner,
        address[] memory _defaultOperators
    )
    internal ERC777RemoteBridge(_name, _symbol, _granularity, _totalSupply, _initialOwner, _defaultOperators)
    {
        mErc20compatible = true;
        setInterfaceImplementation("ERC20Token", address(this));
    }

    /// @notice This modifier is applied to erc20 obsolete methods that are
    ///  implemented only to maintain backwards compatibility. When the erc20
    ///  compatibility is disabled, this methods will fail.
    modifier erc20 () {
        require(mErc20compatible, "ERC20 is disabled");
        _;
    }

    /// @notice For Backwards compatibility
    /// @return The decimals of the token. Forced to 18 in ERC777.
    function decimals() public erc20 view returns (uint8) { return uint8(18); }

    /// @notice ERC20 backwards compatible transfer.
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be transferred
    /// @return `true`, if the transfer can't be done, it should fail.
    function transfer(address _to, uint256 _amount) public erc20 returns (bool success) {
        doSend(msg.sender, msg.sender, _to, _amount, "", "", false);
        return true;
    }

    /// @notice ERC20 backwards compatible transferFrom.
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be transferred
    /// @return `true`, if the transfer can't be done, it should fail.
    function transferFrom(address _from, address _to, uint256 _amount) public erc20 returns (bool success) {
        uint256 allowance = balancesDB.getAllowance(_from, msg.sender);
        require(_amount <= allowance, "Not enough allowance.");

        // Cannot be after doSend because of tokensReceived re-entry
        require(balancesDB.decApprove(_from, msg.sender, _amount));
        doSend(msg.sender, _from, _to, _amount, "", "", false);
        return true;
    }

    /// @notice ERC20 backwards compatible approve.
    ///  `msg.sender` approves `_spender` to spend `_amount` tokens on its behalf.
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _amount The number of tokens to be approved for transfer
    /// @return `true`, if the approve can't be done, it should fail.
    function approve(address _spender, uint256 _amount) public erc20 returns (bool success) {
        require(balancesDB.setApprove(msg.sender, _spender, _amount));
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    /// @notice ERC20 backwards compatible allowance.
    ///  This function makes it easy to read the `allowed[]` map
    /// @param _owner The address of the account that owns the token
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens of _owner that _spender is allowed
    ///  to spend
    function allowance(address _owner, address _spender) public erc20 view returns (uint256 remaining) {
        return balancesDB.getAllowance(_owner, _spender);
    }

    function doSend(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData,
        bool _preventLocking
    )
    internal
    {
        super.doSend(_operator, _from, _to, _amount, _data, _operatorData, _preventLocking);
        if (mErc20compatible) { emit Transfer(_from, _to, _amount); }
    }

    function doBurn(
        address _operator,
        address _tokenHolder,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData
    )
    internal
    {
        super.doBurn(_operator, _tokenHolder, _amount, _data, _operatorData);
        if (mErc20compatible) { emit Transfer(_tokenHolder, address(0), _amount); }
    }
}


/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
pragma solidity 0.5.8;


import { ERC777 } from "./ERC777.sol";
import { CStore } from "./CStore.sol";


contract ERC777RemoteBridge is ERC777 {

    CStore public balancesDB;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _granularity,
        uint256 _totalSupply,
        address _initialOwner,
        address[] memory _defaultOperators
    )
    public ERC777(_name, _symbol, _granularity, new address[](0))
    {
        balancesDB = new CStore(_totalSupply, _initialOwner, _defaultOperators);
    }

    /**
     * @return the total supply of the token
     */
    function totalSupply() public view returns (uint256) {
        return balancesDB.getTotalSupply();
    }

    /**
     * @notice Return the account balance of some account
     * @param _tokenHolder Address for which the balance is returned
     * @return the balance of `_tokenAddress`.
     */
    function balanceOf(address _tokenHolder) public view returns (uint256) {
        return balancesDB.getBalance(_tokenHolder);
    }

    /**
     * @notice Return the list of default operators
     * @return the list of all the default operators
     */
    function defaultOperators() public view returns (address[] memory) {
        return balancesDB.getDefaultOperators();
    }

    /**
     * @notice Authorize a third party `_operator` to manage (send) `msg.sender`'s tokens at remote database.
     * @param _operator The operator that wants to be Authorized
     */
    function authorizeOperator(address _operator) external {
        require(_operator != msg.sender, "Cannot authorize yourself as an operator");
        if (balancesDB.getDefaultOperator(_operator)) {
            require(balancesDB.setRevokedDefaultOperator(_operator, msg.sender, false));
        } else {
            require(balancesDB.setAuthorizedOperator(_operator, msg.sender, true));
        }
        emit AuthorizedOperator(_operator, msg.sender);
    }

    /**
     * @notice Revoke a third party `_operator`'s rights to manage (send) `msg.sender`'s tokens at remote database.
     * @param _operator The operator that wants to be Revoked
     */
    function revokeOperator(address _operator) external {
        require(_operator != msg.sender, "Cannot revoke yourself as an operator");
        if (balancesDB.getDefaultOperator(_operator)) {
            require(balancesDB.setRevokedDefaultOperator(_operator, msg.sender, true));
        } else {
            require(balancesDB.setAuthorizedOperator(_operator, msg.sender, false));
        }
        emit RevokedOperator(_operator, msg.sender);
    }

    /**
    * @notice Check whether the `_operator` address is allowed to manage the tokens held by `_tokenHolder`
    *  address at remote database.
    * @param _operator address to check if it has the right to manage the tokens
    * @param _tokenHolder address which holds the tokens to be managed
    * @return `true` if `_operator` is authorized for `_tokenHolder`
    */
    function isOperatorFor(address _operator, address _tokenHolder) public view returns (bool) {
        return _operator == _tokenHolder || balancesDB.getAuthorizedOperator(_operator, _tokenHolder);
        return (_operator == _tokenHolder // solium-disable-line operator-whitespace
        || balancesDB.getAuthorizedOperator(_operator, _tokenHolder)
        || (balancesDB.getDefaultOperator(_operator) && !balancesDB.getRevokedDefaultOperator(_operator, _tokenHolder)));
    }

    /**
     * @notice Helper function actually performing the sending of tokens using a backend database.
     * @param _from The address holding the tokens being sent
     * @param _to The address of the recipient
     * @param _amount The number of tokens to be sent
     * @param _data Data generated by the user to be passed to the recipient
     * @param _operatorData Data generated by the operator to be passed to the recipient
     * @param _preventLocking `true` if you want this function to throw when tokens are sent to a contract not
     *  implementing `erc777_tokenHolder`.
     *  ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
     *  functions SHOULD set this parameter to `false`.
     */
    function doSend(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData,
        bool _preventLocking
    )
    internal
    {
        requireMultiple(_amount);

        callSender(_operator, _from, _to, _amount, _data, _operatorData);

        require(_to != address(0), "Cannot send to 0x0");          // forbid sending to 0x0 (=burning)
        // require(mBalances[_from] >= _amount); // ensure enough funds
        // (Not Required due to SafeMath throw if underflow in database and false check)

        require(balancesDB.move(_from, _to, _amount));

        callRecipient(_operator, _from, _to, _amount, _data, _operatorData, _preventLocking);

        emit Sent(_operator, _from, _to, _amount, _data, _operatorData);
        //if (mErc20compatible) { emit Transfer(_from, _to, _amount); }
    }

    /**
     * @notice Helper function actually performing the burning of tokens.
     * @param _operator The address performing the burn
     * @param _tokenHolder The address holding the tokens being burn
     * @param _amount The number of tokens to be burnt
     * @param _data Data generated by the token holder
     * @param _operatorData Data generated by the operator
     */
    function doBurn(
        address _operator,
        address _tokenHolder,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData
    )
    internal
    {
        revert("Burning functionality is disabled.");
    }
}


pragma solidity ^0.5.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
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

pragma solidity 0.5.8;


interface IERC644 {
    function getBalance(address _acct) external view returns(uint);
    function incBalance(address _acct, uint _val) external returns(bool);
    function decBalance(address _acct, uint _val) external returns(bool);
    function getAllowance(address _owner, address _spender) external view returns(uint);
    function setApprove(address _sender, address _spender, uint256 _value) external returns(bool);
    function decApprove(address _from, address _spender, uint _value) external returns(bool);
    function getModule(address _acct) external view returns (bool);
    function setModule(address _acct, bool _set) external returns(bool);
    function getTotalSupply() external view returns(uint);
    function incTotalSupply(uint _val) external returns(bool);
    function decTotalSupply(uint _val) external returns(bool);
    function transferRoot(address _new) external returns(bool);

    event BalanceAdj(address indexed Module, address indexed Account, uint Amount, string Polarity);
    event ModuleSet(address indexed Module, bool indexed Set);
}


/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
// solhint-disable-next-line compiler-fixed
pragma solidity 0.5.8;


interface IERC777 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function granularity() external view returns (uint256);

    function defaultOperators() external view returns (address[] memory);
    function isOperatorFor(address operator, address tokenHolder) external view returns (bool);
    function authorizeOperator(address operator) external;
    function revokeOperator(address operator) external;

    function send(address to, uint256 amount, bytes calldata data) external;
    function operatorSend(
        address from,
        address to,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;

    function burn(uint256 amount, bytes calldata data) external;
    function operatorBurn(address from, uint256 amount, bytes calldata data, bytes calldata operatorData) external;

    event Sent(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );
    event Minted(address indexed operator, address indexed to, uint256 amount, bytes data, bytes operatorData);
    event Burned(address indexed operator, address indexed from, uint256 amount, bytes data, bytes operatorData);
    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    event RevokedOperator(address indexed operator, address indexed tokenHolder);
}


/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
// solhint-disable-next-line compiler-fixed
pragma solidity 0.5.8;


interface IERC777TokensRecipient {
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;
}


/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
// solhint-disable-next-line compiler-fixed
pragma solidity 0.5.8;


interface IERC777TokensSender {
    function tokensToSend(
        address operator,
        address from,
        address to,
        uint amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;
}


pragma solidity ^0.5.0;

import "./Context.sol";
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
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
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

pragma solidity 0.5.8;

import "./Ownable.sol";


/**
 * @title Safe Guard Contract
 * @author Panos
 */
contract SafeGuard is Ownable {

    event Transaction(address indexed destination, uint value, bytes data);

    /**
     * @dev Allows owner to execute a transaction.
     */
    function executeTransaction(address destination, uint value, bytes memory data)
    public
    onlyOwner
    {
        require(externalCall(destination, value, data.length, data));
        emit Transaction(destination, value, data);
    }

    /**
     * @dev call has been separated into its own function in order to take advantage
     *  of the Solidity's code generator to produce a loop that copies tx.data into memory.
     */
    function externalCall(address destination, uint value, uint dataLength, bytes memory data)
    private
    returns (bool) {
        bool result;
        assembly { // solhint-disable-line no-inline-assembly
        let x := mload(0x40)   // "Allocate" memory for output
            // (0x40 is where "free memory" pointer is stored by convention)
            let d := add(data, 32) // First 32 bytes are the padded length of data, so exclude that
            result := call(
            sub(gas, 34710), // 34710 is the value that solidity is currently emitting
            // It includes callGas (700) + callVeryLow (3, to pay for SUB) + callValueTransferGas (9000) +
            // callNewAccountGas (25000, in case the destination address does not exist and needs creating)
            destination,
            value,
            d,
            dataLength, // Size of the input (in bytes) - this is what fixes the padding problem
            x,
            0                  // Output is ignored, therefore the output size is zero
            )
        }
        return result;
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

pragma solidity 0.5.8;

import "./ERC777ERC20Compat.sol";
import "./SafeGuard.sol";
import { CStore } from "./CStore.sol"; //TODO: Convert all imports like this

contract CALL is ERC777ERC20Compat, SafeGuard {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _granularity,
        uint256 _totalSupply,
        address _initialOwner,
        address[] memory _defaultOperators
    )
    public ERC777ERC20Compat(_name, _symbol, _granularity, _totalSupply, _initialOwner, _defaultOperators)
    {
        requireMultiple(_totalSupply);
        require(balancesDB.setModule(address(this), true), "Cannot enable access to the database.");
        balancesDB.transferOwnership(_initialOwner);

        callRecipient(msg.sender, address(0), _initialOwner, _totalSupply, "", "", true);

        emit Minted(msg.sender, _initialOwner, _totalSupply, "", "");
        if (mErc20compatible) { emit Transfer(address(0), _initialOwner, _totalSupply); }
    }

    /**
     * @notice change the balances database to `_newDB`
     * @param _newDB The new balances database address
     */
    function changeBalancesDB(address _newDB) public onlyOwner {
        balancesDB = CStore(_newDB);
    }

    /**
     * @notice Disables the ERC20 interface. This function can only be called
     * by the owner.
     */
    function disableERC20() public onlyOwner {
        mErc20compatible = false;
        setInterfaceImplementation("ERC20Token", address(0));
    }

    /**
     * @notice Re enables the ERC20 interface. This function can only be called
     *  by the owner.
     */
    function enableERC20() public onlyOwner {
        mErc20compatible = true;
        setInterfaceImplementation("ERC20Token", address(this));
    }

    /**
     * @dev Transfer the specified amounts of tokens to the specified addresses.
     * @dev Be aware that there is no check for duplicate recipients.
     * @param _toAddresses Receiver addresses.
     * @param _amounts Amounts of tokens that will be transferred.
     */
    function multiPartyTransfer(address[] calldata _toAddresses, uint256[] calldata _amounts) external erc20 {
        /* Ensures _toAddresses array is less than or equal to 255 */
        require(_toAddresses.length <= 255, "Unsupported number of addresses.");
        /* Ensures _toAddress and _amounts have the same number of entries. */
        require(_toAddresses.length == _amounts.length, "Provided addresses does not equal to provided sums.");

        for (uint8 i = 0; i < _toAddresses.length; i++) {
            transfer(_toAddresses[i], _amounts[i]);
        }
    }

    /**
    * @dev Transfer the specified amounts of tokens to the specified addresses from authorized balance of sender.
    * @dev Be aware that there is no check for duplicate recipients.
    * @param _from The address of the sender
    * @param _toAddresses The addresses of the recipients (MAX 255)
    * @param _amounts The amounts of tokens to be transferred
    */
    function multiPartyTransferFrom(address _from, address[] calldata _toAddresses, uint256[] calldata _amounts) external erc20 {
        /* Ensures _toAddresses array is less than or equal to 255 */
        require(_toAddresses.length <= 255, "Unsupported number of addresses.");
        /* Ensures _toAddress and _amounts have the same number of entries. */
        require(_toAddresses.length == _amounts.length, "Provided addresses does not equal to provided sums.");

        for (uint8 i = 0; i < _toAddresses.length; i++) {
            transferFrom(_from, _toAddresses[i], _amounts[i]);
        }
    }

    /**
     * @dev Transfer the specified amounts of tokens to the specified addresses.
     * @dev Be aware that there is no check for duplicate recipients.
     * @param _toAddresses Receiver addresses.
     * @param _amounts Amounts of tokens that will be transferred.
     * @param _userData User supplied data
     */
    function multiPartySend(address[] memory _toAddresses, uint256[] memory _amounts, bytes memory _userData) public {
        /* Ensures _toAddresses array is less than or equal to 255 */
        require(_toAddresses.length <= 255, "Unsupported number of addresses.");
        /* Ensures _toAddress and _amounts have the same number of entries. */
        require(_toAddresses.length == _amounts.length, "Provided addresses does not equal to provided sums.");

        for (uint8 i = 0; i < _toAddresses.length; i++) {
            doSend(msg.sender,  msg.sender, _toAddresses[i], _amounts[i], _userData, "", true);
        }
    }

    /**
    * @dev Transfer the specified amounts of tokens to the specified addresses as `_from`.
    * @dev Be aware that there is no check for duplicate recipients.
    * @param _from Address to use as sender
    * @param _to Receiver addresses.
    * @param _amounts Amounts of tokens that will be transferred.
    * @param _userData User supplied data
    * @param _operatorData Operator supplied data
    */
    function multiOperatorSend(address _from, address[] calldata _to, uint256[] calldata _amounts, bytes calldata _userData, bytes calldata _operatorData)
    external {
        /* Ensures _toAddresses array is less than or equal to 255 */
        require(_to.length <= 255, "Unsupported number of addresses.");
        /* Ensures _toAddress and _amounts have the same number of entries. */
        require(_to.length == _amounts.length, "Provided addresses does not equal to provided sums.");

        for (uint8 i = 0; i < _to.length; i++) {
            require(isOperatorFor(msg.sender, _from), "Not an operator"); //TODO check for denial of service
            doSend(msg.sender, _from, _to[i], _amounts[i], _userData, _operatorData, true);
        }
    }
}


pragma solidity ^0.5.0;

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
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () internal { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

pragma solidity 0.5.8;

import "./ERC644Balances.sol";
import { ERC1820Client } from "./ERC1820Client.sol";


/**
 * @title ERC644 Database Contract
 * @author Panos
 */
contract CStore is ERC644Balances, ERC1820Client {

    address[] internal mDefaultOperators;
    mapping(address => bool) internal mIsDefaultOperator;
    mapping(address => mapping(address => bool)) internal mRevokedDefaultOperator;
    mapping(address => mapping(address => bool)) internal mAuthorizedOperators;

    /**
     * @notice Database construction
     * @param _totalSupply The total supply of the token
     */
    constructor(uint256 _totalSupply, address _initialOwner, address[] memory _defaultOperators) public
    {
        balances[_initialOwner] = _totalSupply;
        totalSupply = _totalSupply;
        mDefaultOperators = _defaultOperators;
        for (uint256 i = 0; i < mDefaultOperators.length; i++) { mIsDefaultOperator[mDefaultOperators[i]] = true; }

        setInterfaceImplementation("ERC644Balances", address(this));
    }

    /**
     * @notice Increase total supply by `_val`
     * @param _val Value to increase
     * @return Operation status
     */
    // solhint-disable-next-line no-unused-vars
    function incTotalSupply(uint _val) external onlyModule returns (bool) {
        return false;
    }

    /**
     * @notice Decrease total supply by `_val`
     * @param _val Value to decrease
     * @return Operation status
     */
     // solhint-disable-next-line no-unused-vars
     function decTotalSupply(uint _val) external onlyModule returns (bool) {
         return false;
     }

    /**
     * @notice moving `_amount` from `_from` to `_to`
     * @param _from The sender address
     * @param _to The receiving address
     * @param _amount The moving amount
     * @return bool The move result
     */
    function move(address _from, address _to, uint256 _amount) external
    onlyModule
    returns (bool) {
        balances[_from] = balances[_from].sub(_amount);
        emit BalanceAdj(msg.sender, _from, _amount, "-");
        balances[_to] = balances[_to].add(_amount);
        emit BalanceAdj(msg.sender, _to, _amount, "+");
        return true;
    }

    /**
     * @notice Setting operator `_operator` for `_tokenHolder`
     * @param _operator The operator to set status
     * @param _tokenHolder The token holder to set operator
     * @param _status The operator status
     * @return bool Status of operation
     */
    function setAuthorizedOperator(address _operator, address _tokenHolder, bool _status) external
    onlyModule
    returns (bool) {
        mAuthorizedOperators[_operator][_tokenHolder] = _status;
        return true;
    }

    /**
     * @notice Set revoke status for default operator `_operator` for `_tokenHolder`
     * @param _operator The default operator to set status
     * @param _tokenHolder The token holder to set operator
     * @param _status The operator status
     * @return bool Status of operation
     */
    function setRevokedDefaultOperator(address _operator, address _tokenHolder, bool _status) external
    onlyModule
    returns (bool) {
    mRevokedDefaultOperator[_operator][_tokenHolder] = _status;
        return true;
    }

    /**
     * @notice Getting operator `_operator` for `_tokenHolder`
     * @param _operator The operator address to get status
     * @param _tokenHolder The token holder address
     * @return bool Operator status
     */
    function getAuthorizedOperator(address _operator, address _tokenHolder) external
    view
    returns (bool) {
        return mAuthorizedOperators[_operator][_tokenHolder];
    }

    /**
     * @notice Getting default operator `_operator`
     * @param _operator The default operator address to get status
     * @return bool Default operator status
     */
    function getDefaultOperator(address _operator) external view returns (bool) {
        return mIsDefaultOperator[_operator];
    }

    /**
     * @notice Getting default operators
     * @return address[] Default operator addresses
     */
    function getDefaultOperators() external view returns (address[] memory) {
        return mDefaultOperators;
    }

    function getRevokedDefaultOperator(address _operator, address _tokenHolder) external view returns (bool) {
        return mRevokedDefaultOperator[_operator][_tokenHolder];
    }

    /**
     * @notice Increment `_acct` balance by `_val`
     * @param _acct Target account to increment balance.
     * @param _val Value to increment
     * @return Operation status
     */
    // solhint-disable-next-line no-unused-vars
    function incBalance(address _acct, uint _val) public onlyModule returns (bool) {
        return false;
    }

    /**
     * @notice Decrement `_acct` balance by `_val`
     * @param _acct Target account to decrement balance.
     * @param _val Value to decrement
     * @return Operation status
     */
     // solhint-disable-next-line no-unused-vars
     function decBalance(address _acct, uint _val) public onlyModule returns (bool) {
         return false;
     }
}


pragma solidity ^0.5.3;


contract ERC1820Registry {
    function setInterfaceImplementer(address _addr, bytes32 _interfaceHash, address _implementer) external;
    function getInterfaceImplementer(address _addr, bytes32 _interfaceHash) external view returns (address);
    function setManager(address _addr, address _newManager) external;
    function getManager(address _addr) public view returns (address);
}


/// Base client to interact with the registry.
contract ERC1820Client {
    ERC1820Registry constant ERC1820REGISTRY = ERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    function setInterfaceImplementation(string memory _interfaceLabel, address _implementation) internal {
        bytes32 interfaceHash = keccak256(abi.encodePacked(_interfaceLabel));
        ERC1820REGISTRY.setInterfaceImplementer(address(this), interfaceHash, _implementation);
    }

    function interfaceAddr(address addr, string memory _interfaceLabel) internal view returns(address) {
        bytes32 interfaceHash = keccak256(abi.encodePacked(_interfaceLabel));
        return ERC1820REGISTRY.getInterfaceImplementer(addr, interfaceHash);
    }

    function delegateManagement(address _newManager) internal {
        ERC1820REGISTRY.setManager(address(this), _newManager);
    }
}

pragma solidity 0.5.8;

import "./SafeMath.sol";
import "./SafeGuard.sol";
import "./IERC644.sol";


/**
 * @title ERC644 Standard Balances Contract
 * @author chrisfranko
 */
contract ERC644Balances is IERC644, SafeGuard {
    using SafeMath for uint256;

    uint256 public totalSupply;

    event BalanceAdj(address indexed module, address indexed account, uint amount, string polarity);
    event ModuleSet(address indexed module, bool indexed set);

    mapping(address => bool) public modules;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowed;

    modifier onlyModule() {
        require(modules[msg.sender], "ERC644Balances: caller is not a module");
        _;
    }

    /**
     * @notice Set allowance of `_spender` in behalf of `_sender` at `_value`
     * @param _sender Owner account
     * @param _spender Spender account
     * @param _value Value to approve
     * @return Operation status
     */
    function setApprove(address _sender, address _spender, uint256 _value) external onlyModule returns (bool) {
        allowed[_sender][_spender] = _value;
        return true;
    }

    /**
     * @notice Decrease allowance of `_spender` in behalf of `_from` at `_value`
     * @param _from Owner account
     * @param _spender Spender account
     * @param _value Value to decrease
     * @return Operation status
     */
    function decApprove(address _from, address _spender, uint _value) external onlyModule returns (bool) {
        allowed[_from][_spender] = allowed[_from][_spender].sub(_value);
        return true;
    }

    /**
    * @notice Increase total supply by `_val`
    * @param _val Value to increase
    * @return Operation status
    */
    function incTotalSupply(uint _val) external onlyModule returns (bool) {
        totalSupply = totalSupply.add(_val);
        return true;
    }

    /**
     * @notice Decrease total supply by `_val`
     * @param _val Value to decrease
     * @return Operation status
     */
    function decTotalSupply(uint _val) external onlyModule returns (bool) {
        totalSupply = totalSupply.sub(_val);
        return true;
    }

    /**
     * @notice Set/Unset `_acct` as an authorized module
     * @param _acct Module address
     * @param _set Module set status
     * @return Operation status
     */
    function setModule(address _acct, bool _set) external onlyOwner returns (bool) {
        modules[_acct] = _set;
        emit ModuleSet(_acct, _set);
        return true;
    }

    /**
     * @notice Get `_acct` balance
     * @param _acct Target account to get balance.
     * @return The account balance
     */
    function getBalance(address _acct) external view returns (uint256) {
        return balances[_acct];
    }

    /**
     * @notice Get allowance of `_spender` in behalf of `_owner`
     * @param _owner Owner account
     * @param _spender Spender account
     * @return Allowance
     */
    function getAllowance(address _owner, address _spender) external view returns (uint256) {
        return allowed[_owner][_spender];
    }

    /**
     * @notice Get if `_acct` is an authorized module
     * @param _acct Module address
     * @return Operation status
     */
    function getModule(address _acct) external view returns (bool) {
        return modules[_acct];
    }

    /**
     * @notice Get total supply
     * @return Total supply
     */
    function getTotalSupply() external view returns (uint256) {
        return totalSupply;
    }

    /**
     * @notice Increment `_acct` balance by `_val`
     * @param _acct Target account to increment balance.
     * @param _val Value to increment
     * @return Operation status
     */
    function incBalance(address _acct, uint _val) public onlyModule returns (bool) {
        balances[_acct] = balances[_acct].add(_val);
        emit BalanceAdj(msg.sender, _acct, _val, "+");
        return true;
    }

    /**
     * @notice Decrement `_acct` balance by `_val`
     * @param _acct Target account to decrement balance.
     * @param _val Value to decrement
     * @return Operation status
     */
    function decBalance(address _acct, uint _val) public onlyModule returns (bool) {
        balances[_acct] = balances[_acct].sub(_val);
        emit BalanceAdj(msg.sender, _acct, _val, "-");
        return true;
    }

    function transferRoot(address _new) external returns (bool) {
        return false;
    }
}


/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */
pragma solidity 0.5.8;

import { ERC1820Client } from "./ERC1820Client.sol";
import { SafeMath } from "./SafeMath.sol";
import { IERC777 } from "./IERC777.sol";
import { IERC777TokensSender } from "./IERC777TokensSender.sol";
import { IERC777TokensRecipient } from "./IERC777TokensRecipient.sol";


contract ERC777 is IERC777, ERC1820Client {
    using SafeMath for uint256;

    string internal mName;
    string internal mSymbol;
    uint256 internal mGranularity;
    uint256 internal mTotalSupply;


    mapping(address => uint) internal mBalances;

    address[] internal mDefaultOperators;
    mapping(address => bool) internal mIsDefaultOperator;
    mapping(address => mapping(address => bool)) internal mRevokedDefaultOperator;
    mapping(address => mapping(address => bool)) internal mAuthorizedOperators;

    /* -- Constructor -- */
    //
    /// @notice Constructor to create a ReferenceToken
    /// @param _name Name of the new token
    /// @param _symbol Symbol of the new token.
    /// @param _granularity Minimum transferable chunk.
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _granularity,
        address[] memory _defaultOperators
    ) internal {
        mName = _name;
        mSymbol = _symbol;
        mTotalSupply = 0;
        require(_granularity >= 1, "Granularity must be > 1");
        mGranularity = _granularity;

        mDefaultOperators = _defaultOperators;
        for (uint256 i = 0; i < mDefaultOperators.length; i++) { mIsDefaultOperator[mDefaultOperators[i]] = true; }

        setInterfaceImplementation("ERC777Token", address(this));
    }

    /* -- ERC777 Interface Implementation -- */
    //
    /// @return the name of the token
    function name() public view returns (string memory) { return mName; }

    /// @return the symbol of the token
    function symbol() public view returns (string memory) { return mSymbol; }

    /// @return the granularity of the token
    function granularity() public view returns (uint256) { return mGranularity; }

    /// @return the total supply of the token
    function totalSupply() public view returns (uint256) { return mTotalSupply; }

    /// @notice Return the account balance of some account
    /// @param _tokenHolder Address for which the balance is returned
    /// @return the balance of `_tokenAddress`.
    function balanceOf(address _tokenHolder) public view returns (uint256) { return mBalances[_tokenHolder]; }

    /// @notice Return the list of default operators
    /// @return the list of all the default operators
    function defaultOperators() public view returns (address[] memory) { return mDefaultOperators; }

    /// @notice Send `_amount` of tokens to address `_to` passing `_data` to the recipient
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be sent
    function send(address _to, uint256 _amount, bytes calldata _data) external {
        doSend(msg.sender, msg.sender, _to, _amount, _data, "", true);
    }

    /// @notice Authorize a third party `_operator` to manage (send) `msg.sender`'s tokens.
    /// @param _operator The operator that wants to be Authorized
    function authorizeOperator(address _operator) external {
        require(_operator != msg.sender, "Cannot authorize yourself as an operator");
        if (mIsDefaultOperator[_operator]) {
            mRevokedDefaultOperator[_operator][msg.sender] = false;
        } else {
            mAuthorizedOperators[_operator][msg.sender] = true;
        }
        emit AuthorizedOperator(_operator, msg.sender);
    }

    /// @notice Revoke a third party `_operator`'s rights to manage (send) `msg.sender`'s tokens.
    /// @param _operator The operator that wants to be Revoked
    function revokeOperator(address _operator) external {
        require(_operator != msg.sender, "Cannot revoke yourself as an operator");
        if (mIsDefaultOperator[_operator]) {
            mRevokedDefaultOperator[_operator][msg.sender] = true;
        } else {
            mAuthorizedOperators[_operator][msg.sender] = false;
        }
        emit RevokedOperator(_operator, msg.sender);
    }

    /// @notice Check whether the `_operator` address is allowed to manage the tokens held by `_tokenHolder` address.
    /// @param _operator address to check if it has the right to manage the tokens
    /// @param _tokenHolder address which holds the tokens to be managed
    /// @return `true` if `_operator` is authorized for `_tokenHolder`
    function isOperatorFor(address _operator, address _tokenHolder) public view returns (bool) {
        return (_operator == _tokenHolder // solium-disable-line operator-whitespace
        || mAuthorizedOperators[_operator][_tokenHolder]
        || (mIsDefaultOperator[_operator] && !mRevokedDefaultOperator[_operator][_tokenHolder]));
    }

    /// @notice Send `_amount` of tokens on behalf of the address `from` to the address `to`.
    /// @param _from The address holding the tokens being sent
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be sent
    /// @param _data Data generated by the user to be sent to the recipient
    /// @param _operatorData Data generated by the operator to be sent to the recipient
    function operatorSend(
        address _from,
        address _to,
        uint256 _amount,
        bytes calldata _data,
        bytes calldata _operatorData
    )
    external
    {
        require(isOperatorFor(msg.sender, _from), "Not an operator.");
        doSend(msg.sender, _from, _to, _amount, _data, _operatorData, true);
    }

    function burn(uint256 _amount, bytes calldata _data) external {
        doBurn(msg.sender, msg.sender, _amount, _data, "");
    }

    function operatorBurn(
        address _tokenHolder,
        uint256 _amount,
        bytes calldata _data,
        bytes calldata _operatorData
    )
    external
    {
        require(isOperatorFor(msg.sender, _tokenHolder), "Not an operator");
        doBurn(msg.sender, _tokenHolder, _amount, _data, _operatorData);
    }

    /* -- Helper Functions -- */
    //
    /// @notice Internal function that ensures `_amount` is multiple of the granularity
    /// @param _amount The quantity that want's to be checked
    function requireMultiple(uint256 _amount) internal view {
        require(_amount % mGranularity == 0, "Amount is not a multiple of granularity");
    }

    /// @notice Check whether an address is a regular address or not.
    /// @param _addr Address of the contract that has to be checked
    /// @return `true` if `_addr` is a regular address (not a contract)
    function isRegularAddress(address _addr) internal view returns(bool) {
        if (_addr == address(0)) { return false; }
        uint size;
        assembly { size := extcodesize(_addr) } // solium-disable-line security/no-inline-assembly
        return size == 0;
    }

    /// @notice Helper function actually performing the sending of tokens.
    /// @param _operator The address performing the send
    /// @param _from The address holding the tokens being sent
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be sent
    /// @param _data Data generated by the user to be passed to the recipient
    /// @param _operatorData Data generated by the operator to be passed to the recipient
    /// @param _preventLocking `true` if you want this function to throw when tokens are sent to a contract not
    ///  implementing `ERC777tokensRecipient`.
    ///  ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
    ///  functions SHOULD set this parameter to `false`.
    function doSend(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData,
        bool _preventLocking
    )
    internal
    {
        requireMultiple(_amount);

        callSender(_operator, _from, _to, _amount, _data, _operatorData);

        require(_to != address(0), "Cannot send to 0x0");
        require(mBalances[_from] >= _amount, "Not enough funds");

        mBalances[_from] = mBalances[_from].sub(_amount);
        mBalances[_to] = mBalances[_to].add(_amount);

        callRecipient(_operator, _from, _to, _amount, _data, _operatorData, _preventLocking);

        emit Sent(_operator, _from, _to, _amount, _data, _operatorData);
    }

    /// @notice Helper function actually performing the burning of tokens.
    /// @param _operator The address performing the burn
    /// @param _tokenHolder The address holding the tokens being burn
    /// @param _amount The number of tokens to be burnt
    /// @param _data Data generated by the token holder
    /// @param _operatorData Data generated by the operator
    function doBurn(
        address _operator,
        address _tokenHolder,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData
    )
    internal
    {
        callSender(_operator, _tokenHolder, address(0), _amount, _data, _operatorData);

        requireMultiple(_amount);
        require(balanceOf(_tokenHolder) >= _amount, "Not enough funds");

        mBalances[_tokenHolder] = mBalances[_tokenHolder].sub(_amount);
        mTotalSupply = mTotalSupply.sub(_amount);

        emit Burned(_operator, _tokenHolder, _amount, _data, _operatorData);
    }

    /// @notice Helper function that checks for ERC777TokensRecipient on the recipient and calls it.
    ///  May throw according to `_preventLocking`
    /// @param _operator The address performing the send or mint
    /// @param _from The address holding the tokens being sent
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be sent
    /// @param _data Data generated by the user to be passed to the recipient
    /// @param _operatorData Data generated by the operator to be passed to the recipient
    /// @param _preventLocking `true` if you want this function to throw when tokens are sent to a contract not
    ///  implementing `ERC777TokensRecipient`.
    ///  ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
    ///  functions SHOULD set this parameter to `false`.
    function callRecipient(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData,
        bool _preventLocking
    )
    internal
    {
        address recipientImplementation = interfaceAddr(_to, "ERC777TokensRecipient");
        if (recipientImplementation != address(0)) {
            IERC777TokensRecipient(recipientImplementation).tokensReceived(
                _operator, _from, _to, _amount, _data, _operatorData);
        } else if (_preventLocking) {
            require(isRegularAddress(_to), "Cannot send to contract without ERC777TokensRecipient");
        }
    }

    /// @notice Helper function that checks for ERC777TokensSender on the sender and calls it.
    ///  May throw according to `_preventLocking`
    /// @param _from The address holding the tokens being sent
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be sent
    /// @param _data Data generated by the user to be passed to the recipient
    /// @param _operatorData Data generated by the operator to be passed to the recipient
    ///  implementing `ERC777TokensSender`.
    ///  ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
    ///  functions SHOULD set this parameter to `false`.
    function callSender(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData
    )
    internal
    {
        address senderImplementation = interfaceAddr(_from, "ERC777TokensSender");
        if (senderImplementation == address(0)) { return; }
        IERC777TokensSender(senderImplementation).tokensToSend(
            _operator, _from, _to, _amount, _data, _operatorData);
    }
}


/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
pragma solidity 0.5.8;


import { IERC20 } from "./IERC20.sol";
import { ERC777RemoteBridge } from "./ERC777RemoteBridge.sol";


contract ERC777ERC20Compat is IERC20, ERC777RemoteBridge {
    bool internal mErc20compatible;

    mapping(address => mapping(address => uint256)) internal mAllowed;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _granularity,
        uint256 _totalSupply,
        address _initialOwner,
        address[] memory _defaultOperators
    )
    internal ERC777RemoteBridge(_name, _symbol, _granularity, _totalSupply, _initialOwner, _defaultOperators)
    {
        mErc20compatible = true;
        setInterfaceImplementation("ERC20Token", address(this));
    }

    /// @notice This modifier is applied to erc20 obsolete methods that are
    ///  implemented only to maintain backwards compatibility. When the erc20
    ///  compatibility is disabled, this methods will fail.
    modifier erc20 () {
        require(mErc20compatible, "ERC20 is disabled");
        _;
    }

    /// @notice For Backwards compatibility
    /// @return The decimals of the token. Forced to 18 in ERC777.
    function decimals() public erc20 view returns (uint8) { return uint8(18); }

    /// @notice ERC20 backwards compatible transfer.
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be transferred
    /// @return `true`, if the transfer can't be done, it should fail.
    function transfer(address _to, uint256 _amount) public erc20 returns (bool success) {
        doSend(msg.sender, msg.sender, _to, _amount, "", "", false);
        return true;
    }

    /// @notice ERC20 backwards compatible transferFrom.
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be transferred
    /// @return `true`, if the transfer can't be done, it should fail.
    function transferFrom(address _from, address _to, uint256 _amount) public erc20 returns (bool success) {
        uint256 allowance = balancesDB.getAllowance(_from, msg.sender);
        require(_amount <= allowance, "Not enough allowance.");

        // Cannot be after doSend because of tokensReceived re-entry
        require(balancesDB.decApprove(_from, msg.sender, _amount));
        doSend(msg.sender, _from, _to, _amount, "", "", false);
        return true;
    }

    /// @notice ERC20 backwards compatible approve.
    ///  `msg.sender` approves `_spender` to spend `_amount` tokens on its behalf.
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _amount The number of tokens to be approved for transfer
    /// @return `true`, if the approve can't be done, it should fail.
    function approve(address _spender, uint256 _amount) public erc20 returns (bool success) {
        require(balancesDB.setApprove(msg.sender, _spender, _amount));
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    /// @notice ERC20 backwards compatible allowance.
    ///  This function makes it easy to read the `allowed[]` map
    /// @param _owner The address of the account that owns the token
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens of _owner that _spender is allowed
    ///  to spend
    function allowance(address _owner, address _spender) public erc20 view returns (uint256 remaining) {
        return balancesDB.getAllowance(_owner, _spender);
    }

    function doSend(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData,
        bool _preventLocking
    )
    internal
    {
        super.doSend(_operator, _from, _to, _amount, _data, _operatorData, _preventLocking);
        if (mErc20compatible) { emit Transfer(_from, _to, _amount); }
    }

    function doBurn(
        address _operator,
        address _tokenHolder,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData
    )
    internal
    {
        super.doBurn(_operator, _tokenHolder, _amount, _data, _operatorData);
        if (mErc20compatible) { emit Transfer(_tokenHolder, address(0), _amount); }
    }
}


/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
pragma solidity 0.5.8;


import { ERC777 } from "./ERC777.sol";
import { CStore } from "./CStore.sol";


contract ERC777RemoteBridge is ERC777 {

    CStore public balancesDB;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _granularity,
        uint256 _totalSupply,
        address _initialOwner,
        address[] memory _defaultOperators
    )
    public ERC777(_name, _symbol, _granularity, new address[](0))
    {
        balancesDB = new CStore(_totalSupply, _initialOwner, _defaultOperators);
    }

    /**
     * @return the total supply of the token
     */
    function totalSupply() public view returns (uint256) {
        return balancesDB.getTotalSupply();
    }

    /**
     * @notice Return the account balance of some account
     * @param _tokenHolder Address for which the balance is returned
     * @return the balance of `_tokenAddress`.
     */
    function balanceOf(address _tokenHolder) public view returns (uint256) {
        return balancesDB.getBalance(_tokenHolder);
    }

    /**
     * @notice Return the list of default operators
     * @return the list of all the default operators
     */
    function defaultOperators() public view returns (address[] memory) {
        return balancesDB.getDefaultOperators();
    }

    /**
     * @notice Authorize a third party `_operator` to manage (send) `msg.sender`'s tokens at remote database.
     * @param _operator The operator that wants to be Authorized
     */
    function authorizeOperator(address _operator) external {
        require(_operator != msg.sender, "Cannot authorize yourself as an operator");
        if (balancesDB.getDefaultOperator(_operator)) {
            require(balancesDB.setRevokedDefaultOperator(_operator, msg.sender, false));
        } else {
            require(balancesDB.setAuthorizedOperator(_operator, msg.sender, true));
        }
        emit AuthorizedOperator(_operator, msg.sender);
    }

    /**
     * @notice Revoke a third party `_operator`'s rights to manage (send) `msg.sender`'s tokens at remote database.
     * @param _operator The operator that wants to be Revoked
     */
    function revokeOperator(address _operator) external {
        require(_operator != msg.sender, "Cannot revoke yourself as an operator");
        if (balancesDB.getDefaultOperator(_operator)) {
            require(balancesDB.setRevokedDefaultOperator(_operator, msg.sender, true));
        } else {
            require(balancesDB.setAuthorizedOperator(_operator, msg.sender, false));
        }
        emit RevokedOperator(_operator, msg.sender);
    }

    /**
    * @notice Check whether the `_operator` address is allowed to manage the tokens held by `_tokenHolder`
    *  address at remote database.
    * @param _operator address to check if it has the right to manage the tokens
    * @param _tokenHolder address which holds the tokens to be managed
    * @return `true` if `_operator` is authorized for `_tokenHolder`
    */
    function isOperatorFor(address _operator, address _tokenHolder) public view returns (bool) {
        return _operator == _tokenHolder || balancesDB.getAuthorizedOperator(_operator, _tokenHolder);
        return (_operator == _tokenHolder // solium-disable-line operator-whitespace
        || balancesDB.getAuthorizedOperator(_operator, _tokenHolder)
        || (balancesDB.getDefaultOperator(_operator) && !balancesDB.getRevokedDefaultOperator(_operator, _tokenHolder)));
    }

    /**
     * @notice Helper function actually performing the sending of tokens using a backend database.
     * @param _from The address holding the tokens being sent
     * @param _to The address of the recipient
     * @param _amount The number of tokens to be sent
     * @param _data Data generated by the user to be passed to the recipient
     * @param _operatorData Data generated by the operator to be passed to the recipient
     * @param _preventLocking `true` if you want this function to throw when tokens are sent to a contract not
     *  implementing `erc777_tokenHolder`.
     *  ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
     *  functions SHOULD set this parameter to `false`.
     */
    function doSend(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData,
        bool _preventLocking
    )
    internal
    {
        requireMultiple(_amount);

        callSender(_operator, _from, _to, _amount, _data, _operatorData);

        require(_to != address(0), "Cannot send to 0x0");          // forbid sending to 0x0 (=burning)
        // require(mBalances[_from] >= _amount); // ensure enough funds
        // (Not Required due to SafeMath throw if underflow in database and false check)

        require(balancesDB.move(_from, _to, _amount));

        callRecipient(_operator, _from, _to, _amount, _data, _operatorData, _preventLocking);

        emit Sent(_operator, _from, _to, _amount, _data, _operatorData);
        //if (mErc20compatible) { emit Transfer(_from, _to, _amount); }
    }

    /**
     * @notice Helper function actually performing the burning of tokens.
     * @param _operator The address performing the burn
     * @param _tokenHolder The address holding the tokens being burn
     * @param _amount The number of tokens to be burnt
     * @param _data Data generated by the token holder
     * @param _operatorData Data generated by the operator
     */
    function doBurn(
        address _operator,
        address _tokenHolder,
        uint256 _amount,
        bytes memory _data,
        bytes memory _operatorData
    )
    internal
    {
        revert("Burning functionality is disabled.");
    }
}


pragma solidity ^0.5.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
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

pragma solidity 0.5.8;


interface IERC644 {
    function getBalance(address _acct) external view returns(uint);
    function incBalance(address _acct, uint _val) external returns(bool);
    function decBalance(address _acct, uint _val) external returns(bool);
    function getAllowance(address _owner, address _spender) external view returns(uint);
    function setApprove(address _sender, address _spender, uint256 _value) external returns(bool);
    function decApprove(address _from, address _spender, uint _value) external returns(bool);
    function getModule(address _acct) external view returns (bool);
    function setModule(address _acct, bool _set) external returns(bool);
    function getTotalSupply() external view returns(uint);
    function incTotalSupply(uint _val) external returns(bool);
    function decTotalSupply(uint _val) external returns(bool);
    function transferRoot(address _new) external returns(bool);

    event BalanceAdj(address indexed Module, address indexed Account, uint Amount, string Polarity);
    event ModuleSet(address indexed Module, bool indexed Set);
}


/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
// solhint-disable-next-line compiler-fixed
pragma solidity 0.5.8;


interface IERC777 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function granularity() external view returns (uint256);

    function defaultOperators() external view returns (address[] memory);
    function isOperatorFor(address operator, address tokenHolder) external view returns (bool);
    function authorizeOperator(address operator) external;
    function revokeOperator(address operator) external;

    function send(address to, uint256 amount, bytes calldata data) external;
    function operatorSend(
        address from,
        address to,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;

    function burn(uint256 amount, bytes calldata data) external;
    function operatorBurn(address from, uint256 amount, bytes calldata data, bytes calldata operatorData) external;

    event Sent(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );
    event Minted(address indexed operator, address indexed to, uint256 amount, bytes data, bytes operatorData);
    event Burned(address indexed operator, address indexed from, uint256 amount, bytes data, bytes operatorData);
    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    event RevokedOperator(address indexed operator, address indexed tokenHolder);
}


/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
// solhint-disable-next-line compiler-fixed
pragma solidity 0.5.8;


interface IERC777TokensRecipient {
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;
}


/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This code has not been reviewed.
 * Do not use or deploy this code before reviewing it personally first.
 */
// solhint-disable-next-line compiler-fixed
pragma solidity 0.5.8;


interface IERC777TokensSender {
    function tokensToSend(
        address operator,
        address from,
        address to,
        uint amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;
}


pragma solidity ^0.5.0;

import "./Context.sol";
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
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
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

pragma solidity 0.5.8;

import "./Ownable.sol";


/**
 * @title Safe Guard Contract
 * @author Panos
 */
contract SafeGuard is Ownable {

    event Transaction(address indexed destination, uint value, bytes data);

    /**
     * @dev Allows owner to execute a transaction.
     */
    function executeTransaction(address destination, uint value, bytes memory data)
    public
    onlyOwner
    {
        require(externalCall(destination, value, data.length, data));
        emit Transaction(destination, value, data);
    }

    /**
     * @dev call has been separated into its own function in order to take advantage
     *  of the Solidity's code generator to produce a loop that copies tx.data into memory.
     */
    function externalCall(address destination, uint value, uint dataLength, bytes memory data)
    private
    returns (bool) {
        bool result;
        assembly { // solhint-disable-line no-inline-assembly
        let x := mload(0x40)   // "Allocate" memory for output
            // (0x40 is where "free memory" pointer is stored by convention)
            let d := add(data, 32) // First 32 bytes are the padded length of data, so exclude that
            result := call(
            sub(gas, 34710), // 34710 is the value that solidity is currently emitting
            // It includes callGas (700) + callVeryLow (3, to pay for SUB) + callValueTransferGas (9000) +
            // callNewAccountGas (25000, in case the destination address does not exist and needs creating)
            destination,
            value,
            d,
            dataLength, // Size of the input (in bytes) - this is what fixes the padding problem
            x,
            0                  // Output is ignored, therefore the output size is zero
            )
        }
        return result;
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

