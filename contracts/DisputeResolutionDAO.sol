pragma solidity ^0.5.0;
import "./User.sol";
// import "./JobListing.sol";

contract DisputeResolutionDAO {

    /*
    * This contract will be referenced by the JobListing contract. This is to make it easier to do job related checks and handle escrow management at a single place

    * Dispute resolution process:
    * - A dispute will always be started by the client.
    * - The client will need to pay (not stake) X amount of tokens to start a dispute.
    * - Reviewers will take a look at the job details, the work done, and make a vote for the winning party
    * - The voting will end the at designated end time, which is 3 days by default (This is an arbitrarily picked number).
    * - Passive closure: If a vote is attempted after the endTime, the dispute will be closed automatically and counting will commence.
    *
    * Outcome:
    * - If the dispute get more or equal number of APPROVE votes vs REJECT, the dispute will be APPROVED.
    * - If the dispute is APPROVED, the client will get back the tokens held in escrow and whatever work has already been done by the client
    * - If the dispute is REJECTED, the freelancer will get the tokens held in escrow
    * - Either way, the staked tokens by the client will get distributed to the reviewers who voted for the winning party
    *
    * Assumptions:
    * - When a dispute is made, the client and freelancer has an avenue to provide evidence and explanations of why the work done is acceptable/unacceptable
    *       For example, there can be an off-chain application/interface for this, like how Uniswap's DAO operates (Snapshot)
    * - While we implemented passive closure, for demo purposes we will include a function that can terminate voting and start the counting before the endTime is reached
    *
    * Future considerations:
    * - Should reviewers need to stake tokens to vote? 
    */

    // ===================================================== SCHEMA & STATE VARIABLES ===================================================== //
    enum Vote { APPROVE, REJECT }
    enum DisputeStatus { PENDING, APPROVED, REJECTED }

    struct Dispute {
        uint256 jobId;           
        uint256 endTime;         
        DisputeStatus status;    
        uint256 approveVotes;     
        uint256 rejectVotes;
    }

    User userContract;
    // JobListing jobListingContract;
    uint256 private disputeCount = 0;
    mapping(uint256 => Dispute) public disputes; // disputeID to dispute
    mapping(uint256 => bool) public isDisputed; // JobID to boolean to check to whether a dispute has been made (O(1))
    mapping(uint256 => mapping(uint256 => bool)) public hasVoted; // Keeps track of who has voted for a given dispute, disputeId -> userId -> bool

    constructor(address userAddress) public {
        userContract = User(userAddress);
        // jobListingContract = JobListing(jobListingAddress);
    }
    // ===================================================== SCHEMA & STATE VARIABLES ===================================================== //
    
    // ====================================================== EVENTS & MODIFIERS ========================================================== //
    event DisputeStarted(uint256 disputeId, uint256 jobId, uint256 endTime);
    event DisputeClosed(uint256 disputeId, DisputeStatus status);
    event voted(uint256 disputeId, uint256 userId, Vote voteChoice);

    modifier userIdMatches(uint256 userId) {
        require(userContract.getAddressFromUserId(userId) == msg.sender, "This userId does not correspond to yourself.");
        _;
    }

    modifier validDisputeId(uint256 disputeId) {
        require(disputeId > 0 && disputeId <= disputeCount, "Invalid dispute ID");
        _;
    }

    // ====================================================== EVENTS & MODIFIERS ========================================================== //


    // ============================================================== METHODS ============================================================= //

    /**
     * Start a new dispute.
     *
     * Considerations: (EXPOSE THIS FUNCTION TO JOBLISTING AND MOVE THESE CONSIDERATIONS THERE)
     * - You must be who you say you are (userId wise)
     * - The jobId must be valid
     * - The job must be in the completed status
     * - Only the client associated with the job can initiate a dispute
     * - The job must not have been disputed before
     */
    function startDispute(uint256 jobId) external {
        require(!isDisputed[jobId], "Job has already been disputed");

        disputeCount++;
        disputes[disputeCount] = Dispute({
            jobId: jobId,
            endTime: block.timestamp + 3 days,
            status: DisputeStatus.PENDING,
            approveVotes: 0,
            rejectVotes: 0
        });
        isDisputed[jobId] = true;
        emit DisputeStarted(disputeCount, jobId, disputes[jobId].endTime);
    }

    /**
     * Resolve an existing dispute.
     *
     * Considerations:
     * - Voting period must have ended
     * - The dispute should be in the PENDING status
     */
    function resolveDispute(uint256 disputeId) internal validDisputeId(disputeId) {
        Dispute storage dispute = disputes[disputeId];
        require(now > dispute.endTime, "Voting period has not ended.");
        require(dispute.status == DisputeStatus.PENDING, "Dispute already resolved.");

        if (dispute.approveVotes >= dispute.rejectVotes) {
            dispute.status = DisputeStatus.APPROVED;
            // RETURN A BOOLEAN TO JOB LISTING TO INSTRUCT IT TO REFUND THE CLIENT
            // pay voters
        } else {
            dispute.status = DisputeStatus.REJECTED;
            // RETURN A BOOLEAN TO JOB LISTING TO INSTRUCT IT TO PROCEED WITH PAYMENT
            // pay voters
        }

        // distributeTokensToVoters(jobId, dispute.status);
        emit DisputeClosed(disputeId, dispute.status);
    }

    /**
    * Vote on a dispute.
    *
    * Considerations:
    * - You must be who you say you are (userId wise) (move this to jobListing)
    * - You must be a reviewer (move this to jobListing)
    * - Reviewer can only vote once on a given dispute
    * - You cannot vote for a dispute where the client and freelancer is also yourself (move this to jobListing)
    */
    function vote(uint256 reviewerId, uint256 disputeId, Vote voteChoice) external validDisputeId(disputeId) userIdMatches(reviewerId) {
        require(disputes[disputeId].status == DisputeStatus.PENDING, "Dispute already resolved or does not exist.");
        require(userContract.isReviewer(reviewerId), "Only reviewers can review.");
        require(hasVoted[disputeId][reviewerId] == false, "Reviewer has already voted.");

        // If vote attempt is made after the endTime, resolve the dispute (passive closure)
        if (block.timestamp > disputes[disputeId].endTime) {
            resolveDispute(disputeId);
            return;
        }

        if (voteChoice == Vote.APPROVE) {
            disputes[disputeId].approveVotes += 1;
        } else if (voteChoice == Vote.REJECT) {
            disputes[disputeId].rejectVotes += 1;
        }
        
        hasVoted[disputeId][reviewerId] = true;
        emit voted(disputeId, reviewerId, voteChoice);
    }

    function distributeTokensToVoters(uint256 disputeId) internal {
        // Todo
    }
    // ============================================================== METHODS ============================================================= //
}
