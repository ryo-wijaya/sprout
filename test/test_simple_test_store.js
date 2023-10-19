const truffleAssert = require("truffle-assertions");
var assert = require("assert");

var SimpleTestStore = artifacts.require("SimpleTestStore");

contract("SimpleTestStore", (accounts) => {
  before(async () => {
    simpleTestStoreInstance = await SimpleTestStore.deployed();
  });

  it("should store and get a value", async () => {
    await simpleTestStoreInstance.set(89, { from: accounts[0] });
    const result = await simpleTestStoreInstance.get();
    assert.equal(result.toNumber(), 89, "Value 89 was not stored.");
  });
});
