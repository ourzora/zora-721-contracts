// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import {IERC2981Upgradeable, IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {IZoraFeeManager} from "./interfaces/IZoraFeeManager.sol";
import {IMetadataRenderer} from "./interfaces/IMetadataRenderer.sol";
import {IEditionSingleMintable} from "./interfaces/IEditionSingleMintable.sol";
import {OwnableSkeleton} from "./OwnableSkeleton.sol";

contract ZoraMediaBase is
    ERC721Upgradeable,
    OwnableSkeleton,
    IEditionSingleMintable,
    IERC2981Upgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using AddressUpgradeable for address payable;

    event PriceChanged(uint256 indexed amount);
    event FundsRecipientChanged(address indexed newAddress);
    event Sale(uint256 indexed price, address indexed purchaser);

    bytes32 public immutable MINTER_ROLE = keccak256("MINTER");
    bytes32 public immutable FUNDS_RECIPIENT_MANAGER_ROLE =
        keccak256("FUNDS_RECIPIENT_MANAGER");

    string public contractURI;

    /// @dev Total size of edition that can be minted
    uint256 public editionSize;

    /// @dev Funds recipient for sale and royalties
    address payable public fundsRecipient;

    /// @dev Current token id minted
    CountersUpgradeable.Counter private atEditionId;

    /// @dev Number of burned tokens
    CountersUpgradeable.Counter private numberBurned;

    /// @dev Royalty amount in bps
    uint256 royaltyBPS;

    /// @dev Price for sale
    uint256 public salePrice;

    /// @dev Metadata renderer
    IMetadataRenderer public metadataRenderer;

    /// @dev ZORA V3 transfer helper address for auto-approval
    address private immutable zoraERC721TransferHelper;

    /// @dev Zora Fee Manager Address
    IZoraFeeManager public immutable zoraFeeManager;

    error OnlyAdminRequired();
    error OnlyRoleOrAdminRequired(bytes32 role);

    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert OnlyAdminRequired();
        }

        _;
    }

    modifier onlyRoleOrAdmin(bytes32 role) {
        if (
            !(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
                hasRole(role, msg.sender))
        ) {
            revert OnlyRoleOrAdminRequired(role);
        }

        _;
    }

    constructor(
        IZoraFeeManager _zoraFeeManager,
        address _zoraERC721TransferHelper
    ) {
        zoraFeeManager = _zoraFeeManager;
        zoraERC721TransferHelper = _zoraERC721TransferHelper;
    }

    function updateContractURI(string memory newContractURI)
        external
        onlyAdmin
    {
        contractURI = newContractURI;
    }

    /// Returns the number of editions allowed to mint (max_uint256 when open edition)
    function numberCanMint() public view override returns (uint256) {
        // Return max int if open edition
        if (editionSize == 0) {
            return type(uint256).max;
        }
        // atEditionId is one-indexed hence the need to remove one here
        return editionSize + 1 - atEditionId.current();
    }

    /**
      @param _owner User that owns and can mint the edition, gets royalty and sales payouts and can update the base url if needed.
      @param _fundsRecipient Wallet/user that receives funds from sale
      @param _editionSize Number of editions that can be minted in total. If 0, unlimited editions can be minted.
      @param _royaltyBPS BPS of the royalty set on the contract. Can be 0 for no royalty.
      @dev Function to create a new edition. Can only be called by the allowed creator
           Sets the only allowed minter to the address that creates/owns the edition.
           This can be re-assigned or updated later
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        address _owner,
        address payable _fundsRecipient,
        uint256 _editionSize,
        uint256 _royaltyBPS,
        IMetadataRenderer _metadataRenderer
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __AccessControl_init();
        // Set ownership to original sender of contract call
        _setOwner(_owner);
        // Set edition id start to be 1 not 0
        atEditionId.increment();

        _setFundsRecipient(_fundsRecipient);
        require(royaltyBPS < 50_01, "Royalty BPS cannot be greater than 50%");

        editionSize = _editionSize;
        royaltyBPS = _royaltyBPS;
        metadataRenderer = _metadataRenderer;
    }

    function isAdmin(address user) external view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, user);
    }

    /// @dev Set new owner for royalties / opensea
    /// @param newOwner new owner to set
    function setOwner(address newOwner) public onlyAdmin {
        _setOwner(newOwner);
    }

    /// @dev returns the number of minted tokens within the edition
    function totalSupply() public view returns (uint256) {
        return atEditionId.current() - numberBurned.current() - 1;
    }

    function numberMinted() public view returns (uint256) {
        return atEditionId.current() - 1;
    }

    /**
        @param tokenId Token ID to burn
        User burn function for token id 
     */
    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Not approved");
        numberBurned.increment();
        _burn(tokenId);
    }

    /// @dev Setup auto-approval for Zora v3 access to sell NFT
    /// Still requires approval for module
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

    /**
        Simple eth-based sales function
        More complex sales functions can be implemented through ISingleEditionMintable interface
     */

    /**
      @dev This allows the user to purchase a edition edition
           at the given price in the contract.
      @dev no need for re-entrancy guard since no safexxx functions are used
     */
    function purchase() external payable returns (uint256) {
        require(salePrice > 0, "Not for sale");
        require(msg.value == salePrice, "Wrong price");
        address[] memory toMint = new address[](1);
        toMint[0] = msg.sender;
        emit Sale(salePrice, msg.sender);
        return _mintEditions(toMint);
    }

    /**
        @dev Get royalty information for token
        @param _salePrice Sale price for the token
     */
    function royaltyInfo(uint256, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        if (fundsRecipient == address(0x0)) {
            return (fundsRecipient, 0);
        }
        return (fundsRecipient, (_salePrice * royaltyBPS) / 10_000);
    }

    /**
      @dev Private function to mint als without any access checks.
           Called by the public edition minting functions.
     */
    function _mintEditions(address[] memory recipients)
        internal
        returns (uint256)
    {
        uint256 startAt = atEditionId.current();
        uint256 endAt = startAt + recipients.length - 1;
        require(editionSize == 0 || endAt <= editionSize, "Sold out");
        while (atEditionId.current() <= endAt) {
            _mint(
                recipients[atEditionId.current() - startAt],
                atEditionId.current()
            );
            atEditionId.increment();
        }
        return atEditionId.current();
    }

    /**
      @param _salePrice if sale price is 0 sale is stopped, otherwise that amount 
                       of ETH is needed to start the sale.
      @dev This sets a simple ETH sales price
           Setting a sales price allows users to mint the edition until it sells out.
           For more granular sales, use an external sales contract.
     */
    function setSalePrice(uint256 _salePrice) external onlyAdmin {
        salePrice = _salePrice;
        emit PriceChanged(salePrice);
    }

    /**
      @dev Set a different funds recipient 
     */
    function setFundsRecipient(address payable newRecipientAddress)
        external
        onlyRoleOrAdmin(FUNDS_RECIPIENT_MANAGER_ROLE)
    {
        _setFundsRecipient(newRecipientAddress);
    }

    function _setFundsRecipient(address payable newRecipientAddress) internal {
        fundsRecipient = newRecipientAddress;
        emit FundsRecipientChanged(newRecipientAddress);
    }

    function zoraFeeForAmount(uint256 amount)
        internal
        returns (address payable, uint256)
    {
        (address payable recipient, uint256 bps) = zoraFeeManager
            .getZORAWithdrawFeesBPS(address(this));
        return (recipient, amount * (bps / 10_000));
    }

    /**
      @dev This withdraws ETH from the contract to the contract owner.
     */
    function withdraw()
        external
        onlyRoleOrAdmin(FUNDS_RECIPIENT_MANAGER_ROLE)
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
        fundsRecipient.sendValue(funds);
    }

    /// @dev This is in case royalty or ERC20s are sent to the contract.
    /// @param tokenAddress address of token
    function withdrawERC20(address tokenAddress)
        external
        onlyRoleOrAdmin(FUNDS_RECIPIENT_MANAGER_ROLE)
        nonReentrant
    {
        IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
        uint256 funds = token.balanceOf(address(this));
        (address payable feeRecipient, uint256 zoraFee) = zoraFeeForAmount(
            funds
        );
        token.transferFrom(address(this), feeRecipient, zoraFee);
        funds -= zoraFee;
        token.transferFrom(address(this), fundsRecipient, zoraFee);
    }

    /**
      @param to address to send the newly minted edition to
      @dev This mints one edition to the given address by an allowed minter on the edition instance.
     */
    function mintEdition(address to)
        external
        override
        onlyRoleOrAdmin(MINTER_ROLE)
        returns (uint256)
    {
        address[] memory toMint = new address[](1);
        toMint[0] = to;
        return _mintEditions(toMint);
    }

    /**
      @param recipients list of addresses to send the newly minted editions to
      @dev This mints multiple editions to the given list of addresses.
     */
    function mintEditions(address[] calldata recipients)
        external
        override
        onlyRoleOrAdmin(MINTER_ROLE)
        returns (uint256)
    {
        return _mintEditions(recipients);
    }

    /**
        Simple override for owner interface.
        @return user owner address
     */
    function owner()
        public
        view
        override(OwnableSkeleton, IEditionSingleMintable)
        returns (address)
    {
        return owner();
    }

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
            type(OwnableSkeleton).interfaceId == interfaceId ||
            type(IERC2981Upgradeable).interfaceId == interfaceId;
    }
}
