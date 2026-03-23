import { WalletManager } from './wallet.js';
import { FHEReveal } from './fhe.js';
import { FormHandler } from './forms.js';
import { ContractInteraction } from './contracts.js';
import { ToastManager } from './components/toast.js';
import { HealthGauge } from './components/health-gauge.js';
import { AssetSelector } from './components/asset-selector.js';

const app = {
  wallet: null,
  toast: null,
  contracts: ContractInteraction,

  init() {
    this.toast = new ToastManager();
    this.wallet = new WalletManager(this.toast);
    FHEReveal.init();
    FormHandler.init(this.toast);
    HealthGauge.initAll();
    AssetSelector.initAll();

    document.querySelectorAll('[data-width]').forEach(el => {
      el.style.width = el.dataset.width + '%';
    });

    document.querySelectorAll('[data-connect-wallet]').forEach(btn => {
      btn.addEventListener('click', () => this.wallet.openConnectModal());
    });

    document.querySelectorAll('[data-disconnect-wallet]').forEach(btn => {
      btn.addEventListener('click', () => this.wallet.disconnect());
    });

    const walletModal = document.getElementById('wallet-connect-modal');
    if (walletModal) {
      walletModal.querySelector('[data-wallet-modal-backdrop]')?.addEventListener('click', () => this.wallet._closeConnectModal());
      walletModal.querySelector('[data-wallet-modal-close]')?.addEventListener('click', () => this.wallet._closeConnectModal());
      document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !walletModal.classList.contains('hidden')) this.wallet._closeConnectModal();
      });
    }

    document.addEventListener('click', (e) => {
      const container = document.getElementById('wallet-container');
      const dropdown = document.getElementById('wallet-dropdown');
      if (dropdown && container && !container.contains(e.target)) {
        dropdown.classList.add('hidden');
      }
    });

    window.fhield = this;
  },
};

document.addEventListener('DOMContentLoaded', () => app.init());

export default app;
