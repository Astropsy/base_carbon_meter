// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract OracleConsumer {
    function getLatestPrice() public pure returns (int256 price, uint8 decimals) {
        return (100e8, 8); // 100.00000000 USD
    }

    function getLatestRoundData()
        external
        pure
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, 100e8, 0, 0, 0);
    }
}