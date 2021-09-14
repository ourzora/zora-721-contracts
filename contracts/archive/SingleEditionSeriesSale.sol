// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../ISerialSingleMintable.sol";

/**
    Example contract for a Eth series sale
    This utilizes the ISingleSerialMintable interface
 */
contract SingleEditionSeriesSale is ReentrancyGuardUpgradeable {
    event OnPauseChange(uint256 releaseId, bool pauseStatus);
    event OnNewRelease(uint256 releaseId);

    struct SketchRelease {
        uint256 maxAllowed;
        uint256 currentReleased;
        uint256 ethPrice;
        ISerialSingleMintable mintable;
        bool isPaused;
    }

    SketchRelease[] public releases;

    function createRelease(
        bool isPaused,
        uint256 maxAllowed,
        uint256 ethPrice,
        ISerialSingleMintable mintable
    ) public {
        require(mintable.owner() == msg.sender, "Only owner can create a sale");

        SketchRelease memory sketchRelease = SketchRelease({
            isPaused: isPaused,
            maxAllowed: maxAllowed,
            currentReleased: 0,
            ethPrice: ethPrice,
            mintable: mintable
        });

        emit OnNewRelease(releases.length);
        releases.push(sketchRelease);
    }

    function setPaused(uint256 releaseId, bool isPaused) public {
        require(releases[releaseId].mintable.owner() == msg.sender, "Not owner");
        releases[releaseId].isPaused = isPaused;
        emit OnPauseChange(releaseId, isPaused);
    }

    function mint(uint256 releaseId)
        public
        payable
        nonReentrant
        returns (uint256)
    {
        SketchRelease storage release = releases[releaseId];
        require(release.currentReleased < release.maxAllowed, "Sold out");
        require(!release.isPaused, "Paused");

        if (release.ethPrice > 0) {
            require(release.ethPrice == msg.value, "Wrong price");
            (bool sent, ) = release.mintable.owner().call{
                value: msg.value,
                gas: 34_000
            }("");
            require(sent, "Failed to send Eth");
        }

        release.currentReleased += 1;
        return release.mintable.mintSerial(msg.sender);
    }
}
