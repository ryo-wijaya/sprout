const User = artifacts.require("User");
const JobListing = artifacts.require("JobListing");
const SproutToken = artifacts.require("SproutToken");
const Escrow = artifacts.require("Escrow");
const DisputeResolutionDAO = artifacts.require("DisputeResolutionDAO");
const JobReview = artifacts.require("JobReview");

const x = 10; // The amount of tokens a client must stake in case of a potential dispute
const y = 1; // The amount of tokens to reward each winner voter in the event of a dispute
const maxNumberOfWinners = x * y; // The maximum number of winners that can be rewarded in the event of a dispute

module.exports = async (deployer, network, accounts) => {
  await deployer.deploy(User);
  await deployer.deploy(SproutToken);
  /*
   * We deploy the escrow contract with 10 tokens (x) as the amount for a client to stake in case of a potential dispute,
   * and 1 token (y) as the amount to reward each winner voter in the event of this dispute
   * These are arbitrary values picked for simplicity to make demonstration of the application's functionality easier.
   *
   * x is also passed into the jobListing contract
   */
  await deployer.deploy(Escrow, User.address, SproutToken.address, x, y);
  await deployer.deploy(JobListing, User.address, Escrow.address, x);
  await deployer.deploy(JobReview, User.address, JobListing.address);
  /*
   * We deploy the disputeResolutionDAO contract with a maxmium of 10 winner voters that can be rewarded (maxNumberOfWinners)
   * This value maxNumberOfWinners MUST have this condition satisified as a business rule: maxNumberOfVoters = x * y
   */
  await deployer.deploy(
    DisputeResolutionDAO,
    User.address,
    JobListing.address,
    Escrow.address,
    maxNumberOfWinners
  );
};
