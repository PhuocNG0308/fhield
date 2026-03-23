---
sidebar_position: 7
title: Libraries
---

# Libraries

## RayMath

Fixed-point arithmetic library with RAY precision (1e27), adapted from AAVE V3.

### Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `RAY` | 1e27 | Base unit for ray arithmetic |
| `HALF_RAY` | 5e26 | Rounding constant |
| `WAD` | 1e18 | Standard Ethereum precision |
| `SECONDS_PER_YEAR` | 31,536,000 | 365 days in seconds |

### Functions

```solidity
function rayMul(uint256 a, uint256 b) → uint256
```
Multiplies two RAY values: `(a × b + HALF_RAY) / RAY`. Used for index compounding.

```solidity
function rayDiv(uint256 a, uint256 b) → uint256
```
Divides a value by another in RAY: `(a × RAY + b/2) / b`. Used for utilization calculations.

```solidity
function calculateCompoundedInterest(uint256 rate, uint256 timeDelta) → uint256
```
3rd-order Taylor expansion for compound interest:
`(1 + r·Δt/T)^n ≈ 1 + n·rΔt + n(n-1)/2·(rΔt)² + n(n-1)(n-2)/6·(rΔt)³`

```solidity
function calculateLinearInterest(uint256 rate, uint256 timeDelta) → uint256
```
Simple linear interest: `1 + r × Δt / SECONDS_PER_YEAR`

---

## FHELendingMath

Wrapper functions for FHE arithmetic operations used in the lending protocol.

### Functions

```solidity
function mulByPlaintext(euint64 encrypted, uint256 plaintext) → euint64
```
Multiplies an encrypted value by a plaintext scalar. Used for price multiplication and index normalization.

```solidity
function divByPlaintext(euint64 encrypted, uint256 plaintext) → euint64
```
Divides an encrypted value by a plaintext scalar. Used for index ratio division.

```solidity
function encryptedMin(euint64 a, euint64 b) → euint64
```
Returns the minimum of two encrypted values using `FHE.select(FHE.lte(a, b), a, b)`. Used for capping repay/withdraw amounts to actual balance.

```solidity
function encryptedMax(euint64 a, euint64 b) → euint64
```
Returns the maximum of two encrypted values.

```solidity
function encryptedZero() → euint64
```
Returns `FHE.asEuint64(0)`. Used as the fallback value in zero-replacement patterns.
