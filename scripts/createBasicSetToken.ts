import { DeployFunction } from "hardhat-deploy/types";
import hre, { hardhatArguments, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
    BasicIssuanceModule__factory,
    AuctionRebalanceModuleV1__factory,
    SetTokenCreator__factory,
    StreamingFeeModule__factory
} from "../typechain-types";

async function main() {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer, manager } = await getNamedAccounts();
  const deployerSigner: SignerWithAddress = await ethers.getSigner(deployer);
  const managerSigner: SignerWithAddress = await ethers.getSigner(manager);

  const wETHDeployment = await deployments.get("WETH9");
  const wBTCDeployment = await deployments.get("wBTC");
  const DAIDeployment = await deployments.get("DAI");
  const setTokenCreatorDeployment = await deployments.get("SetTokenCreator");
  const basicIssuanceModuleDeployment = await deployments.get("BasicIssuanceModule");
  const streamingFeeModuleDeployment = await deployments.get("StreamingFeeModule");
  const integrationRegistryDeployment = await deployments.get("IntegrationRegistry");
  const auctionRebalanceModuleDeployment = await deployments.get("AuctionRebalanceModuleV1");
  const priceOracleDeployment = await deployments.get("PriceOracle");
  const setValuerDeployment = await deployments.get("SetValuer");

  const setTokenCreator = new SetTokenCreator__factory(managerSigner).attach(
    setTokenCreatorDeployment.address
  );

  const streamingFeeModule = new StreamingFeeModule__factory(managerSigner).attach(
    streamingFeeModuleDeployment.address
  );

  const basicIssuanceModule = new BasicIssuanceModule__factory(managerSigner).attach(
    basicIssuanceModuleDeployment.address
  );

  const auctionRebalanceModule = new AuctionRebalanceModuleV1__factory(managerSigner).attach(
    auctionRebalanceModuleDeployment.address
  );

  const feeSettings =  {
        feeRecipient: manager,
        maxStreamingFeePercentage: ethers.utils.parseEther("0.1"),
        streamingFeePercentage: ethers.utils.parseEther("0.01"),
        lastStreamingFeeTimestamp: 0
  }

  let tx = await setTokenCreator.create(
    [wETHDeployment.address, wBTCDeployment.address],
    [ethers.utils.parseEther("1"), 10 ** 8],
    [basicIssuanceModuleDeployment.address, streamingFeeModuleDeployment.address, auctionRebalanceModuleDeployment.address],
    manager,
    "Top 2",
    "T2"
  )
  console.log(tx);
  let lx = await tx.wait();
  const setTokenAddress =  lx.events[1].args[0];

  tx = await streamingFeeModule.initialize(setTokenAddress, feeSettings);
  console.log(tx);
  await tx.wait();

  tx = await basicIssuanceModule.initialize(setTokenAddress, ethers.constants.AddressZero);
  console.log(tx);
  await tx.wait();

  tx = await auctionRebalanceModule.initialize(setTokenAddress);
  console.log(tx);
  await tx.wait();

  tx = await auctionRebalanceModule.setAnyoneBid(setTokenAddress, true);
  console.log(tx);
  await tx.wait();
};


main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});