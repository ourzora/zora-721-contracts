module.exports = async ({ getNamedAccounts, deployments }: any) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const sharedNFTLogicAddress = (await deployments.get("SharedNFTLogic")).address;

  await deploy("SingleEditionMintable", {
    from: deployer,
    args: [
      sharedNFTLogicAddress
    ],
    log: true,
  });
};
module.exports.tags = ["SingleEditionMintable"];
module.exports.dependencies = ["SharedNFTLogic"]
