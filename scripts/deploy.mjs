import { deployAndVerify } from "./contract.mjs";
import { writeFile } from "fs/promises";
import dotenv from "dotenv";
import esMain from "es-main";

dotenv.config();

export async function setupContracts() {
  const feeManagerAdminAddress = process.env.FEE_MANAGER_ADMIN_ADDRESS;
  const zoraERC721TransferHelperAddress =
    process.env.ZORA_ERC_721_TRANSFER_HELPER_ADDRESS;
  const feeDefaultBPS = process.env.FEE_DEFAULT_BPS;

  console.log("deploying fee manager")
  const feeManager = await deployAndVerify(
    "contracts/ZoraFeeManager.sol:ZoraFeeManager",
    [feeDefaultBPS, feeManagerAdminAddress]
  );
  const feeManagerAddress = feeManager.deployed.deploy.deployedTo;
  console.log("deployed fee manager to ", feeManagerAddress)
  console.log("deploying Erc721Drop")
  const dropContract = await deployAndVerify(
    "contracts/ERC721Drop.sol:ERC721Drop",
    [feeManagerAddress, zoraERC721TransferHelperAddress]
  );
  const dropContractAddress = dropContract.deployed.deploy.deployedTo;
  console.log("deployed drop contract to ", dropContractAddress)
  console.log("deploying drops metadata")
  const dropMetadataContract = await deployAndVerify(
    "contracts/metadata/DropMetadataRenderer.sol:DropMetadataRenderer"
  );
  const dropMetadataAddress = dropMetadataContract.deployed.deploy.deployedTo;
  console.log("deployed drops metadata to", dropMetadataAddress)

  console.log("deploying shared nft logic")
  const sharedNFTLogicContract = await deployAndVerify(
    "contracts/utils/SharedNFTLogic.sol:SharedNFTLogic"
  );
  const sharedNFTLogicAddress = sharedNFTLogicContract.deployed.deploy.deployedTo;
  console.log("deployed shared nft logic to", sharedNFTLogicAddress)

  console.log("deploying editions metadata")
  const editionsMetadataContract = await deployAndVerify(
    "contracts/metadata/EditionMetadataRenderer.sol:EditionMetadataRenderer", [sharedNFTLogicAddress]
  );
  const editionsMetadataAddress = editionsMetadataContract.deployed.deploy.deployedTo;
  console.log("deployed drops metadata to", editionsMetadataAddress)

  // const creator = await deployAndVerify(
  //   "contracts/ZoraNFTDropDeployer.sol:ZoraNFTDropDeployer",
  //   [dropContractAddress, dropMetadataAddress]
  // );
  return {
    feeManager,
    dropContract,
    dropMetadataContract,
    editionsMetadataContract
    // creator,
  };
}

async function main() {
  const output = await setupContracts();
  const date = new Date().toISOString().slice(0, 10);
  writeFile(`./deployments/${date}.${process.env.CHAIN}.json`, JSON.stringify(output));
}

if (esMain(import.meta)) {
  // Run main
  await main();
}
