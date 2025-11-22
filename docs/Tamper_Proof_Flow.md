# Tamper-Proof Flow – Carbon Smart Meter (Base + Chainlink + Coinbase CDP)

[Carbon Smart Meter]
        │
        ├── Broadcasts private WiFi AP (WPA2/WPA3)
        ├── Hosts secure local website (no download)
        ├── Signs: device_id + VIR + timestamp (Ed25519)
        │
        ▼ (Wireless connection to device AP)
[User Browser Session (Mobile / Desktop)]
        │
        ├── User connects via browser only
        ├── Local webpage verifies signature
        ├── User logs in (standard email / SSO / password)
        ├── System silently creates a CDP Embedded Wallet
        ├── Device is bound to the user/site account
        ├── Converts VIR → Wh → kWh
        ├── Stores encrypted data in AWS/Azure (GDPR)
        │
        ▼ (HTTPS internet)
[Backend + Base / Chainlink / Coinbase CDP]
        ├── Verifies signature again (server-side)
        ├── Fetches grid/price data via Chainlink oracle (or proxy feed)
        ├── Calculates VIR : kWh : OFFSET using oracle data
        ├── Uses Coinbase CDP Server Wallet to call Base smart contracts
        ├── Mints offset or measurement attestations on Base
        ├── Sends tokens to user’s CDP Embedded Wallet
        └── Stores immutable proofs via on-chain tx hashes

Key Features of this flow:

✔ No downloadable app
✔ Browser only onboarding
✔ Works with CDP Embedded Wallet instead of browser extensions
✔ Local captive portal web page for onboarding (router style setup)
✔ Safe in high voltage solar/industrial environments 
✔ On-chain immutability on Base, with Chainlink for trusted data and Coinbase CDP for wallets & gas sponsorship

## User Login Flow
Login happens once during device pairing.

During the first setup at a site:
1. User opens the device private WiFi portal in the browser.
2. The device serves a local web page (no app, no external internet required).
3. User logs in / creates an account and system silently creates a CDP Embedded Wallet
4. The backend associates:
    → device_id
    → user account
    → embedded wallet address
5. The device switches into “paired mode" and is now bound to that user/site.
This pairing binds:
→ A physical meter
→ To a specific site / user
→ To a specific on-chain wallet on Base

## After Pairing

Once the device is paired:
- No login is needed to read data from the meter.
- No login is needed for background syncing.
- Data uploads happen automatically over HTTPS.
- User only logs in if they want to:
    - View dashboards / history
    - Manage devices / sites
    - Trigger manual offset actions

## Operational flow:

1. Device periodically signs readings:
    - device_id + VIR + timestamp
2. Browser or backend verifies the signature.
3. Backend:
    - Resolves VIR → Wh → kWh
    - Pulls grid CO₂ intensity / pricing data via Chainlink (or configured proxy)
    - Computes offsets or emissions
4. Backend uses Coinbase CDP Server Wallet to:
    - Call the Carbon Smart Meter smart contract on Base
    - Mint carbon offset / measurement tokens or attestations
    - Send them to the user’s CDP Embedded Wallet
5. Tx hash and on-chain state act as a tamper proof audit trail.

## Mental Model

The system behaves like a mix of:
→ Connecting a new router (local captive portal setup)
→ Pairing a Ledger / hardware wallet (device bound to one account)
→ Setting up a smart home hub (one-time pairing, ongoing automatic sync)

Once paired:

Device → signs reading → Browser/Backend verifies → Backend calls Base contract (via Coinbase CDP) using 
Chainlink data → On-chain proof + tokens minted → Done.

One time login, persistent binding, ongoing tamper-proof measurement.