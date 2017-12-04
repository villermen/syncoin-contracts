pragma solidity ^0.4.18;

contract Shop {
    struct Order {
        address customer;
        uint amount;
        uint expireTime;
        bool delivering; // Shop is delivering order, locking payment until it expires
        bool isValid; // Used for checking whether mapping contains an Order
    }
    
    // Time orders stay unconfirmed in seconds
    uint public orderLifetime;
    
    // Whether new orders can be placed
    bool public active = true;
    
    address private owner;
    
    // Orders that are to be confirmed or canceled
    mapping(string => Order) private unconfirmedOrders;
    
    // Settled balance that the owner can withdraw
    uint private confirmedBalance = 0;
    
    event OrderCreated(string reference, uint amount);
    event OrderConfirmedDelivering(string reference);
    event OrderConfirmedReceived(string reference);
    event OrderCanceled(string reference);
    
    function Shop(uint _orderLifetime) public {
        owner = msg.sender;
        orderLifetime = _orderLifetime;
    }
    
    // Order a beer
    function order(string _reference) payable external returns (bool) {
        require(
            active &&
            // Reference must not be in use
            !unconfirmedOrders[_reference].isValid
        );
        
        unconfirmedOrders[_reference] = Order({
            customer: msg.sender,
            amount: msg.value,
            expireTime: block.timestamp + orderLifetime,
            delivering: false,
            isValid: true
        });
        
        OrderCreated(_reference, msg.value);
        
        return true;
    }
    
    // The shop confirms that they are delivering the order, locking the funds from being freely retrieved
    function confirmDelivering(string _reference) external returns (bool) {
        require(
            msg.sender == owner &&
            !unconfirmedOrders[_reference].isValid
        );
        
        unconfirmedOrders[_reference].delivering = true;
        
        OrderConfirmedDelivering(_reference);
        
        return true;
    }
    
    // Confirms that the order has been delivered, making the funds unrecoverable for the customer
    function confirmReceived(string _reference) external returns (bool) {
        var _order = unconfirmedOrders[_reference];
        
        require(
            _order.isValid &&
            _order.customer == msg.sender &&
            // Order must not be expired yet
            block.timestamp <= _order.expireTime
        );
        
        confirmedBalance += _order.amount;
        
        delete unconfirmedOrders[_reference];
        
        OrderConfirmedReceived(_reference);
        
        return true;
    }
    
    // Cancel an expired or undelivered order and issue a refund
    function cancel(string _reference) external returns (bool) {
        var _order = unconfirmedOrders[_reference];
        
        require(
            _order.isValid &&
            _order.customer == msg.sender &&
            // Order must be expired or not being delivered
            (block.timestamp > _order.expireTime ||
            _order.delivering == false)
        );
        
        // Delete before transfer to prevent re-entrancy exploit (Solidity!)
        delete unconfirmedOrders[_reference];
        
        msg.sender.transfer(_order.amount);
        
        OrderCanceled(_reference);
        
        return true;
    }
    
    // Drain confirmed balance to owner
    function drain() external returns (bool) {
        require(
            msg.sender == owner && 
            confirmedBalance > 0
        );
        
        var drainableBalance = confirmedBalance;
        
        // Reset before transfer to prevent re-entrancy exploit (Solidity!)
        confirmedBalance = 0;
        
        msg.sender.transfer(drainableBalance);
        
        return true;
    }
    
    // Toggles active state
    function toggleActive() external returns (bool) {
        require(msg.sender == owner);
        
        active = !active;
        
        return true;
    }
}
