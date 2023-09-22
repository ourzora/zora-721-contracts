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
import {IContractMetadata} from "./interfaces/IContractMetadata.sol";

/// @notice Zora NFT Creator V1
contract ZoraNFTCreatorV1 is OwnableUpgradeable, UUPSUpgradeable, IContractMetadata, Version(8) {
    string private constant CANNOT_BE_ZERO = "Cannot be 0 address";

    /// @notice Emitted when a edition is created reserving the corresponding token IDs.
    event CreatedDrop(
        address indexed creator,
        address indexed editionContractAddress,
        uint256 editionSize
    );

    /// @notice Address for implementation of ERC721Drop to clone
    address public immutable implementation;

    /// @notice Edition metdata renderer
    EditionMetadataRenderer public immutable editionMetadataRenderer;

    /// @notice Drop metdata renderer
    DropMetadataRenderer public immutable dropMetadataRenderer;

    /// @notice Initializes factory with address of implementation logic
    /// @param _implementation ERC721Drop logic implementation contract to clone
    /// @param _editionMetadataRenderer Metadata renderer for editions
    /// @param _dropMetadataRenderer Metadata renderer for drops
    constructor(
        address _implementation,
        EditionMetadataRenderer _editionMetadataRenderer,
        DropMetadataRenderer _dropMetadataRenderer
    ) initializer {
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

    function contractName() external pure override returns (string memory) {
        return "ZORA NFT Creator";
    }

    function contractURI() external pure override returns (string memory) {
        return "https://github.com/ourzora/zora-drops-contracts";
    }

    /// @dev Function to determine who is allowed to upgrade this contract.
    /// @param _newImplementation: unused in access check
    function _authorizeUpgrade(address _newImplementation)
        internal
        override
        onlyOwner
    {}

    function createAndConfigureDrop(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        uint64 editionSize,
        uint16 royaltyBPS,
        address payable fundsRecipient,
        bytes[] memory setupCalls,
        IMetadataRenderer metadataRenderer,
        bytes memory metadataInitializer,
        address createReferral
    ) public returns (address payable newDropAddress) {
        ERC721DropProxy newDrop = new ERC721DropProxy(implementation, "");

        newDropAddress = payable(address(newDrop));
        ERC721Drop(newDropAddress).initialize({
            _contractName: name,
            _contractSymbol: symbol,
            _initialOwner: defaultAdmin,
            _fundsRecipient: fundsRecipient,
            _editionSize: editionSize,
            _royaltyBPS: royaltyBPS,
            _setupCalls: setupCalls,
            _metadataRenderer: metadataRenderer,
            _metadataRendererInit: metadataInitializer,
            _createReferral: createReferral
        });
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
    /// @notice deprecated: Will be removed in 2023
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
        bytes memory metadataInitializer,
        address createReferral
    ) public returns (address) {
        bytes[] memory setupData = new bytes[](1);
        setupData[0] = abi.encodeWithSelector(
            ERC721Drop.setSaleConfiguration.selector,
            saleConfig.publicSalePrice,
            saleConfig.maxSalePurchasePerAddress,
            saleConfig.publicSaleStart,
            saleConfig.publicSaleEnd,
            saleConfig.presaleStart,
            saleConfig.presaleEnd,
            saleConfig.presaleMerkleRoot
        );
        address newDropAddress = createAndConfigureDrop({
            name: name,
            symbol: symbol,
            defaultAdmin: defaultAdmin,
            fundsRecipient: fundsRecipient,
            editionSize: editionSize,
            royaltyBPS: royaltyBPS,
            setupCalls: setupData,
            metadataRenderer: metadataRenderer,
            metadataInitializer: metadataInitializer,
            createReferral: createReferral
        });

        emit CreatedDrop({
            creator: msg.sender,
            editionSize: editionSize,
            editionContractAddress: newDropAddress
        });

        return newDropAddress;
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
    /// @notice @deprecated Will be removed in 2023
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
                metadataInitializer: metadataInitializer,
                createReferral: address(0)
            });
    }

    function createDropWithReferral(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        uint64 editionSize,
        uint16 royaltyBPS,
        address payable fundsRecipient,
        IERC721Drop.SalesConfiguration memory saleConfig,
        string memory metadataURIBase,
        string memory metadataContractURI,
        address createReferral
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
                metadataInitializer: metadataInitializer,
                createReferral: createReferral
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
    /// @notice deprecated: Will be removed in 2023
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
                metadataInitializer: metadataInitializer,
                createReferral: address(0)
            });
    }

    function createEditionWithReferral(
        string memory name,
        string memory symbol,
        uint64 editionSize,
        uint16 royaltyBPS,
        address payable fundsRecipient,
        address defaultAdmin,
        IERC721Drop.SalesConfiguration memory saleConfig,
        string memory description,
        string memory animationURI,
        string memory imageURI,
        address createReferral
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
                metadataInitializer: metadataInitializer,
                createReferral: createReferral
            });
    }
}
