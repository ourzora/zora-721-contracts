import {
  deployAndVerify,
  retryDeploy,
  retryVerify,
  timeout,
} from "./contract.mjs";
import { writeFile } from "fs/promises";
import dotenv from "dotenv";
import esMain from "es-main";

dotenv.config({
  path: `.env.${process.env.CHAIN}`,
});

export async function setupContracts() {
  const feeManagerAdminAddress = process.env.FEE_MANAGER_ADMIN_ADDRESS;
  const zoraERC721TransferHelperAddress =
    process.env.ZORA_ERC_721_TRANSFER_HELPER_ADDRESS;
  const feeDefaultBPS = process.env.FEE_DEFAULT_BPS;
  const creatorProxyAddress = process.env.CREATOR_PROXY_ADDRESS;
  // const sharedNFTLogicAddress = process.env.SHARED_NFT_LOGIC_ADDRESS;
  //
  // if (!sharedNFTLogicAddress) {
  //   throw new Error("shared nft logic address is required");
  // }

  if (!creatorProxyAddress) {
    throw new Error("creator proxy address is required");
  }

  if (!zoraERC721TransferHelperAddress) {
    throw new Error("erc721 transfer helper address is required");
  }

  if (!feeManagerAdminAddress) {
    throw new Error("fee manager admin address is required");
  }

  console.log("deploying upgrade gate");
  const upgradeGate = await deployAndVerify(
    "src/FactoryUpgradeGate.sol:FactoryUpgradeGate",
    [feeManagerAdminAddress]
  );
  const upgradeGateAddress = upgradeGate.deployed.deploy.deployedTo;
  console.log("Deployed upgrade gate to", upgradeGateAddress);

  console.log("deploying fee manager");
  const feeManager = await deployAndVerify(
    "src/ZoraFeeManager.sol:ZoraFeeManager",
    [feeDefaultBPS, feeManagerAdminAddress]
  );
  const feeManagerAddress = feeManager.deployed.deploy.deployedTo;
  console.log("deployed fee manager to ", feeManagerAddress);
  console.log("deploying Erc721Drop");
  const dropContract = await deployAndVerify("src/ERC721Drop.sol:ERC721Drop", [
    feeManagerAddress,
    zoraERC721TransferHelperAddress,
    upgradeGateAddress,
  ]);
  const dropContractAddress = dropContract.deployed.deploy.deployedTo;
  console.log("deployed drop contract to ", dropContractAddress);
  console.log("deploying drops metadata");
  const dropMetadataContract = await deployAndVerify(
    "src/metadata/DropMetadataRenderer.sol:DropMetadataRenderer"
  );
  const dropMetadataAddress = dropMetadataContract.deployed.deploy.deployedTo;
  console.log("deployed drops metadata to", dropMetadataAddress);

  console.log("deploying shared nft logic");
  const sharedNFTLogicContract = await deployAndVerify(
    "src/utils/SharedNFTLogic.sol:SharedNFTLogic"
  );
  const sharedNFTLogicAddress = sharedNFTLogicContract.deployed.deploy.deployedTo;
  console.log("deployed shared nft logic to", sharedNFTLogicAddress);

  console.log("deploying editions metadata");
  const editionsMetadataContract = await deployAndVerify(
    "src/metadata/EditionMetadataRenderer.sol:EditionMetadataRenderer",
    [sharedNFTLogicAddress]
  );
  const editionsMetadataAddress =
    editionsMetadataContract.deployed.deploy.deployedTo;
  console.log("deployed drops metadata to", editionsMetadataAddress);

  console.log("deploying creator implementation");
  const creatorImpl = await deployAndVerify(
    "src/ZoraNFTCreatorV1.sol:ZoraNFTCreatorV1",
    [dropContractAddress, editionsMetadataAddress, dropMetadataAddress]
  );
  console.log(
    "deployed creator implementation to",
    creatorImpl.deployed.deploy.deployedTo
  );

  // console.log("deploying creator proxy");
  // const creatorProxy = await retryDeploy(
  //   2,
  //   "src/ZoraNFTCreatorProxy.sol:ZoraNFTCreatorProxy",
  //   [creatorImpl.deployed.deploy.deployedTo, '""']
  // );
  // await timeout(10000);
  // await retryVerify(
  //   3,
  //   creatorProxy.deploy.deployedTo,
  //   "src/ZoraNFTCreatorProxy.sol:ZoraNFTCreatorProxy",
  //   [creatorImpl.deployed.deploy.deployedTo, []]
  // );
  // console.log("deployed creator proxy to ", creatorProxy.deploy.deployedTo);
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
