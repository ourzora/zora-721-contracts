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

    function setupBlockedOperators(address subscriptionOwner)
        public
        returns (OwnedSubscriptionManager)
    {
        OwnedSubscriptionManager ownedSubscriptionManager = new OwnedSubscriptionManager(
                subscriptionOwner
            );
        address[] memory blockedOperatorsList = new address[](7);
        blockedOperatorsList[0] = address(
            0xf42aa99F011A1fA7CDA90E5E98b277E306BcA83e
        );
        blockedOperatorsList[1] = address(
            0x024aC22ACdB367a3ae52A3D94aC6649fdc1f0779
        );
        blockedOperatorsList[2] = address(
            0xFED24eC7E22f573c2e08AEF55aA6797Ca2b3A051
        );
        blockedOperatorsList[3] = address(
            0x00000000000111AbE46ff893f3B2fdF1F759a8A8
        );
        blockedOperatorsList[4] = address(
            0x59728544B08AB483533076417FbBB2fD0B17CE3a
        );
        blockedOperatorsList[5] = address(
            0xF849de01B080aDC3A814FaBE1E2087475cF2E354
        );
        blockedOperatorsList[6] = address(
            0x2B2e8cDA09bBA9660dCA5cB6233787738Ad68329
        );

        IOperatorFilterRegistry operatorFilterRegistry = IOperatorFilterRegistry(
                0x000000000000AAeB6D7670E522A718067333cd4E
            );
        operatorFilterRegistry.updateOperators(
            address(ownedSubscriptionManager),
            blockedOperatorsList,
            true
        );
        return ownedSubscriptionManager;
    }

    function run() public {
        uint256 chainID = vm.envUint("CHAIN_ID");
        console.log("CHAIN_ID", chainID);

        console2.log("Starting ---");

        vm.startBroadcast();
        address subscriptionOwner = vm.envAddress("SUBSCRIPTION_OWNER");
        console2.log("Setup operators ---");
        // Add opensea contracts to test
        OwnedSubscriptionManager ownedSubscriptionManager = setupBlockedOperators(
            subscriptionOwner
        );

        console2.log("Setup contracts ---");
        ZoraFeeManager feeManager = new ZoraFeeManager(500, subscriptionOwner);
        DropMetadataRenderer dropMetadata = new DropMetadataRenderer();
        EditionMetadataRenderer editionMetadata = new EditionMetadataRenderer();
        FactoryUpgradeGate factoryUpgradeGate = new FactoryUpgradeGate(
            subscriptionOwner
        );

        ERC721Drop dropImplementation = new ERC721Drop({
            _zoraFeeManager: feeManager,
            _zoraERC721TransferHelper: address(0x0),
            _factoryUpgradeGate: factoryUpgradeGate,
            _marketFilterDAOAddress: address(ownedSubscriptionManager)
        });

        ZoraNFTCreatorV1 factoryImpl = new ZoraNFTCreatorV1(
            address(dropImplementation),
            editionMetadata,
            dropMetadata
        );

        ZoraNFTCreatorProxy factory = new ZoraNFTCreatorProxy(address(factoryImpl), "");

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
