
//SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "./SeedPhrasePricing.sol";
import "../interfaces/IN.sol";
import "../interfaces/IRarible.sol";
import "../interfaces/IKarmaScore.sol";
import "../interfaces/INOwnerResolver.sol";
import "../libraries/NilProtocolUtils.sol";
import "../libraries/SeedPhraseUtils.sol";

////////////////////////////////////////////////////////////////////////////////////////
//                                                                                    //
//                                                                                    //
// ░██████╗███████╗███████╗██████╗░  ██████╗░██╗░░██╗██████╗░░█████╗░░██████╗███████╗ //
// ██╔════╝██╔════╝██╔════╝██╔══██╗  ██╔══██╗██║░░██║██╔══██╗██╔══██╗██╔════╝██╔════╝ //
// ╚█████╗░█████╗░░█████╗░░██║░░██║  ██████╔╝███████║██████╔╝███████║╚█████╗░█████╗░░ //
// ░╚═══██╗██╔══╝░░██╔══╝░░██║░░██║  ██╔═══╝░██╔══██║██╔══██╗██╔══██║░╚═══██╗██╔══╝░░ //
// ██████╔╝███████╗███████╗██████╔╝  ██║░░░░░██║░░██║██║░░██║██║░░██║██████╔╝███████╗ //
// ╚═════╝░╚══════╝╚══════╝╚═════╝░  ╚═╝░░░░░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚═╝╚═════╝░╚══════╝ //
//                                                                                    //
//                                                                                    //
//  Title: Seed Phrase                                                                //
//  Devs: Harry Faulkner & maximonee (twitter.com/maximonee_)                         //
//  Description: This contract provides minting for the                               //
//               Seed Phrase NFT by Sean Elliott                                      //
//               (twitter.com/seanelliottoc)                                          //
//                                                                                    //
////////////////////////////////////////////////////////////////////////////////////////

