// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IOperatorFilterRegistry} from "../src/interfaces/IOperatorFilterRegistry.sol";
import {OwnedSubscriptionManager} from "../src/filter/OwnedSubscriptionManager.sol";

contract DeployFeeRegistry is Script {
    using Strings for uint256;

    function setupFeeRegistry(address deployer)
        public
        returns (OwnedSubscriptionManager)
    {
        OwnedSubscriptionManager ownedSubscriptionManager = new OwnedSubscriptionManager(
                deployer
            );
        address[] memory blockedOperatorsList = new address[](6);
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
            0xF849de01B080aDC3A814FaBE1E2087475cF2E354
        );
        blockedOperatorsList[5] = address(
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
        OwnedSubscriptionManager ownedSubscriptionManager = setupFeeRegistry(
            subscriptionOwner
        );

        vm.stopBroadcast();

        console2.log(address(ownedSubscriptionManager));
    }
}
