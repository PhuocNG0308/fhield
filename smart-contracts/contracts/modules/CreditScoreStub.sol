// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../interfaces/ICreditScore.sol";

contract CreditScoreStub is ICreditScore {
    function getBorrowRateDiscount(address) external pure override returns (uint256) {
        return 0;
    }

    function getLTVBoost(address) external pure override returns (uint256) {
        return 0;
    }
}
