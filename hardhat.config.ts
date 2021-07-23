import "@nomiclabs/hardhat-waffle";
import "hardhat-gas-reporter";
import "hardhat-typechain";
import "hardhat-deploy";
import "@nomiclabs/hardhat-etherscan";
import { task } from "hardhat/config";
import { HardhatUserConfig } from "hardhat/config";
import NETWORKS_CONFIG from './networks.private.json';
import apikeys from './apikeys.private.json';

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  // etherscan: {
  //   apiKey: apikeys.etherscan,
  // },
  gasReporter: {
    currency: 'USD',
    gasPrice: 20, 
    // coinmarketcap: apikeys.coinmarketcap,
  },
  networks: {
    hardhat: {
      // fix metamask
      chainId: 1337,
    },
    // mumbai: {
    //   chainId: 80001,
    //   url: "https://rpc-mumbai.maticvigil.com",
    // },
    ...NETWORKS_CONFIG,
  },
  namedAccounts: {
    deployer: 0,
    purchaser: 0,
  },
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
};

export default config;

