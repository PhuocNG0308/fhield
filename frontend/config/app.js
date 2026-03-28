require('dotenv').config();

module.exports = {
  port: process.env.PORT || 3000,
  appName: 'Fhield',
  appTagline: 'Privacy-First FHE DeFi Lending',
  navItems: [
    { key: 'dashboard', label: 'Dashboard', href: '/dashboard', icon: 'grid_view' },
    { key: 'lend', label: 'Lend', href: '/lend', icon: 'south_west' },
    { key: 'borrow', label: 'Borrow', href: '/borrow', icon: 'north_east' },
    { key: 'portfolio', label: 'Portfolio', href: '/portfolio', icon: 'account_balance_wallet' },
    { key: 'swap', label: 'Privacy', href: '/swap', icon: 'enhanced_encryption' },
    { key: 'docs', label: 'Docs', href: 'https://phuocng0308.github.io/fhield/', icon: 'menu_book', external: true },
  ],
};
