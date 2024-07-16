import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { hardhatArguments } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (hardhatArguments.network !== "mainnet") {
    return;
  }

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const timeLockAddress = "0xa54074b2cc0e96a43048d4a68472F7F046aC0DA8";
  console.log(deployer);

  await deploy("Controller", {
    from: deployer,
    args: [timeLockAddress],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });
};

export default func;

func.tags = ["controller"];
