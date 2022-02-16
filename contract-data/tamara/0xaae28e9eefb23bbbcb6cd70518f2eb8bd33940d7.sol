pragma solidity >=0.4.22 <0.6.0;

contract Migrations {
  address public owner;
  uint256 public last_completed_migration;

  modifier restricted() {
    if (msg.sender == owner) _;
  }

  constructor() public {
    owner = msg.sender;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }

  function upgrade(address new_address) public restricted {
    Migrations upgraded = Migrations(new_address);
    upgraded.setCompleted(last_completed_migration);
  }
}

pragma solidity ^0.4.24;

import "./PhotonTestToken.sol";


/**
 * @title PhotochainMarketplace
 * @dev Marketplace to make and accept offers using PhotonToken
 */
contract PhotochainMarketplace is Ownable {
    /**
     * Event for offer creation logging
     * @param id Generated unique offer id
     * @param seller Addess of seller of the photo
     * @param licenseType Which license is applied on the offer
     * @param photoDigest 256-bit hash of the photo
     * @param price How many tokens to pay to accept the offer
     */
    event OfferAdded(
        bytes32 indexed id,
        address indexed seller,
        uint8 licenseType,
        bytes32 photoDigest,
        uint256 price
    );

    /**
     * Event for offer acceptance logging
     * @param id Offer id to accept
     * @param licensee Address of the account that bought license
     */
    event OfferAccepted(bytes32 indexed id, address indexed licensee);

    /**
     * Event for offer price change
     * @param id Offer id to update
     * @param oldPrice Previous price in tokens
     * @param newPrice New price in tokens
     */
    event OfferPriceChanged(bytes32 indexed id, uint256 oldPrice, uint256 newPrice);

    /**
     * Event for offer cancellation
     * @param id Offer id to cancel
     */
    event OfferCancelled(bytes32 indexed id);

    struct Offer {
        address seller;
        uint8 licenseType;
        bool isCancelled;
        bytes32 photoDigest;
        uint256 price;
    }

    ERC20 public token;

    // List of the offers
    mapping(bytes32 => Offer) public offers;

    // List of offer ids by seller
    mapping(address => bytes32[]) public offersBySeller;

    // List of offer ids by licensee
    mapping(address => bytes32[]) public offersByLicensee;

    modifier onlyValidAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }

    modifier onlyActiveOffer(bytes32 _id) {
        require(offers[_id].seller != address(0), "Offer does not exists");
        require(!offers[_id].isCancelled, "Offer is cancelled");
        _;
    }

    /**
     * @param _token Address of the PhotonToken contract
     */
    constructor(ERC20 _token) public onlyValidAddress(address(_token)) {
        token = _token;
    }

    /**
       @dev Sets accounting token address
     * @param _token Address of the PhotonToken contract
     */
    function setToken(ERC20 _token)
        external
        onlyOwner
        onlyValidAddress(address(_token))
    {
        token = _token;
    }

    /**
     * @dev Add an offer to the marketplace
     * @param _seller Address of the photo author
     * @param _licenseType License type for the offer
     * @param _photoDigest 256-bit hash of the photo
     * @param _price Price of the offer
     */
    function addOffer(
        address _seller,
        uint8 _licenseType,
        bytes32 _photoDigest,
        uint256 _price
    )
        external
        onlyOwner
        onlyValidAddress(_seller)
    {
        bytes32 _id = keccak256(
            abi.encodePacked(
                _seller,
                _licenseType,
                _photoDigest
            )
        );
        require(offers[_id].seller == address(0), "Offer already exists");

        offersBySeller[_seller].push(_id);
        offers[_id] = Offer({
            seller: _seller,
            licenseType: _licenseType,
            isCancelled: false,
            photoDigest: _photoDigest,
            price: _price
        });

        emit OfferAdded(_id, _seller, _licenseType, _photoDigest, _price);
    }

    /**
     * @dev Accept an offer on the marketplace
     * @param _id Offer id
     * @param _licensee Address of the licensee that is buying the photo
     */
    function acceptOffer(bytes32 _id, address _licensee)
        external
        onlyOwner
        onlyValidAddress(_licensee)
        onlyActiveOffer(_id)
    {
        Offer storage offer = offers[_id];

        if (offer.price > 0) {
            require(
                token.transferFrom(_licensee, address(this), offer.price),
                "Token transfer to contract failed"
            );

            require(
                token.transfer(offer.seller, offer.price),
                "Token transfer to seller failed"
            );
        }

        offersByLicensee[_licensee].push(_id);

        emit OfferAccepted(_id, _licensee);
    }

    /**
     * @dev Change price of the offer
     * @param _id Offer id
     * @param _price Price of the offer in tokens
     */
    function setOfferPrice(bytes32 _id, uint256 _price)
        external
        onlyOwner
        onlyActiveOffer(_id)
    {
        uint256 oldPrice = offers[_id].price;

        offers[_id].price = _price;

        emit OfferPriceChanged(_id, oldPrice, _price);
    }

    /**
     * @dev Cancel offer
     * @param _id Offer id
     */
    function cancelOffer(bytes32 _id)
        external
        onlyOwner
        onlyActiveOffer(_id)
    {
        offers[_id].isCancelled = true;

        emit OfferCancelled(_id);
    }

    /**
     * @dev Get list of offers id from a seller
     * @param _seller The address of the seller to find its offers
     * @return Offer ids
     */
    function getOffers(address _seller) external view returns (bytes32[] memory) {
        return offersBySeller[_seller];
    }

    /**
     * @dev Get the offer by id
     * @param _id The offer id
     * @return Offer details
     */
    function getOfferById(bytes32 _id)
        external
        view
        returns (
            address seller,
            uint8 licenseType,
            bool isCancelled,
            bytes32 photoDigest,
            uint256 price
        )
    {
        Offer storage offer = offers[_id];

        seller = offer.seller;
        licenseType = offer.licenseType;
        isCancelled = offer.isCancelled;
        photoDigest = offer.photoDigest;
        price = offer.price;
    }

    /**
     * @dev Get the list of the offers id by a licensee
     * @param _licensee Address of a licensee of offers
     */
    function getLicenses(address _licensee)
        external
        view
        returns (bytes32[] memory)
    {
        return offersByLicensee[_licensee];
    }
}

