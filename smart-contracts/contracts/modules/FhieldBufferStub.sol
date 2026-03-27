// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../interfaces/IFhieldBuffer.sol";

contract FhieldBufferStub is IFhieldBuffer {
    function getReliefShare(address, uint256) external pure override returns (uint256) {
        return 0;
    }

    function onLiquidation(address, uint256) external override {}
}
