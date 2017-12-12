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
    
    function Shop(address _owner, uint _orderLifetime) public {
        owner = _owner;
        orderLifetime = _orderLifetime;
    }
    
    // Order a beer
    function order(string reference) payable external returns (bool) {
        require(
            active &&
            // Reference must not be in use
            !unconfirmedOrders[reference].isValid
        );
        
        unconfirmedOrders[reference] = Order({
            customer: msg.sender,
            amount: msg.value,
            expireTime: block.timestamp + orderLifetime,
            delivering: false,
            isValid: true
        });
        
        OrderCreated(reference, msg.value);
        
        return true;
    }
    
    // The shop confirms that they are delivering the order, locking the funds from being freely retrieved
    function confirmDelivering(string reference) external returns (bool) {
        var order = unconfirmedOrders[reference];
        
        require(
            msg.sender == owner &&
            order.isValid &&
            // Order must not be expired yet
            block.timestamp <= order.expireTime &&
            // Order must not already be in delivery
            !order.delivering
        );
        
        unconfirmedOrders[reference].delivering = true;
        
        OrderConfirmedDelivering(reference);
        
        return true;
    }
    
    // Confirms that the order has been delivered, making the funds unrecoverable for the customer
    function confirmReceived(string reference) external returns (bool) {
        var order = unconfirmedOrders[reference];
        
        require(
            order.isValid &&
            order.customer == msg.sender &&
            // Order must not be expired yet
            block.timestamp <= order.expireTime &&
            // Order must be in delivery
            order.delivering
        );
        
        confirmedBalance += order.amount;
        
        delete unconfirmedOrders[reference];
        
        OrderConfirmedReceived(reference);
        
        return true;
    }
    
    // Cancels an expired or undelivering order and refunds it to the customer
    function cancel(string reference) external returns (bool) {
        var order = unconfirmedOrders[reference];
        
        require(
            order.isValid &&
            order.customer == msg.sender &&
            // Order must be expired or not being delivered yet
            (block.timestamp > order.expireTime || !order.delivering)
        );
        
        var amount = order.amount;
        
        // Delete before transfer to prevent re-entrancy exploit (Solidity!)
        delete unconfirmedOrders[reference];
        
        msg.sender.transfer(amount);
        
        OrderCanceled(reference);
        
        return true;
    }
    
    // Drain confirmed balance to owner
    function drain() external returns (bool) {
        require(
            msg.sender == owner
        );
        
        var drainableBalance = confirmedBalance;
        
        if (drainableBalance == 0) {
            return true;
        }
        
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
