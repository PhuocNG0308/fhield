export class HealthGauge {
  static initAll() {
    document.querySelectorAll('[data-health-gauge]').forEach(el => {
      const value = parseFloat(el.dataset.healthGauge) || 0;
      const max = parseFloat(el.dataset.healthMax) || 3;
      new HealthGauge(el, value, max);
    });
  }

  constructor(container, value, max) {
    this.container = container;
    this.value = value;
    this.max = max;
    this.render();
  }

  render() {
    const ratio = Math.min(this.value / this.max, 1);
    const arc = this.container.querySelector('[data-health-arc]');
    if (arc) {
      const totalLength = 126;
      const offset = totalLength * (1 - ratio);
      arc.style.transition = 'stroke-dashoffset 1s ease';
      arc.setAttribute('stroke-dasharray', totalLength);
      arc.setAttribute('stroke-dashoffset', offset);
    }

    const display = this.container.querySelector('[data-health-value]');
    if (display) {
      this.animateNumber(display, 0, this.value, 1000);
    }
  }

  animateNumber(el, from, to, duration) {
    const start = performance.now();
    const step = (ts) => {
      const progress = Math.min((ts - start) / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      el.textContent = (from + (to - from) * eased).toFixed(2);
      if (progress < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  }
}
