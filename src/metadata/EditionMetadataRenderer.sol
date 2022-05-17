// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IMetadataRenderer} from "../interfaces/IMetadataRenderer.sol";
import {IERC721Drop} from "../interfaces/IERC721Drop.sol";
import {IERC721MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC721MetadataUpgradeable.sol";
import {SharedNFTLogic} from "../utils/SharedNFTLogic.sol";
import {MetadataRenderAdminCheck} from "./MetadataRenderAdminCheck.sol";

/// @notice EditionMetadataRenderer for editions support
contract EditionMetadataRenderer is IMetadataRenderer, MetadataRenderAdminCheck {
    /// @notice Storage for token edition information
    struct TokenEditionInfo {
        string description;
        string imageURI;
        string animationURI;
    }

    /// @notice Event for updated Media URIs
    event MediaURIsUpdated(
        address indexed target,
        address sender,
        string imageURI,
        string animationURI
    );

    /// @notice Event for a new edition initialized
    /// @dev admin function indexer feedback
    event EditionInitialized(
        address indexed target,
        string description,
        string imageURI,
        string animationURI
    );

    /// @notice Description updated for this edition
    /// @dev admin function indexer feedback
    event DescriptionUpdated(
        address indexed target,
        address sender,
        string newDescription
    );

    /// @notice Token information mapping storage
    mapping(address => TokenEditionInfo) public tokenInfos;

    /// @notice Reference to Shared NFT logic library
    SharedNFTLogic private immutable sharedNFTLogic;

    /// @notice Constructor for library
    /// @param _sharedNFTLogic reference to shared NFT logic library
    constructor(SharedNFTLogic _sharedNFTLogic) {
        sharedNFTLogic = _sharedNFTLogic;
    }

    /// @notice Update media URIs
    /// @param target target for contract to update metadata for
    /// @param imageURI new image uri address
    /// @param animationURI new animation uri address
    function updateMediaURIs(
        address target,
        string memory imageURI,
        string memory animationURI
    ) external requireSenderAdmin(target) {
        tokenInfos[target].imageURI = imageURI;
        tokenInfos[target].animationURI = animationURI;
        emit MediaURIsUpdated({
            target: target,
            sender: msg.sender,
            imageURI: imageURI,
            animationURI: animationURI
        });
    }

    /// @notice Admin function to update description
    /// @param target target description
    /// @param newDescription new description
    function updateDescription(address target, string memory newDescription)
        external
        requireSenderAdmin(target)
    {
        tokenInfos[target].description = newDescription;

        emit DescriptionUpdated({
            target: target,
            sender: msg.sender,
            newDescription: newDescription
        });
    }

    /// @notice Default initializer for edition data from a specific contract
    /// @param data data to init with
    function initializeWithData(bytes memory data) external {
        // data format: description, imageURI, animationURI
        (
            string memory description,
            string memory imageURI,
            string memory animationURI
        ) = abi.decode(data, (string, string, string));

        tokenInfos[msg.sender] = TokenEditionInfo({
            description: description,
            imageURI: imageURI,
            animationURI: animationURI
        });
        emit EditionInitialized({
            target: msg.sender,
            description: description,
            imageURI: imageURI,
            animationURI: animationURI
        });
    }

    /// @notice Contract URI information getter
    /// @return contract uri (if set)
    function contractURI() external view override returns (string memory) {
        address target = msg.sender;
        bytes memory imageSpace = bytes("");
        if (bytes(tokenInfos[target].imageURI).length > 0) {
            imageSpace = abi.encodePacked(
                '", "image": "',
                tokenInfos[target].imageURI
            );
        }
        return
            string(
                sharedNFTLogic.encodeMetadataJSON(
                    abi.encodePacked(
                        '{"name": "',
                        IERC721MetadataUpgradeable(target).name(),
                        '", "description": "',
                        tokenInfos[target].description,
                        imageSpace,
                        '"}'
                    )
                )
            );
    }

    /// @notice Token URI information getter
    /// @param tokenId to get uri for
    /// @return contract uri (if set)
    function tokenURI(uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        address target = msg.sender;

        TokenEditionInfo memory info = tokenInfos[target];
        IERC721Drop media = IERC721Drop(target);

        uint256 maxSupply = media.saleDetails().maxSupply;

        // For open editions, set max supply to 0 for renderer to remove the edition max number
        // This will be added back on once the open edition is "finalized"
        if (maxSupply == type(uint64).max) {
            maxSupply = 0;
        }

        return
            sharedNFTLogic.createMetadataEdition({
                name: IERC721MetadataUpgradeable(target).name(),
                description: info.description,
                imageUrl: info.imageURI,
                animationUrl: info.animationURI,
                tokenOfEdition: tokenId,
                editionSize: media.saleDetails().maxSupply
            });
    }
}
