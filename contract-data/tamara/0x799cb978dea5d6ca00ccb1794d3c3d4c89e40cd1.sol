/**
 *  @title Arbitrator
 *  @author Clément Lesaege - <clement@lesaege.com>
 */

pragma solidity ^0.5;

import "./IArbitrable.sol";

/** @title Arbitrator
 *  Arbitrator abstract contract.
 *  When developing arbitrator contracts we need to:
 *  -Define the functions for dispute creation (createDispute) and appeal (appeal). Don't forget to store the arbitrated contract and the disputeID (which should be unique, may nbDisputes).
 *  -Define the functions for cost display (arbitrationCost and appealCost).
 *  -Allow giving rulings. For this a function must call arbitrable.rule(disputeID, ruling).
 */
contract Arbitrator {

    enum DisputeStatus {Waiting, Appealable, Solved}


    /** @dev To be emitted when a dispute is created.
     *  @param _disputeID ID of the dispute.
     *  @param _arbitrable The contract which created the dispute.
     */
    event DisputeCreation(uint indexed _disputeID, IArbitrable indexed _arbitrable);

    /** @dev To be emitted when a dispute can be appealed.
     *  @param _disputeID ID of the dispute.
     */
    event AppealPossible(uint indexed _disputeID, IArbitrable indexed _arbitrable);

    /** @dev To be emitted when the current ruling is appealed.
     *  @param _disputeID ID of the dispute.
     *  @param _arbitrable The contract which created the dispute.
     */
    event AppealDecision(uint indexed _disputeID, IArbitrable indexed _arbitrable);

    /** @dev Create a dispute. Must be called by the arbitrable contract.
     *  Must be paid at least arbitrationCost(_extraData).
     *  @param _choices Amount of choices the arbitrator can make in this dispute.
     *  @param _extraData Can be used to give additional info on the dispute to be created.
     *  @return disputeID ID of the dispute created.
     */
    function createDispute(uint _choices, bytes memory _extraData) public payable returns(uint disputeID);

    /** @dev Compute the cost of arbitration. It is recommended not to increase it often, as it can be highly time and gas consuming for the arbitrated contracts to cope with fee augmentation.
     *  @param _extraData Can be used to give additional info on the dispute to be created.
     *  @return cost Amount to be paid.
     */
    function arbitrationCost(bytes memory _extraData) public view returns(uint cost);

    /** @dev Appeal a ruling. Note that it has to be called before the arbitrator contract calls rule.
     *  @param _disputeID ID of the dispute to be appealed.
     *  @param _extraData Can be used to give extra info on the appeal.
     */
    function appeal(uint _disputeID, bytes memory _extraData) public payable;

    /** @dev Compute the cost of appeal. It is recommended not to increase it often, as it can be higly time and gas consuming for the arbitrated contracts to cope with fee augmentation.
     *  @param _disputeID ID of the dispute to be appealed.
     *  @param _extraData Can be used to give additional info on the dispute to be created.
     *  @return cost Amount to be paid.
     */
    function appealCost(uint _disputeID, bytes memory _extraData) public view returns(uint cost);

    /** @dev Compute the start and end of the dispute's current or next appeal period, if possible. If not known or appeal is impossible: should return (0, 0).
     *  @param _disputeID ID of the dispute.
     *  @return The start and end of the period.
     */
    function appealPeriod(uint _disputeID) public view returns(uint start, uint end);

    /** @dev Return the status of a dispute.
     *  @param _disputeID ID of the dispute to rule.
     *  @return status The status of the dispute.
     */
    function disputeStatus(uint _disputeID) public view returns(DisputeStatus status);

    /** @dev Return the current ruling of a dispute. This is useful for parties to know if they should appeal.
     *  @param _disputeID ID of the dispute.
     *  @return ruling The ruling which has been given or the one which will be given if there is no appeal.
     */
    function currentRuling(uint _disputeID) public view returns(uint ruling);

}

pragma solidity >=0.5 <0.6.0;

import "./IArbitrable.sol";
import "./IEvidence.sol";
import "./Arbitrator.sol";

