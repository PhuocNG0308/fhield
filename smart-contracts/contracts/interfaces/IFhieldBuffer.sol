// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IFhieldBuffer {
    function getReliefShare(address liquidatedUser, uint256 penaltyAmount) external view returns (uint256);
    function onLiquidation(address liquidatedUser, uint256 reliefAmount) external;
}
