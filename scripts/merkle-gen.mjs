import { makeTree } from "./merkle.mjs";
import { parseEther } from "@ethersproject/units";
import { join } from "path";
import { writeFile } from "fs/promises";
import esMain from "es-main";

import { dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const MINT_PRICE = parseEther("0.08").toString();

const resultItem = {
  name: "main",
  entries: [
    {
      minter: "0xd52c41363b0defd25cbdc568c93180340f8611a2",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0x9a7a9c4c20808dc37efd8ed45af1f244e70fcbf0",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0x3bcde6b554f047c3214eec6a38a357a51751e165",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0xb7b131bf2a56eb626a841230934945de9866693a",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0x33fc47ed46abbb933e9a3852abc859d92d04d5db",
      maxCount: 15,
      price: MINT_PRICE,
    },
    {
      minter: "0x44b51387773ce3581156d9accb27849a204f31dc",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0xcba9054f1c063263f67fdf15bc868b1d7a3f31c1",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0x40d14d5e75da940df10e73ab9b96db90772d0990",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0xf6910d47fbb1f5518d60c721d4189936ecd5a1b6",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0x9267eedbc2982d88c2f57780bfcdb25689dff781",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0x60d830aa155e23765fac73fd7e9d0d2e5bedcf1b",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0xf397c12c59f50d9c6dae473ef94aaef299d73d07",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0x3d1af3a5f9539157fd24a354fd19170ad45693df",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0xeaffdd42724c06c63f3fab152a5ef1c0bc54acdf",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0x53322e9f6bb3cb3762393901fc5dae637b500560",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0xe420445a738d9c4344cf5b71f599d3ee391b228d",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0x9bdd171cc0ca866cadd025d7bea14d021269242d",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0xC44622EFe9F7b4c880e563548148810b9CE0cdb4",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0x4bb88adc1e40ec1bb42721b4eab574b1229b4a76",
      maxCount: 5,
      price: MINT_PRICE,
    },
    {
      minter: "0xff21d45538e2da4427cf219030c8979cd715570e",
      maxCount: 5,
      price: MINT_PRICE,
    },
  ],
};

async function generateTree() {
  const treeResult = makeTree(resultItem.entries);
  resultItem.entries = treeResult.entries;
  resultItem.root = treeResult.root;

  const outputPath = join(__dirname, "gen.json");
  await writeFile(outputPath, JSON.stringify(resultItem, null, 2));
}

if (esMain(import.meta)) {
  await generateTree();
}
