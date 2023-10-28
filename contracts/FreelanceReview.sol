pragma solidity ^0.5.0;

import "./User.sol";

contract FreelanceReview {

    struct Review {
        uint256 reviewerId;
        uint256 freelancerId;
        uint256 rating;  // we should verify this is 1-5
        string comments;
    }


    uint256 public reviewCount = 0;
    mapping(uint256 => Review) public reviews; // mapping of reviews and ids
    mapping(uint256 => Review[]) public userToReviews; // mapping of userIds and their reviews in an array
    mapping(uint256 => uint256[]) public userToRatings; // mapping of userIds and their array of ratings
    mapping(uint256 => uint256) public userToAvgRatings;
    User public userContract; // Reference to the User Contract

    event FreelancerReviewed(uint256 _freelancerId);
    event ClientReviewed(uint256 _clientId);

    constructor(address _userContract) public {
        userContract = User(_userContract); 
    }

    // modifiers
    modifier isFreelancer(uint256 _freelancerId) {
        require(userContract.isFreelancer(_freelancerId), "User is not a freelancer");
        _;
    }

    modifier isClient(uint256 _clientId) {
        require(userContract.isClient(_clientId), "User is not a client");
        _;
    }


    function createFreelancerReview(uint256 _clientId, uint256 _freelancerId, uint256 _rating, string memory _comments) isFreelancer(_freelancerId) isClient(_clientId) public {
        require(userContract.getAddressFromUserId(_clientId) == msg.sender, "This userId does not correspond to yourself");
        require(_rating >= 1 && _rating <= 5, "Invalid _rating, _rating is a range between 1-5");

        Review storage review = reviews[reviewCount];
        review.reviewerId = _clientId; 
        review.freelancerId = _freelancerId;
        review.rating = _rating;
        review.comments = _comments;

        userToReviews[_freelancerId].push(review);

        // update the rating from the freelancer's previous ratings by taking the average
        userToRatings[_freelancerId].push(_rating);
        uint256 newRating = 0;
        uint256[] storage userRatings = userToRatings[_freelancerId];
        for (uint256 i = 0; i < userRatings.length; i++) {
            newRating += userRatings[i];
        }
        userToAvgRatings[_freelancerId] = newRating / userRatings.length;

        reviewCount++;

        emit FreelancerReviewed(_freelancerId);

    }

    function createClientReview(uint256 _clientId, uint256 jobId, uint256 rating, string memory comments) public {
        // verify job is completed
    }

    // Getter functions
    function getFreelancerRating(uint256 _freelancerId) public view isFreelancer(_freelancerId) returns (uint256) {
        return userToAvgRatings[_freelancerId];
    }

    // how to get the array of reviews for each freelancer?
}
