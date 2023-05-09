// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console2.sol";

import {ZoraDropsDeployBase, ChainConfig} from "./ZoraDropsDeployBase.sol";
import {IOperatorFilterRegistry} from "../src/interfaces/IOperatorFilterRegistry.sol";
import {OwnedSubscriptionManager} from "../src/filter/OwnedSubscriptionManager.sol";

contract DeployFeeRegistry is ZoraDropsDeployBase {
    function setupFeeRegistry(address deployer) public returns (OwnedSubscriptionManager) {
        OwnedSubscriptionManager ownedSubscriptionManager = new OwnedSubscriptionManager(deployer);
        address[] memory blockedOperatorsList = new address[](0);
        IOperatorFilterRegistry operatorFilterRegistry = IOperatorFilterRegistry(0x000000000000AAeB6D7670E522A718067333cd4E);
        operatorFilterRegistry.updateOperators(address(ownedSubscriptionManager), blockedOperatorsList, true);
        return ownedSubscriptionManager;
    }

    function run() public {
        address subscriptionOwner = getChainConfig().subscriptionMarketFilterOwner;
        console2.log("Setup operators ---");

        vm.startBroadcast();

        // Add opensea contracts to test
        OwnedSubscriptionManager ownedSubscriptionManager = setupFeeRegistry(subscriptionOwner);

        vm.stopBroadcast();

        console2.log(address(ownedSubscriptionManager));
    }
}
