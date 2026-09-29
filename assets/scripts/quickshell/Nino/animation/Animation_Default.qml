import QtQuick

// The default catalogue: one property per named action. Each is plain data
// rather than a declared animation, because AnimationSet.around has to run a
// style against whatever target it is handed, and a declared
// SequentialAnimation binds its target at creation.
//
// Outer list = steps that play in sequence. Each step's inner list =
// properties that animate together. A literal translation of QML's own
// SequentialAnimation-containing-ParallelAnimation, with no grouping
// mechanism invented on top.
//
// Entries are grouped by what they animate, not by what triggers them:
// content inside Nino, and Nino's own box. An entry is played one of two
// ways, and which one it is decides how its values are written: a *pulse*
// runs out-action-in in one go through AnimationSet.around, while a *held*
// entry is played a phase at a time through AnimationSet.play and must name
// an explicit `to` everywhere.
//
// A custom set is a file whose root element is *this* one, redeclaring only
// the entries that differ — QML inheritance supplies everything else, so
// there is no per-entry fallback to build.
QtObject {
    // ---- Content inside Nino ----------------------------------------
    //
    // The swap itself: played on the content wrapper, with the change made
    // at the low point. Fires for every mode change and for a card changing
    // what it holds, which is the same event seen from Body — Pose composes
    // a takeover into `mode` exactly as it composes a mode.
    property var contentSwap: ({
        out: [[{ property: "opacity", to: 0.2, duration: 110, easing: Easing.InQuad },
                { property: "scale", to: 0.3, duration: 120, easing: Easing.InQuad },
                { property: "rotation", to: 0, duration: 110, easing: Easing.InQuad }]],
        in: [[{ property: "opacity", to: 1.0, duration: 340, easing: Easing.OutQuad },
               { property: "scale", to: 1.0, duration: 340, easing: Easing.OutBack },
               { property: "rotation", to: 0, duration: 540, easing: Easing.OutBack }]]
    })

    // A pulse: the away look is passed through, not held. Free to omit
    // `to` on an `in` step — AnimationSet.around captures the resting value.
    property var buttonPress: ({
        out: [[{ property: "scale", to: 0.5, duration: 80, easing: Easing.OutQuad },
                { property: "opacity", to: 1, duration: 80, easing: Easing.OutQuad },
                { property: "rotation", to: 0, duration: 80, easing: Easing.OutQuad }]],
        in: [[{ property: "scale", to: 1.0, duration: 120, easing: Easing.OutBack },
               { property: "opacity", to: 1.0, duration: 120, easing: Easing.OutQuad },
               { property: "rotation", to: 0, duration: 120, easing: Easing.OutBack }]]
    })

    // Held: `out` on hover, `in` on leave, so every destination is explicit.
    //
    // `grow` rather than a scale ratio: this entry is shared by a 10px mute
    // glyph, a 14px ControlBar button and a 134px slider, and a ratio moves
    // those by one pixel, by two, and by sixteen — the small ones read as
    // not animating at all. A growth gives each the same four pixels. It is
    // the only entry that needs it, because it is the only one played
    // against targets of such different sizes.
    //
    // Opacity is neutral here on purpose — a part at rest is already fully
    // opaque, so the only move available is a dim, and a dimmed element
    // reads as disabled rather than as pointed at. The axis is wired so a
    // custom set can give it a job.
    property var buttonHover: ({
        out: [[{ property: "scale", grow: 2, duration: 120, easing: Easing.OutQuad },
                { property: "opacity", to: 1.0, duration: 120, easing: Easing.OutQuad },
                { property: "rotation", to: 0, duration: 120, easing: Easing.OutQuad }]],
        in: [[{ property: "scale", to: 1.0, duration: 140, easing: Easing.OutQuad },
               { property: "opacity", to: 1.0, duration: 140, easing: Easing.OutQuad },
               { property: "rotation", to: 0, duration: 140, easing: Easing.OutQuad }]]
    })

    // ---- Nino's own box ----------------------------------------------
    //
    // How the box resizes, and which edge stays put while it does. One per
    // set rather than one per entry: the Behavior that runs it sees a size
    // change, not what caused one, so a single answer is the only answer it
    // could act on.
    //
    // growFrom names the edge that HOLDS STILL — "top" keeps the top edge
    // where it is and grows downward, "bottom" grows upward. Anything
    // unrecognised is centre.
    property var shapeMorph: ({
        duration: 320,
        easing: Easing.OutQuad,
        growFrom: "top"     // center | left | right | top | bottom
    })

    // Plays over the morph rather than instead of it, so it stays well clear
    // of scale 0 — the box is busy changing size and hiding it defeats the
    // point. The content has contentSwap for the disappearing act.
    property var modeTransition: ({
        out: [[{ property: "opacity", to: 0.85, duration: 110, easing: Easing.InQuad },
                { property: "scale", to: 1, duration: 10, easing: Easing.InQuad },
                { property: "rotation", to: 0, duration: 110, easing: Easing.InQuad }]],
        in: [[{ property: "opacity", to: 1.0, duration: 180, easing: Easing.OutQuad },
               { property: "scale", to: 1.0, duration: 1580, easing: Easing.OutBack },
               { property: "rotation", to: 0, duration: 180, easing: Easing.OutBack }]]
    })

    // Held, and the one entry whose `out` values are a resting appearance
    // rather than a moment in a transition — a collapsed bar wears them for
    // as long as the cursor stays away.
    //
    // Scale is neutral here on purpose. The morph already shrinks the box to
    // its collapsed size, and the window's input mask is built from the
    // item's plain geometry with no sign that it tracks a transform, so a
    // scale left standing would leave the clickable area disagreeing with
    // what is drawn for the whole time the bar is collapsed.
    property var barCollapse: ({
        out: [[{ property: "scale", to: 1.0, duration: 160, easing: Easing.InQuad },
                { property: "opacity", to: 1, duration: 160, easing: Easing.InQuad },
                { property: "rotation", to: 0, duration: 160, easing: Easing.InQuad }]],
        in: [[{ property: "scale", to: 1.0, duration: 200, easing: Easing.OutQuad },
               { property: "opacity", to: 1.0, duration: 200, easing: Easing.OutQuad },
               { property: "rotation", to: 0, duration: 200, easing: Easing.OutQuad }]]
    })

    property var configReload: ({
        out: [[{ property: "scale", to: 0.5, duration: 120, easing: Easing.OutQuad },
                { property: "opacity", to: 0.30, duration: 120, easing: Easing.OutQuad },
                { property: "rotation", to: 0, duration: 120, easing: Easing.OutQuad }]],
        in: [[{ property: "scale", to: 1.0, duration: 220, easing: Easing.OutBack },
               { property: "opacity", to: 1.0, duration: 220, easing: Easing.OutQuad },
               { property: "rotation", to: 0, duration: 220, easing: Easing.OutBack }]]
    })

    property var pinToggle: ({
        out: [[{ property: "scale", to: 1.02, duration: 90, easing: Easing.OutQuad },
                { property: "opacity", to: 1, duration: 90, easing: Easing.OutQuad },
                { property: "rotation", to: 0, duration: 90, easing: Easing.OutQuad }]],
        in: [[{ property: "scale", to: 1.0, duration: 160, easing: Easing.OutBack },
               { property: "opacity", to: 1.0, duration: 160, easing: Easing.OutQuad },
               { property: "rotation", to: 0, duration: 160, easing: Easing.OutBack }]]
    })

    property var followToggle: ({
        out: [[{ property: "scale", to: 0.98, duration: 90, easing: Easing.OutQuad },
                { property: "opacity", to: 1, duration: 100, easing: Easing.OutQuad },
                { property: "rotation", to: 0, duration: 100, easing: Easing.OutQuad }]],
        in: [[{ property: "scale", to: 1.0, duration: 180, easing: Easing.OutBack },
               { property: "opacity", to: 1.0, duration: 180, easing: Easing.OutQuad },
               { property: "rotation", to: 0, duration: 180, easing: Easing.OutBack }]]
    })
}
