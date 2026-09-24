pragma Singleton

import Quickshell
import Quickshell.Io

// Writing the system clipboard. Not a ServiceBase: there is nothing to poll
// and no continuous consumer to ref-count — this is a one-shot write.
//
// Quickshell's own Quickshell.clipboardText is not usable here. It reads
// back empty even when the system selection holds a known sentinel, so it
// neither reads nor writes the real clipboard on this compositor
// (lore.md L41). wl-copy is the working path, and only a Service may spawn
// a process — which is why a module cannot just do this itself.
Singleton {
    id: root

    Process { id: writer }

    // Always reports success: it has accepted the request. Returning false
    // for "busy" was wrong — the caller reads false as "I did not handle
    // this" and bubbles the action onward as a command, which for a Body
    // instantiated once per screen meant two of three copies turned into
    // spurious upward commands (lore.md L9).
    //
    // A write already in flight is simply replaced. Every caller is asking
    // for the same selection, so the last request is the right one.
    function copy(text) {
        if (writer.running) return true;
        // wl-copy forks by default; --trim-newline keeps a copied value from
        // gaining a line ending it never had.
        writer.command = ["wl-copy", "--trim-newline", String(text)];
        writer.running = true;
        return true;
    }
}
