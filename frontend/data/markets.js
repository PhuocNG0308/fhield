const ASSET_META = require('./assets');
const contractService = require('../services/contract');

const ASSET_SYMBOLS = ['USDC', 'ETH', 'USDT', 'WBTC'];

const ASSET_SYMBOL_MAP = { ETH: 'WETH', USDC: 'USDC', USDT: 'USDC', WBTC: 'WETH' };

const DEFAULT_MARKET_DATA = {
  USDC: { supplied: 0, borrowed: 0, supplyAPY: 0, borrowAPY: 0 },
  ETH:  { supplied: 0, borrowed: 0, supplyAPY: 0, borrowAPY: 0 },
  USDT: { supplied: 0, borrowed: 0, supplyAPY: 0, borrowAPY: 0 },
  WBTC: { supplied: 0, borrowed: 0, supplyAPY: 0, borrowAPY: 0 },
};

let _cachedMarketData = null;
let _cacheTimestamp = 0;
const CACHE_TTL = 15_000;

async function fetchMarketDataFromChain() {
  if (!contractService.isConnected()) return null;

  try {
    const onChain = await contractService.getAllMarketData();
    if (!onChain || Object.keys(onChain).length === 0) return null;

    const result = {};
    if (onChain.USDC) {
      result.USDC = onChain.USDC;
      result.USDT = { ...onChain.USDC };
    }
    if (onChain.WETH) {
      result.ETH = onChain.WETH;
      result.WBTC = { ...onChain.WETH };
    }
    return result;
  } catch {
    return null;
  }
}

async function getMarketsAsync() {
  const now = Date.now();
  if (_cachedMarketData && now - _cacheTimestamp < CACHE_TTL) {
    return buildMarkets(_cachedMarketData);
  }

  const chainData = await fetchMarketDataFromChain();
  if (chainData) {
    _cachedMarketData = chainData;
    _cacheTimestamp = now;
  }

  return buildMarkets(_cachedMarketData || DEFAULT_MARKET_DATA);
}

function buildMarkets(data) {
  return ASSET_SYMBOLS.map(symbol => {
    const meta = ASSET_META[symbol];
    const m = data[symbol] || DEFAULT_MARKET_DATA[symbol];
    const utilization = m.supplied > 0 ? Math.round((m.borrowed / m.supplied) * 100) : 0;
    return {
      ...meta,
      supplied: m.supplied,
      borrowed: m.borrowed,
      suppliedFmt: formatUSD(m.supplied),
      borrowedFmt: formatUSD(m.borrowed),
      utilization: m.utilization ?? utilization,
      supplyAPY: roundAPY(m.supplyAPY),
      borrowAPY: roundAPY(m.borrowAPY),
    };
  });
}

function getMarkets() {
  return buildMarkets(_cachedMarketData || DEFAULT_MARKET_DATA);
}

function getMarketByAsset(asset) {
  return getMarkets().find(m => m.name === asset) || null;
}

function getProtocolStats() {
  const all = getMarkets();
  const tvl = all.reduce((s, m) => s + m.supplied, 0);
  const totalBorrowed = all.reduce((s, m) => s + m.borrowed, 0);
  const avgSupplyAPY = all.length > 0 ? all.reduce((s, m) => s + m.supplyAPY, 0) / all.length : 0;
  return {
    tvl,
    tvlFmt: formatUSD(tvl),
    totalBorrowed,
    totalBorrowedFmt: formatUSD(totalBorrowed),
    utilization: tvl > 0 ? Math.round((totalBorrowed / tvl) * 100) : 0,
    activeMarkets: all.length,
    avgSupplyAPY: avgSupplyAPY.toFixed(1),
    isLive: contractService.isConnected(),
  };
}

function formatUSD(value) {
  if (value >= 1e9) return `$${(value / 1e9).toFixed(1)}B`;
  if (value >= 1e6) return `$${(value / 1e6).toFixed(1)}M`;
  if (value >= 1e3) return `$${(value / 1e3).toFixed(1)}K`;
  return `$${value.toFixed(2)}`;
}

function roundAPY(v) {
  return Math.round(v * 100) / 100;
}

module.exports = { getMarkets, getMarketsAsync, getMarketByAsset, getProtocolStats, fetchMarketDataFromChain };
