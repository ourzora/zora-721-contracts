// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

interface IEditionSingleMintable {
  struct SaleDetails {
    bool active;
    uint256 price;
    uint256 totalMinted;
    uint256 maxSupply;
  }
  event Sale(address indexed to, uint256 indexed quantity, uint256 indexed price);
  function purchase(uint256 quantity) external payable returns (uint256);
  function saleDetails() external view returns (SaleDetails memory);
  // function mintEdition(address to, uint256 quantity) external returns (uint256);
  function mintEditions(address[] memory to) external returns (uint256);
  function owner() external view returns (address);
}