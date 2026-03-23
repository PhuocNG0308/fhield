import { expect } from "chai";
import hre from "hardhat";

describe("DefaultInterestRateStrategy", function () {
  const RAY = 10n ** 27n;

  const baseRate = 0n;
  const optimalUtilization = (RAY * 90n) / 100n;
  const slope1 = (RAY * 5n) / 100n;
  const slope2 = (RAY * 60n) / 100n;
  const reserveFactor = (RAY * 10n) / 100n;

  async function deployFixture() {
    const [owner] = await hre.ethers.getSigners();
    const Strategy = await hre.ethers.getContractFactory(
      "DefaultInterestRateStrategy"
    );
    const strategy = await Strategy.deploy(
      baseRate,
      optimalUtilization,
      slope1,
      slope2
    );
    return { strategy, owner };
  }

  it("should return 0 borrow rate when utilization is 0", async function () {
    const { strategy } = await deployFixture();
    const [borrowRate] = await strategy.calculateInterestRates(1000, 0, reserveFactor);
    expect(borrowRate).to.equal(baseRate);
  });

  it("should return baseRate when totalDeposits is 0", async function () {
    const { strategy } = await deployFixture();
    const [borrowRate, liquidityRate] = await strategy.calculateInterestRates(
      0,
      0,
      reserveFactor
    );
    expect(borrowRate).to.equal(baseRate);
    expect(liquidityRate).to.equal(0n);
  });

  it("should compute correct rate at optimal utilization (kink)", async function () {
    const { strategy } = await deployFixture();
    // U = 90% → exactly at kink → Rb = R0 + M1 = 0 + 5% = 5%
    const [borrowRate] = await strategy.calculateInterestRates(
      1000,
      900,
      reserveFactor
    );
    const expected = baseRate + slope1;
    // Allow small rounding error
    const diff = borrowRate > expected ? borrowRate - expected : expected - borrowRate;
    expect(diff).to.be.lt(RAY / 10000n);
  });

  it("should compute correct rate above optimal (steep slope)", async function () {
    const { strategy } = await deployFixture();
    // U = 95% → excess = 5%, maxExcess = 10%
    // Rb = 0 + 5% + (5%/10%) * 60% = 5% + 30% = 35%
    const [borrowRate] = await strategy.calculateInterestRates(
      1000,
      950,
      reserveFactor
    );
    const expected = baseRate + slope1 + (slope2 * 50n) / 100n;
    const diff =
      borrowRate > expected ? borrowRate - expected : expected - borrowRate;
    expect(diff).to.be.lt(RAY / 1000n);
  });

  it("should increase rate steeply above optimal", async function () {
    const { strategy } = await deployFixture();
    const [rateBelow] = await strategy.calculateInterestRates(1000, 800, reserveFactor);
    const [rateAbove] = await strategy.calculateInterestRates(1000, 950, reserveFactor);
    expect(rateAbove).to.be.gt(rateBelow);
    expect(rateAbove - rateBelow).to.be.gt(slope1);
  });

  it("should compute supply rate = Rb * U * (1 - RF)", async function () {
    const { strategy } = await deployFixture();
    const [borrowRate, liquidityRate] = await strategy.calculateInterestRates(
      1000,
      500,
      reserveFactor
    );
    // U = 50%, RF = 10% → supply = borrow * 0.5 * 0.9
    expect(liquidityRate).to.be.gt(0n);
    expect(liquidityRate).to.be.lt(borrowRate);
  });

  it("should return 0 supply rate when no borrows", async function () {
    const { strategy } = await deployFixture();
    const [, liquidityRate] = await strategy.calculateInterestRates(
      1000,
      0,
      reserveFactor
    );
    expect(liquidityRate).to.equal(0n);
  });

  it("should allow owner to update params", async function () {
    const { strategy, owner } = await deployFixture();
    const newBase = (RAY * 2n) / 100n;
    await strategy
      .connect(owner)
      .updateParams(newBase, optimalUtilization, slope1, slope2);
    expect(await strategy.baseVariableBorrowRate()).to.equal(newBase);
  });
});