contract SeedPhrase is SeedPhrasePricing, VRFConsumerBase {
    using Strings for uint256;
    using Strings for uint16;
    using Strings for uint8;
    using Counters for Counters.Counter;
    using SeedPhraseUtils for SeedPhraseUtils.Random;

    Counters.Counter private _doublePanelTokens;
    Counters.Counter private _tokenIds;

    address private _owner;

    // Tracks whether an n has been used already to mint
    mapping(uint256 => bool) public override nUsed;

    mapping(PreSaleType => uint16) public presaleLimits;

    address[] private genesisSketchAddresses;
    uint16[] private bipWordIds = new uint16[](2048);

    IRarible public immutable rarible;
    INOwnerResolver public immutable nOwnerResolver;
    IKarmaScore public immutable karma;

    struct Maps {
        // Map double panel tokens to burned singles
        mapping(uint256 => uint256[2]) burnedTokensPairings;
        // Mapping of valid double panel pairings (BIP39 IDs)
        mapping(uint16 => uint16) doubleWordPairings;
        // Stores the guarenteed token rarity for a double panel
        mapping(uint256 => uint8) doubleTokenRarity;
        mapping(address => bool) ogAddresses;
        // Map token to their unique seed
        mapping(uint256 => bytes32) tokenSeed;
    }

    struct Config {
        bool preSaleActive;
        bool publicSaleActive;
        bool isSaleHalted;
        bool bipWordsShuffled;
        bool vrfNumberGenerated;
        bool isBurnActive;
        bool isOwnerSupplyMinted;
        bool isGsAirdropComplete;
        uint8 ownerSupply;
        uint16 maxPublicMint;
        uint16 karmaRequirement;
        uint32 preSaleLaunchTime;
        uint32 publicSaleLaunchTime;
        uint256 doubleBurnTokens;
        uint256 linkFee;
        uint256 raribleTokenId;
        uint256 vrfRandomValue;
        address vrfCoordinator;
        address linkToken;
        bytes32 vrfKeyHash;
    }

    struct ContractAddresses {
        address n;
        address masterMint;
        address dao;
        address nOwnersRegistry;
        address vrfCoordinator;
        address linkToken;
        address karmaAddress;
        address rarible;
    }

    Config private config;
    Maps private maps;

    event Burnt(address to, uint256 firstBurntToken, uint256 secondBurntToken, uint256 doublePaneledToken);

    DerivativeParameters params = DerivativeParameters(false, false, 0, 2048, 4);

    constructor(
        ContractAddresses memory contractAddresses,
        bytes32 _vrfKeyHash,
        uint256 _linkFee
    )
        SeedPhrasePricing(
            "Seed Phrase",
            "SEED",
            IN(contractAddresses.n),
            params,
            30000000000000000,
            60000000000000000,
            contractAddresses.masterMint,
            contractAddresses.dao
        )
        VRFConsumerBase(contractAddresses.vrfCoordinator, contractAddresses.linkToken)
    {
        // Start token IDs at 1
        _tokenIds.increment();

        presaleLimits[PreSaleType.N] = 400;
        presaleLimits[PreSaleType.Karma] = 800;
        presaleLimits[PreSaleType.GenesisSketch] = 40;
        presaleLimits[PreSaleType.OG] = 300;
        presaleLimits[PreSaleType.GM] = 300;

        nOwnerResolver = INOwnerResolver(contractAddresses.nOwnersRegistry);
        rarible = IRarible(contractAddresses.rarible);
        karma = IKarmaScore(contractAddresses.karmaAddress);

        // Initialize Config struct
        config.maxPublicMint = 8;
        config.ownerSupply = 20;
        config.preSaleLaunchTime = 1639591200;
        config.publicSaleLaunchTime = 1639598400;
        config.raribleTokenId = 706480;
        config.karmaRequirement = 1020;

        config.vrfCoordinator = contractAddresses.vrfCoordinator;
        config.linkToken = contractAddresses.linkToken;
        config.linkFee = _linkFee;
        config.vrfKeyHash = _vrfKeyHash;

        _owner = 0x7F05F27CC5D83C3e879C53882de13Cc1cbCe8a8c;
    }

    function owner() external view virtual returns (address) {
        return _owner;
    }

    function setOwner(address owner_) external onlyAdmin {
        _owner = owner_;
    }

    function contractURI() public pure returns (string memory) {
        return "https://www.seedphrase.codes/metadata/seedphrase-metadata.json";
    }

    function getVrfSeed() external onlyAdmin returns (bytes32) {
        require(!config.vrfNumberGenerated, "SP:VRF_ALREADY_CALLED");
        require(LINK.balanceOf(address(this)) >= config.linkFee, "SP:NOT_ENOUGH_LINK");
        return requestRandomness(config.vrfKeyHash, config.linkFee);
    }

    function fulfillRandomness(bytes32, uint256 randomNumber) internal override {
        config.vrfRandomValue = randomNumber;
        config.vrfNumberGenerated = true;
    }

    function _getTokenSeed(uint256 tokenId) internal view returns (bytes32) {
        return maps.tokenSeed[tokenId];
    }

    function _getBipWordIdFromTokenId(uint256 tokenId) internal view returns (uint16) {
        return bipWordIds[tokenId - 1];
    }

    function tokenSVG(uint256 tokenId) public view virtual returns (string memory svg, bytes memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        SeedPhraseUtils.Random memory random = SeedPhraseUtils.Random({
            seed: uint256(_getTokenSeed(tokenId)),
            offsetBit: 0
        });

        uint16 bipWordId;
        uint16 secondBipWordId = 0;
        uint8 rarityValue = 0;
        if (tokenId >= 3000) {
            uint256[2] memory tokens = maps.burnedTokensPairings[tokenId];
            bipWordId = _getBipWordIdFromTokenId(tokens[0]);
            secondBipWordId = _getBipWordIdFromTokenId(tokens[1]);
            rarityValue = maps.doubleTokenRarity[tokenId];
        } else {
            bipWordId = _getBipWordIdFromTokenId(tokenId);
        }

        (bytes memory traits, SeedPhraseUtils.Attrs memory attributes) = SeedPhraseUtils.getTraitsAndAttributes(
            bipWordId,
            secondBipWordId,
            rarityValue,
            random
        );

        return (SeedPhraseUtils.render(random, attributes), traits);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        (string memory output, bytes memory traits) = tokenSVG(tokenId);

        return SeedPhraseUtils.getTokenURI(output, traits, tokenId);
    }

    /**
    Updates the presale state for n holders
     */
    function setPreSaleState(bool _preSaleActiveState) external onlyAdmin {
        config.preSaleActive = _preSaleActiveState;
    }

    /**
    Updates the public sale state for non-n holders
     */
    function setPublicSaleState(bool _publicSaleActiveState) external onlyAdmin {
        config.publicSaleActive = _publicSaleActiveState;
    }

    function setPreSaleTime(uint32 _time) external onlyAdmin {
        config.preSaleLaunchTime = _time;
    }

    function setPublicSaleTime(uint32 _time) external onlyAdmin {
        config.publicSaleLaunchTime = _time;
    }

    /**
    Give the ability to halt the sale if necessary due to automatic sale enablement based on time
     */
    function setSaleHaltedState(bool _saleHaltedState) external onlyAdmin {
        config.isSaleHalted = _saleHaltedState;
    }

    function setBurnActiveState(bool _burnActiveState) external onlyAdmin {
        config.isBurnActive = _burnActiveState;
    }

    function setGenesisSketchAllowList(address[] calldata addresses) external onlyAdmin {
        genesisSketchAddresses = addresses;
    }

    function setOgAllowList(address[] calldata addresses) external onlyAdmin {
        for (uint256 i = 0; i < addresses.length; i++) {
            maps.ogAddresses[addresses[i]] = true;
        }
    }

    function _isPreSaleActive() internal view returns (bool) {
        return ((block.timestamp >= config.preSaleLaunchTime || config.preSaleActive) && !config.isSaleHalted);
    }

    function _isPublicSaleActive() internal view override returns (bool) {
        return ((block.timestamp >= config.publicSaleLaunchTime || config.publicSaleActive) && !config.isSaleHalted);
    }

    function _canMintPresale(
        address addr,
        uint256 amount,
        bytes memory data
    ) internal view override returns (bool, PreSaleType) {
        if (maps.ogAddresses[addr] && presaleLimits[PreSaleType.OG] - amount >= 0) {
            return (true, PreSaleType.OG);
        }

        bool isGsHolder;
        for (uint256 i = 0; i < genesisSketchAddresses.length; i++) {
            if (genesisSketchAddresses[i] == addr) {
                isGsHolder = true;
            }
        }

        if (isGsHolder && presaleLimits[PreSaleType.GenesisSketch] - amount >= 0) {
            return (true, PreSaleType.GenesisSketch);
        }

        if (rarible.balanceOf(addr, config.raribleTokenId) > 0 && presaleLimits[PreSaleType.GM] - amount > 0) {
            return (true, PreSaleType.GM);
        }

        uint256 karmaScore = SeedPhraseUtils.getKarma(karma, data, addr);
        if (nOwnerResolver.balanceOf(addr) > 0) {
            if (karmaScore >= config.karmaRequirement && presaleLimits[PreSaleType.Karma] - amount >= 0) {
                return (true, PreSaleType.Karma);
            }

            if (presaleLimits[PreSaleType.N] - amount >= 0) {
                return (true, PreSaleType.N);
            }
        }

        return (false, PreSaleType.None);
    }

    function canMint(address account, bytes calldata data) public view virtual override returns (bool) {
        if (config.isBurnActive) {
            return false;
        }

        uint256 balance = balanceOf(account);

        if (_isPublicSaleActive() && (totalMintsAvailable() > 0) && balance < config.maxPublicMint) {
            return true;
        }

        if (_isPreSaleActive()) {
            (bool preSaleEligible, ) = _canMintPresale(account, 1, data);
            return preSaleEligible;
        }

        return false;
    }

    /**
     * @notice Allow a n token holder to bulk mint tokens with id of their n tokens' id
     * @param recipient Recipient of the mint
     * @param tokenIds Ids to be minted
     * @param paid Amount paid for the mint
     */
    function mintWithN(
        address recipient,
        uint256[] calldata tokenIds,
        uint256 paid,
        bytes calldata data
    ) public virtual override nonReentrant {
        uint256 maxTokensToMint = tokenIds.length;
        (bool preSaleEligible, PreSaleType presaleType) = _canMintPresale(recipient, maxTokensToMint, data);

        require(config.bipWordsShuffled && config.vrfNumberGenerated, "SP:ENV_NOT_INIT");
        require(_isPublicSaleActive() || (_isPreSaleActive() && preSaleEligible), "SP:SALE_NOT_ACTIVE");
        require(
            balanceOf(recipient) + maxTokensToMint <= _getMaxMintPerWallet(),
            "NilPass:MINT_ABOVE_MAX_MINT_ALLOWANCE"
        );
        require(!config.isBurnActive, "SP:SALE_OVER");

        require(totalSupply() + maxTokensToMint <= params.maxTotalSupply, "NilPass:MAX_ALLOCATION_REACHED");

        uint256 price = getNextPriceForNHoldersInWei(maxTokensToMint, recipient, data);
        require(paid == price, "NilPass:INVALID_PRICE");

        for (uint256 i = 0; i < maxTokensToMint; i++) {
            require(!nUsed[tokenIds[i]], "SP:N_ALREADY_USED");

            uint256 tokenId = _tokenIds.current();
            require(tokenId <= params.maxTotalSupply, "SP:TOKEN_TOO_HIGH");

            maps.tokenSeed[tokenId] = SeedPhraseUtils.generateSeed(tokenId, config.vrfRandomValue);

            _safeMint(recipient, tokenId);
            _tokenIds.increment();

            nUsed[tokenIds[i]] = true;
        }

        if (preSaleEligible) {
            presaleLimits[presaleType] -= uint16(maxTokensToMint);
        }
    }

    /**
     * @notice Allow anyone to mint a token with the supply id if this pass is unrestricted.
     *         n token holders can use this function without using the n token holders allowance,
     *         this is useful when the allowance is fully utilized.
     * @param recipient Recipient of the mint
     * @param amount Amount of tokens to mint
     * @param paid Amount paid for the mint
     */
    function mint(
        address recipient,
        uint8 amount,
        uint256 paid,
        bytes calldata data
    ) public virtual override nonReentrant {
        (bool preSaleEligible, PreSaleType presaleType) = _canMintPresale(recipient, amount, data);

        require(config.bipWordsShuffled && config.vrfNumberGenerated, "SP:ENV_NOT_INIT");
        require(
            _isPublicSaleActive() ||
                (_isPreSaleActive() &&
                    preSaleEligible &&
                    (presaleType != PreSaleType.N && presaleType != PreSaleType.Karma)),
            "SP:SALE_NOT_ACTIVE"
        );
        require(!config.isBurnActive, "SP:SALE_OVER");

        require(balanceOf(recipient) + amount <= _getMaxMintPerWallet(), "NilPass:MINT_ABOVE_MAX_MINT_ALLOWANCE");
        require(totalSupply() + amount <= params.maxTotalSupply, "NilPass:MAX_ALLOCATION_REACHED");

        uint256 price = getNextPriceForOpenMintInWei(amount, recipient, data);
        require(paid == price, "NilPass:INVALID_PRICE");

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIds.current();
            require(tokenId <= params.maxTotalSupply, "SP:TOKEN_TOO_HIGH");
            maps.tokenSeed[tokenId] = SeedPhraseUtils.generateSeed(tokenId, config.vrfRandomValue);

            _safeMint(recipient, tokenId);
            _tokenIds.increment();
        }

        if (preSaleEligible) {
            presaleLimits[presaleType] -= amount;
        }
    }

    function mintOwnerSupply(address account) public nonReentrant onlyAdmin {
        require(!config.isOwnerSupplyMinted, "SP:ALREADY_MINTED");
        require(config.bipWordsShuffled && config.vrfNumberGenerated, "SP:ENV_NOT_INIT");
        require(
            totalSupply() + config.ownerSupply <= params.maxTotalSupply,
            "NilPass:MAX_ALLOCATION_REACHED"
        );

        for (uint256 i = 0; i < config.ownerSupply; i++) {
            uint256 tokenId = _tokenIds.current();
            maps.tokenSeed[tokenId] = SeedPhraseUtils.generateSeed(tokenId, config.vrfRandomValue);

            _mint(account, tokenId);
            _tokenIds.increment();
        }

        config.isOwnerSupplyMinted = true;
    }

    /**
     * @notice Allow anyone to burn two single panels they own in order to mint
     *         a double paneled token.
     * @param firstTokenId Token ID of the first token
     * @param secondTokenId Token ID of the second token
     */
    function burnForDoublePanel(uint256 firstTokenId, uint256 secondTokenId) public nonReentrant {
        require(config.isBurnActive, "SP:BURN_INACTIVE");
        require(ownerOf(firstTokenId) == msg.sender && ownerOf(secondTokenId) == msg.sender, "SP:INCORRECT_OWNER");
        require(firstTokenId != secondTokenId, "SP:EQUAL_TOKENS");
        // Ensure two owned tokens are in Burnable token pairings
        require(
            isValidPairing(_getBipWordIdFromTokenId(firstTokenId), _getBipWordIdFromTokenId(secondTokenId)),
            "SP:INVALID_TOKEN_PAIRING"
        );

        _burn(firstTokenId);
        _burn(secondTokenId);

        // Any Token ID of 3000 or greater indicates it is a double panel e.g. 3000, 3001, 3002...
        uint256 doublePanelTokenId = 3000 + _doublePanelTokens.current();
        maps.tokenSeed[doublePanelTokenId] = SeedPhraseUtils.generateSeed(doublePanelTokenId, config.vrfRandomValue);

        // Get the rarity rating from the burned tokens, store this against the new token
        // Burners are guaranteed their previous strongest trait (at least, could be rarer)
        uint8 rarity1 = SeedPhraseUtils.getRarityRating(_getTokenSeed(firstTokenId));
        uint8 rarity2 = SeedPhraseUtils.getRarityRating(_getTokenSeed(secondTokenId));
        maps.doubleTokenRarity[doublePanelTokenId] = (rarity1 > rarity2 ? rarity1 : rarity2);

        _mint(msg.sender, doublePanelTokenId);

        // Add burned tokens to maps.burnedTokensPairings mapping so we can use them to render the double panels later
        maps.burnedTokensPairings[doublePanelTokenId] = [firstTokenId, secondTokenId];
        _doublePanelTokens.increment();

        emit Burnt(msg.sender, firstTokenId, secondTokenId, doublePanelTokenId);
    }

    function airdropGenesisSketch() public nonReentrant onlyAdmin {
        require(!config.isGsAirdropComplete, "SP:ALREADY_AIRDROPPED");
        require(config.bipWordsShuffled && config.vrfNumberGenerated, "SP:ENV_NOT_INIT");

        uint256 airdropAmount = genesisSketchAddresses.length;
        require(totalSupply() + airdropAmount <= params.maxTotalSupply, "NilPass:MAX_ALLOCATION_REACHED");

        for (uint256 i = 0; i < airdropAmount; i++) {
            uint256 tokenId = _tokenIds.current();
            maps.tokenSeed[tokenId] = SeedPhraseUtils.generateSeed(tokenId, config.vrfRandomValue);

            _mint(genesisSketchAddresses[i], tokenId);
            _tokenIds.increment();
        }

        config.isGsAirdropComplete = true;
    }

    function mintOrphanedPieces(uint256 amount, address addr) public nonReentrant onlyAdmin {
        require(totalMintsAvailable() == 0, "SP:MINT_NOT_OVER");
        
        // _tokenIds - 1 to get the current number of minted tokens (token IDs start at 1)
        uint256 currentSupply = _tokenIds.current() - 1;

        config.doubleBurnTokens = derivativeParams.maxTotalSupply - currentSupply;

        require(config.doubleBurnTokens >= amount, "SP:NOT_ENOUGH_ORPHANS");
        require(currentSupply + amount <= params.maxTotalSupply, "NilPass:MAX_ALLOCATION_REACHED");

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _tokenIds.current();
            require(tokenId <= params.maxTotalSupply, "SP:TOKEN_TOO_HIGH");

            maps.tokenSeed[tokenId] = SeedPhraseUtils.generateSeed(tokenId, config.vrfRandomValue);

            _mint(addr, tokenId);
            _tokenIds.increment();
        }

        config.doubleBurnTokens -= amount;
    }

    /**
     * @notice Calculate the total available number of mints
     * @return total mint available
     */
    function totalMintsAvailable() public view override returns (uint256) {
        uint256 totalAvailable = derivativeParams.maxTotalSupply - totalSupply();
        if (block.timestamp > config.publicSaleLaunchTime + 18 hours) {
            // Double candle burning starts and decreases max. mintable supply with 1 token per minute.
            uint256 doubleBurn = (block.timestamp - (config.publicSaleLaunchTime + 18 hours)) / 1 minutes;
            totalAvailable = totalAvailable > doubleBurn ? totalAvailable - doubleBurn : 0;
        }

        return totalAvailable;
    }

    function getDoubleBurnedTokens() external view returns (uint256) {
        return config.doubleBurnTokens;
    }

    function _getMaxMintPerWallet() internal view returns (uint128) {
        return _isPublicSaleActive() ? config.maxPublicMint : params.maxMintAllowance;
    }

    function isValidPairing(uint16 first, uint16 second) public view returns (bool) {
        return maps.doubleWordPairings[first] == second;
    }

    function amendPairings(uint16[][] calldata pairings) external onlyAdmin {
        for (uint16 i = 0; i < pairings.length; i++) {
            if (pairings[i].length != 2) {
                continue;
            }

            maps.doubleWordPairings[pairings[i][0]] = pairings[i][1];
        }
    }

    function shuffleBipWords() external onlyAdmin {
        require(config.vrfNumberGenerated, "SP:VRF_NOT_CALLED");
        require(!config.bipWordsShuffled, "SP:ALREADY_SHUFFLED");
        bipWordIds = SeedPhraseUtils.shuffleBipWords(config.vrfRandomValue);
        config.bipWordsShuffled = true;
    }
}

