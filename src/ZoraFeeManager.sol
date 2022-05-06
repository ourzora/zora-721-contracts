// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {IZoraFeeManager} from "./interfaces/IZoraFeeManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ZoraFeeManager is Ownable, IZoraFeeManager {
    mapping(address => uint256) private feeOverride;
    uint256 private immutable defaultFeeBPS;

    event FeeOverrideSet(address indexed, uint256 indexed);

    constructor(uint256 _defaultFeeBPS, address feeManagerAdmin) {
        defaultFeeBPS = _defaultFeeBPS;
        _transferOwnership(feeManagerAdmin);
    }

    function setFeeOverride(address mediaContract, uint256 amountBPS)
        external
        onlyOwner
    {
        require(amountBPS < 2001, "Fee too high (not greater than 20%)");
        feeOverride[mediaContract] = amountBPS;
        emit FeeOverrideSet(mediaContract, amountBPS);
    }

    function getZORAWithdrawFeesBPS(address mediaContract)
        external
        view
        returns (address payable, uint256)
    {
        if (feeOverride[mediaContract] > 0) {
            return (payable(owner()), feeOverride[mediaContract]);
        }
        return (payable(owner()), defaultFeeBPS);
    }
}
