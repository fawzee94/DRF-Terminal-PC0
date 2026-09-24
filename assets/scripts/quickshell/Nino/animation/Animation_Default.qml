import QtQuick

// The default catalogue: one property per named action. Each is plain data
// rather than a declared animation, because Animate.around has to run a
// style against whatever target it is handed, and a declared
// SequentialAnimation binds its target at creation.
//
// Outer list = steps that play in sequence. Each step's inner list =
// properties that animate together. A literal translation of QML's own
// SequentialAnimation-containing-ParallelAnimation, with no grouping
// mechanism invented on top.
//
// A custom set is a file whose root element is *this* one, redeclaring only
// the entries that differ — QML inheritance supplies everything else, so
// there is no per-entry fallback to build.
QtObject {
    property var buttonPress: ({
        out: [[{ property: "scale", to: 0.85, duration: 80, easing: Easing.OutQuad },
                { property: "opacity", to: 0.96, duration: 80, easing: Easing.OutQuad }]],
        in: [[{ property: "scale", to: 1.0, duration: 120, easing: Easing.OutBack },
               { property: "opacity", to: 1.0, duration: 120, easing: Easing.OutQuad }]]
    })

    property var modeTransition: ({
        out: [[{ property: "opacity", to: 0.0, duration: 110, easing: Easing.InQuad },
                { property: "scale", to: 0.0, duration: 110, easing: Easing.InQuad }]],
        in: [[{ property: "opacity", to: 1.0, duration: 140, easing: Easing.OutQuad },
               { property: "scale", to: 1.0, duration: 140, easing: Easing.OutBack }]]
    })
}
