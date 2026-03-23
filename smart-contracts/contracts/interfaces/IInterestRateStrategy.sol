// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IInterestRateStrategy {
    function calculateInterestRates(
        uint256 totalDeposits,
        uint256 totalBorrows,
        uint256 reserveFactor
    ) external view returns (uint256 borrowRate, uint256 liquidityRate);
}
