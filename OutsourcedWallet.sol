pragma solidity ^0.4.18;

// Wallet that is owned by someone specified at creation time
contract OutsourcedWallet {
    address private owner;
    
    event TransactionReceived(address sender, uint amount);
    event TransactionSent(address receiver, uint amount);
    
    function OutsourcedWallet(address _owner) public payable {
        owner = _owner;
    }
    
    function () payable external {
        if (msg.value > 0) {
            TransactionReceived(msg.sender, msg.value);
        }
    }
    
    function send(address receiver, uint amount, bytes data) external returns (bool) {
        require(msg.sender == owner);
        
        bool result = receiver.call.value(amount)(data);
        
        if (result) {
            TransactionSent(receiver, amount);
        }
        
        return result;
    }
}
