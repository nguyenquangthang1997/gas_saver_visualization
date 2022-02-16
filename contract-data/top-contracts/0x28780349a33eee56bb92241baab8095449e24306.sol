{"Committee.sol":{"content":"/*\n  Copyright 2019,2020 StarkWare Industries Ltd.\n\n  Licensed under the Apache License, Version 2.0 (the \"License\").\n  You may not use this file except in compliance with the License.\n  You may obtain a copy of the License at\n\n  https://www.starkware.co/open-source-license/\n\n  Unless required by applicable law or agreed to in writing,\n  software distributed under the License is distributed on an \"AS IS\" BASIS,\n  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n  See the License for the specific language governing permissions\n  and limitations under the License.\n*/\n// Solidity 0.5.4 has this bug: https://github.com/ethereum/solidity/issues/5997\n// It\u0027s already fixed: https://github.com/ethereum/solidity/pull/6000 and will be released in 0.5.5.\npragma solidity ^0.5.2;\n\nimport \"FactRegistry.sol\";\nimport \"Identity.sol\";\n\ncontract Committee is FactRegistry, Identity {\n\n    uint256 constant SIGNATURE_LENGTH = 32 * 2 + 1; // r(32) + s(32) +  v(1).\n    uint256 public signaturesRequired;\n    mapping (address =\u003e bool) public isMember;\n\n    /// @dev Contract constructor sets initial members and required number of signatures.\n    /// @param committeeMembers List of committee members.\n    /// @param numSignaturesRequired Number of required signatures.\n    constructor (address[] memory committeeMembers, uint256 numSignaturesRequired)\n        public\n    {\n        require(numSignaturesRequired \u003c= committeeMembers.length, \"TOO_MANY_REQUIRED_SIGNATURES\");\n        for (uint256 idx = 0; idx \u003c committeeMembers.length; idx++) {\n            require(!isMember[committeeMembers[idx]], \"NON_UNIQUE_COMMITTEE_MEMBERS\");\n            isMember[committeeMembers[idx]] = true;\n        }\n        signaturesRequired = numSignaturesRequired;\n    }\n\n    function identify()\n        external pure\n        returns(string memory)\n    {\n        return \"StarkWare_Committee_2019_1\";\n    }\n\n    /// @dev Verifies the availability proof. Reverts if invalid.\n    /// An availability proof should have a form of a concatenation of ec-signatures by signatories.\n    /// Signatures should be sorted by signatory address ascendingly.\n    /// Signatures should be 65 bytes long. r(32) + s(32) + v(1).\n    /// There should be at least the number of required signatures as defined in this contract\n    /// and all signatures provided should be from signatories.\n    ///\n    /// See :sol:mod:`AvailabilityVerifiers` for more information on when this is used.\n    ///\n    /// @param claimHash The hash of the claim the committee is signing on.\n    /// The format is keccak256(abi.encodePacked(\n    ///    newVaultRoot, vaultTreeHeight, newOrderRoot, orderTreeHeight sequenceNumber))\n    /// @param availabilityProofs Concatenated ec signatures by committee members.\n    function verifyAvailabilityProof(\n        bytes32 claimHash,\n        bytes calldata availabilityProofs\n    )\n        external\n    {\n        require(\n            availabilityProofs.length \u003e= signaturesRequired * SIGNATURE_LENGTH,\n            \"INVALID_AVAILABILITY_PROOF_LENGTH\");\n\n        uint256 offset = 0;\n        address prevRecoveredAddress = address(0);\n        for (uint256 proofIdx = 0; proofIdx \u003c signaturesRequired; proofIdx++) {\n            bytes32 r = bytesToBytes32(availabilityProofs, offset);\n            bytes32 s = bytesToBytes32(availabilityProofs, offset + 32);\n            uint8 v = uint8(availabilityProofs[offset + 64]);\n            offset += SIGNATURE_LENGTH;\n            address recovered = ecrecover(\n                claimHash,\n                v,\n                r,\n                s\n            );\n            // Signatures should be sorted off-chain before submitting to enable cheap uniqueness\n            // check on-chain.\n            require(isMember[recovered], \"AVAILABILITY_PROVER_NOT_IN_COMMITTEE\");\n            require(recovered \u003e prevRecoveredAddress, \"NON_SORTED_SIGNATURES\");\n            prevRecoveredAddress = recovered;\n        }\n        registerFact(claimHash);\n    }\n\n    function bytesToBytes32(bytes memory array, uint256 offset)\n        private pure\n        returns (bytes32 result) {\n        // Arrays are prefixed by a 256 bit length parameter.\n        uint256 actualOffset = offset + 32;\n\n        // Read the bytes32 from array memory.\n        // solium-disable-next-line security/no-inline-assembly\n        assembly {\n            result := mload(add(array, actualOffset))\n        }\n    }\n}\n"},"FactRegistry.sol":{"content":"/*\n  Copyright 2019,2020 StarkWare Industries Ltd.\n\n  Licensed under the Apache License, Version 2.0 (the \"License\").\n  You may not use this file except in compliance with the License.\n  You may obtain a copy of the License at\n\n  https://www.starkware.co/open-source-license/\n\n  Unless required by applicable law or agreed to in writing,\n  software distributed under the License is distributed on an \"AS IS\" BASIS,\n  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n  See the License for the specific language governing permissions\n  and limitations under the License.\n*/\npragma solidity ^0.5.2;\n\nimport \"IQueryableFactRegistry.sol\";\n\ncontract FactRegistry is IQueryableFactRegistry {\n    // Mapping: fact hash -\u003e true.\n    mapping (bytes32 =\u003e bool) private verifiedFact;\n\n    // Indicates whether the Fact Registry has at least one fact registered.\n    bool anyFactRegistered;\n\n    /*\n      Checks if a fact has been verified.\n    */\n    function isValid(bytes32 fact)\n        external view\n        returns(bool)\n    {\n        return _factCheck(fact);\n    }\n\n\n    /*\n      This is an internal method to check if the fact is already registered.\n      In current implementation of FactRegistry it\u0027s identical to isValid().\n      But the check is against the local fact registry,\n      So for a derived referral fact registry, it\u0027s not the same.\n    */\n    function _factCheck(bytes32 fact)\n        internal view\n        returns(bool)\n    {\n        return verifiedFact[fact];\n    }\n\n    function registerFact(\n        bytes32 factHash\n        )\n        internal\n    {\n        // This function stores the fact hash in the mapping.\n        verifiedFact[factHash] = true;\n\n        // Mark first time off.\n        if (!anyFactRegistered) {\n            anyFactRegistered = true;\n        }\n    }\n\n    /*\n      Indicates whether at least one fact was registered.\n    */\n    function hasRegisteredFact()\n        external view\n        returns(bool)\n    {\n        return anyFactRegistered;\n    }\n\n}\n"},"Identity.sol":{"content":"/*\n  Copyright 2019,2020 StarkWare Industries Ltd.\n\n  Licensed under the Apache License, Version 2.0 (the \"License\").\n  You may not use this file except in compliance with the License.\n  You may obtain a copy of the License at\n\n  https://www.starkware.co/open-source-license/\n\n  Unless required by applicable law or agreed to in writing,\n  software distributed under the License is distributed on an \"AS IS\" BASIS,\n  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n  See the License for the specific language governing permissions\n  and limitations under the License.\n*/\npragma solidity ^0.5.2;\n\ncontract Identity {\n\n    /*\n      Allows a caller, typically another contract,\n      to ensure that the provided address is of the expected type and version.\n    */\n    function identify()\n        external pure\n        returns(string memory);\n}\n"},"IFactRegistry.sol":{"content":"/*\n  Copyright 2019,2020 StarkWare Industries Ltd.\n\n  Licensed under the Apache License, Version 2.0 (the \"License\").\n  You may not use this file except in compliance with the License.\n  You may obtain a copy of the License at\n\n  https://www.starkware.co/open-source-license/\n\n  Unless required by applicable law or agreed to in writing,\n  software distributed under the License is distributed on an \"AS IS\" BASIS,\n  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n  See the License for the specific language governing permissions\n  and limitations under the License.\n*/\npragma solidity ^0.5.2;\n\n/*\n  The Fact Registry design pattern is a way to separate cryptographic verification from the\n  business logic of the contract flow.\n\n  A fact registry holds a hash table of verified \"facts\" which are represented by a hash of claims\n  that the registry hash check and found valid. This table may be queried by accessing the\n  isValid() function of the registry with a given hash.\n\n  In addition, each fact registry exposes a registry specific function for submitting new claims\n  together with their proofs. The information submitted varies from one registry to the other\n  depending of the type of fact requiring verification.\n\n  For further reading on the Fact Registry design pattern see this\n  `StarkWare blog post \u003chttps://medium.com/starkware/the-fact-registry-a64aafb598b6\u003e`_.\n*/\ncontract IFactRegistry {\n    /*\n      Returns true if the given fact was previously registered in the contract.\n    */\n    function isValid(bytes32 fact)\n        external view\n        returns(bool);\n}\n"},"IQueryableFactRegistry.sol":{"content":"/*\n  Copyright 2019,2020 StarkWare Industries Ltd.\n\n  Licensed under the Apache License, Version 2.0 (the \"License\").\n  You may not use this file except in compliance with the License.\n  You may obtain a copy of the License at\n\n  https://www.starkware.co/open-source-license/\n\n  Unless required by applicable law or agreed to in writing,\n  software distributed under the License is distributed on an \"AS IS\" BASIS,\n  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n  See the License for the specific language governing permissions\n  and limitations under the License.\n*/\npragma solidity ^0.5.2;\n\nimport \"IFactRegistry.sol\";\n\n/*\n  Extends the IFactRegistry interface with a query method that indicates\n  whether the fact registry has successfully registered any fact or is still empty of such facts.\n*/\ncontract IQueryableFactRegistry is IFactRegistry {\n\n    /*\n      Returns true if at least one fact has been registered.\n    */\n    function hasRegisteredFact()\n        external view\n        returns(bool);\n\n}\n"}}