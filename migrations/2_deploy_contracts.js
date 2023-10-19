const Dice = artifacts.require("SimpleTestStore");

module.exports = async (deployer, network, accounts) => {
  await deployer.deploy(Dice);
};
