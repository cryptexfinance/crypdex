import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { hardhatArguments } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (hardhatArguments.network !== "baseSepolia") {
    return;
  }

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("BoundedStepwiseExponentialPriceAdapter", {
    from: deployer,
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("BoundedStepwiseLinearPriceAdapter", {
    from: deployer,
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("BoundedStepwiseLogarithmicPriceAdapter", {
    from: deployer,
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("ConstantPriceAdapter", {
    from: deployer,
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

};

export default func;

func.tags = ["priceAdapters"];
func.dependencies = ['auctionRebalanceModuleV1'];
