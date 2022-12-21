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
import {IZoraFeeManager} from "../src/interfaces/IZoraFeeManager.sol";
import {IFactoryUpgradeGate} from "../src/interfaces/IFactoryUpgradeGate.sol";

contract DeployNewERC721Drop is Script {
    using Strings for uint256;

    string configFile;

    function _getKey(string memory key) internal returns (address result) {
        (result) = abi.decode(vm.parseJson(configFile, key), (address));
    }

    function run() public {
        uint256 chainID = vm.envUint("CHAIN_ID");
        console.log("CHAIN_ID", chainID);

        console2.log("Starting ---");

        configFile = vm.readFile(
            string.concat("./addresses/", Strings.toString(chainID), ".json")
        );
        address zoraFeeManager = _getKey("ZORA_FEE_MANAGER");
        address zoraERC721TransferHelper = _getKey(
            "ZORA_ERC721_TRANSFER_HELPER"
        );
        address factoryUpgradeGate = _getKey("FACTORY_UPGRADE_GATE");
        address ownedSubscriptionManager = _getKey(
            "OWNED_SUBSCRIPTION_MANAGER"
        );

        address editionMetadataRenderer = _getKey("EDITION_METADATA_RENDERER");
        address dropMetadataRenderer = _getKey("DROP_METADATA_RENDERER");

        vm.startBroadcast();

        console2.log("Setup contracts ---");

        ERC721Drop dropImplementation = new ERC721Drop({
            _zoraFeeManager: IZoraFeeManager(zoraFeeManager),
            _zoraERC721TransferHelper: zoraERC721TransferHelper,
            _factoryUpgradeGate: IFactoryUpgradeGate(factoryUpgradeGate),
            _marketFilterDAOAddress: ownedSubscriptionManager
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

        vm.stopBroadcast();
    }
}
