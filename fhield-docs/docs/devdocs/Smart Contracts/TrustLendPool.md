---
sidebar_position: 1
title: TrustLendPool
---

# TrustLendPool

`TrustLendPool` is the core lending contract. It manages deposits, borrowing, repayment, withdrawal, and the full 3-stage liquidation system (fhield Buffer Model). All user balances are stored as FHE-encrypted `euint64` values.

## State Variables

### Core Mappings

| Variable | Type | Description |
|----------|------|-------------|
| `_collateralBalances[user][asset]` | `euint64` | Encrypted collateral balance |
| `_debtBalances[user][asset]` | `euint64` | Encrypted debt balance |
| `_reserves[asset]` | `ReserveData` | Interest indices and rates |
| `totalDeposits[asset]` | `uint256` | Public aggregate deposits |
| `totalBorrows[asset]` | `uint256` | Public aggregate borrows |

### fhield Buffer Model

| Variable | Type | Description |
|----------|------|-------------|
| `_bufferPools[pairKey]` | `BufferPool` | Encrypted aggregate per collateral-debt pair |
| `_pendingAuctions[pairKey]` | `PendingAuction` | Snapshot of buffer during decrypt (isolates sweep from auction) |
| `auctions[pairKey]` | `Auction` | Dutch Auction state per pair |
| `hasBorrowed[user]` | `bool` | Set `true` on first `borrow()` — anti-Sybil gate for sweeps |
| `lastSweptTimestamp[user]` | `uint256` | Last time user was swept — enforces `SWEEP_COOLDOWN` |
| `insuranceFund[asset]` | `uint256` | Bad debt insurance reserve per asset |
| `keeperBountyReserve[asset]` | `uint256` | Keeper compensation reserve per asset |
| `keeperBountyPerUser` | `uint256` | Bounty per user swept |
| `maxSweepBatchSize` | `uint256` | Max users per sweep call (default 3) |

### Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `CLOSE_FACTOR` | 5000 (50%) | Max debt portion seized per sweep |
| `CLOSE_FACTOR_PRECISION` | 10000 | BPS precision |
| `NORMALIZATION_FACTOR` | 1e6 | FHE-safe index scaling |
| `PRICE_PRECISION` | 1e18 | High-precision scaling for `scaledRatio` computation |
| `AUCTION_DURATION` | 3600 (1h) | Dutch Auction price decay window |
| `AUCTION_START_PREMIUM` | 10500 (105%) | Starting premium over oracle |
| `AUCTION_FLOOR` | 8000 (80%) | Minimum auction price ratio |
| `SWEEP_COOLDOWN` | 600 (10 min) | Minimum interval between sweeps for the same user |

## Public Functions

### User Operations

| Function | Access | Description |
|----------|--------|-------------|
| `deposit(asset, amount)` | Anyone | Supply plaintext ERC20, stores encrypted balance |
| `borrow(asset, InEuint64)` | Anyone | Request encrypted borrow, requires health check |
| `claimBorrow(asset)` | Borrower | Claim after decrypt completes |
| `repay(asset, amount)` | Anyone | Repay plaintext ERC20, reduces encrypted debt |
| `withdraw(asset, InEuint64)` | Anyone | Request encrypted withdrawal, requires health check |
| `claimWithdraw(asset)` | Depositor | Claim after decrypt completes |

### Legacy Liquidation (2-step async)

| Function | Access | Description |
|----------|--------|-------------|
| `liquidationCall(col, debt, borrower)` | Anyone | Initiate liquidation check + decrypt request |
| `executeLiquidation(requestId, debtToCover)` | Liquidator | Execute after decrypt confirms undercollateralization |

### fhield Buffer Model (3-stage)

| Function | Access | Description |
|----------|--------|-------------|
| `sweepLiquidations(users[], col, debt)` | Anyone | Stage 1+2: Blind sweep + instant encrypted seizure |
| `requestBufferDecrypt(col, debt)` | Anyone | Stage 2b: Request aggregate decrypt for a pair |
| `startDutchAuction(col, debt)` | Anyone | Stage 3: Create auction from decrypted buffer |
| `bidDutchAuction(col, debt, amount)` | Anyone | Stage 3: Buy collateral at current auction price |
| `closeDutchAuction(col, debt)` | Anyone | Stage 3: Close expired auction + settle |
| `getAuctionPrice(pairKey)` | View | Current auction price with decay |

### Admin

