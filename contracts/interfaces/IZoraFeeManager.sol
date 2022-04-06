// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

interface IZoraFeeManager {
    function getZORAWithdrawFeesBPS(address sender) external returns (address payable, uint256);
}
