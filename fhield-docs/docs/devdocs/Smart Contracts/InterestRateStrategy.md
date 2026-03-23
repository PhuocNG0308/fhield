---
sidebar_position: 4
title: InterestRateStrategy
---

import InterestRateChart from '@site/src/components/InterestRateChart';

# DefaultInterestRateStrategy

Calculates variable borrow and supply rates based on pool utilization using a kinked curve model.

**Inherits**: `IInterestRateStrategy`

## Constructor Parameters

```solidity
constructor(
    uint256 _baseVariableBorrowRate,  // e.g., 2% = 0.02e27
    uint256 _optimalUtilization,      // e.g., 80% = 0.8e27
    uint256 _variableRateSlope1,      // e.g., 4% = 0.04e27
    uint256 _variableRateSlope2       // e.g., 50% = 0.5e27
)
```

All parameters are immutable and set at deployment.

## `calculateInterestRates(uint256 totalDeposits, uint256 totalBorrows, uint256 reserveFactor)`

**Returns**: `(uint256 borrowRate, uint256 liquidityRate)` — both in RAY

**Logic**:
1. If `totalDeposits == 0`: return `(baseRate, 0)`
2. Calculate utilization: `totalBorrows × RAY / totalDeposits`
3. If utilization ≤ optimal:
   - `borrowRate = base + (utilization / optimal) × slope1`
4. If utilization > optimal:
   - `excess = utilization - optimal`
   - `borrowRate = base + slope1 + (excess / (RAY - optimal)) × slope2`
5. `liquidityRate = borrowRate × utilization / RAY × (RAY - reserveFactor) / RAY`

## Typical Configurations

<InterestRateChart configs={[
  { baseRate: 1, optimalUtil: 90, slope1: 3, slope2: 75, reserveFactor: 10, label: "Conservative (Stablecoin) — base: 1%, optimal: 90%, slope1: 3%, slope2: 75%" },
  { baseRate: 2, optimalUtil: 80, slope1: 4, slope2: 50, reserveFactor: 10, label: "Standard (WETH) — base: 2%, optimal: 80%, slope1: 4%, slope2: 50%" },
  { baseRate: 5, optimalUtil: 65, slope1: 8, slope2: 100, reserveFactor: 10, label: "Aggressive (Volatile) — base: 5%, optimal: 65%, slope1: 8%, slope2: 100%" },
]} />

### Conservative (Stablecoin)
```
base: 1%, optimal: 90%, slope1: 3%, slope2: 75%
```
Low base, high optimal — stablecoins are expected to be heavily utilized.

### Standard (WETH)
```
base: 2%, optimal: 80%, slope1: 4%, slope2: 50%
```
Moderate parameters — balances capital efficiency with safety margins.

### Aggressive (Volatile)
```
base: 5%, optimal: 65%, slope1: 8%, slope2: 100%
```
Higher base and slopes — discourages over-borrowing of volatile assets.
