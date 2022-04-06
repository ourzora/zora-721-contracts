# Zora NFT Contracts

### What are these contracts?
1. `ZoraNFTBase`
   Each edition is a unique contract.
   This allows for easy royalty collection, clear ownership of the collection, and your own contract 🎉
2. `SingleEditionMintableCreator`
   Gas-optimized factory contract allowing you to easily + for a low gas transaction create your own edition mintable contract.
3. `SharedNFTLogic`
   Contract that includes dynamic metadata generation for your editions removing the need for a centralized server.
   imageUrl and animationUrl can be base64-encoded data-uris for these contracts totally removing the need for IPFS

### How do I create a new contract?

### Directly on the blockchain:
1. Find/Deploy the `SingleEditionMintableCreator` contract
2. Call `createEdition` on the `SingleEditionMintableCreator`

### Through a GUI:

Rinkeby: https://edition-drop.vercel.app/?network=4

Mainnet: https://edition-drop.vercel.app/?network=1

Polygon: https://edition-drop.vercel.app/?network=137

Mumbai: https://edition-drop.vercel.app/?network=80001


### Where is the factory contract deployed:


**Mainnet ETH**: [0x91A8713155758d410DFAc33a63E193AE3E89F909](https://etherscan.io/address/0x91A8713155758d410DFAc33a63E193AE3E89F909)

note: ~ Deployed with 1.0.1 version of code. Missing public getter for description.


**Rinkeby**: [0x85FaDB8Debc0CED38d0647329fC09143d01Af660](https://rinkeby.etherscan.io/address/0x85FaDB8Debc0CED38d0647329fC09143d01Af660)

note: ~ Deployed with 1.0.1 version of code. Missing public getter for description.


**Polygon**: [0x4500590AfC7f12575d613457aF01F06b1eEE57a3](https://polygonscan.com/address/0x4500590AfC7f12575d613457aF01F06b1eEE57a3)

note: Deployed with 1.0.2 version of code with public getter for description.


**Mumbai**: [0x773E5B82179E6CE1CdF8c5C0d736e797b3ceDDDC](https://mumbai.polygonscan.com/address/0x773E5B82179E6CE1CdF8c5C0d736e797b3ceDDDC)

note: Deployed with 1.0.2 version of code with public getter for description.


### How do I create a new edition?

call `createEdition` with the given arguments to create a new editions contract:

- Name: Token Name Symbol (shows in etherscan)
- Symbol: Symbol of the Token (shows in etherscan)
- Description: Description of the Token (shows in the NFT description)
- Animation URL: IPFS/Arweave URL of the animation (video, webpage, audio, etc)
- Animation Hash: sha-256 hash of the animation, 0x0 if no animation url provided
- Image URL: IPFS/Arweave URL of the image (image/, gifs are good for previewing images)
- Image Hash: sha-256 hash of the image, 0x0 if no image url provided
- Edition Size: Number of this edition, if set to 0 edition is not capped/limited
- BPS Royalty: 500 = 5%, 1000 = 10%, so on and so forth, set to 0 for no on-chain royalty (not supported by all marketplaces)

### How do I sell/distribute editions?

Now that you have a edition, there are multiple options for lazy-minting and sales:

1. To sell editions for ETH you can call `setSalePrice`
2. To allow certain accounts to mint `setApprovedMinter(address, approved)`.
3. To mint yourself to a list of addresses you can call `mintEditions(addresses[])` to mint an edition to each address in the list.

### Benefits of these contracts:

* Full ownership of your own created minting contract
* Each serial gets its own minting contract
* Gas-optimized over creating individual NFTs
* Fully compatible with ERC721 marketplaces / auction houses / tools
* Supports tracking unique parts (edition 1 vs 24 may have different pricing implications) of editions
* Supports free public minting (by approving the 0x0 (zeroaddress) to mint)
* Supports smart-contract based minting (by approving the custom minting smart contract) using an interface.
* All metadata is stored/generated on-chain -- only image/video assets are stored off-chain
* Permissionless and open-source
* Simple integrated ethereum-based sales, can be easily extended with custom interface code

### Potential use cases for these contracts:

* Giveaways for events showing if you’ve attended 
* Serial editioned artworks that can be sold in the Zora auction house / work in any ERC721 market
* Fundraisers for fixed-eth amounts
* Can be used to issue tokens in response for contributing to a fundraiser
* Tickets/access tokens allowing holders to access a discord or mint

### Deploying:
(Replace network with desired network)

`hardhat deploy --network rinkeby`

### Verifying:

`hardhat sourcify --network rinkeby && hardhat etherscan-verify --network rinkeby`

### Bug Bounty
5 ETH for any critical bugs that could result in loss of funds.
Rewards will be given for smaller bugs or ideas.
