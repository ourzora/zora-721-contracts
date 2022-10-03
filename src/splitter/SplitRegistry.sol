// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {SplitRegistryNFT} from "./SplitRegistryNFT.sol";
import {IDropsSplitter} from "./interfaces/IDropsSplitter.sol";
import {IRegistry} from "./interfaces/IRegistry.sol";

contract SplitRegistry is SplitRegistryNFT, IRegistry {
    constructor() {
        setup("ZORA Split Registry", "ZSPLIT");
    }

    function _getTokenId(address sender, uint256 splitIndex)
        internal
        pure
        returns (uint256)
    {
        if (splitIndex > type(uint96).max) {
            revert TokenIDTooLarge();
        }
        return (uint160(sender) << 96) + uint96(splitIndex);
    }

    function _extractTokenId(uint256 tokenId)
        internal
        pure
        returns (address sender, uint256 splitIndex)
    {
        splitIndex = tokenId | ~type(uint160).max;
        sender = address(uint160(tokenId << 96));
    }

    function mint(uint256 id, address user) external {
        _mint(user, _getTokenId(msg.sender, id));
    }

    function burn(uint256 id) external {
        _burn(_getTokenId(msg.sender, id));
    }

    function _setOwner() internal {}

    function _getOwner(uint256 tokenId)
        internal
        view
        override
        returns (address)
    {
        (address sender, uint256 splitIndex) = _extractTokenId(tokenId);
        return IDropsSplitter(sender).shareOwner(splitIndex);
    }

    function _setOwner(uint256 tokenId, address newOwner) internal override {
        (address sender, uint256 splitIndex) = _extractTokenId(tokenId);
        IDropsSplitter(sender).onRegistryTransfer(
            splitIndex,
            payable(newOwner)
        );
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        // Use rendering library for split NFT
        return "";
    }

    function contractURI() public returns (string memory) {
        // Return constant string
        return "";
    }
}