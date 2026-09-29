import QtQuick
import "../foundation/Clicks.js" as Clicks

// One interactive element *inside* a module — Volume's glyph as against its
// slider, Clock's time as against its date, each ControlBar button. Declared
// as a child of the element it animates and filling it, so the element keeps
// the layout it already had and gains a hover and a press of its own.
//
// A module that declares no parts animates nothing: hover belongs to the
// smallest thing under the cursor, and the slot has no way to guess where
// inside a view that is. See architecture.md "System: Module Part".
Item {
    id: root

    property var theme: ({})

    // A slider is dragged, not pressed: scaling it under the hand fights the
    // very gesture the press would be part of.
    property bool pressable: true

    // Run at the low point of the press, the way AnimationSet.around runs any
    // action, so what a button asks for lands while it is at its smallest.
    // Called with the button name, since a part animates for any button but
    // most only act on one.
    property var action: null

    readonly property alias pressed: tap.pressed

    anchors.fill: parent

    readonly property var animations: (theme && theme.animations) || null

    HoverHandler {
        onHoveredChanged: {
            if (!root.animations) return;
            root.animations.play(root.parent, "buttonHover", hovered ? "out" : "in");
        }
    }

    // The default gesture policy takes only a passive grab, so this observes
    // the tap rather than taking it: Module Slot still routes the click on
    // its own exclusive grab, and a slider's MouseArea keeps its drag
    // (lore.md L44). Nothing here competes for a grab with either.
    TapHandler {
        id: tap
        enabled: root.pressable
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onSingleTapped: (eventPoint, button) => {
            const name = Clicks.nameOf(button);
            if (!name) return;
            const run = root.action ? () => root.action(name) : null;
            if (root.animations) root.animations.around(root.parent, "buttonPress", run);
            else if (run) run();
        }
    }
}
