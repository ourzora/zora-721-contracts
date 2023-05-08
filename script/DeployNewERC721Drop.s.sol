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
import {IZoraFeeManager} from "../src/interfaces/IZoraFeeManager.sol";
import {IFactoryUpgradeGate} from "../src/interfaces/IFactoryUpgradeGate.sol";
import {ERC721DropProxy} from "../src/ERC721DropProxy.sol";

contract DeployNewERC721Drop is Script {
    using Strings for uint256;
    using stdJson for string;

    string configFile;

    function run() public {
        uint256 chainID = vm.envUint("CHAIN_ID");
        console.log("CHAIN_ID", chainID);

        console2.log("Starting ---");

        configFile = vm.readFile(
            string.concat("./addresses/", Strings.toString(chainID), ".json")
        );
        address zoraERC721TransferHelper = configFile.readAddress(".ZORA_ERC721_TRANSFER_HELPER");
        address factoryUpgradeGate = configFile.readAddress(".FACTORY_UPGRADE_GATE");
        address ownedSubscriptionManager = configFile.readAddress(".OWNED_SUBSCRIPTION_MANAGER");
        console2.log("OWNED_SUB_MANAGER");
        console2.log(ownedSubscriptionManager);
        console2.log("FACTORY_UPGRADE_GATE", factoryUpgradeGate);

        address editionMetadataRenderer = configFile.readAddress(".EDITION_METADATA_RENDERER");
        address dropMetadataRenderer = configFile.readAddress(".DROP_METADATA_RENDERER");

        console2.log("EDITION_METADATA_RENDERER", editionMetadataRenderer);
        console2.log("DROP_METADATA_RENDERER", dropMetadataRenderer);

        uint256 mintFeeAmount = vm.parseJsonUint(configFile, ".MINT_FEE_AMOUNT");

        address payable mintFeeRecipient = payable(
            configFile.readAddress(".MINT_FEE_RECIPIENT")
        );

        console2.log("MINT_FEE_RECIPIENT", mintFeeRecipient);
        console2.log("MINT_FEE_AMOUNT", mintFeeAmount);

        vm.startBroadcast();

        console2.log("Setup contracts ---");

        ERC721Drop dropImplementation = new ERC721Drop({
            _zoraERC721TransferHelper: zoraERC721TransferHelper,
            _factoryUpgradeGate: IFactoryUpgradeGate(factoryUpgradeGate),
            _marketFilterDAOAddress: ownedSubscriptionManager,
            _mintFeeAmount: mintFeeAmount,
            _mintFeeRecipient: mintFeeRecipient
        });

        console2.log("Drop IMPL: ");
        console2.log(address(dropImplementation));

        ZoraNFTCreatorV1 zoraNFTCreator = new ZoraNFTCreatorV1({
            _implementation: address(dropImplementation),
            _editionMetadataRenderer: EditionMetadataRenderer(
                editionMetadataRenderer
            ),
            _dropMetadataRenderer: DropMetadataRenderer(dropMetadataRenderer)
        });

        console2.log("Factory/Creator IMPL: ");
        console2.log(address(zoraNFTCreator));

        // Next steps:
        // 1. Setup upgrade path
        // 2. Upgrade creator to new contract
        // 3. Update addresses folder

        vm.stopBroadcast();
    }
}
