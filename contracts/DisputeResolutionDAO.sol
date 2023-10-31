pragma solidity ^0.5.0;
import "./User.sol";
import "./JobListing.sol";
import "./Escrow.sol";

contract DisputeResolutionDAO {

    /*
    * This contract will be referenced by the JobListing contract. This is to make it easier to do job related checks and handle escrow management at a single place

    * Dispute resolution process:
    * - A dispute will always be started by the client.
    * - The client will need to pay (not stake) 10 tokens to start a dispute.
    * - Reviewers will take a look at the job details, the work done, and make a vote for the winning party
    * - The voting will end the at designated end time, which is 3 days by default (This is an arbitrarily picked number).
    * - Passive closure: If a vote is attempted after the endTime, the dispute will be closed automatically and counting will commence.
    *
    * Outcome:
    * - If the dispute get more or equal number of APPROVE votes vs REJECT, the dispute will be APPROVED.
    * - If the dispute is APPROVED, the client will get back the tokens held in escrow and whatever work has already been done by the client
    * - If the dispute is REJECTED, the freelancer will get the tokens held in escrow
    * - Either way, the staked tokens by the client will get distributed to the 10 lucky reviewers who voted for the winning party
    *
    * Assumptions:
    * - When a dispute is made, the client and freelancer has an avenue to provide evidence and explanations of why the work done is acceptable/unacceptable
    *       For example, there can be an off-chain application/interface for this, like how Uniswap's DAO operates (Snapshot)
    * - While we implemented passive closure, for demo purposes we will include a function that can terminate voting and start the counting before the endTime is reached
    * - For demo purposes and mathematical simplicity, we will only reward up to 10 random reviewers with the 10 tokens.
    *       If there are less than 10 reviewers, we will reward each reviewer 1 token each. The remaining tokens will be refunded to the client.
    *
    * Future considerations:
    * - Should reviewers need to stake tokens to vote? 
    */

    // ===================================================== SCHEMA & STATE VARIABLES ===================================================== //
    enum Vote { NONE, APPROVE, REJECT }
    enum DisputeStatus { PENDING, APPROVED, REJECTED }

    struct Dispute {
        uint256 jobId;           
        uint256 endTime;         
        DisputeStatus status;    
        uint256 approveVotes;     
        uint256 rejectVotes;
    }

    User userContract;
    JobListing jobListingContract;
    Escrow escrowContract;

    uint256 private disputeCount = 0;
    mapping(uint256 => Dispute) public disputes; // disputeID to dispute
    mapping(uint256 => bool) public isDisputed; // JobID to boolean to check to whether a dispute has been made (O(1))
    mapping(uint256 => uint256[]) public disputeVoters; // keeps track of all voters IDs for a disputeId
    mapping(uint256 => mapping(uint256 => Vote)) public mapUserToVote; // disputeId -> userId -> Vote



    constructor(address userAddress, address jobListingAddress, address escrowAddress) public {
        userContract = User(userAddress);
        escrowContract = Escrow(escrowAddress);
        jobListingContract = JobListing(jobListingAddress);
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
     * Considerations:
     * - You must be who you say you are (userId wise)
     * - The jobId must be valid
     * - The job must be in the completed status
     * - Only the client associated with the job can initiate a dispute
     * - The job must not have been disputed before
     */
    function startDispute(uint256 clientId, uint256 jobId) external userIdMatches(clientId) {
        require(jobListingContract.isValidJob(jobId), "Invalid jobId");
        require(!isDisputed[jobId], "Job has already been disputed");
        require(jobListingContract.getJobStatus(jobId) == JobListingContract.JobStatus.COMPLETED, "Job is not in the completed status");
        require(jobListingContract.getJobClient(jobId) == clientId, "Only the client associated with the job can initiate a dispute");

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
        Vote winningVote;

        if (dispute.approveVotes >= dispute.rejectVotes) {
            dispute.status = DisputeStatus.APPROVED;
            winningVote = Vote.APPROVE;
            // TODO: Escrow refund client
        } else {
            dispute.status = DisputeStatus.REJECTED;
            winningVote = Vote.REJECT;
            // TODO: Escrow pay freelancer
        }

        distributeTokensToVoters(disputeId, winningVote);
        emit DisputeClosed(disputeId, dispute.status);
    }

    /**
    * Vote on a dispute.
    *
    * Considerations:
    * - You must be who you say you are (userId wise) 
    * - You must be a reviewer 
    * - Reviewer can only vote once on a given dispute
    * - You cannot vote for a dispute where the client and freelancer is also yourself
    */
    function vote(uint256 reviewerId, uint256 disputeId, Vote voteChoice) external validDisputeId(disputeId) userIdMatches(reviewerId) {
        Dispute storage dispute = disputes[disputeId];

        require(disputes[disputeId].status == DisputeStatus.PENDING, "Dispute already resolved or does not exist.");
        require(userContract.isReviewer(reviewerId), "Only reviewers can review.");
        require(mapUserToVote[disputeId][reviewerId] == Vote.NONE, "Reviewer has already voted");
        require(!userContract.haveSameAddress(jobListingContract.getFreelancer(dispute.jobId), reviewerId), "You are the freelancer for this job, you can't vote on your own job.");
        require(!userContract.haveSameAddress(jobListingContract.getClient(dispute.jobId), reviewerId), "You are the client for this job, you can't vote on your own job.");

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

        mapUserToVote[disputeId][reviewerId] = voteChoice;
        disputeVoters[disputeId].push(reviewerId);
        emit voted(disputeId, reviewerId, voteChoice);
    }

    function distributeTokensToVoters(uint256 disputeId, Vote winningVote) internal {
        // Todo: Escrow distributes tokens to voters for 10 lucky reviewers of the winning majority.
        // If there are more than 10 reviewers of the winning majority, we will randomly pick 10 of them. (1 token each)
        // If there are less than 10 reviewers of the winning majority, we will distribute 1 token each to them. The rest will be refunded to the client.
        Dispute storage dispute = disputes[disputeId];
        require(dispute.status == DisputeStatus.APPROVED || dispute.status == DisputeStatus.REJECTED, "Dispute is not resolved.");

        // Count votes, store it in a list
        uint256[] memory winningVoters = new uint256[](disputeVoters[disputeId].length);
        uint256 counter = 0;

        for (uint256 i = 0; i < disputeVoters[disputeId].length; i++) {
            uint256 userId = disputeVoters[disputeId][i];
            Vote userVote = mapUserToVote[disputeId][userId];
            if (userVote != Vote.NONE) {
                if ((winningVote == Vote.APPROVE && userVote == Vote.APPROVE) ||
                    (winningVote == Vote.REJECT && userVote == Vote.REJECT)) {
       
                    // Add the user ID to the winningVoters array
                    winningVoters[counter] = userId;
                    counter++;
                }
            }
        }

        // Randomly distribute tokens to up to 10 voters IF there are more than 10, else just distribute to the winning voters
        uint256 rewardsCount = counter > 10 ? 10 : counter;
        if (rewardsCount <= 10) {
            // Less than 10 winning voters
            for (uint256 i = 0; i < rewardsCount; i++) {
                uint256 selectedVoterId = winningVoters[i];
                // TODO: Escrow: Transfer 1 token to the dude
            }

            uint256 refundAmount = 10 - rewardsCount;
            // TODO: Escrow: Refund remaining tokens to client

        } else {
            // If more than 10 voters, randomly pick 10 lucky winners lmao
            bool[] memory rewarded = new bool[](counter); 

            for (uint256 i = 0; i < 10; i++) {
                uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, i))) % counter;

                // Don't reward the same voter twice
                while (rewarded[randomIndex]) {
                    randomIndex = (randomIndex + 1) % counter;
                }
                
                rewarded[randomIndex] = true;
                uint256 selectedVoterId = winningVoters[randomIndex];
                // TODO: Escrow: Transfer 1 token to the chosen one
            }
        }
    }


    // This function should not exist in production, but is here for demo purposes
    function manuallyTriggerEndVoting(uint256 disputeId) external validDisputeId(disputeId) {
        Dispute storage dispute = disputes[disputeId];
        // Set the endTime to a past timestamp to circumvent the require statement in the thing
        dispute.endTime = block.timestamp - 1;
        resolveDispute(disputeId);
    }
    // ============================================================== METHODS ============================================================= //
}
