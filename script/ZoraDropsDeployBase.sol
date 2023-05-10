// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ZoraNFTCreatorV1} from "../src/ZoraNFTCreatorV1.sol";
import {IERC721Drop} from "../src/interfaces/IERC721Drop.sol";

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

    string constant DEMO_IPFS_METADATA_FILE = "ipfs://bafkreigu544g6wjvqcysurpzy5pcskbt45a5f33m6wgythpgb3rfqi3lzi";

    string constant FACTORY_OWNER = "FACTORY_OWNER";
    string constant FACTORY_UPGRADE_GATE_OWNER = "FACTORY_OWNER";
    string constant MINT_FEE_AMOUNT = "MINT_FEE_AMOUNT";
    string constant MINT_FEE_RECIPIENT = "MINT_FEE_RECIPIENT";
    string constant SUBSCRIPTION_MARKET_FILTER_ADDRESS = "SUBSCRIPTION_MARKET_FILTER_ADDRESS";
    string constant SUBSCRIPTION_MARKET_FILTER_OWNER = "SUBSCRIPTION_MARKET_FILTER_OWNER";
    string constant ZORA_ERC721_TRANSFER_HELPER = "ZORA_ERC721_TRANSFER_HELPER";

    string constant DROP_METADATA_RENDERER = "DROP_METADATA_RENDERER";
    string constant EDITION_METADATA_RENDERER = "EDITION_METADATA_RENDERER";
    string constant ERC721DROP_IMPL = "ERC721DROP_IMPL";
    string constant FACTORY_UPGRADE_GATE = "FACTORY_UPGRADE_GATE";
    string constant ZORA_NFT_CREATOR_PROXY = "ZORA_NFT_CREATOR_PROXY";
    string constant ZORA_NFT_CREATOR_V1_IMPL = "ZORA_NFT_CREATOR_V1_IMPL";

    function getKeyPrefix(string memory key) internal pure returns (string memory) {
        return string.concat(".", key);
    }

    function getChainConfig() internal returns (ChainConfig memory chainConfig) {
        string memory json = vm.readFile(string.concat("chainConfigs/", Strings.toString(chainId()), ".json"));
        chainConfig.factoryOwner = json.readAddress(getKeyPrefix(FACTORY_OWNER));
        chainConfig.factoryUpgradeGateOwner = json.readAddress(getKeyPrefix(FACTORY_UPGRADE_GATE_OWNER));
        chainConfig.mintFeeAmount = json.readUint(getKeyPrefix(MINT_FEE_AMOUNT));
        chainConfig.mintFeeRecipient = json.readAddress(getKeyPrefix(MINT_FEE_RECIPIENT));
        chainConfig.subscriptionMarketFilterAddress = json.readAddress(getKeyPrefix(SUBSCRIPTION_MARKET_FILTER_ADDRESS));
        chainConfig.subscriptionMarketFilterOwner = json.readAddress(getKeyPrefix(SUBSCRIPTION_MARKET_FILTER_OWNER));
        chainConfig.zoraERC721TransferHelper = json.readAddress(getKeyPrefix(ZORA_ERC721_TRANSFER_HELPER));
    }

    function getDeployment() internal returns (DropDeployment memory dropDeployment) {
        string memory json = vm.readFile(string.concat("addresses/", Strings.toString(chainId()), ".json"));
        dropDeployment.dropMetadata = json.readAddress(getKeyPrefix(DROP_METADATA_RENDERER));
        dropDeployment.editionMetadata = json.readAddress(getKeyPrefix(EDITION_METADATA_RENDERER));
        dropDeployment.dropImplementation = json.readAddress(getKeyPrefix(ERC721DROP_IMPL));
        dropDeployment.factoryUpgradeGate = json.readAddress(getKeyPrefix(FACTORY_UPGRADE_GATE));
        dropDeployment.factory = json.readAddress(getKeyPrefix(ZORA_NFT_CREATOR_PROXY));
        dropDeployment.factoryImpl = json.readAddress(getKeyPrefix(ZORA_NFT_CREATOR_V1_IMPL));
    }

    function getDeploymentJSON(DropDeployment memory deployment) internal returns (string memory deploymentJson) {
        string memory deploymentJsonKey = "deployment_json_file_key";
        vm.serializeAddress(deploymentJsonKey, DROP_METADATA_RENDERER, deployment.dropMetadata);
        vm.serializeAddress(deploymentJsonKey, EDITION_METADATA_RENDERER, deployment.editionMetadata);
        vm.serializeAddress(deploymentJsonKey, ERC721DROP_IMPL, deployment.dropImplementation);
        vm.serializeAddress(deploymentJsonKey, FACTORY_UPGRADE_GATE, deployment.factoryUpgradeGate);
        vm.serializeAddress(deploymentJsonKey, ZORA_NFT_CREATOR_PROXY, deployment.factory);
        deploymentJson = vm.serializeAddress(deploymentJsonKey, ZORA_NFT_CREATOR_V1_IMPL, deployment.factoryImpl);
        console2.log(deploymentJson);
    }

    function deployTestContractForVerification(ZoraNFTCreatorV1 factory) internal {
        IERC721Drop.SalesConfiguration memory saleConfig;
        address newContract = address(
            factory.createEdition(unicode"☾*☽", "~", 0, 0, payable(address(0)), address(0), saleConfig, "", DEMO_IPFS_METADATA_FILE, DEMO_IPFS_METADATA_FILE)
        );
        console2.log("Deployed new contract for verification purposes", newContract);
    }
}
