import {
  deployAndVerify,
} from "./contract.mjs";
import { writeFile } from "fs/promises";
import dotenv from "dotenv";
import esMain from "es-main";

dotenv.config({
  path: `.env.${process.env.CHAIN}`,
});

export async function setupContracts() {
  const creatorProxyAddress = process.env.CREATOR_PROXY_ADDRESS;

  if (!creatorProxyAddress) {
    throw new Error("creator proxy address required");
  }

  const feeManager = process.env.FEE_MANAGER_ADDRESS;
  if (!feeManager) {
    throw new Error("Fee manager address required");
  }

  let editionMetadataAddress = process.env.EDITION_METADATA_ADDRESS;
  let dropMetadataAddress = process.env.DROP_METADATA_CONTRACT_ADDRESS;
  const dropContractAddress = process.env.DROP_CONTRACT_ADDRESS;

  if (!sharedNFTLogicAddress && !dropMetadataAddress) {
    throw new Error("Shared NFT Logic address is required for drops");
  }

  if (!dropContractAddress) {
    throw new Error("missing drop contract address");
  }

  if (dropMetadataAddress && editionMetadataAddress) {
    throw new Error("At least one of drop or edition needs to be updated");
  }

  if (!editionMetadataAddress) {
    console.log("deploying editions metadata");
    const editionsMetadataContract = await deployAndVerify(
      "src/metadata/EditionMetadataRenderer.sol:EditionMetadataRenderer",
      []
    );
    editionsMetadataAddress =
      editionsMetadataContract.deployed.deploy.deployedTo;
    console.log("deployed drops metadata to", editionsMetadataAddress);
  }

  if (!dropMetadataAddress) {
    console.log("deploying drops metadata");
    const editionsMetadataContract = await deployAndVerify(
      "src/metadata/DropMetadataRenderer.sol:DropMetadataRenderer",
      [sharedNFTLogicAddress]
    );
    editionsMetadataAddress =
      editionsMetadataContract.deployed.deploy.deployedTo;
    console.log("deployed drops metadata to", editionsMetadataAddress);
  }

  console.log("deploying creator implementation");
  const creatorImpl = await deployAndVerify(
    "src/ZoraNFTCreatorV1.sol:ZoraNFTCreatorV1",
    [dropContractAddress, editionsMetadataAddress, dropMetadataAddress]
  );
  console.log(
    "deployed creator implementation to",
    creatorImpl.deployed.deploy.deployedTo
  );

  return {
    feeManager,
    dropContract,
    dropMetadataContract,
    editionsMetadataContract,
    creatorImpl,
    creatorProxyAddress,
  };
}

async function main() {
  const output = await setupContracts();
  const date = new Date().toISOString().slice(0, 10);
  writeFile(
    `./deployments/${date}.${process.env.CHAIN}.json`,
    JSON.stringify(output, null, 2)
  );
}

if (esMain(import.meta)) {
  // Run main
  await main();
}
