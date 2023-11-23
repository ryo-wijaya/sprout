pragma solidity ^0.5.0;

import "./SproutToken.sol";
import "./User.sol";
import "./JobListing.sol";

contract Escrow {

    // ===================================================== SCHEMA & STATE VARIABLES ===================================================== //

    /*
    * AWAITING_PAYMENT: The client has transferred the job reward to the escrow contract, and is awaiting freelancer job completion
    * COMPLETE: This is a happy path. The freelancer has completed the job and the client has confirmed delivery of the job, and the job reward has been transferred to the freelancer
    * PARTIALLY_REFUNDED: There is a dispute, the job reward has been refunded to the client or freelancer depending on its result, but the staked dispute tokens are kept
    * REFUNDED: There is a dispute, but the escrow holds 0 balance. All relevant parties (client, freelancer, reviewers) have been paid out
    */
    enum EscrowStatus { AWAITING_PAYMENT, COMPLETE, PARTIALLY_REFUNDED, REFUNDED }

    struct Payment {
        uint256 clientId;
        uint256 freelancerId;
        uint256 jobId;
        uint256 amount;
        uint256 balance;
        EscrowStatus status;
    }

    // The number of tokens client must stake in the potential event of a dispute (business rule)
    uint256 public stakedTokens;
    // The number of tokens each voter gets as a reward for voting (business rule)
    uint256 public eachVoterReward;

    uint256 public numPayments = 0;
    SproutToken sproutTokenContract;
    User public userContract; // Reference to the User Contract
    mapping(uint256 => Payment) public payments;

    constructor(address _userContract, address _nativeTokenContract, uint256 _stakedTokens, uint256 _eachVoterReward) public {
        userContract = User(_userContract); // The userclass of this address, only clients should be able to pay
        nativeTokenContract = NativeToken(_nativeTokenContract);

        // Set staked tokens and voter reward values as specified by the deployer
        stakedTokens = _stakedTokens;
        eachVoterReward = _eachVoterReward;
    }

    // ====================================================== EVENTS & MODIFIERS ========================================================== //

    event PaymentInitiated(uint256 _paymentId, uint256 _jobId, uint256 _freelancerId, uint256 _clientId, uint256 _amount);
    event PaymentComplete(uint256 _paymentId);
    event PaymentPartiallyRefunded(uint256 _paymentId); // This means the escrow balance is not yet 0
    event PaymentRefunded(uint256 _paymentId);
    event VoterReward(uint256 _paymentId, address voterAddress);

    // Check that the freelancer and client came from different address
    modifier differentAddresses(uint256 _freelancerId, uint256 _clientId) {
        require(userContract.getAddressFromUserId(_freelancerId) != userContract.getAddressFromUserId(_clientId), "Two different address must be used");
        _;
    }

    // Check that the payment ID exist
    modifier validPaymentId(uint256 _paymentId) {
        require(_paymentId <= numPayments, "Invalid payment ID");
        _;
    }

    // Check that person calling function is indeed a client
    modifier isClient(uint256 _clientId) {
        require(userContract.isClient(_clientId), "Only client can call function.");
        _;
    }
    
    // Check that person calling function is indeed a freelancer
    modifier isFreelancer(uint256 _freelancerId) {
        require(userContract.isFreelancer(_freelancerId), "Must be payed to a freelancer");
        _;
    }

    // ============================================================== METHODS ============================================================= //
    /**
        * Function for a client to initiate the payment process with a freelancer when the Job starts (Ongoing status)
        * SproutToken is transferred to the Escrow Contract
        *
        * Considerations:
        * - The freelancer and client must be of different addresses
        * - The freelancerId/clientId must be a freelancer/client
        * - The client must have enough SproutTokens
        * - The job must be in Ongoing status (already checked in the caller)
    */
    function initiatePayment(uint256 _clientId, uint256 _freelancerId, uint256 _jobId, uint256 _amount) public payable differentAddresses(_freelancerId, _clientId) isClient(_clientId) isFreelancer(_freelancerId) returns (uint256) {
        address clientAddress = userContract.getAddressFromUserId(_clientId);
        
        //Check that client does indeed have amount he wants to give
        require(nativeTokenContract.checkCredit(clientAddress) >= _amount, "You do not have enough tokens to pay the reward + staked tokens (in the event of a dispute)");

        numPayments++;

        Payment storage payment = payments[numPayments];
        payment.clientId = _clientId;
        payment.freelancerId = _freelancerId;
        payment.jobId = _jobId;
        payment.amount = _amount;
        payment.balance = _amount;
        payment.status = EscrowStatus.AWAITING_PAYMENT;

        //Client sends payment to Escrow
        nativeTokenContract.transferCredit(address(this), _amount);

        nativeTokenContract.approve(address(this), _amount);

        emit PaymentInitiated(numPayments, _jobId, _freelancerId, _clientId, _amount);

        return numPayments;
    }


    /**
        * Function for the NativeTokens to be transferred to the Freelancer on completion of Job, with the option to be with or without the staked tokens
        *
        * Considerations:
        * - The payment status must be AWAITING_PAYMENT
        * - The job must be COMPLETED (already checked by the jobListing contract)
    */
    function confirmDelivery(uint256 _paymentId, bool withStakedTokens) public payable validPaymentId(_paymentId) {
        Payment storage payment = payments[_paymentId];

        require(payment.status == EscrowStatus.AWAITING_PAYMENT, "Invalid payment status");

        // Pay the freelancer
        nativeTokenContract.transferFrom(address(this), userContract.getAddressFromUserId(payment.freelancerId), payment.amount - stakedTokens);

        if (withStakedTokens) {
            // Refund staked tokens to the client, empty balance and mark as delivered
            nativeTokenContract.transferFrom(address(this), userContract.getAddressFromUserId(payment.clientId), stakedTokens);
            payment.balance = 0;
            payment.status = EscrowStatus.COMPLETE;
            emit PaymentComplete(_paymentId);
        } else {
            // Do not refund staked tokens to the client, mark as partially refunded, awaiting distribution of staked tokens to voters
            payment.balance = stakedTokens;
            payment.status = EscrowStatus.PARTIALLY_REFUNDED;
            emit PaymentPartiallyRefunded(_paymentId);
        }
    }


    /**
        * Function for the SproutTokens to be refunded to the client minus the staked tokens
        *
        * Considerations:
        * - The payment status must be AWAITING_PAYMENT
        * - The msg.sender must be the client of the particular payment
        * - The job cannot be COMPLETED (already checked by the jobListing contract)
    */
    function refundPayment(uint256 _paymentId) public validPaymentId(_paymentId) {
        Payment storage payment = payments[_paymentId];
        require(payment.status == EscrowStatus.AWAITING_PAYMENT, "Invalid payment status");

        nativeTokenContract.transferFrom(address(this), userContract.getAddressFromUserId(payment.clientId), payment.amount - stakedTokens);
        payment.balance = stakedTokens;
        payment.status = EscrowStatus.PARTIALLY_REFUNDED;
        emit PaymentPartiallyRefunded(_paymentId);
    }

    /**
    * @dev Rewards a voter who participated in a dispute resolution process.
    *
    * This function is called to distribute rewards to voters who voted in the winning majority
    * in a dispute resolution process. Each voter receives a predefined number of tokens as a reward.
    *
    * Considerations:
    * - The function can only be called for payments that are in the PARTIALLY_REFUNDED status.
    * - The payment must have enough balance to cover the voter reward.
    * - The balance of the payment is decremented by the reward amount for each voter.
    *
    * @param _paymentId The ID of the escrow payment associated with the job in dispute.
    * @param voterAddress The address of the voter receiving the reward.
    */
    function rewardVoter(uint256 _paymentId, address voterAddress) public validPaymentId(_paymentId) {
        Payment storage payment = payments[_paymentId];
        require(payment.status == EscrowStatus.PARTIALLY_REFUNDED, "Invalid payment status");

        if (payment.balance >= eachVoterReward) {
            nativeTokenContract.transferFrom(address(this), voterAddress, eachVoterReward);
            payment.balance--;
            emit VoterReward(_paymentId, voterAddress);
        }
    }

    /**
    * @dev Refunds the remaining token balance to the client after dispute resolution.
    *
    * This function is used to refund the leftover tokens in the escrow (if any) to the client
    * after the dispute resolution process. This typically happens when fewer than 10 reviewers have
    * voted, leaving some of the staked tokens unallocated.
    *
    * Considerations:
    * - The function can only be called for payments that are in the PARTIALLY_REFUNDED status.
    * - The entire remaining balance of the payment is refunded to the client.
    * - After the refund, the payment status is changed to REFUNDED.
    *
    * @param _paymentId The ID of the escrow payment for which the remaining balance is to be refunded.
    */
    function refundTokenBalance(uint256 _paymentId) public validPaymentId(_paymentId) {
        Payment storage payment = payments[_paymentId];
        require(payment.status == EscrowStatus.PARTIALLY_REFUNDED, "Invalid payment status");

        if (payment.balance > 0) {
            nativeTokenContract.transferFrom(address(this), userContract.getAddressFromUserId(payment.clientId), payment.balance);
            payment.balance = 0;
        }

        payment.status = EscrowStatus.REFUNDED;
        emit PaymentRefunded(_paymentId);
    }

    // Getter functions    
    function getClientId(uint256 _paymentId) public view returns (uint256) {
        return payments[_paymentId].clientId;
    }

    function getFreelancerId(uint256 _paymentId) public view returns (uint256) {
        return payments[_paymentId].freelancerId;
    }

    function getJobId(uint256 _paymentId) public view returns (uint256) {
        return payments[_paymentId].jobId;
    }

    function getBalance(uint256 _paymentId) public view returns (uint256) {
        return payments[_paymentId].balance;
    }

    function getCurrentStatus(uint256 _paymentId) public view returns (EscrowStatus) {
        return payments[_paymentId].status;
    }

}
