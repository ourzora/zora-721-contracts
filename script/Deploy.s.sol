// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {ERC721Drop} from "../src/ERC721Drop.sol";
import {ERC721DropProxy} from "../src/ERC721DropProxy.sol";
import {ZoraNFTCreatorV1} from "../src/ZoraNFTCreatorV1.sol";
import {ZoraNFTCreatorProxy} from "../src/ZoraNFTCreatorProxy.sol";
import {ZoraFeeManager} from "../src/ZoraFeeManager.sol";
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
        address managementOwner = vm.envAddress("MANAGAMENT_OWNER_ADDRESS");
        console2.log("Setup operators ---");

        console2.log("Setup contracts ---");
        ZoraFeeManager feeManager = new ZoraFeeManager(500, managementOwner);
        DropMetadataRenderer dropMetadata = new DropMetadataRenderer();
        EditionMetadataRenderer editionMetadata = new EditionMetadataRenderer();
        FactoryUpgradeGate factoryUpgradeGate = new FactoryUpgradeGate(
            managementOwner
        );

        ERC721Drop dropImplementation = new ERC721Drop({
            _zoraFeeManager: feeManager,
            _zoraERC721TransferHelper: address(0x0),
            _factoryUpgradeGate: factoryUpgradeGate,
            _marketFilterDAOAddress: address(daoFilterMarketAddress)
        });

        ZoraNFTCreatorV1 factoryImpl = new ZoraNFTCreatorV1(
            address(dropImplementation),
            editionMetadata,
            dropMetadata
        );

        // Sets owner as deployer - then the deployer address can transfer ownership
        ZoraNFTCreatorProxy factory = new ZoraNFTCreatorProxy(
            address(factoryImpl),
            abi.encodeWithSelector(ZoraNFTCreatorV1.initialize.selector)
        );

        console2.log("Factory: ");
        console2.log(address(factory));

        vm.stopBroadcast();

        string memory filePath = string(
            abi.encodePacked(
                "deploys/",
                chainID.toString(),
                ".upgradeMetadata.txt"
            )
        );
        // vm.writeFile(filePath, "");
        // vm.writeLine(
        //     filePath,
        //     string(
        //         abi.encodePacked(
        //             "Metadata Renderer implementation: ",
        //             Strings.toHexString(metadataRendererImpl)
        //         )
        //     )
        // );
        // vm.writeLine(
        //     filePath,
        //     string(
        //         abi.encodePacked(
        //             "Manager implementation: ",
        //             Strings.toHexString(managerImpl)
        //         )
        //     )
        // );
    }
}
