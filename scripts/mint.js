// scripts/mint.js
const hre = require("hardhat");

/**
 * mint.js
 *
 * In this script we simulate a full flow:
 * - attach to our deployed BaseCarbonToken + CarbonSmartMeter
 * - register a demo device
 * - send a fake verified energy reading (milli-kWh)
 * - let the smart meter mint BaseCarbon (BC) based on 2.5 kWh = 1 BC
 * - read back our BC balance and approximate USD value using Chainlink
 *
 * This is our main "demo script" to prove that all pieces work together.
 */

async function main() {
  const [signer] = await hre.ethers.getSigners();

  // Paste from deploy.js output
  const TOKEN_ADDRESS = "0xE16168caD36cd907dcd8f402Db5Da47a2207a216";
  const METER_ADDRESS = "0xB173f071DDBE0D6B17C424BD199FB10c9226b19c";

  const Token = await hre.ethers.getContractAt("BaseCarbonToken", TOKEN_ADDRESS);
  const Meter = await hre.ethers.getContractAt("CarbonSmartMeter", METER_ADDRESS);

  console.log("\n👤 Using wallet:", signer.address);

  // 1) Check Chainlink price first (via inherited OracleConsumer)
  const [price, decimals] = await Meter.getLatestPrice();
  const uniPrice = Number(price) / 10 ** decimals;

  console.log("\n✅ Chainlink UNI/USD price (via OracleConsumer):");
  console.log("   Raw:", price.toString());
  console.log("   Decimals:", decimals);
  console.log("   Human:", uniPrice, "USD");

  // 2) Register a demo device (one-time per device id)
  const deviceId = hre.ethers.keccak256(
    hre.ethers.toUtf8Bytes("demo-device-001")
  );

  console.log("\n🛠 Registering demo device:", deviceId);

  const registerTx = await Meter.registerDevice(deviceId, signer.address);
  await registerTx.wait();

  console.log("✅ Device registered and bound to our wallet");

  // 3) Submit a fake verified reading (5 kWh = 5000 milli-kWh)
  const fakeReadingMilliKwh = 5000;

  console.log(
    "\n⚡ Sending fake verified reading:",
    fakeReadingMilliKwh,
    "milli-kWh (5 kWh)"
  );

  const readingTx = await Meter.recordVerifiedReading(
    deviceId,
    fakeReadingMilliKwh
  );
  await readingTx.wait();

  console.log("✅ Verified reading recorded on-chain");

  // 4) Check our BC balance
  const balance = await Token.balanceOf(signer.address);
  const balanceBC = hre.ethers.formatUnits(balance, 18);

  console.log("\n💰 BaseCarbon (BC) balance after reading:");
  console.log("   Raw:", balance.toString());
  console.log("   Human:", balanceBC, "BC");

  // 5) Check estimated USD value of our offsets
  const usdValue = await Meter.getWalletOffsetValueUSD(signer.address);
  const usdHuman = Number(usdValue) / 10 ** decimals;

  console.log("\n💵 Estimated USD value of our BC (using UNI/USD as proxy):");
  console.log("   Raw:", usdValue.toString());
  console.log("   Human (approx):", usdHuman, "USD");

  console.log("\n---- MINT FLOW COMPLETE ----\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});