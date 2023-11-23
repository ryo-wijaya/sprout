const truffleAssert = require("truffle-assertions");
var assert = require("assert");

var User = artifacts.require("User");
var JobListing = artifacts.require("JobListing");
var SproutToken = artifacts.require("SproutToken");
var JobReview = artifacts.require("JobReview");

// Helper functions
function generateUnixTime(daysFromNow) {
  const now = new Date();
  now.setDate(now.getDate() + daysFromNow);
  return Math.floor(now.getTime() / 1000);
}

contract("JobReview", (accounts) => {
  let userInstance;
  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];

  before(async () => {
    userInstance = await User.deployed();
    jobListingInstance = await JobListing.deployed();
    jobReviewInstance = await JobReview.deployed();
    sproutTokenInstance = await SproutToken.deployed();

    // 1 ETH gets each user 100 native tokens
    sproutTokenInstance.getCredit(user1, web3.utils.toWei("1", "ether"));
    sproutTokenInstance.getCredit(user2, web3.utils.toWei("1", "ether"));
  });

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
    // User 1 successfully applies in the end with freelancer ID 2 to user2's Job ID 2 (for the purpose of the next failure test)
    await jobListingInstance.applyForJob(2, 2, "This is my proposal", { from: user1 });
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

  it("Test SUCCESS: Client accepts job completion", async () => {
    // User1 with client ID 1 accepts completed job ID 1 from freelancer User2 with ID 4
    let result = await jobListingInstance.clientAcceptsJobCompletion(1, 1, {
      from: user1,
    });

    truffleAssert.eventEmitted(result, "JobAcceptedAsComplete", (ev) => {
      return ev.jobId.toNumber() === 1 && ev.clientId.toNumber() === 1;
    });
  });

  // TEST JOB REVIEW FUNCTIONS SINCE JOB HAS BEEN COMPLETED

  it("Test SUCCESS: Client leaves a review for freelancer", async () => {
    // User1 with client ID 1 creates a review for user2 Freelancer of ID 2 for Job with ID 1
    let result = await jobReviewInstance.createFreelancerReview(1, 4, 1, 5, "His work is amazing!", {
      from: user1,
    });

    truffleAssert.eventEmitted(result, "FreelancerReviewed", (ev) => {
      return ev._freelancerId.toNumber() === 4;
    });
    // Check Review details
    let reviewDetails = await jobReviewInstance.getReviewDetails(0);
    assert.equal(reviewDetails[0], 1, "Client ID Mismatch");
    assert.equal(reviewDetails[1], 4, "Freelancer ID Mismatch");
    assert.equal(reviewDetails[2], 5, "Rating Mismatch");
    assert.equal(reviewDetails[3], "His work is amazing!", "Comments Mismatch");
  });

  it("Test FAILURE: Client fails to leave a review for a freelancer", async () => {
    // User1 but freelancer ID 2 tries to leave the review
    await truffleAssert.reverts(
      jobReviewInstance.createFreelancerReview(2, 4, 1, 5, "Amazing work!", { from: user1 }),
      "User is not a client"
    );

    // User2 tries to leave a review
    await truffleAssert.reverts(
      jobReviewInstance.createFreelancerReview(1, 4, 1, 5, "Amazing work!", { from: user2 }),
      "This userId does not correspond to yourself"
    );

    // User1 attempts to leave a rating that is not between 1-5
    await truffleAssert.reverts(
      jobReviewInstance.createFreelancerReview(1, 4, 1, 10, "Amazing work", { from: user1 }),
      "Invalid rating, rating is a range between 1-5"
    );
  });

  it("Test SUCCESS: Freelancer leaves a review for client", async () => {
    // User2 with freelancer ID 4 creates a review for user1 Client of ID 1 for Job with ID 1
    let result = await jobReviewInstance.createClientReview(1, 4, 1, 5, "He was very easy to work with!", {
      from: user2,
    });

    truffleAssert.eventEmitted(result, "ClientReviewed", (ev) => {
      return ev._clientId.toNumber() === 1;
    });
    // Check Review details
    let reviewDetails = await jobReviewInstance.getReviewDetails(1);
    assert.equal(reviewDetails[0], 1, "Client ID Mismatch");
    assert.equal(reviewDetails[1], 4, "Freelancer ID Mismatch");
    assert.equal(reviewDetails[2], 5, "Rating Mismatch");
    assert.equal(reviewDetails[3], "He was very easy to work with!", "Comments Mismatch");
  });

  it("Test FAILURE: Freelancer fails to leave a review for a client", async () => {
    // User2 but freelancer ID 3 tries to leave the review
    await truffleAssert.reverts(
      jobReviewInstance.createClientReview(1, 3, 1, 5, "Thanks for the work!", { from: user2 }),
      "User is not a freelancer"
    );

    // User2 tries to leave a review
    await truffleAssert.reverts(
      jobReviewInstance.createClientReview(1, 4, 1, 5, "Thanks for the work!", { from: user1 }),
      "This userId does not correspond to yourself"
    );

    // User1 attempts to leave a rating that is not between 1-5
    await truffleAssert.reverts(
      jobReviewInstance.createClientReview(1, 4, 1, 10, "Thanks for the work!", { from: user2 }),
      "Invalid rating, rating is a range between 1-5"
    );
  });
});
