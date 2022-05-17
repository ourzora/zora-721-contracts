// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {IMetadataRenderer} from "../../src/interfaces/IMetadataRenderer.sol";

contract DummyMetadataRenderer is IMetadataRenderer {
    function tokenURI(uint256) external pure override returns (string memory) {
        return "DUMMY";
    }
    function contractURI() external pure override returns (string memory) {
        return "DUMMY";
    }

     function initializeWithData(bytes memory data) external {
         // no-op
    }
}
