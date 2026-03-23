import React from 'react';
import Link from '@docusaurus/Link';
import styles from './styles.module.css';

type FeatureItem = {
  title: string;
  description: string;
  linkTo: string;
  linkLabel: string;
};

const FeatureList: FeatureItem[] = [
  {
    title: 'Protocol Architecture',
    description: 'How encrypted lending works end-to-end with FHE',
    linkTo: '/docs/devdocs/Architecture/Protocol-Overview',
    linkLabel: 'Explore →',
  },
  {
    title: 'Smart Contracts',
    description: 'TrustLendPool, AssetConfig, FHERC20Wrapper and more',
    linkTo: '/docs/devdocs/Smart%20Contracts/TrustLendPool',
    linkLabel: 'Read →',
  },
  {
    title: 'User Flows',
    description: 'Step-by-step guides for deposit, borrow, repay, withdraw, liquidation',
    linkTo: '/docs/devdocs/User%20Flows/Deposit',
    linkLabel: 'Learn →',
  },
  {
    title: 'Getting Started',
    description: 'Setup, installation, deployment, and testing',
    linkTo: '/docs/devdocs/Getting%20Started/Prerequisites',
    linkLabel: 'Start →',
  },
];

const BuiltWithList = [
  {
    name: 'Fhenix CoFHE',
    description: 'Fully Homomorphic Encryption for confidential smart contracts on Ethereum',
    linkTo: 'https://docs.fhenix.zone',
    linkLabel: 'Learn More →',
  },
  {
    name: 'AAVE V3 Architecture',
    description: 'Battle-tested lending protocol design — interest rate curves, reserve indices, and liquidation mechanics',
    linkTo: '/docs/devdocs/Architecture/Protocol-Overview',
    linkLabel: 'Architecture →',
  },
];

function Feature({title, description, linkTo, linkLabel}: FeatureItem) {
  return (
    <div className={styles.featureCol}>
      <div className="feature-card">
        <div className="feature-card__title">{title}</div>
        <div className="feature-card__description">{description}</div>
        <Link className="feature-card__link" to={linkTo}>
          {linkLabel}
        </Link>
      </div>
    </div>
  );
}

export default function HomepageFeatures(): JSX.Element {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="section-label">Documentation</div>
        <div className="section-heading">Explore the Protocol</div>
        <div className={styles.featureGrid}>
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>

        <div className={styles.builtWithSection}>
          <div className="section-label">Built With</div>
          <div className="section-heading">Foundation</div>
          <div className={styles.builtWithGrid}>
            {BuiltWithList.map((item, idx) => (
              <div key={idx} className="built-with-card">
                <div className="built-with-card__name">{item.name}</div>
                <div className="built-with-card__desc">{item.description}</div>
                <Link className="feature-card__link" to={item.linkTo}>
                  {item.linkLabel}
                </Link>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
