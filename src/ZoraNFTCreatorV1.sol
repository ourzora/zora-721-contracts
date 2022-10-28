// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ERC721DropProxy} from "./ERC721DropProxy.sol";
import {Version} from "./utils/Version.sol";
import {EditionMetadataRenderer} from "./metadata/EditionMetadataRenderer.sol";
import {IERC721Drop} from "./interfaces/IERC721Drop.sol";
import {DropMetadataRenderer} from "./metadata/DropMetadataRenderer.sol";
import {IMetadataRenderer} from "./interfaces/IMetadataRenderer.sol";
import {ERC721Drop} from "./ERC721Drop.sol";

import {IDropsSplitter} from "./splitter/interfaces/IDropsSplitter.sol";

/// @notice Zora NFT Creator V1
contract ZoraNFTCreatorV1 is OwnableUpgradeable, UUPSUpgradeable, Version(2) {
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

    //        ,-.
    //        `-'
    //        /|\
    //         |                    ,----------------.              ,----------.
    //        / \                   |ZoraNFTCreatorV1|              |ERC721Drop|
    //      Caller                  `-------+--------'              `----+-----'
    //        |                       createDrop()                       |
    //        | --------------------------------------------------------->
    //        |                             |                            |
    //        |                             |----.
    //        |                             |    | initialize NFT metadata
    //        |                             |<---'
    //        |                             |                            |
    //        |                             |           deploy           |
    //        |                             | --------------------------->
    //        |                             |                            |
    //        |                             |       initialize drop      |
    //        |                             | --------------------------->
    //        |                             |                            |
    //        |                             |----.                       |
    //        |                             |    | emit CreatedDrop      |
    //        |                             |<---'                       |
    //        |                             |                            |
    //        | return drop contract address|                            |
    //        | <----------------------------                            |
    //      Caller                  ,-------+--------.              ,----+-----.
    //        ,-.                   |ZoraNFTCreatorV1|              |ERC721Drop|
    //        `-'                   `----------------'              `----------'
    //        /|\
    //         |
    //        / \
    /// @notice Function to setup the media contract across all metadata types
    /// @dev Called by edition and drop fns internally
    /// @param name Name for new contract (cannot be changed)
    /// @param symbol Symbol for new contract (cannot be changed)
    /// @param defaultAdmin Default admin address
    /// @param editionSize The max size of the media contract allowed
    /// @param royaltyBPS BPS for on-chain royalties (cannot be changed)
    /// @param fundsRecipient recipient for sale funds and, unless overridden, royalties
    function setupDropsContract(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        uint64 editionSize,
        uint16 royaltyBPS,
        address payable fundsRecipient,
        IERC721Drop.SalesConfiguration memory saleConfig,
        IMetadataRenderer metadataRenderer,
        bytes memory metadataInitializer
    ) public returns (address) {
        address payable newDrop = payable(address(new ERC721DropProxy(implementation, "")));

        IDropsSplitter.Share[] memory userShares = new IDropsSplitter.Share[](
            1
        );
        IDropsSplitter.Share[]
            memory platformShares = new IDropsSplitter.Share[](0);

        ERC721Drop(newDrop).initialize(
            name,
            symbol,
            defaultAdmin,
            IDropsSplitter.SplitSetupParams({
                userDenominator: 1,
                platformShares: platformShares,
                userShares: userShares,
                platformDenominator: 0
            }),
            editionSize,
            royaltyBPS,
            saleConfig,
            metadataRenderer,
            metadataInitializer
        );

        emit CreatedDrop({
            creator: msg.sender,
            editionSize: editionSize,
            editionContractAddress: newDrop
        });

        return newDrop;
    }

    //        ,-.
    //        `-'
    //        /|\
    //         |                    ,----------------.              ,----------.
    //        / \                   |ZoraNFTCreatorV1|              |ERC721Drop|
    //      Caller                  `-------+--------'              `----+-----'
    //        |                       createDrop()                       |
    //        | --------------------------------------------------------->
    //        |                             |                            |
    //        |                             |----.
    //        |                             |    | initialize NFT metadata
    //        |                             |<---'
    //        |                             |                            |
    //        |                             |           deploy           |
    //        |                             | --------------------------->
    //        |                             |                            |
    //        |                             |       initialize drop      |
    //        |                             | --------------------------->
    //        |                             |                            |
    //        |                             |----.                       |
    //        |                             |    | emit CreatedDrop      |
    //        |                             |<---'                       |
    //        |                             |                            |
    //        | return drop contract address|                            |
    //        | <----------------------------                            |
    //      Caller                  ,-------+--------.              ,----+-----.
    //        ,-.                   |ZoraNFTCreatorV1|              |ERC721Drop|
    //        `-'                   `----------------'              `----------'
    //        /|\
    //         |
    //        / \
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
        IERC721Drop.SalesConfiguration memory saleConfig,
        string memory metadataURIBase,
        string memory metadataContractURI
    ) external returns (address) {
        bytes memory metadataInitializer = abi.encode(
            metadataURIBase,
            metadataContractURI
        );
        return
            setupDropsContract({
                defaultAdmin: defaultAdmin,
                name: name,
                symbol: symbol,
                royaltyBPS: royaltyBPS,
                editionSize: editionSize,
                fundsRecipient: fundsRecipient,
                saleConfig: saleConfig,
                metadataRenderer: dropMetadataRenderer,
                metadataInitializer: metadataInitializer
            });
    }

    //        ,-.
    //        `-'
    //        /|\
    //         |                    ,----------------.              ,----------.
    //        / \                   |ZoraNFTCreatorV1|              |ERC721Drop|
    //      Caller                  `-------+--------'              `----+-----'
    //        |                      createEdition()                     |
    //        | --------------------------------------------------------->
    //        |                             |                            |
    //        |                             |----.
    //        |                             |    | initialize NFT metadata
    //        |                             |<---'
    //        |                             |                            |
    //        |                             |           deploy           |
    //        |                             | --------------------------->
    //        |                             |                            |
    //        |                             |     initialize edition     |
    //        |                             | --------------------------->
    //        |                             |                            |
    //        |                             |----.                       |
    //        |                             |    | emit CreatedDrop      |
    //        |                             |<---'                       |
    //        |                             |                            |
    //        | return drop contract address|                            |
    //        | <----------------------------                            |
    //      Caller                  ,-------+--------.              ,----+-----.
    //        ,-.                   |ZoraNFTCreatorV1|              |ERC721Drop|
    //        `-'                   `----------------'              `----------'
    //        /|\
    //         |
    //        / \
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
    /// @param imageURI Metadata: Image url (semi-required) of the edition entry
    function createEdition(
        string memory name,
        string memory symbol,
        uint64 editionSize,
        uint16 royaltyBPS,
        address payable fundsRecipient,
        address defaultAdmin,
        IERC721Drop.SalesConfiguration memory saleConfig,
        string memory description,
        string memory animationURI,
        string memory imageURI
    ) external returns (address) {
        bytes memory metadataInitializer = abi.encode(
            description,
            imageURI,
            animationURI
        );

        return
            setupDropsContract({
                name: name,
                symbol: symbol,
                defaultAdmin: defaultAdmin,
                editionSize: editionSize,
                royaltyBPS: royaltyBPS,
                saleConfig: saleConfig,
                fundsRecipient: fundsRecipient,
                metadataRenderer: editionMetadataRenderer,
                metadataInitializer: metadataInitializer
            });
    }
}
