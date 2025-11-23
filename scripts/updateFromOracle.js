// scripts/updateFromOracle.js
const hre = require("hardhat");

/**
 * updateFromOracle.js
 *
 * - attaches to deployed CarbonSmartMeter
 * - reads stub oracle price (100e8, 8)
 * - reads wallet USD valuation
 *
 * No state changes — pure read-only checks.
 */

async function main() {
  const [signer] = await hre.ethers.getSigners();

  // Paste the new deployed meter address here:
  const METER_ADDRESS = "0x0b1d636E1DdED352e850F8763786aBa87f6ed5e4";

  const Meter = await hre.ethers.getContractAt("CarbonSmartMeter", METER_ADDRESS);

  console.log("\n👤 Using wallet (read-only):", signer.address);

  // ------------------------------------------------------------------
  // 1) Latest price (from stub oracle)
  // ------------------------------------------------------------------
  const result = await Meter.getLatestPrice(); 
  const price = result[0];         // BigInt
  const decimals = Number(result[1]); // Number

  // Convert to JS number for display ONLY — safe because stub is small
  const humanPrice = Number(price) / 10 ** decimals;

  console.log("\n✅ Latest price from stub oracle:");
  console.log("   Raw:", price.toString());
  console.log("   Decimals:", decimals);
  console.log("   Human:", humanPrice, "USD");

  // ------------------------------------------------------------------
  // 2) USD valuation of wallet offsets
  // ------------------------------------------------------------------
  const usdValue = await Meter.getWalletOffsetValueUSD(signer.address); // BigInt

  // This is safe — value is <= 1e36 in worst case
  const usdHuman = Number(usdValue) / 10 ** decimals;

  console.log("\n✅ Wallet offset valuation:");
  console.log("   Raw:", usdValue.toString());
  console.log("   Human:", usdHuman, "USD (approx)");

  console.log("\n---- ORACLE CHECK COMPLETE ----\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});