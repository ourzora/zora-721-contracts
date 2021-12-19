import { NetworksUserConfig } from "hardhat/types";
import dotenv from 'dotenv';

// Setup env from .env file if presetn
dotenv.config();

const networks: NetworksUserConfig = {};

if (process.env.DEV_MNEMONIC) {
  networks.mumbai = {
    chainId: 80001,
    url: "https://rpc-mumbai.maticvigil.com",
    accounts: {
      mnemonic: process.env.DEV_MNEMONIC,
    },
    // Gas price needed because no estimation
    gasPrice: 30000000000,
  };
  networks.polygon = {
    chainId: 137,
    url: "https://polygon-rpc.com/",
    accounts: {
      mnemonic: process.env.DEV_MNEMONIC,
    },
    gasPrice: 80000000000,
  };
  if (process.env.RINKEBY_RPC) {
    networks.rinkeby = {
      chainId: 4,
      url: process.env.RINKEBY_RPC,
      accounts: {
        mnemonic: process.env.DEV_MNEMONIC,
      },
    };
  }
  if (process.env.MAINNET_RPC) {
    networks.rinkeby = {
      chainId: 1,
      url: process.env.MAINNET_RPC,
      accounts: [process.env.PROD_PRIVATE_KEY as string],
    };
  }
}

export default networks;
