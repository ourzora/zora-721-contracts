// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {ZoraRewards} from "@zoralabs/zora-rewards/ZoraRewards.sol";

import {ERC721Drop} from "../src/ERC721Drop.sol";
import {ERC721DropProxy} from "../src/ERC721DropProxy.sol";
import {ZoraNFTCreatorV1} from "../src/ZoraNFTCreatorV1.sol";
import {ZoraNFTCreatorProxy} from "../src/ZoraNFTCreatorProxy.sol";
import {IOperatorFilterRegistry} from "../src/interfaces/IOperatorFilterRegistry.sol";
import {FactoryUpgradeGate} from "../src/FactoryUpgradeGate.sol";
import {DropMetadataRenderer} from "../src/metadata/DropMetadataRenderer.sol";
import {EditionMetadataRenderer} from "../src/metadata/EditionMetadataRenderer.sol";
import {IERC721Drop} from "../src//interfaces/IERC721Drop.sol";

import {ZoraDropsDeployBase} from "./ZoraDropsDeployBase.sol";
import {ChainConfig, DropDeployment} from '../src/DeploymentConfig.sol';

contract Deploy is ZoraDropsDeployBase {
    function run() public returns (string memory) {
        console2.log("Starting --- chainId", chainId());
        ChainConfig memory chainConfig = getChainConfig();
        console2.log(" --- chain config --- ");
        console2.log("Factory Owner", chainConfig.factoryOwner);
        console2.log("Fee Recipient", chainConfig.mintFeeRecipient);
        console2.log("Fee Amount", chainConfig.mintFeeAmount);
        console2.log("Filterer Registry", chainConfig.subscriptionMarketFilterAddress);
        console2.log("Filterer Subscription", chainConfig.subscriptionMarketFilterOwner);

        console2.log("Setup contracts ---");

        vm.startBroadcast();

        DropMetadataRenderer dropMetadata = new DropMetadataRenderer();
        EditionMetadataRenderer editionMetadata = new EditionMetadataRenderer();
        FactoryUpgradeGate factoryUpgradeGate = new FactoryUpgradeGate(chainConfig.factoryUpgradeGateOwner);

        ERC721Drop dropImplementation = new ERC721Drop({
            _zoraERC721TransferHelper: address(0x0),
            _factoryUpgradeGate: factoryUpgradeGate,
            _marketFilterDAOAddress: address(chainConfig.subscriptionMarketFilterAddress),
            _mintFeeAmount: chainConfig.mintFeeAmount,
            _mintFeeRecipient: payable(chainConfig.mintFeeRecipient),
            _zoraRewards: address(chainConfig.zoraRewards)
        });

        ZoraNFTCreatorV1 factoryImpl = new ZoraNFTCreatorV1(address(dropImplementation), editionMetadata, dropMetadata);

        // Sets owner as deployer - then the deployer address can transfer ownership
        ZoraNFTCreatorV1 factory = ZoraNFTCreatorV1(
            address(new ZoraNFTCreatorProxy(address(factoryImpl), abi.encodeWithSelector(ZoraNFTCreatorV1.initialize.selector)))
        );

        ZoraNFTCreatorV1(address(factory)).transferOwnership(chainConfig.factoryOwner);

        console2.log("Factory: ");
        console2.log(address(factory));

        deployTestContractForVerification(factory);

        // vm.stopBroadcast();

        return
            getDeploymentJSON(
                DropDeployment({
                    dropMetadata: address(dropMetadata),
                    editionMetadata: address(editionMetadata),
                    dropImplementation: address(dropImplementation),
                    factoryUpgradeGate: address(factoryUpgradeGate),
                    factory: address(factory),
                    factoryImpl: address(factoryImpl)
                })
            );
    }
}
