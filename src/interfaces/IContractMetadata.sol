// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IContractMetadata {
    /// Contract names do not match
    error UpgradeToMismatchedContractName(string expected, string actual);

    /// @notice Contract name returns the pretty contract name
    function contractName() external returns (string memory);

    /// @notice Contract URI returns the uri for more information about the given contract
    function contractURI() external returns (string memory);
}
