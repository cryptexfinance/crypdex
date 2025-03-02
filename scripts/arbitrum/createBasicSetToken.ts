// npx hardhat run scripts/arbitrum/createBasicSetToken.ts --network arbitrum

import { DeployFunction } from "hardhat-deploy/types";
import hre, { hardhatArguments, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  BasicIssuanceModule__factory,
  AuctionRebalanceModuleV1__factory,
  SetTokenCreator__factory,
  StreamingFeeModule__factory,
  SetToken__factory,
} from "../../typechain-types";

async function main() {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer, manager } = await getNamedAccounts();
  const deployerSigner: SignerWithAddress = await ethers.getSigner(deployer);

  const aave = "0xba5DdD1f9d7F570dc94a51479a000E3BCE967196";
  const gmx = "0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a";
  const uni = "0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0";
  const grail = "0x3d9907F9a368ad0a51Be60f7Da3b97cf940982D8";
  const pendle = "0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8";
  const stg = "0x6694340fc020c5E6B96567843da2df01b2CE1eb6";
  const crv = "0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978";

  const managerAddress = "0xf8Bd793A7c9cB86e827C084D49f343F1296a8247";
  const treasuryAddress = "0x9474B771Fb46E538cfED114Ca816A3e25Bb346CF";

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

  const setTokenCreator = new SetTokenCreator__factory(deployerSigner).attach(
    setTokenCreatorDeployment.address,
  );

  const streamingFeeModule = new StreamingFeeModule__factory(
    deployerSigner,
  ).attach(streamingFeeModuleDeployment.address);

  const basicIssuanceModule = new BasicIssuanceModule__factory(
    deployerSigner,
  ).attach(basicIssuanceModuleDeployment.address);

  const auctionRebalanceModule = new AuctionRebalanceModuleV1__factory(
    deployerSigner,
  ).attach(auctionRebalanceModuleDeployment.address);

  const feeSettings = {
    feeRecipient: treasuryAddress,
    maxStreamingFeePercentage: ethers.utils.parseEther("0.2"),
    streamingFeePercentage: ethers.utils.parseEther("0.0075"),
    lastStreamingFeeTimestamp: (await ethers.provider.getBlock("latest"))
      .timestamp,
  };

  const aaveQuantity = ethers.BigNumber.from("3643199603619883"); // math.ceil((5 * 10 ** 18)/(7 * 196.06))
  const gmxQuantity = ethers.BigNumber.from("40196157247367152"); // math.ceil((5 * 10 ** 18)/(7 * 17.77))
  const uniQuantity = ethers.BigNumber.from("94858660595712384"); // math.ceil((5 * 10 ** 18)/(7 * 7.53))
  const grailQuantity = ethers.BigNumber.from("1421973471662913"); // math.ceil((5 * 10 ** 18)/(7 * 502.32))
  const pendleQuantity = ethers.BigNumber.from("252397778899545664"); // math.ceil((5 * 10 ** 18)/(7 * 2.83))
  const stgQuantity = ethers.BigNumber.from("2840102243680772608"); // math.ceil((5 * 10 ** 18)/(7 * 0.2515))
  const crvQuantity = ethers.BigNumber.from("1651527663088356864"); // math.ceil((5 * 10 ** 18)/(7 * 0.4325))

  let tx = await setTokenCreator.create(
    [aave, gmx, uni, grail, pendle, stg, crv],
    [
      aaveQuantity,
      gmxQuantity,
      uniQuantity,
      grailQuantity,
      pendleQuantity,
      stgQuantity,
      crvQuantity,
    ],
    [
      basicIssuanceModuleDeployment.address,
      streamingFeeModuleDeployment.address,
      auctionRebalanceModuleDeployment.address,
    ],
    deployer,
    "Cryptex ArbFI Index",
    "ARBFI",
  );
  console.log(tx);
  let receipt = await tx.wait(2);
  const setTokenAddress = receipt.events[1].args[0];

  await deployments.save("ArbFIIndexToken", {
    address: setTokenAddress,
    receipt,
  });

  const arbFIIndex = new SetToken__factory(deployerSigner).attach(
    setTokenAddress,
  );

  tx = await streamingFeeModule.initialize(setTokenAddress, feeSettings);
  console.log(tx);
  await tx.wait(2);

  tx = await basicIssuanceModule.initialize(
    setTokenAddress,
    ethers.constants.AddressZero,
  );
  console.log(tx);
  await tx.wait(2);

  tx = await auctionRebalanceModule.initialize(setTokenAddress);
  console.log(tx);
  await tx.wait(2);

  tx = await arbFIIndex.setManager(managerAddress);
  console.log(tx);
  await tx.wait(2);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
