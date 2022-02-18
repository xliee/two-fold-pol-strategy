pragma solidity 0.8.0;

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IERC20.sol";

contract LiquidityManagement {

  address constant DAI_ADDRESS =;
  address constant TORN_ADDRESS =;
  address constant ETH_TORN_ADDRESS =;
  address constant DAI_TORN_ADDRESS =;
  address constant UNIV2_ROUTER02_ADDRESS=;
  address constant TORN_TREASURY =;

  IERC20 DAI;
  IERC20 TORN;
  IERC20 UNIV2_DAI_TORN;
  IERC20 UNIV2_ETH_TORN;
  IUniswapV2Router02 UNIV2_ROUTER;

  constructor() {
    IERC20 DAI = IERC20(DAI_ADDRESS);
    IERC20 TORN = IERC20(TORN_ADDRESS);
    IERC20 UNIV2_DAI_TORN = IERC20(DAI_TORN_ADDRESS);
    IERC20 UNIV2_ETH_TORN = IERC20(ETH_TORN_ADDRESS);
    IUniswapV2Router02 UNIV2_ROUTER = IUniswapV2Router02(UNIV2_ROUTER02_ADDRESS);
  }

  function addLiquidityAndWithdrawToTreasury(
    uint256 amountETH,
    uint256 amountDAI,
    uint256 amountTORN,
    uint256 slippageETH,
    uint8 slippageTORN,
    uint8 slippageDAI,
  ) public returns (bool) {
    require(DAI.transferFrom(msg.sender, address(this), amountDAI));
    require(TORN.transferFrom(msg.sender, address(this), amountTORN));
    require(msg.value == amountETH);

    uint256 deploymentDeadline = now + 6000;
    uint256 amountSeedTORN = amountTORN / 2;
    uint256 minimumAmountTORN = amountSeedTORN - (1 ether * slippageTORN);
    uint256 minimumAmountDAI = amountDAI - (1 ether * slippageTORN);
    uint256 minimumAmountETH = amountETH - slippageETH;

    DAI.approve(UNIV2_ROUTER02_ADDRESS, amountDAI);
    TORN.approve(UNIV2_ROUTER02_ADDRESS, amountTORN);

    UNIV2_ROUTER.addLiquidity(
      DAI_ADDRESS, TORN_ADDRESS,
      amountDAI, amountSeedTORN, minimumAmountDAI, minimumAmountTORN,
      deploymentDeadline,
      TORN_TREASURY,
    );

    UNIV2_ROUTER.addLiquidityETH(
      TORN_ADDRESS,
      amountSeedTORN, minimumAmountTORN, minimumAmountETH,
      deploymentDeadline,
      TORN_TREASURY,
    );

    return true;
  }

}
