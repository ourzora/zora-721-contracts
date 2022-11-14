// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {ERC721Drop} from "../src/ERC721Drop.sol";
import {ERC721DropProxy} from "../src/ERC721DropProxy.sol";
import {ZoraNFTCreatorV1} from "../src/ZoraNFTCreatorV1.sol";
import {ZoraNFTCreatorProxy} from "../src/ZoraNFTCreatorProxy.sol";
import {ZoraFeeManager} from "../src/ZoraFeeManager.sol";
import {OwnedSubscriptionManager} from "../src/filter/OwnedSubscriptionManager.sol";
import {DropMetadataRenderer} from "../src/metadata/DropMetadataRenderer.sol";
import {EditionMetadataRenderer} from "../src/metadata/EditionMetadataRenderer.sol";


contract DeployMetadataUpgrade is Script {
    using Strings for uint256;

    function run() public {
        uint256 chainID = vm.envUint("CHAIN_ID");
        console.log("CHAIN_ID", chainID);

        vm.startBroadcast();
        ZoraFeeManager feeManager = new ZoraFeeManager();
        DropMetadataRenderer dropMetadata = new DropMetadataRenderer();
        EditionMetadataRenderer editionMetadata = new EditionMetadataRenderer();
        // ERC721Drop dropImplementation = new ERC721Drop(
        //   IZoraFeeManager _zoraFeeManager,
        //   address _zoraERC721TransferHelper,
        //   IFactoryUpgradeGate _factoryUpgradeGate,
        //   address _marketFilterDAOAddress
        // );
        vm.stopBroadcast();

        string memory filePath = string(
            abi.encodePacked(
                "deploys/",
                chainID.toString(),
                ".upgradeMetadata.txt"
            )
        );
        vm.writeFile(filePath, "");
        vm.writeLine(
            filePath,
            string(
                abi.encodePacked(
                    "Metadata Renderer implementation: ",
                    Strings.toHexString(metadataRendererImpl)
                )
            )
        );
        vm.writeLine(
            filePath,
            string(
                abi.encodePacked(
                    "Manager implementation: ",
                    Strings.toHexString(managerImpl)
                )
            )
        );
    }
}
