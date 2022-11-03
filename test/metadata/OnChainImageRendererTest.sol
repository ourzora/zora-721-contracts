// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {OnChainImageRenderer} from "../../src/metadata/OnChainImageRenderer.sol";
import {MetadataRenderAdminCheck} from "../../src/metadata/MetadataRenderAdminCheck.sol";
import {IMetadataRenderer} from "../../src/interfaces/IMetadataRenderer.sol";
import {DropMockBase} from "./DropMockBase.sol";
import {IERC721Drop} from "../../src/interfaces/IERC721Drop.sol";
import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

contract IERC721OnChainDataMock {
    IERC721Drop.SaleDetails private saleDetailsInternal;
    IERC721Drop.Configuration private configInternal;

    constructor(uint256 totalMinted, uint256 maxSupply) {
        saleDetailsInternal = IERC721Drop.SaleDetails({
            publicSaleActive: false,
            presaleActive: false,
            publicSalePrice: 0,
            publicSaleStart: 0,
            publicSaleEnd: 0,
            presaleStart: 0,
            presaleEnd: 0,
            presaleMerkleRoot: 0x0000000000000000000000000000000000000000000000000000000000000000,
            maxSalePurchasePerAddress: 0,
            totalMinted: totalMinted,
            maxSupply: maxSupply
        });

        configInternal = IERC721Drop.Configuration({
            metadataRenderer: IMetadataRenderer(address(0x0)),
            editionSize: 12,
            royaltyBPS: 1000,
            fundsRecipient: payable(address(0x163))
        });
    }

    function name() external returns (string memory) {
        return "MOCK NAME";
    }

    function saleDetails() external returns (IERC721Drop.SaleDetails memory) {
        return saleDetailsInternal;
    }

    function config() external returns (IERC721Drop.Configuration memory) {
        return configInternal;
    }
}

