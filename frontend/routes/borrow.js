const express = require('express');
const router = express.Router();
const { fetchMarketDataFromChain, getMarkets } = require('../data/markets');
const { getBorrowPosition } = require('../data/portfolio');

router.get('/', async (_req, res, next) => {
  try {
    await fetchMarketDataFromChain();
    res.render('pages/borrow', {
      activePage: 'borrow',
      pageTitle: 'Borrow Assets',
      useSidebar: false,
      markets: getMarkets(),
      position: getBorrowPosition(),
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
