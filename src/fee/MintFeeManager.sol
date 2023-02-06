// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {TransferHelperUtils} from "../utils/TransferHelperUtils.sol";
import {IMintFeeManager} from "../interfaces/IMintFeeManager.sol";

contract MintFeeManager is IMintFeeManager {
    uint256 public immutable mintFee;
    address public immutable mintFeeRecipient;

    constructor(uint256 _mintFee, address _mintFeeRecipient) {
        // Set fixed finders fee
        if (_mintFee >= 1 ether) {
            revert MintFeeCannotBeMoreThanOneETH(_mintFee);
        }
        mintFee = _mintFee;
        mintFeeRecipient = _mintFeeRecipient;
    }

    function _handleFeeAndGetValueSent()
        internal
        returns (uint256 ethValueSent)
    {
        ethValueSent = msg.value;
        // Handle mint fee
        ethValueSent -= mintFee;
        if (
            !TransferHelperUtils.safeSendETHLowLimit(mintFeeRecipient, mintFee)
        ) {
            revert CannotSendMintFee({
                mintFeeRecipient: mintFeeRecipient,
                mintFee: mintFee
            });
        }
    }
}
