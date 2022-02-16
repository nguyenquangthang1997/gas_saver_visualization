/*
  Copyright 2019 StarkWare Industries Ltd.

  Licensed under the Apache License, Version 2.0 (the "License").
  You may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  https://www.starkware.co/open-source-license/

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions
  and limitations under the License.
*/

pragma solidity ^0.5.2;


contract Base {
    event LogString(string str);

    address payable internal operator;
    uint256 constant internal MINIMUM_TIME_TO_REVEAL = 1 days;
    uint256 constant internal TIME_TO_ALLOW_REVOKE = 7 days;
    bool internal isRevokeStarted = false;
    uint256 internal revokeTime = 0; // The time from which we can revoke.
    bool internal active = true;

    // mapping: (address, commitment) -> time
    // Times from which the users may claim the reward.
    mapping (address => mapping (bytes32 => uint256)) private reveal_timestamps;


    constructor ()
        internal
    {
        operator = msg.sender;
    }

    modifier onlyOperator()
    {
        require(msg.sender == operator, "ONLY_OPERATOR");
        _; // The _; defines where the called function is executed.
    }

    function register(bytes32 commitment)
        public
    {
        require(reveal_timestamps[msg.sender][commitment] == 0, "Entry already registered.");
        reveal_timestamps[msg.sender][commitment] = now + MINIMUM_TIME_TO_REVEAL;
    }


    /*
      Makes sure that the commitment was registered at least MINIMUM_TIME_TO_REVEAL before
      the current time.
    */
    function verifyTimelyRegistration(bytes32 commitment)
        internal view
    {
        uint256 registrationMaturationTime = reveal_timestamps[msg.sender][commitment];
        require(registrationMaturationTime != 0, "Commitment is not registered.");
        require(now >= registrationMaturationTime, "Time for reveal has not passed yet.");
    }


    /*
      WARNING: This function should only be used with call() and not transact().
      Creating a transaction that invokes this function might reveal the collision and make it
      subject to front-running.
    */
    function calcCommitment(uint256[] memory firstInput, uint256[] memory secondInput)
        public view
        returns (bytes32 commitment)
    {
        address sender = msg.sender;
        uint256 firstLength = firstInput.length;
        uint256 secondLength = secondInput.length;
        uint256[] memory hash_elements = new uint256[](1 + firstLength + secondLength);
        hash_elements[0] = uint256(sender);
        uint256 offset = 1;
        for (uint256 i = 0; i < firstLength; i++) {
            hash_elements[offset + i] = firstInput[i];
        }
        offset = 1 + firstLength;
        for (uint256 i = 0; i < secondLength; i++) {
            hash_elements[offset + i] = secondInput[i];
        }
        commitment = keccak256(abi.encodePacked(hash_elements));
    }

    function claimReward(
        uint256[] memory firstInput,
        uint256[] memory secondInput,
        string memory solutionDescription,
        string memory name)
        public
    {
        require(active == true, "This challenge is no longer active. Thank you for participating.");
        require(firstInput.length > 0, "First input cannot be empty.");
        require(secondInput.length > 0, "Second input cannot be empty.");
        require(firstInput.length == secondInput.length, "Input lengths are not equal.");
        uint256 inputLength = firstInput.length;
        bool sameInput = true;
        for (uint256 i = 0; i < inputLength; i++) {
            if (firstInput[i] != secondInput[i]) {
                sameInput = false;
            }
        }
        require(sameInput == false, "Inputs are equal.");
        bool sameHash = true;
        uint256[] memory firstHash = applyHash(firstInput);
        uint256[] memory secondHash = applyHash(secondInput);
        require(firstHash.length == secondHash.length, "Output lengths are not equal.");
        uint256 outputLength = firstHash.length;
        for (uint256 i = 0; i < outputLength; i++) {
            if (firstHash[i] != secondHash[i]) {
                sameHash = false;
            }
        }
        require(sameHash == true, "Not a collision.");
        verifyTimelyRegistration(calcCommitment(firstInput, secondInput));

        active = false;
        emit LogString(solutionDescription);
        emit LogString(name);
        msg.sender.transfer(address(this).balance);
    }

    function applyHash(uint256[] memory elements)
        public view
        returns (uint256[] memory elementsHash)
    {
        elementsHash = sponge(elements);
    }

    function startRevoke()
        public
        onlyOperator()
    {
        require(isRevokeStarted == false, "Revoke already started.");
        isRevokeStarted = true;
        revokeTime = now + TIME_TO_ALLOW_REVOKE;
    }

    function revokeReward()
        public
        onlyOperator()
    {
        require(isRevokeStarted == true, "Revoke not started yet.");
        require(now >= revokeTime, "Revoke time not passed.");
        active = false;
        operator.transfer(address(this).balance);
    }

    function sponge(uint256[] memory inputs)
        internal view
        returns (uint256[] memory outputElements);

    function getStatus()
        public view
        returns (bool[] memory status)
    {
        status = new bool[](2);
        status[0] = isRevokeStarted;
        status[1] = active;
    }
}

