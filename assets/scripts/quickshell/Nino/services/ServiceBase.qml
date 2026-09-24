import QtQuick

// The polling contract every service extends. A subclass writes only
// poll(); this builds continuous, ref-counted consumption on top of it and
// drops to fully idle at zero. See architecture.md "System: Service Base".
//
// One-shot consumption (queryOnce) is deliberately absent until Dashboard
// needs it — building it ahead of its only caller produced a contract that
// had to be widened once and a bug nothing could catch.
//
// Item rather than QtObject only because Item can hold a Timer as a direct
// child; nothing here is visual.
Item {
    id: root

    property string serviceName: "Service"

    // Set by the subclass from its own config.
    property int pollIntervalMs: 0

    property int refCount: 0
    property bool pollFailing: false

    // Callbacks waiting on one fresh reading. Its only caller is Dashboard
    // resolving which screen it opened on — a question that must not start
    // continuous polling nobody needs.
    property var pendingOnce: []

    Timer {
        id: pollTimer
        // Floored at 1: Config.get() answers undefined for a missing or
        // mistyped key, and a repeating 0ms timer would spin the event loop
        // spawning processes as fast as it can.
        interval: Math.max(1, root.pollIntervalMs)
        repeat: true
        onTriggered: root.runPoll()
    }

    function request() {
        refCount++;
        if (refCount === 1) {
            runPoll();
            pollTimer.start();
        }
    }

    function release() {
        if (refCount === 0) return;
        refCount--;
        if (refCount === 0) pollTimer.stop();
    }

    // One fresh reading, without touching the ref-count. Concrete services
    // are asynchronous, so this cannot return — the reading arrives later,
    // through deliverOnce.
    function queryOnce(callback) {
        pendingOnce.push(callback);
        runPoll();
    }

    // Drains whether the read succeeded or failed. Delivering `undefined` is
    // deliberate: a callback that is simply never called leaves its caller
    // unable to tell "still waiting" from "never coming", which is exactly
    // how the first, speculative version of this stranded callbacks during a
    // failure streak.
    function deliverOnce(reading) {
        if (pendingOnce.length === 0) return;
        const callbacks = pendingOnce;
        pendingOnce = [];
        for (const callback of callbacks) callback(reading);
    }

    // Only the first failure in a streak warns; recovery is silent.
    function runPoll() {
        try {
            const result = poll();
            pollFailing = false;
            return result;
        } catch (e) {
            if (!pollFailing) {
                console.warn(`[${root.serviceName}] poll failed: ${e.message}`);
                pollFailing = true;
            }
            return undefined;
        }
    }

    // Subclass contract.
    function poll() {
        throw new Error("poll() not implemented — subclass must override it");
    }
}
