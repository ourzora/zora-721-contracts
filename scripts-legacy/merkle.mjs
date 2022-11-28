import { MerkleTree } from "merkletreejs";
import { defaultAbiCoder } from "@ethersproject/abi";
import { hexValue } from "@ethersproject/bytes";
import { getAddress } from "@ethersproject/address";
import keccak256 from "keccak256";

export function hashForEntry(entry) {
  return keccak256(
    defaultAbiCoder.encode(
      ["address", "uint256", "uint256"],
      [getAddress(entry.minter), entry.maxCount, entry.price]
    )
  );
}

export function makeTree(entries) {
  entries = entries.map((entry) => {
    entry.hash = hashForEntry(entry);
    console.log(entry.hash);
    return entry;
  });
  const tree = new MerkleTree(
    entries.map((entry) => entry.hash),
    keccak256,
    { sortPairs: true }
  );
  entries = entries.map((entry) => {
    entry.hash = hexValue(entry.hash);
    entry.proof = tree.getHexProof(entry.hash);
    return entry;
  });

  return {
    tree,
    root: tree.getHexRoot(),
    entries,
  };
}
