# Allowlist Best Practices

These contracts allow adding in a merkle root to serve as an allowlist for the `presale` function.

ZORA has built an API (https://allowlist.zora.co/docs) for retrieving and storing those allowlists when they are set.

Additionally, we have worked with mint.fun to build https://lanyard.org/ to allow more minting platforms to use a unified allowlist lookup.

Currently, ZORA cross-posts allowlists to both our allowlist engine and lanyard.

To retrieve a ZORA allowlist, you can use either lanyard.org or ZORA's api.

### Retrieving allowlist eligibility

**With ZORA:**

https://allowlist.zora.co/allowed?user=0x4492eCACB5da5D933af0e55eEDad4383BF8D2dB5&root=0x7c407ca53d74f67aaec4f77d464edc9b0734dfd7325288fa9062adfc6e6a77c6

returns a JSON object with the user's proof to send to the contract to mint (the proof is a list of bytes32 hex strings)

We properly decode and organize all the internal values we use for our contracts with this endpoint.

To retrieve all values for a root:

https://allowlist.zora.co/allowlist/{root}

Retrieves all users eligible for the given root.

This allows us with a known contract to fetch the root from salesConfig then look up all entries in the allowlist. To query the root, you can use `salesConfig` on the ZORA 721 contracts to get the current presale root.

    salesConfig method --> response
      publicSalePrice   uint104 :  77700000000000000
      [...]
      presaleMerkleRoot   bytes32 :  0xb8f52a5b5ade4c2c7ce28985a380c660faa8c4b4495aa01b659992f1514e927f

    GET https://allowlist.zora.co/allowlist/0xb8f52a5b5ade4c2c7ce28985a380c660faa8c4b4495aa01b659992f1514e927f 

      "entries": [
        {
          "user": "0x66a3b3ae9789581bb77d8650eabbc8df43e9dbbc",
          "price": "33300000000000000",
          "maxCanMint": 10
        },
        {
          "user": "0x0d7b35d672a35cf21f707853810c467fabec6b6b",
          "price": "33300000000000000",
          "maxCanMint": 10
        },
        [...]
      ]

**With Lanyard:**

GET https://lanyard.org/api/v1/proof?root={root}&unhashedLeaf={unhashedLeaf}

in ZORA's case, the unhashedLeaf is: 

```
import { utils } from 'ethers';

function getZoraUnhashedLeaf(user, mintsAllowed, mintPrice) {
  return utils.defaultAbiCoder.encode(['address', 'uint256', 'uint256'], [user, mintsAllowed, mintPrice]);
}

```

### Creating an Allowlist

To create the allowlist, you need at least 2 entries. In our front-end code we add a second entry for when one entry is added to the allowlist that duplicates the previous entry.

In our UI, we resolve the ENS names entered by the user to addresses to get this final format:

```
user,mints_allowed,mint_price
0x17cd072cBd45031EFc21Da538c783E0ed3b25DCc,10,1000000000000000000
0xd1d1D4e36117aB794ec5d4c78cBD3a8904E691D0,10,1000000000000000000
```

From this we call:

```
const allowlist = await fetch('https://allowlist.zora.co/allowlist', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ entries }),
})
const json = await allowlist.json()
return `0x${json.root}`
```

This then returns the root that we can use to set on the contract.


### Appendix

To update lanyard.org: (optional)

```
  fetch('https://lanyard.org/api/v1/tree, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      unhashedLeaves: entries.map((entry) =>
        utils.defaultAbiCoder.encode(
          ['address', 'uint256', 'uint256'],
          [entry.user, entry.mints_allowed, entry.price]
        )
      ),
      leafTypeDescriptor: ['address', 'uint256', 'uint256'],
      packedEncoding: false,
    }),
  })
```


