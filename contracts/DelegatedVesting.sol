// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.0;

import "./interfaces/IERC20.sol";
import "./interfaces/IGovernance.sol";

contract DelegatedInstance {

  address public spender;
  address public sender;
  uint256 public balance;

  IGovernance governance;
  IERC20 token;

  constructor(
    address stakeholderAddress,
    address governanceAddress,
    address tokenAddress,
    uint256 stakeAmount
  ) {
    governance = IGovernance(governanceAddress);
    token = IERC20(tokenAddress);

    spender = stakeholderAddress;
    balance = stakeAmount;
    sender = msg.sender;
  }

  function delegate(address to) public {
    require(msg.sender == spender, "Incorrect spender");

    governance.delegate(to);
  }

  function lockAndDelegate(
    address to,
    uint256 amount, uint256 deadline,
    uint8 v, bytes32 r, bytes32 s
  ) external {
    require(msg.sender == sender);

    token.transferFrom(msg.sender, address(this), amount);
    governance.lock(
      address(this), amount, deadline, v, r, s
    );
    governance.delegate(to);
  }

  function unlockAndRedeem() public {
    require(msg.sender == sender, "Incorrect sender");

    uint256 stake = balance;

    delete balance;
    governance.unlock(stake);
    token.transfer(spender, stake);
  }

}

contract DelegatedVesting {

  uint256 public vestingPeriod;
  address public vestingGovernance;
  IERC20 public vestingToken;

  mapping(address => uint256) balances;
  mapping(address => address) delegations;
  mapping(address => uint256) commitments;

  constructor(
    uint256 vestingTimestamp,
    address governanceAddress,
    address tokenAddress
  ) {
    vestingPeriod = vestingTimestamp;
    vestingToken = IERC20(tokenAddress);
    vestingGovernance = governanceAddress;
  }

  function isActiveCommitment(address stakeholderAddress) public view returns (bool) {
    uint256 commitment = commitments[stakeholderAddress];
    uint256 stake = balances[stakeholderAddress];

    return stake > 0 && commitment > now;
  }

  function isDelegatedCommitment(address stakeholderAddress) public view returns (bool) {
    uint256 delegated = delegations[stakeholderAddress];
    bool state = isActiveCommitment(stakeholderAddress);

    return state && delegated != address(0x0);
  }

  function isFulfilledCommitment(address stakeholderAddress) public view returns (bool) {
    uint256 commitment = commitments[stakeholderAddress];
    uint256 stake = balances[stakeholderAddress];

    return stake > 0 && commitment < now;
  }

  function makeCommitment(
    address recipientAddress,
    uint256 amount
  ) public {
    require(vestingToken.transferFrom(msg.sender, address(this), amount));

    commitments[recipientAddress] = vestingPeriod;

    if(isActiveCommitment(recipientAddress)) {
      balances[recipientAddress] = balances[recipientAddress] + amount;
    } else {
      balances[recipientAddress] = amount;
    }
  }

  function delegateCommitment(
    address to,
    uint256 deadline,
    uint8 v, bytes32 r, bytes32 s
  ) public {
    require(isActiveCommitment(msg.sender), "Not an active commitment");

    if(isDelegatedCommitment(msg.sender)) {
      DelegatedInstance(delegations[msg.sender]).delegate(to);
    } else {
      DelegatedInstance e = new DelegatedInstance(
        msg.sender,
        vestingGovernance,
        address(vestingToken),
        balances[msg.sender],
        deadline,
        v, r, s
     );
     vestingToken.approve(address(e), balances[msg.sender]);
     e.lockAndDelegate(to, balances[msg.sender], deadline, v, r, s);
     delegations[msg.sender] = address(e);
    }
  }

  function fulfilCommitment() public {
    require(isFulfilledCommitment(msg.sender), "Commitment is not possible to fulfil");

    uint256 stake = balances[msg.sender];
    uint256 delegated = delegations[msg.sender];

    delete balances[msg.sender];

    if(delegated != address(0x0)){
      delete delegations[msg.sender];
      DelegatedInstance(delegated).unlockAndRedeem();
    } else {
      vestingToken.transfer(msg.sender, stake);
    }
  }

 }
