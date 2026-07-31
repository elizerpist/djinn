import { initUniverse4 } from './universe4.js?rev=56';

const routes = {
  home: 'screens/home.html',
  djinn: 'screens/djinn.html',
  query: 'screens/query.html',
  'query-answer': 'screens/query-answer.html',
  'query-evidence': 'screens/query-evidence.html',
  'query-related': 'screens/query-related.html',
  'query-sources': 'screens/query-sources.html',
  'query-process': 'screens/query-process.html',
  'workspace-topics': 'screens/workspace-topics.html',
  'workspace-topic-overview': 'screens/workspace-topic-overview.html',
  'workspace-topic-notes': 'screens/workspace-topic-notes.html',
  'workspace-topic-files': 'screens/workspace-topic-files.html',
  'workspace-topic-activity': 'screens/workspace-topic-activity.html',
  'workspace-notes': 'screens/workspace-notes.html',
  'workspace-note-detail': 'screens/workspace-note-detail.html',
  'workspace-note-editor': 'screens/workspace-note-editor.html',
  'workspace-library': 'screens/workspace-library.html',
  'workspace-source-detail': 'screens/workspace-source-detail.html',
  universe: 'screens/universe.html',
  profile: 'screens/profile.html',
};

const root = document.querySelector('#screen-root');
const toast = document.querySelector('#toast');
const state = { route: 'home', question: '' };
let toastTimer;
let destroyScreen = () => {};
function activeNav(route) {
  return route.startsWith('workspace-') ? 'workspace' : route;
}

function showToast(message) {
  toast.textContent = message;
  toast.classList.add('is-visible');
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => toast.classList.remove('is-visible'), 2200);
}

function createFixedScreenLayout() {
  const screen = root.querySelector('.screen');
  const header = screen?.querySelector(':scope > .top-bar');
  if (!screen || !header) return;

  const chrome = document.createElement('div');
  chrome.className = 'screen-chrome';
  const content = document.createElement('div');
  content.className = 'screen-content';
  const subheaders = [...screen.querySelectorAll(':scope > [data-screen-subheader]')];

  screen.prepend(chrome);
  chrome.append(header, ...subheaders);
  [...screen.children].forEach((child) => {
    if (child !== chrome) content.append(child);
  });
  screen.append(content);
}

function isFullscreen() {
  return Boolean(document.fullscreenElement || document.webkitFullscreenElement);
}

function syncFullscreenControls() {
  const active = isFullscreen();
  document.body.classList.toggle('is-fullscreen', active);
  root.querySelectorAll('[data-action="toggle-fullscreen"]').forEach((button) => {
    button.setAttribute('aria-pressed', String(active));
    button.setAttribute('aria-label', active ? 'Kilépés a teljes képernyőből' : 'Teljes képernyő');
    button.setAttribute('title', active ? 'Kilépés a teljes képernyőből' : 'Teljes képernyő');
    button.textContent = active ? '⤡' : '⛶';
  });
}

function addFullscreenToggle() {
  const header = root.querySelector('.top-bar');
  if (!header || header.querySelector('[data-action="toggle-fullscreen"]')) return;

  const existingActions = header.querySelector(':scope > .top-bar-actions');
  if (existingActions) {
    const fullscreenButton = document.createElement('button');
    fullscreenButton.type = 'button';
    fullscreenButton.className = 'icon-button fullscreen-toggle';
    fullscreenButton.dataset.action = 'toggle-fullscreen';
    existingActions.append(fullscreenButton);
    syncFullscreenControls();
    return;
  }

  const trailingAction = header.querySelector(':scope > .icon-button');
  const actions = document.createElement('div');
  actions.className = 'top-bar-actions';
  if (trailingAction) actions.append(trailingAction);

  const fullscreenButton = document.createElement('button');
  fullscreenButton.type = 'button';
  fullscreenButton.className = 'icon-button fullscreen-toggle';
  fullscreenButton.dataset.action = 'toggle-fullscreen';
  actions.append(fullscreenButton);
  header.append(actions);
  syncFullscreenControls();
}

async function toggleFullscreen() {
  try {
    if (isFullscreen()) {
      if (document.exitFullscreen) await document.exitFullscreen();
      else if (document.webkitExitFullscreen) document.webkitExitFullscreen();
      return;
    }

    const target = document.documentElement;
    if (target.requestFullscreen) await target.requestFullscreen();
    else if (target.webkitRequestFullscreen) target.webkitRequestFullscreen();
    else showToast('A böngésző nem támogatja a teljes képernyőt.');
  } catch {
    showToast('A teljes képernyős nézet most nem érhető el.');
  }
}

