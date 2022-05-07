// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ERC721DropProxy} from "./ERC721DropProxy.sol";
import {Version} from "./utils/Version.sol";
import {EditionMetadataRenderer} from "./metadata/EditionMetadataRenderer.sol";
import {DropMetadataRenderer} from "./metadata/DropMetadataRenderer.sol";
import {IMetadataRenderer} from "./interfaces/IMetadataRenderer.sol";
import {ERC721Drop} from "./ERC721Drop.sol";

/// @notice Zora NFT Creator V1
contract ZoraNFTCreatorV1 is
    OwnableUpgradeable,
    UUPSUpgradeable,
    Version(1)
{
    string private constant CANNOT_BE_ZERO = "Cannot be 0 address";

    /// @notice Emitted when a edition is created reserving the corresponding token IDs.
    event CreatedDrop(
        address indexed creator,
        address indexed editionContractAddress,
        uint256 editionSize
    );

    /// @notice Address for implementation of ZoraNFTBase to clone
    address public immutable implementation;

    /// @notice Edition metdata renderer
    EditionMetadataRenderer public immutable editionMetadataRenderer;

    /// @notice Drop metdata renderer
    DropMetadataRenderer public immutable dropMetadataRenderer;

    /// @notice Initializes factory with address of implementation logic
    /// @param _implementation SingleEditionMintable logic implementation contract to clone
    /// @param _editionMetadataRenderer Metadata renderer for editions
    /// @param _dropMetadataRenderer Metadata renderer for drops
    constructor(
        address _implementation,
        EditionMetadataRenderer _editionMetadataRenderer,
        DropMetadataRenderer _dropMetadataRenderer
    ) {
        require(_implementation != address(0), CANNOT_BE_ZERO);
        require(
            address(_editionMetadataRenderer) != address(0),
            CANNOT_BE_ZERO
        );
        require(address(_dropMetadataRenderer) != address(0), CANNOT_BE_ZERO);

        implementation = _implementation;
        editionMetadataRenderer = _editionMetadataRenderer;
        dropMetadataRenderer = _dropMetadataRenderer;
    }

    /// @notice Call to validate upgrade for child drop contract.
    /// @dev Can be upgraded to include a static list of allowable upgrades for child media contracts.
    /// @param newImplementation proposed new implementation address
    function isValidUpgrade(address newImplementation) external returns (bool) {
        return false;
    }

    /// @dev Initializes the proxy contract
    function initialize() external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    /// @dev Function to determine who is allowed to upgrade this contract.
    /// @param _newImplementation: unused in access check
    function _authorizeUpgrade(address _newImplementation)
        internal
        override
        onlyOwner
    {}

    /// @dev Internal function to setup the media contract across all metadata types
    /// @param name Name for new contract (cannot be changed)
    /// @param symbol Symbol for new contract (cannot be changed)
    /// @param defaultAdmin Default admin address
    /// @param editionSize The max size of the media contract allowed
    /// @param royaltyBPS BPS for on-chain royalties (cannot be changed)
    /// @param fundsRecipient recipient for sale funds and, unless overridden, royalties
    function _setupMediaContract(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        uint64 editionSize,
        uint16 royaltyBPS,
        address payable fundsRecipient,
        IMetadataRenderer metadataRenderer,
        bytes memory metadataInitializer
    ) internal returns (address) {
        ERC721DropProxy newDrop = new ERC721DropProxy(
            implementation, ""
        );

        address newDropAddress = address(newDrop);

        ERC721Drop(newDropAddress).initialize(
            name,
            symbol,
            defaultAdmin,
            fundsRecipient,
            editionSize,
            royaltyBPS,
            metadataRenderer,
            metadataInitializer
        );

        emit CreatedDrop({creator: msg.sender, editionSize: editionSize, editionContractAddress: newDropAddress});

        return newDropAddress;
    }

    /// @dev Setup the media contract for a drop
    /// @param name Name for new contract (cannot be changed)
    /// @param symbol Symbol for new contract (cannot be changed)
    /// @param defaultAdmin Default admin address
    /// @param editionSize The max size of the media contract allowed
    /// @param royaltyBPS BPS for on-chain royalties (cannot be changed)
    /// @param fundsRecipient recipient for sale funds and, unless overridden, royalties
    /// @param metadataURIBase URI Base for metadata
    /// @param metadataContractURI URI for contract metadata
    function createDrop(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        uint64 editionSize,
        uint16 royaltyBPS,
        address payable fundsRecipient,
        string memory metadataURIBase,
        string memory metadataContractURI
    ) external returns (address) {
        bytes memory metadataInitializer = abi.encode(
            metadataURIBase,
            metadataContractURI
        );
        return
            _setupMediaContract({
                defaultAdmin: defaultAdmin,
                name: name,
                symbol: symbol,
                royaltyBPS: royaltyBPS,
                editionSize: editionSize,
                fundsRecipient: fundsRecipient,
                metadataRenderer: dropMetadataRenderer,
                metadataInitializer: metadataInitializer
            });
    }

    /// @notice Creates a new edition contract as a factory with a deterministic address
    /// @notice Important: None of these fields (except the Url fields with the same hash) can be changed after calling
    /// @param name Name of the edition contract
    /// @param symbol Symbol of the edition contract
    /// @param defaultAdmin Default admin address
    /// @param editionSize Total size of the edition (number of possible editions)
    /// @param royaltyBPS BPS amount of royalty
    /// @param fundsRecipient Funds recipient for the NFT sale
    /// @param description Metadata: Description of the edition entry
    /// @param animationURI Metadata: Animation url (optional) of the edition entry
    /// @param animationHash Metadata: SHA-256 Hash of the animation (if no animation url, can be 0x0)
    /// @param imageURI Metadata: Image url (semi-required) of the edition entry
    /// @param imageHash Metadata: SHA-256 hash of the Image of the edition entry (if not image, can be 0x0)
    function createEdition(
        string memory name,
        string memory symbol,
        uint64 editionSize,
        uint16 royaltyBPS,
        address payable fundsRecipient,
        address defaultAdmin,
        string memory description,
        string memory animationURI,
        // stored as calldata
        bytes32 animationHash,
        string memory imageURI,
        // stored as calldata
        bytes32 imageHash
    ) external returns (address) {
        bytes memory metadataInitializer = abi.encode(
            description,
            imageURI,
            animationURI
        );
        return
            _setupMediaContract({
                name: name,
                symbol: symbol,
                defaultAdmin: defaultAdmin,
                royaltyBPS: royaltyBPS,
                editionSize: editionSize,
                fundsRecipient: fundsRecipient,
                metadataRenderer: editionMetadataRenderer,
                metadataInitializer: metadataInitializer
            });
    }
}
