---
sidebar_position: 1
title: TrustLendPool
---

# TrustLendPool

The main lending pool contract. Handles deposits, borrowing, repayments, withdrawals, and liquidations with encrypted balances.

**Inherits**: `AccessControl`, `ReentrancyGuard`

## State Variables

```solidity
mapping(address => mapping(address => euint64)) _collateralBalances;
mapping(address => mapping(address => euint64)) _debtBalances;
mapping(address => uint256) public totalDeposits;
mapping(address => uint256) public totalBorrows;
mapping(address => uint256) public userLiquidityIndex;
mapping(address => uint256) public userBorrowIndex;
mapping(address => ReserveLogic.ReserveData) public reserves;
```

| Variable | Type | Description |
|----------|------|-------------|
| `_collateralBalances` | `euint64` | User's encrypted deposit per asset |
| `_debtBalances` | `euint64` | User's encrypted borrow per asset |
| `totalDeposits` | `uint256` | Plaintext global total deposits per asset |
| `totalBorrows` | `uint256` | Plaintext global total borrows per asset |
| `userLiquidityIndex` | `uint256` | User's stored liquidity index (for normalization) |
| `userBorrowIndex` | `uint256` | User's stored borrow index (for normalization) |
| `reserves` | `ReserveData` | Per-asset reserve state (indices, rates, timestamp) |

### Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `CLOSE_FACTOR` | 5000 (50%) | Max debt repayable in single liquidation |
| `NORMALIZATION_FACTOR` | 1e6 | Scaling factor for FHE index normalization |

## Core Functions

### `deposit(address asset, uint64 amount)`

Deposits plaintext amount as encrypted collateral.

**Flow**:
1. Accrues interest on the asset's reserve
2. Transfers ERC20 tokens from user to contract
3. Encrypts amount as `euint64`
4. If first deposit: stores directly; otherwise normalizes existing balance and adds
5. Grants FHE ACL: `FHE.allowThis()` + `FHE.allow(msg.sender)`
6. Updates `totalDeposits[asset]`
7. Recalculates interest rates

**Events**: `Deposit(address user, address asset, uint64 amount)`

---

### `borrow(address asset, InEuint64 calldata encryptedAmount)`

Requests an encrypted borrow amount. Step 1 of 2 (async).

**Flow**:
1. Converts `InEuint64` to `euint64` via `FHE.asEuint64()`
2. Computes encrypted collateral value across ALL assets (LTV-adjusted, with CreditScore LTV boost)
3. Computes encrypted debt value across ALL assets
4. Encrypted health check: `collateralValue >= currentDebt + newBorrow`
5. `FHE.select(healthy, requestedAmount, zero)` — caps to 0 if unhealthy
6. Stores actual amount in `_pendingBorrows[user][asset]`
7. Triggers `FHE.decrypt()` for off-chain processing

**Events**: `Borrow(address user, address asset)`

---

### `claimBorrow(address asset)`

Claims a previously requested borrow after decryption completes. Step 2 of 2.

**Flow**:
1. Reads pending borrow for user
2. Calls `FHE.getDecryptResultSafe()` — reverts if not ready
3. Transfers plaintext amount to user
4. Updates `totalBorrows[asset]` and interest rates

**Events**: `BorrowClaimed(address user, address asset, uint256 amount)`

---

### `repay(address asset, uint64 amount)`

Repays debt with plaintext amount.

**Flow**:
1. Accrues interest
2. Transfers ERC20 from user
3. Normalizes user's encrypted debt (applies index growth)
4. `actualRepay = min(amount, normalizedDebt)` via `FHELendingMath.encryptedMin()`
5. Subtracts from encrypted debt
6. Updates `totalBorrows[asset]` and interest rates

**Events**: `Repay(address user, address asset, uint64 amount)`

---

### `withdraw(address asset, InEuint64 calldata encryptedAmount)`

Requests encrypted withdrawal. Step 1 of 2 (async).

**Flow**:
1. Normalizes collateral balance
2. `actualWithdraw = min(requested, balance)` via `encryptedMin()`
3. Computes post-withdrawal collateral value
4. Health check: `newCollateral >= debt`
5. `FHE.select(healthy, actualWithdraw, zero)`
6. Triggers `FHE.decrypt()` for off-chain processing

**Events**: `Withdraw(address user, address asset)`

---

### `claimWithdraw(address asset)`

Claims a previously requested withdrawal. Step 2 of 2.

**Flow**:
1. Reads pending withdrawal
2. `FHE.getDecryptResultSafe()` — reverts if not ready
3. Transfers plaintext amount to user
4. Updates `totalDeposits[asset]` and interest rates

**Events**: `WithdrawClaimed(address user, address asset, uint256 amount)`

---

### `liquidationCall(address collateralAsset, address debtAsset, address borrower)`

Initiates liquidation check for a borrower. Step 1 of 2 (async).

**Flow**:
1. Accrues interest on debt asset
2. Computes encrypted collateral value (using `liquidationThreshold`, not LTV)
3. Computes encrypted debt value
4. `isUndercollateralized = FHE.lt(collateral, debt)` — encrypted boolean
5. Stores `LiquidationRequest` with encrypted flag
6. Triggers `FHE.decrypt(isUndercollateralized)`

**Returns**: `uint256 requestId`

**Events**: `LiquidationRequested(uint256 requestId, address borrower, address liquidator)`

---

### `executeLiquidation(uint256 requestId, uint64 debtToCover)`

Executes liquidation if health check failed. Step 2 of 2.

**Flow**:
1. Reads decrypt result — must be `true` (undercollateralized)
2. Liquidator transfers `debtToCover` tokens
3. Repays portion of borrower's encrypted debt
4. Calculates collateral seizure: `(debtToCover × debtPrice × (1 + bonus)) / collateralPrice`
5. Triggers Phoenix Program relief hook (currently 0%)
6. Seizes collateral from borrower, transfers to liquidator

**Events**: `LiquidationExecuted(uint256 requestId, address borrower, uint256 debtRepaid)`

## Internal Functions

### `_normalizeCollateral(euint64 balance, address user, address asset)`

Applies accrued interest to a user's encrypted deposit balance.

Calculates growth = `(currentLiquidityIndex / userLiquidityIndex)` scaled by NORMALIZATION_FACTOR, then multiplies encrypted balance.

### `_normalizeDebt(euint64 debt, address user, address asset)`

Same as above but for borrow index.

### `_computeEncryptedCollateralValue(address user, uint256 ltvBoost)`

Iterates all assets, normalizes each balance, multiplies by `(price × ltvBps × NORMALIZATION_FACTOR)`, sums into total encrypted value.

### `_computeEncryptedDebtValue(address user)`

Same pattern but for debt — normalizes each debt balance, multiplies by price.

### `_triggerPhoenixRelief(address borrower, uint256 penaltyAmount)`

Calls PhoenixProgram stub to check if user qualifies for liquidation relief.
