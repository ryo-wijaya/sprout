const SimpleTestStore = artifacts.require("SimpleTestStore");
const User = artifacts.require("User");
const JobListing = artifacts.require("JobListing");

module.exports = async (deployer, network, accounts) => {
  await deployer.deploy(SimpleTestStore);
  await deployer.deploy(User);
  await deployer.deploy(JobListing, User.address);
};
