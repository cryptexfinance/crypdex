import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { hardhatArguments } from "hardhat";
import { utils } from "ethers";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (hardhatArguments.network !== "sepolia") {
    return;
  }

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const controllerDeployment = await deployments.get("Controller");
  const wETHDeployment = await deployments.get("WETH9");
  const usdcDeployment = await deployments.get("USDC");
  const wBTCDeployment = await deployments.get("wBTC");
  const daiDeployment = await deployments.get("DAI");
  const wETHOracleDeployment = await deployments.get("ETHOracle");
  const usdcOracleDeployment = await deployments.get("USDCOracle");
  const wBTCOracleDeployment = await deployments.get("wBTCOracle");
  const daiOracleDeployment = await deployments.get("DAIOracle");


  await deploy("PriceOracle", {
    from: deployer,
    args: [
        controllerDeployment.address,
        usdcDeployment.address,
        [],
        [wETHDeployment.address, usdcDeployment.address, wBTCDeployment.address, daiDeployment.address],
        [usdcDeployment.address, usdcDeployment.address, usdcDeployment.address, usdcDeployment.address],
        [wETHOracleDeployment.address, usdcOracleDeployment.address, wBTCOracleDeployment.address, daiOracleDeployment.address]
    ],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });


};

export default func;

func.tags = ["priceOracle"];
