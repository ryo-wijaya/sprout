const truffleAssert = require("truffle-assertions");
var assert = require("assert");

var User = artifacts.require("User");

contract("User", (accounts) => {
  let userInstance;
  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];

  before(async () => {
    userInstance = await User.deployed();
  });

  it("Test SUCCESS: regisering a user profile (freelancer)", async () => {
    let result = await userInstance.register(0, "username1", "name1", "email1@example.com", "bio1", {
      from: user1,
      value: web3.utils.toWei("0.01", "ether"),
    });
    truffleAssert.eventEmitted(result, "NewUserRegistered", (ev) => {
      return ev.userId.toNumber() === 1 && ev.userType.toNumber() === 0; // 0 corresponds to UserType.Freelancer for the 2nd predicate
    });
    const userDetails = await userInstance.getUserDetails(1);
    assert.equal(userDetails[1], "username1", "Username mismatch");
    assert.equal(userDetails[2], "name1", "Name mismatch");
  });

  it("Test SUCCESS: updating a user a profile details", async () => {
    let result = await userInstance.updateUserDetails(
      1,
      "name1_updated",
      "email1_updated@example.com",
      "bio1_updated",
      {
        from: user1,
      }
    );
    truffleAssert.eventEmitted(result, "UserUpdated", (ev) => {
      return ev.userId.toNumber() === 1;
    });
    const userDetails = await userInstance.getUserDetails(1);
    assert.equal(userDetails[2], "name1_updated", "Name update failed");
    assert.equal(userDetails[3], "email1_updated@example.com", "Email update failed");
  });

  it("Test FAILURE: only the owner of the profile can update a profile", async () => {
    await truffleAssert.reverts(
      userInstance.updateUserDetails(1, "name1_new", "email1_new@example.com", "bio1_new", { from: user2 }),
      "You are not the owner of this profile"
    );
  });

  it("Test SUCCESS: get total number of users", async () => {
    const totalUsers = await userInstance.getTotalUsers();
    assert.equal(totalUsers.toNumber(), 1, "Total users mismatch");
  });

  it("Test SUCCESS: get correct address from userId", async () => {
    const address = await userInstance.getAddressFromUserId(1);
    assert.equal(address, user1, "Address mismatch");
  });

  it("Test SUCCESS: haveSameAddress method returns the correct bool", async () => {
    const result = await userInstance.haveSameAddress(1, 1);
    assert.equal(result, true, "Users should have same address");
  });

  it("Test SUCCESS: UserType predicate checks return the correct bool", async () => {
    const isFreelancer = await userInstance.isFreelancer(1);
    assert.equal(isFreelancer, true, "User should be freelancer");

    const isClient = await userInstance.isClient(1);
    assert.equal(isClient, false, "User should not be client");

    const isReviewer = await userInstance.isReviewer(1);
    assert.equal(isReviewer, false, "User should not be reviewer");
  });

  it("Test FAILURE: no duplicate usernames in the system", async () => {
    await truffleAssert.reverts(
      userInstance.register(0, "username1", "name2", "email2@example.com", "bio2", {
        from: user2,
        value: web3.utils.toWei("0.01", "ether"),
      }),
      "Username already exists."
    );
  });

  it("Test SUCCESS: for one address, max 1 UserType profile each", async () => {
    await truffleAssert.reverts(
      userInstance.register(0, "username2", "name2", "email2@example.com", "bio2", {
        from: user1,
        value: web3.utils.toWei("0.01", "ether"),
      }),
      "User of this type already exists for this address."
    );
  });
});
