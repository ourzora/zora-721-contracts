import 'isomorphic-fetch'

const indexer_result = await fetch("https://indexer-prod-mainnet.zora.co/v1/graphql", {
  headers: {
    Accept: "*/*",
    "Content-Type": "application/json",
  },
  body: '{"query":"query Token {\\n  Token(where:{\\n    tokenContract:{address:{_eq:\\"0xC9677Cd8e9652F1b1aaDd3429769b0Ef8D7A0425\\"}}\\n  }\\n  limit: 100\\n\\toffset: 0\\n) {\\n    tokenId\\n    owner\\n    metadata {\\n      json\\n    }\\n  }\\n}","variables":null,"operationName":"Token"}',
  method: "POST",
});

console.log(indexer_result)