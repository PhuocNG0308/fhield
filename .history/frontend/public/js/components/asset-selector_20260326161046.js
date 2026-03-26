export class AssetSelector {
  static initAll() {
    document.querySelectorAll('[data-asset-selector]').forEach(el => {
      new AssetSelector(el);
    });
  }

  constructor(container) {
    this.container = container;
    this.cards = container.querySelectorAll('[data-asset]');
    this.hiddenInput = container.querySelector('input[type="hidden"]');

    this.cards.forEach(card => {
      card.addEventListener('click', () => this.select(card));
    });
  }

  select(card) {
    this.cards.forEach(c => c.classList.remove('active', 'border-primary', 'bg-surface-container-high'));
    this.cards.forEach(c => {
      c.classList.add('border-transparent', 'bg-surface-container-lowest');
    });
    card.classList.remove('border-transparent', 'bg-surface-container-lowest');
    card.classList.add('active', 'border-primary', 'bg-surface-container-high');

    const asset = card.dataset.asset;
    if (this.hiddenInput) this.hiddenInput.value = asset;

    const section = this.container.closest('section') || this.container.closest('form');
    if (section) {
      section.querySelectorAll('[data-action-asset]').forEach(btn => {
        btn.dataset.actionAsset = asset;
      });
    }

    this.container.dispatchEvent(new CustomEvent('asset-change', {
      detail: { asset },
      bubbles: true,
    }));
  }
}
