---
sidebar_position: 4
title: Testing
---

# Testing

## Running Tests

```bash
cd smart-contracts
npx hardhat test
```

## Test Suites

### AssetConfig.test.ts
Tests the asset registry:
- Adding assets with valid parameters
- Updating asset configurations
- Toggling active/inactive status
- Validation of LTV ≤ liquidationThreshold constraints
- Reading asset info by index

### DefaultInterestRateStrategy.test.ts
Tests the interest rate curve:
- Base rate when utilization is 0%
- Linear rate increase below optimal utilization
- Steep rate increase above optimal (penalty zone)
- Supply rate calculation with reserve factor
- Edge cases: 100% utilization, 0 deposits

### FHERC20Wrapper.test.ts
Tests encrypted token operations:
- Wrapping ERC20 → FHERC20
- Unwrapping FHERC20 → ERC20 (async)
- Confidential transfers between users
- Balance encryption and ACL
- Operator permissions

### PriceOracle.test.ts
Tests the oracle:
- Setting individual prices
- Batch price updates
- Reading prices
- Owner access control

### TrustLendPool.test.ts
Tests the full lending protocol:
- Deposit and encrypted balance storage
- Borrow with encrypted health check
- Repay and debt reduction
- Withdraw with health verification
- Interest accrual and index growth
- Liquidation flow
- **Sweep Liquidations (Stage 1+2)**: batch sweep with correct event emission, empty batch rejection, `maxSweepBatchSize` enforcement, permissionless access
- **Dutch Auction (Stage 3)**: reject operations when no active auction, correct auction constants (`AUCTION_DURATION`, `AUCTION_START_PREMIUM`, `AUCTION_FLOOR`)
- **Buffer Model Constants**: `CLOSE_FACTOR`, `maxSweepBatchSize`, keeper bounty configuration, insurance fund deposits

## Testing with FHE Mock

The `@cofhe/hardhat-plugin` provides a local FHE mock that simulates:
- Encrypted type operations (add, sub, mul, comparison)
- ACL checks (allowThis, allow, isAllowed)
- Decrypt simulation (instant, not async)
- Input encryption (InEuint64 → euint64)

### Using the Test Client

```typescript
import { createClientWithBatteries } from "@cofhe/hardhat-plugin";

const client = await hre.cofhe.createClientWithBatteries(signer);
```

### Asserting Encrypted Values

```typescript
// Check plaintext value of a ciphertext handle
await hre.cofhe.mocks.expectPlaintext(ctHash, expectedValue);
```

## BigInt Precision

:::warning
When working with RAY values (1e27) in tests, always use BigInt literals:

```typescript
// Correct
const RAY = 10n ** 27n;

// Wrong — loses precision due to float64
const RAY = BigInt(1e27);
```
:::