/**
 *Submitted for verification at Etherscan.io on 2018-09-30
*/

pragma solidity ^0.4.24;


/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() public view returns (uint256);
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
}


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 * @dev Based on https://github.com/OpenZeppelin/zeppelin-solidity
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        assert(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}


/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * @dev Based on https://github.com/OpenZeppelin/zeppelin-solidity
 */
contract StandardToken is ERC20 {
    using SafeMath for uint256;

    uint256 internal _totalSupply;
    mapping(address => uint256) internal _balanceOf;
    mapping (address => mapping (address => uint256)) internal _allowance;

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Address cannot be zero");
        _;
    }

    modifier onlySufficientBalance(address from, uint256 value) {
        require(value <= _balanceOf[from], "Insufficient balance");
        _;
    }

    modifier onlySufficientAllowance(address owner, address spender, uint256 value) {
        require(value <= _allowance[owner][spender], "Insufficient allowance");
        _;
    }

    /**
      * @dev Transfers token to the specified address
      * @param to The address to transfer to.
      * @param value The amount to be transferred.
      */
    function transfer(address to, uint256 value)
        public
        onlyValidAddress(to)
        onlySufficientBalance(msg.sender, value)
        returns (bool)
    {
        _balanceOf[msg.sender] = _balanceOf[msg.sender].sub(value);
        _balanceOf[to] = _balanceOf[to].add(value);

        emit Transfer(msg.sender, to, value);

        return true;
    }

    /**
     * @dev Transfers tokens from one address to another
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value)
        public
        onlyValidAddress(to)
        onlySufficientBalance(from, value)
        onlySufficientAllowance(from, msg.sender, value)
        returns (bool)
    {
        _balanceOf[from] = _balanceOf[from].sub(value);
        _balanceOf[to] = _balanceOf[to].add(value);
        _allowance[from][msg.sender] = _allowance[from][msg.sender].sub(value);

        emit Transfer(from, to, value);

        return true;
    }

    /**
     * @dev Approves the passed address to spend the specified amount of tokens on behalf of msg.sender.
     *
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value)
        public
        onlyValidAddress(spender)
        returns (bool)
    {
        _allowance[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);

        return true;
    }

    /**
     * @dev Increases the amount of tokens that an owner allowed to a spender.
     *
     * approve should be called when _allowance[spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        public
        onlyValidAddress(spender)
        returns (bool)
    {
        _allowance[msg.sender][spender] = _allowance[msg.sender][spender].add(addedValue);

        emit Approval(msg.sender, spender, _allowance[msg.sender][spender]);

        return true;
    }

    /**
     * @dev Decreases the amount of tokens that an owner allowed to a spender.
     *
     * approve should be called when _allowance[spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        onlyValidAddress(spender)
        onlySufficientAllowance(msg.sender, spender, subtractedValue)
        returns (bool)
    {
        _allowance[msg.sender][spender] = _allowance[msg.sender][spender].sub(subtractedValue);

        emit Approval(msg.sender, spender, _allowance[msg.sender][spender]);

        return true;
    }

    /**
     * @dev Gets total number of tokens in existence
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param owner The address to query the the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address owner) public view returns (uint256) {
        return _balanceOf[owner];
    }

    /**
     * @dev Checks the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowance[owner][spender];
    }
}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 * @dev Based on https://github.com/OpenZeppelin/zeppelin-soliditysettable
 */
contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Can only be called by the owner");
        _;
    }

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Address cannot be zero");
        _;
    }

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() public {
        owner = msg.sender;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner)
        public
        onlyOwner
        onlyValidAddress(newOwner)
    {
        emit OwnershipTransferred(owner, newOwner);

        owner = newOwner;
    }
}


/**
 * @title Mintable token
 * @dev Standard token with minting
 * @dev Based on https://github.com/OpenZeppelin/zeppelin-solidity
 */
contract MintableToken is StandardToken, Ownable {
    bool public mintingFinished;
    uint256 public cap;

    event Mint(address indexed to, uint256 amount);
    event MintFinished();

    modifier onlyMinting() {
        require(!mintingFinished, "Minting is already finished");
        _;
    }

    modifier onlyNotExceedingCap(uint256 amount) {
        require(_totalSupply.add(amount) <= cap, "Total supply must not exceed cap");
        _;
    }

    constructor(uint256 _cap) public {
        cap = _cap;
    }

    /**
     * @dev Creates new tokens for the given address
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mint(address to, uint256 amount)
        public
        onlyOwner
        onlyMinting
        onlyValidAddress(to)
        onlyNotExceedingCap(amount)
        returns (bool)
    {
        mintImpl(to, amount);

        return true;
    }

    /**
     * @dev Creates new tokens for the given addresses
     * @param addresses The array of addresses that will receive the minted tokens.
     * @param amounts The array of amounts of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mintMany(address[] addresses, uint256[] amounts)
        public
        onlyOwner
        onlyMinting
        onlyNotExceedingCap(sum(amounts))
        returns (bool)
    {
        require(
            addresses.length == amounts.length,
            "Addresses array must be the same size as amounts array"
        );

        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Address cannot be zero");
            mintImpl(addresses[i], amounts[i]);
        }

        return true;
    }

    /**
     * @dev Stops minting new tokens.
     * @return True if the operation was successful.
     */
    function finishMinting()
        public
        onlyOwner
        onlyMinting
        returns (bool)
    {
        mintingFinished = true;

        emit MintFinished();

        return true;
    }

    function mintImpl(address to, uint256 amount) private {
        _totalSupply = _totalSupply.add(amount);
        _balanceOf[to] = _balanceOf[to].add(amount);

        emit Mint(to, amount);
        emit Transfer(address(0), to, amount);
    }

    function sum(uint256[] arr) private pure returns (uint256) {
        uint256 aggr = 0;
        for (uint256 i = 0; i < arr.length; i++) {
            aggr = aggr.add(arr[i]);
        }
        return aggr;
    }
}


contract PhotonTestToken is MintableToken {
    string public name = "PhotonTestToken";
    string public symbol = "PHT";
    uint256 public decimals = 18;
    uint256 public cap = 120 * 10**6 * 10**decimals;

    // solhint-disable-next-line no-empty-blocks
    constructor() public MintableToken(cap) {}
}
pragma solidity >=0.4.22 <0.6.0;

contract Migrations {
  address public owner;
  uint256 public last_completed_migration;

  modifier restricted() {
    if (msg.sender == owner) _;
  }

  constructor() public {
    owner = msg.sender;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }

  function upgrade(address new_address) public restricted {
    Migrations upgraded = Migrations(new_address);
    upgraded.setCompleted(last_completed_migration);
  }
}

pragma solidity ^0.4.24;

import "./PhotonTestToken.sol";


/**
 * @title PhotochainMarketplace
 * @dev Marketplace to make and accept offers using PhotonToken
 */
