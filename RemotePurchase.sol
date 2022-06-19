// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;
contract Purchase {
    uint public value;
    uint public calledConfirmPurchase;
    address payable public seller;
    address payable public buyer;

    enum State { Created, Locked, Release, Inactive }
    // The state variable has a default value of the first member, `State.created`
    State public state;

    modifier condition(bool condition_) {
        require(condition_);
        _;
    }

    /// Only the buyer can call this function.
    error OnlyBuyer();
    /// Only the seller can call this function.
    error OnlySeller();
    /// The function cannot be called at the current state.
    error InvalidState();
    /// The provided value has to be even.
    error ValueNotEven();
    /// Seller can call this function only after 5 min passed since Buyer confirmedReceived() - Buyer can call it at any time
    error FiveMinNotPassedYet();

    modifier onlyBuyer() {
        if (msg.sender != buyer)
            revert OnlyBuyer();
        _;
    }

    // / New modifier that lets Seller call confirmPurchase()
    // / 5 min after Buyer called confirmReceived() will this modifier let act
    // / 5 min are measured in Unix as 300 seconds
    modifier fiveMinSeller() {
        if ( ( msg.sender == seller && block.timestamp <= calledConfirmPurchase + 300 ) )
            revert FiveMinNotPassedYet();
        _;
    }

    modifier onlySeller() {
        if (msg.sender != seller)
            revert OnlySeller();
        _;
    }

    modifier inState(State state_) {
        if (state != state_)
            revert InvalidState();
        _;
    }

    event Aborted();
    event PurchaseConfirmed();
    event ItemReceived();
    event SellerRefunded();
    event PurchaseComplete(); //  New Event for completePurchase()

    // Ensure that `msg.value` is an even number.
    // Division will truncate if it is an odd number.
    // Check via multiplication that it wasn't an odd number.
    constructor() payable {
        seller = payable(msg.sender);
        value = msg.value / 2;
        if ((2 * value) != msg.value)
            revert ValueNotEven();
    }

    /// Abort the purchase and reclaim the ether.
    /// Can only be called by the seller before
    /// the contract is locked.
    function abort()
        external
        onlySeller
        inState(State.Created)
    {
        emit Aborted();
        state = State.Inactive;
        // We use transfer here directly. It is
        // reentrancy-safe, because it is the
        // last call in this function and we
        // already changed the state.
        seller.transfer(address(this).balance);
    }

    /// Confirm the purchase as buyer.
    /// Transaction has to include `2 * value` ether.
    /// The ether will be locked until confirmReceived
    /// is called.
    function confirmPurchase()
        external
        inState(State.Created)
        condition(msg.value == (2 * value))
        payable
    {
        emit PurchaseConfirmed();
        buyer = payable(msg.sender);
        state = State.Locked;
        calledConfirmPurchase = block.timestamp;
    }

    /// New Function that merges both confirmReceived() and refundSeller()
    /// It first checks if the if the Seller is already allowed to call the function
    /// Then it changes the State
    /// then it transfer the values to both Seller and Buyer
    function completePurchase() 
        external
        inState( State.Locked )
        fiveMinSeller()
    {
        emit PurchaseComplete();
        // Transfer the value back to the Buyer
        state = State.Release;
        buyer.transfer( value );

        // Refund Seller with the sold amount + the deposit done at contract deploment value * 2
        state = State.Inactive;
        seller.transfer( 3 * value );
    }

}