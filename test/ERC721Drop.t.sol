// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {IERC721AUpgradeable} from "erc721a-upgradeable/IERC721AUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ProtocolRewards} from "@zoralabs/protocol-rewards/src/ProtocolRewards.sol";
import {RewardsSettings} from "@zoralabs/protocol-rewards/src/abstract/RewardSplits.sol";

import {ERC721Drop} from "../src/ERC721Drop.sol";
import {DummyMetadataRenderer} from "./utils/DummyMetadataRenderer.sol";
import {MockUser} from "./utils/MockUser.sol";
import {IOperatorFilterRegistry} from "../src/interfaces/IOperatorFilterRegistry.sol";
import {IMetadataRenderer} from "../src/interfaces/IMetadataRenderer.sol";
import {IERC721Drop} from "../src/interfaces/IERC721Drop.sol";
import {FactoryUpgradeGate} from "../src/FactoryUpgradeGate.sol";
import {ERC721DropProxy} from "../src/ERC721DropProxy.sol";
import {OperatorFilterRegistry} from "./filter/OperatorFilterRegistry.sol";
import {OperatorFilterRegistryErrorsAndEvents} from "./filter/OperatorFilterRegistryErrorsAndEvents.sol";
import {OwnedSubscriptionManager} from "../src/filter/OwnedSubscriptionManager.sol";

