---
sidebar_position: 5
title: PriceOracle
---

# PriceOracle

Simple owner-controlled oracle for asset price feeds. Provides price data used in collateral/debt value calculations.

**Inherits**: `Ownable`

## Functions

### `setPrice(address asset, uint256 price)`

Sets the price for a single asset. Owner only.

### `setBatchPrices(address[] calldata assets, uint256[] calldata prices)`

Sets prices for multiple assets in one transaction. Owner only.

### `getPrice(address asset) → uint256`

Returns the current price for an asset.

## Usage in TrustLendPool

The oracle provides prices for:
- **Collateral valuation**: `collateralAmount × collateralPrice × LTV`
- **Debt valuation**: `debtAmount × debtPrice`
- **Liquidation seizure**: `(debtToCover × debtPrice × (1 + bonus)) / collateralPrice`

:::caution
This is a mock oracle controlled by the contract owner. For production, integrate a decentralized oracle (Chainlink, Pyth) for tamper-resistant price feeds.
:::
