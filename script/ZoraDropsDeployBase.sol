// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

struct ChainConfig {
    address factoryOwner;
    address factoryUpgradeGateOwner;
    uint256 mintFeeAmount;
    address mintFeeRecipient;
    address subscriptionMarketFilterAddress;
    address subscriptionMarketFilterOwner;
    address zoraERC721TransferHelper;
}

struct DropDeployment {
    address dropMetadata;
    address editionMetadata;
    address dropImplementation;
    address factoryUpgradeGate;
    address factory;
    address factoryImpl;
}

abstract contract ZoraDropsDeployBase is Script {
    using stdJson for string;

    function chainId() internal view returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }

    function getChainConfig() internal returns (ChainConfig memory chainConfig) {
        string memory json = vm.readFile(string.concat("chainConfigs/", Strings.toString(chainId()), ".json"));
        chainConfig.factoryOwner = json.readAddress(".FACTORY_OWNER");
        chainConfig.factoryUpgradeGateOwner = json.readAddress(".FACTORY_UPGRADE_GATE_OWNER");
        chainConfig.mintFeeAmount = json.readUint(".MINT_FEE_AMOUNT");
        chainConfig.subscriptionMarketFilterAddress = json.readAddress(".SUBSCRIPTION_MARKET_FILTER_ADDRESS");
        chainConfig.subscriptionMarketFilterOwner = json.readAddress(".SUBSCRIPTION_MARKET_FILTER_OWNER");
        chainConfig.zoraERC721TransferHelper = json.readAddress(".ZORA_ERC721_TRANSFER_HELPER");
    }

    function getDeployment() internal returns (DropDeployment memory dropDeployment) {
        string memory json = vm.readFile(string.concat("addresses/", Strings.toString(chainId()), ".json"));
        dropDeployment.dropMetadata = json.readAddress(".DROP_METADATA_RENDERER");
        dropDeployment.editionMetadata = json.readAddress(".EDITION_METADATA_RENDERER");
        dropDeployment.dropImplementation = json.readAddress(".ERC721DROP_IMPL");
        dropDeployment.factoryUpgradeGate = json.readAddress(".FACTORY_UPGRADE_GATE");
        dropDeployment.factory = json.readAddress(".ZORA_NFT_CREATOR_PROXY");
        dropDeployment.factoryImpl = json.readAddress(".ZORA_NFT_CREATOR_V1_IMPL");
    }

    function writeDeployment(DropDeployment memory deployment) internal {
        string memory deploymentJson = "{}";
        deploymentJson = vm.serializeAddress(deploymentJson, "DROP_METADATA_RENDERER", deployment.dropMetadata);
        deploymentJson = vm.serializeAddress(deploymentJson, "EDITION_METADATA_RENDERER", deployment.editionMetadata);
        deploymentJson = vm.serializeAddress(deploymentJson, "ERC721DROP_IMPL", deployment.dropImplementation);
        deploymentJson = vm.serializeAddress(deploymentJson, "FACTORY_UPGRADE_GATE", deployment.factoryUpgradeGate);
        deploymentJson = vm.serializeAddress(deploymentJson, "ZORA_NFT_CREATOR_PROXY", deployment.factory);
        deploymentJson = vm.serializeAddress(deploymentJson, "ZORA_NFT_CREATOR_V1_IMPL", deployment.factoryImpl);

        string memory deploymentDataPath = string.concat("addresses/", Strings.toString(chainId()), ".json");
        vm.writeJson(deploymentJson, deploymentDataPath);
    }
}
