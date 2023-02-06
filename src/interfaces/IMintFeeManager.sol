// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IMintFeeManager {
    error MintFeeCannotBeMoreThanOneETH(uint256 mintFeeBPS);

    error CannotSendMintFee(address mintFeeRecipient, uint256 mintFee);

    function mintFee() external view returns (uint256);

    function mintFeeRecipient() external view returns (address);
}
