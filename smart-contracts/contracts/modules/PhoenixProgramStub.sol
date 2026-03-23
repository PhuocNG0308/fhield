// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../interfaces/IPhoenixProgram.sol";

contract PhoenixProgramStub is IPhoenixProgram {
    function getReliefShare(address, uint256) external pure override returns (uint256) {
        return 0;
    }

    function onLiquidation(address, uint256) external override {
        // No-op: 0% relief in v1
    }
}
