import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { hardhatArguments } from "hardhat";
import { utils } from "ethers";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (hardhatArguments.network !== "arbitrum") {
    return;
  }

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const pythContract = "0xff1a0f4744e8582DF1aE09D5611b887B6a12925C";
  const aavePriceId =
    "0x2b9ab1e972a281585084148ba1389800799bd4be63b957507db1349314e47445";
  const gmxPriceId =
    "0xb962539d0fcb272a494d65ea56f94851c2bcf8823935da05bd628916e2e9edbf";
  const uniPriceId =
    "0x78d185a741d07edb3412b09008b7c5cfb9bbbd7d568bf00ba737b456ba171501";
  const grailPriceId =
    "0x48f3736d94693aa73c11214c4176ba7f997a8329f4dbc3854c4b2686861132ce";
  const pendlePriceId =
    "0x9a4df90b25497f66b1afb012467e316e801ca3d839456db028892fe8c70c8016";
  const stgPriceId =
    "0x008546b175392b878c5c7ff0b6327b1cb12669be012fc2935c09a16fc8f6c58f";
  const crvPriceId =
    "0xa19d04ac696c7a6616d291c7e5d1377cc8be437c327b75adb5dc1bad745fcae8";
  const usdcPriceId =
    "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a";

  await deploy("AavePythOracle", {
    from: deployer,
    contract: "PythOracle",
    args: [pythContract, aavePriceId],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("GmxPythOracle", {
    from: deployer,
    contract: "PythOracle",
    args: [pythContract, gmxPriceId],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("UniPythOracle", {
    from: deployer,
    contract: "PythOracle",
    args: [pythContract, uniPriceId],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("GrailPythOracle", {
    from: deployer,
    contract: "PythOracle",
    args: [pythContract, grailPriceId],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("PendlePythOracle", {
    from: deployer,
    contract: "PythOracle",
    args: [pythContract, pendlePriceId],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("StgPythOracle", {
    from: deployer,
    contract: "PythOracle",
    args: [pythContract, stgPriceId],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("CrvPythOracle", {
    from: deployer,
    contract: "PythOracle",
    args: [pythContract, crvPriceId],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

  await deploy("UsdcPythOracle", {
    from: deployer,
    contract: "PythOracle",
    args: [pythContract, usdcPriceId],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });
};

export default func;

func.tags = ["pythOracles"];
