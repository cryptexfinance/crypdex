import { DeployFunction } from "hardhat-deploy/types";
import hre, { hardhatArguments, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
    BasicIssuanceModule__factory,
    AuctionRebalanceModuleV1__factory,
    SetTokenCreator__factory,
    StreamingFeeModule__factory,
    SetToken__factory
} from "../typechain-types";

async function main() {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer, manager } = await getNamedAccounts();
  const deployerSigner: SignerWithAddress = await ethers.getSigner(deployer);
  const managerSigner: SignerWithAddress = await ethers.getSigner(manager);

  const dogeAddress = "0x4206931337dc273a630d328dA6441786BfaD668f";
  const shibAddress = "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE";
  const pepeAddress = "0x6982508145454Ce325dDbE47a25d4ec3d2311933";
  const flokiAddress = "0xcf0C122c6b73ff809C693DB761e7BaeBe62b6a2E";
  const wETHAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

  const teamMultiSigAddress = "0xa70b638B70154EdfCbb8DbbBd04900F328F32c35"
  const treasuryAddress = "0xa54074b2cc0e96a43048d4a68472F7F046aC0DA8";

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
        feeRecipient: treasuryAddress,
        maxStreamingFeePercentage: ethers.utils.parseEther("0.2"),
        streamingFeePercentage: ethers.utils.parseEther("0.0075"),
        lastStreamingFeeTimestamp: (await ethers.provider.getBlock("latest")).timestamp
  }

  const dogeQuantity = ethers.BigNumber.from("1870907391");               // math.ceil((2 * 10 ** 8)/0.1069)
  const shibQuantity = ethers.BigNumber.from("122850122850122843815936"); // math.ceil((2 * 10 ** 18)/0.00001628)
  const pepeQuantity = ethers.BigNumber.from("221827861579414378643456"); // math.ceil((2 * 10 ** 18)/0.000009016)
  const flokiQuantity = ethers.BigNumber.from("13831258644537");          // math.ceil((2 * 10 ** 9)/0.0001446)
  const wethQuantity = ethers.BigNumber.from("643616610457483");          // math.ceil((2 * 10 ** 18)/3107.44)

  const dogeAddress = "0x4206931337dc273a630d328dA6441786BfaD668f";
  const shibAddress = "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE";
  const pepeAddress = "0x6982508145454Ce325dDbE47a25d4ec3d2311933";
  const flokiAddress = "0xcf0C122c6b73ff809C693DB761e7BaeBe62b6a2E";
  const wETHAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

  let tx = await setTokenCreator.create(
    [dogeAddress, shibAddress, pepeAddress, flokiAddress, wETHAddress],
    [dogeQuantity, shibQuantity, pepeQuantity, flokiQuantity, wethQuantity],
    [basicIssuanceModuleDeployment.address, streamingFeeModuleDeployment.address, auctionRebalanceModuleDeployment.address],
    manager,
    "Cryptex Meme Index",
    "MEMEX"
  )
  console.log(tx);
  let lx = await tx.wait();
  const setTokenAddress =  lx.events[1].args[0];

  const memeIndex = new SetToken__factory(managerSigner).attach(
    setTokenAddress
  )

  tx = await streamingFeeModule.initialize(setTokenAddress, feeSettings);
  console.log(tx);
  await tx.wait();

  tx = await basicIssuanceModule.initialize(setTokenAddress, ethers.constants.AddressZero);
  console.log(tx);
  await tx.wait();

  tx = await auctionRebalanceModule.initialize(setTokenAddress);
  console.log(tx);
  await tx.wait();

  tx = await memeIndex.setManager(teamMultiSigAddress);
  console.log(tx);
  await tx.wait();
};


main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});