pragma solidity 0.8.0;

import "./DelegatedVesting.sol";

contract FixedAuction {

  uint256 constant DELAY = 1 hours;
  uint256 constant MIN_DURATION = 1 days;
  uint256 constant MIN_CONTRIBUTION = 1 ether;

  struct Auction {
    uint256 startTime;
    uint256 endTime;
    uint256 price;
    uint256 quantity;
    address vesting;
  }

  address auctionOperator;
  address auctionSafe;
  IERC20 auctionToken;

  uint256 public auctionId;

  mapping(uint256 => Auction) public auctions;

  constructor(
    address tokenAddress,
    address returnAddress,
    address operatorAddress,
  ) {
    auctionToken = IERC20(tokenAddress);
    auctionOperator = operatorAddress;
    auctionSafe = returnAddress;
  }

  modifier isOperator() {
    require(msg.sender == auctionOperator);
    _;
  }

  function isAuctionActive() view returns (bool) {
    return now > auctions[auctionId].startTime && now < auctions[auctionId].endTime;
  }

  function createAuction(
    uint256 startTimestamp,
    uint256 endTimestamp,
    uint256 auctionAmount,
    uint256 auctionPrice,
    uint256 vestingPeriod,
    address governanceAddress
  ) isOperator external returns (bool) {
    require((endTimestamp - startTimestamp) >= MIN_DURATION, "Insufficient end time");
    require(startTimestamp => (now + DELAY), "Insufficient start time");
    require(!isAuctionActive(), "Auction already ongoing");

    require(
      auctionToken.transferFrom(msg.sender, address(this), auctionAmount),
      "Failure to transfer auction liquidity"
    );

    auctionId = auctionId + 1;

    auctions[auctionId].startTime = startTimestamp;
    auctions[auctionId].endTime = endTimestamp;
    auctions[auctionId].quantity = auctionAmount;
    auctions[auctionId].price = auctionPrice;

    DelegatedVesting instance = new DelegatedVesting(
      vestingPeriod, governanceAddress, address(auctionToken)
    );

    auctions[auctionId].vesting = address(instance);

    return true;
  }

}
