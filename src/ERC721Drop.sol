// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

/**

 ________   _____   ____    ______      ____
/\_____  \ /\  __`\/\  _`\ /\  _  \    /\  _`\
\/____//'/'\ \ \/\ \ \ \L\ \ \ \L\ \   \ \ \/\ \  _ __   ___   _____     ____
     //'/'  \ \ \ \ \ \ ,  /\ \  __ \   \ \ \ \ \/\`'__\/ __`\/\ '__`\  /',__\
    //'/'___ \ \ \_\ \ \ \\ \\ \ \/\ \   \ \ \_\ \ \ \//\ \L\ \ \ \L\ \/\__, `\
    /\_______\\ \_____\ \_\ \_\ \_\ \_\   \ \____/\ \_\\ \____/\ \ ,__/\/\____/
    \/_______/ \/_____/\/_/\/ /\/_/\/_/    \/___/  \/_/ \/___/  \ \ \/  \/___/
                                                                 \ \_\
                                                                  \/_/

 */

import {ERC721AUpgradeable} from "erc721a-upgradeable/ERC721AUpgradeable.sol";
import {IERC2981Upgradeable, IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

import {IZoraFeeManager} from "./interfaces/IZoraFeeManager.sol";
import {IMetadataRenderer} from "./interfaces/IMetadataRenderer.sol";
import {IZoraDrop} from "./interfaces/IZoraDrop.sol";
import {IOwnable} from "./interfaces/IOwnable.sol";
import {OwnableSkeleton} from "./utils/OwnableSkeleton.sol";

/**
 * @notice ZORA NFT Base contract for Drops and Editions
 *
 * @dev For drops: assumes 1. linear mint order, 2. max number of mints needs to be less than max_uint64
 *       (if you have more than 18 quintillion linear mints you should probably not be using this contract)
 * @author iain@zora.co
 *
 */
contract ERC721Drop is
    ERC721AUpgradeable,
    IERC2981Upgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    IZoraDrop,
    OwnableSkeleton
{
    /// @dev This is the underlying contract version that is implemented by the interface
    uint256 private constant VERSION = 3;
    /// @dev This is the max mint batch size for the optimized ERC721A mint contract
    uint256 private constant MAX_MINT_BATCH_SIZE = 8;

    using AddressUpgradeable for address payable;

    event SalesConfigChanged(
        address indexed changedBy,
        SalesConfiguration salesConfig
    );

    event FundsRecipientChanged(
        address indexed newAddress,
        address indexed changedBy
    );

    event OpenMintFinalized(address indexed sender, uint256 numberOfMints);

    /// @notice Error string constants
    string private constant SOLD_OUT = "Sold out";
    string private constant TOO_MANY = "Too many";

    /// @notice Access control roles
    bytes32 public immutable MINTER_ROLE = keccak256("MINTER");
    bytes32 public immutable SALES_MANAGER_ROLE = keccak256("SALES_MANAGER");

    /// @dev Returns the version of the contract.
    function contractVersion() external pure returns (uint256) {
        return VERSION;
    }

    /// @notice General configuration for NFT Minting and bookkeeping
    struct Configuration {
        /// @dev Metadata renderer
        IMetadataRenderer metadataRenderer;
        /// @dev Total size of edition that can be minted
        uint64 editionSize;
        /// @dev Royalty amount in bps
        uint16 royaltyBPS;
        /// @dev Funds recipient for sale
        address payable fundsRecipient;
    }

    /// @notice Sales states and configuration
    /// @dev Uses 3 storage slots
    struct SalesConfiguration {
        /// @dev Public sale price
        uint104 publicSalePrice;
        /// @dev Max purchase number per txn
        uint32 maxSalePurchasePerAddress;
        /// @dev uint64 type allows for dates into 292 billion years

        // Storage: uses 1 slot

        /// @dev Public sale start timestamp
        uint64 publicSaleStart;
        /// @dev Public sale end timestamp
        uint64 publicSaleEnd;
        /// @dev Presale start timestamp
        uint64 presaleStart;
        /// @dev Presale end timestamp
        uint64 presaleEnd;
        // Storage: uses 1 slot

        /// @dev Presale merkle root
        bytes32 presaleMerkleRoot;
    }

    /// @notice Configuration for NFT minting contract storage
    Configuration public config;

    /// @notice Sales configuration
    SalesConfiguration public salesConfig;

    /// @dev ZORA V3 transfer helper address for auto-approval
    address private immutable zoraERC721TransferHelper;

    /// @dev Mapping for presale mint counts by address to allow public mint limit
    mapping(address => uint256) public presaleMintsByAddress;

    /// @dev Zora Fee Manager address
    IZoraFeeManager public immutable zoraFeeManager;

    /// @notice Only allow for users with admin access
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Only admin allowed");

        _;
    }

    /// @notice Allows user to mint tokens at a quantity
    modifier canMintTokens(uint256 quantity) {
        require(quantity + _totalMinted() <= config.editionSize, TOO_MANY);

        _;
    }

    function _presaleActive() internal view returns (bool) {
        return
            salesConfig.presaleStart <= block.timestamp &&
            salesConfig.presaleEnd > block.timestamp;
    }

    function _publicSaleActive() internal view returns (bool) {
        return
            salesConfig.publicSaleStart <= block.timestamp &&
            salesConfig.publicSaleEnd > block.timestamp;
    }

    /// @notice Presale active
    modifier onlyPresaleActive() {
        require(_presaleActive(), "Presale inactive");

        _;
    }

    /// @notice Public sale active
    modifier onlyPublicSaleActive() {
        require(_publicSaleActive(), "Sale inactive");

        _;
    }

    /// @notice Getter for last minted token ID (gets next token id and subtracts 1)
    function _lastMintedTokenId() internal view returns (uint256) {
        return _currentIndex - 1;
    }

    /// @notice Start token ID for minting (1-100 vs 0-99)
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /// @notice Only a given role has access or admin
    /// @param role role to check for alongside the admin role
    modifier onlyRoleOrAdmin(bytes32 role) {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
                hasRole(role, msg.sender),
            "Does not have proper role or admin"
        );

        _;
    }

    /// @notice Global constructor – these variables will not change with further proxy deploys
    /// @param _zoraFeeManager Zora Fee Manager
    /// @param _zoraERC721TransferHelper Transfer helper
    constructor(
        IZoraFeeManager _zoraFeeManager,
        address _zoraERC721TransferHelper
    ) {
        zoraFeeManager = _zoraFeeManager;
        zoraERC721TransferHelper = _zoraERC721TransferHelper;
    }

    ///  @dev Create a new drop
    ///  @param _contractName Contract name
    ///  @param _contractSymbol Contract symbol
    ///  @param _initialOwner User that owns and can mint the edition, gets royalty and sales payouts and can update the base url if needed.
    ///  @param _fundsRecipient Wallet/user that receives funds from sale
    ///  @param _editionSize Number of editions that can be minted in total. If 0, unlimited editions can be minted.
    ///  @param _royaltyBPS BPS of the royalty set on the contract. Can be 0 for no royalty.
    function initialize(
        string memory _contractName,
        string memory _contractSymbol,
        address _initialOwner,
        address payable _fundsRecipient,
        uint64 _editionSize,
        uint16 _royaltyBPS,
        IMetadataRenderer _metadataRenderer,
        bytes memory _metadataRendererInit
    ) public initializer {
        // Setup ERC721A
        __ERC721A_init(_contractName, _contractSymbol);
        // Setup access control
        __AccessControl_init();
        // Setup re-entracy guard
        __ReentrancyGuard_init();
        // Setup the owner role
        _setupRole(DEFAULT_ADMIN_ROLE, _initialOwner);
        // Set ownership to original sender of contract call
        _setOwner(_initialOwner);

        require(
            config.royaltyBPS < 50_01,
            "Royalty BPS cannot be greater than 50%"
        );

        config.editionSize = _editionSize;
        config.metadataRenderer = _metadataRenderer;
        config.royaltyBPS = _royaltyBPS;
        config.fundsRecipient = _fundsRecipient;
        _metadataRenderer.initializeWithData(_metadataRendererInit);
    }

    /// @dev Getter for admin role associated with the contract to handle metadata
    /// @return boolean if address is admin
    function isAdmin(address user) external view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, user);
    }

    /// @param tokenId Token ID to burn
    /// @notice User burn function for token id
    function burn(uint256 tokenId) public {
        _burn(tokenId, true);
    }

    /// @dev Get royalty information for token
    /// @param _salePrice Sale price for the token
    function royaltyInfo(uint256, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        if (config.fundsRecipient == address(0x0)) {
            return (config.fundsRecipient, 0);
        }
        return (
            config.fundsRecipient,
            (_salePrice * config.royaltyBPS) / 10_000
        );
    }

    /// @notice Sale details
    /// @return IZoraDrop.SaleDetails sale information details
    function saleDetails()
        external
        view
        returns (IZoraDrop.SaleDetails memory)
    {
        return
            IZoraDrop.SaleDetails({
                publicSaleActive: _publicSaleActive(),
                presaleActive: _presaleActive(),
                presaleStart: salesConfig.presaleStart,
                presaleEnd: salesConfig.presaleEnd,
                publicSaleStart: salesConfig.publicSaleStart,
                publicSaleEnd: salesConfig.publicSaleEnd,
                presaleMerkleRoot: salesConfig.presaleMerkleRoot,
                publicSalePrice: salesConfig.publicSalePrice,
                totalMinted: _totalMinted(),
                maxSupply: config.editionSize,
                maxSalePurchasePerAddress: salesConfig.maxSalePurchasePerAddress
            });
    }

    /// @dev Number of NFTs the user has minted per address
    /// @param minter to get counts for
    function mintedPerAddress(address minter)
        external
        view
        override
        returns (IZoraDrop.AddressMintDetails memory)
    {
        return
            IZoraDrop.AddressMintDetails({
                presaleMints: presaleMintsByAddress[minter],
                publicMints: _numberMinted(minter) -
                    presaleMintsByAddress[minter],
                totalMints: _numberMinted(minter)
            });
    }

    /// @dev Setup auto-approval for Zora v3 access to sell NFT
    ///      Still requires approval for module
    /// @param nftOwner owner of the nft
    /// @param operator operator wishing to transfer/burn/etc the NFTs
    function isApprovedForAll(address nftOwner, address operator)
        public
        view
        override(ERC721AUpgradeable)
        returns (bool)
    {
        if (operator == zoraERC721TransferHelper) {
            return true;
        }
        return super.isApprovedForAll(nftOwner, operator);
    }

    /// @dev Gets the zora fee for amount of withdraw
    /// @param amount amount of funds to get fee for
    function zoraFeeForAmount(uint256 amount)
        public
        returns (address payable, uint256)
    {
        (address payable recipient, uint256 bps) = zoraFeeManager
            .getZORAWithdrawFeesBPS(address(this));
        return (recipient, (amount * bps) / 10_000);
    }

    /**
     *** ---------------------------------- ***
     ***                                    ***
     ***     PUBLIC MINTING FUNCTIONS       ***
     ***                                    ***
     *** ---------------------------------- ***
     ***
     ***/

    /**
      @dev This allows the user to purchase a edition edition
           at the given price in the contract.
     */
    function purchase(uint256 quantity)
        external
        payable
        nonReentrant
        canMintTokens(quantity)
        onlyPublicSaleActive
        returns (uint256)
    {
        uint256 salePrice = salesConfig.publicSalePrice;

        require(msg.value == salePrice * quantity, "Wrong price");
        require(
            _numberMinted(_msgSender()) +
                quantity -
                presaleMintsByAddress[_msgSender()] <=
                salesConfig.maxSalePurchasePerAddress,
            TOO_MANY
        );

        _mintNFTs(_msgSender(), quantity);
        uint256 firstMintedTokenId = _lastMintedTokenId() - quantity;

        emit IZoraDrop.Sale({
            to: _msgSender(),
            quantity: quantity,
            pricePerToken: salePrice,
            firstPurchasedTokenId: firstMintedTokenId
        });
        return firstMintedTokenId;
    }

    /// @notice Function to mint NFTs
    /// @dev (important: Does not enforce max supply limit, enforce that limit earlier)
    /// @dev This batches in size of 8 as per recommended by ERC721A creators
    /// @param to address to mint NFTs to
    /// @param quantity number of NFTs to mint
    function _mintNFTs(address to, uint256 quantity) internal {
        do {
            uint256 toMint = quantity > MAX_MINT_BATCH_SIZE
                ? MAX_MINT_BATCH_SIZE
                : quantity;
            _mint({to: to, quantity: toMint, _data: "", safe: false});
            quantity -= toMint;
        } while (quantity > 0);
    }

    /// @notice Merkle-tree based presale purchase function
    /// @param quantity quantity to purchase
    /// @param maxQuantity max quantity that can be purchased via merkle proof #
    /// @param pricePerToken price that each token is purchased at
    /// @param merkleProof proof for presale mint
    function purchasePresale(
        uint256 quantity,
        uint256 maxQuantity,
        uint256 pricePerToken,
        bytes32[] calldata merkleProof
    )
        external
        payable
        nonReentrant
        canMintTokens(quantity)
        onlyPresaleActive
        returns (uint256)
    {
        require(
            MerkleProofUpgradeable.verify(
                merkleProof,
                salesConfig.presaleMerkleRoot,
                keccak256(
                    // address, uint256, uint256
                    abi.encode(msg.sender, maxQuantity, pricePerToken)
                )
            ),
            "Needs to be approved"
        );
        require(msg.value == pricePerToken * quantity, "Wrong price");

        presaleMintsByAddress[_msgSender()] += quantity;
        require(presaleMintsByAddress[_msgSender()] <= maxQuantity, TOO_MANY);

        _mintNFTs(_msgSender(), quantity);
        uint256 firstMintedTokenId = _lastMintedTokenId() - quantity;

        emit IZoraDrop.Sale({
            to: _msgSender(),
            quantity: quantity,
            pricePerToken: pricePerToken,
            firstPurchasedTokenId: firstMintedTokenId
        });

        return firstMintedTokenId;
    }

    /**
     *** ---------------------------------- ***
     ***                                    ***
     ***     ADMIN MINTING FUNCTIONS        ***
     ***                                    ***
     *** ---------------------------------- ***
     ***
     ***/

    /// @notice Mint admin
    /// @param recipient recipient to mint to
    /// @param quantity quantity to mint
    function adminMint(address recipient, uint256 quantity)
        external
        onlyRoleOrAdmin(MINTER_ROLE)
        canMintTokens(quantity)
        returns (uint256)
    {
        _mintNFTs(recipient, quantity);

        return _lastMintedTokenId();
    }

    /// @dev This mints multiple editions to the given list of addresses.
    /// @param recipients list of addresses to send the newly minted editions to
    function adminMintAirdrop(address[] calldata recipients)
        external
        override
        onlyRoleOrAdmin(MINTER_ROLE)
        canMintTokens(recipients.length)
        returns (uint256)
    {
        uint256 atId = _currentIndex;
        uint256 startAt = atId;

        unchecked {
            for (
                uint256 endAt = atId + recipients.length;
                atId < endAt;
                atId++
            ) {
                _mintNFTs(recipients[atId - startAt], 1);
            }
        }
        return _lastMintedTokenId();
    }

    /**
     *** ---------------------------------- ***
     ***                                    ***
     ***  ADMIN CONFIGURATION FUNCTIONS     ***
     ***                                    ***
     *** ---------------------------------- ***
     ***
     ***/

    /// @dev Set new owner for royalties / opensea
    /// @param newOwner new owner to set
    function setOwner(address newOwner) public onlyAdmin {
        _setOwner(newOwner);
    }

    /// @dev This sets the sales configuration
    /// @param newConfig new configuration to set for sales information
    function setDropSaleConfiguration(SalesConfiguration memory newConfig)
        external
        onlyAdmin
    {
        salesConfig = newConfig;
        emit SalesConfigChanged(_msgSender(), salesConfig);
    }

    /// @dev Set a different funds recipient
    /// @param newRecipientAddress new funds recipient address
    function setFundsRecipient(address payable newRecipientAddress)
        external
        onlyRoleOrAdmin(SALES_MANAGER_ROLE)
    {
        config.fundsRecipient = newRecipientAddress;
        emit FundsRecipientChanged(newRecipientAddress, _msgSender());
    }

    /// @dev This withdraws ETH from the contract to the contract owner.
    function withdraw() external nonReentrant {
        address sender = _msgSender();

        uint256 funds = address(this).balance;
        (address payable feeRecipient, uint256 zoraFee) = zoraFeeForAmount(
            funds
        );

        require(
            hasRole(DEFAULT_ADMIN_ROLE, sender) ||
                hasRole(SALES_MANAGER_ROLE, sender) ||
                sender == feeRecipient ||
                sender == config.fundsRecipient,
            "Does not have proper role to withdraw"
        );

        // No need for gas limit to trusted address.
        if (zoraFee > 0) {
            feeRecipient.sendValue(zoraFee);
            funds -= zoraFee;
        }
        // No need for gas limit to trusted address.
        config.fundsRecipient.sendValue(funds);
    }

    /// @notice Admin function to finalize and open edition sale
    function finalizeOpenEdition()
        external
        onlyRoleOrAdmin(SALES_MANAGER_ROLE)
    {
        require(config.editionSize == type(uint64).max, "Not open edition");
        config.editionSize = uint64(_totalMinted());
        emit OpenMintFinalized(_msgSender(), config.editionSize);
    }

    /**
     *** ---------------------------------- ***
     ***                                    ***
     ***      GENERAL GETTER FUNCTIONS      ***
     ***                                    ***
     *** ---------------------------------- ***
     ***
     ***/

    /// @notice Simple override for owner interface.
    /// @return user owner address
    function owner()
        public
        view
        override(OwnableSkeleton, IZoraDrop)
        returns (address)
    {
        return super.owner();
    }

    /// @notice Contract URI Getter, proxies to metadataRenderer
    /// @return Contract URI
    function contractURI() external view returns (string memory) {
        return config.metadataRenderer.contractURI();
    }

    /// @notice Getter for metadataRenderer contract
    function metadataRenderer() external view returns (IMetadataRenderer) {
        return IMetadataRenderer(config.metadataRenderer);
    }

    /// @notice Token URI Getter, proxies to metadataRenderer
    /// @param tokenId id of token to get URI for
    /// @return Token URI
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return config.metadataRenderer.tokenURI(tokenId);
    }

    /// @notice ERC165 supports interface
    /// @param interfaceId interface id to check if supported
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(
            IERC165Upgradeable,
            ERC721AUpgradeable,
            AccessControlUpgradeable
        )
        returns (bool)
    {
        return
            super.supportsInterface(interfaceId) ||
            type(IOwnable).interfaceId == interfaceId ||
            type(IERC2981Upgradeable).interfaceId == interfaceId ||
            type(IZoraDrop).interfaceId == interfaceId;
    }
}
