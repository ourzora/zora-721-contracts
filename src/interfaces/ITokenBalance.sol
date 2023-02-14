// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ITokenBalance {
    function balanceOf(address account) external view returns (uint256);
}
