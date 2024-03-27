// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC721Drop} from "../interfaces/IERC721Drop.sol";

/// @custom:storage-location erc7201:zora.erc721drop.transferhook
struct TransferHookStorage {
    /// @notice Extension for transfer hook across the whole contract. Optional – disabled if set to address(0).
    address transferHookExtension;
}

/// @notice Contract to handle the storage of the transfer hook information for 721
contract ERC721TransferHookStorageV1 {
    /// @notice Called when an invalid transfer hook is attempted to be set
    error InvalidTransferHook();
    /// @notice Emitted when a new transfer hook is setup
    event SetNewTransferHook(address _newTransferHook);

    // keccak256(abi.encode(uint256(keccak256("zora.erc721drop.transferhook")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant TRANSFER_HOOK_STORAGE_LOCATION = 0x7dd1076582dd9e0dc6a5073ed536c067f2e92ed46866d3076f6f2d9a5e36b400;

    /// @notice Function to get the current transfer hook storage from its direct storage slot.
    function _getTransferHookStorage() internal pure returns (TransferHookStorage storage $) {
        assembly {
            $.slot := TRANSFER_HOOK_STORAGE_LOCATION
        }
    }

    /// @notice Internal direct setter for transfer hook. Emits changed event.
    function _setTransferHook(address _newTransferHook) internal {
        _getTransferHookStorage().transferHookExtension = _newTransferHook;
        emit SetNewTransferHook(_newTransferHook);
    }
}
