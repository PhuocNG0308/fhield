import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

task("task:deposit", "Deposit collateral into the lending pool")
  .addParam("pool", "PrivateLendingPool address")
  .addParam("asset", "ERC20 token address")
  .addParam("amount", "Amount to deposit (raw units)")
  .setAction(
    async (
      taskArgs: { pool: string; asset: string; amount: string },
      hre: HardhatRuntimeEnvironment
    ) => {
      const [signer] = await hre.ethers.getSigners();

      const erc20 = await hre.ethers.getContractAt(
        "MockERC20",
        taskArgs.asset,
        signer
      );
      const pool = await hre.ethers.getContractAt(
        "TrustLendPool",
        taskArgs.pool,
        signer
      );

      const amount = BigInt(taskArgs.amount);

      console.log(`Approving ${amount} tokens...`);
      const approveTx = await erc20.approve(taskArgs.pool, amount);
      await approveTx.wait();

      console.log(`Depositing ${amount} tokens into pool...`);
      const depositTx = await pool.deposit(taskArgs.asset, amount);
      await depositTx.wait();

      console.log("Deposit successful!");
    }
  );
