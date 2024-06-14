import hre from "hardhat";


async function main() {
  const { deployments } = hre;
  const contracts = await deployments.all();
  const contractNames = Object.keys(contracts);
  contractNames.map( async(contractName)  => {
    console.log(`verifying ${contracts[contractName].address}`)
    await hre.run("verify:verify", {
      address: contracts[contractName].address,
      constructorArguments: contracts[contractName].args
    });
    console.log(`verified ${contracts[contractName].address}`)
  });
};


main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});