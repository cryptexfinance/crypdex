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
  const controllerDeployment = await deployments.get("Controller");

  const aaveAddress = "0xba5DdD1f9d7F570dc94a51479a000E3BCE967196";
  const gmxAddress = "0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a";
  const uniAddress = "0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0";
  const grailAddress = "0x3d9907F9a368ad0a51Be60f7Da3b97cf940982D8";
  const pendleAddress = "0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8";
  const StgAddress = "0x6694340fc020c5E6B96567843da2df01b2CE1eb6";
  const CrvAddress = "0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978";

  const usdcAddress = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831";

  const aaveOracleDeployment = await deployments.get("AavePythOracle");
  const gmxOracleDeployment = await deployments.get("GmxPythOracle");
  const uniOracleDeployment = await deployments.get("UniPythOracle");
  const grailOracleDeployment = await deployments.get("GrailPythOracle");
  const PendleOracleDeployment = await deployments.get("PendlePythOracle");
  const stgOracleDeployment = await deployments.get("StgPythOracle");
  const CrvOracleDeployment = await deployments.get("CrvPythOracle");

  await deploy("PriceOracle", {
    from: deployer,
    args: [
      controllerDeployment.address,
      usdcAddress,
      [],
      [
        aaveAddress,
        gmxAddress,
        uniAddress,
        grailAddress,
        pendleAddress,
        StgAddress,
        CrvAddress,
      ],
      [
        usdcAddress,
        usdcAddress,
        usdcAddress,
        usdcAddress,
        usdcAddress,
        usdcAddress,
        usdcAddress,
      ],
      [
        aaveOracleDeployment.address,
        gmxOracleDeployment.address,
        uniOracleDeployment.address,
        grailOracleDeployment.address,
        PendleOracleDeployment.address,
        stgOracleDeployment.address,
        CrvOracleDeployment.address,
      ],
    ],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });
};

export default func;

func.tags = ["priceOracle"];
