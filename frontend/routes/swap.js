const express = require('express');
const router = express.Router();
const ASSET_META = require('../data/assets');
const contracts = require('../config/contracts');

function getSwapAssets() {
  return Object.values(ASSET_META).map(a => ({
    ...a,
    shieldedBalance: null,
    publicBalance: null,
    contractAddress: contracts.addresses.assets[a.name] || null,
    wrapperAddress: contracts.addresses.wrappers[a.name] || null,
  }));
}

router.get('/', (_req, res) => {
  res.render('pages/swap', {
    activePage: 'swap',
    pageTitle: 'Shield & Unshield',
    useSidebar: false,
  });
});

router.get('/api/assets', (_req, res) => {
  res.json(getSwapAssets());
});

module.exports = router;
