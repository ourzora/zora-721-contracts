// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";


library SafeSender {
  uint256 constant ETH_SEND_GAS_LIMIT = 210_000;

  function safeSendERC20(IERC20Upgradeable erc20, address recipient, uint256 amount) internal {
    SafeERC20Upgradeable.safeTransfer(erc20, recipient, amount);
  }

  function safeSendETH(address recipient, uint256 amount) internal {
    (bool success, ) = recipient.call{
        gas: ETH_SEND_GAS_LIMIT,
        value: amount
    }("");
    require(success, "Failed sending ETH");
  }
}