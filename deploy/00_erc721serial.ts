module.exports = async ({ getNamedAccounts, deployments }: any) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("ERC721SerialFactory", {
    from: deployer,
    args: ["Test Serial", "TESTSERIAL"],
    log: true,
  });
};
module.exports.tags = ["ERC721SerialFactory"];
