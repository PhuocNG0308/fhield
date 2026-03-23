---
sidebar_position: 3
title: ReserveLogic
---

# ReserveLogic

Library managing per-asset reserve state — liquidity/borrow indices, interest rates, and interest accrual.

## ReserveData Struct

```solidity
struct ReserveData {
    uint256 liquidityIndex;          // Scaled by RAY (1e27), grows for deposits
    uint256 variableBorrowIndex;     // Scaled by RAY, grows for borrows
    uint256 currentLiquidityRate;    // Current supply APY in RAY
    uint256 currentVariableBorrowRate; // Current borrow APY in RAY
    uint40 lastUpdateTimestamp;
}
```

Both indices start at `RAY` (1e27) on first initialization and grow monotonically over time.

## Functions

### `accrueInterest(ReserveData storage reserve)`

Updates liquidity and borrow indices based on elapsed time since last update.

1. Calculates time delta: `block.timestamp - lastUpdateTimestamp`
2. Computes compound interest multiplier using `RayMath.calculateCompoundedInterest(rate, timeDelta)`
3. Updates indices: `index = index.rayMul(multiplier)`
4. Stores new timestamp

Called at the start of every state-changing operation (deposit, borrow, repay, withdraw).

### `updateRates(ReserveData storage reserve, ...)`

Recalculates supply and borrow rates from the interest rate strategy based on current utilization.

1. Calls `IInterestRateStrategy.calculateInterestRates(totalDeposits, totalBorrows, reserveFactor)`
2. Stores returned `borrowRate` and `liquidityRate` in reserve state

Called after every operation that changes `totalDeposits` or `totalBorrows`.

## How Indices Work

The index represents cumulative interest since reserve initialization:

```
Time 0:  liquidityIndex = 1.0 (RAY)
Time T1: liquidityIndex = 1.0 × (1 + rate × Δt / year) = 1.003 (0.3% earned)
Time T2: liquidityIndex = 1.003 × (1 + rate × Δt / year) = 1.008 (compounding)
```

A user who deposited at T1 with `userLiquidityIndex = 1.003`:
- At T2, their effective multiplier = `1.008 / 1.003 = 1.00498`
- Their balance grows by 0.498%
