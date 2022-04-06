// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {IMetadataRenderer} from "../interfaces/IMetadataRenderer.sol";
import {ZoraNFTBase} from "../ZoraNFTBase.sol";

/// @notice Add ZORF NFT Style Fee Support
contract DropMetadataRenderer is IMetadataRenderer {
    struct MetadataURIInfo {
        string base;
        string extension;
        string contractURI;
        uint256 freezeAt;
    }

    mapping(address => MetadataURIInfo) public metadataBaseByContract;

    function updateMetadataBase(
        address target,
        string memory baseUri,
        string memory newContractURI
    ) external {
        updateMetadataBaseWithDetails(target, baseUri, "", newContractURI, 0);
    }

    function updateMetadataBaseWithDetails(
        address target,
        string memory metadataBase,
        string memory metadataExtension,
        string memory newContractURI,
        uint256 freezeAt
    ) public {
        require(ZoraNFTBase(target).isAdmin(msg.sender), "Only admin");
        require(freezeAt == 0 || freezeAt < block.timestamp, "Metadata frozen");
        metadataBaseByContract[target] = MetadataURIInfo({
            base: metadataBase,
            extension: metadataExtension,
            contractURI: newContractURI,
            freezeAt: freezeAt
        });
    }

    function contractURI(address target) external view returns (string memory) {
        return metadataBaseByContract[target].contractURI;
    }

    function tokenURI(address target, uint256 tokenId)
        external
        view
        returns (string memory)
    {
        MetadataURIInfo memory info = metadataBaseByContract[target];

        return
            string(
                abi.encodePacked(
                    info.base,
                    StringsUpgradeable.toString(tokenId),
                    info.extension
                )
            );
    }
}
