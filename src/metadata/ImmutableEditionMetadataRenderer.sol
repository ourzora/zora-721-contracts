// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IMetadataRenderer} from "../interfaces/IMetadataRenderer.sol";
import {IERC721Drop} from "../interfaces/IERC721Drop.sol";
import {IERC721MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC721MetadataUpgradeable.sol";
import {IERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {NFTMetadataRenderer} from "../utils/NFTMetadataRenderer.sol";
import {MetadataRenderAdminCheck} from "./MetadataRenderAdminCheck.sol";
import {BytecodeStorage} from "../utils/metadata/BytecodeStorage.sol";
import {LibString} from "../utils/metadata/LibString.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

interface DropConfigGetter {
    function config() external view returns (IERC721Drop.Configuration memory config);
}

/// @notice ImmutableEditionMetadataRenderer for editions support with contract storage optimization
contract ImmutableEditionMetadataRenderer is IMetadataRenderer, MetadataRenderAdminCheck {
    event SetMetadataTemplate(address target, address sender, string template);

    /// @notice Token information mapping storage
    mapping(address => address) public tokenData;

    /// @notice Update template
    /// @param target target for contract to update metadata for
    /// @param template new template to update
    function updateTemplate(address target, string calldata template) external requireSenderAdmin(target) {
        BytecodeStorage.purgeBytecode(tokenData[target]);
        tokenData[target] = BytecodeStorage.writeToBytecode(template);
        emit SetMetadataTemplate({target: target, sender: msg.sender, template: template});
    }

    /// @notice Default initializer for edition data from a specific contract
    /// @param data data to init with
    function initializeWithData(bytes memory data) external {
        // data format: description, imageURI, animationURI
        string memory template = abi.decode(data, (string));

        address target = msg.sender;

        tokenData[target] = BytecodeStorage.writeToBytecode(template);

        emit SetMetadataTemplate({target: target, sender: msg.sender, template: template});
    }

    function tokenDataWithIdReplaced(address target, string memory idReplacement) public view returns (string memory) {
        string memory data = BytecodeStorage.readFromBytecode(tokenData[target]);

        return LibString.replace(data, "__TOKEN_ID__", idReplacement);
    }

    /// @notice Contract URI information getter
    /// @return contract uri (if set)
    function contractURI() external view override returns (string memory) {
        return NFTMetadataRenderer.encodeMetadataJSON(bytes(tokenDataWithIdReplaced(msg.sender, "")));
    }

    /// @notice Token URI information getter
    /// @param tokenId to get uri for
    /// @return contract uri (if set)
    function tokenURI(uint256 tokenId) external view override returns (string memory) {
        address target = msg.sender;

        IERC721Drop media = IERC721Drop(target);

        uint256 maxSupply = media.saleDetails().maxSupply;

        string memory numberString = string.concat(Strings.toString(tokenId));

        if (maxSupply != type(uint64).max) {
            numberString = string.concat(Strings.toString(tokenId), "/", Strings.toString(maxSupply));
        }

        return NFTMetadataRenderer.encodeMetadataJSON(bytes(tokenDataWithIdReplaced(msg.sender, numberString)));
    }
}
