pragma solidity ^0.5.0;

import "./NativeToken.sol";
import "./User.sol";

contract Escrow {

    enum EscrowStatus { AWAITING_PAYMENT, AWAITING_DELIVERY, COMPLETE, REFUNDED }

    struct Payment {
        address client;
        address freelancer;
        uint256 amount;
        EscrowStatus status;
    }

    uint256 public numPayments = 0;
    NativeToken nativeTokenContract;
    User public userContract;
    mapping(uint256 => Payment) public payments;


    // Events for Payments
    event PaymentInitiated(uint256 _paymentId, address _freelancer, address _client, uint256 amount);
    event PaymentComplete(uint256 _paymentId);
    event PaymentRefunded(uint256 _paymentId);

    // Modifier to prevent sending to the same address 
    modifier differentAddresses(address _freelancer, address _client) {
        require(_freelancer != _client, "Both addresses must be different.");
        _;
    }

    modifier validPaymentId(uint256 _paymentId) {
        require(_paymentId < numPayments, "Invalid payment ID");
        _;
    }

    //Check that person calling function is indeed a client
    modifier isClient(User userContract) {
        require(userContract.isClient(userId), "Only client can call function.");
        _;
    }

    constructor(address _userAddress, address _nativeTokenAddress) public {
        userContract = User(_userAddress); //The userclass of this address, only clients should be able to pay
        nativeTokenContract = nativeTokenAddress;
    }

    function initiatePayment(address _freelancer, uint256 _amount) public payable differentAddresses(_freelancer, msg.sender) isClient(userContract) {
        //require(msg.value == _amount, "Sent ether does not match the specified amount");
        //Need check the payment to be equivalent to reward claimed in job listing

        //Check that client does indeed have amount he wants to give
        require(nativeTokenContract.checkCredit(msg.sender) >= _amount, "Client does not have enough tokens for payment")
        require(_freelancer != address(0), "Freelancer address cannot be 0");
        
        uint256 paymentId = numPayments;
        Payment storage payment = payments[numPayments];
        payment.client = msg.sender;
        payment.freelancer = _freelancer;
        payment.amount = _amount;
        payment.status = EscrowStatus.AWAITING_PAYMENT;
        //Client sends payment to Escrow contract
        nativeTokenContract.transferCredit(address(this), _amount);
        //Currently I have to allow the client to be able to spend on behalf of escrow
        // in order for client to use the confirmDelivery function later on, if there's
        // a better idea please edit cause this weird.
        nativeTokenContract.approve(msg.sender, _amount);

        emit PaymentInitiated(paymentId, payment.freelancer, payment.client, payment.amount);

        numPayments++;
    }

    function confirmDelivery(uint256 _paymentId) public validPaymentId(_paymentId) isClient(userContract) {
        Payment storage payment = payments[_paymentId];
        require(payment.status == EscrowStatus.AWAITING_PAYMENT, "Invalid payment status");
        require(msg.sender == payment.client, "Invalid client sending");

        //Client confirms delivery
        payment.status = EscrowStatus.COMPLETE;
        nativeTokenContract.transferFrom(address(this), payment.freelancer, payment.amount);
        //Client cannot take more money out of contract
        nativeTokenContract.approve(msg.sender, 0);
        emit PaymentComplete(_paymentId);
    }

    function refundPayment(uint256 _paymentId) public validPaymentId(_paymentId) isClient(userContract) {
        Payment storage payment = payments[_paymentId];
        require(payment.status == EscrowStatus.AWAITING_PAYMENT, "Invalid payment status");
        
        //With my current code only the client can refund payment
        //cause only client approved to take money out of the escrow contract
        payment.status = EscrowStatus.REFUNDED;
        nativeTokenContract.transferFrom(address(this), payment.client, payment.amount);
        //Client cannot take more money out of contract
        nativeTokenContract.approve(msg.sender, 0);
        emit PaymentRefunded(_paymentId);
    }


    // Getter functions
    function getClientAddress(uint256 _paymentId) public view returns (address) {
        return payments[_paymentId].client;
    }

    function getFreelancerAddress(uint256 _paymentId) public view returns (address) {
        return payments[_paymentId].freelancer;
    }

    function getAmount(uint256 _paymentId) public view returns (uint256) {
        return payments[_paymentId].amount;
    }

    function getCurrentStatus(uint256 _paymentId) public view returns (EscrowStatus) {
        return payments[_paymentId].status;
    }
    

}
