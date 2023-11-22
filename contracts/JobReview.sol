pragma solidity ^0.5.0;

import "./User.sol";
import "./JobListing.sol";

contract JobReview {

    // ===================================================== SCHEMA & STATE VARIABLES ===================================================== //

    struct Review {
        uint256 clientId;
        uint256 freelancerId;
        uint256 rating;  // we should verify this is 1-5
        string comments;
    }


    uint256 public reviewCount = 0;
    mapping(uint256 => Review) public reviews; // mapping of reviews and review ids
    mapping(uint256 => Review[]) public userToReviews; // mapping of userIds and their reviews in an array
    mapping(uint256 => uint256[]) public userToRatings; // mapping of userIds and their array of ratings
    mapping(uint256 => uint256) public userToAvgRatings; // mapping of userIds and their average ratings
    User public userContract; // Reference to the User Contract
    JobListing public jobContract; // Reference to the Job Contract

    constructor(address _userContract, address _jobContract) public {
        userContract = User(_userContract);
        jobContract = JobListing(_jobContract);
    }

    // ====================================================== EVENTS & MODIFIERS ========================================================== //
    event FreelancerReviewed(uint256 _freelancerId);
    event ClientReviewed(uint256 _clientId);

    modifier isFreelancer(uint256 _freelancerId) {
        require(userContract.isFreelancer(_freelancerId), "User is not a freelancer");
        _;
    }

    modifier isClient(uint256 _clientId) {
        require(userContract.isClient(_clientId), "User is not a client");
        _;
    }

    modifier jobCompleted(uint256 _jobId) {
        require(jobContract.isJobClosed(_jobId), "Job is not completed yet");
        _;
    }

    modifier isValidReview(uint256 _reviewId) {
        require(_reviewId >= 0 && _reviewId <= reviewCount, "Review ID is not valid");
        _;
    }


    // ============================================================== METHODS ============================================================= //
    /*
        * Function for a client to create a review for a freelancer
        *
        * Considerations:
        * - You must be who you say you are (userId wise)
        * - The userId must be valid
        * - You must be a client
        * - The freelancerId must be a freelancer
        * - The job must be completed
    */
    function createFreelancerReview(uint256 _clientId, uint256 _freelancerId, uint256 _jobId, uint256 _rating, string memory _comments) isFreelancer(_freelancerId) isClient(_clientId) jobCompleted(_jobId) public {
        require(userContract.getAddressFromUserId(_clientId) == msg.sender, "This userId does not correspond to yourself");
        require(_rating >= 1 && _rating <= 5, "Invalid rating, rating is a range between 1-5");

        Review storage review = reviews[reviewCount];
        review.clientId = _clientId; 
        review.freelancerId = _freelancerId;
        review.rating = _rating;
        review.comments = _comments;

        userToReviews[_freelancerId].push(review); // updates the array of reviews of a particular freelancer

        // update the rating from the freelancer's previous ratings by taking the average
        userToRatings[_freelancerId].push(_rating);
        uint256 newRating = 0;

        uint256[] storage userCurrentRatings = userToRatings[_freelancerId];
        for (uint256 i = 0; i < userCurrentRatings.length; i++) {
            newRating += userCurrentRatings[i];
        }
        userToAvgRatings[_freelancerId] = newRating / userCurrentRatings.length; // updates the average rating of the particular freelancer

        reviewCount++; // update the count of reviews

        emit FreelancerReviewed(_freelancerId);
    }

    /**
        * Function for a freelancer to review a client
        *
        * Considerations:
        * - You must be who you say you are (userId wise)
        * - The userId must be valid
        * - You must be a freelancer
        * - The freelancerId/clientId must be a freelancer/client
        * - The job must be completed
    */
    function createClientReview(uint256 _clientId, uint256 _freelancerId, uint256 _jobId, uint256 _rating, string memory _comments) isFreelancer(_freelancerId) isClient(_clientId) jobCompleted(_jobId) public {
        require(userContract.getAddressFromUserId(_freelancerId) == msg.sender, "This userId does not correspond to yourself");
        require(_rating >= 1 && _rating <= 5, "Invalid rating, rating is a range between 1-5");

        Review storage review = reviews[reviewCount];
        review.clientId = _clientId; 
        review.freelancerId = _freelancerId;
        review.rating = _rating;
        review.comments = _comments;

        userToReviews[_clientId].push(review); // updates the array of reviews of a particular client

        // update the rating from the freelancer's previous ratings by taking the average
        userToRatings[_clientId].push(_rating);
        uint256 newRating = 0;
        uint256[] storage userCurrentRatings = userToRatings[_clientId];
        for (uint256 i = 0; i < userCurrentRatings.length; i++) {
            newRating += userCurrentRatings[i];
        }
        userToAvgRatings[_clientId] = newRating / userCurrentRatings.length; // updates the average rating of the particular freelancer

        reviewCount++; // update the count of reviews

        emit ClientReviewed(_clientId);
    }

    // Get a freelancer's current rating
    function getFreelancerRating(uint256 _freelancerId) public view isFreelancer(_freelancerId) returns (uint256) {
        return userToAvgRatings[_freelancerId];
    }

    // Get a client's current rating
    function getClientRating(uint256 _clientId) public view isClient(_clientId) returns (uint256) {
        return userToAvgRatings[_clientId];
    }
    
    // Get review Details
    function getReviewDetails(uint256 _reviewId) public view isValidReview(_reviewId) returns(uint256, uint256, uint256, string memory) {
        Review memory review = reviews[_reviewId];
        return (review.clientId, review.freelancerId, review.rating, review.comments);
    }
}
