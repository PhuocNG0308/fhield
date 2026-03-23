const { ethers } = require('ethers');
const contracts = require('../config/contracts');

const RAY = 10n ** 27n;
const WAD = 10n ** 18n;

let _provider = null;
let _poolContract = null;
let _assetConfigContract = null;
let _oracleContract = null;

function getProvider() {
  if (!_provider && contracts.rpcUrl) {
    _provider = new ethers.JsonRpcProvider(contracts.rpcUrl);
  }
  return _provider;
}

function getPoolContract() {
  if (!_poolContract) {
    const provider = getProvider();
    if (!provider || !contracts.addresses.pool) return null;
    _poolContract = new ethers.Contract(contracts.addresses.pool, contracts.POOL_ABI, provider);
  }
  return _poolContract;
}

function getAssetConfigContract() {
  if (!_assetConfigContract) {
    const provider = getProvider();
    if (!provider || !contracts.addresses.assetConfig) return null;
    _assetConfigContract = new ethers.Contract(contracts.addresses.assetConfig, contracts.ASSET_CONFIG_ABI, provider);
  }
  return _assetConfigContract;
}

function getOracleContract() {
  if (!_oracleContract) {
    const provider = getProvider();
    if (!provider || !contracts.addresses.oracle) return null;
    _oracleContract = new ethers.Contract(contracts.addresses.oracle, contracts.ORACLE_ABI, provider);
  }
  return _oracleContract;
}

function rayToPercent(rayValue) {
  return Number((rayValue * 10000n) / RAY) / 100;
}

function wadToNumber(wadValue, decimals = 18) {
  return Number(wadValue) / (10 ** decimals);
}

async function getAssetMarketData(assetSymbol) {
  const pool = getPoolContract();
  const oracle = getOracleContract();
  const assetAddr = contracts.addresses.assets[assetSymbol];
  if (!pool || !oracle || !assetAddr) return null;

  try {
    const [totalDeposits, totalBorrows, borrowRate, supplyRate, price] = await Promise.all([
      pool.totalDeposits(assetAddr),
      pool.totalBorrows(assetAddr),
      pool.getBorrowRate(assetAddr),
      pool.getSupplyRate(assetAddr),
      oracle.getPrice(assetAddr),
    ]);

    const decimals = assetSymbol === 'WETH' ? 18 : 6;
    const priceNum = wadToNumber(price, 18);
    const depositsNum = wadToNumber(totalDeposits, decimals);
    const borrowsNum = wadToNumber(totalBorrows, decimals);

    const suppliedUSD = depositsNum * priceNum;
    const borrowedUSD = borrowsNum * priceNum;
    const utilization = suppliedUSD > 0 ? Math.round((borrowedUSD / suppliedUSD) * 100) : 0;

    return {
      supplied: suppliedUSD,
      borrowed: borrowedUSD,
      suppliedFmt: `$${(suppliedUSD / 1e6).toFixed(1)}M`,
      borrowedFmt: `$${(borrowedUSD / 1e6).toFixed(1)}M`,
      supplyAPY: rayToPercent(supplyRate),
      borrowAPY: rayToPercent(borrowRate),
      utilization,
      price: priceNum,
      totalDepositsRaw: totalDeposits.toString(),
      totalBorrowsRaw: totalBorrows.toString(),
    };
  } catch (err) {
    console.error(`[ContractService] Failed to read ${assetSymbol} market data:`, err.message);
    return null;
  }
}

async function getAllMarketData() {
  const results = {};
  const symbols = Object.keys(contracts.addresses.assets);

  for (const sym of symbols) {
    const data = await getAssetMarketData(sym);
    if (data) results[sym] = data;
  }

  return results;
}

async function getReserveData(assetSymbol) {
  const pool = getPoolContract();
  const assetAddr = contracts.addresses.assets[assetSymbol];
  if (!pool || !assetAddr) return null;

  try {
    const data = await pool.getReserveData(assetAddr);
    return {
      liquidityIndex: data.liquidityIndex.toString(),
      variableBorrowIndex: data.variableBorrowIndex.toString(),
      currentLiquidityRate: rayToPercent(data.currentLiquidityRate),
      currentVariableBorrowRate: rayToPercent(data.currentVariableBorrowRate),
      lastUpdateTimestamp: Number(data.lastUpdateTimestamp),
    };
  } catch (err) {
    console.error(`[ContractService] Failed to read reserve data for ${assetSymbol}:`, err.message);
    return null;
  }
}

module.exports = {
  isConnected: () => contracts.isConfigured(),
  getProvider,
  getPoolContract,
  getAssetConfigContract,
  getOracleContract,
  getAssetMarketData,
  getAllMarketData,
  getReserveData,
  rayToPercent,
  wadToNumber,
};
