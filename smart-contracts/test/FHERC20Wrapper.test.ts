import { expect } from "chai";
import hre from "hardhat";

describe("FHERC20Wrapper", function () {
  async function deployFixture() {
    const [owner, alice, bob] = await hre.ethers.getSigners();

    const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
    const underlying = await MockERC20.deploy("Mock USDC", "mUSDC", 6);

    const Wrapper = await hre.ethers.getContractFactory("FHERC20Wrapper");
    const wrapper = await Wrapper.deploy(
      await underlying.getAddress(),
      "FHE USDC",
      "fUSDC"
    );

    await underlying.mint(await alice.getAddress(), BigInt(100000e6));
    await underlying.mint(await bob.getAddress(), BigInt(100000e6));

    return { owner, alice, bob, underlying, wrapper };
  }

  describe("Wrap", function () {
    it("should wrap ERC20 tokens", async function () {
      const { alice, underlying, wrapper } = await deployFixture();
      const wrapperAddr = await wrapper.getAddress();

      await underlying.connect(alice).approve(wrapperAddr, BigInt(1000e6));
      await wrapper.connect(alice).wrap(BigInt(1000e6));

      expect(await wrapper.totalWrapped()).to.equal(BigInt(1000e6));
      expect(await wrapper.indicatedBalanceOf(await alice.getAddress())).to.equal(5001);
    });

    it("should reject zero amount", async function () {
      const { alice, wrapper } = await deployFixture();
      await expect(wrapper.connect(alice).wrap(0n)).to.be.revertedWith(
        "Amount must be > 0"
      );
    });
  });

  describe("Operator", function () {
    it("should set and check operator", async function () {
      const { alice, bob, wrapper } = await deployFixture();
      const aliceAddr = await alice.getAddress();
      const bobAddr = await bob.getAddress();

      await wrapper.connect(alice).setOperator(bobAddr, true);
      expect(await wrapper.isOperator(aliceAddr, bobAddr)).to.be.true;

      await wrapper.connect(alice).setOperator(bobAddr, false);
      expect(await wrapper.isOperator(aliceAddr, bobAddr)).to.be.false;
    });
  });
});
