// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {IERC2981Upgradeable, IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

import {IZoraFeeManager} from "./interfaces/IZoraFeeManager.sol";
import {IMetadataRenderer} from "./interfaces/IMetadataRenderer.sol";
import {IEditionSingleMintable} from "./interfaces/IEditionSingleMintable.sol";
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
contract ZoraNFTBase is
    ERC721Upgradeable,
    IEditionSingleMintable,
    IERC2981Upgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    OwnableSkeleton
{
    using AddressUpgradeable for address payable;

    event PriceChanged(uint256 indexed amount);
    event FundsRecipientChanged(address indexed newAddress);

    /// @notice Error string constants
    string private constant SOLD_OUT = "Sold out";
    string private constant TOO_MANY = "Too many";

    /// @notice Access control roles
    bytes32 public immutable MINTER_ROLE = keccak256("MINTER");
    bytes32 public immutable SALES_MANAGER_ROLE = keccak256("SALES_MANAGER");

    /// @notice General configuration for NFT Minting and bookkeeping
    struct Configuration {
        /// @dev Optional contract metadata address
        string contractURI;
        /// @dev Metadata renderer
        IMetadataRenderer metadataRenderer;
        /// @dev Current token id minted
        uint64 atEditionId;
        /// @dev Number of burned tokens
        uint64 numberBurned;
        /// @dev Total size of edition that can be minted
        uint64 editionSize;
        /// @dev Royalty amount in bps
        uint16 royaltyBPS;
        /// @dev Funds recipient for sale
        address payable fundsRecipient;
    }

    /// @notice Sales states and configuration
    struct SalesConfiguration {
        /// @dev Is the public sale active
        bool publicSaleActive;
        /// @dev Is the presale active
        bool presaleActive;
        /// @dev Is the public sale active
        uint64 publicSalePrice;
        /// @dev Private sale price
        uint64 privateSalePrice;
        /// @dev Max purchase number per txn
        uint32 maxPurchasePerTransaction;
        /// @dev Presale sale price
        bytes32 presaleMerkleRoot;
    }

    /// @notice Configuration for NFT minting contract storage
    Configuration public config;

    /// @notice Sales configuration
    SalesConfiguration public salesConfig;

    /// @dev ZORA V3 transfer helper address for auto-approval
    address private immutable zoraERC721TransferHelper;

    /// @dev Mapping for contract mint protection
    mapping(address => uint256) private mintedByContract;

    /// @dev Zora Fee Manager Address
    IZoraFeeManager public immutable zoraFeeManager;

    /// @notice Only allow for users with admin access
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Only admin allowed");

        _;
    }

    /// @notice Feature for contract mint guard
    modifier contractMintGuard(uint256 mintedNumber) {
        if (tx.origin != msg.sender) {
            mintedByContract[tx.origin] += mintedNumber;
            require(
                mintedByContract[tx.origin] <=
                    salesConfig.maxPurchasePerTransaction,
                "Too many mints from contract"
            );
        }

        _;
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

    /// @notice Admin function to update contractURI
    /// @param newContractURI new contract uri
    function updateContractURI(string memory newContractURI)
        external
        onlyAdmin
    {
        config.contractURI = newContractURI;
    }

    ///  @param _owner User that owns and can mint the edition, gets royalty and sales payouts and can update the base url if needed.
    ///  @param _fundsRecipient Wallet/user that receives funds from sale
    ///  @param _editionSize Number of editions that can be minted in total. If 0, unlimited editions can be minted.
    ///  @param _royaltyBPS BPS of the royalty set on the contract. Can be 0 for no royalty.
    ///  @dev Function to create a new edition. Can only be called by the allowed creator
    ///       Sets the only allowed minter to the address that creates/owns the edition.
    ///       This can be re-assigned or updated later
    function initialize(
        string memory _name,
        string memory _symbol,
        address _owner,
        address payable _fundsRecipient,
        uint64 _editionSize,
        uint16 _royaltyBPS,
        IMetadataRenderer _metadataRenderer
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __AccessControl_init();
        // Setup the owner role
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        // Set ownership to original sender of contract call
        _setOwner(_owner);

        require(
            config.royaltyBPS < 50_01,
            "Royalty BPS cannot be greater than 50%"
        );

        config.atEditionId = 1;
        config.editionSize = _editionSize;
        config.metadataRenderer = _metadataRenderer;
        config.royaltyBPS = _royaltyBPS;
        config.fundsRecipient = _fundsRecipient;
    }

    /// @dev Getter for admin role associated with the contract to handle metadata
    /// @return boolean if address is admin
    function isAdmin(address user) external view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, user);
    }

    /// @dev returns the number of minted tokens within the edition
    /// @return Total NFT Supply
    function totalSupply() public view returns (uint256) {
        unchecked {
            return config.atEditionId - config.numberBurned - 1;
        }
    }

    /// @param tokenId Token ID to burn
    /// @notice User burn function for token id
    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Not approved");
        unchecked {
            ++config.numberBurned;
        }
        _burn(tokenId);
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

    function saleDetails()
        external
        view
        returns (IEditionSingleMintable.SaleDetails memory)
    {
        return
            IEditionSingleMintable.SaleDetails({
                active: salesConfig.maxPurchasePerTransaction > 0 &&
                    salesConfig.publicSalePrice > 0,
                price: salesConfig.publicSalePrice,
                totalMinted: config.atEditionId - 1,
                maxSupply: config.editionSize
            });
    }

    /// @dev Setup auto-approval for Zora v3 access to sell NFT
    ///      Still requires approval for module
    function isApprovedForAll(address nftOwner, address operator)
        public
        view
        override(ERC721Upgradeable)
        returns (bool)
    {
        if (operator == zoraERC721TransferHelper) {
            return true;
        }
        return super.isApprovedForAll(nftOwner, operator);
    }

    /** PUBLIC MINTING FUNCTIONS */

    /**
      @dev This allows the user to purchase a edition edition
           at the given price in the contract.
      @dev no need for re-entrancy guard since no safe_xxx functions are used
     */
    function purchase(uint256 quantity)
        external
        payable
        contractMintGuard(quantity)
        returns (uint256)
    {
        uint256 salePrice = salesConfig.publicSalePrice;
        require(salePrice > 0, "Not for sale");
        require(quantity <= salesConfig.maxPurchasePerTransaction, TOO_MANY);
        address mintToAddress = msg.sender;
        require(msg.value == salePrice * quantity, "Wrong price");
        uint256 endId = _mintMultiple(mintToAddress, quantity);
        emit IEditionSingleMintable.Sale(mintToAddress, quantity, salePrice);
        return endId;
    }

    function purchasePresale(uint256 quantity, bytes32[] memory merkleProof)
        external
    {
        // MerkleProofUpgradeable.verifyProof(merkleProof)
    }

    // curator of drops
    // matt & kolber

    // add merkle-style allowlist
    // v2
    // add signature based allowlist?

    /** ADMIN MINTING FUNCTIONS */

    function mint(address recipient, uint256 quantity)
        external
        onlyRoleOrAdmin(MINTER_ROLE)
        returns (uint256)
    {
        return _mintMultiple(recipient, quantity);
    }

    function _mintMultiple(address recipient, uint256 quantity)
        internal
        returns (uint256)
    {
        uint256 startAt = config.atEditionId;
        uint256 atEditionId = config.atEditionId;
        require(quantity < config.editionSize, TOO_MANY);

        unchecked {
            uint256 endAt = startAt + quantity;
            require(
                // endAt = 1 indexed // config.editionSize = 0 indexed
                endAt < config.editionSize || config.editionSize == 0,
                SOLD_OUT
            );
            for (; atEditionId < endAt; ) {
                _mint(recipient, atEditionId);
                ++atEditionId;
            }
        }

        // Store updated at edition
        _updateEditionId(atEditionId);

        return atEditionId;
    }

    /// @dev Private function to mint als without any access checks.
    ///      Called by the public edition minting functions.
    function _mintAirdrop(address[] memory recipients)
        internal
        returns (uint256)
    {
        uint256 startAt = config.atEditionId;
        uint256 atEditionId = config.atEditionId;
        uint256 endAt = startAt + recipients.length;
        require(
            endAt < config.editionSize || config.editionSize == 0,
            SOLD_OUT
        );

        for (; atEditionId < endAt; ) {
            _mint(recipients[atEditionId - startAt], atEditionId);
            unchecked {
                ++atEditionId;
            }
        }
        _updateEditionId(atEditionId);
        return atEditionId;
    }

    function _updateEditionId(uint256 newId) internal {
        require(newId < type(uint64).max, "Overflow");
        config.atEditionId = uint64(newId);
    }

    /// @dev Set new owner for royalties / opensea
    /// @param newOwner new owner to set
    function setOwner(address newOwner) public onlyAdmin {
        _setOwner(newOwner);
    }

    /// @param _salePrice if sale price is 0 sale is stopped, otherwise that amount
    ///                   of ETH is needed to start the sale.
    ///  @dev This sets a simple ETH sales price
    ///       Setting a sales price allows users to mint the edition until it sells out.
    ///       For more granular sales, use an external sales contract.
    function setSalePrice(uint256 _salePrice, uint8 _maxPurchasePerTransaction)
        external
        onlyAdmin
    {
        salesConfig.publicSalePrice = uint64(_salePrice);
        salesConfig.maxPurchasePerTransaction = _maxPurchasePerTransaction;
        emit PriceChanged(_salePrice);
    }

    /// @dev Set a different funds recipient
    function setFundsRecipient(address payable newRecipientAddress)
        external
        onlyRoleOrAdmin(SALES_MANAGER_ROLE)
    {
        config.fundsRecipient = newRecipientAddress;
        emit FundsRecipientChanged(newRecipientAddress);
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

    /// @dev This withdraws ETH from the contract to the contract owner.
    function withdraw()
        external
        onlyRoleOrAdmin(SALES_MANAGER_ROLE)
        nonReentrant
    {
        uint256 funds = address(this).balance;
        (address payable feeRecipient, uint256 zoraFee) = zoraFeeForAmount(
            funds
        );

        // No need for gas limit to trusted address.
        feeRecipient.sendValue(zoraFee);
        funds -= zoraFee;
        // No need for gas limit to trusted address.
        config.fundsRecipient.sendValue(funds);
    }

    /// @param recipients list of addresses to send the newly minted editions to
    /// @dev This mints multiple editions to the given list of addresses.
    function mintAirdrop(address[] calldata recipients)
        external
        override
        onlyRoleOrAdmin(MINTER_ROLE)
        returns (uint256)
    {
        return _mintAirdrop(recipients);
    }

    /// Simple override for owner interface.
    /// @return user owner address
    function owner()
        public
        view
        override(OwnableSkeleton, IEditionSingleMintable)
        returns (address)
    {
        return super.owner();
    }

    /// @notice Contract URI Getter, proxies to metadataRenderer
    /// @return Contract URI
    function contractURI() external view returns (string memory) {
        return config.metadataRenderer.contractURI(address(this));
    }

    /// @notice Token URI Getter, proxies to metadataRenderer
    /// @return Token URI
    function tokenURI(uint256 tokenURI) external view returns (string memory) {
        return config.metadataRenderer.contractURI(address(this), tokenURI);
    }

    /// @notice ERC165 supports interface
    /// @param interfaceId interface id to check if supported
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(
            IERC165Upgradeable,
            ERC721Upgradeable,
            AccessControlUpgradeable
        )
        returns (bool)
    {
        return
            super.supportsInterface(interfaceId) ||
            type(IOwnable).interfaceId == interfaceId ||
            type(IERC2981Upgradeable).interfaceId == interfaceId;
    }
}
