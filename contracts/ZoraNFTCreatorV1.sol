// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {ClonesUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {EditionMetadataRenderer} from "./metadata/EditionMetadataRenderer.sol";
import {DropMetadataRenderer} from "./metadata/DropMetadataRenderer.sol";
import {IMetadataRenderer} from "./interfaces/IMetadataRenderer.sol";
import {ERC721Drop} from "./ERC721Drop.sol";


/// @dev Zora NFT Creator V1
contract ZoraNFTCreatorV1 is OwnableUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    /// TODO: figure out memory implications of using immutable variables here
    /// They are supposed to be discarded upon upgrade

    /// @notice Counter for current contract id upgraded
    CountersUpgradeable.Counter private atContract;

    /// @notice Address for implementation of ZoraNFTBase to clone
    address public immutable implementation;

    /// @notice Edition metdata renderer
    EditionMetadataRenderer public immutable editionMetadataRenderer;

    /// @notice Drop metdata renderer
    DropMetadataRenderer public immutable dropMetadataRenderer;

    /// Initializes factory with address of implementation logic
    /// @param _implementation SingleEditionMintable logic implementation contract to clone
    /// @param _editionMetadataRenderer Metadata renderer for editions
    /// @param _dropMetadataRenderer Metadata renderer for drops
    constructor(
        address _implementation,
        EditionMetadataRenderer _editionMetadataRenderer,
        DropMetadataRenderer _dropMetadataRenderer
    ) {
        implementation = _implementation;
        editionMetadataRenderer = _editionMetadataRenderer;
        dropMetadataRenderer = _dropMetadataRenderer;
    }

    /// @dev Initializes the proxy contract
    function initialize() public initializer {
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
    /// @param editionSize The max size of the media contract allowed
    /// @param royaltyBPS BPS for on-chain royalties (cannot be changed)
    /// @param fundsRecipient recipient for sale funds and, unless overridden, royalties
    function _setupMediaContract(
        string memory name,
        string memory symbol,
        uint64 editionSize,
        uint16 royaltyBPS,
        address payable fundsRecipient,
        IMetadataRenderer metadataRenderer,
        bytes memory metadataInitializer
    ) internal returns (uint256, address) {
        uint256 newId = atContract.current();
        address newMediaContract = ClonesUpgradeable.cloneDeterministic(
            implementation,
            bytes32(abi.encodePacked(newId))
        );

        ERC721Drop(newMediaContract).initialize({
            _owner: msg.sender,
            _name: name,
            _symbol: symbol,
            _fundsRecipient: fundsRecipient,
            _editionSize: editionSize,
            _royaltyBPS: royaltyBPS,
            _metadataRenderer: metadataRenderer,
            _metadataRendererInit: metadataInitializer
        });
        atContract.increment();
        emit CreatedEdition(newId, msg.sender, editionSize, newMediaContract);

        return (newId, newMediaContract);
    }

    /// @dev Setup the media contract for a drop
    /// @param name Name for new contract (cannot be changed)
    /// @param symbol Symbol for new contract (cannot be changed)
    /// @param editionSize The max size of the media contract allowed
    /// @param royaltyBPS BPS for on-chain royalties (cannot be changed)
    /// @param fundsRecipient recipient for sale funds and, unless overridden, royalties
    /// @param metadataURIBase URI Base for metadata
    /// @param metadataContractURI URI for contract metadata
    function createDrop(
        string memory name,
        string memory symbol,
        uint64 editionSize,
        uint16 royaltyBPS,
        address payable fundsRecipient,
        string memory metadataURIBase,
        string memory metadataContractURI
    ) external returns (uint256) {
        bytes memory metadataInitializer = abi.encode(metadataURIBase, metadataContractURI);
        (uint256 newId, address mediaContract) = _setupMediaContract({
            name: name,
            symbol: symbol,
            royaltyBPS: royaltyBPS,
            editionSize: editionSize,
            fundsRecipient: fundsRecipient,
            metadataRenderer: dropMetadataRenderer,
            metadataInitializer: metadataInitializer
        });

        return newId;
    }

    /// @notice Creates a new edition contract as a factory with a deterministic address
    /// @notice Important: None of these fields (except the Url fields with the same hash) can be changed after calling
    /// @param name Name of the edition contract
    /// @param symbol Symbol of the edition contract
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
        string memory description,
        string memory animationURI,
        // stored as calldata
        bytes32 animationHash,
        string memory imageURI,
        // stored as calldata
        bytes32 imageHash
    ) external returns (uint256) {
        bytes memory metadataInitializer = abi.encode(description, imageURI, animationURI);
        (uint256 newId, address mediaContract) = _setupMediaContract({
            name: name,
            symbol: symbol,
            royaltyBPS: royaltyBPS,
            editionSize: editionSize,
            fundsRecipient: fundsRecipient,
            metadataRenderer: editionMetadataRenderer,
            metadataInitializer: metadataInitializer
        });

        return newId;
    }

    /// @notice Get edition given the created ID
    /// @param editionId id of edition to get contract for
    /// @return SingleEditionMintable Edition NFT contract
    function getEditionAtId(uint256 editionId)
        external
        view
        returns (ERC721Drop)
    {
        return
            ERC721Drop(
                ClonesUpgradeable.predictDeterministicAddress(
                    implementation,
                    bytes32(abi.encodePacked(editionId)),
                    address(this)
                )
            );
    }

    /// @notice Emitted when a edition is created reserving the corresponding token IDs.
    event CreatedEdition(
        uint256 indexed editionId,
        address indexed creator,
        uint256 editionSize,
        address editionContractAddress
    );
}