contract BinaryArbitrableProxy is IArbitrable, IEvidence {

    uint constant NUMBER_OF_CHOICES = 2;

    struct DisputeStruct {
        Arbitrator arbitrator;
        bytes arbitratorExtraData;
        bool isRuled;
        uint disputeIDOnArbitratorSide;
    }


    DisputeStruct[] public disputes;
    mapping(uint => DisputeStruct) public disputeIDOnArbitratorSidetoDisputeStruct;

    function createDispute(Arbitrator _arbitrator, bytes calldata _arbitratorExtraData, string calldata _metaevidenceURI) external payable {
        uint arbitrationCost = _arbitrator.arbitrationCost(_arbitratorExtraData);
        uint _disputeIDOnArbitratorSide = _arbitrator.createDispute.value(arbitrationCost)(NUMBER_OF_CHOICES, _arbitratorExtraData);

        disputes.push(DisputeStruct({
            arbitrator: _arbitrator,
            arbitratorExtraData: _arbitratorExtraData,
            isRuled: false,
            disputeIDOnArbitratorSide: _disputeIDOnArbitratorSide
        }));

        disputeIDOnArbitratorSidetoDisputeStruct[_disputeIDOnArbitratorSide] = disputes[disputes.length-1];

        emit MetaEvidence(disputes.length-1, _metaevidenceURI);
        emit Dispute(_arbitrator, _disputeIDOnArbitratorSide, disputes.length-1, disputes.length-1);

    }

    function appeal(uint _localDisputeID) external payable {
        DisputeStruct storage dispute = disputes[_localDisputeID];
        dispute.arbitrator.appeal.value(msg.value)(dispute.disputeIDOnArbitratorSide, dispute.arbitratorExtraData);
    }

    function rule(uint _localDisputeID, uint _ruling) external {
        DisputeStruct storage dispute = disputes[_localDisputeID];
        require(msg.sender == address(dispute.arbitrator), "Unauthorized call.");
        require(_ruling <= NUMBER_OF_CHOICES, "Invalid ruling.");
        require(dispute.isRuled == false, "Is ruled already.");

        emit Ruling(Arbitrator(msg.sender), dispute.disputeIDOnArbitratorSide, _ruling);
        dispute.isRuled = true;
    }

    function submitEvidence(uint _localDisputeID, string memory _evidenceURI) public {
        DisputeStruct storage dispute = disputes[_localDisputeID];

        require(dispute.isRuled == false, "Is ruled already.");

        emit Evidence(dispute.arbitrator, _localDisputeID, msg.sender, _evidenceURI);
    }
}

/**
 *  @title IArbitrable
 *  @author Enrique Piqueras - <enrique@kleros.io>
 */

pragma solidity ^0.5;

import "./Arbitrator.sol";

/** @title IArbitrable
 *  Arbitrable interface.
 *  When developing arbitrable contracts, we need to:
 *  -Define the action taken when a ruling is received by the contract.
 *  -Allow dispute creation. For this a function must call arbitrator.createDispute.value(_fee)(_choices,_extraData);
 */
interface IArbitrable {

    /** @dev To be raised when a ruling is given.
     *  @param _arbitrator The arbitrator giving the ruling.
     *  @param _disputeID ID of the dispute in the Arbitrator contract.
     *  @param _ruling The ruling which was given.
     */
    event Ruling(Arbitrator indexed _arbitrator, uint indexed _disputeID, uint _ruling);

    /** @dev Give a ruling for a dispute. Must be called by the arbitrator.
     *  The purpose of this function is to ensure that the address calling it has the right to rule on the contract.
     *  @param _disputeID ID of the dispute in the Arbitrator contract.
     *  @param _ruling Ruling given by the arbitrator. Note that 0 is reserved for "Not able/wanting to make a decision".
     */
    function rule(uint _disputeID, uint _ruling) external;
}

pragma solidity ^0.5;

import "../Arbitrator.sol";

/** @title IEvidence
 *  ERC-1497: Evidence Standard
 */
interface IEvidence {