contract PhotochainMarketplace is Ownable {
    /**
     * Event for offer creation logging
     * @param id Generated unique offer id
     * @param seller Addess of seller of the photo
     * @param licenseType Which license is applied on the offer
     * @param photoDigest 256-bit hash of the photo
     * @param price How many tokens to pay to accept the offer
     */
    event OfferAdded(
        bytes32 indexed id,
        address indexed seller,
        uint8 licenseType,
        bytes32 photoDigest,
        uint256 price
    );

    /**
     * Event for offer acceptance logging
     * @param id Offer id to accept
     * @param licensee Address of the account that bought license
     */
    event OfferAccepted(bytes32 indexed id, address indexed licensee);

    /**
     * Event for offer price change
     * @param id Offer id to update
     * @param oldPrice Previous price in tokens
     * @param newPrice New price in tokens
     */
    event OfferPriceChanged(bytes32 indexed id, uint256 oldPrice, uint256 newPrice);

    /**
     * Event for offer cancellation
     * @param id Offer id to cancel
     */
    event OfferCancelled(bytes32 indexed id);

    struct Offer {
        address seller;
        uint8 licenseType;
        bool isCancelled;
        bytes32 photoDigest;
        uint256 price;
    }

    ERC20 public token;

    // List of the offers
    mapping(bytes32 => Offer) public offers;

    // List of offer ids by seller
    mapping(address => bytes32[]) public offersBySeller;

    // List of offer ids by licensee
    mapping(address => bytes32[]) public offersByLicensee;

    modifier onlyValidAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }

    modifier onlyActiveOffer(bytes32 _id) {
        require(offers[_id].seller != address(0), "Offer does not exists");
        require(!offers[_id].isCancelled, "Offer is cancelled");
        _;
    }

    /**
     * @param _token Address of the PhotonToken contract
     */
    constructor(ERC20 _token) public onlyValidAddress(address(_token)) {
        token = _token;
    }

    /**
       @dev Sets accounting token address
     * @param _token Address of the PhotonToken contract
     */
    function setToken(ERC20 _token)
        external
        onlyOwner
        onlyValidAddress(address(_token))
    {
        token = _token;
    }

    /**
     * @dev Add an offer to the marketplace
     * @param _seller Address of the photo author
     * @param _licenseType License type for the offer
     * @param _photoDigest 256-bit hash of the photo
     * @param _price Price of the offer
     */
    function addOffer(
        address _seller,
        uint8 _licenseType,
        bytes32 _photoDigest,
        uint256 _price
    )
        external
        onlyOwner
        onlyValidAddress(_seller)
    {
        bytes32 _id = keccak256(
            abi.encodePacked(
                _seller,
                _licenseType,
                _photoDigest
            )
        );
        require(offers[_id].seller == address(0), "Offer already exists");

        offersBySeller[_seller].push(_id);
        offers[_id] = Offer({
            seller: _seller,
            licenseType: _licenseType,
            isCancelled: false,
            photoDigest: _photoDigest,
            price: _price
        });

        emit OfferAdded(_id, _seller, _licenseType, _photoDigest, _price);
    }

    /**
     * @dev Accept an offer on the marketplace
     * @param _id Offer id
     * @param _licensee Address of the licensee that is buying the photo
     */
    function acceptOffer(bytes32 _id, address _licensee)
        external
        onlyOwner
        onlyValidAddress(_licensee)
        onlyActiveOffer(_id)
    {
        Offer storage offer = offers[_id];

        if (offer.price > 0) {
            require(
                token.transferFrom(_licensee, address(this), offer.price),
                "Token transfer to contract failed"
            );

            require(
                token.transfer(offer.seller, offer.price),
                "Token transfer to seller failed"
            );
        }

        offersByLicensee[_licensee].push(_id);

        emit OfferAccepted(_id, _licensee);
    }

    /**
     * @dev Change price of the offer
     * @param _id Offer id
     * @param _price Price of the offer in tokens
     */
    function setOfferPrice(bytes32 _id, uint256 _price)
        external
        onlyOwner
        onlyActiveOffer(_id)
    {
        uint256 oldPrice = offers[_id].price;

        offers[_id].price = _price;

        emit OfferPriceChanged(_id, oldPrice, _price);
    }

    /**
     * @dev Cancel offer
     * @param _id Offer id
     */
    function cancelOffer(bytes32 _id)
        external
        onlyOwner
        onlyActiveOffer(_id)
    {
        offers[_id].isCancelled = true;

        emit OfferCancelled(_id);
    }

    /**
     * @dev Get list of offers id from a seller
     * @param _seller The address of the seller to find its offers
     * @return Offer ids
     */
    function getOffers(address _seller) external view returns (bytes32[] memory) {
        return offersBySeller[_seller];
    }

    /**
     * @dev Get the offer by id
     * @param _id The offer id
     * @return Offer details
     */
    function getOfferById(bytes32 _id)
        external
        view
        returns (
            address seller,
            uint8 licenseType,
            bool isCancelled,
            bytes32 photoDigest,
            uint256 price
        )
    {
        Offer storage offer = offers[_id];

        seller = offer.seller;
        licenseType = offer.licenseType;
        isCancelled = offer.isCancelled;
        photoDigest = offer.photoDigest;
        price = offer.price;
    }

    /**
     * @dev Get the list of the offers id by a licensee
     * @param _licensee Address of a licensee of offers
     */
    function getLicenses(address _licensee)
        external
        view
        returns (bytes32[] memory)
    {
        return offersByLicensee[_licensee];
    }
}

