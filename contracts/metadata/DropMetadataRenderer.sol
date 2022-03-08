// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {IMetadataRenderer} from "../interfaces/IMetadataRenderer.sol";
import {ZoraNFTBase} from "../ZoraNFTBase.sol";

contract DropMetadataRenderer is IMetadataRenderer {
    struct MetadataURIInfo {
        string base;
        string extension;
        uint256 freezeAt;
    }

    mapping(address => MetadataURIInfo) public metadataBaseByContract;

    function updateMetadataBase(address target, string memory baseUri)
        external
    {
        updateMetadataBaseWithDetails(target, baseUri, "", 0);
    }

    function updateMetadataBaseWithDetails(
        address target,
        string memory metadataBase,
        string memory metadataExtension,
        uint256 freezeAt
    ) public {
        require(ZoraNFTBase(target).isAdmin(msg.sender), "Only admin");
        require(freezeAt == 0 || freezeAt < block.timestamp, "Metadata frozen");
        metadataBaseByContract[target] = MetadataURIInfo({
            base: metadataBase,
            extension: metadataExtension,
            freezeAt: freezeAt
        });
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
