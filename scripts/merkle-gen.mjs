import { makeTree } from "./merkle.mjs";
import { parseEther } from "@ethersproject/units";
import { join } from "path";
import { writeFile } from "fs/promises";
import esMain from "es-main";

import { dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const resultItem = {
  name: "main",
  entries: [
    {
      minter: "0x9444390c01Dd5b7249E53FAc31290F7dFF53450D",
      maxCount: 5,
      price: parseEther("0.01").toString(),
    },
    {
      minter: "0x2F7218644600c2860709623de3E8A1f82d27ed3b",
      maxCount: 5,
      price: parseEther("0.01").toString(),
    },
    {
      minter: "0x07966725a7928083bA85e75276518561D0c28B19",
      maxCount: 5,
      price: parseEther("0.01").toString(),
    },
  ],
};

async function generateTree() {
  const treeResult = makeTree(resultItem.entries);
  resultItem.entries = treeResult.entries;
  resultItem.root = treeResult.root;

  const outputPath = join(__dirname, "gen.json");
  await writeFile(outputPath, JSON.stringify(resultItem));
}

if (esMain(import.meta)) {
  await generateTree();
}
