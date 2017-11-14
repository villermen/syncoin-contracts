pragma solidity ^0.4.18;

contract Wallet {
    address private owner;
    
    event TransactionReceived(address sender, uint amount);
    event TransactionSent(address receiver, uint amount);
    
    function Wallet() public payable {
        owner = msg.sender;
    }
    
    function () payable external {
        if (msg.value > 0) {
            TransactionReceived(msg.sender, msg.value);
        }
    }
    
    function send(address receiver, uint amount) external {
        require(msg.sender == owner);
        
        receiver.transfer(amount);
        
        TransactionSent(receiver, amount);
    }
}
