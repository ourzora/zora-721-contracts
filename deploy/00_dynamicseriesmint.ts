module.exports = async ({ getNamedAccounts, deployments }: any) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("DynamicSerialMintable", {
    from: deployer,
    args: ["Dynamic Mint", "DYNSKCH"],
    log: true,
  });
};
module.exports.tags = ["DynamicSerialMintable"];
