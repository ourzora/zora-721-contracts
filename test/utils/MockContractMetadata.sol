// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IContractMetadata} from "../../src/interfaces/IContractMetadata.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MockContractMetadata is IContractMetadata, UUPSUpgradeable {
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

    function _authorizeUpgrade(address _newImplementation) internal override {}
}
