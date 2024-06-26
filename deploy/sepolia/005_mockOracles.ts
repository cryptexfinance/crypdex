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

  await deploy("ETHOracle", {
    from: deployer,
    contract: "MockOracle",
    args: [utils.parseEther("3601.65")],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

   await deploy("USDCOracle", {
    from: deployer,
    contract: "MockOracle",
    args: [utils.parseEther("1")],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("wBTCOracle", {
    from: deployer,
    contract: "MockOracle",
    args: [utils.parseEther("69595.70")],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("DAIOracle", {
    from: deployer,
    contract: "MockOracle",
    args: [utils.parseEther("1")],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

};

export default func;

func.tags = ["mockOracles"];
