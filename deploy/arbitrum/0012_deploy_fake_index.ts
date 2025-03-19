// use this script to get the set token verified

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { hardhatArguments } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (hardhatArguments.network !== "arbitrum") {
    return;
  }

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  let ags = [
    [
      "0xba5DdD1f9d7F570dc94a51479a000E3BCE967196",
      "0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a",
      "0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0",
      "0x3d9907F9a368ad0a51Be60f7Da3b97cf940982D8",
      "0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8",
      "0x6694340fc020c5E6B96567843da2df01b2CE1eb6",
      "0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978",
    ],
    [
      "3643199603619883",
      "40196157247367152",
      "94858660595712384",
      "1421973471662913",
      "252397778899545664",
      "2840102243680772608",
      "1651527663088356864",
    ],
    [
      "0x99c1AbfD91C7b0d43865316eF2BCa614237bEB2A",
      "0x9330d0F979af5c8a5f2380f7bc41234A7d8A15de",
      "0x5870f88b5464AbE5E50a271d8377e953E46F398b",
    ],
    "0x15f9cec1c568352Cd48Da1E84D3e74F27f6ee160",
    "0xf8Bd793A7c9cB86e827C084D49f343F1296a8247",
    "Cryptex ArbFI Index",
    "ARBFI",
  ];

  await deploy("FakeIndex", {
    contract: "SetToken",
    from: deployer,
    args: ags,
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });
};

export default func;

func.tags = ["fakeIndex"];
