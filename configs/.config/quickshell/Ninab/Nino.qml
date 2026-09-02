import QtQuick

// Nino: the pill/card widget — trails a target point, freezes while
// hovered or paused, expands into a card on click. Screen/Wayland
// agnostic (see shell.qml) and system agnostic (see logic/System.qml) —
// this file only knows about position, shape, and module hosting.

Item {
    id: nino

    // ---- tunables ----
    // WHAT: visual/movement defaults.
    // WHY: normally fed from Theme.qml/Config.qml via shell.qml; these
    //   are just sane fallbacks so Nino still works standalone.
    property int pillWidth: 90
    property int pillHeight: 36
    property int cardWidth: 220
    property int cardHeight: 150
    property real cardCornerRadius: 16   // the pill itself stays fully rounded (a pill shape)
    property real buttonSize: 11         // pin/back corner buttons (circle + triangle), square footprint
    property int followDurationMs: 350   // the "slight delay"
    property color bgColor: "#1e1e2e"
    property color borderColor: Qt.lighter(bgColor, 1.6)

    // WHAT: chrome colors/font, also handed to modules for icon-mode rendering.
    property color fgColor: "#cdd6f4"
    property color accentColor: "#89b4fa"
    property string fontFamily: "sans-serif"
    property real fontSize: 13
    property bool fontBold: false

    // ---- modules ----
    // WHAT: pillModules (["clock", ...], icon-only) and cardModules
    //   ([{name, mode}, ...]) — see modules/template.qml for the contract.
    // WHY: theme/system are handed down as whole instances (not
    //   flattened into individual properties) so modules read
    //   theme.fgColor/system.volume/etc. directly — re-exposing every
    //   possible value on Nino itself wouldn't scale as modules grow.
    property var pillModules: []
    property var cardModules: []
    property var theme: null
    property var system: null
    property var settingsFor: name => ({})

    // WHAT: pill icon row alignment ("left" | "center" | "right").
    // WHY: only meaningful for the pill — card icon rows stay
    //   left-aligned (see ModuleIconRow.qml).
    property string pillAlignment: "left"

    // ---- movement tunables ----
    // WHAT: independent pill/card position+leash settings. angleDegrees
    //   is clockwise from directly above (0°); distancePx is the
    //   distance from the cursor to Nino's center; maxDistancePx is the
    //   leash radius (see maybeTrackTarget below); angleFree ignores
    //   angleDegrees and just holds distancePx in whatever direction
    //   Nino already happens to be.
    // WHY: pill and card are very different sizes — a distance/leash
    //   that feels right for the small pill can feel wrong once the
    //   much bigger card is showing.
    property real pillAngleDegrees: 0
    property bool pillAngleFree: false
    property real pillDistancePx: 40
    property real pillMaxDistancePx: 800

    property real cardAngleDegrees: 0
    property bool cardAngleFree: false
    property real cardDistancePx: 20
    property real cardMaxDistancePx: 500

    readonly property real effectiveAngleDegrees: expanded ? cardAngleDegrees : pillAngleDegrees
    readonly property bool effectiveAngleFree: expanded ? cardAngleFree : pillAngleFree
    readonly property real effectiveDistancePx: expanded ? cardDistancePx : pillDistancePx
    readonly property real effectiveMaxDistancePx: expanded ? cardMaxDistancePx : pillMaxDistancePx

    // WHAT: reserved for a real velocity/acceleration curve (logic/Kinematics.js).
    // NOTE: not acted on yet — Nino eases with a fixed-duration
    //   animation (followDurationMs below).
    property real speed: 5.0
    property real accel: 1.2

    // ---- external input ----
    // WHAT: target point (owner's local coordinate space, e.g. cursor
    //   position converted to screen-local) — Nino anchors itself
    //   above-and-centered on this.
    property real targetX: 0
    property real targetY: 0

    // ---- state ----
    property bool hovered: false
    // WHAT: is Nino following the cursor.
    // WHY: owned externally (see shell.qml) so it's one shared flag
    //   across monitors — otherwise "sitting" on one monitor wouldn't
    //   stop a fresh, still-following Nino spawning on another.
    property bool following: true
    signal toggleFollowRequested()

    // WHAT: pill vs. card. Owned externally, same reasoning as `following`.
    property bool expanded: false
    signal toggleExpandedRequested()

    // WHAT: blocks the leash auto-collapse (see maybeTrackTarget) so an
    //   expanded card can be dragged along instead of collapsing back to
    //   a pill. Owned externally, same reasoning as expanded/following.
    property bool pinned: false
    signal togglePinRequested()

    // ---- card content state ----
    // WHAT: what the card shows — "" is the default overview (all of
    //   cardModules), anything else is a module name (a full takeover of
    //   that module's own card view).
    // WHY: owned externally so it survives a monitor switch; writes go
    //   through moduleCardRequested, never direct assignment.
    property string cardContent: ""
    // WHAT: fires for both "open a module's card" (moduleId set — owner
    //   should also expand) and "back to overview" (moduleId == "").
    signal moduleCardRequested(string moduleId)

    // WHAT: reserved scroll offset for card content.
    // NOTE: not yet written to anywhere — NinoCardContent.qml scrolls on
    //   its own internal Flickable for now; wiring this through would
    //   need a signal-per-scroll-tick, not worth the chatter yet.
    property real cardScrollY: 0

    // WHAT: reserved top strip so module content never renders under the
    //   pin/back buttons (same top-10px corner region).
    // WHY: matches their own anchors.margins below plus a small breathing gap.
    readonly property real cardTopInset: 10 + buttonSize + 6

    // WHAT: fixed-angle polar offset from the target point to Nino's
    //   center, 0° = straight up, clockwise.
    // WHY: used directly in fixed-angle mode, and as the starting
    //   direction before the first free-angle re-anchor.
    readonly property real angleRad: effectiveAngleDegrees * Math.PI / 180
    readonly property real fixedOffsetX: effectiveDistancePx * Math.sin(angleRad)
    readonly property real fixedOffsetY: -effectiveDistancePx * Math.cos(angleRad)

    // WHAT: Nino's actual rendered center — only recomputed while
    //   actively following (not hovered/paused) and once the cursor has
    //   strayed past effectiveMaxDistancePx.
    // WHY: ignoring the cursor inside that radius is what gives a grace
    //   window to walk up and click Nino instead of racing a moving
    //   target. Fixed-angle mode then snaps to the configured
    //   angle/distance; free-angle mode keeps whatever direction Nino
    //   was already sitting at and just enforces the distance (dragged
    //   along, not reset to a side).
    property real restX: 0
    property real restY: 0
    Component.onCompleted: {
        restX = targetX + fixedOffsetX
        restY = targetY + fixedOffsetY
    }
    function maybeTrackTarget() {
        if (!following || hovered) return
        const dx = restX - targetX
        const dy = restY - targetY
        if (Math.hypot(dx, dy) <= effectiveMaxDistancePx) return

        // WHY: an unpinned card left behind collapses to a pill instead
        // of dragging the much bigger card around; pinning is what keeps
        // it put regardless of cursor distance.
        if (expanded && !pinned) {
            toggleExpandedRequested()
            return
        }

        if (effectiveAngleFree) {
            const dist = Math.hypot(dx, dy)
            const ux = dist > 0 ? dx / dist : 0
            const uy = dist > 0 ? dy / dist : -1
            restX = targetX + ux * effectiveDistancePx
            restY = targetY + uy * effectiveDistancePx
        } else {
            restX = targetX + fixedOffsetX
            restY = targetY + fixedOffsetY
        }
    }
    onTargetXChanged: maybeTrackTarget()
    onTargetYChanged: maybeTrackTarget()

    // WHAT: force-clears hover when Nino becomes invisible.
    // WHY: a hidden/click-through instance can't legitimately be
    //   "hovered" — without this, losing focus mid-hover (no guaranteed
    //   exit event once masked out) would leave it stuck frozen the next
    //   time it becomes active.
    onVisibleChanged: if (!visible) hovered = false

    width: expanded ? cardWidth : pillWidth
    height: expanded ? cardHeight : pillHeight
    x: restX - width / 2
    y: restY - height / 2

    Behavior on x { NumberAnimation { duration: nino.followDurationMs; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: nino.followDurationMs; easing.type: Easing.OutCubic } }
    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: nino.expanded ? nino.cardCornerRadius : height / 2
        color: nino.bgColor
        border.color: nino.borderColor
        border.width: 1
        clip: true

        Behavior on radius { NumberAnimation { duration: 150 } }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onEntered: nino.hovered = true
        onExited: nino.hovered = false
        onClicked: mouse => {
            // WHY: left click only opens the pill into a card — once
            // expanded, left/right click belong to module interaction
            // (and the pin button below); collapsing happens via the
            // leash (maybeTrackTarget) or an explicit module action, not
            // a plain click here.
            if (mouse.button === Qt.LeftButton && !nino.expanded) {
                nino.toggleExpandedRequested()
            } else if (mouse.button === Qt.MiddleButton) {
                nino.toggleFollowRequested()
            }
        }
    }

    // NOTE: everything below is declared AFTER the big MouseArea above
    // (and before the pin button further down) so it stacks on top and
    // gets input priority within its own bounds — same trick the pin
    // button itself uses. Left clicks landing where there's no module
    // content still fall through to the big MouseArea for expand/follow.

    // ---- pill content: icon row ----
    // WHAT: fixed-size, non-scrolling icon row, clipped by the
    //   background Rectangle above.
    // WHY: modules that don't fit in pillWidth/pillHeight are just cut
    //   off rather than growing/scrolling the pill (Project doc rule).
    //   interactive: false means left clicks fall through to the big
    //   MouseArea (expand); right clicks are still captured per-icon
    //   (see ModuleIconSlot.qml).
    Item {
        id: pillRowArea
        visible: !nino.expanded
        anchors.fill: parent
        anchors.margins: 6

        // NOTE: its own margined area (not just a shrunk ModuleIconRow
        // width) so alignment offsets computed inside ModuleIconRow are
        // relative to this already-inset space — otherwise "right" would
        // land flush with the pill's true edge instead of matching "left".
        ModuleIconRow {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            interactive: false
            theme: nino.theme
            system: nino.system
            moduleNames: nino.pillModules
            settingsFor: nino.settingsFor
            alignment: nino.pillAlignment
            onCardRequested: moduleId => nino.moduleCardRequested(moduleId)
        }
    }

    // ---- card content: default overview, or one module's full takeover ----
    // WHAT: "shuffle" transition between the two — whichever becomes
    //   current rises from underneath (y offset shrinking, scale/opacity
    //   up, z on top); the other sinks the same way in reverse.
    // WHY: only ever animates between these two fixed elements — the
    //   icon/widget rows that trigger a takeover live inside
    //   NinoCardContent, only visible while showing the default overview,
    //   so there's no path from one module's takeover straight to
    //   another's without passing back through the overview first.
    Item {
        id: cardArea
        visible: nino.expanded
        anchors.fill: parent
        clip: true

        readonly property bool showingDefault: nino.cardContent === ""

        NinoCardContent {
            id: defaultContent
            x: 0
            width: cardArea.width
            height: cardArea.height
            y: cardArea.showingDefault ? 0 : height * 0.12
            scale: cardArea.showingDefault ? 1 : 0.88
            opacity: cardArea.showingDefault ? 1 : 0
            z: cardArea.showingDefault ? 1 : 0
            visible: opacity > 0.01
            theme: nino.theme
            system: nino.system
            cardModules: nino.cardModules
            settingsFor: nino.settingsFor
            topPadding: nino.cardTopInset
            onCardRequested: moduleId => nino.moduleCardRequested(moduleId)

            Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        // WHAT: full takeover of a single module's own card view.
        // NOTE: sizing beyond this is the module's own problem — if its
        //   card content is taller than the card, it wraps itself in a
        //   Flickable; the host doesn't force one.
        Loader {
            id: takeoverLoader
            x: 12
            y: cardArea.showingDefault ? (nino.cardTopInset + height * 0.12) : nino.cardTopInset
            width: cardArea.width - 24
            height: cardArea.height - nino.cardTopInset - 12
            scale: cardArea.showingDefault ? 0.88 : 1
            opacity: cardArea.showingDefault ? 0 : 1
            z: cardArea.showingDefault ? 0 : 1
            visible: opacity > 0.01
            source: nino.cardContent !== "" ? ("modules/" + nino.cardContent + ".qml") : ""
            onLoaded: {
                item.displayMode = "card"
                item.theme = Qt.binding(() => nino.theme)
                item.system = Qt.binding(() => nino.system)
                item.config = Qt.binding(() => nino.settingsFor(nino.cardContent))
                item.availableWidth = Qt.binding(() => takeoverLoader.width)
            }

            Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        // WHAT: back button — mirrors the pin button's corner, returns
        //   to the default overview without collapsing the card itself.
        // WHY: Canvas-drawn upward triangle (no extra import needed
        //   beyond QtQuick) rather than a plain dot, reads as "go up/back".
        Canvas {
            id: backButton
            visible: nino.cardContent !== ""
            width: nino.buttonSize
            height: nino.buttonSize
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 10

            property color fillColor: nino.fgColor
            onFillColorChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.fillStyle = fillColor
                ctx.beginPath()
                ctx.moveTo(width / 2, 0)
                ctx.lineTo(width, height)
                ctx.lineTo(0, height)
                ctx.closePath()
                ctx.fill()
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onClicked: nino.moduleCardRequested("")
            }
        }
    }

    // WHAT: pin button — small circle, card's upper-right corner.
    // WHY: declared last so it stacks above everything else, claiming
    //   clicks in this small region before they reach anything underneath.
    Rectangle {
        id: pinButton
        visible: nino.expanded
        width: nino.buttonSize
        height: nino.buttonSize
        radius: width / 2
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        color: nino.pinned ? nino.accentColor : nino.fgColor

        Behavior on color { ColorAnimation { duration: 150 } }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: nino.togglePinRequested()
        }
    }
}
