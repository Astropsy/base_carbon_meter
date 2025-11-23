// marketplace-p2p/scripts/acceptOffer.js
const hre = require("hardhat");

/**
 * acceptOffer.js
 *
 * Seller accepts an existing offer by ID.
 *
 * Usage:
 *   npx hardhat run marketplace-p2p/scripts/acceptOffer.js --network base <offerId>
 *
 * Example:
 *   npx hardhat run marketplace-p2p/scripts/acceptOffer.js --network base 1
 */

async function main() {
  const [seller] = await hre.ethers.getSigners();

  const MARKETPLACE_ADDRESS = process.env.MARKETPLACE_ADDRESS || "0xYOUR_MARKETPLACE";

  const offerIdArg = process.argv[2];
  if (!offerIdArg) {
    console.log("\nUsage:");
    console.log("  npx hardhat run marketplace-p2p/scripts/acceptOffer.js --network base <offerId>\n");
    process.exit(1);
  }

  const offerId = Number(offerIdArg);

  console.log("\n👤 Seller (must match listing.seller):", seller.address);

  const Marketplace = await hre.ethers.getContractAt("CarbonMarketplace", MARKETPLACE_ADDRESS, seller);

  console.log(`\n⏳ Sending acceptOffer(${offerId}) transaction...`);

  // We can't see internal Offer details (mapping is private),
  // but the contract will enforce:
  //  - msg.sender == listing.seller
  //  - listing & offer are active.
  const tx = await Marketplace.acceptOffer(offerId);
  const receipt = await tx.wait();

  console.log("\n✅ Offer accepted!");
  console.log("  Offer ID:", offerId);
  console.log("  Tx hash:", receipt.hash, "\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