    /** @dev To be emitted when meta-evidence is submitted.
     *  @param _metaEvidenceID Unique identifier of meta-evidence.
     *  @param _evidence A link to the meta-evidence JSON.
     */
    event MetaEvidence(uint indexed _metaEvidenceID, string _evidence);

    /** @dev To be raised when evidence is submitted. Should point to the resource (evidences are not to be stored on chain due to gas considerations).
     *  @param _arbitrator The arbitrator of the contract.
     *  @param _evidenceGroupID Unique identifier of the evidence group the evidence belongs to.
     *  @param _party The address of the party submiting the evidence. Note that 0x0 refers to evidence not submitted by any party.
     *  @param _evidence A URI to the evidence JSON file whose name should be its keccak256 hash followed by .json.
     */
    event Evidence(Arbitrator indexed _arbitrator, uint indexed _evidenceGroupID, address indexed _party, string _evidence);

    /** @dev To be emitted when a dispute is created to link the correct meta-evidence to the disputeID.
     *  @param _arbitrator The arbitrator of the contract.
     *  @param _disputeID ID of the dispute in the Arbitrator contract.
     *  @param _metaEvidenceID Unique identifier of meta-evidence.
     *  @param _evidenceGroupID Unique identifier of the evidence group that is linked to this dispute.
     */
    event Dispute(Arbitrator indexed _arbitrator, uint indexed _disputeID, uint _metaEvidenceID, uint _evidenceGroupID);

}

/**
 *  @title Arbitrator
 *  @author Clément Lesaege - <clement@lesaege.com>
 */

pragma solidity ^0.5;

import "./IArbitrable.sol";

/** @title Arbitrator
 *  Arbitrator abstract contract.
 *  When developing arbitrator contracts we need to:
 *  -Define the functions for dispute creation (createDispute) and appeal (appeal). Don't forget to store the arbitrated contract and the disputeID (which should be unique, may nbDisputes).
 *  -Define the functions for cost display (arbitrationCost and appealCost).
 *  -Allow giving rulings. For this a function must call arbitrable.rule(disputeID, ruling).
 */
contract Arbitrator {

    enum DisputeStatus {Waiting, Appealable, Solved}


    /** @dev To be emitted when a dispute is created.
     *  @param _disputeID ID of the dispute.
     *  @param _arbitrable The contract which created the dispute.
     */
    event DisputeCreation(uint indexed _disputeID, IArbitrable indexed _arbitrable);

    /** @dev To be emitted when a dispute can be appealed.
     *  @param _disputeID ID of the dispute.
     */
    event AppealPossible(uint indexed _disputeID, IArbitrable indexed _arbitrable);

    /** @dev To be emitted when the current ruling is appealed.
     *  @param _disputeID ID of the dispute.
     *  @param _arbitrable The contract which created the dispute.
     */
    event AppealDecision(uint indexed _disputeID, IArbitrable indexed _arbitrable);

    /** @dev Create a dispute. Must be called by the arbitrable contract.
     *  Must be paid at least arbitrationCost(_extraData).
     *  @param _choices Amount of choices the arbitrator can make in this dispute.
     *  @param _extraData Can be used to give additional info on the dispute to be created.
     *  @return disputeID ID of the dispute created.
     */
    function createDispute(uint _choices, bytes memory _extraData) public payable returns(uint disputeID);

    /** @dev Compute the cost of arbitration. It is recommended not to increase it often, as it can be highly time and gas consuming for the arbitrated contracts to cope with fee augmentation.
     *  @param _extraData Can be used to give additional info on the dispute to be created.
     *  @return cost Amount to be paid.
     */
    function arbitrationCost(bytes memory _extraData) public view returns(uint cost);

    /** @dev Appeal a ruling. Note that it has to be called before the arbitrator contract calls rule.
     *  @param _disputeID ID of the dispute to be appealed.
     *  @param _extraData Can be used to give extra info on the appeal.
     */
    function appeal(uint _disputeID, bytes memory _extraData) public payable;

    /** @dev Compute the cost of appeal. It is recommended not to increase it often, as it can be higly time and gas consuming for the arbitrated contracts to cope with fee augmentation.
     *  @param _disputeID ID of the dispute to be appealed.
     *  @param _extraData Can be used to give additional info on the dispute to be created.
     *  @return cost Amount to be paid.
     */
    function appealCost(uint _disputeID, bytes memory _extraData) public view returns(uint cost);

    /** @dev Compute the start and end of the dispute's current or next appeal period, if possible. If not known or appeal is impossible: should return (0, 0).
     *  @param _disputeID ID of the dispute.
     *  @return The start and end of the period.
     */
    function appealPeriod(uint _disputeID) public view returns(uint start, uint end);

    /** @dev Return the status of a dispute.
     *  @param _disputeID ID of the dispute to rule.
     *  @return status The status of the dispute.
     */
    function disputeStatus(uint _disputeID) public view returns(DisputeStatus status);

    /** @dev Return the current ruling of a dispute. This is useful for parties to know if they should appeal.
     *  @param _disputeID ID of the dispute.
     *  @return ruling The ruling which has been given or the one which will be given if there is no appeal.
     */
    function currentRuling(uint _disputeID) public view returns(uint ruling);

}

