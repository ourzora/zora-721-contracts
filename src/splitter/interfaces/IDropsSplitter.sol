// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;


interface IDropsSplitter {
    function onRegistryTransfer(uint256 id, address payable recipient) external;
    function shareOwner(uint256 id) external view returns (address);

    struct Share {
        uint96 numerator;
        address payable user;
    }

    struct SharesStorage {
        Share[] userShares;
        Share[] platformShares;
        uint96 userDenominator;
        uint96 platformDenominator;
    }

    error ShareDenominatorMismatch();
    error PlatformDenomiantorMismatch();
    error WrongSenderAccount();
    error SharesSizeTooLarge();

    event UserSharesUpdated(Share[] shares, uint96 denominator);
    event PlatformSharesUpdated(Share[] shares, uint96 denominator);

    event PlatformSplitWithdrawn(address user, uint256 amount);
    event UserSplitWithdrawn(address user, uint256 amount);
}
