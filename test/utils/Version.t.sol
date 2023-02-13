// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {Version} from "../../src/utils/Version.sol";

contract DemoContract is Version(2) {}

contract VersionTest is Test {
    function test_ContractGetsVersions() external {
        DemoContract demo = new DemoContract();
        assertEq(demo.contractVersion(), 2);
    }
}
