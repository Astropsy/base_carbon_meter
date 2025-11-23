// scripts/deploy.js
const hre = require("hardhat");

/**
 * deploy.js
 *
 * In this script we:
 * - deploy our BaseCarbonToken (BC)
 * - deploy our CarbonSmartMeter logic contract
 * - set CarbonSmartMeter as the ONLY authorized minter for BC
 *
 * We run this once per network (e.g. Base Sepolia) and then
 * paste the addresses into our other scripts for testing.
 */

// Chainlink ETH/USD feed on Base Sepolia (used by OracleConsumer)
const ETH_USD_FEED_BASE_SEPOLIA = "0x201eac7f50f3d21d9a3165b1af6b6dc31c2b1992";

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("\n🚀 Deploying with account:", deployer.address);
  console.log(
    "   Balance:",
    (await deployer.provider.getBalance(deployer.address)).toString()
  );
  console.log("   Using ETH/USD feed (Base Sepolia):", ETH_USD_FEED_BASE_SEPOLIA);

  // 1) Deploy BaseCarbonToken
  const Token = await hre.ethers.getContractFactory("BaseCarbonToken");
  const token = await Token.deploy();
  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();

  console.log("\n✅ BaseCarbonToken deployed at:", tokenAddress);

  // 2) Deploy CarbonSmartMeter (token wired in)
  // NOTE: current CarbonSmartMeter constructor only takes `token` address.
  const CarbonSmartMeter = await hre.ethers.getContractFactory("CarbonSmartMeter");
  const meter = await CarbonSmartMeter.deploy(tokenAddress);
  await meter.waitForDeployment();
  const meterAddress = await meter.getAddress();

  console.log("✅ CarbonSmartMeter deployed at:", meterAddress);

  // 3) Set CarbonSmartMeter as the ONLY minter
  const tx = await token.setMinter(meterAddress);
  await tx.wait();

  console.log("\n✅ Minter for BaseCarbonToken set to CarbonSmartMeter");
  console.log("   Minter address:", meterAddress);

  console.log("\n📝 Paste these into scripts/mint.js and scripts/updateFromOracle.js:");
  console.log("   TOKEN_ADDRESS =", tokenAddress);
  console.log("   METER_ADDRESS =", meterAddress);
  console.log("   ETH_USD_FEED  =", ETH_USD_FEED_BASE_SEPOLIA);
  console.log("\n---- DEPLOY DONE ----\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});