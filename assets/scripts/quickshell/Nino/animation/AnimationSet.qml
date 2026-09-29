import QtQuick
import "../foundation"

// Loads the configured catalogue and runs its named styles against
// arbitrary targets. One per Nino, owned by Body.
Item {
    id: root

    property string setName: "Default"

    // Built from a config string, so it passes the identifier guard before
    // it ever becomes a path — architecture.md "Config Engine > Security".
    readonly property string safeName: Config.sanitizeIdentifier(setName) || "Default"
    property string effectiveName: safeName
    onSafeNameChanged: effectiveName = safeName

    readonly property url source: Qt.resolvedUrl("Animation_" + effectiveName + ".qml")

    Loader {
        id: catalogue
        source: root.source
        onStatusChanged: {
            if (status !== Loader.Error || root.effectiveName === "Default") return;
            console.warn(`[AnimationSet] no set named "${root.effectiveName}", using Default`);
            root.effectiveName = "Default";
        }
    }

    Component { id: propertyAnimation; PropertyAnimation {} }
    Component { id: parallelGroup; ParallelAnimation {} }
    Component { id: sequentialGroup; SequentialAnimation {} }

    function style(name) {
        return catalogue.item ? catalogue.item[name] : undefined;
    }

    // How Nino's box resizes, read by the Behavior that runs the morph.
    readonly property var morph: style("shapeMorph") || ({})
    readonly property var grow: growFractions(morph.growFrom)

    // Which edge holds still while the box morphs, as the share of the size
    // slack that goes in front of the box on each axis — 0 keeps the near
    // edge, 1 keeps the far one — together with the transform origin that
    // puts a scale or a rotation on the same edge.
    //
    // Silent fallback rather than the warn-and-fall-back the identifier
    // guard uses: this is a look, not a path, so a wrong value costs a
    // different animation and nothing else.
    function growFractions(name) {
        switch (name) {
        case "left":   return { x: 0,   y: 0.5, origin: Item.Left };
        case "right":  return { x: 1,   y: 0.5, origin: Item.Right };
        case "top":    return { x: 0.5, y: 0,   origin: Item.Top };
        case "bottom": return { x: 0.5, y: 1,   origin: Item.Bottom };
        case "center": return { x: 0.5, y: 0.5, origin: Item.Center };
        // Named separately from "center" so the fallback is its own branch
        // and a typo in a config-authored set can be shown to be harmless.
        default:       return { x: 0.5, y: 0.5, origin: Item.Center };
        }
    }

    // Captures what the style touches, animates it away, runs `action` at
    // the low point, then animates back. The style is a complete recipe, so
    // there is no separate property list or away-value to pass in.
    function around(target, styleName, action) {
        const recipe = style(styleName);
        if (!target || !recipe) {
            if (action) action();
            return;
        }

        const restore = capture(target, recipe);
        const away = build(target, recipe.out, restore);
        const back = build(target, recipe["in"], restore);

        function finish() {
            if (action) action();
            back.start();
        }

        back.finished.connect(function () {
            away.destroy();
            back.destroy();
            // A pulse and a held state share a target and often a property:
            // every path that collapses a bar also pulses the body, and the
            // pulse's `in` returns to *its* rest, not to the collapsed look.
            // Whichever finished last used to win. The held phase is
            // re-asserted instead, so a pulse is an excursion from the state
            // in force rather than a thing that ends it.
            const rest = held.get(target);
            if (rest) play(target, rest.styleName, rest.phase);
        });

        // An empty `out` needs no special case: a group with no children
        // reports finished from inside start(), so the action still runs on
        // the same turn it would have (lore.md L50).
        away.finished.connect(finish);
        away.start();
    }

    // Hover and collapse are held states rather than wrapped actions: the
    // caller plays "out" on the way out and "in" on the way back, and the
    // away look stands for as long as the state does. A held entry must
    // therefore name an explicit `to` on every step — `capture` reads the
    // target as it stands, which for an `in` played minutes after its `out`
    // is the away value, not the resting one.
    //
    // One running group per target: a fast hover in-and-out would otherwise
    // leave two animations writing the same property on the same frame.
    readonly property var running: new Map()

    // The phase each target was last held in — what it should look like at
    // rest, which for anything with a held entry is not the same as its
    // declared resting values.
    readonly property var held: new Map()

    function play(target, styleName, phase) {
        const recipe = style(styleName);
        if (!target || !recipe) return;

        held.set(target, { styleName: styleName, phase: phase });

        const previous = running.get(target);
        if (previous) {
            previous.stop();
            previous.destroy();
        }
        running.delete(target);

        // Recorded before it is started, because an empty phase finishes
        // from inside start() (lore.md L50) — set it afterwards and the
        // handler that clears it has already run, leaving a dead group in
        // `running` for good.
        const group = build(target, recipe[phase], capture(target, recipe));
        running.set(target, group);
        group.finished.connect(function () {
            if (running.get(target) === group) running.delete(target);
            group.destroy();
        });
        group.start();
    }

    // Every property the recipe mentions, as it stands right now. This is
    // what an `in` step animates back to when it names no `to` of its own.
    function capture(target, recipe) {
        const values = ({});
        for (const phase of [recipe.out, recipe["in"]]) {
            for (const step of (phase || [])) {
                for (const spec of step) {
                    if (values[spec.property] === undefined) {
                        values[spec.property] = target[spec.property];
                    }
                }
            }
        }
        return values;
    }

    function build(target, phase, restore) {
        return sequentialGroup.createObject(root, {
            animations: (phase || []).map(step => buildStep(target, step, restore))
        });
    }

    function buildStep(target, step, restore) {
        const parts = step.map(spec => propertyAnimation.createObject(root, {
            target: target,
            property: spec.property,
            to: destination(target, spec, restore),
            duration: spec.duration !== undefined ? spec.duration : 150,
            "easing.type": spec.easing !== undefined ? spec.easing : Easing.InOutQuad
        }));
        return parts.length === 1 ? parts[0]
                                  : parallelGroup.createObject(root, { animations: parts });
    }

    // `grow` first, then `to`, then whatever the property was at rest. The
    // order is reachable by authoring rather than theoretical: converting an
    // entry from a ratio to a growth leaves both keys behind if the old one
    // is not cut, and the more specific of the two is what was meant.
    function destination(target, spec, restore) {
        if (spec.grow !== undefined) return scaleForGrowth(target, spec.grow);
        if (spec.to !== undefined) return spec.to;
        return restore[spec.property];
    }

    // Scale is a ratio, so one entry shared by elements of different sizes
    // moves each by a different amount: 1.12 grows a 134px slider by
    // sixteen pixels and a 10px glyph by one, which reads as the glyph not
    // animating at all. A growth converts per target instead — the longest
    // side gains exactly this many pixels whatever the element is.
    //
    // The longest side rather than either axis on its own: it is the
    // element's visual extent, and measuring a 134x12 slider by its height
    // would grow it half its own length sideways.
    function scaleForGrowth(target, pixels) {
        const extent = Math.max(target.width, target.height);
        if (!(extent > 0)) return 1;
        return Math.max(0, (extent + pixels) / extent);
    }
}