/**
 *Submitted for verification at Etherscan.io on 2018-09-30
*/

pragma solidity ^0.4.24;


/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() public view returns (uint256);
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
}


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 * @dev Based on https://github.com/OpenZeppelin/zeppelin-solidity
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        assert(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}


/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * @dev Based on https://github.com/OpenZeppelin/zeppelin-solidity
 */
contract StandardToken is ERC20 {
    using SafeMath for uint256;

    uint256 internal _totalSupply;
    mapping(address => uint256) internal _balanceOf;
    mapping (address => mapping (address => uint256)) internal _allowance;

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Address cannot be zero");
        _;
    }

    modifier onlySufficientBalance(address from, uint256 value) {
        require(value <= _balanceOf[from], "Insufficient balance");
        _;
    }

    modifier onlySufficientAllowance(address owner, address spender, uint256 value) {
        require(value <= _allowance[owner][spender], "Insufficient allowance");
        _;
    }

    /**
      * @dev Transfers token to the specified address
      * @param to The address to transfer to.
      * @param value The amount to be transferred.
      */
    function transfer(address to, uint256 value)
        public
        onlyValidAddress(to)
        onlySufficientBalance(msg.sender, value)
        returns (bool)
    {
        _balanceOf[msg.sender] = _balanceOf[msg.sender].sub(value);
        _balanceOf[to] = _balanceOf[to].add(value);

        emit Transfer(msg.sender, to, value);

        return true;
    }

    /**
     * @dev Transfers tokens from one address to another
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value)
        public
        onlyValidAddress(to)
        onlySufficientBalance(from, value)
        onlySufficientAllowance(from, msg.sender, value)
        returns (bool)
    {
        _balanceOf[from] = _balanceOf[from].sub(value);
        _balanceOf[to] = _balanceOf[to].add(value);
        _allowance[from][msg.sender] = _allowance[from][msg.sender].sub(value);

        emit Transfer(from, to, value);

        return true;
    }

    /**
     * @dev Approves the passed address to spend the specified amount of tokens on behalf of msg.sender.
     *
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value)
        public
        onlyValidAddress(spender)
        returns (bool)
    {
        _allowance[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);

        return true;
    }

    /**
     * @dev Increases the amount of tokens that an owner allowed to a spender.
     *
     * approve should be called when _allowance[spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        public
        onlyValidAddress(spender)
        returns (bool)
    {
        _allowance[msg.sender][spender] = _allowance[msg.sender][spender].add(addedValue);

        emit Approval(msg.sender, spender, _allowance[msg.sender][spender]);

        return true;
    }

    /**
     * @dev Decreases the amount of tokens that an owner allowed to a spender.
     *
     * approve should be called when _allowance[spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        onlyValidAddress(spender)
        onlySufficientAllowance(msg.sender, spender, subtractedValue)
        returns (bool)
    {
        _allowance[msg.sender][spender] = _allowance[msg.sender][spender].sub(subtractedValue);

        emit Approval(msg.sender, spender, _allowance[msg.sender][spender]);

        return true;
    }

    /**
     * @dev Gets total number of tokens in existence
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param owner The address to query the the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address owner) public view returns (uint256) {
        return _balanceOf[owner];
    }

    /**
     * @dev Checks the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowance[owner][spender];
    }
}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 * @dev Based on https://github.com/OpenZeppelin/zeppelin-soliditysettable
 */
contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Can only be called by the owner");
        _;
    }

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Address cannot be zero");
        _;
    }

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() public {
        owner = msg.sender;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner)
        public
        onlyOwner
        onlyValidAddress(newOwner)
    {
        emit OwnershipTransferred(owner, newOwner);

        owner = newOwner;
    }
}


/**
 * @title Mintable token
 * @dev Standard token with minting
 * @dev Based on https://github.com/OpenZeppelin/zeppelin-solidity
 */
