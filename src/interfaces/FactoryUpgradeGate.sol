// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

interface FactoryUpgradeGate {
  function isValidUpgrade(address newImplementation) external returns (bool);
}