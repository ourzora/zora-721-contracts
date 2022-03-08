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

    SharedNFTLogic private immutable sharedNFTLogic;

    constructor(SharedNFTLogic _sharedNFTLogic) {
        sharedNFTLogic = _sharedNFTLogic;
    }

    function updateMediaURIs(
        address target,
        string memory imageUrl,
        string memory animationUrl
    ) external {
        require(ZoraNFTBase(target).isAdmin(msg.sender), "only admin");
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
    ) external {
        TokenEditionInfo memory info;
        info.description = description;
        info.imageUrl = imageUrl;
        info.animationUrl = animationUrl;

        tokenInfos[target] = info;
    }

    function tokenURI(address target, uint256 tokenId)
        external
        view
        returns (string memory)
    {
        TokenEditionInfo memory info = tokenInfos[target];
        ZoraNFTBase media = ZoraNFTBase(target);

        return
            sharedNFTLogic.createMetadataEdition({
                name: media.name(),
                description: info.description,
                imageUrl: info.imageUrl,
                animationUrl: info.animationUrl,
                tokenOfEdition: tokenId,
                editionSize: media.editionSize()
            });
    }
}
