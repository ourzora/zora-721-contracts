// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {ClonesUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import {ERC721Drop} from "./ERC721Drop.sol";
import {DropMetadataRenderer} from "./metadata/DropMetadataRenderer.sol";
import {IMetadataRenderer} from "./interfaces/IMetadataRenderer.sol";

contract ZoraNFTDropDeployer {
  event DeployedNewContract(address indexed from, address indexed newContract);
  address private immutable implementation;
  IMetadataRenderer private immutable metadataDropRendererAddress;
  constructor(address mediaContractBase, IMetadataRenderer _metadataDropRendererAddress) {
    implementation = mediaContractBase;
    metadataDropRendererAddress = _metadataDropRendererAddress;
  }

  function createDrop(
    address owner,
    string memory name,
    string memory symbol,
    address payable fundsRecipient,
    uint16 royaltyBPS,
    uint64 editionSize,
    string memory metadataURIBase,
    string memory metadataContractURI
  ) external returns (address) {
    bytes memory metadataInitializer = abi.encode(metadataURIBase, metadataContractURI);
    address newMediaContract = ClonesUpgradeable.clone(
        implementation
    );

    ERC721Drop(newMediaContract).initialize({
        _initialOwner: owner,
        _contractName: name,
        _contractSymbol: symbol,
        _fundsRecipient: fundsRecipient,
        _editionSize: editionSize,
        _royaltyBPS: royaltyBPS,
        _metadataRenderer: metadataDropRendererAddress,
        _metadataRendererInit: metadataInitializer
    });
    emit DeployedNewContract(msg.sender, newMediaContract);

    return newMediaContract;
  }
}
