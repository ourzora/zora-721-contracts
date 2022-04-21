// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {DSTest} from "ds-test/test.sol";
import {ZoraFeeManager} from "../../ZoraFeeManager.sol";
import {MockUser} from "../utils/MockUser.sol";
import {Vm} from "forge-std/Vm.sol";

contract ZoraFeeManagerTest is DSTest {
    
    MockUser mockUser;
    Vm public constant vm = Vm(HEVM_ADDRESS);
    address public constant mediaContract = address(123456);

    function setUp() public {

    }

    function test_GetDefaultFee() public {
        
    }
}
