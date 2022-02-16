
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";



contract stakeing is Ownable , IERC721Receiver,ReentrancyGuard{

    address  nftAddress = 0x3F916867A9f38aa68aD7583C7360f83387d06dAf;
    address  erc20Address =  0xf4d2888d29D722226FafA5d9B24F9164c092421E;

    uint8 public singlehashrate = 2 ;
    uint8 public doublehashrate = 5 ;
    uint8 public pairhashrate = 10 ;

    mapping(address => uint256[] ) public stakedEyeStarIds30;
    mapping(address => uint256[] ) public stakedEyeStarIds60;

    mapping(address => uint256) public hashrate30;
    mapping(address => uint256) public hashrate60;

    uint256 public totalhashrate30;
    uint256 public totalhashrate60;

    uint256 public amonut30;
    uint256 public amonut60;

    uint256 public stakeStartdate;

    bool public claimLive30; 
    bool public claimLive60; 
    bool public stakeLive; 
    bool public depositLive = true; 


    constructor() {
        stakeStartdate = block.timestamp;
    }

    function toggleClaimLive30() external onlyOwner {
        claimLive30 = !claimLive30;
    }

    function toggleClaimLive60() external onlyOwner {
        claimLive60 = !claimLive60;
    }

    function toggleDepositLivee() external onlyOwner {
        depositLive = !depositLive;
    }

    function setAmount30(uint256 amonut) external onlyOwner {
        amonut30 = amonut;
    }

    function setAmount60(uint256 amonut) external onlyOwner {
        amonut60 = amonut;
    }

    function set20Address(address erc20) external onlyOwner {
        erc20Address = erc20;
    }

    function confirmHashrate(uint256 amount) public onlyOwner {
      amonut30 = ( totalhashrate30 * 100 / ( totalhashrate30 + totalhashrate60 ) ) * amount / 100;
      amonut60 = amount - amonut30;
      stakeLive = !stakeLive; 
      stakeStartdate = block.timestamp;
    }


    function deposit(uint256[] memory single,uint256[2][] memory double,uint256 lockMod) external {
        require(lockMod==1 || lockMod ==2, "lockMod abnormal");
        require(depositLive, "deposit end");

        if(single.length>0) {
             _deposit(single,lockMod);
        }
        if(double.length>0) {
            _depositDouble(double,lockMod);
        }
    }


    function _deposit(uint256[] memory eyeStarIds,uint256 lockMod) private {
        uint256 hashrate;
        for(uint256 i = 0; i < eyeStarIds.length ; i++){
            uint256 eyeStarId = eyeStarIds[i];
            IERC721(nftAddress).safeTransferFrom(msg.sender,address(this),eyeStarId);
            hashrate +=singlehashrate;

            if(lockMod == 1){
                stakedEyeStarIds30[msg.sender].push(eyeStarId);
            }else{
                stakedEyeStarIds60[msg.sender].push(eyeStarId);
            }
        }

        if(lockMod == 1){
            hashrate30[msg.sender] += hashrate;
            totalhashrate30 += hashrate;
        }else{
            hashrate60[msg.sender] += hashrate;
            totalhashrate60 += hashrate;
        }  
    }

    function _depositDouble(uint256[2][] memory eyeStarIds,uint256 lockMod) private {

        for(uint256 i = 0; i < eyeStarIds.length ; i++){
            uint256 leftId = eyeStarIds[i][0];
            uint256 rightId = eyeStarIds[i][1];
            require(leftId!=0 && rightId!=0, "direction error1");
            require(leftId<=3605, "direction error2");
            require(rightId>3605, "direction error3");
        }

        uint256 stakeType;
        uint256 hashrate;
        for(uint256 i = 0; i < eyeStarIds.length ; i++){
            uint256 leftId = eyeStarIds[i][0];
            uint256 rightId = eyeStarIds[i][1];

            IERC721(nftAddress).safeTransferFrom(msg.sender,address(this),leftId);
            IERC721(nftAddress).safeTransferFrom(msg.sender,address(this),rightId);
            if(leftId+rightId == 7212){
                hashrate += pairhashrate;
                stakeType = 3;
            }else{
                hashrate += doublehashrate;
                stakeType = 2;
            }
          
            if(lockMod == 1){
                stakedEyeStarIds30[msg.sender].push(leftId);
                stakedEyeStarIds30[msg.sender].push(rightId);
            }else{
                stakedEyeStarIds60[msg.sender].push(leftId);
                stakedEyeStarIds60[msg.sender].push(rightId);
            }
        }

        if(lockMod == 1){
                hashrate30[msg.sender] += hashrate;
                totalhashrate30 += hashrate;
            }else{
                hashrate60[msg.sender] += hashrate;
                totalhashrate60 += hashrate;
        }  
    }

    function unstake30()  public  nonReentrant() {
        
        for (uint256 i; i < stakedEyeStarIds30[msg.sender].length; i++) {
            uint256 tokenId = stakedEyeStarIds30[msg.sender][i];
            IERC721(nftAddress).safeTransferFrom(address(this), msg.sender,tokenId);
        }   

        delete stakedEyeStarIds30[msg.sender];

         if(!stakeLive){
                totalhashrate30 -= hashrate30[msg.sender];
         }
         hashrate30[msg.sender] = 0;
    }


    function unstake60()  public  nonReentrant() {

        for (uint256 i; i < stakedEyeStarIds60[msg.sender].length; i++) {
            uint256 tokenId = stakedEyeStarIds60[msg.sender][i];
            IERC721(nftAddress).safeTransferFrom(address(this), msg.sender,tokenId);
        }   

        delete stakedEyeStarIds60[msg.sender];

        if(!stakeLive){
            totalhashrate60 -= hashrate60[msg.sender];
        }
        hashrate60[msg.sender] = 0;
    }


    function _claimToken(uint256 lockMod) private {
        uint256 reward ;
        if(lockMod==1 ){
            reward = amonut30 / totalhashrate30  *  hashrate30[msg.sender];
            unstake30();
        }else{
            reward = amonut60 / totalhashrate60  *  hashrate60[msg.sender];
            unstake60();
        }
        IERC20(erc20Address).transfer(msg.sender, reward);
    }

    function expirationDate30 () external view returns (bool){
        return stakeStartdate + 30 days <= block.timestamp || claimLive30;
    }

    function expirationDate60 () external view returns (bool){
        return stakeStartdate + 60 days <= block.timestamp || claimLive60;
    }

    function claimAndWithdraw30() external  {
        require( stakeStartdate + 30 days <= block.timestamp || claimLive30, "claim_closed");
        require(hashrate30[msg.sender] > 0, "not hashrate");
        _claimToken(1);
    }

    function claimAndWithdraw60() external   {
        require( stakeStartdate + 60 days <= block.timestamp || claimLive60, "claim_closed");
        require(hashrate60[msg.sender] > 0, "not hashrate");
        _claimToken(2);

    }

    function numberOfStaked(address user, uint256 lockMod) external view returns (uint256) {

        if(lockMod==1 ){
            return (stakedEyeStarIds30[user].length);
        }else{
            return (stakedEyeStarIds60[user].length);
        }
    }

    function withdrawTokens() external onlyOwner {
        uint256 tokenSupply = IERC20(erc20Address).balanceOf(address(this));
        IERC20(erc20Address).transfer(msg.sender, tokenSupply);
    }

    function onERC721Received(address,address,uint256,bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }



}
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

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
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
