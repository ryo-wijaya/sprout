pragma solidity ^0.5.0;

contract Escrow {

    enum EscrowStatus { AWAITING_PAYMENT, AWAITING_DELIVERY, COMPLETE, REFUNDED }

    struct Payment {
        address client;
        address freelancer;
        uint256 amount;
        EscrowStatus status;
    }

    uint256 public numPayments = 0;
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
    

    function initiatePayment(address _freelancer, uint256 _amount) public payable differentAddresses(_freelancer, msg.sender) {
        require(msg.value == _amount, "Sent ether does not match the specified amount");
        require(_freelancer != address(0), "Freelancer address cannot be 0");
        
        uint256 paymentId = numPayments;
        Payment storage payment = payments[numPayments];
        payment.client = msg.sender;
        payment.freelancer = _freelancer;
        payment.amount = _amount;
        payment.status = EscrowStatus.AWAITING_PAYMENT;

        emit PaymentInitiated(paymentId, payment.freelancer, payment.client, payment.amount);

        numPayments++;
    }

    function confirmDelivery(uint256 _paymentId) public validPaymentId(_paymentId) {
        Payment storage payment = payments[_paymentId];
        require(payment.status == EscrowStatus.AWAITING_PAYMENT, "Invalid payment status");
        require(msg.sender == payment.client, "Invalid client sending");
        
        address payable freelancer = address(uint160(payment.freelancer));
        freelancer.transfer(payment.amount);
        payment.status = EscrowStatus.COMPLETE;
        
        emit PaymentComplete(_paymentId);
    }

    function refundPayment(uint256 _paymentId) public validPaymentId(_paymentId) {
        Payment storage payment = payments[_paymentId];
        require(payment.status == EscrowStatus.AWAITING_PAYMENT, "Invalid payment status");

        address payable client = address(uint160(payment.client));
        client.transfer(payment.amount);
        payment.status = EscrowStatus.REFUNDED;

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