contract MintableToken is StandardToken, Ownable {
    bool public mintingFinished;
    uint256 public cap;

    event Mint(address indexed to, uint256 amount);
    event MintFinished();

    modifier onlyMinting() {
        require(!mintingFinished, "Minting is already finished");
        _;
    }

    modifier onlyNotExceedingCap(uint256 amount) {
        require(_totalSupply.add(amount) <= cap, "Total supply must not exceed cap");
        _;
    }

    constructor(uint256 _cap) public {
        cap = _cap;
    }

    /**
     * @dev Creates new tokens for the given address
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mint(address to, uint256 amount)
        public
        onlyOwner
        onlyMinting
        onlyValidAddress(to)
        onlyNotExceedingCap(amount)
        returns (bool)
    {
        mintImpl(to, amount);

        return true;
    }

    /**
     * @dev Creates new tokens for the given addresses
     * @param addresses The array of addresses that will receive the minted tokens.
     * @param amounts The array of amounts of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mintMany(address[] addresses, uint256[] amounts)
        public
        onlyOwner
        onlyMinting
        onlyNotExceedingCap(sum(amounts))
        returns (bool)
    {
        require(
            addresses.length == amounts.length,
            "Addresses array must be the same size as amounts array"
        );

        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Address cannot be zero");
            mintImpl(addresses[i], amounts[i]);
        }

        return true;
    }

    /**
     * @dev Stops minting new tokens.
     * @return True if the operation was successful.
     */
    function finishMinting()
        public
        onlyOwner
        onlyMinting
        returns (bool)
    {
        mintingFinished = true;

        emit MintFinished();

        return true;
    }

    function mintImpl(address to, uint256 amount) private {
        _totalSupply = _totalSupply.add(amount);
        _balanceOf[to] = _balanceOf[to].add(amount);

        emit Mint(to, amount);
        emit Transfer(address(0), to, amount);
    }

    function sum(uint256[] arr) private pure returns (uint256) {
        uint256 aggr = 0;
        for (uint256 i = 0; i < arr.length; i++) {
            aggr = aggr.add(arr[i]);
        }
        return aggr;
    }
}


contract PhotonTestToken is MintableToken {
    string public name = "PhotonTestToken";
    string public symbol = "PHT";
    uint256 public decimals = 18;
    uint256 public cap = 120 * 10**6 * 10**decimals;

    // solhint-disable-next-line no-empty-blocks
    constructor() public MintableToken(cap) {}
}
pragma solidity >=0.4.22 <0.6.0;

contract Migrations {
  address public owner;
  uint256 public last_completed_migration;

  modifier restricted() {
    if (msg.sender == owner) _;
  }

  constructor() public {
    owner = msg.sender;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }

  function upgrade(address new_address) public restricted {
    Migrations upgraded = Migrations(new_address);
    upgraded.setCompleted(last_completed_migration);
  }
}

pragma solidity ^0.4.24;

import "./PhotonTestToken.sol";


/**
 * @title PhotochainMarketplace
 * @dev Marketplace to make and accept offers using PhotonToken
 */
