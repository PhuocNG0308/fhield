import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const USER_ADDRESS = "0x111b63dc532d5a03fb74ef582dae7847c52f5c77";

task("task:setup-local", "Fund user wallet + mint mock tokens for local testing")
  .addOptionalParam("user", "Address to fund", USER_ADDRESS)
  .setAction(
    async (
      taskArgs: { user: string },
      hre: HardhatRuntimeEnvironment
    ) => {
      const [deployer] = await hre.ethers.getSigners();
      const user = taskArgs.user;

      console.log(`Deployer: ${deployer.address}`);
      console.log(`Funding user: ${user}`);

      const deployerBalance = await hre.ethers.provider.getBalance(deployer.address);
      console.log(`Deployer ETH balance: ${hre.ethers.formatEther(deployerBalance)} ETH`);

      const ethToSend = hre.ethers.parseEther("1000");
      if (deployerBalance > ethToSend) {
        const tx = await deployer.sendTransaction({
          to: user,
          value: ethToSend,
        });
        await tx.wait();
        console.log(`Sent 1000 ETH to ${user}`);
      } else {
        console.log("Deployer has insufficient ETH, skipping ETH transfer");
      }

      const module = await import("../ignition/modules/DeployLending");
      const deployResult = await hre.ignition.deploy(module.default);

      const mockUSDC = await hre.ethers.getContractAt(
        "MockERC20",
        await deployResult.mockUSDC.getAddress()
      );
      const mockWETH = await hre.ethers.getContractAt(
        "MockERC20",
        await deployResult.mockWETH.getAddress()
      );

      const usdcAmount = 1_000_000n * 10n ** 6n; // 1M USDC
      const wethAmount = 100n * 10n ** 18n; // 100 WETH

      await (await mockUSDC.mint(user, usdcAmount)).wait();
      console.log(`Minted 1,000,000 mUSDC to ${user}`);

      await (await mockWETH.mint(user, wethAmount)).wait();
      console.log(`Minted 100 mWETH to ${user}`);

      await (await mockUSDC.mint(deployer.address, usdcAmount)).wait();
      await (await mockWETH.mint(deployer.address, wethAmount)).wait();
      console.log(`Minted tokens to deployer for liquidity`);

      const pool = await hre.ethers.getContractAt(
        "TrustLendPool",
        await deployResult.lendingPool.getAddress()
      );

      const seedUSDC = 100_000n * 10n ** 6n;
      const seedWETH = 10n * 10n ** 18n;

      await (await mockUSDC.approve(await pool.getAddress(), seedUSDC)).wait();
      await (await pool.deposit(await mockUSDC.getAddress(), seedUSDC)).wait();
      console.log(`Seeded pool with 100,000 mUSDC liquidity`);

      await (await mockWETH.approve(await pool.getAddress(), seedWETH)).wait();
      await (await pool.deposit(await mockWETH.getAddress(), seedWETH)).wait();
      console.log(`Seeded pool with 10 mWETH liquidity`);

      const userETH = await hre.ethers.provider.getBalance(user);
      const userUSDC = await mockUSDC.balanceOf(user);
      const userWETH = await mockWETH.balanceOf(user);

      console.log("\n=== User Wallet Summary ===");
      console.log(`Address: ${user}`);
      console.log(`ETH: ${hre.ethers.formatEther(userETH)}`);
      console.log(`mUSDC: ${hre.ethers.formatUnits(userUSDC, 6)}`);
      console.log(`mWETH: ${hre.ethers.formatEther(userWETH)}`);
      console.log("\n=== Setup Complete ===");
    }
  );
