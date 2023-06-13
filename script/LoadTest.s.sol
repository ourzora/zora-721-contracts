// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {ERC721Drop} from "../src/ERC721Drop.sol";
import {ERC721DropProxy} from "../src/ERC721DropProxy.sol";
import {ZoraNFTCreatorV1} from "../src/ZoraNFTCreatorV1.sol";
import {IERC721Drop} from "../src/interfaces/IERC721Drop.sol";
import {IMetadataRenderer} from "../src/interfaces/IMetadataRenderer.sol";

import {ZoraDropsDeployBase, ChainConfig, DropDeployment} from "./ZoraDropsDeployBase.sol";

interface IOwner {
    function owner() external view returns (address);
}

contract Deploy is ZoraDropsDeployBase {
    uint256 constant _INNER_BATCH = 250;

    // total is 125k

    function min(uint256 a, uint256 b) internal returns (uint256) {
        return a < b ? a : b;
    }

    function run() public returns (string memory) {
        DropDeployment memory deployment = getDeployment();
        address payable sender = payable(vm.envAddress("sender"));

        vm.startBroadcast(sender);

        bytes[] memory setup = new bytes[](0);
        address result = ZoraNFTCreatorV1(deployment.factory).createAndConfigureDrop(
            "TEST",
            "TEST",
            sender,
            type(uint64).max,
            0,
            sender,
            setup,
            IMetadataRenderer(deployment.dropMetadata),
            abi.encode("asdf", "asdf")
        );

        IERC721Drop drop = IERC721Drop(result);

        address[] memory addresses = vm.parseJsonAddressArray(vm.readFile("./addresses/holders.json"), ".addresses");

        console2.log(addresses.length);

        uint256 added = 0;
        while (added < addresses.length) {
            uint256 toAdd = min(_INNER_BATCH, addresses.length - added);
            address[] memory mintAddressBatch = new address[](toAdd);

            for (uint256 i = 0; i < toAdd; i++) {
                mintAddressBatch[i] = addresses[i + added];
            }

            drop.adminMintAirdrop(mintAddressBatch);

            added += toAdd;
        }

        console2.log("Airdropped ", added);
    }
}
