const dashboardRouter = require('./dashboard');
const swapRouter = require('./swap');
const lendRouter = require('./lend');
const borrowRouter = require('./borrow');
const depositRouter = require('./deposit');
const marketsRouter = require('./markets');
const portfolioRouter = require('./portfolio');
const repayRouter = require('./repay');
const apiRouter = require('./api');

function registerRoutes(app) {
  app.get('/', (_req, res) => res.redirect('/dashboard'));
  app.use('/dashboard', dashboardRouter);
  app.use('/swap', swapRouter);
  app.use('/lend', lendRouter);
  app.use('/deposit', depositRouter);
  app.use('/borrow', borrowRouter);
  app.use('/markets', marketsRouter);
  app.use('/portfolio', portfolioRouter);
  app.use('/repay', repayRouter);
  app.use('/api', apiRouter);
}

module.exports = registerRoutes;
