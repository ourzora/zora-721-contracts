// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IFactoryUpgradeGate} from "./interfaces/IFactoryUpgradeGate.sol";
import "./utils/OwnableSkeleton.sol";

contract FactoryUpgradeGate is IFactoryUpgradeGate, OwnableSkeleton {
    mapping(address => mapping(address => bool)) private _validUpgradePaths;

    event UpgradePathRegistered(address newImpl, address oldImpl);
    event UpgradePathRemoved(address newImpl, address oldImpl);

    modifier onlyOwner() {
        require(msg.sender == owner(), "only owner");

        _;
    }

    constructor(address _owner) {
        _setOwner(_owner);
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
}