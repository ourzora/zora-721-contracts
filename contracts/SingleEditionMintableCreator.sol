// SPDX-License-Identifier: GPL-3.0

/**
█▄░█ █▀▀ ▀█▀   █▀▀ █▀▄ █ ▀█▀ █ █▀█ █▄░█ █▀
█░▀█ █▀░ ░█░   ██▄ █▄▀ █ ░█░ █ █▄█ █░▀█ ▄█

▀█ █▀█ █▀█ ▄▀█
█▄ █▄█ █▀▄ █▀█
 */

pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "./SingleEditionMintable.sol";

contract SingleEditionMintableCreator {
    uint256 atContract = 0;
    address public implementation;

    /// Initializes factory with address of implementation logic
    /// @param _implementation SingleEditionMintable logic implementation contract to clone
    constructor(address _implementation) {
        implementation = _implementation;
    }

    /// Creates a new serial contract as a factory with a deterministic address
    /// Important: None of these fields (except the Url fields with the same hash) can be changed after calling
    /// @param _name Name of the serial contract
    /// @param _symbol Symbol of the serial contract
    /// @param _description Metadata: Description of the serial entry
    /// @param _animationUrl Metadata: Animation url (optional) of the serial entry
    /// @param _animationHash Metadata: SHA-256 Hash of the animation (if no animation url, can be 0x0)
    /// @param _imageUrl Metadata: Image url (semi-required) of the serial entry
    /// @param _imageHash Metadata: SHA-256 hash of the Image of the serial entry (if not image, can be 0x0)
    /// @param _serialSize Total size of the serial (number of possible editions)
    /// @param _royaltyBPS BPS amount of royalty
    function createSerial(
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _animationUrl,
        bytes32 _animationHash,
        string memory _imageUrl,
        bytes32 _imageHash,
        uint256 _serialSize,
        uint256 _royaltyBPS
    ) external returns (uint256) {
        address newContract = ClonesUpgradeable.cloneDeterministic(
            implementation,
            bytes32(abi.encodePacked(atContract))
        );
        SingleEditionMintable(newContract).initialize(
            msg.sender,
            _name,
            _symbol,
            _description,
            _animationUrl,
            _animationHash,
            _imageUrl,
            _imageHash,
            _serialSize,
            _royaltyBPS
        );
        emit CreatedSerial(atContract, msg.sender, _serialSize);
        // Returns the ID of the recently created minting contract 
        // Also increments for the next contract creation call
        return ++atContract;
    }

    /// Get serial given the created ID
    /// @param serialId id of serial to get contract for
    /// @return SingleEditionMintable Edition NFT contract
    function getSerialAtId(uint256 serialId)
        external
        view
        returns (SingleEditionMintable)
    {
        return
            SingleEditionMintable(
                ClonesUpgradeable.predictDeterministicAddress(
                    implementation,
                    bytes32(abi.encodePacked(serialId)),
                    address(this)
                )
            );
    }

    /// Emitted when a serial is created reserving the corresponding token IDs.
    /// @param serialId ID of newly created serial
    event CreatedSerial(uint256 serialId, address creator, uint256 serialSize);
}
