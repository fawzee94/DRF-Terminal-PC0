import QtQuick
import Quickshell
import "../foundation"
import "../services"

// One per Nino, not per screen. Owns which mode is active and where this
// Nino's rectangle sits in global coordinates. Position is a native
// SmoothedAnimation retargeted toward a point Geometry computes, gated by
// the deadzone — there is no simulation.
//
// See architecture.md "System: Pose" for why any of it is shaped this way.
QtObject {
    id: root

    // This instance's own config slice, injected by shell.qml.
    property var instance: ({})

    // Injected, so a check can drive Pose against a synthetic cursor and
    // synthetic monitors.
    property var cursorSource: CursorService
    property var screens: Quickshell.screens

    property string activeMode: ""
    property string lastActiveMode: ""

    property var takeoverEntry: null

    // Cleared by any change that can take the asking module off the screen:
    // a request must not outlive what made it.
    property bool keyboardWanted: false
    onActiveModeChanged: keyboardWanted = false
    onTakeoverEntryChanged: if (!takeoverEntry) keyboardWanted = false

    function requestKeyboard(wanted) {
        keyboardWanted = !!wanted;
    }

    readonly property var mode: {
        const block = (instance && instance[activeMode]) || ({});
        if (activeMode !== "contextual" || !takeoverEntry) return block;
        return Object.assign({}, block, {
            modules: [{ id: "takeover", module: takeoverEntry.module }],
            moduleOptions: ({ takeover: takeoverEntry.options })
        });
    }

    // A perch is a mode Nino rests in rather than one it is summoned into.
    // Derived, not listed, so no name has to be kept in step.
    property string lastPerchMode: ""
    readonly property var perch: (instance && lastPerchMode) ? instance[lastPerchMode] : null

    function isPerch(name) {
        const block = (instance && instance[name]) || null;
        if (!block) return false;
        return (block.positioning || "cursor") !== "inherit"
            && (block.sizing || "fixed") !== "screen";
    }

    // Every read of the active mode's config goes through this. `mode` is a
    // var binding, and a var binding reads undefined until it first
    // evaluates (L40) — which several bindings here beat during
    // construction. Nothing dereferences `mode` blind.
    function modeField(key, fallback) {
        const active = mode;
        return (active && active[key] !== undefined) ? active[key] : fallback;
    }

    function resolvePositioning(declared) {
        if (declared !== "inherit") return declared;
        return (perch && perch.positioning === "anchored") ? "anchored" : "cursor";
    }

    readonly property string positioning: resolvePositioning(modeField("positioning", "cursor"))

    // The same question asked of a mode by name rather than of the active
    // one. A mode that is not declared follows nothing.
    function followsCursor(name) {
        const block = (instance && instance[name]) || null;
        return !!block && resolvePositioning(block.positioning || "cursor") === "cursor";
    }

    // A mode that inherits its positioning inherits the whole anchor with
    // it — edge, alignment and screen.
    readonly property var anchorSource:
        (modeField("positioning", "cursor") === "inherit" && perch) ? perch : mode

    readonly property bool borrowsAnchor:
        modeField("positioning", "cursor") === "inherit" && !!perch

    // FullScreen locks the screen it opened on, so it cannot migrate if the
    // cursor wanders afterwards. Everything else resolves live.
    property var lockedScreen: null
    readonly property var activeScreen: lockedScreen || anchorScreen()

    // The global rect. w/h rather than width/height because QQuickItem's are
    // FINAL and this is deliberately not an Item (L29).
    property real x: 0
    property real y: 0
    readonly property bool fillsScreen: modeField("sizing", "fixed") === "screen"

    // `width` is a mode's length along its edge and `height` its thickness.
    // Taken from this mode's own edge, never a borrowed one.
    readonly property bool verticalEdge: {
        const edge = modeField("edge", "top");
        return edge === "left" || edge === "right";
    }

    readonly property var fullSize: Geometry.sizeOnEdge(modeField("edge", "top"),
                                                        measure("width"), measure("height"))
    // 0 on an axis means "do not shrink on this one" — a mode that inherits
    // a key it does not want needs a value that declines, not an absence.
    function collapsedAxis(key, full) {
        const declared = modeField(key, 0);
        return declared > 0 ? declared : full;
    }

    readonly property var collapsedSize: Geometry.sizeOnEdge(modeField("edge", "top"),
        collapsedAxis("collapsedWidth", fullSize.width),
        collapsedAxis("collapsedHeight", fullSize.height))

    readonly property real fullWidth: fillsScreen
        ? (activeScreen ? activeScreen.width : 0) : fullSize.width
    readonly property real fullHeight: fillsScreen
        ? (activeScreen ? activeScreen.height : 0) : fullSize.height

    // An opt-in capability: a revealDistance above zero turns it on, and 0
    // is how a mode that inherits the key still says no.
    readonly property bool revealByProximity: modeField("revealDistance", 0) > 0

    // What revealDistance is measured against: the rect a cursor mode draws,
    // an anchored mode's anchor rect. Reading w/h here is safe only because
    // `revealed` is held rather than bound.
    readonly property var fullRect: {
        const screen = activeScreen;
        if (!screen || !mode) return null;
        if (positioning === "cursor") {
            return acceptedTarget ? { x: x, y: y, width: w, height: h } : null;
        }
        const corner = anchorCorner(screen, { width: fullWidth, height: fullHeight });
        return { x: corner.x, y: corner.y, width: fullWidth, height: fullHeight };
    }

    // pinPreventsCollapse: the capability lives wherever collapse does, and
    // needs no config key of its own.
    property bool pinned: false

    // Drag writes position straight in, bypassing the target computation for
    // the gesture's duration.
    property bool dragging: false

    // The screen whose window may hold the keyboard, which is not always the
    // one Nino is over: changing a surface's keyboard focus costs it the
    // pointer grab (L56), so following the cursor here would end every drag
    // that crosses a monitor.
    property var dragScreen: null
    readonly property var keyboardScreen: dragging ? dragScreen : activeScreen

    function beginDrag() {
        dragScreen = activeScreen;
        dragging = true;
        delayTimer.stop();
    }

    function dragBy(dx, dy) {
        if (!dragging) return;
        root.x += dx;
        root.y += dy;
    }

    // Written from the animations' own signal, never bound to their
    // `running`: bound it closes a loop, and a detected loop stops being
    // evaluated, which leaves `motion` stale.
    property bool inTransit: false

    function syncMotion() {
        inTransit = followX.running || followY.running;
    }
    readonly property string motion: dragging ? "dragging"
                                   : inTransit ? "inTransit" : "stationary"

    function endDrag() {
        // Recorded *before* the flag clears: clearing it settles the motion,
        // and a settled resize repositions from acceptedTarget.
        acceptedTarget = centre();
        dragging = false;
    }

    // Whether the cursor is near enough *right now*. Read live only while
    // Nino is still — see `revealed`.
    readonly property bool nearEnough: {
        if (!revealByProximity || pinned) return true;
        if (!cursor || !fullRect) return false;
        return Geometry.distanceToRect(cursor, fullRect) <= modeField("revealDistance", 0);
    }

    // A plain property, not a binding: the point is that it can decline to
    // follow `nearEnough`.
    property bool revealed: true

    function syncReveal() {
        if (motion === "inTransit") revealed = false;
        else if (motion === "stationary") revealed = nearEnough;
    }

    // Deferred a pass, so this answers "did that cursor move start a leg?"
    // rather than racing it.
    onNearEnoughChanged: Qt.callLater(syncReveal)
    onMotionChanged: syncReveal();

    readonly property real w: revealed ? fullWidth : collapsedSize.width
    readonly property real h: revealed ? fullHeight : collapsedSize.height

    // An anchored mode needs no cursor — unless it collapses by proximity,
    // which is entirely a question about where the cursor is.
    readonly property bool needsCursor:
        positioning !== "anchored" || revealByProximity || collapseDistance > 0

    // Thousands of px/s, so config reads 6 rather than 6000.
    readonly property real speed: modeField("speed", 0) * 1000

    // How long the velocity spends climbing before it levels out and cruises.
    readonly property real easeMs: modeField("easeMs", 0)

    // The shortest a move may take.
    readonly property real minMoveMs: modeField("minMoveMs", 0)

    // Each axis is given the velocity that covers its own share of the leg
    // in the same time, so they finish together and the resultant is `speed`
    // rather than 1.41x it on a diagonal.
    property real legVelocityX: 0
    property real legVelocityY: 0

    // Parks Nino where it stands. Belongs to the perch, and survives
    // everything summoned from it.
    property bool following: true

    // Following is following the *cursor*, so an anchored mode is never
    // parked — gating its retarget would leave it unable to place itself.
    readonly property bool parked: !following && positioning === "cursor"

    // Opt-in like revealByProximity: a mode leaves for its perch once the
    // cursor is this far from its edge. Pinning holds it open.
    readonly property real collapseDistance: modeField("collapseDistance", 0)

    function collapseWhenAbandoned() {
        if (collapseDistance <= 0 || pinned || dragging) return;
        if (!lastPerchMode || !instance || !instance[lastPerchMode]) return;
        if (!acceptedTarget || gapAtTarget() <= collapseDistance) return;
        collapse();
    }

    // Measured to where the mode is *going*: the drawn rect reads as
    // abandoned and collapses a mode the instant it opens.
    function gapAtTarget() {
        if (!cursor || !acceptedTarget) return 0;
        return Geometry.distanceToRect(cursor, {
            x: acceptedTarget.x - w / 2,
            y: acceptedTarget.y - h / 2,
            width: w, height: h
        });
    }

    readonly property real deadzone: modeField("deadzone", 0)

    // How long to wait, once the deadzone gate has opened, before setting
    // off. The target is recomputed when the wait ends, not captured.
    readonly property real delayMs: modeField("delayMs", 0)

    readonly property Timer delayTimer: Timer {
        interval: root.delayMs
        onTriggered: root.acceptCurrentTarget()
    }

    // The centre point the deadzone gate last accepted, not the live centre.
    property var acceptedTarget: null
    property bool holdingCursor: false

    // Where the cursor was when this mode opened, fixed once. The standing
    // reading is used immediately, then replaced by a fresh one — the mode
    // being left may have held no cursor subscription at all.
    property var summonPoint: null

    function captureSummonPoint() {
        summonPoint = cursor || null;
        cursorSource.queryOnce(reading => { if (reading) root.summonPoint = reading; });
    }

    readonly property var cursor: cursorSource.lastReading

    onCursorChanged: {
        retarget();
        collapseWhenAbandoned();
    }

    // Lands rather than flies, which is where the motion loop is cut. An
    // anchored mode's centre moves with its size, so it needs a fresh target
    // too; a cursor mode is excluded, where re-deriving is the flicker.
    function resettleAfterResize() {
        if (positioning === "anchored") {
            const target = anchoredTarget();
            if (target) acceptedTarget = target;
        }
        applyPosition(true);
    }

    onWChanged: if (!inTransit) resettleAfterResize()
    onHChanged: if (!inTransit) resettleAfterResize()

    // The anchor screen can arrive after the first target was computed —
    // FullScreen's lock is asynchronous.
    onActiveScreenChanged: retarget()

    // Keyed to `mode`, not `activeMode`, and deferred: the bindings derived
    // from `mode` have not re-evaluated while a handler on it runs (L46).
    onModeChanged: Qt.callLater(enterMode)
    Component.onCompleted: enterMode()

    // Whether position animates at all. Named so a check can read it — a
    // Behavior's `enabled` is not reachable from outside.
    readonly property bool glides: (speed > 0 || minMoveMs > 0) && !dragging

    Behavior on x {
        enabled: root.glides && !root.repositioning
        SmoothedAnimation {
            id: followX
            velocity: root.legVelocityX
            // -1 is Qt's "ease across the whole move"; a positive easeMs
            // levels the velocity out after that long and cruises the rest.
            maximumEasingTime: root.easeMs > 0 ? root.easeMs : -1
            onRunningChanged: root.syncMotion()
        }
    }
    Behavior on y {
        enabled: root.glides && !root.repositioning
        SmoothedAnimation {
            id: followY
            velocity: root.legVelocityY
            maximumEasingTime: root.easeMs > 0 ? root.easeMs : -1
            onRunningChanged: root.syncMotion()
        }
    }

    function enterMode() {
        delayTimer.stop();
        acceptedTarget = startingTarget();
        summonPoint = null;
        lockedScreen = null;
        syncCursorSubscription();
        if (borrowsAnchor) captureSummonPoint();
        if (fillsScreen) lockScreen();
        retarget();
        // Runs through Qt.callLater (L46), so this reads settled bindings —
        // a mode that opens already still makes no move to wait for.
        revealed = nearEnough;
    }

    // What a mode starts out heading for. Null means "work it out from
    // scratch", which is right for a mode that places itself.
    function startingTarget() {
        // Parked, the target stops moving — it does not stop existing.
        if (parked) return centre();
        // Between two cursor-relative modes a switch is a change of shape,
        // not a move: re-deriving slides the centre along the cursor ray.
        if (positioning === "cursor" && followsCursor(lastActiveMode)) return centre();
        return null;
    }

    // A command's name is the name of the method that carries it out, so a
    // bubbled request and an IPC call reach the identical function.
    function handleCommand(message) {
        if (!message || typeof message.command !== "string") return;
        const handler = root[message.command];
        if (typeof handler !== "function") {
            console.warn(`[Pose] no handler for command "${message.command}"`);
            return;
        }
        handler(message.value);
    }

    // Returns to whatever this instance rests in.
    function close() {
        switchMode((instance && instance.restingMode) || "leashed");
    }

    // The instance's own list, or every mode it declares — found by looking
    // for a contentShape rather than by a hardcoded list of names.
    readonly property var cycleOrder: {
        const listed = (instance && instance.cycleModes) || [];
        if (listed.length > 0) {
            // Warned about rather than skipped in silence: a name this
            // instance does not declare is a typo every time.
            for (const name of listed) {
                if (instance && !instance[name]) {
                    console.warn(`[Pose] cycleModes lists "${name}", which instance `
                        + `"${instance.id}" does not declare — skipping it`);
                }
            }
            return listed;
        }
        const found = [];
        for (const key of Object.keys(instance || ({}))) {
            const block = instance[key];
            if (block && typeof block === "object" && block.contentShape !== undefined) {
                found.push(key);
            }
        }
        return found;
    }

    // Skips any mode the instance does not declare, so a cycle list naming
    // an absent one cannot stall on it.
    function cycleModes() {
        const order = cycleOrder;
        if (order.length === 0) return;
        const at = order.indexOf(activeMode);
        for (let step = 1; step <= order.length; step++) {
            const candidate = order[(at + step) % order.length];
            if (instance && instance[candidate]) {
                switchMode(candidate);
                return;
            }
        }
    }

    function togglePin() {
        setPinned();
    }

    function toggleFollow() {
        following = !following;
    }

    // Back to the perch. A Nino that has not rested anywhere yet has no
    // perch to return to, so close() answers.
    function collapse() {
        if (lastPerchMode && instance && instance[lastPerchMode]) switchMode(lastPerchMode);
        else close();
    }

    // Back to whatever was active before this mode. Not close(), which
    // always goes to restingMode.
    function back() {
        // A takeover summoned from the contextual never changed the mode, so
        // the step back is out of the takeover. Only back peels.
        if (takeoverEntry && takeoverEntry.from === activeMode) {
            takeoverEntry = null;
            return;
        }
        if (lastActiveMode && instance && instance[lastActiveMode]) switchMode(lastActiveMode);
        else close();
    }

    // Free or fixed bearing, for this Nino rather than for one mode.
    // Undefined until toggled, which keeps each mode's defaultAngle meaning
    // something until then.
    property var angleOverride: undefined

    readonly property bool bearingIsFree: angleOverride === undefined
        ? modeField("defaultAngle", "free") === "free"
        : angleOverride

    function toggleAngle() {
        angleOverride = !bearingIsFree;
    }

    function setPinned(value) {
        pinned = (value === undefined) ? !pinned : !!value;
    }

    // The clicked module's own config, with the takeover view forced on.
    // Leashed names its one module outright; every packing mode by id.
    function takeoverSource(id) {
        // The mode's own configured block, not the composed `mode`: while a
        // takeover is open that one holds nothing but the takeover.
        const from = (instance && instance[activeMode]) || ({});
        if (!from.modules) return from.module ? { module: from.module, options: from.moduleOptions || ({}) } : null;
        const entry = (from.modules || []).find(each => each.id === id);
        return entry ? { module: entry.module, options: (from.moduleOptions || ({}))[id] || ({}) } : null;
    }

    // Opens Contextual holding nothing but the module that was clicked.
    function takeover(id) {
        const source = takeoverSource(id);
        if (!source) {
            console.warn(`[Pose] takeover: "${id}" is not a module of mode "${activeMode}"`);
            return;
        }
        if (!instance || !instance.contextual) {
            console.warn(`[Pose] takeover needs a contextual mode, which instance `
                + `"${instance ? instance.id : "?"}" does not declare`);
            return;
        }
        // Dropped: their ids name the modules of the mode they were
        // configured in, so they resolve against nothing here.
        const options = Object.assign({}, source.options, { view: "takeover" });
        delete options.clicks;
        takeoverEntry = { module: source.module, options: options, from: activeMode };
        switchMode("contextual");
    }

    // The one place a mode change happens, so lastActiveMode is always
    // written exactly once per transition.
    function switchMode(next) {
        if (next !== "contextual") takeoverEntry = null;
        if (next === activeMode) return;
        // A name this instance does not declare would leave every mode field
        // undefined and blank Nino.
        if (!instance || !instance[next]) {
            console.warn(`[Pose] "${next}" is not a mode on instance "${instance ? instance.id : "?"}"`);
            return;
        }
        // Settling somewhere else to rest is a fresh start; anything
        // summoned from a perch inherits whatever that perch was doing.
        if (isPerch(activeMode) && isPerch(next)) following = true;
        if (isPerch(activeMode)) lastPerchMode = activeMode;
        lastActiveMode = activeMode;
        activeMode = next;
    }

    // Leashed declares a single `size` because it is square; every other mode
    // declares width and height.
    function measure(axis) {
        return modeField(axis, modeField("size", 0));
    }

    function centre() {
        return { x: root.x + w / 2, y: root.y + h / 2 };
    }

    function cursorTarget() {
        if (!cursor) return null;
        // Two keys rather than one number-or-literal, because a fixed
        // bearing of 0 is a real bearing and not a sentinel.
        //
        // Measured to where Nino is *going*, not where it has got to: the
        // two are the same at rest, and a leg in flight would otherwise
        // swing its own target and re-floor itself on every reading (L52).
        const bearing = bearingIsFree
            ? Geometry.angleFrom(cursor, acceptedTarget || centre())
            : modeField("angleDegrees", 0);
        // targetDistance is the gap to Nino's nearest edge, so how far its
        // centre goes depends on the mode's proportions and this bearing.
        const offset = Geometry.offsetForGap(bearing, { width: w, height: h },
                                             modeField("targetDistance", 0),
                                             modeField("radius", 0));
        return Geometry.pointAtAngle(cursor, bearing, offset);
    }

    function anchoredTarget() {
        const screen = activeScreen;
        if (!screen || !mode) return null;
        // A screen-sized mode has no edge to anchor against; it is the screen.
        if (fillsScreen) {
            return { x: screen.x + screen.width / 2, y: screen.y + screen.height / 2 };
        }
        const corner = anchorCorner(screen, { width: w, height: h });
        return { x: corner.x + w / 2, y: corner.y + h / 2 };
    }

    // Top-left of this mode at `size`. Shared by the live target and by
    // fullRect, which must describe the same place at full size.
    function anchorCorner(screen, size) {
        const anchor = anchorSource || mode;
        const edge = anchor.edge || "top";
        const corner = Geometry.anchorPoint(screen, edge, anchor.alignment || "center",
                                            size, anchor.edgeMargin);
        return summonedCorner(screen, edge, corner, size);
    }

    // The borrowed anchor fixes which edge; the cursor at summon time fixes
    // where along it, clamped so it cannot hang off the screen.
    function summonedCorner(screen, edge, corner, size) {
        if (!borrowsAnchor || !summonPoint) return corner;
        if (edge === "left" || edge === "right") {
            return { x: corner.x,
                     y: Geometry.spanCenteredAt(summonPoint.y, size.height, screen.y, screen.height) };
        }
        return { x: Geometry.spanCenteredAt(summonPoint.x, size.width, screen.x, screen.width),
                 y: corner.y };
    }

    // A binding rather than a lookup inside anchorScreen(), so an unknown
    // name warns once at mode entry instead of on every cursor poll.
    readonly property var namedScreen: {
        const source = anchorSource || mode;
        const wanted = (source && source.screen) || "current";
        if (wanted === "current") return null;
        const found = (screens || []).find(screen => screen.name === wanted);
        if (!found) {
            console.warn(`[Pose] no screen named "${wanted}" — using the cursor's screen`);
        }
        return found || null;
    }

    function anchorScreen() {
        if (!screens || screens.length === 0) return null;
        if (namedScreen) return namedScreen;
        if (!cursor) return screens[0];
        // containingScreen can answer nothing — the monitor layout has
        // uncovered regions (L25).
        return Geometry.containingScreen(cursor, screens) || screens[0];
    }

    function retarget() {
        if (dragging || parked) return;
        const target = positioning === "anchored" ? anchoredTarget() : cursorTarget();
        if (!target) return;
        if (!acceptedTarget || pastDeadzone(target)) {
            // The very first placement is never delayed — there is nothing
            // to wait for when Nino has nowhere to be yet.
            if (delayMs > 0 && acceptedTarget) {
                if (!delayTimer.running) delayTimer.restart();
            } else {
                acceptedTarget = target;
            }
        }
        applyPosition();
    }

    // How far the cursor may get from Nino's edge before it follows. An
    // anchored mode has no cursor in the loop; its gate is the anchor point
    // itself moving, so a screen change still lands.
    function pastDeadzone(target) {
        if (positioning === "anchored")
            return Geometry.distance(target, acceptedTarget) > deadzone;
        return cursorGap() > deadzone;
    }

    // The same measure targetDistance places Nino by. Read from the drawn
    // rect, so a Nino still catching up keeps chasing.
    function cursorGap() {
        if (!cursor) return 0;
        return Geometry.distanceToRect(cursor, { x: x, y: y, width: w, height: h });
    }

    function acceptCurrentTarget() {
        const target = positioning === "anchored" ? anchoredTarget() : cursorTarget();
        // The wait can end with the cursor back on Nino, which must not
        // push it away.
        if (!target || !pastDeadzone(target)) return;
        acceptedTarget = target;
        applyPosition();
    }

    // Separate from retarget(): the deadzone gates which *target* is
    // accepted, not whether position follows from it.
    function applyPosition(instant) {
        if (!acceptedTarget) return;
        if (instant) {
            // The Behavior is off for exactly this assignment.
            repositioning = true;
            root.x = acceptedTarget.x - w / 2;
            root.y = acceptedTarget.y - h / 2;
            repositioning = false;
            return;
        }
        planLeg();
        root.x = acceptedTarget.x - w / 2;
        root.y = acceptedTarget.y - h / 2;
    }

    // Held true across a reposition that must land rather than fly. Read by
    // the Behaviors above, never by anything that decides where to go.
    property bool repositioning: false

    // The centre this leg was planned for. Compared by value, not identity:
    // `retarget` builds a fresh target object on every reading whose gate is
    // open, so identity reports a new destination on every poll of a cursor
    // that has not moved, and the leg decays instead of arriving (L52).
    property var plannedTarget: null

    // Called with Nino still at the leg's starting point. Once per
    // destination and no more.
    function planLeg() {
        if (plannedTarget && plannedTarget.x === acceptedTarget.x
            && plannedTarget.y === acceptedTarget.y) return;
        plannedTarget = acceptedTarget;
        const dx = Math.abs(acceptedTarget.x - w / 2 - x);
        const dy = Math.abs(acceptedTarget.y - h / 2 - y);
        const span = Math.hypot(dx, dy);
        if (span <= 0) return;
        // No speed cap leaves minMoveMs as the whole duration; with neither
        // there is nothing to fly and the Behavior is off anyway.
        const seconds = Math.max(speed > 0 ? span / speed : 0, minMoveMs / 1000);
        if (seconds <= 0) return;
        legVelocityX = dx / seconds;
        legVelocityY = dy / seconds;
    }

    // Resolved once, when the mode opens. A reading may fail and
    // containingScreen may answer nothing (L25); either falls back to live
    // resolution rather than refusing to open.
    function lockScreen() {
        cursorSource.queryOnce(reading => {
            root.lockedScreen = reading
                ? Geometry.containingScreen(reading, screens) || null
                : null;
        });
    }

    // Cursor-relative modes need continuous polling; anchored ones do not.
    function syncCursorSubscription() {
        const wants = needsCursor;
        if (wants === holdingCursor) return;
        if (wants) cursorSource.request();
        else cursorSource.release();
        holdingCursor = wants;
    }
}