/*
  Copyright 2019 StarkWare Industries Ltd.

  Licensed under the Apache License, Version 2.0 (the "License").
  You may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  https://www.starkware.co/open-source-license/

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions
  and limitations under the License.
*/

pragma solidity ^0.5.2;


contract Sponge {
    uint256 prime;
    uint256 r;
    uint256 c;
    uint256 m;
    uint256 outputSize;
    uint256 nRounds;

    constructor (uint256 prime_, uint256 r_, uint256 c_, uint256 nRounds_)
        public
    {
        prime = prime_;
        r = r_;
        c = c_;
        m = r + c;
        outputSize = c;
        nRounds = nRounds_;
    }

    function LoadAuxdata()
        internal view
        returns (uint256[] memory /*auxdata*/);

    function permutation_func(uint256[] memory /*auxdata*/, uint256[] memory /*elements*/)
        internal view
        returns (uint256[] memory /*hash_elements*/);

    function sponge(uint256[] memory inputs)
        internal view
        returns (uint256[] memory outputElements)
    {
        uint256 inputLength = inputs.length;
        for (uint256 i = 0; i < inputLength; i++) {
            require(inputs[i] < prime, "elements do not belong to the field");
        }

        require(inputLength % r == 0, "Number of field elements is not divisible by r.");

        uint256[] memory state = new uint256[](m);
        for (uint256 i = 0; i < m; i++) {
            state[i] = 0; // fieldZero.
        }

        uint256[] memory auxData = LoadAuxdata();
        uint256 n_columns = inputLength / r;
        for (uint256 i = 0; i < n_columns; i++) {
            for (uint256 j = 0; j < r; j++) {
                state[j] = addmod(state[j], inputs[i * r + j], prime);
            }
            state = permutation_func(auxData, state);
        }

        require(outputSize <= r, "No support for more than r output elements.");
        outputElements = new uint256[](outputSize);
        for (uint256 i = 0; i < outputSize; i++) {
            outputElements[i] = state[i];
        }
    }

    function getParameters()
        public view
        returns (uint256[] memory status)
    {
        status = new uint256[](4);
        status[0] = prime;
        status[1] = r;
        status[2] = c;
        status[3] = nRounds;
    }
}

/*
    This smart contract was written by StarkWare Industries Ltd. as part of the STARK-friendly hash
    challenge effort, funded by the Ethereum Foundation.
    The contract will pay out 2 ETH to the first finder of a collision in GMiMC_erf with rate 2
    and capacity 2 at security level of 80 bits, if such a collision is discovered before the end
    of March 2020.
    More information about the STARK-friendly hash challenge can be found
    here https://starkware.co/hash-challenge/.
    More information about the STARK-friendly hash selection process (of which this challenge is a
    part) can be found here
    https://medium.com/starkware/stark-friendly-hash-tire-kicking-8087e8d9a246.
    Sage code reference implementation for the contender hash functions available
    at https://starkware.co/hash-challenge-implementation-reference-code/.
*/

/*
  Copyright 2019 StarkWare Industries Ltd.

  Licensed under the Apache License, Version 2.0 (the "License").
  You may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  https://www.starkware.co/open-source-license/

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions
  and limitations under the License.
*/

pragma solidity ^0.5.2;

import "./Base.sol";
import "./Sponge.sol";


