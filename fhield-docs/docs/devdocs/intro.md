---
sidebar_position: 1
title: Overview
---

# Welcome to Fhield

**Fhield** is a privacy-first DeFi lending protocol built on **Fhenix CoFHE** (Fully Homomorphic Encryption). Users can deposit collateral, borrow assets, and manage positions with **fully encrypted balances** — no one can see your collateral amounts or debt levels except you.

## What Makes Fhield Different?

Traditional DeFi lending protocols (Aave, Compound) expose every user's position on-chain. Anyone can see how much you deposited, borrowed, and your liquidation risk. Fhield solves this by leveraging FHE:

| Feature | Traditional DeFi | Fhield |
|---------|-----------------|--------|
| Collateral balance | Public on-chain | Encrypted (`euint64`) |
| Debt balance | Public on-chain | Encrypted (`euint64`) |
| Health check | Public computation | Encrypted comparison via `FHE.select()` |
| Liquidation status | Anyone can check | Only revealed via Threshold Network decryption |
| Transfer amounts | Visible in tx data | Encrypted end-to-end |

## Core Protocol: TrustLend

The smart contract suite powering Fhield is called **TrustLend** — an AAVE V3-inspired lending pool with FHE privacy:

| Component | Purpose |
|-----------|---------|
| **TrustLendPool** | Main lending pool — deposit, borrow, repay, withdraw, liquidation |
| **AssetConfig** | Asset registry with LTV, liquidation thresholds, reserve factors |
| **ReserveLogic** | Interest accrual via liquidity/borrow indices (RAY precision) |
| **DefaultInterestRateStrategy** | Utilization-based kinked rate curve |
| **PriceOracle** | On-chain price feed for collateral/debt valuation |
| **FHERC20Wrapper** | ERC20 ↔ FHERC20 confidential token wrapper |
| **CreditScoreStub** | Future: per-user LTV boosts and rate discounts |
| **PhoenixProgramStub** | Future: liquidation relief/subsidy system |

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
- [Smart Contracts](/docs/devdocs/Smart%20Contracts/TrustLendPool) — Contract-level documentation
- [User Flows](/docs/devdocs/User%20Flows/Deposit) — Step-by-step operation guides
- [Getting Started](/docs/devdocs/Getting%20Started/Prerequisites) — Setup and deployment
