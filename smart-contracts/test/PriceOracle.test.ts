import { expect } from "chai";
import hre from "hardhat";

describe("PriceOracle", function () {
  async function deployFixture() {
    const [owner, other] = await hre.ethers.getSigners();
    const Oracle = await hre.ethers.getContractFactory("PriceOracle");
    const oracle = await Oracle.deploy();

    const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
    const token = await MockERC20.deploy("Test", "TST", 18);

    return { oracle, owner, other, token };
  }

  it("should let owner set price", async function () {
    const { oracle, token } = await deployFixture();
    const tokenAddr = await token.getAddress();
    await oracle.setPrice(tokenAddr, 1000n);
    expect(await oracle.getPrice(tokenAddr)).to.equal(1000n);
  });

  it("should revert for non-owner", async function () {
    const { oracle, other, token } = await deployFixture();
    const tokenAddr = await token.getAddress();
    await expect(
      oracle.connect(other).setPrice(tokenAddr, 1000n)
    ).to.be.reverted;
  });

  it("should revert for unset price", async function () {
    const { oracle, token } = await deployFixture();
    const tokenAddr = await token.getAddress();
    await expect(oracle.getPrice(tokenAddr)).to.be.revertedWith("Price not set");
  });

  it("should set batch prices", async function () {
    const { oracle, token } = await deployFixture();
    const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
    const token2 = await MockERC20.deploy("Test2", "TST2", 6);

    const addr1 = await token.getAddress();
    const addr2 = await token2.getAddress();

    await oracle.setBatchPrices([addr1, addr2], [100n, 200n]);
    expect(await oracle.getPrice(addr1)).to.equal(100n);
    expect(await oracle.getPrice(addr2)).to.equal(200n);
  });
});
