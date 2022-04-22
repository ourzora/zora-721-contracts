// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

interface IZoraDrop {
    struct SaleDetails {
        // built-in eth sales
        bool presaleActive;
        bool publicSaleActive;
        uint64 publicSaleStart;
        uint64 publicSaleEnd;
        uint256 publicSalePrice;
        uint64 presaleStart;
        uint64 presaleEnd;
        bytes32 presaleMerkleRoot;
        uint256 maxSalePurchasePerAddress;
        // Information about the rest of the supply
        uint256 totalMinted;
        uint256 maxSupply;
    }

    struct AddressMintDetails {
        uint256 totalMints;
        uint256 presaleMints;
        uint256 publicMints;
    }

    event Sale(
        address indexed to,
        uint256 indexed quantity,
        uint256 indexed pricePerToken,
        uint256 firstPurchasedTokenId
    );

    function purchase(uint256 quantity) external payable returns (uint256);

    function purchasePresale(
        uint256 quantity,
        uint256 maxQuantity,
        uint256 pricePerToken,
        bytes32[] memory merkleProof
    ) external payable returns (uint256);

    function saleDetails() external view returns (SaleDetails memory);

    function mintedPerAddress(address minter)
        external
        view
        returns (AddressMintDetails memory);

    function owner() external view returns (address);

    function adminMint(address to, uint256 quantity) external returns (uint256);

    function adminMintAirdrop(address[] memory to) external returns (uint256);
}
