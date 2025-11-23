// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockV3Aggregator {
    uint8 public decimals_;
    int256 public latestAnswer;

    constructor(uint8 _decimals, int256 _initialAnswer) {
        decimals_ = _decimals;
        latestAnswer = _initialAnswer;
    }

    function decimals() external view returns (uint8) {
        return decimals_;
    }

    function updateAnswer(int256 _answer) external {
        latestAnswer = _answer;
    }

    function latestRoundData()
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
        return (0, latestAnswer, 0, block.timestamp, 0);
    }
}