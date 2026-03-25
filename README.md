# fhield

**Privacy-first DeFi lending powered by Fully Homomorphic Encryption.**

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

## Roadmap

### Wave 1: Ideation & Smart Contract Core (Mar 21–28) ✅

- [x] Research Fhenix CoFHE architecture and FHE patterns
- [x] Design TrustLend protocol architecture (AAVE V3-inspired)
- [x] Implement core contracts: `TrustLendPool`, `AssetConfig`, `ReserveLogic`, `PriceOracle`
- [x] Implement `DefaultInterestRateStrategy` (utilization-based kinked curve)
- [x] Implement `FHERC20Wrapper` (ERC20 ↔ encrypted token bridging)
- [x] Build FHE lending math library (`FHELendingMath`, `RayMath`)
- [x] Create stub modules: `CreditScoreStub`, `PhoenixProgramStub`
- [x] Write comprehensive test suite (32 tests across 5 suites)
- [x] Compile full FHE/CoFHE documentation reference (`docs/`)

### Wave 2: React Frontend (Mar 30 – Apr 6)

- [ ] Migrate from EJS server-rendered to React SPA
- [ ] Implement wallet connection flow with viewing key generation
- [ ] Build Dashboard page (TVL, markets overview, APY display)
- [ ] Build Deposit & Withdraw modals with encrypted amount handling
- [ ] Build Borrow & Repay flows with FHE encryption via `@cofhe/sdk`
- [ ] Build Portfolio page with sealed balance decryption
- [ ] Integrate contract interactions via ethers.js + cofhejs

### Wave 3: CreditScoreModule (Apr 8 – May 8)

- [ ] Design on-chain encrypted credit scoring model
- [ ] Implement `CreditScoreModule` replacing the stub
- [ ] LTV boost logic based on encrypted repayment history
- [ ] Interest rate discount calculation using FHE comparisons
- [ ] Integration tests with TrustLendPool credit score hooks
- [ ] Frontend: credit score display with sealed decryption

### Wave 4: PhoenixProgramModule (May 11–20)

- [ ] Design liquidation relief / subsidy mechanism
- [ ] Implement `PhoenixProgramModule` replacing the stub
- [ ] Threshold-based relief triggers using encrypted health factors
- [ ] Subsidy pool funding and distribution logic
- [ ] Integration tests with TrustLendPool liquidation flow
- [ ] Frontend: Phoenix program status and opt-in UI

### Wave 5: Polish & Showcase (May 23 – Jun 1)

- [ ] End-to-end testing on Fhenix testnet (Arbitrum Sepolia)
- [ ] Gas optimization and FHE operation batching
- [ ] Documentation site finalization (`fhield-docs`)
- [ ] Demo video and walkthrough
- [ ] Final submission for Privacy-by-Design dApp Buildathon
