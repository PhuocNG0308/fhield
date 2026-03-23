const express = require('express');
const router = express.Router();
const { getMarketsAsync, getProtocolStats, fetchMarketDataFromChain } = require('../data/markets');

router.get('/', async (_req, res, next) => {
  try {
    await fetchMarketDataFromChain();
    const markets = getProtocolStats().isLive
      ? (await getMarketsAsync())
      : require('../data/markets').getMarkets();

    res.render('pages/dashboard', {
      activePage: 'dashboard',
      pageTitle: 'Private DeFi Lending',
      useSidebar: false,
      stats: getProtocolStats(),
      markets,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
