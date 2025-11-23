## Peer-to-Peer Offset Marketplace (P2P Layer)

To close the loop between energy producers and offset buyers, we add a separate, modular P2P marketplace on Base.

### What It Does

- Renewable energy producers receive BaseCarbon (BC) tokens when their smart meters cross energy thresholds (2.5 kWh = 1 BC in our design).
- Producers can list BC tokens for sale on-chain using the `CarbonMarketplace` contract.
- Buyers can purchase BC on-chain using ETH, with all movements (BC and ETH) fully traceable on Base.
- A 5% BC fee from each sale is routed automatically to a protocol treasury to fund:
  - gas costs,
  - oracle development,
  - backend + smart contract hosting.

## Net effect  
Producers keep 95% of their BC, the protocol keeps 5%, and buyers acquire on-chain, verifiable offsets that tie directly back to real world energy generation.

## The UX flow

1. Buyer chooses a currency (fiat, stablecoin, other crypto currency).
2. Frontend + CDP Trade API swap that asset into ETH on Base.
3. Buyer sees available BC listings (price, quantity, seller profile).

4. (Optional – volume discounts)
   - If the buyer is taking size (e.g. ESG desk, airline, exporter), they can submit an offer:
     - X BC at Y price (below or at list)
   - The seller (or an automated selling agent) can:
     - accept the offer, or
     - counter / ignore and leave the listing at the original price.

5. Once a price is agreed (either list price or accepted offer), the frontend calls:

   `buyBC(listingId, amountBC)` with ETH on Base.

6. On-chain, `CarbonMarketplace`:
   - transfers 95% of the agreed BC amount from producer → buyer,
   - transfers 5% of the BC amount from producer → treasury,
   - forwards the agreed ETH payment to the producer (less any swap fees handled off-chain).

7. Buyer receives:
   - BC in their wallet,
   - a fully on-chain, auditable trail they can plug into ESG reports and compliance workflows.

### Target Users

- Renewable energy producers (solar, wind, hydro) seeking green financing.
- Aviation and unregulated aerospace markets needing **ESG-aligned offsets**.
- Exporters requiring **CBAM-compliant documentation**.
- Funds, DAOs, and corporates needing **audited, device-level climate assets**.

---

### Why It Matters

This P2P layer:

- Turns **MRV data + smart meter outputs** into **liquid, tradeable climate assets**.
- Creates new revenue streams for energy producers.
- Gives buyers audit-proof offsets for ESG and compliance, especially in under-served markets (e.g. unregulated aerospace, emerging markets).
- Keeps the core Carbon Smart Meter system **unchanged**, while adding a clean, modular marketplace on top.
