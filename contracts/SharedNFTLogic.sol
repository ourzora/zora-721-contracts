// SPDX-License-Identifier: GPL-3.0

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "base64-sol/base64.sol";

contract SharedNFTLogic {
    function base64Encode(bytes memory args)
        public
        pure
        returns (string memory)
    {
        return Base64.encode(args);
    }

    function numberToString(uint256 value) public pure returns (string memory) {
        return Strings.toString(value);
    }

    function createMetadataEdition(
        string memory name,
        string memory description,
        string memory imageUrl,
        string memory animationUrl,
        uint256 tokenOfEdition,
        uint256 editionSize
    ) external pure returns (string memory) {
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

    function createMetadataJSON(
        string memory name,
        string memory description,
        string memory mediaData,
        uint256 tokenOfEdition,
        uint256 editionSize
    ) public pure returns (bytes memory) {
        return
            abi.encodePacked(
                '{"name": "',
                name,
                " ",
                Strings.toString(tokenOfEdition),
                "/",
                Strings.toString(editionSize),
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

    function encodeMetadataJSON(bytes memory json)
        public
        pure
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    base64Encode(json)
                )
            );
    }

    function tokenMediaData(
        string memory imageUrl,
        string memory animationUrl,
        uint256 tokenOfEdition
    ) public pure returns (string memory) {
        bool hasImage = bytes(imageUrl).length > 0;
        bool hasAnimation = bytes(animationUrl).length > 0;
        if (hasImage && hasAnimation) {
            return
                string(
                    abi.encodePacked(
                        'image": "',
                        imageUrl,
                        "?id=",
                        numberToString(tokenOfEdition),
                        '", "animation_url": "',
                        animationUrl,
                        "?id=",
                        numberToString(tokenOfEdition),
                        '", "'
                    )
                );
        }
        if (hasImage) {
            return
                string(
                    abi.encodePacked(
                        'image": "',
                        imageUrl,
                        "?id=",
                        numberToString(tokenOfEdition),
                        '", "'
                    )
                );
        }
        if (hasAnimation) {
            return
                string(
                    abi.encodePacked(
                        'animation_url": "',
                        animationUrl,
                        "?id=",
                        numberToString(tokenOfEdition),
                        '", "'
                    )
                );
        }

        return "";
    }
}
