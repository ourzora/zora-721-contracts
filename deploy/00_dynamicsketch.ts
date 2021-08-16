module.exports = async ({ getNamedAccounts, deployments }: any) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("DyanmicSeriesMint", {
    from: deployer,
    args: ["Dynamic Sketch", "DYNSKCH"],
    log: true,
  });
};
module.exports.tags = ["DynamicSketch"];