contract PhotochainMarketplace is Ownable {
    /**
     * Event for offer creation logging
     * @param id Generated unique offer id
     * @param seller Addess of seller of the photo
     * @param licenseType Which license is applied on the offer
     * @param photoDigest 256-bit hash of the photo
     * @param price How many tokens to pay to accept the offer
     */
    event OfferAdded(
        bytes32 indexed id,
        address indexed seller,
        uint8 licenseType,
        bytes32 photoDigest,
        uint256 price
    );

    /**
     * Event for offer acceptance logging
     * @param id Offer id to accept
     * @param licensee Address of the account that bought license
     */
    event OfferAccepted(bytes32 indexed id, address indexed licensee);

    /**
     * Event for offer price change
     * @param id Offer id to update
     * @param oldPrice Previous price in tokens
     * @param newPrice New price in tokens
     */
    event OfferPriceChanged(bytes32 indexed id, uint256 oldPrice, uint256 newPrice);

    /**
     * Event for offer cancellation
     * @param id Offer id to cancel
     */
    event OfferCancelled(bytes32 indexed id);

    struct Offer {
        address seller;
        uint8 licenseType;
        bool isCancelled;
        bytes32 photoDigest;
        uint256 price;
    }

    ERC20 public token;

    // List of the offers
    mapping(bytes32 => Offer) public offers;

    // List of offer ids by seller
    mapping(address => bytes32[]) public offersBySeller;

    // List of offer ids by licensee
    mapping(address => bytes32[]) public offersByLicensee;

    modifier onlyValidAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }

    modifier onlyActiveOffer(bytes32 _id) {
        require(offers[_id].seller != address(0), "Offer does not exists");
        require(!offers[_id].isCancelled, "Offer is cancelled");
        _;
    }

    /**
     * @param _token Address of the PhotonToken contract
     */
    constructor(ERC20 _token) public onlyValidAddress(address(_token)) {
        token = _token;
    }

    /**
       @dev Sets accounting token address
     * @param _token Address of the PhotonToken contract
     */
    function setToken(ERC20 _token)
        external
        onlyOwner
        onlyValidAddress(address(_token))
    {
        token = _token;
    }

    /**
     * @dev Add an offer to the marketplace
     * @param _seller Address of the photo author
     * @param _licenseType License type for the offer
     * @param _photoDigest 256-bit hash of the photo
     * @param _price Price of the offer
     */
    function addOffer(
        address _seller,
        uint8 _licenseType,
        bytes32 _photoDigest,
        uint256 _price
    )
        external
        onlyOwner
        onlyValidAddress(_seller)
    {
        bytes32 _id = keccak256(
            abi.encodePacked(
                _seller,
                _licenseType,
                _photoDigest
            )
        );
        require(offers[_id].seller == address(0), "Offer already exists");

        offersBySeller[_seller].push(_id);
        offers[_id] = Offer({
            seller: _seller,
            licenseType: _licenseType,
            isCancelled: false,
            photoDigest: _photoDigest,
            price: _price
        });

        emit OfferAdded(_id, _seller, _licenseType, _photoDigest, _price);
    }

    /**
     * @dev Accept an offer on the marketplace
     * @param _id Offer id
     * @param _licensee Address of the licensee that is buying the photo
     */
    function acceptOffer(bytes32 _id, address _licensee)
        external
        onlyOwner
        onlyValidAddress(_licensee)
        onlyActiveOffer(_id)
    {
        Offer storage offer = offers[_id];

        if (offer.price > 0) {
            require(
                token.transferFrom(_licensee, address(this), offer.price),
                "Token transfer to contract failed"
            );

            require(
                token.transfer(offer.seller, offer.price),
                "Token transfer to seller failed"
            );
        }

        offersByLicensee[_licensee].push(_id);

        emit OfferAccepted(_id, _licensee);
    }

    /**
     * @dev Change price of the offer
     * @param _id Offer id
     * @param _price Price of the offer in tokens
     */
    function setOfferPrice(bytes32 _id, uint256 _price)
        external
        onlyOwner
        onlyActiveOffer(_id)
    {
        uint256 oldPrice = offers[_id].price;

        offers[_id].price = _price;

        emit OfferPriceChanged(_id, oldPrice, _price);
    }

    /**
     * @dev Cancel offer
     * @param _id Offer id
     */
    function cancelOffer(bytes32 _id)
        external
        onlyOwner
        onlyActiveOffer(_id)
    {
        offers[_id].isCancelled = true;

        emit OfferCancelled(_id);
    }

    /**
     * @dev Get list of offers id from a seller
     * @param _seller The address of the seller to find its offers
     * @return Offer ids
     */
    function getOffers(address _seller) external view returns (bytes32[] memory) {
        return offersBySeller[_seller];
    }

    /**
     * @dev Get the offer by id
     * @param _id The offer id
     * @return Offer details
     */
    function getOfferById(bytes32 _id)
        external
        view
        returns (
            address seller,
            uint8 licenseType,
            bool isCancelled,
            bytes32 photoDigest,
            uint256 price
        )
    {
        Offer storage offer = offers[_id];

        seller = offer.seller;
        licenseType = offer.licenseType;
        isCancelled = offer.isCancelled;
        photoDigest = offer.photoDigest;
        price = offer.price;
    }

    /**
     * @dev Get the list of the offers id by a licensee
     * @param _licensee Address of a licensee of offers
     */
    function getLicenses(address _licensee)
        external
        view
        returns (bytes32[] memory)
    {
        return offersByLicensee[_licensee];
    }
}

/**
 *Submitted for verification at Etherscan.io on 2018-09-30
*/

pragma solidity ^0.4.24;


/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() public view returns (uint256);
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
}


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 * @dev Based on https://github.com/OpenZeppelin/zeppelin-solidity
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        assert(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}


/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * @dev Based on https://github.com/OpenZeppelin/zeppelin-solidity
 */
