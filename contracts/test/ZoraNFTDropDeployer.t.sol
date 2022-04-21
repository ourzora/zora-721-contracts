// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

import {ZoraNFTDropDeployer} from "../ZoraNFTDropDeployer.sol";
import {IMetadataRenderer} from "../interfaces/IMetadataRenderer.sol";


contract ZoraFeeManagerTest is DSTest {
    Vm public constant vm = Vm(HEVM_ADDRESS);
    address public constant ADMIN_ADDRESS = address(23499);
    address public constant ZORA_PROXY_ADDRESS = address(123456);
    address public constant SHARED_NFT_LOGIC_ADDRESS = address(33);

    function test_deploy() public {
        ZoraNFTDropDeployer deployer = new ZoraNFTDropDeployer(
            ADMIN_ADDRESS,
            IMetadataRenderer(ZORA_PROXY_ADDRESS)
        );
    }
}
