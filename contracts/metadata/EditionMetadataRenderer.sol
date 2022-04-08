// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IMetadataRenderer} from "../interfaces/IMetadataRenderer.sol";
import {ZoraNFTBase} from "../ZoraNFTBase.sol";
import {SharedNFTLogic} from "../utils/SharedNFTLogic.sol";

contract EditionMetadataRenderer is IMetadataRenderer {
    struct TokenEditionInfo {
        string description;
        string imageUrl;
        string animationUrl;
    }
    mapping(address => TokenEditionInfo) public tokenInfos;

    modifier requireSenderAdmin(address target) {
        require(
            target == msg.sender || ZoraNFTBase(target).isAdmin(msg.sender),
            "Only admin"
        );

        _;
    }

    SharedNFTLogic private immutable sharedNFTLogic;

    constructor(SharedNFTLogic _sharedNFTLogic) {
        sharedNFTLogic = _sharedNFTLogic;
    }

    function updateMediaURIs(
        address target,
        string memory imageUrl,
        string memory animationUrl
    ) external requireSenderAdmin(target) {
        tokenInfos[target].imageUrl = imageUrl;
        tokenInfos[target].animationUrl = animationUrl;
    }

    function setEditionDataForContract(
        address target,
        string memory description,
        string memory imageUrl,
        // stored as calldata
        bytes32 imageHash,
        string memory animationUrl,
        // stored as calldata
        bytes32 animationHash
    ) external requireSenderAdmin(target) {
        TokenEditionInfo memory info;
        info.description = description;
        info.imageUrl = imageUrl;
        info.animationUrl = animationUrl;

        tokenInfos[target] = info;
    }

    function contractURI() external view override returns (string memory) {
        address target = msg.sender;
        bytes memory imageSpace;
        if (bytes(tokenInfos[target].imageUrl).length > 0) {
            imageSpace = abi.encodePacked(
                '", "image": "',
                tokenInfos[target].imageUrl
            );
        }
        return
            string(
                sharedNFTLogic.encodeMetadataJSON(
                    abi.encodePacked(
                        '{"name": "',
                        ZoraNFTBase(target).name,
                        '", "description": "',
                        tokenInfos[target].description,
                        imageSpace,
                        '"}'
                    )
                )
            );
    }

    function tokenURI(uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        address target = msg.sender;

        TokenEditionInfo memory info = tokenInfos[target];
        ZoraNFTBase media = ZoraNFTBase(target);

        return
            sharedNFTLogic.createMetadataEdition({
                name: media.name(),
                description: info.description,
                imageUrl: info.imageUrl,
                animationUrl: info.animationUrl,
                tokenOfEdition: tokenId,
                editionSize: media.saleDetails().maxSupply
            });
    }
}
