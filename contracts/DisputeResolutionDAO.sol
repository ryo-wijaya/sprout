pragma solidity ^0.5.0;
import "./User.sol";
import "./JobListing.sol";
import "./Escrow.sol";

contract DisputeResolutionDAO {

    /*
    * Key variable definitions:
    * - x (The amount of tokens staked by the client) will be specified by the deployer in the Escrow contract
    * - y (The amount of tokens rewarded to each winning reviewer) will be specified by the deployer in the Escrow contract
    * - maxNumberOfWinners (The maximum number of reviewers that can be rewarded) will be specified by the deployer in this contract 
    *
    * Dispute resolution process:
    * - A dispute will always be started by the client.
    * - The client will need to pay (not stake) x tokens to start a dispute.
    * - Reviewers will take a look at the job details, the work done, and make a vote for the winning party
    * - The voting will end the at designated end time, which is 3 days by default (This is an arbitrarily picked number).
    * - Passive closure: If a vote is attempted after the endTime, the dispute will be closed automatically and counting will commence.
    *
    * Outcome:
    * - If the dispute get more or equal number of APPROVE votes vs REJECT, the dispute will be APPROVED.
    * - If the dispute is APPROVED, the client will get back the tokens held in escrow and whatever work has already been done by the client
    * - If the dispute is REJECTED, the freelancer will get the tokens held in escrow
    * - Either way, the staked tokens by the client will get distributed to the specified maxNumberOfWinners lucky reviewers who voted for the winning party
    *
    * Assumptions:
    * - When a dispute is made, the client and freelancer has an avenue to provide evidence and explanations of why the work done is acceptable/unacceptable
    *       For example, there can be an off-chain application/interface for this, like how Uniswap's DAO operates (Snapshot)
    * - While we implemented passive closure, for demo purposes we will include a function that can terminate voting and start the counting before the endTime is reached
    * - For demo purposes and mathematical simplicity, we will only reward up to the specified maxNumberOfWinners with the x amount of tokens tokens.
    *       If there are less than the specified maxNumberOfWinners reviewers, we will reward each reviewer y token each. The remaining tokens will be refunded to the client.
    */

    // ===================================================== SCHEMA & STATE VARIABLES ===================================================== //
    enum Vote { NONE, APPROVE, REJECT }
    enum DisputeStatus { PENDING, APPROVED, REJECTED }

    struct Dispute {
        uint256 jobId;
        uint256 paymentId; // paymentId in the Escrow contract
        uint256 endTime;
        DisputeStatus status;
        uint256 approveVotes;     
        uint256 rejectVotes;
    }

    User userContract;
    JobListing jobListingContract;
    Escrow escrowContract;

    uint256 public maxNumberOfWinners;

    uint256 private disputeCount = 0;
    mapping(uint256 => Dispute) public disputes; // disputeID to dispute
    mapping(uint256 => bool) public isDisputed; // JobID to boolean to check to whether a dispute has been made (O(1))
    mapping(uint256 => uint256[]) public disputeVoters; // keeps track of all voters IDs for a disputeId
    mapping(uint256 => mapping(uint256 => Vote)) public mapUserToVote; // disputeId -> userId -> Vote



    constructor(address userAddress, address jobListingAddress, address escrowAddress, uint256 _maxNumberOfWinners) public {
        userContract = User(userAddress);
        escrowContract = Escrow(escrowAddress);
        jobListingContract = JobListing(jobListingAddress);
        maxNumberOfWinners = _maxNumberOfWinners;
    }

    // ====================================================== EVENTS & MODIFIERS ========================================================== //
    event DisputeStarted(uint256 disputeId, uint256 jobId, uint256 endTime);
    event DisputeClosed(uint256 disputeId, DisputeStatus status);
    event voted(uint256 disputeId, uint256 userId, Vote voteChoice);

    modifier userIdMatches(uint256 userId) {
        require(userContract.getAddressFromUserId(userId) == msg.sender, "This userId does not correspond to yourself");
        _;
    }

    modifier validDisputeId(uint256 disputeId) {
        require(disputeId > 0 && disputeId <= disputeCount, "Invalid dispute ID");
        _;
    }


    // ============================================================== METHODS ============================================================= //

    /**
    * @dev Start a new dispute for a job.
    *
    * Considerations:
    * - The user calling must match the clientId.
    * - The jobId must be valid and the job must be in the completed status.
    * - Only the client associated with the job can initiate a dispute.
    * - The job must not have been disputed before.
    *
    * @param clientId The unique identifier of the client initiating the dispute.
    * @param jobId The unique identifier of the job associated with the dispute.
    */
    function startDispute(uint256 clientId, uint256 jobId) external userIdMatches(clientId) {
        require(jobListingContract.isValidJob(jobId), "Invalid Job ID");
        require(!isDisputed[jobId], "Job has already been disputed");
        require(jobListingContract.isJobCompleted(jobId), "Job is not in the completed status");
        require(jobListingContract.getJobClient(jobId) == clientId, "Only the client associated with the job can initiate a dispute");

        disputeCount++;
        disputes[disputeCount] = Dispute({
            jobId: jobId,
            paymentId: jobListingContract.getJobPaymentId(jobId),
            endTime: block.timestamp + 3 days,
            status: DisputeStatus.PENDING,
            approveVotes: 0,
            rejectVotes: 0
        });
        isDisputed[jobId] = true;
        emit DisputeStarted(disputeCount, jobId, disputes[jobId].endTime);
    }

    /**
     * @dev Resolve an existing dispute.
     * There are 2 ways this should be triggered in production:
     *      1. The endTime has passed, and the dispute is still in the PENDING status, and someone attempts a vote (passive closure)
     *      2. Some sort of CRON functionality provided by external services e.g. Ethereum Alarm Clock
     *
     * Considerations:
     * - Voting period must have ended
     * - The dispute should be in the PENDING status
    *
    * @param disputeId The unique identifier of the dispute to be resolved.
    */
    function resolveDispute(uint256 disputeId) internal validDisputeId(disputeId) {
        Dispute storage dispute = disputes[disputeId];
        require(now > dispute.endTime, "Voting period has not ended.");
        require(dispute.status == DisputeStatus.PENDING, "Dispute already resolved.");
        Vote winningVote;

        if (dispute.approveVotes >= dispute.rejectVotes) {
            dispute.status = DisputeStatus.APPROVED;
            winningVote = Vote.APPROVE;
            // Escrow refunds the client the job rewards, but keeps the client's x staked tokens for distribution to voters later 
            escrowContract.refundPayment(dispute.paymentId);
        } else {
            dispute.status = DisputeStatus.REJECTED;
            winningVote = Vote.REJECT;
            // Escrow pays freelancer what they're owed, but keeps the client's x staked tokens for distribution to voters later 
            escrowContract.confirmDelivery(dispute.paymentId, false);
        }

        distributeTokensToVoters(disputeId, winningVote);
        emit DisputeClosed(disputeId, dispute.status);
    }

    /**
    * @dev Vote on a dispute as a reviewer.
    *
    * Considerations:
    * - The user calling must match the reviewerId.
    * - Reviewers can only vote once on a given dispute.
    * - Reviewers cannot vote for a dispute where they are the client or freelancer involved.
    * - Dispute must be in the PENDING status.
    *
    * @param reviewerId The unique identifier of the reviewer casting the vote.
    * @param disputeId The unique identifier of the dispute being voted on.
    * @param voteChoice The vote choice (APPROVE or REJECT) cast by the reviewer.
    */
    function vote(uint256 reviewerId, uint256 disputeId, Vote voteChoice) external validDisputeId(disputeId) userIdMatches(reviewerId) {
        Dispute storage dispute = disputes[disputeId];

        require(disputes[disputeId].status == DisputeStatus.PENDING, "Dispute already resolved or does not exist.");
        require(userContract.isReviewer(reviewerId), "Only reviewers can review.");
        require(mapUserToVote[disputeId][reviewerId] == Vote.NONE, "Reviewer has already voted");
        require(!userContract.haveSameAddress(jobListingContract.getJobFreelancer(dispute.jobId), reviewerId), "You are the freelancer for this job, you can't vote on your own job.");
        require(!userContract.haveSameAddress(jobListingContract.getJobClient(dispute.jobId), reviewerId), "You are the client for this job, you can't vote on your own job.");

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

    /**
    * @dev Distribute tokens to voters after a dispute resolution.
    *
    * Considerations:
    * - The dispute must be resolved (either APPROVED or REJECTED).
    * - Tokens are distributed to voters for the winning side, up to the maxNumberOfWinners.
    * - If there are fewer winning voters than the maxNumberOfWinners, each will receive y tokens.
    * - Any remaining tokens are refunded to the client.
    *
    * @param disputeId The unique identifier of the resolved dispute.
    * @param winningVote The winning vote (APPROVE or REJECT) in the dispute.
    */
    function distributeTokensToVoters(uint256 disputeId, Vote winningVote) internal {
        // If there are more than the specified maxNumberOfWinners of the winning majority, we will randomly pick the specified maxNumberOfWinners of them. (y tokens each)
        // If there are less than the specified maxNumberOfWinners of the winning majority, we will distribute y tokens each to them. The rest will be refunded to the client.
        Dispute storage dispute = disputes[disputeId];
        require(dispute.status == DisputeStatus.APPROVED || dispute.status == DisputeStatus.REJECTED, "Dispute is not resolved.");

        // Count votes, store it in a list
        uint256[] memory winningVoters = new uint256[](disputeVoters[disputeId].length);
        uint256 counter = 0;

        // Loop through all the voters, and add the ones that voted for the winning party to the winningVoters array
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

        // Randomly distribute tokens to up to the specified maxNumberOfWinners IF there are more than the specified maxNumberOfWinners, else just distribute to the winning voters
        uint256 rewardsCount = counter > maxNumberOfWinners ? maxNumberOfWinners : counter;
        if (rewardsCount <= maxNumberOfWinners) {
            // Less than maxNumberOfWinners winning voters
            for (uint256 i = 0; i < rewardsCount; i++) {
                uint256 selectedVoterId = winningVoters[i];
                // Pay the voter y tokens
                escrowContract.rewardVoter(dispute.paymentId, userContract.getAddressFromUserId(selectedVoterId));
            }

            // Refund remaining tokens to the client, in the event that there are not enough winning voters
            escrowContract.refundTokenBalance(dispute.paymentId);
            

        } else {
            // If more than the specified maxNumberOfWinners, randomly pick the specified maxNumberOfWinners from the winning pool
            bool[] memory rewarded = new bool[](counter); 

            // Randomly pick the specified maxNumberOfWinners from the winning pool
            for (uint256 i = 0; i < maxNumberOfWinners; i++) {
                uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, i))) % counter;

                // Don't reward the same voter twice
                while (rewarded[randomIndex]) {
                    randomIndex = (randomIndex + 1) % counter;
                }
                
                rewarded[randomIndex] = true;
                uint256 selectedVoterId = winningVoters[randomIndex];
                // Pay the voter y tokens
                escrowContract.rewardVoter(dispute.paymentId, userContract.getAddressFromUserId(selectedVoterId));
            }
        }
    }

    /**
    * @dev Manually end voting on a dispute. This function is for demo purposes and should not exist in production.
    *
    * @param disputeId The unique identifier of the dispute to end voting on.
    */
    function manuallyTriggerEndVoting(uint256 disputeId) external validDisputeId(disputeId) {
        Dispute storage dispute = disputes[disputeId];
        // Set the endTime to a past timestamp to circumvent the require statement in the thing
        dispute.endTime = block.timestamp - 1;
        resolveDispute(disputeId);
    }
}
