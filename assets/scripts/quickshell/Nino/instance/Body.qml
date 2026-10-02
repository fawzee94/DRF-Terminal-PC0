import QtQuick
import "../foundation/Clicks.js" as Clicks
import "../foundation"
import "../presentation"
import "../animation"

// The persistent content host, one per Viewport. Never destroyed or
// reloaded across a mode switch, so a transition has nothing to rescue.
// See architecture.md "System: Modes".
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

    // The one bundle every level below reads: displayedMode wholesale (Config
    // already resolved theme inheritance) plus the global fields no mode
    // inherits, the animation set and Nino's live state. Module-facing rather
    // than a palette, so a second bundle buys nothing. The explicit keys go
    // last, where a mode block declaring the same name cannot shadow them.
    readonly property var theme: Object.assign({ bold: Config.data.bold }, displayedMode,
                                               { animations: animations,
                                                 pinned: root.pose ? root.pose.pinned : false })

    signal commandRequested(var message)

    // The body's own look follows the mode at once; only what the content
    // reads waits for the swap's low point — see `displayedMode`.
    color: mode.background || "transparent"
    radius: mode.radius || 0
    border.width: mode.borderWidth || 0
    border.color: mode.accent || "transparent"

    // Body owns its size because the morph is Body's: Viewport places it,
    // Pose decides what size it should be, the interpolation is neither's.
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

    // Mid-morph the size lags what Pose asked for. Where that slack is taken
    // is which edge appears to stand still; Viewport adds it to the position.
    readonly property real slackX: ((pose ? pose.w : 0) - width) * animations.grow.x
    readonly property real slackY: ((pose ? pose.h : 0) - height) * animations.grow.y

    // A scale or a rotation emanates from the same edge the morph holds, so
    // the two never pull in opposite directions.
    transformOrigin: animations.grow.origin

    // Drag belongs to the thing being moved, so it lives here rather than in
    // a slot — the padding and the gaps between modules drag too.
    //
    // A DragHandler may by default take a grab from an item that already has
    // one (L44), which is what dragged Nino along with the Volume slider.
    // Dropping CanTakeOverFromItems leaves inner press-drag gestures alone;
    // handlers stay stealable, since a TapHandler yielding to a drag is the
    // disambiguation wanted.
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

    // Here for the same reason the drag is. A slot takes an exclusive grab
    // and resolves its own click, so this only ever sees what lands outside
    // one.
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

    // One Loader, its component named by the mode's own data. Two consecutive
    // modes sharing a shape never recreate it — the binding value is equal.
    readonly property var shapes: ({
        single: singleShape,
        autoflow: autoFlowShape,
        contextualBody: contextualBodyShape,
        fullScreenGrid: fullScreenShape
    })

    // A vertical anchored turns as one piece, so every shape, module and view
    // is reused unchanged. The box itself is never left turned: rotating Body
    // turns the very rectangle the window mask and the proximity rect derive
    // from. Read off the content clock, not Pose, so the turn changes when the
    // content does rather than a transition early.
    readonly property string contentEdge: root.displayedMode.edge || "top"
    readonly property bool verticalEdge: contentEdge === "left" || contentEdge === "right"

    // Left turns counter-clockwise so text reads bottom-to-top, right turns
    // clockwise so it reads top-to-bottom.
    readonly property real contentRotation:
        !verticalEdge ? 0 : (contentEdge === "right" ? 90 : -90)

    // The turn lives on the wrapper so the Loader's own rotation stays free
    // for the catalogue: one property cannot carry two rotations, and the
    // catalogue's values are offsets from a rest that is already ±90 here.
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

    // A change to Nino's shape, so it plays on Body alongside the morph that
    // resizes it. Held: an anchored stays collapsed while the cursor is away.
    readonly property bool revealed: root.pose ? root.pose.revealed : true
    onRevealedChanged: animations.play(root, "proximityCollapse", revealed ? "in" : "out")

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

    // The mode the *content* is showing, trailing the real one by exactly one
    // animation. Everything below reads this rather than `mode`, so the shape,
    // the modules, the padding and the gaps all change together at the low
    // point. Pose composes a takeover into `mode` the same way it composes a
    // mode, so one hook covers both.
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

    // Body's own clock beside the content's; the two overlap deliberately.
    // Keyed on activeMode rather than `mode`, so a takeover and a config
    // reload — neither of which resizes the box — leave the body alone.
    readonly property string activeMode: root.pose ? root.pose.activeMode : ""
    onActiveModeChanged: animations.around(root, "modeTransition")

    // Dynamic and Anchored: items flow and wrap, rows are a uniform icon
    // height, and whatever does not fit the rows available is dropped.
    Component {
        id: autoFlowShape

        AutoFlowGrid {
            anchors.fill: parent
            // The total inset, split evenly: it trades off against icon size
            // rather than adding to the footprint.
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

    // Contextual and every FullScreen cell share this verbatim; only the
    // viewport each is handed differs.
    Component {
        id: contextualBodyShape

        ContextualBody {
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

    // FullScreen looks each contextual up by its authored col/row/w/h rather than
    // packing anything.
    Component {
        id: fullScreenShape

        FullScreenGrid {
            anchors.fill: parent
            anchors.margins: (root.theme.padding || 0) / 2
            columns: root.displayedMode.columns || 1
            rows: root.displayedMode.rows || 1
            tiles: root.displayedMode.tiles || []
            theme: root.theme
            padding: root.theme.padding || 0
            gap: root.theme.gap || 0
            onCommandRequested: message => root.commandRequested(message)
        }
    }

    // Leashed: one Module Slot, no packing. The wrapper is load-bearing — a
    // Loader given a size resizes whatever it loads to fill it, which is
    // right for the packing shapes and wrong here, where the single icon must
    // sit at `size - padding` and be centred. The wrapper takes the fill; the
    // slot keeps its own size inside it.
    Component {
        id: singleShape

        Item {
            ModuleSlot {
                anchors.centerIn: parent
                moduleName: root.displayedMode.module || ""
                theme: root.theme
                options: root.displayedMode.moduleOptions || ({})
                // Leashed's whole footprint is its one icon, so `size` is the
                // icon size and padding trades off against it.
                iconSize: root.displayedMode.size || 0
                padding: root.theme.padding || 0
                fixedCeiling: true
                backgroundClicks: root.displayedMode.clicks || ({})
                onCommandRequested: message => root.commandRequested(message)
            }
        }
    }
}
