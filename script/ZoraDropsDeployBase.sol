// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {ScriptDeploymentConfig, DropDeployment} from '../src/DeploymentConfig.sol';
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ZoraNFTCreatorV1} from "../src/ZoraNFTCreatorV1.sol";
import {IERC721Drop} from "../src/interfaces/IERC721Drop.sol";

/// @notice Deployment drops for base where 
abstract contract ZoraDropsDeployBase is ScriptDeploymentConfig {
    
    /// @notice Get deployment configuration struct as JSON
    /// @param deployment deploymet struct
    /// @return deploymentJson string JSON of the deployment info
    function getDeploymentJSON(DropDeployment memory deployment) internal returns (string memory deploymentJson) {
        // This is the key for the json file geneation
        string memory deploymentJsonKey = "deployment_json_file_key";
        vm.serializeAddress(deploymentJsonKey, DROP_METADATA_RENDERER, deployment.dropMetadata);
        vm.serializeAddress(deploymentJsonKey, EDITION_METADATA_RENDERER, deployment.editionMetadata);
        vm.serializeAddress(deploymentJsonKey, ERC721DROP_IMPL, deployment.dropImplementation);
        vm.serializeAddress(deploymentJsonKey, FACTORY_UPGRADE_GATE, deployment.factoryUpgradeGate);
        vm.serializeAddress(deploymentJsonKey, ZORA_NFT_CREATOR_PROXY, deployment.factory);
        // Get the JSON key as a seralized string
        deploymentJson = vm.serializeAddress(deploymentJsonKey, ZORA_NFT_CREATOR_V1_IMPL, deployment.factoryImpl);
        console2.log(deploymentJson);
    }

    /// @notice Deploy a test contract for etherscan auto-verification
    /// @param factory Factory address to use
    function deployTestContractForVerification(ZoraNFTCreatorV1 factory) internal {
        IERC721Drop.SalesConfiguration memory saleConfig;
        address newContract = address(
            factory.createEdition(unicode"☾*☽", "~", 0, 0, payable(address(0)), address(0), saleConfig, "", DEMO_IPFS_METADATA_FILE, DEMO_IPFS_METADATA_FILE)
        );
        console2.log("Deployed new contract for verification purposes", newContract);
    }
}
