# Zora NFT Drop Media Contracts

### Features these contracts support:


### What are these contracts?
1. `ERC721Drop`
   Each drop is a unique contract.
   This allows for easy royalty collection, clear ownership of the collection, and your own contract 🎉
2. `ZoraNFTCreatorV1`
   Gas-optimized factory contract allowing you to easily + for a low gas transaction create your own drop contract.
3. `DropMetadataRenderer`
   A flexible metadata renderer architecture that allows for centralised and IFPS metadata group roots to be rendered.
4. `EditionsMetadataRenderer`
   A partially on-chain renderer for editions that encodes name and description on-chain with media metadata off-chain.
5. `UpgradeGate`
   A registry allowing for upgrades to be allowed for child contracts by `zora.eth`.
   
### Flexibility and safety

All drops contracts are wholly owned by their creator and allow for extensibility with rendering and minting.
The root drops contract can be upgraded to allow for product upgrades with new contracts and Zora gates allowed upgrade paths
for deployed contracts to be upgraded by the users of the platform to opt into new features.

The metadata renderer abstraction allows these drops contracts to power a variety of on-chain powered projects and also.
  
### Local development

1. Install [Foundry](https://github.com/foundry-rs/foundry)
1. `yarn install`
1. `git submodule init && git submodule update`
1. `yarn build

### Bug Bounty
5 ETH for any critical bugs that could result in loss of funds.
Rewards will be given for smaller bugs or ideas.
