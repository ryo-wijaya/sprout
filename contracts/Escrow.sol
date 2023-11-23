pragma solidity ^0.5.0;

import "./SproutToken.sol";
import "./User.sol";
import "./JobListing.sol";

contract Escrow {

    // ===================================================== SCHEMA & STATE VARIABLES ===================================================== //

    enum EscrowStatus { AWAITING_PAYMENT, COMPLETE, REFUNDED }

    struct Payment {
        uint256 clientId;
        uint256 freelancerId;
        uint256 jobId;
        uint256 amount;
        EscrowStatus status;
    }

    uint256 public numPayments = 0;
    SproutToken sproutTokenContract;
    User public userContract; // Reference to the User Contract
    JobListing public jobContract; // Reference to the Job Contract
    mapping(uint256 => Payment) public payments;

    constructor(address _userContract, address _sproutTokenContract, address _jobContract) public {
        userContract = User(_userContract); // The userclass of this address, only clients should be able to pay
        sproutTokenContract = SproutToken(_sproutTokenContract);
        jobContract = JobListing(_jobContract);
    }

    // ====================================================== EVENTS & MODIFIERS ========================================================== //

    event PaymentInitiated(uint256 _paymentId, uint256 _jobId, uint256 _freelancerId, uint256 _clientId, uint256 _amount);
    event PaymentComplete(uint256 _paymentId);
    event PaymentRefunded(uint256 _paymentId);

    // Check that the freelancer and client came from different address
    modifier differentAddresses(uint256 _freelancerId, uint256 _clientId) {
        require(userContract.getAddressFromUserId(_freelancerId) != userContract.getAddressFromUserId(_clientId), "Two different address must be used");
        _;
    }

    // Check that the payment ID exist
    modifier validPaymentId(uint256 _paymentId) {
        require(_paymentId < numPayments, "Invalid payment ID");
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
        * - The job must be in Ongoing status
    */
    function initiatePayment(uint256 _clientId, uint256 _freelancerId, uint256 _jobId, uint256 _amount) public payable differentAddresses(_freelancerId, _clientId) isClient(_clientId) isFreelancer(_freelancerId) {
        //Check that client does indeed have amount he wants to give
        require(sproutTokenContract.checkCredit(msg.sender) >= _amount, "Client does not have enough tokens for payment");
        require(jobContract.isJobOngoing(_jobId), "Job is currently not in Ongoing status.");

        Payment storage payment = payments[numPayments];
        payment.clientId = _clientId;
        payment.freelancerId = _freelancerId;
        payment.jobId = _jobId;
        payment.amount = _amount;
        payment.status = EscrowStatus.AWAITING_PAYMENT;

        //Client sends payment to Escrow contract
        sproutTokenContract.transferCredit(address(this), _amount);

        sproutTokenContract.approve(msg.sender, _amount);

        emit PaymentInitiated(numPayments, _jobId, _freelancerId, _clientId, _amount);

        numPayments++;
    }


    /**
        * Function for the SproutTokens to be transferred to the Freelancer on completion of Job
        * SproutToken is transferred to the Freelancer
        *
        * Considerations:
        * - The payment status must be AWAITING_PAYMENT
        * - The msg.sender must be the client of the particular payment
        * - The job must be COMPLETED
    */
    function confirmDelivery(uint256 _paymentId) public payable validPaymentId(_paymentId) {
        Payment storage payment = payments[_paymentId];

        require(payment.status == EscrowStatus.AWAITING_PAYMENT, "Invalid payment status");
        require(msg.sender == userContract.getAddressFromUserId(payment.clientId), "Invalid client sending");
        require(jobContract.isJobClosed(payment.jobId), "Job has not been completed yet");

        //Client confirms delivery
        payment.status = EscrowStatus.COMPLETE;
        sproutTokenContract.transferFrom(address(this), userContract.getAddressFromUserId(payment.freelancerId), payment.amount);

        //Client cannot take more money out of contract
        sproutTokenContract.approve(msg.sender, 0);
        emit PaymentComplete(_paymentId);
    }


    /**
        * Function for the SproutTokens to be refunded --> Does this depend on any disputes?
        *
        * Considerations:
        * - The payment status must be AWAITING_PAYMENT
        * - The msg.sender must be the client of the particular payment
        * - The job cannot be COMPLETED
    */
    function refundPayment(uint256 _paymentId) public validPaymentId(_paymentId) {
        Payment storage payment = payments[_paymentId];
        require(payment.status == EscrowStatus.AWAITING_PAYMENT, "Invalid payment status");
        require(jobContract.isJobClosed(payment.jobId) != true, "Job cannot be completed");
        //With my current code only the client can refund payment
        //cause only client approved to take money out of the escrow contract
        sproutTokenContract.transferFrom(address(this), userContract.getAddressFromUserId(payment.clientId), payment.amount);
        // does this depend on the DAO contract? 
        payment.status = EscrowStatus.REFUNDED;

        //Client cannot take more money out of contract
        sproutTokenContract.approve(msg.sender, 0);
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

    function getAmount(uint256 _paymentId) public view returns (uint256) {
        return payments[_paymentId].amount;
    }

    function getCurrentStatus(uint256 _paymentId) public view returns (EscrowStatus) {
        return payments[_paymentId].status;
    }

}
