// faucet.js
// Simple testnet faucet for Base Sepolia – DO NOT use in production as-is.

const express = require("express");
const { ethers } = require("ethers");
const { serverWallet } = require("./server-wallet");

const router = express.Router();

// Amount to send per request (0.01 ETH on Base Sepolia)
const DRIP_AMOUNT = ethers.parseEther("0.01");

router.post("/faucet", async (req, res) => {
  try {
    const { to } = req.body || {};

    if (!to || !ethers.isAddress(to)) {
      return res.status(400).json({ error: "Invalid or missing 'to' address" });
    }

    // Basic safety: don't let faucet send to itself
    if (to.toLowerCase() === serverWallet.address.toLowerCase()) {
      return res.status(400).json({ error: "Cannot faucet to server wallet" });
    }

    const balance = await serverWallet.provider.getBalance(serverWallet.address);
    if (balance < DRIP_AMOUNT) {
      return res.status(400).json({ error: "Faucet depleted on this wallet" });
    }

    const tx = await serverWallet.sendTransaction({
      to,
      value: DRIP_AMOUNT,
    });

    const receipt = await tx.wait();

    return res.json({
      ok: true,
      hash: tx.hash,
      blockNumber: receipt.blockNumber,
      from: serverWallet.address,
      to,
      amount: DRIP_AMOUNT.toString(),
    });
  } catch (err) {
    console.error("Faucet error:", err);
    return res.status(500).json({ error: "Faucet failed", details: err.message });
  }
});

module.exports = router;