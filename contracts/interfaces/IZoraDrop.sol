// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

interface IZoraDrop {
  struct SaleDetails {
    // built-in eth sales
    bool publicSaleActive;
    uint256 publicSalePrice;
    bool presaleActive;

    uint256 maxSalePurchasePerAddress;

    // Information about the rest of the supply
    uint256 totalMinted;
    uint256 maxSupply;
  }

  event Sale(address indexed to, uint256 indexed quantity, uint256 indexed pricePerToken, uint256 firstPurchasedTokenId);
  
  function purchase(uint256 quantity) external payable returns (uint256);
  function purchasePresale(
      uint256 quantity,
      uint256 maxQuantity,
      uint256 pricePerToken,
      bytes32[] memory merkleProof
  ) external payable returns (uint256);

  function saleDetails() external view returns (SaleDetails memory);

  function owner() external view returns (address);

  function adminMint(address to, uint256 quantity) external returns (uint256);
  function adminMintAirdrop(address[] memory to) external returns (uint256);
}