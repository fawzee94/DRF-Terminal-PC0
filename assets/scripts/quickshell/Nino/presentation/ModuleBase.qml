import QtQuick
import "../foundation/Clicks.js" as Clicks
import "../foundation"

// The contract every module implements. A module declares its views, which
// one it prefers, and what its clicks mean; the host supplies the space and
// the theme. See architecture.md "System: Module Base".
//
// Views are numbered: 0 icon, 1 takeover, 2+ the module's own. The number
// decides how a view is sized, so what each declares differs:
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

    // So config can say "widget" rather than 2. The host/module contract
    // stays numeric; this applies only to this module's own options.
    property var viewNames: ({ icon: 0, takeover: 1 })

    // --- supplied by the host ---
    property var theme: ({})
    property var rawOptions: ({})

    // Validated locally, through the same engine the central config uses, so
    // a new module stays one drop-in file the central schema never hears of.
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

    // Fit-test inputs only, never read to lay a view out. -1 on an axis
    // means unconstrained, which is how the scrolling shapes present height.
    property real availableWidth: -1
    property real availableHeight: -1

    // The size an icon draws at, or -1 for natural. Separate from
    // availableHeight, which under a packing host is the whole host.
    property real iconHeight: -1

    // Stated outright rather than scaled into: a Text fitted to a size it
    // was handed still reports the size it would have had, and the host packs
    // the number it reports.
    readonly property real iconSizing: {
        // theme is a var, undefined until its binding first evaluates (L40).
        const size = (theme && theme.fontSize) || 12;
        return iconHeight >= 0 ? Math.max(6, Math.min(iconHeight, size)) : size;
    }

    // True for Dynamic/Anchored/Leashed, which cannot scroll. A takeover is
    // excluded outright under one, not tried and rejected on size.
    property bool fixedCeiling: true

    // -1 means this module is not rendered here at all.
    readonly property int selectedView: selectView(availableWidth, availableHeight)

    readonly property int takeoverView: 1

    // Held half a second because a host's size settles over several frames
    // and the mismatches on the way there are not real; `running` restarts
    // the wait each time the state changes.
    Timer {
        interval: 500
        running: root.requestedView >= 0 && root.selectedView !== root.requestedView
        onTriggered: console.warn(root.views[root.requestedView]
            ? `[ModuleBase] view ${root.requestedView} does not fit `
                + `${root.availableWidth}x${root.availableHeight}; showing ${root.selectedView}`
            : `[ModuleBase] view ${root.requestedView} is not declared by this module; `
                + `showing nothing`)
    }

    // IPC's own command vocabulary. Bubbles one level at a time; each level
    // forwards what it does not consume.
    signal commandRequested(var message)

    function fitsIn(view, maxWidth, maxHeight) {
        const candidate = views[view];
        if (!candidate) return false;
        if (view === takeoverView && fixedCeiling) return false;
        // A view declaring no minimum cannot fail one, which is why an icon
        // needs no rule of its own here.
        if (maxWidth >= 0 && candidate.minWidth > maxWidth) return false;
        if (maxHeight >= 0 && candidate.minHeight > maxHeight) return false;
        return true;
    }

    // At most two tries: what was asked for, then the module's own default.
    // No descending search and no guaranteed fall-back-to-icon.
    function selectView(maxWidth, maxHeight) {
        const first = requestedView >= 0 ? requestedView : defaultView;
        // The two tries are for a view that does not fit *here*. One this
        // module never declared is a different kind of wrong.
        if (requestedView >= 0 && !views[requestedView]) return -1;
        if (fitsIn(first, maxWidth, maxHeight)) return first;
        if (first !== defaultView && fitsIn(defaultView, maxWidth, maxHeight)) return defaultView;
        return -1;
    }

    // Buttons this module's elements act on by being what they are, which
    // config never names. Undeclared, the host sees no claim and hands the
    // same click to the mode as well.
    property var claimedButtons: []

    // What this module's options say a button does, or undefined — in which
    // case the host falls through to the mode's background config.
    function actionFor(button) {
        const clicks = options && options.clicks;
        return clicks ? clicks[button] : undefined;
    }

    // Returns whether the click was consumed. A configured action wins over
    // a positional one, since config is the later word.
    function handleClick(button) {
        const message = Clicks.messageFor(actionFor(button));
        if (!message) return claimedButtons.indexOf(button) >= 0;
        // Here rather than one level up because nothing above knows which
        // views a module declares. Judged on the *sending* module's views.
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

    // Sized by what it loads rather than filling the slot: a view told its
    // height can never report the height it needs.
    Loader {
        id: view
        active: root.selectedView >= 0
        sourceComponent: active ? root.views[root.selectedView].delegate : null
        // Width is the host's to give; height is always the view's to report.
        width: root.width
        height: implicitHeight
    }

    implicitWidth: view.item ? view.item.implicitWidth : 0
    implicitHeight: view.item ? view.item.implicitHeight : 0
}