contract OnchainEditionMetadataRendererTest is DSTest {
    Vm public constant vm = Vm(HEVM_ADDRESS);
    address public constant mediaContract = address(123456);
    OnChainImageRenderer public editionRenderer = new OnChainImageRenderer();

    function test_EditionMetadataInitsURLs() public {
        vm.startPrank(address(0x123));
        OnChainImageRenderer.MediaData
            memory mediaDataImage = OnChainImageRenderer.MediaData(
                "text/plain",
                "hello testing"
            );
        OnChainImageRenderer.MediaData
            memory mediaDataAnimation = OnChainImageRenderer.MediaData(
                "",
                "https://example.com/animation.mp4"
            );
        bytes memory data = abi.encode(OnChainImageRenderer.TokenEditionInfo({
            description: "Description for metadata",
            image: mediaDataImage,
            animation: mediaDataAnimation
        }));
        editionRenderer.initializeWithData(data);
        OnChainImageRenderer.TokenEditionInfo
            memory editionInfo = editionRenderer.editionInfo(address(0x123));
        assertEq(editionInfo.description, "Description for metadata");
        assertEq(editionInfo.image.mimeType, "image/svg+xml");
        assertEq(editionInfo.image.data.length, 0);
        assertEq(editionInfo.animation.mimeType, "");
        assertEq(
            string(editionInfo.animation.data),
            "https://example.com/animation.mp4"
        );
    }

    function test_EditionMetadataInitsData() public {
        vm.startPrank(address(0x123));
        OnChainImageRenderer.MediaData
            memory mediaDataImage = OnChainImageRenderer.MediaData(
                "text/plain",
                "hello testing"
            );
        OnChainImageRenderer.MediaData
            memory mediaDataAnimation = OnChainImageRenderer.MediaData(
                "text/html",
                "<!doctype html><html><head></head><body>asdfjiawef asdf asd fasjkldfklajsdfjlkasdjlkfaljskdf alkjsdfj klasdfjlkas dlkjfkljas df ljkasdlkjfalkjsdfkljasdfl kjasdljkfjlk asdfljk aslkdj flkjasd flkjasdljk falkjsdfl jkasdljk faljksd flkj asdlkjfaljksd flkasdfjlk afd</body></html>"
            );
        bytes memory data = abi.encode(OnChainImageRenderer.TokenEditionInfo({
            description: "Description for metadata",
            image: mediaDataImage,
            animation: mediaDataAnimation
        }));
        editionRenderer.initializeWithData(data);
        OnChainImageRenderer.TokenEditionInfo
            memory editionInfo = editionRenderer.editionInfo(address(0x123));
        assertEq(editionInfo.description, "Description for metadata");
        assertEq(editionInfo.image.mimeType, "image/svg+xml");
        assertEq(string(editionInfo.image.data), "hello testing");
        assertEq(editionInfo.animation.mimeType, "");
        assertEq(
            string(editionInfo.animation.data),
            "https://example.com/animation.mp4"
        );
    }

    function test_AllowMetadataURIUpdates() public {
        vm.startPrank(address(0x123));
        OnChainImageRenderer.MediaData
            memory mediaDataImage = OnChainImageRenderer.MediaData(
                "text/plain",
                "hello testing"
            );
        OnChainImageRenderer.MediaData
            memory mediaDataAnimation = OnChainImageRenderer.MediaData(
                "text/html",
                "<!doctype html><html><head></head><body>asdfjiawef asdf asd fasjkldfklajsdfjlkasdjlkfaljskdf alkjsdfj klasdfjlkas dlkjfkljas df ljkasdlkjfalkjsdfkljasdfl kjasdljkfjlk asdfljk aslkdj flkjasd flkjasdljk falkjsdfl jkasdljk faljksd flkj asdlkjfaljksd flkasdfjlk afd</body></html>"
            );

        bytes memory data = abi.encode(OnChainImageRenderer.TokenEditionInfo({
            description: "Description for metadata 2",
            image: mediaDataImage,
            animation: mediaDataAnimation
    }));
        editionRenderer.initializeWithData(data);

        mediaDataAnimation.data = "";
        editionRenderer.updateTokenData(
            address(0x123),
            "description",
            mediaDataImage,
            mediaDataAnimation
        );

        OnChainImageRenderer.TokenEditionInfo
            memory editionInfo = editionRenderer.editionInfo(address(0x123));
        assertEq(editionInfo.description, "description");
        assertEq(editionInfo.image.mimeType, "image/svg+xml");
        assertEq(string(editionInfo.image.data), "hello testing");
        assertEq(editionInfo.animation.mimeType, "");
        assertEq(string(editionInfo.animation.data), "");
    }

    function test_MetadataURIUpdateNotAllowed() public {
        DropMockBase base = new DropMockBase();
        vm.startPrank(address(base));
        OnChainImageRenderer.MediaData
            memory mediaDataImage = OnChainImageRenderer.MediaData(
                "text/plain",
                "hello testing"
            );
        OnChainImageRenderer.MediaData
            memory mediaDataAnimation = OnChainImageRenderer.MediaData(
                "text/html",
                "<!doctype html><html><head></head><body>asdfjiawef asdf asd fasjkldfklajsdfjlkasdjlkfaljskdf alkjsdfj klasdfjlkas dlkjfkljas df ljkasdlkjfalkjsdfkljasdfl kjasdljkfjlk asdfljk aslkdj flkjasd flkjasdljk falkjsdfl jkasdljk faljksd flkj asdlkjfaljksd flkasdfjlk afd</body></html>"
            );

        bytes memory data = abi.encode(OnChainImageRenderer.TokenEditionInfo({
            description: "Description for metadata 2",
            image: mediaDataImage,
            animation: mediaDataAnimation
    }));
        editionRenderer.initializeWithData(data);

        vm.prank(address(0x144));
        vm.expectRevert(MetadataRenderAdminCheck.Access_OnlyAdmin.selector);
        editionRenderer.updateTokenData(
            address(base),
            "description",
            mediaDataImage,
            mediaDataAnimation
        );
    }

    function test_MetadataRenderingURI() public {
        IERC721OnChainDataMock mock = new IERC721OnChainDataMock({
            totalMinted: 10,
            maxSupply: 100
        });
        vm.startPrank(address(mock));

        OnChainImageRenderer.MediaData
            memory mediaDataImage = OnChainImageRenderer.MediaData(
                "text/plain",
                "hello testing"
            );
        OnChainImageRenderer.MediaData
            memory mediaDataAnimation = OnChainImageRenderer.MediaData(
                "text/html",
                "<!doctype html><html><head></head><body>asdfjiawef asdf asd fasjkldfklajsdfjlkasdjlkfaljskdf alkjsdfj klasdfjlkas dlkjfkljas df ljkasdlkjfalkjsdfkljasdfl kjasdljkfjlk asdfljk aslkdj flkjasd flkjasdljk falkjsdfl jkasdljk faljksd flkj asdlkjfaljksd flkasdfjlk afd</body></html>"
            );
        bytes memory data = abi.encode(OnChainImageRenderer.TokenEditionInfo({
            description: "Description for metadata",
            image: mediaDataImage,
            animation: mediaDataAnimation
    }));
        editionRenderer.initializeWithData(data);

        //
        assertEq(
            "data:application/json;base64,eyJuYW1lIjogIk1PQ0sgTkFNRSAxLzEwMCIsICJkZXNjcmlwdGlvbiI6ICJEZXNjcmlwdGlvbiIsICJpbWFnZSI6ICJpbWFnZSIsICJhbmltYXRpb25fdXJsIjogImFuaW1hdGlvbiIsICJwcm9wZXJ0aWVzIjogeyJudW1iZXIiOiAxLCAibmFtZSI6ICJNT0NLIE5BTUUifX0=",
            editionRenderer.tokenURI(1)
        );
    }

    function test_OpenEdition() public {
        IERC721OnChainDataMock mock = new IERC721OnChainDataMock({
            totalMinted: 10,
            maxSupply: type(uint64).max
        });
        vm.startPrank(address(mock));
        OnChainImageRenderer.MediaData
            memory mediaDataImage = OnChainImageRenderer.MediaData(
                "image/svg+xml",
                "<svg></svg>"
            );
        OnChainImageRenderer.MediaData
            memory mediaDataAnimation = OnChainImageRenderer.MediaData(
                "",
                "https://animation-provider.com/animation.mp4"
            );
        bytes memory data = abi.encode(OnChainImageRenderer.TokenEditionInfo({
            description: "Very very long silly description for metadata",
            image: mediaDataImage,
            animation: mediaDataAnimation
    }));
        editionRenderer.initializeWithData(data);

        //
        assertEq(
            "data:application/json;base64,eyJuYW1lIjogIk1PQ0sgTkFNRSAxIiwgImRlc2NyaXB0aW9uIjogIkRlc2NyaXB0aW9uIiwgImltYWdlIjogImltYWdlIiwgImFuaW1hdGlvbl91cmwiOiAiYW5pbWF0aW9uIiwgInByb3BlcnRpZXMiOiB7Im51bWJlciI6IDEsICJuYW1lIjogIk1PQ0sgTkFNRSJ9fQ==",
            editionRenderer.tokenURI(1)
        );
    }

    function test_ContractURI() public {
        IERC721OnChainDataMock mock = new IERC721OnChainDataMock({
            totalMinted: 20,
            maxSupply: 10
        });
        vm.startPrank(address(mock));
        OnChainImageRenderer.MediaData
            memory mediaDataImage = OnChainImageRenderer.MediaData(
                "image/svg+xml",
                "<svg></svg>"
            );
        OnChainImageRenderer.MediaData
            memory mediaDataAnimation = OnChainImageRenderer.MediaData(
                "",
                "https://animation-provider.com/animation.mp4"
            );
        bytes memory data = abi.encode(OnChainImageRenderer.TokenEditionInfo({
            description: "Very very long silly description for metadata",
            image: mediaDataImage,
            animation: mediaDataAnimation
    }));
        editionRenderer.initializeWithData(data);
        assertEq(
            "data:application/json;base64,eyJuYW1lIjogIk1PQ0sgTkFNRSIsICJkZXNjcmlwdGlvbiI6ICJEZXNjcmlwdGlvbiIsICJzZWxsZXJfZmVlX2Jhc2lzX3BvaW50cyI6IDEwMDAsICJmZWVfcmVjaXBpZW50IjogIjB4MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDE2MyIsICJpbWFnZSI6ICJpcGZzOi8vaW1hZ2UifQ==",
            editionRenderer.contractURI()
        );
    }
}
