// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IInterestRateStrategy.sol";
import "../libraries/RayMath.sol";

contract DefaultInterestRateStrategy is IInterestRateStrategy, Ownable {
    using RayMath for uint256;

    uint256 public baseVariableBorrowRate;
    uint256 public optimalUtilization;
    uint256 public variableRateSlope1;
    uint256 public variableRateSlope2;

    event ParamsUpdated(
        uint256 baseRate,
        uint256 optimalUtilization,
        uint256 slope1,
        uint256 slope2
    );

    constructor(
        uint256 _baseRate,
        uint256 _optimalUtilization,
        uint256 _slope1,
        uint256 _slope2
    ) Ownable(msg.sender) {
        baseVariableBorrowRate = _baseRate;
        optimalUtilization = _optimalUtilization;
        variableRateSlope1 = _slope1;
        variableRateSlope2 = _slope2;
    }

    function calculateInterestRates(
        uint256 totalDeposits,
        uint256 totalBorrows,
        uint256 reserveFactor
    ) external view override returns (uint256 borrowRate, uint256 liquidityRate) {
        if (totalDeposits == 0) {
            return (baseVariableBorrowRate, 0);
        }

        uint256 utilization = totalBorrows.rayDiv(totalDeposits);

        if (utilization <= optimalUtilization) {
            borrowRate = baseVariableBorrowRate +
                utilization.rayMul(variableRateSlope1).rayDiv(optimalUtilization);
        } else {
            uint256 excessUtilization = utilization - optimalUtilization;
            uint256 maxExcess = RayMath.RAY - optimalUtilization;
            borrowRate = baseVariableBorrowRate + variableRateSlope1 +
                excessUtilization.rayDiv(maxExcess).rayMul(variableRateSlope2);
        }

        liquidityRate = borrowRate.rayMul(utilization).rayMul(RayMath.RAY - reserveFactor);
    }

    function updateParams(
        uint256 _baseRate,
        uint256 _optimalUtilization,
        uint256 _slope1,
        uint256 _slope2
    ) external onlyOwner {
        baseVariableBorrowRate = _baseRate;
        optimalUtilization = _optimalUtilization;
        variableRateSlope1 = _slope1;
        variableRateSlope2 = _slope2;
        emit ParamsUpdated(_baseRate, _optimalUtilization, _slope1, _slope2);
    }
}
