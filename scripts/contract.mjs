import util from "util";
import { exec } from "child_process";
import dotenv from "dotenv";
import {Interface} from '@ethersproject/abi';

const execPromise = util.promisify(exec);

dotenv.config();

function timeout(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export async function deploy(contract, args = undefined) {
  const [contractPath, contractName] = contract.split(":");
  const constructorArgs = args ? ["--constructor-args", args.join(' ')] : [];
  const { stdout, stderr } = await execPromise(
    [
      "forge",
      "create",
      contract,
      "--private-key",
      process.env.PRIVATE_KEY,
      "--rpc-url",
      process.env.ETH_RPC_URL,
      "--chain",
      process.env.CHAIN,
      ...constructorArgs,
      "--json",
    ].join(" ")
  );
  if (stderr) {
    throw new Error(stderr);
  }
  return {
    deploy: JSON.parse(stdout),
    contractName,
    contractPath,
    args
  };
}

export async function verify(address, contract, args = undefined)  {
  const [contractPath, contractName] = contract.split(":");
  const inspectResult = await execPromise(['forge', 'inspect', contractName, 'abi'].join(' '));
  const deployArgs = new Interface(inspectResult.stdout).encodeDeploy(args);
  const constructorArgs = args ? ["--constructor-args", deployArgs] : [];
  const { stdout, stderr } = await execPromise(
    [
      "forge",
      "verify-contract",
      address,
      contract,
      process.env.ETHERSCAN_API_KEY,
      "--chain",
      process.env.CHAIN,
      ...constructorArgs,
      "--compiler-version",
      process.env.COMPILER_VERSION
    ].join(" ") 
  );
  if (stderr) {
    throw new Error(stderr);
  }
  return {
    verify: stdout,
    contractName,
    contractPath,
  };
}

async function retryVerify(maxTries, ...args) {
  if (maxTries == 0) {
    console.log('failed to verify');
  }
  try {
    return await verify(...args);
  } catch (e) {
    // 15 second delay
    await timeout(15000);
    console.error(e);
    console.log('retrying');
    return retryVerify(maxTries - 1, ...args);
  }
}

export async function deployAndVerify(contract, args) {
  const deployed = await deploy(contract, args);
  console.log(`[deployed] ${contract}`);
  console.log('wait 10 sec for etherscan to catch up');
  await timeout(10000);
  const verified = await retryVerify(3, deployed.deploy.deployedTo, contract, deployed.args);
  console.log(`[verified] ${contract}`)
  console.log(verified)
  return {
    deployed, verify: verified
  }
}