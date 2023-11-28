import hre, { ethers } from 'hardhat';
import fs from 'fs';
import dotenv from 'dotenv';

async function main() {
	const net = hre.network.name;

	const config = dotenv.parse(fs.readFileSync(`.env-${net}`));
	for (const parameter in config) {
		process.env[parameter] = config[parameter];
	}
	const link = await ethers.getContractAt("LinkToken", config.LINK_ADDRESS)
	await link.transferAndCall(
		config.VRF_COORDINATOR_ADDRESS,
		ethers.utils.parseEther("40"),
		ethers.utils.defaultAbiCoder.encode(["uint64"], [config.VRF_SUBSCRIPTION_ID])
	)
}

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
