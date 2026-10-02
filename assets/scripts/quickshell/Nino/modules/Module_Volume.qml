import QtQuick
import "../presentation"
import "../services"

// Default sink volume. Consumes AudioService directly — a singleton needs no
// injection, and a service is shared machine-wide rather than per-Nino.
ModuleBase {
    id: root

    defaultView: 0
    viewNames: ({ icon: 0, takeover: 1, widget: 2 })

    // Every left click that lands anywhere in this module is already spoken
    // for: the glyph mutes, the track sets the level.
    claimedButtons: ["left"]

    optionsSchema: ({
        type: "object",
        fields: {
            view: { type: "string", default: "" },
            // Config supplies glyphs for a Nerd Font; these defaults are
            // plain Unicode so the module is legible before it is styled.
            icons: {
                type: "object",
                fields: {
                    volumeHigh: { type: "string", default: "\u{1F50A}" },
                    volumeMid: { type: "string", default: "\u{1F509}" },
                    volumeLow: { type: "string", default: "\u{1F508}" },
                    mute: { type: "string", default: "\u{1F507}" }
                }
            },
            // The slider's own length. It has to declare one rather than
            // measure the space it is in: a fixed-ceiling host lays the slot
            // out at what the view draws, so a width read back off that width
            // is a loop. A host with more room to give still stretches it.
            sliderWidth: { type: "number", default: 40, min: 12 },
            clicks: { type: "opaque" }
        }
    })

    // Ref-counted: the service polls only while something is showing it, and
    // drops to fully idle the moment this module goes away.
    Component.onCompleted: AudioService.request()
    Component.onDestruction: AudioService.release()

    readonly property var reading: AudioService.lastReading
    readonly property real level: reading ? reading.volume : 0
    readonly property bool muted: reading ? reading.muted : false

    readonly property string glyph: {
        const icons = options.icons || ({});
        if (muted) return icons.mute;
        if (level >= 0.66) return icons.volumeHigh;
        if (level >= 0.33) return icons.volumeMid;
        return icons.volumeLow;
    }

    readonly property real sliderWidth: options.sliderWidth || 40

    views: ({
        0: { delegate: iconView },
        2: { minWidth: 40, minHeight: 18, maxHeight: 22, delegate: sliderView }
    })

    Component {
        id: iconView

        // Sized like every icon: the glyph states its point size and the
        // host lays out against whatever that comes to.
        Text {
            text: root.glyph
            color: root.theme.text || "#ffffff"
            font.family: root.theme.font || "sans-serif"
            font.pixelSize: root.iconSizing
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            ModulePart {
                theme: root.theme
                action: name => { if (name === "left") AudioService.toggleMute(); }
            }
        }
    }

    // One channel: the mute glyph, then a track the width of whatever is
    // left. The fill is what the system reports, never what was just
    // requested, so an external change — media keys, another app — moves it
    // exactly the same way a drag here does.
    Component {
        id: sliderView

        // The wrapper reports what the channel comes to, so a host can lay
        // out against it. It does not centre the row: anchoring a row to the
        // middle of the very item whose size that row decides is a loop, and
        // a host that hugs leaves nothing to centre in anyway.
        Item {
            implicitWidth: channel.implicitWidth
            implicitHeight: channel.implicitHeight

            Row {
                id: channel
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    id: glyph
                    anchors.verticalCenter: parent.verticalCenter
                    // A Row pays its spacing for a zero-width child, so an
                    // unconfigured glyph would leave a gap in front of the
                    // slider. Hidden, it costs nothing.
                    visible: text !== ""
                    text: root.glyph
                    color: root.theme.text || "#ffffff"
                    font.family: root.theme.font || "sans-serif"
                    font.pixelSize: root.theme.fontSize || 8

                    // Its own part: muting from here leaves the slider
                    // beside it perfectly still.
                    ModulePart {
                        theme: root.theme
                        action: name => { if (name === "left") AudioService.toggleMute(); }
                    }
                }

                Item {
                    id: slider
                    anchors.verticalCenter: parent.verticalCenter
                    // A fixed-ceiling host is as wide as this view reports,
                    // so reading its width back would be the report chasing
                    // itself. There the slider is simply its own length; a
                    // contextual offers a width of its own and it stretches.
                    width: root.fixedCeiling ? root.sliderWidth
                        : Math.max(root.sliderWidth, root.availableWidth
                            - (glyph.visible ? glyph.width + channel.spacing : 0))
                    height: Math.max(12, root.theme.fontSize || 12)

                    Rectangle {
                        id: track
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: 2
                        color: root.theme.background || "#2e282828"
                        border.width: root.theme.borderWidth || 0
                        border.color: root.theme.accent || "#87af5f"
                    }

                    Rectangle {
                        anchors.left: track.left
                        anchors.verticalCenter: track.verticalCenter
                        width: track.width * Math.max(0, Math.min(1, root.level))
                        height: track.height
                        radius: track.radius
                        color: root.muted ? (root.theme.text || "#888888")
                                          : (root.theme.accent || "#87af5f")

                        // Smooths a change from any source. Held off until a
                        // real reading exists, so the first one does not glide
                        // up from a fake zero.
                        Behavior on width {
                            enabled: root.reading !== undefined
                            NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                        }
                    }

                    // Hover only. A press here is the start of a drag, and
                    // scaling the track under the hand would fight the very
                    // gesture it belongs to.
                    ModulePart {
                        theme: root.theme
                        pressable: false
                    }

                    // A MouseArea rather than a handler: press position and
                    // continuous tracking in one, which is what a slider needs.
                    // Nino's own drag leaves this gesture alone because Body
                    // declines to take a grab from an item (lore.md L44) — the
                    // grab itself does not protect it.
                    MouseArea {
                        anchors.fill: parent
                        function applyAt(mx) {
                            AudioService.setVolume(mx / width);
                        }
                        onPressed: mouse => applyAt(mouse.x)
                        onPositionChanged: mouse => { if (pressed) applyAt(mouse.x); }
                    }
                }
            }
        }
    }
}
