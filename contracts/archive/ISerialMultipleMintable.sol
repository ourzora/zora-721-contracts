// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.6;

interface ISerialMultipleMintable {
  function mintSerial(uint256 serialId, address to) external returns (uint256);
  function mintSerials(uint256 serialId, address[] memory to) external returns (uint256);
}