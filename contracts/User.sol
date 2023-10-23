pragma solidity ^0.5.0;

contract User {

    // ===================================================== SCHEMA & STATE VARIABLES ===================================================== //
    enum UserType {Freelancer, Client, Reviewer}
    
    // Password is omitted for simplicity
    struct UserProfile {
        UserType userType;
        string username;
        string name;
        string email; 
        string bio;
        uint256 rating;
    }

    uint256 public numUsers = 1;
    mapping(uint256 => UserProfile) public users;
    // This is a mapping of address -> userType (0 means Freelancer) -> userId
    mapping(address => mapping(uint256 => uint256)) public addressToUserTypeId;
    mapping(uint256 => address) public userIdToAddress; // reverse mapping
    mapping(string => uint256) public usernamesToUserId;
    uint256[] public userList; // This is to display lists of users on the frontend
    // ===================================================== SCHEMA & STATE VARIABLES ===================================================== //
    


    // ====================================================== EVENTS & MODIFIERS ========================================================== //
    event NewUserRegistered(uint256 userId, UserType userType);
    event UserUpdated(uint256 userId);

    modifier onlyUser(uint256 userId) {
        require(bytes(users[userId].username).length > 0, "Only registered users can perform this action");
        _;
    }

    modifier onlyOwner(uint256 userId) {
        require(addressToUserTypeId[msg.sender][uint(users[userId].userType)] == userId, "You are not the owner of this profile");
        _;
    }

    modifier validUserId(uint256 userId) {
        require(userId <= numUsers, "Invalid user ID");
        _;
    }
    // ====================================================== EVENTS & MODIFIERS ========================================================== //



    // ============================================================== METHODS ============================================================= //
    /**
    * Register a user profile.
    *
    * Considerations:
    * - UserType must be valid
    * - Username must be unique
    * - There can only be one profile of each user type per address
    * - At least 0.01 ETH is needed to spawn a new user
    */
    function register(UserType userType, string memory username, string memory name, string memory email, string memory bio) public payable {
        require(userType >= UserType.Freelancer && userType <= UserType.Reviewer, "Invalid user type provided.");
        require(usernamesToUserId[username] == 0, "Username already exists.");
        require(addressToUserTypeId[msg.sender][uint(userType)] == 0, "User of this type already exists for this address.");  
        require(msg.value >= 0.01 ether, "At least 0.01 ETH is needed to spawn a new user.");

        UserProfile memory newUser;
        newUser.userType = userType;
        newUser.username = username; 
        newUser.name = name;
        newUser.email = email;
        newUser.bio = bio;
        newUser.rating = 0;

        uint256 userId = numUsers++;

        users[userId] = newUser;
        addressToUserTypeId[msg.sender][uint(userType)] = userId;
        userIdToAddress[userId] = msg.sender; // populate the reverse mapping
        usernamesToUserId[username] = userId;
        userList.push(userId);
        
        emit NewUserRegistered(userId, userType);
    }

    /**
    * Update the details of a user profile. Only the name, email address and bio can be updated.
    *
    * Considerations:
    * - You must be the owner of the profile, which implies you must be a registered user
    */
    function updateUserDetails(uint256 userId, string memory name, string memory email, string memory bio) public onlyUser(userId) onlyOwner(userId) validUserId(userId) {
        users[userId].name = name;
        users[userId].email = email;
        users[userId].bio = bio;

        emit UserUpdated(userId);
    }

    /**
    * Return the user profile details (Meant for FE use as a custom getter)
    */
    function getUserDetails(uint256 userId) public view validUserId(userId) returns (UserType, string memory, string memory, string memory, string memory, uint256) {
        UserProfile memory userProfile = users[userId];
        return (userProfile.userType, userProfile.username, userProfile.name, userProfile.email, userProfile.bio, userProfile.rating);
    }

    /**
    * Deletes a user profile and returns the funds to the owner.
    * 
    * Considerations: 
    * - Only the owner of the profile can delete it
    * - The profile must have no ongoing ops
    */
    function deleteUserProfile(uint256 userId) public view {
        // TODO
        // I think we should get rid of this use case as it adds complexity and not really neccessary, do yall agree?
    }

    /**
    * Get the total number of users in the application
    */
    function getTotalUsers() public view returns(uint256) {
        return userList.length;
    }

    /**
    * Get the address from a given userId
    */
    function getAddressFromUserId(uint256 userId) public view returns(address) {
        return userIdToAddress[userId];
    }

    /**
    * Checks if 2 users share the same address, uses the reverse mapping
    */
    function haveSameAddress(uint256 userId1, uint256 userId2) public view returns(bool) {
        return userIdToAddress[userId1] == userIdToAddress[userId2];
    }

    /**
    * Checks if a user is a client
    */
    function isClient(uint256 userId) public view returns(bool) {
        return users[userId].userType == UserType.Client;
    }

    /**
    * Checks if a user is a freelancer
    */
    function isFreelancer(uint256 userId) public view returns(bool) {
        return users[userId].userType == UserType.Freelancer;
    }

    /**
    * Checks if a user is a reviewer
    */
    function isReviewer(uint256 userId) public view returns(bool) {
        return users[userId].userType == UserType.Reviewer;
    }
    // ============================================================== METHODS ============================================================= //
}
