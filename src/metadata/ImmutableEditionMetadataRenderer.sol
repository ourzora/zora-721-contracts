// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IMetadataRenderer} from "../interfaces/IMetadataRenderer.sol";
import {IERC721Drop} from "../interfaces/IERC721Drop.sol";
import {IERC721MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC721MetadataUpgradeable.sol";
import {IERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {NFTMetadataRenderer} from "../utils/NFTMetadataRenderer.sol";
import {MetadataRenderAdminCheck} from "./MetadataRenderAdminCheck.sol";
import {BytecodeStorage} from "../utils/metadata/BytecodeStorage.sol";

interface DropConfigGetter {
    function config()
        external
        view
        returns (IERC721Drop.Configuration memory config);
}

/// @notice EditionMetadataRenderer for editions support
contract EditionMetadataRenderer is
    IMetadataRenderer,
    MetadataRenderAdminCheck
{
  event SetMetadataTemplate(
    address target,
    address sender,
    string template
  );

    /// @notice Token information mapping storage
    mapping(address => address) public tokenData;

    /// @notice Update media URIs
    /// @param target target for contract to update metadata for
    /// @param imageURI new image uri address
    /// @param animationURI new animation uri address
    function updateTemplate(
        address target,
        string calldata template
    ) external requireSenderAdmin(target) {
      BytecodeStorage.purgeBytecode(tokenData[target]);
      BytecodeStorage.writeToBytecode(template);
      emit SetMetadataTemplate({
        target: target,
        sender: msg.sender, 
        template: template
      });
    }

    /// @notice Default initializer for edition data from a specific contract
    /// @param data data to init with
    function initializeWithData(bytes memory data) external {
        // data format: description, imageURI, animationURI
        (
            string memory template,
            string memory imageURI,
            string memory animationURI
        ) = abi.decode(data, (string, string, string));

        emit SetMetadataTemplate({
          target: target,
          wender: msg.sender,
          template: template
        });

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
        TokenEditionInfo storage editionInfo = tokenInfos[target];
        IERC721Drop.Configuration memory config = DropConfigGetter(target)
            .config();

        return
            NFTMetadataRenderer.encodeContractURIJSON({
                name: IERC721MetadataUpgradeable(target).name(),
                description: editionInfo.description,
                imageURI: editionInfo.imageURI,
                animationURI: editionInfo.animationURI,
                royaltyBPS: uint256(config.royaltyBPS),
                royaltyRecipient: config.fundsRecipient
            });
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
            NFTMetadataRenderer.createMetadataEdition({
                name: IERC721MetadataUpgradeable(target).name(),
                description: info.description,
                imageURI: info.imageURI,
                animationURI: info.animationURI,
                tokenOfEdition: tokenId,
                editionSize: maxSupply
            });
    }
}
