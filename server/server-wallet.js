// server-wallet.js
// Shared provider + signer + contract helpers for the Base Carbon Meter backend

require("dotenv").config();
const { ethers } = require("ethers");
const path = require("path");

// Load env
const {
  BASE_RPC,
  PRIVATE_KEY,
  TOKEN_ADDRESS,
  METER_ADDRESS,
} = process.env;

if (!BASE_RPC) {
  throw new Error("Missing BASE_RPC in .env");
}
if (!PRIVATE_KEY) {
  throw new Error("Missing PRIVATE_KEY in .env");
}

const provider = new ethers.JsonRpcProvider(BASE_RPC);
const serverWallet = new ethers.Wallet(PRIVATE_KEY, provider);

// Load ABIs from Hardhat artifacts
const tokenArtifact = require(path.join(
  __dirname,
  "..",
  "artifacts",
  "contracts",
  "Token.sol",          // <- file name
  "BaseCarbonToken.json" // <- contract name
));

const meterArtifact = require(path.join(
  __dirname,
  "..",
  "artifacts",
  "contracts",
  "CarbonSmartMeter.sol",
  "CarbonSmartMeter.json"
));

function getTokenContract() {
  if (!TOKEN_ADDRESS) {
    throw new Error("Missing TOKEN_ADDRESS in .env");
  }
  return new ethers.Contract(TOKEN_ADDRESS, tokenArtifact.abi, serverWallet);
}

function getMeterContract() {
  if (!METER_ADDRESS) {
    throw new Error("Missing METER_ADDRESS in .env");
  }
  return new ethers.Contract(METER_ADDRESS, meterArtifact.abi, serverWallet);
}

module.exports = {
  provider,
  serverWallet,
  getTokenContract,
  getMeterContract,
};