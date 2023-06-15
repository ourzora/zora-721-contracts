import { defineConfig } from '@wagmi/cli';
import { foundry } from '@wagmi/cli/plugins';
import { readdirSync, readFileSync } from 'fs';

type ContractNames =
  | 'DropMetadataRenderer'
  | 'EditionMetadataRenderer'
  | 'FactoryUpgradeGate'
  | 'ERC721Drop'
  | 'ZoraNFTCreatorProxy'
  | 'ZoraNFTCreatorV1';

type Address = `0x${string}`;

const contractFilesToInclude: ContractNames[] = [
  'DropMetadataRenderer',
  'FactoryUpgradeGate',
  'EditionMetadataRenderer',
  'ERC721Drop',
  'ZoraNFTCreatorProxy',
  'ZoraNFTCreatorV1'
];

type Addresses = {
  [key in ContractNames]?: {
    [chainId: number]: Address;
  };
};

const getAddresses = () => {
  const addresses: Addresses = {};

  const addressesFiles = readdirSync('./addresses');

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
      readFileSync(`./addresses/${addressesFile}`, 'utf-8')
    ) as {
      DROP_METADATA_RENDERER: Address;
      EDITION_METADATA_RENDERER: Address;
      ERC721DROP_IMPL: Address;
      FACTORY_UPGRADE_GATE: Address;
      ZORA_NFT_CREATOR_PROXY: Address;
      ZORA_NFT_CREATOR_V1_IMPL: Address;
    };

    const chainId = parseInt(addressesFile.split('.')[0]);

    // addAddress(
    //   "DropMetadataRenderer",
    //   chainId,
    //   jsonAddress.DROP_METADATA_RENDERER
    // );
    // addAddress(
    //   "EditionMetadataRenderer",
    //   chainId,
    //   jsonAddress.EDITION_METADATA_RENDERER
    // );
    // addAddress("ERC721Drop", chainId, jsonAddress.ERC721DROP_IMPL);
    // addAddress("FactoryUpgradeGate", chainId, jsonAddress.FACTORY_UPGRADE_GATE);
    addAddress(
      'ZoraNFTCreatorV1',
      chainId,
      jsonAddress.ZORA_NFT_CREATOR_PROXY
    );
    // addAddress("ZoraNFTCreatorV1", chainId, jsonAddress.ZORA_NFT_CREATOR_V1_IMPL);
  }

  return addresses;
};

export default defineConfig({
  out: 'package/wagmiGenerated.ts',
  plugins: [
    foundry({
      deployments: getAddresses(),
      include: contractFilesToInclude.map(
        (contractName) => `${contractName}.json`
      )
    })
  ]
});