pragma solidity >=0.5 <0.6.0;

import "./IArbitrable.sol";
import "./IEvidence.sol";
import "./Arbitrator.sol";

contract BinaryArbitrableProxy is IArbitrable, IEvidence {

    uint constant NUMBER_OF_CHOICES = 2;

    struct DisputeStruct {
        Arbitrator arbitrator;
        bytes arbitratorExtraData;
        bool isRuled;
        uint disputeIDOnArbitratorSide;
    }


    DisputeStruct[] public disputes;
    mapping(uint => DisputeStruct) public disputeIDOnArbitratorSidetoDisputeStruct;

    function createDispute(Arbitrator _arbitrator, bytes calldata _arbitratorExtraData, string calldata _metaevidenceURI) external payable {
        uint arbitrationCost = _arbitrator.arbitrationCost(_arbitratorExtraData);
        uint _disputeIDOnArbitratorSide = _arbitrator.createDispute.value(arbitrationCost)(NUMBER_OF_CHOICES, _arbitratorExtraData);

        disputes.push(DisputeStruct({
            arbitrator: _arbitrator,
            arbitratorExtraData: _arbitratorExtraData,
            isRuled: false,
            disputeIDOnArbitratorSide: _disputeIDOnArbitratorSide
        }));

        disputeIDOnArbitratorSidetoDisputeStruct[_disputeIDOnArbitratorSide] = disputes[disputes.length-1];

        emit MetaEvidence(disputes.length-1, _metaevidenceURI);
        emit Dispute(_arbitrator, _disputeIDOnArbitratorSide, disputes.length-1, disputes.length-1);

    }

    function appeal(uint _localDisputeID) external payable {
        DisputeStruct storage dispute = disputes[_localDisputeID];
        dispute.arbitrator.appeal.value(msg.value)(dispute.disputeIDOnArbitratorSide, dispute.arbitratorExtraData);
    }

    function rule(uint _localDisputeID, uint _ruling) external {
        DisputeStruct storage dispute = disputes[_localDisputeID];
        require(msg.sender == address(dispute.arbitrator), "Unauthorized call.");
        require(_ruling <= NUMBER_OF_CHOICES, "Invalid ruling.");
        require(dispute.isRuled == false, "Is ruled already.");

        emit Ruling(Arbitrator(msg.sender), dispute.disputeIDOnArbitratorSide, _ruling);
        dispute.isRuled = true;
    }

    function submitEvidence(uint _localDisputeID, string memory _evidenceURI) public {
        DisputeStruct storage dispute = disputes[_localDisputeID];

        require(dispute.isRuled == false, "Is ruled already.");

        emit Evidence(dispute.arbitrator, _localDisputeID, msg.sender, _evidenceURI);
    }
}

/**
 *  @title IArbitrable
 *  @author Enrique Piqueras - <enrique@kleros.io>
 */

pragma solidity ^0.5;

