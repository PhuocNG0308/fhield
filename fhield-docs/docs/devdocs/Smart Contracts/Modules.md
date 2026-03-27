---
sidebar_position: 8
title: Modules
---

# Modules

fhield includes **stub modules** that serve as extension points for future features, plus an **on-chain insurance fund** and **keeper bounty system** integrated directly into `TrustLendPool`.

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

## FhieldBufferStub (Legacy Relief)

**Implements**: `IFhieldBuffer`

Provides liquidation relief — a subsidy system that can reduce penalties for liquidated users.

### Interface

```solidity
interface IFhieldBuffer {
    function getReliefShare(address user, uint256 penaltyAmount) external view returns (uint256);
    function onLiquidation(address user, uint256 reliefAmount) external;
}
```

### Current Behavior

`getReliefShare()` returns `0` — no relief for any user. This is used by the legacy `executeLiquidation()` path.

---

## PhoenixProgram (Relief Hook)

**Implements**: `IPhoenixProgram`

The Phoenix Program is the protocol's subsidy mechanism for liquidated users — it can reduce the effective penalty by redirecting a portion of the liquidation bonus.

### Interface

```solidity
interface IPhoenixProgram {
    function getReliefShare(address liquidatedUser, uint256 penaltyAmount) external view returns (uint256);
    function onLiquidation(address liquidatedUser, uint256 reliefAmount) external;
}
```

### Integration

Called via `_triggerPhoenixRelief()` during legacy liquidation execution:
```solidity
uint256 reliefShare = phoenixProgram.getReliefShare(borrower, penaltyAmount);
if (reliefShare > 0) {
    phoenixProgram.onLiquidation(borrower, reliefShare);
}
```

---

## Insurance Fund

The protocol maintains a **per-asset insurance reserve** (`insuranceFund[asset]`) directly in `TrustLendPool` to cover bad debt from Dutch Auction shortfalls.

### How It Works

1. **Funding**: Owner deposits via `depositInsurance(asset, amount)`
2. **Surplus accumulation**: When a Dutch Auction recovers more debt than owed, the surplus is added to `insuranceFund[debtAsset]`
3. **Bad debt coverage**: When an auction recovers less than owed, `_coverBadDebt()` draws from the insurance fund to absorb the shortfall

```solidity
function _coverBadDebt(address debtAsset, uint256 shortfall) internal {
    uint256 covered;
    if (insuranceFund[debtAsset] >= shortfall) {
        insuranceFund[debtAsset] -= shortfall;
        covered = shortfall;
    } else {
        covered = insuranceFund[debtAsset];
        insuranceFund[debtAsset] = 0;
    }
    emit BadDebtCovered(debtAsset, shortfall, covered);
}
```

### Events

| Event | Description |
|-------|-------------|
| `InsuranceDeposited(asset, amount)` | Owner funded the insurance reserve |
| `BadDebtCovered(asset, shortfall, covered)` | Insurance absorbed (partial or full) shortfall |

---

## Keeper Bounty System

Keepers who call `sweepLiquidations()` are compensated with a **fixed bounty per user actually swept**. Anti-Sybil guards ensure only legitimate borrowers consume bounty:

- **`hasBorrowed` gate**: Only users who have called `borrow()` at least once are swept — empty wallets are skipped
- **`SWEEP_COOLDOWN` (600s)**: Each user can only be swept once per 10 minutes — prevents repeated bounty claims on the same user
- Bounty is calculated as `sweptCount * keeperBountyPerUser` where `sweptCount` only includes users that passed both gates

### Configuration

| Function | Access | Description |
|----------|--------|-------------|
| `setKeeperBounty(uint256)` | Owner | Set bounty amount per user swept |
| `depositKeeperBounty(asset, amount)` | Owner | Fund the keeper bounty reserve for an asset |

### How It Works

After processing all users in `sweepLiquidations()`:
```solidity
uint256 bounty = swept * keeperBountyPerUser;
if (bounty > 0 && keeperBountyReserve[debtAsset] >= bounty) {
    keeperBountyReserve[debtAsset] -= bounty;
    IERC20(debtAsset).safeTransfer(msg.sender, bounty);
}
```

### Events

| Event | Description |
|-------|-------------|
| `KeeperBountyPaid(keeper, asset, amount)` | Bounty paid to keeper after sweep |

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
