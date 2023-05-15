// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {ERC721Drop} from "../src/ERC721Drop.sol";
import {ERC721DropProxy} from "../src/ERC721DropProxy.sol";
import {ZoraNFTCreatorV1} from "../src/ZoraNFTCreatorV1.sol";
import {IERC721Drop} from "../src/interfaces/IERC721Drop.sol";

import {ZoraNFTCreatorProxy} from "../src/ZoraNFTCreatorProxy.sol";
import {IOperatorFilterRegistry} from "../src/interfaces/IOperatorFilterRegistry.sol";
import {OwnedSubscriptionManager} from "../src/filter/OwnedSubscriptionManager.sol";
import {FactoryUpgradeGate} from "../src/FactoryUpgradeGate.sol";
import {DropMetadataRenderer} from "../src/metadata/DropMetadataRenderer.sol";
import {EditionMetadataRenderer} from "../src/metadata/EditionMetadataRenderer.sol";
import {IFactoryUpgradeGate} from "../src/interfaces/IFactoryUpgradeGate.sol";
import {IMetadataRenderer} from "../src/interfaces/IMetadataRenderer.sol";
import {ERC721DropProxy} from "../src/ERC721DropProxy.sol";
import {DropDeployment, ZoraDropsDeployBase} from "./ZoraDropsDeployBase.sol";

contract DeployNewERC721Drop is ZoraDropsDeployBase {
    function run() public {
        address oldContract = vm.envAddress("OLD_CONTRACT");

        DropDeployment memory deployment = getDeployment();

        console2.log("Starting ---");

        console2.log("Setup contracts ---");


        ERC721Drop oldDrop = ERC721Drop(payable(oldContract));

        address oldFactoryUpgradeGate = address(0xD3ef85b707Db8132C20249272dEC7e35d50a73A3);

        address oldImpl = address(uint160(uint256(vm.load(address(oldDrop), bytes32(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc)))));
        address[] memory prevImpls = new address[](1);
        prevImpls[0] = oldImpl;

        console2.log("old impl", oldImpl);
        console2.log("new impl", deployment.dropImplementation);
        console2.log("gate address", oldFactoryUpgradeGate);

        vm.prank(FactoryUpgradeGate(oldFactoryUpgradeGate).owner());
        FactoryUpgradeGate(oldFactoryUpgradeGate).registerNewUpgradePath(deployment.dropImplementation, prevImpls);

        vm.prank(oldDrop.owner());
        oldDrop.upgradeTo(deployment.dropImplementation);

        vm.startPrank(oldDrop.owner());
        oldDrop.adminMint(address(this), 1);
    }
}
