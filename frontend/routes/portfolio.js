const express = require('express');
const router = express.Router();
const { getUserPortfolio } = require('../data/portfolio');
const ASSET_META = require('../data/assets');
const contracts = require('../config/contracts');

router.get('/', (_req, res) => {
  res.render('pages/portfolio', {
    activePage: 'portfolio',
    pageTitle: 'Your Portfolio',
    useSidebar: false,
  });
});

router.get('/api', (_req, res) => {
  const portfolio = getUserPortfolio();
  portfolio.contractAddresses = contracts.addresses;
  portfolio.assets = ASSET_META;
  res.json(portfolio);
});

module.exports = router;
