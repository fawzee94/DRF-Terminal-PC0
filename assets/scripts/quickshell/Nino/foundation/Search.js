// Pure search arithmetic for the launcher module. No imports, no QML: app
// rows arrive as desktop entries and file rows as a process's stdout, and
// both are plain data by the time they reach here.

// Case-insensitive substring on the name, alphabetical. Deliberately not
// ranked: the query is the navigation, and an order that re-sorts as you
// type moves a row out from under the selection.
function matchApps(entries, query, limit) {
  const needle = String(query || '').toLowerCase();
  const matched = (entries || []).filter(entry => entry && typeof entry.name === 'string'
    && entry.name.toLowerCase().indexOf(needle) >= 0);
  matched.sort((a, b) => a.name.localeCompare(b.name));
  return limit > 0 ? matched.slice(0, limit) : matched;
}

// Wraps both ways, so holding Down walks off the last row onto the first.
function stepIndex(index, count, delta) {
  if (count <= 0) return 0;
  return ((index + delta) % count + count) % count;
}

// `-name '.*' -prune` drops hidden trees before descending them rather than
// filtering their contents afterwards, and `%y` is what tells a folder from
// a file, so the kind comes from this one process instead of a stat per row.
// The caller must not pass an empty query: `**` matches the whole tree.
function findCommand(root, depth, query) {
  return ['find', root,
    '-mindepth', '1', '-maxdepth', String(Math.max(1, depth)),
    '-name', '.*', '-prune', '-o',
    '-iname', '*' + query + '*', '-printf', '%y\t%p\n'];
}

function baseName(path) {
  const cut = path.lastIndexOf('/');
  return cut >= 0 ? path.slice(cut + 1) : path;
}

// A line is "<kind>\t<path>". Anything without a path after a tab is
// skipped: find writes its own errors to stderr, but a path containing a
// newline would otherwise arrive as a row with no kind.
function pathRows(text, limit) {
  const rows = [];
  for (const line of String(text || '').split('\n')) {
    const tab = line.indexOf('\t');
    if (tab < 1) continue;
    const path = line.slice(tab + 1);
    if (!path) continue;
    rows.push({ path: path, name: baseName(path), isDir: line[0] === 'd' });
    if (limit > 0 && rows.length >= limit) break;
  }
  return rows;
}

if (typeof module !== 'undefined') {
  module.exports = { matchApps, stepIndex, findCommand, pathRows };
}
