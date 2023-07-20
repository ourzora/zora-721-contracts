
## Deploying to a new chain

### 0.1. Prepare

Make sure required addresses / multisigs are setup for 
1. funds recipient
2. contract factory upgrade owner address

Ensure that the default operator-filterer-registry deployment is on the current chain.

If not, use the mainnet default filter address to re-deploy on the chain using ImmutableCreate2Factory (required also for seaport).

To deploy ImmutableCreate2Factory, follow the steps in the seaport deploy scripts: https://github.com/ProjectOpenSea/seaport/blob/main/docs/Deployment.md#setting-up-factory-on-a-new-chain

example call:
cast send 0x0000000000FFe8B47B3e2130213B802212439497 'function safeCreate2(bytes32,bytes)' [...] --rpc-url $(rpc base) --interactive

copied from the mainnet deploy txn: https://etherscan.io/tx/0x4c2038f55147cae309c2e597a5323b42b63fd556a15d2f1b5a799eee1b3ddf04

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

    forge script script/Deploy.s.sol --rpc-url $RPC --verify --etherscan-api-key $API_KEY --broadcast --interactives 1 --sender $SENDER_WALLET

*Important*: Sender is required to have the simulation succeed. Without it, the drops contract is not deployed.

Use your own RPC configuration variables

### 3. Copy new chain configuration for deployment

Copies new addresses over to `addresses` folder:

    node js-scripts/copy-latest-deployment-addresses.mjs deploy
