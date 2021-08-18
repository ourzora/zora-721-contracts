module.exports = async ({ getNamedAccounts, deployments }: any) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("DynamicSerialMintable", {
    from: deployer,
    args: [
      "Dynamic Mint",
      "DYNSKCH",
      "0x0000000000000000000000000000000000000000",
    ],
    log: true,
  });
};
module.exports.tags = ["DynamicSerialMintable"];
