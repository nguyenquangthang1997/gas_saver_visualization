{"FactRegistry.sol":{"content":"/*\n  Copyright 2019-2021 StarkWare Industries Ltd.\n\n  Licensed under the Apache License, Version 2.0 (the \"License\").\n  You may not use this file except in compliance with the License.\n  You may obtain a copy of the License at\n\n  https://www.starkware.co/open-source-license/\n\n  Unless required by applicable law or agreed to in writing,\n  software distributed under the License is distributed on an \"AS IS\" BASIS,\n  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n  See the License for the specific language governing permissions\n  and limitations under the License.\n*/\n// SPDX-License-Identifier: Apache-2.0.\npragma solidity ^0.6.12;\n\nimport \"IQueryableFactRegistry.sol\";\n\ncontract FactRegistry is IQueryableFactRegistry {\n    // Mapping: fact hash -\u003e true.\n    mapping(bytes32 =\u003e bool) private verifiedFact;\n\n    // Indicates whether the Fact Registry has at least one fact registered.\n    bool anyFactRegistered;\n\n    /*\n      Checks if a fact has been verified.\n    */\n    function isValid(bytes32 fact) external view override returns (bool) {\n        return _factCheck(fact);\n    }\n\n    /*\n      This is an internal method to check if the fact is already registered.\n      In current implementation of FactRegistry it\u0027s identical to isValid().\n      But the check is against the local fact registry,\n      So for a derived referral fact registry, it\u0027s not the same.\n    */\n    function _factCheck(bytes32 fact) internal view returns (bool) {\n        return verifiedFact[fact];\n    }\n\n    function registerFact(bytes32 factHash) internal {\n        // This function stores the fact hash in the mapping.\n        verifiedFact[factHash] = true;\n\n        // Mark first time off.\n        if (!anyFactRegistered) {\n            anyFactRegistered = true;\n        }\n    }\n\n    /*\n      Indicates whether at least one fact was registered.\n    */\n    function hasRegisteredFact() external view override returns (bool) {\n        return anyFactRegistered;\n    }\n}\n"},"IFactRegistry.sol":{"content":"/*\n  Copyright 2019-2021 StarkWare Industries Ltd.\n\n  Licensed under the Apache License, Version 2.0 (the \"License\").\n  You may not use this file except in compliance with the License.\n  You may obtain a copy of the License at\n\n  https://www.starkware.co/open-source-license/\n\n  Unless required by applicable law or agreed to in writing,\n  software distributed under the License is distributed on an \"AS IS\" BASIS,\n  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n  See the License for the specific language governing permissions\n  and limitations under the License.\n*/\n// SPDX-License-Identifier: Apache-2.0.\npragma solidity ^0.6.12;\n\n/*\n  The Fact Registry design pattern is a way to separate cryptographic verification from the\n  business logic of the contract flow.\n\n  A fact registry holds a hash table of verified \"facts\" which are represented by a hash of claims\n  that the registry hash check and found valid. This table may be queried by accessing the\n  isValid() function of the registry with a given hash.\n\n  In addition, each fact registry exposes a registry specific function for submitting new claims\n  together with their proofs. The information submitted varies from one registry to the other\n  depending of the type of fact requiring verification.\n\n  For further reading on the Fact Registry design pattern see this\n  `StarkWare blog post \u003chttps://medium.com/starkware/the-fact-registry-a64aafb598b6\u003e`_.\n*/\ninterface IFactRegistry {\n    /*\n      Returns true if the given fact was previously registered in the contract.\n    */\n    function isValid(bytes32 fact) external view returns (bool);\n}\n"},"IMerkleVerifier.sol":{"content":"/*\n  Copyright 2019-2021 StarkWare Industries Ltd.\n\n  Licensed under the Apache License, Version 2.0 (the \"License\").\n  You may not use this file except in compliance with the License.\n  You may obtain a copy of the License at\n\n  https://www.starkware.co/open-source-license/\n\n  Unless required by applicable law or agreed to in writing,\n  software distributed under the License is distributed on an \"AS IS\" BASIS,\n  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n  See the License for the specific language governing permissions\n  and limitations under the License.\n*/\n// SPDX-License-Identifier: Apache-2.0.\npragma solidity ^0.6.12;\n\nabstract contract IMerkleVerifier {\n    uint256 internal constant MAX_N_MERKLE_VERIFIER_QUERIES = 128;\n\n    function verifyMerkle(\n        uint256 channelPtr,\n        uint256 queuePtr,\n        bytes32 root,\n        uint256 n\n    ) internal view virtual returns (bytes32 hash);\n}\n"},"IQueryableFactRegistry.sol":{"content":"/*\n  Copyright 2019-2021 StarkWare Industries Ltd.\n\n  Licensed under the Apache License, Version 2.0 (the \"License\").\n  You may not use this file except in compliance with the License.\n  You may obtain a copy of the License at\n\n  https://www.starkware.co/open-source-license/\n\n  Unless required by applicable law or agreed to in writing,\n  software distributed under the License is distributed on an \"AS IS\" BASIS,\n  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n  See the License for the specific language governing permissions\n  and limitations under the License.\n*/\n// SPDX-License-Identifier: Apache-2.0.\npragma solidity ^0.6.12;\n\nimport \"IFactRegistry.sol\";\n\n/*\n  Extends the IFactRegistry interface with a query method that indicates\n  whether the fact registry has successfully registered any fact or is still empty of such facts.\n*/\ninterface IQueryableFactRegistry is IFactRegistry {\n    /*\n      Returns true if at least one fact has been registered.\n    */\n    function hasRegisteredFact() external view returns (bool);\n}\n"},"MerkleStatementContract.sol":{"content":"/*\n  Copyright 2019-2021 StarkWare Industries Ltd.\n\n  Licensed under the Apache License, Version 2.0 (the \"License\").\n  You may not use this file except in compliance with the License.\n  You may obtain a copy of the License at\n\n  https://www.starkware.co/open-source-license/\n\n  Unless required by applicable law or agreed to in writing,\n  software distributed under the License is distributed on an \"AS IS\" BASIS,\n  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n  See the License for the specific language governing permissions\n  and limitations under the License.\n*/\n// SPDX-License-Identifier: Apache-2.0.\npragma solidity ^0.6.12;\n\nimport \"FactRegistry.sol\";\nimport \"MerkleVerifier.sol\";\n\ncontract MerkleStatementContract is MerkleVerifier, FactRegistry {\n    /*\n      This function receives an initial Merkle queue (consists of indices of leaves in the Merkle\n      in addition to their values) and a Merkle view (contains the values of all the nodes\n      required to be able to validate the queue). In case of success it registers the Merkle fact,\n      which is the hash of the queue together with the resulting root.\n    */\n    // NOLINTNEXTLINE: external-function.\n    function verifyMerkle(\n        uint256[] memory merkleView,\n        uint256[] memory initialMerkleQueue,\n        uint256 height,\n        uint256 expectedRoot\n    ) public {\n        require(height \u003c 200, \"Height must be \u003c 200.\");\n        require(\n            initialMerkleQueue.length \u003c= MAX_N_MERKLE_VERIFIER_QUERIES * 2,\n            \"TOO_MANY_MERKLE_QUERIES\"\n        );\n        require(initialMerkleQueue.length % 2 == 0, \"ODD_MERKLE_QUEUE_SIZE\");\n\n        uint256 merkleQueuePtr;\n        uint256 channelPtr;\n        uint256 nQueries;\n        uint256 dataToHashPtr;\n        uint256 badInput = 0;\n\n        assembly {\n            // Skip 0x20 bytes length at the beginning of the merkleView.\n            let merkleViewPtr := add(merkleView, 0x20)\n            // Let channelPtr point to a free space.\n            channelPtr := mload(0x40) // freePtr.\n            // channelPtr will point to the merkleViewPtr since the \u0027verify\u0027 function expects\n            // a pointer to the proofPtr.\n            mstore(channelPtr, merkleViewPtr)\n            // Skip 0x20 bytes length at the beginning of the initialMerkleQueue.\n            merkleQueuePtr := add(initialMerkleQueue, 0x20)\n            // Get number of queries.\n            nQueries := div(mload(initialMerkleQueue), 0x2) //NOLINT: divide-before-multiply.\n            // Get a pointer to the end of initialMerkleQueue.\n            let initialMerkleQueueEndPtr := add(merkleQueuePtr, mul(nQueries, 0x40))\n            // Let dataToHashPtr point to a free memory.\n            dataToHashPtr := add(channelPtr, 0x20) // Next freePtr.\n\n            // Copy initialMerkleQueue to dataToHashPtr and validaite the indices.\n            // The indices need to be in the range [2**height..2*(height+1)-1] and\n            // strictly incrementing.\n\n            // First index needs to be \u003e= 2**height.\n            let idxLowerLimit := shl(height, 1)\n            for {\n\n            } lt(merkleQueuePtr, initialMerkleQueueEndPtr) {\n\n            } {\n                let curIdx := mload(merkleQueuePtr)\n                // badInput |= curIdx \u003c IdxLowerLimit.\n                badInput := or(badInput, lt(curIdx, idxLowerLimit))\n\n                // The next idx must be at least curIdx + 1.\n                idxLowerLimit := add(curIdx, 1)\n\n                // Copy the pair (idx, hash) to the dataToHash array.\n                mstore(dataToHashPtr, curIdx)\n                mstore(add(dataToHashPtr, 0x20), mload(add(merkleQueuePtr, 0x20)))\n\n                dataToHashPtr := add(dataToHashPtr, 0x40)\n                merkleQueuePtr := add(merkleQueuePtr, 0x40)\n            }\n\n            // We need to enforce that lastIdx \u003c 2**(height+1)\n            // =\u003e fail if lastIdx \u003e= 2**(height+1)\n            // =\u003e fail if (lastIdx + 1) \u003e 2**(height+1)\n            // =\u003e fail if idxLowerLimit \u003e 2**(height+1).\n            badInput := or(badInput, gt(idxLowerLimit, shl(height, 2)))\n\n            // Reset merkleQueuePtr.\n            merkleQueuePtr := add(initialMerkleQueue, 0x20)\n            // Let freePtr point to a free memory (one word after the copied queries - reserved\n            // for the root).\n            mstore(0x40, add(dataToHashPtr, 0x20))\n        }\n        require(badInput == 0, \"INVALID_MERKLE_INDICES\");\n        bytes32 resRoot = verifyMerkle(channelPtr, merkleQueuePtr, bytes32(expectedRoot), nQueries);\n        bytes32 factHash;\n        assembly {\n            // Append the resulted root (should be the return value of verify) to dataToHashPtr.\n            mstore(dataToHashPtr, resRoot)\n            // Reset dataToHashPtr.\n            dataToHashPtr := add(channelPtr, 0x20)\n            factHash := keccak256(dataToHashPtr, add(mul(nQueries, 0x40), 0x20))\n        }\n\n        registerFact(factHash);\n    }\n}\n"},"MerkleVerifier.sol":{"content":"/*\n  Copyright 2019-2021 StarkWare Industries Ltd.\n\n  Licensed under the Apache License, Version 2.0 (the \"License\").\n  You may not use this file except in compliance with the License.\n  You may obtain a copy of the License at\n\n  https://www.starkware.co/open-source-license/\n\n  Unless required by applicable law or agreed to in writing,\n  software distributed under the License is distributed on an \"AS IS\" BASIS,\n  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n  See the License for the specific language governing permissions\n  and limitations under the License.\n*/\n// SPDX-License-Identifier: Apache-2.0.\npragma solidity ^0.6.12;\n\nimport \"IMerkleVerifier.sol\";\n\ncontract MerkleVerifier is IMerkleVerifier {\n    function getHashMask() internal pure returns (uint256) {\n        // Default implementation.\n        return 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000000;\n    }\n\n    /*\n      Verifies a Merkle tree decommitment for n leaves in a Merkle tree with N leaves.\n\n      The inputs data sits in the queue at queuePtr.\n      Each slot in the queue contains a 32 bytes leaf index and a 32 byte leaf value.\n      The indices need to be in the range [N..2*N-1] and strictly incrementing.\n      Decommitments are read from the channel in the ctx.\n\n      The input data is destroyed during verification.\n    */\n    function verifyMerkle(\n        uint256 channelPtr,\n        uint256 queuePtr,\n        bytes32 root,\n        uint256 n\n    ) internal view virtual override returns (bytes32 hash) {\n        uint256 lhashMask = getHashMask();\n        require(n \u003c= MAX_N_MERKLE_VERIFIER_QUERIES, \"TOO_MANY_MERKLE_QUERIES\");\n\n        assembly {\n            // queuePtr + i * 0x40 gives the i\u0027th index in the queue.\n            // hashesPtr + i * 0x40 gives the i\u0027th hash in the queue.\n            let hashesPtr := add(queuePtr, 0x20)\n            let queueSize := mul(n, 0x40)\n            let slotSize := 0x40\n\n            // The items are in slots [0, n-1].\n            let rdIdx := 0\n            let wrIdx := 0 // = n % n.\n\n            // Iterate the queue until we hit the root.\n            let index := mload(add(rdIdx, queuePtr))\n            let proofPtr := mload(channelPtr)\n\n            // while(index \u003e 1).\n            for {\n\n            } gt(index, 1) {\n\n            } {\n                let siblingIndex := xor(index, 1)\n                // sibblingOffset := 0x20 * lsb(siblingIndex).\n                let sibblingOffset := mulmod(siblingIndex, 0x20, 0x40)\n\n                // Store the hash corresponding to index in the correct slot.\n                // 0 if index is even and 0x20 if index is odd.\n                // The hash of the sibling will be written to the other slot.\n                mstore(xor(0x20, sibblingOffset), mload(add(rdIdx, hashesPtr)))\n                rdIdx := addmod(rdIdx, slotSize, queueSize)\n\n                // Inline channel operation:\n                // Assume we are going to read a new hash from the proof.\n                // If this is not the case add(proofPtr, 0x20) will be reverted.\n                let newHashPtr := proofPtr\n                proofPtr := add(proofPtr, 0x20)\n\n                // Push index/2 into the queue, before reading the next index.\n                // The order is important, as otherwise we may try to read from an empty queue (in\n                // the case where we are working on one item).\n                // wrIdx will be updated after writing the relevant hash to the queue.\n                mstore(add(wrIdx, queuePtr), div(index, 2))\n\n                // Load the next index from the queue and check if it is our sibling.\n                index := mload(add(rdIdx, queuePtr))\n                if eq(index, siblingIndex) {\n                    // Take sibling from queue rather than from proof.\n                    newHashPtr := add(rdIdx, hashesPtr)\n                    // Revert reading from proof.\n                    proofPtr := sub(proofPtr, 0x20)\n                    rdIdx := addmod(rdIdx, slotSize, queueSize)\n\n                    // Index was consumed, read the next one.\n                    // Note that the queue can\u0027t be empty at this point.\n                    // The index of the parent of the current node was already pushed into the\n                    // queue, and the parent is never the sibling.\n                    index := mload(add(rdIdx, queuePtr))\n                }\n\n                mstore(sibblingOffset, mload(newHashPtr))\n\n                // Push the new hash to the end of the queue.\n                mstore(add(wrIdx, hashesPtr), and(lhashMask, keccak256(0x00, 0x40)))\n                wrIdx := addmod(wrIdx, slotSize, queueSize)\n            }\n            hash := mload(add(rdIdx, hashesPtr))\n\n            // Update the proof pointer in the context.\n            mstore(channelPtr, proofPtr)\n        }\n        require(hash == root, \"INVALID_MERKLE_PROOF\");\n    }\n}\n"}}