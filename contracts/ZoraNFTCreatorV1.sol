// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {ClonesUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {EditionMetadataRenderer} from "./metadata/EditionMetadataRenderer.sol";
import {DropMetadataRenderer} from "./metadata/DropMetadataRenderer.sol";
import {IMetadataRenderer} from "./interfaces/IMetadataRenderer.sol";
import {ZoraNFTBase} from "./ZoraNFTBase.sol";

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

    /// @dev Setup the media contract in general
    function _setupMediaContract(
        string memory name,
        string memory symbol,
        uint64 editionSize,
        uint16 royaltyBPS,
        address payable fundsRecipient,
        IMetadataRenderer metadataRenderer
    ) internal returns (uint256, address) {
        uint256 newId = atContract.current();
        address newMediaContract = ClonesUpgradeable.cloneDeterministic(
            implementation,
            bytes32(abi.encodePacked(newId))
        );

        ZoraNFTBase(newMediaContract).initialize({
            _owner: msg.sender,
            _name: name,
            _symbol: symbol,
            _fundsRecipient: fundsRecipient,
            _editionSize: editionSize,
            _royaltyBPS: royaltyBPS,
            _metadataRenderer: metadataRenderer
        });
        atContract.increment();
        emit CreatedEdition(newId, msg.sender, editionSize, newMediaContract);

        return (newId, newMediaContract);
    }

    /// @dev Setup the media contract for a drop
    function createDrop(
        string memory name,
        string memory symbol,
        uint16 royaltyBPS,
        uint64 editionSize,
        address payable fundsRecipient,
        string memory metadataURIBase,
        string memory metadataContractURI
    ) external returns (uint256) {
        (uint256 newId, address mediaContract) = _setupMediaContract({
            name: name,
            symbol: symbol,
            royaltyBPS: royaltyBPS,
            editionSize: editionSize,
            fundsRecipient: fundsRecipient,
            metadataRenderer: dropMetadataRenderer
        });
        dropMetadataRenderer.updateMetadataBase(
            mediaContract,
            metadataURIBase,
            metadataContractURI
        );

        return newId;
    }

    /// @notice Creates a new edition contract as a factory with a deterministic address
    /// @notice Important: None of these fields (except the Url fields with the same hash) can be changed after calling
    /// @param name Name of the edition contract
    /// @param symbol Symbol of the edition contract
    /// @param description Metadata: Description of the edition entry
    /// @param animationUrl Metadata: Animation url (optional) of the edition entry
    /// @param animationHash Metadata: SHA-256 Hash of the animation (if no animation url, can be 0x0)
    /// @param imageUrl Metadata: Image url (semi-required) of the edition entry
    /// @param imageHash Metadata: SHA-256 hash of the Image of the edition entry (if not image, can be 0x0)
    /// @param editionSize Total size of the edition (number of possible editions)
    /// @param royaltyBPS BPS amount of royalty
    /// @param royaltyBPS Funds recipient for the NFT sale
    function createEdition(
        string memory name,
        string memory symbol,
        string memory description,
        string memory animationUrl,
        // stored as calldata
        bytes32 animationHash,
        string memory imageUrl,
        // stored as calldata
        bytes32 imageHash,
        uint64 editionSize,
        uint16 royaltyBPS,
        address payable fundsRecipient
    ) external returns (uint256) {
        (uint256 newId, address mediaContract) = _setupMediaContract({
            name: name,
            symbol: symbol,
            royaltyBPS: royaltyBPS,
            editionSize: editionSize,
            fundsRecipient: fundsRecipient,
            metadataRenderer: editionMetadataRenderer
        });
        editionMetadataRenderer.setEditionDataForContract({
            target: mediaContract,
            description: description,
            imageUrl: imageUrl,
            imageHash: imageHash,
            animationUrl: animationUrl,
            animationHash: animationHash
        });

        return newId;
    }

    /// Get edition given the created ID
    /// @param editionId id of edition to get contract for
    /// @return SingleEditionMintable Edition NFT contract
    function getEditionAtId(uint256 editionId)
        external
        view
        returns (ZoraNFTBase)
    {
        return
            ZoraNFTBase(
                ClonesUpgradeable.predictDeterministicAddress(
                    implementation,
                    bytes32(abi.encodePacked(editionId)),
                    address(this)
                )
            );
    }

    /// Emitted when a edition is created reserving the corresponding token IDs.
    /// @param editionId ID of newly created edition
    event CreatedEdition(
        uint256 indexed editionId,
        address indexed creator,
        uint256 editionSize,
        address editionContractAddress
    );
}
