---
sidebar_position: 8
title: Modules
---

# Modules

Fhield includes two **stub modules** that serve as extension points for future features. Both currently return neutral values (0%) but define the interfaces for credit scoring and liquidation relief.

## CreditScoreStub

**Implements**: `ICreditScore`

Provides per-user borrow rate discounts and LTV boosts based on their protocol history.

### Interface

```solidity
interface ICreditScore {
    function getBorrowRateDiscount(address user) external view returns (uint256);
    function getLTVBoost(address user) external view returns (uint256);
}
```

### Current Behavior

Both functions return `0` — no discounts, no LTV boosts for any user.

### Future Vision

| Function | Purpose |
|----------|---------|
| `getBorrowRateDiscount` | Lower borrowing cost for users with good repayment history |
| `getLTVBoost` | Higher borrowing power (LTV) for trusted users, capped at `liquidationThreshold` |

**Integration point** in `TrustLendPool.borrow()`:
```solidity
uint256 ltvBoost = creditScore.getLTVBoost(msg.sender);
euint64 collateralValue = _computeEncryptedCollateralValue(msg.sender, ltvBoost);
```

---

## PhoenixProgramStub

**Implements**: `IPhoenixProgram`

Provides liquidation relief — a subsidy system that can reduce penalties for liquidated users.

### Interface

```solidity
interface IPhoenixProgram {
    function getReliefShare(address user, uint256 penaltyAmount) external view returns (uint256);
    function onLiquidation(address user, uint256 reliefAmount) external;
}
```

### Current Behavior

`getReliefShare()` returns `0` — no relief for any user.

### Future Vision

| Function | Purpose |
|----------|---------|
| `getReliefShare` | Calculate subsidy amount from insurance pool |
| `onLiquidation` | Execute relief payment, emit events, update user score |

**Integration point** in `TrustLendPool._triggerPhoenixRelief()`:
```solidity
uint256 reliefShare = phoenixProgram.getReliefShare(borrower, penaltyAmount);
if (reliefShare > 0) {
    phoenixProgram.onLiquidation(borrower, reliefShare);
}
```

---

## Interfaces

### IInterestRateStrategy

```solidity
interface IInterestRateStrategy {
    function calculateInterestRates(
        uint256 totalDeposits,
        uint256 totalBorrows,
        uint256 reserveFactor
    ) external view returns (uint256 borrowRate, uint256 liquidityRate);
}
```

Consumed by `ReserveLogic.updateRates()` to recalculate APYs after any pool state change.
