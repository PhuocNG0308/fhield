const express = require('express');
const router = express.Router();
const { fetchMarketDataFromChain, getMarkets, getProtocolStats } = require('../data/markets');
const contracts = require('../config/contracts');

router.get('/config', (_req, res) => {
  res.json({
    chainId: contracts.chainId,
    rpcUrl: contracts.rpcUrl,
    addresses: contracts.addresses,
    isConfigured: contracts.isConfigured(),
    abis: {
      pool: contracts.POOL_ABI,
      assetConfig: contracts.ASSET_CONFIG_ABI,
      oracle: contracts.ORACLE_ABI,
      erc20: contracts.ERC20_ABI,
      fherc20: contracts.FHERC20_ABI,
    },
  });
});

router.get('/markets', async (_req, res) => {
  try {
    await fetchMarketDataFromChain();
    res.json({
      markets: getMarkets(),
      stats: getProtocolStats(),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
