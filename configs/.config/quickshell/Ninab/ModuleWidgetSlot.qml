import QtQuick

// ModuleWidgetSlot: hosts one module's widget view as a full-width row in
// the card.
//
// WHAT: a right-click catcher UNDERNEATH the widget's own content.
// WHY: unlike ModuleIconSlot there's no left-click gating to do — widget
//   content only lives in the card, and its own controls (sliders,
//   buttons, ...) should just work normally. Right-clicking anywhere the
//   widget itself doesn't consume the click requests a card takeover
//   (Project doc: "right-clicking a module's Icon or Widget expands it
//   to its Card mode").
// NOTE: width is set externally (a full-width row in NinoCardContent.qml)
//   — this doesn't decide its own width.

Item {
    id: slot

    // NOTE: not `required` — unlike ModuleIconSlot's moduleName (set
    // directly in a declarative Repeater delegate binding), this one is
    // set imperatively after construction (see NinoCardContent.qml's
    // Loader.onLoaded).
    property string moduleName: ""
    property var theme: null
    property var system: null
    property var moduleConfig: ({})
    readonly property real availableWidth: width

    signal cardRequested(string moduleId)

    implicitHeight: loader.item ? loader.item.implicitHeight : 0
    // NOTE: plain Item, so height doesn't auto-follow implicitHeight
    // (width is deliberately left to the caller — see above; availableWidth
    // reads back from width, so defaulting width to implicitWidth here
    // would be circular).
    height: implicitHeight

    // WHY: declared first = lower stacking order, so it only ever sees
    // clicks the widget's own controls didn't claim.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: {
            if (loader.item && loader.item.hasCard) slot.cardRequested(slot.moduleName)
        }
    }

    Loader {
        id: loader
        anchors.fill: parent
        // NOTE: moduleName starts empty and is set imperatively right
        // after construction (see NinoCardContent.qml) — guard against
        // briefly trying to load "modules/.qml" in that gap.
        source: slot.moduleName ? ("modules/" + slot.moduleName + ".qml") : ""
        onLoaded: {
            item.displayMode = "widget"
            item.theme = Qt.binding(() => slot.theme)
            item.system = Qt.binding(() => slot.system)
            item.config = Qt.binding(() => slot.moduleConfig)
            item.availableWidth = Qt.binding(() => slot.availableWidth)
        }
    }
}
