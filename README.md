<p align="center">
  <img src="assets/images/fhield-icon.png" alt="fhield" width="120" />
</p>

# fhield

<p align="center"><strong>Privacy-first DeFi lending powered by Fully Homomorphic Encryption.</strong></p>

Built with [Fhenix CoFHE](https://cofhe-docs.fhenix.zone/) for the **Privacy-by-Design dApp Buildathon**.

> To find out more details, read at [https://phuocng0308.github.io/fhield](https://phuocng0308.github.io/fhield)

---

## What is fhield?

fhield is an AAVE V3-inspired lending protocol where **every user position is encrypted on-chain**. You can deposit collateral, borrow assets, repay debt, and get liquidated — all while your balances, health factors, and debt levels remain invisible to everyone except you.

Traditional DeFi is financially transparent by default: anyone can see how much you deposited, how leveraged you are, and when you're close to liquidation. fhield flips that — privacy is the default, transparency is opt-in.

## The Core Insight

DeFi protocols don't actually *need* to see your balances to function. Interest accrual, health checks, and liquidation logic can all operate on **encrypted values** using FHE math. The protocol enforces rules without ever knowing the numbers.

## Why fhield?

### The Problem

In current DeFi lending (Aave, Compound, etc.):

- Your collateral and debt amounts are **publicly visible** to anyone on-chain
- Competitors, MEV bots, and adversaries can monitor your health factor in real-time
- Liquidation bots front-run your repayments by watching your position deteriorate
- Your financial behavior is fully traceable — every deposit, borrow, and repay is an open book

This isn't just a privacy inconvenience — it's a **structural disadvantage** for users and a systemic risk for the protocol.

### Why FHE Solves This

Fhenix CoFHE enables **computation on encrypted data** directly on-chain:

- Collateral and debt balances are stored as `euint64` — encrypted, unreadable on-chain
- The protocol performs health checks, interest accrual, and liquidation using **FHE operations** (add, sub, compare) without ever decrypting
- Only the position owner can decrypt and view their own balances via **ACL-gated sealed outputs**
- ERC20 tokens are wrapped into **FHERC20** — confidential token balances with encrypted transfers

### Why It Matters

- **For users**: Your financial position is private. No one can front-run your liquidation or profile your on-chain behavior
- **For the protocol**: Reduces MEV extraction and creates a fairer lending market
- **For the ecosystem**: Proves that privacy and DeFi composability can coexist — FHE lending is not a tradeoff, it's an upgrade

---

## Deployed Contracts — Arbitrum Sepolia Testnet

All contracts are deployed and verified on **Arbitrum Sepolia** (Chain ID: `421614`).

| Contract | Address |
|---|---|
| **TrustLendPool** | [`0xe2192Fbd78a4b39c19820eb15cf8DB0c240A599F`](https://sepolia.arbiscan.io/address/0xe2192Fbd78a4b39c19820eb15cf8DB0c240A599F) |
| **AssetConfig** | [`0x7A7335e36caF0f1F140Aa450ADad9df5228f70c0`](https://sepolia.arbiscan.io/address/0x7A7335e36caF0f1F140Aa450ADad9df5228f70c0) |
| **PriceOracle** | [`0xF93bE26299D4E6627a1333e02954BA1d88A19C8D`](https://sepolia.arbiscan.io/address/0xF93bE26299D4E6627a1333e02954BA1d88A19C8D) |
| **InterestRateStrategy** | [`0xABf5e393F630c4F9a55AceEB69D9833B0fC79839`](https://sepolia.arbiscan.io/address/0xABf5e393F630c4F9a55AceEB69D9833B0fC79839) |
| **FHERC20 Wrapper (USDC)** | [`0xb9902840Bf04c56Ad2367DE63536b467F8cf46A3`](https://sepolia.arbiscan.io/address/0xb9902840Bf04c56Ad2367DE63536b467F8cf46A3) |
| **FHERC20 Wrapper (WETH)** | [`0xd946372dF9b63481F65924B5E8ed94A13a117c06`](https://sepolia.arbiscan.io/address/0xd946372dF9b63481F65924B5E8ed94A13a117c06) |
| **MockUSDC** | [`0x4674EBAC0805d47E835375397868F49be423648c`](https://sepolia.arbiscan.io/address/0x4674EBAC0805d47E835375397868F49be423648c) |
| **MockWETH** | [`0xeeBD923904B37451d59E43706Fc631882B9DFcB3`](https://sepolia.arbiscan.io/address/0xeeBD923904B37451d59E43706Fc631882B9DFcB3) |
| **CreditScoreStub** | [`0x8587571A6152E09d80C19583c6f8EFd3178FeC14`](https://sepolia.arbiscan.io/address/0x8587571A6152E09d80C19583c6f8EFd3178FeC14) |
| **FhieldBufferStub** | [`0x956d19B69c8B8F768CfFcb40Cc97e3015eb30182`](https://sepolia.arbiscan.io/address/0x956d19B69c8B8F768CfFcb40Cc97e3015eb30182) |

> **Note:** These are testnet contracts for demonstration purposes. FHE operations require the Fhenix CoFHE runtime; on Arbitrum Sepolia, only non-FHE functions (token transfers, oracle reads, config queries) are callable.

---

## Roadmap

### Wave 1: Ideation & Smart Contract Core (Mar 21–28) ✅

- [x] Research Fhenix CoFHE architecture and FHE patterns
- [x] Design TrustLend protocol architecture (AAVE V3-inspired)
- [x] Implement core contracts: `TrustLendPool`, `AssetConfig`, `ReserveLogic`, `PriceOracle`
- [x] Implement `DefaultInterestRateStrategy` (utilization-based kinked curve)
- [x] Implement `FHERC20Wrapper` (ERC20 ↔ encrypted token bridging)
- [x] Build FHE lending math library (`FHELendingMath`, `RayMath`)
- [x] Implement **fhield Buffer Model** — 3-stage privacy-preserving liquidation (blind sweep → instant FHE seizure → Dutch Auction)
- [x] Implement Insurance Fund (bad debt coverage) and Keeper Bounty System (anti-Sybil)
- [x] Create stub modules: `CreditScoreStub`, `PhoenixProgramStub`
- [x] Write comprehensive test suite (46 tests across 5 suites)
- [x] Compile full FHE/CoFHE documentation reference (`docs/`)
- [x] Build fhield-docs site with complete architecture, user flows, and smart contract specs

### Wave 2: Build Frontend (Mar 30 – Apr 6)

- [ ] Migrate from EJS server-rendered to React / Next.js SPA
- [ ] Implement wallet connection flow with viewing key generation
- [ ] Build Dashboard page (TVL, markets overview, APY display)
- [ ] Build Deposit & Withdraw modals with encrypted amount handling
- [ ] Build Borrow & Repay flows with FHE encryption via `@cofhe/sdk`
- [ ] Build Portfolio page with sealed balance decryption
- [ ] Integrate contract interactions via ethers.js + cofhejs

### Wave 3: Full Liquidation Infrastructure (Apr 8 – May 8)

- [ ] Build off-chain Keeper node ecosystem to maintain the Buffer Model
- [ ] Implement Automated Blind Sweep cron jobs
- [ ] Implement Dutch Auction UI for liquidators to bid on seized collateral
- [ ] Backend services to monitor and execute liquidation phases securely
- [ ] *Note: Phoenix Program (Liquidation Relief) has been temporarily deferred due to the complexity of the core liquidation system.*

### Wave 4: CreditScoreModule (May 11–20)

- [ ] Design on-chain encrypted credit scoring model
- [ ] Implement `CreditScoreModule` replacing the stub
- [ ] LTV boost logic based on encrypted repayment history
- [ ] Interest rate discount calculation using FHE comparisons
- [ ] Integration tests with TrustLendPool credit score hooks
- [ ] Frontend: credit score display with sealed decryption

### Wave 5: Polish & Showcase (May 23 – Jun 1)

- [ ] End-to-end testing on Fhenix testnet (Arbitrum Sepolia)
- [ ] Gas optimization and FHE operation batching
- [ ] Documentation site finalization (`fhield-docs`)
- [ ] Demo video and walkthrough
- [ ] Final submission for Privacy-by-Design dApp Buildathon
