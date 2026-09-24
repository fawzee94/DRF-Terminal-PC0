import Quickshell
import Quickshell.Io
import "foundation"
import "instance"

// The only file allowed to know this project's shape: for each configured
// instance, one Pose and one Viewport per screen. Nothing else — mode
// blocks, module lists and click config are all resolved further down, at
// the level that needs them.
ShellRoot {
    Variants {
        // Keyed by id rather than by the instance objects. A config reload
        // rebuilds the whole tree, so a model of objects looks entirely new
        // and Variants tears down and recreates every window — which also
        // double-registers the IpcHandler for as long as the old one is
        // still alive. Ids survive a reload, so the delegates persist and
        // only the data behind them changes.
        model: (Config.data.instances || []).map(entry => entry.id)

        Scope {
            id: nino
            required property var modelData

            readonly property var instance: {
                for (const entry of (Config.data.instances || [])) {
                    if (entry.id === modelData) return entry;
                }
                return ({});
            }

            Pose {
                id: ninoPose
                instance: nino.instance
                activeMode: nino.instance.restingMode || "dot"
            }

            // Addressing "which Nino" is just picking the right target
            // string; Quickshell's own per-target registration is the
            // instance registry, so there is no second one to keep.
            IpcHandler {
                target: nino.modelData

                // Each is a one-line typed wrapper onto the very method a
                // module's bubbled command already reaches, so external and
                // internal callers share one piece of logic rather than two
                // that drift.
                function switchMode(mode: string): void { ninoPose.switchMode(mode); }
                function setPinned(pinned: bool): void { ninoPose.setPinned(pinned); }
                function close(): void { ninoPose.close(); }
                function togglePin(): void { ninoPose.togglePin(); }
                function cycleModes(): void { ninoPose.cycleModes(); }
                function takeover(module: string): void { ninoPose.takeover(module); }
                function toggleFollow(): void { ninoPose.toggleFollow(); }
                function collapse(): void { ninoPose.collapse(); }
                function back(): void { ninoPose.back(); }
            }

            // One window per screen: a PanelWindow cannot span monitors.
            Variants {
                model: Quickshell.screens

                Viewport {
                    required property var modelData
                    screen: modelData
                    pose: ninoPose
                }
            }
        }
    }
}
