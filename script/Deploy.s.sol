// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {ERC721Drop} from "../src/ERC721Drop.sol";
import {ERC721DropProxy} from "../src/ERC721DropProxy.sol";
import {ZoraNFTCreatorV1} from "../src/ZoraNFTCreatorV1.sol";
import {ZoraNFTCreatorProxy} from "../src/ZoraNFTCreatorProxy.sol";
import {IOperatorFilterRegistry} from "../src/interfaces/IOperatorFilterRegistry.sol";
import {OwnedSubscriptionManager} from "../src/filter/OwnedSubscriptionManager.sol";
import {FactoryUpgradeGate} from "../src/FactoryUpgradeGate.sol";
import {DropMetadataRenderer} from "../src/metadata/DropMetadataRenderer.sol";
import {EditionMetadataRenderer} from "../src/metadata/EditionMetadataRenderer.sol";
import {EditionOptimizedMetadataRenderer} from "../src/metadata/EditionOptimizedMetadataRenderer.sol";

contract Deploy is Script {
    using Strings for uint256;

    function run() public {
        uint256 chainID = vm.envUint("CHAIN_ID");
        console.log("CHAIN_ID", chainID);

        console2.log("Starting ---");

        vm.startBroadcast();
        address daoFilterMarketAddress = vm.envAddress("SUBSCRIPTION_MARKET_FILTER_ADDRESS");

        address factoryUpgradeGateOwner = vm.envAddress("FACTORY_UPGRADE_GATE_OWNER");

        uint256 mintFeeAmount = vm.envUint("MINT_FEE_AMOUNT");
        address payable mintFeeRecipient = payable(vm.envAddress("MINT_FEE_RECIPIENT"));

        address transferHelper = vm.envOr("ZORA_ERC721_TRANSFER_HELPER", address(0));

        console2.log("Setup contracts ---");
        DropMetadataRenderer dropMetadata = new DropMetadataRenderer();
        EditionMetadataRenderer editionMetadata = new EditionMetadataRenderer();
        EditionOptimizedMetadataRenderer optimizedEditionMetadata = new EditionOptimizedMetadataRenderer();
        FactoryUpgradeGate factoryUpgradeGate = new FactoryUpgradeGate(factoryUpgradeGateOwner);

        ERC721Drop dropImplementation = new ERC721Drop({
            _zoraERC721TransferHelper: transferHelper,
            _factoryUpgradeGate: factoryUpgradeGate,
            _marketFilterDAOAddress: address(daoFilterMarketAddress),
            _mintFeeAmount: mintFeeAmount,
            _mintFeeRecipient: mintFeeRecipient
        });

        ZoraNFTCreatorV1 factoryImpl = new ZoraNFTCreatorV1(address(dropImplementation), editionMetadata, dropMetadata);

        // Sets owner as deployer - then the deployer address can transfer ownership
        ZoraNFTCreatorProxy factory = new ZoraNFTCreatorProxy(address(factoryImpl), abi.encodeWithSelector(ZoraNFTCreatorV1.initialize.selector));

        vm.stopBroadcast();

        console2.log("Factory: ");
        console2.log(address(factory));

        string memory deploymentJson = "{}";
        deploymentJson = vm.serializeAddress(deploymentJson, "ZORA_ERC721_TRANSFER_HELPER", transferHelper);
        deploymentJson = vm.serializeAddress(deploymentJson, "FACTORY_UPGRADE_GATE", address(factoryUpgradeGate));
        deploymentJson = vm.serializeAddress(deploymentJson, "OWNED_SUBSCRIPTION_MANAGER", daoFilterMarketAddress);
        deploymentJson = vm.serializeAddress(deploymentJson, "EDITION_METADATA_RENDERER", address(editionMetadata));
        deploymentJson = vm.serializeAddress(deploymentJson, "EDITION_OPTIMIZED_METADATA_RENDERER", address(optimizedEditionMetadata));
        deploymentJson = vm.serializeAddress(deploymentJson, "DROP_METADATA_RENDERER", address(dropMetadata));
        deploymentJson = vm.serializeAddress(deploymentJson, "ERC721DROP_IMPL", address(dropImplementation));
        deploymentJson = vm.serializeAddress(deploymentJson, "ZORA_NFT_CREATOR_V1_IMPL", address(factoryImpl));
        deploymentJson = vm.serializeAddress(deploymentJson, "ZORA_NFT_CREATOR_PROXY", address(factory));
        deploymentJson = vm.serializeAddress(deploymentJson, "MINT_FEE_RECIPIENT", address(mintFeeRecipient));
        deploymentJson = vm.serializeUint(deploymentJson, "MINT_FEE_AMOUNT", mintFeeAmount);

        string memory deploymentDataPath = string.concat("addresses/", vm.envString("CHAIN_ID"), ".json");
        vm.writeJson(deploymentJson, deploymentDataPath);
    }
}
