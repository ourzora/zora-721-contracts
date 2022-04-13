// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

interface IEditionSingleMintable {
  struct SaleDetails {
    // built-in eth sales
    bool publicSaleActive;
    uint256 publicSalePrice;
    // built-in eth pre-sales (merkle list authentication)
    bool presaleActive;
    uint256 presalePrice;

    // Information about the rest of the supply
    uint256 totalMinted;
    uint256 maxSupply;
  }
  event Sale(address indexed to, uint256 indexed quantity, uint256 indexed price);
  function purchase(uint256 quantity) external payable returns (uint256);
  function saleDetails() external view returns (SaleDetails memory);
  function adminMint(address to, uint256 quantity) external returns (uint256);
  function adminMintAirdrop(address[] memory to) external returns (uint256);
  function owner() external view returns (address);
}