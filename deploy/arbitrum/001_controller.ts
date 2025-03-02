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
  const timeLockAddress = "0xf8Bd793A7c9cB86e827C084D49f343F1296a8247"; // meme index deployer for ease
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
