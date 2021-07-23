// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FundsRecoverable is AccessControl {
    /**
    Recover accidental tokens sent to contract
    */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) public {
        require(
            hasRole(AccessControl.DEFAULT_ADMIN_ROLE, msg.sender),
            "NOT AUTHD"
        );
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);
    }

    /**
    Recover accidental ETH sent to contract
    */
    function recoverETH() public {
        require(
            hasRole(AccessControl.DEFAULT_ADMIN_ROLE, msg.sender),
            "NOT AUTHD"
        );
        uint256 balance = address(this).balance;
        msg.sender.call{value: balance}("");
    }
}