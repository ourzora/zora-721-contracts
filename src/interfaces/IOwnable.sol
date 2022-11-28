// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This ownership interface matches OZ's ownable interface.
 *
 */
interface IOwnable {
    error ONLY_OWNER();
    error ONLY_PENDING_OWNER();

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event OwnerPending(
        address indexed previousOwner,
        address indexed potentialNewOwner
    );

    event OwnerCanceled(
        address indexed previousOwner,
        address indexed potentialNewOwner
    );

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() external view returns (address);
}
