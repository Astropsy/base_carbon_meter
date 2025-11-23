// marketplace-p2p/scripts/makeOffer.js
const hre = require("hardhat");

/**
 * makeOffer.js
 *
 * Buyer submits an offer for a listing:
 *   - listingId: which listing to target
 *   - amountBC: how many BC they want to buy (human units)
 *   - offerEth: total ETH they're offering (human units)
 *
 * Usage:
 *   npx hardhat run marketplace-p2p/scripts/makeOffer.js --network base <listingId> <amountBC> <offerEth>
 *
 * Example:
 *   npx hardhat run marketplace-p2p/scripts/makeOffer.js --network base 1 10 0.08
 *   -> Offer 0.08 ETH to buy 10 BC on listing #1
 */

async function main() {
  const [buyer] = await hre.ethers.getSigners();

  const MARKETPLACE_ADDRESS = process.env.MARKETPLACE_ADDRESS || "0xMARKETPLACE";
  const TOKEN_ADDRESS = process.env.TOKEN_ADDRESS || "0x_BC_TOKEN";

  const listingIdArg = process.argv[2];
  const amountBCArg = process.argv[3];
  const offerEthArg = process.argv[4];

  if (!listingIdArg || !amountBCArg || !offerEthArg) {
    console.log("\nUsage:");
    console.log("  npx hardhat run marketplace-p2p/scripts/makeOffer.js --network base <listingId> <amountBC> <offerEth>");
    console.log("\nExample:");
    console.log("  npx hardhat run ... 1 10 0.08   # offer 0.08 ETH for 10 BC on listing #1\n");
    process.exit(1);
  }

  const listingId = Number(listingIdArg);

  console.log("\n👤 Buyer:", buyer.address);

  const Marketplace = await hre.ethers.getContractAt("CarbonMarketplace", MARKETPLACE_ADDRESS, buyer);
  const Token = await hre.ethers.getContractAt("BaseCarbonToken", TOKEN_ADDRESS, buyer);

  const decimals = Number(await Token.decimals());

  const amountBC = hre.ethers.parseUnits(amountBCArg, decimals);   // amount of BC with decimals
  const offerWei = hre.ethers.parseEther(offerEthArg);             // ETH offer (wei)

  // Show listing info
  const listing = await Marketplace.listings(listingId);
  if (!listing.active) {
    console.log(`\n❌ Listing ${listingId} is not active.\n`);
    process.exit(1);
  }

  const listAmountHuman = Number(listing.amountBC) / 10 ** decimals;
  const listPriceHuman = Number(listing.priceEth) / 10 ** 18;

  console.log(`\n📋 Listing #${listingId} snapshot:`);
  console.log(`  Seller:         ${listing.seller}`);
  console.log(`  Listed amount:  ${listAmountHuman} BC`);
  console.log(`  Listed price:   ${listPriceHuman} ETH (for full lot)`);

  console.log(`\n📝 Making offer:`);
  console.log(`  Target listing: ${listingId}`);
  console.log(`  Offer amount:   ${amountBCArg} BC`);
  console.log(`  Offer price:    ${offerEthArg} ETH total`);

  console.log("\n⏳ Sending makeOffer transaction...");

  const tx = await Marketplace.makeOffer(listingId, amountBC, offerWei, {
    value: offerWei,
  });
  const receipt = await tx.wait();

  // We cannot show offer details (private), but we can show the latest offer ID because
  // offerCounter is public.
  const offerCounter = await Marketplace.offerCounter();

  console.log("\n✅ Offer submitted!");
  console.log("  Offer ID (latest):", offerCounter.toString());
  console.log("  Tx hash:", receipt.hash, "\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
