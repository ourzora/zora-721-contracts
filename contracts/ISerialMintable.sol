// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.6;

interface ISerialMintable {
  function mintSerial(uint256 collectionId, address to) external returns (uint256);
  function mintSerials(uint256 collectionId, address[] memory to) external returns (uint256);
}