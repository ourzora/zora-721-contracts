// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import {ZoraDropsDeployBase} from "./ZoraDropsDeployBase.sol";
import {ChainConfig, DropDeployment} from "../src/DeploymentConfig.sol";

import {ERC721Drop} from "../src/ERC721Drop.sol";
import {ERC721DropProxy} from "../src/ERC721DropProxy.sol";
import {ZoraNFTCreatorV1} from "../src/ZoraNFTCreatorV1.sol";
import {ZoraNFTCreatorProxy} from "../src/ZoraNFTCreatorProxy.sol";
import {FactoryUpgradeGate} from "../src/FactoryUpgradeGate.sol";
import {DropMetadataRenderer} from "../src/metadata/DropMetadataRenderer.sol";
import {EditionMetadataRenderer} from "../src/metadata/EditionMetadataRenderer.sol";
import {IZoraFeeManager} from "../src/interfaces/IZoraFeeManager.sol";
import {IFactoryUpgradeGate} from "../src/interfaces/IFactoryUpgradeGate.sol";
import {ERC721DropProxy} from "../src/ERC721DropProxy.sol";
import {IERC721Drop} from "../src//interfaces/IERC721Drop.sol";

contract UpgradeERC721DropFactory is ZoraDropsDeployBase {
    function run() public returns (string memory) {
        DropDeployment memory deployment = getDeployment();
        ChainConfig memory chainConfig = getChainConfig();

        bytes32 dropRendererCodehash = keccak256(deployment.dropMetadata.code);
        // it is important for this to be _outside_ startBroadcast since this does a null deployment to
        // read the latest contract code to compare versions
        bytes32 newDropRendererCodehash = keccak256(address(new DropMetadataRenderer()).code);

        bytes32 editionRendererCodehash = keccak256(deployment.editionMetadata.code);
        // it is important for this to be _outside_ startBroadcast since this does a null deployment to
        // read the latest contract code to compare versions
        bytes32 newEditionRendererCodehash = keccak256(address(new EditionMetadataRenderer()).code);

        bool deployNewDropRenderer = dropRendererCodehash != newDropRendererCodehash;
        bool deployNewEditionRenderer = editionRendererCodehash != newEditionRendererCodehash;

        console2.log("Mint Fee Amount: ", chainConfig.mintFeeAmount);
        console2.log("Mint Fee Recipient: ", chainConfig.mintFeeRecipient);

        vm.startBroadcast();

        console2.log("Setup contracts ---");

        if (deployNewDropRenderer) {
            deployment.dropMetadata = address(new DropMetadataRenderer());
            console2.log("Deployed new drop renderer to ", deployment.dropMetadata);
        }

        if (deployNewEditionRenderer) {
            deployment.editionMetadata = address(new EditionMetadataRenderer());
            console2.log("Deployed new edition renderer to ", deployment.editionMetadata);
        }

        ERC721Drop dropImplementation = new ERC721Drop({
            _zoraERC721TransferHelper: chainConfig.zoraERC721TransferHelper,
            _factoryUpgradeGate: IFactoryUpgradeGate(deployment.factoryUpgradeGate),
            _mintFeeAmount: chainConfig.mintFeeAmount,
            _mintFeeRecipient: payable(chainConfig.mintFeeRecipient),
            _protocolRewards: chainConfig.protocolRewards
        });

        deployment.dropImplementation = address(dropImplementation);
        deployment.dropImplementationVersion = dropImplementation.contractVersion();

        console2.log("Drop IMPL: ");
        console2.log(address(dropImplementation));

        ZoraNFTCreatorV1 newZoraNFTCreatorImpl = new ZoraNFTCreatorV1({
            _implementation: address(deployment.dropImplementation),
            _editionMetadataRenderer: EditionMetadataRenderer(deployment.editionMetadata),
            _dropMetadataRenderer: DropMetadataRenderer(deployment.dropMetadata)
        });

        deployment.factoryImpl = address(newZoraNFTCreatorImpl);

        console2.log("Factory/Creator IMPL: ");
        console2.log(address(newZoraNFTCreatorImpl));

        address deployer = vm.envAddress("DEPLOYER");

        deployTestContractForVerification(newZoraNFTCreatorImpl, deployer);

        vm.stopBroadcast();

        return getDeploymentJSON(deployment);
    }
}
