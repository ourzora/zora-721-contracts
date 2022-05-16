// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {EditionMetadataRenderer} from "../../src/metadata/EditionMetadataRenderer.sol";
import {SharedNFTLogic} from "../../src/utils/SharedNFTLogic.sol";
import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

contract EditionMetadataRendererTest is DSTest {
    Vm public constant vm = Vm(HEVM_ADDRESS);
    address public constant mediaContract = address(123456);
    SharedNFTLogic public sharedLogic = new SharedNFTLogic();
    EditionMetadataRenderer public editionRenderer =
        new EditionMetadataRenderer(sharedLogic);

    function test_EditionMetadataInits() public {
        vm.startPrank(address(0x123));
        bytes memory data = abi.encode(
            "Description for metadata",
            "https://example.com/image.png",
            "https://example.com/animation.mp4"
        );
        editionRenderer.initializeWithData(data);
        (
            string memory description,
            string memory imageURI,
            string memory animationURI
        ) = editionRenderer.tokenInfos(address(0x123));
        assertEq(description, "Description for metadata");
        assertEq(animationURI, "https://example.com/animation.mp4");
        assertEq(imageURI, "https://example.com/image.png");
    }

    function test_AllowMetadataURIUpdates() public {
        vm.startPrank(address(0x123));
        bytes memory data = abi.encode(
            "Description for metadata",
            "https://example.com/image.png",
            "https://example.com/animation.mp4"
        );
        editionRenderer.initializeWithData(data);

        editionRenderer.updateMediaURIs(
            address(0x123),
            "https://example.com/image.png",
            "https://example.com/animation.mp4"
        );
        editionRenderer.initializeWithData(data);
        (
            string memory description,
            string memory imageURI,
            string memory animationURI
        ) = editionRenderer.tokenInfos(address(0x123));
        assertEq(description, "Description for metadata");
        assertEq(animationURI, "https://example.com/animation.mp4");
        assertEq(imageURI, "https://example.com/image.png");
    }
}