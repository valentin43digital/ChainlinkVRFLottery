import hre, { ethers } from 'hardhat';
import fs from 'fs';

async function main() {
	const net = hre.network.name;

	const TTUSD = await ethers.getContractFactory("TTUSD");
	const ttusd = await TTUSD.deploy(
		"Test True USD",
		"TTUSD"
	)

	// Sync env file
	fs.appendFileSync(
		`.env-${net}`,
		`USDT_ADDRESS=${ttusd.address}\r`
	);
	console.log(`Lottery Token: ${ttusd.address}`);
}

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
