// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ForkDeploymentConfig} from "../../src/DeploymentConfig.sol";

contract ForkHelper is ForkDeploymentConfig {
    /// @notice gets the chains to do fork tests on, by reading environment var FORK_TEST_CHAINS.
    /// Chains are by name, and must match whats under `rpc_endpoints` in the foundry.toml
    function getForkTestChains() internal view returns (string[] memory result) {
        try vm.envString("FORK_TEST_CHAINS", ",") returns (string[] memory forkTestChains) {
            result = forkTestChains;
        } catch {
            result = new string[](0);
        }
    }
}
