import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { hardhatArguments, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {Controller__factory,} from "../../typechain-types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (hardhatArguments.network !== "baseSepolia") {
    return;
  }

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const controllerDeployment = await deployments.get("Controller");
  const deployerSigner: SignerWithAddress = await ethers.getSigner(deployer);

  const controller = new Controller__factory(deployerSigner).attach(
    controllerDeployment.address
  );

  const setTokenCreatorDeployment = await deployments.get("SetTokenCreator");
  const basicIssuanceModuleDeployment = await deployments.get("BasicIssuanceModule");
  const streamingFeeModuleDeployment = await deployments.get("StreamingFeeModule");
  const integrationRegistryDeployment = await deployments.get("IntegrationRegistry");
  const auctionRebalanceModuleDeployment = await deployments.get("AuctionRebalanceModuleV1");
  const priceOracleDeployment = await deployments.get("PriceOracle");
  const setValuerDeployment = await deployments.get("SetValuer");

  let tx = await controller.initialize(
    [setTokenCreatorDeployment.address],
    [basicIssuanceModuleDeployment.address, streamingFeeModuleDeployment.address, auctionRebalanceModuleDeployment.address],
    [integrationRegistryDeployment.address, priceOracleDeployment.address, setValuerDeployment.address],
    [0, 1, 2]
  );
  console.log(tx);
  await tx.wait();

};

export default func;

func.tags = ["initController"];
