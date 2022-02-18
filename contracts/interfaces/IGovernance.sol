pragma solidity 0.80;

interface IGovernance  {

  function lock(
    address owner,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s,
  ) external;

  function delegate(address to) external;

  function undelegate() external;

  function unlock(address to) external;

}
