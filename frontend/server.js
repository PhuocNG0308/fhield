const express = require('express');
const expressLayouts = require('express-ejs-layouts');
const path = require('path');
const config = require('./config/app');
const registerRoutes = require('./routes');

const app = express();

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(expressLayouts);
app.set('layout', 'layouts/main');

app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

app.use((_req, res, next) => {
  res.locals.appName = config.appName;
  res.locals.navItems = config.navItems;
  next();
});

registerRoutes(app);

app.use((err, _req, res, _next) => {
  console.error(err.stack);
  res.status(500).send('Internal Server Error');
});

app.listen(config.port, () => {
  console.log(`${config.appName} frontend running at http://localhost:${config.port}`);
});
