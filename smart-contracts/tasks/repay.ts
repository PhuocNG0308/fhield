import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

task("task:repay", "Repay borrowed assets")
  .addParam("pool", "PrivateLendingPool address")
  .addParam("asset", "ERC20 token address to repay")
  .addParam("amount", "Amount to repay (raw units)")
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

      console.log(`Approving ${amount} tokens for repayment...`);
      const approveTx = await erc20.approve(taskArgs.pool, amount);
      await approveTx.wait();

      console.log(`Repaying ${amount} tokens...`);
      const repayTx = await pool.repay(taskArgs.asset, amount);
      await repayTx.wait();

      console.log("Repayment successful!");
    }
  );
