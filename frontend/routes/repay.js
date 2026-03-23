const express = require('express');
const router = express.Router();
const { getRepayPosition } = require('../data/portfolio');

router.get('/', (_req, res) => {
  res.render('pages/repay', {
    activePage: 'borrow',
    pageTitle: 'Repay Debt',
    useSidebar: false,
    position: getRepayPosition(),
  });
});

module.exports = router;
