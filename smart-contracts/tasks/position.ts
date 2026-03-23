import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

task("task:position", "View your encrypted position (aggregate public data)")
  .addParam("pool", "PrivateLendingPool address")
  .addParam("asset", "Asset address to check")
  .setAction(
    async (
      taskArgs: { pool: string; asset: string },
      hre: HardhatRuntimeEnvironment
    ) => {
      const [signer] = await hre.ethers.getSigners();

      const pool = await hre.ethers.getContractAt(
        "TrustLendPool",
        taskArgs.pool,
        signer
      );

      const totalDeposits = await pool.totalDeposits(taskArgs.asset);
      const totalBorrows = await pool.totalBorrows(taskArgs.asset);
      const utilization = await pool.getUtilizationRate(taskArgs.asset);
      const borrowRate = await pool.getBorrowRate(taskArgs.asset);
      const supplyRate = await pool.getSupplyRate(taskArgs.asset);

      console.log("=== Pool Stats (Public) ===");
      console.log(`Total Deposits: ${totalDeposits}`);
      console.log(`Total Borrows: ${totalBorrows}`);
      console.log(`Utilization Rate: ${utilization}`);
      console.log(`Borrow Rate (annual): ${borrowRate}`);
      console.log(`Supply Rate (annual): ${supplyRate}`);

      console.log("\n=== Your Position (Encrypted) ===");
      console.log(
        "Collateral and debt balances are encrypted."
      );
      console.log(
        "Use cofhejs decryptForView() with your permit to see plaintext values."
      );
    }
  );
