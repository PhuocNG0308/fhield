import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

task("task:borrow", "Borrow assets from the lending pool (step 1: submit)")
  .addParam("pool", "PrivateLendingPool address")
  .addParam("asset", "ERC20 token address to borrow")
  .addParam("amount", "Amount to borrow (raw units)")
  .setAction(
    async (
      taskArgs: { pool: string; asset: string; amount: string },
      hre: HardhatRuntimeEnvironment
    ) => {
      const [signer] = await hre.ethers.getSigners();
      const { cofhejs, Encryptable } = await import("cofhejs/node");
      const { cofhejs_initializeWithHardhatSigner } = await import(
        "cofhe-hardhat-plugin"
      );

      await cofhejs_initializeWithHardhatSigner(hre, signer);

      const pool = await hre.ethers.getContractAt(
        "TrustLendPool",
        taskArgs.pool,
        signer
      );

      const amount = BigInt(taskArgs.amount);
      console.log(`Encrypting borrow amount: ${amount}...`);

      const result = await cofhejs.encrypt(
        [Encryptable.uint64(amount)]
      );
      if (!result.success) throw new Error("Encryption failed");
      const [encryptedAmount] = result.data;

      console.log("Submitting borrow request...");
      const tx = await pool.borrow(taskArgs.asset, encryptedAmount);
      await tx.wait();

      console.log("Borrow request submitted! Use task:claim-borrow to claim after decrypt.");
    }
  );

task("task:claim-borrow", "Claim borrowed assets (step 2: after decrypt)")
  .addParam("pool", "PrivateLendingPool address")
  .addParam("asset", "ERC20 token address")
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

      console.log("Claiming borrow...");
      const tx = await pool.claimBorrow(taskArgs.asset);
      const receipt = await tx.wait();

      console.log("Borrow claimed! TX:", receipt!.hash);
    }
  );
