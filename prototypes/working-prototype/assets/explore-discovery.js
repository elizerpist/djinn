const TABS = [
  ['overview', 'Áttekintés'],
  ['concepts', 'Fogalmak'],
  ['connections', 'Kapcsolatok'],
];

export function initExploreDiscovery(root) {
  const discovery = root.querySelector('[data-explore-discovery]');
  const tabList = root.querySelector('.screen-subheader .tabs');
  if (!discovery || !tabList) return () => {};

  tabList.setAttribute('role', 'tablist');
  tabList.setAttribute('aria-label', 'Explore nézetek');
  tabList.replaceChildren(...TABS.map(([id, label], index) => {
    const tab = document.createElement('button');
    tab.className = `tab${index === 0 ? ' is-active' : ''}`;
    tab.type = 'button';
    tab.setAttribute('role', 'tab');
    tab.setAttribute('aria-selected', String(index === 0));
    tab.dataset.exploreTab = id;
    tab.textContent = label;
    return tab;
  }));

  const tabButtons = [...tabList.querySelectorAll('[data-explore-tab]')];
  const panels = [...discovery.querySelectorAll('[data-explore-panel]')];
  const activate = (name) => {
    tabButtons.forEach((tab) => {
      const active = tab.dataset.exploreTab === name;
      tab.classList.toggle('is-active', active);
      tab.setAttribute('aria-selected', String(active));
    });
    panels.forEach((panel) => {
      panel.hidden = panel.dataset.explorePanel !== name;
    });
  };

  const onClick = (event) => {
    const tab = event.target.closest('[data-explore-tab]');
    if (tab && tabList.contains(tab)) activate(tab.dataset.exploreTab);
  };

  root.addEventListener('click', onClick);
  return () => root.removeEventListener('click', onClick);
}
