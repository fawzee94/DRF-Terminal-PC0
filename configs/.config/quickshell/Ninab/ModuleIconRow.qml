import QtQuick

// ModuleIconRow: a wrapping row (Flow) of icon-mode modules from an
// ordered name list. Shared by the pill's icon row (interactive: false,
// clipped, no scroll — see Nino.qml) and a contiguous run of icon modules
// inside the card's default view (interactive: true — see
// NinoCardContent.qml), since both are exactly the same layout problem.

Flow {
    id: row

    property var moduleNames: []               // ["clock", "volume", ...], in order
    property bool interactive: true
    property var theme: null
    property var system: null
    property var settingsFor: (name) => ({})    // Config.settingsFor
    property real iconSpacing: 8

    // WHAT: "left" | "center" | "right" row alignment.
    // WHY: Flow has no built-in "justify" — it always lays children out
    //   from its own x:0. childrenRect gives the actual bounding box
    //   Flow's layout produced, so offsetting Flow's x by the leftover
    //   space (width - that box) achieves center/right for the common
    //   single-row case. Wrapped multi-row content ends up close to full
    //   width anyway, so the offset shrinks to ~0 and just reads as
    //   left-aligned — nothing meaningful left to justify at that point.
    property string alignment: "left"
    readonly property real usedWidth: Math.min(childrenRect.width, width)
    x: {
        if (alignment === "center") return (width - usedWidth) / 2
        if (alignment === "right") return width - usedWidth
        return 0
    }

    signal cardRequested(string moduleId)

    spacing: iconSpacing

    // WHAT: tallest icon among the currently-loaded slots.
    // WHY: handed back down to every slot as rowHeight so Flow (which
    //   top-aligns children within a row instead of centering them) ends
    //   up with uniform-height slots, each centering its own icon
    //   inside. Reads each slot's implicitHeight, not its
    //   rowHeight-driven actual height, so this isn't circular.
    readonly property real rowHeight: {
        let maxH = 0
        for (let i = 0; i < repeater.count; i++) {
            const slotItem = repeater.itemAt(i)
            if (slotItem && slotItem.implicitHeight > maxH) maxH = slotItem.implicitHeight
        }
        return maxH
    }

    Repeater {
        id: repeater
        model: row.moduleNames

        delegate: ModuleIconSlot {
            required property string modelData
            moduleName: modelData
            interactive: row.interactive
            theme: row.theme
            system: row.system
            moduleConfig: row.settingsFor(modelData)
            rowHeight: row.rowHeight
            onCardRequested: moduleId => row.cardRequested(moduleId)
        }
    }
}
