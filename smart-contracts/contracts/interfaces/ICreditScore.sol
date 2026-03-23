// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface ICreditScore {
    function getBorrowRateDiscount(address user) external view returns (uint256);
    function getLTVBoost(address user) external view returns (uint256);
}
