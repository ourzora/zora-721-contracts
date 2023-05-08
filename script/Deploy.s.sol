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

contract Deploy is Script {
    using Strings for uint256;

    function run() public {
        uint256 chainID = vm.envUint("CHAIN_ID");
        console.log("CHAIN_ID", chainID);

        console2.log("Starting ---");

        vm.startBroadcast();
        address daoFilterMarketAddress = vm.envAddress(
            "SUBSCRIPTION_MARKET_FILTER_ADDRESS"
        );

        address factoryUpgradeGateOwner = vm.envAddress(
            "FACTORY_UPGRADE_GATE_OWNER"
        );

        uint256 mintFeeAmount = vm.envUint("MINT_FEE_AMOUNT");
        address payable mintFeeRecipient = payable(
            vm.envAddress("MINT_FEE_RECIPIENT")
        );

        console2.log("Setup contracts ---");
        DropMetadataRenderer dropMetadata = new DropMetadataRenderer();
        EditionMetadataRenderer editionMetadata = new EditionMetadataRenderer();
        FactoryUpgradeGate factoryUpgradeGate = new FactoryUpgradeGate(
            factoryUpgradeGateOwner
        );

        ERC721Drop dropImplementation = new ERC721Drop({
            _zoraERC721TransferHelper: address(0x0),
            _factoryUpgradeGate: factoryUpgradeGate,
            _marketFilterDAOAddress: address(daoFilterMarketAddress),
            _mintFeeAmount: mintFeeAmount,
            _mintFeeRecipient: mintFeeRecipient
        });

        ZoraNFTCreatorV1 factoryImpl = new ZoraNFTCreatorV1(
            address(dropImplementation),
            editionMetadata,
            dropMetadata
        );

        console2.log("factoryimpl", address(factoryImpl));
        console2.log("factoryimpllen", address(factoryImpl).code.length);
        console2.log("dropimpl", address(dropImplementation));
        console2.log("dropimpllen", address(dropImplementation).code.length);

        // Sets owner as deployer - then the deployer address can transfer ownership
        ZoraNFTCreatorProxy factory = new ZoraNFTCreatorProxy(
            address(factoryImpl),
            abi.encodeWithSelector(ZoraNFTCreatorV1.initialize.selector)
        );

        ZoraNFTCreatorV1(address(factory)).transferOwnership(factoryUpgradeGateOwner);

        console2.log("Factory: ");
        console2.log(address(factory));

        vm.stopBroadcast();
    }
}
