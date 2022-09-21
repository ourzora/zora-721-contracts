// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/ISplitMain.sol";
import "./PureSplitHelpers.sol";

contract SplitHelpers is PureHelpers {
    /// @notice 0xSplits address for split.
    address payable public immutable payoutSplit;
    /// @notice 0xSplits address for updating & distributing split.
    ISplitMain public splitMain;
    /// @notice address of ERC721 contract with controlling tokens.
    IERC721 public nftContract;
    /// @notice array of token holders as split recipients.
    uint32[] public tokenIds;
    /// @notice constant to scale uints into percentages (1e6 == 100%)
    uint32 public constant PERCENTAGE_SCALE = 1e6;

    /// @notice Funds have been received. activate liquidity.
    event FundsReceived(address indexed source, uint256 amount);

    constructor(address _nftContractAddress, uint32[] memory _tokenIds) {
        /// Establish NFT holder contract
        nftContract = IERC721(_nftContractAddress);
        /// Establish tokenIds from NFT contract for split recipients.
        tokenIds = _tokenIds;
        /// Establish interface to splits contract
        splitMain = ISplitMain(0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE);
        // create dummy mutable split with this contract as controller;
        // recipients & distributorFee will be updated on first payout
        address[] memory recipients = new address[](2);
        recipients[0] = address(0);
        recipients[1] = address(1);
        uint32[] memory percentAllocations = new uint32[](2);
        percentAllocations[0] = uint32(500000);
        percentAllocations[1] = uint32(500000);
        payoutSplit = payable(
            splitMain.createSplit(
                recipients,
                percentAllocations,
                0,
                address(this)
            )
        );
    }

    /// @notice Returns array of all current token holders.
    function getAllHolders() public view returns (address[] memory holders) {
        holders = new address[](tokenIds.length);
        uint256 loopLength = holders.length;
        for (uint256 i = 0; i < loopLength; ) {
            holders[i] = nftContract.ownerOf(tokenIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Returns array of sorted token holders.
    function getSortedHolders() public view returns (address[] memory holders) {
        holders = _sortAddresses(getAllHolders());
    }

    /// @notice Returns array of recipients and array of percent allocations for current liquid split.
    function getRecipientsAndAllocations()
        public
        view
        returns (
            address[] memory recipients,
            uint32[] memory percentAllocations
        )
    {
        address[] memory sortedHolders = getSortedHolders();
        uint256 numUniqRecipients = _countUniqueRecipients(sortedHolders);

        recipients = new address[](numUniqRecipients);
        percentAllocations = new uint32[](numUniqRecipients);
        uint32 percentPerToken = uint32(
            PERCENTAGE_SCALE / sortedHolders.length
        );
        uint256 lastRecipient = numUniqRecipients - 1;
        uint256 j = 0;
        for (uint256 i = 0; i < lastRecipient; ) {
            recipients[i] = sortedHolders[j];
            while (recipients[i] == sortedHolders[j]) {
                unchecked {
                    percentAllocations[i] += percentPerToken;
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
        recipients[lastRecipient] = sortedHolders[j];
        unchecked {
            percentAllocations[lastRecipient] =
                PERCENTAGE_SCALE -
                uint32(percentPerToken * j);
        }
    }
}
