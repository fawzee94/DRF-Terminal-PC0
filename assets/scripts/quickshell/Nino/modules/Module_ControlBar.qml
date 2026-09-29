import QtQuick
import "../presentation"

// Nino's own chrome — pin, dashboard, close — as an ordinary module rather
// than a separate rendering system. A mode wanting chrome just lists it
// among its modules; there is nothing else to build. See architecture.md
// "System: Modes > Chrome".
ModuleBase {
    id: root

    defaultView: 0

    // Every left click here lands on a button, so none of them may also
    // reach the mode.
    claimedButtons: ["left"]

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
                    back: { type: "string", default: "󰔶" },
                    close: { type: "string", default: "" }
                }
            }
        }
    })

    // Each button's upward command. The vocabulary is shared with IPC, so a
    // pin press and an external caller land on the identical method.
    readonly property var commands: ({
        pin: { command: "setPinned" },
        dashboard: { command: "switchMode", value: "dashboard" },
        back: { command: "back" },
        close: { command: "close" }
    })

    readonly property var buttons: options.buttons || []
    readonly property real buttonSize: options.buttonSize || 14

    // Read off Nino rather than off the click, so a press and an IPC call
    // leave the glyph saying the same thing.
    readonly property bool pinned: theme.pinned || false

    // Lit means the state this button toggles is on, which today only pin
    // has. A press lights any of them, and outlasts nothing. A named function
    // for the reason press() is one: a check cannot read a colour back out of
    // a Repeater delegate.
    function glyphColor(id, pressed) {
        const lit = pressed || (id === "pin" && pinned);
        return lit ? (theme.accent || "#87af5f") : (theme.text || "#ffffff");
    }

    // An icon view declares no size: the row of buttons reports what it
    // comes to, which is the same number the old minWidth restated by hand.
    views: ({
        0: { delegate: buttonRow }
    })

    // What a button press sends. A named function rather than a body inside
    // the part's action, for the reason CardBody's scrollBy is one: a check
    // cannot call a handler. Returns the message so a check can read it even
    // when nothing is listening.
    function press(button, id) {
        if (button !== "left") return null;
        const message = commands[id];
        if (!message) return null;
        commandRequested(message);
        return message;
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
                        color: root.glyphColor(button.modelData, part.pressed)
                        font.family: root.theme.font || "sans-serif"
                        font.pixelSize: root.buttonSize
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 6
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        // Each button is its own part, so one lights up and
                        // moves without its neighbours. The style rides in
                        // the theme bundle, which is why a button several
                        // levels deep reaches it off the object it has.
                        ModulePart {
                            id: part
                            theme: root.theme
                            action: name => root.press(name, button.modelData)
                        }
                    }
                }
            }
        }
    }
}
