// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

import {IDropsSplitter} from "./interfaces/IDropsSplitter.sol";
import {SafeSender} from "../utils/SafeSender.sol";
import {FundsReceiver} from "../utils/FundsReceiver.sol";
import {SplitterStorage} from "./SplitterStorage.sol";
import {IRegistry} from "./interfaces/IRegistry.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract DropsSplitter is SplitterStorage, FundsReceiver {
    using SafeSender for IERC20Upgradeable;
    using SafeSender for address payable;

    IRegistry public immutable registry;

    modifier onlySender(address matches) {
        if (matches != msg.sender) {
            revert WrongSenderAccount();
        }

        _;
    }

    constructor(IRegistry _newRegistry) {
        registry = _newRegistry;
    }

    function getCombinedNumerator(Share[] memory shares)
        internal
        view
        returns (uint256 numerator)
    {
        for (uint256 i = 0; i < shares.length; i++) {
            numerator += shares[i].numerator;
        }
    }

    function shareOwner(uint256 id) external view override returns (address) {
        return shares.userShares[id].user;
    }

    function setup(
        Share[] memory _userShares,
        uint96 _userDenominator,
        Share[] memory _platformShares,
        uint96 _platformDenominator
    ) public {
        if (getCombinedNumerator(_userShares) != _userDenominator) {
            revert ShareDenominatorMismatch();
        }
        if (getCombinedNumerator(_platformShares) > _platformDenominator) {
            revert PlatformDenomiantorMismatch();
        }

        for (uint256 i = 0; i < _userShares.length; i++) {
            shares.userShares.push(_userShares[i]);
            registry.mint(i, _userShares[i].user);
        }
        shares.userDenominator = _userDenominator;

        for (uint256 i = 0; i < _platformShares.length; i++) {
            shares.platformShares.push(_platformShares[i]);
        }
        shares.platformDenominator = _platformDenominator;

        emit UserSharesUpdated(_userShares, _userDenominator);
        emit PlatformSharesUpdated(_platformShares, _platformDenominator);
    }

    /// @notice Called by registry
    function onRegistryTransfer(uint256 id, address payable recipient)
        external
        onlySender(address(registry))
    {
        shares.userShares[id].user = recipient;
        emit UserSharesUpdated(shares.userShares, shares.userDenominator);
    }

    function updateSplit(Share[] memory _newShares, uint96 _newDenominator)
        external
    {
        if (getCombinedNumerator(_newShares) != _newDenominator) {
            revert ShareDenominatorMismatch();
        }

        // remove extra NFTs
        for (uint256 i = _newShares.length; i < shares.userShares.length; i++) {
            registry.burn(i);
        }

        for (
            uint256 i = 0;
            i < Math.min(_newShares.length, shares.userShares.length);
            i++
        ) {
            if (shares.userShares[i].user != _newShares[i].user) {
                registry.burn(i);
                registry.mint(i, _newShares[i].user);
            }
        }

        delete shares.userShares;
        for (uint256 i = 0; i < _newShares.length; i++) {
            shares.userShares.push(
                Share({
                    user: _newShares[i].user,
                    numerator: _newShares[i].numerator
                })
            );
        }
        shares.userDenominator = _newDenominator;
        emit UserSharesUpdated(_newShares, _newDenominator);
    }

    function updatePlatformSplit(
        Share[] memory _newPlatformShares,
        uint8 _newDenominator
    ) external {
        if (getCombinedNumerator(_newPlatformShares) > _newDenominator) {
            revert PlatformDenomiantorMismatch();
        }

        delete shares.platformShares;
        for (uint256 i = 0; i < _newPlatformShares.length; i++) {
            shares.platformShares.push(
                Share({
                    user: _newPlatformShares[i].user,
                    numerator: _newPlatformShares[i].numerator
                })
            );
        }
        shares.platformDenominator = _newDenominator;
        emit PlatformSharesUpdated(_newPlatformShares, _newDenominator);
    }

    function withdrawETH() external {
        // if no shares are set, fall back to previous distribution method???
        // such as after an upgrade

        // if (shares.userShares.length == 0) {
        //   // process upgrade
        // }

        uint256 balance = address(this).balance;

        if (primaryBalance > 0) {
            for (uint256 i = 0; i < shares.platformShares.length; i++) {
                uint256 value = (primaryBalance *
                    shares.platformShares[i].numerator) /
                    shares.platformDenominator;
                shares.platformShares[i].user.safeSendETH(value);
                balance -= value;
            }
        }

        for (uint256 i = shares.userShares.length; i >= 0; i--) {
            // For the first recipient, send all remaining value.
            uint256 value = i == 0
                ? balance
                : (balance * shares.userShares[i].numerator) /
                    shares.userDenominator;
            shares.userShares[i].user.safeSendETH(value);
            balance -= value;
        }
    }

    function withdrawERC20(IERC20Upgradeable tokenAddress) external {
        uint256 balance = tokenAddress.balanceOf(address(this));
        for (uint256 i = shares.userShares.length; i >= 0; i--) {
            // For the first recipient, send all remaining value.
            uint256 value = i == 0
                ? balance
                : (balance * shares.userShares[i].numerator) /
                    shares.userDenominator;
            tokenAddress.safeSendERC20(shares.userShares[i].user, value);
            balance -= value;
        }
    }
}
