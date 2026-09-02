import QtQuick

// Module template — copy this file to build a new module.
//
// WHAT: drop the copy into modules/ under a lowercase filename (e.g.
//   modules/mymodule.qml) and reference that name — no ".qml" — in
//   config.json's pillModules/cardModules. Settings live under
//   config.json's moduleSettings["mymodule"], read via `config` below.
//
// WHAT: three views (icon/widget/card) switched by `displayMode` — icon
//   fits in the pill or a card icon row; widget is a full-width card
//   row, your own height; card is a full takeover of Nino's card
//   (right-click an icon/widget to get here), same ambition as widget
//   with the whole card instead of one row. Declare which you implement
//   via hasIcon/hasWidget/hasCard.
// WHY: not every module needs all three — e.g. a slider-only module
//   might leave hasIcon/hasCard false.
//
// WHAT: click handling is NOT this file's job — ModuleIconSlot.qml/
//   ModuleWidgetSlot.qml (repo root) own every MouseArea. A module only
//   implements activateIcon() (icon left-clicked while hosted in the
//   card — no-op is fine if purely informational) and renders its
//   view(s); right-click-to-open-card is entirely generic.
// WHY: pill-vs-card and left-vs-right gating lives in one place instead
//   of every module reinventing it.

Item {
    id: module

    // ---- declare what you implement ----
    readonly property bool hasIcon: true
    readonly property bool hasWidget: true
    readonly property bool hasCard: true

    // ---- set by the host (ModuleIconSlot/ModuleWidgetSlot/NinoCardContent) ----
    // NOTE: read-only from a module's own perspective — don't write these.
    property string displayMode: "icon"   // "icon" | "widget" | "card"
    property var theme: null              // Theme.qml instance — theme.fgColor, theme.accentColor, theme.fontFamily, theme.fontSize, theme.fontBold, ...
    property var system: null             // logic/System.qml instance — system.volume, system.setVolume(), ... ; read/act through this, never shell out from a module directly
    property var config: ({})             // this module's own settings sub-object; may be missing keys or {} entirely
    property real availableWidth: 0       // only meaningful in widget/card mode — the row's/card's content width

    // ---- tunables ----
    // WHAT: pull your own config-derived values here, with a fallback —
    //   same approach as Theme.qml/Config.qml.
    // WHY: `config` can be {} or wrong-shaped (hand-edited config.json,
    //   or nobody's configured this new module yet) — never trust it
    //   directly, a bad/missing value should degrade to a sane default.
    readonly property string exampleText: (typeof config.exampleText === "string") ? config.exampleText : "Hello"

    // WHAT: icon left-click hook.
    // WHY: called by the host ONLY when hosted in the card, not the pill
    //   (see ModuleIconSlot.qml for why) — no-op is fine if the icon is
    //   purely informational.
    function activateIcon() {}

    // WHAT: implicitWidth/Height, matter most in icon mode (the pill's
    //   and card's icon rows are a Flow, sized off each icon's own
    //   implicit size). In widget/card mode height is up to you; width
    //   should normally just track availableWidth.
    // NOTE: keep all three view Items declared below even for a view you
    //   don't implement (hasIcon/hasWidget/hasCard false) — leave it
    //   empty (implicitWidth:0, implicitHeight:0) rather than deleting
    //   it, since this binding references all three by id regardless.
    implicitWidth: displayMode === "icon" ? iconView.implicitWidth : availableWidth
    implicitHeight: {
        if (displayMode === "icon") return iconView.implicitHeight
        if (displayMode === "widget") return widgetView.implicitHeight
        return cardView.implicitHeight
    }
    // AI: a plain Item's actual width/height do NOT automatically track
    // implicitWidth/Height the way Text or a positioner's would — without
    // these two lines this module computes a correct implicit size and
    // then renders at 0x0 anyway. Every module built from this template
    // needs this same pair. This has bitten multiple files already.
    width: implicitWidth
    height: implicitHeight

    // ---- icon view ----
    Item {
        id: iconView
        anchors.fill: parent
        visible: module.displayMode === "icon"
        implicitWidth: iconLabel.implicitWidth + 8
        implicitHeight: iconLabel.implicitHeight + 4

        Text {
            id: iconLabel
            anchors.centerIn: parent
            text: module.exampleText
            color: module.theme ? module.theme.fgColor : "#cdd6f4"
            font.family: module.theme ? module.theme.fontFamily : "sans-serif"
            font.pixelSize: module.theme ? module.theme.fontSize : 13
            font.bold: module.theme ? module.theme.fontBold : false
        }
    }

    // ---- widget view (full-width row in the card) ----
    Item {
        id: widgetView
        width: module.availableWidth
        visible: module.displayMode === "widget"
        implicitHeight: 48

        Text {
            anchors.centerIn: parent
            text: "Widget view: " + module.exampleText
            color: module.theme ? module.theme.fgColor : "#cdd6f4"
            font.family: module.theme ? module.theme.fontFamily : "sans-serif"
        }
    }

    // ---- card view (full takeover of Nino's card) ----
    Item {
        id: cardView
        width: module.availableWidth
        visible: module.displayMode === "card"
        implicitHeight: 200

        Text {
            anchors.centerIn: parent
            text: "Card view: " + module.exampleText
            color: module.theme ? module.theme.fgColor : "#cdd6f4"
            font.family: module.theme ? module.theme.fontFamily : "sans-serif"
        }
    }
}
