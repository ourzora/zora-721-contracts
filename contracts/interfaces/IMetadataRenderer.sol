// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface IMetadataRenderer {
    function tokenURI(address, uint256) external returns (string memory);
    function contractURI(address) external returns (string memory);
}
