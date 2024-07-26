import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { hardhatArguments } from "hardhat";
import { TokenExchangeSetIssuer__factory } from "../../typechain-types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (hardhatArguments.network !== "mainnet") {
    return;
  }

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const deployerSigner: SignerWithAddress = await ethers.getSigner(deployer);
  console.log(deployer);

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

  let exchangeDeployer = await deploy("TokenExchangeSetIssuer", {
    from: deployer,
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  let flokiUniswapDeployer = await deploy("FlokiUniswapV2BuyTokens", {
    from: deployer,
    args: [flokiTaxHandlerAddress, uniswapRouterAddress, flokiAddress],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  const tokenExchangeIssuer = new TokenExchangeSetIssuer__factory(
    deployerSigner,
  ).attach(exchangeDeployer.address);
  let toApprove = [
    [usdc, paraSwapV6Address],
    [usdc, flokiUniswapDeployer.address],
    [weth, paraSwapV6Address],
    [weth, flokiUniswapDeployer.address],
    [doge, paraSwapV6Address],
    [shib, paraSwapV6Address],
    [pepe, paraSwapV6Address],
    [floki, flokiUniswapDeployer.address],
    [weth, paraSwapV6Address],
    [doge, basicIssuanceModuleAddress],
    [shib, basicIssuanceModuleAddress],
    [pepe, basicIssuanceModuleAddress],
    [floki, basicIssuanceModuleAddress],
    [weth, basicIssuanceModuleAddress],
  ];
  let tx;
  for (var addresses of toApprove) {
    console.log("approving", addresses[0], addresses[1]);
    tx = await tokenExchangeIssuer.approveToken(addresses[0], addresses[1]);
    console.log(tx);
    await tx.wait(2);
    console.log("approved", addresses[0], addresses[1]);
  }
};

export default func;

func.tags = ["exchangeHelpers"];
