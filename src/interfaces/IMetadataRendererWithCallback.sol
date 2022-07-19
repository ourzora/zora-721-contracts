// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IMetadataRenderer} from "./IMetadataRenderer.sol";

interface IMetadataRendererWithCallback is IMetadataRenderer {
  /// Called when there is a batch transfer.
  function batchTransferCallback(address fromAddress, address toAddress, uint256 startTokenId, uint256 tokenQuantity) external;
  /// May not exist.
  function hasBatchTransferCallback() external returns (bool);
}
