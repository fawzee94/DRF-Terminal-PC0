import QtQuick
import Quickshell
import "../foundation"
import "../services"

// One per Nino — not per screen. Owns which mode is active and where this
// Nino's rectangle sits in global coordinates. See architecture.md
// "System: Pose".
//
// No simulation: position is a native SmoothedAnimation retargeted toward a
// point Geometry computes, gated by the deadzone.
QtObject {
    id: root

    // This instance's own config slice, injected by shell.qml.
    property var instance: ({})

    // The machine-wide facts this Nino reads, injected so a check can drive
    // it against a synthetic cursor and synthetic monitors. Everything in
    // here is behaviour no pure function can reach — which modes follow
    // which, what a summoned mode borrows, when it collapses — so it is
    // worth being able to instantiate without a real desktop underneath.
    property var cursorSource: CursorService
    property var screens: Quickshell.screens

    property string activeMode: ""
    property string lastActiveMode: ""

    // A takeover replaces Card's contents with the one module that asked
    // for it, so the mode below stays untouched data and the override lives
    // exactly as long as the card opened for it.
    property var takeoverEntry: null

    readonly property var mode: {
        const block = (instance && instance[activeMode]) || ({});
        if (activeMode !== "card" || !takeoverEntry) return block;
        return Object.assign({}, block, {
            modules: [{ id: "takeover", module: takeoverEntry.module }],
            moduleOptions: ({ takeover: takeoverEntry.options })
        });
    }

    // A perch is a mode Nino rests in, rather than one it is summoned into:
    // it positions itself, and it is not a screen-sized overlay whose edge
    // and alignment mean nothing at another mode's size. Derived rather
    // than listed, so no name has to be kept in step with the modes
    // actually declared.
    property string lastPerchMode: ""
    readonly property var perch: (instance && lastPerchMode) ? instance[lastPerchMode] : null

    function isPerch(name) {
        const block = (instance && instance[name]) || null;
        if (!block) return false;
        return (block.positioning || "cursor") !== "inherit"
            && (block.sizing || "fixed") !== "screen";
    }

    // "inherit" is how Card follows if it was opened from Pill and stays put
    // if it was opened from Bar, without Card needing to know how it was
    // opened — it just reads what its perch does. Keyed to the perch and not
    // to whatever ran last, so opening Card from Dashboard returns to the
    // dot/pill/bar that preceded it.
    // Every read of the active mode's config goes through this. `mode` is a
    // var binding, and a var binding reads undefined until it first
    // evaluates (lore.md L40) — which several bindings here beat during
    // construction, throwing on a property access two functions from the
    // cause. Nothing dereferences `mode` blind.
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
    // one. A mode that is not declared follows nothing, which is what keeps
    // the very first entry — with no previous mode at all — from claiming
    // the corner it starts in as a position worth keeping.
    function followsCursor(name) {
        const block = (instance && instance[name]) || null;
        return !!block && resolvePositioning(block.positioning || "cursor") === "cursor";
    }

    // A mode that inherits its positioning inherits the whole anchor with
    // it — edge, alignment and screen. Reading its own, absent, keys is
    // what put a Card opened from a bottom Bar at the top of the screen.
    readonly property var anchorSource:
        (modeField("positioning", "cursor") === "inherit" && perch) ? perch : mode

    readonly property bool borrowsAnchor:
        modeField("positioning", "cursor") === "inherit" && !!perch

    // Dashboard locks the screen it opened on, so it cannot migrate if the
    // cursor wanders afterwards. Everything else resolves live.
    property var lockedScreen: null
    readonly property var activeScreen: lockedScreen || anchorScreen()

    // The global rect. w/h rather than width/height because QQuickItem's are
    // FINAL and this is deliberately not an Item (lore.md L29).
    property real x: 0
    property real y: 0
    // The size the mode asks for, before any collapse capability applies.
    readonly property bool fillsScreen: modeField("sizing", "fixed") === "screen"

    // `width` is a mode's length along its edge and `height` its thickness,
    // so a bar reads the same whichever side it is anchored to. Taken from
    // this mode's own edge, not a borrowed one: a Card against a vertical
    // Bar keeps its own proportions rather than becoming a strip.
    readonly property bool verticalEdge: {
        const edge = modeField("edge", "top");
        return edge === "left" || edge === "right";
    }

    readonly property var fullSize: Geometry.sizeOnEdge(modeField("edge", "top"),
                                                        measure("width"), measure("height"))
    readonly property var collapsedSize: Geometry.sizeOnEdge(modeField("edge", "top"),
        modeField("collapsedWidth", fullSize.width),
        modeField("collapsedHeight", fullSize.height))

    readonly property real fullWidth: fillsScreen
        ? (activeScreen ? activeScreen.width : 0) : fullSize.width
    readonly property real fullHeight: fillsScreen
        ? (activeScreen ? activeScreen.height : 0) : fullSize.height

    // revealByProximity — an opt-in capability a mode turns on simply by
    // declaring revealDistance. Bar uses it; nothing else does today, and a
    // future mode wanting it needs none of Bar's code, because Bar never
    // owned the behaviour either.
    readonly property bool revealByProximity: modeField("revealDistance", undefined) !== undefined

    // Measured against where this mode sits at *full* size, deliberately:
    // measuring against the current rect would make w/h depend on revealed
    // and revealed depend on w/h — a binding loop.
    readonly property var fullRect: {
        const screen = activeScreen;
        if (!screen || !mode) return null;
        const corner = anchorCorner(screen, { width: fullWidth, height: fullHeight });
        return { x: corner.x, y: corner.y, width: fullWidth, height: fullHeight };
    }

    // pinPreventsCollapse: pinning holds a collapsing mode open. The
    // capability lives wherever collapse does rather than needing a config
    // key of its own — "pinned" has no other meaning for a mode that
    // collapses, and none at all for one that does not.
    property bool pinned: false

    // Drag writes position straight in, bypassing the target computation
    // for the gesture's duration. Nothing else is needed for following to
    // resume correctly: the cursor is on Nino when the gesture ends, so the
    // gap is zero and the gate is shut until the cursor leaves again.
    property bool dragging: false

    function beginDrag() {
        dragging = true;
        delayTimer.stop();
    }

    function dragBy(dx, dy) {
        if (!dragging) return;
        root.x += dx;
        root.y += dy;
    }

    function endDrag() {
        dragging = false;
        // The drop point is where following resumes measuring from.
        acceptedTarget = centre();
    }

    readonly property bool revealed: {
        if (!revealByProximity || pinned) return true;
        if (!cursor || !fullRect) return false;
        return Geometry.distanceToRect(cursor, fullRect) <= modeField("revealDistance", 0);
    }

    readonly property real w: revealed ? fullWidth : collapsedSize.width
    readonly property real h: revealed ? fullHeight : collapsedSize.height

    // An anchored mode needs no cursor — unless it collapses by proximity,
    // which is entirely a question about where the cursor is.
    readonly property bool needsCursor:
        positioning !== "anchored" || revealByProximity || collapseDistance > 0



    // Thousands of px/s, so config reads 6 rather than 6000 and 1.5 is
    // 1500. The useful range runs into five figures and nothing else here
    // is written at that scale.
    readonly property real speed: modeField("speed", 0) * 1000

    // How long the velocity spends climbing before it levels out and
    // cruises. Qt eases across the whole move by default, which puts a long
    // move at full speed only as it arrives.
    readonly property real easeMs: modeField("easeMs", 0)

    // The shortest a move may take. Speed alone makes a small hop finish in
    // a few milliseconds, which reads as a teleport rather than a move.
    readonly property real minMoveMs: modeField("minMoveMs", 0)

    // Each axis is a separate animation, so each is given the velocity that
    // covers its own share of the leg in the same time — they finish
    // together, the path stays straight, and the resultant is `speed`
    // rather than 1.41x it on a diagonal.
    property real legVelocityX: 0
    property real legVelocityY: 0

    // Parks Nino where it stands. Only the cursor-relative target is gated:
    // dragging, collapsing and the mode's own chrome all still work, and an
    // anchored mode is untouched, since following the cursor is not what it
    // was doing. A freeze belongs to the perch and survives everything
    // summoned from it — a card opened from a parked pill stays parked, and
    // collapsing back does not quietly set it going again.
    property bool following: true

    // Following is following the *cursor*, so an anchored mode is never
    // parked — it was not doing that, and gating its retarget would leave
    // it unable to place itself at all.
    readonly property bool parked: !following && positioning === "cursor"

    // An opt-in capability like revealByProximity: a mode declaring
    // collapseDistance leaves for its perch once the cursor is that far
    // from its edge. Pinning holds it open, as it does a collapsing size.
    readonly property real collapseDistance: modeField("collapseDistance", 0)

    function collapseWhenAbandoned() {
        if (collapseDistance <= 0 || pinned || dragging) return;
        if (!lastPerchMode || !instance || !instance[lastPerchMode]) return;
        if (!acceptedTarget || gapAtTarget() <= collapseDistance) return;
        collapse();
    }

    // Measured to where the mode is *going*, not where it currently is.
    // On entry the drawn rect is still the previous mode's, and mid-flight
    // it is somewhere between the two — either reads as abandoned and
    // collapses a mode the instant it opens.
    function gapAtTarget() {
        if (!cursor || !acceptedTarget) return 0;
        return Geometry.distanceToRect(cursor, {
            x: acceptedTarget.x - w / 2,
            y: acceptedTarget.y - h / 2,
            width: w, height: h
        });
    }

    readonly property real deadzone: modeField("deadzone", 0)

    // How long to wait, once the deadzone gate has opened, before actually
    // setting off. The target is recomputed when the wait ends rather than
    // captured when it began, so Nino heads for where the cursor is *then*,
    // not where it was when it first strayed.
    readonly property real delayMs: modeField("delayMs", 0)

    readonly property Timer delayTimer: Timer {
        interval: root.delayMs
        onTriggered: root.acceptCurrentTarget()
    }

    // The centre point the deadzone gate last accepted, not the live centre.
    property var acceptedTarget: null
    property bool holdingCursor: false

    // Where the cursor was when this mode opened, fixed once rather than
    // followed. The standing reading is used immediately so nothing appears
    // centred for a frame, then replaced by a genuinely fresh one: the mode
    // being left may have held no cursor subscription at all, in which case
    // the standing reading is as old as that mode is.
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

    // Collapsing changes the size, and position is measured from the
    // centre, so x/y must be re-derived when it does.
    onWChanged: applyPosition()
    onHChanged: applyPosition()

    // The anchor screen can arrive after the first target was computed —
    // Dashboard's lock is asynchronous, so the opening frame resolves
    // against whatever screen was current and the real answer lands a
    // moment later. Without this the mode keeps the earlier screen's
    // position while wearing the locked screen's size.
    onActiveScreenChanged: retarget()

    // Keyed to `mode` rather than `activeMode`: the mode's config is what
    // all of this depends on, and an activeMode handler never runs at all
    // when the starting mode arrives through a binding that settles before
    // the handler is connected.
    //
    // Deferred rather than called straight from the handler, because being
    // keyed to `mode` is not enough on its own: `fillsScreen`,
    // `positioning` and the rest are bindings *derived* from `mode`, and
    // they have not re-evaluated while the handler is running (lore.md
    // L46). Entering Dashboard read the outgoing mode's values, so it never
    // locked a screen and followed the cursor between monitors instead.
    onModeChanged: Qt.callLater(enterMode)
    Component.onCompleted: enterMode()

    // speed 0 means teleport, so the Behavior is simply switched off and the
    // assignment lands instantly.
    Behavior on x {
        enabled: root.speed > 0 && !root.dragging
        SmoothedAnimation {
            id: followX
            velocity: root.legVelocityX
            // -1 is Qt's "ease across the whole move"; a positive easeMs
            // levels the velocity out after that long and cruises the rest.
            maximumEasingTime: root.easeMs > 0 ? root.easeMs : -1
        }
    }
    Behavior on y {
        enabled: root.speed > 0 && !root.dragging
        SmoothedAnimation {
            id: followY
            velocity: root.legVelocityY
            maximumEasingTime: root.easeMs > 0 ? root.easeMs : -1
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
    }

    // What a mode starts out heading for. Null means "work it out from
    // scratch", which is right for a mode that places itself.
    function startingTarget() {
        // Parked, the target stops moving — it does not stop existing. A
        // parked mode never accepts a replacement, so clearing this leaves
        // the collapse distance and the deadzone measuring from nothing.
        if (parked) return centre();
        // Two cursor-relative modes are different sizes, and targetDistance
        // is the gap to the nearest *edge* — so re-deriving from the cursor
        // slides the centre along the cursor ray by the difference between
        // them, every single switch. Keeping it makes a switch a change of
        // shape rather than a move; the mode's own targetDistance takes
        // effect again on the first move that opens the deadzone gate.
        if (positioning === "cursor" && followsCursor(lastActiveMode)) return centre();
        return null;
    }

    // A command's name is simply the name of the method that carries it
    // out, so a module's bubbled request and an external IPC call reach the
    // identical function. Nothing to register, and no dispatcher table that
    // could fall out of step with the methods it names.
    function handleCommand(message) {
        if (!message || typeof message.command !== "string") return;
        const handler = root[message.command];
        if (typeof handler !== "function") {
            console.warn(`[Pose] no handler for command "${message.command}"`);
            return;
        }
        handler(message.value);
    }

    // Returns to whatever this instance rests in. The nearest owner of
    // "which mode is active" is Pose, so this is where close resolves.
    function close() {
        switchMode((instance && instance.restingMode) || "dot");
    }

    // The order cycleModes walks. Configured per instance when it is
    // listed; otherwise every mode this instance actually declares, found
    // by looking for a contentShape rather than by a hardcoded list of
    // names — a Nino that only configures dot and pill cycles those two
    // without anyone having to write them down twice.
    readonly property var cycleOrder: {
        const listed = (instance && instance.cycleModes) || [];
        if (listed.length > 0) {
            // Warned about rather than skipped in silence: a name this
            // instance does not declare is a typo every time, and cycling
            // simply stepping over it reads as the mode being broken.
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

    // Steps forward from the current mode, skipping any the instance does
    // not declare so a cycle list naming an absent mode cannot stall on it.
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

    // Back to the perch — what a collapsing mode does when abandoned, and
    // what a click asking to collapse does on purpose. A Nino that has not
    // rested anywhere yet has no perch to return to, so close() answers.
    function collapse() {
        if (lastPerchMode && instance && instance[lastPerchMode]) switchMode(lastPerchMode);
        else close();
    }

    // Back to whatever was active before this mode, which is not the same
    // question close() answers — that one always goes to restingMode.
    function back() {
        if (lastActiveMode && instance && instance[lastActiveMode]) switchMode(lastActiveMode);
        else close();
    }

    function setPinned(value) {
        pinned = (value === undefined) ? !pinned : !!value;
    }

    // The clicked module's own config, with the takeover view forced on, so
    // the card shows what the author already configured rather than schema
    // defaults. Dot names its one module outright; every packing mode by id.
    function takeoverSource(id) {
        const from = mode;
        if (!from.modules) return from.module ? { module: from.module, options: from.moduleOptions || ({}) } : null;
        const entry = (from.modules || []).find(each => each.id === id);
        return entry ? { module: entry.module, options: (from.moduleOptions || ({}))[id] || ({}) } : null;
    }

    // Opens Card holding nothing but the module that was clicked. The
    // module's own view is left alone — a takeover is a card, not a
    // different shape for the slot it was summoned from.
    function takeover(id) {
        const source = takeoverSource(id);
        if (!source) {
            console.warn(`[Pose] takeover: "${id}" is not a module of mode "${activeMode}"`);
            return;
        }
        if (!instance || !instance.card) {
            console.warn(`[Pose] takeover needs a card mode, which instance `
                + `"${instance ? instance.id : "?"}" does not declare`);
            return;
        }
        takeoverEntry = { module: source.module,
                          options: Object.assign({}, source.options, { view: "takeover" }) };
        switchMode("card");
    }

    // The one place a mode change happens, so lastActiveMode is always
    // written exactly once per transition. Phase 8's IPC calls this too.
    function switchMode(next) {
        if (next !== "card") takeoverEntry = null;
        if (next === activeMode) return;
        // A name this instance does not declare would leave every mode
        // field undefined and blank Nino — an easy typo to make in a
        // keybinding, and a confusing one to diagnose from the result.
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

    // Dot declares a single `size` because it is square; every other mode
    // declares width and height.
    function measure(axis) {
        return modeField(axis, modeField("size", 0));
    }

    function centre() {
        return { x: root.x + w / 2, y: root.y + h / 2 };
    }

    function cursorTarget() {
        if (!cursor) return null;
        // "free" holds whatever bearing the rectangle already has, so it
        // corrects distance without ever swinging around the cursor.
        const angle = modeField("angle", "free");
        const bearing = angle === "free" ? Geometry.angleFrom(cursor, centre()) : angle;
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

    // Top-left of this mode at `size`, honouring a borrowed anchor and the
    // point it was summoned at. Shared by the live target and by fullRect,
    // which must describe the same place at full size.
    function anchorCorner(screen, size) {
        const anchor = anchorSource || mode;
        const edge = anchor.edge || "top";
        const corner = Geometry.anchorPoint(screen, edge, anchor.alignment || "center",
                                            size, anchor.edgeMargin);
        return summonedCorner(screen, edge, corner, size);
    }

    // A summoned mode appears where it was summoned: the borrowed anchor
    // fixes which edge it sits on, and the cursor at summon time fixes
    // where along that edge, clamped so it cannot hang off the screen.
    function summonedCorner(screen, edge, corner, size) {
        if (!borrowsAnchor || !summonPoint) return corner;
        if (edge === "left" || edge === "right") {
            return { x: corner.x,
                     y: Geometry.spanCenteredAt(summonPoint.y, size.height, screen.y, screen.height) };
        }
        return { x: Geometry.spanCenteredAt(summonPoint.x, size.width, screen.x, screen.width),
                 y: corner.y };
    }

    // A mode may pin itself to one output by name; "current" — the default
    // — means whichever screen the cursor is on. A binding rather than a
    // lookup inside anchorScreen(), so an unknown name warns once when the
    // mode is entered instead of on every cursor poll.
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
        // uncovered regions (lore.md L25).
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

    // How far the cursor may get from Nino's edge before it follows —
    // measured the way targetDistance and revealDistance are, so the three
    // are one quantity. A cursor on Nino reads a gap of zero and therefore
    // cannot open the gate, which is what lets Nino be caught and clicked.
    // An anchored mode has no cursor in the loop; its gate is the anchor
    // point itself moving, so a screen change still lands.
    function pastDeadzone(target) {
        if (positioning === "anchored")
            return Geometry.distance(target, acceptedTarget) > deadzone;
        return cursorGap() > deadzone;
    }

    // Distance from the cursor to Nino's nearest edge — the same measure
    // targetDistance places it by and revealDistance is tested against.
    // Read from the drawn rect rather than the accepted target, so a Nino
    // still catching up keeps chasing instead of resting on a point it has
    // not reached. A function rather than a binding: it is wanted once per
    // gate check, not on every frame x and y move through.
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

    // Separate from retarget() because the deadzone gates which *target* is
    // accepted, not whether position follows from it. A mode that changes
    // size — Bar revealing — keeps the same centre, so the gate sees an
    // unchanged target and would otherwise leave x/y at the old size's
    // offset, drawing the mode off-centre by half the size change.
    function applyPosition() {
        if (!acceptedTarget) return;
        planLeg();
        root.x = acceptedTarget.x - w / 2;
        root.y = acceptedTarget.y - h / 2;
    }

    // Called with Nino still at the leg's starting point, so a retarget
    // mid-flight plans for the leg it is actually about to fly. `speed`
    // caps a long leg; minMoveMs floors a short one.
    function planLeg() {
        if (speed <= 0) return;
        const dx = Math.abs(acceptedTarget.x - w / 2 - x);
        const dy = Math.abs(acceptedTarget.y - h / 2 - y);
        const span = Math.hypot(dx, dy);
        if (span <= 0) return;
        const seconds = Math.max(span / speed, minMoveMs / 1000);
        legVelocityX = dx / seconds;
        legVelocityY = dy / seconds;
    }

    // Resolved once, at the moment the mode opens. A reading may fail, and
    // containingScreen may legitimately answer nothing for a point in an
    // uncovered region (lore.md L25) — either way this falls back to the
    // same live resolution every other mode uses rather than refusing to
    // open, which would be a worse answer than a slightly wrong screen.
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
