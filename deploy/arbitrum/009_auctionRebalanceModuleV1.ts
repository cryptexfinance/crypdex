import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { hardhatArguments } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (hardhatArguments.network !== "arbitrum") {
    return;
  }

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const controllerDeployment = await deployments.get("Controller");

  await deploy("AuctionRebalanceModuleV1", {
    from: deployer,
    args: [controllerDeployment.address],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });
};

export default func;

func.tags = ["auctionRebalanceModuleV1"];
func.dependencies = ["controller"];