async function render(route) {
  const normalized = routes[route] ? route : 'home';
  state.route = normalized;
  root.setAttribute('aria-busy', 'true');
  destroyScreen();
  destroyScreen = () => {};
  try {
    const response = await fetch(routes[normalized], { cache: 'no-store' });
    if (!response.ok) throw new Error(`Nem tölthető be: ${normalized}`);
    root.innerHTML = await response.text();
    createFixedScreenLayout();
    addFullscreenToggle();
    if (normalized === 'query' && state.question) {
      const queryInput = root.querySelector('[data-query-form] input');
      if (queryInput) queryInput.value = state.question;
    }
    if (normalized === 'universe') {
      destroyScreen = initUniverse4(root, { showToast, navigate });
    }
    root.querySelector('.screen-content')?.scrollTo(0, 0);
    document.querySelectorAll('.bottom-nav [data-route]').forEach((button) => {
      const navKey = button.dataset.nav || button.dataset.route;
      button.classList.toggle('is-active', navKey === activeNav(normalized));
    });
  } catch (error) {
    root.innerHTML = `<section class="screen"><header class="top-bar"><div><span class="eyebrow">HIBA</span><h1>Nem tölthető be a képernyő</h1></div></header><p class="empty">${error.message}</p></section>`;
  } finally {
    root.removeAttribute('aria-busy');
  }
}

function navigate(route) {
  const target = routes[route] ? route : 'home';
  if (window.location.hash !== `#${target}`) window.location.hash = target;
  else render(target);
}

document.addEventListener('click', (event) => {
  const scopeToggle = event.target.closest('[data-query-scope-toggle]');
  if (scopeToggle) {
    const menu = document.querySelector('[data-query-scope-menu]');
    if (menu) {
      const open = menu.hidden;
      menu.hidden = !open;
      scopeToggle.setAttribute('aria-expanded', String(open));
    }
    return;
  }

  const scopeOption = event.target.closest('[data-query-scope-option]');
  if (scopeOption) {
    const current = document.querySelector('[data-query-scope-current]');
    const menu = document.querySelector('[data-query-scope-menu]');
    const toggle = document.querySelector('[data-query-scope-toggle]');
    if (current) current.textContent = scopeOption.dataset.queryScopeOption;
    if (menu) menu.hidden = true;
    if (toggle) toggle.setAttribute('aria-expanded', 'false');
    return;
  }

  const queryFill = event.target.closest('[data-query-fill]');
  if (queryFill) {
    const input = document.querySelector('[data-query-form] input');
    if (input) {
      input.value = queryFill.dataset.queryFill;
      input.focus();
    }
    return;
  }

  const queryVoice = event.target.closest('[data-query-voice]');
  if (queryVoice) {
    showToast('Hangbevitel – a mockupban szöveges kérdés indítható.');
    return;
  }

  const routeButton = event.target.closest('[data-route]');
  if (routeButton) {
    event.preventDefault();
    navigate(routeButton.dataset.route);
    return;
  }

  const actionButton = event.target.closest('[data-action]');
  if (!actionButton) return;
  if (actionButton.dataset.action === 'toggle-fullscreen') {
    void toggleFullscreen();
    return;
  }
  if (actionButton.dataset.action === 'save-note') {
    showToast('A jegyzet elmentve a mockupban.');
    navigate('workspace-notes');
  }
  if (actionButton.dataset.action === 'new-topic') showToast('Új téma létrehozása – következő mockup lépés.');
  if (actionButton.dataset.action === 'upload-material') showToast('Anyag feltöltése – következő mockup lépés.');
});

document.addEventListener('submit', (event) => {
  const djinnForm = event.target.closest('[data-djinn-form]');
  if (djinnForm) {
    event.preventDefault();
    state.question = djinnForm.querySelector('input')?.value.trim() || 'Mi kapcsolódik ehhez a tudáshoz?';
    navigate('query');
    return;
  }

  const form = event.target.closest('[data-query-form]');
  if (!form) return;
  event.preventDefault();
  state.question = form.querySelector('input')?.value.trim() || 'Mi kapcsolódik ehhez a tudáshoz?';
  navigate('query-answer');
});

window.addEventListener('hashchange', () => render(window.location.hash.slice(1)));
document.addEventListener('fullscreenchange', syncFullscreenControls);
document.addEventListener('webkitfullscreenchange', syncFullscreenControls);
render(window.location.hash.slice(1) || 'home');
