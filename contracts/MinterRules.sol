// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ISerialMintable.sol";
import "./FundsRecoverable.sol";

contract MinterRules is Ownable, ReentrancyGuard, FundsRecoverable {
    event OnPauseChange(uint256 releaseId, bool pauseStatus);
    event OnNewRelease(uint256 releaseId);

    struct GasRule {
        uint256 maxGasAllowed;
        bool disallowZeroGas;
        bool enabled;
    }

    struct OwnershipRule {
        address tokenAddress;
        uint256 tokenIdRangeStart;
        uint256 tokenIdRangeEnd;
        bool enabled;
    }

    struct SketchRelease {
        GasRule gasRule;
        OwnershipRule ownershipRule;
        bool isPaused;
        uint256 maxAllowed;
        uint256 currentReleased;
        uint256 ethPrice;
        address payable recipient;
        address mintableAddress;
        uint256 mintableCollection;
    }

    SketchRelease[] private releases;

    function createRelease(
        GasRule memory sketchReleaseGasRule,
        OwnershipRule memory sketchReleaseRuleOwnership,
        bool isPaused,
        uint256 maxAllowed,
        uint256 ethPrice,
        address payable recipient,
        address mintableAddress,
        uint256 mintableCollection
    ) public onlyOwner {
        SketchRelease memory sketchRelease;
        sketchRelease.isPaused = isPaused;
        sketchRelease.maxAllowed = maxAllowed;
        sketchRelease.gasRule = sketchReleaseGasRule;
        sketchRelease.ownershipRule = sketchReleaseRuleOwnership;
        sketchRelease.recipient = recipient;
        sketchRelease.mintableAddress = mintableAddress;
        sketchRelease.mintableCollection = mintableCollection;

        emit OnNewRelease(releases.length);
        releases.push(sketchRelease);
    }

    function setPaused(uint256 releaseId, bool isPaused) public onlyOwner {
        releases[releaseId].isPaused = isPaused;
        emit OnPauseChange(releaseId, isPaused);
    }

    function getRelease(uint256 releaseId) public view returns (SketchRelease memory) {
        return releases[releaseId];
    }

    function mint(uint256 releaseId, uint256 tokenOwned)
        public
        payable
        nonReentrant
        returns (uint256)
    {
        SketchRelease memory release = getRelease(releaseId);
        require(!release.isPaused, "PAUSED");
        require(release.currentReleased < release.maxAllowed, "FINISHED");

        if (release.gasRule.enabled) {
            if (release.gasRule.disallowZeroGas) {
                require(tx.gasprice != 0, "GAS");
            }
            require(release.gasRule.maxGasAllowed <= tx.gasprice, "GAS");
        }

        if (release.ownershipRule.enabled) {
            require(
                tokenOwned >= release.ownershipRule.tokenIdRangeStart &&
                    tokenOwned <= release.ownershipRule.tokenIdRangeEnd,
                "OWNERSHIP"
            );
            require(
                IERC721(release.ownershipRule.tokenAddress).ownerOf(tokenOwned) == msg.sender,
                "OWNERSHIP"
            );
        }

        if (release.ethPrice > 0) {
            require(release.ethPrice == msg.value, "PRICE");
            (bool sent, bytes memory _data) = release.recipient.call{
                value: msg.value
            }("");
            require(sent, "Failed to send Ether");
        }

        release.currentReleased += 1;
        uint256 mintedToken = ISerialMintable(release.mintableAddress).mintSerial(
            releaseId, msg.sender
        );

        return mintedToken;
    }
}
