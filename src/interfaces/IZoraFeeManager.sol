// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IZoraFeeManager {
    function getZORAWithdrawFeesBPS(address sender) external returns (address payable, uint256);
}
