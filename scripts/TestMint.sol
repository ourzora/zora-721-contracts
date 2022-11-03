// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {ZoraNFTCreatorV1} from "../src/ZoraNFTCreatorV1.sol";
import {IERC721Drop} from "../src/interfaces/IERC721Drop.sol";
import {ERC721Drop} from "../src/ERC721Drop.sol";

contract SetupDaoScript is Script {
    ZoraNFTCreatorV1 creator;
    address newImpl;
    address sender;

    function setUp() public {
        creator = ZoraNFTCreatorV1(vm.envAddress("ZORA_CREATOR"));
        newImpl = address(vm.envAddress("NEW_IMPL"));
        sender = address(vm.envAddress("SENDER"));
    }

    function run() public {
        testMint();
        vm.prank(creator.owner());
        creator.upgradeTo(newImpl);
        testMint();
    }

    function testMint() public {
        vm.startPrank(sender);

        address payable self = payable(sender);

        IERC721Drop.SalesConfiguration memory salesConfiguration = IERC721Drop
            .SalesConfiguration({
                publicSalePrice: 0.001 ether,
                maxSalePurchasePerAddress: 1000,
                publicSaleStart: 0,
                publicSaleEnd: type(uint64).max,
                presaleStart: 0,
                presaleEnd: 0,
                presaleMerkleRoot: 0x0000000000000000000000000000000000000000000000000000000000000000
            });

        // setup edition
        address newEdition = creator.createEdition(
            "TESTING",
            "TST",
            10,
            1000,
            self,
            self,
            salesConfiguration,
            "DESCRIPTION",
            "ipfs://animation",
            "ipfs://image"
        );

        vm.deal(self, 1 ether);
        ERC721Drop editionContract = ERC721Drop(payable(newEdition));
        ERC721Drop(editionContract).purchase{value: 0.01 ether}(10);

        console2.log(editionContract.tokenURI(1));
        console2.log(editionContract.contractURI());

        // setup drop
        address newDrop = creator.createDrop(
            "TSTDROP",
            "DRP",
            self,
            10,
            1000,
            self,
            salesConfiguration,
            "https://zora.co/metadata/",
            "https://zora.co/metadata/contract.json"
        );

        ERC721Drop dropContract = ERC721Drop(payable(newDrop));
        ERC721Drop(dropContract).purchase{value: 0.01 ether}(10);

        console2.log(dropContract.tokenURI(1));
        console2.log(dropContract.contractURI());

        // vm.stopBroadcast();
        vm.stopPrank();
    }
}
