// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IMetadataRenderer} from "../interfaces/IMetadataRenderer.sol";
import {IERC721Drop} from "../interfaces/IERC721Drop.sol";
import {IERC721MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC721MetadataUpgradeable.sol";
import {IERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {NFTMetadataRenderer} from "../utils/NFTMetadataRenderer.sol";
import {MetadataRenderAdminCheck} from "./MetadataRenderAdminCheck.sol";
import {BytecodeStorage} from "../utils/BytecodeStorage.sol";
import {console2} from "forge-std/console2.sol";

interface DropConfigGetter {
    function config()
        external
        view
        returns (IERC721Drop.Configuration memory config);
}

/// @notice EditionMetadataRenderer for editions support
contract OnChainImageRenderer is IMetadataRenderer, MetadataRenderAdminCheck {
    error DataInputLengthError();
    mapping(address => address) internal dataStorage;

    struct MediaData {
        string mimeType;
        bytes data;
    }

    /// @notice Storage for token edition information
    struct TokenEditionInfo {
        string description;
        MediaData image;
        MediaData animation;
    }

    /// @notice Event for updated Media URIs
    event MediaDataUpdated(
        address indexed target,
        address dataContract,
        address sender
    );

    /// @notice Event for a new edition initialized
    event EditionDataInitialized(
        address indexed target,
        address dataContract,
        address sender
    );

    /// @notice Update media URIs
    /// @param target target for contract to update metadata for
    /// @param image new image address
    /// @param animation new animation address
    function updateTokenData(
        address target,
        string memory _description,
        MediaData memory image,
        MediaData memory animation
    ) external requireSenderAdmin(target) {
        address dataContract = dataStorage[target];
        if (dataContract != address(0x0)) {
            BytecodeStorage.purgeBytecode(dataContract);
        }

        TokenEditionInfo memory editionInfo = TokenEditionInfo({
            description: _description,
            image: image,
            animation: animation
        });
        dataStorage[target] = BytecodeStorage.writeToBytecode(
            abi.encode((editionInfo))
        );
        emit MediaDataUpdated({
            target: target,
            sender: msg.sender,
            dataContract: dataContract
        });
    }

    event FieldLength(uint256 length);

    /// @notice Default initializer for edition data from a specific contract
    /// @param data data to init with
    function initializeWithData(bytes memory data) external {
        address target = msg.sender;

        // bool fieldLengthCorrect;
        // assembly {
        //     fieldLengthCorrect := eq(mload(add(data, 32)), 0x60)
        // }

        // if (!fieldLengthCorrect) {
        //     // input should be 3 arrays with 3 sizes = 6 fields in abi.
        //     revert DataInputLengthError();
        // }

        // data format: description, imageURI, animationURI
        address dataContract = BytecodeStorage.writeToBytecode(data);
        dataStorage[target] = dataContract;

        emit EditionDataInitialized({
            target: target,
            dataContract: dataContract,
            sender: target
        });
    }

    function _buildURI(MediaData memory mediaData)
        internal
        pure
        returns (string memory)
    {
        if (mediaData.data.length == 0) {
            return "";
        }
        if (bytes(mediaData.mimeType).length == 0) {
            return string(mediaData.data);
        }
        return
            NFTMetadataRenderer.encodeDataURI(
                mediaData.mimeType,
                mediaData.data
            );
    }

    /// @notice Contract URI information getter
    /// @return contract uri (if set)
    function contractURI() external view override returns (string memory) {
        address target = msg.sender;
        TokenEditionInfo memory editionInfo = abi.decode(
            BytecodeStorage.readFromBytecode(dataStorage[target]),
            (TokenEditionInfo)
        );

        IERC721Drop.Configuration memory config = DropConfigGetter(target)
            .config();

        return
            NFTMetadataRenderer.encodeContractURIJSON({
                name: IERC721MetadataUpgradeable(target).name(),
                description: editionInfo.description,
                imageURI: _buildURI(editionInfo.image),
                animationURI: _buildURI(editionInfo.animation),
                royaltyBPS: uint256(config.royaltyBPS),
                royaltyRecipient: config.fundsRecipient
            });
    }

    function description(address target) external view returns (string memory) {
        return editionInfo(target).description;
    }

    function editionInfo(address target) public view returns (TokenEditionInfo memory result) {
        console2.log(string(BytecodeStorage.readFromBytecode(dataStorage[target])));
        // return TokenEditionInfo({
        //     description: "testing2",
        //     image: MediaData({
        //         mimeType: 'image/svg+xml',
        //         data: ''
        //     }),
        //     animation: MediaData({
        //         mimeType: '',
        //         data: ''
        //     })
        // });
        (result) = abi.decode(
            BytecodeStorage.readFromBytecode(dataStorage[target]),
            (TokenEditionInfo)
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

        TokenEditionInfo memory editionInfo = abi.decode(
            BytecodeStorage.readFromBytecode(dataStorage[target]),
            (TokenEditionInfo)
        );
        IERC721Drop media = IERC721Drop(target);

        uint256 maxSupply = media.saleDetails().maxSupply;

        // For open editions, set max supply to 0 for renderer to remove the edition max number
        // This will be added back on once the open edition is "finalized"
        if (maxSupply == type(uint64).max) {
            maxSupply = 0;
        }

        return
            NFTMetadataRenderer.createMetadataEdition({
                name: IERC721MetadataUpgradeable(target).name(),
                description: editionInfo.description,
                imageUrl: _buildURI(editionInfo.image),
                animationUrl: _buildURI(editionInfo.animation),
                tokenOfEdition: tokenId,
                editionSize: maxSupply
            });
    }
}
