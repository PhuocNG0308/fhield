---
sidebar_position: 6
title: FHERC20Wrapper
---

# FHERC20Wrapper

Wraps standard ERC20 tokens into FHERC20 confidential tokens with encrypted balances and private transfers.

**Inherits**: `AccessControl`, `ReentrancyGuard`

## Key Features

- **1:1 Backing**: Every wrapped FHERC20 token is backed by an ERC20 token held in the contract
- **Encrypted Balances**: `_confidentialBalances` stored as `euint64`
- **Indicator System**: `_indicatedBalances` (`uint16`, 0-9999) provides a non-revealing activity indicator
- **Operator Model**: Time-based permission system for delegated operations
- **Zero-Replacement**: Transfer exceeding balance silently transfers 0 (no revert)

## State Variables

```solidity
mapping(address => euint64) _confidentialBalances;   // Real balance, encrypted
mapping(address => uint16) _indicatedBalances;        // Activity indicator
mapping(address => mapping(address => bool)) _operators; // Permissions
uint256 public totalWrapped;                          // Total ERC20 locked
```

## Functions

### `wrap(uint64 amount)`

Deposits ERC20 and mints equivalent encrypted FHERC20.

1. Transfers ERC20 from caller to contract
2. Creates encrypted amount: `FHE.asEuint64(amount)`
3. Adds to caller's `_confidentialBalances`
4. Grants ACL: `FHE.allowThis()` + `FHE.allow(msg.sender)`
5. Updates `totalWrapped`

### `unwrap(InEuint64 calldata encryptedAmount)`

Requests destruction of FHERC20 to reclaim ERC20. Step 1 of async unwrap.

1. Converts input to `euint64`
2. Caps to actual balance via `encryptedMin`
3. Subtracts from encrypted balance
4. Triggers `FHE.decrypt()` for off-chain processing
5. Returns `claimId` for later retrieval

### `claimUnwrapped(bytes32 claimId)`

Claims ERC20 after decryption completes. Step 2 of async unwrap.

1. Reads decrypt result via `FHE.getDecryptResultSafe()`
2. Transfers plaintext amount of ERC20 to caller
3. Updates `totalWrapped`

### `confidentialTransfer(address to, InEuint64 calldata encryptedAmount)`

Transfers encrypted amount between two users.

1. Converts input to `euint64`
2. Caps to sender's balance: `actualAmount = min(requested, senderBalance)`
3. Subtracts from sender, adds to receiver (all encrypted)
4. Updates ACL for both parties
5. Updates indicator balances

### `setOperator(address operator, bool approved)`

Grants or revokes time-based permission for another address to operate on the user's tokens.

## Indicator Balance System

The `_indicatedBalances` field provides a non-revealing way to show approximate activity level without exposing the actual balance. Values range from 0-9999 and are updated on deposits/transfers but do not reflect the real encrypted balance.
