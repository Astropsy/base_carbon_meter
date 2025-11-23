// embedded-wallet.js
// Helper routes for working with user wallets in an "embedded" flow.
// NOTE: We do NOT generate or return private keys from the server.

const express = require("express");
const { ethers } = require("ethers");
const { getMeterContract } = require("./server-wallet");

const router = express.Router();

/**
 * POST /embedded/bind-device
 * body: { deviceId: string (hex32), wallet: string (address) }
 *
 * For demo:
 *  - backend (owner) calls registerDevice(deviceId, wallet)
 *  - this assumes the server wallet is the CarbonSmartMeter owner
 */
router.post("/embedded/bind-device", async (req, res) => {
  try {
    const { deviceId, wallet } = req.body || {};

    if (!deviceId || !wallet) {
      return res.status(400).json({ error: "deviceId and wallet are required" });
    }
    if (!ethers.isAddress(wallet)) {
      return res.status(400).json({ error: "Invalid wallet address" });
    }

    // deviceId should be 32-byte hex string (0x...)
    if (!/^0x[0-9a-fA-F]{64}$/.test(deviceId)) {
      return res.status(400).json({ error: "deviceId must be 32-byte hex string" });
    }

    const meter = getMeterContract();
    const tx = await meter.registerDevice(deviceId, wallet);
    const receipt = await tx.wait();

    return res.json({
      ok: true,
      txHash: tx.hash,
      blockNumber: receipt.blockNumber,
      deviceId,
      wallet,
    });
  } catch (err) {
    console.error("bind-device error:", err);
    return res.status(500).json({ error: "bind-device failed", details: err.message });
  }
});

/**
 * GET /embedded/wallet-totals/:wallet
 * Returns kWh, CO2 and pending readings for a given wallet.
 */
router.get("/embedded/wallet-totals/:wallet", async (req, res) => {
  try {
    const wallet = req.params.wallet;
    if (!ethers.isAddress(wallet)) {
      return res.status(400).json({ error: "Invalid wallet address" });
    }

    const meter = getMeterContract();
    const [kwhMilli, co2MicroKg, pending] = await meter.getWalletTotals(wallet);

    return res.json({
      ok: true,
      wallet,
      kwhMilli: kwhMilli.toString(),
      co2MicroKg: co2MicroKg.toString(),
      pendingKwhMilli: pending.toString(),
    });
  } catch (err) {
    console.error("wallet-totals error:", err);
    return res.status(500).json({ error: "wallet-totals failed", details: err.message });
  }
});

module.exports = router;