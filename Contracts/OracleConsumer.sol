// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * OracleConsumer.sol is our data ingestion layer for Chainlink.
 *
 * We connect directly to the Chainlink UNI / USD price feed so that our
 * system can estimate a USD value for the BaseCarbon (BC) tokens we mint
 * in CarbonSmartMeter.
 *
 * Design notes:
 * - Our core CO₂ + kWh logic does NOT depend on the oracle.
 * - This oracle is only used for valuation & reporting, not mint logic.
 * - For the hackathon, UNI / USD is used as a proxy for a carbon price index.
 * - In production, we could swap this to a dedicated carbon credit feed.
 *
 * Product name: UNI/USD-RefPrice-DF-Ethereum-001
 * Feed address: 0x553303d460EE0afB37EdFf9bE42922D8FF63220e
 * ENS         : uni-usd.data.eth
 */
contract OracleConsumer {

    /// @notice Hardcoded UNI / USD Chainlink price feed on Ethereum mainnet
    AggregatorV3Interface public priceFeed =
        AggregatorV3Interface(0x553303d460EE0afB37EdFf9bE42922D8FF63220e);

    /**
     * @notice Returns the latest price and the number of decimals.
     *
     * We will typically use this inside CarbonSmartMeter to derive an
     * approximate USD value for the BaseCarbon (BC) tokens.
     *
     * @return price    Latest price from the Chainlink feed
     * @return decimals Number of decimals the price is scaled by
     */
    function getLatestPrice() public view returns (int256 price, uint8 decimals) {
        (
            /* uint80 roundID */,
            int256 answer,
            /* uint256 startedAt */,
            /* uint256 updatedAt */,
            /* uint80 answeredInRound */
        ) = priceFeed.latestRoundData();

        price = answer;
        decimals = priceFeed.decimals();
    }

    /**
     * @notice Convenience method for debugging & scripts.
     *         Returns the full Chainlink round data.
     */
    function getLatestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return priceFeed.latestRoundData();
    }
}