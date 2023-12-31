pragma solidity ^0.5.0;

import "./ERC20.sol";

// As a future work, we can include a function to allow users to exchange NT for ETH, taking a very small commission fee to discourage spam.

contract SproutToken {
    ERC20 erc20Contract;
    address owner;

    constructor() public {
        ERC20 e = new ERC20();
        erc20Contract = e;
        owner = msg.sender;
    }

    /**
    * @dev Function to give NT (SproutToken) to the recipient for a given wei amount
    *
    * @param recipient address of the recipient that wants to buy the NT
    * @param weiAmt uint256 amount indicating the amount of wei that was passed
    * @return uint256 representing the amount of NT bought by the msg.sender.
    */
    function getCredit(address recipient, uint256 weiAmt)
        public
        returns (uint256)
    {
        uint256 amt = weiAmt / (1000000000000000000/100); // Convert weiAmt to SproutToken
        erc20Contract.mint(recipient, amt);
        return amt;
    }
    /**
    * @dev Function to check the amount of NT (SproutToken) the msg.sender has
    *
    * @param ad address of the recipient that wants to check their NT
    * @return uint256 representing the amount of NT owned by the msg.sender.
    */
    function checkCredit(address ad) public view returns (uint256) {
        uint256 credit = erc20Contract.balanceOf(ad);
        return credit;
    }
    /**
    * @dev Function to transfer the credits from the owner to the recipient
    *
    * @param recipient address of the recipient that will gain in NT
    * @param amt uint256 amount of NT to transfer
    */
    function transferCredit(address recipient, uint256 amt) public {
        // Transfers from tx.origin to receipient
        erc20Contract.transfer(recipient, amt);
    }
    
    /**
    * @dev Function to transfer NT (SproutToken) from one address to another.
    *
    * @param from Address from which NT is being transferred.
    * @param recipient Address of the recipient who will receive the NT.
    * @param amt The amount of NT to be transferred.
    */
    function transferFrom(address from, address recipient, uint256 amt) public {
        erc20Contract.transferFrom(from, recipient, amt);
    }

    /**
    * @dev Function to approve another address to spend a specified amount of NT on behalf of msg.sender.
    *
    * @param spender Address which will be authorized to spend the NT.
    * @param amt The amount of NT that the spender is authorized to spend.
    */
    function approve(address spender, uint256 amt) public {
        erc20Contract.approve(spender, amt);
    }
}
