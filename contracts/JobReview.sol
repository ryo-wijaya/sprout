pragma solidity ^0.5.0;

import "./User.sol";
import "./JobListing.sol";

contract JobReview {

    // ===================================================== SCHEMA & STATE VARIABLES ===================================================== //

    struct Review {
        uint256 clientId;
        uint256 freelancerId;
        uint256 rating; // This should be 1-5
        string comments;
    }

    User public userContract;
    JobListing public jobContract;

    uint256 public reviewCount = 0;
    mapping(uint256 => Review) public reviews; // mapping of reviewIDs to reviews
    mapping(uint256 => Review[]) public userToReviews; // mapping of userIds to their reviews
    mapping(uint256 => uint256[]) public userToRatings; // mapping of userIds to their ratings
    mapping(uint256 => uint256) public userToAvgRatings; // mapping of userIds to their average ratings

    // Track whether a freelancer or client has reviewed the other party for a particular job (each job can only have 1 client and 1 freelancer rating)
    mapping(uint256 => bool) public jobFreelancerReviewed;
    mapping(uint256 => bool) public jobClientReviewed;

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
    /**
    * @dev Function for a client to create a review for a freelancer
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The userId must be valid
    * - You must be a client
    * - The freelancerId must be a freelancer
    * - The job must be completed
    * - The freelancer and client must correspond to the one in the stipulated job
    * - Rating must be within the 1-5 range.
    * - The client can only review the freelancer ONCE per completed job
    *
    * @param _clientId The unique identifier of the client creating the review.
    * @param _freelancerId The unique identifier of the freelancer being reviewed.
    * @param _jobId The unique identifier of the job associated with this review.
    * @param _rating The rating given to the freelancer (1-5).
    * @param _comments The review comments.
    */
    function createFreelancerReview(uint256 _clientId, uint256 _freelancerId, uint256 _jobId, uint256 _rating, string memory _comments) isFreelancer(_freelancerId) isClient(_clientId) jobCompleted(_jobId) public {
        require(userContract.getAddressFromUserId(_clientId) == msg.sender, "This userId does not correspond to yourself");
        require(_rating >= 1 && _rating <= 5, "Invalid rating, rating is a range between 1-5");
        require(!jobFreelancerReviewed[_jobId], "Freelancer has already reviewed this job");

        Review storage review = reviews[reviewCount];
        review.clientId = _clientId; 
        review.freelancerId = _freelancerId;
        review.rating = _rating;
        review.comments = _comments;

        // updates the array of reviews of a particular freelancer
        userToReviews[_freelancerId].push(review);

        // updates the mapping to indicate that the freelancer has reviewed the client for this job
        jobFreelancerReviewed[_jobId] = true;

        // update the rating from the freelancer's previous ratings by taking the average
        userToRatings[_freelancerId].push(_rating);
        uint256 newRating = 0;

        uint256[] storage userCurrentRatings = userToRatings[_freelancerId];
        for (uint256 i = 0; i < userCurrentRatings.length; i++) {
            newRating += userCurrentRatings[i];
        }
         // updates the average rating of the particular freelancer
        userToAvgRatings[_freelancerId] = newRating / userCurrentRatings.length;
        uint256 newAvgRating = userToAvgRatings[_freelancerId];
        userContract.updateUserRating(_freelancerId, newAvgRating);
        reviewCount++;

        emit FreelancerReviewed(_freelancerId);
    }

    /**
    * @dev Function for a freelancer to review a client
    *
    * Considerations:
    * - You must be who you say you are (userId wise)
    * - The userId must be valid
    * - You must be a freelancer
    * - The freelancer and client must correspond to the one in the stipulated job
    * - Rating must be within the 1-5 range.
    * - The job must be completed
    * - The freelancer can only review the client ONCE per completed job
    *
    * @param _clientId The unique identifier of the client being reviewed.
    * @param _freelancerId The unique identifier of the freelancer creating the review.
    * @param _jobId The unique identifier of the job associated with this review.
    * @param _rating The rating given to the client (1-5).
    * @param _comments The review comments.
    */
    function createClientReview(uint256 _clientId, uint256 _freelancerId, uint256 _jobId, uint256 _rating, string memory _comments) isFreelancer(_freelancerId) isClient(_clientId) jobCompleted(_jobId) public {
        require(userContract.getAddressFromUserId(_freelancerId) == msg.sender, "This userId does not correspond to yourself");
        require(_rating >= 1 && _rating <= 5, "Invalid rating, rating is a range between 1-5");
        require(!jobClientReviewed[_jobId], "Client has already reviewed this job");

        Review storage review = reviews[reviewCount];
        review.clientId = _clientId; 
        review.freelancerId = _freelancerId;
        review.rating = _rating;
        review.comments = _comments;

        // updates the array of reviews of a particular client
        userToReviews[_clientId].push(review);

        // updates the mapping to indicate that the client has reviewed the freelancer for this job
        jobClientReviewed[_jobId] = true;

        // update the rating from the freelancer's previous ratings by taking the average
        userToRatings[_clientId].push(_rating);
        uint256 newRating = 0;
        uint256[] storage userCurrentRatings = userToRatings[_clientId];
        for (uint256 i = 0; i < userCurrentRatings.length; i++) {
            newRating += userCurrentRatings[i];
        }
         // updates the average rating of the particular freelancer
        userToAvgRatings[_clientId] = newRating / userCurrentRatings.length;
        uint256 newAvgRating = userToAvgRatings[_clientId];
        userContract.updateUserRating(_clientId, newAvgRating);
        reviewCount++;
        
        emit ClientReviewed(_clientId);
    }

    /**
    * @dev Retrieve the current average rating of a freelancer.
    *
    * @param _freelancerId The unique identifier of the freelancer.
    * @return uint256 of the average rating of the freelancer.
    */
    function getFreelancerRating(uint256 _freelancerId) public view isFreelancer(_freelancerId) returns (uint256) {
        return userToAvgRatings[_freelancerId];
    }

    /**
    * @dev Retrieve the current average rating of a client.
    *
    * @param _clientId The unique identifier of the client.
    * @return uint256 of the average rating of the client.
    */
    function getClientRating(uint256 _clientId) public view isClient(_clientId) returns (uint256) {
        return userToAvgRatings[_clientId];
    }
    
    /**
    * @dev Retrieve the details of a specific review.
    *
    * @param _reviewId The unique identifier of the review.
    * @return tuple of the details of the review including clientId, freelancerId, rating, and comments.
    */
    function getReviewDetails(uint256 _reviewId) public view isValidReview(_reviewId) returns(uint256, uint256, uint256, string memory) {
        Review memory review = reviews[_reviewId];
        return (review.clientId, review.freelancerId, review.rating, review.comments);
    }
}