contract STARK_Friendly_Hash_Challenge_GMiMC_erf_S80a is Base, Sponge {
    address roundConstantsContract;

    constructor (
        uint256 prime,
        uint256 r,
        uint256 c,
        uint256 nRounds,
        address roundConstantsContract_
        )
        public payable
        Sponge(prime, r, c, nRounds)
    {
        roundConstantsContract = roundConstantsContract_;
    }

    function LoadAuxdata()
        internal view
        returns (uint256[] memory roundConstants)
    {
        roundConstants = new uint256[](nRounds);
        address contractAddr = roundConstantsContract;
        assembly {
            let sizeInBytes := mul(mload(roundConstants), 0x20)
            extcodecopy(contractAddr, add(roundConstants, 0x20), 0, sizeInBytes)
        }
    }

    function permutation_func(uint256[] memory roundConstants, uint256[] memory elements)
        internal view
        returns (uint256[] memory)
    {
        uint256 length = elements.length;
        require(length == m, "elements length is not equal to m.");
        for (uint256 i = 0; i < roundConstants.length; i++) {
            uint256 element0Old = elements[0];
            uint256 step1 = addmod(elements[0], roundConstants[i], prime);
            uint256 mask = mulmod(mulmod(step1, step1, prime), step1, prime);
            for (uint256 j = 0; j < length - 1; j++) {
                elements[j] = addmod(elements[j + 1], mask, prime);
            }
            elements[length - 1] = element0Old;
        }
        return elements;
    }
}

/*
  Copyright 2019 StarkWare Industries Ltd.

  Licensed under the Apache License, Version 2.0 (the "License").
  You may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  https://www.starkware.co/open-source-license/

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions
  and limitations under the License.
*/

pragma solidity ^0.5.2;


contract Base {
    event LogString(string str);

    address payable internal operator;
    uint256 constant internal MINIMUM_TIME_TO_REVEAL = 1 days;
    uint256 constant internal TIME_TO_ALLOW_REVOKE = 7 days;
    bool internal isRevokeStarted = false;
    uint256 internal revokeTime = 0; // The time from which we can revoke.
    bool internal active = true;

    // mapping: (address, commitment) -> time
    // Times from which the users may claim the reward.
    mapping (address => mapping (bytes32 => uint256)) private reveal_timestamps;


    constructor ()
        internal
    {
        operator = msg.sender;
    }

    modifier onlyOperator()
    {
        require(msg.sender == operator, "ONLY_OPERATOR");
        _; // The _; defines where the called function is executed.
    }

    function register(bytes32 commitment)
        public
    {
        require(reveal_timestamps[msg.sender][commitment] == 0, "Entry already registered.");
        reveal_timestamps[msg.sender][commitment] = now + MINIMUM_TIME_TO_REVEAL;
    }


    /*
      Makes sure that the commitment was registered at least MINIMUM_TIME_TO_REVEAL before
      the current time.
    */
    function verifyTimelyRegistration(bytes32 commitment)
        internal view
    {
        uint256 registrationMaturationTime = reveal_timestamps[msg.sender][commitment];
        require(registrationMaturationTime != 0, "Commitment is not registered.");
        require(now >= registrationMaturationTime, "Time for reveal has not passed yet.");
    }


    /*
      WARNING: This function should only be used with call() and not transact().
      Creating a transaction that invokes this function might reveal the collision and make it
      subject to front-running.
    */
    function calcCommitment(uint256[] memory firstInput, uint256[] memory secondInput)
        public view
        returns (bytes32 commitment)
    {
        address sender = msg.sender;
        uint256 firstLength = firstInput.length;
        uint256 secondLength = secondInput.length;
        uint256[] memory hash_elements = new uint256[](1 + firstLength + secondLength);
        hash_elements[0] = uint256(sender);
        uint256 offset = 1;
        for (uint256 i = 0; i < firstLength; i++) {
            hash_elements[offset + i] = firstInput[i];
        }
        offset = 1 + firstLength;
        for (uint256 i = 0; i < secondLength; i++) {
            hash_elements[offset + i] = secondInput[i];
        }
        commitment = keccak256(abi.encodePacked(hash_elements));
    }

    function claimReward(
        uint256[] memory firstInput,
        uint256[] memory secondInput,
        string memory solutionDescription,
        string memory name)
        public
    {
        require(active == true, "This challenge is no longer active. Thank you for participating.");
        require(firstInput.length > 0, "First input cannot be empty.");
        require(secondInput.length > 0, "Second input cannot be empty.");
        require(firstInput.length == secondInput.length, "Input lengths are not equal.");
        uint256 inputLength = firstInput.length;
        bool sameInput = true;
        for (uint256 i = 0; i < inputLength; i++) {
            if (firstInput[i] != secondInput[i]) {
                sameInput = false;
            }
        }
        require(sameInput == false, "Inputs are equal.");
        bool sameHash = true;
        uint256[] memory firstHash = applyHash(firstInput);
        uint256[] memory secondHash = applyHash(secondInput);
        require(firstHash.length == secondHash.length, "Output lengths are not equal.");
        uint256 outputLength = firstHash.length;
        for (uint256 i = 0; i < outputLength; i++) {
            if (firstHash[i] != secondHash[i]) {
                sameHash = false;
            }
        }
        require(sameHash == true, "Not a collision.");
        verifyTimelyRegistration(calcCommitment(firstInput, secondInput));

        active = false;
        emit LogString(solutionDescription);
        emit LogString(name);
        msg.sender.transfer(address(this).balance);
    }

    function applyHash(uint256[] memory elements)
        public view
        returns (uint256[] memory elementsHash)
    {
        elementsHash = sponge(elements);
    }

    function startRevoke()
        public
        onlyOperator()
    {
        require(isRevokeStarted == false, "Revoke already started.");
        isRevokeStarted = true;
        revokeTime = now + TIME_TO_ALLOW_REVOKE;
    }

    function revokeReward()
        public
        onlyOperator()
    {
        require(isRevokeStarted == true, "Revoke not started yet.");
        require(now >= revokeTime, "Revoke time not passed.");
        active = false;
        operator.transfer(address(this).balance);
    }

    function sponge(uint256[] memory inputs)
        internal view
        returns (uint256[] memory outputElements);

    function getStatus()
        public view
        returns (bool[] memory status)
    {
        status = new bool[](2);
        status[0] = isRevokeStarted;
        status[1] = active;
    }
}

