import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { hardhatArguments } from "hardhat";
import { TokenExchangeSetIssuer__factory, IParaswapV6__factory, IUniswapV2Router__factory } from "../../typechain-types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (hardhatArguments.network !== "mainnet") {
    return;
  }

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const deployerSigner: SignerWithAddress = await ethers.getSigner(deployer);
  console.log(deployer);

  let paraswapV6Interface = new ethers.utils.Interface(IParaswapV6__factory.abi);
  let uniswapRouterInterface = new ethers.utils.Interface(IUniswapV2Router__factory.abi);

  let flokiTaxHandlerAddress = "0x834F96fD4fE9147a2a647D957FBbE67FEc62B67b";
  let uniswapRouterAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
  let flokiAddress = "0xcf0C122c6b73ff809C693DB761e7BaeBe62b6a2E";
  let paraSwapV6Address = "0x6A000F20005980200259B80c5102003040001068";
  let basicIssuanceModuleAddress = "0x9330d0F979af5c8a5f2380f7bc41234A7d8A15de";
  let usdc = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
  let doge = "0x4206931337dc273a630d328dA6441786BfaD668f";
  let shib = "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE";
  let pepe = "0x6982508145454Ce325dDbE47a25d4ec3d2311933";
  let floki = "0xcf0C122c6b73ff809C693DB761e7BaeBe62b6a2E";
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

  let meem = await deployments.get("MEEMIndexToken");
  let exchangeDeployer = await deploy("TokenExchangeSetIssuer", {
    from: deployer,
    args: [deployer],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  // let flokiUniswapDeployer = await deploy("FlokiUniswapV2BuyTokens", {
  //   from: deployer,
  //   args: [flokiTaxHandlerAddress, uniswapRouterAddress, flokiAddress],
  //   skipIfAlreadyDeployed: true,
  //   log: true,
  //   autoMine: true,
  // });
  let flokiUniswapDeployer = await deployments.get("FlokiUniswapV2BuyTokens");

  const tokenExchangeIssuer = new TokenExchangeSetIssuer__factory(
    deployerSigner,
  ).attach(exchangeDeployer.address);

  let toApprove = [
	[[usdc, weth, doge, shib, pepe], paraSwapV6Address],
	[[weth, doge, shib, pepe, floki], basicIssuanceModuleAddress],
	[[usdc, weth, floki], flokiUniswapDeployer.address]
];
  let tx;
  for (var params of toApprove) {
    console.log("approving tokens for", params[1]);
    tx = await tokenExchangeIssuer.approveTokens(params[0], params[1], ethers.constants.MaxUint256);
    console.log(tx);
    await tx.wait(2);
    console.log("approved tokens for", params[1]);
  }
  console.log("adding basicIssuanceModuleAddress for meem");
  tx = await tokenExchangeIssuer.addSetTokenIssuanceModules(meem.address, basicIssuanceModuleAddress);
  console.log(tx);
  await tx.wait(2);
  console.log("added basicIssuanceModuleAddress for meem");

  let paraswapFunctions = [
        paraswapV6Interface.getSighash('swapExactAmountOut'),
        paraswapV6Interface.getSighash('swapExactAmountOutOnUniswapV3'),
        paraswapV6Interface.getSighash('swapExactAmountOutOnUniswapV2'),
        paraswapV6Interface.getSighash('swapExactAmountIn'),
        paraswapV6Interface.getSighash('swapExactAmountInOnUniswapV3'),
        paraswapV6Interface.getSighash('swapExactAmountInOnUniswapV2'),
  ];

  console.log("whitelisting paraswap functions");
  tx = await tokenExchangeIssuer.whitelistFunctions(paraSwapV6Address, paraswapFunctions);
  console.log(tx);
  await tx.wait(2);
  console.log("whitelisted paraswap functions");

  let uniswapFunctions = [
    uniswapRouterInterface.getSighash('swapTokensForExactTokens'),
    uniswapRouterInterface.getSighash('swapExactTokensForTokensSupportingFeeOnTransferTokens'),
  ];

  console.log("whitelisting uniswap functions");
  tx = await tokenExchangeIssuer.whitelistFunctions(uniswapRouterAddress, uniswapFunctions);
  console.log(tx);
  await tx.wait(2);
  console.log("whitelisted uniswap functions");

};

export default func;

func.tags = ["exchangeHelpers"];
