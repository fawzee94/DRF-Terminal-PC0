import QtQuick

// ModuleSlider: a bar slider (track + fill, optional circular knob) —
// click/drag anywhere on the bar to set it. Shared by any module that
// controls a 0..1 level, not tied to one module.
//
// WHAT: barHeight/cornerRadius/showKnob are plain properties, not read
//   from Theme directly.
// WHY: keeps this a dumb, reusable component — every module binds these
//   from theme.sliderHeight/sliderCornerRadius/sliderShowKnob itself
//   (see modules/volume.qml), so all sliders stay consistent without
//   this file reaching into Theme.
//
// WHAT: `value` is controlled/external — the slider never writes to it,
//   only emits `moved`/`committed`; while dragging it shows `dragValue`
//   (live, local) instead.
// WHY: if the caller feeds `moved` straight back into a property bound
//   to `value`, the drag doesn't fight its own feedback loop — same
//   "bound mirror + signal bubble" pattern used everywhere in this
//   codebase (see CLAUDE.md).

Item {
    id: slider

    property real value: 0             // 0..1, set from outside to reflect real state
    property color trackColor: "#000000"
    property color fillColor: "#ffffff"
    property real barHeight: 14
    property real cornerRadius: barHeight / 2
    property bool showKnob: false
    property bool interactive: true

    signal moved(real value)           // fires continuously while dragging/clicking
    signal committed(real value)       // fires once, on release

    property bool dragging: false
    property real dragValue: value
    readonly property real displayValue: dragging ? dragValue : value

    // WHAT: knob drawn bigger than the track, not flush with it.
    // WHY: reads as a "handle" grabbing the track — same idea as Qt
    //   Quick Controls Slider's groove-vs-handle sizing.
    readonly property real knobDiameter: Math.max(barHeight * 1.7, barHeight + 8)

    implicitHeight: showKnob ? knobDiameter : barHeight
    // NOTE: plain Item, so height doesn't auto-follow implicitHeight
    // (width is deliberately left to the caller, same as ModuleWidgetSlot).
    height: implicitHeight

    Rectangle {
        // AI: `clip: true` here is a safety clamp against float-overshoot
        // only — it does NOT shape the fill below. Item/Rectangle.clip in
        // Qt Quick is an axis-aligned bounding-box (scissor) clip; it does
        // not follow a Rectangle's own rounded outline. A square-cornered
        // fill on top of this would keep square corners and paint over
        // the track's rounded ones. The fill gets the same radius
        // directly instead (below) — a smaller pill nested inside this
        // one, the same technique real custom QML sliders use for a
        // track split into independently-rounded segments.
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: slider.barHeight
        radius: slider.cornerRadius
        color: slider.trackColor
        clip: true

        Rectangle {
            width: track.width * slider.displayValue
            height: track.height
            radius: slider.cornerRadius
            color: slider.fillColor
        }
    }

    Rectangle {
        id: knob
        visible: slider.showKnob
        width: slider.knobDiameter
        height: slider.knobDiameter
        radius: width / 2
        anchors.verticalCenter: track.verticalCenter
        x: Math.min(Math.max(track.width * slider.displayValue - width / 2, 0), track.width - width)
        color: slider.fillColor
        border.color: slider.trackColor
        border.width: 2
        scale: slider.dragging ? 1.15 : 1
        antialiasing: true

        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: slider.interactive
        acceptedButtons: Qt.LeftButton

        function updateFromX(x) {
            const v = Math.max(0, Math.min(1, x / width))
            slider.dragValue = v
            slider.moved(v)
        }

        onPressed: mouse => {
            slider.dragging = true
            updateFromX(mouse.x)
        }
        onPositionChanged: mouse => { if (pressed) updateFromX(mouse.x) }
        onReleased: mouse => {
            updateFromX(mouse.x)
            slider.dragging = false
            slider.committed(slider.dragValue)
        }
    }
}
