pragma solidity 0.5.12;

contract DeliverFunds {
    constructor(address payable target) public payable {
        selfdestruct(target);
    }
}
pragma solidity 0.5.12;

/**
 * (E)t)h)e)x) Superprize Contract 
 *  This smart-contract is the part of Ethex Lottery fair game.
 *  See latest version at https://github.com/ethex-bet/ethex-lottery 
 *  http://ethex.bet
 */
 
 import "./DeliverFunds.sol";
 import "./Ownable.sol";
 
 contract EthexSuperprize is Ownable {
    struct Payout {
        uint256 index;
        uint256 amount;
        uint256 block;
        address payable winnerAddress;
        uint256 betId;
    }
     
    Payout[] public payouts;
    
    address public lotoAddress;
    address payable public newVersionAddress;
    EthexSuperprize public previousContract;
    uint256 public hold;
    
    event Superprize (
        uint256 index,
        uint256 amount,
        address winner,
        uint256 betId,
        byte state
    );
    
    uint8 internal constant PARTS = 6;
    uint256 internal constant PRECISION = 1 ether;
    uint256 internal constant MONTHLY = 150000;

    function() external payable { }
    
    function initSuperprize(address payable winner, uint256 betId) external {
        require(msg.sender == lotoAddress, "Loto only");
        uint256 amount = address(this).balance - hold;
        hold = address(this).balance;
        uint256 sum;
        uint256 temp;
        for (uint256 i = 1; i < PARTS; i++) {
            temp = amount * PRECISION * (i - 1 + 10) / 75 / PRECISION;
            sum += temp;
            payouts.push(Payout(i, temp, block.number + i * MONTHLY, winner, betId));
        }
        payouts.push(Payout(PARTS, amount - sum, block.number + PARTS * MONTHLY, winner, betId));
        emit Superprize(0, amount, winner, betId, 0);
    }
    
    function paySuperprize() external onlyOwner {
        if (payouts.length == 0)
            return;
        Payout[] memory payoutArray = new Payout[](payouts.length);
        uint i = payouts.length;
        while (i > 0) {
            i--;
            if (payouts[i].block <= block.number) {
                emit Superprize(payouts[i].index, payouts[i].amount, payouts[i].winnerAddress, payouts[i].betId, 0x01);
                hold -= payouts[i].amount;
            }
            payoutArray[i] = payouts[i];
            payouts.pop();
        }
        for (i = 0; i < payoutArray.length; i++)
            if (payoutArray[i].block > block.number)
                payouts.push(payoutArray[i]);
        for (i = 0; i < payoutArray.length; i++)
            if (payoutArray[i].block <= block.number && !payoutArray[i].winnerAddress.send(payoutArray[i].amount))
                (new DeliverFunds).value(payoutArray[i].amount)(payoutArray[i].winnerAddress);
    }
     
    function setOldVersion(address payable oldAddress) external onlyOwner {
        previousContract = EthexSuperprize(oldAddress);
        lotoAddress = previousContract.lotoAddress();
        hold = previousContract.hold();
        uint256 index;
        uint256 amount;
        uint256 betBlock;
        address payable winner;
        uint256 betId;
        uint256 payoutsCount = previousContract.getPayoutsCount();
        for (uint i = 0; i < payoutsCount; i++) {
            (index, amount, betBlock, winner, betId) = previousContract.payouts(i);
            payouts.push(Payout(index, amount, betBlock, winner, betId));
        }
        previousContract.migrate();
    }
    
    function setNewVersion(address payable newVersion) external onlyOwner {
        newVersionAddress = newVersion;
    }
    
    function setLoto(address loto) external onlyOwner {
        lotoAddress = loto;
    }
    
    function migrate() external {
        require(msg.sender == owner || msg.sender == newVersionAddress);
        require(newVersionAddress != address(0));
        newVersionAddress.transfer(address(this).balance);
    }   

    function getPayoutsCount() public view returns (uint256) { return payouts.length; }
}
pragma solidity 0.5.12;

