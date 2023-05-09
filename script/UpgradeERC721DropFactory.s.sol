// SPDX-License-Identifier: UNLICENSED
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

        // bytes32 dropRendererCodehash = keccak256(deployment.dropMetadata.code);
        // bytes32 editionRendererCodehash = keccak256(deployment.editionMetadata.code);

        // bytes32 newDropRendererCodehash = keccak256(address(new DropMetadataRenderer()).code);
        // bytes32 newEditionRendererCodehash = keccak256(address(new EditionMetadataRenderer()).code);

        // bool deployNewDropRenderer = dropRendererCodehash != newDropRendererCodehash;
        // bool deployNewEditionRenderer = dropRendererCodehash != newDropRendererCodehash;

        vm.startBroadcast();

        console2.log("Setup contracts ---");

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
            _editionMetadataRenderer: EditionMetadataRenderer(
                deployment.editionMetadata
            ),
            _dropMetadataRenderer: DropMetadataRenderer(deployment.dropMetadata)
        });

        deployment.factoryImpl = address(newZoraNFTCreatorImpl);

        console2.log("Factory/Creator IMPL: ");
        console2.log(address(newZoraNFTCreatorImpl));

        IERC721Drop.SalesConfiguration memory saleConfig;
        address newContract = address(ZoraNFTCreatorV1(deployment.factoryImpl).createEdition(
            unicode"☾*☽",
            "~",
            0,
            0,
            payable(address(0)),
            address(0),
            saleConfig,
            "",
            "ipfs://bafkreigu544g6wjvqcysurpzy5pcskbt45a5f33m6wgythpgb3rfqi3lzi",
            "ipfs://bafkreigu544g6wjvqcysurpzy5pcskbt45a5f33m6wgythpgb3rfqi3lzi"
        ));

        console2.log("Deploying new contract for verification purposes", newContract);

        vm.stopBroadcast();

        writeDeployment(deployment);
    }
}
