import QtQuick
import Quickshell.Io

// Theme: shared visual values, loaded from theme.json next to this file
// (auto-created with defaults if missing, live-reloaded on edit).
//
// WHAT: JsonAdapter fields + validated readonly properties on top.
// WHY: JsonAdapter already refuses wrong-typed values (keeps the
//   default, no crash); the readonly properties below also catch values
//   that parse fine but are nonsensical (e.g. a negative size) — the
//   Project doc's "evaluate config values, fallback rather than crash"
//   rule. Always read Theme.xxx elsewhere, never adapter.xxx directly.

FileView {
    id: theme

    path: Qt.resolvedUrl("./theme.json")
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()
    onLoadFailed: error => {
        if (error === FileViewError.FileNotFound) writeAdapter()
    }

    adapter: JsonAdapter {
        id: adapter

        property JsonObject pillSize: JsonObject {
            property real width: 90
            property real height: 36
        }
        property JsonObject cardSize: JsonObject {
            property real width: 220
            property real height: 150
            property real buttonSize: 11   // the pin/back corner buttons (circle + triangle), square footprint
        }
        property real cornerRadius: 16   // card corner radius; the pill stays fully rounded (a pill shape)

        // WHAT: standalone slider styling.
        // WHY: not tied to any one module — every module's ModuleSlider
        //   reads this directly, so all sliders look consistent.
        //   cornerRadius -1 = "unset", falls back to height/2 (a full
        //   pill) below, since that needs `height` to compute.
        property JsonObject slider: JsonObject {
            property real height: 14
            property real cornerRadius: -1   // -1 = "unset", falls back to height / 2 (a full pill)
            property bool showKnob: false
        }

        property color bgColor: "#1e1e2e"
        property color altBgColor: "#15151f"   // a bit darker than bgColor — slider tracks, etc.
        property color fgColor: "#cdd6f4"
        property color accentColor: "#89b4fa"

        property string font: "sans-serif"
        property real fontSize: 13
        property bool fontBold: false
    }

    function positiveOr(value, fallback) {
        return (typeof value === "number" && isFinite(value) && value > 0) ? value : fallback
    }
    function nonNegativeOr(value, fallback) {
        return (typeof value === "number" && isFinite(value) && value >= 0) ? value : fallback
    }
    function boolOr(value, fallback) {
        return (typeof value === "boolean") ? value : fallback
    }

    readonly property real pillWidth: positiveOr(adapter.pillSize.width, 90)
    readonly property real pillHeight: positiveOr(adapter.pillSize.height, 36)
    readonly property real cardWidth: positiveOr(adapter.cardSize.width, 220)
    readonly property real cardHeight: positiveOr(adapter.cardSize.height, 150)
    readonly property real buttonSize: positiveOr(adapter.cardSize.buttonSize, 11)
    readonly property real cornerRadius: nonNegativeOr(adapter.cornerRadius, 16)

    readonly property real sliderHeight: positiveOr(adapter.slider.height, 14)
    readonly property real sliderCornerRadius: nonNegativeOr(adapter.slider.cornerRadius, sliderHeight / 2)
    readonly property bool sliderShowKnob: boolOr(adapter.slider.showKnob, false)

    readonly property color bgColor: adapter.bgColor
    readonly property color altBgColor: adapter.altBgColor
    readonly property color fgColor: adapter.fgColor
    readonly property color accentColor: adapter.accentColor

    readonly property string fontFamily: adapter.font
    readonly property real fontSize: positiveOr(adapter.fontSize, 13)
    readonly property bool fontBold: adapter.fontBold
}
