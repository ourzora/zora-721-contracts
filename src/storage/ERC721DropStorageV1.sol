// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {IERC721Drop} from "../interfaces/IERC721Drop.sol";

contract ERC721DropStorageV1 {
    /// @notice Configuration for NFT minting contract storage
    IERC721Drop.Configuration public config;

    /// @notice Sales configuration
    IERC721Drop.SalesConfiguration public salesConfig;

    /// @dev Mapping for presale mint counts by address to allow public mint limit
    mapping(address => uint256) public presaleMintsByAddress;
}
