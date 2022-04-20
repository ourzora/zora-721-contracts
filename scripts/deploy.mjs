import { deployAndVerify } from "./contract.mjs";
import { writeFile } from "fs/promises";

// RINKEBY CONSTANTS
const feeManagerAdmin = "0x9444390c01Dd5b7249E53FAc31290F7dFF53450D";
const zoraERC721TransferHelperAddress =
  "0x029AA5a949C9C90916729D50537062cb73b5Ac92";
const feeDefaultBPS = "500";

export async function setupContracts() {
  const feeManager = await deployAndVerify(
    "contracts/ZoraFeeManager.sol:ZoraFeeManager",
    [feeDefaultBPS, feeManagerAdmin]
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

if (require.main === module) {
  // Run main
  await main();
}
