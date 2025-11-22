// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./OracleConsumer.sol";

/**
 * CarbonSmartMeter.sol is the core logic contract.
 *
 * It receives verified meter data, converts VIR to kWh, applies a global
 * grid intensity factor (0.40 kg CO₂/kWh), calculates the carbon impact
 * / offset, and triggers the minting of BaseCarbon (BC) tokens via the
 * Token contract on Base.
 *
 * We then *optionally* use a Chainlink price feed (e.g. UNI/USD) via
 * OracleConsumer to estimate the USD value of the offsets for reporting.
 *
 * Assumptions:
 * - All MRV (Measurement, Reporting, Verification), Ed25519 signature checks,
 *   daily caps, and per site grid intensity selection are handled off-chain
 *   (ESP32 → Cloud → LLM).
 * - This contract is only called with VERIFIED readings by an integrated backend.
 */

// Minimal interface for the BaseCarbon ERC-20 token.
interface IBaseCarbonToken {
    function decimals() external view returns (uint8);
    function mint(address to, uint256 amount) external;
}

contract CarbonSmartMeter is OracleConsumer {
    // ------------------------------------------------------------------------
    // Types & constants
    // ------------------------------------------------------------------------

    /**
     * @dev  Grid intensity is fixed at 0.40 kg CO₂ per kWh.
     *
     *      0.40 kg/kWh = 0.40 * 1,000,000 micro-kg/kWh
     *                   = 400,000 micro-kg/kWh
     *
     *      We store CO₂ in micro-kg and energy in milli-kWh:
     *        - 1 kWh   = 1,000 milli-kWh
     *        - 1 kg    = 1,000,000 micro-kg
     */
    uint256 public constant GRID_DENSITY_MICRO_KG_PER_KWH = 400_000; // 0.40 kg/kWh * 1e6
    uint256 public constant MILLI_PER_KWH                 = 1_000;   // 1 kWh = 1,000 milli-kWh

    /// @dev Mint rule: 1 BaseCarbon (BC) per 2.5 kWh verified.
    ///     2.5 kWh = 2,500 milli-kWh
    uint256 public constant KWH_PER_TOKEN_MILLI = 2_500;  // 2.5 kWh per 1 BC

    /// @dev Cached decimals from the ERC-20 token, e.g. 18.
    uint8 public immutable TOKEN_DECIMALS;

    /// @dev Represents a physical Carbon Smart Meter device.
    struct Device {
        bytes32 deviceId;          // 32-byte hardware id
        address wallet;            // bound user / site owner wallet
        uint256 totalKwhMilli;     // cumulative verified energy, milli-kWh
        uint256 totalCo2MicroKg;   // cumulative CO₂ impact, micro-kg
        bool active;               // device active flag
    }

    // ------------------------------------------------------------------------
    // Storage
    // ------------------------------------------------------------------------

    /// @notice Backend controller (your cloud + LLM pipeline).
    address public owner;

    /// @notice deviceId (bytes32) → Device metadata.
    mapping(bytes32 => Device) public devices;

    /// @notice Verified but not yet minted energy per wallet, in milli-kWh.
    mapping(address => uint256) public pendingKwhMilli;

    /// @notice Total verified kWh per wallet, in milli-kWh.
    mapping(address => uint256) public totalKwhMilliByWallet;

    /// @notice Total CO₂ impact per wallet, in micro-kg.
    mapping(address => uint256) public totalCo2MicroKgByWallet;

    /// @notice BaseCarbon token contract.
    IBaseCarbonToken public immutable baseCarbonToken;

    // ------------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------------

    event DeviceRegistered(bytes32 indexed deviceId, address indexed wallet);
    event DeviceDeactivated(bytes32 indexed deviceId);

    event EnergyRecorded(
        bytes32 indexed deviceId,
        address indexed wallet,
        uint256 kwhMilli,
        uint256 co2MicroKg
    );

    event TokensMinted(address indexed wallet, uint256 amount);
    event OwnerUpdated(address indexed oldOwner, address indexed newOwner);

    // ------------------------------------------------------------------------
    // Modifiers
    // ------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------

    /**
     * @param token       Address of the BaseCarbon ERC-20 token contract.
     * @param aggregator  Address of the Chainlink price feed (e.g. UNI/USD).
     *
     * OracleConsumer(aggregator) wires up the Chainlink feed, while the core
     * meter logic is independent of the price feed.
     */
    constructor(address token, address aggregator)
        OracleConsumer(aggregator)
    {
        require(token != address(0), "Zero token address");

        baseCarbonToken = IBaseCarbonToken(token);
        owner = msg.sender;

        // Cache token decimals once.
        TOKEN_DECIMALS = IBaseCarbonToken(token).decimals();
    }

    // ------------------------------------------------------------------------
    // Admin functions
    // ------------------------------------------------------------------------

    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnerUpdated(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @notice Register a device and bind it to a wallet.
     *
     * Off-chain we already have:
     * - generated Ed25519 keys,
     * - verified uniqueness,
     * - stored bindings in our backend (ESP32 → Cloud).
     */
    function registerDevice(bytes32 deviceId, address wallet) external onlyOwner {
        require(wallet != address(0), "Zero wallet");

        Device storage existing = devices[deviceId];
        require(existing.deviceId == bytes32(0), "Device already registered");

        devices[deviceId] = Device({
            deviceId:        deviceId,
            wallet:          wallet,
            totalKwhMilli:   0,
            totalCo2MicroKg: 0,
            active:          true
        });

        emit DeviceRegistered(deviceId, wallet);
    }

    function deactivateDevice(bytes32 deviceId) external onlyOwner {
        Device storage device = devices[deviceId];
        require(device.deviceId != bytes32(0), "Device not registered");
        require(device.active, "Already inactive");

        device.active = false;
        emit DeviceDeactivated(deviceId);
    }

    // ------------------------------------------------------------------------
    // Core flow: record a verified reading & mint tokens
    // ------------------------------------------------------------------------

    /**
     * @notice Backend hook: record VERIFIED energy (after MRV + LLM routing).
     *
     * @param deviceId  32-byte device id.
     * @param kwhMilli  Verified energy to add (milli-kWh).
     *
     * Behaviour:
     * - updates device & wallet energy totals
     * - updates CO₂ impact using global GRID_DENSITY_MICRO_KG_PER_KWH
     * - accumulates pending kWh for that wallet
     * - mints 1 BaseCarbon (BC) per 2.5 kWh (using ERC-20 decimals)
     *
     * This function assumes all upstream verification has already happened
     * off-chain, and this call is made by the trusted backend (owner).
     */
    function recordVerifiedReading(bytes32 deviceId, uint256 kwhMilli)
        external
        onlyOwner
    {
        require(kwhMilli > 0, "Zero reading");

        Device storage device = devices[deviceId];
        require(device.deviceId != bytes32(0), "Device not registered");
        require(device.active, "Device inactive");

        address wallet = device.wallet;

        // 1) Update energy totals.
        device.totalKwhMilli += kwhMilli;
        totalKwhMilliByWallet[wallet] += kwhMilli;

        // 2) CO₂ accounting using 0.40 kg/kWh in micro-kg.
        //
        // We store:
        //   - kwhMilli: milli-kWh
        //   - GRID_DENSITY_MICRO_KG_PER_KWH: micro-kg per kWh
        //
        // So:
        //   co2MicroKgDelta = (kwhMilli / 1000) * GRID
        //                   = (kwhMilli * GRID) / MILLI_PER_KWH
        uint256 co2MicroKgDelta =
            (kwhMilli * GRID_DENSITY_MICRO_KG_PER_KWH) / MILLI_PER_KWH;

        device.totalCo2MicroKg += co2MicroKgDelta;
        totalCo2MicroKgByWallet[wallet] += co2MicroKgDelta;

        emit EnergyRecorded(deviceId, wallet, kwhMilli, co2MicroKgDelta);

        // 3) Pending kWh → BaseCarbon token minting.
        uint256 pending = pendingKwhMilli[wallet] + kwhMilli;

        // Integer division: how many whole tokens worth of kWh we have
        uint256 tokensToMint = pending / KWH_PER_TOKEN_MILLI;
        uint256 remainingKwhMilli = pending % KWH_PER_TOKEN_MILLI;

        if (tokensToMint > 0) {
            uint256 scaleFactor = 10 ** uint256(TOKEN_DECIMALS);
            uint256 mintAmount = tokensToMint * scaleFactor;

            // Mint tokens to the user's wallet.
            // In practice, this contract is called by our backend, which is
            // running inside a Coinbase CDP Server Wallet flow.
            baseCarbonToken.mint(wallet, mintAmount);
            emit TokensMinted(wallet, mintAmount);
        }

        // Store leftover kWh for next reading.
        pendingKwhMilli[wallet] = remainingKwhMilli;
    }

    // ------------------------------------------------------------------------
    // View helpers
    // ------------------------------------------------------------------------

    function getDevice(bytes32 deviceId) external view returns (Device memory) {
        Device memory device = devices[deviceId];
        require(device.deviceId != bytes32(0), "Device not registered");
        return device;
    }

    /**
     * @return kwhMilli   Total verified kWh (in milli-kWh)
     * @return co2MicroKg Total CO₂ impact (micro-kg)
     * @return pending    Pending, not yet converted kWh (milli-kWh)
     */
    function getWalletTotals(address wallet)
        external
        view
        returns (
            uint256 kwhMilli,
            uint256 co2MicroKg,
            uint256 pending
        )
    {
        kwhMilli   = totalKwhMilliByWallet[wallet];
        co2MicroKg = totalCo2MicroKgByWallet[wallet];
        pending    = pendingKwhMilli[wallet];
    }

    /**
     * @notice Approximate USD value of all BaseCarbon for a wallet,
     *         using the Chainlink price feed inherited from OracleConsumer.
     *
     *         For the hackathon, we will plug in UNI/USD as a proxy for
     *         a "carbon price index". Swapping to a real carbon feed later
     *         by just changing the aggregator address.
     *
     * @dev This is a view/analytics helper, does NOT affect minting logic.
     */
    function getWalletOffsetValueUSD(address wallet)
        external
        view
        returns (uint256 usdValue)
    {
        // First, estimate how many whole BC tokens the wallet "should" have
        // under the 2.5 kWh = 1 BC rule, based on total verified kWh.
        uint256 kwhMilli = totalKwhMilliByWallet[wallet];
        uint256 bcUnits  = kwhMilli / KWH_PER_TOKEN_MILLI; // number of BC tokens

        if (bcUnits == 0) {
            return 0;
        }

        uint256 scaleFactor = 10 ** uint256(TOKEN_DECIMALS);
        uint256 bcBalance   = bcUnits * scaleFactor;

        // Now fetch the latest price from Chainlink feed via OracleConsumer.
        (int256 price, uint8 priceDecimals) = getLatestPrice();
        if (price <= 0) {
            return 0;
        }

        // usdValue ≈ (bcBalance * price) / 10**priceDecimals
        usdValue = (bcBalance * uint256(price)) / (10 ** uint256(priceDecimals));
    }
}
