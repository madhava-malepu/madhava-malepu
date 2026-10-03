/* Progressive enhancement: navigation and copy work without animation libraries. */
(() => {
  'use strict';
  const $ = s => document.querySelector(s);
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const nav = $('.nav'), menu = $('#mobileMenu'), burger = $('#navBurger'), overlay = $('#mobileMenuOverlay');
  function closeMenu(restore = false) {
    burger.classList.remove('is-open'); menu.classList.remove('is-open'); overlay.classList.remove('is-open');
    burger.setAttribute('aria-expanded', 'false'); burger.setAttribute('aria-label', 'Open menu'); menu.inert = true;
    if (restore) burger.focus();
  }
  burger.addEventListener('click', () => {
    if (burger.getAttribute('aria-expanded') === 'true') return closeMenu();
    menu.inert = false; burger.classList.add('is-open'); menu.classList.add('is-open'); overlay.classList.add('is-open');
    burger.setAttribute('aria-expanded', 'true'); burger.setAttribute('aria-label', 'Close menu');
  });
  overlay.addEventListener('click', () => closeMenu(true));
  menu.querySelectorAll('a').forEach(a => a.addEventListener('click', () => closeMenu()));
  document.addEventListener('keydown', e => { if (e.key === 'Escape' && burger.getAttribute('aria-expanded') === 'true') closeMenu(true); });
  matchMedia('(min-width: 901px)').addEventListener('change', e => { if (e.matches) closeMenu(); });
  function onScroll() {
    nav.classList.toggle('is-scrolled', scrollY > 32);
    const height = document.documentElement.scrollHeight - innerHeight;
    $('.progress__bar').style.transform = `scaleX(${height > 0 ? scrollY / height : 0})`;
  }
  addEventListener('scroll', onScroll, {passive:true}); onScroll();
  document.querySelectorAll('a[href^="#"]').forEach(a => a.addEventListener('click', e => {
    const target = document.getElementById(a.hash.slice(1));
    if (!target) return;
    e.preventDefault();
    target.scrollIntoView({behavior:reduceMotion.matches ? 'instant' : 'smooth', block:'start'});
    history.replaceState(null, '', a.hash);
    if (a.classList.contains('skip-link')) target.focus({preventScroll:true});
  }));
  document.querySelectorAll('[data-year]').forEach(el => {el.textContent = new Date().getFullYear();});
  const slider = $('#calcSlider');
  function updateSavings() {
    const bags = Number(slider.value), yearly = bags * 115 * 52;
    $('#calcBags').textContent = bags;
    $('#calcMonthly').textContent = Math.round(yearly / 12).toLocaleString('en-IN');
    $('#calcYearly').textContent = yearly.toLocaleString('en-IN');
    slider.setAttribute('aria-valuetext', `${bags} bags per week`);
  }
  slider.addEventListener('input', updateSavings); updateSavings();

  // Real scroll-reveal: elements fade/slide in as they enter view,
  // rather than the previous state where a CSS override made every
  // [data-reveal] element just statically visible with no animation
  // at all. Runs before the WebGL-related early return below, so this
  // applies for every visitor, not only those who get the 3D scene.
  const revealTargets = document.querySelectorAll('[data-reveal]');
  if (reduceMotion.matches) {
    // Respecting the same preference already honored elsewhere in this
    // file - reduced-motion users see content immediately, no animation.
    revealTargets.forEach(el => el.classList.add('is-revealed'));
  } else if ('IntersectionObserver' in window) {
    const revealObserver = new IntersectionObserver((entries, obs) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-revealed');
          obs.unobserve(entry.target);
        }
      });
    }, {threshold: 0.15, rootMargin: '0px 0px -40px 0px'});
    revealTargets.forEach(el => revealObserver.observe(el));
  } else {
    // No IntersectionObserver support - reveal everything rather than
    // leave content permanently invisible.
    revealTargets.forEach(el => el.classList.add('is-revealed'));
  }

  // "See the App" carousel: the track itself already works with zero
  // JS at all, via native CSS scroll-snap - swipeable on touch, drag or
  // wheel-scroll on desktop. This is pure progressive enhancement:
  // clicking a dot jumps to that slide, and the active dot highlights
  // itself as the matching slide scrolls into view.
  const appTrack = $('#appCarouselTrack');
  if (appTrack) {
    const dots = Array.from(document.querySelectorAll('.app-carousel__dots .dot'));
    const slides = Array.from(appTrack.querySelectorAll('.app-slide'));
    dots.forEach((dot, i) => dot.addEventListener('click', () => {
      slides[i]?.scrollIntoView({behavior: reduceMotion.matches ? 'auto' : 'smooth', inline: 'center', block: 'nearest'});
    }));
    if ('IntersectionObserver' in window && slides.length) {
      const io = new IntersectionObserver(entries => {
        entries.forEach(entry => {
          if (!entry.isIntersecting) return;
          const idx = slides.indexOf(entry.target);
          dots.forEach((d, i) => {
            d.classList.toggle('is-active', i === idx);
            d.setAttribute('aria-selected', i === idx ? 'true' : 'false');
          });
        });
      }, {root: appTrack, threshold: 0.6});
      slides.forEach(s => io.observe(s));
    }
  }

  // Rendering is optional. The preloaded SVG remains visible if WebGL is unavailable.
  // Reduced motion/data-saving users receive the illustration without downloading Three.js.
  if (reduceMotion.matches || navigator.connection?.saveData) return;
  const loadScene = () => {
    const library = document.createElement('script');
    library.src = 'assets/vendor/three.min.js';
    library.onload = () => {
      const scene = document.createElement('script'); scene.src = 'surpl-scene.js'; document.head.append(scene);
    };
    document.head.append(library);
  };
  if ('requestIdleCallback' in window) requestIdleCallback(loadScene, {timeout:1200});
  else setTimeout(loadScene, 250);
  // The launch-month 0% commission offer ends 30 Sept 2026 (IST). From 1 Oct
  // the page switches by itself to the standing terms, so it never advertises
  // an offer that has ended.
  if (Date.now() >= Date.UTC(2026, 8, 30, 18, 30, 0)) {
    document.querySelectorAll('[data-trial-stat]').forEach(el => {
      el.innerHTML = '<b>10%</b><span>Flat commission · completed orders only</span>';
    });
  }
})();
