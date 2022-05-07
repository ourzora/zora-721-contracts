// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {IFactoryUpgradeGate} from "./interfaces/IFactoryUpgradeGate.sol";

contract FactoryUpgradeGate is IFactoryUpgradeGate {
    mapping(address => mapping(address => bool)) private _validUpgradePaths;
    address public owner;

    event OwnerUpdated(address indexed newOwner);
    event UpgradePathRegistered(address newImpl, address oldImpl);
    event UpgradePathRemoved(address newImpl, address oldImpl);

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");

        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    /// @notice Ensures the given upgrade path is valid and does not overwrite existing storage slots
    /// @param _newImpl The proposed implementation address
    /// @param _currentImpl The current implementation address
    function isValidUpgradePath(address _newImpl, address _currentImpl) external view returns (bool) {
        return _validUpgradePaths[_newImpl][_currentImpl];
    }

    /// @notice Registers a new safe upgrade path for an implementation
    /// @param _newImpl The new implementation
    /// @param _supportedPrevImpls Safe implementations that can upgrade to this new implementation
    function registerNewUpgradePath(address _newImpl, address[] calldata _supportedPrevImpls) external onlyOwner {
        for (uint256 i = 0; i < _supportedPrevImpls.length; i++) {
            _validUpgradePaths[_newImpl][_supportedPrevImpls[i]] = true;
            emit UpgradePathRegistered(_newImpl, _supportedPrevImpls[i]);
        }
    }

    /// @notice Unregisters an upgrade path, in case of emergency
    /// @param _newImpl the newer implementation
    /// @param _prevImpl the older implementation
    function unregisterUpgradePath(address _newImpl, address _prevImpl) external onlyOwner {
        _validUpgradePaths[_newImpl][_prevImpl] = false;
        emit UpgradePathRemoved(_newImpl, _prevImpl);
    }

    /// @notice Sets the owner for the contract
    /// @param _owner The new owner
    function setOwner(address _owner) external onlyOwner {
        owner = _owner;

        emit OwnerUpdated(owner);
    }
}