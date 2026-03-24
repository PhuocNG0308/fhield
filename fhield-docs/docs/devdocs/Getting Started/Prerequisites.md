---
sidebar_position: 1
title: Prerequisites
---

# Prerequisites

## System Requirements

- **Node.js** 20+
- **pnpm** (recommended) or npm
- **Git**

## Supported Networks

| Network | Chain ID | Status |
|---------|----------|--------|
| Arbitrum Sepolia | 421614 | Primary testnet |
| Sepolia | 11155111 | Supported |
| Base Sepolia | 84532 | Future support |

## Package Dependencies

### Smart Contracts

| Package | Version | Purpose |
|---------|---------|---------|
| `@fhenixprotocol/cofhe-contracts` | ^0.1.0 | FHE.sol, encrypted types, ACL |
| `@openzeppelin/contracts` | ^5.0.0 | AccessControl, ERC20, ReentrancyGuard |
| `hardhat` | 2.22.19 | Build & test framework |
| `@cofhe/hardhat-plugin` | ^0.4.0 | Local FHE mock for testing |

### Frontend

| Package | Version | Purpose |
|---------|---------|---------|
| `express` | ^4.x | Web server |
| `ethers` | ^6.x | Blockchain interaction |
| `ejs` | ^3.x | Template rendering |

### Client SDK (for encrypted operations)

| Package | Version | Purpose |
|---------|---------|---------|
| `@cofhe/sdk` | ^0.4.0 | Encrypt inputs, decrypt results, permits |
