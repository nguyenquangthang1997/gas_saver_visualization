{"Address.sol":{"content":"// SPDX-License-Identifier: MIT\r\n\r\npragma solidity ^0.8.0;\r\n\r\n/**\r\n * @dev Collection of functions related to the address type\r\n */\r\nlibrary Address {\r\n    /**\r\n     * @dev Returns true if `account` is a contract.\r\n     *\r\n     * [IMPORTANT]\r\n     * ====\r\n     * It is unsafe to assume that an address for which this function returns\r\n     * false is an externally-owned account (EOA) and not a contract.\r\n     *\r\n     * Among others, `isContract` will return false for the following\r\n     * types of addresses:\r\n     *\r\n     *  - an externally-owned account\r\n     *  - a contract in construction\r\n     *  - an address where a contract will be created\r\n     *  - an address where a contract lived, but was destroyed\r\n     * ====\r\n     */\r\n    function isContract(address account) internal view returns (bool) {\r\n        // This method relies on extcodesize, which returns 0 for contracts in\r\n        // construction, since the code is only stored at the end of the\r\n        // constructor execution.\r\n\r\n        uint256 size;\r\n        assembly {\r\n            size := extcodesize(account)\r\n        }\r\n        return size \u003e 0;\r\n    }\r\n\r\n    /**\r\n     * @dev Replacement for Solidity\u0027s `transfer`: sends `amount` wei to\r\n     * `recipient`, forwarding all available gas and reverting on errors.\r\n     *\r\n     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost\r\n     * of certain opcodes, possibly making contracts go over the 2300 gas limit\r\n     * imposed by `transfer`, making them unable to receive funds via\r\n     * `transfer`. {sendValue} removes this limitation.\r\n     *\r\n     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].\r\n     *\r\n     * IMPORTANT: because control is transferred to `recipient`, care must be\r\n     * taken to not create reentrancy vulnerabilities. Consider using\r\n     * {ReentrancyGuard} or the\r\n     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].\r\n     */\r\n    function sendValue(address payable recipient, uint256 amount) internal {\r\n        require(address(this).balance \u003e= amount, \"Address: insufficient balance\");\r\n\r\n        (bool success, ) = recipient.call{value: amount}(\"\");\r\n        require(success, \"Address: unable to send value, recipient may have reverted\");\r\n    }\r\n\r\n    /**\r\n     * @dev Performs a Solidity function call using a low level `call`. A\r\n     * plain `call` is an unsafe replacement for a function call: use this\r\n     * function instead.\r\n     *\r\n     * If `target` reverts with a revert reason, it is bubbled up by this\r\n     * function (like regular Solidity function calls).\r\n     *\r\n     * Returns the raw returned data. To convert to the expected return value,\r\n     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].\r\n     *\r\n     * Requirements:\r\n     *\r\n     * - `target` must be a contract.\r\n     * - calling `target` with `data` must not revert.\r\n     *\r\n     * _Available since v3.1._\r\n     */\r\n    function functionCall(address target, bytes memory data) internal returns (bytes memory) {\r\n        return functionCall(target, data, \"Address: low-level call failed\");\r\n    }\r\n\r\n    /**\r\n     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with\r\n     * `errorMessage` as a fallback revert reason when `target` reverts.\r\n     *\r\n     * _Available since v3.1._\r\n     */\r\n    function functionCall(\r\n        address target,\r\n        bytes memory data,\r\n        string memory errorMessage\r\n    ) internal returns (bytes memory) {\r\n        return functionCallWithValue(target, data, 0, errorMessage);\r\n    }\r\n\r\n    /**\r\n     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],\r\n     * but also transferring `value` wei to `target`.\r\n     *\r\n     * Requirements:\r\n     *\r\n     * - the calling contract must have an ETH balance of at least `value`.\r\n     * - the called Solidity function must be `payable`.\r\n     *\r\n     * _Available since v3.1._\r\n     */\r\n    function functionCallWithValue(\r\n        address target,\r\n        bytes memory data,\r\n        uint256 value\r\n    ) internal returns (bytes memory) {\r\n        return functionCallWithValue(target, data, value, \"Address: low-level call with value failed\");\r\n    }\r\n\r\n    /**\r\n     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but\r\n     * with `errorMessage` as a fallback revert reason when `target` reverts.\r\n     *\r\n     * _Available since v3.1._\r\n     */\r\n    function functionCallWithValue(\r\n        address target,\r\n        bytes memory data,\r\n        uint256 value,\r\n        string memory errorMessage\r\n    ) internal returns (bytes memory) {\r\n        require(address(this).balance \u003e= value, \"Address: insufficient balance for call\");\r\n        require(isContract(target), \"Address: call to non-contract\");\r\n\r\n        (bool success, bytes memory returndata) = target.call{value: value}(data);\r\n        return verifyCallResult(success, returndata, errorMessage);\r\n    }\r\n\r\n    /**\r\n     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],\r\n     * but performing a static call.\r\n     *\r\n     * _Available since v3.3._\r\n     */\r\n    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {\r\n        return functionStaticCall(target, data, \"Address: low-level static call failed\");\r\n    }\r\n\r\n    /**\r\n     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],\r\n     * but performing a static call.\r\n     *\r\n     * _Available since v3.3._\r\n     */\r\n    function functionStaticCall(\r\n        address target,\r\n        bytes memory data,\r\n        string memory errorMessage\r\n    ) internal view returns (bytes memory) {\r\n        require(isContract(target), \"Address: static call to non-contract\");\r\n\r\n        (bool success, bytes memory returndata) = target.staticcall(data);\r\n        return verifyCallResult(success, returndata, errorMessage);\r\n    }\r\n\r\n    /**\r\n     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],\r\n     * but performing a delegate call.\r\n     *\r\n     * _Available since v3.4._\r\n     */\r\n    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {\r\n        return functionDelegateCall(target, data, \"Address: low-level delegate call failed\");\r\n    }\r\n\r\n    /**\r\n     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],\r\n     * but performing a delegate call.\r\n     *\r\n     * _Available since v3.4._\r\n     */\r\n    function functionDelegateCall(\r\n        address target,\r\n        bytes memory data,\r\n        string memory errorMessage\r\n    ) internal returns (bytes memory) {\r\n        require(isContract(target), \"Address: delegate call to non-contract\");\r\n\r\n        (bool success, bytes memory returndata) = target.delegatecall(data);\r\n        return verifyCallResult(success, returndata, errorMessage);\r\n    }\r\n\r\n    /**\r\n     * @dev Tool to verifies that a low level call was successful, and revert if it wasn\u0027t, either by bubbling the\r\n     * revert reason using the provided one.\r\n     *\r\n     * _Available since v4.3._\r\n     */\r\n    function verifyCallResult(\r\n        bool success,\r\n        bytes memory returndata,\r\n        string memory errorMessage\r\n    ) internal pure returns (bytes memory) {\r\n        if (success) {\r\n            return returndata;\r\n        } else {\r\n            // Look for revert reason and bubble it up if present\r\n            if (returndata.length \u003e 0) {\r\n                // The easiest way to bubble the revert reason is using memory via assembly\r\n\r\n                assembly {\r\n                    let returndata_size := mload(returndata)\r\n                    revert(add(32, returndata), returndata_size)\r\n                }\r\n            } else {\r\n                revert(errorMessage);\r\n            }\r\n        }\r\n    }\r\n}\r\n"},"Context.sol":{"content":"// SPDX-License-Identifier: MIT\r\n\r\npragma solidity ^0.8.0;\r\n\r\n/**\r\n * @dev Provides information about the current execution context, including the\r\n * sender of the transaction and its data. While these are generally available\r\n * via msg.sender and msg.data, they should not be accessed in such a direct\r\n * manner, since when dealing with meta-transactions the account sending and\r\n * paying for execution may not be the actual sender (as far as an application\r\n * is concerned).\r\n *\r\n * This contract is only required for intermediate, library-like contracts.\r\n */\r\nabstract contract Context {\r\n    function _msgSender() internal view virtual returns (address) {\r\n        return msg.sender;\r\n    }\r\n\r\n    function _msgData() internal view virtual returns (bytes calldata) {\r\n        return msg.data;\r\n    }\r\n}\r\n"},"ERC165.sol":{"content":"// SPDX-License-Identifier: MIT\r\n\r\npragma solidity ^0.8.0;\r\n\r\nimport \"./IERC165.sol\";\r\n\r\n/**\r\n * @dev Implementation of the {IERC165} interface.\r\n *\r\n * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check\r\n * for the additional interface id that will be supported. For example:\r\n *\r\n * ```solidity\r\n * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {\r\n *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);\r\n * }\r\n * ```\r\n *\r\n * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.\r\n */\r\nabstract contract ERC165 is IERC165 {\r\n    /**\r\n     * @dev See {IERC165-supportsInterface}.\r\n     */\r\n    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {\r\n        return interfaceId == type(IERC165).interfaceId;\r\n    }\r\n}\r\n"},"ERC721Enum.sol":{"content":"// SPDX-License-Identifier: GPL-3.0\r\npragma solidity ^0.8.10;\r\nimport \"./ERC721P.sol\";\r\nimport \"./IERC721Enumerable.sol\";\r\n\r\nabstract contract ERC721Enum is ERC721P, IERC721Enumerable {\r\n    function supportsInterface(bytes4 interfaceId)\r\n        public\r\n        view\r\n        virtual\r\n        override(IERC165, ERC721P)\r\n        returns (bool)\r\n    {\r\n        return\r\n            interfaceId == type(IERC721Enumerable).interfaceId ||\r\n            super.supportsInterface(interfaceId);\r\n    }\r\n\r\n    function tokenOfOwnerByIndex(address owner, uint256 index)\r\n        public\r\n        view\r\n        override\r\n        returns (uint256 tokenId)\r\n    {\r\n        require(index \u003c ERC721P.balanceOf(owner), \"ERC721Enum: owner ioob\");\r\n        uint256 count;\r\n        for (uint256 i; i \u003c _owners.length; ++i) {\r\n            if (owner == _owners[i]) {\r\n                if (count == index) return i;\r\n                else ++count;\r\n            }\r\n        }\r\n        require(false, \"ERC721Enum: owner ioob\");\r\n    }\r\n\r\n    function tokensOfOwner(address owner)\r\n        public\r\n        view\r\n        returns (uint256[] memory)\r\n    {\r\n        require(0 \u003c ERC721P.balanceOf(owner), \"ERC721Enum: owner ioob\");\r\n        uint256 tokenCount = balanceOf(owner);\r\n        uint256[] memory tokenIds = new uint256[](tokenCount);\r\n        for (uint256 i = 0; i \u003c tokenCount; i++) {\r\n            tokenIds[i] = tokenOfOwnerByIndex(owner, i);\r\n        }\r\n        return tokenIds;\r\n    }\r\n\r\n    function totalSupply() public view virtual override returns (uint256) {\r\n        return _owners.length;\r\n    }\r\n\r\n    function tokenByIndex(uint256 index)\r\n        public\r\n        view\r\n        virtual\r\n        override\r\n        returns (uint256)\r\n    {\r\n        require(index \u003c ERC721Enum.totalSupply(), \"ERC721Enum: global ioob\");\r\n        return index;\r\n    }\r\n}\r\n"},"ERC721P.sol":{"content":"// SPDX-License-Identifier: GPL-3.0\r\npragma solidity ^0.8.10;\r\nimport \"./IERC721.sol\";\r\nimport \"./IERC721Receiver.sol\";\r\nimport \"./IERC721Metadata.sol\";\r\nimport \"./Address.sol\";\r\nimport \"./Context.sol\";\r\nimport \"./ERC165.sol\";\r\n\r\nabstract contract ERC721P is Context, ERC165, IERC721, IERC721Metadata {\r\n    using Address for address;\r\n    string private _name;\r\n    string private _symbol;\r\n    address[] internal _owners;\r\n    mapping(uint256 =\u003e address) private _tokenApprovals;\r\n    mapping(address =\u003e mapping(address =\u003e bool)) private _operatorApprovals;\r\n\r\n    constructor(string memory name_, string memory symbol_) {\r\n        _name = name_;\r\n        _symbol = symbol_;\r\n    }\r\n    \r\n    function getOwners() external view returns (address[] memory) {\r\n        return _owners;\r\n    }\r\n\r\n    function supportsInterface(bytes4 interfaceId)\r\n        public\r\n        view\r\n        virtual\r\n        override(ERC165, IERC165)\r\n        returns (bool)\r\n    {\r\n        return\r\n            interfaceId == type(IERC721).interfaceId ||\r\n            interfaceId == type(IERC721Metadata).interfaceId ||\r\n            super.supportsInterface(interfaceId);\r\n    }\r\n\r\n    function balanceOf(address owner)\r\n        public\r\n        view\r\n        virtual\r\n        override\r\n        returns (uint256)\r\n    {\r\n        require(\r\n            owner != address(0),\r\n            \"ERC721: balance query for the zero address\"\r\n        );\r\n        uint256 count = 0;\r\n        uint256 length = _owners.length;\r\n        for (uint256 i = 0; i \u003c length; ++i) {\r\n            if (owner == _owners[i]) {\r\n                ++count;\r\n            }\r\n        }\r\n        delete length;\r\n        return count;\r\n    }\r\n\r\n    function ownerOf(uint256 tokenId)\r\n        public\r\n        view\r\n        virtual\r\n        override\r\n        returns (address)\r\n    {\r\n        address owner = _owners[tokenId];\r\n        require(\r\n            owner != address(0),\r\n            \"ERC721: owner query for nonexistent token\"\r\n        );\r\n        return owner;\r\n    }\r\n\r\n    function name() public view virtual override returns (string memory) {\r\n        return _name;\r\n    }\r\n\r\n    function symbol() public view virtual override returns (string memory) {\r\n        return _symbol;\r\n    }\r\n\r\n    function approve(address to, uint256 tokenId) public virtual override {\r\n        address owner = ERC721P.ownerOf(tokenId);\r\n        require(to != owner, \"ERC721: approval to current owner\");\r\n\r\n        require(\r\n            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),\r\n            \"ERC721: approve caller is not owner nor approved for all\"\r\n        );\r\n\r\n        _approve(to, tokenId);\r\n    }\r\n\r\n    function getApproved(uint256 tokenId)\r\n        public\r\n        view\r\n        virtual\r\n        override\r\n        returns (address)\r\n    {\r\n        require(\r\n            _exists(tokenId),\r\n            \"ERC721: approved query for nonexistent token\"\r\n        );\r\n\r\n        return _tokenApprovals[tokenId];\r\n    }\r\n\r\n    function setApprovalForAll(address operator, bool approved)\r\n        public\r\n        virtual\r\n        override\r\n    {\r\n        require(operator != _msgSender(), \"ERC721: approve to caller\");\r\n\r\n        _operatorApprovals[_msgSender()][operator] = approved;\r\n        emit ApprovalForAll(_msgSender(), operator, approved);\r\n    }\r\n\r\n    function isApprovedForAll(address owner, address operator)\r\n        public\r\n        view\r\n        virtual\r\n        override\r\n        returns (bool)\r\n    {\r\n        return _operatorApprovals[owner][operator];\r\n    }\r\n\r\n    function transferFrom(\r\n        address from,\r\n        address to,\r\n        uint256 tokenId\r\n    ) public virtual override {\r\n        //solhint-disable-next-line max-line-length\r\n        require(\r\n            _isApprovedOrOwner(_msgSender(), tokenId),\r\n            \"ERC721: transfer caller is not owner nor approved\"\r\n        );\r\n\r\n        _transfer(from, to, tokenId);\r\n    }\r\n\r\n    function safeTransferFrom(\r\n        address from,\r\n        address to,\r\n        uint256 tokenId\r\n    ) public virtual override {\r\n        safeTransferFrom(from, to, tokenId, \"\");\r\n    }\r\n\r\n    function safeTransferFrom(\r\n        address from,\r\n        address to,\r\n        uint256 tokenId,\r\n        bytes memory _data\r\n    ) public virtual override {\r\n        require(\r\n            _isApprovedOrOwner(_msgSender(), tokenId),\r\n            \"ERC721: transfer caller is not owner nor approved\"\r\n        );\r\n        _safeTransfer(from, to, tokenId, _data);\r\n    }\r\n\r\n    function _safeTransfer(\r\n        address from,\r\n        address to,\r\n        uint256 tokenId,\r\n        bytes memory _data\r\n    ) internal virtual {\r\n        _transfer(from, to, tokenId);\r\n        require(\r\n            _checkOnERC721Received(from, to, tokenId, _data),\r\n            \"ERC721: transfer to non ERC721Receiver implementer\"\r\n        );\r\n    }\r\n\r\n    function _exists(uint256 tokenId) internal view virtual returns (bool) {\r\n        return tokenId \u003c _owners.length \u0026\u0026 _owners[tokenId] != address(0);\r\n    }\r\n\r\n    function _isApprovedOrOwner(address spender, uint256 tokenId)\r\n        internal\r\n        view\r\n        virtual\r\n        returns (bool)\r\n    {\r\n        require(\r\n            _exists(tokenId),\r\n            \"ERC721: operator query for nonexistent token\"\r\n        );\r\n        address owner = ERC721P.ownerOf(tokenId);\r\n        return (spender == owner ||\r\n            getApproved(tokenId) == spender ||\r\n            isApprovedForAll(owner, spender));\r\n    }\r\n\r\n    function _safeMint(address to, uint256 tokenId) internal virtual {\r\n        _safeMint(to, tokenId, \"\");\r\n    }\r\n\r\n    function _safeMint(\r\n        address to,\r\n        uint256 tokenId,\r\n        bytes memory _data\r\n    ) internal virtual {\r\n        _mint(to, tokenId);\r\n        require(\r\n            _checkOnERC721Received(address(0), to, tokenId, _data),\r\n            \"ERC721: transfer to non ERC721Receiver implementer\"\r\n        );\r\n    }\r\n\r\n    function _mint(address to, uint256 tokenId) internal virtual {\r\n        require(to != address(0), \"ERC721: mint to the zero address\");\r\n        require(!_exists(tokenId), \"ERC721: token already minted\");\r\n\r\n        _beforeTokenTransfer(address(0), to, tokenId);\r\n        _owners.push(to);\r\n\r\n        emit Transfer(address(0), to, tokenId);\r\n    }\r\n\r\n    function _burn(uint256 tokenId) internal virtual {\r\n        address owner = ERC721P.ownerOf(tokenId);\r\n\r\n        _beforeTokenTransfer(owner, address(0), tokenId);\r\n\r\n        // Clear approvals\r\n        _approve(address(0), tokenId);\r\n        _owners[tokenId] = address(0);\r\n\r\n        emit Transfer(owner, address(0), tokenId);\r\n    }\r\n\r\n    function _transfer(\r\n        address from,\r\n        address to,\r\n        uint256 tokenId\r\n    ) internal virtual {\r\n        require(\r\n            ERC721P.ownerOf(tokenId) == from,\r\n            \"ERC721: transfer of token that is not own\"\r\n        );\r\n        require(to != address(0), \"ERC721: transfer to the zero address\");\r\n\r\n        _beforeTokenTransfer(from, to, tokenId);\r\n\r\n        // Clear approvals from the previous owner\r\n        _approve(address(0), tokenId);\r\n        _owners[tokenId] = to;\r\n\r\n        emit Transfer(from, to, tokenId);\r\n    }\r\n\r\n    function _approve(address to, uint256 tokenId) internal virtual {\r\n        _tokenApprovals[tokenId] = to;\r\n        emit Approval(ERC721P.ownerOf(tokenId), to, tokenId);\r\n    }\r\n\r\n    function _checkOnERC721Received(\r\n        address from,\r\n        address to,\r\n        uint256 tokenId,\r\n        bytes memory _data\r\n    ) private returns (bool) {\r\n        if (to.isContract()) {\r\n            try\r\n                IERC721Receiver(to).onERC721Received(\r\n                    _msgSender(),\r\n                    from,\r\n                    tokenId,\r\n                    _data\r\n                )\r\n            returns (bytes4 retval) {\r\n                return retval == IERC721Receiver.onERC721Received.selector;\r\n            } catch (bytes memory reason) {\r\n                if (reason.length == 0) {\r\n                    revert(\r\n                        \"ERC721: transfer to non ERC721Receiver implementer\"\r\n                    );\r\n                } else {\r\n                    assembly {\r\n                        revert(add(32, reason), mload(reason))\r\n                    }\r\n                }\r\n            }\r\n        } else {\r\n            return true;\r\n        }\r\n    }\r\n\r\n    function _beforeTokenTransfer(\r\n        address from,\r\n        address to,\r\n        uint256 tokenId\r\n    ) internal virtual {}\r\n}\r\n"},"IERC165.sol":{"content":"// SPDX-License-Identifier: MIT\r\n\r\npragma solidity ^0.8.0;\r\n\r\n/**\r\n * @dev Interface of the ERC165 standard, as defined in the\r\n * https://eips.ethereum.org/EIPS/eip-165[EIP].\r\n *\r\n * Implementers can declare support of contract interfaces, which can then be\r\n * queried by others ({ERC165Checker}).\r\n *\r\n * For an implementation, see {ERC165}.\r\n */\r\ninterface IERC165 {\r\n    /**\r\n     * @dev Returns true if this contract implements the interface defined by\r\n     * `interfaceId`. See the corresponding\r\n     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]\r\n     * to learn more about how these ids are created.\r\n     *\r\n     * This function call must use less than 30 000 gas.\r\n     */\r\n    function supportsInterface(bytes4 interfaceId) external view returns (bool);\r\n}\r\n"},"IERC721.sol":{"content":"// SPDX-License-Identifier: MIT\r\n\r\npragma solidity ^0.8.0;\r\n\r\nimport \"./IERC165.sol\";\r\n\r\n/**\r\n * @dev Required interface of an ERC721 compliant contract.\r\n */\r\ninterface IERC721 is IERC165 {\r\n    /**\r\n     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.\r\n     */\r\n    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);\r\n\r\n    /**\r\n     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.\r\n     */\r\n    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);\r\n\r\n    /**\r\n     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.\r\n     */\r\n    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);\r\n\r\n    /**\r\n     * @dev Returns the number of tokens in ``owner``\u0027s account.\r\n     */\r\n    function balanceOf(address owner) external view returns (uint256 balance);\r\n\r\n    /**\r\n     * @dev Returns the owner of the `tokenId` token.\r\n     *\r\n     * Requirements:\r\n     *\r\n     * - `tokenId` must exist.\r\n     */\r\n    function ownerOf(uint256 tokenId) external view returns (address owner);\r\n\r\n    /**\r\n     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients\r\n     * are aware of the ERC721 protocol to prevent tokens from being forever locked.\r\n     *\r\n     * Requirements:\r\n     *\r\n     * - `from` cannot be the zero address.\r\n     * - `to` cannot be the zero address.\r\n     * - `tokenId` token must exist and be owned by `from`.\r\n     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.\r\n     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.\r\n     *\r\n     * Emits a {Transfer} event.\r\n     */\r\n    function safeTransferFrom(\r\n        address from,\r\n        address to,\r\n        uint256 tokenId\r\n    ) external;\r\n\r\n    /**\r\n     * @dev Transfers `tokenId` token from `from` to `to`.\r\n     *\r\n     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.\r\n     *\r\n     * Requirements:\r\n     *\r\n     * - `from` cannot be the zero address.\r\n     * - `to` cannot be the zero address.\r\n     * - `tokenId` token must be owned by `from`.\r\n     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.\r\n     *\r\n     * Emits a {Transfer} event.\r\n     */\r\n    function transferFrom(\r\n        address from,\r\n        address to,\r\n        uint256 tokenId\r\n    ) external;\r\n\r\n    /**\r\n     * @dev Gives permission to `to` to transfer `tokenId` token to another account.\r\n     * The approval is cleared when the token is transferred.\r\n     *\r\n     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.\r\n     *\r\n     * Requirements:\r\n     *\r\n     * - The caller must own the token or be an approved operator.\r\n     * - `tokenId` must exist.\r\n     *\r\n     * Emits an {Approval} event.\r\n     */\r\n    function approve(address to, uint256 tokenId) external;\r\n\r\n    /**\r\n     * @dev Returns the account approved for `tokenId` token.\r\n     *\r\n     * Requirements:\r\n     *\r\n     * - `tokenId` must exist.\r\n     */\r\n    function getApproved(uint256 tokenId) external view returns (address operator);\r\n\r\n    /**\r\n     * @dev Approve or remove `operator` as an operator for the caller.\r\n     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.\r\n     *\r\n     * Requirements:\r\n     *\r\n     * - The `operator` cannot be the caller.\r\n     *\r\n     * Emits an {ApprovalForAll} event.\r\n     */\r\n    function setApprovalForAll(address operator, bool _approved) external;\r\n\r\n    /**\r\n     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.\r\n     *\r\n     * See {setApprovalForAll}\r\n     */\r\n    function isApprovedForAll(address owner, address operator) external view returns (bool);\r\n\r\n    /**\r\n     * @dev Safely transfers `tokenId` token from `from` to `to`.\r\n     *\r\n     * Requirements:\r\n     *\r\n     * - `from` cannot be the zero address.\r\n     * - `to` cannot be the zero address.\r\n     * - `tokenId` token must exist and be owned by `from`.\r\n     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.\r\n     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.\r\n     *\r\n     * Emits a {Transfer} event.\r\n     */\r\n    function safeTransferFrom(\r\n        address from,\r\n        address to,\r\n        uint256 tokenId,\r\n        bytes calldata data\r\n    ) external;\r\n}\r\n"},"IERC721Enumerable.sol":{"content":"// SPDX-License-Identifier: MIT\r\n\r\npragma solidity ^0.8.0;\r\n\r\nimport \"./IERC721.sol\";\r\n\r\n/**\r\n * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension\r\n * @dev See https://eips.ethereum.org/EIPS/eip-721\r\n */\r\ninterface IERC721Enumerable is IERC721 {\r\n    /**\r\n     * @dev Returns the total amount of tokens stored by the contract.\r\n     */\r\n    function totalSupply() external view returns (uint256);\r\n\r\n    /**\r\n     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.\r\n     * Use along with {balanceOf} to enumerate all of ``owner``\u0027s tokens.\r\n     */\r\n    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);\r\n\r\n    /**\r\n     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.\r\n     * Use along with {totalSupply} to enumerate all tokens.\r\n     */\r\n    function tokenByIndex(uint256 index) external view returns (uint256);\r\n}\r\n"},"IERC721Metadata.sol":{"content":"// SPDX-License-Identifier: MIT\r\n\r\npragma solidity ^0.8.0;\r\n\r\nimport \"./IERC721.sol\";\r\n\r\n/**\r\n * @title ERC-721 Non-Fungible Token Standard, optional metadata extension\r\n * @dev See https://eips.ethereum.org/EIPS/eip-721\r\n */\r\ninterface IERC721Metadata is IERC721 {\r\n    /**\r\n     * @dev Returns the token collection name.\r\n     */\r\n    function name() external view returns (string memory);\r\n\r\n    /**\r\n     * @dev Returns the token collection symbol.\r\n     */\r\n    function symbol() external view returns (string memory);\r\n\r\n    /**\r\n     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.\r\n     */\r\n    function tokenURI(uint256 tokenId) external view returns (string memory);\r\n}\r\n"},"IERC721Receiver.sol":{"content":"// SPDX-License-Identifier: MIT\r\n\r\npragma solidity ^0.8.0;\r\n\r\n/**\r\n * @title ERC721 token receiver interface\r\n * @dev Interface for any contract that wants to support safeTransfers\r\n * from ERC721 asset contracts.\r\n */\r\ninterface IERC721Receiver {\r\n    /**\r\n     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}\r\n     * by `operator` from `from`, this function is called.\r\n     *\r\n     * It must return its Solidity selector to confirm the token transfer.\r\n     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.\r\n     *\r\n     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.\r\n     */\r\n    function onERC721Received(\r\n        address operator,\r\n        address from,\r\n        uint256 tokenId,\r\n        bytes calldata data\r\n    ) external returns (bytes4);\r\n}\r\n"},"Ownable.sol":{"content":"// SPDX-License-Identifier: MIT\r\n\r\npragma solidity ^0.8.0;\r\n\r\nimport \"./Context.sol\";\r\n\r\n/**\r\n * @dev Contract module which provides a basic access control mechanism, where\r\n * there is an account (an owner) that can be granted exclusive access to\r\n * specific functions.\r\n *\r\n * By default, the owner account will be the one that deploys the contract. This\r\n * can later be changed with {transferOwnership}.\r\n *\r\n * This module is used through inheritance. It will make available the modifier\r\n * `onlyOwner`, which can be applied to your functions to restrict their use to\r\n * the owner.\r\n */\r\nabstract contract Ownable is Context {\r\n    address private _owner;\r\n\r\n    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);\r\n\r\n    /**\r\n     * @dev Initializes the contract setting the deployer as the initial owner.\r\n     */\r\n    constructor() {\r\n        _setOwner(_msgSender());\r\n    }\r\n\r\n    /**\r\n     * @dev Returns the address of the current owner.\r\n     */\r\n    function owner() public view virtual returns (address) {\r\n        return _owner;\r\n    }\r\n\r\n    /**\r\n     * @dev Throws if called by any account other than the owner.\r\n     */\r\n    modifier onlyOwner() {\r\n        require(owner() == _msgSender(), \"Ownable: caller is not the owner\");\r\n        _;\r\n    }\r\n\r\n    /**\r\n     * @dev Leaves the contract without owner. It will not be possible to call\r\n     * `onlyOwner` functions anymore. Can only be called by the current owner.\r\n     *\r\n     * NOTE: Renouncing ownership will leave the contract without an owner,\r\n     * thereby removing any functionality that is only available to the owner.\r\n     */\r\n    function renounceOwnership() public virtual onlyOwner {\r\n        _setOwner(address(0));\r\n    }\r\n\r\n    /**\r\n     * @dev Transfers ownership of the contract to a new account (`newOwner`).\r\n     * Can only be called by the current owner.\r\n     */\r\n    function transferOwnership(address newOwner) public virtual onlyOwner {\r\n        require(newOwner != address(0), \"Ownable: new owner is the zero address\");\r\n        _setOwner(newOwner);\r\n    }\r\n\r\n    function _setOwner(address newOwner) private {\r\n        address oldOwner = _owner;\r\n        _owner = newOwner;\r\n        emit OwnershipTransferred(oldOwner, newOwner);\r\n    }\r\n}\r\n"},"savannah_pixels.sol":{"content":"// SPDX-License-Identifier: GPL-3.0\r\n\r\npragma solidity ^0.8.10;\r\n\r\nimport \"./ERC721Enum.sol\";\r\nimport \"./Ownable.sol\";\r\nimport \"./Strings.sol\";\r\n\r\ncontract Savannah_Pixels is ERC721Enum, Ownable {\r\n  using Strings for uint256;\r\n  string internal baseURI ;\r\n  uint256 public cost = 0.015 ether;\r\n  uint256 public maxSupply = 3333;\r\n  uint256 public maxMintAmount = 50;\r\n  bool public paused = true;\r\n  string _name = \"Savannah Pixels\";\r\n  string _symbol = \"SP\";\r\n  string _initBaseURI = \"https://xm02-uvgu-kd4v.n2.xano.io/api:ZN1Zg2oJ/savannah_pixels/\";\r\n\r\n    constructor() ERC721P(_name, _symbol){\r\n        setBaseURI(_initBaseURI);\r\n    }\r\n\r\n  // public\r\n  function mint(address _to, uint256 _mintAmount) public payable {\r\n    uint256 supply = totalSupply();\r\n    require(!paused);\r\n    require(_mintAmount \u003e 0);\r\n    require(_mintAmount \u003c= maxMintAmount);\r\n    require(supply + _mintAmount \u003c= maxSupply);\r\n\r\n\r\n    for (uint256 i = 0; i \u003c _mintAmount; i++) {\r\n      _safeMint(_to, supply + i);\r\n    }\r\n  }\r\n\r\n  function walletOfOwner(address _owner)\r\n    public\r\n    view\r\n    returns (uint256[] memory)\r\n  {\r\n    uint256 ownerTokenCount = balanceOf(_owner);\r\n    uint256[] memory tokenIds = new uint256[](ownerTokenCount);\r\n    for (uint256 i; i \u003c ownerTokenCount; i++) {\r\n      tokenIds[i] = tokenOfOwnerByIndex(_owner, i);\r\n    }\r\n    return tokenIds;\r\n  }\r\n    // internal\r\n    function _baseURI() internal view virtual returns (string memory) {\r\n        return baseURI;\r\n    }\r\n    \r\n     function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {\r\n        require(_exists(tokenId), \"ERC721Metadata: Nonexistent token\");\r\n        string memory currentBaseURI = _baseURI();\r\n     return bytes(currentBaseURI).length \u003e 0\r\n        ? string(abi.encodePacked(currentBaseURI, tokenId.toString()))\r\n        : \"\";\r\n    }\r\n\r\n  //only owner\r\n  function setCost(uint256 _newCost) public onlyOwner {\r\n    cost = _newCost;\r\n  }\r\n\r\n  function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {\r\n    maxMintAmount = _newmaxMintAmount;\r\n  }\r\n\r\n  function setBaseURI(string memory _newBaseURI) public onlyOwner {\r\n    baseURI = _newBaseURI;\r\n  }\r\n\r\n  function pause(bool _state) public onlyOwner {\r\n    paused = _state;\r\n  }\r\n \r\n\r\n  function withdraw() public payable onlyOwner {\r\n    // This pays zeekay 10% of the initial sale.\r\n    // =============================================================================\r\n    (bool hs, ) = payable(0x0344e6DC73A4128d7a889509a13C3Dd25B4B688A).call{value: address(this).balance * 10 / 100}(\"\");\r\n    require(hs);\r\n    // =============================================================================\r\n    \r\n    // This will payout the owner the contract balance.\r\n    // =============================================================================\r\n    (bool os, ) = payable(owner()).call{value: address(this).balance}(\"\");\r\n    require(os);\r\n    // =============================================================================\r\n  }\r\n}\r\n"},"Strings.sol":{"content":"// SPDX-License-Identifier: MIT\r\n\r\npragma solidity ^0.8.0;\r\n\r\n/**\r\n * @dev String operations.\r\n */\r\nlibrary Strings {\r\n    bytes16 private constant _HEX_SYMBOLS = \"0123456789abcdef\";\r\n\r\n    /**\r\n     * @dev Converts a `uint256` to its ASCII `string` decimal representation.\r\n     */\r\n    function toString(uint256 value) internal pure returns (string memory) {\r\n        // Inspired by OraclizeAPI\u0027s implementation - MIT licence\r\n        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol\r\n\r\n        if (value == 0) {\r\n            return \"0\";\r\n        }\r\n        uint256 temp = value;\r\n        uint256 digits;\r\n        while (temp != 0) {\r\n            digits++;\r\n            temp /= 10;\r\n        }\r\n        bytes memory buffer = new bytes(digits);\r\n        while (value != 0) {\r\n            digits -= 1;\r\n            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));\r\n            value /= 10;\r\n        }\r\n        return string(buffer);\r\n    }\r\n\r\n    /**\r\n     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.\r\n     */\r\n    function toHexString(uint256 value) internal pure returns (string memory) {\r\n        if (value == 0) {\r\n            return \"0x00\";\r\n        }\r\n        uint256 temp = value;\r\n        uint256 length = 0;\r\n        while (temp != 0) {\r\n            length++;\r\n            temp \u003e\u003e= 8;\r\n        }\r\n        return toHexString(value, length);\r\n    }\r\n\r\n    /**\r\n     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.\r\n     */\r\n    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {\r\n        bytes memory buffer = new bytes(2 * length + 2);\r\n        buffer[0] = \"0\";\r\n        buffer[1] = \"x\";\r\n        for (uint256 i = 2 * length + 1; i \u003e 1; --i) {\r\n            buffer[i] = _HEX_SYMBOLS[value \u0026 0xf];\r\n            value \u003e\u003e= 4;\r\n        }\r\n        require(value == 0, \"Strings: hex length insufficient\");\r\n        return string(buffer);\r\n    }\r\n}\r\n"}}