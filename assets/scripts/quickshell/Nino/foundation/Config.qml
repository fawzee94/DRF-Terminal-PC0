pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "ConfigParser.js" as ConfigParser
import "SchemaValidator.js" as SchemaValidator

// The live-reloading config tree. Knows nothing about pills or modules —
// that lives entirely in config.schema.json. Why `data` is assigned rather
// than bound, why `configText` is its own property, and why parsing is
// wrapped rather than left to the binding: architecture.md "Config Engine >
// Implementation notes".
Singleton {
    id: root

    FileView {
        id: schemaFile
        path: Quickshell.shellPath("config.schema.json")
        preload: true
        blockLoading: true
    }

    FileView {
        id: configFile
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        blockLoading: true
        // A watch event is one of the two ways a re-read is asked for; the
        // reloadConfig command is the other, and both land on the same
        // function so they cannot drift.
        onFileChanged: root.reload()
    }

    // A split file is read once, when config.json is parsed. Only
    // config.json itself watches for changes, so editing a split file needs
    // a reloadConfig or a touch of config.json — splitting is for organising
    // a mostly-stable structure, not for tuning live.
    Component {
        id: splitFile
        FileView { blockLoading: true }
    }

    // A re-read was asked for — by a watch event or by the reloadConfig
    // command. Not "the tree changed": `configFile.reload()` is asynchronous
    // (`L33`), so at the moment this fires the new text has not arrived and
    // whether it will even parse is unknowable here. Emitting it anyway is
    // the honest reading, and a config that fails to parse says so in the
    // log. It is deliberately not emitted on the first load, which is why it
    // lives here rather than at the bottom of updateData().
    signal reloaded()

    // The whole re-read, named so a caller can ask for one without having to
    // touch the file to fake a watch event.
    //
    // configFile.reload() because watchChanges alone does not refresh text()
    // (lore.md L33), and updateData() because the tree may need rebuilding
    // even when this file's own text is unchanged — re-reading config.json is
    // how an edited split file is picked up, and that only works if the
    // re-read re-runs validation rather than a text change doing it.
    function reload() {
        configFile.reload();
        updateData();
        reloaded();
    }

    readonly property var schema: ConfigParser.parseJson(schemaFile.text())

    readonly property string configText: configFile.text()   // lore.md L32
    onConfigTextChanged: updateData()

    property var data: ({})

    function updateData() {
        let parsed;
        try {
            parsed = ConfigParser.parseJson(configText);
        } catch (e) {
            console.warn("[Config] config.json is not valid JSON — keeping previous config: " + e.message);
            return;
        }
        data = SchemaValidator.validate(schema, parsed, "",
                                        { schema: schema, data: ({}), loadFile: loadFile });
    }

    // Resolves a bare string found where an object or list was expected.
    // Returns undefined on any failure, which leaves the node at its own
    // empty default rather than taking the whole tree down with it.
    function loadFile(relativePath, path) {
        if (relativePath.indexOf("..") !== -1) {
            console.warn(`[Config] refusing "${relativePath}" at ${path}: a split file must stay inside the shell directory`);
            return undefined;
        }
        const view = splitFile.createObject(root, { path: Quickshell.shellPath(relativePath) });
        try {
            return ConfigParser.parseJson(view.text());
        } catch (e) {
            console.warn(`[Config] could not read "${relativePath}" at ${path}: ${e.message}`);
            return undefined;
        } finally {
            view.destroy();
        }
    }

    function get(path) {
        return path.split(".").reduce((value, key) => {
            return value && typeof value === "object" ? value[key] : undefined;
        }, data);
    }

    function validate(schemaNode, blob, path) {
        return SchemaValidator.validate(schemaNode, blob, path);
    }

    // Guards any name used to build a dynamic file path — module type, mode
    // name, animation set. See architecture.md "Config Engine > Security".
    function sanitizeIdentifier(name) {
        if (typeof name === "string" && /^[A-Za-z0-9_]+$/.test(name)) return name;
        console.warn(`[Config] invalid identifier ${JSON.stringify(name)}, using ""`);
        return "";
    }
}
