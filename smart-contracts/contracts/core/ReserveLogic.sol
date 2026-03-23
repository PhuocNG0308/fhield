// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../libraries/RayMath.sol";
import "../interfaces/IInterestRateStrategy.sol";

library ReserveLogic {
    using RayMath for uint256;

    struct ReserveData {
        uint256 liquidityIndex;
        uint256 variableBorrowIndex;
        uint256 currentLiquidityRate;
        uint256 currentVariableBorrowRate;
        uint40 lastUpdateTimestamp;
    }

    function accrueInterest(ReserveData storage self) internal {
        if (self.liquidityIndex == 0) {
            self.liquidityIndex = RayMath.RAY;
            self.variableBorrowIndex = RayMath.RAY;
            self.lastUpdateTimestamp = uint40(block.timestamp);
            return;
        }

        uint256 elapsed = block.timestamp - uint256(self.lastUpdateTimestamp);
        if (elapsed == 0) return;

        if (self.currentVariableBorrowRate > 0) {
            uint256 compounded = RayMath.calculateCompoundedInterest(
                self.currentVariableBorrowRate, elapsed
            );
            self.variableBorrowIndex = compounded.rayMul(self.variableBorrowIndex);
        }

        if (self.currentLiquidityRate > 0) {
            uint256 linear = RayMath.calculateLinearInterest(
                self.currentLiquidityRate, elapsed
            );
            self.liquidityIndex = linear.rayMul(self.liquidityIndex);
        }

        self.lastUpdateTimestamp = uint40(block.timestamp);
    }

    function updateRates(
        ReserveData storage self,
        uint256 totalDeposits,
        uint256 totalBorrows,
        IInterestRateStrategy strategy,
        uint256 reserveFactor
    ) internal {
        (uint256 borrowRate, uint256 liquidityRate) = strategy.calculateInterestRates(
            totalDeposits, totalBorrows, reserveFactor
        );
        self.currentVariableBorrowRate = borrowRate;
        self.currentLiquidityRate = liquidityRate;
    }
}
