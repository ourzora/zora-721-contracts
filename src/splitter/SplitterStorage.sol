// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IDropsSplitter} from "./interfaces/IDropsSplitter.sol";

abstract contract SplitterStorage is IDropsSplitter {
    SharesStorage public shares;
    uint256 public primaryBalance;
}