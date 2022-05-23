// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {Vm} from "forge-std/Vm.sol";
import {DSTest} from "ds-test/test.sol";

import {FactoryUpgradeGate} from "../src/FactoryUpgradeGate.sol";

/// @notice Test for factory upgrade gate
contract FactoryUpgradeGateTest is DSTest {
    Vm public constant vm = Vm(HEVM_ADDRESS);
    FactoryUpgradeGate public gate;

    function setUp() public {
        gate = new FactoryUpgradeGate(address(0xad));
    }

    function test_GateBlockedByDefault() public {
        assert(!gate.isValidUpgradePath(address(0x0), address(0x0)));
    }

    function test_AnyoneNotAllowedUpdate() public {
        address[] memory newPaths = new address[](1);
        newPaths[0] = address(0x1);
        vm.expectRevert(FactoryUpgradeGate.Access_OnlyOwner.selector);
        gate.registerNewUpgradePath(address(0x23), newPaths);
    }

    function test_AdminCanUpdate() public {
        vm.startPrank(address(0xad));
        address[] memory newPaths = new address[](1);
        newPaths[0] = address(0x1);
        gate.registerNewUpgradePath(address(0x23), newPaths);
        assert(gate.isValidUpgradePath(address(0x23), address(0x1)));
        assert(!gate.isValidUpgradePath(address(0x1), address(0x23)));
    }

    function test_AdminCanDelete() public {
        vm.startPrank(address(0xad));
        address[] memory newPaths = new address[](1);
        newPaths[0] = address(0x1);
        gate.registerNewUpgradePath(address(0x23), newPaths);
        assert(gate.isValidUpgradePath(address(0x23), address(0x1)));
        gate.unregisterUpgradePath(address(0x23), address(0x1));
        assert(!gate.isValidUpgradePath(address(0x23), address(0x1)));
    }
}
