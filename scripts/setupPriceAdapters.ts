import { DeployFunction } from "hardhat-deploy/types";
import hre, { hardhatArguments, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {IntegrationRegistry__factory,} from "../typechain-types";

async function main() {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const deployerSigner: SignerWithAddress = await ethers.getSigner(deployer);

  const integrationRegistryDeployment = await deployments.get("IntegrationRegistry");
  const auctionRebalanceModuleDeployment = await deployments.get("AuctionRebalanceModuleV1");
  const auctionRebalanceModuleAddress = auctionRebalanceModuleDeployment.address;
  const integrationRegistry = new IntegrationRegistry__factory(deployerSigner).attach(integrationRegistryDeployment.address);

  const constantPriceAdapter = await deployments.get("ConstantPriceAdapter");
  const boundedStepwiseExponentialPriceAdapter = await deployments.get("BoundedStepwiseExponentialPriceAdapter");
  const boundedStepwiseLinearPriceAdapter = await deployments.get("BoundedStepwiseLinearPriceAdapter");
  const boundedStepwiseLogarithmicPriceAdapter = await deployments.get("BoundedStepwiseLogarithmicPriceAdapter");

  let tx = await integrationRegistry.batchAddIntegration(
    [auctionRebalanceModuleAddress, auctionRebalanceModuleAddress, auctionRebalanceModuleAddress, auctionRebalanceModuleAddress],
    ["CONSTANT_PRICE_ADAPTER", "BOUNDED_STEPWISE_EXPONENTIAL_PRICE_ADAPTER", "BOUNDED_STEPWISE_LINEAR_PRICE_ADAPTER", "BOUNDED_STEPWISE_LOGARITHMIC_PRICE_ADAPTER"],
    [constantPriceAdapter.address, boundedStepwiseExponentialPriceAdapter.address, boundedStepwiseLinearPriceAdapter.address, boundedStepwiseLogarithmicPriceAdapter.address]
  );
  console.log(tx);
  await tx.wait();

};


main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});