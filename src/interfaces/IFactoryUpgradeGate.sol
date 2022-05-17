// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IFactoryUpgradeGate {
  function isValidUpgradePath(address _newImpl, address _currentImpl) external returns (bool);

  function registerNewUpgradePath(address _newImpl, address[] calldata _supportedPrevImpls) external;

  function unregisterUpgradePath(address _newImpl, address _prevImpl) external;
}