/*
  Copyright 2019 StarkWare Industries Ltd.

  Licensed under the Apache License, Version 2.0 (the "License").
  You may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  https://www.starkware.co/open-source-license/

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions
  and limitations under the License.
*/

pragma solidity ^0.5.2;


contract Sponge {
    uint256 prime;
    uint256 r;
    uint256 c;
    uint256 m;
    uint256 outputSize;
    uint256 nRounds;

    constructor (uint256 prime_, uint256 r_, uint256 c_, uint256 nRounds_)
        public
    {
        prime = prime_;
        r = r_;
        c = c_;
        m = r + c;
        outputSize = c;
        nRounds = nRounds_;
    }

    function LoadAuxdata()
        internal view
        returns (uint256[] memory /*auxdata*/);

    function permutation_func(uint256[] memory /*auxdata*/, uint256[] memory /*elements*/)
        internal view
        returns (uint256[] memory /*hash_elements*/);

    function sponge(uint256[] memory inputs)
        internal view
        returns (uint256[] memory outputElements)
    {
        uint256 inputLength = inputs.length;
        for (uint256 i = 0; i < inputLength; i++) {
            require(inputs[i] < prime, "elements do not belong to the field");
        }

        require(inputLength % r == 0, "Number of field elements is not divisible by r.");

        uint256[] memory state = new uint256[](m);
        for (uint256 i = 0; i < m; i++) {
            state[i] = 0; // fieldZero.
        }

        uint256[] memory auxData = LoadAuxdata();
        uint256 n_columns = inputLength / r;
        for (uint256 i = 0; i < n_columns; i++) {
            for (uint256 j = 0; j < r; j++) {
                state[j] = addmod(state[j], inputs[i * r + j], prime);
            }
            state = permutation_func(auxData, state);
        }

        require(outputSize <= r, "No support for more than r output elements.");
        outputElements = new uint256[](outputSize);
        for (uint256 i = 0; i < outputSize; i++) {
            outputElements[i] = state[i];
        }
    }

    function getParameters()
        public view
        returns (uint256[] memory status)
    {
        status = new uint256[](4);
        status[0] = prime;
        status[1] = r;
        status[2] = c;
        status[3] = nRounds;
    }
}

