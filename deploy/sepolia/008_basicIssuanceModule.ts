import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { hardhatArguments } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (hardhatArguments.network !== "sepolia") {
    return;
  }

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const controllerDeployment = await deployments.get("Controller");

  await deploy("BasicIssuanceModule", {
    from: deployer,
    args: [controllerDeployment.address,],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });


};

export default func;

func.tags = ["basicIssuanceModule"];
