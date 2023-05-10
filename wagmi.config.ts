import { defineConfig } from "@wagmi/cli";
import { foundry } from "@wagmi/cli/plugins";
import { readdirSync, readFileSync } from "fs";

type ContractNames =
  | "DropMetadataRenderer"
  | "EditionMetadataRenderer"
  | "FactoryUpgradeGate"
  | "ERC721Drop"
  | "ZoraNFTCreatorProxy"
  | "ZoraNFTCreatorV1";

type Address = `0x${string}`;

const contractFilesToInclude: ContractNames[] = [
  "DropMetadataRenderer",
  "FactoryUpgradeGate",
  "EditionMetadataRenderer",
  "ERC721Drop",
  "ZoraNFTCreatorProxy",
  "ZoraNFTCreatorV1",
];

type Addresses = {
  [key in ContractNames]?: {
    [chainId: number]: Address;
  };
};

const getAddresses = () => {
  const addresses: Addresses = {};

  const addressesFiles = readdirSync("./addresses");

  const addAddress = (
    contractName: ContractNames,
    chainId: number,
    address: Address
  ) => {
    if (!addresses[contractName]) {
      addresses[contractName] = {};
    }

    addresses[contractName]![chainId] = address;
  };

  for (const addressesFile of addressesFiles) {
    const jsonAddress = JSON.parse(
      readFileSync(`./addresses/${addressesFile}`, "utf-8")
    ) as {
      ZORA_NFT_CREATOR_PROXY: Address;
    };

    const chainId = parseInt(addressesFile.split(".")[0]);

    // the create v1 is the only that needs to be exported; 
    // all other addresses can be retreived from the create v1
    // we use the proxy address for the create v1
    addAddress("ZoraNFTCreatorV1", chainId, jsonAddress.ZORA_NFT_CREATOR_PROXY);
  }

  return addresses;
} 



export default defineConfig({
  out: "index.ts",
  plugins: [
    foundry({
      deployments: getAddresses(),
      include: contractFilesToInclude.map(
        (contractName) => `${contractName}.json`
      ),
    }),
  ],
});
