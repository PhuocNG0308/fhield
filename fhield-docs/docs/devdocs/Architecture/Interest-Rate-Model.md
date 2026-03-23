---
sidebar_position: 3
title: Interest Rate Model
---

import InterestRateChart from '@site/src/components/InterestRateChart';

# Interest Rate Model

Fhield uses an AAVE V3-style **kinked interest rate curve** that adjusts borrowing and supply rates based on pool utilization. The model incentivizes balanced usage — rates stay low when utilization is below optimal, and spike sharply above it to encourage repayments.

## Rate Strategy Parameters

| Parameter | Description | Example |
|-----------|------------|---------|
| `baseVariableBorrowRate` | Minimum borrow APY regardless of utilization | 2% |
| `optimalUtilization` | Target utilization ratio | 80% |
| `variableRateSlope1` | Rate slope below optimal utilization | 4% |
| `variableRateSlope2` | Rate slope above optimal utilization (penalty zone) | 50% |
| `reserveFactor` | Protocol revenue share taken from supply APY | 10% |

All values stored in RAY precision (1e27).

## Formulas

### Utilization Rate

```math
U = \frac{\text{totalBorrows}}{\text{totalDeposits}}
```

### Borrow Rate

```math
borrowRate = \begin{cases}
baseRate + \dfrac{U}{U_{optimal}} \times slope_1 & \text{if } U \le U_{optimal} \\[10pt]
baseRate + slope_1 + \dfrac{U - U_{optimal}}{1 - U_{optimal}} \times slope_2 & \text{if } U > U_{optimal}
\end{cases}
```

### Supply Rate

```math
supplyRate = borrowRate \times U \times (1 - reserveFactor)
```

## Rate Curve Visualization

### Standard Strategy (WETH)

<InterestRateChart configs={[
  { baseRate: 2, optimalUtil: 80, slope1: 4, slope2: 50, reserveFactor: 10, label: "Standard (WETH) — base: 2%, optimal: 80%, slope1: 4%, slope2: 50%" }
]} />

## Example Scenarios

| Utilization | Borrow Rate | Supply Rate (10% reserve) |
|-------------|-------------|--------------------------|
| 0% | 2.0% | 0.0% |
| 25% | 3.25% | 0.73% |
| 50% | 4.5% | 2.03% |
| 80% (optimal) | 6.0% | 4.32% |
| 90% | 31.0% | 25.11% |
| 100% | 56.0% | 50.40% |

## Strategy Comparison

<InterestRateChart configs={[
  { baseRate: 1, optimalUtil: 90, slope1: 3, slope2: 75, reserveFactor: 10, label: "Conservative (Stablecoin) — base: 1%, optimal: 90%, slope1: 3%, slope2: 75%" },
  { baseRate: 2, optimalUtil: 80, slope1: 4, slope2: 50, reserveFactor: 10, label: "Standard (WETH) — base: 2%, optimal: 80%, slope1: 4%, slope2: 50%" },
  { baseRate: 5, optimalUtil: 65, slope1: 8, slope2: 100, reserveFactor: 10, label: "Aggressive (Volatile) — base: 5%, optimal: 65%, slope1: 8%, slope2: 100%" },
]} />

## Interest Accrual

Interest compounds over time using **liquidity** and **borrow** indices:

### Reserve State (per asset)

```solidity
struct ReserveData {
    uint256 liquidityIndex;          // Grows for depositors (supply APY)
    uint256 variableBorrowIndex;     // Grows for borrowers (borrow APY)
    uint256 currentLiquidityRate;    // Current supply APY (RAY)
    uint256 currentVariableBorrowRate; // Current borrow APY (RAY)
    uint40 lastUpdateTimestamp;
}
```

### Compound Interest Calculation

When `accrueInterest()` is called, elapsed seconds since last update are used to compound:

```math
newIndex = oldIndex \times \left(1 + \frac{rate \times \Delta t}{\text{SECONDS\_PER\_YEAR}}\right)
```

Where:
- $index$ = liquidity or borrow index
- $rate$ = current rate (supply or borrow)
- $\Delta t$ = seconds elapsed
- SECONDS_PER_YEAR = 31,536,000 (365 days)

The implementation uses a 3rd-order Taylor expansion for precision:

```math
(1 + x)^n \approx 1 + nx + \frac{n(n-1)}{2} x^2 + \frac{n(n-1)(n-2)}{6} x^3
```

### User Balance Normalization

When a user's encrypted balance is accessed, it's **normalized** by the ratio of current to stored index:

```math
currentBalance = storedBalance \times \frac{currentIndex}{storedIndex}
```

This is done in encrypted space using `FHELendingMath.mulByPlaintext()` and `FHELendingMath.divByPlaintext()`, with a `NORMALIZATION_FACTOR` of 1e6 to keep values within `euint64` safe range.

## Reserve Factor

The reserve factor determines how much of the borrow interest goes to the protocol versus depositors:

- **Depositors receive**: $borrowRate \times utilization \times (1 - reserveFactor)$
- **Protocol reserves**: The remainder accumulates as protocol revenue

With a 10% reserve factor at 80% utilization and 6% borrow rate:
- Depositors earn: 6% × 80% × 90% = **4.32% APY**
- Protocol earns: 6% × 80% × 10% = **0.48%** of total deposits annually
