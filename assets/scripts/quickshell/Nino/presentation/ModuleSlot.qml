import QtQuick
import "../foundation/Clicks.js" as Clicks
import "../foundation"

// The host-side counterpart to Module Base: loads one module by name,
// gives it the space this content shape can offer, and owns its
// interaction. Used by every content shape, and by Dot directly.
// See architecture.md "System: Module Slot".
Item {
    id: root

    // The module type from config, e.g. "Clock".
    property string moduleName: ""
    property var theme: ({})
    property var options: ({})

    // How much width the host can offer. Dot offers exactly the icon; a
    // packing host offers a whole row. Kept separate from this slot's own
    // width, which is derived from the view the module then picks — binding
    // one to the other would be a loop.
    property real offeredWidth: renderSize

    // This mode's icon sizing. The rendered size is iconSize - padding:
    // the same padding value that insets the whole grid also trades off
    // against icon size, since a mode's footprint is fixed.
    property real iconSize: 0
    property real padding: 0

    // True for Pill/Bar/Dot, which cannot scroll and so cap height at the
    // icon row. False for Card and Dashboard cells, whose height is organic.
    property bool fixedCeiling: true

    // The mode's own click config, used for whatever the module does not claim.
    property var backgroundClicks: ({})


    signal commandRequested(var message)

    readonly property real renderSize: Math.max(0, iconSize - padding)

    // How much height the host can offer the fit test, the counterpart to
    // offeredWidth. A packing host offers its whole inner height; Dot offers
    // its one icon. -1 where height is organic and nothing can fail on it.
    property real heightCeiling: fixedCeiling ? renderSize : -1

    // Built from a config string, so it goes through the identifier guard
    // before it ever becomes a path. See architecture.md "Config Engine >
    // Security".
    readonly property string safeName: moduleName ? Config.sanitizeIdentifier(moduleName) : ""
    readonly property url moduleSource: safeName
        ? Qt.resolvedUrl("../modules/Module_" + safeName + ".qml") : ""

    // Whichever view the module settled on, or null.
    readonly property var view: {
        const item = moduleLoader.item;
        if (!item || item.selectedView < 0) return null;
        return item.views[item.selectedView] || null;
    }

    function bound(key) {
        return (view && view[key]) ? view[key] : 0;
    }

    // What the view actually draws at, once it has been given a width.
    readonly property real naturalWidth: moduleLoader.item ? moduleLoader.item.implicitWidth : 0
    readonly property real naturalHeight: moduleLoader.item ? moduleLoader.item.implicitHeight : 0

    // Whether the module actually rendered — a content shape needs this to
    // know if the slot took any room.
    readonly property bool rendered: moduleLoader.item ? moduleLoader.item.selectedView >= 0 : false

    readonly property bool showingTakeover: moduleLoader.item
        ? moduleLoader.item.selectedView === 1 : false

    // View 0 is the icon, by the same convention that makes 1 the takeover.
    // A card flows icons and gives everything else a row of its own, so it
    // is the host that needs to know, not the module.
    readonly property bool showingIcon: moduleLoader.item
        ? moduleLoader.item.selectedView === 0 : false

    // A plain Item does not follow its own implicit size (lore.md L3), so
    // these are set outright; a host that packs slots itself overrides them.
    //
    // A fixed ceiling packs what the view draws, on both axes, because a row
    // that is bigger than the thing in it turns its own slack into apparent
    // gap. An icon does the same everywhere. What is left is the card, which
    // gives a widget the whole offer and a takeover the same, measured:
    //
    //   fixed ceiling  what it draws
    //   icon           what it draws
    //   widget/card    the full offer wide, maxHeight tall
    //   takeover/card  the full offer, measured, clamped to min/max height
    //
    // minWidth and minHeight are what the fit test reads and nothing else.
    implicitWidth: {
        if (!rendered) return 0;
        return (fixedCeiling || showingIcon) ? naturalWidth : offeredWidth;
    }

    implicitHeight: {
        if (!rendered) return 0;
        // maxHeight is a card's rule, where scrolling absorbs the rest. A
        // fixed ceiling has nothing to scroll, so capping there would leave
        // the view drawing past a slot that reported the cap; the host drops
        // a row that will not clear it instead.
        if (fixedCeiling || showingIcon) return naturalHeight;
        const ceiling = bound("maxHeight");
        if (!showingTakeover) return ceiling || naturalHeight;
        const capped = ceiling > 0 ? Math.min(naturalHeight, ceiling) : naturalHeight;
        return Math.max(bound("minHeight"), capped);
    }

    width: implicitWidth
    height: implicitHeight

    Loader {
        id: moduleLoader
        // Width first, then the module reports the height it needs at that
        // width — the order matters for anything that wraps.
        width: root.width
        height: root.height
        source: root.moduleSource
    }

    // Bindings rather than assignment in onLoaded: the module's properties
    // must keep tracking config reloads and mode changes, and a property
    // assigned only in onLoaded can never be `required` anyway (lore.md L30).
    Binding { target: moduleLoader.item; property: "theme"; value: root.theme; when: moduleLoader.item }
    Binding { target: moduleLoader.item; property: "rawOptions"; value: root.options; when: moduleLoader.item }
    Binding { target: moduleLoader.item; property: "availableWidth"; value: root.offeredWidth; when: moduleLoader.item }
    Binding { target: moduleLoader.item; property: "availableHeight"; value: root.heightCeiling; when: moduleLoader.item }
    Binding { target: moduleLoader.item; property: "iconHeight"; value: root.fixedCeiling ? root.renderSize : -1; when: moduleLoader.item }
    Binding { target: moduleLoader.item; property: "fixedCeiling"; value: root.fixedCeiling; when: moduleLoader.item }

    Connections {
        target: moduleLoader.item
        function onCommandRequested(message) { root.commandRequested(message); }
    }

    // A click lands here first because a module may claim it; a drag does
    // not, because dragging moves Nino rather than anything in this slot —
    // Body owns that. The exclusive grab is what keeps a tap on a module
    // from also reaching Body's background click: the default policy takes
    // only a passive grab, which leaves both handlers free to fire for the
    // one tap. Dropping CanTakeOverFromItems for the same reason Body's
    // DragHandler does — so this cannot steal the Volume slider's own
    // press-drag (lore.md L44) — while a drag, being a different type of
    // handler, still takes over freely.
    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType
                       | PointerHandler.ApprovesTakeOverByAnything
        onSingleTapped: (eventPoint, button) => root.route(button)
    }

    // The module's own config first; whatever it leaves undefined falls
    // through to the mode's background click. "Did the module claim this
    // button" is the only question asked — no icon-versus-widget branching.
    function route(button) {
        const name = Clicks.nameOf(button);
        if (!name) return;
        if (moduleLoader.item && moduleLoader.item.handleClick(name)) return;
        const message = Clicks.messageFor(backgroundClicks ? backgroundClicks[name] : undefined);
        if (message) root.commandRequested(message);
    }
}
