import { ContractInteraction } from './contracts.js';

const ARB_SEPOLIA = {
  chainId: '0x66eee',
  chainName: 'Arbitrum Sepolia',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: ['https://sepolia-rollup.arbitrum.io/rpc'],
  blockExplorerUrls: ['https://sepolia.arbiscan.io'],
};

export class WalletManager {
  constructor(toast) {
    this.toast = toast;
    this.account = null;
    this.provider = null;
    this.balances = {};
    this.discoveredWallets = [];
    this._discoverWallets();
  }

  _discoverWallets() {
    window.addEventListener('eip6963:announceProvider', (event) => {
      const { info, provider } = event.detail;
      if (!this.discoveredWallets.find(w => w.info.uuid === info.uuid)) {
        this.discoveredWallets.push({ info, provider });
        this._renderWalletList();
      }
    });
    window.dispatchEvent(new Event('eip6963:requestProvider'));

    setTimeout(() => {
      if (this.discoveredWallets.length === 0 && window.ethereum) {
        this.discoveredWallets.push({
          info: {
            uuid: 'injected',
            name: window.ethereum.isMetaMask ? 'MetaMask' : 'Browser Wallet',
            icon: '',
            rdns: 'injected',
          },
          provider: window.ethereum,
        });
        this._renderWalletList();
      }
    }, 500);
  }

  openConnectModal() {
    if (this.account) {
      this._toggleDropdown();
      return;
    }
    const modal = document.getElementById('wallet-connect-modal');
    if (modal) {
      this._renderWalletList();
      modal.classList.remove('hidden');
      document.body.style.overflow = 'hidden';
    }
  }

  _closeConnectModal() {
    const modal = document.getElementById('wallet-connect-modal');
    if (modal) {
      modal.classList.add('hidden');
      document.body.style.overflow = '';
    }
  }