// SPDX-License-Identifier: MIT

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
     * by making the `nonReentrant` function external, and make it call a
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

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/LinkTokenInterface.sol";

import "./VRFRequestIDBase.sol";

/** ****************************************************************************
 * @notice Interface for contracts using VRF randomness
 * *****************************************************************************
 * @dev PURPOSE
 *
 * @dev Reggie the Random Oracle (not his real job) wants to provide randomness
 * @dev to Vera the verifier in such a way that Vera can be sure he's not
 * @dev making his output up to suit himself. Reggie provides Vera a public key
 * @dev to which he knows the secret key. Each time Vera provides a seed to
 * @dev Reggie, he gives back a value which is computed completely
 * @dev deterministically from the seed and the secret key.
 *
 * @dev Reggie provides a proof by which Vera can verify that the output was
 * @dev correctly computed once Reggie tells it to her, but without that proof,
 * @dev the output is indistinguishable to her from a uniform random sample
 * @dev from the output space.
 *
 * @dev The purpose of this contract is to make it easy for unrelated contracts
 * @dev to talk to Vera the verifier about the work Reggie is doing, to provide
 * @dev simple access to a verifiable source of randomness.
 * *****************************************************************************
 * @dev USAGE
 *
 * @dev Calling contracts must inherit from VRFConsumerBase, and can
 * @dev initialize VRFConsumerBase's attributes in their constructor as
 * @dev shown:
 *
 * @dev   contract VRFConsumer {
 * @dev     constuctor(<other arguments>, address _vrfCoordinator, address _link)
 * @dev       VRFConsumerBase(_vrfCoordinator, _link) public {
 * @dev         <initialization with other arguments goes here>
 * @dev       }
 * @dev   }
 *
 * @dev The oracle will have given you an ID for the VRF keypair they have
 * @dev committed to (let's call it keyHash), and have told you the minimum LINK
 * @dev price for VRF service. Make sure your contract has sufficient LINK, and
 * @dev call requestRandomness(keyHash, fee, seed), where seed is the input you
 * @dev want to generate randomness from.
 *
 * @dev Once the VRFCoordinator has received and validated the oracle's response
 * @dev to your request, it will call your contract's fulfillRandomness method.
 *
 * @dev The randomness argument to fulfillRandomness is the actual random value
 * @dev generated from your seed.
 *
 * @dev The requestId argument is generated from the keyHash and the seed by
 * @dev makeRequestId(keyHash, seed). If your contract could have concurrent
 * @dev requests open, you can use the requestId to track which seed is
 * @dev associated with which randomness. See VRFRequestIDBase.sol for more
 * @dev details. (See "SECURITY CONSIDERATIONS" for principles to keep in mind,
 * @dev if your contract could have multiple requests in flight simultaneously.)
 *
 * @dev Colliding `requestId`s are cryptographically impossible as long as seeds
 * @dev differ. (Which is critical to making unpredictable randomness! See the
 * @dev next section.)
 *
 * *****************************************************************************
 * @dev SECURITY CONSIDERATIONS
 *
 * @dev A method with the ability to call your fulfillRandomness method directly
 * @dev could spoof a VRF response with any random value, so it's critical that
 * @dev it cannot be directly called by anything other than this base contract
 * @dev (specifically, by the VRFConsumerBase.rawFulfillRandomness method).
 *
 * @dev For your users to trust that your contract's random behavior is free
 * @dev from malicious interference, it's best if you can write it so that all
 * @dev behaviors implied by a VRF response are executed *during* your
 * @dev fulfillRandomness method. If your contract must store the response (or
 * @dev anything derived from it) and use it later, you must ensure that any
 * @dev user-significant behavior which depends on that stored value cannot be
 * @dev manipulated by a subsequent VRF request.
 *
 * @dev Similarly, both miners and the VRF oracle itself have some influence
 * @dev over the order in which VRF responses appear on the blockchain, so if
 * @dev your contract could have multiple VRF requests in flight simultaneously,
 * @dev you must ensure that the order in which the VRF responses arrive cannot
 * @dev be used to manipulate your contract's user-significant behavior.
 *
 * @dev Since the ultimate input to the VRF is mixed with the block hash of the
 * @dev block in which the request is made, user-provided seeds have no impact
 * @dev on its economic security properties. They are only included for API
 * @dev compatability with previous versions of this contract.
 *
 * @dev Since the block hash of the block which contains the requestRandomness
 * @dev call is mixed into the input to the VRF *last*, a sufficiently powerful
 * @dev miner could, in principle, fork the blockchain to evict the block
 * @dev containing the request, forcing the request to be included in a
 * @dev different block with a different hash, and therefore a different input
 * @dev to the VRF. However, such an attack would incur a substantial economic
 * @dev cost. This cost scales with the number of blocks the VRF oracle waits
 * @dev until it calls responds to a request.
 */
