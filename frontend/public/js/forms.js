import { ContractInteraction } from './contracts.js';

export class FormHandler {
  static init(toast) {
    this.toast = toast;

    document.querySelectorAll('[data-max-btn]').forEach(btn => {
      btn.addEventListener('click', () => {
        const input = btn.closest('.relative')?.querySelector('input')
          || document.querySelector(btn.dataset.maxBtn);
        const max = btn.dataset.maxValue || '0';
        if (input) {
          input.value = max;
          input.dispatchEvent(new Event('input', { bubbles: true }));
        }
      });
    });

    document.querySelectorAll('[data-usd-display]').forEach(input => {
      const displayEl = document.querySelector(input.dataset.usdDisplay);
      const price = parseFloat(input.dataset.usdPrice) || 1;
      if (!displayEl) return;

      input.addEventListener('input', () => {
        const val = parseFloat(input.value) || 0;
        const usd = (val * price).toLocaleString('en-US', {
          style: 'currency', currency: 'USD',
        });
        displayEl.textContent = `≈ ${usd}`;
      });
    });

    document.querySelectorAll('[data-action-btn]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        const action = btn.dataset.actionBtn;
        const asset = btn.dataset.actionAsset || btn.closest('[data-asset]')?.dataset.asset || form?.querySelector('input[name="asset"]')?.value || '';
        const form = btn.closest('form') || btn.closest('section');
        const input = form?.querySelector('input[type="text"], input[type="number"]');
        const amount = input?.value;

        if (!amount || parseFloat(amount) <= 0) {
          this.toast.show('Please enter a valid amount', 'error');
          return;
        }

        this.executeTransaction(btn, action, asset, amount);
      });
    });
  }

  static async executeTransaction(btn, action, asset, amount) {
    const originalText = btn.innerHTML;
    btn.disabled = true;

    try {
      btn.innerHTML = `
        <span class="material-symbols-outlined text-sm animate-spin">progress_activity</span>
        <span>Preparing...</span>
      `;

      const lowerAction = action.toLowerCase();

      if (lowerAction === 'deposit' || lowerAction === 'supply') {
        btn.innerHTML = `<span class="material-symbols-outlined text-sm animate-spin">progress_activity</span><span>Approving...</span>`;
        await ContractInteraction.deposit(asset, amount);
      } else if (lowerAction === 'repay') {
        btn.innerHTML = `<span class="material-symbols-outlined text-sm animate-spin">progress_activity</span><span>Approving...</span>`;
        await ContractInteraction.repay(asset, amount);
      } else if (lowerAction === 'shield' || lowerAction === 'wrap') {
        btn.innerHTML = `<span class="material-symbols-outlined text-sm animate-spin">progress_activity</span><span>Wrapping...</span>`;
        await ContractInteraction.wrap(asset, amount);
      } else if (lowerAction === 'unwrap' || lowerAction === 'unshield') {
        btn.innerHTML = `<span class="material-symbols-outlined text-sm animate-spin">progress_activity</span><span>Unwrapping...</span>`;
        await ContractInteraction.unwrap(asset, amount);
      } else {
        this.toast.show(`Action "${action}" requires wallet encryption (cofhejs)`, 'info');
        btn.disabled = false;
        btn.innerHTML = originalText;
        return;
      }

      btn.disabled = false;
      btn.innerHTML = originalText;
      this.toast.show(`${action} of ${amount} ${asset} confirmed!`, 'success');

    } catch (err) {
      btn.disabled = false;
      btn.innerHTML = originalText;
      const msg = err?.reason || err?.message || 'Transaction failed';
      this.toast.show(msg, 'error');
    }
  }
}
