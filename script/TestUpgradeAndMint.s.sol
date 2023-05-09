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
import {ERC721DropProxy} from "../src/ERC721DropProxy.sol";

contract DeployNewERC721Drop is Script {
    using Strings for uint256;

    string configFile;

    function _getKey(string memory key) internal returns (address result) {
        (result) = abi.decode(vm.parseJson(configFile, key), (address));
    }

    function run() public {
        uint256 chainID = vm.envUint("CHAIN_ID");
        address sender = vm.envAddress("SENDER");

        console.log("CHAIN_ID", chainID);
        console.log("SENDER", sender);

        console2.log("Starting ---");

        configFile = vm.readFile(
            string.concat("./addresses/", Strings.toString(chainID), ".json")
        );
        address creatorProxy = _getKey("ZORA_NFT_CREATOR_PROXY");

        address newImpl = _getKey("ERC721DROP_IMPL");

        console2.log("Setup contracts ---");

        vm.startPrank(sender);

        ZoraNFTCreatorV1 zoraNFTCreator = ZoraNFTCreatorV1(creatorProxy);
        ERC721Drop drop = ERC721Drop(payable(zoraNFTCreator.createEdition(
            "name",
            "symbol",
            100,
            500,
            payable(sender),
            payable(sender),
            IERC721Drop.SalesConfiguration({
                publicSaleStart: 0,
                publicSaleEnd: type(uint64).max,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0.1 ether,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0)
            }),
            "desc",
            "animation",
            "image"
        )));

        drop.adminMint(sender, 4);

        assert(drop.balanceOf(sender) == 4);

        vm.stopPrank();

        FactoryUpgradeGate gate = FactoryUpgradeGate(_getKey("FACTORY_UPGRADE_GATE"));
        address[] memory _supportedPrevImpls = new address[](1);
        _supportedPrevImpls[0] = zoraNFTCreator.implementation();
        vm.prank(gate.owner());
        gate.registerNewUpgradePath(newImpl, _supportedPrevImpls);

        vm.startPrank(sender);
        drop.upgradeTo(newImpl);

        drop.adminMint(sender, 4);
        assert(drop.balanceOf(sender) == 8);

        address recipient2 = address(0x9992);
        vm.deal(recipient2, 1 ether);
        vm.stopPrank();
        vm.prank(recipient2);
        drop.purchase{value: 0.1 ether + 0.000777 ether}(1);
        assert(drop.balanceOf(recipient2) == 1);

        vm.prank(zoraNFTCreator.owner());
        zoraNFTCreator.upgradeTo(_getKey("ZORA_NFT_CREATOR_V1_IMPL"));

        ERC721Drop drop2 = ERC721Drop(payable(zoraNFTCreator.createEdition(
            "name",
            "symbol",
            100,
            500,
            payable(sender),
            payable(sender),
            IERC721Drop.SalesConfiguration({
                publicSaleStart: 0,
                publicSaleEnd: type(uint64).max,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0.1 ether,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0)
            }),
            "desc",
            "animation",
            "image"
        )));
        assert(drop2.balanceOf(sender) == 0);


        address recipient3 = address(0x9992);
        vm.deal(recipient3, 1 ether);
        vm.stopPrank();
        vm.prank(recipient3);
        drop2.purchase{value: 0.1 ether + 0.000777 ether}(1);
        assert(drop2.balanceOf(recipient3) == 1);

        // Next steps:
        // 1. Setup upgrade path
        // 2. Upgrade creator to new contract
        // 3. Update addresses folder

    }
}
