// SPDX-License-Identifier: GPL-3.0

/**

█▄░█ █▀▀ ▀█▀   █▀▀ █▀▄ █ ▀█▀ █ █▀█ █▄░█ █▀
█░▀█ █▀░ ░█░   ██▄ █▄▀ █ ░█░ █ █▄█ █░▀█ ▄█

▀█ █▀█ █▀█ ▄▀█
█▄ █▄█ █▀▄ █▀█

 */

pragma solidity 0.8.6;

import {PaymentSplitterUpgradeable} from "@openzeppelin/contracts-upgradeable/finance/PaymentSplitterUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IEditionSingleMintable} from "../IEditionSingleMintable.sol";

/**
WIP Idea: not tested, do not use yet
*/
contract SplitMinter is OwnableUpgradeable, PaymentSplitterUpgradeable {
  IEditionSingleMintable public immutable mintable;
    // Price for sale
    uint256 public salePrice;
    // Price or sale status changed
    event PriceChanged(uint256 amount);

    constructor(
        IEditionSingleMintable _mintable,
        address[] memory _payees,
        uint256[] memory _shares
    ) {
      mintable = _mintable;
       __Ownable_init();
       __PaymentSplitter_init(_payees, _shares);
    }

    /**
      @param _salePrice if sale price is 0 sale is stopped, otherwise that amount 
                       of ETH is needed to start the sale.
      @dev This sets a simple ETH sales price
           Setting a sales price allows users to mint the edition until it sells out.
           For more granular sales, use an external sales contract.
     */
    function setSalePrice(uint256 _salePrice) external onlyOwner {
        salePrice = _salePrice;
        emit PriceChanged(salePrice);
    }

    /**
      @dev This allows the user to purchase a edition edition
           at the given price in the contract.
     */
    function purchase() external payable returns (uint256) {
        require(salePrice > 0, "Not for sale");
        require(msg.value == salePrice, "Wrong price");
        return mintable.mintEdition(msg.sender);
    }

    receive() external payable virtual override {
        revert("Cannot send value directly");
    }
}
