# Deploying to a new chain

### 1. Setup `chainConfigs` file.

Use `1.json` for reference. We are ordering keys alphabetically.

```
{
  # owner of the factory contract – owner to allow upgrading public factory
  "FACTORY_OWNER": "0xd1d1D4e36117aB794ec5d4c78cBD3a8904E691D0",
  # upgrade gate for existing deployed 721 contracts owner – this address gates upgrades allowed
  "FACTORY_UPGRADE_GATE_OWNER": "0xd1d1D4e36117aB794ec5d4c78cBD3a8904E691D0",
  # mint fee amount in wei (0 is valid)
  "MINT_FEE_AMOUNT": 777000000000000,
  # recipient for above mint fee
  "MINT_FEE_RECIPIENT": "0xd1d1D4e36117aB794ec5d4c78cBD3a8904E691D0",
  # subscription market filter address for operator filter registry.
  # can be set to 0 to disable. see: https://github.com/ProjectOpenSea/operator-filter-registry
  "SUBSCRIPTION_MARKET_FILTER_ADDRESS": "0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6",
  # subscription market filter owner address.
  "SUBSCRIPTION_MARKET_FILTER_OWNER": "0x9AaC739c133074dB445183A95149880a2156541A",
  # pre-approved transfer helper for ZORA v3, likely should be 0 on new networks
  "ZORA_ERC721_TRANSFER_HELPER": "0x909e9efE4D87d1a6018C2065aE642b6D0447bc91"
}
```

### 2. Deploy forge script

    forge script script/Deploy.s.sol --broadcast --verify --rpc-url $ETH_RPC
  
For example, to deploy on optimism goerli, this is the forge command:

    forge script script/Deploy.s.sol --rpc-url https://goerli.optimism.io --verify --etherscan-api-key ${ETHERSCAN_OPTISM_API_KEY} --broadcast --interactives 1

Use your own RPC configuration variables

### 3. Copy new chain configuration for deployment

Copies new addresses over to `addresses` folder:

    node js-scripts/copy-latest-deployment-addresses.mjs deploy

### 4. Update node 
