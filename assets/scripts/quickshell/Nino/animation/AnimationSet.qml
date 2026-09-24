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
        });

        // A sequence with no steps never reports finished, so an empty
        // `out` has to skip straight to the action rather than wait on it.
        if (!recipe.out || recipe.out.length === 0) {
            away.destroy();
            finish();
            return;
        }
        away.finished.connect(finish);
        away.start();
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
            to: spec.to !== undefined ? spec.to : restore[spec.property],
            duration: spec.duration !== undefined ? spec.duration : 150,
            "easing.type": spec.easing !== undefined ? spec.easing : Easing.InOutQuad
        }));
        return parts.length === 1 ? parts[0]
                                  : parallelGroup.createObject(root, { animations: parts });
    }
}
