{{
  "sources": {
    "lottery.sol": {
      "content": "/* Orchid - WebRTC P2P VPN Market (on Ethereum)\n * Copyright (C) 2017-2019  The Orchid Authors\n*/\n\n/* GNU Affero General Public License, Version 3 {{{ */\n/*\n * This program is free software: you can redistribute it and/or modify\n * it under the terms of the GNU Affero General Public License as published by\n * the Free Software Foundation, either version 3 of the License, or\n * (at your option) any later version.\n\n * This program is distributed in the hope that it will be useful,\n * but WITHOUT ANY WARRANTY; without even the implied warranty of\n * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n * GNU Affero General Public License for more details.\n\n * You should have received a copy of the GNU Affero General Public License\n * along with this program.  If not, see <http://www.gnu.org/licenses/>.\n**/\n/* }}} */\n\n\npragma solidity 0.5.13;\n\ninterface IERC20 {\n    function transfer(address recipient, uint256 amount) external returns (bool);\n    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);\n}\n\ninterface OrchidVerifier {\n    function book(bytes calldata shared, address target, bytes calldata receipt) external pure;\n}\n\ncontract OrchidLottery {\n\n    IERC20 internal token_;\n\n    constructor(IERC20 token) public {\n        token_ = token;\n    }\n\n    function what() external view returns (IERC20) {\n        return token_;\n    }\n\n\n    struct Pot {\n        uint256 offset_;\n\n        uint128 amount_;\n        uint128 escrow_;\n\n        uint256 unlock_;\n\n        OrchidVerifier verify_;\n        bytes32 codehash_;\n        bytes shared_;\n    }\n\n    event Update(address indexed funder, address indexed signer, uint128 amount, uint128 escrow, uint256 unlock);\n\n    function send(address funder, address signer, Pot storage pot) private {\n        emit Update(funder, signer, pot.amount_, pot.escrow_, pot.unlock_);\n    }\n\n\n    struct Lottery {\n        address[] keys_;\n        mapping(address => Pot) pots_;\n    }\n\n    mapping(address => Lottery) internal lotteries_;\n\n\n    function find(address funder, address signer) private view returns (Pot storage) {\n        return lotteries_[funder].pots_[signer];\n    }\n\n    function kill(address signer) external {\n        address funder = msg.sender;\n        Lottery storage lottery = lotteries_[funder];\n        Pot storage pot = lottery.pots_[signer];\n        require(pot.offset_ != 0);\n        if (pot.verify_ != OrchidVerifier(0))\n            emit Bound(funder, signer);\n        address key = lottery.keys_[lottery.keys_.length - 1];\n        lottery.pots_[key].offset_ = pot.offset_;\n        lottery.keys_[pot.offset_ - 1] = key;\n        --lottery.keys_.length;\n        delete lottery.pots_[signer];\n        send(funder, signer, pot);\n    }\n\n\n    function size(address funder) external view returns (uint256) {\n        return lotteries_[funder].keys_.length;\n    }\n\n    function keys(address funder) external view returns (address[] memory) {\n        return lotteries_[funder].keys_;\n    }\n\n    function seek(address funder, uint256 offset) external view returns (address) {\n        return lotteries_[funder].keys_[offset];\n    }\n\n    function page(address funder, uint256 offset, uint256 count) external view returns (address[] memory) {\n        address[] storage all = lotteries_[funder].keys_;\n        require(offset <= all.length);\n        if (count > all.length - offset)\n            count = all.length - offset;\n        address[] memory slice = new address[](count);\n        for (uint256 i = 0; i != count; ++i)\n            slice[i] = all[offset + i];\n        return slice;\n    }\n\n\n    function look(address funder, address signer) external view returns (uint128, uint128, uint256, OrchidVerifier, bytes32, bytes memory) {\n        Pot storage pot = lotteries_[funder].pots_[signer];\n        return (pot.amount_, pot.escrow_, pot.unlock_, pot.verify_, pot.codehash_, pot.shared_);\n    }\n\n\n    event Create(address indexed funder, address indexed signer);\n\n    function push(address signer, uint128 total, uint128 escrow) external {\n        address funder = msg.sender;\n        require(total >= escrow);\n        Pot storage pot = find(funder, signer);\n        if (pot.offset_ == 0) {\n            pot.offset_ = lotteries_[funder].keys_.push(signer);\n            emit Create(funder, signer);\n        }\n        pot.amount_ += total - escrow;\n        pot.escrow_ += escrow;\n        send(funder, signer, pot);\n        require(token_.transferFrom(funder, address(this), total));\n    }\n\n    function move(address signer, uint128 amount) external {\n        address funder = msg.sender;\n        Pot storage pot = find(funder, signer);\n        require(pot.amount_ >= amount);\n        pot.amount_ -= amount;\n        pot.escrow_ += amount;\n        send(funder, signer, pot);\n    }\n\n    function burn(address signer, uint128 escrow) external {\n        address funder = msg.sender;\n        Pot storage pot = find(funder, signer);\n        if (escrow > pot.escrow_)\n            escrow = pot.escrow_;\n        pot.escrow_ -= escrow;\n        send(funder, signer, pot);\n    }\n\n    event Bound(address indexed funder, address indexed signer);\n\n    function bind(address signer, OrchidVerifier verify, bytes calldata shared) external {\n        address funder = msg.sender;\n        Pot storage pot = find(funder, signer);\n        require(pot.escrow_ == 0);\n\n        bytes32 codehash;\n        assembly { codehash := extcodehash(verify) }\n\n        pot.verify_ = verify;\n        pot.codehash_ = codehash;\n        pot.shared_ = shared;\n\n        emit Bound(funder, signer);\n    }\n\n\n    struct Track {\n        uint256 until_;\n    }\n\n    mapping(address => mapping(bytes32 => Track)) internal tracks_;\n\n\n    function take(address funder, address signer, address payable recipient, uint128 amount, bytes memory receipt) private {\n        Pot storage pot = find(funder, signer);\n\n        uint128 cache = pot.amount_;\n\n        if (cache >= amount) {\n            cache -= amount;\n            pot.amount_ = cache;\n            emit Update(funder, signer, cache, pot.escrow_, pot.unlock_);\n        } else {\n            amount = cache;\n            pot.amount_ = 0;\n            pot.escrow_ = 0;\n            emit Update(funder, signer, 0, 0, pot.unlock_);\n        }\n\n        OrchidVerifier verify = pot.verify_;\n        bytes32 codehash;\n        bytes memory shared;\n        if (verify != OrchidVerifier(0)) {\n            codehash = pot.codehash_;\n            shared = pot.shared_;\n        }\n\n        if (amount != 0)\n            require(token_.transfer(recipient, amount));\n\n        if (verify != OrchidVerifier(0)) {\n            bytes32 current; assembly { current := extcodehash(verify) }\n            if (codehash == current)\n                verify.book(shared, recipient, receipt);\n        }\n    }\n\n    // the arguments to this function are carefully ordered for stack depth optimization\n    // this function was marked public, instead of external, for lower stack depth usage\n    function grab(\n        bytes32 reveal, bytes32 commit,\n        uint256 issued, bytes32 nonce,\n        uint8 v, bytes32 r, bytes32 s,\n        uint128 amount, uint128 ratio,\n        uint256 start, uint128 range,\n        address funder, address payable recipient,\n        bytes memory receipt, bytes32[] memory old\n    ) public {\n        require(keccak256(abi.encode(reveal)) == commit);\n        require(uint128(uint256(keccak256(abi.encode(reveal, nonce)))) <= ratio);\n\n        // this variable is being reused because I do not have even one extra stack slot\n        bytes32 ticket; assembly { ticket := chainid() }\n        // keccak256(\"Orchid.grab\") == 0x8b988a5483b8a95aa306ba150c9513d5565a0eee358bc4b35b29425708700645\n        ticket = keccak256(abi.encode(bytes32(uint256(0x8b988a5483b8a95aa306ba150c9513d5565a0eee358bc4b35b29425708700645)),\n            commit, issued, nonce, address(this), ticket, amount, ratio, start, range, funder, recipient, receipt));\n        address signer = ecrecover(keccak256(abi.encodePacked(\"\\x19Ethereum Signed Message:\\n32\", ticket)), v, r, s);\n        require(signer != address(0));\n\n        {\n            mapping(bytes32 => Track) storage tracks = tracks_[recipient];\n\n            {\n                Track storage track = tracks[keccak256(abi.encode(signer, ticket))];\n                uint256 until = start + range;\n                require(until > block.timestamp);\n                require(track.until_ == 0);\n                track.until_ = until;\n            }\n\n            for (uint256 i = 0; i != old.length; ++i) {\n                Track storage track = tracks[old[i]];\n                if (track.until_ <= block.timestamp)\n                    delete track.until_;\n            }\n        }\n\n        if (start < block.timestamp) {\n            uint128 limit = uint128(uint256(amount) * (range - (block.timestamp - start)) / range);\n            if (amount > limit)\n                amount = limit;\n        }\n\n        take(funder, signer, recipient, amount, receipt);\n    }\n\n    function give(address funder, address payable recipient, uint128 amount, bytes calldata receipt) external {\n        address signer = msg.sender;\n        take(funder, signer, recipient, amount, receipt);\n    }\n\n\n    function warn(address signer) external {\n        address funder = msg.sender;\n        Pot storage pot = find(funder, signer);\n        pot.unlock_ = block.timestamp + 1 days;\n        send(funder, signer, pot);\n    }\n\n    function lock(address signer) external {\n        address funder = msg.sender;\n        Pot storage pot = find(funder, signer);\n        pot.unlock_ = 0;\n        send(funder, signer, pot);\n    }\n\n    function pull(address signer, address payable target, bool autolock, uint128 amount, uint128 escrow) external {\n        address funder = msg.sender;\n        Pot storage pot = find(funder, signer);\n        if (amount > pot.amount_)\n            amount = pot.amount_;\n        if (escrow > pot.escrow_)\n            escrow = pot.escrow_;\n        if (escrow != 0)\n            require(pot.unlock_ - 1 < block.timestamp);\n        uint128 total = amount + escrow;\n        pot.amount_ -= amount;\n        pot.escrow_ -= escrow;\n        if (autolock && pot.escrow_ == 0)\n            pot.unlock_ = 0;\n        send(funder, signer, pot);\n        if (total != 0)\n            require(token_.transfer(target, total));\n    }\n\n    function yank(address signer, address payable target, bool autolock) external {\n        address funder = msg.sender;\n        Pot storage pot = find(funder, signer);\n        if (pot.escrow_ != 0)\n            require(pot.unlock_ - 1 < block.timestamp);\n        uint128 total = pot.amount_ + pot.escrow_;\n        pot.amount_ = 0;\n        pot.escrow_ = 0;\n        if (autolock)\n            pot.unlock_ = 0;\n        send(funder, signer, pot);\n        require(token_.transfer(target, total));\n    }\n}\n"
    }
  },
  "language": "Solidity",
  "settings": {
    "evmVersion": "istanbul",
    "outputSelection": {
      "*": {
        "*": [
          "evm.bytecode",
          "evm.deployedBytecode",
          "abi"
        ]
      }
    }
  }
}}