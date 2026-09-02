import QtQuick

// NinoCardContent: the card's default (non-takeover) body.
//
// WHAT: chunks the ordered cardModules list into contiguous icon-flow
//   segments and full-width widget rows, in list order, inside a
//   Flickable.
// WHY: list order determines display order (Project doc); Flickable so
//   an unlimited number of modules can fit ("cards are scrollable").
//   Click routing (left-click actions, right-click-to-card) all happens
//   in ModuleIconSlot/ModuleWidgetSlot — this just lays things out and
//   forwards cardRequested upward.

Flickable {
    id: root

    property var cardModules: []               // [{name, mode}, ...] from Config.cardModules
    property var theme: null
    property var system: null
    property var settingsFor: (name) => ({})    // Config.settingsFor

    signal cardRequested(string moduleId)

    readonly property real contentPadding: 12
    // WHAT: top padding only, kept separate from contentPadding.
    // WHY: the host overrides this to clear the pin button (top-right
    //   corner) rather than sharing the smaller side/bottom padding.
    //   Defaults to contentPadding so standalone use is unaffected.
    property real topPadding: contentPadding
    readonly property real rowSpacing: 8
    readonly property real iconSpacing: 8

    clip: true
    contentWidth: width
    contentHeight: column.height + topPadding + contentPadding
    boundsBehavior: Flickable.StopAtBounds

    // WHAT: groups consecutive icon-mode entries into one Flow segment;
    //   each widget-mode entry becomes its own full-width segment.
    // WHY: order is preserved throughout, per the display-order rule above.
    function buildSegments(list) {
        const segments = []
        let iconRun = []
        for (const entry of list) {
            if (entry.mode === "widget") {
                if (iconRun.length) {
                    segments.push({ kind: "icons", items: iconRun })
                    iconRun = []
                }
                segments.push({ kind: "widget", name: entry.name })
            } else {
                iconRun.push(entry.name)
            }
        }
        if (iconRun.length) segments.push({ kind: "icons", items: iconRun })
        return segments
    }
    readonly property var segments: buildSegments(cardModules)

    Column {
        id: column
        x: root.contentPadding
        y: root.topPadding
        width: root.width - root.contentPadding * 2
        spacing: root.rowSpacing

        Repeater {
            model: root.segments

            delegate: Loader {
                id: segLoader
                required property var modelData
                sourceComponent: modelData.kind === "widget" ? widgetComponent : iconRowComponent
                onLoaded: {
                    if (modelData.kind === "widget") item.moduleName = modelData.name
                    else item.moduleNames = modelData.items
                }
            }
        }
    }

    Component {
        id: widgetComponent
        ModuleWidgetSlot {
            width: column.width
            theme: root.theme
            system: root.system
            moduleConfig: root.settingsFor(moduleName)
            onCardRequested: moduleId => root.cardRequested(moduleId)
        }
    }

    Component {
        id: iconRowComponent
        ModuleIconRow {
            width: column.width
            interactive: true
            theme: root.theme
            system: root.system
            settingsFor: root.settingsFor
            iconSpacing: root.iconSpacing
            onCardRequested: moduleId => root.cardRequested(moduleId)
        }
    }
}
