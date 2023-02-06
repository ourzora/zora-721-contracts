// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


/// @dev Zora NFT Creator Proxy Access Contract
contract ERC721DropProxy is ERC1967Proxy {
    constructor(address target)
        payable
        ERC1967Proxy(target, '')
    {}
}