// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ImmutableEditionMetadataRenderer} from "../../src/metadata/ImmutableEditionMetadataRenderer.sol";
import {MetadataRenderAdminCheck} from "../../src/metadata/MetadataRenderAdminCheck.sol";
import {IMetadataRenderer} from "../../src/interfaces/IMetadataRenderer.sol";
import {DropMockBase} from "./DropMockBase.sol";
import {IERC721Drop} from "../../src/interfaces/IERC721Drop.sol";
import {Test} from "forge-std/Test.sol";

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

    function saleDetails() external returns (IERC721Drop.SaleDetails memory) {
        return saleDetailsInternal;
    }

    function config() external returns (IERC721Drop.Configuration memory) {
        return configInternal;
    }
}

contract DropImmutableEditionMetadataRendererTest is Test {
    address public constant mediaContract = address(123456);
    ImmutableEditionMetadataRenderer public immutableEditionRenderer = new ImmutableEditionMetadataRenderer();

    function test_ImmutableEditionMetadataInits() public {
        vm.startPrank(address(0x123));
        bytes memory data = abi.encode('{"name": "testing __TOKEN_ID__", "description": "Token Description", "properties": {"number": "__TOKEN_ID__"}}');
        immutableEditionRenderer.initializeWithData(data);
        string memory template = immutableEditionRenderer.tokenDataWithIdReplaced(address(0x123), "3");
        assertEq(template, '{"name": "testing 3", "description": "Token Description", "properties": {"number": "3"}}');
    }

    function test_UpdateTemplateAllowed() public {
        vm.startPrank(address(0x123));
        bytes memory data = abi.encode('{"name": "testing__TOKEN_ID__", "description": "Token Description", "properties": {"number": "__TOKEN_ID__"}}');
        immutableEditionRenderer.initializeWithData(data);

        immutableEditionRenderer.updateTemplate(address(0x123), '{"name": "BaSic"}');
        string memory template = immutableEditionRenderer.tokenDataWithIdReplaced(address(0x123), "3");
        assertEq(template, '{"name": "BaSic"}');
    }

    function test_NormalEdition() public {
        IERC721OnChainDataMock mock = new IERC721OnChainDataMock({totalMinted: 10, maxSupply: 200});
        vm.startPrank(address(mock));
        immutableEditionRenderer.initializeWithData(
            abi.encode('{"name": "testing __TOKEN_ID__", "description": "Token Description", "properties": {"number": "__TOKEN_ID__"}}')
        );
        assertEq(
            immutableEditionRenderer.tokenURI(4),
            "data:application/json;base64,eyJuYW1lIjogInRlc3RpbmcgNC8yMDAiLCAiZGVzY3JpcHRpb24iOiAiVG9rZW4gRGVzY3JpcHRpb24iLCAicHJvcGVydGllcyI6IHsibnVtYmVyIjogIjQvMjAwIn19"
        );
    }

    function test_ImmutableEditionOpenEdition() public {
        IERC721OnChainDataMock mock = new IERC721OnChainDataMock({totalMinted: 10, maxSupply: type(uint64).max});
        vm.startPrank(address(mock));
        immutableEditionRenderer.initializeWithData(
            abi.encode('{"name": "testing __TOKEN_ID__", "description": "Token Description", "properties": {"number": "__TOKEN_ID__"}}')
        );
        assertEq(
            immutableEditionRenderer.tokenURI(1),
            "data:application/json;base64,eyJuYW1lIjogInRlc3RpbmcgMSIsICJkZXNjcmlwdGlvbiI6ICJUb2tlbiBEZXNjcmlwdGlvbiIsICJwcm9wZXJ0aWVzIjogeyJudW1iZXIiOiAiMSJ9fQ=="
        );
    }

    function test_ContractURI() public {
        IERC721OnChainDataMock mock = new IERC721OnChainDataMock({totalMinted: 20, maxSupply: 10});
        vm.startPrank(address(mock));
        immutableEditionRenderer.initializeWithData(abi.encode('{"name": "testing __TOKEN_ID__", "description": "Token Description"}'));
        // {"name": "testing 1", "description": "Token Description"}}
        assertEq(
            immutableEditionRenderer.contractURI(),
            "data:application/json;base64,eyJuYW1lIjogInRlc3RpbmcgMSIsICJkZXNjcmlwdGlvbiI6ICJUb2tlbiBEZXNjcmlwdGlvbiJ9fQ=="
        );
    }
}
