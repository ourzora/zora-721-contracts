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

    /// Counter for current contract id upgraded
    CountersUpgradeable.Counter private atContract;

    /// Address for implementation of ZoraNFTBase to clone
    address public immutable implementation;

    EditionMetadataRenderer public immutable editionMetadataRenderer;
    DropMetadataRenderer public immutable dropMetadataRenderer;

    /// Initializes factory with address of implementation logic
    /// @param _implementation SingleEditionMintable logic implementation contract to clone
    constructor(
        address _implementation,
        EditionMetadataRenderer _editionMetadataRenderer,
        DropMetadataRenderer _dropMetadataRenderer
    ) {
        implementation = _implementation;
        editionMetadataRenderer = _editionMetadataRenderer;
        dropMetadataRenderer = _dropMetadataRenderer;
    }

    // Initializes the proxy contract
    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();   
    }

    // Only owner can upgrade
    function _authorizeUpgrade(address) internal override onlyOwner {
    }

    function _setupMediaContract(
        string memory name,
        string memory symbol,
        uint256 editionSize,
        uint256 royaltyBPS,
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

    function createDrop(
        string memory name,
        string memory symbol,
        uint256 royaltyBPS,
        uint256 editionSize,
        address payable fundsRecipient,
        string memory metadataURIBase
    ) external returns (uint256) {
        (uint256 newId, address mediaContract) = _setupMediaContract({
            name: name,
            symbol: symbol,
            royaltyBPS: royaltyBPS,
            editionSize: editionSize,
            fundsRecipient: fundsRecipient,
            metadataRenderer: dropMetadataRenderer
        });
        dropMetadataRenderer.updateMetadataBase(mediaContract, metadataURIBase);

        return newId;
    }

    // Creates a new edition contract as a factory with a deterministic address
    // Important: None of these fields (except the Url fields with the same hash) can be changed after calling
    // @param _name Name of the edition contract
    // @param _symbol Symbol of the edition contract
    // @param _description Metadata: Description of the edition entry
    // @param _animationUrl Metadata: Animation url (optional) of the edition entry
    // @param _animationHash Metadata: SHA-256 Hash of the animation (if no animation url, can be 0x0)
    // @param _imageUrl Metadata: Image url (semi-required) of the edition entry
    // @param _imageHash Metadata: SHA-256 hash of the Image of the edition entry (if not image, can be 0x0)
    // @param _editionSize Total size of the edition (number of possible editions)
    // @param _royaltyBPS BPS amount of royalty
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
        uint256 editionSize,
        uint256 royaltyBPS,
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
