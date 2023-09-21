// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {IERC721AUpgradeable} from "erc721a-upgradeable/IERC721AUpgradeable.sol";
import {ProtocolRewards} from "@zoralabs/protocol-rewards/src/ProtocolRewards.sol";

import {IMetadataRenderer} from "../src/interfaces/IMetadataRenderer.sol";
import "../src/ZoraNFTCreatorV1.sol";
import "../src/ZoraNFTCreatorProxy.sol";
import {MockMetadataRenderer} from "./metadata/MockMetadataRenderer.sol";
import {FactoryUpgradeGate} from "../src/FactoryUpgradeGate.sol";
import {IERC721AUpgradeable} from "erc721a-upgradeable/IERC721AUpgradeable.sol";
import {ForkHelper} from "./utils/ForkHelper.sol";
import {DropDeployment , ChainConfig} from "../src/DeploymentConfig.sol";

contract ZoraNFTCreatorV1Test is Test {
    address public constant DEFAULT_OWNER_ADDRESS = address(0x23499);
    address payable public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS =
        payable(address(0x21303));
    address payable public constant DEFAULT_ZORA_DAO_ADDRESS =
        payable(address(0x999));
    address payable public constant mintFeeRecipient = payable(address(0x1234));
    uint256 public constant mintFee = 0.000777 ether;
    ERC721Drop public dropImpl;
    ZoraNFTCreatorV1 public creator;
    EditionMetadataRenderer public editionMetadataRenderer;
    DropMetadataRenderer public dropMetadataRenderer;
    ProtocolRewards internal protocolRewards;
    address internal constant DEFAULT_CREATE_REFERRAL = address(0);

    function setUp() public {
        protocolRewards = new ProtocolRewards();

        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        dropImpl = new ERC721Drop(
            address(1234),
            FactoryUpgradeGate(address(0)),
            mintFee,
            mintFeeRecipient,
            address(protocolRewards)
        );
        editionMetadataRenderer = new EditionMetadataRenderer();
        dropMetadataRenderer = new DropMetadataRenderer();
        ZoraNFTCreatorV1 impl = new ZoraNFTCreatorV1(
            address(dropImpl),
            editionMetadataRenderer,
            dropMetadataRenderer
        );
        creator = ZoraNFTCreatorV1(
            address(
                new ZoraNFTCreatorProxy(
                    address(impl),
                    abi.encodeWithSelector(ZoraNFTCreatorV1.initialize.selector)
                )
            )
        );
    }

    function test_ContractName() public {
        assertEq(creator.contractName(), "ZORA NFT Creator");
    }

    function test_ContractURI() public {
        assertEq(creator.contractURI(), "https://github.com/ourzora/zora-drops-contracts");
    }

    function test_CreateEdition() public {
        address deployedEdition = creator.createEdition(
            "name",
            "symbol",
            100,
            500,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            IERC721Drop.SalesConfiguration({
                publicSaleStart: 0,
                publicSaleEnd: type(uint64).max,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0.1 ether,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0)
            }),
            "desc",
            "animation",
            "image"
        );
        ERC721Drop drop = ERC721Drop(payable(deployedEdition));
        (, uint256 fee) = drop.zoraFeeForAmount(10);
        vm.startPrank(DEFAULT_FUNDS_RECIPIENT_ADDRESS);
        vm.deal(DEFAULT_FUNDS_RECIPIENT_ADDRESS, 10 ether + fee);
        drop.purchase{value: 1 ether + fee}(10);
        assertEq(drop.totalSupply(), 10);
    }

    function test_CreateDrop() public {
        address deployedDrop = creator.createDrop(
            "name",
            "symbol",
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            1000,
            100,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            IERC721Drop.SalesConfiguration({
                publicSaleStart: 0,
                publicSaleEnd: type(uint64).max,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0)
            }),
            "metadata_uri",
            "metadata_contract_uri"
        );
        ERC721Drop drop = ERC721Drop(payable(deployedDrop));
        (, uint256 fee) = drop.zoraFeeForAmount(10);
        drop.purchase{value: fee}(10);
        assertEq(drop.totalSupply(), 10);
    }

    function test_CreateGenericDrop() public {
        MockMetadataRenderer mockRenderer = new MockMetadataRenderer();
        address deployedDrop = creator.setupDropsContract(
            "name",
            "symbol",
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            1000,
            100,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            IERC721Drop.SalesConfiguration({
                publicSaleStart: 0,
                publicSaleEnd: type(uint64).max,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0)
            }),
            mockRenderer,
            "",
            DEFAULT_CREATE_REFERRAL
        );
        ERC721Drop drop = ERC721Drop(payable(deployedDrop));
        ERC721Drop.SaleDetails memory saleDetails = drop.saleDetails();
        assertEq(saleDetails.publicSaleStart, 0);
        assertEq(saleDetails.publicSaleEnd, type(uint64).max);

        vm.expectRevert(
            IERC721AUpgradeable.URIQueryForNonexistentToken.selector
        );
        drop.tokenURI(1);
        assertEq(drop.contractURI(), "DEMO");
        (, uint256 fee) = drop.zoraFeeForAmount(1);
        drop.purchase{value: fee}(1);
        assertEq(drop.tokenURI(1), "DEMO");
    }


}
