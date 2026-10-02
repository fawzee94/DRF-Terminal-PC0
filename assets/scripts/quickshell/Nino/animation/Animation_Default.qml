import QtQuick

// The default catalogue: one property per named action, as plain data
// rather than declared animations. See architecture.md "System: Animation
// Catalogue". Editing this file is the supported way to retune Nino's feel.
//
// Outer list = steps that play in sequence; each step's inner list =
// properties that animate together.
//
// Entries are grouped by what they animate, not by what triggers them. An
// entry is played one of two ways, and that decides how its values are
// written: a *pulse* runs out-action-in in one go, while a *held* entry is
// played a phase at a time and must name an explicit `to` everywhere.
//
// A custom set is a file whose root element is *this* one, redeclaring only
// the entries that differ; QML inheritance supplies the rest.
QtObject {
    // ---- Content inside Nino ----------------------------------------
    //
    // Played on the content wrapper, with the change made at the low point.
    // Fires for every mode change and for a contextual changing what it
    // holds, which is one event from Body's side.
    property var contentSwap: ({
        out: [[{ property: "opacity", to: 0.2, duration: 110, easing: Easing.InQuad },
                { property: "scale", to: 0.3, duration: 120, easing: Easing.InQuad },
                { property: "rotation", to: 0, duration: 110, easing: Easing.InQuad }]],
        in: [[{ property: "opacity", to: 1.0, duration: 340, easing: Easing.OutQuad },
               { property: "scale", to: 1.0, duration: 340, easing: Easing.OutBack },
               { property: "rotation", to: 0, duration: 540, easing: Easing.OutBack }]]
    })

    // A pulse: the away look is passed through, not held. Free to omit `to`
    // on an `in` step — `around` captures the resting value.
    property var buttonPress: ({
        out: [[{ property: "scale", to: 0.5, duration: 80, easing: Easing.OutQuad },
                { property: "opacity", to: 1, duration: 80, easing: Easing.OutQuad },
                { property: "rotation", to: 0, duration: 80, easing: Easing.OutQuad }]],
        in: [[{ property: "scale", to: 1.0, duration: 120, easing: Easing.OutBack },
               { property: "opacity", to: 1.0, duration: 120, easing: Easing.OutQuad },
               { property: "rotation", to: 0, duration: 120, easing: Easing.OutBack }]]
    })

    // Held: `out` on hover, `in` on leave, so every destination is explicit.
    // `grow` names pixels rather than a ratio, because this entry is played
    // against targets from a 10px glyph to a 134px slider. Opacity is
    // neutral on purpose — the only move available is a dim, which reads as
    // disabled rather than as pointed at — but the axis is wired so a custom
    // set can give it a job.
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
    // change and not what caused one.
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
    // of scale 0. The content has contentSwap for the disappearing act.
    property var modeTransition: ({
        out: [[{ property: "opacity", to: 0.85, duration: 110, easing: Easing.InQuad },
                { property: "scale", to: 1, duration: 10, easing: Easing.InQuad },
                { property: "rotation", to: 0, duration: 110, easing: Easing.InQuad }]],
        in: [[{ property: "opacity", to: 1.0, duration: 180, easing: Easing.OutQuad },
               { property: "scale", to: 1.0, duration: 1580, easing: Easing.OutBack },
               { property: "rotation", to: 0, duration: 180, easing: Easing.OutBack }]]
    })

    // Held, and the one entry whose `out` values are a resting appearance
    // rather than a moment in a transition. Scale must stay neutral: it
    // targets Body, whose input mask is plain geometry with no sign of
    // tracking a transform, so a scale left standing puts the clickable area
    // out of step with what is drawn for as long as the state lasts.
    property var proximityCollapse: ({
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
