// marketplace-p2p/scripts/buyOffsets.js
const hre = require("hardhat");

/**
 * Buy a full listing via buyNow(listingId)
 *
 * Usage:
 *   npx hardhat run marketplace-p2p/scripts/buyOffsets.js --network base <listingId>
 */

async function main() {
  const [buyer] = await hre.ethers.getSigners();

  const MARKETPLACE_ADDRESS = process.env.MARKETPLACE_ADDRESS || "0xMARKETPLACE";
  const TOKEN_ADDRESS = process.env.TOKEN_ADDRESS || "0x_BC_TOKEN";

  const listingIdArg = process.argv[2];
  if (!listingIdArg) {
    console.log("\nUsage:");
    console.log("  npx hardhat run marketplace-p2p/scripts/buyOffsets.js --network base <listingId>\n");
    process.exit(1);
  }

  const listingId = Number(listingIdArg);

  console.log("\n👤 Buyer:", buyer.address);

  const Marketplace = await hre.ethers.getContractAt("CarbonMarketplace", MARKETPLACE_ADDRESS, buyer);
  const Token = await hre.ethers.getContractAt("BaseCarbonToken", TOKEN_ADDRESS, buyer);

  const decimals = Number(await Token.decimals());

  const listing = await Marketplace.listings(listingId);
  if (!listing.active) {
    console.log(`\n❌ Listing ${listingId} is not active.\n`);
    return;
  }

  const seller     = listing.seller;
  const amountBC   = listing.amountBC;
  const priceEth   = listing.priceEth;

  const amountHuman = Number(amountBC) / 10 ** decimals;
  const priceHuman  = Number(priceEth) / 10 ** 18;

  console.log(`\n🛒 Buying listing ${listingId}:`);
  console.log(`  Seller:  ${seller}`);
  console.log(`  Amount:  ${amountHuman} BC`);
  console.log(`  Price:   ${priceHuman} ETH`);

  // Confirm purchase (optional – for hackathon UX just proceed)
  console.log("\n⏳ Sending buyNow transaction...");

  const tx = await Marketplace.buyNow(listingId, { value: priceEth });
  const receipt = await tx.wait();

  console.log("\n✅ Purchase complete!");
  console.log("  Tx hash:", receipt.hash, "\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});