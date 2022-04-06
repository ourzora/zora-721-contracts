// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {IMetadataRenderer} from "../../interfaces/IMetadataRenderer.sol";

contract DummyMetadataRenderer is IMetadataRenderer {
    function tokenURI(address, uint256) external pure returns (string memory) {
        return "DUMMY";
    }
    function contractURI(address) external pure returns (string memory) {
        return "DUMMY";
    }
}
