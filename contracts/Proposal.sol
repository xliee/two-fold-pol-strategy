// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.0;

import "./DutchAuction.sol";

contract Proposal  {

  function executeProposal() external {
    // Launch the Dutch Auction
    DutchAuction dutchAuction = new DutchAuction();
    dutchAuction.startAuction(
      ,// Amount of TORN to sell
      ,// Start Price
      ,// Minimum Price
      ,// Start Time
      ,// End Time
      ,// Fee
    );
  }

}
