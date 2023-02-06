// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library TransferHelperUtils {
    /// @dev Gas limit to send funds
    uint256 internal constant FUNDS_SEND_LOW_GAS_LIMIT = 110_000;

    // @dev Gas limit to send funds – usable for splits, can use with withdraws
    uint256 internal constant FUNDS_SEND_GAS_LIMIT = 310_000;

    function safeSendETHLowLimit(address recipient, uint256 value)
        internal
        returns (bool success)
    {
        (success, ) = recipient.call{
            value: value,
            gas: FUNDS_SEND_LOW_GAS_LIMIT
        }("");
    }

    function safeSendETH(address recipient, uint256 value)
        internal
        returns (bool success)
    {
        (success, ) = recipient.call{value: value, gas: FUNDS_SEND_GAS_LIMIT}(
            ""
        );
    }
}
