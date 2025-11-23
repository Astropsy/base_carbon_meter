require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const { BASE_RPC, PRIVATE_KEY } = process.env;

/**
 * Hardhat configuration for BASE_CARBON_METER.
 *
 * We keep it simple:
 * - Solidity 0.8.24 (same as our contracts)
 * - Default 'hardhat' local network
 * - 'base' network for Base / Base Sepolia using env vars
 * - Explicit paths so we use ./contracts and ./scripts
 */
module.exports = {
  solidity: "0.8.24",
  networks: {
    hardhat: {},
    base: {
      url: BASE_RPC || "https://sepolia.base.org",
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    scripts: "./scripts",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};