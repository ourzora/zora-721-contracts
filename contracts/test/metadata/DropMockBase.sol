// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

contract DropMockBase {
    mapping(address => bool) isAdminList;

    function setIsAdmin(address target, bool admin) external {
        isAdminList[target] = admin;
    }

    /// @dev Getter for admin role associated with the contract to handle metadata
    /// @return boolean if address is admin
    function isAdmin(address user) external view returns (bool) {
        return isAdminList[user];
    }
}
