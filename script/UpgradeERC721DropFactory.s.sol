// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import {ZoraDropsDeployBase, ChainConfig, DropDeployment} from "./ZoraDropsDeployBase.sol";

import {ERC721Drop} from "../src/ERC721Drop.sol";
import {ERC721DropProxy} from "../src/ERC721DropProxy.sol";
import {ZoraNFTCreatorV1} from "../src/ZoraNFTCreatorV1.sol";
import {ZoraNFTCreatorProxy} from "../src/ZoraNFTCreatorProxy.sol";
import {IOperatorFilterRegistry} from "../src/interfaces/IOperatorFilterRegistry.sol";
import {OwnedSubscriptionManager} from "../src/filter/OwnedSubscriptionManager.sol";
import {FactoryUpgradeGate} from "../src/FactoryUpgradeGate.sol";
import {DropMetadataRenderer} from "../src/metadata/DropMetadataRenderer.sol";
import {EditionMetadataRenderer} from "../src/metadata/EditionMetadataRenderer.sol";
import {IZoraFeeManager} from "../src/interfaces/IZoraFeeManager.sol";
import {IFactoryUpgradeGate} from "../src/interfaces/IFactoryUpgradeGate.sol";
import {ERC721DropProxy} from "../src/ERC721DropProxy.sol";
import {IERC721Drop} from "../src//interfaces/IERC721Drop.sol";

contract UpgradeERC721DropFactory is ZoraDropsDeployBase {
    function run() public {
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
            _marketFilterDAOAddress: chainConfig.subscriptionMarketFilterAddress,
            _mintFeeAmount: chainConfig.mintFeeAmount,
            _mintFeeRecipient: payable(chainConfig.mintFeeRecipient)
        });

        deployment.dropImplementation = address(dropImplementation);

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

        deployTestContractForVerification(newZoraNFTCreatorImpl);

        vm.stopBroadcast();

        writeDeployment(deployment);
    }
}
