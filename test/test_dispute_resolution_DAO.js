const truffleAssert = require("truffle-assertions");
var assert = require("assert");

var User = artifacts.require("User");
var JobListing = artifacts.require("JobListing");
var NativeToken = artifacts.require("NativeToken");
var Escrow = artifacts.require("Escrow");
var DisputeResolutionDAO = artifacts.require("DisputeResolutionDAO");

// Helper functions
function generateUnixTime(daysFromNow) {
  const now = new Date();
  now.setDate(now.getDate() + daysFromNow);
  return Math.floor(now.getTime() / 1000);
}

contract("DisputeResolutionDAO", (accounts) => {
  let userInstance;
  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];

  // 7 seperate users for reviewing
  const user3 = accounts[3];
  const user4 = accounts[4];
  const user5 = accounts[5];
  const user6 = accounts[6];
  const user7 = accounts[7];
  const user8 = accounts[8];
  const user9 = accounts[9];

  before(async () => {
    userInstance = await User.deployed();
    jobListingInstance = await JobListing.deployed();
    nativeTokenInstance = await NativeToken.deployed();
    escrowInstance = await Escrow.deployed();
    disputeResolutionDAOInstance = await DisputeResolutionDAO.deployed();

    // 1 ETH gets each user 100 native tokens
    nativeTokenInstance.getCredit(user1, web3.utils.toWei("1", "ether"));
    nativeTokenInstance.getCredit(user2, web3.utils.toWei("1", "ether"));

    nativeTokenInstance.getCredit(user3, web3.utils.toWei("1", "ether"));
    nativeTokenInstance.getCredit(user4, web3.utils.toWei("1", "ether"));
    nativeTokenInstance.getCredit(user5, web3.utils.toWei("1", "ether"));
    nativeTokenInstance.getCredit(user6, web3.utils.toWei("1", "ether"));
    nativeTokenInstance.getCredit(user7, web3.utils.toWei("1", "ether"));
    nativeTokenInstance.getCredit(user8, web3.utils.toWei("1", "ether"));
    nativeTokenInstance.getCredit(user9, web3.utils.toWei("1", "ether"));
  });

  it("Test SUCCESS: regiser 4 user profiles for users 1 and 2", async () => {
    // 2 user profiles from user 1, one client and one reviewer
    let result1 = await userInstance.register(1, "username1", "client1", "email1@example.com", "bio1", {
      from: user1,
      value: web3.utils.toWei("0.01", "ether"),
    });
    let result2 = await userInstance.register(2, "username2", "reviewer1", "email2@example.com", "bio2", {
      from: user1,
      value: web3.utils.toWei("0.01", "ether"),
    });
    // 2 user profiles from user 2, one freelancer and one reviewer
    let result3 = await userInstance.register(2, "username3", "reviewer2", "email3@example.com", "bio3", {
      from: user2,
      value: web3.utils.toWei("0.01", "ether"),
    });
    let result4 = await userInstance.register(0, "username4", "freelancer1", "email4@example.com", "bio4", {
      from: user2,
      value: web3.utils.toWei("0.01", "ether"),
    });
    truffleAssert.eventEmitted(result1, "NewUserRegistered", (ev) => {
      return ev.userId.toNumber() === 1 && ev.userType.toNumber() === 1;
    });
    truffleAssert.eventEmitted(result2, "NewUserRegistered", (ev) => {
      return ev.userId.toNumber() === 2 && ev.userType.toNumber() === 2;
    });
    truffleAssert.eventEmitted(result3, "NewUserRegistered", (ev) => {
      return ev.userId.toNumber() === 3 && ev.userType.toNumber() === 2;
    });
    truffleAssert.eventEmitted(result4, "NewUserRegistered", (ev) => {
      return ev.userId.toNumber() === 4 && ev.userType.toNumber() === 0;
    });
  });

  it("Test SUCCESS: register 7 user profiles for users 3-9", async () => {
    // Registering 7 user profiles as reviewers
    const userAccounts = [user3, user4, user5, user6, user7, user8, user9];
    for (let i = 0; i < userAccounts.length; i++) {
      let result = await userInstance.register(
        2,
        `username${i + 5}`,
        `reviewer${i + 3}`,
        `email${i + 5}@example.com`,
        `bio${i + 5}`,
        {
          from: userAccounts[i],
          value: web3.utils.toWei("0.01", "ether"),
        }
      );

      truffleAssert.eventEmitted(result, "NewUserRegistered", (ev) => {
        return ev.userId.toNumber() === i + 5 && ev.userType.toNumber() === 2;
      });
    }
  });

  it("Test SUCCESS: Client creates a job", async () => {
    let jobIdExpected = 1;
    let title = "Sample Job Title";
    let description = "This is a sample job description.";
    let endTime = generateUnixTime(5); // ends 5 days in the future
    let reward = 15;

    // user1 uses client ID 1 to create a job
    let result = await jobListingInstance.createJob(1, title, description, endTime, reward, {
      from: user1,
    });

    truffleAssert.eventEmitted(result, "JobCreated", (ev) => {
      return ev.jobId.toNumber() === jobIdExpected && ev.title === title;
    });

    // Check job is created correctly
    let jobDetails = await jobListingInstance.getJobDetails(jobIdExpected);
    assert.equal(jobDetails[0].toNumber(), 1, "Job clientId should be 1");
    assert.equal(jobDetails[1].toNumber(), 0, "Job acceptedFreelancerId should be 0 (null)");
    assert.equal(jobDetails[2], title, "Job title mismatch");
    assert.equal(jobDetails[3], description, "Job description mismatch");
    assert.equal(jobDetails[4], endTime, "End time mismatch");
    assert.equal(jobDetails[5].toNumber(), reward, "Job reward mismatch");
    assert.equal(jobDetails[6].toNumber(), 1, "Job status should be 1 (OPEN)");

    truffleAssert.eventEmitted(result, "JobCreated", (ev) => {
      return ev.jobId.toNumber() === jobIdExpected && ev.title === title;
    });
  });

  it("Test SUCCESS: Freelancer applies for a job", async () => {
    // User2 uses freelancer ID 4 to apply for user1's client ID 1's job with Job ID 1
    let result = await jobListingInstance.applyForJob(4, 1, "This is my proposal", {
      from: user2,
    });
    truffleAssert.eventEmitted(result, "ApplicationCreated", (ev) => {
      return ev.jobId.toNumber() === 1 && ev.applicationId.toNumber() === 1;
    });

    // Check application is made correctly
    let applicationDetails = await jobListingInstance.getApplicationDetails(1, 1);
    assert.equal(applicationDetails[0], 4, "Freelancer ID mismatch");
    assert.equal(applicationDetails[1], "This is my proposal", "Proposal mismatch");
    assert.equal(applicationDetails[2], false, "application should not be accepted yet");
  });

  it("Test SUCCESS: Client accepts an application", async () => {
    // User1 with client ID 1 accepts freelancer ID 4's application for job ID 1, application ID 1
    let result = await jobListingInstance.acceptApplication(1, 1, 1, {
      from: user1,
    });
    truffleAssert.eventEmitted(result, "ApplicationAccepted", (ev) => {
      return (
        ev.jobId.toNumber() === 1 && ev.applicationId.toNumber() === 1 && ev.freelancerId.toNumber() === 4
      );
    });

    // Getting details of escrow payment with ID 1, tokens should be 15 (reward) + 10 (staked for DAO) = 25
    assert.equal(await escrowInstance.getBalance(1), 25, "Invalid Escrow Payment Balance");
    // Client should be 25 tokens poorer
    assert.equal(await nativeTokenInstance.checkCredit(user1), 75, "Invalid Client Balance");
  });

  it("Test SUCCESS: Freelancer completes a job", async () => {
    // User2 with freelancer ID 4 completes job ID 1
    let result = await jobListingInstance.freelancerCompletesJob(4, 1, {
      from: user2,
    });
    truffleAssert.eventEmitted(result, "JobMarkedComplete", (ev) => {
      return ev.jobId.toNumber() === 1 && ev.freelancerId.toNumber() === 4;
    });
  });

  it("Test Failure: Client starts a dispute", async () => {
    // User1 with client ID 1 is not satisfied with job ID 1
    // Invalid job ID
    await truffleAssert.reverts(
      disputeResolutionDAOInstance.startDispute(1, 2, { from: user1 }),
      "Invalid Job ID"
    );

    // You are not who you say you are
    await truffleAssert.reverts(
      disputeResolutionDAOInstance.startDispute(1, 1, { from: user2 }),
      "This userId does not correspond to yourself"
    );

    // A user that is not the client of this particular job tries to start a dispute
    await truffleAssert.reverts(
      disputeResolutionDAOInstance.startDispute(3, 1, { from: user2 }),
      "Only the client associated with the job can initiate a dispute"
    );
  });

  it("Test Success: Client starts a dispute", async () => {
    // User1 with client ID 1 is not satisfied with job ID 1
    let result = await disputeResolutionDAOInstance.startDispute(1, 1, {
      from: user1,
    });
    truffleAssert.eventEmitted(result, "DisputeStarted", (ev) => {
      return ev.jobId.toNumber() === 1 && ev.disputeId.toNumber() === 1;
    });
  });

  it("Test Success: Reviewers vote on the dispute", async () => {
    // Votes from user3 to user7 (APPROVE)
    for (let i = 3; i <= 7; i++) {
      await disputeResolutionDAOInstance.vote(i + 2, 1, 1, { from: accounts[i] });
    }

    // Votes from user8 and user9 (REJECT)
    await disputeResolutionDAOInstance.vote(10, 1, 2, { from: user8 });
    await disputeResolutionDAOInstance.vote(11, 1, 2, { from: user9 });
  });

  it("Test Success: Manually end voting and resolve dispute", async () => {
    await disputeResolutionDAOInstance.manuallyTriggerEndVoting(1, { from: owner });
  });

  it("Test Token Balances After Dispute Resolution - (in favour of client)", async () => {
    // Check balances of client, freelancer, and reviewers
    // Client (user1) should have 95 tokens [Client had 75. 25 was held in escrow. Upon voting in their favour, 15 (reward) was refunded. After distribution to the 5 winning voters, 5 more are refunded.]
    // Freelancer (user2) should have 100 tokens (no change)
    // Reviewers (user3 to user7) should have 101 tokens each (1 token reward)
    // Reviewers (user8 and user9) should have 100 tokens each (no reward)

    let clientBalance = await nativeTokenInstance.checkCredit(user1);
    let freelancerBalance = await nativeTokenInstance.checkCredit(user2);
    assert.equal(clientBalance.toNumber(), 95, "Client should have 95 tokens");
    assert.equal(freelancerBalance.toNumber(), 100, "Freelancer should have 100 tokens");

    for (let i = 3; i <= 9; i++) {
      let reviewerBalance = await nativeTokenInstance.checkCredit(accounts[i]);
      if (i <= 7) {
        assert.equal(reviewerBalance.toNumber(), 101, `Reviewer ${i} should have 101 tokens`);
      } else {
        assert.equal(reviewerBalance.toNumber(), 100, `Reviewer ${i} should have 100 tokens`);
      }
    }
  });
});
