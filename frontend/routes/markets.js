const express = require('express');
const router = express.Router();
const { fetchMarketDataFromChain, getMarketByAsset } = require('../data/markets');

router.get('/', async (req, res, next) => {
  try {
    await fetchMarketDataFromChain();
    const asset = req.query.asset || 'USDC';
    const market = getMarketByAsset(asset);

    res.render('pages/markets', {
      activePage: 'markets',
      pageTitle: `${asset} Market Detail`,
      useSidebar: true,
      market,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
