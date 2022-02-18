pragma solidity >=0.6.2;

interface IUniswapV2Router02 {

  function addLiquidity(
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline,
  ) external returns (
    uint amountA,
    uint amountB,
    uint liquidity,
  );

  function addLiquidityETH(
    address token,
    uint amountTokenDesired,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline,
  ) external returns (
    uint amountToken,
    uint amountETH,
    uint liquidity,
  );

  function removeLiquidity(
    address tokenA,
    address tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
  ) external returns (
    uint amountA,
    uint amountB,
  );

  function removeLiquidityETH(
    address token,
    uint liquidity,
    uint amountTokenMin,
    uint amountETHMin,
    address to,
    uint deadline,
  ) external returns (
    uint amountToken,
    uint amountETH,
  );

}
