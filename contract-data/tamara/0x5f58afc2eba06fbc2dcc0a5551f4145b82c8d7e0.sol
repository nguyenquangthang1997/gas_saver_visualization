pragma solidity ^0.5.0;

/**
 * @dev Collection of functions related to the address type,
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * This test is non-exhaustive, and there may be false-negatives: during the
     * execution of a contract's constructor, its address will be reported as
     * not containing a contract.
     *
     * > It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
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
}

/**
 *  Controller - The Consumer Contract Wallet
 *  Copyright (C) 2019 The Contract Wallet Company Limited
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.

 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.

 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.5.10;

import "./ownable.sol";
import "./transferrable.sol";

/// @title The IController interface provides access to the isController and isAdmin checks.
interface IController {
    function isController(address) external view returns (bool);
    function isAdmin(address) external view returns (bool);
}


/// @title Controller stores a list of controller addresses that can be used for authentication in other contracts.
/// @notice The Controller implements a hierarchy of concepts, Owner, Admin, and the Controllers.
/// @dev Owner can change the Admins
/// @dev Admins and can the Controllers
/// @dev Controllers are used by the application.
contract Controller is IController, Ownable, Transferrable {

    event AddedController(address _sender, address _controller);
    event RemovedController(address _sender, address _controller);

    event AddedAdmin(address _sender, address _admin);
    event RemovedAdmin(address _sender, address _admin);

    event Claimed(address _to, address _asset, uint _amount);

    event Stopped(address _sender);
    event Started(address _sender);

    mapping (address => bool) private _isAdmin;
    uint private _adminCount;

    mapping (address => bool) private _isController;
    uint private _controllerCount;

    bool private _stopped;

    /// @notice Constructor initializes the owner with the provided address.
    /// @param _ownerAddress_ address of the owner.
    constructor(address payable _ownerAddress_) Ownable(_ownerAddress_, false) public {}

    /// @notice Checks if message sender is an admin.
    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "sender is not an admin");
        _;
    }

    /// @notice Check if Owner or Admin
    modifier onlyAdminOrOwner() {
        require(_isOwner(msg.sender) || isAdmin(msg.sender), "sender is not an admin");
        _;
    }

    /// @notice Check if controller is stopped
    modifier notStopped() {
        require(!isStopped(), "controller is stopped");
        _;
    }

    /// @notice Add a new admin to the list of admins.
    /// @param _account address to add to the list of admins.
    function addAdmin(address _account) external onlyOwner notStopped {
        _addAdmin(_account);
    }

    /// @notice Remove a admin from the list of admins.
    /// @param _account address to remove from the list of admins.
    function removeAdmin(address _account) external onlyOwner {
        _removeAdmin(_account);
    }

    /// @return the current number of admins.
    function adminCount() external view returns (uint) {
        return _adminCount;
    }

    /// @notice Add a new controller to the list of controllers.
    /// @param _account address to add to the list of controllers.
    function addController(address _account) external onlyAdminOrOwner notStopped {
        _addController(_account);
    }

    /// @notice Remove a controller from the list of controllers.
    /// @param _account address to remove from the list of controllers.
    function removeController(address _account) external onlyAdminOrOwner {
        _removeController(_account);
    }

    /// @notice count the Controllers
    /// @return the current number of controllers.
    function controllerCount() external view returns (uint) {
        return _controllerCount;
    }

    /// @notice is an address an Admin?
    /// @return true if the provided account is an admin.
    function isAdmin(address _account) public view notStopped returns (bool) {
        return _isAdmin[_account];
    }

    /// @notice is an address a Controller?
    /// @return true if the provided account is a controller.
    function isController(address _account) public view notStopped returns (bool) {
        return _isController[_account];
    }

    /// @notice this function can be used to see if the controller has been stopped
    /// @return true is the Controller has been stopped
    function isStopped() public view returns (bool) {
        return _stopped;
    }

    /// @notice Internal-only function that adds a new admin.
    function _addAdmin(address _account) private {
        require(!_isAdmin[_account], "provided account is already an admin");
        require(!_isController[_account], "provided account is already a controller");
        require(!_isOwner(_account), "provided account is already the owner");
        require(_account != address(0), "provided account is the zero address");
        _isAdmin[_account] = true;
        _adminCount++;
        emit AddedAdmin(msg.sender, _account);
    }

    /// @notice Internal-only function that removes an existing admin.
    function _removeAdmin(address _account) private {
        require(_isAdmin[_account], "provided account is not an admin");
        _isAdmin[_account] = false;
        _adminCount--;
        emit RemovedAdmin(msg.sender, _account);
    }

    /// @notice Internal-only function that adds a new controller.
    function _addController(address _account) private {
        require(!_isAdmin[_account], "provided account is already an admin");
        require(!_isController[_account], "provided account is already a controller");
        require(!_isOwner(_account), "provided account is already the owner");
        require(_account != address(0), "provided account is the zero address");
        _isController[_account] = true;
        _controllerCount++;
        emit AddedController(msg.sender, _account);
    }

    /// @notice Internal-only function that removes an existing controller.
    function _removeController(address _account) private {
        require(_isController[_account], "provided account is not a controller");
        _isController[_account] = false;
        _controllerCount--;
        emit RemovedController(msg.sender, _account);
    }

    /// @notice stop our controllers and admins from being useable
    function stop() external onlyAdminOrOwner {
        _stopped = true;
        emit Stopped(msg.sender);
    }

    /// @notice start our controller again
    function start() external onlyOwner {
        _stopped = false;
        emit Started(msg.sender);
    }

    //// @notice Withdraw tokens from the smart contract to the specified account.
    function claim(address payable _to, address _asset, uint _amount) external onlyAdmin notStopped {
        _safeTransfer(_to, _asset, _amount);
        emit Claimed(_to, _asset, _amount);
    }
}

pragma solidity ^0.5.10;

/// @title ERC20 interface is a subset of the ERC20 specification.
/// @notice see https://github.com/ethereum/EIPs/issues/20
interface ERC20 {
    function allowance(address _owner, address _spender) external view returns (uint256);
    function approve(address _spender, uint256 _value) external returns (bool);
    function balanceOf(address _who) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
}

/**
 *  Ownable - The Consumer Contract Wallet
 *  Copyright (C) 2019 The Contract Wallet Company Limited
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.

 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.

 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.5.10;


/// @title Ownable has an owner address and provides basic authorization control functions.
/// This contract is modified version of the MIT OpenZepplin Ownable contract
/// This contract allows for the transferOwnership operation to be made impossible
/// https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/ownership/Ownable.sol
contract Ownable {
    event TransferredOwnership(address _from, address _to);
    event LockedOwnership(address _locked);

    address payable private _owner;
    bool private _isTransferable;

    /// @notice Constructor sets the original owner of the contract and whether or not it is one time transferable.
    constructor(address payable _account_, bool _transferable_) internal {
        _owner = _account_;
        _isTransferable = _transferable_;
        // Emit the LockedOwnership event if no longer transferable.
        if (!_isTransferable) {
            emit LockedOwnership(_account_);
        }
        emit TransferredOwnership(address(0), _account_);
    }

    /// @notice Reverts if called by any account other than the owner.
    modifier onlyOwner() {
        require(_isOwner(msg.sender), "sender is not an owner");
        _;
    }

    /// @notice Allows the current owner to transfer control of the contract to a new address.
    /// @param _account address to transfer ownership to.
    /// @param _transferable indicates whether to keep the ownership transferable.
    function transferOwnership(address payable _account, bool _transferable) external onlyOwner {
        // Require that the ownership is transferable.
        require(_isTransferable, "ownership is not transferable");
        // Require that the new owner is not the zero address.
        require(_account != address(0), "owner cannot be set to zero address");
        // Set the transferable flag to the value _transferable passed in.
        _isTransferable = _transferable;
        // Emit the LockedOwnership event if no longer transferable.
        if (!_transferable) {
            emit LockedOwnership(_account);
        }
        // Emit the ownership transfer event.
        emit TransferredOwnership(_owner, _account);
        // Set the owner to the provided address.
        _owner = _account;
    }

    /// @notice check if the ownership is transferable.
    /// @return true if the ownership is transferable.
    function isTransferable() external view returns (bool) {
        return _isTransferable;
    }

    /// @notice Allows the current owner to relinquish control of the contract.
    /// @dev Renouncing to ownership will leave the contract without an owner and unusable.
    /// @dev It will not be possible to call the functions with the `onlyOwner` modifier anymore.
    function renounceOwnership() external onlyOwner {
        // Require that the ownership is transferable.
        require(_isTransferable, "ownership is not transferable");
        // note that this could be terminal
        _owner = address(0);

        emit TransferredOwnership(_owner, address(0));
    }

    /// @notice Find out owner address
    /// @return address of the owner.
    function owner() public view returns (address payable) {
        return _owner;
    }

    /// @notice Check if owner address
    /// @return true if sender is the owner of the contract.
    function _isOwner(address _address) internal view returns (bool) {
        return _address == _owner;
    }
}

/**
 * The MIT License (MIT)
 *
 * Copyright (c) 2016-2019 zOS Global Limited
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

pragma solidity ^0.5.0;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Address.sol";

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

    function safeTransfer(ERC20 token, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(ERC20 token, address from, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(ERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(ERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(ERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function callOptionalReturn(ERC20 token, bytes memory data) internal {
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
        require(b <= a, "SafeMath: subtraction overflow");
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
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
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
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
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
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

/**
 *  Transferrable - The Consumer Contract Wallet
 *  Copyright (C) 2019 The Contract Wallet Company Limited
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.

 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.

 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.5.10;

import "./ERC20.sol";
import "./SafeERC20.sol";


/// @title SafeTransfer, allowing contract to withdraw tokens accidentally sent to itself
contract Transferrable {

    using SafeERC20 for ERC20;


    /// @dev This function is used to move tokens sent accidentally to this contract method.
    /// @dev The owner can chose the new destination address
    /// @param _to is the recipient's address.
    /// @param _asset is the address of an ERC20 token or 0x0 for ether.
    /// @param _amount is the amount to be transferred in base units.
    function _safeTransfer(address payable _to, address _asset, uint _amount) internal {
        // address(0) is used to denote ETH
        if (_asset == address(0)) {
            _to.transfer(_amount);
        } else {
            ERC20(_asset).safeTransfer(_to, _amount);
        }
    }
}

pragma solidity ^0.5.0;

/**
 * @dev Collection of functions related to the address type,
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * This test is non-exhaustive, and there may be false-negatives: during the
     * execution of a contract's constructor, its address will be reported as
     * not containing a contract.
     *
     * > It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
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
}

/**
 *  Controller - The Consumer Contract Wallet
 *  Copyright (C) 2019 The Contract Wallet Company Limited
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.

 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.

 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.5.10;

import "./ownable.sol";
import "./transferrable.sol";

/// @title The IController interface provides access to the isController and isAdmin checks.
interface IController {
    function isController(address) external view returns (bool);
    function isAdmin(address) external view returns (bool);
}


/// @title Controller stores a list of controller addresses that can be used for authentication in other contracts.
/// @notice The Controller implements a hierarchy of concepts, Owner, Admin, and the Controllers.
/// @dev Owner can change the Admins
/// @dev Admins and can the Controllers
/// @dev Controllers are used by the application.
contract Controller is IController, Ownable, Transferrable {

    event AddedController(address _sender, address _controller);
    event RemovedController(address _sender, address _controller);

    event AddedAdmin(address _sender, address _admin);
    event RemovedAdmin(address _sender, address _admin);

    event Claimed(address _to, address _asset, uint _amount);

    event Stopped(address _sender);
    event Started(address _sender);

    mapping (address => bool) private _isAdmin;
    uint private _adminCount;

    mapping (address => bool) private _isController;
    uint private _controllerCount;

    bool private _stopped;

    /// @notice Constructor initializes the owner with the provided address.
    /// @param _ownerAddress_ address of the owner.
    constructor(address payable _ownerAddress_) Ownable(_ownerAddress_, false) public {}

    /// @notice Checks if message sender is an admin.
    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "sender is not an admin");
        _;
    }

    /// @notice Check if Owner or Admin
    modifier onlyAdminOrOwner() {
        require(_isOwner(msg.sender) || isAdmin(msg.sender), "sender is not an admin");
        _;
    }

    /// @notice Check if controller is stopped
    modifier notStopped() {
        require(!isStopped(), "controller is stopped");
        _;
    }

    /// @notice Add a new admin to the list of admins.
    /// @param _account address to add to the list of admins.
    function addAdmin(address _account) external onlyOwner notStopped {
        _addAdmin(_account);
    }

    /// @notice Remove a admin from the list of admins.
    /// @param _account address to remove from the list of admins.
    function removeAdmin(address _account) external onlyOwner {
        _removeAdmin(_account);
    }

    /// @return the current number of admins.
    function adminCount() external view returns (uint) {
        return _adminCount;
    }

    /// @notice Add a new controller to the list of controllers.
    /// @param _account address to add to the list of controllers.
    function addController(address _account) external onlyAdminOrOwner notStopped {
        _addController(_account);
    }

    /// @notice Remove a controller from the list of controllers.
    /// @param _account address to remove from the list of controllers.
    function removeController(address _account) external onlyAdminOrOwner {
        _removeController(_account);
    }

    /// @notice count the Controllers
    /// @return the current number of controllers.
    function controllerCount() external view returns (uint) {
        return _controllerCount;
    }

    /// @notice is an address an Admin?
    /// @return true if the provided account is an admin.
    function isAdmin(address _account) public view notStopped returns (bool) {
        return _isAdmin[_account];
    }

    /// @notice is an address a Controller?
    /// @return true if the provided account is a controller.
    function isController(address _account) public view notStopped returns (bool) {
        return _isController[_account];
    }

    /// @notice this function can be used to see if the controller has been stopped
    /// @return true is the Controller has been stopped
    function isStopped() public view returns (bool) {
        return _stopped;
    }

    /// @notice Internal-only function that adds a new admin.
    function _addAdmin(address _account) private {
        require(!_isAdmin[_account], "provided account is already an admin");
        require(!_isController[_account], "provided account is already a controller");
        require(!_isOwner(_account), "provided account is already the owner");
        require(_account != address(0), "provided account is the zero address");
        _isAdmin[_account] = true;
        _adminCount++;
        emit AddedAdmin(msg.sender, _account);
    }

    /// @notice Internal-only function that removes an existing admin.
    function _removeAdmin(address _account) private {
        require(_isAdmin[_account], "provided account is not an admin");
        _isAdmin[_account] = false;
        _adminCount--;
        emit RemovedAdmin(msg.sender, _account);
    }

    /// @notice Internal-only function that adds a new controller.
    function _addController(address _account) private {
        require(!_isAdmin[_account], "provided account is already an admin");
        require(!_isController[_account], "provided account is already a controller");
        require(!_isOwner(_account), "provided account is already the owner");
        require(_account != address(0), "provided account is the zero address");
        _isController[_account] = true;
        _controllerCount++;
        emit AddedController(msg.sender, _account);
    }

    /// @notice Internal-only function that removes an existing controller.
    function _removeController(address _account) private {
        require(_isController[_account], "provided account is not a controller");
        _isController[_account] = false;
        _controllerCount--;
        emit RemovedController(msg.sender, _account);
    }

    /// @notice stop our controllers and admins from being useable
    function stop() external onlyAdminOrOwner {
        _stopped = true;
        emit Stopped(msg.sender);
    }

    /// @notice start our controller again
    function start() external onlyOwner {
        _stopped = false;
        emit Started(msg.sender);
    }

    //// @notice Withdraw tokens from the smart contract to the specified account.
    function claim(address payable _to, address _asset, uint _amount) external onlyAdmin notStopped {
        _safeTransfer(_to, _asset, _amount);
        emit Claimed(_to, _asset, _amount);
    }
}

pragma solidity ^0.5.10;

/// @title ERC20 interface is a subset of the ERC20 specification.
/// @notice see https://github.com/ethereum/EIPs/issues/20
interface ERC20 {
    function allowance(address _owner, address _spender) external view returns (uint256);
    function approve(address _spender, uint256 _value) external returns (bool);
    function balanceOf(address _who) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
}

/**
 *  Ownable - The Consumer Contract Wallet
 *  Copyright (C) 2019 The Contract Wallet Company Limited
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.

 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.

 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.5.10;


/// @title Ownable has an owner address and provides basic authorization control functions.
/// This contract is modified version of the MIT OpenZepplin Ownable contract
/// This contract allows for the transferOwnership operation to be made impossible
/// https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/ownership/Ownable.sol
contract Ownable {
    event TransferredOwnership(address _from, address _to);
    event LockedOwnership(address _locked);

    address payable private _owner;
    bool private _isTransferable;

    /// @notice Constructor sets the original owner of the contract and whether or not it is one time transferable.
    constructor(address payable _account_, bool _transferable_) internal {
        _owner = _account_;
        _isTransferable = _transferable_;
        // Emit the LockedOwnership event if no longer transferable.
        if (!_isTransferable) {
            emit LockedOwnership(_account_);
        }
        emit TransferredOwnership(address(0), _account_);
    }

    /// @notice Reverts if called by any account other than the owner.
    modifier onlyOwner() {
        require(_isOwner(msg.sender), "sender is not an owner");
        _;
    }

    /// @notice Allows the current owner to transfer control of the contract to a new address.
    /// @param _account address to transfer ownership to.
    /// @param _transferable indicates whether to keep the ownership transferable.
    function transferOwnership(address payable _account, bool _transferable) external onlyOwner {
        // Require that the ownership is transferable.
        require(_isTransferable, "ownership is not transferable");
        // Require that the new owner is not the zero address.
        require(_account != address(0), "owner cannot be set to zero address");
        // Set the transferable flag to the value _transferable passed in.
        _isTransferable = _transferable;
        // Emit the LockedOwnership event if no longer transferable.
        if (!_transferable) {
            emit LockedOwnership(_account);
        }
        // Emit the ownership transfer event.
        emit TransferredOwnership(_owner, _account);
        // Set the owner to the provided address.
        _owner = _account;
    }

    /// @notice check if the ownership is transferable.
    /// @return true if the ownership is transferable.
    function isTransferable() external view returns (bool) {
        return _isTransferable;
    }

    /// @notice Allows the current owner to relinquish control of the contract.
    /// @dev Renouncing to ownership will leave the contract without an owner and unusable.
    /// @dev It will not be possible to call the functions with the `onlyOwner` modifier anymore.
    function renounceOwnership() external onlyOwner {
        // Require that the ownership is transferable.
        require(_isTransferable, "ownership is not transferable");
        // note that this could be terminal
        _owner = address(0);

        emit TransferredOwnership(_owner, address(0));
    }

    /// @notice Find out owner address
    /// @return address of the owner.
    function owner() public view returns (address payable) {
        return _owner;
    }

    /// @notice Check if owner address
    /// @return true if sender is the owner of the contract.
    function _isOwner(address _address) internal view returns (bool) {
        return _address == _owner;
    }
}

/**
 * The MIT License (MIT)
 *
 * Copyright (c) 2016-2019 zOS Global Limited
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

pragma solidity ^0.5.0;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Address.sol";

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

    function safeTransfer(ERC20 token, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(ERC20 token, address from, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(ERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(ERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(ERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function callOptionalReturn(ERC20 token, bytes memory data) internal {
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
        require(b <= a, "SafeMath: subtraction overflow");
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
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
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
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
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
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

/**
 *  Transferrable - The Consumer Contract Wallet
 *  Copyright (C) 2019 The Contract Wallet Company Limited
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.

 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.

 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.5.10;

import "./ERC20.sol";
import "./SafeERC20.sol";


/// @title SafeTransfer, allowing contract to withdraw tokens accidentally sent to itself
contract Transferrable {

    using SafeERC20 for ERC20;


    /// @dev This function is used to move tokens sent accidentally to this contract method.
    /// @dev The owner can chose the new destination address
    /// @param _to is the recipient's address.
    /// @param _asset is the address of an ERC20 token or 0x0 for ether.
    /// @param _amount is the amount to be transferred in base units.
    function _safeTransfer(address payable _to, address _asset, uint _amount) internal {
        // address(0) is used to denote ETH
        if (_asset == address(0)) {
            _to.transfer(_amount);
        } else {
            ERC20(_asset).safeTransfer(_to, _amount);
        }
    }
}

pragma solidity ^0.5.0;

/**
 * @dev Collection of functions related to the address type,
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * This test is non-exhaustive, and there may be false-negatives: during the
     * execution of a contract's constructor, its address will be reported as
     * not containing a contract.
     *
     * > It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
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
}

/**
 *  Controller - The Consumer Contract Wallet
 *  Copyright (C) 2019 The Contract Wallet Company Limited
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.

 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.

 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.5.10;

import "./ownable.sol";
import "./transferrable.sol";

/// @title The IController interface provides access to the isController and isAdmin checks.
interface IController {
    function isController(address) external view returns (bool);
    function isAdmin(address) external view returns (bool);
}


/// @title Controller stores a list of controller addresses that can be used for authentication in other contracts.
/// @notice The Controller implements a hierarchy of concepts, Owner, Admin, and the Controllers.
/// @dev Owner can change the Admins
/// @dev Admins and can the Controllers
/// @dev Controllers are used by the application.
contract Controller is IController, Ownable, Transferrable {

    event AddedController(address _sender, address _controller);
    event RemovedController(address _sender, address _controller);

    event AddedAdmin(address _sender, address _admin);
    event RemovedAdmin(address _sender, address _admin);

    event Claimed(address _to, address _asset, uint _amount);

    event Stopped(address _sender);
    event Started(address _sender);

    mapping (address => bool) private _isAdmin;
    uint private _adminCount;

    mapping (address => bool) private _isController;
    uint private _controllerCount;

    bool private _stopped;

    /// @notice Constructor initializes the owner with the provided address.
    /// @param _ownerAddress_ address of the owner.
    constructor(address payable _ownerAddress_) Ownable(_ownerAddress_, false) public {}

    /// @notice Checks if message sender is an admin.
    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "sender is not an admin");
        _;
    }

    /// @notice Check if Owner or Admin
    modifier onlyAdminOrOwner() {
        require(_isOwner(msg.sender) || isAdmin(msg.sender), "sender is not an admin");
        _;
    }

    /// @notice Check if controller is stopped
    modifier notStopped() {
        require(!isStopped(), "controller is stopped");
        _;
    }

    /// @notice Add a new admin to the list of admins.
    /// @param _account address to add to the list of admins.
    function addAdmin(address _account) external onlyOwner notStopped {
        _addAdmin(_account);
    }

    /// @notice Remove a admin from the list of admins.
    /// @param _account address to remove from the list of admins.
    function removeAdmin(address _account) external onlyOwner {
        _removeAdmin(_account);
    }

    /// @return the current number of admins.
    function adminCount() external view returns (uint) {
        return _adminCount;
    }

    /// @notice Add a new controller to the list of controllers.
    /// @param _account address to add to the list of controllers.
    function addController(address _account) external onlyAdminOrOwner notStopped {
        _addController(_account);
    }

    /// @notice Remove a controller from the list of controllers.
    /// @param _account address to remove from the list of controllers.
    function removeController(address _account) external onlyAdminOrOwner {
        _removeController(_account);
    }

    /// @notice count the Controllers
    /// @return the current number of controllers.
    function controllerCount() external view returns (uint) {
        return _controllerCount;
    }

    /// @notice is an address an Admin?
    /// @return true if the provided account is an admin.
    function isAdmin(address _account) public view notStopped returns (bool) {
        return _isAdmin[_account];
    }

    /// @notice is an address a Controller?
    /// @return true if the provided account is a controller.
    function isController(address _account) public view notStopped returns (bool) {
        return _isController[_account];
    }

    /// @notice this function can be used to see if the controller has been stopped
    /// @return true is the Controller has been stopped
    function isStopped() public view returns (bool) {
        return _stopped;
    }

    /// @notice Internal-only function that adds a new admin.
    function _addAdmin(address _account) private {
        require(!_isAdmin[_account], "provided account is already an admin");
        require(!_isController[_account], "provided account is already a controller");
        require(!_isOwner(_account), "provided account is already the owner");
        require(_account != address(0), "provided account is the zero address");
        _isAdmin[_account] = true;
        _adminCount++;
        emit AddedAdmin(msg.sender, _account);
    }

    /// @notice Internal-only function that removes an existing admin.
    function _removeAdmin(address _account) private {
        require(_isAdmin[_account], "provided account is not an admin");
        _isAdmin[_account] = false;
        _adminCount--;
        emit RemovedAdmin(msg.sender, _account);
    }

    /// @notice Internal-only function that adds a new controller.
    function _addController(address _account) private {
        require(!_isAdmin[_account], "provided account is already an admin");
        require(!_isController[_account], "provided account is already a controller");
        require(!_isOwner(_account), "provided account is already the owner");
        require(_account != address(0), "provided account is the zero address");
        _isController[_account] = true;
        _controllerCount++;
        emit AddedController(msg.sender, _account);
    }

    /// @notice Internal-only function that removes an existing controller.
    function _removeController(address _account) private {
        require(_isController[_account], "provided account is not a controller");
        _isController[_account] = false;
        _controllerCount--;
        emit RemovedController(msg.sender, _account);
    }

    /// @notice stop our controllers and admins from being useable
    function stop() external onlyAdminOrOwner {
        _stopped = true;
        emit Stopped(msg.sender);
    }

    /// @notice start our controller again
    function start() external onlyOwner {
        _stopped = false;
        emit Started(msg.sender);
    }

    //// @notice Withdraw tokens from the smart contract to the specified account.
    function claim(address payable _to, address _asset, uint _amount) external onlyAdmin notStopped {
        _safeTransfer(_to, _asset, _amount);
        emit Claimed(_to, _asset, _amount);
    }
}

pragma solidity ^0.5.10;

/// @title ERC20 interface is a subset of the ERC20 specification.
/// @notice see https://github.com/ethereum/EIPs/issues/20
interface ERC20 {
    function allowance(address _owner, address _spender) external view returns (uint256);
    function approve(address _spender, uint256 _value) external returns (bool);
    function balanceOf(address _who) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
}

/**
 *  Ownable - The Consumer Contract Wallet
 *  Copyright (C) 2019 The Contract Wallet Company Limited
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.

 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.

 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.5.10;


/// @title Ownable has an owner address and provides basic authorization control functions.
/// This contract is modified version of the MIT OpenZepplin Ownable contract
/// This contract allows for the transferOwnership operation to be made impossible
/// https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/ownership/Ownable.sol
contract Ownable {
    event TransferredOwnership(address _from, address _to);
    event LockedOwnership(address _locked);

    address payable private _owner;
    bool private _isTransferable;

    /// @notice Constructor sets the original owner of the contract and whether or not it is one time transferable.
    constructor(address payable _account_, bool _transferable_) internal {
        _owner = _account_;
        _isTransferable = _transferable_;
        // Emit the LockedOwnership event if no longer transferable.
        if (!_isTransferable) {
            emit LockedOwnership(_account_);
        }
        emit TransferredOwnership(address(0), _account_);
    }

    /// @notice Reverts if called by any account other than the owner.
    modifier onlyOwner() {
        require(_isOwner(msg.sender), "sender is not an owner");
        _;
    }

    /// @notice Allows the current owner to transfer control of the contract to a new address.
    /// @param _account address to transfer ownership to.
    /// @param _transferable indicates whether to keep the ownership transferable.
    function transferOwnership(address payable _account, bool _transferable) external onlyOwner {
        // Require that the ownership is transferable.
        require(_isTransferable, "ownership is not transferable");
        // Require that the new owner is not the zero address.
        require(_account != address(0), "owner cannot be set to zero address");
        // Set the transferable flag to the value _transferable passed in.
        _isTransferable = _transferable;
        // Emit the LockedOwnership event if no longer transferable.
        if (!_transferable) {
            emit LockedOwnership(_account);
        }
        // Emit the ownership transfer event.
        emit TransferredOwnership(_owner, _account);
        // Set the owner to the provided address.
        _owner = _account;
    }

    /// @notice check if the ownership is transferable.
    /// @return true if the ownership is transferable.
    function isTransferable() external view returns (bool) {
        return _isTransferable;
    }

    /// @notice Allows the current owner to relinquish control of the contract.
    /// @dev Renouncing to ownership will leave the contract without an owner and unusable.
    /// @dev It will not be possible to call the functions with the `onlyOwner` modifier anymore.
    function renounceOwnership() external onlyOwner {
        // Require that the ownership is transferable.
        require(_isTransferable, "ownership is not transferable");
        // note that this could be terminal
        _owner = address(0);

        emit TransferredOwnership(_owner, address(0));
    }

    /// @notice Find out owner address
    /// @return address of the owner.
    function owner() public view returns (address payable) {
        return _owner;
    }

    /// @notice Check if owner address
    /// @return true if sender is the owner of the contract.
    function _isOwner(address _address) internal view returns (bool) {
        return _address == _owner;
    }
}

/**
 * The MIT License (MIT)
 *
 * Copyright (c) 2016-2019 zOS Global Limited
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

pragma solidity ^0.5.0;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Address.sol";

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

    function safeTransfer(ERC20 token, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(ERC20 token, address from, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(ERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(ERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(ERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function callOptionalReturn(ERC20 token, bytes memory data) internal {
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
        require(b <= a, "SafeMath: subtraction overflow");
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
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
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
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
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
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

/**
 *  Transferrable - The Consumer Contract Wallet
 *  Copyright (C) 2019 The Contract Wallet Company Limited
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.

 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.

 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity ^0.5.10;

import "./ERC20.sol";
import "./SafeERC20.sol";


/// @title SafeTransfer, allowing contract to withdraw tokens accidentally sent to itself
contract Transferrable {

    using SafeERC20 for ERC20;


    /// @dev This function is used to move tokens sent accidentally to this contract method.
    /// @dev The owner can chose the new destination address
    /// @param _to is the recipient's address.
    /// @param _asset is the address of an ERC20 token or 0x0 for ether.
    /// @param _amount is the amount to be transferred in base units.
    function _safeTransfer(address payable _to, address _asset, uint _amount) internal {
        // address(0) is used to denote ETH
        if (_asset == address(0)) {
            _to.transfer(_amount);
        } else {
            ERC20(_asset).safeTransfer(_to, _amount);
        }
    }
}

