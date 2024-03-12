// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ITransferHookExtension {
   function beforeTokenTransfers(address from, address to, uint256 startTokenId, uint256 quantity) external; 
   function supportsInterface(bytes4 interfaceId) external returns (bool);
}