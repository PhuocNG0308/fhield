import { expect } from "chai";
import hre from "hardhat";

describe("AssetConfig", function () {
  async function deployFixture() {
    const [owner, other] = await hre.ethers.getSigners();

    const AssetConfig = await hre.ethers.getContractFactory("AssetConfig");
    const config = await AssetConfig.deploy();

    const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
    const token = await MockERC20.deploy("Token", "TKN", 18);
    const wrapper = await MockERC20.deploy("Wrapper", "wTKN", 18);

    return {
      config,
      owner,
      other,
      token,
      wrapper,
    };
  }

  it("should add a new asset", async function () {
    const { config, token, wrapper } = await deployFixture();
    const tokenAddr = await token.getAddress();
    const wrapperAddr = await wrapper.getAddress();

    await config.addAsset(tokenAddr, wrapperAddr, 8000, 8500, 500, 1000, 18);

    expect(await config.isSupported(tokenAddr)).to.be.true;
    expect(await config.getAssetCount()).to.equal(1);
  });

  it("should reject duplicate asset", async function () {
    const { config, token, wrapper } = await deployFixture();
    const tokenAddr = await token.getAddress();
    const wrapperAddr = await wrapper.getAddress();

    await config.addAsset(tokenAddr, wrapperAddr, 8000, 8500, 500, 1000, 18);
    await expect(
      config.addAsset(tokenAddr, wrapperAddr, 8000, 8500, 500, 1000, 18)
    ).to.be.revertedWith("Already added");
  });

  it("should reject LTV > threshold", async function () {
    const { config, token, wrapper } = await deployFixture();
    await expect(
      config.addAsset(
        await token.getAddress(),
        await wrapper.getAddress(),
        9000,
        8500,
        500,
        1000,
        18
      )
    ).to.be.revertedWith("LTV > threshold");
  });

  it("should toggle asset active state", async function () {
    const { config, token, wrapper } = await deployFixture();
    const tokenAddr = await token.getAddress();
    await config.addAsset(tokenAddr, await wrapper.getAddress(), 8000, 8500, 500, 1000, 18);

    await config.toggleAsset(tokenAddr, false);
    expect(await config.isSupported(tokenAddr)).to.be.false;

    await config.toggleAsset(tokenAddr, true);
    expect(await config.isSupported(tokenAddr)).to.be.true;
  });
});