| Function | Access | Description |
|----------|--------|-------------|
| `setCreditScore(addr)` | Owner | Set credit score module |
| `setPhoenixProgram(addr)` | Owner | Set phoenix relief module |
| `setInterestRateStrategy(addr)` | Owner | Set interest rate strategy |
| `setMaxSweepBatchSize(n)` | Owner | Set max users per sweep (1-10) |
| `setKeeperBounty(amount)` | Owner | Set bounty per user swept |
| `depositKeeperBounty(asset, amount)` | Owner | Fund keeper bounty reserve |
| `depositInsurance(asset, amount)` | Owner | Fund insurance reserve |

## Structs

### BufferPool

```solidity
struct BufferPool {
    euint64 encCollateral;
    euint64 encDebt;
}
```

Keyed by `keccak256(collateralAsset, debtAsset)`. Accumulates encrypted collateral and debt from swept users.

### PendingAuction

```solidity
struct PendingAuction {
    euint64 encCollateral;
    euint64 encDebt;
    bool pending;
}
```

Snapshot of a buffer at the time `requestBufferDecrypt()` is called. Isolates the decrypt/auction flow from ongoing sweeps — new `sweepLiquidations()` calls accumulate into a fresh buffer while the snapshot is being decrypted.

### Auction

```solidity
struct Auction {
    address collateralAsset;
    address debtAsset;
    uint64 collateralRemaining;
    uint64 debtToRecover;
    uint64 debtRecovered;
    uint256 startTime;
    bool active;
}
```

Supports partial fills — liquidators can buy any amount up to `collateralRemaining`.

### LiquidationRequest (Legacy)

```solidity
struct LiquidationRequest {
    address liquidator;
    address borrower;
    address debtAsset;
    address collateralAsset;
    ebool isUndercollateralized;
    bool executed;
}
```

Used by the 2-step async `liquidationCall` / `executeLiquidation` path.

## Events

| Event | Description |
|-------|-------------|
| `Deposit(user, asset, amount)` | Plaintext deposit recorded |
| `Borrow(user, asset)` | Borrow requested (amount encrypted) |
| `BorrowClaimed(user, asset, amount)` | Borrow claimed after decrypt |
| `Repay(user, asset, amount)` | Debt repaid |
| `Withdraw(user, asset)` | Withdrawal requested |
| `WithdrawClaimed(user, asset, amount)` | Withdrawal claimed after decrypt |
| `LiquidationRequested(requestId, borrower, liquidator)` | Legacy liquidation initiated |
| `LiquidationExecuted(requestId, borrower, debtRepaid)` | Legacy liquidation executed |
| `Swept(keeper, colAsset, debtAsset, count)` | Sweep completed |
| `KeeperBountyPaid(keeper, asset, amount)` | Bounty paid |
| `BufferDecryptRequested(pairKey)` | Aggregate decrypt initiated |
| `AuctionStarted(pairKey, col, debt)` | Dutch Auction created |
| `AuctionBid(pairKey, bidder, colBought, debtPaid)` | Bid placed |
| `AuctionSettled(pairKey, debtRecovered, surplus)` | Auction closed |
| `BadDebtCovered(asset, shortfall, covered)` | Insurance fund used |
| `InsuranceDeposited(asset, amount)` | Insurance funded |

## Key Internal Functions

| Function | Description |
|----------|-------------|
| `_sweepUser()` | Per-user FHE health check + seizure with correct bonus math |
| `_closeDutchAuction()` | Surplus/shortfall settlement + insurance |
| `_coverBadDebt()` | Draw from insurance fund |
| `_computeEncryptedCollateralValue()` | Sum encrypted (balance × price × LTV) across all assets |
| `_computeEncryptedLiquidationCollateralValue()` | Same but uses `liquidationThreshold` instead of LTV |
| `_computeEncryptedDebtValue()` | Sum encrypted (debt × price) across all assets |
| `_normalizeDebt()` / `_normalizeCollateral()` | Apply interest accrual via index growth |
| `_accrueAllReserves()` | Accrue interest on all reserves (called once per sweep) |
| `_pairKey()` | `keccak256(col, debt)` for buffer/auction mapping |

## Dependencies

- `AssetConfig` — Asset registry (LTV, thresholds, bonus)
- `PriceOracle` — Asset price feeds
- `IInterestRateStrategy` — Interest rate model
- `ICreditScore` — DCS hooks (LTV boost, rate discount)
- `IPhoenixProgram` — Liquidation relief hook
- `ReserveLogic` — Interest accrual library
- `FHELendingMath` — Encrypted math utilities
- `RayMath` — RAY-precision math library
