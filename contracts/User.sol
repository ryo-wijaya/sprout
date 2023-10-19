pragma solidity ^0.5.0;

contract User {

    enum UserType {Freelancer, Client, Reviewer}
    
    struct UserProfile {
        UserType userType;
        string username;
        string name;
        string email; 
        string bio;
        // bool isVerified;
        uint256 rating;
    }

    uint256 public numUsers = 1;
    mapping(uint256 => UserProfile) public users;
    mapping(address => uint256) public addressToUserId;
    mapping(string => uint256) public usernamesToUserId;
    uint256[] public userList; // This is to display lists of users on the frontend
    
    event NewUserRegistered(uint256 userId, UserType userType);
    event UserUpdated(uint256 userId);

    modifier onlyUser(uint256 userId) {
        require(bytes(users[userId].username).length > 0, "Only registered users can perform this action");
        _;
    }

    modifier onlyOwner(uint256 userId) {
        require(addressToUserId[msg.sender] == userId, "You are not the owner of this profile");
        _;
    }

    modifier validUserId(uint256 userId) {
        require(userId <= numUsers, "Invalid user ID");
        _;
    }

    function register(UserType userType, string memory username, string memory name, string memory email, string memory bio) public payable {
        require(usernamesToUserId[username] == 0, "Username already exists.");  // Check if username is already taken
        require(msg.value >= 0.01 ether, "At least 0.01 ETH is needed to spawn a new user.");

        UserProfile memory newUser;
        newUser.userType = userType;
        newUser.username = username; 
        newUser.name = name;
        newUser.email = email;
        newUser.bio = bio;
        // newUser.isVerified = false; 
        newUser.rating = 0;

        uint256 userId = numUsers++;

        users[userId] = newUser;
        addressToUserId[msg.sender] = userId;
        usernamesToUserId[username] = userId;
        userList.push(userId);
        
        emit NewUserRegistered(userId, userType);
    }

    function updateUserDetails(uint256 userId, string memory name, string memory email, string memory bio) public onlyUser(userId) onlyOwner(userId) validUserId(userId) {
        users[userId].name = name;
        users[userId].email = email;
        users[userId].bio = bio;

        emit UserUpdated(userId);
    }

    // How to verify without making it centralized? Maybe we can have some sort of vouching system?
    // function setVerificationStatus(address _user, bool _status) public onlyOwner {
        // KIV: Add logic to verfiy here (Only admin roles can call this function)
    //     users[_user].isVerified = _status;
    // }

    function getTotalUsers() public view returns(uint256) {
        return userList.length;
    }

    function isClient(uint256 userId) public view returns(bool) {
        return users[userId].userType == UserType.Client;
    }

    function isFreelancer(uint256 userId) public view returns(bool) {
        return users[userId].userType == UserType.Freelancer;
    }

    function isReviewer(uint256 userId) public view returns(bool) {
        return users[userId].userType == UserType.Reviewer;
    }
}
