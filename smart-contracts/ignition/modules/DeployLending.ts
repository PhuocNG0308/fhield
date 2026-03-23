import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DeployLendingModule = buildModule("DeployLending", (m) => {
  const mockUSDC = m.contract("MockERC20", ["Mock USDC", "mUSDC", 6], {
    id: "MockUSDC",
  });
  const mockWETH = m.contract("MockERC20", ["Mock WETH", "mWETH", 18], {
    id: "MockWETH",
  });

  const fheUSDC = m.contract(
    "FHERC20Wrapper",
    [mockUSDC, "FHE USDC", "fUSDC"],
    { id: "FheUSDC" }
  );
  const fheWETH = m.contract(
    "FHERC20Wrapper",
    [mockWETH, "FHE WETH", "fWETH"],
    { id: "FheWETH" }
  );

  const oracle = m.contract("PriceOracle", []);

  // USDC Params: R0=0, U_optimal=90%, M1=5%, M2=60% (all in RAY = 1e27)
  const strategy = m.contract("DefaultInterestRateStrategy", [
    "0",                            // baseRate = 0
    "900000000000000000000000000",   // optimalUtilization = 0.9e27
    "50000000000000000000000000",    // slope1 = 0.05e27
    "600000000000000000000000000",   // slope2 = 0.6e27
  ]);

  const assetConfig = m.contract("AssetConfig", []);
  const creditScore = m.contract("CreditScoreStub", []);
  const phoenixProgram = m.contract("PhoenixProgramStub", []);

  const lendingPool = m.contract("TrustLendPool", [
    assetConfig,
    oracle,
    strategy,
    creditScore,
    phoenixProgram,
  ]);

  // USDC: LTV 80%, liq threshold 85%, bonus 5%, RF 10%, 6 decimals
  m.call(assetConfig, "addAsset", [mockUSDC, fheUSDC, 8000, 8500, 500, 1000, 6], {
    id: "addUSDC",
  });
  // WETH: LTV 75%, liq threshold 82.5%, bonus 5%, RF 10%, 18 decimals
  m.call(assetConfig, "addAsset", [mockWETH, fheWETH, 7500, 8250, 500, 1000, 18], {
    id: "addWETH",
  });

  // Prices: USDC=$1, WETH=$2500 (18 decimals)
  m.call(oracle, "setPrice", [mockUSDC, "1000000000000000000"], {
    id: "priceUSDC",
  });
  m.call(oracle, "setPrice", [mockWETH, "2500000000000000000000"], {
    id: "priceWETH",
  });

  return {
    mockUSDC,
    mockWETH,
    fheUSDC,
    fheWETH,
    oracle,
    strategy,
    assetConfig,
    creditScore,
    phoenixProgram,
    lendingPool,
  };
});

export default DeployLendingModule;
