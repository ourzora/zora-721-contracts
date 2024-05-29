// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/// @dev ITransferHookExtension – optional extension to add custom behavior to 721 NFT on Transfer
/// @notice Used for custom functionality and improvements
interface ITransferHookExtension {
    /// @param from Address transfer from
    /// @param to Address transfer to
    /// @param operator Address operating (calling) the transfer
    /// @param startTokenId transfer start token id
    /// @param quantity Transfer quantity (from ERC721A)
    function beforeTokenTransfers(address from, address to, address operator, uint256 startTokenId, uint256 quantity) external;
    /// @notice Used for supportsInterface IERC165
    function supportsInterface(bytes4 interfaceId) external returns (bool);
}
