import QtQuick
import Quickshell
import Quickshell.Wayland

// One per screen, per Nino. A PanelWindow occupies exactly one screen, so a
// Nino visible across monitors is N windows all drawing the same global
// rect — each window's own edges clip whatever does not overlap it, which
// is what makes crossing a boundary a slide rather than a jump, and what
// makes an anchored mode show on exactly one screen.
PanelWindow {
    id: root

    property var pose: null

    // The name the compositor matches a rule against — mango's
    // `layerrule=...,layer_name:nino`. Nothing in Nino reads it; it is
    // declared rather than left to Quickshell's default because a rule
    // naming the wrong surface fails silently (lore.md L48).
    WlrLayershell.namespace: "nino"

    // Nino holds the keyboard only while something inside is asking for it,
    // and only on the screen it is actually on: there is one of these windows
    // per screen, all drawing the same global rect, so N surfaces asking
    // means the keys land on whichever asked last — which can be one whose
    // copy of Nino its own edges clipped away (lore.md L54).
    //
    // Exclusive rather than OnDemand because OnDemand leaves the choice to
    // the compositor, and mango's answer is "on click" — a search field came
    // up unfocused until it was clicked once (lore.md L55). Focus is a
    // separate mechanism from click-through, which is `mask` below (L12).
    WlrLayershell.keyboardFocus: (pose && pose.keyboardWanted && pose.activeScreen === root.screen)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    // Only Nino's own rectangle takes input; the rest of this
    // screen-covering window stays click-through. An accepted click is
    // exclusively ours and is never forwarded on (lore.md L11).
    mask: Region { item: body }

    Body {
        id: body
        pose: root.pose
        // A module's request bubbles one level at a time and is resolved at
        // the nearest system that owns the state — which for every command
        // so far is Pose.
        onCommandRequested: message => { if (root.pose) root.pose.handleCommand(message); }
        // The window is at the screen's origin, so global becomes local by
        // subtracting it. The slack is Body's own, and is zero except while
        // its size is morphing: Pose gives the position of the *finished*
        // size, and the slack decides which edge stands still on the way
        // there. Body owns its width and height.
        x: (root.pose ? root.pose.x - root.screen.x : 0) + body.slackX
        y: (root.pose ? root.pose.y - root.screen.y : 0) + body.slackY
    }
}
