export class FHEReveal {
  static hidden = false;

  static init() {
    document.querySelectorAll('[data-fhe-reveal]').forEach(btn => {
      btn.addEventListener('click', () => FHEReveal.handleReveal(btn));
    });

    document.querySelectorAll('.fhe-blur').forEach(el => {
      el.addEventListener('click', () => {
        el.classList.toggle('revealed');
      });
    });

    document.querySelectorAll('[data-fhe-toggle]').forEach(btn => {
      btn.addEventListener('click', () => FHEReveal.toggleGlobalVisibility(btn));
    });
  }

  static toggleGlobalVisibility(btn) {
    FHEReveal.hidden = !FHEReveal.hidden;
    const icon = btn.querySelector('.material-symbols-outlined');

    document.querySelectorAll('[data-fhe-value]').forEach(el => {
      if (FHEReveal.hidden) {
        if (!el.dataset.originalText) el.dataset.originalText = el.textContent;
        el.textContent = '••••••';
        el.classList.add('fhe-blur');
      } else {
        if (el.dataset.originalText) el.textContent = el.dataset.originalText;
        el.classList.remove('fhe-blur');
      }
    });

    if (icon) {
      icon.textContent = FHEReveal.hidden ? 'visibility_off' : 'visibility';
    }
  }

  static async handleReveal(trigger) {
    const targetSelector = trigger.dataset.fheReveal;
    const targets = targetSelector
      ? document.querySelectorAll(targetSelector)
      : [trigger.closest('[data-fhe-container]')?.querySelector('.encrypted-blur')];

    trigger.disabled = true;
    trigger.innerHTML = `
      <span class="material-symbols-outlined text-sm animate-spin">progress_activity</span>
      Decrypting via CoFHE...
    `;

    const hasWallet = typeof window.ethereum !== 'undefined';
    if (hasWallet) {
      trigger.innerHTML = `
        <span class="material-symbols-outlined text-sm animate-spin">progress_activity</span>
        Requesting permit...
      `;
      await new Promise(resolve => setTimeout(resolve, 600));
      trigger.innerHTML = `
        <span class="material-symbols-outlined text-sm animate-spin">progress_activity</span>
        Threshold decryption...
      `;
      await new Promise(resolve => setTimeout(resolve, 800));
    } else {
      await new Promise(resolve => setTimeout(resolve, 1200));
    }

    targets.forEach(el => {
      if (el) el.classList.add('revealed');
    });

    trigger.innerHTML = `
      <span class="material-symbols-outlined text-sm" style="font-variation-settings: 'FILL' 1;">visibility</span>
      Revealed
    `;
    trigger.classList.add('opacity-50');
  }
}
