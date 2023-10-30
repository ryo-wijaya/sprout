const truffleAssert = require("truffle-assertions");
var assert = require("assert");

var User = artifacts.require("User");
var JobListing = artifacts.require("JobListing");
var NativeToken = artifacts.require("NativeToken");

// Helper functions
function generateUnixTime(daysFromNow) {
  const now = new Date();
  now.setDate(now.getDate() + daysFromNow);
  return Math.floor(now.getTime() / 1000);
}

contract("JobListing", (accounts) => {
  let userInstance;
  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];

  before(async () => {
    userInstance = await User.deployed();
    jobListingInstance = await JobListing.deployed();
    nativeTokenInstance = await NativeToken.deployed();

    // 1 ETH gets each user 100 native tokens
    nativeTokenInstance.getCredit(user1, web3.utils.toWei("1", "ether"));
    nativeTokenInstance.getCredit(user2, web3.utils.toWei("1", "ether"));
  });

  /*
    Remember we want to set up the following user profiles:
        User Address 1:
            - User 1, Client
            - User 2, Freelancer
        User Address 2:
            - User 3, Client
            - User 4, Freelancer
  */

  it("Test SUCCESS: regiser 4 user profiles", async () => {
    // 2 user profiles from user 1, one freelancer and one client
    let result1 = await userInstance.register(1, "username1", "client1", "email1@example.com", "bio1", {
      from: user1,
      value: web3.utils.toWei("0.01", "ether"),
    });
    let result2 = await userInstance.register(0, "username2", "freelancer1", "email2@example.com", "bio2", {
      from: user1,
      value: web3.utils.toWei("0.01", "ether"),
    });
    // 2 user profiles from user 2, one freelancer and one client
    let result3 = await userInstance.register(1, "username3", "client2", "email3@example.com", "bio3", {
      from: user2,
      value: web3.utils.toWei("0.01", "ether"),
    });
    let result4 = await userInstance.register(0, "username4", "freelancer2", "email4@example.com", "bio4", {
      from: user2,
      value: web3.utils.toWei("0.01", "ether"),
    });
    truffleAssert.eventEmitted(result1, "NewUserRegistered", (ev) => {
      return ev.userId.toNumber() === 1 && ev.userType.toNumber() === 1;
    });
    truffleAssert.eventEmitted(result2, "NewUserRegistered", (ev) => {
      return ev.userId.toNumber() === 2 && ev.userType.toNumber() === 0;
    });
    truffleAssert.eventEmitted(result3, "NewUserRegistered", (ev) => {
      return ev.userId.toNumber() === 3 && ev.userType.toNumber() === 1;
    });
    truffleAssert.eventEmitted(result4, "NewUserRegistered", (ev) => {
      return ev.userId.toNumber() === 4 && ev.userType.toNumber() === 0;
    });
  });

  it("Test SUCCESS: Client creates a job", async () => {
    let jobIdExpected = 1;
    let title = "Sample Job Title";
    let description = "This is a sample job description.";
    let startDate = "2023-01-01";
    let endDate = "2023-02-01";
    let reward = 10;

    // user1 uses client ID 1 to create a job
    let result = await jobListingInstance.createJob(1, title, description, startDate, endDate, reward, {
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
    assert.equal(jobDetails[4].toNumber(), reward, "Job reward mismatch");
    assert.equal(jobDetails[5].toNumber(), 1, "Job status should be 1 (OPEN)");
  });

  it("Test FAILURE: Failed to create a job", async () => {
    // test failure due to creator not being a client
    // test failure due to not enough tokens to pay the reward
  });

  it("Test SUCCESS: Client updates a job's details", async () => {
    // test here
  });

  it("Test FAILURE: Failed to update a job's details", async () => {
    // Basically for the rest of the failure tests is just test the require statements only
  });

  it("Test SUCCESS: Client closes a job", async () => {
    // test here
  });

  it("Test FAILURE: Failed to close a job", async () => {
    // test here
  });

  it("Test SUCCESS: Client re-opens a closed job", async () => {
    // test here
  });

  it("Test FAILURE: Failed to re-open a closed job", async () => {
    // test here
  });

  it("Test SUCCESS: Freelancer applies for a job", async () => {
    // test here
  });

  it("Test FAILURE: Failed to apply for a job", async () => {
    // test here
  });

  it("Test SUCCESS: Client accepts an application", async () => {
    // test here
  });

  it("Test FAILURE: Failed to accept an application", async () => {
    // test here
  });

  it("Test SUCCESS: Freelancer completes a job", async () => {
    // test here
  });

  it("Test FAILURE: Failed to complete a job", async () => {
    // test here
  });

  it("Test SUCCESS: Client accepts job completion", async () => {
    // test here
  });

  it("Test FAILURE: Failed to accept job completion", async () => {
    // test here
  });

  it("Test SUCCESS: Get job details", async () => {
    // test here
  });

  it("Test SUCCESS: Get application details", async () => {
    // test here
  });

  it("Test SUCCESS: Get number of application for a job", async () => {
    // test here
  });
});
