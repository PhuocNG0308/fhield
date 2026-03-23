import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

task("task:deploy", "Deploy the full lending protocol").setAction(
  async (_, hre: HardhatRuntimeEnvironment) => {
    const module = await import(
      "../ignition/modules/DeployLending"
    );
    const result = await hre.ignition.deploy(module.default);

    console.log("=== TrustLend Protocol Deployed ===");
    console.log("MockUSDC:", await result.mockUSDC.getAddress());
    console.log("MockWETH:", await result.mockWETH.getAddress());
    console.log("FHE USDC Wrapper:", await result.fheUSDC.getAddress());
    console.log("FHE WETH Wrapper:", await result.fheWETH.getAddress());
    console.log("PriceOracle:", await result.oracle.getAddress());
    console.log("InterestRateStrategy:", await result.strategy.getAddress());
    console.log("AssetConfig:", await result.assetConfig.getAddress());
    console.log("CreditScoreStub:", await result.creditScore.getAddress());
    console.log("PhoenixProgramStub:", await result.phoenixProgram.getAddress());
    console.log("TrustLendPool:", await result.lendingPool.getAddress());
  }
);
