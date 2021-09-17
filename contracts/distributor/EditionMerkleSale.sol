// SPDX-License-Identifier: GPL-3.0

import {IEditionSingleMintable} from "../IEditionSingleMintable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

pragma solidity 0.8.6;

contract SingleEditionMintableDistributor {
  IEditionSingleMintable private immutable mintable;
  bytes32 merkleRoot;

  mapping(uint256 => uint256) private claimedBitMap;

  // From astrodrop (https://etherscan.io/address/0x4f96cccfd25b4b7a89062d52c3099e1a97793a99#code)
  function isClaimed(uint256 index) public view returns (bool) {
      uint256 claimedWordIndex = index / 256;
      uint256 claimedBitIndex = index % 256;
      uint256 claimedWord = claimedBitMap[claimedWordIndex];
      uint256 mask = (1 << claimedBitIndex);
      return claimedWord & mask == mask;
  }
  function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

  constructor(IEditionSingleMintable _mintable, bytes32 _merkleRoot) {
    mintable = _mintable;
    merkleRoot = _merkleRoot;
  }

  function claim(uint256 index, bytes32[] memory merkleProof) public {
    require(!isClaimed(index));
    bytes32 node = keccak256(abi.encodePacked(index, msg.sender));
    require(MerkleProof.verify(merkleProof, merkleRoot, node), 'Invalid proof');
    mintable.mintEdition(msg.sender);
    _setClaimed(index);
  }
}