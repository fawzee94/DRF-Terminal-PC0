import QtQuick
import "../presentation"

// Nino's own chrome — pin, dashboard, close — as an ordinary module rather
// than a separate rendering system. A mode wanting chrome just lists it
// among its modules; there is nothing else to build. See architecture.md
// "System: Modes > Chrome".
ModuleBase {
    id: root

    defaultView: 0

    optionsSchema: ({
        type: "object",
        fields: {
            view: { type: "string", default: "" },
            buttons: { type: "list", idField: "", entry: { type: "string", default: "" } },
            buttonSize: { type: "number", default: 14, min: 1 },
            glyphs: {
                type: "object",
                fields: {
                    pin: { type: "string", default: "󰝥" },
                    dashboard: { type: "string", default: "" },
                    close: { type: "string", default: "󰔶" }
                }
            }
        }
    })

    // Each button's upward command. The vocabulary is shared with IPC, so a
    // pin press and an external caller land on the identical method.
    readonly property var commands: ({
        pin: { command: "setPinned" },
        dashboard: { command: "switchMode", value: "dashboard" },
        close: { command: "close" }
    })

    readonly property var buttons: options.buttons || []
    readonly property real buttonSize: options.buttonSize || 14

    // An icon view declares no size: the row of buttons reports what it
    // comes to, which is the same number the old minWidth restated by hand.
    views: ({
        0: { delegate: buttonRow }
    })

    // The buttons handle their own clicks positionally, so a left click
    // anywhere here is already accounted for and must not also fall through
    // to the mode's background action.
    function handleClick(button) {
        return button === "left";
    }

    Component {
        id: buttonRow

        // The wrapper reports what the row comes to, so a host can lay out
        // against it, while the row itself stays centred in whatever width
        // it is given.
        Item {
            implicitWidth: buttons.implicitWidth
            implicitHeight: buttons.implicitHeight

            Row {
                id: buttons
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: root.buttons

                    Text {
                        id: button
                        required property var modelData

                        width: root.buttonSize
                        height: root.buttonSize
                        text: root.options.glyphs[modelData] || modelData
                        color: tap.pressed ? (root.theme.accent || "#87af5f")
                                           : (root.theme.text || "#ffffff")
                        font.family: root.theme.font || "sans-serif"
                        font.pixelSize: root.buttonSize
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 6
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        TapHandler {
                            id: tap
                            onSingleTapped: {
                                const message = root.commands[modelData];
                                if (!message) return;
                                // The style rides in the theme bundle, so a
                                // button several levels deep reaches it off
                                // the object it already has.
                                const animations = root.theme.animations;
                                if (animations) {
                                    animations.around(button, "buttonPress",
                                                      () => root.commandRequested(message));
                                } else {
                                    root.commandRequested(message);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
