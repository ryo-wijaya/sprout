const User = artifacts.require("User");
const JobListing = artifacts.require("JobListing");
const NativeToken = artifacts.require("NativeToken");
// const Escrow = artifacts.require("Escrow");
// const DisputeResolutionDAO = artifacts.require("DisputeResolutionDAO");
// const JobReview = artifacts.require("JobReview");

module.exports = async (deployer, network, accounts) => {
  await deployer.deploy(User);
  await deployer.deploy(NativeToken);
  // await deployer.deploy(Escrow);
  await deployer.deploy(JobListing, User.address, NativeToken.address);
  // await deployer.deploy(JobReview, User.address, JobListing.address);
  // await deployer.deploy(DisputeResolutionDAO, User.address, Escrow.address, JobListing.address);
};
