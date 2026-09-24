pragma Singleton

import "../foundation"

// Global cursor position. Polling is not a shortcut here: a layer-shell
// surface is told nothing about the cursor (lore.md L10) and mango's IPC
// has no watch for it (L27).
ProcessService {
    serviceName: "CursorService"
    pollIntervalMs: Config.get("cursorPollIntervalMs")
    command: ["mmsg", "get", "cursorpos"]

    // lore.md L36: {"x":<float>,"y":<float>,"monitor":"<name>"}
    function parse(text) {
        const reading = JSON.parse(text);
        return { x: reading.x, y: reading.y, monitor: reading.monitor };
    }
}
