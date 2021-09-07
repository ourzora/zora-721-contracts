// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.6;

interface ISerialMintable {
  function mintSerial(address to) external returns (uint256);
  function mintSerials(address[] memory to) external returns (uint256);
}