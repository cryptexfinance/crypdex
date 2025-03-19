// npx hardhat run scripts/arbitrum/initializeController.ts --network arbitrum
import { DeployFunction } from "hardhat-deploy/types";
import hre, { hardhatArguments, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Controller__factory } from "../../typechain-types";

async function main() {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const controllerDeployment = await deployments.get("Controller");
  const deployerSigner: SignerWithAddress = await ethers.getSigner(deployer);

  const controller = new Controller__factory(deployerSigner).attach(
    controllerDeployment.address,
  );

  const setTokenCreatorDeployment = await deployments.get("SetTokenCreator");
  const basicIssuanceModuleDeployment = await deployments.get(
    "BasicIssuanceModule",
  );
  const streamingFeeModuleDeployment =
    await deployments.get("StreamingFeeModule");
  const integrationRegistryDeployment = await deployments.get(
    "IntegrationRegistry",
  );
  const auctionRebalanceModuleDeployment = await deployments.get(
    "AuctionRebalanceModuleV1",
  );
  const priceOracleDeployment = await deployments.get("PriceOracle");
  const setValuerDeployment = await deployments.get("SetValuer");

  let tx = await controller.initialize(
    [setTokenCreatorDeployment.address],
    [
      basicIssuanceModuleDeployment.address,
      streamingFeeModuleDeployment.address,
      auctionRebalanceModuleDeployment.address,
    ],
    [
      integrationRegistryDeployment.address,
      priceOracleDeployment.address,
      setValuerDeployment.address,
    ],
    [0, 1, 2],
  );
  console.log(tx);
  await tx.wait();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
