import ejs from "ejs";
import { makeTree } from "./merkle.mjs";
import { zeroPad, hexlify } from "@ethersproject/bytes";
import { parseEther } from "@ethersproject/units";
import { join } from "path";
import { writeFile } from "fs/promises";
import esMain from "es-main";

import { dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));


async function renderFromPath(path, data) {
  return new Promise((resolve, reject) => {
    ejs.renderFile(path, data, (err, result) => {
      if (err) {
        return reject(err);
      }
      return resolve(result);
    });
  });
}

function makeAddress(partial) {
  return hexlify(zeroPad(partial, 20));
}

const testDataInput = [
  {
    name: "test-3-addresses",
    entries: [
      { minter: makeAddress(0x10), maxCount: 1, price: parseEther("0.01") },
      { minter: makeAddress(0x11), maxCount: 2, price: parseEther("0.01") },
      { minter: makeAddress(0x12), maxCount: 3, price: parseEther("0.01") },
    ],
  },
  {
    name: "test-2-prices",
    entries: [
      {minter: makeAddress(0x10), maxCount: 2, price: parseEther("0.1")},
      {minter: makeAddress(0x10), maxCount: 2, price: parseEther("0.2")},
    ]
  },
  {
    name: "test-max-count",
    entries: [
      {minter: makeAddress(0x10), maxCount: 2, price: parseEther("0.1")},
      {minter: makeAddress(0x10), maxCount: 2, price: parseEther("0.2")},
    ]
  }
];

async function renderExample() {
  const testData = testDataInput.map((testDataItem) => {
    console.log(testDataItem);
    const treeResult = makeTree(testDataItem.entries);
    testDataItem.entries = treeResult.entries;
    testDataItem.root = treeResult.root;
    return testDataItem;
  });
  const testPath = join(
    __dirname,
    "../",
    "test/merkle",
    "MerkleData.sol.ejs"
  );
  const resultPath = testPath.substring(0, testPath.length - 4);
  const render = await renderFromPath(testPath, { testData });
  await writeFile(resultPath, render);
  console.log(render);
}

if (esMain(import.meta)) {
  // Run main
  await renderExample();
}
