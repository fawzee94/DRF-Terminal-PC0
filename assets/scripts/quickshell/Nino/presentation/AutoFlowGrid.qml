import QtQuick
import "../foundation"
import "Packing.js" as Packing

// The fixed-ceiling, no-scroll packing used by Pill and Bar: items flow left
// to right and wrap, each row is as tall as its tallest item, and any row
// whose bottom does not clear the host is discarded outright rather than
// half-drawn. See architecture.md "Row-fit algorithm".
//
// Wrapping is not a per-mode setting. A short pill only ever shows one row
// because its height only admits one, not because wrapping was turned off.
Item {
    id: root

    // Config's module list for this mode: [{ id, module }, ...].
    property var modules: []
    property var moduleOptions: ({})
    property var theme: ({})

    property real iconSize: 0
    property real padding: 0
    property real gap: 0
    property var moduleAlignment: ({})
    property var backgroundClicks: ({})

    signal commandRequested(var message)

    // Each slot reports its own size once its module has loaded and chosen a
    // view, so the layout cannot be computed up front — it settles as they
    // arrive. Replaced wholesale rather than mutated so the binding re-runs.
    property var slotWidths: []
    property var slotHeights: []

    // index -> { x, y }, or undefined for an item that did not fit.
    readonly property var placements: {
        // Nothing here claims a row of its own: a fixed-ceiling host flows
        // everything and drops what will not fit.
        const rows = Packing.packRows(slotWidths.map(w => ({ width: w })), width, gap);
        // A row is as tall as its content, so the cut is whether a row's
        // bottom clears the host — not a count of uniform rows. Uniform ones
        // were taller than what sat in them, and the slack read as gap.
        const stacked = Packing.stackRows(rows, slotHeights, gap);
        let shown = 0;
        while (shown < rows.length
               && stacked.rows[shown].y + stacked.rows[shown].height <= height) shown++;
        const block = shown > 0
            ? stacked.rows[shown - 1].y + stacked.rows[shown - 1].height : 0;
        // Leftover space splits evenly rather than collecting at one edge.
        const top = Geometry.alignedPosition(height, block, moduleAlignment.vertical);

        const out = [];
        for (let r = 0; r < shown; r++) {
            let x = Geometry.alignedPosition(width, rows[r].usedWidth, moduleAlignment.horizontal);
            for (const item of rows[r].items) {
                out[item.index] = { x: x, y: top + stacked.rows[r].y };
                x += item.width + gap;
            }
        }
        return out;
    }

    function noteSize(index, width, height) {
        if (slotWidths[index] !== width) {
            const next = slotWidths.slice();
            next[index] = width;
            slotWidths = next;
        }
        if (slotHeights[index] !== height) {
            const next = slotHeights.slice();
            next[index] = height;
            slotHeights = next;
        }
    }

    Repeater {
        model: root.modules

        ModuleSlot {
            id: slot
            required property int index
            required property var modelData

            moduleName: modelData.module || ""
            theme: root.theme
            options: root.moduleOptions[modelData.id] || ({})
            iconSize: root.iconSize
            padding: root.padding
            heightCeiling: root.height
            fixedCeiling: true
            backgroundClicks: root.backgroundClicks

            // A module may take at most a full row, so that is what it
            // tests its views against. Its own width then follows from the
            // view it picked, via ModuleSlot's implicit sizing.
            offeredWidth: root.width

            readonly property var placement: root.placements[index]
            visible: placement !== undefined
            x: placement ? placement.x : 0
            y: placement ? placement.y : 0

            onWidthChanged: root.noteSize(index, width, height)
            onHeightChanged: root.noteSize(index, width, height)
            Component.onCompleted: root.noteSize(index, width, height)
            onCommandRequested: message => root.commandRequested(message)
        }
    }
}
