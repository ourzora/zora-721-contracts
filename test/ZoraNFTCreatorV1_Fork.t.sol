// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {IMetadataRenderer} from "../src/interfaces/IMetadataRenderer.sol";
import "../src/ZoraNFTCreatorV1.sol";
import "../src/ZoraNFTCreatorProxy.sol";
import {MockMetadataRenderer} from "./metadata/MockMetadataRenderer.sol";
import {FactoryUpgradeGate} from "../src/FactoryUpgradeGate.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC721AUpgradeable} from "erc721a-upgradeable/IERC721AUpgradeable.sol";
import {ForkHelper} from "./utils/ForkHelper.sol";
import {DropDeployment, ChainConfig} from "../src/DeploymentConfig.sol";

contract ZoraNFTCreatorV1Test is Test, ForkHelper {
    address public constant DEFAULT_OWNER_ADDRESS = address(0x23499);
    address payable public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS = payable(address(0x21303));
    address payable public constant DEFAULT_ZORA_DAO_ADDRESS = payable(address(0x999));
    address payable public constant mintFeeRecipient = payable(address(0x1234));
    uint256 public constant mintFee = 0.000777 ether;
    ERC721Drop public dropImpl;
    ZoraNFTCreatorV1 public creator;
    EditionMetadataRenderer public editionMetadataRenderer;
    DropMetadataRenderer public dropMetadataRenderer;

    function makeDefaultSalesConfiguration(uint104 price) internal returns (IERC721Drop.SalesConfiguration memory) {
        return IERC721Drop.SalesConfiguration({
                publicSaleStart: 0,
                publicSaleEnd: type(uint64).max,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: price,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0)
            });
    }

    function test_create_fork() external {
        string[] memory forkTestChains = getForkTestChains();

        for (uint256 i = 0; i < forkTestChains.length; i++) {
            string memory chainName = forkTestChains[i];

            vm.createSelectFork(vm.rpcUrl(chainName));
            creator = ZoraNFTCreatorV1(getDeployment().factory);
            verifyAddressesFork(chainName);
            forkEdition();
            forkDrop();
            forkDropGeneric();
        }
    }

    function verifyAddressesFork(string memory chainName) internal {
        ChainConfig memory chainConfig = getChainConfig();
        DropDeployment memory deployment = getDeployment();

        assertEq(chainConfig.factoryOwner, OwnableUpgradeable(deployment.factory).owner(), string.concat("configured owner incorrect on: ", chainName));

        bytes32 slot = UUPSUpgradeable(deployment.factoryImpl).proxiableUUID();
        address factoryImpl = address(uint160(uint256(vm.load(deployment.factory, slot))));
        if (factoryImpl != deployment.factoryImpl) {
            console2.log("===========");
            console2.log("===========");
            console2.log("FACTORY IMPL NOT SAME AS CHAIN: SIMULATING UPGRADE STEP");
            console2.log("to save changes: call upgradeTo(", deployment.factoryImpl, ")");
            console2.log(string.concat("data: ", vm.toString(abi.encodeWithSelector(UUPSUpgradeable.upgradeTo.selector, deployment.factoryImpl)), ")"));
            console2.log("on ", deployment.factory);
            console2.log("chain: ", chainName);
            console2.log("===========");
            console2.log("===========");

            creator = ZoraNFTCreatorV1(deployment.factory);
            vm.prank(creator.owner());
            creator.upgradeTo(deployment.factoryImpl);
        }

        assertEq(
            deployment.dropMetadata,
            address(creator.dropMetadataRenderer()),
            string.concat("configured drop metadata renderer incorrect on: ", chainName)
        );
        assertEq(
            deployment.editionMetadata,
            address(creator.editionMetadataRenderer()),
            string.concat("configured edition metadata renderer incorrect on: ", chainName)
        );
        assertEq(deployment.dropImplementation, address(creator.implementation()), string.concat("configured metadata renderer incorrect on: ", chainName));
    }

    function forkEdition() internal {
        address deployedEdition = creator.createEdition(
            "name",
            "symbol",
            100,
            500,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            makeDefaultSalesConfiguration(0.1 ether), 
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

    function forkDrop() internal {
        address deployedDrop = creator.createDrop(
            "name",
            "symbol",
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            1000,
            100,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            makeDefaultSalesConfiguration(0),
            "metadata_uri",
            "metadata_contract_uri"
        );
        ERC721Drop drop = ERC721Drop(payable(deployedDrop));
        (, uint256 fee) = drop.zoraFeeForAmount(10);
        drop.purchase{value: fee}(10);
        assertEq(drop.totalSupply(), 10);
    }

    function forkDropGeneric() internal {
        MockMetadataRenderer mockRenderer = new MockMetadataRenderer();
        address deployedDrop = creator.setupDropsContract(
            "name",
            "symbol",
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            1000,
            100,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            makeDefaultSalesConfiguration(0),
            mockRenderer,
            ""
        );
        ERC721Drop drop = ERC721Drop(payable(deployedDrop));
        ERC721Drop.SaleDetails memory saleDetails = drop.saleDetails();
        assertEq(saleDetails.publicSaleStart, 0);
        assertEq(saleDetails.publicSaleEnd, type(uint64).max);

        vm.expectRevert(IERC721AUpgradeable.URIQueryForNonexistentToken.selector);
        drop.tokenURI(1);
        assertEq(drop.contractURI(), "DEMO");
        (, uint256 fee) = drop.zoraFeeForAmount(1);
        drop.purchase{value: fee}(1);
        assertEq(drop.tokenURI(1), "DEMO");
    }
}
