// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DutchAuction{

    uint256 constant MIN_DURATION = 1 days;
    uint256 constant DELAY = 1 hours;


    // Operator address
    address public operator;

    // Address to collect raised funds and fees
    address public auctionSafe;

    uint256 public lastAuctionId;
    IERC20 public token;

    // User tokens reserved
    // AuctionId => user => amount
    mapping (uint256 => mapping (address => uint)) public reserve;

    // Tokens left
    // AuctionId => tokens left
    mapping (uint256 => uint256) public tokensLeft;
    // Tokens at start
    // AuctionId => tokens at start
    mapping (uint256 => uint256) public tokensStart;
    // Current price ( Token decimals / 1e18 decimals ) ( Tokens per ETH )
    // AuctionId => current price
    mapping (uint256 => uint256) public price;
    // Start price ( Token decimals / 1e18 decimals ) ( Tokens per ETH )
    // AuctionId => start price
    mapping (uint256 => uint256) public startPrice;
    // Minimum price ( Token decimals / 1e18 decimals ) ( Tokens per ETH )
    // AuctionId => min price
    mapping (uint256 => uint256) public minPrice;
    // Start timestamp
    // AuctionId => start timestamp
    mapping (uint256 => uint256) public start;
    // Finish timestamp
    // AuctionId => finish timestamp
    mapping (uint256 => uint256) public finish;
    // fee percent (0-100)
    // AuctionId => fee
    mapping (uint256 => uint256) public fee;

    // Total amount of tokens sold (including fees)
    // AuctionId => total amount of tokens sold
    mapping (uint256 => uint256) public sold;
    // Total amount of ETH raised
    // AuctionId => total amount of ETH raised
    mapping (uint256 => uint256) public ethRaised;
    // AuctionId => amount
    mapping (uint256 => uint256) public collectedFees;

    // Auction State
    // AuctionId => state
    mapping (uint256 => AuctionStates) public auctionState;

    enum AuctionStates {
      Closed,   // Auction not started
      Open,     // Auction started
      Ended,    // Auction ended
      Collected // Auction ended and funds collected
    }

    constructor(address _tokenAddress, address _operator, address _auctionSafe) {
        operator = _operator;
        auctionSafe = _auctionSafe;
        token = IERC20(_tokenAddress);
    }


    function changeOperator(address payable newOperator) external {
        require(msg.sender == operator, "Not operator");
        operator = newOperator;
    }

    function getFee(uint256 _auctionId) public view returns (uint256) {
        require (_auctionId <= lastAuctionId, "AuctionId must be below or equal lastAuctionId")
        return fee[_auctionId];
    }

    function startAuction(
        uint256 _amount,
        uint256 _startPrice,
        uint256 _minPrice,
        uint256 _start,
        uint256 _finish,
        uint256 _fee
    )
    public
    {
        require(msg.sender == operator, "Not operator");
        unit256 _auctionId = lastAuctionId + 1;
        // require(_auctionId == lastAuctionId + 1, "AuctionId must be lastAuctionId + 1")
        require(auctionState[_auctionId] == AuctionStates.Closed, "Auction already started");
        require(_amount > 0, "Amount must be above 0");
        require(
            auctionToken.transferFrom(msg.sender, address(this), _amount),
            "Failure to transfer auction liquidity"
        );
        // require(_amount <= token.balanceOf(address(this)), "Amount must be below or equal balance");
        require(_minPrice < _startPrice, "Min price above start price");

        require(_start < _finish, "Start time below finish time");
        require((_finish - _start) >= MIN_DURATION, "Insufficient end time");
        require(_finish > block.timestamp, "Finish time must be in the future");
        require(_start >= (block.timestamp + DELAY), "Insufficient start time");

        require(_fee <= 100, "Fee must be below or equal 100");
        require(_fee >= 0, "Fee must be above or equal 0");


        finish[_auctionId] = _finish;
        start[_auctionId] = _start;
        startPrice[_auctionId] = _startPrice;
        minPrice[_auctionId] = _minPrice;
        tokensLeft[_auctionId] = _amount;
        tokensStart[_auctionId] = _amount;
        auctionState[_auctionId] = AuctionStates.Open;
        fee[_auctionId] = _fee;

        updateCurrentPrice(_auctionId);
        lastAuctionId = _auctionId;
    }

    function getCurrentPrice(uint256 _auctionId) public view returns (uint256) {
        require (_auctionId <= lastAuctionId, "AuctionId must be below or equal lastAuctionId")
        uint256 returnPrice = startPrice[_auctionId];

        if (auctionState[_auctionId] == AuctionStates.Open && block.timestamp >= start[_auctionId]) {
            returnPrice = startPrice[_auctionId]*(finish[_auctionId] - block.timestamp) / (finish[_auctionId] - start[_auctionId]);
            if (returnPrice < minPrice[_auctionId]){
                returnPrice = minPrice[_auctionId];
            }
        }
        if (auctionState[_auctionId] == AuctionStates.Ended || auctionState[_auctionId] == AuctionStates.Collected) {
            returnPrice = price[_auctionId];
        }

        return returnPrice;
    }

    function updateCurrentPrice(uint256 _auctionId) public returns (uint256) {
        require (_auctionId <= lastAuctionId, "AuctionId must be below or equal lastAuctionId")
        // Auction is not closed
        require (auctionState[_auctionId] != AuctionStates.Closed, "Auction has not started");

        // Auction is open
        if (auctionState[_auctionId] == AuctionStates.Open) {
            // Auction is not finished
            if (block.timestamp >= start[_auctionId] && block.timestamp < finish[_auctionId]) {
                // Update price
                // Price = startPrice * (finish - now) / (finish - start)
                price[_auctionId] = startPrice[_auctionId]*(finish[_auctionId] - block.timestamp) / (finish[_auctionId] - start[_auctionId]);
                // Check if price is below minPrice
                if (price[_auctionId] < minPrice[_auctionId]){
                    // Set price to minPrice
                    price[_auctionId] = minPrice[_auctionId];
                }
            }

            // Auction hasn't started yet
            if (block.timestamp < start[_auctionId]) {
                // Set price to startPrice
                price[_auctionId] = startPrice[_auctionId];
            }

            // Auction is finished
            if (block.timestamp >= finish[_auctionId]){
                // Set auction state to ended
                auctionState[_auctionId] = AuctionStates.Ended;
            }
        }

        return price[_auctionId];
    }

    function closeAuction(uint256 _auctionId) public {
        require (_auctionId <= lastAuctionId, "AuctionId must be below or equal lastAuctionId")
        require (auctionState[_auctionId] == AuctionStates.Open, "Auction not active");
        require ((msg.sender == operator && sold[_auctionId] == 0) || (block.timestamp > finish[_auctionId]),
            "Either not operator and no current bid or auction finish time not reached");

        auctionState[_auctionId] = AuctionStates.Ended;
    }


    // Place a bid
    function bid(uint256 _auctionId, uint256 amount) public payable {
        require (_auctionId <= lastAuctionId, "AuctionId must be below or equal lastAuctionId")
        require (msg.value * updateCurrentPrice() >= amount, "Not enough payment");
        require (auctionState[_auctionId] == AuctionStates.Open, "Not active auction");
        require (block.timestamp >= start[_auctionId], "Start time not reached");
        require (msg.value > 0, "Cant bid with 0");


        if (amount > tokensLeft[_auctionId]){
            amount = tokensLeft[_auctionId];
        }

        tokensLeft[_auctionId] -= amount;

        // Calculate fee
        uint256 bidFee =   amount * fee[_auctionId] / 100;

        // Bidders Token Reserve
        reserve[_auctionId][msg.sender] += amount - bidFee;

        // Collected fees
        fees[_auctionId] += bidFee;

        // Tokens sold
        sold[_auctionId] += amount;

        // Total eth raised
        ethRaised[_auctionId] += msg.value;


        if (tokensLeft[_auctionId] == 0){
            auctionState[_auctionId] = AuctionStates.Ended;
        }
    }

    // Claim tokens after auction ended
    function claim(uint256 _auctionId) public {
        require (_auctionId <= lastAuctionId, "AuctionId must be below or equal lastAuctionId")
        require (auctionState[_auctionId] == AuctionStates.Ended || auctionState[_auctionId] == AuctionStates.Collected, "Auction not ended");
        uint256 userTokens;

        // amount of tokens reserved
        userTokens = reserve[_auctionId][msg.sender];
        require(userTokens > 0, "No tokens reserved");

        reserve[_auctionId][msg.sender] = 0;

        // Transfer tokens
        token.transfer(msg.sender, userTokens);
    }

    /// -> View functions <-

    // View auction state
    function auctionState(uint256 _auctionId) public view returns (AuctionStates) {
        require (_auctionId <= lastAuctionId, "AuctionId must be below or equal lastAuctionId")
        return auctionState[_auctionId];
    }

    // View auction start time
    function auctionStart(uint256 _auctionId) public view returns (uint256) {
        require (_auctionId <= lastAuctionId, "AuctionId must be below or equal lastAuctionId")
        return start[_auctionId];
    }

    // View auction finish time
    function auctionFinish(uint256 _auctionId) public view returns (uint256) {
        require (_auctionId <= lastAuctionId, "AuctionId must be below or equal lastAuctionId")
        return finish[_auctionId];
    }

    // View auction start price
    function auctionStartPrice(uint256 _auctionId) public view returns (uint256) {
        require (_auctionId <= lastAuctionId, "AuctionId must be below or equal lastAuctionId")
        return startPrice[_auctionId];
    }

    // View auction min price
    function auctionMinPrice(uint256 _auctionId) public view returns (uint256) {
        require (_auctionId <= lastAuctionId, "AuctionId must be below or equal lastAuctionId")
        return minPrice[_auctionId];
    }

    // View auction fee
    function auctionFee(uint256 _auctionId) public view returns (uint256) {
        require (_auctionId <= lastAuctionId, "AuctionId must be below or equal lastAuctionId")
        return fee[_auctionId];
    }

    // View auction tokens left
    function auctionTokensLeft(uint256 _auctionId) public view returns (uint256) {
        require (_auctionId <= lastAuctionId, "AuctionId must be below or equal lastAuctionId")
        return tokensLeft[_auctionId];
    }

    // View start tokens
    function auctionStartTokens(uint256 _auctionId) public view returns (uint256) {
        require (_auctionId <= lastAuctionId, "AuctionId must be below or equal lastAuctionId")
        return tokensStart[_auctionId];
    }

    // View Claimable tokens
    function claimable(uint256 _auctionId) public view returns (uint256) {
        require (_auctionId <= lastAuctionId, "AuctionId must be below or equal lastAuctionId")
        require (auctionState[_auctionId] == AuctionStates.Ended || auctionState[_auctionId] == AuctionStates.Collected, "Auction not ended");
        return reserve[_auctionId][msg.sender];
    }

    fallback () external payable {
        require(lastAuctionId != 0, "No auction created yet");
        if (auctionState[lastAuctionId] == AuctionStates.Open && block.timestamp >= start[lastAuctionId]){
            require(msg.value > 0, "Cant bid with 0");
            bid(msg.value * updateCurrentPrice(lastAuctionId));
        }
        else if (auctionState[lastAuctionId] == AuctionStates.Ended){
            require(msg.value == 0, "Cant send ETH to contract");
            claim(lastAuctionId);
            if (msg.sender == operator){
                withdraw(lastAuctionId);
            }
        }
        else{
            revert();
        }
    }
    function withdraw(uint256 _auctionId) public {
        require (_auctionId <= lastAuctionId, "AuctionId must be below or equal lastAuctionId")
        require(auctionState[_auctionId] == AuctionStates.Ended, "Not closed");

        // calculate the amount of ETH to send to the operator
        uint256 withdrawAmount = ethRaised[_auctionId];
        
        if (withdrawAmount > address(this).balance) {
            withdrawAmount = address(this).balance;
        }

        // send the raised funds to the auctionSafe (ETH)
        if (withdrawAmount > 0){
            (bool success, ) = payable(auctionSafe).call.value(withdrawAmount)("");
            require(success, "Transfer failed.");
            withdrawAmount = 0;
            ethRaised[_auctionId] = 0;
        }

        // send the collected fees to the operator (ERC20)
        if (collectedFees[_auctionId] > 0){
            if (collectedFees[_auctionId] > token.balanceOf(address(this))){
                collectedFees[_auctionId] = token.balanceOf(address(this));
            }
            require(
                token.transfer(auctionSafe, collectedFees[_auctionId]);,
                "Transfer failed."
            );
            collectedFees[_auctionId] = 0;
        }

        auctionState[_auctionId] = AuctionStates.Collected;
    }

}