/*
    This smart contract was written by StarkWare Industries Ltd. as part of the STARK-friendly hash
    challenge effort, funded by the Ethereum Foundation.
    The contract will pay out 2 ETH to the first finder of a collision in GMiMC_erf with rate 2
    and capacity 2 at security level of 80 bits, if such a collision is discovered before the end
    of March 2020.
    More information about the STARK-friendly hash challenge can be found
    here https://starkware.co/hash-challenge/.
    More information about the STARK-friendly hash selection process (of which this challenge is a
    part) can be found here
    https://medium.com/starkware/stark-friendly-hash-tire-kicking-8087e8d9a246.
    Sage code reference implementation for the contender hash functions available
    at https://starkware.co/hash-challenge-implementation-reference-code/.
*/

/*
  Copyright 2019 StarkWare Industries Ltd.

  Licensed under the Apache License, Version 2.0 (the "License").
  You may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  https://www.starkware.co/open-source-license/

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions
  and limitations under the License.
*/

pragma solidity ^0.5.2;

import "./Base.sol";
import "./Sponge.sol";


contract STARK_Friendly_Hash_Challenge_GMiMC_erf_S80a is Base, Sponge {
    address roundConstantsContract;

    constructor (
        uint256 prime,
        uint256 r,
        uint256 c,
        uint256 nRounds,
        address roundConstantsContract_
        )
        public payable
        Sponge(prime, r, c, nRounds)
    {
        roundConstantsContract = roundConstantsContract_;
    }

    function LoadAuxdata()
        internal view
        returns (uint256[] memory roundConstants)
    {
        roundConstants = new uint256[](nRounds);
        address contractAddr = roundConstantsContract;
        assembly {
            let sizeInBytes := mul(mload(roundConstants), 0x20)
            extcodecopy(contractAddr, add(roundConstants, 0x20), 0, sizeInBytes)
        }
    }

    function permutation_func(uint256[] memory roundConstants, uint256[] memory elements)
        internal view
        returns (uint256[] memory)
    {
        uint256 length = elements.length;
        require(length == m, "elements length is not equal to m.");
        for (uint256 i = 0; i < roundConstants.length; i++) {
            uint256 element0Old = elements[0];
            uint256 step1 = addmod(elements[0], roundConstants[i], prime);
            uint256 mask = mulmod(mulmod(step1, step1, prime), step1, prime);
            for (uint256 j = 0; j < length - 1; j++) {
                elements[j] = addmod(elements[j + 1], mask, prime);
            }
            elements[length - 1] = element0Old;
        }
        return elements;
    }
}

/*
  Copyright 2019 StarkWare Industries Ltd.

  Licensed under the Apache License, Version 2.0 (the "License").
  You may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  https://www.starkware.co/open-source-license/

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions
  and limitations under the License.
*/

pragma solidity ^0.5.2;


