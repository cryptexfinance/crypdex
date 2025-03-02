import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { hardhatArguments } from "hardhat";
import {
  TokenExchangeSetIssuer__factory,
  IParaswapV6__factory,
  IUniswapV2Router__factory,
} from "../../typechain-types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (hardhatArguments.network !== "arbitrum") {
    return;
  }

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const deployerSigner: SignerWithAddress = await ethers.getSigner(deployer);
  console.log(deployer);

  let paraswapV6Interface = new ethers.utils.Interface(
    IParaswapV6__factory.abi,
  );
  let uniswapRouterInterface = new ethers.utils.Interface(
    IUniswapV2Router__factory.abi,
  );

  let paraSwapV6Address = "0x6A000F20005980200259B80c5102003040001068";
  let basicIssuanceModuleAddress = "0x99c1AbfD91C7b0d43865316eF2BCa614237bEB2A";

  let usdc = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831";
  let weth = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
  const aave = "0xba5DdD1f9d7F570dc94a51479a000E3BCE967196";
  const gmx = "0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a";
  const uni = "0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0";
  const grail = "0x3d9907F9a368ad0a51Be60f7Da3b97cf940982D8";
  const pendle = "0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8";
  const Stg = "0x6694340fc020c5E6B96567843da2df01b2CE1eb6";
  const Crv = "0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978";

  let arbFI = await deployments.get("ArbFIIndexToken");
  let exchangeDeployer = await deploy("TokenExchangeSetIssuer", {
    from: deployer,
    args: [deployer],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  const tokenExchangeIssuer = new TokenExchangeSetIssuer__factory(
    deployerSigner,
  ).attach(exchangeDeployer.address);

  let toApprove = [
    [[usdc, weth, aave, gmx, uni, grail, pendle, Stg, Crv], paraSwapV6Address],
    [[aave, gmx, uni, grail, pendle, Stg, Crv], basicIssuanceModuleAddress],
  ];
  let tx;
  for (var params of toApprove) {
    console.log("approving tokens for", params[1]);
    tx = await tokenExchangeIssuer.approveTokens(
      params[0],
      params[1],
      ethers.constants.MaxUint256,
    );
    console.log(tx);
    await tx.wait(2);
    console.log("approved tokens for", params[1]);
  }
  console.log("adding basicIssuanceModuleAddress for arbFI");
  tx = await tokenExchangeIssuer.addSetTokenIssuanceModules(
    arbFI.address,
    basicIssuanceModuleAddress,
  );
  console.log(tx);
  await tx.wait(2);
  console.log("added basicIssuanceModuleAddress for arbFI");

  let paraswapFunctions = [
    paraswapV6Interface.getSighash("swapExactAmountOut"),
    paraswapV6Interface.getSighash("swapExactAmountOutOnBalancerV2"),
    paraswapV6Interface.getSighash("swapExactAmountOutOnUniswapV3"),
    paraswapV6Interface.getSighash("swapExactAmountOutOnUniswapV2"),
    paraswapV6Interface.getSighash("swapExactAmountIn"),
    paraswapV6Interface.getSighash("swapExactAmountInOnBalancerV2"),
    paraswapV6Interface.getSighash("swapExactAmountInOnCurveV1"),
    paraswapV6Interface.getSighash("swapExactAmountInOnCurveV2"),
    paraswapV6Interface.getSighash("swapExactAmountInOnUniswapV3"),
    paraswapV6Interface.getSighash("swapExactAmountInOnUniswapV2"),
  ];

  console.log("whitelisting paraswap functions");
  tx = await tokenExchangeIssuer.whitelistFunctions(
    paraSwapV6Address,
    paraswapFunctions,
  );
  console.log(tx);
  await tx.wait(2);
  console.log("whitelisted paraswap functions");
};

export default func;

func.tags = ["exchangeHelpers"];
