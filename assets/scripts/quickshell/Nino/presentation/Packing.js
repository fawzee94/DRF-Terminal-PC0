// Pure packing arithmetic, shared by the auto-flow grid (fixed ceiling) and
// the contextual body (organic height) — they differ in how they treat height, not
// in how they pack width. No imports, no QML.

// Packs items left to right in order, wrapping when the next one will not
// fit the remaining width. Each item is { width, solo }; an item marked
// solo claims a row to itself, which is how a contextual keeps anything that is
// not an icon out of the flow. Returns rows of
// { items: [{ index, width }], usedWidth }.
//
// An item too wide for an empty row is dropped. Corrected 2026-09-23: it
// used to get a row of its own "rather than vanishing", which is precisely
// how modules came to extend past Nino's edge. A host cannot draw what is
// wider than it is, and an absence is easier to see and fix than an
// overflow.
function packRows(items, availableWidth, gap) {
  const rows = [];
  let current = { items: [], usedWidth: 0 };

  function closeRow() {
    if (current.items.length > 0) rows.push(current);
    current = { items: [], usedWidth: 0 };
  }

  for (let i = 0; i < items.length; i++) {
    const item = items[i] || {};
    const width = item.width || 0;
    // A zero width is a slot that is not rendering — its module failed to
    // load, or no view of it fits. It takes no room and no gap, rather than
    // leaving a hole where something was supposed to be.
    if (width <= 0) continue;
    if (width > availableWidth) continue;

    if (item.solo) {
      closeRow();
      rows.push({ items: [{ index: i, width: width }], usedWidth: width });
      continue;
    }

    const extended = current.items.length === 0 ? width : current.usedWidth + gap + width;
    if (current.items.length > 0 && extended > availableWidth) closeRow();
    current.usedWidth = current.items.length === 0 ? width : current.usedWidth + gap + width;
    current.items.push({ index: i, width: width });
  }

  closeRow();
  return rows;
}

// Stacks packed rows from the top, each row as tall as its tallest item.
// Every host measures this way: a contextual grows to the total, a fixed-ceiling
// host keeps the rows whose bottom clears it. Uniform rows were the
// alternative and they were taller than what sat in them, which turned their
// own slack into apparent gap. Returns { rows: [{ y, height }], totalHeight }.
function stackRows(rows, heights, gap) {
  const placed = [];
  let y = 0;

  for (let r = 0; r < rows.length; r++) {
    let tallest = 0;
    for (const item of rows[r].items) {
      tallest = Math.max(tallest, heights[item.index] || 0);
    }
    placed.push({ y: y, height: tallest });
    y += tallest + gap;
  }

  return { rows: placed, totalHeight: Math.max(0, y - gap) };
}

if (typeof module !== 'undefined') {
  module.exports = { packRows, stackRows };
}
