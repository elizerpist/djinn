const INCLUDE_PATTERN = /<!--\s*include:\s*([^\s]+)\s*-->/g;

function assertResponse(response, path) {
  if (!response?.ok) throw new Error(`Nem tölthető be a képernyő-részlet: ${path}`);
  return response.text();
}

function resolveIncludePath(includePath, fragmentRoot) {
  if (includePath.startsWith('/')) return includePath.slice(1);
  const normalizedRoot = fragmentRoot.replace(/\/$/, '');
  const rootName = normalizedRoot.slice(normalizedRoot.lastIndexOf('/') + 1);
  if (includePath.startsWith(`${rootName}/`)) {
    return `${normalizedRoot}/${includePath.slice(rootName.length + 1)}`;
  }
  return `${normalizedRoot}/${includePath}`;
}

async function resolveIncludes(markup, { fetchImpl, fragmentRoot, depth, seen }) {
  if (depth > 8) throw new Error('A képernyő-részletek egymásba ágyazása túl mély.');
  const matches = [...markup.matchAll(INCLUDE_PATTERN)];
  if (!matches.length) return markup;

  let cursor = 0;
  let resolved = '';
  for (const match of matches) {
    const [token, includeName] = match;
    resolved += markup.slice(cursor, match.index);
    const includePath = resolveIncludePath(includeName, fragmentRoot);
    if (seen.has(includePath)) throw new Error(`Körkörös képernyő-részlet hivatkozás: ${includePath}`);
    seen.add(includePath);
    const response = await fetchImpl(includePath, { cache: 'no-store' });
    const fragment = await assertResponse(response, includePath);
    resolved += await resolveIncludes(fragment, { fetchImpl, fragmentRoot, depth: depth + 1, seen });
    seen.delete(includePath);
    cursor = match.index + token.length;
  }
  return resolved + markup.slice(cursor);
}

export async function loadScreenMarkup(path, {
  fetchImpl = globalThis.fetch.bind(globalThis),
  fragmentRoot = 'screens/partials',
} = {}) {
  const response = await fetchImpl(path, { cache: 'no-store' });
  const markup = await assertResponse(response, path);
  return resolveIncludes(markup, {
    fetchImpl,
    fragmentRoot,
    depth: 0,
    seen: new Set([path]),
  });
}

export function syncScreenTabs(root, route) {
  root.querySelectorAll('.topic-tabs[data-route-tabs], .workspace-tabs[data-route-tabs]').forEach((tabList) => {
    tabList.querySelectorAll('[data-route]').forEach((button) => {
      button.classList.toggle('is-active', button.dataset.route === route);
    });
  });
}
