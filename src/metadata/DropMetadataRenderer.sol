// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {IMetadataRenderer} from "../interfaces/IMetadataRenderer.sol";
import {MetadataRenderAdminCheck} from "./MetadataRenderAdminCheck.sol";

/// @notice Drops metadata system
contract DropMetadataRenderer is IMetadataRenderer, MetadataRenderAdminCheck {
    error MetadataFrozen();

    /// Event to mark updated metadata information
    event MetadataUpdated(
        address indexed target,
        string metadataBase,
        string metadataExtension,
        string contractURI,
        uint256 freezeAt
    );

    /// @notice Hash to mark updated provenance hash
    event ProvenanceHashUpdated(address indexed target, bytes32 provenanceHash);

    /// @notice Struct to store metadata info and update data
    struct MetadataURIInfo {
        string base;
        string extension;
        string contractURI;
        uint256 freezeAt;
    }

    /// @notice NFT metadata by contract
    mapping(address => MetadataURIInfo) public metadataBaseByContract;

    /// @notice Optional provenance hashes for NFT metadata by contract
    mapping(address => bytes32) public provenanceHashes;

    /// @notice Standard init for drop metadata from root drop contract
    /// @param data passed in for initialization
    function initializeWithData(bytes memory data) external {
        // data format: string baseURI, string newContractURI
        (string memory initialBaseURI, string memory initialContractURI) = abi
            .decode(data, (string, string));
        _updateMetadataDetails(
            msg.sender,
            initialBaseURI,
            "",
            initialContractURI,
            0
        );
    }

    /// @notice Update the provenance hash (optional) for a given nft
    /// @param target target address to update
    /// @param provenanceHash provenance hash to set
    function updateProvenanceHash(
        address target,
        bytes32 provenanceHash
    ) external requireSenderAdmin(target) {
        provenanceHashes[target] = provenanceHash;
        emit ProvenanceHashUpdated(target, provenanceHash);
    }

    /// @notice Update metadata base URI and contract URI
    /// @param baseUri new base URI
    /// @param newContractUri new contract URI (can be an empty string)
    function updateMetadataBase(
        address target,
        string memory baseUri,
        string memory newContractUri
    ) external requireSenderAdmin(target) {
        _updateMetadataDetails(target, baseUri, "", newContractUri, 0);
    }

    /// @notice Update metadata base URI, extension, contract URI and freezing detailsUpdate metadata base URI, extension, contract URI and freezing detailsUpdate metadata base URI, extension, contract URI and freezing detailsUpdate metadata base URI, extension, contract URI and freezing detailsUpdate metadata base URI, extension, contract URI and freezing detailsUpdate metadata base URI, extension, contract URI and freezing detailsUpdate metadata base URI, extension, contract URI and freezing detailsUpdate metadata base URI, extension, contract URI and freezing details
    /// @param target target contract to update metadata for
    /// @param metadataBase new base URI to update metadata with
    /// @param metadataExtension new extension to append to base metadata URI
    /// @param freezeAt time to freeze the contract metadata at (set to 0 to disable)
    function updateMetadataBaseWithDetails(
        address target,
        string memory metadataBase,
        string memory metadataExtension,
        string memory newContractURI,
        uint256 freezeAt
    ) external requireSenderAdmin(target) {
        _updateMetadataDetails(
            target,
            metadataBase,
            metadataExtension,
            newContractURI,
            freezeAt
        );
    }

    /// @notice Internal metadata update function
    /// @param metadataBase Base URI to update metadata for
    /// @param metadataExtension Extension URI to update metadata for
    /// @param freezeAt timestamp to freeze metadata (set to 0 to disable freezing)
    function _updateMetadataDetails(
        address target,
        string memory metadataBase,
        string memory metadataExtension,
        string memory newContractURI,
        uint256 freezeAt
    ) internal {
        if (freezeAt != 0 && freezeAt > block.timestamp) {
            revert MetadataFrozen();
        }

        metadataBaseByContract[target] = MetadataURIInfo({
            base: metadataBase,
            extension: metadataExtension,
            contractURI: newContractURI,
            freezeAt: freezeAt
        });
        emit MetadataUpdated({
            target: target,
            metadataBase: metadataBase,
            metadataExtension: metadataExtension,
            contractURI: newContractURI,
            freezeAt: freezeAt
        });
    }

    /// @notice A contract URI for the given drop contract
    /// @dev reverts if a contract uri is not provided
    /// @return contract uri for the contract metadata
    function contractURI() external view override returns (string memory) {
        string memory uri = metadataBaseByContract[msg.sender].contractURI;
        if (bytes(uri).length == 0) revert();
        return uri;
    }

    /// @notice A token URI for the given drops contract
    /// @dev reverts if a contract uri is not set
    /// @return token URI for the given token ID and contract (set by msg.sender)
    function tokenURI(
        uint256 tokenId
    ) external view override returns (string memory) {
        MetadataURIInfo memory info = metadataBaseByContract[msg.sender];

        if (bytes(info.base).length == 0) revert();

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
