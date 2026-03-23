const contractService = require('../services/contract');
const ASSET_META = require('./assets');

function getUserPortfolio() {
  return {
    netWorth: 0,
    netWorthChange: 0,
    healthFactor: 0,
    liquidationThreshold: 1.10,
    borrowingPowerUsed: 0,
    borrowingUsed: 0,
    borrowingTotal: 0,
    supplies: [],
    borrows: [],
    pendingWithdrawals: [],
    recentActivity: [],
    isLive: contractService.isConnected(),
    requiresWallet: true,
  };
}

function getBorrowPosition() {
  return {
    healthFactor: 0,
    borrowAPY: 0,
    availableLiquidity: 0,
    collateral: [],
    borrows: [],
    borrowingPowerUsed: 0,
    borrowingUsed: 0,
    borrowingAvailable: 0,
    isLive: contractService.isConnected(),
    requiresWallet: true,
  };
}

function getRepayPosition() {
  const supportedAssets = Object.entries(ASSET_META).map(([key, meta], i) => ({
    asset: key,
    fullName: meta.fullName,
    icon: meta.icon,
    selected: i === 0,
  }));

  return {
    currentAPY: 0,
    healthBefore: 0,
    healthAfter: 0,
    walletBalance: '0.00',
    repayAssets: supportedAssets,
    isLive: contractService.isConnected(),
    requiresWallet: true,
  };
}

module.exports = { getUserPortfolio, getBorrowPosition, getRepayPosition };
