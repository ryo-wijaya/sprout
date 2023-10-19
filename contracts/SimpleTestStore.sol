pragma solidity ^0.5.0;

contract SimpleTestStore {
    uint256 private storedData;

    event DataStored(uint256 value);

    function set(uint256 x) public {
        storedData = x;
        emit DataStored(x);
    }

    function get() public view returns (uint256) {
        return storedData;
    }
}