contract Base {
    event LogString(string str);

    address payable internal operator;
    uint256 constant internal MINIMUM_TIME_TO_REVEAL = 1 days;
    uint256 constant internal TIME_TO_ALLOW_REVOKE = 7 days;
    bool internal isRevokeStarted = false;
    uint256 internal revokeTime = 0; // The time from which we can revoke.
    bool internal active = true;

    // mapping: (address, commitment) -> time
    // Times from which the users may claim the reward.
    mapping (address => mapping (bytes32 => uint256)) private reveal_timestamps;


    constructor ()
        internal
    {
        operator = msg.sender;
    }

    modifier onlyOperator()
    {
        require(msg.sender == operator, "ONLY_OPERATOR");
        _; // The _; defines where the called function is executed.
    }

    function register(bytes32 commitment)
        public
    {
        require(reveal_timestamps[msg.sender][commitment] == 0, "Entry already registered.");
        reveal_timestamps[msg.sender][commitment] = now + MINIMUM_TIME_TO_REVEAL;
    }


    /*
      Makes sure that the commitment was registered at least MINIMUM_TIME_TO_REVEAL before
      the current time.
    */
    function verifyTimelyRegistration(bytes32 commitment)
        internal view
    {
        uint256 registrationMaturationTime = reveal_timestamps[msg.sender][commitment];
        require(registrationMaturationTime != 0, "Commitment is not registered.");
        require(now >= registrationMaturationTime, "Time for reveal has not passed yet.");
    }


    /*
      WARNING: This function should only be used with call() and not transact().
      Creating a transaction that invokes this function might reveal the collision and make it
      subject to front-running.
    */
    function calcCommitment(uint256[] memory firstInput, uint256[] memory secondInput)
        public view
        returns (bytes32 commitment)
    {
        address sender = msg.sender;
        uint256 firstLength = firstInput.length;
        uint256 secondLength = secondInput.length;
        uint256[] memory hash_elements = new uint256[](1 + firstLength + secondLength);
        hash_elements[0] = uint256(sender);
        uint256 offset = 1;
        for (uint256 i = 0; i < firstLength; i++) {
            hash_elements[offset + i] = firstInput[i];
        }
        offset = 1 + firstLength;
        for (uint256 i = 0; i < secondLength; i++) {
            hash_elements[offset + i] = secondInput[i];
        }
        commitment = keccak256(abi.encodePacked(hash_elements));
    }

    function claimReward(
        uint256[] memory firstInput,
        uint256[] memory secondInput,
        string memory solutionDescription,
        string memory name)
        public
    {
        require(active == true, "This challenge is no longer active. Thank you for participating.");
        require(firstInput.length > 0, "First input cannot be empty.");
        require(secondInput.length > 0, "Second input cannot be empty.");
        require(firstInput.length == secondInput.length, "Input lengths are not equal.");
        uint256 inputLength = firstInput.length;
        bool sameInput = true;
        for (uint256 i = 0; i < inputLength; i++) {
            if (firstInput[i] != secondInput[i]) {
                sameInput = false;
            }
        }
        require(sameInput == false, "Inputs are equal.");
        bool sameHash = true;
        uint256[] memory firstHash = applyHash(firstInput);
        uint256[] memory secondHash = applyHash(secondInput);
        require(firstHash.length == secondHash.length, "Output lengths are not equal.");
        uint256 outputLength = firstHash.length;
        for (uint256 i = 0; i < outputLength; i++) {
            if (firstHash[i] != secondHash[i]) {
                sameHash = false;
            }
        }
        require(sameHash == true, "Not a collision.");
        verifyTimelyRegistration(calcCommitment(firstInput, secondInput));

        active = false;
        emit LogString(solutionDescription);
        emit LogString(name);
        msg.sender.transfer(address(this).balance);
    }

    function applyHash(uint256[] memory elements)
        public view
        returns (uint256[] memory elementsHash)
    {
        elementsHash = sponge(elements);
    }

    function startRevoke()
        public
        onlyOperator()
    {
        require(isRevokeStarted == false, "Revoke already started.");
        isRevokeStarted = true;
        revokeTime = now + TIME_TO_ALLOW_REVOKE;
    }

    function revokeReward()
        public
        onlyOperator()
    {
        require(isRevokeStarted == true, "Revoke not started yet.");
        require(now >= revokeTime, "Revoke time not passed.");
        active = false;
        operator.transfer(address(this).balance);
    }

    function sponge(uint256[] memory inputs)
        internal view
        returns (uint256[] memory outputElements);

    function getStatus()
        public view
        returns (bool[] memory status)
    {
        status = new bool[](2);
        status[0] = isRevokeStarted;
        status[1] = active;
    }
}

/*
  Copyright 2019 StarkWare Industries Ltd.

  Licensed under the Apache License, Version 2.0 (the "License").
  You may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  https://www.starkware.co/open-source-license/

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions
  and limitations under the License.
*/

pragma solidity ^0.5.2;


