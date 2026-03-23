---
sidebar_position: 2
title: AssetConfig
---

# AssetConfig

Manages the registry of supported collateral assets and their risk parameters.

**Inherits**: `Ownable`

## AssetInfo Struct

```solidity
struct AssetInfo {
    address underlying;          // ERC20 token address
    address wrapper;             // FHERC20Wrapper address
    uint256 ltv;                 // Loan-to-Value in basis points (e.g., 7500 = 75%)
    uint256 liquidationThreshold; // Liquidation trigger in basis points (e.g., 8000 = 80%)
    uint256 liquidationBonus;    // Liquidator incentive in basis points (e.g., 500 = 5%)
    uint256 reserveFactor;       // Protocol revenue share in basis points
    uint8 decimals;              // Token decimals
    bool isActive;               // Whether the asset is enabled
}
```

### Constraints
- `ltv <= liquidationThreshold <= PERCENTAGE_PRECISION (10000)`
- `reserveFactor <= PERCENTAGE_PRECISION`
- `liquidationBonus` is additive (applied on top of debt value during seizure)

## Functions

### `addAsset(AssetInfo calldata info)`

Registers a new supported asset. Owner only.

### `updateAsset(uint256 index, AssetInfo calldata info)`

Modifies parameters of an existing asset. Owner only.

### `toggleAsset(uint256 index)`

Enables or disables an asset. Owner only.

### `getAsset(uint256 index) → AssetInfo`

Returns asset info by index.

### `getAssetCount() → uint256`

Returns number of registered assets.

### `isSupported(address asset) → bool`

Checks if an asset address is registered and active.

## Example Configuration

| Asset | LTV | Liq. Threshold | Liq. Bonus | Reserve Factor | Decimals |
|-------|-----|---------------|------------|----------------|----------|
| USDC | 75% | 80% | 5% | 10% | 6 |
| WETH | 70% | 75% | 10% | 15% | 18 |

### What These Parameters Mean

- **LTV 75%**: For every \$100 of USDC collateral, you can borrow up to \$75
- **Liquidation Threshold 80%**: If your debt exceeds 80% of your collateral value, you become liquidatable
- **Liquidation Bonus 5%**: Liquidators receive collateral worth 105% of the debt they repay
- **Reserve Factor 10%**: 10% of borrow interest goes to the protocol treasury
