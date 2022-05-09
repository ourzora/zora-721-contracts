// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {FactoryUpgradeGate} from "../FactoryUpgradeGate.sol";
import {IZoraFeeManager} from "../interfaces/IZoraFeeManager.sol";
import {IMetadataRenderer} from "../interfaces/IMetadataRenderer.sol";

contract ERC721DropStorageV1 {
    /// @dev This is the max mint batch size for the optimized ERC721A mint contract
    uint256 internal constant MAX_MINT_BATCH_SIZE = 8;

    /// @notice Error string constants
    string internal constant SOLD_OUT = "Sold out";
    string internal constant TOO_MANY = "Too many";

    /// @notice Access control roles
    bytes32 public immutable MINTER_ROLE = keccak256("MINTER");
    bytes32 public immutable SALES_MANAGER_ROLE = keccak256("SALES_MANAGER");

    /// @notice Configuration for NFT minting contract storage
    Configuration public config;

    /// @notice Sales configuration
    SalesConfiguration public salesConfig;

    /// @dev ZORA V3 transfer helper address for auto-approval
    address internal immutable zoraERC721TransferHelper;

    /// @dev Factory upgrade gate
    FactoryUpgradeGate internal immutable factoryUpgradeGate;

    /// @dev Mapping for presale mint counts by address to allow public mint limit
    mapping(address => uint256) public presaleMintsByAddress;

    /// @dev Zora Fee Manager address
    IZoraFeeManager public immutable zoraFeeManager;

    /// @notice General configuration for NFT Minting and bookkeeping
    struct Configuration {
        /// @dev Metadata renderer (uint160)
        IMetadataRenderer metadataRenderer;
        /// @dev Total size of edition that can be minted (uint160+64 = 224)
        uint64 editionSize;
        /// @dev Royalty amount in bps (uint224+16 = 240)
        uint16 royaltyBPS;
        /// @dev Funds recipient for sale (new slot, uint160)
        address payable fundsRecipient;
    }

    /// @notice Sales states and configuration
    /// @dev Uses 3 storage slots
    struct SalesConfiguration {
        /// @dev Public sale price (max ether value > 1000 ether with this value)
        uint104 publicSalePrice;
        /// @dev Max purchase number per txn (90+32 = 122)
        uint32 maxSalePurchasePerAddress;
        /// @dev uint64 type allows for dates into 292 billion years
        /// @notice Public sale start timestamp (136+64 = 186)
        uint64 publicSaleStart;
        /// @notice Public sale end timestamp (186+64 = 250)
        uint64 publicSaleEnd;
        /// @notice Presale start timestamp
        /// @dev new storage slot
        uint64 presaleStart;
        /// @notice Presale end timestamp
        uint64 presaleEnd;
        /// @notice Presale merkle root
        bytes32 presaleMerkleRoot;
    }

    constructor(
        IZoraFeeManager _zoraFeeManager,
        address _zoraERC721TransferHelper,
        FactoryUpgradeGate _factoryUpgradeGate
    ) {
        zoraFeeManager = _zoraFeeManager;
        zoraERC721TransferHelper = _zoraERC721TransferHelper;
        factoryUpgradeGate = _factoryUpgradeGate;
    }
}