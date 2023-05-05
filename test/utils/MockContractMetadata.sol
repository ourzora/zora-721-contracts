// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IContractMetadata} from "../../src/interfaces/IContractMetadata.sol";

contract MockContractMetadata is IContractMetadata {
    string public override contractURI;
    string public override contractName;

    constructor(string memory _contractURI, string memory _contractName) {
        contractURI = _contractURI;
        contractName = _contractName;
    }

    function setContractURI(string memory _contractURI) external {
        contractURI = _contractURI;
    }

    function setContractName(string memory _contractName) external {
        contractName = _contractName;
    }
}
