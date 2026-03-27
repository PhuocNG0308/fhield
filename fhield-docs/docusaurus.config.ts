import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';

const isDeployment = process.env.DEPLOYMENT === 'true';

const config: Config = {
  title: 'fhield',
  tagline: 'Privacy-First FHE DeFi Lending Protocol',
  favicon: 'img/fhield-icon.png',

  url: 'https://phuocng0308.github.io',
  baseUrl: isDeployment ? '/fhield/' : '/',

  organizationName: 'PhuocNG0308',
  projectName: 'fhield',

  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',

  markdown: {
    mermaid: true,
  },
  themes: ['@docusaurus/theme-mermaid'],
  trailingSlash: false,
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },
  clientModules: [
    require.resolve('katex/dist/katex.min.css'),
  ],

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          remarkPlugins: [remarkMath],
          rehypePlugins: [rehypeKatex],
        },
        theme: {
          customCss: './src/css/custom.css',
        },
        sitemap: {
          changefreq: 'weekly',
          priority: 0.5,
          ignorePatterns: ['/tags/**'],
          filename: 'sitemap.xml',
        },
      } satisfies Preset.Options,
    ],
  ],
  themeConfig: {
    metadata: [
      {name: 'description', content: 'Developer documentation for fhield — a privacy-first DeFi lending protocol powered by Fully Homomorphic Encryption (FHE) on Fhenix. Explore the TrustLend smart contract architecture, encrypted user flows, FHE privacy model, and integration guides.'},
      {name: 'keywords', content: 'fhield, TrustLend, DeFi, FHE, Fully Homomorphic Encryption, Lending, Privacy, Fhenix, Encrypted Lending, Confidential DeFi'},
      {name: 'twitter:card', content: 'summary_large_image'}
    ],
    image: 'img/Splash.webp',
    colorMode: {
      defaultMode: 'dark',
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'fhield',
      logo: {
        alt: 'fhield',
        src: 'img/fhield-icon.png',
        href: '/',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: 'Documentation',
        },
        {
          href: 'https://github.com/PhuocNG0308/fhield',
          className: 'header-github-link',
          position: 'right',
          'aria-label': 'GitHub',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [],
      copyright: `© ${new Date().getFullYear()} fhield`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['solidity'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