  _renderWalletList() {
    const list = document.getElementById('wallet-list');
    if (!list) return;

    if (this.discoveredWallets.length === 0) {
      list.innerHTML = `<div class="text-center py-8">
        <span class="material-symbols-outlined text-4xl text-on-surface-variant/30 mb-3 block">search_off</span>
        <p class="text-sm font-bold text-on-surface-variant">No Web3 wallets detected</p>
        <p class="text-xs text-on-surface-variant/50 mt-1">Install MetaMask or another browser wallet extension</p>
      </div>`;
      return;
    }

    list.innerHTML = this.discoveredWallets.map((w, i) => {
      const icon = w.info.icon && (w.info.icon.startsWith('data:image/') || w.info.icon.startsWith('https://'))
        ? `<img src="${w.info.icon}" class="w-10 h-10 rounded-xl" alt="" />`
        : `<div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center"><span class="material-symbols-outlined text-primary">account_balance_wallet</span></div>`;
      const name = document.createElement('span');
      name.textContent = w.info.name;
      return `<button class="wallet-option w-full flex items-center gap-4 p-4 rounded-xl hover:bg-surface-container-highest transition-all text-left border border-outline-variant/10 hover:border-primary/30" data-wallet-idx="${i}">
        ${icon}
        <div class="flex-1 min-w-0">
          <p class="text-sm font-bold text-on-surface">${name.textContent}</p>
          <p class="text-[10px] text-on-surface-variant">Click to connect</p>
        </div>
        <span class="material-symbols-outlined text-on-surface-variant/50 text-sm">chevron_right</span>
      </button>`;
    }).join('');

    list.querySelectorAll('.wallet-option').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = parseInt(btn.dataset.walletIdx);
        this._connectWithProvider(this.discoveredWallets[idx]);
      });
    });
  }

  async _connectWithProvider(wallet) {
    const list = document.getElementById('wallet-list');
    try {
      this.provider = wallet.provider;

      if (list) {
        const safeName = document.createElement('span');
        safeName.textContent = wallet.info.name;
        list.innerHTML = `<div class="text-center py-8">
          <span class="material-symbols-outlined text-4xl text-primary mb-3 block animate-spin">progress_activity</span>
          <p class="text-sm text-on-surface">Connecting to ${safeName.textContent}...</p>
        </div>`;
      }

      const accounts = await this.provider.request({ method: 'eth_requestAccounts' });
      this.account = accounts[0];
      ContractInteraction.setProvider(this.provider);

      this._closeConnectModal();

      const switched = await this._ensureCorrectNetwork();
      if (!switched) {
        this.account = null;
        this.provider = null;
        ContractInteraction.setProvider(null);
        this.updateUI();
        return;
      }

      this.updateUI();
      this.toast.show(`Connected: ${this.shortAddress()}`, 'success');
      await this.loadBalances();

      this.provider.on?.('accountsChanged', (accs) => {
        this.account = accs[0] || null;
        ContractInteraction.resetSigner();
        this.updateUI();
        if (this.account) this.loadBalances();
        else this.disconnect();
      });

      this.provider.on?.('chainChanged', async () => {
        ContractInteraction.resetSigner();
        const ok = await this._ensureCorrectNetwork();
        if (ok) {
          ContractInteraction.setProvider(this.provider);
          this.loadBalances();
        }
      });

    } catch (err) {
      this._closeConnectModal();
      if (err.code === 4001) {
        this.toast.show('Connection rejected by user', 'error');
      } else {
        this.toast.show('Failed to connect wallet', 'error');
      }
    }
  }

  async _ensureCorrectNetwork() {
    if (!this.provider) return false;
    try {
      const chainId = await this.provider.request({ method: 'eth_chainId' });
      if (chainId.toLowerCase() === ARB_SEPOLIA.chainId.toLowerCase()) return true;

      this.toast.show('Wrong network — switching to Arbitrum Sepolia...', 'info');

      try {
        await this.provider.request({
          method: 'wallet_switchEthereumChain',
          params: [{ chainId: ARB_SEPOLIA.chainId }],
        });
        return true;
      } catch (switchErr) {
        if (switchErr.code === 4902) {
          await this.provider.request({
            method: 'wallet_addEthereumChain',
            params: [ARB_SEPOLIA],
          });
          return true;
        }
        this.toast.show('Please switch to Arbitrum Sepolia to use FHIELD', 'error');
        return false;
      }
    } catch {
      this.toast.show('Could not verify network — please check your wallet', 'error');
      return false;
    }
  }

  _toggleDropdown() {
    const dropdown = document.getElementById('wallet-dropdown');
    if (dropdown) dropdown.classList.toggle('hidden');
  }

  disconnect() {
    this.account = null;
    this.provider = null;
    this.balances = {};
    ContractInteraction.setProvider(null);
    this.updateUI();
    this.toast.show('Wallet disconnected', 'info');
    const dropdown = document.getElementById('wallet-dropdown');
    if (dropdown) dropdown.classList.add('hidden');
  }

  async loadBalances() {
    if (!this.account) return;
    try {
      this.balances = await ContractInteraction.getWalletBalances(this.account);
      this.updateBalanceUI();
      document.dispatchEvent(new CustomEvent('wallet:balances', { detail: this.balances }));
    } catch { /* Contract not configured */ }
  }

  updateBalanceUI() {
    document.querySelectorAll('[data-wallet-balance]').forEach(el => {
      const asset = el.dataset.walletBalance;
      const bal = this.balances[asset];
      if (bal) {
        el.textContent = parseFloat(bal.formatted).toLocaleString('en-US', {
          maximumFractionDigits: bal.decimals > 8 ? 4 : 2,
        });
      }
    });

    document.querySelectorAll('[data-max-btn]').forEach(btn => {
      const asset = btn.dataset.maxAsset;
      if (asset && this.balances[asset]) {
        btn.dataset.maxValue = this.balances[asset].formatted;
      }
    });
  }

  shortAddress() {
    if (!this.account) return '';
    return `${this.account.slice(0, 6)}...${this.account.slice(-4)}`;
  }

  updateUI() {
    const btns = document.querySelectorAll('[data-connect-wallet]');
    btns.forEach(btn => {
      const label = btn.querySelector('[data-wallet-label]');
      if (this.account) {
        if (label) label.textContent = this.shortAddress();
        btn.classList.add('connected');
      } else {
        if (label) label.textContent = 'Connect Wallet';
        btn.classList.remove('connected');
      }
    });

    document.querySelectorAll('[data-wallet-address]').forEach(el => {
      el.textContent = this.account || '';
    });

    document.querySelectorAll('[data-requires-wallet]').forEach(el => {
      el.classList.toggle('opacity-50', !this.account);
      el.classList.toggle('pointer-events-none', !this.account);
    });
  }

  isConnected() {
    return !!this.account;
  }

  getBalance(asset) {
    return this.balances[asset]
      ? parseFloat(this.balances[asset].formatted)
      : 0;
  }
}
