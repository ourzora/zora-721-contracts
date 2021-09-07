module.exports = async ({ getNamedAccounts, deployments }: any) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const mintableAddress = (await deployments.get("DynamicSerialMintable")).address;

  await deploy("DynamicSerialCreator", {
    from: deployer,
    args: [mintableAddress],
    log: true,
  });
};
module.exports.tags = ["DynamicSerialCreator"];
module.exports.dependencies = ["DynamicSerialMintable"];
