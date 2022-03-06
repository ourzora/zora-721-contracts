import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {IERC2981Upgradeable, IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IEditionSingleMintable} from "./IEditionSingleMintable.sol";
import {OwnableSkeleton} from "./OwnableSkeleton.sol";

contract ZoraMediaBase is
    ERC721Upgradeable,
    IEditionSingleMintable,
    IERC2981Upgradeable,
    OwnableSkeleton,
    AccessControlUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using AddressUpgradeable for address;

    event PriceChanged(uint256 amount);
    event Sale(uint256 price, address owner);

    bytes32 public immutable MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @dev Zora fee recipient
    address public immutable zoraDaoWallet;

    /// @dev Total size of edition that can be minted
    uint256 public editionSize;

    /// @dev Funds recipient for sale and royalties
    address public fundsRecipient;

    /// @dev Current token id minted
    CountersUpgradeable.Counter private atEditionId;

    /// @dev Royalty amount in bps
    uint256 royaltyBPS;

    /// @dev Price for sale
    uint256 public salePrice;

    error OnlyAdminRequired();

    modifier onlyAdmin() {
        require(hasRole(msg.sender, DEFAULT_ADMIN_ROLE), OnlyAdminRequired);

        _;
    }

    /// @dev ASDF
    /// @param _zoraDaoWallet Payout zora DAO wallet
    constructor(address _zoraDaoWallet) {
        zoraDaoWallet = _zoraDaoWallet;
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
        string _name,
        string _symbol,
        address _owner,
        address _fundsRecipient,
        uint256 _editionSize,
        uint256 _royaltyBPS
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __AccessControl_init();
        // Set ownership to original sender of contract call
        _setOwner(_owner);
        // Set edition id start to be 1 not 0
        atEditionId.increment();

        fundsRecipient = _fundsRecipient;
        royaltyBPS = _royaltyBPS;
    }

    /// @dev set new owner for royalties / opensea
    /// @param newOwner new owner to set
    function setOwner(address newOwner) public onlyAdmin {
        _setOwner(newOwner);
    }

    /// @dev returns the number of minted tokens within the edition
    function totalSupply() public view returns (uint256) {
        return atEditionId.current() - 1;
    }

    /**
        Simple eth-based sales function
        More complex sales functions can be implemented through ISingleEditionMintable interface
     */

    /**
      @dev This allows the user to purchase a edition edition
           at the given price in the contract.
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
      @dev This withdraws ETH from the contract to the contract owner.
     */
    function withdraw() external onlyAdmin {
        uint256 funds = address(this).balance;
        uint256 zoraFee = funds * 0.05;
        zoraDaoWallet.sendValue(zoraFee);
        funds -= zoraFee;
        // No need for gas limit to trusted address.
        fundsRecipient.sendValue(funds);
    }

    /**
      @dev This helper function checks if the msg.sender is allowed to mint the
            given edition id.
     */
    function _isAllowedToMint() internal view returns (bool) {
        if (owner() == msg.sender) {
            return true;
        }
        if (
            hasRole(msg.sender, MINTER_ROLE) ||
            hasRole(msg.sender, DEFAULT_ADMIN_ROLE)
        ) {
            return true;
        }
        return false;
    }

    /**
      @param to address to send the newly minted edition to
      @dev This mints one edition to the given address by an allowed minter on the edition instance.
     */
    function mintEdition(address to) external override returns (uint256) {
        require(_isAllowedToMint(), "Needs to be an allowed minter");
        address[] memory toMint = new address[](1);
        toMint[0] = to;
        return _mintEditions(toMint);
    }

    /**
      @param recipients list of addresses to send the newly minted editions to
      @dev This mints multiple editions to the given list of addresses.
     */
    function mintEditions(address[] memory recipients)
        external
        override
        returns (uint256)
    {
        require(_isAllowedToMint(), "Needs to be an allowed minter");
        return _mintEditions(recipients);
    }

    /**
        Simple override for owner interface.
     */
    function owner()
        public
        view
        override(OwnableUpgradeable, IEditionSingleMintable)
        returns (address)
    {
        return super.owner();
    }

    /**
      @param minter address to set approved minting status for
      @param allowed boolean if that address is allowed to mint
      @dev Sets the approved minting status of the given address.
           This requires that msg.sender is the owner of the given edition id.
           If the ZeroAddress (address(0x0)) is set as a minter,
             anyone will be allowed to mint.
           This setup is similar to setApprovalForAll in the ERC721 spec.
     */
    function setApprovedMinter(address minter, bool allowed) public onlyOwner {
        allowedMinters[minter] = allowed;
    }

    // receive fn for royalties
}