contract Sponge {
    uint256 prime;
    uint256 r;
    uint256 c;
    uint256 m;
    uint256 outputSize;
    uint256 nRounds;

    constructor (uint256 prime_, uint256 r_, uint256 c_, uint256 nRounds_)
        public
    {
        prime = prime_;
        r = r_;
        c = c_;
        m = r + c;
        outputSize = c;
        nRounds = nRounds_;
    }

    function LoadAuxdata()
        internal view
        returns (uint256[] memory /*auxdata*/);

    function permutation_func(uint256[] memory /*auxdata*/, uint256[] memory /*elements*/)
        internal view
        returns (uint256[] memory /*hash_elements*/);

    function sponge(uint256[] memory inputs)
        internal view
        returns (uint256[] memory outputElements)
    {
        uint256 inputLength = inputs.length;
        for (uint256 i = 0; i < inputLength; i++) {
            require(inputs[i] < prime, "elements do not belong to the field");
        }

        require(inputLength % r == 0, "Number of field elements is not divisible by r.");

        uint256[] memory state = new uint256[](m);
        for (uint256 i = 0; i < m; i++) {
            state[i] = 0; // fieldZero.
        }

        uint256[] memory auxData = LoadAuxdata();
        uint256 n_columns = inputLength / r;
        for (uint256 i = 0; i < n_columns; i++) {
            for (uint256 j = 0; j < r; j++) {
                state[j] = addmod(state[j], inputs[i * r + j], prime);
            }
            state = permutation_func(auxData, state);
        }

        require(outputSize <= r, "No support for more than r output elements.");
        outputElements = new uint256[](outputSize);
        for (uint256 i = 0; i < outputSize; i++) {
            outputElements[i] = state[i];
        }
    }

    function getParameters()
        public view
        returns (uint256[] memory status)
    {
        status = new uint256[](4);
        status[0] = prime;
        status[1] = r;
        status[2] = c;
        status[3] = nRounds;
    }
}

/*
    This smart contract was written by StarkWare Industries Ltd. as part of the STARK-friendly hash
    challenge effort, funded by the Ethereum Foundation.
    The contract will pay out 2 ETH to the first finder of a collision in GMiMC_erf with rate 2
    and capacity 2 at security level of 80 bits, if such a collision is discovered before the end
    of March 2020.
    More information about the STARK-friendly hash challenge can be found
    here https://starkware.co/hash-challenge/.
    More information about the STARK-friendly hash selection process (of which this challenge is a
    part) can be found here
    https://medium.com/starkware/stark-friendly-hash-tire-kicking-8087e8d9a246.
    Sage code reference implementation for the contender hash functions available
    at https://starkware.co/hash-challenge-implementation-reference-code/.
*/

/*
  Copyright 2019 StarkWare Industries Ltd.

  Licensed under the Apache License, Version 2.0 (the "License").
  You may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  https://www.starkware.co/open-source-license/

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions
  and limitations under the License.
*/

pragma solidity ^0.5.2;

import "./Base.sol";
import "./Sponge.sol";


contract STARK_Friendly_Hash_Challenge_GMiMC_erf_S80a is Base, Sponge {
    address roundConstantsContract;

    constructor (
        uint256 prime,
        uint256 r,
        uint256 c,
        uint256 nRounds,
        address roundConstantsContract_
        )
        public payable
        Sponge(prime, r, c, nRounds)
    {
        roundConstantsContract = roundConstantsContract_;
    }

    function LoadAuxdata()
        internal view
        returns (uint256[] memory roundConstants)
    {
        roundConstants = new uint256[](nRounds);
        address contractAddr = roundConstantsContract;
        assembly {
            let sizeInBytes := mul(mload(roundConstants), 0x20)
            extcodecopy(contractAddr, add(roundConstants, 0x20), 0, sizeInBytes)
        }
    }

    function permutation_func(uint256[] memory roundConstants, uint256[] memory elements)
        internal view
        returns (uint256[] memory)
    {
        uint256 length = elements.length;
        require(length == m, "elements length is not equal to m.");
        for (uint256 i = 0; i < roundConstants.length; i++) {
            uint256 element0Old = elements[0];
            uint256 step1 = addmod(elements[0], roundConstants[i], prime);
            uint256 mask = mulmod(mulmod(step1, step1, prime), step1, prime);
            for (uint256 j = 0; j < length - 1; j++) {
                elements[j] = addmod(elements[j + 1], mask, prime);
            }
            elements[length - 1] = element0Old;
        }
        return elements;
    }
}

