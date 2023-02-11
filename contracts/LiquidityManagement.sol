pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// https://docs.uniswap.org/contracts/v2/reference/smart-contracts/router-02
// https://github.com/Uniswap/v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";



contract LiquidityManagement {

  address constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
  address constant TORN_ADDRESS = 0x77777FeDdddFfC19Ff86DB637967013e6C6A116C;
  address constant ETH_TORN_ADDRESS = 0x0C722a487876989Af8a05FFfB6e32e45cc23FB3A; // TORN/ETH ?
  address constant DAI_TORN_ADDRESS = 0xb9C6f39dB4e81DB44Cf057C7D4d8e3193745101E;
  address constant UNIV2_ROUTER02_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  address constant TORN_TREASURY = 0x5efda50f22d34F262c29268506C5Fa42cB56A1Ce; // Governance

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



  // Add liquidity to the DAI/TORN and ETH/TORN pools
  function addLiquidityAndWithdrawToTreasury(
    uint256 amountETH,
    uint256 amountDAI,
    uint256 amountTORN,
    uint256 slippageETH,
    uint256 slippageTORN,
    uint256 slippageDAI
  ) public returns (bool) {
    // transfer tokens from the user to the contract
    require(DAI.transferFrom(msg.sender, address(this), amountDAI));
    require(TORN.transferFrom(msg.sender, address(this), amountTORN));
    require(msg.value == amountETH);

    // deadline for the transaction to be mined (10 minutes)
    uint256 deploymentDeadline = block.timestamp + 10 minutes;
    // Split the TORN amount in half for the two liquidity pools
    uint256 amountSeedTORN = amountTORN / 2;
    // configure slippage
    uint256 minimumAmountDAI = amountDAI - slippageDAI;
    uint256 minimumAmountETH = amountETH - slippageETH;
    uint256 minimumAmountTORN = amountSeedTORN - slippageTORN;


    // DAI/TORN
    DAI.approve(UNIV2_ROUTER02_ADDRESS, amountDAI);
    UNIV2_ROUTER.addLiquidity(
      DAI_ADDRESS,        // tokenA address
      TORN_ADDRESS,       // tokenB address
      amountDAI,          // tokenA amount
      amountSeedTORN,     // tokenB amount
      minimumAmountDAI,   // minimum tokenA amount
      minimumAmountTORN,  // minimum tokenB amount
      TORN_TREASURY,      // to
      deploymentDeadline, // deadline
    );

    // ETH/TORN
    TORN.approve(UNIV2_ROUTER02_ADDRESS, amountTORN);
    UNIV2_ROUTER.addLiquidityETH(
      TORN_ADDRESS,       // token address
      amountSeedTORN,     // token amount
      minimumAmountTORN,  // minimum token amount
      minimumAmountETH,   // minimum eth amount
      TORN_TREASURY,      // to
      deploymentDeadline, // deadline
    );

    return true;
  }

}
