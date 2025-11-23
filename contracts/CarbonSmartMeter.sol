// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./OracleConsumer.sol";

/**
 * CarbonSmartMeter.sol
 * ---------------------
 * Core smart contract for verified renewable energy → carbon offsets → BC token minting.
 *
 * Responsibilities:
 *  - Receives verified energy readings (in milli-kWh) from backend (ESP32 → Cloud → LLM → Backend)
 *  - Applies CO₂ impact calculation using global GRID_DENSITY_MICRO_KG_PER_KWH
 *  - Tracks device + wallet totals
 *  - Converts 2.5 kWh → 1 BC token
 *  - Mints BaseCarbon (BC) tokens via ERC-20 contract
 *  - Optionally retrieves USD valuation for reporting (via on-chain oracle stub)
 *
 * Notes:
 *  - MRV happens off-chain (signature verification, daily caps, regional grid intensity, anomaly detection)
 *  - On-chain contract only handles VERIFIED inputs from trusted backend
 *  - For the hackathon, OracleConsumer.getLatestPrice() returns a fixed price
 *    (e.g. 100.00000000 USD with 8 decimals). Swapping to a live Chainlink
 *    feed later is a one-file change in OracleConsumer.
 */

interface IBaseCarbonToken {
    function decimals() external view returns (uint8);
    function mint(address to, uint256 amount) external;
}

contract CarbonSmartMeter is OracleConsumer {
    // ------------------------------------------------------------------------
    // Constants
    // ------------------------------------------------------------------------

    uint256 public constant GRID_DENSITY_MICRO_KG_PER_KWH = 400_000; // 0.40 kg CO₂/kWh → 400,000 µg
    uint256 public constant MILLI_PER_KWH = 1_000;                   // 1 kWh = 1,000 milli-kWh

    /// @dev Mint rule: 2.5 kWh = 2,500 milli-kWh = 1 BC token
    uint256 public constant KWH_PER_TOKEN_MILLI = 2_500;

    uint8 public immutable TOKEN_DECIMALS;

    // ------------------------------------------------------------------------
    // Types
    // ------------------------------------------------------------------------

    struct Device {
        bytes32 deviceId;
        address wallet;
        uint256 totalKwhMilli;
        uint256 totalCo2MicroKg;
        bool active;
    }

    // ------------------------------------------------------------------------
    // Storage
    // ------------------------------------------------------------------------

    address public owner;

    mapping(bytes32 => Device) public devices;
    mapping(address => uint256) public pendingKwhMilli;
    mapping(address => uint256) public totalKwhMilliByWallet;
    mapping(address => uint256) public totalCo2MicroKgByWallet;

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

    constructor(address token) {
        require(token != address(0), "Zero token address");
        baseCarbonToken = IBaseCarbonToken(token);
        owner = msg.sender;
        TOKEN_DECIMALS = IBaseCarbonToken(token).decimals();
    }

    // ------------------------------------------------------------------------
    // Admin
    // ------------------------------------------------------------------------

    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnerUpdated(owner, newOwner);
        owner = newOwner;
    }

    function registerDevice(bytes32 deviceId, address wallet) external onlyOwner {
        require(wallet != address(0), "Zero wallet");
        require(devices[deviceId].deviceId == 0, "Device already registered");

        devices[deviceId] = Device(deviceId, wallet, 0, 0, true);
        emit DeviceRegistered(deviceId, wallet);
    }

    function deactivateDevice(bytes32 deviceId) external onlyOwner {
        Device storage d = devices[deviceId];
        require(d.deviceId != 0, "Not registered");
        require(d.active, "Inactive");
        d.active = false;
        emit DeviceDeactivated(deviceId);
    }

    // ------------------------------------------------------------------------
    // Core: Verified Reading → CO₂ impact → BC Minting
    // ------------------------------------------------------------------------

    function recordVerifiedReading(bytes32 deviceId, uint256 kwhMilli)
        external
        onlyOwner
    {
        require(kwhMilli > 0, "Zero reading");

        Device storage d = devices[deviceId];
        require(d.deviceId != 0, "Device not registered");
        require(d.active, "Inactive");

        address wallet = d.wallet;

        // Add energy totals
        d.totalKwhMilli += kwhMilli;
        totalKwhMilliByWallet[wallet] += kwhMilli;

        // CO₂ impact (micro-kg)
        uint256 co2Delta =
            (kwhMilli * GRID_DENSITY_MICRO_KG_PER_KWH) / MILLI_PER_KWH;

        d.totalCo2MicroKg += co2Delta;
        totalCo2MicroKgByWallet[wallet] += co2Delta;

        emit EnergyRecorded(deviceId, wallet, kwhMilli, co2Delta);

        // Minting logic
        uint256 pending = pendingKwhMilli[wallet] + kwhMilli;

        uint256 tokensToMint = pending / KWH_PER_TOKEN_MILLI;
        uint256 remainder = pending % KWH_PER_TOKEN_MILLI;

        if (tokensToMint > 0) {
            uint256 mintAmount =
                tokensToMint * (10 ** uint256(TOKEN_DECIMALS));
            baseCarbonToken.mint(wallet, mintAmount);
            emit TokensMinted(wallet, mintAmount);
        }

        pendingKwhMilli[wallet] = remainder;
    }

    // ------------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------------

    function getDevice(bytes32 deviceId)
        external
        view
        returns (Device memory)
    {
        require(devices[deviceId].deviceId != 0, "Not registered");
        return devices[deviceId];
    }

    function getWalletTotals(address wallet)
        external
        view
        returns (
            uint256 kwhMilli,
            uint256 co2MicroKg,
            uint256 pending
        )
    {
        return (
            totalKwhMilliByWallet[wallet],
            totalCo2MicroKgByWallet[wallet],
            pendingKwhMilli[wallet]
        );
    }

    /**
     * @notice USD valuation helper (non-critical).
     *
     * For hackathon deployment, this uses the stubbed on-chain oracle
     * via OracleConsumer.getLatestPrice(), which returns a fixed price
     * (e.g. 100.00000000 USD with 8 decimals).
     *
     * Formula:
     *   - Compute BC units from total verified kWh
     *   - Convert BC units → ERC20 token units
     *   - Multiply by oracle price
     *   - Normalize using oracle decimals
     */
    function getWalletOffsetValueUSD(address wallet)
        external
        view
        returns (uint256 usdValue)
    {
        // 1) Total verified energy for this wallet
        uint256 kwhMilli = totalKwhMilliByWallet[wallet];

        // Convert to BaseCarbon token units (1 BC per 2.5 kWh)
        uint256 bcUnits = kwhMilli / KWH_PER_TOKEN_MILLI;

        if (bcUnits == 0) {
            return 0;
        }

        // 2) Convert BC “units” to ERC-20 decimals
        uint256 scaleFactor = 10 ** uint256(TOKEN_DECIMALS);
        uint256 bcBalance   = bcUnits * scaleFactor;

        // 3) Fetch stub oracle price
        (int256 price, uint8 priceDecimals) = getLatestPrice();

        if (price <= 0) {
            return 0;
        }

        // 4) USD value = (bcBalance * price) / 10^priceDecimals
        usdValue = (bcBalance * uint256(price)) /
                   (10 ** uint256(priceDecimals));
    }
}