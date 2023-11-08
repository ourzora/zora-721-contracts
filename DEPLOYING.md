
## Deploying to a new chain

### 0.1. Prepare

Make sure required addresses / multisigs are setup for 
1. funds recipient
2. contract factory upgrade owner address

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
  # pre-approved transfer helper for ZORA v3, likely should be 0 on new networks
  "ZORA_ERC721_TRANSFER_HELPER": "0x909e9efE4D87d1a6018C2065aE642b6D0447bc91"
}
```

### 2. Deploy forge script

    forge script script/Deploy.s.sol --broadcast --verify --rpc-url $ETH_RPC --sender $SENDER_WALLET
  
For example, to deploy on optimism goerli, this is the forge command:

    forge script script/Deploy.s.sol $(chains optimism-goerli) --verify --broadcast --interactives 1 --sender $SENDER_WALLET

*Important*: Sender is required to have the simulation succeed. Without it, the drops contract is not deployed.

Use your own RPC configuration variables

### 3. Copy new chain configuration for deployment

Copies new addresses over to `addresses` folder:

    node js-scripts/copy-latest-deployment-addresses.mjs deploy


## Upgrading an implementation on a new chain

### 1. Upgrade forge script

    forge script script/UpgradeERC721DropFactory.s.sol --broadcast --verify $(chains optimism-goerli --deploy) --sender $SENDER_WALLET

*Important*: Sender is required to have the simulation succeed. Without it, the drops contract is not deployed.

Use your own RPC configuration variables

### 2. Copy new chain configuration for deployment

Copies new addresses over to `addresses` folder:

    node js-scripts/copy-latest-deployment-addresses.mjs
