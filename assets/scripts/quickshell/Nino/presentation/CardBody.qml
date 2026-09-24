import QtQuick
import "../foundation"
import "Packing.js" as Packing

// The organic-height, scrollable packing. Card mode and every Dashboard
// cell use this verbatim, differing only in the viewport size they are
// handed — which is why a cell and a standalone Card look and behave
// identically with no special-casing. See architecture.md "System: Card Body".
//
// Height is organic: a view renders at its own natural size and the
// scrollable area grows to fit, so there is no height for a view to fail.
// Width stays a real fit decision.
Item {
    id: root

    property var modules: []
    property var moduleOptions: ({})
    property var theme: ({})

    property real iconSize: 0
    property real padding: 0
    property real gap: 0
    property var moduleAlignment: ({})
    property var backgroundClicks: ({})

    signal commandRequested(var message)

    property var slotWidths: []
    property var slotHeights: []
    property var slotSolo: []

    readonly property var layout: {
        // Only icons flow. Anything else claims a row, so a widget never
        // sits beside an icon and a takeover never shares with what follows.
        const items = slotWidths.map((w, i) => ({ width: w, solo: slotSolo[i] === true }));
        const rows = Packing.packRows(items, flick.width, gap);
        const stacked = Packing.stackRows(rows, slotHeights, gap);
        const places = [];
        for (let r = 0; r < rows.length; r++) {
            let x = Geometry.alignedPosition(flick.width, rows[r].usedWidth, moduleAlignment.horizontal);
            for (const item of rows[r].items) {
                places[item.index] = { x: x, y: stacked.rows[r].y };
                x += item.width + gap;
            }
        }
        return { places: places, totalHeight: stacked.totalHeight };
    }

    function noteSize(index, width, height, solo) {
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
        if (slotSolo[index] !== solo) {
            const next = slotSolo.slice();
            next[index] = solo;
            slotSolo = next;
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: root.layout.totalHeight
        boundsBehavior: Flickable.StopAtBounds

        // interactive: false disables Flickable's own drag recognition while
        // keeping its clipping, content-height and bounds machinery. Native
        // flick scrolling *is* a drag gesture, and would fight Card's
        // drag-to-reposition on the same surface; driving contentY from a
        // WheelHandler instead means two input channels that no single
        // gesture can trigger at once, so there is nothing to arbitrate.
        interactive: false

        // Where the wheel has asked the content to be, which is not where
        // it currently is while the ease below is still running. Reading
        // contentY for the next notch instead would measure from a position
        // the animation has not finished reaching, and a fast spin would
        // lose most of its distance.
        property real scrollTarget: 0

        // A wheel notch arrives as one 120-unit step, so writing it
        // straight into contentY teleports the content by more than half a
        // card at a time — which is the whole of why scrolling read as
        // choppy. The Behavior interpolates between notches, and a burst of
        // them retargets the animation already running rather than queueing
        // behind it, so holding the wheel down glides.
        Behavior on contentY {
            NumberAnimation { id: scrollEase; duration: 120; easing.type: Easing.OutQuad }
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
                // No ceiling: scrolling absorbs any amount of content.
                fixedCeiling: false
                offeredWidth: flick.width
                backgroundClicks: root.backgroundClicks

                readonly property var placement: root.layout.places[index]
                visible: placement !== undefined
                x: placement ? placement.x : 0
                y: placement ? placement.y : 0

                readonly property bool solo: !slot.showingIcon

                onWidthChanged: root.noteSize(index, width, height, solo)
                onHeightChanged: root.noteSize(index, width, height, solo)
                onSoloChanged: root.noteSize(index, width, height, solo)
                Component.onCompleted: root.noteSize(index, width, height, solo)
                onCommandRequested: message => root.commandRequested(message)
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.scrollBy(event.angleDelta.y)
    }

    // One wheel notch is a 120-unit step upward; scrolling down is negative.
    // Mid-ease the target is the truth, and at rest contentY is — which is
    // what picks up a content height that changed underneath it.
    function scrollBy(delta) {
        const limit = Math.max(0, flick.contentHeight - flick.height);
        const from = scrollEase.running ? flick.scrollTarget : flick.contentY;
        flick.scrollTarget = Math.max(0, Math.min(limit, from - delta));
        flick.contentY = flick.scrollTarget;
    }

    // What the content is easing toward, for a check that cannot wait out
    // an animation to read where it landed.
    readonly property real scrollTarget: flick.scrollTarget
    readonly property real scrollLimit: Math.max(0, flick.contentHeight - flick.height)
}
