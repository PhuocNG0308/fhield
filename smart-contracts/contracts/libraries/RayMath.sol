// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

library RayMath {
    uint256 internal constant RAY = 1e27;
    uint256 internal constant HALF_RAY = 5e26;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant HALF_WAD = 5e17;
    uint256 internal constant WAD_RAY_RATIO = 1e9;
    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    function rayMul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 || b == 0) return 0;
        return (a * b + HALF_RAY) / RAY;
    }

    function rayDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 halfB = b / 2;
        return (a * RAY + halfB) / b;
    }

    function wadToRay(uint256 a) internal pure returns (uint256) {
        return a * WAD_RAY_RATIO;
    }

    function rayToWad(uint256 a) internal pure returns (uint256) {
        uint256 halfRatio = WAD_RAY_RATIO / 2;
        return (a + halfRatio) / WAD_RAY_RATIO;
    }

    /// @dev Taylor expansion (3rd order) of (1 + rate/SECONDS_PER_YEAR)^timeDelta
    function calculateCompoundedInterest(
        uint256 rate,
        uint256 timeDelta
    ) internal pure returns (uint256) {
        if (timeDelta == 0) return RAY;

        uint256 expMinusOne;
        uint256 expMinusTwo;

        unchecked {
            expMinusOne = timeDelta - 1;
            expMinusTwo = timeDelta > 2 ? timeDelta - 2 : 0;
        }

        uint256 basePowerTwo = rayMul(rate, rate) / (SECONDS_PER_YEAR * SECONDS_PER_YEAR);
        uint256 basePowerThree = rayMul(basePowerTwo, rate) / SECONDS_PER_YEAR;

        uint256 secondTerm = timeDelta * expMinusOne * basePowerTwo;
        unchecked {
            secondTerm /= 2;
        }

        uint256 thirdTerm = timeDelta * expMinusOne * expMinusTwo * basePowerThree;
        unchecked {
            thirdTerm /= 6;
        }

        return RAY + (rate * timeDelta) / SECONDS_PER_YEAR + secondTerm + thirdTerm;
    }

    function calculateLinearInterest(
        uint256 rate,
        uint256 timeDelta
    ) internal pure returns (uint256) {
        return RAY + (rate * timeDelta) / SECONDS_PER_YEAR;
    }
}
