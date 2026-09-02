import QtQuick
import Quickshell.Io

// Config: user-tunable movement/module-layout values, loaded from
// config.json next to this file (auto-created with defaults if missing,
// live-reloaded on edit). Same validated-readonly-property approach as
// Theme.qml — see there for why.
//
// WHAT: pill/card get independent angleDegrees/distancePx/maxDistancePx.
// WHY: very different sizes — a distance/leash that feels right for the
//   small pill can feel wrong once the much bigger card is showing.
//   angleDegrees/distancePx position Nino relative to the cursor (0° =
//   directly above, clockwise) unless angleFree holds distancePx in
//   whatever direction Nino already is instead of a fixed compass spot.
//   maxDistancePx is the leash radius — Nino ignores the cursor inside
//   it, giving a grace window to walk up and click instead of racing a
//   moving target.
//
// WHAT: pillModules/cardModules pick which modules show up where.
// WHY: pill is icon-only (flat name list); card can show a module as an
//   icon or full-width widget row, so each entry also carries a "mode".
//   moduleSettings is a freeform per-module blob — each module validates
//   its own slice (see modules/template.qml).

FileView {
    id: config

    path: Qt.resolvedUrl("./config.json")
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()
    onLoadFailed: error => {
        if (error === FileViewError.FileNotFound) writeAdapter()
    }

    adapter: JsonAdapter {
        id: adapter

        property JsonObject pill: JsonObject {
            property real angleDegrees: 0     // 0 = directly above the cursor, clockwise
            property bool angleFree: false    // true: ignore angleDegrees, just hold distancePx from the cursor
            property real distancePx: 40      // distance from the cursor to the pill's center
            property real maxDistancePx: 800  // leash radius before the pill bothers following
            property string alignment: "left" // "left" | "center" | "right" — icon row alignment when it doesn't fill the pill
        }
        property JsonObject card: JsonObject {
            property real angleDegrees: 0
            property bool angleFree: false
            property real distancePx: 20
            property real maxDistancePx: 500
        }

        property real speed: 5.0   // reserved: movement speed once kinematics exist
        property real accel: 1.2   // reserved: acceleration once kinematics exist

        // WHAT: tunables for logic/System.qml.
        // WHY: it's the one place that shells out to the OS, so its poll
        //   rates/targets live in config too rather than being hardcoded there.
        property JsonObject system: JsonObject {
            property real cursorPollIntervalMs: 30
            property real cursorIdleIntervalMs: 400   // poll rate once the cursor's held still
            property int cursorIdleAfterTicks: 5      // consecutive unchanged reads before backing off
            property real audioPollIntervalMs: 2000
            property real networkPollIntervalMs: 2000
            property real pingIntervalMs: 5000
            property string pingHost: "1.1.1.1"
            property string audioSink: "@DEFAULT_AUDIO_SINK@"
            property string micSink: "@DEFAULT_AUDIO_SOURCE@"
        }

        property var pillModules: []       // ["clock", ...] — icon mode only, in order
        property var cardModules: []       // [{"name": "clock", "mode": "icon"|"widget"}, ...], in order
        property var moduleSettings: ({})  // {"clock": {...its own config...}, ...}
    }

    function numberOr(value, fallback) {
        return (typeof value === "number" && isFinite(value)) ? value : fallback
    }
    function wrapDegrees(value, fallback) {
        return ((numberOr(value, fallback) % 360) + 360) % 360
    }
    function nonNegative(value, fallback) {
        return Math.max(0, numberOr(value, fallback))
    }
    function positiveOr(value, fallback) {
        return (typeof value === "number" && isFinite(value) && value > 0) ? value : fallback
    }
    function boolOr(value, fallback) {
        return typeof value === "boolean" ? value : fallback
    }
    // WHAT: duck-typed array check, not Array.isArray(value).
    // WHY: a JSON array read off a JsonAdapter `property var` (like
    //   pillModules/cardModules below) is array-*like* — indexable,
    //   real .length, .filter()/.map() work — but fails
    //   Array.isArray()/instanceof Array.
    // AI: this is not a hypothetical edge case — it's what silently
    //   zeroed out pillModules/cardModules the first time around, with
    //   no warning anywhere since it's not a deserialize error, just a
    //   validator that looked reasonable and wasn't. Use this helper for
    //   any array-shaped config value, in any file, not Array.isArray().
    function isArrayLike(value) {
        return !!value && typeof value.length === "number" && typeof value.filter === "function"
    }
    function stringList(value, fallback) {
        if (!isArrayLike(value)) return fallback
        return value.filter(v => typeof v === "string")
    }
    function moduleEntryList(value, fallback) {
        if (!isArrayLike(value)) return fallback
        return value
            .filter(v => v && typeof v === "object" && typeof v.name === "string")
            .map(v => ({ name: v.name, mode: v.mode === "widget" ? "widget" : "icon" }))
    }
    function plainObject(value, fallback) {
        return (value && typeof value === "object" && !isArrayLike(value)) ? value : fallback
    }
    function alignmentOr(value, fallback) {
        return (value === "left" || value === "center" || value === "right") ? value : fallback
    }

    readonly property real pillAngleDegrees: wrapDegrees(adapter.pill.angleDegrees, 0)
    readonly property bool pillAngleFree: boolOr(adapter.pill.angleFree, false)
    readonly property real pillDistancePx: nonNegative(adapter.pill.distancePx, 40)
    readonly property real pillMaxDistancePx: nonNegative(adapter.pill.maxDistancePx, 800)
    readonly property string pillAlignment: alignmentOr(adapter.pill.alignment, "left")

    readonly property real cardAngleDegrees: wrapDegrees(adapter.card.angleDegrees, 0)
    readonly property bool cardAngleFree: boolOr(adapter.card.angleFree, false)
    readonly property real cardDistancePx: nonNegative(adapter.card.distancePx, 20)
    readonly property real cardMaxDistancePx: nonNegative(adapter.card.maxDistancePx, 500)

    readonly property real speed: nonNegative(adapter.speed, 5.0)
    readonly property real accel: nonNegative(adapter.accel, 1.2)

    function stringOr(value, fallback) {
        return (typeof value === "string" && value.length > 0) ? value : fallback
    }
    readonly property real cursorPollIntervalMs: positiveOr(adapter.system.cursorPollIntervalMs, 30)
    readonly property real cursorIdleIntervalMs: positiveOr(adapter.system.cursorIdleIntervalMs, 400)
    readonly property int cursorIdleAfterTicks: positiveOr(adapter.system.cursorIdleAfterTicks, 5)
    readonly property real audioPollIntervalMs: positiveOr(adapter.system.audioPollIntervalMs, 2000)
    readonly property real networkPollIntervalMs: positiveOr(adapter.system.networkPollIntervalMs, 2000)
    readonly property real pingIntervalMs: positiveOr(adapter.system.pingIntervalMs, 5000)
    readonly property string pingHost: stringOr(adapter.system.pingHost, "1.1.1.1")
    readonly property string audioSink: stringOr(adapter.system.audioSink, "@DEFAULT_AUDIO_SINK@")
    readonly property string micSink: stringOr(adapter.system.micSink, "@DEFAULT_AUDIO_SOURCE@")

    readonly property var pillModules: stringList(adapter.pillModules, [])
    readonly property var cardModules: moduleEntryList(adapter.cardModules, [])
    readonly property var moduleSettings: plainObject(adapter.moduleSettings, ({}))

    // WHAT: this module's settings sub-object, or {} if there isn't one.
    // WHY: used by ModuleIconSlot.qml/ModuleWidgetSlot.qml — modules
    //   validate their own slice, this only guarantees "it's an object".
    function settingsFor(moduleName) {
        const s = moduleSettings[moduleName]
        return (s && typeof s === "object") ? s : {}
    }
}
