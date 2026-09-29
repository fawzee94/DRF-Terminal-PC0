import QtQuick
import "../foundation/Clicks.js" as Clicks
import "../foundation"
import "../presentation"
import "../animation"

// The persistent content host, one per Viewport. Never destroyed or
// reloaded across a mode switch: position lives in Pose, which does not
// reload, so a transition has nothing to rescue.
Rectangle {
    id: root

    property var pose: null

    readonly property var mode: pose ? pose.mode : ({})
    readonly property var instance: pose ? pose.instance : ({})

    // One per Nino. Chosen at instance level only — never inherited or
    // overridden per mode.
    AnimationSet {
        id: animations
        setName: (root.instance && root.instance.animationSet) || "Default"
    }

    // The token bundle every level below reads from. The mode slice already
    // carries every theme field — Config resolved inheritance when it
    // loaded — so this is that slice plus the global fields no mode
    // inherits. Phase 7 adds the animation set to it.
    // The animation set rides in the same bundle as the colours, so a
    // button several levels down reaches its style off the object it
    // already has rather than having it re-declared at every level.
    // Nino's own live state rides along with the look. The bundle named
    // `theme` is already displayedMode wholesale plus the animation set, so
    // it is the module-facing bundle rather than a palette, and a second one
    // plumbed through every content shape buys nothing for one flag. Last, so
    // a mode block declaring the same key cannot shadow it.
    readonly property var theme: Object.assign({ bold: Config.data.bold }, displayedMode,
                                               { animations: animations,
                                                 pinned: root.pose ? root.pose.pinned : false })

    signal commandRequested(var message)

    // The body's own look follows the mode at once; only what the content
    // reads waits for the swap's low point. See `displayedMode`.
    color: mode.background || "transparent"
    radius: mode.radius || 0
    border.width: mode.borderWidth || 0
    border.color: mode.accent || "transparent"

    // Body owns its size because the morph is Body's — Viewport places it,
    // Pose decides what size it should be, and the interpolation between
    // two sizes belongs to neither.
    width: pose ? pose.w : 0
    height: pose ? pose.h : 0

    // Off until there is a size to move from, or the first frame animates
    // the whole box in from nothing before Nino has been placed at all.
    Behavior on width {
        enabled: root.width > 0
        NumberAnimation {
            duration: animations.morph.duration || 0
            easing.type: animations.morph.easing !== undefined
                ? animations.morph.easing : Easing.OutQuad
        }
    }
    Behavior on height {
        enabled: root.height > 0
        NumberAnimation {
            duration: animations.morph.duration || 0
            easing.type: animations.morph.easing !== undefined
                ? animations.morph.easing : Easing.OutQuad
        }
    }

    // While the box morphs, its size lags what Pose asked for. Where that
    // slack is taken is which edge appears to stand still; Viewport adds it
    // to the position Pose computed for the finished size.
    readonly property real slackX: ((pose ? pose.w : 0) - width) * animations.grow.x
    readonly property real slackY: ((pose ? pose.h : 0) - height) * animations.grow.y

    // A scale or a rotation emanates from the same edge the morph holds, so
    // the two never pull in opposite directions.
    transformOrigin: animations.grow.origin

    // Drag is Nino's, not a module's: the gesture repositions the whole
    // window, so it belongs to the thing being moved rather than to
    // whatever happened to be under the finger. Dragging anywhere on Nino
    // works, including the padding and the gaps between modules.
    //
    // Inner interactive content still wins, but not by hit-testing order:
    // a widget owning a press-drag gesture grabs on press, and a
    // DragHandler is allowed by default to take that grab the moment the
    // drag threshold passes (lore.md L44). Dropping CanTakeOverFromItems
    // is what leaves Volume's slider alone. Handlers stay stealable — a
    // TapHandler yielding to a drag is the disambiguation we want.
    DragHandler {
        enabled: root.mode.draggable === true && !!root.pose
        // Nothing here is moved by the handler; Pose owns position.
        target: null
        grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType
                       | PointerHandler.ApprovesTakeOverByAnything

        property vector2d lastTranslation: Qt.vector2d(0, 0)

        onActiveChanged: {
            if (active) {
                lastTranslation = Qt.vector2d(0, 0);
                root.pose.beginDrag();
            } else {
                root.pose.endDrag();
            }
        }

        onActiveTranslationChanged: {
            if (!active) return;
            root.pose.dragBy(activeTranslation.x - lastTranslation.x,
                             activeTranslation.y - lastTranslation.y);
            lastTranslation = activeTranslation;
        }
    }

    // The background click, for the same reason the drag is here: Nino's
    // padding and the gaps between modules are part of its surface, and a
    // Module Slot only ever sees what lands on the slot itself. A slot
    // resolves its own click and never lets one reach here.
    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onSingleTapped: (eventPoint, button) => root.routeBackground(button)
    }

    function routeBackground(button) {
        const name = Clicks.nameOf(button);
        if (!name) return;
        const message = Clicks.messageFor((root.displayedMode.clicks || ({}))[name]);
        if (message) root.commandRequested(message);
    }

    // One Loader, its component named by the active mode's own data. Two
    // consecutive modes sharing a shape cost nothing: the binding value does
    // not change, so the Loader never recreates.
    readonly property var shapes: ({
        single: singleShape,
        autoflow: autoFlowShape,
        cardBody: cardBodyShape,
        dashboardGrid: dashboardShape
    })

    // A bar on a vertical edge packs along its long axis and turns as one
    // piece, so every shape, module and view is reused unchanged. The box
    // itself is never left turned: rotating Body turns the very rectangle the
    // window mask and the proximity rect derive from, which only a pulse may
    // do, and only because it ends back at rest.
    //
    // The edge is read off the content clock rather than off Pose, which
    // knows the same thing about the live mode: the turn and the box it
    // turns in belong to the content, so they change when the content does
    // rather than a transition early.
    readonly property string contentEdge: root.displayedMode.edge || "top"
    readonly property bool verticalEdge: contentEdge === "left" || contentEdge === "right"

    // Left turns counter-clockwise so text reads bottom-to-top, right turns
    // clockwise so it reads top-to-bottom.
    readonly property real contentRotation:
        !verticalEdge ? 0 : (contentEdge === "right" ? 90 : -90)

    // The edge turn lives on the wrapper so the Loader's own rotation stays
    // free for the catalogue. One property cannot carry two rotations: the
    // catalogue's values are an offset from rest, while rest for a vertical
    // bar is already ±90, so animating the turned property would replace the
    // turn rather than add to it — and a held entry would leave it replaced.
    Item {
        width: root.verticalEdge ? parent.height : parent.width
        height: root.verticalEdge ? parent.width : parent.height
        rotation: root.contentRotation
        anchors.centerIn: parent

        Loader {
            id: content
            anchors.fill: parent
            sourceComponent: root.shapes[root.displayedMode.contentShape] || null
        }
    }

    // Collapse is a change to Nino's shape, so it plays on Body alongside
    // the morph that resizes it. Held: a bar stays collapsed for as long as
    // the cursor stays away.
    readonly property bool revealed: root.pose ? root.pose.revealed : true
    onRevealedChanged: animations.play(root, "barCollapse", revealed ? "in" : "out")

    // Off Pose's state, not off the click that caused it, so a ControlBar
    // press, a background click and an IPC call all look the same.
    Connections {
        target: root.pose
        function onPinnedChanged() { animations.around(root, "pinToggle"); }
        function onFollowingChanged() { animations.around(root, "followToggle"); }
    }

    Connections {
        target: Config
        function onReloaded() { animations.around(root, "configReload"); }
    }

    // The mode the *content* is currently showing, which trails the real one
    // by exactly one animation. Everything below this level reads it rather
    // than `mode`, so the shape, the modules, the padding and the gaps all
    // change together at the low point rather than one of them changing
    // early and the rest arriving late.
    //
    // It also makes one hook cover both halves of "the content changed":
    // Pose composes a takeover into `mode` the same way it composes a mode,
    // so a card swapping to a takeover and a mode change are one event here.
    // Two consecutive modes sharing a shape still cost nothing — the Loader
    // sees the same component and never recreates.
    property var displayedMode: ({})
    Component.onCompleted: displayedMode = mode
    onModeChanged: swapContent()

    function swapContent() {
        if (!content.sourceComponent) {
            displayedMode = mode;
            return;
        }
        animations.around(content, "contentSwap", () => { root.displayedMode = root.mode; });
    }

    // Body's own shape change, on its own clock beside the content's — the
    // two overlap deliberately. Keyed on which mode is active rather than on
    // `mode`, so a takeover and a config reload, neither of which resizes
    // the box, leave the body alone.
    readonly property string activeMode: root.pose ? root.pose.activeMode : ""
    onActiveModeChanged: animations.around(root, "modeTransition")

    // Dot: exactly one Module Slot, no packing and no shape component of its
    // own. Phase 5 adds the auto-flow grid, the card body and the dashboard
    // grid alongside it.
    //
    // The wrapper exists because a Loader that has been given a size resizes
    // whatever it loads to fill it — right for the packing shapes, wrong for
    // Dot, whose single icon must sit at `size - padding` and be centred. The
    // wrapper takes the fill; the slot keeps its own size inside it.
    // Pill and Bar: items flow and wrap, rows are a uniform icon height, and
    // whatever does not fit the rows available is dropped.
    Component {
        id: autoFlowShape

        AutoFlowGrid {
            anchors.fill: parent
            // padding is the total inset, split evenly — it trades off
            // against icon size rather than adding to the footprint.
            anchors.margins: (root.theme.padding || 0) / 2
            modules: root.displayedMode.modules || []
            moduleOptions: root.displayedMode.moduleOptions || ({})
            theme: root.theme
            iconSize: root.displayedMode.iconSize || 0
            padding: root.theme.padding || 0
            gap: root.theme.gap || 0
            moduleAlignment: root.displayedMode.moduleAlignment || ({})
            backgroundClicks: root.displayedMode.clicks || ({})
            onCommandRequested: message => root.commandRequested(message)
        }
    }

    // Card, and every Dashboard cell, share this verbatim — the only
    // difference is the viewport each is handed.
    Component {
        id: cardBodyShape

        CardBody {
            anchors.fill: parent
            anchors.margins: (root.theme.padding || 0) / 2
            modules: root.displayedMode.modules || []
            moduleOptions: root.displayedMode.moduleOptions || ({})
            theme: root.theme
            iconSize: root.displayedMode.iconSize || 0
            padding: root.theme.padding || 0
            gap: root.theme.gap || 0
            moduleAlignment: root.displayedMode.moduleAlignment || ({})
            backgroundClicks: root.displayedMode.clicks || ({})
            onCommandRequested: message => root.commandRequested(message)
        }
    }

    // Dashboard looks each card up by its authored col/row/w/h rather than
    // packing anything.
    Component {
        id: dashboardShape

        DashboardGrid {
            anchors.fill: parent
            anchors.margins: (root.theme.padding || 0) / 2
            columns: root.displayedMode.columns || 1
            rows: root.displayedMode.rows || 1
            cards: root.displayedMode.cards || []
            theme: root.theme
            padding: root.theme.padding || 0
            gap: root.theme.gap || 0
            onCommandRequested: message => root.commandRequested(message)
        }
    }

    Component {
        id: singleShape

        Item {
            ModuleSlot {
                anchors.centerIn: parent
                moduleName: root.displayedMode.module || ""
                theme: root.theme
                options: root.displayedMode.moduleOptions || ({})
                // Dot's whole footprint is its one icon, so its `size` is
                // the icon size; padding trades off against it rather than
                // adding to it.
                iconSize: root.displayedMode.size || 0
                padding: root.theme.padding || 0
                fixedCeiling: true
                backgroundClicks: root.displayedMode.clicks || ({})
                onCommandRequested: message => root.commandRequested(message)
            }
        }
    }
}
