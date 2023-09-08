// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ZoraNFTCreatorV1} from "../src/ZoraNFTCreatorV1.sol";
import {IERC721Drop} from "../src/interfaces/IERC721Drop.sol";

/// @notice Chain configuration for constants set manually during deploy. Does not get written to after deploys.
struct ChainConfig {
    /// @notice The user that owns the factory proxy. Allows ability to upgrade for new implementations deployed.
    address factoryOwner;
    /// @notice The user that owns the factory upgrade gate. This contract gates what existing deployed impls can upgrade to.
    address factoryUpgradeGateOwner;
    /// @notice Mint fee amount in WEI charged for each mint
    uint256 mintFeeAmount;
    /// @notice Mint fee recipient user
    address mintFeeRecipient;
    /// @notice Subscription address for operator-filterer-registry (opensea / cori)
    address subscriptionMarketFilterAddress;
    /// @notice Owner for subscription of operator-filterer-registry (opensea / cori)
    address subscriptionMarketFilterOwner;
    /// @notice Auto-approved hyperstructure on mainnet for enabling ZORA v3 with less gas. Deprecated – safe to set to address(0x)
    address zoraERC721TransferHelper;
    /// @notice The Protocol Rewards contract
    address protocolRewards;
}

/// @notice Deployment addresses – set to new deployed addresses by the scripts.
struct DropDeployment {
    /// @notice Metadata renderer for drop style contracts
    address dropMetadata;
    /// @notice Metadata renderer for edition style contracts
    address editionMetadata;
    /// @notice Implementation contract for the drop contract
    address dropImplementation;
    /// @notice Implementation version for the drop contract
    uint256 dropImplementationVersion;
    /// @notice Factory upgrade gate immutable registry for allowing upgrades
    address factoryUpgradeGate;
    /// @notice Factory proxy contract that creates zora drops style NFT contracts
    address factory;
    /// @notice Factory implementation contract that is the impl for the above proxy.
    address factoryImpl;
}

/// @notice Deployment drops for base where 
abstract contract DeploymentConfig is StdChains, StdCheatsSafe, StdUtils, ScriptBase {
    using stdJson for string;

    /// @notice ChainID convenience getter
    /// @return id chainId
    function chainId() internal view virtual returns (uint256 id);

    /// @notice File used for demo metadata on verification test mint
    string constant DEMO_IPFS_METADATA_FILE = "ipfs://bafkreigu544g6wjvqcysurpzy5pcskbt45a5f33m6wgythpgb3rfqi3lzi";

    address constant DEFAULT_CREATE_REFERRAL = address(0);

    ///
    // These are the JSON key constants to standardize writing and reading configuration
    ///

    string constant FACTORY_OWNER = "FACTORY_OWNER";
    string constant FACTORY_UPGRADE_GATE_OWNER = "FACTORY_OWNER";
    string constant MINT_FEE_AMOUNT = "MINT_FEE_AMOUNT";
    string constant MINT_FEE_RECIPIENT = "MINT_FEE_RECIPIENT";
    string constant SUBSCRIPTION_MARKET_FILTER_ADDRESS = "SUBSCRIPTION_MARKET_FILTER_ADDRESS";
    string constant SUBSCRIPTION_MARKET_FILTER_OWNER = "SUBSCRIPTION_MARKET_FILTER_OWNER";
    string constant ZORA_ERC721_TRANSFER_HELPER = "ZORA_ERC721_TRANSFER_HELPER";
    string constant PROTOCOL_REWARDS = "PROTOCOL_REWARDS";

    string constant DROP_METADATA_RENDERER = "DROP_METADATA_RENDERER";
    string constant EDITION_METADATA_RENDERER = "EDITION_METADATA_RENDERER";
    string constant ERC721DROP_IMPL = "ERC721DROP_IMPL";
    string constant ERC721DROP_IMPL_VERSION = "ERC721DROP_IMPL_VERSION";
    string constant FACTORY_UPGRADE_GATE = "FACTORY_UPGRADE_GATE";
    string constant ZORA_NFT_CREATOR_PROXY = "ZORA_NFT_CREATOR_PROXY";
    string constant ZORA_NFT_CREATOR_V1_IMPL = "ZORA_NFT_CREATOR_V1_IMPL";

    /// @notice Return a prefixed key for reading with a ".".
    /// @param key key to prefix
    /// @return prefixed key
    function getKeyPrefix(string memory key) internal pure returns (string memory) {
        return string.concat(".", key);
    }

    /// @notice Returns the chain configuration struct from the JSON configuration file
    /// @return chainConfig structure
    function getChainConfig() internal view returns (ChainConfig memory chainConfig) {
        string memory json = vm.readFile(string.concat("chainConfigs/", Strings.toString(chainId()), ".json"));
        chainConfig.factoryOwner = json.readAddress(getKeyPrefix(FACTORY_OWNER));
        chainConfig.factoryUpgradeGateOwner = json.readAddress(getKeyPrefix(FACTORY_UPGRADE_GATE_OWNER));
        chainConfig.mintFeeAmount = json.readUint(getKeyPrefix(MINT_FEE_AMOUNT));
        chainConfig.mintFeeRecipient = json.readAddress(getKeyPrefix(MINT_FEE_RECIPIENT));
        chainConfig.subscriptionMarketFilterAddress = json.readAddress(getKeyPrefix(SUBSCRIPTION_MARKET_FILTER_ADDRESS));
        chainConfig.zoraERC721TransferHelper = json.readAddress(getKeyPrefix(ZORA_ERC721_TRANSFER_HELPER));
        chainConfig.protocolRewards = json.readAddress(getKeyPrefix(PROTOCOL_REWARDS));
    }

    /// @notice Get the deployment configuration struct from the JSON configuration file
    /// @return dropDeployment deployment configuration structure
    function getDeployment() internal view returns (DropDeployment memory dropDeployment) {
        string memory json = vm.readFile(string.concat("addresses/", Strings.toString(chainId()), ".json"));
        dropDeployment.dropMetadata = json.readAddress(getKeyPrefix(DROP_METADATA_RENDERER));
        dropDeployment.editionMetadata = json.readAddress(getKeyPrefix(EDITION_METADATA_RENDERER));
        dropDeployment.dropImplementation = json.readAddress(getKeyPrefix(ERC721DROP_IMPL));
        dropDeployment.factoryUpgradeGate = json.readAddress(getKeyPrefix(FACTORY_UPGRADE_GATE));
        dropDeployment.factory = json.readAddress(getKeyPrefix(ZORA_NFT_CREATOR_PROXY));
        dropDeployment.factoryImpl = json.readAddress(getKeyPrefix(ZORA_NFT_CREATOR_V1_IMPL));
    }

}

contract ForkDeploymentConfig is DeploymentConfig {
    function chainId() internal view override returns (uint256 id) {
        return block.chainid;
    }
}

contract ScriptDeploymentConfig is DeploymentConfig {
    function chainId() internal view override returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }
}
