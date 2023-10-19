pragma solidity ^0.5.0;

contract Escrow {

    enum EscrowStatus { AWAITING_PAYMENT, AWAITING_DELIVERY, COMPLETE, REFUNDED } // r we doing refunds

    struct Payment {
        uint256 clientId;
        uint256 freelancerId;
        uint256 amount;
        EscrowStatus status;
    }

    uint256 public paymentCount = 0;
    mapping(uint256 => Payment) public payments;

    // Constructor with both freelancer's and client's ID

    function initiatePayment(address freelancerId, uint256 amount) public payable {
        // stub
    }

    function confirmDelivery(uint256 paymentId) public {
        // stub
    }

    function refundPayment(uint256 paymentId) public {
        // stub
    }
}
