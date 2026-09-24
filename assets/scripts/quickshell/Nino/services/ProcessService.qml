import Quickshell.Io

// Base for any service whose reading comes from running a command-line
// tool — which is all of them today. Owns the Process, the spawn-failure
// detection and the error latch, so a concrete service states only its two
// genuinely distinct facts: `command`, and a `parse(text)` turning one run's
// stdout into a reading.
//
// Process has no blocking exec, so poll() cannot wait for a fresh read. It
// returns the last parsed reading and starts the next run if one is not
// already in flight — at most one poll interval stale.
ServiceBase {
    id: root

    property alias command: proc.command
    property var lastReading

    // Persists until a genuine success clears it. Clearing on every throw
    // flaps the warn-once latch and re-warns on nearly every recurring
    // failure — see architecture.md "System: Service Base".
    property var lastError: null

    Process {
        id: proc

        // lore.md L34: a spawn failure emits only runningChanged(false),
        // never started or exited, so this latch is how the two are told
        // apart.
        property bool started: false

        onStarted: started = true
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) root.lastError = new Error(`${proc.command[0]} exited with code ${exitCode}`);
        }
        onRunningChanged: {
            if (running || started) return;
            root.lastError = new Error(`${proc.command[0]} failed to spawn (binary not found?)`);
            // Nothing will arrive on stdout, so anything waiting on a fresh
            // reading has to be released here or it waits forever.
            root.deliverOnce(undefined);
        }

        // lore.md L35: stdout finishes before onExited, so a parse of bad
        // output can land before the non-zero exit explaining it. The latch
        // set there still wins, on the next poll.
        stdout: StdioCollector {
            id: out
            onStreamFinished: root.absorb(out.text)
        }
    }

    function absorb(text) {
        try {
            root.lastReading = parse(text);
            root.lastError = null;
            root.deliverOnce(root.lastReading);
        } catch (e) {
            root.lastError = e;
            root.deliverOnce(undefined);
        }
    }

    function poll() {
        if (!proc.running) {
            proc.started = false;
            proc.running = true;
        }
        if (root.lastError) throw root.lastError;
        return root.lastReading;
    }

    // Subclass contract: one run's stdout in, one reading out. Throw to
    // reject output that cannot be read.
    function parse(text) {
        throw new Error("parse() not implemented — subclass must override it");
    }
}
