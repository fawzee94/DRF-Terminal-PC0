pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../foundation/Search.js" as Search

// What the launcher module cannot reach itself: the desktop entry list, and
// searching the filesystem. Not a ServiceBase — there is nothing to poll and
// no continuous consumer to ref-count, the same shape and the same reason as
// ClipboardService. It is a Service at all because only a Service may spawn a
// process.
Singleton {
    id: root

    // Only `.values` is reactive; the model itself is not. It fills in
    // entry by entry after startup rather than arriving whole (lore.md L53),
    // so this must stay a binding — a one-time read lands on an empty list.
    readonly property var apps: DesktopEntries.applications.values

    // Written by the module. An empty query means "search for nothing", not
    // "search for everything": `*``*` would walk the entire root.
    property string query: ""
    property string searchRoot: Quickshell.env("HOME")
    property int depth: 4
    property int limit: 8

    // Owned by this service; the module reads it. The rows of the last run
    // whose query still matched when it finished.
    property var files: []

    onQueryChanged: {
        if (!query) {
            files = [];
            debounce.stop();
            return;
        }
        debounce.restart();
    }

    // Apps filter in memory on every keystroke; only the process needs
    // holding back, and a run already in flight is left to finish and be
    // discarded rather than killed.
    Timer {
        id: debounce
        interval: 150
        onTriggered: {
            if (search.running || !root.query) return;
            search.startedFor = root.query;
            search.command = Search.findCommand(root.searchRoot, root.depth, root.query);
            search.running = true;
        }
    }

    Process {
        id: search

        // Which query this run was started for. A launcher must never show
        // results for a string already typed past, and find answers slowly
        // enough on a cold cache for that to happen.
        property string startedFor: ""

        // lore.md L35: stdout finishes before onExited, so this is where a
        // reading lands. A non-zero exit means find hit an unreadable
        // directory, which is not a reason to drop what it did print.
        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                if (search.startedFor === root.query) root.files = Search.pathRows(out.text, root.limit);
                // The query moved on while this ran, so the answer is stale
                // and the current one was never started.
                else if (root.query) debounce.restart();
            }
        }
    }

    // Both report success as soon as the request is accepted, never "busy":
    // a caller reading false bubbles the action upward as a command, and with
    // one Body per screen that becomes N spurious commands (lore.md L9).
    function launch(entry) {
        if (entry) entry.execute();
        return true;
    }

    function open(path) {
        if (opener.running) return true;
        opener.command = ["xdg-open", String(path)];
        opener.running = true;
        return true;
    }

    // Its own process: the search one is a reader, and sharing a slot makes
    // a read and a write fight over it (AudioService's reason).
    Process { id: opener }
}
