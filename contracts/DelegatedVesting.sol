pragma solidity 0.8.0;

import "./IERC20.sol";

contract DelegatedVesting {

  uint256 public vestingPeriod;
  address public vestingGovernance;
  IERC20 public vestingToken;

  mapping(address => uint256) balances;
  mapping(address => uint256) delegations;
  mapping(address => uint256) commitments;

  constructor(
    uint256 vestingDuration,
    address governanceAddress,
    address tokenAddress
  ) {
    vestingPeriod = vestingDuration;
    vestingToken = IERC20(tokenAddress);
    vestingGovernance = governanceAddress;
  }

  function isActiveCommitment(address stakeholderAddress) view returns (bool) {
    uint256 commitment = commitments[stakeholderAddress];
    uint256 stake = balances[stakeholderAddress];

    return stake > 0 && commitment > now;
  }

  function isDelegatedCommitment(address stakeholderAddress) view returns (bool) {
    uint256 delegated = delegations[stakeholderAddress];
    bool state = isActiveCommitment(stakeholderAddress);

    return state && delegated == stake;
  }

  function isFulfilledCommitment(address stakeholderAddress) view returns (bool) {
    uint256 commitment = commitments[stakeholderAddress];
    uint256 stake = balances[stakeholderAddress];

    return stake > 0 && commitment < now;
  }

  function makeCommitment(
    address recipientAddress,
    uint256 stakeAmount
  ) external returns (bool) {
    require(vestingToken.transferFrom(msg.sender, address(this), stakeAmount));

    if(isActiveCommitment(recipientAddress)) {
      balances[recipientAddress] = balances[recipientAddress] + stakeAmount;
    } else {
      balances[recipientAddress] = stakeAmount;
    }

    commitments[recipientAddress] = now + vestingPeriod;

    return true;
  }

  function delegateCommitment(
    address candidateAddress
  ) external {
    require(isActiveCommitment(msg.sender), "Not an active commitment");

    if(!isDelegatedCommitment(msg.sender)) {
      // @TODO governance lock
      delegations[msg.sender] = balances[msg.sender];
    }

    // @TODO governance delegate
  }

  function fulfilCommitment() external {
    require(isFulfilledCommitment(msg.sender), "Commitment is not possible to fulfil");

    uint256 stake = balances[msg.sender];
    uint256 delegated = delegations[msg.sender];

    if(stake == delegated){
      // @TODO governance withdraw
      delete delegations[msg.sender];
    }

    delete balances[msg.sender];

    require(vestingToken.transfer(msg.sender, stake));
  }

 }
