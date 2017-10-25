pragma solidity ^0.4.18;

contract Beer {
    struct Order {
        address customer;
        uint amount;
        uint expireTime;
        bool isValid;
    }
    
    // Price of a beer in Wei
    uint public beerPrice;
    
    // Time orders stay unconfirmed in seconds
    uint public orderLifetime;
    
    // Whether new orders can be placed
    bool public active = true;
    
    address private owner;
    
    // Orders that are to be confirmed or canceled
    mapping(string => Order) private unconfirmedOrders;
    
    // Settled balance that the owner can withdraw
    uint private confirmedBalance = 0;
    
    event OrderCreated(string _reference, uint amount);
    event OrderConfirmed(string _reference);
    
    function Beer(uint _beerPrice, uint _orderLifetime) public {
        owner = msg.sender;
        beerPrice = _beerPrice;
        orderLifetime = _orderLifetime;
    }
    
    // Order a beer
    function order(string _reference) payable external  {
        require(
            active &&
            // Paid value must be at least the price of a beer
            msg.value >= beerPrice &&
            // Reference must not be in use
            !unconfirmedOrders[_reference].isValid
        );
        
        unconfirmedOrders[_reference] = Order({
            customer: msg.sender,
            amount: msg.value,
            expireTime: block.timestamp + orderLifetime,
            isValid: true
        });
        
        OrderCreated(_reference, msg.value);
    }
    
    // Confirms an order, making the funds unrecoverable for the customer
    function confirm(string _reference) external {
        var _order = unconfirmedOrders[_reference];
        
        require(
            _order.isValid &&
            _order.customer == msg.sender &&
            // Order must not be expired yet
            block.timestamp <= _order.expireTime
        );
        
        confirmedBalance += _order.amount;
        
        delete unconfirmedOrders[_reference];
        
        OrderConfirmed(_reference);
    }
    
    // Cancel an expired order and issue a refund
    function cancel(string _reference) external {
        var _order = unconfirmedOrders[_reference];
        
        require(
            _order.isValid &&
            _order.customer == msg.sender &&
            // Order must be expired
            block.timestamp > _order.expireTime
        );
        
        // Delete before transfer to prevent re-entrancy exploit (Solidity!)
        delete unconfirmedOrders[_reference];
        
        msg.sender.transfer(_order.amount);
    }
    
    // Drain confirmed balance to owner
    function drain() external {
        require(
            msg.sender == owner && 
            confirmedBalance > 0
        );
        
        var drainableBalance = confirmedBalance;
        
        // Reset before transfer to prevent re-entrancy exploit (Solidity!)
        confirmedBalance = 0;
        
        msg.sender.transfer(drainableBalance);
    }
    
    // Toggles active state
    function toggleActive() external {
        require(msg.sender == owner);
        
        active = !active;
    }
}
