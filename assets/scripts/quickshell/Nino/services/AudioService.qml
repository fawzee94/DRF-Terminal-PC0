pragma Singleton

import Quickshell.Io
import "../foundation"

// Default sink volume and mute state, via PipeWire's wpctl.
ProcessService {
    serviceName: "AudioService"
    pollIntervalMs: Config.get("audioPollIntervalMs")
    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]

    // Writes get their own one-shot process: the inherited one is the
    // poller, and reusing it would mean a write and a read fighting over
    // the same slot. A write is answered by the next poll rather than
    // optimistically applied here, so what the slider shows is always what
    // the system actually reports.
    Process {
        id: writer
        // A drag produces far more requests than wpctl can service. Rather
        // than dropping the ones that arrive mid-write, the most recent is
        // held and sent when the current one finishes — so a drag always
        // settles on the value the hand stopped at, not on whichever
        // request happened to win the race.
        onRunningChanged: {
            if (running || root.pendingLevel === undefined) return;
            const level = root.pendingLevel;
            root.pendingLevel = undefined;
            root.setVolume(level);
        }
    }

    property var pendingLevel: undefined

    function run(args) {
        if (writer.running) return false;
        writer.command = args;
        writer.running = true;
        return true;
    }

    function setVolume(level) {
        const clamped = Math.max(0, Math.min(1, level));
        if (writer.running) {
            pendingLevel = clamped;
            return true;
        }
        return run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", clamped.toFixed(3)]);
    }

    function toggleMute() {
        return run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
    }

    // lore.md L37: "Volume: <float>", optionally suffixed " [MUTED]".
    function parse(text) {
        const match = /^Volume:\s*([\d.]+)\s*(\[MUTED\])?/.exec(text.trim());
        if (!match) throw new Error(`unparseable wpctl output: ${text}`);
        return { volume: parseFloat(match[1]), muted: !!match[2] };
    }
}
