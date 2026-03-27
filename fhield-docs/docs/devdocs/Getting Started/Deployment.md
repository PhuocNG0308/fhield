---
sidebar_position: 3
title: Deployment
---

# Deployment

## Deploy Contracts

fhield uses Hardhat Ignition for deployment. The deployment sequence matters because contracts reference each other.

### Deployment Order

1. **PriceOracle** — No dependencies
2. **DefaultInterestRateStrategy** — No dependencies
3. **AssetConfig** — No dependencies
4. **CreditScoreStub** — No dependencies
5. **FhieldBufferStub** — No dependencies
6. **TrustLendPool** — Depends on all above
7. **FHERC20Wrapper** (per asset) — Depends on each ERC20 token

### Deploy to Arbitrum Sepolia

```bash
cd smart-contracts
npx hardhat run tasks/deploy.ts --network arbitrumSepolia
```

### Configure Assets After Deployment

Once contracts are deployed, configure supported assets:

```bash
# Add USDC as collateral
npx hardhat addAsset \
  --pool <POOL_ADDRESS> \
  --config <ASSET_CONFIG_ADDRESS> \
  --underlying <USDC_ADDRESS> \
  --wrapper <FHE_USDC_ADDRESS> \
  --ltv 7500 \
  --liquidation-threshold 8000 \
  --liquidation-bonus 500 \
  --reserve-factor 1000 \
  --decimals 6 \
  --network arbitrumSepolia
```

### Set Asset Prices

```bash
npx hardhat setPrice \
  --oracle <ORACLE_ADDRESS> \
  --asset <USDC_ADDRESS> \
  --price 1000000 \
  --network arbitrumSepolia
```

### Verify Contracts

```bash
npx hardhat verify --network arbitrumSepolia <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

## Post-Deployment Checklist

- [ ] All contracts deployed and verified
- [ ] Assets added to AssetConfig with correct parameters
- [ ] Prices set in PriceOracle
- [ ] TrustLendPool has approval to transfer FHERC20 tokens
- [ ] Frontend `.env` updated with all contract addresses
- [ ] Frontend tested against live contracts
