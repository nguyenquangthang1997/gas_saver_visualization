pragma solidity ^0.5.2;

/*
The MIT License (MIT)

Copyright (c) 2016 Smart Contract Solutions, Inc.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/**
 * @title ERC20 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-20
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity >=0.4.25 <0.6.0;

/*
The MIT License (MIT)

Copyright (c) 2016 Smart Contract Solutions, Inc.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/**
 * @title MerkleProof
 * @dev Merkle proof verification based on
 * https://github.com/ameensol/merkle-tree-solidity/blob/master/src/MerkleProof.sol
 */
library MerkleProof {
    /**
     * @dev Verifies a Merkle proof proving the existence of a leaf in a Merkle tree. Assumes that each pair of leaves
     * and each pair of pre-images are sorted.
     * @param proof Merkle proof containing sibling hashes on the branch from the leaf to the root of the Merkle tree
     * @param root Merkle root
     * @param leaf Leaf of Merkle tree
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash < proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}

pragma solidity >=0.4.21 <0.6.0;

contract Migrations {
  address public owner;
  uint public last_completed_migration;

  constructor() public {
    owner = msg.sender;
  }

  modifier restricted() {
    if (msg.sender == owner) _;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }

  function upgrade(address new_address) public restricted {
    Migrations upgraded = Migrations(new_address);
    upgraded.setCompleted(last_completed_migration);
  }
}

pragma solidity ^0.5.2;

import "./IERC20.sol";
import "./MerkleProof.sol";

contract TownOfSalem
{
	constructor() public {}

  IERC20 CereneumContract = IERC20(0xd9D4A7CA154fe137c808F7EEDBe24b639B7AF5a6);
  bytes32 public m_hMerkleTreeRoot = 0x7804aa8223f9eff3d1df195fe18d13b2191a7a3ac890aa970a34ccb42520038a;
  mapping(bytes32 => bool) public m_claimedMap;
  uint256 m_nAirdropAmount = 1000000000;  //10 CER
  address m_contractOwner = 0xe0d53E9fd7A9E0251641cB9CC7F70aff579bfbbE;
  address m_returnAddress = 0x8eAf4Fec503da352EB66Ef1E2f75C63e5bC635e1;

  function ClaimAirdrop(
    bytes32 a_hMerkleLeaf,
    bytes32[] memory a_hMerkleTreeBranches
  ) public returns (bool)
  {
    require(m_claimedMap[a_hMerkleLeaf] == false, "Duplicate claim");

    require(MerkleProof.verify(a_hMerkleTreeBranches, m_hMerkleTreeRoot, a_hMerkleLeaf), "Merkle Proof Failed");

    CereneumContract.transfer(msg.sender, m_nAirdropAmount);

    m_claimedMap[a_hMerkleLeaf] = true;
  }

  modifier restricted()
	{
    if (msg.sender == m_contractOwner) _;
  }

  function UpdateMerkleRoot(bytes32 a_hMerkleTreeRoot) public restricted()
  {
    m_hMerkleTreeRoot = a_hMerkleTreeRoot;
  }

  function ReturnCereneum() public restricted()
  {
    CereneumContract.transfer(m_returnAddress, CereneumContract.balanceOf(address(this)));
  }

	function AdjustAirdropAmount(uint256 a_nAirdropAmount) public restricted()
  {
    m_nAirdropAmount = a_nAirdropAmount;
  }
}

pragma solidity ^0.5.2;

/*
The MIT License (MIT)

Copyright (c) 2016 Smart Contract Solutions, Inc.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/**
 * @title ERC20 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-20
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity >=0.4.25 <0.6.0;

/*
The MIT License (MIT)

Copyright (c) 2016 Smart Contract Solutions, Inc.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/**
 * @title MerkleProof
 * @dev Merkle proof verification based on
 * https://github.com/ameensol/merkle-tree-solidity/blob/master/src/MerkleProof.sol
 */
library MerkleProof {
    /**
     * @dev Verifies a Merkle proof proving the existence of a leaf in a Merkle tree. Assumes that each pair of leaves
     * and each pair of pre-images are sorted.
     * @param proof Merkle proof containing sibling hashes on the branch from the leaf to the root of the Merkle tree
     * @param root Merkle root
     * @param leaf Leaf of Merkle tree
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash < proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}

pragma solidity >=0.4.21 <0.6.0;

contract Migrations {
  address public owner;
  uint public last_completed_migration;

  constructor() public {
    owner = msg.sender;
  }

  modifier restricted() {
    if (msg.sender == owner) _;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }

  function upgrade(address new_address) public restricted {
    Migrations upgraded = Migrations(new_address);
    upgraded.setCompleted(last_completed_migration);
  }
}

pragma solidity ^0.5.2;

import "./IERC20.sol";
import "./MerkleProof.sol";

contract TownOfSalem
{
	constructor() public {}

  IERC20 CereneumContract = IERC20(0xd9D4A7CA154fe137c808F7EEDBe24b639B7AF5a6);
  bytes32 public m_hMerkleTreeRoot = 0x7804aa8223f9eff3d1df195fe18d13b2191a7a3ac890aa970a34ccb42520038a;
  mapping(bytes32 => bool) public m_claimedMap;
  uint256 m_nAirdropAmount = 1000000000;  //10 CER
  address m_contractOwner = 0xe0d53E9fd7A9E0251641cB9CC7F70aff579bfbbE;
  address m_returnAddress = 0x8eAf4Fec503da352EB66Ef1E2f75C63e5bC635e1;

  function ClaimAirdrop(
    bytes32 a_hMerkleLeaf,
    bytes32[] memory a_hMerkleTreeBranches
  ) public returns (bool)
  {
    require(m_claimedMap[a_hMerkleLeaf] == false, "Duplicate claim");

    require(MerkleProof.verify(a_hMerkleTreeBranches, m_hMerkleTreeRoot, a_hMerkleLeaf), "Merkle Proof Failed");

    CereneumContract.transfer(msg.sender, m_nAirdropAmount);

    m_claimedMap[a_hMerkleLeaf] = true;
  }

  modifier restricted()
	{
    if (msg.sender == m_contractOwner) _;
  }

  function UpdateMerkleRoot(bytes32 a_hMerkleTreeRoot) public restricted()
  {
    m_hMerkleTreeRoot = a_hMerkleTreeRoot;
  }

  function ReturnCereneum() public restricted()
  {
    CereneumContract.transfer(m_returnAddress, CereneumContract.balanceOf(address(this)));
  }

	function AdjustAirdropAmount(uint256 a_nAirdropAmount) public restricted()
  {
    m_nAirdropAmount = a_nAirdropAmount;
  }
}

pragma solidity ^0.5.2;

/*
The MIT License (MIT)

Copyright (c) 2016 Smart Contract Solutions, Inc.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/**
 * @title ERC20 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-20
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity >=0.4.25 <0.6.0;

/*
The MIT License (MIT)

Copyright (c) 2016 Smart Contract Solutions, Inc.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/**
 * @title MerkleProof
 * @dev Merkle proof verification based on
 * https://github.com/ameensol/merkle-tree-solidity/blob/master/src/MerkleProof.sol
 */
library MerkleProof {
    /**
     * @dev Verifies a Merkle proof proving the existence of a leaf in a Merkle tree. Assumes that each pair of leaves
     * and each pair of pre-images are sorted.
     * @param proof Merkle proof containing sibling hashes on the branch from the leaf to the root of the Merkle tree
     * @param root Merkle root
     * @param leaf Leaf of Merkle tree
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash < proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}

pragma solidity >=0.4.21 <0.6.0;

contract Migrations {
  address public owner;
  uint public last_completed_migration;

  constructor() public {
    owner = msg.sender;
  }

  modifier restricted() {
    if (msg.sender == owner) _;
  }

  function setCompleted(uint completed) public restricted {
    last_completed_migration = completed;
  }

  function upgrade(address new_address) public restricted {
    Migrations upgraded = Migrations(new_address);
    upgraded.setCompleted(last_completed_migration);
  }
}

pragma solidity ^0.5.2;

import "./IERC20.sol";
import "./MerkleProof.sol";

contract TownOfSalem
{
	constructor() public {}

  IERC20 CereneumContract = IERC20(0xd9D4A7CA154fe137c808F7EEDBe24b639B7AF5a6);
  bytes32 public m_hMerkleTreeRoot = 0x7804aa8223f9eff3d1df195fe18d13b2191a7a3ac890aa970a34ccb42520038a;
  mapping(bytes32 => bool) public m_claimedMap;
  uint256 m_nAirdropAmount = 1000000000;  //10 CER
  address m_contractOwner = 0xe0d53E9fd7A9E0251641cB9CC7F70aff579bfbbE;
  address m_returnAddress = 0x8eAf4Fec503da352EB66Ef1E2f75C63e5bC635e1;

  function ClaimAirdrop(
    bytes32 a_hMerkleLeaf,
    bytes32[] memory a_hMerkleTreeBranches
  ) public returns (bool)
  {
    require(m_claimedMap[a_hMerkleLeaf] == false, "Duplicate claim");

    require(MerkleProof.verify(a_hMerkleTreeBranches, m_hMerkleTreeRoot, a_hMerkleLeaf), "Merkle Proof Failed");

    CereneumContract.transfer(msg.sender, m_nAirdropAmount);

    m_claimedMap[a_hMerkleLeaf] = true;
  }

  modifier restricted()
	{
    if (msg.sender == m_contractOwner) _;
  }

  function UpdateMerkleRoot(bytes32 a_hMerkleTreeRoot) public restricted()
  {
    m_hMerkleTreeRoot = a_hMerkleTreeRoot;
  }

  function ReturnCereneum() public restricted()
  {
    CereneumContract.transfer(m_returnAddress, CereneumContract.balanceOf(address(this)));
  }

	function AdjustAirdropAmount(uint256 a_nAirdropAmount) public restricted()
  {
    m_nAirdropAmount = a_nAirdropAmount;
  }
}

