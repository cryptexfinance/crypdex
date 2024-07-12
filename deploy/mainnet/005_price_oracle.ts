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
  const controllerDeployment = await deployments.get("Controller");

  const dogeAddress = "0x4206931337dc273a630d328dA6441786BfaD668f";
  const shibAddress = "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE";
  const pepeAddress = "0x6982508145454Ce325dDbE47a25d4ec3d2311933";
  const flokiAddress = "0xcf0C122c6b73ff809C693DB761e7BaeBe62b6a2E";
  const wETHAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  const usdcAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

  const dogeOracleDeployment = await deployments.get("DogePythOracle");
  const shibOracleDeployment = await deployments.get("ShibPythOracle");
  const pepeOracleDeployment = await deployments.get("PepePythOracle");
  const flokiOracleDeployment = await deployments.get("FlokiPythOracle");
  const wethOracleDeployment = await deployments.get("EthPythOracle");

  await deploy("PriceOracle", {
    from: deployer,
    args: [
        controllerDeployment.address,
        usdcAddress,
        [],
        [dogeAddress, shibAddress, pepeAddress, flokiAddress, wETHAddress],
        [usdcAddress, usdcAddress, usdcAddress, usdcAddress, usdcAddress],
        [dogeOracleDeployment.address, shibOracleDeployment.address, pepeOracleDeployment.address, flokiOracleDeployment.address, wethOracleDeployment.address]
    ],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });


};

export default func;

func.tags = ["priceOracle"];
