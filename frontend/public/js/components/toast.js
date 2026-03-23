export class ToastManager {
  constructor() {
    this.container = document.createElement('div');
    this.container.className = 'fixed top-20 right-4 z-[100] flex flex-col gap-2 pointer-events-none';
    document.body.appendChild(this.container);
  }

  show(message, type = 'info', duration = 4000) {
    const icons = { success: 'check_circle', error: 'error', info: 'info' };
    const colors = {
      success: 'bg-green-500/10 border-green-500/30 text-green-400',
      error: 'bg-red-500/10 border-red-500/30 text-red-400',
      info: 'bg-primary/10 border-primary/30 text-primary',
    };

    const toast = document.createElement('div');
    toast.className = `pointer-events-auto flex items-center gap-3 px-5 py-3 rounded-xl border backdrop-blur-xl shadow-2xl animate-fade-in-up ${colors[type] || colors.info}`;
    toast.innerHTML = `
      <span class="material-symbols-outlined text-lg" style="font-variation-settings: 'FILL' 1;">${icons[type] || icons.info}</span>
      <span class="text-sm font-medium">${this.escapeHtml(message)}</span>
    `;
    this.container.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateY(-8px)';
      toast.style.transition = 'all 0.3s ease';
      setTimeout(() => toast.remove(), 300);
    }, duration);
  }

  escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }
}
