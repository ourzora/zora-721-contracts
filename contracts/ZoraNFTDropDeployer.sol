// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {ZoraFeeManager} from "./ZoraFeeManager.sol";
import {ERC721Drop} from "./ERC721Drop.sol";
import {EditionMetadataRenderer} from "./metadata/EditionMetadataRenderer.sol";
import {DropMetadataRenderer} from "./metadata/DropMetadataRenderer.sol";
import {ZoraNFTCreatorProxy} from "./ZoraNFTCreatorProxy.sol";
import {ZoraNFTCreatorV1} from "./ZoraNFTCreatorV1.sol";


contract ZoraNFTDropDeployer {
  constructor(address feeManagerAdmin, address zoraERC721TransferHelper, address sharedNFTLogicAddress) {
    ZoraFeeManager feeManager = new ZoraFeeManager(500, feeManagerAdmin);
    ERC721Drop dropContract = new ERC721Drop(feeManager, zoraERC721TransferHelper);
    EditionMetadataRenderer editionMetadata = new EditionMetadataRenderer(sharedNFTLogicAddress);
    DropMetadataRenderer dropMetadata = new DropMetadataRenderer();
    ZoraNFTCreatorV1 creator = new ZoraNFTCreatorV1(address(dropContract), editionMetadata, dropMetadata);
    ZoraNFTCreatorProxy proxy = new ZoraNFTCreatorProxy(address(creator), "");
  }
}
