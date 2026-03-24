---
sidebar_position: 2
title: Installation
---

# Installation

## Clone the Repository

```bash
git clone https://github.com/PhuocNG0308/fhield.git
cd fhield
```

## Smart Contracts Setup

```bash
cd smart-contracts
pnpm install
```

### Hardhat Configuration

The project uses Hardhat 2.22.19 with the following key settings:

```typescript
// hardhat.config.ts
{
  solidity: {
    version: "0.8.25",
    settings: {
      optimizer: { enabled: true, runs: 200 },
      viaIR: true,          // Required for stack depth in FHE contracts
      evmVersion: "cancun"
    }
  }
}
```

:::info
`viaIR: true` is required because FHE operations generate deep call stacks that exceed the default Solidity stack limit.
:::

### Environment Variables

Create a `.env` file in `smart-contracts/`:

```bash
# Network
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
PRIVATE_KEY=0x...

# Verification
ARBISCAN_API_KEY=...
```

### Run Tests

```bash
npx hardhat test
```

All 32 tests across 5 suites should pass:
- `AssetConfig.test.ts` — Asset registry operations
- `DefaultInterestRateStrategy.test.ts` — Rate curve calculations
- `FHERC20Wrapper.test.ts` — Token wrapping & encrypted transfers
- `PriceOracle.test.ts` — Oracle price management
- `TrustLendPool.test.ts` — Full lending protocol flows

## Frontend Setup

```bash
cd frontend
pnpm install
```

### Environment Variables

Create a `.env` file in `frontend/`:

```bash
# Contract Addresses (set after deployment)
POOL_ADDRESS=0x...
ASSET_CONFIG_ADDRESS=0x...
ORACLE_ADDRESS=0x...
USDC_ADDRESS=0x...
WETH_ADDRESS=0x...
FHE_USDC_ADDRESS=0x...
FHE_WETH_ADDRESS=0x...

# Network
RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
CHAIN_ID=421614

# Server
PORT=3000
```

### Start Development Server

```bash
node server.js
```

The frontend runs at `http://localhost:3000` with routes:
- `/dashboard` — Portfolio overview
- `/lend` — Supply/deposit
- `/borrow` — Borrow interface
- `/portfolio` — Position details
- `/markets` — Market stats
