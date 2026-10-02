import QtQuick
import Quickshell
import Quickshell.Wayland

// One per screen, per Nino. A PanelWindow occupies exactly one screen, so a
// Nino visible across monitors is N windows all drawing the same global
// rect, each clipping to its own edges. See architecture.md "System:
// Viewport".
PanelWindow {
    id: root

    property var pose: null
    property var instance: ({})

    // Read by nothing here: it exists so a compositor rule can name Nino's
    // surfaces, and a rule naming the wrong surface fails silently (L48).
    WlrLayershell.namespace: "nino"

    // Gated twice — something is asking, and this is the screen — because N
    // surfaces asking means the keys land on whichever asked last (L54).
    // Exclusive rather than OnDemand: mango's OnDemand is "on click" (L55).
    // keyboardScreen rather than activeScreen, because changing this
    // mid-gesture costs the surface its pointer grab (L56).
    WlrLayershell.keyboardFocus: (pose && pose.keyboardWanted && pose.keyboardScreen === root.screen)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Configuration because the choice is a trade: mango offers these two
    // and nothing between them (L57). Not `aboveWindows`, which is the bool
    // spelling of this same property and only reaches Top or Bottom.
    WlrLayershell.layer: root.instance.layer === "overlay"
        ? WlrLayer.Overlay : WlrLayer.Top

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Only Nino's own rectangle takes input; the rest of this
    // screen-covering window stays click-through (L11).
    mask: Region { item: body }

    Body {
        id: body
        pose: root.pose
        // Resolved at the nearest system owning the state, which so far is
        // always Pose.
        onCommandRequested: message => { if (root.pose) root.pose.handleCommand(message); }
        // Global becomes local by subtracting the screen's origin. The slack
        // is Body's, zero except mid-morph: Pose gives the position of the
        // *finished* size, and the slack picks which edge stands still.
        x: (root.pose ? root.pose.x - root.screen.x : 0) + body.slackX
        y: (root.pose ? root.pose.y - root.screen.y : 0) + body.slackY
    }
}
