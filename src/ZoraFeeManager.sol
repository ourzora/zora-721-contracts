// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC721Drop} from "./interfaces/IERC721Drop.sol";
import {IZoraFeeManager} from "./interfaces/IZoraFeeManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ZoraFeeManager is Ownable, IZoraFeeManager {
    mapping(address => uint256) private feeOverride;
    uint256 private immutable defaultFeeBPS;

    error NotCalledByOwner();

    event FeeOverrideSet(address indexed, uint256 indexed);

    constructor(uint256 _defaultFeeBPS, address feeManagerAdmin) {
        defaultFeeBPS = _defaultFeeBPS;
        _transferOwnership(feeManagerAdmin);
    }

    modifier onlyContractOwner(address mediaContract) {
        if (!IERC721Drop(mediaContract).isAdmin(msg.sender)) {
            revert NotCalledByOwner();
        }

        _;
    }

    function setFeeOverride(address mediaContract, uint256 amountBPS)
        external
        onlyContractOwner(mediaContract)
    {
        require(amountBPS < 5001, "Fee too high (not greater than 50%)");
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
