// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC721Drop} from "../interfaces/IERC721Drop.sol";

contract ERC721DropStorageV2 {
     /// @notice Token gate
    IERC721Drop.TokenGate public tokenGate;
}
