module.exports = async ({ getNamedAccounts, deployments }: any) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const sharedNFTLogicAddress = (await deployments.get("SharedNFTLogic"))
    .address;

  // Change these when deploying
  const name = "Zora Shared Editions Mintable";
  const symbol = "ZORAEDITIONS";

  await deploy("SharedEditionsMintable", {
    from: deployer,
    args: [
      name,
      symbol,
      sharedNFTLogicAddress,
      // anyone can mint
      deployer,
    ],
    log: true,
  });
};
module.exports.tags = ["SharedEditionsMintable"];
module.exports.dependencies = ["SharedNFTLogic"];
