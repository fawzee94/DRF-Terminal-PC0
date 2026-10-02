import QtQuick
import Quickshell
import Quickshell.Widgets
import "../presentation"
import "../services"
import "../foundation/Search.js" as Search

// Applications, and optionally files and folders, searched by name. View 0 is
// the icon; view 1 is the takeover — a search field over a list of results.
// The first module here that takes keyboard input, which is why the window it
// lands in has to grant focus at all (lore.md L12, L54).
ModuleBase {
    id: root

    defaultView: 0
    viewNames: ({ icon: 0, takeover: 1 })

    // Every result row acts on a left click. Without the claim the host hands
    // that same click to the mode's background config as well.
    claimedButtons: ["left"]

    optionsSchema: ({
        type: "object",
        fields: {
            view: { type: "string", default: "" },
            icon: { type: "string", default: "󰀻" },
            // The toggle's state when the takeover opens, not a lock on it.
            searchFiles: { type: "bool", default: false },
            // Empty means $HOME. A bounded root and depth are what keep a
            // search per keystroke affordable without an index.
            searchRoot: { type: "string", default: "" },
            // Drawn when a row has no themed icon of its own: files and
            // folders never do, and an application may not either.
            glyphs: {
                type: "object",
                fields: {
                    folder: { type: "string", default: "󰉋" },
                    file: { type: "string", default: "" },
                    app: { type: "string", default: "󰣆" }
                }
            },
            searchDepth: { type: "number", default: 4, min: 1 },
            maxResults: { type: "number", default: 8, min: 1 },
            clicks: { type: "opaque" }
        }
    })

    // Injected rather than named inline, so a check can drive the rows and
    // what one does without a desktop or a filesystem under it — the reason
    // Pose takes its cursor the same way.
    property var service: LauncherService

    property string filter: ""
    property bool includeFiles: options.searchFiles || false

    // What the arrows moved to, which the rows below may have since
    // outgrown — narrowing the filter shortens the list under it.
    property int selected: 0
    readonly property int selectedRow: Math.min(selected, Math.max(0, rows.length - 1))

    readonly property int cap: options.maxResults || 8

    // One row shape whichever half it came from, so the delegate does not
    // have to ask. With files included, apps take at most half the room:
    // filling the cap with apps first would leave a common query showing no
    // files at all, and the toggle looking broken.
    readonly property var rows: {
        const glyphs = options.glyphs || ({});
        const appCap = includeFiles ? Math.ceil(cap / 2) : cap;
        const apps = Search.matchApps(service.apps, filter, appCap).map(entry => ({
            name: entry.name, icon: entry.icon || "", glyph: glyphs.app, entry: entry, path: ""
        }));
        if (!includeFiles) return apps;
        // A path has no icon of its own to look up, so these are glyphs
        // outright rather than a fallback behind a themed lookup.
        const files = (service.files || []).map(file => ({
            name: file.name, icon: "", glyph: file.isDir ? glyphs.folder : glyphs.file,
            entry: null, path: file.path
        }));
        return apps.concat(files.slice(0, cap - apps.length));
    }

    onFilterChanged: { selected = 0; syncSearch(); }
    onIncludeFilesChanged: { selected = 0; syncSearch(); }

    // The service searches for one string at a time. It is a singleton and
    // this module exists once per screen, but only the copy holding the
    // keyboard can change the filter (lore.md L54).
    function syncSearch() {
        if (options.searchRoot) service.searchRoot = options.searchRoot;
        service.depth = options.searchDepth || 4;
        service.limit = cap;
        service.query = includeFiles ? filter : "";
    }

    // Named functions rather than bodies inside the key handlers, for the
    // reason ContextualBody's scrollBy is one: a check cannot call a handler.
    function step(delta) {
        selected = Search.stepIndex(selectedRow, rows.length, delta);
    }

    // The check form, twice: passing a fallback still asks the loader for an
    // icon that may not exist either, and a miss there draws a missing-texture
    // placeholder and warns. An empty source simply draws nothing.
    function iconFor(name) {
        return Quickshell.iconPath(name, true)
            || Quickshell.iconPath("application-x-executable", true) || "";
    }

    function activate(index) {
        const row = rows[index];
        if (!row) return false;
        if (row.entry) service.launch(row.entry);
        else service.open(row.path);
        commandRequested({ command: "back" });
        return true;
    }

    views: ({
        0: { delegate: iconView },
        1: { minHeight: 140, maxHeight: 520, delegate: takeoverView }
    })

    Component {
        id: iconView

        Text {
            text: root.options.icon
            color: root.theme.text || "#ffffff"
            font.family: root.theme.font || "sans-serif"
            font.bold: root.theme.bold || false
            font.pixelSize: root.iconSizing
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            ModulePart { theme: root.theme }
        }
    }

    Component {
        id: takeoverView

        Item {
            id: takeover

            // Reports what the field and the rows come to, never derived from
            // its own width: a row's height is set by the font and a long name
            // elides, so widening this changes nothing vertical (lore.md L49).
            implicitWidth: takeover.baseSize * 16
            implicitHeight: results.y + results.height

            readonly property real baseSize: root.theme.fontSize || 12
            readonly property color accent: root.theme.accent || "#87af5f"

            // The delegate is built only after Body's content swap finishes,
            // so this is already the right moment to ask. Two asks, because
            // they are different things: the window has to hold the
            // compositor's keyboard focus at all, and the field has to be
            // what Qt delivers it to. Nothing releases the first — Pose drops
            // the request whenever this can have left the screen.
            Component.onCompleted: {
                root.commandRequested({ command: "requestKeyboard", value: true });
                field.forceActiveFocus();
            }

            Rectangle {
                id: anchored
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: takeover.baseSize * 2.4
                radius: root.theme.radius || 16
                // A tint of the accent rather than a theme key of its own, so
                // it stays an input field whatever the mode's colours are.
                color: Qt.rgba(takeover.accent.r, takeover.accent.g, takeover.accent.b, 0.15)

                TextInput {
                    id: field
                    anchors {
                        left: parent.left; leftMargin: anchored.radius * 0.6
                        right: toggle.left; rightMargin: 6
                        verticalCenter: parent.verticalCenter
                    }
                    color: root.theme.text || "#ffffff"
                    font.family: root.theme.font || "sans-serif"
                    font.pixelSize: takeover.baseSize
                    clip: true
                    onTextChanged: root.filter = text

                    // Left/Right/Home/End are left to the field itself; these
                    // four are the ones a list needs back.
                    Keys.onEscapePressed: root.commandRequested({ command: "back" })
                    Keys.onUpPressed: root.step(-1)
                    Keys.onDownPressed: root.step(1)
                    Keys.onReturnPressed: root.activate(root.selectedRow)
                    Keys.onEnterPressed: root.activate(root.selectedRow)
                }

                Text {
                    id: toggle
                    anchors {
                        right: parent.right; rightMargin: anchored.radius * 0.6
                        verticalCenter: parent.verticalCenter
                    }
                    text: "󰥩"
                    color: root.includeFiles ? takeover.accent : (root.theme.text || "#ffffff")
                    font.family: root.theme.font || "sans-serif"
                    font.pixelSize: takeover.baseSize * 1.2

                    ModulePart {
                        theme: root.theme
                        action: name => { if (name === "left") root.includeFiles = !root.includeFiles; }
                    }
                }
            }

            Column {
                id: results
                anchors {
                    top: anchored.bottom; topMargin: 8
                    left: parent.left; right: parent.right
                }
                spacing: 2

                Repeater {
                    model: root.rows

                    Rectangle {
                        id: row
                        required property var modelData
                        required property int index

                        width: results.width
                        height: takeover.baseSize * 2
                        radius: (root.theme.radius || 16) / 2
                        color: index === root.selectedRow ? takeover.accent : "transparent"

                        Item {
                            id: rowIcon
                            anchors {
                                left: parent.left; leftMargin: 6
                                verticalCenter: parent.verticalCenter
                            }
                            width: takeover.baseSize * 1.4
                            height: width

                            readonly property string themed: row.modelData.icon
                                ? root.iconFor(row.modelData.icon) : ""

                            IconImage {
                                anchors.fill: parent
                                visible: rowIcon.themed !== ""
                                source: rowIcon.themed
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: rowIcon.themed === ""
                                text: row.modelData.glyph || ""
                                color: row.index === root.selectedRow
                                    ? (root.theme.background || "#282828")
                                    : (root.theme.text || "#ffffff")
                                font.family: root.theme.font || "sans-serif"
                                font.pixelSize: takeover.baseSize * 1.2
                            }
                        }

                        Text {
                            anchors {
                                left: rowIcon.right; leftMargin: 6
                                right: parent.right; rightMargin: 6
                                verticalCenter: parent.verticalCenter
                            }
                            text: row.modelData.name
                            elide: Text.ElideRight
                            color: row.index === root.selectedRow ? (root.theme.background || "#282828")
                                                                  : (root.theme.text || "#ffffff")
                            font.family: root.theme.font || "sans-serif"
                            font.pixelSize: takeover.baseSize
                        }

                        ModulePart {
                            theme: root.theme
                            action: name => { if (name === "left") root.activate(row.index); }
                        }
                    }
                }
            }
        }
    }
}
