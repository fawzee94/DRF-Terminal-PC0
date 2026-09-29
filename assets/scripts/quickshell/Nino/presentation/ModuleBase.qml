import QtQuick
import "../foundation/Clicks.js" as Clicks
import "../foundation"

// The contract every module implements. A module declares its views, which
// one it prefers, and what its clicks mean; the host supplies the space and
// the theme. See architecture.md "System: Module Base".
//
// Views are numbered, not named: 0 is icon, 1 is takeover — both fixed
// conventions every host understands structurally — and 2+ are the module's
// own. The number decides how a view is sized, because the three kinds want
// different things:
//
//   0  icon      declares no size at all; it draws at the theme's fontSize
//                and the host reads whatever that comes to
//   1  takeover  declares minHeight/maxHeight; takes the width it is given
//                and is measured at it, clamped to those bounds
//   2+ widget    declares minWidth/minHeight, and maxHeight for a card
//
//   views: ({ 0: { delegate: iconView },
//             1: { minHeight: 150, maxHeight: 400, delegate: takeoverView },
//             2: { minWidth: 62, minHeight: 30, maxHeight: 90, delegate: widgetView } })
Item {
    id: root

    // --- declared by the module ---
    property int defaultView: 0
    property var views: ({})
    property var optionsSchema: ({})

    // A module may name its own views, so config can say "widget" rather
    // than 2. The host/module contract stays numeric — this is a lookup
    // applied only to this module's own opaque options. 0 and 1 are the
    // conventional names for the two views every host understands.
    property var viewNames: ({ icon: 0, takeover: 1 })

    // --- supplied by the host ---
    property var theme: ({})
    property var rawOptions: ({})

    // A module validates its own options locally, through the same engine
    // the central config uses. That is what keeps a new module a single
    // drop-in file the central schema never has to hear about.
    readonly property var options: (optionsSchema && optionsSchema.type)
        ? Config.validate(optionsSchema, rawOptions, "moduleOptions")
        : (rawOptions || ({}))

    // Which view this module's own options ask for, or -1 for no preference.
    property int requestedView: {
        const asked = options ? options.view : undefined;
        if (asked === undefined || asked === "") return -1;
        if (typeof asked === "number") return asked;
        const named = viewNames[asked];
        if (named !== undefined) return named;
        console.warn(`[ModuleBase] unknown view "${asked}"`);
        return -1;
    }

    // The space the host can give. -1 on an axis means unconstrained, which
    // is how the scrolling shapes (Card, Dashboard cell) present height.
    //
    // A fit-test input only. A view lays itself out inside the width it is
    // handed, which under a fixed ceiling is its own declared minWidth and
    // not this — sizing content off the whole offer is what drew a bar's
    // slider across its neighbours.
    property real availableWidth: -1
    property real availableHeight: -1

    // The size an icon view should draw at, or -1 for its natural size. Kept
    // apart from availableHeight, which is the fit test's ceiling and under a
    // packing host is the whole host rather than one row.
    property real iconHeight: -1

    // What an icon's text states outright, rather than being boxed and
    // scaled into a height: a Text fitted to a size it was handed still
    // reports the size it would have had, and the host packs the number it
    // reports. A Dot smaller than the configured point size still shrinks.
    readonly property real iconSizing: {
        // theme is a var, and is undefined on the first evaluation — before
        // the host's binding lands.
        const size = (theme && theme.fontSize) || 12;
        return iconHeight >= 0 ? Math.max(6, Math.min(iconHeight, size)) : size;
    }

    // Set by the host: true for Pill/Bar/Dot, which cannot scroll. A
    // takeover is never offered under one — not tried and rejected on size,
    // but excluded outright, so a module configured for takeover in a bar
    // shows its default view rather than a squeezed calendar.
    property bool fixedCeiling: true

    // -1 means this module is not rendered here at all.
    readonly property int selectedView: selectView(availableWidth, availableHeight)

    readonly property int takeoverView: 1

    // A view the config named outright and did not get is worth saying out
    // loud — the fallback is deliberate, but silent it reads as a bug in
    // whichever host dropped it. Held half a second because a host's size
    // settles over several frames and the mismatches on the way there are
    // not real; `running` restarts the wait each time the state changes.
    Timer {
        interval: 500
        running: root.requestedView >= 0 && root.selectedView !== root.requestedView
        onTriggered: console.warn(root.views[root.requestedView]
            ? `[ModuleBase] view ${root.requestedView} does not fit `
                + `${root.availableWidth}x${root.availableHeight}; showing ${root.selectedView}`
            : `[ModuleBase] view ${root.requestedView} is not declared by this module; `
                + `showing nothing`)
    }

    // Reuses IPC's command vocabulary, so a module's request is
    // indistinguishable from an external one by the time it lands. Bubbles
    // one level at a time; each level forwards what it does not consume.
    signal commandRequested(var message)

    function fitsIn(view, maxWidth, maxHeight) {
        const candidate = views[view];
        if (!candidate) return false;
        if (view === takeoverView && fixedCeiling) return false;
        // A view declaring no minimum cannot fail one, which is what makes
        // an icon the floor every host has room for without needing a rule
        // of its own.
        if (maxWidth >= 0 && candidate.minWidth > maxWidth) return false;
        if (maxHeight >= 0 && candidate.minHeight > maxHeight) return false;
        return true;
    }

    // At most two tries: what was asked for, then the module's own default.
    // No descending search and no guaranteed fall-back-to-icon — if the
    // default cannot fit, not rendering is better than silently degrading
    // into a view nobody chose.
    function selectView(maxWidth, maxHeight) {
        const first = requestedView >= 0 ? requestedView : defaultView;
        // The fallback below is for a view that does not fit *here* — a
        // takeover in a bar, a widget in a narrow slot. A view this module
        // never declared is a different thing: showing the default instead
        // says nothing about which name was wrong.
        if (requestedView >= 0 && !views[requestedView]) return -1;
        if (fitsIn(first, maxWidth, maxHeight)) return first;
        if (first !== defaultView && fitsIn(defaultView, maxWidth, maxHeight)) return defaultView;
        return -1;
    }

    // Buttons this module's own elements already act on, wherever inside it
    // they land — Volume's glyph mutes and its track sets the level, each
    // ControlBar button sends its command. Config never names these, because
    // they are what the module *is*, so without declaring them the host sees
    // no claim and hands the same click to the mode as well. That is how a
    // left click on a mute glyph also opened a card.
    property var claimedButtons: []

    // What this module's own options say a button does, or undefined if it
    // claims nothing — in which case the click is not consumed here and the
    // host falls through to the mode's background config.
    function actionFor(button) {
        const clicks = options && options.clicks;
        return clicks ? clicks[button] : undefined;
    }

    // Returns whether the click was consumed. An action the module handles
    // itself (Clock copying a date) is handled by overriding performLocally;
    // anything else goes upward as the standard command. A configured action
    // wins over a positional one, since config is the later word.
    function handleClick(button) {
        const message = Clicks.messageFor(actionFor(button));
        if (!message) return claimedButtons.indexOf(button) >= 0;
        // Judged on this module's own views, since a takeover names the entry
        // that sends it. One naming a *different* module would be refused on
        // the wrong module's behalf — not a pattern config has, but the reason
        // this guard is here rather than one level up is that nothing above
        // knows which views a module declares.
        if (message.command === "takeover" && !views[takeoverView]) {
            console.warn(`[ModuleBase] takeover refused: no view ${takeoverView} declared`);
            return true;
        }
        if (!performLocally(message.command)) commandRequested(message);
        return true;
    }

    // Modules override this to act internally. Returning false sends the
    // action upward instead.
    function performLocally(action) {
        return false;
    }

    // Sized by what it loads rather than filling the slot: a view that is
    // told its height can never report the height it actually needs, which
    // is how a takeover came to be drawn at its declared minimum and
    // overlapped by whatever followed it.
    Loader {
        id: view
        active: root.selectedView >= 0
        sourceComponent: active ? root.views[root.selectedView].delegate : null
        // Width is the host's to give; height is always the view's to
        // report, since every host now takes a row from what it draws.
        width: root.width
        height: implicitHeight
    }

    implicitWidth: view.item ? view.item.implicitWidth : 0
    implicitHeight: view.item ? view.item.implicitHeight : 0
}
