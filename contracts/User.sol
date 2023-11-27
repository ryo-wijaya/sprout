pragma solidity ^0.5.0;

contract User {

    // ===================================================== SCHEMA & STATE VARIABLES ===================================================== //
    enum UserType {Freelancer, Client, Reviewer}
    
    /*
    * Password is omitted for technical simplicity. Ideally, in a production environment, user authentication should be handled using secure, 
    * off-chain methods or through Ethereum's built-in cryptographic functions. 
    * Storing sensitive information like passwords on-chain is not recommended due to transparency of blockchain data. 
    * Instead, external identity verification services can be used for user authentication. Wallet-based authentication is also an option.
    *
    * We also assume some sort of off-chain user verification mechanism to discourage the risk of sybil attacks.
    */
    struct UserProfile {
        UserType userType;
        string username;
        string name;
        string email; 
        string bio;
        uint256 rating;
    }

    address private owner;

    address public jobReviewAddress; // This is for access control to contract functions

    uint256 private numUsers = 1;
    mapping(uint256 => UserProfile) private users;
    // This is a mapping of address -> userType (0 means Freelancer) -> userId
    mapping(address => mapping(uint256 => uint256)) private addressToUserTypeId;
    mapping(uint256 => address) private userIdToAddress; // reverse mapping to get address from userId
    mapping(string => uint256) private usernamesToUserId;
    uint256[] private userList; // This is to display lists of users on the frontend

    constructor() public {
        owner = msg.sender;
    }


    // ====================================================== EVENTS & MODIFIERS ========================================================== //
    event NewUserRegistered(uint256 userId, UserType userType);
    event UserUpdated(uint256 userId);
    event UserRatingUpdated(uint256 userId, uint256 newRating);

    modifier onlyUser(uint256 userId) {
        require(bytes(users[userId].username).length > 0, "Only registered users can perform this action");
        _;
    }

    modifier onlyOwner(uint256 userId) {
        require(addressToUserTypeId[msg.sender][uint(users[userId].userType)] == userId, "You are not the owner of this profile");
        _;
    }

    modifier onlyContractOwner() {
        require(msg.sender == owner, "Caller is not the contract owner");
        _;
    }

    modifier validUserId(uint256 userId) {
        require(userId <= numUsers, "Invalid user ID");
        _;
    }

    modifier onlyJobReview() {
        require(msg.sender == jobReviewAddress, "Caller is not the Job Review Contract");
        _;
    }

    // ============================================================== METHODS ============================================================= //
    /**
    * @dev Register a user profile on the platform. Either as a Freelancer, Client or Reviewer.
    *
    * Considerations:
    * - UserType must be valid
    * - Username must be unique
    * - There can only be one profile of each user type per address
    * - At least 0.01 ETH is needed to spawn a new user
    * 
    * @param userType The type of the user (Freelancer, Client, Reviewer).
    * @param username The chosen username for the new user.
    * @param name The name of the user.
    * @param email The email address of the user.
    * @param bio A brief description of the user and their qualifications / information.
    */
    function register(UserType userType, string memory username, string memory name, string memory email, string memory bio) public payable {
        require(userType >= UserType.Freelancer && userType <= UserType.Reviewer, "Invalid user type provided.");
        require(usernamesToUserId[username] == 0, "Username already exists.");
        require(addressToUserTypeId[msg.sender][uint(userType)] == 0, "User of this type already exists for this address.");  
        require(msg.value >= 0.01 ether, "At least 0.01 ETH is needed to spawn a new user.");

        // Create the new user profile
        UserProfile memory newUser;
        newUser.userType = userType;
        newUser.username = username; 
        newUser.name = name;
        newUser.email = email;
        newUser.bio = bio;
        newUser.rating = 0;

        // associate the new user profile to mappings
        uint256 userId = numUsers++;
        users[userId] = newUser;
        addressToUserTypeId[msg.sender][uint(userType)] = userId;
        userIdToAddress[userId] = msg.sender; // populate the reverse mapping
        usernamesToUserId[username] = userId;
        userList.push(userId);
        
        emit NewUserRegistered(userId, userType);
    }

    /**
    * @dev Update the details of a user profile. Only the name, email address and bio can be updated.
    *
    * Considerations:
    * - You must be the owner of the profile, which implies you must be a registered user.
    * - Only name, email, and bio can be updated.
    *
    * @param userId The unique identifier of the user.
    * @param name The new name of the user.
    * @param email The new email address of the user.
    * @param bio The new bio of the user.
    */
    function updateUserDetails(uint256 userId, string memory name, string memory email, string memory bio) public onlyUser(userId) onlyOwner(userId) validUserId(userId) {
        users[userId].name = name;
        users[userId].email = email;
        users[userId].bio = bio;

        emit UserUpdated(userId);
    }

    /**
    * @dev Update the ratings of a user after a jobReview. 
    *
    * Considerations:
    * - This function can only be called by the JobReview contract
    *
    * @param userId The unique identifier of the user.
    * @param newRating The new rating of the user
    */
    function updateUserRating(uint256 userId, uint256 newRating) public validUserId(userId) onlyJobReview() {
        users[userId].rating = newRating;
        emit UserRatingUpdated(userId, newRating);
    }
    /**
    * @dev Return the user profile details. This custom getter is primarily for front-end use.
    *
    * Considerations:
    * - The userId must be valid and correspond to an existing user.
    *
    * @param userId The unique identifier of the user whose details are being fetched.
    * @return tuple containing the user's profile details: UserType, username, name, email, bio, and rating.
    */
    function getUserDetails(uint256 userId) public view validUserId(userId) returns (UserType, string memory, string memory, string memory, string memory, uint256) {
        UserProfile memory userProfile = users[userId];
        return (userProfile.userType, userProfile.username, userProfile.name, userProfile.email, userProfile.bio, userProfile.rating);
    }

    /**
    * @dev Get the total number of users registered in the application.
    *
    * @return uint256 representing the total number of users registered in the platform.
    */
    function getTotalUsers() public view returns(uint256) {
        return userList.length;
    }

    /**
    * @dev Get the address from a given userId
    *
    * @param userId The unique identifier of the user.
    * @return address associated with the given userId.
    */
    function getAddressFromUserId(uint256 userId) public view returns(address) {
        return userIdToAddress[userId];
    }

    /**
    * @dev Checks if 2 users share the same address using the reverse mapping
    *
    * @param userId1 The unique identifier of the first user.
    * @param userId2 The unique identifier of the second user.
    * @return bool indicating whether the two users have the same address.
    */
    function haveSameAddress(uint256 userId1, uint256 userId2) public view returns(bool) {
        return userIdToAddress[userId1] == userIdToAddress[userId2];
    }

    /**
    * @dev Checks if a user is a client
    *
    * @param userId The unique identifier of the user.
    * @return bool indicating whether the user is a client.
    */
    function isClient(uint256 userId) public view returns(bool) {
        return users[userId].userType == UserType.Client;
    }

    /**
    * @dev Checks if a user is a freelancer
    *
    * @param userId The unique identifier of the user.
    * @return bool indicating whether the user is a freelancer.
    */
    function isFreelancer(uint256 userId) public view returns(bool) {
        return users[userId].userType == UserType.Freelancer;
    }

    /**
    * @dev Checks if a user is a reviewer
    *
    * @param userId The unique identifier of the user.
    * @return bool indicating whether the user is a reviewer.
    */
    function isReviewer(uint256 userId) public view returns(bool) {
        return users[userId].userType == UserType.Reviewer;
    }

    /**
    * @dev Transfer ownership of the contract to another address.
    *
    * Considerations:
    * - Only the current owner can transfer ownership.
    * - The new owner cannot be the zero address.
    *
    * @param newOwner The address of the new owner.
    */
    function transferOwnership(address newOwner) public onlyContractOwner {
        require(newOwner != address(0), "New owner is the zero address");
        owner = newOwner;
    }

    /**
    * @dev Withdraw Ether held in this contract to the owner's address.
    *
    * Considerations:
    * - Only the contract owner can withdraw Ether.
    * - There must be Ether in the contract to withdraw.
    */
    function withdrawEther() public onlyContractOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "User: no Ether to withdraw");
        // Transfer Ether to the owner's address
        address payable ownerAddress = address(uint160(owner));
        ownerAddress.transfer(amount);
    }

    /**
    * @dev Sets the address of the JobReview contract. This function can only be called once.
    *
    * This function allows the contract owner to set the address of the JobReview contract.
    * It is essential for linking the User contract with the JobReviewContract for checking for validity.
    *
    * @notice Can only be called by the contract owner and only once.
    * @param _jobReviewAddress The address of the JobReview contract to be linked.
    */
    function setJobReviewAddress(address _jobReviewAddress) public onlyContractOwner() {
        require(jobReviewAddress == address(0), "jobReview address already set");
        jobReviewAddress = _jobReviewAddress;
    }
}
