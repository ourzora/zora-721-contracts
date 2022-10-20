// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {Vm} from "forge-std/Vm.sol";
import {DSTest} from "ds-test/test.sol";
import {IERC721AUpgradeable} from "erc721a-upgradeable/IERC721AUpgradeable.sol";

import {IERC721Drop} from "../src/interfaces/IERC721Drop.sol";
import {ERC721Drop} from "../src/ERC721Drop.sol";
import {DummyMetadataRenderer} from "./utils/DummyMetadataRenderer.sol";
import {MockUser} from "./utils/MockUser.sol";
import {IMetadataRenderer} from "../src/interfaces/IMetadataRenderer.sol";
import {FactoryUpgradeGate} from "../src/FactoryUpgradeGate.sol";
import {ERC721DropProxy} from "../src/ERC721DropProxy.sol";

contract ERC721DropTest is DSTest {
    /// @notice Event emitted when the funds are withdrawn from the minting contract
    /// @param withdrawnBy address that issued the withdraw
    /// @param withdrawnTo address that the funds were withdrawn to
    /// @param amount amount that was withdrawn
    event FundsWithdrawn(
        address indexed withdrawnBy,
        address indexed withdrawnTo,
        uint256 amount
    );

    ERC721Drop zoraNFTBase;
    MockUser mockUser;
    Vm public constant vm = Vm(HEVM_ADDRESS);
    DummyMetadataRenderer public dummyRenderer = new DummyMetadataRenderer();
    FactoryUpgradeGate public factoryUpgradeGate;
    address public constant DEFAULT_OWNER_ADDRESS = address(0x23499);
    address payable public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS =
        payable(address(0x21303));
    address payable public constant DEFAULT_ZORA_DAO_ADDRESS =
        payable(address(0x999));
    address public constant UPGRADE_GATE_ADMIN_ADDRESS = address(0x942924224);
    address public constant mediaContract = address(0x123456);
    address public impl;

    struct Configuration {
        IMetadataRenderer metadataRenderer;
        uint64 editionSize;
        uint16 royaltyBPS;
        address payable fundsRecipient;
    }

    modifier setupZoraNFTBase(uint64 editionSize) {
        zoraNFTBase.initialize({
            _contractName: "Test NFT",
            _contractSymbol: "TNFT",
            _initialOwner: DEFAULT_OWNER_ADDRESS,
            _fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
            _editionSize: editionSize,
            _royaltyBPS: 800,
            _metadataRenderer: dummyRenderer,
            _metadataRendererInit: "",
            _salesConfig: IERC721Drop.SalesConfiguration({
                publicSaleStart: 0,
                publicSaleEnd: 0,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0)
            })
        });

        _;
    }

    function setUp() public {
        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        factoryUpgradeGate = new FactoryUpgradeGate(UPGRADE_GATE_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        impl = address(new ERC721Drop(address(0x1234), factoryUpgradeGate));
        address payable newDrop = payable(
            address(new ERC721DropProxy(impl, ""))
        );
        zoraNFTBase = ERC721Drop(newDrop);
    }

    function test_Init() public setupZoraNFTBase(10) {
        require(
            zoraNFTBase.owner() == DEFAULT_OWNER_ADDRESS,
            "Default owner set wrong"
        );

        (
            IMetadataRenderer renderer,
            uint64 editionSize,
            uint16 royaltyBPS,
            address payable fundsRecipient
        ) = zoraNFTBase.config();

        require(address(renderer) == address(dummyRenderer));
        require(editionSize == 10, "EditionSize is wrong");
        require(royaltyBPS == 800, "RoyaltyBPS is wrong");
        require(
            fundsRecipient == payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
            "FundsRecipient is wrong"
        );

        string memory name = zoraNFTBase.name();
        string memory symbol = zoraNFTBase.symbol();
        require(keccak256(bytes(name)) == keccak256(bytes("Test NFT")));
        require(keccak256(bytes(symbol)) == keccak256(bytes("TNFT")));

        vm.expectRevert("Initializable: contract is already initialized");
        zoraNFTBase.initialize({
            _contractName: "Test NFT",
            _contractSymbol: "TNFT",
            _initialOwner: DEFAULT_OWNER_ADDRESS,
            _fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
            _editionSize: 10,
            _royaltyBPS: 800,
            _metadataRenderer: dummyRenderer,
            _metadataRendererInit: "",
            _salesConfig: IERC721Drop.SalesConfiguration({
                publicSaleStart: 0,
                publicSaleEnd: 0,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0)
            })
        });
    }

    function test_Purchase(uint64 amount) public setupZoraNFTBase(10) {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: amount,
            maxSalePurchasePerAddress: 2,
            presaleMerkleRoot: bytes32(0)
        });

        vm.deal(address(456), uint256(amount) * 2);
        vm.prank(address(456));
        zoraNFTBase.purchase{value: amount}(1);

        assertEq(zoraNFTBase.saleDetails().maxSupply, 10);
        assertEq(zoraNFTBase.saleDetails().totalMinted, 1);
        require(
            zoraNFTBase.ownerOf(1) == address(456),
            "owner is wrong for new minted token"
        );
        assertEq(address(zoraNFTBase).balance, amount);
    }

    function test_UpgradeApproved() public setupZoraNFTBase(10) {
        address newImpl = address(
            new ERC721Drop(address(0x3333), factoryUpgradeGate)
        );

        address[] memory lastImpls = new address[](1);
        lastImpls[0] = impl;
        vm.prank(UPGRADE_GATE_ADMIN_ADDRESS);
        factoryUpgradeGate.registerNewUpgradePath({
            _newImpl: newImpl,
            _supportedPrevImpls: lastImpls
        });
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.upgradeTo(newImpl);
    }

    function test_PurchaseTime() public setupZoraNFTBase(10) {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: 0,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.1 ether,
            maxSalePurchasePerAddress: 2,
            presaleMerkleRoot: bytes32(0)
        });

        assertTrue(!zoraNFTBase.saleDetails().publicSaleActive);

        vm.deal(address(456), 1 ether);
        vm.prank(address(456));
        vm.expectRevert(IERC721Drop.Sale_Inactive.selector);
        zoraNFTBase.purchase{value: 0.1 ether}(1);

        assertEq(zoraNFTBase.saleDetails().maxSupply, 10);
        assertEq(zoraNFTBase.saleDetails().totalMinted, 0);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 9 * 3600,
            publicSaleEnd: 11 * 3600,
            presaleStart: 0,
            presaleEnd: 0,
            maxSalePurchasePerAddress: 20,
            publicSalePrice: 0.1 ether,
            presaleMerkleRoot: bytes32(0)
        });

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

    function test_Mint() public setupZoraNFTBase(10) {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.adminMint(DEFAULT_OWNER_ADDRESS, 1);
        assertEq(zoraNFTBase.saleDetails().maxSupply, 10);
        assertEq(zoraNFTBase.saleDetails().totalMinted, 1);
        require(
            zoraNFTBase.ownerOf(1) == DEFAULT_OWNER_ADDRESS,
            "Owner is wrong for new minted token"
        );
    }

    function test_MintWrongValue() public setupZoraNFTBase(10) {
        vm.deal(address(456), 1 ether);
        vm.prank(address(456));
        vm.expectRevert(IERC721Drop.Sale_Inactive.selector);
        zoraNFTBase.purchase{value: 0.12 ether}(1);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.15 ether,
            maxSalePurchasePerAddress: 2,
            presaleMerkleRoot: bytes32(0)
        });
        vm.prank(address(456));
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Drop.Purchase_WrongPrice.selector,
                0.15 ether
            )
        );
        zoraNFTBase.purchase{value: 0.12 ether}(1);
    }

    function test_Withdraw(uint128 amount) public setupZoraNFTBase(10) {
        vm.assume(amount > 0.01 ether);
        vm.deal(address(zoraNFTBase), amount);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        vm.expectEmit(true, true, true, true);
        uint256 leftoverFunds = amount;
        emit FundsWithdrawn(
            DEFAULT_OWNER_ADDRESS,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            leftoverFunds
        );
        zoraNFTBase.withdraw();

        assertTrue(
            DEFAULT_ZORA_DAO_ADDRESS.balance <
                ((uint256(amount) * 1_000 * 5) / 100000) + 2 ||
                DEFAULT_ZORA_DAO_ADDRESS.balance >
                ((uint256(amount) * 1_000 * 5) / 100000) + 2
        );
        assertTrue(
            DEFAULT_FUNDS_RECIPIENT_ADDRESS.balance >
                ((uint256(amount) * 1_000 * 95) / 100000) - 2 ||
                DEFAULT_FUNDS_RECIPIENT_ADDRESS.balance <
                ((uint256(amount) * 1_000 * 95) / 100000) + 2
        );
    }

    function test_MintLimit(uint8 limit) public setupZoraNFTBase(5000) {
        // set limit to speed up tests
        vm.assume(limit > 0 && limit < 50);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.1 ether,
            maxSalePurchasePerAddress: limit,
            presaleMerkleRoot: bytes32(0)
        });
        vm.deal(address(456), 1_000_000 ether);
        vm.prank(address(456));
        zoraNFTBase.purchase{value: 0.1 ether * uint256(limit)}(limit);

        assertEq(zoraNFTBase.saleDetails().totalMinted, limit);

        vm.deal(address(444), 1_000_000 ether);
        vm.prank(address(444));
        vm.expectRevert(IERC721Drop.Purchase_TooManyForAddress.selector);
        zoraNFTBase.purchase{value: 0.1 ether * (uint256(limit) + 1)}(
            uint256(limit) + 1
        );

        assertEq(zoraNFTBase.saleDetails().totalMinted, limit);
    }

    function testSetSalesConfiguration() public setupZoraNFTBase(10) {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 100,
            publicSalePrice: 0.1 ether,
            maxSalePurchasePerAddress: 10,
            presaleMerkleRoot: bytes32(0)
        });

        (, , , , , uint64 presaleEndLookup, ) = zoraNFTBase.salesConfig();
        assertEq(presaleEndLookup, 100);

        address SALES_MANAGER_ADDR = address(0x11002);
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.grantRole(
            zoraNFTBase.SALES_MANAGER_ROLE(),
            SALES_MANAGER_ADDR
        );
        vm.stopPrank();
        vm.prank(SALES_MANAGER_ADDR);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 100,
            presaleEnd: 0,
            publicSalePrice: 0.1 ether,
            maxSalePurchasePerAddress: 1003,
            presaleMerkleRoot: bytes32(0)
        });

        (
            ,
            ,
            ,
            ,
            uint64 presaleStartLookup2,
            uint64 presaleEndLookup2,

        ) = zoraNFTBase.salesConfig();
        assertEq(presaleEndLookup2, 0);
        assertEq(presaleStartLookup2, 100);
    }

    function test_GlobalLimit(uint16 limit)
        public
        setupZoraNFTBase(uint64(limit))
    {
        vm.assume(limit > 0);
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.adminMint(DEFAULT_OWNER_ADDRESS, limit);
        vm.expectRevert(IERC721Drop.Mint_SoldOut.selector);
        zoraNFTBase.adminMint(DEFAULT_OWNER_ADDRESS, 1);
    }

    function test_WithdrawNotAllowed() public setupZoraNFTBase(10) {
        vm.expectRevert(IERC721Drop.Access_WithdrawNotAllowed.selector);
        zoraNFTBase.withdraw();
    }

    function test_InvalidFinalizeOpenEdition() public setupZoraNFTBase(5) {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.2 ether,
            presaleMerkleRoot: bytes32(0),
            maxSalePurchasePerAddress: 5
        });
        zoraNFTBase.purchase{value: 0.6 ether}(3);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.adminMint(address(0x1234), 2);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        vm.expectRevert(
            IERC721Drop.Admin_UnableToFinalizeNotOpenEdition.selector
        );
        zoraNFTBase.finalizeOpenEdition();
    }

    function test_ValidFinalizeOpenEdition()
        public
        setupZoraNFTBase(type(uint64).max)
    {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.2 ether,
            presaleMerkleRoot: bytes32(0),
            maxSalePurchasePerAddress: 10
        });
        zoraNFTBase.purchase{value: 0.6 ether}(3);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.adminMint(address(0x1234), 2);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.finalizeOpenEdition();
        vm.expectRevert(IERC721Drop.Mint_SoldOut.selector);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.adminMint(address(0x1234), 2);
        vm.expectRevert(IERC721Drop.Mint_SoldOut.selector);
        zoraNFTBase.purchase{value: 0.6 ether}(3);
    }

    function test_AdminMint() public setupZoraNFTBase(10) {
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

    function test_EditionSizeZero() public setupZoraNFTBase(0) {
        address minter = address(0x32402);
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        vm.expectRevert(IERC721Drop.Mint_SoldOut.selector);
        zoraNFTBase.adminMint(DEFAULT_OWNER_ADDRESS, 1);
        zoraNFTBase.grantRole(zoraNFTBase.MINTER_ROLE(), minter);
        vm.stopPrank();
        vm.prank(minter);
        vm.expectRevert(IERC721Drop.Mint_SoldOut.selector);
        zoraNFTBase.adminMint(minter, 1);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 1,
            maxSalePurchasePerAddress: 2,
            presaleMerkleRoot: bytes32(0)
        });

        vm.deal(address(456), uint256(1) * 2);
        vm.prank(address(456));
        vm.expectRevert(IERC721Drop.Mint_SoldOut.selector);
        zoraNFTBase.purchase{value: 1}(1);
    }

    // test Admin airdrop
    function test_AdminMintAirdrop() public setupZoraNFTBase(1000) {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        address[] memory toMint = new address[](4);
        toMint[0] = address(0x10);
        toMint[1] = address(0x11);
        toMint[2] = address(0x12);
        toMint[3] = address(0x13);
        zoraNFTBase.adminMintAirdrop(toMint);
        assertEq(zoraNFTBase.saleDetails().totalMinted, 4);
        assertEq(zoraNFTBase.balanceOf(address(0x10)), 1);
        assertEq(zoraNFTBase.balanceOf(address(0x11)), 1);
        assertEq(zoraNFTBase.balanceOf(address(0x12)), 1);
        assertEq(zoraNFTBase.balanceOf(address(0x13)), 1);
    }

    function test_AdminMintAirdropFails() public setupZoraNFTBase(1000) {
        vm.startPrank(address(0x10));
        address[] memory toMint = new address[](4);
        toMint[0] = address(0x10);
        toMint[1] = address(0x11);
        toMint[2] = address(0x12);
        toMint[3] = address(0x13);
        bytes32 minterRole = zoraNFTBase.MINTER_ROLE();
        vm.expectRevert(
            abi.encodeWithSignature(
                "Access_MissingRoleOrAdmin(bytes32)",
                minterRole
            )
        );
        zoraNFTBase.adminMintAirdrop(toMint);
    }

    // test admin mint non-admin permissions
    function test_AdminMintBatch() public setupZoraNFTBase(1000) {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.adminMint(DEFAULT_OWNER_ADDRESS, 100);
        assertEq(zoraNFTBase.saleDetails().totalMinted, 100);
        assertEq(zoraNFTBase.balanceOf(DEFAULT_OWNER_ADDRESS), 100);
    }

    function test_AdminMintBatchFails() public setupZoraNFTBase(1000) {
        vm.startPrank(address(0x10));
        bytes32 role = zoraNFTBase.MINTER_ROLE();
        vm.expectRevert(
            abi.encodeWithSignature("Access_MissingRoleOrAdmin(bytes32)", role)
        );
        zoraNFTBase.adminMint(address(0x10), 100);
    }

    function test_Burn() public setupZoraNFTBase(10) {
        address minter = address(0x32402);
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.grantRole(zoraNFTBase.MINTER_ROLE(), minter);
        vm.stopPrank();
        vm.startPrank(minter);
        address[] memory airdrop = new address[](1);
        airdrop[0] = minter;
        zoraNFTBase.adminMintAirdrop(airdrop);
        zoraNFTBase.burn(1);
        vm.stopPrank();
    }

    function test_BurnNonOwner() public setupZoraNFTBase(10) {
        address minter = address(0x32402);
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.grantRole(zoraNFTBase.MINTER_ROLE(), minter);
        vm.stopPrank();
        vm.startPrank(minter);
        address[] memory airdrop = new address[](1);
        airdrop[0] = minter;
        zoraNFTBase.adminMintAirdrop(airdrop);
        vm.stopPrank();

        vm.prank(address(1));
        vm.expectRevert(
            IERC721AUpgradeable.TransferCallerNotOwnerNorApproved.selector
        );
        zoraNFTBase.burn(1);
    }

    // Add test burn failure state for users that don't own the token

    function test_EIP165() public view {
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
