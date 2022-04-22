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

  const feeManager = await deployAndVerify(
    "contracts/ZoraFeeManager.sol:ZoraFeeManager",
    [feeDefaultBPS, feeManagerAdminAddress]
  );
  const feeManagerAddress = feeManager.deployed.deploy.deployedTo;
  const dropContract = await deployAndVerify(
    "contracts/ERC721Drop.sol:ERC721Drop",
    [feeManagerAddress, zoraERC721TransferHelperAddress]
  );
  const dropContractAddress = dropContract.deployed.deploy.deployedTo;
  const dropMetadataContract = await deployAndVerify(
    "contracts/metadata/DropMetadataRenderer.sol:DropMetadataRenderer"
  );
  const dropMetadataAddress = dropMetadataContract.deployed.deploy.deployedTo;
  const creator = await deployAndVerify(
    "contracts/ZoraNFTDropDeployer.sol:ZoraNFTDropDeployer",
    [dropContractAddress, dropMetadataAddress]
  );
  return {
    feeManager,
    dropContract,
    dropMetadataContract,
    creator,
  };
}

async function main() {
  const output = await setupContracts();
  const date = new Date().toISOString().slice(0, 10);
  writeFile(`./deployments/${date}.json`, JSON.stringify(output));
}

if (esMain(import.meta)) {
  // Run main
  await main();
}
