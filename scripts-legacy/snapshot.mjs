import "isomorphic-fetch";
import { writeFile } from "fs/promises";
import esMain from "es-main";

async function fetchIndexer(contract, offset) {
  const query = `{"query":"query Token {\\n  Token(where:{\\n    tokenContract:{address:{_eq:\\"${contract}\\"}}\\n  }\\n  limit: 100\\n\\toffset: ${offset}\\n) {\\n    tokenId\\n    owner\\n    metadata {\\n      json\\n    }\\n  }\\n}","variables":null,"operationName":"Token"}`;
  console.log(query);
  const result = await fetch(
    "https://indexer-prod-mainnet.zora.co/v1/graphql",
    {
      headers: {
        Accept: "*/*",
        "Content-Type": "application/json",
      },
      body: query,
      method: "POST",
    }
  );
  const jsonResult = await result.json();
  const tokenData = jsonResult.data.Token;
  return tokenData;
}

async function fetchLoop(contract) {
  let resultPart = [];
  let results = [];
  let offset = 0;
  do {
    resultPart = await fetchIndexer(contract, offset);
    results = results.concat(resultPart);
    console.log({ offset });
    offset += 100;
  } while (resultPart.length > 0);
  return results;
}

async function fetchAllAddresses(contract) {
  const results = await fetchLoop(contract);
  console.log(`[results] has ${results.length} nfts`);
  writeFile("./results.json", JSON.stringify(results, null, 2));
}

if (esMain(import.meta)) {
  const contract = process.argv[2];
  console.log(`[result] fetching for contract: ${contract}`);
  await fetchAllAddresses(contract);
  console.log(`[result] done`);
}