abstract contract VRFConsumerBase is VRFRequestIDBase {

  /**
   * @notice fulfillRandomness handles the VRF response. Your contract must
   * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
   * @notice principles to keep in mind when implementing your fulfillRandomness
   * @notice method.
   *
   * @dev VRFConsumerBase expects its subcontracts to have a method with this
   * @dev signature, and will call it once it has verified the proof
   * @dev associated with the randomness. (It is triggered via a call to
   * @dev rawFulfillRandomness, below.)
   *
   * @param requestId The Id initially returned by requestRandomness
   * @param randomness the VRF output
   */
  function fulfillRandomness(
    bytes32 requestId,
    uint256 randomness
  )
    internal
    virtual;

  /**
   * @dev In order to keep backwards compatibility we have kept the user
   * seed field around. We remove the use of it because given that the blockhash
   * enters later, it overrides whatever randomness the used seed provides.
   * Given that it adds no security, and can easily lead to misunderstandings,
   * we have removed it from usage and can now provide a simpler API.
   */
  uint256 constant private USER_SEED_PLACEHOLDER = 0;

  /**
   * @notice requestRandomness initiates a request for VRF output given _seed
   *
   * @dev The fulfillRandomness method receives the output, once it's provided
   * @dev by the Oracle, and verified by the vrfCoordinator.
   *
   * @dev The _keyHash must already be registered with the VRFCoordinator, and
   * @dev the _fee must exceed the fee specified during registration of the
   * @dev _keyHash.
   *
   * @dev The _seed parameter is vestigial, and is kept only for API
   * @dev compatibility with older versions. It can't *hurt* to mix in some of
   * @dev your own randomness, here, but it's not necessary because the VRF
   * @dev oracle will mix the hash of the block containing your request into the
   * @dev VRF seed it ultimately uses.
   *
   * @param _keyHash ID of public key against which randomness is generated
   * @param _fee The amount of LINK to send with the request
   *
   * @return requestId unique ID for this request
   *
   * @dev The returned requestId can be used to distinguish responses to
   * @dev concurrent requests. It is passed as the first argument to
   * @dev fulfillRandomness.
   */
  function requestRandomness(
    bytes32 _keyHash,
    uint256 _fee
  )
    internal
    returns (
      bytes32 requestId
    )
  {
    LINK.transferAndCall(vrfCoordinator, _fee, abi.encode(_keyHash, USER_SEED_PLACEHOLDER));
    // This is the seed passed to VRFCoordinator. The oracle will mix this with
    // the hash of the block containing this request to obtain the seed/input
    // which is finally passed to the VRF cryptographic machinery.
    uint256 vRFSeed  = makeVRFInputSeed(_keyHash, USER_SEED_PLACEHOLDER, address(this), nonces[_keyHash]);
    // nonces[_keyHash] must stay in sync with
    // VRFCoordinator.nonces[_keyHash][this], which was incremented by the above
    // successful LINK.transferAndCall (in VRFCoordinator.randomnessRequest).
    // This provides protection against the user repeating their input seed,
    // which would result in a predictable/duplicate output, if multiple such
    // requests appeared in the same block.
    nonces[_keyHash] = nonces[_keyHash] + 1;
    return makeRequestId(_keyHash, vRFSeed);
  }

  LinkTokenInterface immutable internal LINK;
  address immutable private vrfCoordinator;

  // Nonces for each VRF key from which randomness has been requested.
  //
  // Must stay in sync with VRFCoordinator[_keyHash][this]
  mapping(bytes32 /* keyHash */ => uint256 /* nonce */) private nonces;

  /**
   * @param _vrfCoordinator address of VRFCoordinator contract
   * @param _link address of LINK token contract
   *
   * @dev https://docs.chain.link/docs/link-token-contracts
   */
  constructor(
    address _vrfCoordinator,
    address _link
  ) {
    vrfCoordinator = _vrfCoordinator;
    LINK = LinkTokenInterface(_link);
  }

  // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
  // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
  // the origin of the call
  function rawFulfillRandomness(
    bytes32 requestId,
    uint256 randomness
  )
    external
  {
    require(msg.sender == vrfCoordinator, "Only VRFCoordinator can fulfill");
    fulfillRandomness(requestId, randomness);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "../core/NilPassCore.sol";

abstract contract SeedPhrasePricing is NilPassCore {
    uint256 preSalePrice;
    uint256 publicSalePrice;

    constructor(
        string memory name,
        string memory symbol,
        IN n,
        DerivativeParameters memory derivativeParams,
        uint256 preSalePrice_,
        uint256 publicSalePrice_,
        address masterMint,
        address dao
    ) NilPassCore(name, symbol, n, derivativeParams, masterMint, dao) {
        preSalePrice = preSalePrice_;
        publicSalePrice = publicSalePrice_;
    }

    enum PreSaleType {
        GenesisSketch,
        OG,
        GM,
        Karma,
        N,
        None
    }

    function _canMintPresale(
        address addr,
        uint256 amount,
        bytes memory data
    ) internal view virtual returns (bool, PreSaleType);

    function _isPublicSaleActive() internal view virtual returns (bool);

    /**
     * @notice Returns the next price for an N mint
     */
    function getNextPriceForNHoldersInWei(
        uint256 numberOfMints,
        address account,
        bytes memory data
    ) public view override returns (uint256) {
        (bool preSaleEligible, ) = _canMintPresale(account, numberOfMints, data);
        uint256 price = preSaleEligible && !_isPublicSaleActive() ? preSalePrice : publicSalePrice;
        return numberOfMints * price;
    }

    /**
     * @notice Returns the next price for an open mint
     */
    function getNextPriceForOpenMintInWei(
        uint256 numberOfMints,
        address account,
        bytes memory data
    ) public view override returns (uint256) {
        (bool preSaleEligible, ) = _canMintPresale(account, numberOfMints, data);
        uint256 price = preSaleEligible && !_isPublicSaleActive() ? preSalePrice : publicSalePrice;
        return numberOfMints * price;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

interface IN is IERC721Enumerable, IERC721Metadata {
    function getFirst(uint256 tokenId) external view returns (uint256);

    function getSecond(uint256 tokenId) external view returns (uint256);

    function getThird(uint256 tokenId) external view returns (uint256);

    function getFourth(uint256 tokenId) external view returns (uint256);

    function getFifth(uint256 tokenId) external view returns (uint256);

    function getSixth(uint256 tokenId) external view returns (uint256);

    function getSeventh(uint256 tokenId) external view returns (uint256);

    function getEight(uint256 tokenId) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

interface IRarible is IERC721Enumerable, IERC721Metadata {
    function balanceOf(address _owner, uint256 _id) external view returns (uint256);
}

//SPDX-License-Identifier: MIT
/**
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ @@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(     (@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@           @@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(   @@@@@@@@@@@@@@@@@@@@(            @@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@@@@@             @@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@           @@@@@@@@@@@(            @@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@      @@@@@@@@@@@@             @@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ @@@@@@@@@@@(            @@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@     @@@@@@@     @@@@@@@             @@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@(         @@(         @@(            @@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@          @@          @@           @@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@     @@@@@@@     @@@@@@@     @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ @@@@@@@@@@@ @@@@@@@@@@@ @@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(     @@@@@@@     @@@@@@@     @@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@           @           @           @@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@(            @@@         @@@         @@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@             @@@@@@@     @@@@@@@     @@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@(            @@@@@@@@@@@@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@             @@@@@@@@@@@       @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@(            @@@@@@@@@@@@           @@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@             @@@@@@@@@@@@@@@         @@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@(            @@@@@@@@@@@@@@@@@@@@@   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@           @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@(     @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 */
pragma solidity >=0.8.4;

interface IKarmaScore {
    function verify(
        address account,
        uint256 score,
        bytes calldata data
    ) external view returns (bool);

    function merkleRoot() external view returns (bytes32);

    function setMerkleRoot(bytes32 _merkleRoot) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface INOwnerResolver {
    function ownerOf(uint256 nid) external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function nOwned(address owner) external view returns (uint256[] memory);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

library NilProtocolUtils {
    bytes internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// [MIT License]
    /// @title Base64
    /// @notice Provides a function for encoding some bytes in base64
    /// @author Brecht Devos <brecht@loopring.org>

    /// @notice Encodes some bytes to the base64 representation
    function base64encode(bytes memory data) external pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(input, 0x3F))), 0xFF))
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }

    // @notice converts number to string
    function stringify(uint256 value) external pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT license
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IKarmaScore.sol";
import "./NilProtocolUtils.sol";
import "../libraries/NilProtocolUtils.sol";

library SeedPhraseUtils {
    using Strings for uint256;
    using Strings for uint16;
    using Strings for uint8;

    struct Random {
        uint256 seed;
        uint256 offsetBit;
    }

    struct Colors {
        string background;
        string panel;
        string panel2;
        string panelStroke;
        string selectedCircleStroke;
        string selectedCircleFill;
        string selectedCircleFill2;
        string negativeCircleStroke;
        string negativeCircleFill;
        string blackOrWhite;
        string dynamicOpacity;
        string backgroundCircle;
    }

    struct Attrs {
        bool showStroke;
        bool border;
        bool showPanel;
        bool backgroundSquare;
        bool bigBackgroundCircle;
        bool showGrid;
        bool backgroundCircles;
        bool greyscale;
        bool doublePanel;
        uint16 bipWordId;
        uint16 secondBipWordId;
    }

    uint8 internal constant strokeWeight = 7;
    uint16 internal constant segmentSize = 100;
    uint16 internal constant radius = 50;
    uint16 internal constant padding = 10;
    uint16 internal constant viewBox = 1600;
    uint16 internal constant panelWidth = segmentSize * 4;
    uint16 internal constant panelHeight = segmentSize * 10;
    uint16 internal constant singlePanelX = (segmentSize * 6);
    uint16 internal constant doublePanel1X = (segmentSize * 3);
    uint16 internal constant doublePanel2X = doublePanel1X + (segmentSize * 6);
    uint16 internal constant panelY = (segmentSize * 3);

    function generateSeed(uint256 tokenId, uint256 vrfRandomValue) external view returns (bytes32) {
        return keccak256(abi.encode(tokenId, block.timestamp, block.difficulty, vrfRandomValue));
    }

    function _shouldAddTrait(
        bool isTrue,
        bytes memory trueName,
        bytes memory falseName,
        uint8 prevRank,
        uint8 newRank,
        bytes memory traits
    ) internal pure returns (bytes memory, uint8) {
        if (isTrue) {
            traits = abi.encodePacked(traits, ',{"value": "', trueName, '"}');
        }
        // Only add the falsy trait if it's named (e.g. there's no negative version of "greyscale")
        else if (falseName.length != 0) {
            traits = abi.encodePacked(traits, ',{"value": "', falseName, '"}');
        }

        // Return new (higher rank if trait is true)
        return (traits, (isTrue ? newRank : prevRank));
    }

    function tokenTraits(Attrs memory attributes) internal pure returns (bytes memory traits, uint8 rarityRating) {
        rarityRating = 0;
        traits = abi.encodePacked("[");
        // Add both words to trait if a double panel
        if (attributes.doublePanel) {
            traits = abi.encodePacked(
                traits,
                '{"trait_type": "Double Panel BIP39 IDs", "value": "',
                attributes.bipWordId.toString(),
                " - ",
                attributes.secondBipWordId.toString(),
                '"},',
                '{"value": "Double Panel"}'
            );
        } else {
            traits = abi.encodePacked(
                traits,
                '{"trait_type": "BIP39 ID",  "display_type": "number", "max_value": 2048, "value": ',
                attributes.bipWordId.toString(),
                "}"
            );
        }
        // Stroke trait - rank 1
        (traits, rarityRating) = _shouldAddTrait(
            !attributes.showStroke,
            "No Stroke",
            "OG Stroke",
            rarityRating,
            1,
            traits
        );
        // Border - rank 2
        (traits, rarityRating) = _shouldAddTrait(attributes.border, "Border", "", rarityRating, 2, traits);
        // No Panel - rank 3
        (traits, rarityRating) = _shouldAddTrait(
            !attributes.showPanel,
            "No Panel",
            "OG Panel",
            rarityRating,
            3,
            traits
        );
        // Symmetry Group Square - rank 4
        (traits, rarityRating) = _shouldAddTrait(
            attributes.backgroundSquare,
            "Group Square",
            "",
            rarityRating,
            4,
            traits
        );
        // Symmetry Group Circle - rank 5
        (traits, rarityRating) = _shouldAddTrait(
            attributes.bigBackgroundCircle,
            "Group Circle",
            "",
            rarityRating,
            5,
            traits
        );
        // Caged - rank 6
        (traits, rarityRating) = _shouldAddTrait(attributes.showGrid, "Caged", "", rarityRating, 6, traits);
        // Bubblewrap - rank 7
        (traits, rarityRating) = _shouldAddTrait(
            attributes.backgroundCircles,
            "Bubblewrap",
            "",
            rarityRating,
            7,
            traits
        );
        // Monochrome - rank 8
        (traits, rarityRating) = _shouldAddTrait(attributes.greyscale, "Monochrome", "", rarityRating, 8, traits);

        traits = abi.encodePacked(traits, "]");
    }

    /**
     * @notice Generates the art defining attributes
     * @param bipWordId bip39 word id
     * @param secondBipWordId ^ only for a double panel
     * @param random RNG
     * @param predefinedRarity double panels trait to carry over
     * @return attributes struct
     */
    function tokenAttributes(
        uint16 bipWordId,
        uint16 secondBipWordId,
        Random memory random,
        uint8 predefinedRarity
    ) internal pure returns (Attrs memory attributes) {
        attributes = Attrs({
            showStroke: (predefinedRarity == 1) ? false : _boolPercentage(random, 70), // rank 1
            border: (predefinedRarity == 2) ? true : _boolPercentage(random, 30), // rank 2
            showPanel: (predefinedRarity == 3) ? false : _boolPercentage(random, 80), // rank 3
            backgroundSquare: (predefinedRarity == 4) ? true : _boolPercentage(random, 18), // rank 4
            bigBackgroundCircle: (predefinedRarity == 5) ? true : _boolPercentage(random, 12), // rank = 5
            showGrid: (predefinedRarity == 6) ? true : _boolPercentage(random, 6), // rank 6
            backgroundCircles: (predefinedRarity == 7) ? true : _boolPercentage(random, 4), // rank 7
            greyscale: (predefinedRarity == 8) ? true : _boolPercentage(random, 2), // rank 8
            bipWordId: bipWordId,
            doublePanel: (secondBipWordId > 0),
            secondBipWordId: secondBipWordId
        });

        // Rare attributes should always superseed less-rare
        // If greyscale OR grid is true then turn on stroke (as it is required)
        if (attributes.showGrid || attributes.greyscale) {
            attributes.showStroke = true;
        }
        // backgroundCircles superseeds grid (they cannot co-exist)
        if (attributes.backgroundCircles) {
            attributes.showGrid = false;
        }
        // Border cannot be on if background shapes are turned on
        if (attributes.bigBackgroundCircle || attributes.backgroundSquare) {
            attributes.border = false;
            // Big Background Shapes cannot co-exist
            if (attributes.bigBackgroundCircle) {
                attributes.backgroundSquare = false;
            }
        }
    }

    /**
     * @notice Converts a tokenId (uint256) into the formats needed to generate the art
     * @param tokenId tokenId (also the BIP39 word)
     * @return tokenArray with prepended 0's (if tokenId is less that 4 digits) also returns in string format
     */
    function _transformTokenId(uint256 tokenId) internal pure returns (uint8[4] memory tokenArray, string memory) {
        bytes memory tokenString;
        uint8 digit;

        for (int8 i = 3; i >= 0; i--) {
            digit = uint8(tokenId % 10); // This returns the final digit in the token
            if (tokenId > 0) {
                tokenId = tokenId / 10; // this removes the last digit from the token as we've grabbed the digit already
                tokenArray[uint8(i)] = digit;
            }
            tokenString = abi.encodePacked(digit.toString(), tokenString);
        }

        return (tokenArray, string(tokenString));
    }

    function _renderText(string memory text, string memory color) internal pure returns (bytes memory svg) {
        svg = abi.encodePacked(
            "<text x='1500' y='1500' text-anchor='end' style='font:700 36px &quot;Courier New&quot;;fill:",
            color,
            ";opacity:.4'>#",
            text,
            "</text>"
        );

        return svg;
    }

    function _backgroundShapeSizing(Random memory random, Attrs memory attributes)
        internal
        pure
        returns (uint16, uint16)
    {
        uint256 idx;
        // If we DON'T have a 'doublePanel' or 'no panel' we can return the default sizing
        if (!attributes.doublePanel && attributes.showPanel) {
            uint16[2][6] memory defaultSizing = [
                [1275, 200],
                [1150, 375],
                [900, 300],
                [925, 225],
                [850, 150],
                [775, 125]
            ];
            idx = SeedPhraseUtils._next(random, 0, defaultSizing.length);
            return (defaultSizing[idx][0], defaultSizing[idx][1]);
        }

        // Otherwise we need to return some slightly different data
        if (attributes.bigBackgroundCircle) {
            uint16[2][4] memory restrictedCircleDimensions = [[1150, 150], [1275, 200], [1300, 100], [1350, 200]];
            idx = SeedPhraseUtils._next(random, 0, restrictedCircleDimensions.length);
            return (restrictedCircleDimensions[idx][0], restrictedCircleDimensions[idx][1]);
        }

        // Else we can assume that it is backgroundSquares
        uint16[2][4] memory restrictedSquareDimensions = [[1150, 50], [1100, 125], [1275, 200], [1300, 150]];
        idx = SeedPhraseUtils._next(random, 0, restrictedSquareDimensions.length);
        return (restrictedSquareDimensions[idx][0], restrictedSquareDimensions[idx][1]);
    }

    function _getStrokeStyle(
        bool showStroke,
        string memory color,
        string memory opacity,
        uint8 customStrokeWeight
    ) internal pure returns (bytes memory strokeStyle) {
        if (showStroke) {
            strokeStyle = abi.encodePacked(
                " style='stroke-opacity:",
                opacity,
                ";stroke:",
                color,
                ";stroke-width:",
                customStrokeWeight.toString(),
                "' "
            );

            return strokeStyle;
        }
    }

    function _getPalette(Random memory random, Attrs memory attributes) internal pure returns (Colors memory) {
        string[6] memory selectedPallet;
        uint8[6] memory lumosity;
        if (attributes.greyscale) {
            selectedPallet = ["#f8f9fa", "#c3c4c4", "#909091", "#606061", "#343435", "#0a0a0b"];
            lumosity = [249, 196, 144, 96, 52, 10];
        } else {
            uint256 randPalette = SeedPhraseUtils._next(random, 0, 25);
            if (randPalette == 0) {
                selectedPallet = ["#ffe74c", "#ff5964", "#ffffff", "#6bf178", "#35a7ff", "#5b3758"];
                lumosity = [225, 125, 255, 204, 149, 65];
            } else if (randPalette == 1) {
                selectedPallet = ["#ff0000", "#ff8700", "#e4ff33", "#a9ff1f", "#0aefff", "#0a33ff"];
                lumosity = [54, 151, 235, 221, 191, 57];
            } else if (randPalette == 2) {
                selectedPallet = ["#f433ab", "#cb04a5", "#934683", "#65334d", "#2d1115", "#e0e2db"];
                lumosity = [101, 58, 91, 64, 23, 225];
            } else if (randPalette == 3) {
                selectedPallet = ["#f08700", "#f6aa28", "#f9d939", "#00a6a6", "#bbdef0", "#23556c"];
                lumosity = [148, 177, 212, 131, 216, 76];
            } else if (randPalette == 4) {
                selectedPallet = ["#f7e6de", "#e5b59e", "#cb7d52", "#bb8f77", "#96624a", "#462b20"];
                lumosity = [233, 190, 138, 151, 107, 48];
            } else if (randPalette == 5) {
                selectedPallet = ["#f61379", "#d91cbc", "#da81ee", "#5011e4", "#4393ef", "#8edef6"];
                lumosity = [75, 80, 156, 46, 137, 207];
            } else if (randPalette == 6) {
                selectedPallet = ["#010228", "#006aa3", "#005566", "#2ac1df", "#82dded", "#dbf5fa"];
                lumosity = [5, 88, 68, 163, 203, 240];
            } else if (randPalette == 7) {
                selectedPallet = ["#f46036", "#5b85aa", "#414770", "#372248", "#171123", "#f7f5fb"];
                lumosity = [124, 127, 73, 41, 20, 246];
            } else if (randPalette == 8) {
                selectedPallet = ["#393d3f", "#fdfdff", "#c6c5b9", "#62929e", "#546a7b", "#c52233"];
                lumosity = [60, 253, 196, 137, 103, 70];
            } else if (randPalette == 9) {
                selectedPallet = ["#002626", "#0e4749", "#95c623", "#e55812", "#efe7da", "#8ddbe0"];
                lumosity = [30, 59, 176, 113, 232, 203];
            } else if (randPalette == 10) {
                selectedPallet = ["#03071e", "#62040d", "#d00000", "#e85d04", "#faa307", "#ffcb47"];
                lumosity = [8, 25, 44, 116, 170, 205];
            } else if (randPalette == 11) {
                selectedPallet = ["#f56a00", "#ff931f", "#ffd085", "#20003d", "#7b2cbf", "#c698eb"];
                lumosity = [128, 162, 213, 11, 71, 168];
            } else if (randPalette == 12) {
                selectedPallet = ["#800016", "#ffffff", "#ff002b", "#407ba7", "#004e89", "#00043a"];
                lumosity = [29, 255, 57, 114, 66, 7];
            } else if (randPalette == 13) {
                selectedPallet = ["#d6d6d6", "#f9f7dc", "#ffee32", "#ffd100", "#202020", "#6c757d"];
                lumosity = [214, 245, 228, 204, 32, 116];
            } else if (randPalette == 14) {
                selectedPallet = ["#fff5d6", "#ccc5b9", "#403d39", "#252422", "#eb5e28", "#bb4111"];
                lumosity = [245, 198, 61, 36, 120, 87];
            } else if (randPalette == 15) {
                selectedPallet = ["#0c0f0a", "#ff206e", "#fbff12", "#41ead4", "#6c20fd", "#ffffff"];
                lumosity = [14, 85, 237, 196, 224, 255];
            } else if (randPalette == 16) {
                selectedPallet = ["#fdd8d8", "#f67979", "#e51010", "#921314", "#531315", "#151315"];
                lumosity = [224, 148, 61, 46, 33, 20];
            } else if (randPalette == 17) {
                selectedPallet = ["#000814", "#002752", "#0066cc", "#f5bc00", "#ffd60a", "#ffee99"];
                lumosity = [7, 34, 88, 187, 208, 235];
            } else if (randPalette == 18) {
                selectedPallet = ["#010b14", "#022d4f", "#fdfffc", "#2ec4b6", "#e71d36", "#ff990a"];
                lumosity = [10, 38, 254, 163, 74, 164];
            } else if (randPalette == 19) {
                selectedPallet = ["#fd650d", "#d90368", "#820263", "#291720", "#06efa9", "#0d5943"];
                lumosity = [127, 56, 36, 27, 184, 71];
            } else if (randPalette == 20) {
                selectedPallet = ["#002914", "#005200", "#34a300", "#70e000", "#aef33f", "#e0ff85"];
                lumosity = [31, 59, 128, 184, 215, 240];
            } else if (randPalette == 21) {
                selectedPallet = ["#001413", "#fafffe", "#6f0301", "#a92d04", "#f6b51d", "#168eb6"];
                lumosity = [16, 254, 26, 68, 184, 119];
            } else if (randPalette == 22) {
                selectedPallet = ["#6a1f10", "#d53e20", "#f7d1ca", "#c4f3fd", "#045362", "#fffbfa"];
                lumosity = [46, 92, 217, 234, 67, 252];
            } else if (randPalette == 23) {
                selectedPallet = ["#6b42ff", "#a270ff", "#dda1f7", "#ffd6eb", "#ff8fb2", "#f56674"];
                lumosity = [88, 133, 180, 224, 169, 133];
            } else if (randPalette == 24) {
                selectedPallet = ["#627132", "#273715", "#99a271", "#fefae1", "#e0a35c", "#bf6b21"];
                lumosity = [105, 49, 157, 249, 171, 120];
            }
        }

        // Randomize pallet order here...
        return _shufflePallet(random, selectedPallet, lumosity, attributes);
    }

    function _shufflePallet(
        Random memory random,
        string[6] memory hexColors,
        uint8[6] memory lumaValues,
        Attrs memory attributes
    ) internal pure returns (Colors memory) {
        // Shuffle colors and luma values with the same index
        for (uint8 i = 0; i < hexColors.length; i++) {
            // n = Pick random i > (array length - i)
            uint256 n = i + SeedPhraseUtils._next(random, 0, (hexColors.length - i));
            // temp = Temporarily store value from array[n]
            string memory tempHex = hexColors[n];
            uint8 tempLuma = lumaValues[n];
            // Swap n value with i value
            hexColors[n] = hexColors[i];
            hexColors[i] = tempHex;
            lumaValues[n] = lumaValues[i];
            lumaValues[i] = tempLuma;
        }

        Colors memory pallet = Colors({
            background: hexColors[0],
            panel: hexColors[1],
            panel2: "", // panel2 should match selected circles
            panelStroke: hexColors[2],
            selectedCircleStroke: hexColors[2], // Match panel stroke
            negativeCircleStroke: hexColors[3],
            negativeCircleFill: hexColors[4],
            selectedCircleFill: hexColors[5],
            selectedCircleFill2: "", // should match panel1
            backgroundCircle: "",
            blackOrWhite: lumaValues[0] < 150 ? "#fff" : "#000",
            dynamicOpacity: lumaValues[0] < 150 ? "0.08" : "0.04"
        });

        if (attributes.doublePanel) {
            pallet.panel2 = pallet.selectedCircleFill;
            pallet.selectedCircleFill2 = pallet.panel;
        }

        if (attributes.bigBackgroundCircle) {
            // Set background circle colors here
            pallet.backgroundCircle = pallet.background;
            pallet.background = pallet.panel;
            // Luma based on 'new background', previous background is used for bgCircleColor)
            pallet.blackOrWhite = lumaValues[1] < 150 ? "#fff" : "#000";
            pallet.dynamicOpacity = lumaValues[1] < 150 ? "0.08" : "0.04";
        }

        return pallet;
    }

    /// @notice get an random number between (min and max) using seed and offseting bits
    ///         this function assumes that max is never bigger than 0xffffff (hex color with opacity included)
    /// @dev this function is simply used to get random number using a seed.
    ///      if does bitshifting operations to try to reuse the same seed as much as possible.
    ///      should be enough for anyth
    /// @param random the randomizer
    /// @param min the minimum
    /// @param max the maximum
    /// @return result the resulting pseudo random number
    function _next(
        Random memory random,
        uint256 min,
        uint256 max
    ) internal pure returns (uint256 result) {
        uint256 newSeed = random.seed;
        uint256 newOffset = random.offsetBit + 3;

        uint256 maxOffset = 4;
        uint256 mask = 0xf;
        if (max > 0xfffff) {
            mask = 0xffffff;
            maxOffset = 24;
        } else if (max > 0xffff) {
            mask = 0xfffff;
            maxOffset = 20;
        } else if (max > 0xfff) {
            mask = 0xffff;
            maxOffset = 16;
        } else if (max > 0xff) {
            mask = 0xfff;
            maxOffset = 12;
        } else if (max > 0xf) {
            mask = 0xff;
            maxOffset = 8;
        }

        // if offsetBit is too high to get the max number
        // just get new seed and restart offset to 0
        if (newOffset > (256 - maxOffset)) {
            newOffset = 0;
            newSeed = uint256(keccak256(abi.encode(newSeed)));
        }

        uint256 offseted = (newSeed >> newOffset);
        uint256 part = offseted & mask;
        result = min + (part % (max - min));

        random.seed = newSeed;
        random.offsetBit = newOffset;
    }

    function _boolPercentage(Random memory random, uint256 percentage) internal pure returns (bool) {
        // E.G. If percentage = 30, and random = 0-29 we return true
        // Percentage = 1, random = 0 (TRUE)
        return (SeedPhraseUtils._next(random, 0, 100) < percentage);
    }

    /// @param random source of randomness (based on tokenSeed)
    /// @param attributes art attributes
    /// @return the json
    function render(SeedPhraseUtils.Random memory random, SeedPhraseUtils.Attrs memory attributes)
        external
        pure
        returns (string memory)
    {
        // Get color pallet
        SeedPhraseUtils.Colors memory pallet = SeedPhraseUtils._getPalette(random, attributes);

        //  Start SVG (viewbox & static patterns)
        bytes memory svg = abi.encodePacked(
            "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1600 1600'><path fill='",
            pallet.background,
            "' ",
            SeedPhraseUtils._getStrokeStyle(attributes.border, pallet.blackOrWhite, "0.3", 50),
            " d='M0 0h1600v1600H0z'/>",
            "  <pattern id='panelCircles' x='0' y='0' width='.25' height='.1' patternUnits='objectBoundingBox'>",
            "<circle cx='50' cy='50' r='40' fill='",
            pallet.negativeCircleFill,
            "' ",
            SeedPhraseUtils._getStrokeStyle(attributes.showStroke, pallet.negativeCircleStroke, "1", strokeWeight),
            " /></pattern>"
        );
        // Render optional patterns (grid OR background circles)
        if (attributes.backgroundCircles) {
            svg = abi.encodePacked(
                svg,
                "<pattern id='backgroundCircles' x='0' y='0' width='100' height='100'",
                " patternUnits='userSpaceOnUse'><circle cx='50' cy='50' r='40' fill='",
                pallet.blackOrWhite,
                "' style='fill-opacity: ",
                pallet.dynamicOpacity,
                ";'></circle></pattern><path fill='url(#backgroundCircles)' d='M0 0h1600v1600H0z'/>"
            );
        } else if (attributes.showGrid) {
            svg = abi.encodePacked(
                svg,
                "<pattern id='grid' x='0' y='0' width='100' height='100'",
                " patternUnits='userSpaceOnUse'><rect x='0' y='0' width='100' height='100' fill='none' ",
                SeedPhraseUtils._getStrokeStyle(true, pallet.blackOrWhite, pallet.dynamicOpacity, strokeWeight),
                " /></pattern><path fill='url(#grid)' d='M0 0h1600v1600H0z'/>"
            );
        }
        if (attributes.bigBackgroundCircle) {
            (uint16 shapeSize, uint16 stroke) = SeedPhraseUtils._backgroundShapeSizing(random, attributes);
            // uint16 centerCircle = (viewBox / 2); // Viewbox = 1600, Center = 800
            svg = abi.encodePacked(
                svg,
                "<circle cx='800' cy='800' r='",
                (shapeSize / 2).toString(),
                "' fill='",
                pallet.backgroundCircle,
                "' stroke='",
                pallet.negativeCircleStroke,
                "' style='stroke-width:",
                stroke.toString(),
                ";stroke-opacity:0.3'/>"
            );
        } else if (attributes.backgroundSquare) {
            (uint16 shapeSize, uint16 stroke) = SeedPhraseUtils._backgroundShapeSizing(random, attributes);
            uint16 centerSquare = ((viewBox - shapeSize) / 2);
            svg = abi.encodePacked(
                svg,
                "<rect x='",
                centerSquare.toString(),
                "' y='",
                centerSquare.toString(),
                "' width='",
                shapeSize.toString(),
                "' height='",
                shapeSize.toString(),
                "' fill='",
                pallet.backgroundCircle,
                "' stroke='",
                pallet.negativeCircleStroke,
                "' style='stroke-width:",
                stroke.toString(),
                ";stroke-opacity:0.3'/>"
            );
        }

        // Double panel (only if holder has burned two tokens from the defined pairings)
        if (attributes.doublePanel) {
            (uint8[4] memory firstBipIndexArray, string memory firstBipIndexStr) = SeedPhraseUtils._transformTokenId(
                attributes.bipWordId
            );
            (uint8[4] memory secondBipIndexArray, string memory secondBipIndexStr) = SeedPhraseUtils._transformTokenId(
                attributes.secondBipWordId
            );

            svg = abi.encodePacked(
                svg,
                _renderSinglePanel(firstBipIndexArray, attributes, pallet, doublePanel1X, false),
                _renderSinglePanel(secondBipIndexArray, attributes, pallet, doublePanel2X, true)
            );

            // Create text
            bytes memory combinedText = abi.encodePacked(firstBipIndexStr, " - #", secondBipIndexStr);
            svg = abi.encodePacked(
                svg,
                SeedPhraseUtils._renderText(string(combinedText), pallet.blackOrWhite),
                "</svg>"
            );
        }
        // Single Panel
        else {
            (uint8[4] memory bipIndexArray, string memory bipIndexStr) = SeedPhraseUtils._transformTokenId(
                attributes.bipWordId
            );
            svg = abi.encodePacked(svg, _renderSinglePanel(bipIndexArray, attributes, pallet, singlePanelX, false));

            // Add closing text and svg element
            svg = abi.encodePacked(svg, SeedPhraseUtils._renderText(bipIndexStr, pallet.blackOrWhite), "</svg>");
        }

        return string(svg);
    }

    function _renderSinglePanel(
        uint8[4] memory bipIndexArray,
        SeedPhraseUtils.Attrs memory attributes,
        SeedPhraseUtils.Colors memory pallet,
        uint16 panelX,
        bool secondPanel
    ) internal pure returns (bytes memory panelSvg) {
        // Draw panels
        bool squareEdges = (attributes.doublePanel && attributes.backgroundSquare);
        if (attributes.showPanel) {
            panelSvg = abi.encodePacked(
                "<rect x='",
                (panelX - padding).toString(),
                "' y='",
                (panelY - padding).toString(),
                "' width='",
                (panelWidth + (padding * 2)).toString(),
                "' height='",
                (panelHeight + (padding * 2)).toString(),
                "' rx='",
                (squareEdges ? 0 : radius).toString(),
                "' fill='",
                (secondPanel ? pallet.panel2 : pallet.panel),
                "' ",
                SeedPhraseUtils._getStrokeStyle(attributes.showStroke, pallet.panelStroke, "1", strokeWeight),
                "/>"
            );
        }
        // Fill panel with negative circles, should resemble M600 300h400v1000H600z
        panelSvg = abi.encodePacked(
            panelSvg,
            "<path fill='url(#panelCircles)' d='M",
            panelX.toString(),
            " ",
            panelY.toString(),
            "h",
            panelWidth.toString(),
            "v",
            panelHeight.toString(),
            "H",
            panelX.toString(),
            "z'/>"
        );
        // Draw selected circles
        panelSvg = abi.encodePacked(
            panelSvg,
            _renderSelectedCircles(bipIndexArray, pallet, attributes.showStroke, panelX, secondPanel)
        );
    }

    function _renderSelectedCircles(
        uint8[4] memory bipIndexArray,
        SeedPhraseUtils.Colors memory pallet,
        bool showStroke,
        uint16 panelX,
        bool secondPanel
    ) internal pure returns (bytes memory svg) {
        for (uint8 i = 0; i < bipIndexArray.length; i++) {
            svg = abi.encodePacked(
                svg,
                "<circle cx='",
                (panelX + (segmentSize * i) + radius).toString(),
                "' cy='",
                (panelY + (segmentSize * bipIndexArray[i]) + radius).toString(),
                "' r='41' fill='", // Increase the size a tiny bit here (+1) to hide negative circle outline
                (secondPanel ? pallet.selectedCircleFill2 : pallet.selectedCircleFill),
                "' ",
                SeedPhraseUtils._getStrokeStyle(showStroke, pallet.selectedCircleStroke, "1", strokeWeight),
                " />"
            );
        }
    }

    function getRarityRating(bytes32 tokenSeed) external pure returns (uint8) {
        SeedPhraseUtils.Random memory random = SeedPhraseUtils.Random({ seed: uint256(tokenSeed), offsetBit: 0 });
        (, uint8 rarityRating) = SeedPhraseUtils.tokenTraits(SeedPhraseUtils.tokenAttributes(0, 0, random, 0));

        return rarityRating;
    }

    function getTraitsAndAttributes(
        uint16 bipWordId,
        uint16 secondBipWordId,
        uint8 rarityValue,
        SeedPhraseUtils.Random memory random
    ) external pure returns (bytes memory, SeedPhraseUtils.Attrs memory) {
        SeedPhraseUtils.Attrs memory attributes = SeedPhraseUtils.tokenAttributes(
            bipWordId,
            secondBipWordId,
            random,
            rarityValue
        );

        (bytes memory traits, ) = SeedPhraseUtils.tokenTraits(attributes);

        return (traits, attributes);
    }

    function getKarma(IKarmaScore karma, bytes memory data, address account) external view returns (uint256) {
        if (data.length > 0) {
            (, uint256 karmaScore, ) = abi.decode(data, (address, uint256, bytes32[]));
            if (karma.verify(account, karmaScore, data)) {
                return account == address(0) ? 1000 : karmaScore;
            }
        }
        return 1000;
    }

    function shuffleBipWords(uint256 randomValue) external pure returns (uint16[] memory) {
        uint16 size = 2048;
        uint16[] memory result = new uint16[](size);

        // Initialize array.
        for (uint16 i = 0; i < size; i++) {
            result[i] = i + 1;
        }

        // Set the initial randomness based on the provided entropy from VRF.
        bytes32 random = keccak256(abi.encodePacked(randomValue));

        // Set the last item of the array which will be swapped.
        uint16 lastItem = size - 1;

        // We need to do `size - 1` iterations to completely shuffle the array.
        for (uint16 i = 1; i < size - 1; i++) {
            // Select a number based on the randomness.
            uint16 selectedItem = uint16(uint256(random) % lastItem);

            // Swap items `selected_item <> last_item`.
            (result[lastItem], result[selectedItem]) = (result[selectedItem], result[lastItem]);

            // Decrease the size of the possible shuffle
            // to preserve the already shuffled items.
            // The already shuffled items are at the end of the array.
            lastItem--;

            // Generate new randomness.
            random = keccak256(abi.encodePacked(random));
        }

        return result;
    }

    function getDescriptionPt1() internal pure returns (string memory) {
        return "\"Seed Phrase is a 'Crypto Native' *fully* on-chain collection.\\n\\nA '*SEED*' is unique, it represents a single word from the BIP-0039 word list (the most commonly used word list to generate a seed/recovery phrase, think of it as a dictionary that only holds 2048 words).\\n\\n***Your 'SEED*' = *Your 'WORD*' in the list.**  \\nClick [here](https://www.seedphrase.codes/token?id=";

    }

    function getDescriptionPt2() internal pure returns (string memory) {
        return ") to decipher *your 'SEED*' and find out which word it translates to!\\n\\nFor Licensing, T&Cs or any other info, please visit: [www.seedphrase.codes](https://www.seedphrase.codes/).\"";
    }

    function getTokenURI(string memory output, bytes memory traits, uint256 tokenId) external pure returns (string memory) {
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                    NilProtocolUtils.base64encode(
                    bytes(
                        string(
                            abi.encodePacked(
                                '{"name": "Seed Phrase #',
                                    NilProtocolUtils.stringify(tokenId),
                                '", "image": "data:image/svg+xml;base64,',
                                    NilProtocolUtils.base64encode(bytes(output)),
                                '", "attributes": ',
                                traits,
                                ', "description": ',
                                getDescriptionPt1(),
                                tokenId.toString(),
                                getDescriptionPt2(),
                                "}"
                            )
                        )
                    )
                )
            )
        );
    }

}

// SPDX-License-Identifier: MIT

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

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
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

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
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
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

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

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT

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
pragma solidity ^0.8.0;

interface LinkTokenInterface {

  function allowance(
    address owner,
    address spender
  )
    external
    view
    returns (
      uint256 remaining
    );

  function approve(
    address spender,
    uint256 value
  )
    external
    returns (
      bool success
    );

  function balanceOf(
    address owner
  )
    external
    view
    returns (
      uint256 balance
    );

  function decimals()
    external
    view
    returns (
      uint8 decimalPlaces
    );

  function decreaseApproval(
    address spender,
    uint256 addedValue
  )
    external
    returns (
      bool success
    );

  function increaseApproval(
    address spender,
    uint256 subtractedValue
  ) external;

  function name()
    external
    view
    returns (
      string memory tokenName
    );

  function symbol()
    external
    view
    returns (
      string memory tokenSymbol
    );

  function totalSupply()
    external
    view
    returns (
      uint256 totalTokensIssued
    );

  function transfer(
    address to,
    uint256 value
  )
    external
    returns (
      bool success
    );

  function transferAndCall(
    address to,
    uint256 value,
    bytes calldata data
  )
    external
    returns (
      bool success
    );

  function transferFrom(
    address from,
    address to,
    uint256 value
  )
    external
    returns (
      bool success
    );

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VRFRequestIDBase {

  /**
   * @notice returns the seed which is actually input to the VRF coordinator
   *
   * @dev To prevent repetition of VRF output due to repetition of the
   * @dev user-supplied seed, that seed is combined in a hash with the
   * @dev user-specific nonce, and the address of the consuming contract. The
   * @dev risk of repetition is mostly mitigated by inclusion of a blockhash in
   * @dev the final seed, but the nonce does protect against repetition in
   * @dev requests which are included in a single block.
   *
   * @param _userSeed VRF seed input provided by user
   * @param _requester Address of the requesting contract
   * @param _nonce User-specific nonce at the time of the request
   */
  function makeVRFInputSeed(
    bytes32 _keyHash,
    uint256 _userSeed,
    address _requester,
    uint256 _nonce
  )
    internal
    pure
    returns (
      uint256
    )
  {
    return uint256(keccak256(abi.encode(_keyHash, _userSeed, _requester, _nonce)));
  }

  /**
   * @notice Returns the id for this request
   * @param _keyHash The serviceAgreement ID to be used for this request
   * @param _vRFInputSeed The seed to be passed directly to the VRF
   * @return The id for this request
   *
   * @dev Note that _vRFInputSeed is not the seed passed by the consuming
   * @dev contract, but the one generated by makeVRFInputSeed
   */
  function makeRequestId(
    bytes32 _keyHash,
    uint256 _vRFInputSeed
  )
    internal
    pure
    returns (
      bytes32
    )
  {
    return keccak256(abi.encodePacked(_keyHash, _vRFInputSeed));
  }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IN.sol";
import "../interfaces/INilPass.sol";
import "../interfaces/IPricingStrategy.sol";

/**
 * @title NilPassCore contract
 * @author Tony Snark
 * @notice This contract provides basic functionalities to allow minting using the NilPass
 * @dev This contract should be used only for testing or testnet deployments
 */
abstract contract NilPassCore is ERC721Enumerable, ReentrancyGuard, AccessControl, INilPass, IPricingStrategy {
    uint128 public constant MAX_MULTI_MINT_AMOUNT = 32;
    uint128 public constant MAX_N_TOKEN_ID = 8888;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant DAO_ROLE = keccak256("DAO");

    IN public immutable n;
    uint16 public reserveMinted;
    uint256 public mintedOutsideNRange;
    address public masterMint;
    DerivativeParameters public derivativeParams;
    uint128 maxTokenId;

    struct DerivativeParameters {
        bool onlyNHolders;
        bool supportsTokenId;
        uint16 reservedAllowance;
        uint128 maxTotalSupply;
        uint128 maxMintAllowance;
    }

    event Minted(address to, uint256 tokenId);

    /**
     * @notice Construct an NilPassCore instance
     * @param name Name of the token
     * @param symbol Symbol of the token
     * @param n_ Address of your n instance (only for testing)
     * @param derivativeParams_ Parameters describing the derivative settings
     * @param masterMint_ Address of the master mint contract
     * @param dao_ Address of the NIL DAO
     */
    constructor(
        string memory name,
        string memory symbol,
        IN n_,
        DerivativeParameters memory derivativeParams_,
        address masterMint_,
        address dao_
    ) ERC721(name, symbol) {
        derivativeParams = derivativeParams_;
        require(derivativeParams.maxTotalSupply > 0, "NilPass:INVALID_SUPPLY");
        require(
            !derivativeParams.onlyNHolders ||
                (derivativeParams.onlyNHolders && derivativeParams.maxTotalSupply <= MAX_N_TOKEN_ID),
            "NilPass:INVALID_SUPPLY"
        );
        require(derivativeParams.maxTotalSupply >= derivativeParams.reservedAllowance, "NilPass:INVALID_ALLOWANCE");
        require(masterMint_ != address(0), "NilPass:INVALID_MASTERMINT");
        require(dao_ != address(0), "NilPass:INVALID_DAO");
        n = n_;
        masterMint = masterMint_;
        derivativeParams.maxMintAllowance = derivativeParams.maxMintAllowance < MAX_MULTI_MINT_AMOUNT
            ? derivativeParams.maxMintAllowance
            : MAX_MULTI_MINT_AMOUNT;
        maxTokenId = derivativeParams.maxTotalSupply > MAX_N_TOKEN_ID
            ? derivativeParams.maxTotalSupply
            : MAX_N_TOKEN_ID;
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(DAO_ROLE, dao_);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(DAO_ROLE, DAO_ROLE);
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Nil:ACCESS_DENIED");
        _;
    }

    modifier onlyDAO() {
        require(hasRole(DAO_ROLE, msg.sender), "Nil:ACCESS_DENIED");
        _;
    }

    /**
     * @notice Allow anyone to mint a token with the supply id if this pass is unrestricted.
     *         n token holders can use this function without using the n token holders allowance,
     *         this is useful when the allowance is fully utilized.
     */
    function mint(
        address,
        uint8,
        uint256,
        bytes calldata
    ) public virtual override nonReentrant {
        require(false, "MINTING DISABLED");
    }

    /**
     * @notice Allow anyone to mint multiple tokens with the provided IDs if this pass is unrestricted.
     *         n token holders can use this function without using the n token holders allowance,
     *         this is useful when the allowance is fully utilized.
     */
    function mintTokenId(
        address,
        uint256[] calldata,
        uint256,
        bytes calldata
    ) public virtual override nonReentrant {
        require(false, "MINTING DISABLED");
    }

    /**
     * @notice Allow a n token holder to bulk mint tokens with id of their n tokens' id
     */
    function mintWithN(
        address,
        uint256[] calldata,
        uint256,
        bytes calldata
    ) public virtual override nonReentrant {
        require(false, "MINTING DISABLED");
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`
     */
    function _safeMint(address to, uint256 tokenId) internal virtual override {
        require(msg.sender == masterMint, "NilPass:INVALID_MINTER");
        super._safeMint(to, tokenId);
        emit Minted(to, tokenId);
    }

    /**
     * @notice Set the exclusivity flag to only allow N holders to mint
     * @param status Boolean to enable or disable N holder exclusivity
     */
    function setOnlyNHolders(bool status) public onlyAdmin {
        derivativeParams.onlyNHolders = status;
    }

    /**
     * @notice Calculate the currently available number of reserved tokens for n token holders
     * @return Reserved mint available
     */
    function nHoldersMintsAvailable() public view returns (uint256) {
        return derivativeParams.reservedAllowance - reserveMinted;
    }

    /**
     * @notice Calculate the currently available number of open mints
     * @return Open mint available
     */
    function openMintsAvailable() public view returns (uint256) {
        uint256 maxOpenMints = derivativeParams.maxTotalSupply - derivativeParams.reservedAllowance;
        uint256 currentOpenMints = totalSupply() - reserveMinted;
        return maxOpenMints - currentOpenMints;
    }

    /**
     * @notice Calculate the total available number of mints
     * @return total mint available
     */
    function totalMintsAvailable() public view virtual override returns (uint256) {
        return nHoldersMintsAvailable() + openMintsAvailable();
    }

    function mintParameters() external view override returns (INilPass.MintParams memory) {
        return
            INilPass.MintParams({
                reservedAllowance: derivativeParams.reservedAllowance,
                maxTotalSupply: derivativeParams.maxTotalSupply,
                openMintsAvailable: openMintsAvailable(),
                totalMintsAvailable: totalMintsAvailable(),
                nHoldersMintsAvailable: nHoldersMintsAvailable(),
                nHolderPriceInWei: getNextPriceForNHoldersInWei(1, address(0x1), ""),
                openPriceInWei: getNextPriceForOpenMintInWei(1, address(0x1), ""),
                totalSupply: totalSupply(),
                onlyNHolders: derivativeParams.onlyNHolders,
                maxMintAllowance: derivativeParams.maxMintAllowance,
                supportsTokenId: derivativeParams.supportsTokenId
            });
    }

    /**
     * @notice Check if a token with an Id exists
     * @param tokenId The token Id to check for
     */
    function tokenExists(uint256 tokenId) external view override returns (bool) {
        return _exists(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, IERC165, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function maxTotalSupply() external view override returns (uint256) {
        return derivativeParams.maxTotalSupply;
    }

    function reservedAllowance() public view returns (uint16) {
        return derivativeParams.reservedAllowance;
    }

    function getNextPriceForNHoldersInWei(
        uint256 numberOfMints,
        address account,
        bytes memory data
    ) public view virtual override returns (uint256);

    function getNextPriceForOpenMintInWei(
        uint256 numberOfMints,
        address account,
        bytes memory data
    ) public view virtual override returns (uint256);

    function canMint(address account, bytes calldata data) external view virtual override returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "./IERC721Enumerable.sol";

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "../utils/Context.sol";
import "../utils/Strings.sol";
import "../utils/introspection/ERC165.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    function _grantRole(bytes32 role, address account) private {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a / b + (a % b == 0 ? 0 : 1);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface INilPass is IERC721Enumerable {
    struct MintParams {
        uint256 reservedAllowance;
        uint256 maxTotalSupply;
        uint256 nHoldersMintsAvailable;
        uint256 openMintsAvailable;
        uint256 totalMintsAvailable;
        uint256 nHolderPriceInWei;
        uint256 openPriceInWei;
        uint256 totalSupply;
        uint256 maxMintAllowance;
        bool onlyNHolders;
        bool supportsTokenId;
    }

    function mint(
        address recipient,
        uint8 amount,
        uint256 paid,
        bytes calldata data
    ) external;

    function mintTokenId(
        address recipient,
        uint256[] calldata tokenIds,
        uint256 paid,
        bytes calldata data
    ) external;

    function mintWithN(
        address recipient,
        uint256[] calldata tokenIds,
        uint256 paid,
        bytes calldata data
    ) external;

    function totalMintsAvailable() external view returns (uint256);

    function maxTotalSupply() external view returns (uint256);

    function mintParameters() external view returns (MintParams memory);

    function tokenExists(uint256 tokenId) external view returns (bool);

    function canMint(address account, bytes calldata data) external view returns (bool);

    function nUsed(uint256 nid) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IPricingStrategy {
    /**
     * @notice Returns the next price for an N mint
     */
    function getNextPriceForNHoldersInWei(
        uint256 numberOfMints,
        address account,
        bytes memory data
    ) external view returns (uint256);

    /**
     * @notice Returns the next price for an open mint
     */
    function getNextPriceForOpenMintInWei(
        uint256 numberOfMints,
        address account,
        bytes memory data
    ) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}
