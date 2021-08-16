// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FundsRecoverable is Ownable {
    /**
    Recover accidental tokens sent to contract
    */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) public onlyOwner {
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);
    }

    /**
    Recover accidental ETH sent to contract
    */
    function recoverETH() public onlyOwner {
        uint256 balance = address(this).balance;
        msg.sender.call{value: balance}("");
    }
}