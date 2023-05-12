import { readdirSync, readFileSync, writeFileSync } from 'fs';

// Reads all the chain configs in ./chainConfigs folder, and bundles them into a typescript 
// definition that looks like:
// export const chainConfigs = {
//  [chainId]: {
//    ...chainConfig
//  }
//}
function makeConfig() {
  // read all files in the chainConfigs folder
  const files = readdirSync('chainConfigs');

  // combine them into a single mapping
  const chainConfigsInner = files
    .map((fileName) => {
      const chainId = fileName.split('.')[0];

      const fileContents = JSON.parse(readFileSync(`chainConfigs/${fileName}`));

      return `[${chainId}]: ${JSON.stringify(fileContents, null, 2)}`;
    })
    .join(', ');

  return `export const chainConfigs = {
    ${chainConfigsInner}
  };`;
}

async function bundleChainConfigs() {
  const configString = makeConfig();

  writeFileSync('./package/chainConfigs.ts', configString);
}

await bundleChainConfigs();
