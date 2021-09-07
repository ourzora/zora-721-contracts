// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "./DynamicSerialMintable.sol";
import "hardhat/console.sol";

contract DynamicSerialCreator {
    uint256 atContract = 0;
    address public implementation;

    constructor(address _implementation) {
      implementation = _implementation;
    }

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
    ) public {
        address newContract = 
            ClonesUpgradeable.cloneDeterministic(
                implementation,
                bytes32(abi.encodePacked(atContract))
            );
        console.log(newContract);
        DynamicSerialMintable(newContract).initialize(
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
        // Move to next contract slot
        atContract++;
    }

    function getSerialAtId(uint256 serialId)
        public
        view
        returns (address)
    {
        return
            ClonesUpgradeable.predictDeterministicAddress(
                implementation,
                bytes32(abi.encodePacked(serialId)),
                address(this)
            );
    }

    // Emitted when a serial is created reserving the corresponding token IDs.
    event CreatedSerial(uint256 serialId, address creator, uint256 serialSize);
}
