import QtQuick
import Quickshell
import Quickshell.Wayland
import "logic"

// Ninab shell entry point.
//
// WHAT: Wayland window/layer-shell plumbing, multi-monitor setup, and the
//   shared "one Nino" identity state mirrored into every monitor's Nino
//   instance.
// WHY: the pill/card widget itself (behaviour + visuals) lives in
//   Nino.qml so it stays screen-agnostic; all system I/O (cursor
//   position, audio, network) lives in logic/System.qml so Nino/modules
//   stay system-agnostic. This file is just the glue between them.
// NOTE: run standalone with `quickshell -p shell.qml`.

ShellRoot {
    id: root

    // WHAT: is Nino currently following the cursor.
    // WHY: shared across every monitor's Nino instance — see Nino.qml
    //   for why this can't just live on each Nino separately.
    property bool following: true

    // WHAT: which monitor currently hosts the visible/active Nino.
    // WHY: tracks the cursor's monitor while following, but freezes in
    //   place while sitting (following: false) so a fresh Nino doesn't
    //   spawn the moment the cursor wanders off to another screen.
    property string activeMonitorName: ""
    Connections {
        target: systemInstance
        function onCursorMonitorChanged() {
            if (root.following) root.activeMonitorName = systemInstance.cursorMonitor
        }
    }
    onFollowingChanged: if (following) activeMonitorName = systemInstance.cursorMonitor

    // ---- Nino identity state ----
    // WHAT: "the one Nino" state — pill/card mode, pin, card content.
    // WHY: owned here, mirrored into whichever monitor's instance is
    //   active, because each monitor gets its own persistent Nino
    //   instance (see Nino.qml) — anything that should survive a
    //   monitor switch has to live above all of them.
    property bool expanded: false
    onExpandedChanged: if (!expanded) pinned = false   // pinning only means something while a card is open

    // WHAT: blocks the leash auto-collapse (see Nino.qml's maybeTrackTarget).
    // WHY: cleared on collapse so it doesn't leak into the next expand.
    property bool pinned: false

    property string cardContent: ""   // "" = default card view; otherwise a module name
    property real cardScrollY: 0      // reserved for scrollable card content

    // WHAT: which module's own card takeover is actually on screen right
    //   now — "" otherwise (including "" when cardContent is stale from
    //   a previous session but the card isn't expanded).
    // WHY: fed into System (below) so it can skip expensive polling
    //   (wifi scan, per-app streams, ping, ...) for a module nobody's
    //   looking at. cardContent alone isn't enough — it doesn't get
    //   reset on collapse, so a leash-triggered collapse would otherwise
    //   still read as "showing" the last-opened module's card.
    readonly property string visibleCardModule: expanded ? cardContent : ""

    // WHAT: opens a module's own card view (or "" for the back button).
    // WHY: "" shouldn't force an expand (it's the back button returning
    //   to the overview); anything else should, in case it came from a
    //   pill icon that hasn't opened a card yet at all.
    function openModuleCard(moduleId) {
        root.cardContent = moduleId
        if (moduleId !== "") root.expanded = true
    }

    // WHAT: theme, config, and system — loaded/instantiated once here,
    //   mirrored (theme/config) or referenced directly (system) by every
    //   monitor's Nino instance below.
    // NOTE: named themeInstance/systemInstance, not theme/system — Nino
    //   and modules also have properties by those names, and e.g.
    //   `theme: theme` would resolve to Nino's OWN property
    //   (self-reference, always null) instead of this one. Qualifying
    //   every use avoids that shadowing.
    Theme { id: themeInstance }
    Config { id: config }
    System {
        id: systemInstance
        cursorPollIntervalMs: config.cursorPollIntervalMs
        cursorIdleIntervalMs: config.cursorIdleIntervalMs
        cursorIdleAfterTicks: config.cursorIdleAfterTicks
        audioPollIntervalMs: config.audioPollIntervalMs
        networkPollIntervalMs: config.networkPollIntervalMs
        pingIntervalMs: config.pingIntervalMs
        pingHost: config.pingHost
        audioSink: config.audioSink
        micSink: config.micSink
        following: root.following
        activeCardModule: root.visibleCardModule
    }

    // one overlay per connected screen
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            // does THIS monitor currently host the active Nino?
            readonly property bool isActive: modelData.name === root.activeMonitorName

            color: "transparent"
            anchors { top: true; left: true; right: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: Layer.Overlay
            // WHAT: OnDemand keyboard focus (not None, not Exclusive).
            // WHY: modules/network.qml's wifi password field needs SOME
            //   focus mode to receive keystrokes; OnDemand only grabs
            //   focus when something inside (a TextInput) actually asks
            //   for it, and releases it otherwise, so it doesn't steal
            //   focus from the rest of the desktop or affect the
            //   click-through pointer behavior (a separate mechanism —
            //   see mask/Region below).
            WlrLayershell.keyboardFocus: KeyboardFocus.OnDemand

            // WHAT: only Nino's own bounds are clickable on this monitor.
            // WHY: Wayland can't both catch a click and forward it to
            //   whatever's underneath — an accepted event is exclusively
            //   yours — so an expanded card can't also claim the rest of
            //   the screen to catch an outside-click-to-collapse. See
            //   Nino.qml's maybeTrackTarget for how it collapses instead
            //   (leash distance, not an outside click).
            mask: Region {
                item: win.isActive ? nino : null
            }

            Nino {
                id: nino
                visible: win.isActive
                following: root.following
                onToggleFollowRequested: root.following = !root.following
                expanded: root.expanded
                onToggleExpandedRequested: root.expanded = !root.expanded
                pinned: root.pinned
                onTogglePinRequested: root.pinned = !root.pinned
                cardContent: root.cardContent
                onModuleCardRequested: moduleId => root.openModuleCard(moduleId)
                cardScrollY: root.cardScrollY

                pillModules: config.pillModules
                cardModules: config.cardModules
                theme: themeInstance
                system: systemInstance
                settingsFor: config.settingsFor
                pillAlignment: config.pillAlignment

                pillWidth: themeInstance.pillWidth
                pillHeight: themeInstance.pillHeight
                cardWidth: themeInstance.cardWidth
                cardHeight: themeInstance.cardHeight
                cardCornerRadius: themeInstance.cornerRadius
                buttonSize: themeInstance.buttonSize
                bgColor: themeInstance.bgColor
                fgColor: themeInstance.fgColor
                accentColor: themeInstance.accentColor
                fontFamily: themeInstance.fontFamily
                fontSize: themeInstance.fontSize
                fontBold: themeInstance.fontBold

                pillAngleDegrees: config.pillAngleDegrees
                pillAngleFree: config.pillAngleFree
                pillDistancePx: config.pillDistancePx
                pillMaxDistancePx: config.pillMaxDistancePx
                cardAngleDegrees: config.cardAngleDegrees
                cardAngleFree: config.cardAngleFree
                cardDistancePx: config.cardDistancePx
                cardMaxDistancePx: config.cardMaxDistancePx
                speed: config.speed
                accel: config.accel

                // convert absolute cursor coords to this screen's local space
                targetX: systemInstance.cursorX - win.modelData.x
                targetY: systemInstance.cursorY - win.modelData.y
            }
        }
    }
}
