const express = require('express');
const router = express.Router();
const { fetchMarketDataFromChain, getMarkets } = require('../data/markets');

router.get('/', async (req, res, next) => {
  try {
    await fetchMarketDataFromChain();
    const asset = req.query.asset || 'USDC';
    const markets = getMarkets();
    const selected = markets.find(m => m.name === asset) || markets[0];

    res.render('pages/deposit', {
      activePage: 'deposit',
      pageTitle: 'Deposit Assets',
      useSidebar: false,
      selected,
      markets,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
