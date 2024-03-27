// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ITransferHookExtension} from "../../src/interfaces/ITransferHookExtension.sol";

contract MockTransferHookReverts is ITransferHookExtension {
    function beforeTokenTransfers(address, address, address, uint256, uint256) external pure {
        revert("AT_HOOK");
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ITransferHookExtension).interfaceId;
    }
}

contract MockTransferHookWrongInterface is ITransferHookExtension {
    function beforeTokenTransfers(address, address, address, uint256, uint256) external pure {
        revert("AT_HOOK");
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return false;
    }
}

contract MockTransferHookSavesState is ITransferHookExtension {
    uint256 public numberTransfers = 0;
    struct LastCall {
        address from;
        address to;
        address operator;
        uint256 firstTokenId;
        uint256 quantity;
    }
    LastCall internal lastCall;
    function beforeTokenTransfers(address from, address to, address operator, uint256 firstTokenId, uint256 quantity) external {
        lastCall.from = from;
        lastCall.to = to;
        lastCall.operator = operator;
        lastCall.firstTokenId = firstTokenId;
        lastCall.quantity = quantity;
        numberTransfers += 1;
    }
    function getLastCall() public view returns (LastCall memory) {
        return lastCall;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ITransferHookExtension).interfaceId;
    }
}
