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
    console.log(deployer);
  await deploy("BurnMintERC677", {
    from: deployer,
    args: ["Cryptex Meme Index", "MEEM", 18, ethers.constants.MaxUint256],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

};

export default func;

func.tags = ["meem_erc677"];