import "./Arbitrator.sol";

/** @title IArbitrable
 *  Arbitrable interface.
 *  When developing arbitrable contracts, we need to:
 *  -Define the action taken when a ruling is received by the contract.
 *  -Allow dispute creation. For this a function must call arbitrator.createDispute.value(_fee)(_choices,_extraData);
 */
interface IArbitrable {

    /** @dev To be raised when a ruling is given.
     *  @param _arbitrator The arbitrator giving the ruling.
     *  @param _disputeID ID of the dispute in the Arbitrator contract.
     *  @param _ruling The ruling which was given.
     */
    event Ruling(Arbitrator indexed _arbitrator, uint indexed _disputeID, uint _ruling);

    /** @dev Give a ruling for a dispute. Must be called by the arbitrator.
     *  The purpose of this function is to ensure that the address calling it has the right to rule on the contract.
     *  @param _disputeID ID of the dispute in the Arbitrator contract.
     *  @param _ruling Ruling given by the arbitrator. Note that 0 is reserved for "Not able/wanting to make a decision".
     */
    function rule(uint _disputeID, uint _ruling) external;
}

pragma solidity ^0.5;

import "../Arbitrator.sol";

/** @title IEvidence
 *  ERC-1497: Evidence Standard
 */
interface IEvidence {

    /** @dev To be emitted when meta-evidence is submitted.
     *  @param _metaEvidenceID Unique identifier of meta-evidence.
     *  @param _evidence A link to the meta-evidence JSON.
     */
    event MetaEvidence(uint indexed _metaEvidenceID, string _evidence);

    /** @dev To be raised when evidence is submitted. Should point to the resource (evidences are not to be stored on chain due to gas considerations).
     *  @param _arbitrator The arbitrator of the contract.
     *  @param _evidenceGroupID Unique identifier of the evidence group the evidence belongs to.
     *  @param _party The address of the party submiting the evidence. Note that 0x0 refers to evidence not submitted by any party.
     *  @param _evidence A URI to the evidence JSON file whose name should be its keccak256 hash followed by .json.
     */
    event Evidence(Arbitrator indexed _arbitrator, uint indexed _evidenceGroupID, address indexed _party, string _evidence);

    /** @dev To be emitted when a dispute is created to link the correct meta-evidence to the disputeID.
     *  @param _arbitrator The arbitrator of the contract.
     *  @param _disputeID ID of the dispute in the Arbitrator contract.
     *  @param _metaEvidenceID Unique identifier of meta-evidence.
     *  @param _evidenceGroupID Unique identifier of the evidence group that is linked to this dispute.
     */
    event Dispute(Arbitrator indexed _arbitrator, uint indexed _disputeID, uint _metaEvidenceID, uint _evidenceGroupID);

}

/**
 *  @title Arbitrator
 *  @author Clément Lesaege - <clement@lesaege.com>
 */

pragma solidity ^0.5;

import "./IArbitrable.sol";

/** @title Arbitrator
 *  Arbitrator abstract contract.
 *  When developing arbitrator contracts we need to:
 *  -Define the functions for dispute creation (createDispute) and appeal (appeal). Don't forget to store the arbitrated contract and the disputeID (which should be unique, may nbDisputes).
 *  -Define the functions for cost display (arbitrationCost and appealCost).
 *  -Allow giving rulings. For this a function must call arbitrable.rule(disputeID, ruling).
 */
