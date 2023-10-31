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
    let endTime = generateUnixTime(5); // ends 5 days in the future
    let reward = 10;

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

    // user2 uses client ID 3 to create a job, for tetsing later
    let result2 = await jobListingInstance.createJob(3, title, description, endTime, reward, {
      from: user2,
    });
    truffleAssert.eventEmitted(result2, "JobCreated", (ev) => {
      return ev.jobId.toNumber() === 2 && ev.title === title;
    });
  });

  it("Test FAILURE: Failed to create a job", async () => {
    let title = "Sample Job Title";
    let description = "This is a sample job description.";
    let endTime = generateUnixTime(5); // ends 5 days in the future
    let reward = 10;

    // user1 attempts to use user2's client ID 3 to create a job
    await truffleAssert.reverts(
      jobListingInstance.createJob(3, title, description, endTime, reward, { from: user1 }),
      "This userId does not correspond to yourself"
    );
    // user1 attempts to create a job with his freelancer account with ID 2
    await truffleAssert.reverts(
      jobListingInstance.createJob(2, title, description, endTime, reward, {
        from: user1,
      }),
      "Only clients can create jobs."
    );
    // user1 attempts to create a job with an end time less than 3 days from now (business rule)
    await truffleAssert.reverts(
      jobListingInstance.createJob(1, title, description, generateUnixTime(2), reward, {
        from: user1,
      }),
      "The end time must be at least 3 days from now."
    );
  });

  it("Test SUCCESS: Client updates a job's details", async () => {
    let jobIdToUpdate = 1;
    let title = "New Job Title";
    let description = "New job description.";
    let endTime = generateUnixTime(6); // ends 5 days in the future
    let reward = 15;

    // user1 uses client ID 1 updating his job with ID 1
    let result = await jobListingInstance.updateJob(1, 1, title, description, endTime, reward, {
      from: user1,
    });

    truffleAssert.eventEmitted(result, "JobUpdated", (ev) => {
      return ev.jobId.toNumber() === jobIdToUpdate && ev.title === title;
    });

    // Check job is updated correctly
    let jobDetails = await jobListingInstance.getJobDetails(jobIdToUpdate);
    assert.equal(jobDetails[2], title, "Job title mismatch");
    assert.equal(jobDetails[3], description, "Job description mismatch");
    assert.equal(jobDetails[4], endTime, "End time mismatch");
    assert.equal(jobDetails[5].toNumber(), reward, "Job reward mismatch");
  });

  it("Test FAILURE: Failed to update a job's details", async () => {
    let title = "New Job Title";
    let description = "New job description.";
    let endTime = generateUnixTime(6); // ends 6 days in the future
    let reward = 15;

    // User2 attempts to update the job using user1's client ID 1 and job ID 1
    await truffleAssert.reverts(
      jobListingInstance.updateJob(1, 1, title, description, endTime, reward, { from: user2 }),
      "This userId does not correspond to yourself"
    );

    // End time is not in the future
    const pastTime = Math.floor(Date.now() / 1000) - 60;
    await truffleAssert.reverts(
      jobListingInstance.updateJob(1, 1, title, description, pastTime, reward, { from: user1 }),
      "The end time must be in the future."
    );
  });

  it("Test SUCCESS: Client closes a job", async () => {
    // User1 closes his client ID 1's job with ID 1
    let result = await jobListingInstance.closeJob(1, 1, {
      from: user1,
    });
    truffleAssert.eventEmitted(result, "JobClosed", (ev) => {
      return ev.jobId.toNumber() === 1 && ev.title === "New Job Title";
    });
    // User2 closes his client ID 3's job with ID 2
    let result2 = await jobListingInstance.closeJob(3, 2, {
      from: user2,
    });
    truffleAssert.eventEmitted(result2, "JobClosed", (ev) => {
      return ev.jobId.toNumber() === 2 && ev.title === "Sample Job Title";
    });
  });

  it("Test FAILURE: Failed to close a job", async () => {
    // User1 attempts to close an invalid job ID
    await truffleAssert.reverts(jobListingInstance.closeJob(1, 10, { from: user1 }), "Invalid Job ID");

    // User1 attempts to close an already closed job
    await truffleAssert.reverts(
      jobListingInstance.closeJob(1, 1, { from: user1 }),
      "This job is either OPEN or currently ongoing and cannot be closed."
    );

    // User2 attempts to close user1's job ID 1
    await truffleAssert.reverts(
      jobListingInstance.closeJob(1, 1, { from: user2 }),
      "This userId does not correspond to yourself"
    );
  });

  it("Test SUCCESS: Client re-opens a closed job", async () => {
    // User1 re-opens his client ID 1's job with ID 1
    let result = await jobListingInstance.reopenJob(1, 1, {
      from: user1,
    });
    truffleAssert.eventEmitted(result, "JobOpened", (ev) => {
      return ev.jobId.toNumber() === 1 && ev.title === "New Job Title";
    });
  });

  it("Test FAILURE: Failed to re-open a closed job", async () => {
    // User1 attempts to reopen an invalid job ID
    await truffleAssert.reverts(jobListingInstance.reopenJob(1, 10, { from: user1 }), "Invalid Job ID");

    // User1 attempts to reopen an already open job
    await truffleAssert.reverts(
      jobListingInstance.reopenJob(1, 1, { from: user1 }),
      "This job is not currently CLOSED."
    );

    // User2 attempts to reopen user1's job ID 1
    await truffleAssert.reverts(
      jobListingInstance.reopenJob(1, 1, { from: user2 }),
      "This userId does not correspond to yourself"
    );
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

  it("Test FAILURE: Failed to apply for a job", async () => {
    // Invalid job ID
    await truffleAssert.reverts(
      jobListingInstance.applyForJob(4, 10, "This is my proposal", { from: user2 }),
      "Invalid Job ID"
    );

    // User2 uses freelancer ID 4 to apply for the job that they have already applied to
    await truffleAssert.reverts(
      jobListingInstance.applyForJob(4, 1, "This is my proposal", {
        from: user2,
      }),
      "You have already applied for this job."
    );

    // User1 attempts to apply to user2's JobID 2 that is closed
    await truffleAssert.reverts(
      jobListingInstance.applyForJob(1, 2, "This is my proposal", { from: user1 }),
      "Job is not open for applications"
    );

    // Reopen the job
    await jobListingInstance.reopenJob(3, 2, {
      from: user2,
    });

    // User1 attempts to apply to user2's JobID 2 with a client
    await truffleAssert.reverts(
      jobListingInstance.applyForJob(1, 2, "This is my proposal", { from: user1 }),
      "Only freelancers can take jobs."
    );

    // User2 attempts to apply to his own job with his freelancer account
    await truffleAssert.reverts(
      jobListingInstance.applyForJob(4, 2, "This is my proposal", { from: user2 }),
      "Freelancer and client cannot have the same address"
    );

    // User2 attempts to reopen user1's job ID 1
    await truffleAssert.reverts(
      jobListingInstance.reopenJob(1, 1, { from: user2 }),
      "This userId does not correspond to yourself"
    );
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

    // TODO: TEST THAT THE FUNDS ARE IN THE ESCROW

    // User 1 successfully applies in the end with freelancer ID 2 to user2's Job ID 2 (for the purpose of the next failure test)
    await jobListingInstance.applyForJob(2, 2, "This is my proposal", { from: user1 });
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
});
