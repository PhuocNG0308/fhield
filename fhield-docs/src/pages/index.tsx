import React from 'react';
import clsx from 'clsx';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import HomepageFeatures from '@site/src/components/HomepageFeatures';
import Link from '@docusaurus/Link';
import styles from './index.module.css';

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('hero', styles.heroBanner)}>
      <div className="container">
        <h1 className="hero__title">{siteConfig.title}</h1>
        <p className="hero__subtitle">
          Privacy-first lending protocol powered by Fully Homomorphic Encryption.
          Deposit, borrow, and manage assets — all encrypted on-chain.
        </p>
        <div className={styles.buttons}>
          <Link className="hero-button--primary" to="/docs/devdocs/intro">
            Get Started
          </Link>
          <Link
            className="hero-button--secondary"
            to="/docs/devdocs/Architecture/Protocol-Overview"
          >
            Architecture
          </Link>
        </div>
      </div>
    </header>
  );
}

export default function Home(): JSX.Element {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={siteConfig.title}
      description="Privacy-First FHE DeFi Lending Protocol"
    >
      <HomepageHeader />
      <main>
        <HomepageFeatures />
      </main>
    </Layout>
  );
}