contract Arbitrator {

    enum DisputeStatus {Waiting, Appealable, Solved}


    /** @dev To be emitted when a dispute is created.
     *  @param _disputeID ID of the dispute.
     *  @param _arbitrable The contract which created the dispute.
     */
    event DisputeCreation(uint indexed _disputeID, IArbitrable indexed _arbitrable);

    /** @dev To be emitted when a dispute can be appealed.
     *  @param _disputeID ID of the dispute.
     */
    event AppealPossible(uint indexed _disputeID, IArbitrable indexed _arbitrable);

    /** @dev To be emitted when the current ruling is appealed.
     *  @param _disputeID ID of the dispute.
     *  @param _arbitrable The contract which created the dispute.
     */
    event AppealDecision(uint indexed _disputeID, IArbitrable indexed _arbitrable);

    /** @dev Create a dispute. Must be called by the arbitrable contract.
     *  Must be paid at least arbitrationCost(_extraData).
     *  @param _choices Amount of choices the arbitrator can make in this dispute.
     *  @param _extraData Can be used to give additional info on the dispute to be created.
     *  @return disputeID ID of the dispute created.
     */
    function createDispute(uint _choices, bytes memory _extraData) public payable returns(uint disputeID);

    /** @dev Compute the cost of arbitration. It is recommended not to increase it often, as it can be highly time and gas consuming for the arbitrated contracts to cope with fee augmentation.
     *  @param _extraData Can be used to give additional info on the dispute to be created.
     *  @return cost Amount to be paid.
     */
    function arbitrationCost(bytes memory _extraData) public view returns(uint cost);

    /** @dev Appeal a ruling. Note that it has to be called before the arbitrator contract calls rule.
     *  @param _disputeID ID of the dispute to be appealed.
     *  @param _extraData Can be used to give extra info on the appeal.
     */
    function appeal(uint _disputeID, bytes memory _extraData) public payable;

    /** @dev Compute the cost of appeal. It is recommended not to increase it often, as it can be higly time and gas consuming for the arbitrated contracts to cope with fee augmentation.
     *  @param _disputeID ID of the dispute to be appealed.
     *  @param _extraData Can be used to give additional info on the dispute to be created.
     *  @return cost Amount to be paid.
     */
    function appealCost(uint _disputeID, bytes memory _extraData) public view returns(uint cost);

    /** @dev Compute the start and end of the dispute's current or next appeal period, if possible. If not known or appeal is impossible: should return (0, 0).
     *  @param _disputeID ID of the dispute.
     *  @return The start and end of the period.
     */
    function appealPeriod(uint _disputeID) public view returns(uint start, uint end);

    /** @dev Return the status of a dispute.
     *  @param _disputeID ID of the dispute to rule.
     *  @return status The status of the dispute.
     */
    function disputeStatus(uint _disputeID) public view returns(DisputeStatus status);

    /** @dev Return the current ruling of a dispute. This is useful for parties to know if they should appeal.
     *  @param _disputeID ID of the dispute.
     *  @return ruling The ruling which has been given or the one which will be given if there is no appeal.
     */
    function currentRuling(uint _disputeID) public view returns(uint ruling);

}

pragma solidity >=0.5 <0.6.0;

import "./IArbitrable.sol";
import "./IEvidence.sol";
import "./Arbitrator.sol";

contract BinaryArbitrableProxy is IArbitrable, IEvidence {

    uint constant NUMBER_OF_CHOICES = 2;

    struct DisputeStruct {
        Arbitrator arbitrator;
        bytes arbitratorExtraData;
        bool isRuled;
        uint disputeIDOnArbitratorSide;
    }


    DisputeStruct[] public disputes;
    mapping(uint => DisputeStruct) public disputeIDOnArbitratorSidetoDisputeStruct;

    function createDispute(Arbitrator _arbitrator, bytes calldata _arbitratorExtraData, string calldata _metaevidenceURI) external payable {
        uint arbitrationCost = _arbitrator.arbitrationCost(_arbitratorExtraData);
        uint _disputeIDOnArbitratorSide = _arbitrator.createDispute.value(arbitrationCost)(NUMBER_OF_CHOICES, _arbitratorExtraData);

        disputes.push(DisputeStruct({
            arbitrator: _arbitrator,
            arbitratorExtraData: _arbitratorExtraData,
            isRuled: false,
            disputeIDOnArbitratorSide: _disputeIDOnArbitratorSide
        }));

        disputeIDOnArbitratorSidetoDisputeStruct[_disputeIDOnArbitratorSide] = disputes[disputes.length-1];

        emit MetaEvidence(disputes.length-1, _metaevidenceURI);
        emit Dispute(_arbitrator, _disputeIDOnArbitratorSide, disputes.length-1, disputes.length-1);

    }

    function appeal(uint _localDisputeID) external payable {
        DisputeStruct storage dispute = disputes[_localDisputeID];
        dispute.arbitrator.appeal.value(msg.value)(dispute.disputeIDOnArbitratorSide, dispute.arbitratorExtraData);
    }

    function rule(uint _localDisputeID, uint _ruling) external {
        DisputeStruct storage dispute = disputes[_localDisputeID];
        require(msg.sender == address(dispute.arbitrator), "Unauthorized call.");
        require(_ruling <= NUMBER_OF_CHOICES, "Invalid ruling.");
        require(dispute.isRuled == false, "Is ruled already.");

        emit Ruling(Arbitrator(msg.sender), dispute.disputeIDOnArbitratorSide, _ruling);
        dispute.isRuled = true;
    }

    function submitEvidence(uint _localDisputeID, string memory _evidenceURI) public {
        DisputeStruct storage dispute = disputes[_localDisputeID];

        require(dispute.isRuled == false, "Is ruled already.");

        emit Evidence(dispute.arbitrator, _localDisputeID, msg.sender, _evidenceURI);
    }
}

