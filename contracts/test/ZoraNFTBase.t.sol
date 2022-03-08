// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {Vm} from "forge-std/Vm.sol";
import {DSTest} from "ds-test/test.sol";
import {ZoraNFTBase} from "../ZoraNFTBase.sol";
import {ZoraDAOFeeManager} from "../ZoraDAOFeeManager.sol";
import {DummyMetadataRenderer} from "./utils/DummyMetadataRenderer.sol";
import {MockUser} from "./utils/MockUser.sol";

contract ZoraNFTBaseTest is DSTest {
    ZoraNFTBase zoraNFTBase;
    MockUser mockUser;
    Vm public constant vm = Vm(HEVM_ADDRESS);
    DummyMetadataRenderer public dummyRenderer = new DummyMetadataRenderer();
    address public constant DEFAULT_OWNER_ADDRESS = address(23499);
    address public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS = address(21303);
    address public constant mediaContract = address(123456);

    modifier setupZoraNFTBase() {
        zoraNFTBase.initialize({
            _name: "Test NFT",
            _symbol: "TNFT",
            _owner: DEFAULT_OWNER_ADDRESS,
            _fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
            _editionSize: 10,
            _royaltyBPS: 800,
            _metadataRenderer: dummyRenderer
        });
        _;
    }

    function setUp() public {
        ZoraDAOFeeManager feeManager = new ZoraDAOFeeManager(250);
        zoraNFTBase = new ZoraNFTBase(feeManager, address(1234));
    }

    function test_Init() public setupZoraNFTBase {
        // require(
        //     zoraNFTBase.owner() == DEFAULT_OWNER_ADDRESS,
        //     "Default owner set wrong"
        // );
        vm.expectRevert("Initializable: contract is already initialized");
        zoraNFTBase.initialize({
            _name: "Test NFT",
            _symbol: "TNFT",
            _owner: DEFAULT_OWNER_ADDRESS,
            _fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
            _editionSize: 10,
            _royaltyBPS: 800,
            _metadataRenderer: dummyRenderer
        });
    }

    function test_UpdateContractURI() public setupZoraNFTBase {
        require(
            bytes(zoraNFTBase.contractURI()).length == 0,
            "Contract URI set by default"
        );
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.updateContractURI(
            "https://data.zora.co/beautiful-contract/data.json"
        );
        assertEq(
            zoraNFTBase.contractURI(),
            "https://data.zora.co/beautiful-contract/data.json",
            "Contract URI set by default"
        );
        vm.prank(address(39));
        vm.expectRevert("Only admin allowed");
        zoraNFTBase.updateContractURI(
            "https://data.zora.co/beautiful-contract/data.json"
        );
    }
}
