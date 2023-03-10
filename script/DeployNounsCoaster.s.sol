// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {NounsCoasterMetadataRenderer} from "../src/metadata/NounsCoasterMetadataRenderer.sol";

contract DeployNounsCoaster is Script {
    using Strings for uint256;

    function run() public {
        console2.log("Starting ---");
        console2.log("~~~~~~~~~~ DEPLOYER ~~~~~~~~~~~");
        uint256 key = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(key);
        console2.log(deployerAddress);
        vm.startBroadcast();
        address token = vm.envAddress("TOKEN_ADDRESS");
        bytes memory initStrings = abi.encode(
            "https://nouns.wtf/api/coaster/",
            ".json",
            "Nouns Coaster",
            "Nouns Coaster",
            "https://nouns.wtf/api/coaster/contract.png",
            "https://nouns.wtf/api/coaster/"
        );
        address renderer = address(new NounsCoasterMetadataRenderer(initStrings, token, deployerAddress));
        console2.log("Deployed NounsCoasterMetadataRenderer at", renderer);
        console2.log("Configuring layers");
        
        console2.log("Done ---");
        vm.stopBroadcast();
    }
}
