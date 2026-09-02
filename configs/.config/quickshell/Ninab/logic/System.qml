import QtQuick
import QtQml.Models
import Quickshell.Io

// System: the one place Nino and its modules touch the outside world.
// Cursor position, audio, network — every shell-out lives here behind
// plain properties/functions. Porting Ninab to a different compositor
// or audio/network stack means editing this file, not Nino.qml or any
// module.

Item {
    id: system

    // ---- tunables (fed from Config.qml via shell.qml) ----
    property real cursorPollIntervalMs: 95
    // WHAT: slower poll rate once the cursor's held still for a while,
    //   and how many consecutive unchanged reads count as "still".
    // WHY: the fast rate exists to track a moving cursor smoothly; once
    //   it's stationary there's nothing new to track, so polling that
    //   often is wasted subprocess spawns.
    property real cursorIdleIntervalMs: 400
    property int cursorIdleAfterTicks: 5
    property real audioPollIntervalMs: 2000
    property real networkPollIntervalMs: 2000
    property real pingIntervalMs: 5000
    property string pingHost: "1.1.1.1"
    property string audioSink: "@DEFAULT_AUDIO_SINK@"
    property string micSink: "@DEFAULT_AUDIO_SOURCE@"

    // WHAT: is Nino currently following the cursor (fed from shell.qml's
    //   root.following).
    // WHY: gates cursor polling entirely below — while "sitting"
    //   (following: false), Nino ignores cursor movement anyway (see
    //   Nino.qml's maybeTrackTarget), so there's nothing to poll for.
    property bool following: true

    // WHAT: which module's own card takeover is currently on screen —
    //   "" if none (see shell.qml's visibleCardModule for exactly what
    //   counts as "currently"). Gates the expensive/rarely-viewed polls
    //   below (wifi scan, per-app streams, ping) — see each poll's own
    //   comment for what's actually gated and why.
    // WHY: immediately kicks off a fetch for whichever module just
    //   became visible, rather than leaving it stale until the next
    //   regular poll tick (up to several seconds away) — opening a card
    //   should show fresh data right away, not a stale snapshot from
    //   whenever it last happened to poll.
    property string activeCardModule: ""
    onActiveCardModuleChanged: {
        if (activeCardModule === "network") {
            wifiListProc.running = true
            pingProc.running = true
            if (connectionType === "wifi") wifiSignalProc.running = true
        } else if (activeCardModule === "volume") {
            statusProc.running = true
        }
    }

    // ==================================================================
    // Cursor (Mango, via mmsg)
    // ==================================================================
    // WHAT: polls the compositor for global pointer position + monitor.
    // WHY: Wayland gives a click-through layer-shell surface no other
    //   way to know where the pointer is.
    // NOTE: `mmsg` has a `watch` (streaming) mode for several queries,
    //   but not cursor position — polling is the only option here.
    property real cursorX: 200
    property real cursorY: 200
    property string cursorMonitor: ""

    // WHAT: adaptive poll rate — cursorPollIntervalMs while moving,
    //   backs off to cursorIdleIntervalMs after cursorIdleAfterTicks
    //   consecutive unchanged reads, snaps back the instant it moves again.
    // WHY: the fast rate is for tracking motion smoothly; a stationary
    //   cursor has nothing new to report, so polling that often is just
    //   wasted subprocess spawns.
    property real currentCursorIntervalMs: cursorPollIntervalMs
    property int cursorStationaryTicks: 0

    // WHY: resuming from "sitting" should track crisply right away, not
    // pick up wherever the backoff happened to leave off before sitting.
    onFollowingChanged: {
        cursorStationaryTicks = 0
        currentCursorIntervalMs = cursorPollIntervalMs
    }

    Process {
        id: cursorProc
        command: ["mmsg", "get", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const pos = JSON.parse(this.text)
                    const moved = Math.abs(pos.x - system.cursorX) > 0.5 || Math.abs(pos.y - system.cursorY) > 0.5
                    system.cursorX = pos.x
                    system.cursorY = pos.y
                    if (pos.monitor) system.cursorMonitor = pos.monitor

                    if (moved) {
                        system.cursorStationaryTicks = 0
                        system.currentCursorIntervalMs = system.cursorPollIntervalMs
                    } else {
                        system.cursorStationaryTicks += 1
                        if (system.cursorStationaryTicks >= system.cursorIdleAfterTicks) {
                            system.currentCursorIntervalMs = system.cursorIdleIntervalMs
                        }
                    }
                } catch (e) {
                    // WHY: malformed/partial output — just skip this tick,
                    // next poll corrects it.
                }
            }
        }
    }
    // WHAT: only runs while following — see the `following` property above.
    // NOTE: triggeredOnStart so resuming from "sitting" (running flips
    //   false -> true) polls immediately instead of waiting out a full
    //   interval first.
    Timer {
        interval: system.currentCursorIntervalMs
        running: system.following
        repeat: true
        triggeredOnStart: true
        onTriggered: cursorProc.running = true
    }

    // ==================================================================
    // Audio (PipeWire, via wpctl)
    // ==================================================================
    // WHAT: default output (volume) + input (mic) level/mute, plus
    //   per-app stream volumes.
    // WHY: `wpctl` is what a PipeWire desktop ships by default (Project
    //   doc: "via wpctl or pamixer"). Swap the Process commands below to
    //   port to pamixer/pactl.
    // NOTE: optimistic-update-then-reconcile — volume/muted flip
    //   immediately on a user action, a poll corrects it if wrong. Avoids
    //   needing to know wpctl's exact exit semantics.
    property real volume: 0
    property bool muted: false
    property real micVolume: 0
    property bool micMuted: false

    // WHAT: id+name of every currently-playing app audio stream.
    // WHY: kept separate from appVolumes (below) on purpose — see AI note.
    // AI: do not merge this with appVolumes into one list-of-objects and
    //   use that as a Repeater model. A per-row volume drag calls
    //   setAppVolume() on every pointer-move tick; if that rebuilds a
    //   list that also carries the id/name, the Repeater sees a new
    //   array on every tick and destroys/recreates every delegate,
    //   killing the drag after the first move (real bug, already hit
    //   once). appStreamMeta only changes when apps start/stop; per-row
    //   UI reads live values via valueFor(id)/showMutedFor(id) instead.
    property var appStreamMeta: []   // [{id, name}, ...]
    property var appVolumes: ({})    // {id: {volume, muted}, ...}

    // WHAT: single dispatch point for "volume" / "mic" / any app stream id.
    // WHY: lets a module render one generic row component for all three
    //   kinds instead of duplicating UI per kind.
    function valueFor(id) {
        if (id === "mic") return micVolume
        if (id === "volume") return volume
        const v = appVolumes[id]
        return v ? v.volume : 0
    }
    function showMutedFor(id) {
        if (id === "mic") return micMuted || micVolume <= 0.001
        if (id === "volume") return muted || volume <= 0.001
        const v = appVolumes[id]
        return v ? (v.muted || v.volume <= 0.001) : false
    }
    function setValueFor(id, v) {
        if (id === "mic") setMicVolume(v)
        else if (id === "volume") setVolume(v)
        else setAppVolume(id, v)
    }
    function toggleMuteFor(id) {
        if (id === "mic") toggleMicMute()
        else if (id === "volume") toggleMute()
        else toggleAppMute(id)
    }

    function setVolume(v) {
        volume = Math.max(0, Math.min(1, v))
        setVolumeProc.command = ["wpctl", "set-volume", audioSink, volume.toFixed(2)]
        setVolumeProc.running = true
    }
    function toggleMute() {
        muted = !muted
        toggleMuteProc.running = true
    }
    function setMicVolume(v) {
        micVolume = Math.max(0, Math.min(1, v))
        setMicVolumeProc.command = ["wpctl", "set-volume", micSink, micVolume.toFixed(2)]
        setMicVolumeProc.running = true
    }
    function toggleMicMute() {
        micMuted = !micMuted
        toggleMicMuteProc.running = true
    }
    function setAppVolume(id, v) {
        const clamped = Math.max(0, Math.min(1, v))
        const prev = appVolumes[id] || { volume: 0, muted: false }
        appVolumes = Object.assign({}, appVolumes, { [id]: Object.assign({}, prev, { volume: clamped }) })
        appSetVolumeProc.command = ["wpctl", "set-volume", id, clamped.toFixed(2)]
        appSetVolumeProc.running = true
    }
    function toggleAppMute(id) {
        const prev = appVolumes[id] || { volume: 0, muted: false }
        appVolumes = Object.assign({}, appVolumes, { [id]: Object.assign({}, prev, { muted: !prev.muted }) })
        appToggleMuteProc.command = ["wpctl", "set-mute", id, "toggle"]
        appToggleMuteProc.running = true
    }

    // WHAT: volume/mic always refresh; the per-app stream list only
    //   refreshes while volume's own card is actually being viewed.
    // WHY: appStreamMeta/appVolumes only ever render inside volume.qml's
    //   Applications group (card mode) — nothing reads them otherwise,
    //   so polling `wpctl status` (a full status dump, heavier than a
    //   targeted get-volume) for a hidden module is wasted work.
    function refreshAudio() {
        getVolumeProc.running = true
        getMicProc.running = true
        if (activeCardModule === "volume") statusProc.running = true
    }

    Process {
        id: getVolumeProc
        command: ["wpctl", "get-volume", system.audioSink]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                const match = text.match(/Volume:\s*([\d.]+)/)
                if (match) system.volume = parseFloat(match[1])
                system.muted = text.indexOf("[MUTED]") !== -1
            }
        }
    }
    Process { id: setVolumeProc }
    Process {
        id: toggleMuteProc
        command: ["wpctl", "set-mute", system.audioSink, "toggle"]
    }

    Process {
        id: getMicProc
        command: ["wpctl", "get-volume", system.micSink]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                const match = text.match(/Volume:\s*([\d.]+)/)
                if (match) system.micVolume = parseFloat(match[1])
                system.micMuted = text.indexOf("[MUTED]") !== -1
            }
        }
    }
    Process { id: setMicVolumeProc }
    Process {
        id: toggleMicMuteProc
        command: ["wpctl", "set-mute", system.micSink, "toggle"]
    }

    // WHAT: `wpctl status`'s "Streams:" section -> [{id, name}, ...].
    // WHY: that's the only place per-app stream ids/names show up.
    // NOTE: tested against a real playing app (not just assumed) —
    //   `wpctl status` does NOT print a volume for stream entries the
    //   way it does for Sinks/Sources, even though the volume genuinely
    //   exists (`wpctl get-volume <id>` returns it fine). That's why
    //   volume is fetched separately per id (appVolumeInstantiator)
    //   instead of parsed from this text.
    // NOTE: each entry has indented port-link sub-lines underneath that
    //   would also match a bare "<id>. <name>" shape — filtered out by
    //   indentation depth against the section's first entry. The
    //   section ends at the first blank line (the real boundary,
    //   confirmed against real output), not "first unparseable line".
    function parseAppStreamMeta(text) {
        const lines = text.split("\n")
        const headerIndex = lines.findIndex(l => l.trim().endsWith("Streams:"))
        if (headerIndex === -1) return []
        const entryRe = /^(\s*)(\d+)\.\s+(.+?)\s*$/
        let topIndent = -1
        const result = []
        for (let i = headerIndex + 1; i < lines.length; i++) {
            const line = lines[i]
            if (line.trim() === "") break
            const m = line.match(entryRe)
            if (!m) continue
            const indent = m[1].length
            if (topIndent === -1) topIndent = indent
            if (indent !== topIndent) continue
            result.push({ id: m[2], name: m[3].trim() })
        }
        return result
    }

    Process {
        id: statusProc
        command: ["wpctl", "status"]
        stdout: StdioCollector {
            onStreamFinished: system.appStreamMeta = system.parseAppStreamMeta(this.text)
        }
    }
    Process { id: appSetVolumeProc }
    Process { id: appToggleMuteProc }

    // WHAT: one `wpctl get-volume` Process per known app stream id.
    // WHY: Instantiator rebuilds delegates whenever appStreamMeta
    //   changes (a new array from statusProc, every poll) — combined
    //   with `running: true` below, that alone re-fetches every app's
    //   volume every poll cycle, no separate refresh-loop needed.
    // AI: `running: true` is required here — a freshly-created Process
    //   does NOT auto-run (running defaults to false). Without this line
    //   the Process sits inert with no error/warning anywhere; only
    //   checking appVolumes directly (not the log) reveals it never ran.
    //   Cost a full instrumented test pass to catch once already.
    Instantiator {
        model: system.appStreamMeta.map(s => s.id)
        delegate: Process {
            id: appGetVolumeProc
            required property var modelData
            running: true
            command: ["wpctl", "get-volume", modelData]
            stdout: StdioCollector {
                onStreamFinished: {
                    const text = this.text.trim()
                    const match = text.match(/Volume:\s*([\d.]+)/)
                    if (!match) return
                    const entry = { volume: parseFloat(match[1]), muted: text.indexOf("[MUTED]") !== -1 }
                    system.appVolumes = Object.assign({}, system.appVolumes, { [appGetVolumeProc.modelData]: entry })
                }
            }
        }
    }

    Timer {
        interval: system.audioPollIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: system.refreshAudio()
    }

    // ==================================================================
    // Network (NetworkManager, via nmcli/ip; sysfs for rates; ping)
    // ==================================================================
    // WHAT: primary connection status/rate/ping + wifi scan/connect.
    // WHY: nmcli is what a NetworkManager desktop ships by default; ip
    //   route finds the interface that actually carries traffic (a
    //   machine can have several "connected" devices, only one routes).
    // NOTE: no wifi hardware on the machine this was built/tested on —
    //   the scan/connect/password path was only checked structurally
    //   (correct nmcli syntax, parsing against hand-written sample
    //   lines), not against a real scan or connect. Empty-list handling
    //   *is* live-verified (that's what this machine always returns).
    property string primaryIface: ""
    property string connectionType: "disconnected"   // "wifi" | "ethernet" | "disconnected"
    property string connectionName: ""
    property string ipAddress: ""
    property real wifiSignal: -1     // 0..100, -1 = n/a
    property real pingMs: -1         // -1 = unknown/unreachable

    property real rxRate: 0   // bytes/sec
    property real txRate: 0
    property real prevRxBytes: -1
    property real prevTxBytes: -1
    property string prevStatsIface: ""
    property real prevStatsTimeMs: 0

    property var availableNetworks: []   // [{ssid, signal, secured, inUse}, ...]

    // WHAT: undoes nmcli -t's ':'/'\' escaping while splitting a line.
    // WHY: a plain split(':') breaks if a value (an SSID, in principle)
    //   legitimately contains a colon.
    function splitTerse(line) {
        const parts = []
        let cur = ""
        for (let i = 0; i < line.length; i++) {
            const c = line[i]
            if (c === "\\" && i + 1 < line.length) {
                cur += line[i + 1]
                i++
            } else if (c === ":") {
                parts.push(cur)
                cur = ""
            } else {
                cur += c
            }
        }
        parts.push(cur)
        return parts
    }

    // WHAT: primary-connection status always refreshes (icon/widget mode
    //   need it); the wifi scan only refreshes while network's own card
    //   is actually being viewed.
    // WHY: availableNetworks only ever renders inside network.qml's
    //   Available Networks section (card mode) — a hidden module doesn't
    //   need a fresh scan every poll.
    function refreshNetwork() {
        routeProc.running = true
        if (activeCardModule === "network") wifiListProc.running = true
    }

    function disconnectPrimaryNetwork() {
        if (system.primaryIface === "") return
        disconnectProc.command = ["nmcli", "device", "disconnect", system.primaryIface]
        disconnectProc.running = true
    }
    function connectWifiOpen(ssid) {
        connectProc.command = ["nmcli", "device", "wifi", "connect", ssid]
        connectProc.running = true
    }
    function connectWifiSecured(ssid, password) {
        connectProc.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password]
        connectProc.running = true
    }

    Process {
        id: routeProc
        command: ["ip", "-4", "route", "show", "default"]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim()
                const match = text.match(/\bdev\s+(\S+)/)
                if (!match) {
                    system.primaryIface = ""
                    system.connectionType = "disconnected"
                    system.connectionName = ""
                    system.ipAddress = ""
                    system.wifiSignal = -1
                    return
                }
                system.primaryIface = match[1]
                deviceProc.running = true
                statsProc.running = true
            }
        }
    }

    Process {
        id: deviceProc
        command: ["nmcli", "-t", "-f", "GENERAL.STATE,GENERAL.CONNECTION,GENERAL.TYPE,IP4.ADDRESS", "device", "show", system.primaryIface]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                let type = "", conn = "", ip = ""
                for (const line of lines) {
                    const idx = line.indexOf(":")
                    if (idx === -1) continue
                    const key = line.slice(0, idx)
                    const value = line.slice(idx + 1)
                    if (key === "GENERAL.TYPE") type = value
                    else if (key === "GENERAL.CONNECTION") conn = value
                    else if (key.indexOf("IP4.ADDRESS") === 0 && ip === "") ip = value.split("/")[0]
                }
                system.connectionType = (type === "wifi") ? "wifi" : (type.length > 0 ? "ethernet" : "disconnected")
                system.connectionName = conn
                system.ipAddress = ip
                // WHAT/WHY: signal % only renders in network's card view
                // — same "don't fetch for a hidden module" reasoning as
                // the wifi scan above.
                if (system.connectionType === "wifi" && system.activeCardModule === "network") wifiSignalProc.running = true
                else if (system.connectionType !== "wifi") system.wifiSignal = -1
            }
        }
    }

    Process {
        id: wifiSignalProc
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                for (const line of lines) {
                    const parts = system.splitTerse(line)
                    if (parts[0] === "*" && parts.length > 1) {
                        system.wifiSignal = parseFloat(parts[1])
                        return
                    }
                }
            }
        }
    }

    // WHAT: rx/tx byte counters -> bytes/sec, via real elapsed time.
    // WHY: Date.now() delta, not an assumed-exact pollIntervalMs, so a
    //   late-firing Timer tick doesn't skew the rate.
    Process {
        id: statsProc
        command: ["cat", "/sys/class/net/" + system.primaryIface + "/statistics/rx_bytes", "/sys/class/net/" + system.primaryIface + "/statistics/tx_bytes"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                if (lines.length < 2) return
                const rx = parseFloat(lines[0])
                const tx = parseFloat(lines[1])
                const now = Date.now()
                const sameIface = system.prevStatsIface === system.primaryIface
                if (sameIface && system.prevRxBytes >= 0 && now > system.prevStatsTimeMs) {
                    const dt = (now - system.prevStatsTimeMs) / 1000
                    system.rxRate = Math.max(0, (rx - system.prevRxBytes) / dt)
                    system.txRate = Math.max(0, (tx - system.prevTxBytes) / dt)
                } else {
                    system.rxRate = 0
                    system.txRate = 0
                }
                system.prevRxBytes = rx
                system.prevTxBytes = tx
                system.prevStatsIface = system.primaryIface
                system.prevStatsTimeMs = now
            }
        }
    }

    Process {
        id: wifiListProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                const result = []
                for (const line of lines) {
                    if (line.trim() === "") continue
                    const parts = system.splitTerse(line)
                    if (parts.length < 4) continue
                    const ssid = parts[1]
                    if (ssid.length === 0) continue
                    result.push({
                        inUse: parts[0] === "*",
                        ssid: ssid,
                        signal: parseFloat(parts[2]) || 0,
                        secured: parts[3] !== "" && parts[3] !== "--"
                    })
                }
                system.availableNetworks = result
            }
        }
    }

    Process {
        id: pingProc
        command: ["ping", "-c", "1", "-W", "1", system.pingHost]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = this.text.match(/time=([\d.]+)/)
                system.pingMs = match ? parseFloat(match[1]) : -1
            }
        }
    }

    Process { id: disconnectProc }
    Process { id: connectProc }

    Timer {
        interval: system.networkPollIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: system.refreshNetwork()
    }
    // WHAT: ping on its own, slower timer; only while network's card is visible.
    // WHY: ping is a ~1s blocking call — doesn't need the same cadence
    //   as everything else, and shouldn't hold up those polls. pingMs
    //   only renders in network.qml's card view, so a hidden module
    //   doesn't need it refreshed either.
    Timer {
        interval: system.pingIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (system.activeCardModule === "network") pingProc.running = true
    }
}
