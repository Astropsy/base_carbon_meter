// marketplace-p2p/scripts/listOffsets.js
const hre = require("hardhat");

/**
 * List BC tokens for sale on CarbonMarketplace
 *
 * Usage:
 *   npx hardhat run marketplace-p2p/scripts/listOffsets.js --network base 10 0.1
 *
 *   -> lists 10 BC for 0.1 ETH total
 */

async function main() {
  const [seller] = await hre.ethers.getSigners();

  const MARKETPLACE_ADDRESS = process.env.MARKETPLACE_ADDRESS || "0xYOUR_MARKETPLACE";
  const TOKEN_ADDRESS = process.env.TOKEN_ADDRESS || "0xYOUR_BC_TOKEN";

  const amountArg = process.argv[2];
  const priceEthArg = process.argv[3];

  if (!amountArg || !priceEthArg) {
    console.log("\nUsage:");
    console.log("  npx hardhat run marketplace-p2p/scripts/listOffsets.js --network base <amountBC> <lotPriceEth>");
    console.log("Example:");
    console.log("  npx hardhat run ... 10 0.1  # 10 BC for 0.1 ETH\n");
    process.exit(1);
  }

  console.log("\n👤 Seller:", seller.address);

  const Token = await hre.ethers.getContractAt("BaseCarbonToken", TOKEN_ADDRESS, seller);
  const Marketplace = await hre.ethers.getContractAt("CarbonMarketplace", MARKETPLACE_ADDRESS, seller);

  const decimals = Number(await Token.decimals());

  const amountBC = hre.ethers.parseUnits(amountArg, decimals);   // BC amount (with decimals)
  const lotPriceWei = hre.ethers.parseEther(priceEthArg);        // total price in ETH (wei)

  console.log(`\n📝 Creating listing:`);
  console.log(`  Amount:      ${amountArg} BC`);
  console.log(`  Total price: ${priceEthArg} ETH`);
  console.log(`  Marketplace: ${MARKETPLACE_ADDRESS}`);
  console.log(`  Token:       ${TOKEN_ADDRESS}`);

  // 1) Approve marketplace to pull BC from seller
  const approveTx = await Token.approve(MARKETPLACE_ADDRESS, amountBC);
  console.log("\n⏳ Approving marketplace to spend BC...");
  await approveTx.wait();
  console.log("✅ Approved.");

  // 2) Create listing
  const tx = await Marketplace.createListing(amountBC, lotPriceWei);
  console.log("\n⏳ Creating listing on-chain...");
  const receipt = await tx.wait();

  // Read the new listing id from event or listingCounter
  const listingCounter = await Marketplace.listingCounter();
  console.log("\n✅ Listing created!");
  console.log("  Listing ID:", listingCounter.toString());
  console.log("  Tx hash:   ", receipt.hash, "\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});