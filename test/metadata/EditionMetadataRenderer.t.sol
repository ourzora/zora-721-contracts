// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {EditionMetadataRenderer} from "../../src/metadata/EditionMetadataRenderer.sol";
import {MetadataRenderAdminCheck} from "../../src/metadata/MetadataRenderAdminCheck.sol";
import {SharedNFTLogic} from "../../src/utils/SharedNFTLogic.sol";
import {DropMockBase} from "./DropMockBase.sol";
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

    function test_UpdateDescriptionAllowed() public {
        vm.startPrank(address(0x123));
        bytes memory data = abi.encode(
            "Description for metadata",
            "https://example.com/image.png",
            "https://example.com/animation.mp4"
        );
        editionRenderer.initializeWithData(data);

        editionRenderer.updateDescription(address(0x123), "new description");

        (string memory updatedDescription, , ) = editionRenderer.tokenInfos(
            address(0x123)
        );
        assertEq(updatedDescription, "new description");
    }

    function test_UpdateDescriptionNotAllowed() public {
        DropMockBase base = new DropMockBase();
        vm.startPrank(address(base));
        bytes memory data = abi.encode(
            "Description for metadata",
            "https://example.com/image.png",
            "https://example.com/animation.mp4"
        );
        editionRenderer.initializeWithData(data);
        vm.stopPrank();

        vm.expectRevert(MetadataRenderAdminCheck.Access_OnlyAdmin.selector);
        editionRenderer.updateDescription(address(base), "new description");
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

    function test_MetadatURIUpdateNotAllowed() public {
        DropMockBase base = new DropMockBase();
        vm.startPrank(address(base));
        bytes memory data = abi.encode(
            "Description for metadata",
            "https://example.com/image.png",
            "https://example.com/animation.mp4"
        );
        editionRenderer.initializeWithData(data);
        vm.stopPrank();

        vm.prank(address(0x144));
        vm.expectRevert(MetadataRenderAdminCheck.Access_OnlyAdmin.selector);
        editionRenderer.updateMediaURIs(
            address(base),
            "https://example.com/image.png",
            "https://example.com/animation.mp4"
        );
    }
}