contract ERC721DropTest is Test {
    /// @notice Event emitted when the funds are withdrawn from the minting contract
    /// @param withdrawnBy address that issued the withdraw
    /// @param withdrawnTo address that the funds were withdrawn to
    /// @param amount amount that was withdrawn
    /// @param feeRecipient user getting withdraw fee (if any)
    /// @param feeAmount amount of the fee getting sent (if any)
    event FundsWithdrawn(
        address indexed withdrawnBy,
        address indexed withdrawnTo,
        uint256 amount,
        address feeRecipient,
        uint256 feeAmount
    );

    event Sale(
        address indexed to, uint256 indexed purchaseQuantity, uint256 indexed pricePerToken, uint256 firstPurchasedTokenId
    );

    event MintComment(
        address indexed sender, address indexed tokenContract, uint256 indexed tokenId, uint256 purchaseQuantity, string comment
    );

    address internal creator;
    address internal collector;
    address internal mintReferral;
    address internal createReferral;
    address internal zora;

    ProtocolRewards protocolRewards;
    ERC721Drop zoraNFTBase;
    MockUser mockUser;
    DummyMetadataRenderer public dummyRenderer = new DummyMetadataRenderer();
    FactoryUpgradeGate public factoryUpgradeGate;
    address public constant DEFAULT_OWNER_ADDRESS = address(0x23499);
    address payable public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS = payable(address(0x21303));
    address payable public constant DEFAULT_ZORA_DAO_ADDRESS = payable(address(0x999));
    address public constant UPGRADE_GATE_ADMIN_ADDRESS = address(0x942924224);
    address public constant mediaContract = address(0x123456);
    address public impl;
    address public ownedSubscriptionManager;
    address payable public constant mintFeeRecipient = payable(address(0x11));
    uint256 public constant mintFee = 777000000000000; // 0.000777 ETH
    uint256 public constant TOTAL_REWARD_PER_MINT = 0.000999 ether;
    address internal constant DEFAULT_CREATE_REFERRAL = address(0);

    struct Configuration {
        IMetadataRenderer metadataRenderer;
        uint64 editionSize;
        uint16 royaltyBPS;
        address payable fundsRecipient;
    }

    modifier setupZoraNFTBase(uint64 editionSize) {
        bytes[] memory setupCalls = new bytes[](0);
        zoraNFTBase.initialize({
            _contractName: "Test NFT",
            _contractSymbol: "TNFT",
            _initialOwner: DEFAULT_OWNER_ADDRESS,
            _fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
            _editionSize: editionSize,
            _royaltyBPS: 800,
            _setupCalls: setupCalls,
            _metadataRenderer: dummyRenderer,
            _metadataRendererInit: "",
            _createReferral: DEFAULT_CREATE_REFERRAL
        });

        _;
    }

    modifier setupZoraNFTBaseWithCreateReferral(uint64 editionSize, address initCreateReferral) {
        bytes[] memory setupCalls = new bytes[](0);
        zoraNFTBase.initialize({
            _contractName: "Test NFT",
            _contractSymbol: "TNFT",
            _initialOwner: DEFAULT_OWNER_ADDRESS,
            _fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
            _editionSize: editionSize,
            _royaltyBPS: 800,
            _setupCalls: setupCalls,
            _metadataRenderer: dummyRenderer,
            _metadataRendererInit: "",
            _createReferral: initCreateReferral
        });

        _;
    }

    function setUp() public {
        creator = makeAddr("creator");
        collector = makeAddr("collector");
        mintReferral = makeAddr("mintReferral");
        createReferral = makeAddr("createReferral");
        zora = makeAddr("zora");

        protocolRewards = new ProtocolRewards();

        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        factoryUpgradeGate = new FactoryUpgradeGate(UPGRADE_GATE_ADMIN_ADDRESS);
        vm.etch(address(0x000000000000AAeB6D7670E522A718067333cd4E), address(new OperatorFilterRegistry()).code);
        ownedSubscriptionManager = address(new OwnedSubscriptionManager(address(0x123456)));

        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        impl = address(
            new ERC721Drop(
                address(0x1234),
                factoryUpgradeGate,
                address(0x0),
                mintFee,
                mintFeeRecipient,
                address(protocolRewards)
            )
        );
        address payable newDrop = payable(address(new ERC721DropProxy(impl, "")));
        zoraNFTBase = ERC721Drop(newDrop);
    }

    modifier factoryWithSubscriptionAddress(address subscriptionAddress) {
        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        impl = address(
            new ERC721Drop(
                address(0x1234),
                factoryUpgradeGate,
                address(subscriptionAddress),
                mintFee,
                mintFeeRecipient,
                address(protocolRewards)
            )
        );
        address payable newDrop = payable(address(new ERC721DropProxy(impl, "")));
        zoraNFTBase = ERC721Drop(newDrop);

        _;
    }

    function test_Init() public setupZoraNFTBase(10) {
        require(zoraNFTBase.owner() == DEFAULT_OWNER_ADDRESS, "Default owner set wrong");

        (IMetadataRenderer renderer, uint64 editionSize, uint16 royaltyBPS, address payable fundsRecipient) =
            zoraNFTBase.config();

        require(address(renderer) == address(dummyRenderer));
        require(editionSize == 10, "EditionSize is wrong");
        require(royaltyBPS == 800, "RoyaltyBPS is wrong");
        require(fundsRecipient == payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS), "FundsRecipient is wrong");

        string memory name = zoraNFTBase.name();
        string memory symbol = zoraNFTBase.symbol();
        require(keccak256(bytes(name)) == keccak256(bytes("Test NFT")));
        require(keccak256(bytes(symbol)) == keccak256(bytes("TNFT")));

        vm.expectRevert("Initializable: contract is already initialized");
        bytes[] memory setupCalls = new bytes[](0);
        zoraNFTBase.initialize({
            _contractName: "Test NFT",
            _contractSymbol: "TNFT",
            _initialOwner: DEFAULT_OWNER_ADDRESS,
            _fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
            _editionSize: 10,
            _royaltyBPS: 800,
            _setupCalls: setupCalls,
            _metadataRenderer: dummyRenderer,
            _metadataRendererInit: "",
            _createReferral: DEFAULT_CREATE_REFERRAL
        });
    }

    // Uncomment when this bug is fixed.
    //
    // function test_InitFailsTooHighRoyalty() public {
    //     bytes[] memory setupCalls = new bytes[](0);
    //     vm.expectRevert(abi.encodeWithSelector(IERC721Drop.Setup_RoyaltyPercentageTooHigh.selector, 8000));
    //     zoraNFTBase.initialize({
    //         _contractName: "Test NFT",
    //         _contractSymbol: "TNFT",
    //         _initialOwner: DEFAULT_OWNER_ADDRESS,
    //         _fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
    //         _editionSize: 10,
    //         // 80% royalty is above 50% max.
    //         _royaltyBPS: 8000,
    //         _setupCalls: setupCalls,
    //         _metadataRenderer: dummyRenderer,
    //         _metadataRendererInit: ""
    //     });
    // }

    function test_IsAdminGetter() public setupZoraNFTBase(1) {
        assertTrue(zoraNFTBase.isAdmin(DEFAULT_OWNER_ADDRESS));
        assertTrue(!zoraNFTBase.isAdmin(address(0x999)));
        assertTrue(!zoraNFTBase.isAdmin(address(0)));
    }

    function test_SubscriptionEnabled()
        public
        factoryWithSubscriptionAddress(ownedSubscriptionManager)
        setupZoraNFTBase(10)
    {
        IOperatorFilterRegistry operatorFilterRegistry =
            IOperatorFilterRegistry(0x000000000000AAeB6D7670E522A718067333cd4E);
        vm.startPrank(address(0x123456));
        operatorFilterRegistry.updateOperator(ownedSubscriptionManager, address(0xcafeea3), true);
        vm.stopPrank();
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.manageMarketFilterDAOSubscription(true);
        zoraNFTBase.adminMint(DEFAULT_OWNER_ADDRESS, 10);
        zoraNFTBase.setApprovalForAll(address(0xcafeea3), true);
        vm.stopPrank();
        vm.prank(address(0xcafeea3));
        vm.expectRevert(
            abi.encodeWithSelector(OperatorFilterRegistryErrorsAndEvents.AddressFiltered.selector, address(0xcafeea3))
        );
        zoraNFTBase.transferFrom(DEFAULT_OWNER_ADDRESS, address(0x123456), 1);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.manageMarketFilterDAOSubscription(false);
        vm.prank(address(0xcafeea3));
        zoraNFTBase.transferFrom(DEFAULT_OWNER_ADDRESS, address(0x123456), 1);
    }

    function test_OnlyAdminEnableSubscription()
        public
        factoryWithSubscriptionAddress(ownedSubscriptionManager)
        setupZoraNFTBase(10)
    {
        vm.startPrank(address(0xcafecafe));
        vm.expectRevert(IERC721Drop.Access_OnlyAdmin.selector);
        zoraNFTBase.manageMarketFilterDAOSubscription(true);
        vm.stopPrank();
    }

    function test_ProxySubscriptionAccessOnlyAdmin()
        public
        factoryWithSubscriptionAddress(ownedSubscriptionManager)
        setupZoraNFTBase(10)
    {
        bytes memory baseCall = abi.encodeWithSelector(IOperatorFilterRegistry.register.selector, address(zoraNFTBase));
        vm.startPrank(address(0xcafecafe));
        vm.expectRevert(IERC721Drop.Access_OnlyAdmin.selector);
        zoraNFTBase.updateMarketFilterSettings(baseCall);
        vm.stopPrank();
    }

    function test_ProxySubscriptionAccess()
        public
        factoryWithSubscriptionAddress(ownedSubscriptionManager)
        setupZoraNFTBase(10)
    {
        vm.startPrank(address(DEFAULT_OWNER_ADDRESS));
        bytes memory baseCall = abi.encodeWithSelector(IOperatorFilterRegistry.register.selector, address(zoraNFTBase));
        zoraNFTBase.updateMarketFilterSettings(baseCall);
        vm.stopPrank();
    }

    function test_RoyaltyInfo() public setupZoraNFTBase(10) {
        // assert 800 royaltyAmount or 8%
        ( , uint256 royaltyAmount) = zoraNFTBase.royaltyInfo(10, 1 ether);
        assertEq(royaltyAmount, 0.08 ether);
    }

    function test_NoRoyaltyInfoNoFundsRecipientAddress() public setupZoraNFTBase(10) {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setFundsRecipient(payable(address(0)));
        // assert 800 royaltyAmount or 8%
        ( , uint256 royaltyAmount) = zoraNFTBase.royaltyInfo(10, 1 ether);
        assertEq(royaltyAmount, 0 ether);
    }

    function test_Purchase(uint64 salePrice, uint32 purchaseQuantity) public setupZoraNFTBase(purchaseQuantity) {
        vm.assume(purchaseQuantity < 100 && purchaseQuantity > 0);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: salePrice,
            maxSalePurchasePerAddress: purchaseQuantity + 1,
            presaleMerkleRoot: bytes32(0)
        });

        (, uint256 zoraFee) = zoraNFTBase.zoraFeeForAmount(purchaseQuantity);
        uint256 paymentAmount = uint256(salePrice) * purchaseQuantity + zoraFee;
        vm.deal(address(456), paymentAmount);
        vm.prank(address(456));
        vm.expectEmit(true, true, true, true);
        emit Sale(address(456), purchaseQuantity, salePrice, 0);
        zoraNFTBase.purchase{value: paymentAmount}(purchaseQuantity);

        assertEq(zoraNFTBase.saleDetails().maxSupply, purchaseQuantity);
        assertEq(zoraNFTBase.saleDetails().totalMinted, purchaseQuantity);
        require(zoraNFTBase.ownerOf(1) == address(456), "owner is wrong for new minted token");
        assertEq(address(zoraNFTBase).balance, paymentAmount - zoraFee);
        assertEq(mintFeeRecipient.balance, zoraFee);
    }

    function test_PurchaseWithComment(uint64 salePrice, uint32 purchaseQuantity)
        public
        setupZoraNFTBase(purchaseQuantity)
    {
        vm.assume(purchaseQuantity < 100 && purchaseQuantity > 0);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: salePrice,
            maxSalePurchasePerAddress: purchaseQuantity + 1,
            presaleMerkleRoot: bytes32(0)
        });

        (, uint256 zoraFee) = zoraNFTBase.zoraFeeForAmount(purchaseQuantity);
        uint256 paymentAmount = uint256(salePrice) * purchaseQuantity + zoraFee;
        vm.deal(address(456), paymentAmount);
        vm.prank(address(456));
        vm.expectEmit(true, true, true, true);
        emit MintComment(address(456), address(zoraNFTBase), 0, purchaseQuantity, "test comment");
        zoraNFTBase.purchaseWithComment{value: paymentAmount}(purchaseQuantity, "test comment");
    }

    function test_PurchaseWithRecipient(uint64 salePrice, uint32 purchaseQuantity)
        public
        setupZoraNFTBase(purchaseQuantity)
    {
        vm.assume(purchaseQuantity < 100 && purchaseQuantity > 0);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: salePrice,
            maxSalePurchasePerAddress: purchaseQuantity + 1,
            presaleMerkleRoot: bytes32(0)
        });

        (, uint256 zoraFee) = zoraNFTBase.zoraFeeForAmount(purchaseQuantity);
        uint256 paymentAmount = uint256(salePrice) * purchaseQuantity + zoraFee;

        address minter = makeAddr("minter");
        address recipient = makeAddr("recipient");

        vm.deal(minter, paymentAmount);
        vm.prank(minter);
        zoraNFTBase.purchaseWithRecipient{value: paymentAmount}(recipient, purchaseQuantity, "");

        for (uint256 i; i < purchaseQuantity;) {
            assertEq(zoraNFTBase.ownerOf(++i), recipient);
        }
    }

    function test_PurchaseWithRecipientAndComment(uint64 salePrice, uint32 purchaseQuantity)
        public
        setupZoraNFTBase(purchaseQuantity)
    {
        vm.assume(purchaseQuantity < 100 && purchaseQuantity > 0);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: salePrice,
            maxSalePurchasePerAddress: purchaseQuantity + 1,
            presaleMerkleRoot: bytes32(0)
        });

        (, uint256 zoraFee) = zoraNFTBase.zoraFeeForAmount(purchaseQuantity);
        uint256 paymentAmount = uint256(salePrice) * purchaseQuantity + zoraFee;

        address minter = makeAddr("minter");
        address recipient = makeAddr("recipient");

        vm.deal(minter, paymentAmount);

        vm.expectEmit(true, true, true, true);
        emit MintComment(minter, address(zoraNFTBase), 0, purchaseQuantity, "test comment");
        vm.prank(minter);
        zoraNFTBase.purchaseWithRecipient{value: paymentAmount}(recipient, purchaseQuantity, "test comment");
    }

    function testRevert_PurchaseWithInvalidRecipient(uint64 salePrice, uint32 purchaseQuantity)
        public
        setupZoraNFTBase(purchaseQuantity)
    {
        vm.assume(purchaseQuantity < 100 && purchaseQuantity > 0);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: salePrice,
            maxSalePurchasePerAddress: purchaseQuantity + 1,
            presaleMerkleRoot: bytes32(0)
        });

        (, uint256 zoraFee) = zoraNFTBase.zoraFeeForAmount(purchaseQuantity);
        uint256 paymentAmount = uint256(salePrice) * purchaseQuantity + zoraFee;

        address minter = makeAddr("minter");
        address recipient = address(0);

        vm.deal(minter, paymentAmount);

        vm.expectRevert(abi.encodeWithSignature("MintToZeroAddress()"));
        vm.prank(minter);
        zoraNFTBase.purchaseWithRecipient{value: paymentAmount}(recipient, purchaseQuantity, "");
    }

    function test_FreeMintRewards(uint32 purchaseQuantity) public setupZoraNFTBase(purchaseQuantity) {
        vm.assume(purchaseQuantity < 100 && purchaseQuantity > 0);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0,
            maxSalePurchasePerAddress: purchaseQuantity + 1,
            presaleMerkleRoot: bytes32(0)
        });

        uint256 totalReward = zoraNFTBase.computeTotalReward(purchaseQuantity);

        RewardsSettings memory settings = zoraNFTBase.computeFreeMintRewards(purchaseQuantity);

        vm.deal(collector, totalReward);
        vm.prank(collector);
        zoraNFTBase.mintWithRewards{value: totalReward}(collector, purchaseQuantity, "test comment", address(0));

        assertEq(protocolRewards.balanceOf(DEFAULT_FUNDS_RECIPIENT_ADDRESS), settings.creatorReward + settings.firstMinterReward);
        assertEq(protocolRewards.balanceOf(mintFeeRecipient), settings.zoraReward + settings.mintReferralReward + settings.createReferralReward);
    }

    function test_FreeMintRewardsWithMintReferral(uint32 purchaseQuantity) public setupZoraNFTBase(purchaseQuantity) {
        vm.assume(purchaseQuantity < 100 && purchaseQuantity > 0);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0,
            maxSalePurchasePerAddress: purchaseQuantity + 1,
            presaleMerkleRoot: bytes32(0)
        });

        uint256 totalReward = zoraNFTBase.computeTotalReward(purchaseQuantity);

        RewardsSettings memory settings = zoraNFTBase.computeFreeMintRewards(purchaseQuantity);

        vm.deal(collector, totalReward);
        vm.prank(collector);
        zoraNFTBase.mintWithRewards{value: totalReward}(collector, purchaseQuantity, "test comment", mintReferral);

        assertEq(protocolRewards.balanceOf(DEFAULT_FUNDS_RECIPIENT_ADDRESS), settings.creatorReward + settings.firstMinterReward);
        assertEq(protocolRewards.balanceOf(mintFeeRecipient), settings.zoraReward + settings.createReferralReward);
        assertEq(protocolRewards.balanceOf(mintReferral), settings.mintReferralReward);
    }

    function test_FreeMintRewardsWithCreateReferral(uint32 purchaseQuantity)
        public
        setupZoraNFTBaseWithCreateReferral(purchaseQuantity, createReferral)
    {
        vm.assume(purchaseQuantity < 100 && purchaseQuantity > 0);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0,
            maxSalePurchasePerAddress: purchaseQuantity + 1,
            presaleMerkleRoot: bytes32(0)
        });

        uint256 totalReward = zoraNFTBase.computeTotalReward(purchaseQuantity);

        RewardsSettings memory settings = zoraNFTBase.computeFreeMintRewards(purchaseQuantity);

        vm.deal(collector, totalReward);
        vm.prank(collector);
        zoraNFTBase.mintWithRewards{value: totalReward}(collector, purchaseQuantity, "test comment", address(0));

        assertEq(protocolRewards.balanceOf(DEFAULT_FUNDS_RECIPIENT_ADDRESS), settings.creatorReward + settings.firstMinterReward);
        assertEq(protocolRewards.balanceOf(mintFeeRecipient), settings.zoraReward + settings.mintReferralReward);
        assertEq(protocolRewards.balanceOf(createReferral), settings.createReferralReward);
    }

    function test_FreeMintRewardsWithMintAndCreateReferrals(uint32 purchaseQuantity)
        public
        setupZoraNFTBaseWithCreateReferral(purchaseQuantity, createReferral)
    {
        vm.assume(purchaseQuantity < 100 && purchaseQuantity > 0);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0,
            maxSalePurchasePerAddress: purchaseQuantity + 1,
            presaleMerkleRoot: bytes32(0)
        });

        uint256 totalReward = zoraNFTBase.computeTotalReward(purchaseQuantity);

        RewardsSettings memory settings = zoraNFTBase.computeFreeMintRewards(purchaseQuantity);

        vm.deal(collector, totalReward);
        vm.prank(collector);
        zoraNFTBase.mintWithRewards{value: totalReward}(collector, purchaseQuantity, "test comment", mintReferral);

        assertEq(protocolRewards.balanceOf(DEFAULT_FUNDS_RECIPIENT_ADDRESS), settings.creatorReward + settings.firstMinterReward);
        assertEq(protocolRewards.balanceOf(mintFeeRecipient), settings.zoraReward);
        assertEq(protocolRewards.balanceOf(mintReferral), settings.mintReferralReward);
        assertEq(protocolRewards.balanceOf(createReferral), settings.createReferralReward);
    }

    function testRevert_FreeMintRewardsInsufficientEth(uint32 purchaseQuantity)
        public
        setupZoraNFTBase(purchaseQuantity)
    {
        vm.assume(purchaseQuantity < 100 && purchaseQuantity > 0);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0,
            maxSalePurchasePerAddress: purchaseQuantity + 1,
            presaleMerkleRoot: bytes32(0)
        });

        vm.expectRevert(abi.encodeWithSignature("INVALID_ETH_AMOUNT()"));
        zoraNFTBase.mintWithRewards(collector, purchaseQuantity, "test comment", address(0));
    }

    function test_PaidMintRewards(uint64 salePrice, uint32 purchaseQuantity)
        public
        setupZoraNFTBase(purchaseQuantity)
    {
        vm.assume(salePrice > 0);
        vm.assume(purchaseQuantity < 100 && purchaseQuantity > 0);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: salePrice,
            maxSalePurchasePerAddress: purchaseQuantity + 1,
            presaleMerkleRoot: bytes32(0)
        });

        RewardsSettings memory settings = zoraNFTBase.computePaidMintRewards(purchaseQuantity);

        uint256 totalReward = zoraNFTBase.computeTotalReward(purchaseQuantity);
        uint256 totalSales = uint256(salePrice) * purchaseQuantity;
        uint256 totalPayment = totalSales + totalReward;

        vm.deal(collector, totalPayment);
        vm.prank(collector);
        zoraNFTBase.mintWithRewards{value: totalPayment}(collector, purchaseQuantity, "test comment", address(0));

        assertEq(address(zoraNFTBase).balance, totalSales);
        assertEq(protocolRewards.balanceOf(DEFAULT_FUNDS_RECIPIENT_ADDRESS), settings.firstMinterReward);
        assertEq(protocolRewards.balanceOf(mintFeeRecipient), settings.zoraReward + settings.mintReferralReward + settings.createReferralReward);
    }

    function test_PaidMintRewardsWithMintReferral(uint64 salePrice, uint32 purchaseQuantity)
        public
        setupZoraNFTBase(purchaseQuantity)
    {
        vm.assume(salePrice > 0);
        vm.assume(purchaseQuantity < 100 && purchaseQuantity > 0);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: salePrice,
            maxSalePurchasePerAddress: purchaseQuantity + 1,
            presaleMerkleRoot: bytes32(0)
        });

        RewardsSettings memory settings = zoraNFTBase.computePaidMintRewards(purchaseQuantity);
        uint256 totalReward = zoraNFTBase.computeTotalReward(purchaseQuantity);
        uint256 totalSales = uint256(salePrice) * purchaseQuantity;
        uint256 totalPayment = totalSales + totalReward;

        vm.deal(collector, totalPayment);
        vm.prank(collector);
        zoraNFTBase.mintWithRewards{value: totalPayment}(collector, purchaseQuantity, "test comment", mintReferral);

        assertEq(address(zoraNFTBase).balance, totalSales);
        assertEq(protocolRewards.balanceOf(DEFAULT_FUNDS_RECIPIENT_ADDRESS), settings.firstMinterReward);
        assertEq(protocolRewards.balanceOf(mintFeeRecipient), settings.zoraReward + settings.createReferralReward);
        assertEq(protocolRewards.balanceOf(mintReferral), settings.mintReferralReward);
    }

    function test_PaidMintRewardsWithCreateReferral(uint64 salePrice, uint32 purchaseQuantity)
        public
        setupZoraNFTBaseWithCreateReferral(purchaseQuantity, createReferral)
    {
        vm.assume(salePrice > 0);
        vm.assume(purchaseQuantity < 100 && purchaseQuantity > 0);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: salePrice,
            maxSalePurchasePerAddress: purchaseQuantity + 1,
            presaleMerkleRoot: bytes32(0)
        });

        RewardsSettings memory settings = zoraNFTBase.computePaidMintRewards(purchaseQuantity);

        uint256 totalReward = zoraNFTBase.computeTotalReward(purchaseQuantity);
        uint256 totalSales = uint256(salePrice) * purchaseQuantity;
        uint256 totalPayment = totalSales + totalReward;

        vm.deal(collector, totalPayment);
        vm.prank(collector);
        zoraNFTBase.mintWithRewards{value: totalPayment}(collector, purchaseQuantity, "test comment", address(0));

        assertEq(address(zoraNFTBase).balance, totalSales);
        assertEq(protocolRewards.balanceOf(DEFAULT_FUNDS_RECIPIENT_ADDRESS), settings.firstMinterReward);
        assertEq(protocolRewards.balanceOf(mintFeeRecipient), settings.zoraReward + settings.mintReferralReward);
        assertEq(protocolRewards.balanceOf(createReferral), settings.createReferralReward);
    }

    function test_PaidMintRewardsWithMintAndCreateReferrals(uint64 salePrice, uint32 purchaseQuantity)
        public
        setupZoraNFTBaseWithCreateReferral(purchaseQuantity, createReferral)
    {
        vm.assume(salePrice > 0);
        vm.assume(purchaseQuantity < 100 && purchaseQuantity > 0);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: salePrice,
            maxSalePurchasePerAddress: purchaseQuantity + 1,
            presaleMerkleRoot: bytes32(0)
        });

        RewardsSettings memory settings = zoraNFTBase.computePaidMintRewards(purchaseQuantity);

        uint256 totalReward = zoraNFTBase.computeTotalReward(purchaseQuantity);
        uint256 totalSales = uint256(salePrice) * purchaseQuantity;
        uint256 totalPayment = totalSales + totalReward;

        vm.deal(collector, totalPayment);
        vm.prank(collector);
        zoraNFTBase.mintWithRewards{value: totalPayment}(collector, purchaseQuantity, "test comment", mintReferral);

        assertEq(address(zoraNFTBase).balance, totalSales);
        assertEq(protocolRewards.balanceOf(DEFAULT_FUNDS_RECIPIENT_ADDRESS), settings.firstMinterReward);
        assertEq(protocolRewards.balanceOf(mintFeeRecipient), settings.zoraReward);
        assertEq(protocolRewards.balanceOf(mintReferral), settings.mintReferralReward);
        assertEq(protocolRewards.balanceOf(createReferral), settings.createReferralReward);
    }

    function testRevert_PaidMintRewardsInsufficientEth(uint64 salePrice, uint32 purchaseQuantity)
        public
        setupZoraNFTBase(purchaseQuantity)
    {
        vm.assume(salePrice > 0);
        vm.assume(purchaseQuantity < 100 && purchaseQuantity > 0);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: salePrice,
            maxSalePurchasePerAddress: purchaseQuantity + 1,
            presaleMerkleRoot: bytes32(0)
        });

        vm.expectRevert(abi.encodeWithSignature("INVALID_ETH_AMOUNT()"));
        zoraNFTBase.mintWithRewards(collector, purchaseQuantity, "test comment", address(0));
    }

    function test_UpgradeApproved() public setupZoraNFTBase(10) {
        address newImpl = address(
            new ERC721Drop(
                address(0x3333),
                factoryUpgradeGate,
                address(0x0),
                mintFee,
                mintFeeRecipient,
                address(protocolRewards)
            )
        );

        address[] memory lastImpls = new address[](1);
        lastImpls[0] = impl;
        vm.prank(UPGRADE_GATE_ADMIN_ADDRESS);
        factoryUpgradeGate.registerNewUpgradePath({_newImpl: newImpl, _supportedPrevImpls: lastImpls});
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.upgradeTo(newImpl);
    }

    function test_UpgradeFailsNotApproved() public setupZoraNFTBase(10) {
        address newImpl = address(
            new ERC721Drop(
                address(0x3333),
                factoryUpgradeGate,
                address(0x0),
                mintFee,
                mintFeeRecipient,
                address(protocolRewards)
            )
        );

        vm.prank(DEFAULT_OWNER_ADDRESS);
        vm.expectRevert(abi.encodeWithSelector(IERC721Drop.Admin_InvalidUpgradeAddress.selector, newImpl));
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

        (, uint256 fee) = zoraNFTBase.zoraFeeForAmount(1);

        vm.deal(address(456), 1 ether);
        vm.prank(address(456));
        vm.expectRevert(IERC721Drop.Sale_Inactive.selector);
        zoraNFTBase.purchase{value: 0.1 ether + fee}(1);

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
        zoraNFTBase.purchase{value: 0.1 ether + fee}(1);

        assertEq(zoraNFTBase.saleDetails().totalMinted, 1);
        assertEq(zoraNFTBase.ownerOf(1), address(456));
    }

    function test_Mint() public setupZoraNFTBase(10) {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.adminMint(DEFAULT_OWNER_ADDRESS, 1);
        assertEq(zoraNFTBase.saleDetails().maxSupply, 10);
        assertEq(zoraNFTBase.saleDetails().totalMinted, 1);
        require(zoraNFTBase.ownerOf(1) == DEFAULT_OWNER_ADDRESS, "Owner is wrong for new minted token");
    }

    function test_MulticallAccessControl() public setupZoraNFTBase(10) {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0,
            maxSalePurchasePerAddress: 10,
            presaleMerkleRoot: bytes32(0)
        });

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(IERC721Drop.adminMint.selector, address(0x456), 1);
        calls[1] = abi.encodeWithSelector(IERC721Drop.adminMint.selector, address(0x123), 3);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Drop.Access_MissingRoleOrAdmin.selector,
                bytes32(0xf0887ba65ee2024ea881d91b74c2450ef19e1557f03bed3ea9f16b037cbe2dc9)
            )
        );
        zoraNFTBase.multicall(calls);

        assertEq(zoraNFTBase.balanceOf(address(0x123)), 0);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.multicall(calls);

        assertEq(zoraNFTBase.balanceOf(address(0x123)), 3);
        assertEq(zoraNFTBase.balanceOf(address(0x456)), 1);
    }

    function test_MintMulticall() public setupZoraNFTBase(10) {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(IERC721Drop.adminMint.selector, DEFAULT_OWNER_ADDRESS, 5);
        calls[1] = abi.encodeWithSelector(IERC721Drop.adminMint.selector, address(0x123), 3);
        calls[2] = abi.encodeWithSelector(IERC721Drop.saleDetails.selector);
        bytes[] memory results = zoraNFTBase.multicall(calls);

        (bool saleActive, bool presaleActive, uint256 publicSalePrice,,,,,,,,) = abi.decode(
            results[2], (bool, bool, uint256, uint64, uint64, uint64, uint64, bytes32, uint256, uint256, uint256)
        );
        assertTrue(!saleActive);
        assertTrue(!presaleActive);
        assertEq(publicSalePrice, 0);
        uint256 firstMintedId = abi.decode(results[0], (uint256));
        uint256 secondMintedId = abi.decode(results[1], (uint256));
        assertEq(firstMintedId, 5);
        assertEq(secondMintedId, 8);
    }

    function test_UpdatePriceMulticall() public setupZoraNFTBase(10) {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(
            IERC721Drop.setSaleConfiguration.selector, 0.1 ether, 2, 0, type(uint64).max, 0, 0, bytes32(0)
        );
        calls[1] = abi.encodeWithSelector(IERC721Drop.adminMint.selector, address(0x123), 3);
        calls[2] = abi.encodeWithSelector(IERC721Drop.adminMint.selector, address(0x123), 3);
        bytes[] memory results = zoraNFTBase.multicall(calls);

        IERC721Drop.SaleDetails memory saleDetails = zoraNFTBase.saleDetails();

        assertTrue(saleDetails.publicSaleActive);
        assertTrue(!saleDetails.presaleActive);
        assertEq(saleDetails.publicSalePrice, 0.1 ether);
        uint256 firstMintedId = abi.decode(results[1], (uint256));
        uint256 secondMintedId = abi.decode(results[2], (uint256));
        assertEq(firstMintedId, 3);
        assertEq(secondMintedId, 6);
        vm.stopPrank();
        vm.startPrank(address(0x111));
        vm.deal(address(0x111), 0.3 ether);
        zoraNFTBase.purchase{value: 0.2 ether + (mintFee * 2)}(2);
        assertEq(zoraNFTBase.balanceOf(address(0x111)), 2);
        vm.stopPrank();
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
        (, uint256 fee) = zoraNFTBase.zoraFeeForAmount(1);
        vm.prank(address(456));
        vm.expectRevert(abi.encodeWithSelector(IERC721Drop.Purchase_WrongPrice.selector, 0.15 ether + fee));
        zoraNFTBase.purchase{value: 0.12 ether}(1);
    }

    function test_Withdraw(uint128 amount) public setupZoraNFTBase(10) {
        vm.assume(amount > 0.01 ether);
        vm.deal(address(zoraNFTBase), amount);
        uint256 leftoverFunds = amount;

        vm.prank(DEFAULT_OWNER_ADDRESS);
        vm.expectEmit(true, true, true, true);
        emit FundsWithdrawn(
            DEFAULT_OWNER_ADDRESS, DEFAULT_FUNDS_RECIPIENT_ADDRESS, leftoverFunds, payable(address(0)), 0
        );
        zoraNFTBase.withdraw();

        assertEq(DEFAULT_FUNDS_RECIPIENT_ADDRESS.balance, amount);
    }

    function test_WithdrawNoZoraFee(uint128 amount) public setupZoraNFTBase(10) {
        vm.assume(amount > 0.01 ether);

        address payable fundsRecipientTarget = payable(address(0x0));

        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.setFundsRecipient(fundsRecipientTarget);

        vm.deal(address(zoraNFTBase), amount);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        vm.expectEmit(true, true, true, true);
        emit FundsWithdrawn(DEFAULT_OWNER_ADDRESS, fundsRecipientTarget, amount, payable(address(0)), 0);
        zoraNFTBase.withdraw();

        assertTrue(fundsRecipientTarget.balance == uint256(amount));
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
        (, uint256 limitFee) = zoraNFTBase.zoraFeeForAmount(limit);
        vm.deal(address(456), 100_000_000 ether);
        vm.prank(address(456));
        zoraNFTBase.purchase{value: 0.1 ether * uint256(limit) + limitFee}(limit);

        assertEq(zoraNFTBase.saleDetails().totalMinted, limit);

        (, uint256 fee) = zoraNFTBase.zoraFeeForAmount(1);
        vm.deal(address(444), 1_000_000 ether);
        vm.prank(address(444));
        vm.expectRevert(IERC721Drop.Purchase_TooManyForAddress.selector);
        zoraNFTBase.purchase{value: (0.1 ether * (uint256(limit) + 1)) + (fee * (uint256(limit) + 1))}(
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

        (,,,,, uint64 presaleEndLookup,) = zoraNFTBase.salesConfig();
        assertEq(presaleEndLookup, 100);

        address SALES_MANAGER_ADDR = address(0x11002);
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.grantRole(zoraNFTBase.SALES_MANAGER_ROLE(), SALES_MANAGER_ADDR);
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

        (,,,, uint64 presaleStartLookup2, uint64 presaleEndLookup2,) = zoraNFTBase.salesConfig();
        assertEq(presaleEndLookup2, 0);
        assertEq(presaleStartLookup2, 100);
    }

    function test_GlobalLimit(uint16 limit) public setupZoraNFTBase(uint64(limit)) {
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
        (, uint256 fee) = zoraNFTBase.zoraFeeForAmount(3);
        zoraNFTBase.purchase{value: 0.6 ether + fee}(3);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        zoraNFTBase.adminMint(address(0x1234), 2);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        vm.expectRevert(IERC721Drop.Admin_UnableToFinalizeNotOpenEdition.selector);
        zoraNFTBase.finalizeOpenEdition();
    }

    function test_ValidFinalizeOpenEdition() public setupZoraNFTBase(type(uint64).max) {
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
        (, uint256 fee) = zoraNFTBase.zoraFeeForAmount(3);
        zoraNFTBase.purchase{value: 0.6 ether + fee}(3);
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
        require(zoraNFTBase.balanceOf(DEFAULT_OWNER_ADDRESS) == 1, "Wrong balance");
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
        vm.expectRevert(abi.encodeWithSignature("Access_MissingRoleOrAdmin(bytes32)", minterRole));
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
        vm.expectRevert(abi.encodeWithSignature("Access_MissingRoleOrAdmin(bytes32)", role));
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
        vm.expectRevert(IERC721AUpgradeable.TransferCallerNotOwnerNorApproved.selector);
        zoraNFTBase.burn(1);
    }

    function test_AdminMetadataRendererUpdateCall() public setupZoraNFTBase(10) {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        assertEq(dummyRenderer.someState(), "");
        zoraNFTBase.callMetadataRenderer(
            abi.encodeWithSelector(DummyMetadataRenderer.updateSomeState.selector, "new state", address(zoraNFTBase))
        );
        assertEq(dummyRenderer.someState(), "new state");
    }

    function test_NonAdminMetadataRendererUpdateCall() public setupZoraNFTBase(10) {
        vm.startPrank(address(0x99493));
        assertEq(dummyRenderer.someState(), "");
        bytes memory targetCall =
            abi.encodeWithSelector(DummyMetadataRenderer.updateSomeState.selector, "new state", address(zoraNFTBase));
        vm.expectRevert(IERC721Drop.Access_OnlyAdmin.selector);
        zoraNFTBase.callMetadataRenderer(targetCall);
        assertEq(dummyRenderer.someState(), "");
    }

    function test_SupplyRoyaltyMintScheduleCannotBeOne() public setupZoraNFTBase(100) {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        vm.expectRevert(IERC721Drop.InvalidMintSchedule.selector);
        zoraNFTBase.updateRoyaltyMintSchedule(1);
    }

    function test_SupplyRoyaltyPurchase(uint32 royaltyMintSchedule, uint32 editionSize, uint256 mintQuantity)
        public
        setupZoraNFTBase(editionSize)
    {
        vm.assume(
            royaltyMintSchedule > 1 && royaltyMintSchedule <= editionSize && editionSize <= 100000 && mintQuantity > 0
                && mintQuantity <= editionSize
        );
        uint256 totalRoyaltyMintsForSale = editionSize / royaltyMintSchedule;
        vm.assume(mintQuantity <= editionSize - totalRoyaltyMintsForSale);

        vm.startPrank(DEFAULT_OWNER_ADDRESS);

        zoraNFTBase.updateRoyaltyMintSchedule(royaltyMintSchedule);

        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.1 ether,
            maxSalePurchasePerAddress: editionSize,
            presaleMerkleRoot: bytes32(0)
        });
        vm.stopPrank();

        uint256 totalRoyaltyMintsForPurchase = mintQuantity / (royaltyMintSchedule - 1);
        totalRoyaltyMintsForPurchase = Math.min(totalRoyaltyMintsForPurchase, editionSize - mintQuantity);
        (, uint256 zoraFee) = zoraNFTBase.zoraFeeForAmount(mintQuantity);

        uint256 paymentAmount = 0.1 ether * mintQuantity + zoraFee;
        vm.deal(address(456), paymentAmount);

        vm.startPrank(address(456));
        zoraNFTBase.purchase{value: paymentAmount}(mintQuantity);

        assertEq(zoraNFTBase.balanceOf(address(456)), mintQuantity);
        assertEq(zoraNFTBase.balanceOf(DEFAULT_FUNDS_RECIPIENT_ADDRESS), totalRoyaltyMintsForPurchase);

        vm.stopPrank();
    }

    function test_SupplyRoyaltyCleanNumbers() public setupZoraNFTBase(100) {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);

        zoraNFTBase.updateRoyaltyMintSchedule(5);

        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.1 ether,
            maxSalePurchasePerAddress: 100,
            presaleMerkleRoot: bytes32(0)
        });
        vm.stopPrank();

        (, uint256 zoraFee) = zoraNFTBase.zoraFeeForAmount(80);
        uint256 paymentAmount = 0.1 ether * 80 + zoraFee;
        vm.deal(address(456), paymentAmount);

        vm.startPrank(address(456));
        zoraNFTBase.purchase{value: paymentAmount}(80);

        assertEq(zoraNFTBase.balanceOf(address(456)), 80);
        assertEq(zoraNFTBase.balanceOf(DEFAULT_FUNDS_RECIPIENT_ADDRESS), 20);

        vm.stopPrank();
    }

    function test_SupplyRoyaltyEdgeCaseNumbers() public setupZoraNFTBase(137) {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);

        zoraNFTBase.updateRoyaltyMintSchedule(3);

        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.1 ether,
            maxSalePurchasePerAddress: 92,
            presaleMerkleRoot: bytes32(0)
        });
        vm.stopPrank();

        (, uint256 zoraFee) = zoraNFTBase.zoraFeeForAmount(92);
        uint256 paymentAmount = 0.1 ether * 92 + zoraFee;
        vm.deal(address(456), paymentAmount);

        vm.startPrank(address(456));
        zoraNFTBase.purchase{value: paymentAmount}(92);

        assertEq(zoraNFTBase.balanceOf(address(456)), 92);
        assertEq(zoraNFTBase.balanceOf(DEFAULT_FUNDS_RECIPIENT_ADDRESS), 45);

        vm.stopPrank();
    }

    function test_SupplyRoyaltyEdgeCaseNumbersOpenEdition() public setupZoraNFTBase(type(uint64).max) {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);

        zoraNFTBase.updateRoyaltyMintSchedule(3);

        zoraNFTBase.setSaleConfiguration({
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.1 ether,
            maxSalePurchasePerAddress: 93,
            presaleMerkleRoot: bytes32(0)
        });
        vm.stopPrank();

        (, uint256 zoraFee) = zoraNFTBase.zoraFeeForAmount(92);
        uint256 paymentAmount = 0.1 ether * 92 + zoraFee;
        vm.deal(address(456), paymentAmount);

        vm.startPrank(address(456));
        zoraNFTBase.purchase{value: paymentAmount}(92);

        assertEq(zoraNFTBase.balanceOf(address(456)), 92);
        assertEq(zoraNFTBase.balanceOf(DEFAULT_FUNDS_RECIPIENT_ADDRESS), 46);

        (, zoraFee) = zoraNFTBase.zoraFeeForAmount(1);
        paymentAmount = 0.1 ether + zoraFee;
        vm.deal(address(456), paymentAmount);

        zoraNFTBase.purchase{value: paymentAmount}(1);

        assertEq(zoraNFTBase.balanceOf(address(456)), 93);
        assertEq(zoraNFTBase.balanceOf(DEFAULT_FUNDS_RECIPIENT_ADDRESS), 46);

        vm.stopPrank();
    }

    function test_EIP165() public view {
        require(zoraNFTBase.supportsInterface(0x01ffc9a7), "supports 165");
        require(zoraNFTBase.supportsInterface(0x80ac58cd), "supports 721");
        require(zoraNFTBase.supportsInterface(0x5b5e139f), "supports 721-metdata");
        require(zoraNFTBase.supportsInterface(0x2a55205a), "supports 2981");
        require(zoraNFTBase.supportsInterface(0x49064906), "supports 4906");
        require(!zoraNFTBase.supportsInterface(0x0000000), "doesnt allow non-interface");
    }
}