/**
 *  @title IArbitrable
 *  @author Enrique Piqueras - <enrique@kleros.io>
 */

pragma solidity ^0.5;

import "./Arbitrator.sol";

/** @title IArbitrable
 *  Arbitrable interface.
 *  When developing arbitrable contracts, we need to:
 *  -Define the action taken when a ruling is received by the contract.
 *  -Allow dispute creation. For this a function must call arbitrator.createDispute.value(_fee)(_choices,_extraData);
 */
interface IArbitrable {

    /** @dev To be raised when a ruling is given.
     *  @param _arbitrator The arbitrator giving the ruling.
     *  @param _disputeID ID of the dispute in the Arbitrator contract.
     *  @param _ruling The ruling which was given.
     */
    event Ruling(Arbitrator indexed _arbitrator, uint indexed _disputeID, uint _ruling);

    /** @dev Give a ruling for a dispute. Must be called by the arbitrator.
     *  The purpose of this function is to ensure that the address calling it has the right to rule on the contract.
     *  @param _disputeID ID of the dispute in the Arbitrator contract.
     *  @param _ruling Ruling given by the arbitrator. Note that 0 is reserved for "Not able/wanting to make a decision".
     */
    function rule(uint _disputeID, uint _ruling) external;
}

pragma solidity ^0.5;

import "../Arbitrator.sol";

/** @title IEvidence
 *  ERC-1497: Evidence Standard
 */
interface IEvidence {

    /** @dev To be emitted when meta-evidence is submitted.
     *  @param _metaEvidenceID Unique identifier of meta-evidence.
     *  @param _evidence A link to the meta-evidence JSON.
     */
    event MetaEvidence(uint indexed _metaEvidenceID, string _evidence);

    /** @dev To be raised when evidence is submitted. Should point to the resource (evidences are not to be stored on chain due to gas considerations).
     *  @param _arbitrator The arbitrator of the contract.
     *  @param _evidenceGroupID Unique identifier of the evidence group the evidence belongs to.
     *  @param _party The address of the party submiting the evidence. Note that 0x0 refers to evidence not submitted by any party.
     *  @param _evidence A URI to the evidence JSON file whose name should be its keccak256 hash followed by .json.
     */
    event Evidence(Arbitrator indexed _arbitrator, uint indexed _evidenceGroupID, address indexed _party, string _evidence);

    /** @dev To be emitted when a dispute is created to link the correct meta-evidence to the disputeID.
     *  @param _arbitrator The arbitrator of the contract.
     *  @param _disputeID ID of the dispute in the Arbitrator contract.
     *  @param _metaEvidenceID Unique identifier of meta-evidence.
     *  @param _evidenceGroupID Unique identifier of the evidence group that is linked to this dispute.
     */
    event Dispute(Arbitrator indexed _arbitrator, uint indexed _disputeID, uint _metaEvidenceID, uint _evidenceGroupID);

}

