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
    readonly property var theme: Object.assign({ bold: Config.data.bold }, mode,
                                               { animations: animations })

    signal commandRequested(var message)

    color: theme.background || "transparent"
    radius: theme.radius || 0
    border.width: theme.borderWidth || 0
    border.color: theme.accent || "transparent"

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
        const message = Clicks.messageFor((root.mode.clicks || ({}))[name]);
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
    // itself stays upright: rotating Body would turn the very rectangle the
    // window mask and the proximity rect are derived from.
    readonly property bool verticalEdge: root.pose ? root.pose.verticalEdge : false

    // Left turns counter-clockwise so text reads bottom-to-top, right turns
    // clockwise so it reads top-to-bottom.
    readonly property real contentRotation:
        !verticalEdge ? 0 : (root.mode.edge === "right" ? 90 : -90)

    Loader {
        id: content
        width: root.verticalEdge ? parent.height : parent.width
        height: root.verticalEdge ? parent.width : parent.height
        rotation: root.contentRotation
        anchors.centerIn: parent
    }

    readonly property var wantedShape: root.shapes[root.mode.contentShape] || null

    // Imperative rather than a plain binding, because the swap has to happen
    // at the low point of the transition rather than the moment the mode
    // changes. Two modes sharing a shape still cost nothing — wantedShape
    // does not change, so nothing fires and the Loader never recreates.
    onWantedShapeChanged: swapShape()
    Component.onCompleted: content.sourceComponent = wantedShape

    function swapShape() {
        if (!content.sourceComponent) {
            content.sourceComponent = wantedShape;
            return;
        }
        animations.around(root, "modeTransition", () => {
            content.sourceComponent = root.wantedShape;
        });
    }

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
            modules: root.mode.modules || []
            moduleOptions: root.mode.moduleOptions || ({})
            theme: root.theme
            iconSize: root.mode.iconSize || 0
            padding: root.theme.padding || 0
            gap: root.theme.gap || 0
            moduleAlignment: root.mode.moduleAlignment || ({})
            backgroundClicks: root.mode.clicks || ({})
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
            modules: root.mode.modules || []
            moduleOptions: root.mode.moduleOptions || ({})
            theme: root.theme
            iconSize: root.mode.iconSize || 0
            padding: root.theme.padding || 0
            gap: root.theme.gap || 0
            moduleAlignment: root.mode.moduleAlignment || ({})
            backgroundClicks: root.mode.clicks || ({})
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
            columns: root.mode.columns || 1
            rows: root.mode.rows || 1
            cards: root.mode.cards || []
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
                moduleName: root.mode.module || ""
                theme: root.theme
                options: root.mode.moduleOptions || ({})
                // Dot's whole footprint is its one icon, so its `size` is
                // the icon size; padding trades off against it rather than
                // adding to it.
                iconSize: root.mode.size || 0
                padding: root.theme.padding || 0
                fixedCeiling: true
                backgroundClicks: root.mode.clicks || ({})
                onCommandRequested: message => root.commandRequested(message)
            }
        }
    }
}
