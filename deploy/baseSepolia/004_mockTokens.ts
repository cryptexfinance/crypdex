import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { hardhatArguments } from "hardhat";
import { utils } from "ethers";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (hardhatArguments.network !== "baseSepolia") {
    return;
  }

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("WETH9", {
    from: deployer,
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("USDC", {
    from: deployer,
    contract: "MockERC20",
    args: [deployer, 10000000 * 10 ** 6, "USDC", "USDC", 6],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("wBTC", {
    from: deployer,
    contract: "MockERC20",
    args: [deployer, 10000000 * 10 ** 8, "Wrapped BTC", "WBTC", 8],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("DAI", {
    from: deployer,
    contract: "MockERC20",
    args: [deployer, utils.parseEther("10000000"), "DAI", "DAI", 18],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

};

export default func;

func.tags = ["mockTokens"];
