const DISCOVERY_TEMPLATE = `
  <main class="explore-discovery" data-explore-discovery>
    <section class="explore-panel" data-explore-panel="overview">
      <section class="explore-spotlight" aria-label="Mai felfedezés">
        <span class="eyebrow">MAI FELFEDEZÉS</span>
        <h2>Új híd: PEEP ↔ Oxigenizáció</h2>
        <p>Hat külön jegyzetben és három közös chunkban együtt jelennek meg.</p>
        <button class="explore-spotlight-action" type="button" data-route="workspace-topic-connections">Kapcsolat felfedezése <b>›</b></button>
      </section>

      <section class="explore-feed-section" aria-labelledby="explore-continue-title">
        <div class="explore-section-heading"><div><span class="eyebrow">ELŐZMÉNY</span><h2 id="explore-continue-title">Folytasd, ahol abbahagytad</h2></div><button class="text-link" type="button" data-route="workspace-topic-connections">Összes</button></div>
        <div class="explore-route-list">
          <button class="explore-route-card" type="button" data-route="workspace-topic-connections"><span class="explore-route-mark">01</span><span><strong>Hipoxémia és gázcsere</strong><small>8 Atom · tegnap felfedezve</small></span><b>›</b></button>
          <button class="explore-route-card" type="button" data-route="workspace-topic-connections"><span class="explore-route-mark">02</span><span><strong>ARDS ventilációs útvonal</strong><small>5 Atom · 3 új kapcsolat</small></span><b>›</b></button>
        </div>
      </section>

      <section class="explore-feed-section" aria-labelledby="explore-bridges-title">
        <div class="explore-section-heading"><div><span class="eyebrow">STRUKTURÁLIS JELZÉSEK</span><h2 id="explore-bridges-title">Érdekes kapcsolatok</h2></div></div>
        <button class="explore-bridge-card" type="button" data-route="workspace-topic-connections"><span class="explore-atom-pill">PaO₂</span><i></i><span class="explore-atom-pill">Oxigénterápia</span><b>0.93</b><small>2 közös mondat · 1 közös chunk</small></button>
        <button class="explore-bridge-card" type="button" data-route="workspace-topic-connections"><span class="explore-atom-pill">Shunt</span><i></i><span class="explore-atom-pill">PEEP</span><b>0.78</b><small>4 közös bekezdés · 2 közös jegyzet</small></button>
      </section>

      <section class="explore-feed-section" aria-labelledby="explore-paths-title">
        <div class="explore-section-heading"><div><span class="eyebrow">VEZETETT FÓKUSZ</span><h2 id="explore-paths-title">Tudásutak</h2></div></div>
        <button class="explore-path" type="button" data-route="workspace-topic-connections"><span>Oxigén</span><b>→</b><span>Gázcsere</span><b>→</b><span>PaO₂</span><b>→</b><span>Hipoxémia</span></button>
        <button class="explore-path" type="button" data-route="workspace-topic-connections"><span>Pneumonia</span><b>→</b><span>Shunt</span><b>→</b><span>PEEP</span></button>
      </section>

      <section class="explore-feed-section" aria-labelledby="explore-topics-title">
        <div class="explore-section-heading"><div><span class="eyebrow">MOZGÁSBAN</span><h2 id="explore-topics-title">Növekvő témák</h2></div></div>
        <div class="explore-topic-chips"><button type="button" data-route="workspace-topic-connections">Légzési elégtelenség <b>+12</b></button><button type="button" data-route="workspace-topic-connections">Hemodinamika <b>+7</b></button><button type="button" data-route="workspace-topic-connections">Intenzív terápia <b>+5</b></button></div>
      </section>
    </section>

    <section class="explore-panel" data-explore-panel="concepts" hidden>
      <section class="explore-panel-intro"><span class="eyebrow">ATOMOK</span><h2>Fogalmak, amelyek most összeérnek</h2><p>Kapcsolati fok, frissesség és strukturális bizonyíték alapján.</p></section>
      <div class="explore-concept-list">
        <button type="button" data-route="workspace-topic-connections"><span class="concept-orb high"></span><span><strong>Oxigén</strong><small>24 kapcsolat · 4 új evidence</small></span><b>›</b></button>
        <button type="button" data-route="workspace-topic-connections"><span class="concept-orb"></span><span><strong>PaO₂</strong><small>18 kapcsolat · erős híd</small></span><b>›</b></button>
        <button type="button" data-route="workspace-topic-connections"><span class="concept-orb warm"></span><span><strong>PEEP</strong><small>14 kapcsolat · növekvő téma</small></span><b>›</b></button>
        <button type="button" data-route="workspace-topic-connections"><span class="concept-orb"></span><span><strong>Shunt</strong><small>11 kapcsolat · 2 új útvonal</small></span><b>›</b></button>
      </div>
    </section>

    <section class="explore-panel" data-explore-panel="connections" hidden>
      <section class="explore-panel-intro"><span class="eyebrow">HIDAK</span><h2>Kapcsolatok, amelyek új kontextust nyitnak</h2><p>A weight strukturális bizonyíték, nem szemantikai fontosság.</p></section>
      <div class="explore-connection-list">
        <button type="button" data-route="workspace-topic-connections"><strong>ARDS <i>↔</i> Perctérfogat</strong><span>Eltérő community · 0.71 evidence</span><b>Felfedezés ›</b></button>
        <button type="button" data-route="workspace-topic-connections"><strong>Diffúzió <i>↔</i> Tüdőödéma</strong><span>3 közös jegyzet · 0.68 evidence</span><b>Felfedezés ›</b></button>
        <button type="button" data-route="workspace-topic-connections"><strong>Hypercapnia <i>↔</i> Intubáció</strong><span>2 közös chunk · 0.62 evidence</span><b>Felfedezés ›</b></button>
      </div>
    </section>
  </main>`;

export function initExploreDiscovery(root) {
  const galaxySlot = root.querySelector('.explore-galaxy-slot');
  if (!galaxySlot) return () => {};

  let discovery = root.querySelector('[data-explore-discovery]');
  if (!discovery) {
    galaxySlot.insertAdjacentHTML('afterend', DISCOVERY_TEMPLATE);
    root.querySelector('.primary-action[data-route="workspace-topic-overview"]')?.remove();
  }
  discovery = root.querySelector('[data-explore-discovery]');

  const tabList = root.querySelector('.screen-subheader .tabs');
  const tabs = [
    ['overview', 'Áttekintés'],
    ['concepts', 'Fogalmak'],
    ['connections', 'Kapcsolatok'],
  ];
  tabList?.setAttribute('role', 'tablist');
  tabList?.setAttribute('aria-label', 'Explore nézetek');
  tabList?.replaceChildren(...tabs.map(([id, label], index) => {
    const tab = document.createElement('button');
    tab.className = `tab${index === 0 ? ' is-active' : ''}`;
    tab.type = 'button';
    tab.setAttribute('role', 'tab');
    tab.setAttribute('aria-selected', String(index === 0));
    tab.dataset.exploreTab = id;
    tab.textContent = label;
    return tab;
  }));

  const tabButtons = [...root.querySelectorAll('[data-explore-tab]')];
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
    if (tab) activate(tab.dataset.exploreTab);
  };

  root.addEventListener('click', onClick);
  return () => root.removeEventListener('click', onClick);
}
