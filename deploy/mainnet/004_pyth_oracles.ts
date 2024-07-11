import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { hardhatArguments } from "hardhat";
import { utils } from "ethers";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (hardhatArguments.network !== "mainnet") {
    return;
  }

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const pythContract = "0x4305FB66699C3B2702D4d05CF36551390A4c69C6";
  const dogePriceId = "0xdcef50dd0a4cd2dcc17e45df1676dcb336a11a61c69df7a0299b0150c672d25c";
  const shibPriceId = "0xf0d57deca57b3da2fe63a493f4c25925fdfd8edf834b20f93e1f84dbd1504d4a";
  const pepePriceId = "0xd69731a2e74ac1ce884fc3890f7ee324b6deb66147055249568869ed700882e4";
  const flokiPriceId = "0x6b1381ce7e874dc5410b197ac8348162c0dd6c0d4c9cd6322672d6c2b1d58293";
  const ethPriceId = "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace";

  await deploy("DogePythOracle", {
    from: deployer,
    contract: "PythOracle",
    args: [pythContract, dogePriceId],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("ShibPythOracle", {
    from: deployer,
    contract: "PythOracle",
    args: [pythContract, shibPriceId],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("PepePythOracle", {
    from: deployer,
    contract: "PythOracle",
    args: [pythContract, pepePriceId],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("FlokiPythOracle", {
    from: deployer,
    contract: "PythOracle",
    args: [pythContract, flokiPriceId],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("EthPythOracle", {
    from: deployer,
    contract: "PythOracle",
    args: [pythContract, ethPriceId],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

};

export default func;

func.tags = ["pythOracles"];
