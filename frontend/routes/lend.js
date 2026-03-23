const express = require('express');
const router = express.Router();
const { getMarketsAsync, fetchMarketDataFromChain, getMarkets } = require('../data/markets');

router.get('/', async (req, res, next) => {
  try {
    await fetchMarketDataFromChain();
    const markets = getMarkets();

    res.render('pages/lend', {
      activePage: 'lend',
      pageTitle: 'Lend Assets',
      useSidebar: false,
      markets,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
