// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {NounsCoasterMetadataRenderer} from "../../src/metadata/NounsCoasterMetadataRenderer.sol";
import {INounsCoasterMetadataRendererTypes} from "../../src/interfaces/INounsCoasterMetadataRendererTypes.sol";
import {MetadataRenderAdminCheck} from "../../src/metadata/MetadataRenderAdminCheck.sol";
import {IMetadataRenderer} from "../../src/interfaces/IMetadataRenderer.sol";
import {DropMockBase} from "./DropMockBase.sol";
import {IERC721Drop} from "../../src/interfaces/IERC721Drop.sol";
import {IOwnable2Step} from "../../src/utils/ownable/IOwnable2Step.sol";
import {NounMetadataHelper} from "../../src/utils/NounMetadataHelper.sol";
import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

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

contract NounsCoasterMetadataRendererTest is Test, NounMetadataHelper {
    address public constant mediaContract = address(123456);
    bytes initStrings =
        abi.encode("", "", "Nouns Coaster", "https://image.com", "https://projectURI.com", "ipfs://QmZ9UT92uG3oxKHhm6s6Xts9p8HTxZ99KdevVhQbD3vuUj/");

    NounsCoasterMetadataRenderer public nounsRenderer;
    IERC721OnChainDataMock public mock;

    function setUp() external {
        mock = new IERC721OnChainDataMock(0, 10);
        nounsRenderer = new NounsCoasterMetadataRenderer(initStrings, address(mock), address(this));

        string[] memory names = getBackgroundNames();

        NounsCoasterMetadataRenderer.ItemParam[] memory items = getBackgroundItems();

        NounsCoasterMetadataRenderer.ItemParam[] memory getNounItems_0_3 = getNounItems_0_3();
        NounsCoasterMetadataRenderer.ItemParam[] memory getNounItems_4 = getNounItems_4();
        NounsCoasterMetadataRenderer.ItemParam[] memory getNounItems_5_7 = getNounItems_5_7();
        NounsCoasterMetadataRenderer.ItemParam[] memory getNounItems_8_10 = getNounItems_8_10();

        INounsCoasterMetadataRendererTypes.IPFSGroup memory ipfsGroup = INounsCoasterMetadataRendererTypes.IPFSGroup({
            baseUri: "ipfs://QmZ9UT92uG3oxKHhm6s6Xts9p8HTxZ99KdevVhQbD3vuUj/",
            extension: ".png"
        });        

        // Noun 1 metadata setup
        {
            string[] memory noun1Names = getNounNames(0);
            string[] memory noun1Names_0_3 = nameSlicer(noun1Names, 0, 3);
            string[] memory noun1Names_4 = nameSlicer(noun1Names, 4, 4);
            string[] memory noun1Names_5_7 = nameSlicer(noun1Names, 5, 7);
            string[] memory noun1Names_8_10 = nameSlicer(noun1Names, 8, 10);

            nounsRenderer.addNounProperties(0, noun1Names_0_3, getNounItems_0_3, ipfsGroup);
            nounsRenderer.addNounProperties(0, noun1Names_4, getNounItems_4, ipfsGroup);
            nounsRenderer.addNounProperties(0, noun1Names_5_7, getNounItems_5_7, ipfsGroup);
            nounsRenderer.addNounProperties(0, noun1Names_8_10, getNounItems_8_10, ipfsGroup);            
        }

        // Noun 2 metadata setup
        {
            string[] memory noun2Names = getNounNames(1);
            string[] memory noun2Names_0_3 = nameSlicer(noun2Names, 0, 3);
            string[] memory noun2Names_4 = nameSlicer(noun2Names, 4, 4);
            string[] memory noun2Names_5_7 = nameSlicer(noun2Names, 5, 7);
            string[] memory noun2Names_8_10 = nameSlicer(noun2Names, 8, 10);       

            nounsRenderer.addNounProperties(1, noun2Names_0_3, getNounItems_0_3, ipfsGroup);
            nounsRenderer.addNounProperties(1, noun2Names_4, getNounItems_4, ipfsGroup);
            nounsRenderer.addNounProperties(1, noun2Names_5_7, getNounItems_5_7, ipfsGroup);
            nounsRenderer.addNounProperties(1, noun2Names_8_10, getNounItems_8_10, ipfsGroup);              
        } 

        // Noun 3 metadata setup
        {
            string[] memory noun3Names = getNounNames(2);
            string[] memory noun3Names_0_3 = nameSlicer(noun3Names, 0, 3);
            string[] memory noun3Names_4 = nameSlicer(noun3Names, 4, 4);
            string[] memory noun3Names_5_7 = nameSlicer(noun3Names, 5, 7);
            string[] memory noun3Names_8_10 = nameSlicer(noun3Names, 8, 10);  

            nounsRenderer.addNounProperties(2, noun3Names_0_3, getNounItems_0_3, ipfsGroup);
            nounsRenderer.addNounProperties(2, noun3Names_4, getNounItems_4, ipfsGroup);
            nounsRenderer.addNounProperties(2, noun3Names_5_7, getNounItems_5_7, ipfsGroup);
            nounsRenderer.addNounProperties(2, noun3Names_8_10, getNounItems_8_10, ipfsGroup); 
        }

        // Noun 4 metadata setup
        {
            string[] memory noun4Names = getNounNames(3);
            string[] memory noun4Names_0_3 = nameSlicer(noun4Names, 0, 3);
            string[] memory noun4Names_4 = nameSlicer(noun4Names, 4, 4);
            string[] memory noun4Names_5_7 = nameSlicer(noun4Names, 5, 7);
            string[] memory noun4Names_8_10 = nameSlicer(noun4Names, 8, 10);          

            nounsRenderer.addNounProperties(3, noun4Names_0_3, getNounItems_0_3, ipfsGroup);
            nounsRenderer.addNounProperties(3, noun4Names_4, getNounItems_4, ipfsGroup);
            nounsRenderer.addNounProperties(3, noun4Names_5_7, getNounItems_5_7, ipfsGroup);
            nounsRenderer.addNounProperties(3, noun4Names_8_10, getNounItems_8_10, ipfsGroup);   
        }
    }

    function test_NCMetadataInits() public {
        address token = nounsRenderer.token();
        string memory image = nounsRenderer.contractImage();
        string memory uri = nounsRenderer.contractURI();
        string memory desc = nounsRenderer.description();
        string memory projURI = nounsRenderer.projectURI();

        assertEq(token, address(mock));
        assertEq(image, "https://image.com");
        assertEq(desc, "Nouns Coaster");
        assertEq(projURI, "https://projectURI.com");
        assertEq(
            uri,
            "data:application/json;base64,eyJuYW1lIjogIk1PQ0sgTkFNRSIsImRlc2NyaXB0aW9uIjogIk5vdW5zIENvYXN0ZXIiLCJpbWFnZSI6ICJodHRwczovL2ltYWdlLmNvbSIsImV4dGVybmFsX3VybCI6ICJodHRwczovL3Byb2plY3RVUkkuY29tIn0="
        );
    }

    function test_UpdateDescriptionAllowed() public {
        vm.startPrank(address(this));
        nounsRenderer.updateDescription("new description");

        string memory description = nounsRenderer.description();
        assertEq(description, "new description");
    }

    function test_UpdateDescriptionNotAllowed() public {
        vm.expectRevert(IOwnable2Step.ONLY_OWNER.selector);
        vm.prank(vm.addr(0x1));
        nounsRenderer.updateDescription("new description");
    }

    function test_OpenEdition() public {
        IERC721OnChainDataMock mock = new IERC721OnChainDataMock({totalMinted: 10, maxSupply: type(uint64).max});

        console.log("tokenURI", nounsRenderer.tokenURI(1));

        assertEq(
            "data:application/json;base64,eyJuYW1lIjogIk1PQ0sgTkFNRSAxIiwgImRlc2NyaXB0aW9uIjogIkRlc2NyaXB0aW9uIiwgImltYWdlIjogImltYWdlIiwgImFuaW1hdGlvbl91cmwiOiAiYW5pbWF0aW9uIiwgInByb3BlcnRpZXMiOiB7Im51bWJlciI6IDEsICJuYW1lIjogIk1PQ0sgTkFNRSJ9fQ==",
            nounsRenderer.tokenURI(1)
        );
    }
}
