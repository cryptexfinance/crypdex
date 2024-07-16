import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { hardhatArguments } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (hardhatArguments.network !== "sepolia") {
    return;
  }

  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("SetToken", {
    from: deployer,
    args: [
    ["0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE", "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE", "0x6982508145454Ce325dDbE47a25d4ec3d2311933", "0xcf0C122c6b73ff809C693DB761e7BaeBe62b6a2E", "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"],
    ["1870907391", "122850122850122843815936", "221827861579414378643456", "13831258644537", "643616610457483"],
    ["0x9330d0F979af5c8a5f2380f7bc41234A7d8A15de", "0x5870f88b5464AbE5E50a271d8377e953E46F398b", "0x032DE34585bEBC04a0173cc4e5dA5cfEAdFB994e"],
    "0x15f9cec1c568352Cd48Da1E84D3e74F27f6ee160",
    "0xf8Bd793A7c9cB86e827C084D49f343F1296a8247",
    "Cryptex Meme Index",
    "MEEM",
    ],
    skipIfAlreadyDeployed: true,
    log: true,
    autoMine: true,
  });

};

export default func;

func.tags = ["setToken"];

