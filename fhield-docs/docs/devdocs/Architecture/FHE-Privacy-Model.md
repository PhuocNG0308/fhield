---
sidebar_position: 2
title: FHE Privacy Model
---

# FHE Privacy Model

Fhield uses Fhenix's Fully Homomorphic Encryption (FHE) to keep user positions private. This page explains the encryption model, key FHE patterns used in the protocol, and trade-offs.

## Encrypted Types in Fhield

| Type | Usage |
|------|-------|
| `euint64` | Collateral balances, debt balances, transfer amounts |
| `ebool` | Health check results (is undercollateralized?) |
| `InEuint64` | Client-encrypted input (borrow amount, withdraw amount) |

All encrypted values are **handles** — references to ciphertexts stored off-chain by the CoFHE infrastructure. On-chain contracts only store 32-byte handles, not the actual encrypted data.

## Key FHE Patterns

### 1. Zero-Replacement (No Reverts on Failure)

In traditional Solidity, you would write:
```solidity
require(collateralValue >= newDebtValue, "Unhealthy position");
```

In FHE, encrypted values cannot be used in `require()` or `if` statements. Instead, Fhield uses `FHE.select()`:

```solidity
ebool isHealthy = FHE.gte(collateralValue, newDebtValue);
euint64 actualBorrow = FHE.select(isHealthy, requestedAmount, FHE.asEuint64(0));
```

If the health check fails, the borrow amount silently becomes 0. No revert occurs — this prevents attackers from learning whether a position is healthy by observing revert/success patterns.

### 2. Constant-Time Asset Loops

When computing collateral or debt value, TrustLendPool iterates **all** configured assets, not just the assets the user holds:

```solidity
for (uint256 i = 0; i < assetConfig.getAssetCount(); i++) {
    AssetConfig.AssetInfo memory info = assetConfig.getAsset(i);
    // Always compute — even if user has zero balance in this asset
    euint64 balance = _collateralBalances[user][info.underlying];
    // ... multiply by price, add to total
}
```

This prevents an observer from deducing which assets a user holds by counting which loop iterations produce state changes.

### 3. ACL Management

After every mutation to an encrypted value, the contract must re-grant access:

```solidity
_collateralBalances[user][asset] = newBalance;
FHE.allowThis(newBalance);    // Contract can use it in future operations
FHE.allow(newBalance, user);  // User can decrypt via Threshold Network
```

Without `FHE.allowThis()`, the contract loses access to the ciphertext on the next transaction. Without `FHE.allow(user)`, the user cannot decrypt their own balance.

### 4. Two-Step Async Decryption

When the protocol needs a plaintext value (e.g., to transfer ERC20 tokens), it:

1. Stores the encrypted result and calls `FHE.decrypt(encryptedValue)`
2. The Threshold Network processes the decryption off-chain
3. A second transaction (`claimBorrow`, `claimWithdraw`) reads the decrypted result via `FHE.getDecryptResultSafe()`

This pattern is used for:
- **Borrow**: `borrow()` → wait → `claimBorrow()`
- **Withdraw**: `withdraw()` → wait → `claimWithdraw()`
- **Liquidation**: `liquidationCall()` → wait → `executeLiquidation()`

### 5. Trivial Encryption for Constants

Non-sensitive constants (like zero) can be created via trivial encryption:

```solidity
euint64 zero = FHE.asEuint64(0);
```

This is NOT secure for user secrets — it creates a ciphertext whose plaintext is known. It's only used for protocol constants (initial balances, comparison values).

## Privacy Boundaries

### What the Protocol Hides
- How much each user deposited per asset
- How much each user borrowed per asset
- Whether a specific user is close to liquidation
- Individual transfer amounts in FHERC20

### What Remains Public
- That a user interacted with the protocol (tx from their address)
- Global pool utilization (total deposits / total borrows)
- Current interest rates
- Asset prices
- Which assets are supported
- Protocol parameters (LTV, thresholds)

### Information Leakage Mitigations

| Attack Vector | Mitigation |
|--------------|-----------|
| Revert analysis (probe health) | Zero-replacement pattern |
| Gas analysis (detect asset composition) | Constant-time loops |
| Event analysis (track amounts) | Events emit user address only, not amounts (for encrypted ops) |
| Timing analysis (decrypt latency) | Async two-step — all decrypts go through same pipeline |

## Trade-offs

1. **Async UX**: Borrow/Withdraw require two transactions (request + claim), adding latency
2. **Plaintext Totals**: Global `totalDeposits` and `totalBorrows` must stay public for interest rate calculation. This reveals aggregate pool metrics but not individual positions
3. **Gas Cost**: FHE operations are more expensive than plaintext operations (each triggers an off-chain task)
4. **Deposit Amount**: Currently, `deposit()` takes a plaintext `uint64` amount (visible in calldata). The `wrap()` function in FHERC20Wrapper provides fully encrypted deposits
