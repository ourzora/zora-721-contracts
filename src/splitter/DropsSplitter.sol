// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {IDropsSplitter} from "./interfaces/IDropsSplitter.sol";
import {SafeSender} from "../utils/SafeSender.sol";
import {FundsReceiver} from "../utils/FundsReceiver.sol";
import {SplitterStorage} from "./SplitterStorage.sol";
import {ISplitRegistry} from "./interfaces/ISplitRegistry.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract DropsSplitter is
    SplitterStorage,
    FundsReceiver,
    ReentrancyGuardUpgradeable
{
    using SafeSender for IERC20Upgradeable;
    using SafeSender for address payable;

    ISplitRegistry immutable registry;

    constructor(ISplitRegistry _splitRegistry) {
        registry = _splitRegistry;
    }

    /// @notice Allows only the sender of the address to update the function
    /// @param matches address to allow
    modifier onlySender(address matches) {
        if (matches != msg.sender) {
            revert WrongSenderAccount();
        }

        _;
    }

    /// @notice Validates max share size is less than max
    /// @param size size to validate
    /// @param max max to validate
    modifier validateMaxSharesSize(uint256 size, uint256 max) {
        if (size > max) {
            revert SharesSizeTooLarge();
        }

        _;
    }

    function getCombinedNumerator(Share[] memory _shares)
        internal
        pure
        returns (uint256 numerator)
    {
        for (uint256 i = 0; i < _shares.length; i++) {
            numerator += _shares[i].numerator;
        }
    }

    /// @notice Get the owner of a specific share ID
    /// @param id share ID to get the owner of
    /// @return The user of the share to return
    function shareOwner(uint256 id) external view override returns (address) {
        return shares.userShares[id].user;
    }

    function getShareForUser(address user)
        external
        view
        returns (
            address share,
            uint256 numerator,
            uint256 denominator
        )
    {
        for (uint256 i = 0; i < shares.userShares.length; i++) {
            if (shares.userShares[i].user == user) {
                share = shares.userShares[i].user;
                numerator = shares.userShares[i].numerator;
                denominator = shares.userDenominator;
            }
        }
    }

    function _setupSplit(
        Share[] memory _userShares,
        uint96 _userDenominator,
        Share[] memory _platformShares,
        uint96 _platformDenominator
    ) internal {
        _updatePlatformSplit(_platformShares, _platformDenominator);
        _updateUserSplit(_userShares, _userDenominator);
    }

    function _setupSplit(SplitSetupParams memory _params) internal {
        _updatePlatformSplit(
            _params.platformShares,
            _params.platformDenominator
        );
        _updateUserSplit(_params.userShares, _params.userDenominator);
    }

    /// @notice Called by registry when an NFT is transferred
    /// @param id of the NFT transferred
    /// @param recipient new recipient of the transfer
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

    /// @dev Throws on authorized split update
    function _authorizeSplitUpdate() internal virtual;

    function updatePlatformSplit(
        Share[] memory _newPlatformShares,
        uint96 _newDenominator
    ) external {
        _authorizeSplitUpdate();
        _updatePlatformSplit(_newPlatformShares, _newDenominator);
    }

    /// @notice Set platform split to new shares and denominator.
    /// @param _newPlatformShares New platform shares in split
    /// @param _newDenominator New deonominator of split
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

    function _setPrimaryBalance(uint256 _primaryBalance) internal {
        require(_primaryBalance <= address(this).balance, "too high");
        primaryBalance = _primaryBalance;
    }

    function withdrawETH() external nonReentrant {
        // if no shares are set, fall back to previous distribution method???
        // such as after an upgrade

        // if (shares.userShares.length == 0) {
        //     _legacySharesPayout();
        //     process upgrade
        // }

        uint256 balance = address(this).balance;

        if (primaryBalance > 0) {
            for (uint256 i = 0; i < shares.platformShares.length; i++) {
                uint256 value = (primaryBalance *
                    shares.platformShares[i].numerator) /
                    shares.platformDenominator;
                balance -= value;
                emit PlatformSplitWithdrawn(
                    shares.platformShares[i].user,
                    value
                );
                shares.platformShares[i].user.safeSendETH(value);
            }
        }

        for (uint256 i = shares.userShares.length; i > 0; ) {
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

    function withdrawERC20(IERC20Upgradeable tokenAddress)
        external
        nonReentrant
    {
        uint256 balance = tokenAddress.balanceOf(address(this));
        for (uint256 i = shares.userShares.length; i-- > 0; ) {
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