contract StandardToken is ERC20 {
    using SafeMath for uint256;

    uint256 internal _totalSupply;
    mapping(address => uint256) internal _balanceOf;
    mapping (address => mapping (address => uint256)) internal _allowance;

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Address cannot be zero");
        _;
    }

    modifier onlySufficientBalance(address from, uint256 value) {
        require(value <= _balanceOf[from], "Insufficient balance");
        _;
    }

    modifier onlySufficientAllowance(address owner, address spender, uint256 value) {
        require(value <= _allowance[owner][spender], "Insufficient allowance");
        _;
    }

    /**
      * @dev Transfers token to the specified address
      * @param to The address to transfer to.
      * @param value The amount to be transferred.
      */
    function transfer(address to, uint256 value)
        public
        onlyValidAddress(to)
        onlySufficientBalance(msg.sender, value)
        returns (bool)
    {
        _balanceOf[msg.sender] = _balanceOf[msg.sender].sub(value);
        _balanceOf[to] = _balanceOf[to].add(value);

        emit Transfer(msg.sender, to, value);

        return true;
    }

    /**
     * @dev Transfers tokens from one address to another
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value)
        public
        onlyValidAddress(to)
        onlySufficientBalance(from, value)
        onlySufficientAllowance(from, msg.sender, value)
        returns (bool)
    {
        _balanceOf[from] = _balanceOf[from].sub(value);
        _balanceOf[to] = _balanceOf[to].add(value);
        _allowance[from][msg.sender] = _allowance[from][msg.sender].sub(value);

        emit Transfer(from, to, value);

        return true;
    }

    /**
     * @dev Approves the passed address to spend the specified amount of tokens on behalf of msg.sender.
     *
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value)
        public
        onlyValidAddress(spender)
        returns (bool)
    {
        _allowance[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);

        return true;
    }

    /**
     * @dev Increases the amount of tokens that an owner allowed to a spender.
     *
     * approve should be called when _allowance[spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        public
        onlyValidAddress(spender)
        returns (bool)
    {
        _allowance[msg.sender][spender] = _allowance[msg.sender][spender].add(addedValue);

        emit Approval(msg.sender, spender, _allowance[msg.sender][spender]);

        return true;
    }

    /**
     * @dev Decreases the amount of tokens that an owner allowed to a spender.
     *
     * approve should be called when _allowance[spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        onlyValidAddress(spender)
        onlySufficientAllowance(msg.sender, spender, subtractedValue)
        returns (bool)
    {
        _allowance[msg.sender][spender] = _allowance[msg.sender][spender].sub(subtractedValue);

        emit Approval(msg.sender, spender, _allowance[msg.sender][spender]);

        return true;
    }

    /**
     * @dev Gets total number of tokens in existence
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param owner The address to query the the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address owner) public view returns (uint256) {
        return _balanceOf[owner];
    }

    /**
     * @dev Checks the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowance[owner][spender];
    }
}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 * @dev Based on https://github.com/OpenZeppelin/zeppelin-soliditysettable
 */
contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Can only be called by the owner");
        _;
    }

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Address cannot be zero");
        _;
    }

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() public {
        owner = msg.sender;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner)
        public
        onlyOwner
        onlyValidAddress(newOwner)
    {
        emit OwnershipTransferred(owner, newOwner);

        owner = newOwner;
    }
}


/**
 * @title Mintable token
 * @dev Standard token with minting
 * @dev Based on https://github.com/OpenZeppelin/zeppelin-solidity
 */
contract MintableToken is StandardToken, Ownable {
    bool public mintingFinished;
    uint256 public cap;

    event Mint(address indexed to, uint256 amount);
    event MintFinished();

    modifier onlyMinting() {
        require(!mintingFinished, "Minting is already finished");
        _;
    }

    modifier onlyNotExceedingCap(uint256 amount) {
        require(_totalSupply.add(amount) <= cap, "Total supply must not exceed cap");
        _;
    }

    constructor(uint256 _cap) public {
        cap = _cap;
    }

    /**
     * @dev Creates new tokens for the given address
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mint(address to, uint256 amount)
        public
        onlyOwner
        onlyMinting
        onlyValidAddress(to)
        onlyNotExceedingCap(amount)
        returns (bool)
    {
        mintImpl(to, amount);

        return true;
    }

    /**
     * @dev Creates new tokens for the given addresses
     * @param addresses The array of addresses that will receive the minted tokens.
     * @param amounts The array of amounts of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mintMany(address[] addresses, uint256[] amounts)
        public
        onlyOwner
        onlyMinting
        onlyNotExceedingCap(sum(amounts))
        returns (bool)
    {
        require(
            addresses.length == amounts.length,
            "Addresses array must be the same size as amounts array"
        );

        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Address cannot be zero");
            mintImpl(addresses[i], amounts[i]);
        }

        return true;
    }

    /**
     * @dev Stops minting new tokens.
     * @return True if the operation was successful.
     */
    function finishMinting()
        public
        onlyOwner
        onlyMinting
        returns (bool)
    {
        mintingFinished = true;

        emit MintFinished();

        return true;
    }

    function mintImpl(address to, uint256 amount) private {
        _totalSupply = _totalSupply.add(amount);
        _balanceOf[to] = _balanceOf[to].add(amount);

        emit Mint(to, amount);
        emit Transfer(address(0), to, amount);
    }

    function sum(uint256[] arr) private pure returns (uint256) {
        uint256 aggr = 0;
        for (uint256 i = 0; i < arr.length; i++) {
            aggr = aggr.add(arr[i]);
        }
        return aggr;
    }
}


contract PhotonTestToken is MintableToken {
    string public name = "PhotonTestToken";
    string public symbol = "PHT";
    uint256 public decimals = 18;
    uint256 public cap = 120 * 10**6 * 10**decimals;

    // solhint-disable-next-line no-empty-blocks
    constructor() public MintableToken(cap) {}
}
