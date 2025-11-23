require("dotenv").config();
const express = require("express");

const { serverWallet } = require("./server-wallet");
const { embeddedWallet } = require("./embedded-wallet");
const { faucet } = require("./faucet");

const app = express();
app.use(express.json());

// Test endpoint
app.get("/", (req, res) => {
  res.send("Carbon Smart Meter backend is running");
});

// Use server wallet to call Mint or Meter functions
app.post("/record-reading", async (req, res) => {
  try {
    const result = await serverWallet.recordReading(req.body);
    res.json({ ok: true, result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Provide a faucet for testing
app.get("/faucet/:address", async (req, res) => {
  try {
    const tx = await faucet(req.params.address);
    res.json({ ok: true, tx });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Embedded wallet calls (optional)
app.post("/embedded/tx", async (req, res) => {
  try {
    const result = await embeddedWallet.sendTx(req.body);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));