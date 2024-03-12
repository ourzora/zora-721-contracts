// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC721Drop} from "../interfaces/IERC721Drop.sol";

/// @custom:storage-location erc7201:zora.erc721drop.transferhook
struct TransferHookStorage {
    address transferHookExtension;
}

contract ERC721TransferHookStorageV1 {
    error InvalidTransferHook();
    event SetNewTransferHook(address _newTransferHook);

    // keccak256(abi.encode(uint256(keccak256("zora.erc721drop.transferhook")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant TRANSFER_HOOK_STORAGE_LOCATION =
        0x7dd1076582dd9e0dc6a5073ed536c067f2e92ed46866d3076f6f2d9a5e36b400;

    function _getTransferHookStorage() internal pure returns (TransferHookStorage storage $) {
        assembly {
            $.slot := TRANSFER_HOOK_STORAGE_LOCATION
        }
    }

    function _setTransferHook(address _newTransferHook) internal {
        _getTransferHookStorage().transferHookExtension = _newTransferHook;
        emit SetNewTransferHook(_newTransferHook);
    }
}
