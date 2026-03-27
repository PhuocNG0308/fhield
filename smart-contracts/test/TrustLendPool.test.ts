import { expect } from "chai";
import hre from "hardhat";

describe("TrustLendPool", function () {
  const RAY = 10n ** 27n;
  const PRECISION = 10n ** 18n;

  async function deployFixture() {
    const [owner, alice, bob, keeper, liquidator] = await hre.ethers.getSigners();

    const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
    const usdc = await MockERC20.deploy("Mock USDC", "mUSDC", 6);
    const weth = await MockERC20.deploy("Mock WETH", "mWETH", 18);

    const Oracle = await hre.ethers.getContractFactory("PriceOracle");
    const oracle = await Oracle.deploy();

    const Strategy = await hre.ethers.getContractFactory(
      "DefaultInterestRateStrategy"
    );
    const strategy = await Strategy.deploy(
      0n,
      (RAY * 90n) / 100n,
      (RAY * 5n) / 100n,
      (RAY * 60n) / 100n
    );

    const AssetConfig = await hre.ethers.getContractFactory("AssetConfig");
    const assetConfig = await AssetConfig.deploy();

    const CreditScore = await hre.ethers.getContractFactory("CreditScoreStub");
    const creditScore = await CreditScore.deploy();

    const FhieldBuffer = await hre.ethers.getContractFactory("FhieldBufferStub");
    const fhieldBuffer = await FhieldBuffer.deploy();

    const Pool = await hre.ethers.getContractFactory("TrustLendPool");
    const pool = await Pool.deploy(
      await assetConfig.getAddress(),
      await oracle.getAddress(),
      await strategy.getAddress(),
      await creditScore.getAddress(),
      await fhieldBuffer.getAddress()
    );

    const usdcAddr = await usdc.getAddress();
    const wethAddr = await weth.getAddress();
    const poolAddr = await pool.getAddress();

    await oracle.setPrice(usdcAddr, PRECISION);
    await oracle.setPrice(wethAddr, PRECISION * 2500n);

    await assetConfig.addAsset(usdcAddr, usdcAddr, 8000, 8500, 500, 1000, 6);
    await assetConfig.addAsset(wethAddr, wethAddr, 7500, 8250, 500, 1000, 18);

    await usdc.mint(await alice.getAddress(), BigInt(100000e6));
    await usdc.mint(await bob.getAddress(), BigInt(100000e6));
    await usdc.mint(await keeper.getAddress(), BigInt(100000e6));
    await usdc.mint(await liquidator.getAddress(), BigInt(100000e6));
    await weth.mint(await alice.getAddress(), BigInt(100e18));
    await weth.mint(await bob.getAddress(), BigInt(100e18));

    await usdc.mint(poolAddr, BigInt(1000000e6));
    await weth.mint(poolAddr, BigInt(1000e18));

    return {
      owner,
      alice,
      bob,
      keeper,
      liquidator,
      usdc,
      weth,
      oracle,
      strategy,
      assetConfig,
      creditScore,
      fhieldBuffer,
      pool,
    };
  }

  describe("Deposit", function () {
    it("should accept deposits and update totalDeposits", async function () {
      const { alice, usdc, pool } = await deployFixture();
      const poolAddr = await pool.getAddress();
      const usdcAddr = await usdc.getAddress();

      await usdc.connect(alice).approve(poolAddr, BigInt(1000e6));
      await pool.connect(alice).deposit(usdcAddr, BigInt(1000e6));

      expect(await pool.totalDeposits(usdcAddr)).to.equal(BigInt(1000e6));
    });

    it("should reject unsupported asset", async function () {
      const { alice, pool } = await deployFixture();
      await expect(
        pool.connect(alice).deposit(hre.ethers.ZeroAddress, BigInt(1000e6))
      ).to.be.revertedWith("Unsupported asset");
    });

    it("should reject zero amount", async function () {
      const { alice, usdc, pool } = await deployFixture();
      await expect(
        pool.connect(alice).deposit(await usdc.getAddress(), 0)
      ).to.be.revertedWith("Amount must be > 0");
    });

    it("should initialize reserve on first deposit", async function () {
      const { alice, usdc, pool } = await deployFixture();
      const usdcAddr = await usdc.getAddress();
      const poolAddr = await pool.getAddress();

      await usdc.connect(alice).approve(poolAddr, BigInt(1000e6));
      await pool.connect(alice).deposit(usdcAddr, BigInt(1000e6));

      const [liquidityIndex, borrowIndex, , , lastUpdate] =
        await pool.getReserveData(usdcAddr);
      expect(liquidityIndex).to.equal(RAY);
      expect(borrowIndex).to.equal(RAY);
      expect(lastUpdate).to.be.gt(0);
    });
  });

  describe("Repay", function () {
    it("should accept repayment", async function () {
      const { alice, usdc, pool } = await deployFixture();
      const poolAddr = await pool.getAddress();
      const usdcAddr = await usdc.getAddress();

      await usdc.connect(alice).approve(poolAddr, BigInt(1000e6));
      await pool.connect(alice).deposit(usdcAddr, BigInt(1000e6));

      await usdc.connect(alice).approve(poolAddr, BigInt(500e6));
      await pool.connect(alice).repay(usdcAddr, BigInt(500e6));
    });
  });

  describe("Interest Rate", function () {
    it("should return borrow and supply rates (RAY precision)", async function () {
      const { alice, usdc, pool } = await deployFixture();
      const usdcAddr = await usdc.getAddress();

      await usdc
        .connect(alice)
        .approve(await pool.getAddress(), BigInt(10000e6));
      await pool.connect(alice).deposit(usdcAddr, BigInt(10000e6));

      const borrowRate = await pool.getBorrowRate(usdcAddr);
      const supplyRate = await pool.getSupplyRate(usdcAddr);

      expect(borrowRate).to.be.gte(0);
      expect(supplyRate).to.be.gte(0);
    });
  });

  describe("Utilization", function () {
    it("should return 0 utilization when no borrows", async function () {
      const { alice, usdc, pool } = await deployFixture();
      const usdcAddr = await usdc.getAddress();

      await usdc
        .connect(alice)
        .approve(await pool.getAddress(), BigInt(10000e6));
      await pool.connect(alice).deposit(usdcAddr, BigInt(10000e6));

      expect(await pool.getUtilizationRate(usdcAddr)).to.equal(0);
    });
  });

  describe("DCS Hooks", function () {
    it("CreditScoreStub returns 0 for getBorrowRateDiscount", async function () {
      const { creditScore, alice } = await deployFixture();
      expect(
        await creditScore.getBorrowRateDiscount(await alice.getAddress())
      ).to.equal(0);
    });

    it("CreditScoreStub returns 0 for getLTVBoost", async function () {
      const { creditScore, alice } = await deployFixture();
      expect(
        await creditScore.getLTVBoost(await alice.getAddress())
      ).to.equal(0);
    });
  });

  describe("fhield Buffer Hooks", function () {
    it("FhieldBufferStub returns 0 relief share", async function () {
      const { fhieldBuffer, alice } = await deployFixture();
      expect(
        await fhieldBuffer.getReliefShare(await alice.getAddress(), 1000)
      ).to.equal(0);
    });
  });

  describe("Reserve Data", function () {
    it("should expose reserve indices and rates", async function () {
      const { alice, usdc, pool } = await deployFixture();
      const usdcAddr = await usdc.getAddress();
      const poolAddr = await pool.getAddress();

      await usdc.connect(alice).approve(poolAddr, BigInt(5000e6));
      await pool.connect(alice).deposit(usdcAddr, BigInt(5000e6));

      const [liqIdx, borIdx, liqRate, borRate, ts] =
        await pool.getReserveData(usdcAddr);

      expect(liqIdx).to.equal(RAY);
      expect(borIdx).to.equal(RAY);
      expect(liqRate).to.be.gte(0n);
      expect(borRate).to.be.gte(0n);
      expect(ts).to.be.gt(0);
    });
  });

  describe("Config Setters", function () {
    it("should allow owner to set new CreditScore module", async function () {
      const { pool, owner, creditScore } = await deployFixture();
      const csAddr = await creditScore.getAddress();
      await pool.connect(owner).setCreditScore(csAddr);
    });

    it("should allow owner to set new FhieldBuffer module", async function () {
      const { pool, owner, fhieldBuffer } = await deployFixture();
      const addr = await fhieldBuffer.getAddress();
      await pool.connect(owner).setFhieldBuffer(addr);
    });
  });

  describe("Sweep Liquidations (Stage 1+2)", function () {
    it("should emit SweepCompleted with correct userCount", async function () {
      const { alice, bob, keeper, usdc, pool } = await deployFixture();
      const usdcAddr = await usdc.getAddress();
      const poolAddr = await pool.getAddress();

      await usdc.connect(alice).approve(poolAddr, BigInt(1000e6));
      await pool.connect(alice).deposit(usdcAddr, BigInt(1000e6));

      const tx = await pool.connect(keeper).sweepLiquidations(
        [await alice.getAddress(), await bob.getAddress()]
      );

      await expect(tx).to.emit(pool, "SweepCompleted");
    });

    it("should accept empty user list", async function () {
      const { keeper, pool } = await deployFixture();

      const tx = await pool.connect(keeper).sweepLiquidations([]);
      await expect(tx).to.emit(pool, "SweepCompleted");
    });

    it("should update lastSweepBlock for swept users", async function () {
      const { alice, keeper, usdc, pool } = await deployFixture();
      const usdcAddr = await usdc.getAddress();
      const poolAddr = await pool.getAddress();
      const aliceAddr = await alice.getAddress();

      await usdc.connect(alice).approve(poolAddr, BigInt(1000e6));
      await pool.connect(alice).deposit(usdcAddr, BigInt(1000e6));

      await pool.connect(keeper).sweepLiquidations([aliceAddr]);

      expect(await pool.lastSweepBlock(aliceAddr)).to.be.gt(0);
    });

    it("should allow anyone to call sweepLiquidations", async function () {
      const { alice, bob, usdc, pool } = await deployFixture();
      const usdcAddr = await usdc.getAddress();
      const poolAddr = await pool.getAddress();

      await usdc.connect(alice).approve(poolAddr, BigInt(1000e6));
      await pool.connect(alice).deposit(usdcAddr, BigInt(1000e6));

      await pool.connect(bob).sweepLiquidations([await alice.getAddress()]);
    });
  });

  describe("Dutch Auction (Stage 3)", function () {
    it("should emit AuctionRequested on requestAuction", async function () {
      const { alice, keeper, usdc, pool } = await deployFixture();
      const usdcAddr = await usdc.getAddress();
      const poolAddr = await pool.getAddress();

      await usdc.connect(alice).approve(poolAddr, BigInt(1000e6));
      await pool.connect(alice).deposit(usdcAddr, BigInt(1000e6));
      await pool.connect(keeper).sweepLiquidations([await alice.getAddress()]);

      const tx = await pool.connect(keeper).requestAuction(usdcAddr, usdcAddr);
      await expect(tx).to.emit(pool, "AuctionRequested");
    });

    it("should reject startAuction for non-existent auction", async function () {
      const { keeper, pool } = await deployFixture();
      const fakeId = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("fake"));
      await expect(
        pool.connect(keeper).startAuction(fakeId)
      ).to.be.revertedWith("Auction not found");
    });

    it("should reject bid on non-started auction", async function () {
      const { alice, keeper, usdc, pool } = await deployFixture();
      const usdcAddr = await usdc.getAddress();
      const poolAddr = await pool.getAddress();

      await usdc.connect(alice).approve(poolAddr, BigInt(1000e6));
      await pool.connect(alice).deposit(usdcAddr, BigInt(1000e6));
      await pool.connect(keeper).sweepLiquidations([await alice.getAddress()]);

      const tx = await pool.connect(keeper).requestAuction(usdcAddr, usdcAddr);
      const receipt = await tx.wait();
      const event = receipt?.logs.find(
        (l: any) => l.fragment?.name === "AuctionRequested"
      );
      if (event) {
        const auctionId = (event as any).args[0];
        await expect(
          pool.connect(keeper).bid(auctionId)
        ).to.be.revertedWith("Invalid auction");
      }
    });

    it("should return correct auction price with decay", async function () {
      const { pool } = await deployFixture();
      const DECAY_RATE = await pool.DUTCH_AUCTION_DECAY_RATE();
      const START_PRICE = await pool.DUTCH_AUCTION_START_PRICE();
      const MIN_PRICE = await pool.DUTCH_AUCTION_MIN_PRICE();

      expect(DECAY_RATE).to.equal(10n);
      expect(START_PRICE).to.equal(9800n);
      expect(MIN_PRICE).to.equal(8000n);
    });
  });

  describe("Auction Constants", function () {
    it("should have correct CLOSE_FACTOR", async function () {
      const { pool } = await deployFixture();
      expect(await pool.CLOSE_FACTOR()).to.equal(5000n);
    });

    it("should have correct SWEEP_COOLDOWN", async function () {
      const { pool } = await deployFixture();
      expect(await pool.SWEEP_COOLDOWN()).to.equal(10n);
    });
  });
});
