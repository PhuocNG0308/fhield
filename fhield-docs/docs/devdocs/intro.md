---
sidebar_position: 1
title: Overview
---

# Welcome to fhield

**fhield** is a privacy-first DeFi lending protocol built on **Fhenix CoFHE** (Fully Homomorphic Encryption). Users can deposit collateral, borrow assets, and manage positions with **fully encrypted balances** — no one can see your collateral amounts or debt levels except you.

## Key Innovations

:::tip What sets fhield apart
fhield is not just "AAVE with encryption." It introduces **novel FHE-native mechanisms** that are impossible in plaintext DeFi — solving problems that no existing lending protocol has addressed.
:::

### 1. fhield Buffer Model — FHE-Native Liquidation

Traditional lending protocols require liquidators to identify and target individual undercollateralized users. This is fundamentally broken under FHE because balances are encrypted. fhield's **fhield Buffer Model** introduces:

- **Blind Batched Sweeping**: Keepers check users in bulk without knowing who is underwater
- **Instant Encrypted Seizure**: Bad debt is absorbed into the fhield Buffer Pool within encrypted space using `FHE.select()` — zero decryption latency, zero bad debt risk
- **Bulk Dutch Auction**: Aggregated positions are auctioned to liquidators, revealing only the total — never individual positions

→ [Full Liquidation Architecture](/docs/devdocs/User%20Flows/Liquidation)

### 2. Zero-Replacement Pattern — Information-Leak-Free Operations

Instead of reverting on failure (which leaks health status), all encrypted operations silently return zero on failure via `FHE.select()`. An attacker probing a user's health receives the exact same gas cost and tx success status regardless of the result.

### 3. Constant-Time Processing — Side-Channel Resistant

All asset loops iterate every configured asset, not just the user's holdings. This prevents timing and gas analysis attacks from revealing a user's portfolio composition.

### 4. Dynamic Credit Score (DCS) — Future Module

Per-user LTV boosts and rate discounts based on on-chain creditworthiness. Interface ready (`ICreditScore`), currently stubbed at 0%.

### 5. fhield Relief Program — Future Module

Liquidation penalty subsidies for users participating in good-faith protocol usage. Hooks already integrated (`IFhieldBuffer`, `_triggerFhieldRelief()`), currently stubbed at 0%.

## fhield vs. Traditional DeFi

| Feature | Traditional DeFi | fhield |
|---------|-----------------|--------|
| Collateral balance | Public on-chain | Encrypted (`euint64`) |
| Debt balance | Public on-chain | Encrypted (`euint64`) |
| Health check | Public computation | Encrypted comparison via `FHE.select()` |
| Liquidation trigger | Anyone can see who to liquidate | Blind batch sweep — no one knows |
| Liquidation execution | Per-user, exposes amounts | fhield Buffer Pool aggregation, Dutch Auction |
| MEV exposure | High (frontrunning, sandwich) | Near zero (uniform price decay auction) |
| Transfer amounts | Visible in tx data | Encrypted end-to-end (FHERC20) |

## Core Protocol: TrustLend

The smart contract suite powering fhield is called **TrustLend** — an AAVE V3-inspired lending pool with FHE privacy:

| Component | Purpose |
|-----------|---------|
| **TrustLendPool** | Main lending pool — deposit, borrow, repay, withdraw, liquidation |
| **AssetConfig** | Asset registry with LTV, liquidation thresholds, reserve factors |
| **ReserveLogic** | Interest accrual via liquidity/borrow indices (RAY precision) |
| **DefaultInterestRateStrategy** | Utilization-based kinked rate curve |
| **PriceOracle** | On-chain price feed for collateral/debt valuation |
| **FHERC20Wrapper** | ERC20 ↔ FHERC20 confidential token wrapper |
| **CreditScoreStub** | Future: per-user LTV boosts and rate discounts (DCS) |
| **FhieldBufferStub** | Future: fhield Buffer Model full implementation |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Smart Contracts** | Solidity 0.8.25, Hardhat, OpenZeppelin, Fhenix CoFHE |
| **FHE Runtime** | `@fhenixprotocol/cofhe-contracts`, CoFHE Threshold Network |
| **Frontend** | Express.js, EJS, Ethers.js |
| **Testing** | Hardhat + `@cofhe/hardhat-plugin` (local FHE mock) |
| **Networks** | Arbitrum Sepolia, Sepolia, Base Sepolia (testnet) |

## Quick Links

- [Protocol Architecture](/docs/devdocs/Architecture/Protocol-Overview) — How the system works end-to-end
- [Liquidation: fhield Buffer Model](/docs/devdocs/User%20Flows/Liquidation) — fhield's flagship innovation
- [Smart Contracts](/docs/devdocs/Smart%20Contracts/TrustLendPool) — Contract-level documentation
- [User Flows](/docs/devdocs/User%20Flows/Deposit) — Step-by-step operation guides
- [Getting Started](/docs/devdocs/Getting%20Started/Prerequisites) — Setup and deployment
