{"EnergiTokenProxy.sol":{"content":"// Copyright (C) 2020 Energi Core\n\n// This program is free software: you can redistribute it and/or modify\n// it under the terms of the GNU General Public License as published by\n// the Free Software Foundation, either version 3 of the License, or\n// (at your option) any later version.\n\n// This program is distributed in the hope that it will be useful,\n// but WITHOUT ANY WARRANTY; without even the implied warranty of\n// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n// GNU General Public License for more details.\n\n// You should have received a copy of the GNU General Public License\n// along with this program.  If not, see \u003chttp://www.gnu.org/licenses/\u003e.\n\npragma solidity ^0.5.0;\n\nimport \u0027./IEnergiTokenProxy.sol\u0027;\n\ncontract EnergiTokenProxy is IEnergiTokenProxy {\n\n    address public delegate;\n\n    address public proxyOwner;\n\n    modifier onlyProxyOwner {\n        require(msg.sender == proxyOwner, \u0027EnergiTokenProxy: FORBIDDEN\u0027);\n        _;\n    }\n\n    constructor(address _owner, address _delegate) public {\n        proxyOwner = _owner;\n        delegate = _delegate;\n    }\n\n    function setProxyOwner(address _owner) external onlyProxyOwner {\n        proxyOwner = _owner;\n    }\n\n    function upgradeDelegate(address _delegate) external onlyProxyOwner {\n        delegate = _delegate;\n    }\n\n    function () external payable {\n\n        address _delegate = delegate;\n        require(_delegate != address(0));\n\n        assembly {\n            let ptr := mload(0x40)\n            calldatacopy(ptr, 0, calldatasize)\n            let result := delegatecall(gas, _delegate, ptr, calldatasize, 0, 0)\n            let size := returndatasize\n            returndatacopy(ptr, 0, size)\n\n            switch result\n            case 0 { revert(ptr, size) }\n            default { return(ptr, size) }\n        }\n    }\n}\n"},"IEnergiTokenProxy.sol":{"content":"// Copyright (C) 2020 Energi Core\n\n// This program is free software: you can redistribute it and/or modify\n// it under the terms of the GNU General Public License as published by\n// the Free Software Foundation, either version 3 of the License, or\n// (at your option) any later version.\n\n// This program is distributed in the hope that it will be useful,\n// but WITHOUT ANY WARRANTY; without even the implied warranty of\n// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n// GNU General Public License for more details.\n\n// You should have received a copy of the GNU General Public License\n// along with this program.  If not, see \u003chttp://www.gnu.org/licenses/\u003e.\n\npragma solidity ^0.5.0;\n\ninterface IEnergiTokenProxy {\n\n    function proxyOwner() external view returns (address);\n\n    function delegate() external view returns (address);\n\n    function setProxyOwner(address _owner) external;\n\n    function upgradeDelegate(address _delegate) external;\n}\n"}}