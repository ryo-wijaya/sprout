pragma solidity ^0.5.0;

contract FreelanceReview {

    struct Review {
        uint256 reviewerId;
        uint256 freelancerId;
        uint256 rating;  // we should verify this is 1-5
        string comments;
    }

    uint256 public reviewCount = 0;
    mapping(uint256 => Review) public reviews;

    function createFreelancerReview(uint256 freelancerId, uint256 jobId, uint256 rating, string memory comments) public {
        // verify job is completed
    }

    function createClientReview(uint256 clientId, uint256 jobId, uint256 rating, string memory comments) public {
        // verify job is completed
    }
}