contract Ownable {
    address payable public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    constructor () internal {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }
    
    function transferOwnership(address payable newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
pragma solidity 0.5.12;

contract DeliverFunds {
    constructor(address payable target) public payable {
        selfdestruct(target);
    }
}
pragma solidity 0.5.12;

/**
 * (E)t)h)e)x) Superprize Contract 
 *  This smart-contract is the part of Ethex Lottery fair game.
 *  See latest version at https://github.com/ethex-bet/ethex-lottery 
 *  http://ethex.bet
 */
 
 import "./DeliverFunds.sol";
 import "./Ownable.sol";
 
 contract EthexSuperprize is Ownable {
    struct Payout {
        uint256 index;
        uint256 amount;
        uint256 block;
        address payable winnerAddress;
        uint256 betId;
    }
     
    Payout[] public payouts;
    
    address public lotoAddress;
    address payable public newVersionAddress;
    EthexSuperprize public previousContract;
    uint256 public hold;
    
    event Superprize (
        uint256 index,
        uint256 amount,
        address winner,
        uint256 betId,
        byte state
    );
    
    uint8 internal constant PARTS = 6;
    uint256 internal constant PRECISION = 1 ether;
    uint256 internal constant MONTHLY = 150000;

    function() external payable { }
    
    function initSuperprize(address payable winner, uint256 betId) external {
        require(msg.sender == lotoAddress, "Loto only");
        uint256 amount = address(this).balance - hold;
        hold = address(this).balance;
        uint256 sum;
        uint256 temp;
        for (uint256 i = 1; i < PARTS; i++) {
            temp = amount * PRECISION * (i - 1 + 10) / 75 / PRECISION;
            sum += temp;
            payouts.push(Payout(i, temp, block.number + i * MONTHLY, winner, betId));
        }
        payouts.push(Payout(PARTS, amount - sum, block.number + PARTS * MONTHLY, winner, betId));
        emit Superprize(0, amount, winner, betId, 0);
    }
    
    function paySuperprize() external onlyOwner {
        if (payouts.length == 0)
            return;
        Payout[] memory payoutArray = new Payout[](payouts.length);
        uint i = payouts.length;
        while (i > 0) {
            i--;
            if (payouts[i].block <= block.number) {
                emit Superprize(payouts[i].index, payouts[i].amount, payouts[i].winnerAddress, payouts[i].betId, 0x01);
                hold -= payouts[i].amount;
            }
            payoutArray[i] = payouts[i];
            payouts.pop();
        }
        for (i = 0; i < payoutArray.length; i++)
            if (payoutArray[i].block > block.number)
                payouts.push(payoutArray[i]);
        for (i = 0; i < payoutArray.length; i++)
            if (payoutArray[i].block <= block.number && !payoutArray[i].winnerAddress.send(payoutArray[i].amount))
                (new DeliverFunds).value(payoutArray[i].amount)(payoutArray[i].winnerAddress);
    }
     
    function setOldVersion(address payable oldAddress) external onlyOwner {
        previousContract = EthexSuperprize(oldAddress);
        lotoAddress = previousContract.lotoAddress();
        hold = previousContract.hold();
        uint256 index;
        uint256 amount;
        uint256 betBlock;
        address payable winner;
        uint256 betId;
        uint256 payoutsCount = previousContract.getPayoutsCount();
        for (uint i = 0; i < payoutsCount; i++) {
            (index, amount, betBlock, winner, betId) = previousContract.payouts(i);
            payouts.push(Payout(index, amount, betBlock, winner, betId));
        }
        previousContract.migrate();
    }
    
    function setNewVersion(address payable newVersion) external onlyOwner {
        newVersionAddress = newVersion;
    }
    
    function setLoto(address loto) external onlyOwner {
        lotoAddress = loto;
    }
    
    function migrate() external {
        require(msg.sender == owner || msg.sender == newVersionAddress);
        require(newVersionAddress != address(0));
        newVersionAddress.transfer(address(this).balance);
    }   

    function getPayoutsCount() public view returns (uint256) { return payouts.length; }
}
pragma solidity 0.5.12;

contract Ownable {
    address payable public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    constructor () internal {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }
    
    function transferOwnership(address payable newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
pragma solidity 0.5.12;

contract DeliverFunds {
    constructor(address payable target) public payable {
        selfdestruct(target);
    }
}
pragma solidity 0.5.12;

/**
 * (E)t)h)e)x) Superprize Contract 
 *  This smart-contract is the part of Ethex Lottery fair game.
 *  See latest version at https://github.com/ethex-bet/ethex-lottery 
 *  http://ethex.bet
 */
 
 import "./DeliverFunds.sol";
 import "./Ownable.sol";
 
 contract EthexSuperprize is Ownable {
    struct Payout {
        uint256 index;
        uint256 amount;
        uint256 block;
        address payable winnerAddress;
        uint256 betId;
    }
     
    Payout[] public payouts;
    
    address public lotoAddress;
    address payable public newVersionAddress;
    EthexSuperprize public previousContract;
    uint256 public hold;
    
    event Superprize (
        uint256 index,
        uint256 amount,
        address winner,
        uint256 betId,
        byte state
    );
    
    uint8 internal constant PARTS = 6;
    uint256 internal constant PRECISION = 1 ether;
    uint256 internal constant MONTHLY = 150000;

    function() external payable { }
    
    function initSuperprize(address payable winner, uint256 betId) external {
        require(msg.sender == lotoAddress, "Loto only");
        uint256 amount = address(this).balance - hold;
        hold = address(this).balance;
        uint256 sum;
        uint256 temp;
        for (uint256 i = 1; i < PARTS; i++) {
            temp = amount * PRECISION * (i - 1 + 10) / 75 / PRECISION;
            sum += temp;
            payouts.push(Payout(i, temp, block.number + i * MONTHLY, winner, betId));
        }
        payouts.push(Payout(PARTS, amount - sum, block.number + PARTS * MONTHLY, winner, betId));
        emit Superprize(0, amount, winner, betId, 0);
    }
    
    function paySuperprize() external onlyOwner {
        if (payouts.length == 0)
            return;
        Payout[] memory payoutArray = new Payout[](payouts.length);
        uint i = payouts.length;
        while (i > 0) {
            i--;
            if (payouts[i].block <= block.number) {
                emit Superprize(payouts[i].index, payouts[i].amount, payouts[i].winnerAddress, payouts[i].betId, 0x01);
                hold -= payouts[i].amount;
            }
            payoutArray[i] = payouts[i];
            payouts.pop();
        }
        for (i = 0; i < payoutArray.length; i++)
            if (payoutArray[i].block > block.number)
                payouts.push(payoutArray[i]);
        for (i = 0; i < payoutArray.length; i++)
            if (payoutArray[i].block <= block.number && !payoutArray[i].winnerAddress.send(payoutArray[i].amount))
                (new DeliverFunds).value(payoutArray[i].amount)(payoutArray[i].winnerAddress);
    }
     
    function setOldVersion(address payable oldAddress) external onlyOwner {
        previousContract = EthexSuperprize(oldAddress);
        lotoAddress = previousContract.lotoAddress();
        hold = previousContract.hold();
        uint256 index;
        uint256 amount;
        uint256 betBlock;
        address payable winner;
        uint256 betId;
        uint256 payoutsCount = previousContract.getPayoutsCount();
        for (uint i = 0; i < payoutsCount; i++) {
            (index, amount, betBlock, winner, betId) = previousContract.payouts(i);
            payouts.push(Payout(index, amount, betBlock, winner, betId));
        }
        previousContract.migrate();
    }
    
    function setNewVersion(address payable newVersion) external onlyOwner {
        newVersionAddress = newVersion;
    }
    
    function setLoto(address loto) external onlyOwner {
        lotoAddress = loto;
    }
    
    function migrate() external {
        require(msg.sender == owner || msg.sender == newVersionAddress);
        require(newVersionAddress != address(0));
        newVersionAddress.transfer(address(this).balance);
    }   

    function getPayoutsCount() public view returns (uint256) { return payouts.length; }
}
pragma solidity 0.5.12;

contract Ownable {
    address payable public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    constructor () internal {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }
    
    function transferOwnership(address payable newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
