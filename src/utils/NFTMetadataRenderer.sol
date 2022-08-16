// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {IPublicSharedMetadata} from "../interfaces/IPublicSharedMetadata.sol";

/// NFT metadata library for rendering metadata associated with editions
library NFTMetadataRenderer {
    /// Generate edition metadata from storage information as base64-json blob
    /// Combines the media data and metadata
    /// @param name Name of NFT in metadata
    /// @param description Description of NFT in metadata
    /// @param imageUrl URL of image to render for edition
    /// @param animationUrl URL of animation to render for edition
    /// @param tokenOfEdition Token ID for specific token
    /// @param editionSize Size of entire edition to show
    function createMetadataEdition(
        string memory name,
        string memory description,
        string memory imageUrl,
        string memory animationUrl,
        uint256 tokenOfEdition,
        uint256 editionSize
    ) internal pure returns (string memory) {
        string memory _tokenMediaData = tokenMediaData(
            imageUrl,
            animationUrl,
            tokenOfEdition
        );
        bytes memory json = createMetadataJSON(
            name,
            description,
            _tokenMediaData,
            tokenOfEdition,
            editionSize
        );
        return encodeMetadataJSON(json);
    }

    function encodeContractURIJSON(
        string memory name,
        string memory description,
        string memory imageURI,
        uint256 royaltyBPS,
        address royaltyRecipient
    ) internal pure returns (string memory) {
        bytes memory imageSpace = bytes("");
        if (bytes(imageURI).length > 0) {
            imageSpace = abi.encodePacked('", "image": "', imageURI);
        }
        return
            string(
                encodeMetadataJSON(
                    abi.encodePacked(
                        '{"name": "',
                        name,
                        '", "description": "',
                        description,
                        // this is for opensea since they don't respect ERC2981 right now
                        '", "seller_fee_basis_points": ',
                        Strings.toString(royaltyBPS),
                        ', "fee_recipient": "',
                        Strings.toHexString(uint256(uint160(royaltyRecipient)), 20),
                        imageSpace,
                        '"}'
                    )
                )
            );
    }

    /// Function to create the metadata json string for the nft edition
    /// @param name Name of NFT in metadata
    /// @param description Description of NFT in metadata
    /// @param mediaData Data for media to include in json object
    /// @param tokenOfEdition Token ID for specific token
    /// @param editionSize Size of entire edition to show
    function createMetadataJSON(
        string memory name,
        string memory description,
        string memory mediaData,
        uint256 tokenOfEdition,
        uint256 editionSize
    ) internal pure returns (bytes memory) {
        bytes memory editionSizeText;
        if (editionSize > 0) {
            editionSizeText = abi.encodePacked(
                "/",
                Strings.toString(editionSize)
            );
        }
        return
            abi.encodePacked(
                '{"name": "',
                name,
                " ",
                Strings.toString(tokenOfEdition),
                editionSizeText,
                '", "',
                'description": "',
                description,
                '", "',
                mediaData,
                'properties": {"number": ',
                Strings.toString(tokenOfEdition),
                ', "name": "',
                name,
                '"}}'
            );
    }

    /// Encodes the argument json bytes into base64-data uri format
    /// @param json Raw json to base64 and turn into a data-uri
    function encodeMetadataJSON(bytes memory json)
        internal
        pure
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(json)
                )
            );
    }

    /// Generates edition metadata from storage information as base64-json blob
    /// Combines the media data and metadata
    /// @param imageUrl URL of image to render for edition
    /// @param animationUrl URL of animation to render for edition
    function tokenMediaData(
        string memory imageUrl,
        string memory animationUrl,
        uint256 tokenOfEdition
    ) internal pure returns (string memory) {
        bool hasImage = bytes(imageUrl).length > 0;
        bool hasAnimation = bytes(animationUrl).length > 0;
        if (hasImage && hasAnimation) {
            return
                string(
                    abi.encodePacked(
                        'image": "',
                        imageUrl,
                        '", "animation_url": "',
                        animationUrl,
                        '", "'
                    )
                );
        }
        if (hasImage) {
            return string(abi.encodePacked('image": "', imageUrl, '", "'));
        }
        if (hasAnimation) {
            return
                string(
                    abi.encodePacked('animation_url": "', animationUrl, '", "')
                );
        }

        return "";
    }
}
