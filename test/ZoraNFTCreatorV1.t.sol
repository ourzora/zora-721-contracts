// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

import {IMetadataRenderer} from "../src/interfaces/IMetadataRenderer.sol";
import "../src/ZoraNFTCreatorV1.sol";
import "../src/ZoraFeeManager.sol";
import "../src/ZoraNFTCreatorProxy.sol";
import {FactoryUpgradeGate} from "../src/FactoryUpgradeGate.sol";
import {SharedNFTLogic} from "../src/utils/SharedNFTLogic.sol";

contract ZoraFeeManagerTest is DSTest {
    Vm public constant vm = Vm(HEVM_ADDRESS);
    address public constant DEFAULT_OWNER_ADDRESS = address(0x23499);
    address payable public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS =
        payable(address(0x21303));
    address payable public constant DEFAULT_ZORA_DAO_ADDRESS =
        payable(address(0x999));
    ERC721Drop public dropImpl;
    ZoraNFTCreatorV1 public creator;
    EditionMetadataRenderer public editionMetadataRenderer;
    DropMetadataRenderer public dropMetadataRenderer;

    function setUp() public {
        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        ZoraFeeManager feeManager = new ZoraFeeManager(
            500,
            DEFAULT_ZORA_DAO_ADDRESS
        );
        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        SharedNFTLogic sharedLogic = new SharedNFTLogic();
        dropImpl = new ERC721Drop(
            feeManager,
            address(1234),
            FactoryUpgradeGate(address(0))
        );
        editionMetadataRenderer = new EditionMetadataRenderer(sharedLogic);
        dropMetadataRenderer = new DropMetadataRenderer();
        ZoraNFTCreatorV1 impl = new ZoraNFTCreatorV1(
            address(dropImpl),
            editionMetadataRenderer,
            dropMetadataRenderer
        );
        creator = ZoraNFTCreatorV1(
            address(new ZoraNFTCreatorProxy(address(impl), ""))
        );
        creator.initialize();
    }

    function test_CreateEdition() public {
        address deployedDrop = creator.createEdition(
            "name",
            "symbol",
            100,
            500,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            IERC721Drop.SalesConfiguration({
                publicSaleStart: 0,
                publicSaleEnd: 0,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0)
            }),
            "desc",
            "animation",
            "image"
        );
    }
}
