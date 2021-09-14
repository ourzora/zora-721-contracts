# Bounded Unique Media Editions Contract

These contracts allow for creating on-chain nft media editions.

They include Zora cryptomedia features such as the ability to update canonical urls and include content hashes.

They can be minted by the owner or an arbitary set of addresses – Sales contracts are coming soon.

There are two flavors of contracts
1. SingleEditionMintable (+ SingleEditionMintableCreator factory contract)
   Each edition is a unique contract.
   This allows for easy royalty collection, clear ownership of the collection, and your own contract 🎉

2. SharedEditionMintable
   A traditional shared contract where different editions all resolve to the same contract.
   Useful for a brand or organization that wants to keep their editions all in one collection.

3. SeriesSale
   Prototype contract for selling editions for a fixed amount of ETH.
   Ties into the contract by being an approved minter.

### Deploying:
(Replace network with desired network)
`hardhat deploy --network rinkeby --tags SingleEditionMintable`

### Verifying:
`hardhat sourcify --network rinkeby && hardhat etherscan-verify --network rinkeby`

### Minting:

