// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

import {IDropsSplitter} from "./interfaces/IDropsSplitter.sol";
import {SafeSender} from "../utils/SafeSender.sol";
import {FundsReceiver} from "../utils/FundsReceiver.sol";
import {SplitterStorage} from "./SplitterStorage.sol";
import {IRegistry} from "./interfaces/IRegistry.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {console2} from "forge-std/console2.sol";

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

    modifier validateMaxSharesSize(uint256 size, uint256 max) {
        if (size > max) {
            revert SharesSizeTooLarge();
        }

        _;
    }

    constructor(IRegistry _newRegistry) {
        registry = _newRegistry;
    }

    function getCombinedNumerator(Share[] memory shares)
        internal
        pure
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
        _updatePlatformSplit(_platformShares, _platformDenominator);
        _updateUserSplit(_userShares, _userDenominator);
    }

    /// @notice Called by registry
    function onRegistryTransfer(uint256 id, address payable recipient)
        external
        onlySender(address(registry))
    {
        shares.userShares[id].user = recipient;
        emit UserSharesUpdated(shares.userShares, shares.userDenominator);
    }

    function updateUserSplit(Share[] memory _newShares, uint96 _newDenominator)
        external
    {
        _updateUserSplit(_newShares, _newDenominator);
    }

    function _updateUserSplit(Share[] memory _newShares, uint96 _newDenominator)
        internal
        validateMaxSharesSize(_newShares.length, 8)
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

        uint256 lastSharesSize = shares.userShares.length;
        delete shares.userShares;
        for (uint256 i = 0; i < _newShares.length; i++) {
            if (i >= lastSharesSize) {
                registry.mint(i, _newShares[i].user);
            }
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
        uint96 _newDenominator
    ) external {
        _updatePlatformSplit(_newPlatformShares, _newDenominator);
    }

    function _updatePlatformSplit(
        Share[] memory _newPlatformShares,
        uint96 _newDenominator
    ) internal validateMaxSharesSize(_newPlatformShares.length, 4) {
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

    /// TODO: call with purchase fn
    function setPrimaryBalance(uint256 _primaryBalance) external {
        require (_primaryBalance <= address(this).balance, "too high");
        primaryBalance = _primaryBalance;
    }

    /// TODO: re-entracy + access control
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
                balance -= value;
                emit PlatformSplitWithdrawn(shares.platformShares[i].user, value);
                shares.platformShares[i].user.safeSendETH(value);
            }
        }

        for (uint256 i = shares.userShares.length; i > 0;) {
            // i cannot increment below 0 for test :(
            if (i != 0) {
                i--;
            }

            // For the first recipient, send all remaining value.
            uint256 value = i == 0
                ? balance
                : (balance * shares.userShares[i].numerator) /
                    shares.userDenominator;
            balance -= value;
            emit UserSplitWithdrawn(shares.userShares[i].user, value);
            shares.userShares[i].user.safeSendETH(value);
        }
    }

    /// TODO: re-entracy + access control
    function withdrawERC20(IERC20Upgradeable tokenAddress) external {
        uint256 balance = tokenAddress.balanceOf(address(this));
        for (uint256 i = shares.userShares.length; i-- > 0;) {
            // For the first recipient, send all remaining value.
            uint256 value = i == 0
                ? balance
                : (balance * shares.userShares[i].numerator) /
                    shares.userDenominator;
            balance -= value;
            tokenAddress.safeSendERC20(shares.userShares[i].user, value);
        }
    }
}
