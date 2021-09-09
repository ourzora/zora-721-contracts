module.exports = async ({ getNamedAccounts, deployments }: any) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const sharedNFTLogicAddress = (await deployments.get("SharedNFTLogic")).address;

  const name = "Zora Shared Editions Mintable";
  const symbol = "ZORAEDITIONS"

  await deploy("SharedEditionsMintable", {
    from: deployer,
    args: [
      name,
      symbol,
      // anyone can mint
      [],
      sharedNFTLogicAddress 
    ],
    log: true,
  });
};
module.exports.tags = ["SharedEditionsMintable"];
module.exports.dependencies = ["SharedNFTLogic"]
