// SPDX-License-Identifier: MIT
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
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC721Upgradeable.sol";
import {IERC721AUpgradeable} from "erc721a-upgradeable/IERC721AUpgradeable.sol";
import {IERC2981Upgradeable, IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IMetadataRenderer} from "./interfaces/IMetadataRenderer.sol";
import {IOperatorFilterRegistry} from "./interfaces/IOperatorFilterRegistry.sol";
import {IERC721Drop} from "./interfaces/IERC721Drop.sol";
import {IOwnable} from "./interfaces/IOwnable.sol";
import {IERC4906} from "./interfaces/IERC4906.sol";
import {IFactoryUpgradeGate} from "./interfaces/IFactoryUpgradeGate.sol";
import {OwnableSkeleton} from "./utils/OwnableSkeleton.sol";
import {FundsReceiver} from "./utils/FundsReceiver.sol";
import {Version} from "./utils/Version.sol";
import {PublicMulticall} from "./utils/PublicMulticall.sol";
import {ERC721DropStorageV1} from "./storage/ERC721DropStorageV1.sol";

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
    UUPSUpgradeable,
    IERC2981Upgradeable,
    IERC4906,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    IERC721Drop,
    PublicMulticall,
    OwnableSkeleton,
    FundsReceiver,
    Version(12),
    ERC721DropStorageV1
{
    /// @dev This is the max mint batch size for the optimized ERC721A mint contract
    uint256 internal immutable MAX_MINT_BATCH_SIZE = 8;

    /// @dev Gas limit to send funds
    uint256 internal immutable FUNDS_SEND_GAS_LIMIT = 210_000;

    /// @notice Access control roles
    bytes32 public immutable MINTER_ROLE = keccak256("MINTER");
    bytes32 public immutable SALES_MANAGER_ROLE = keccak256("SALES_MANAGER");

    /// @dev ZORA V3 transfer helper address for auto-approval
    address public immutable zoraERC721TransferHelper;

    /// @dev Factory upgrade gate
    IFactoryUpgradeGate public immutable factoryUpgradeGate;

    /// @notice Zora Mint Fee
    uint256 private immutable ZORA_MINT_FEE;

    /// @notice Mint Fee Recipient
    address payable private immutable ZORA_MINT_FEE_RECIPIENT;

    /// @notice Max royalty BPS
    uint16 constant MAX_ROYALTY_BPS = 50_00;

    // /// @notice Empty string for blank comments
    // string constant EMPTY_STRING = "";

    /// @notice Market filter DAO address for opensea filter registry
    address public immutable marketFilterDAOAddress;

    IOperatorFilterRegistry immutable operatorFilterRegistry =
        IOperatorFilterRegistry(0x000000000000AAeB6D7670E522A718067333cd4E);

    /// @notice Only allow for users with admin access
    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert Access_OnlyAdmin();
        }

        _;
    }

    /// @notice Only a given role has access or admin
    /// @param role role to check for alongside the admin role
    modifier onlyRoleOrAdmin(bytes32 role) {
        if (
            !hasRole(DEFAULT_ADMIN_ROLE, _msgSender()) &&
            !hasRole(role, _msgSender())
        ) {
            revert Access_MissingRoleOrAdmin(role);
        }

        _;
    }

    /// @notice Allows user to mint tokens at a quantity
    modifier canMintTokens(uint256 quantity) {
        if (quantity + _totalMinted() > config.editionSize) {
            revert Mint_SoldOut();
        }

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
        if (!_presaleActive()) {
            revert Presale_Inactive();
        }

        _;
    }

    /// @notice Public sale active
    modifier onlyPublicSaleActive() {
        if (!_publicSaleActive()) {
            revert Sale_Inactive();
        }

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

    /// @notice Global constructor – these variables will not change with further proxy deploys
    /// @dev Marked as an initializer to prevent storage being used of base implementation. Can only be init'd by a proxy.
    /// @param _zoraERC721TransferHelper Transfer helper
    /// @param _factoryUpgradeGate Factory upgrade gate address
    /// @param _marketFilterDAOAddress Market filter DAO address
    /// @param _mintFeeAmount Mint fee amount in wei
    /// @param _mintFeeRecipient Mint fee recipient address
    constructor(
        address _zoraERC721TransferHelper,
        IFactoryUpgradeGate _factoryUpgradeGate,
        address _marketFilterDAOAddress,
        uint256 _mintFeeAmount,
        address payable _mintFeeRecipient
    ) initializer {
        zoraERC721TransferHelper = _zoraERC721TransferHelper;
        factoryUpgradeGate = _factoryUpgradeGate;
        marketFilterDAOAddress = _marketFilterDAOAddress;
        ZORA_MINT_FEE = _mintFeeAmount;
        ZORA_MINT_FEE_RECIPIENT = _mintFeeRecipient;
    }

    ///  @dev Create a new drop contract
    ///  @param _contractName Contract name
    ///  @param _contractSymbol Contract symbol
    ///  @param _initialOwner User that owns and can mint the edition, gets royalty and sales payouts and can update the base url if needed.
    ///  @param _fundsRecipient Wallet/user that receives funds from sale
    ///  @param _editionSize Number of editions that can be minted in total. If type(uint64).max, unlimited editions can be minted as an open edition.
    ///  @param _royaltyBPS BPS of the royalty set on the contract. Can be 0 for no royalty.
    ///  @param _setupCalls Bytes-encoded list of setup multicalls
    ///  @param _metadataRenderer Renderer contract to use
    ///  @param _metadataRendererInit Renderer data initial contract
    function initialize(
        string memory _contractName,
        string memory _contractSymbol,
        address _initialOwner,
        address payable _fundsRecipient,
        uint64 _editionSize,
        uint16 _royaltyBPS,
        bytes[] calldata _setupCalls,
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

        if (_setupCalls.length > 0) {
            // Setup temporary role
            _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
            // Execute setupCalls
            multicall(_setupCalls);
            // Remove temporary role
            _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }

        if (config.royaltyBPS > MAX_ROYALTY_BPS) {
            revert Setup_RoyaltyPercentageTooHigh(MAX_ROYALTY_BPS);
        }

        // Setup config variables
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

    /// @notice Connects this contract to the factory upgrade gate
    /// @param newImplementation proposed new upgrade implementation
    /// @dev Only can be called by admin
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyAdmin
    {
        if (
            !factoryUpgradeGate.isValidUpgradePath({
                _newImpl: newImplementation,
                _currentImpl: _getImplementation()
            })
        ) {
            revert Admin_InvalidUpgradeAddress(newImplementation);
        }
    }

    //        ,-.
    //        `-'
    //        /|\
    //         |             ,----------.
    //        / \            |ERC721Drop|
    //      Caller           `----+-----'
    //        |       burn()      |
    //        | ------------------>
    //        |                   |
    //        |                   |----.
    //        |                   |    | burn token
    //        |                   |<---'
    //      Caller           ,----+-----.
    //        ,-.            |ERC721Drop|
    //        `-'            `----------'
    //        /|\
    //         |
    //        / \
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
        if (config.fundsRecipient == address(0)) {
            return (config.fundsRecipient, 0);
        }
        return (
            config.fundsRecipient,
            (_salePrice * config.royaltyBPS) / 10_000
        );
    }

    /// @notice Sale details
    /// @return IERC721Drop.SaleDetails sale information details
    function saleDetails()
        external
        view
        returns (IERC721Drop.SaleDetails memory)
    {
        return
            IERC721Drop.SaleDetails({
                publicSaleActive: _publicSaleActive(),
                presaleActive: _presaleActive(),
                publicSalePrice: salesConfig.publicSalePrice,
                publicSaleStart: salesConfig.publicSaleStart,
                publicSaleEnd: salesConfig.publicSaleEnd,
                presaleStart: salesConfig.presaleStart,
                presaleEnd: salesConfig.presaleEnd,
                presaleMerkleRoot: salesConfig.presaleMerkleRoot,
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
        returns (IERC721Drop.AddressMintDetails memory)
    {
        return
            IERC721Drop.AddressMintDetails({
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
        override(IERC721Upgradeable, ERC721AUpgradeable)
        returns (bool)
    {
        if (operator == zoraERC721TransferHelper) {
            return true;
        }
        return super.isApprovedForAll(nftOwner, operator);
    }

    /// @notice ZORA fee is fixed now per mint
    /// @dev Gets the zora fee for amount of withdraw
    function zoraFeeForAmount(uint256 quantity)
        public
        view
        returns (address payable recipient, uint256 fee)
    {
        recipient = ZORA_MINT_FEE_RECIPIENT;
        fee = ZORA_MINT_FEE * quantity;
    }

    /**
     *** ---------------------------------- ***
     ***                                    ***
     ***     PUBLIC MINTING FUNCTIONS       ***
     ***                                    ***
     *** ---------------------------------- ***
     ***/

    //                       ,-.
    //                       `-'
    //                       /|\
    //                        |                       ,----------.
    //                       / \                      |ERC721Drop|
    //                     Caller                     `----+-----'
    //                       |          purchase()         |
    //                       | ---------------------------->
    //                       |                             |
    //                       |                             |
    //          ___________________________________________________________
    //          ! ALT  /  drop has no tokens left for caller to mint?      !
    //          !_____/      |                             |               !
    //          !            |    revert Mint_SoldOut()    |               !
    //          !            | <----------------------------               !
    //          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                             |
    //                       |                             |
    //          ___________________________________________________________
    //          ! ALT  /  public sale isn't active?        |               !
    //          !_____/      |                             |               !
    //          !            |    revert Sale_Inactive()   |               !
    //          !            | <----------------------------               !
    //          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                             |
    //                       |                             |
    //          ___________________________________________________________
    //          ! ALT  /  inadequate funds sent?           |               !
    //          !_____/      |                             |               !
    //          !            | revert Purchase_WrongPrice()|               !
    //          !            | <----------------------------               !
    //          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                             |
    //                       |                             |----.
    //                       |                             |    | mint tokens
    //                       |                             |<---'
    //                       |                             |
    //                       |                             |----.
    //                       |                             |    | emit IERC721Drop.Sale()
    //                       |                             |<---'
    //                       |                             |
    //                       | return first minted token ID|
    //                       | <----------------------------
    //                     Caller                     ,----+-----.
    //                       ,-.                      |ERC721Drop|
    //                       `-'                      `----------'
    //                       /|\
    //                        |
    //                       / \
    /**
      @dev This allows the user to purchase a edition edition
           at the given price in the contract.
     */
    /// @notice Purchase a quantity of tokens
    /// @param quantity quantity to purchase
    /// @return tokenId of the first token minted
    function purchase(uint256 quantity)
        external
        payable
        nonReentrant
        canMintTokens(quantity)
        onlyPublicSaleActive
        returns (uint256)
    {
        return _handlePurchase(quantity, "");
    }

    /// @notice Purchase a quantity of tokens with a comment
    /// @param quantity quantity to purchase
    /// @param comment comment to include in the IERC721Drop.Sale event
    /// @return tokenId of the first token minted
    function purchaseWithComment(uint256 quantity, string calldata comment)
        external
        payable
        nonReentrant
        canMintTokens(quantity)
        onlyPublicSaleActive
        returns (uint256)
    {
        return _handlePurchase(quantity, comment);
    }

    function _handlePurchase(uint256 quantity, string memory comment) internal returns (uint256) {
        uint256 salePrice = salesConfig.publicSalePrice;

        if (msg.value != (salePrice + ZORA_MINT_FEE) * quantity) {
            revert Purchase_WrongPrice((salePrice + ZORA_MINT_FEE) * quantity);
        }

        // If max purchase per address == 0 there is no limit.
        // Any other number, the per address mint limit is that.
        if (
            salesConfig.maxSalePurchasePerAddress != 0 &&
            _numberMinted(_msgSender()) +
                quantity -
                presaleMintsByAddress[_msgSender()] >
            salesConfig.maxSalePurchasePerAddress
        ) {
            revert Purchase_TooManyForAddress();
        }

        _mintNFTs(_msgSender(), quantity);
        uint256 firstMintedTokenId = _lastMintedTokenId() - quantity;

        _payoutZoraFee(quantity);

        emit IERC721Drop.Sale({
            to: _msgSender(),
            quantity: quantity,
            pricePerToken: salePrice,
            firstPurchasedTokenId: firstMintedTokenId
        });
        if(bytes(comment).length > 0) {
            emit IERC721Drop.MintComment({
                sender: _msgSender(),
                tokenContract: address(this),
                tokenId: firstMintedTokenId,
                quantity: quantity,
                comment: comment
            });
        }
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
            _mint({to: to, quantity: toMint});
            quantity -= toMint;
        } while (quantity > 0);
    }

    //                       ,-.
    //                       `-'
    //                       /|\
    //                        |                             ,----------.
    //                       / \                            |ERC721Drop|
    //                     Caller                           `----+-----'
    //                       |         purchasePresale()         |
    //                       | ---------------------------------->
    //                       |                                   |
    //                       |                                   |
    //          _________________________________________________________________
    //          ! ALT  /  drop has no tokens left for caller to mint?            !
    //          !_____/      |                                   |               !
    //          !            |       revert Mint_SoldOut()       |               !
    //          !            | <----------------------------------               !
    //          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                                   |
    //                       |                                   |
    //          _________________________________________________________________
    //          ! ALT  /  presale sale isn't active?             |               !
    //          !_____/      |                                   |               !
    //          !            |     revert Presale_Inactive()     |               !
    //          !            | <----------------------------------               !
    //          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                                   |
    //                       |                                   |
    //          _________________________________________________________________
    //          ! ALT  /  merkle proof unapproved for caller?    |               !
    //          !_____/      |                                   |               !
    //          !            | revert Presale_MerkleNotApproved()|               !
    //          !            | <----------------------------------               !
    //          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                                   |
    //                       |                                   |
    //          _________________________________________________________________
    //          ! ALT  /  inadequate funds sent?                 |               !
    //          !_____/      |                                   |               !
    //          !            |    revert Purchase_WrongPrice()   |               !
    //          !            | <----------------------------------               !
    //          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                                   |
    //                       |                                   |----.
    //                       |                                   |    | mint tokens
    //                       |                                   |<---'
    //                       |                                   |
    //                       |                                   |----.
    //                       |                                   |    | emit IERC721Drop.Sale()
    //                       |                                   |<---'
    //                       |                                   |
    //                       |    return first minted token ID   |
    //                       | <----------------------------------
    //                     Caller                           ,----+-----.
    //                       ,-.                            |ERC721Drop|
    //                       `-'                            `----------'
    //                       /|\
    //                        |
    //                       / \
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
        return _handlePurchasePresale(quantity, maxQuantity, pricePerToken, merkleProof, "");
    }

    /// @notice Merkle-tree based presale purchase function with a comment
    /// @param quantity quantity to purchase
    /// @param maxQuantity max quantity that can be purchased via merkle proof #
    /// @param pricePerToken price that each token is purchased at
    /// @param merkleProof proof for presale mint
    /// @param comment comment to include in the IERC721Drop.Sale event
    function purchasePresaleWithComment(
        uint256 quantity,
        uint256 maxQuantity,
        uint256 pricePerToken,
        bytes32[] calldata merkleProof,
        string calldata comment
    )
        external
        payable
        nonReentrant
        canMintTokens(quantity)
        onlyPresaleActive
        returns (uint256)
    {
        return _handlePurchasePresale(quantity, maxQuantity, pricePerToken, merkleProof, comment);
    }

    function _handlePurchasePresale(
        uint256 quantity,
        uint256 maxQuantity,
        uint256 pricePerToken,
        bytes32[] calldata merkleProof,
        string memory comment
    ) internal returns (uint256) {
        if (
            !MerkleProofUpgradeable.verify(
                merkleProof,
                salesConfig.presaleMerkleRoot,
                keccak256(
                    // address, uint256, uint256
                    abi.encode(_msgSender(), maxQuantity, pricePerToken)
                )
            )
        ) {
            revert Presale_MerkleNotApproved();
        }

        if (msg.value != (pricePerToken + ZORA_MINT_FEE) * quantity) {
            revert Purchase_WrongPrice(
                (pricePerToken + ZORA_MINT_FEE) * quantity
            );
        }

        presaleMintsByAddress[_msgSender()] += quantity;
        if (presaleMintsByAddress[_msgSender()] > maxQuantity) {
            revert Presale_TooManyForAddress();
        }

        _mintNFTs(_msgSender(), quantity);
        uint256 firstMintedTokenId = _lastMintedTokenId() - quantity;

        _payoutZoraFee(quantity);

        emit IERC721Drop.Sale({
            to: _msgSender(),
            quantity: quantity,
            pricePerToken: pricePerToken,
            firstPurchasedTokenId: firstMintedTokenId
        });
        if (bytes(comment).length > 0) {
            emit IERC721Drop.MintComment({
                sender: _msgSender(),
                tokenContract: address(this),
                tokenId: firstMintedTokenId,
                quantity: quantity,
                comment: comment
            });
        }

        return firstMintedTokenId;
    }

    /**
     *** ---------------------------------- ***
     ***                                    ***
     ***     ADMIN OPERATOR FILTERING       ***
     ***                                    ***
     *** ---------------------------------- ***
     ***/

    /// @notice Proxy to update market filter settings in the main registry contracts
    /// @notice Requires admin permissions
    /// @param args Calldata args to pass to the registry
    function updateMarketFilterSettings(bytes calldata args)
        external
        onlyAdmin
        returns (bytes memory)
    {
        (bool success, bytes memory ret) = address(operatorFilterRegistry).call(
            args
        );
        if (!success) {
            revert RemoteOperatorFilterRegistryCallFailed();
        }
        return ret;
    }

    /// @notice Manage subscription to the DAO for marketplace filtering based off royalty payouts.
    /// @param enable Enable filtering to non-royalty payout marketplaces
    function manageMarketFilterDAOSubscription(bool enable) external onlyAdmin {
        address self = address(this);
        if (marketFilterDAOAddress == address(0x0)) {
            revert MarketFilterDAOAddressNotSupportedForChain();
        }
        if (!operatorFilterRegistry.isRegistered(self) && enable) {
            operatorFilterRegistry.registerAndSubscribe(
                self,
                marketFilterDAOAddress
            );
        } else if (enable) {
            operatorFilterRegistry.subscribe(self, marketFilterDAOAddress);
        } else {
            operatorFilterRegistry.unsubscribe(self, false);
            operatorFilterRegistry.unregister(self);
        }
    }

    /// @notice Hook to filter operators (no-op if no filters are registered)
    /// @dev Part of ERC721A token hooks
    /// @param from Transfer from user
    /// @param to Transfer to user
    /// @param startTokenId Token ID to start with
    /// @param quantity Quantity of token being transferred
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override {
        if (
            from != address(0) && // skip on mints
            from != msg.sender // skip on transfers from sender
        ) {
            if (
                !operatorFilterRegistry.isOperatorAllowed(
                    address(this),
                    msg.sender
                )
            ) {
                revert OperatorNotAllowed(msg.sender);
            }
        }
    }

    /**
     *** ---------------------------------- ***
     ***                                    ***
     ***     ADMIN MINTING FUNCTIONS        ***
     ***                                    ***
     *** ---------------------------------- ***
     ***/

    //                       ,-.
    //                       `-'
    //                       /|\
    //                        |                             ,----------.
    //                       / \                            |ERC721Drop|
    //                     Caller                           `----+-----'
    //                       |            adminMint()            |
    //                       | ---------------------------------->
    //                       |                                   |
    //                       |                                   |
    //          _________________________________________________________________
    //          ! ALT  /  caller is not admin or minter role?    |               !
    //          !_____/      |                                   |               !
    //          !            | revert Access_MissingRoleOrAdmin()|               !
    //          !            | <----------------------------------               !
    //          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                                   |
    //                       |                                   |
    //          _________________________________________________________________
    //          ! ALT  /  drop has no tokens left for caller to mint?            !
    //          !_____/      |                                   |               !
    //          !            |       revert Mint_SoldOut()       |               !
    //          !            | <----------------------------------               !
    //          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                                   |
    //                       |                                   |----.
    //                       |                                   |    | mint tokens
    //                       |                                   |<---'
    //                       |                                   |
    //                       |    return last minted token ID    |
    //                       | <----------------------------------
    //                     Caller                           ,----+-----.
    //                       ,-.                            |ERC721Drop|
    //                       `-'                            `----------'
    //                       /|\
    //                        |
    //                       / \
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

    //                       ,-.
    //                       `-'
    //                       /|\
    //                        |                             ,----------.
    //                       / \                            |ERC721Drop|
    //                     Caller                           `----+-----'
    //                       |         adminMintAirdrop()        |
    //                       | ---------------------------------->
    //                       |                                   |
    //                       |                                   |
    //          _________________________________________________________________
    //          ! ALT  /  caller is not admin or minter role?    |               !
    //          !_____/      |                                   |               !
    //          !            | revert Access_MissingRoleOrAdmin()|               !
    //          !            | <----------------------------------               !
    //          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                                   |
    //                       |                                   |
    //          _________________________________________________________________
    //          ! ALT  /  drop has no tokens left for recipients to mint?        !
    //          !_____/      |                                   |               !
    //          !            |       revert Mint_SoldOut()       |               !
    //          !            | <----------------------------------               !
    //          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                                   |
    //                       |                                   |
    //                       |                    _____________________________________
    //                       |                    ! LOOP  /  for all recipients        !
    //                       |                    !______/       |                     !
    //                       |                    !              |----.                !
    //                       |                    !              |    | mint tokens    !
    //                       |                    !              |<---'                !
    //                       |                    !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                                   |
    //                       |    return last minted token ID    |
    //                       | <----------------------------------
    //                     Caller                           ,----+-----.
    //                       ,-.                            |ERC721Drop|
    //                       `-'                            `----------'
    //                       /|\
    //                        |
    //                       / \
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
     ***/

    //                       ,-.
    //                       `-'
    //                       /|\
    //                        |                    ,----------.
    //                       / \                   |ERC721Drop|
    //                     Caller                  `----+-----'
    //                       |        setOwner()        |
    //                       | ------------------------->
    //                       |                          |
    //                       |                          |
    //          ________________________________________________________
    //          ! ALT  /  caller is not admin?          |               !
    //          !_____/      |                          |               !
    //          !            | revert Access_OnlyAdmin()|               !
    //          !            | <-------------------------               !
    //          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                          |
    //                       |                          |----.
    //                       |                          |    | set owner
    //                       |                          |<---'
    //                     Caller                  ,----+-----.
    //                       ,-.                   |ERC721Drop|
    //                       `-'                   `----------'
    //                       /|\
    //                        |
    //                       / \
    /// @dev Set new owner for royalties / opensea
    /// @param newOwner new owner to set
    function setOwner(address newOwner) public onlyAdmin {
        _setOwner(newOwner);
    }

    /// @notice Set a new metadata renderer
    /// @param newRenderer new renderer address to use
    /// @param setupRenderer data to setup new renderer with
    function setMetadataRenderer(
        IMetadataRenderer newRenderer,
        bytes memory setupRenderer
    ) external onlyAdmin {
        config.metadataRenderer = newRenderer;

        if (setupRenderer.length > 0) {
            newRenderer.initializeWithData(setupRenderer);
        }

        emit UpdatedMetadataRenderer({
            sender: _msgSender(),
            renderer: newRenderer
        });

        _notifyMetadataUpdate();
    }

    /// @notice Calls the metadata renderer contract to make an update and uses the EIP4906 event to notify
    /// @param data raw calldata to call the metadata renderer contract with.
    /// @dev Only accessible via an admin role
    function callMetadataRenderer(bytes memory data)
        public
        onlyAdmin
        returns (bytes memory)
    {
        (bool success, bytes memory response) = address(config.metadataRenderer)
            .call(data);
        if (!success) {
            revert ExternalMetadataRenderer_CallFailed();
        }
        _notifyMetadataUpdate();
        return response;
    }

    //                       ,-.
    //                       `-'
    //                       /|\
    //                        |                             ,----------.
    //                       / \                            |ERC721Drop|
    //                     Caller                           `----+-----'
    //                       |      setSalesConfiguration()      |
    //                       | ---------------------------------->
    //                       |                                   |
    //                       |                                   |
    //          _________________________________________________________________
    //          ! ALT  /  caller is not admin?                   |               !
    //          !_____/      |                                   |               !
    //          !            | revert Access_MissingRoleOrAdmin()|               !
    //          !            | <----------------------------------               !
    //          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                                   |
    //                       |                                   |----.
    //                       |                                   |    | set funds recipient
    //                       |                                   |<---'
    //                       |                                   |
    //                       |                                   |----.
    //                       |                                   |    | emit FundsRecipientChanged()
    //                       |                                   |<---'
    //                     Caller                           ,----+-----.
    //                       ,-.                            |ERC721Drop|
    //                       `-'                            `----------'
    //                       /|\
    //                        |
    //                       / \
    /// @dev This sets the sales configuration
    /// @param publicSalePrice New public sale price
    /// @param maxSalePurchasePerAddress Max # of purchases (public) per address allowed
    /// @param publicSaleStart unix timestamp when the public sale starts
    /// @param publicSaleEnd unix timestamp when the public sale ends (set to 0 to disable)
    /// @param presaleStart unix timestamp when the presale starts
    /// @param presaleEnd unix timestamp when the presale ends
    /// @param presaleMerkleRoot merkle root for the presale information
    function setSaleConfiguration(
        uint104 publicSalePrice,
        uint32 maxSalePurchasePerAddress,
        uint64 publicSaleStart,
        uint64 publicSaleEnd,
        uint64 presaleStart,
        uint64 presaleEnd,
        bytes32 presaleMerkleRoot
    ) external onlyRoleOrAdmin(SALES_MANAGER_ROLE) {
        salesConfig.publicSalePrice = publicSalePrice;
        salesConfig.maxSalePurchasePerAddress = maxSalePurchasePerAddress;
        salesConfig.publicSaleStart = publicSaleStart;
        salesConfig.publicSaleEnd = publicSaleEnd;
        salesConfig.presaleStart = presaleStart;
        salesConfig.presaleEnd = presaleEnd;
        salesConfig.presaleMerkleRoot = presaleMerkleRoot;

        emit SalesConfigChanged(_msgSender());
    }

    //                       ,-.
    //                       `-'
    //                       /|\
    //                        |                    ,----------.
    //                       / \                   |ERC721Drop|
    //                     Caller                  `----+-----'
    //                       |        setOwner()        |
    //                       | ------------------------->
    //                       |                          |
    //                       |                          |
    //          ________________________________________________________
    //          ! ALT  /  caller is not admin or SALES_MANAGER_ROLE?    !
    //          !_____/      |                          |               !
    //          !            | revert Access_OnlyAdmin()|               !
    //          !            | <-------------------------               !
    //          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                          |
    //                       |                          |----.
    //                       |                          |    | set sales configuration
    //                       |                          |<---'
    //                       |                          |
    //                       |                          |----.
    //                       |                          |    | emit SalesConfigChanged()
    //                       |                          |<---'
    //                     Caller                  ,----+-----.
    //                       ,-.                   |ERC721Drop|
    //                       `-'                   `----------'
    //                       /|\
    //                        |
    //                       / \
    /// @notice Set a different funds recipient
    /// @param newRecipientAddress new funds recipient address
    function setFundsRecipient(address payable newRecipientAddress)
        external
        onlyRoleOrAdmin(SALES_MANAGER_ROLE)
    {
        // TODO(iain): funds recipient cannot be 0?
        config.fundsRecipient = newRecipientAddress;
        emit FundsRecipientChanged(newRecipientAddress, _msgSender());
    }

    //                       ,-.                  ,-.                      ,-.
    //                       `-'                  `-'                      `-'
    //                       /|\                  /|\                      /|\
    //                        |                    |                        |                      ,----------.
    //                       / \                  / \                      / \                     |ERC721Drop|
    //                     Caller            FeeRecipient            FundsRecipient                `----+-----'
    //                       |                    |           withdraw()   |                            |
    //                       | ------------------------------------------------------------------------->
    //                       |                    |                        |                            |
    //                       |                    |                        |                            |
    //          ________________________________________________________________________________________________________
    //          ! ALT  /  caller is not admin or manager?                  |                            |               !
    //          !_____/      |                    |                        |                            |               !
    //          !            |                    revert Access_WithdrawNotAllowed()                    |               !
    //          !            | <-------------------------------------------------------------------------               !
    //          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                    |                        |                            |
    //                       |                    |                   send fee amount                   |
    //                       |                    | <----------------------------------------------------
    //                       |                    |                        |                            |
    //                       |                    |                        |                            |
    //                       |                    |                        |             ____________________________________________________________
    //                       |                    |                        |             ! ALT  /  send unsuccesful?                                 !
    //                       |                    |                        |             !_____/        |                                            !
    //                       |                    |                        |             !              |----.                                       !
    //                       |                    |                        |             !              |    | revert Withdraw_FundsSendFailure()    !
    //                       |                    |                        |             !              |<---'                                       !
    //                       |                    |                        |             !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                    |                        |             !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                    |                        |                            |
    //                       |                    |   foundry.toml                     | send remaining funds amount|
    //                       |                    |                        | <---------------------------
    //                       |                    |                        |                            |
    //                       |                    |                        |                            |
    //                       |                    |                        |             ____________________________________________________________
    //                       |                    |                        |             ! ALT  /  send unsuccesful?                                 !
    //                       |                    |                        |             !_____/        |                                            !
    //                       |                    |                        |             !              |----.                                       !
    //                       |                    |                        |             !              |    | revert Withdraw_FundsSendFailure()    !
    //                       |                    |                        |             !              |<---'                                       !
    //                       |                    |                        |             !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                    |                        |             !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                     Caller            FeeRecipient            FundsRecipient                ,----+-----.
    //                       ,-.                  ,-.                      ,-.                     |ERC721Drop|
    //                       `-'                  `-'                      `-'                     `----------'
    //                       /|\                  /|\                      /|\
    //                        |                    |                        |
    //                       / \                  / \                      / \
    /// @notice This withdraws ETH from the contract to the contract owner.
    function withdraw() external nonReentrant {
        address sender = _msgSender();

        uint256 funds = address(this).balance;

        // Check if withdraw is allowed for sender
        if (
            !hasRole(DEFAULT_ADMIN_ROLE, sender) &&
            !hasRole(SALES_MANAGER_ROLE, sender) &&
            sender != config.fundsRecipient
        ) {
            revert Access_WithdrawNotAllowed();
        }

        // Payout recipient
        (bool successFunds, ) = config.fundsRecipient.call{
            value: funds,
            gas: FUNDS_SEND_GAS_LIMIT
        }("");
        if (!successFunds) {
            revert Withdraw_FundsSendFailure();
        }

        // Emit event for indexing
        emit FundsWithdrawn(
            _msgSender(),
            config.fundsRecipient,
            funds,
            address(0),
            0
        );
    }

    //                       ,-.
    //                       `-'
    //                       /|\
    //                        |                             ,----------.
    //                       / \                            |ERC721Drop|
    //                     Caller                           `----+-----'
    //                       |       finalizeOpenEdition()       |
    //                       | ---------------------------------->
    //                       |                                   |
    //                       |                                   |
    //          _________________________________________________________________
    //          ! ALT  /  caller is not admin or SALES_MANAGER_ROLE?             !
    //          !_____/      |                                   |               !
    //          !            | revert Access_MissingRoleOrAdmin()|               !
    //          !            | <----------------------------------               !
    //          !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //          !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                                   |
    //                       |                                   |
    //                       |                    _______________________________________________________________________
    //                       |                    ! ALT  /  drop is not an open edition?                                 !
    //                       |                    !_____/        |                                                       !
    //                       |                    !              |----.                                                  !
    //                       |                    !              |    | revert Admin_UnableToFinalizeNotOpenEdition()    !
    //                       |                    !              |<---'                                                  !
    //                       |                    !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                    !~[noop]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
    //                       |                                   |
    //                       |                                   |----.
    //                       |                                   |    | set config edition size
    //                       |                                   |<---'
    //                       |                                   |
    //                       |                                   |----.
    //                       |                                   |    | emit OpenMintFinalized()
    //                       |                                   |<---'
    //                     Caller                           ,----+-----.
    //                       ,-.                            |ERC721Drop|
    //                       `-'                            `----------'
    //                       /|\
    //                        |
    //                       / \
    /// @notice Admin function to finalize and open edition sale
    function finalizeOpenEdition()
        external
        onlyRoleOrAdmin(SALES_MANAGER_ROLE)
    {
        if (config.editionSize != type(uint64).max) {
            revert Admin_UnableToFinalizeNotOpenEdition();
        }

        config.editionSize = uint64(_totalMinted());
        emit OpenMintFinalized(_msgSender(), config.editionSize);
    }

    /**
     *** ---------------------------------- ***
     ***                                    ***
     ***      GENERAL GETTER FUNCTIONS      ***
     ***                                    ***
     *** ---------------------------------- ***
     ***/

    /// @notice Simple override for owner interface.
    /// @return user owner address
    function owner()
        public
        view
        override(OwnableSkeleton, IERC721Drop)
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
        if (!_exists(tokenId)) {
            revert IERC721AUpgradeable.URIQueryForNonexistentToken();
        }

        return config.metadataRenderer.tokenURI(tokenId);
    }

    /// @notice Internal function to notify that all metadata may/was updated in the update
    /// @dev Since we don't know what tokens were updated, most calls to a metadata renderer
    ///      update the metadata we can assume all tokens metadata changed
    function _notifyMetadataUpdate() internal {
        uint256 totalMinted = _totalMinted();

        // If we have tokens to notify about
        if (totalMinted > 0) {
            emit BatchMetadataUpdate(
                _startTokenId(),
                totalMinted + _startTokenId()
            );
        }
    }

    function _payoutZoraFee(uint256 quantity) internal {
        // Transfer ZORA fee to recipient
        (, uint256 zoraFee) = zoraFeeForAmount(quantity);
        (bool success, ) = ZORA_MINT_FEE_RECIPIENT.call{value: zoraFee, gas: FUNDS_SEND_GAS_LIMIT}(
            ""
        );
        emit MintFeePayout(zoraFee, ZORA_MINT_FEE_RECIPIENT, success);
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
            // Because the EIP-4906 spec is event-based a numerically relevant interfaceId is used.
            bytes4(0x49064906) == interfaceId ||
            type(IERC721Drop).interfaceId == interfaceId;
    }
}
