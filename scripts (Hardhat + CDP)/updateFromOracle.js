// scripts/updateFromOracle.js
const hre = require("hardhat");

/**
 * updateFromOracle.js
 *
 * Here we:
 * - attach to our deployed CarbonSmartMeter
 * - read the latest UNI/USD price via Chainlink
 * - read the USD value of our BaseCarbon (BC) for the current wallet
 *
 * This script does not change state – it's just how we check that our
 * Chainlink integration is wired correctly and our valuation math behaves.
 */

async function main() {
  const [signer] = await hre.ethers.getSigners();

  // Paste from deploy.js output
  const METER_ADDRESS = "PASTE_METER_ADDRESS_HERE";

  const Meter = await hre.ethers.getContractAt("CarbonSmartMeter", METER_ADDRESS);

  console.log("\n👤 Using wallet (read-only):", signer.address);

  // 1) Latest UNI/USD price
  const [price, decimals] = await Meter.getLatestPrice();
  const uniPrice = Number(price) / 10 ** decimals;

  console.log("\n✅ Latest UNI/USD price from Chainlink:");
  console.log("   Raw:", price.toString());
  console.log("   Decimals:", decimals);
  console.log("   Human:", uniPrice, "USD");

  // 2) Current USD value of this wallet's offsets
  const usdValue = await Meter.getWalletOffsetValueUSD(signer.address);
  const usdHuman = Number(usdValue) / 10 ** decimals;

  console.log("\n✅ Estimated USD value of our BaseCarbon for this wallet:");
  console.log("   Raw:", usdValue.toString());
  console.log("   Human (approx):", usdHuman, "USD");

  console.log("\n---- ORACLE CHECK COMPLETE ----\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});