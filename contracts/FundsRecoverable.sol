// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract FundsRecoverable is OwnableUpgradeable {
    /**
    Recover accidental tokens sent to contract
    */
    function recoverERC20(address tokenAddress, uint256 tokenAmount)
        public
        onlyOwner
    {
        IERC20Upgradeable(tokenAddress).transfer(msg.sender, tokenAmount);
    }

    /**
    Recover accidental ETH sent to contract
    */
    function recoverETH() public onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "TransferFailed");
    }
}
