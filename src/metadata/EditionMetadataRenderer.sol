// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IMetadataRenderer} from "../interfaces/IMetadataRenderer.sol";
import {ERC721Drop} from "../ERC721Drop.sol";
import {SharedNFTLogic} from "../utils/SharedNFTLogic.sol";

/// @notice EditionMetadataRenderer for editions support
contract EditionMetadataRenderer is IMetadataRenderer {
    struct TokenEditionInfo {
        string description;
        string imageURI;
        string animationURI;
    }

    mapping(address => TokenEditionInfo) public tokenInfos;

    modifier requireSenderAdmin(address target) {
        require(
            target == msg.sender || ERC721Drop(target).isAdmin(msg.sender),
            "Only admin"
        );

        _;
    }

    SharedNFTLogic private immutable sharedNFTLogic;

    constructor(address _sharedNFTLogic) {
        sharedNFTLogic = SharedNFTLogic(_sharedNFTLogic);
    }

    function updateMediaURIs(
        address target,
        string memory imageURI,
        string memory animationURI
    ) external requireSenderAdmin(target) {
        tokenInfos[target].imageURI = imageURI;
        tokenInfos[target].animationURI = animationURI;
    }

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
    }

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
                        ERC721Drop(target).name,
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
        ERC721Drop media = ERC721Drop(target);

        uint256 maxSupply = media.saleDetails().maxSupply;

        // For open editions, set max supply to 0 for renderer to remove the edition max number
        // This will be added back on once the open edition is "finalized"
        if (maxSupply == type(uint64).max) {
            maxSupply = 0;
        }

        return
            sharedNFTLogic.createMetadataEdition({
                name: media.name(),
                description: info.description,
                imageUrl: info.imageURI,
                animationUrl: info.animationURI,
                tokenOfEdition: tokenId,
                editionSize: media.saleDetails().maxSupply
            });
    }
}
