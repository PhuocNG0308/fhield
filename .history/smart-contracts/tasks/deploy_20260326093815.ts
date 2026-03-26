import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import * as fs from "fs";
import * as path from "path";

function updateEnvFile(envPath: string, updates: Record<string, string>) {
  let content = fs.existsSync(envPath)
    ? fs.readFileSync(envPath, "utf-8")
    : "";
  for (const [key, value] of Object.entries(updates)) {
    const regex = new RegExp(`^${key}=.*$`, "m");
    if (regex.test(content)) {
      content = content.replace(regex, `${key}=${value}`);
    } else {
      content += `\n${key}=${value}`;
    }
  }
  fs.writeFileSync(envPath, content.trim() + "\n");
}

task("task:deploy", "Deploy the full lending protocol").setAction(
  async (_, hre: HardhatRuntimeEnvironment) => {
    const module = await import(
      "../ignition/modules/DeployLending"
    );
    const result = await hre.ignition.deploy(module.default);

    const addresses = {
      mockUSDC: await result.mockUSDC.getAddress(),
      mockWETH: await result.mockWETH.getAddress(),
      fheUSDC: await result.fheUSDC.getAddress(),
      fheWETH: await result.fheWETH.getAddress(),
      oracle: await result.oracle.getAddress(),
      strategy: await result.strategy.getAddress(),
      assetConfig: await result.assetConfig.getAddress(),
      creditScore: await result.creditScore.getAddress(),
      phoenixProgram: await result.phoenixProgram.getAddress(),
      lendingPool: await result.lendingPool.getAddress(),
    };

    console.log("=== TrustLend Protocol Deployed ===");
    console.log("MockUSDC:", addresses.mockUSDC);
    console.log("MockWETH:", addresses.mockWETH);
    console.log("FHE USDC Wrapper:", addresses.fheUSDC);
    console.log("FHE WETH Wrapper:", addresses.fheWETH);
    console.log("PriceOracle:", addresses.oracle);
    console.log("InterestRateStrategy:", addresses.strategy);
    console.log("AssetConfig:", addresses.assetConfig);
    console.log("CreditScoreStub:", addresses.creditScore);
    console.log("PhoenixProgramStub:", addresses.phoenixProgram);
    console.log("TrustLendPool:", addresses.lendingPool);

    const smartContractsEnv = path.resolve(__dirname, "../.env");
    updateEnvFile(smartContractsEnv, {
      LOCAL_POOL_ADDRESS: addresses.lendingPool,
      LOCAL_ASSET_CONFIG_ADDRESS: addresses.assetConfig,
      LOCAL_ORACLE_ADDRESS: addresses.oracle,
      LOCAL_MOCK_USDC_ADDRESS: addresses.mockUSDC,
      LOCAL_MOCK_WETH_ADDRESS: addresses.mockWETH,
      LOCAL_FHE_USDC_ADDRESS: addresses.fheUSDC,
      LOCAL_FHE_WETH_ADDRESS: addresses.fheWETH,
    });

    const frontendEnv = path.resolve(__dirname, "../../frontend/.env");
    updateEnvFile(frontendEnv, {
      RPC_URL: "http://127.0.0.1:8545",
      CHAIN_ID: "31337",
      POOL_ADDRESS: addresses.lendingPool,
      ASSET_CONFIG_ADDRESS: addresses.assetConfig,
      ORACLE_ADDRESS: addresses.oracle,
      USDC_ADDRESS: addresses.mockUSDC,
      WETH_ADDRESS: addresses.mockWETH,
      FHE_USDC_ADDRESS: addresses.fheUSDC,
      FHE_WETH_ADDRESS: addresses.fheWETH,
    });

    console.log("\n.env files updated for smart-contracts/ and frontend/");
  }
);
