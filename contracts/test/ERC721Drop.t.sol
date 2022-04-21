// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {Vm} from "forge-std/Vm.sol";
import {DSTest} from "ds-test/test.sol";
import {ERC721Drop} from "../ERC721Drop.sol";
import {ZoraFeeManager} from "../ZoraFeeManager.sol";
import {DummyMetadataRenderer} from "./utils/DummyMetadataRenderer.sol";
import {MockUser} from "./utils/MockUser.sol";

contract ERC721DropTest is DSTest {
    ERC721Drop zoraNFTBase;
    MockUser mockUser;
    Vm public constant vm = Vm(HEVM_ADDRESS);
    DummyMetadataRenderer public dummyRenderer = new DummyMetadataRenderer();
    ZoraFeeManager public feeManager;
    address public constant DEFAULT_OWNER_ADDRESS = address(0x23499);
    address payable public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS =
        payable(address(0x21303));
    address payable public constant DEFAULT_ZORA_DAO_ADDRESS =
        payable(address(0x999));
    address public constant mediaContract = address(0x123456);

    modifier setupZoraNFTBase() {
        zoraNFTBase.initialize({
            _name: "Test NFT",
            _symbol: "TNFT",
            _owner: DEFAULT_OWNER_ADDRESS,
            _fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
            _editionSize: 10,
            _royaltyBPS: 800,
            _metadataRenderer: dummyRenderer,
            _metadataRendererInit: ''
        });

        _;
    }

    function setUp() public {
        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        feeManager = new ZoraFeeManager(250, DEFAULT_ZORA_DAO_ADDRESS);
        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        zoraNFTBase = new ERC721Drop(feeManager, address(1234));
    }

    function test_Init() public setupZoraNFTBase {
        require(
            zoraNFTBase.owner() == DEFAULT_OWNER_ADDRESS,
            "Default owner set wrong"
        );
        vm.expectRevert("Initializable: contract is already initialized");
        zoraNFTBase.initialize({
            _name: "Test NFT",
            _symbol: "TNFT",
            _owner: DEFAULT_OWNER_ADDRESS,
            _fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
            _editionSize: 10,
            _royaltyBPS: 800,
            _metadataRenderer: dummyRenderer,
            _metadataRendererInit: ''
        });
    }

    function test_Purchase() public setupZoraNFTBase {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration(ERC721Drop.SalesConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.1 ether,
            maxSalePurchasePerAddress: 2,
            presaleMerkleRoot: bytes32(0)
        }));
        vm.deal(address(456), 1 ether);
        vm.prank(address(456));
        zoraNFTBase.purchase{value: 0.1 ether}(1);
        assertEq(zoraNFTBase.saleDetails().maxSupply, 10);
        assertEq(zoraNFTBase.saleDetails().totalMinted, 1);
        require(
            zoraNFTBase.ownerOf(1) == address(456),
            "owner is wrong for new minted token"
        );
    }

    function test_PurchaseTime() public setupZoraNFTBase {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration(ERC721Drop.SalesConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: 0,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.1 ether,
            maxSalePurchasePerAddress: 2,
            presaleMerkleRoot: bytes32(0)
        }));

        assertTrue(!zoraNFTBase.saleDetails().publicSaleActive);

        vm.deal(address(456), 1 ether);
        vm.prank(address(456));
        vm.expectRevert("Sale inactive");
        zoraNFTBase.purchase{value: 0.1 ether}(1);

        assertEq(zoraNFTBase.saleDetails().maxSupply, 10);
        assertEq(zoraNFTBase.saleDetails().totalMinted, 0);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration(ERC721Drop.SalesConfiguration({
            publicSaleStart: 9 * 3600,
            publicSaleEnd: 11 * 3600,
            presaleStart: 0,
            presaleEnd: 0,
            
            maxSalePurchasePerAddress: 20,
            publicSalePrice: 0.1 ether,
            presaleMerkleRoot: bytes32(0)
        }));

        assertTrue(!zoraNFTBase.saleDetails().publicSaleActive);
        // jan 1st 1980
        vm.warp(10 * 3600);
        assertTrue(zoraNFTBase.saleDetails().publicSaleActive);
        assertTrue(!zoraNFTBase.saleDetails().presaleActive);

        vm.prank(address(456));
        zoraNFTBase.purchase{value: 0.1 ether}(1);

        assertEq(zoraNFTBase.saleDetails().totalMinted, 1);
        assertEq(zoraNFTBase.ownerOf(1), address(456));
    }

    function test_Mint() public setupZoraNFTBase {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.adminMint(DEFAULT_OWNER_ADDRESS, 1);
        assertEq(zoraNFTBase.saleDetails().maxSupply, 10);
        assertEq(zoraNFTBase.saleDetails().totalMinted, 1);
        require(
            zoraNFTBase.ownerOf(1) == DEFAULT_OWNER_ADDRESS,
            "Owner is wrong for new minted token"
        );
    }

    function test_MintWrongValue() public setupZoraNFTBase {
        vm.deal(address(456), 1 ether);
        vm.prank(address(456));
        vm.expectRevert("Sale inactive");
        zoraNFTBase.purchase{value: 0.12 ether}(1);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration(ERC721Drop.SalesConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.15 ether,
            maxSalePurchasePerAddress: 2,
            presaleMerkleRoot: bytes32(0)
        }));
        vm.prank(address(456));
        vm.expectRevert("Wrong price");
        zoraNFTBase.purchase{value: 0.12 ether}(1);
    }

    function test_Withdraw() public setupZoraNFTBase {
        vm.deal(address(zoraNFTBase), 1 ether);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.withdraw();
        (, uint256 feeBps) = feeManager.getZORAWithdrawFeesBPS(
            address(zoraNFTBase)
        );
        assertEq(feeBps, 250);
        assertEq(DEFAULT_ZORA_DAO_ADDRESS.balance, 0.025 ether);
        assertEq(DEFAULT_FUNDS_RECIPIENT_ADDRESS.balance, 0.975 ether);
    }

    function test_WithdrawNotAllowed() public setupZoraNFTBase {
        vm.expectRevert("Does not have proper role or admin");
        zoraNFTBase.withdraw();
    }

    function test_AdminMint() public setupZoraNFTBase {
        address minter = address(0x32402);
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.adminMint(DEFAULT_OWNER_ADDRESS, 1);
        require(
            zoraNFTBase.balanceOf(DEFAULT_OWNER_ADDRESS) == 1,
            "Wrong balance"
        );
        zoraNFTBase.grantRole(zoraNFTBase.MINTER_ROLE(), minter);
        vm.stopPrank();
        vm.prank(minter);
        zoraNFTBase.adminMint(minter, 1);
        require(zoraNFTBase.balanceOf(minter) == 1, "Wrong balance");
        assertEq(zoraNFTBase.saleDetails().totalMinted, 2);
    }

    // test Admin airdrop

    // test admin mint non-admin permissions

    // test admin airdrop non-admin permissions

    function test_Burn() public setupZoraNFTBase {
        address minter = address(0x32402);
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.grantRole(zoraNFTBase.MINTER_ROLE(), minter);
        vm.stopPrank();
        vm.startPrank(minter);
        address[] memory airdrop = new address[](1);
        airdrop[0] = minter;
        zoraNFTBase.adminMintAirdrop(airdrop);

        vm.stopPrank();
    }

    // Add test burn failure state for users that don't own the token

    function test_eip165() public {
        require(zoraNFTBase.supportsInterface(0x01ffc9a7), "supports 165");
        require(zoraNFTBase.supportsInterface(0x80ac58cd), "supports 721");
        require(
            zoraNFTBase.supportsInterface(0x5b5e139f),
            "supports 721-metdata"
        );
        require(zoraNFTBase.supportsInterface(0x2a55205a), "supports 2981");
        require(
            !zoraNFTBase.supportsInterface(0x0000000),
            "doesnt allow non-interface"
        );
    }
}
