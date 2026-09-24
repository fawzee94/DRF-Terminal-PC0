pragma Singleton

import Quickshell

// Pure, stateless geometry shared by Pose and Viewport. No state, no
// instance — see architecture.md "System: Geometry".
Singleton {
    // This screen's top-left corner as {x, y}.
    function screenOrigin(screen) {
        return { x: screen.x, y: screen.y };
    }

    // {x, y, width, height} for the given screen.
    function screenBounds(screen) {
        return { x: screen.x, y: screen.y, width: screen.width, height: screen.height };
    }

    // The point `distance` px from `origin` at `angleDegrees`, with 0°
    // pointing along the positive x-axis (rightward, screen coordinates).
    function pointAtAngle(origin, angleDegrees, distance) {
        const radians = angleDegrees * Math.PI / 180;
        return {
            x: origin.x + distance * Math.cos(radians),
            y: origin.y + distance * Math.sin(radians)
        };
    }

    // Bearing in degrees from `origin` to `point` — the inverse of
    // pointAtAngle, and what "free" positioning reads off Nino's own
    // current position to correct its distance without turning it.
    function angleFrom(origin, point) {
        return Math.atan2(point.y - origin.y, point.x - origin.x) * 180 / Math.PI;
    }

    // Euclidean distance between two {x, y} points.
    function distance(a, b) {
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        return Math.sqrt(dx * dx + dy * dy);
    }

    // Offset of an element of `elementSize` within `extent`. Centred unless
    // pinned to a named near ("left"/"top") or far ("right"/"bottom") side.
    function alignedPosition(extent, elementSize, alignment) {
        if (alignment === "left" || alignment === "top") return 0;
        if (alignment === "right" || alignment === "bottom") return extent - elementSize;
        return (extent - elementSize) / 2;
    }

    // A mode's `width` is its length along its edge and `height` its
    // thickness. On a left or right edge those land on the other screen
    // axis, so one bar config describes the same bar whichever side it is
    // anchored to.
    function sizeOnEdge(edge, length, thickness) {
        return (edge === "left" || edge === "right")
            ? { width: thickness, height: length }
            : { width: length, height: thickness };
    }

    // Top-left {x, y} for an element of `size` anchored against one `edge`
    // of `screen`, aligned along that edge and held `edgeMargin` clear of
    // it. An unknown edge behaves as top. The margin moves the element away
    // from its edge only; where it sits *along* that edge is untouched, so
    // a centred element stays centred.
    function anchorPoint(screen, edge, alignment, size, edgeMargin) {
        const inset = edgeMargin || 0;
        const onVerticalEdge = edge === "left" || edge === "right";
        const along = onVerticalEdge
            ? alignedPosition(screen.height, size.height, alignment)
            : alignedPosition(screen.width, size.width, alignment);
        const offsets = { top: inset, left: inset,
                          bottom: screen.height - size.height - inset,
                          right: screen.width - size.width - inset };
        const offEdge = offsets[edge] !== undefined ? offsets[edge] : inset;
        return onVerticalEdge
            ? { x: screen.x + offEdge, y: screen.y + along }
            : { x: screen.x + along, y: screen.y + offEdge };
    }

    // Where a `size`-long span starts if it is centred on `at` but kept
    // inside [min, min + extent] — a mode summoned at the cursor sits where
    // it was summoned, without hanging off the end of the screen. A span
    // longer than the extent pins to the near end.
    function spanCenteredAt(at, size, min, extent) {
        return Math.max(min, Math.min(at - size / 2, min + extent - size));
    }

    // Shortest distance from `point` to the boundary of `rect`, or 0 inside.
    function distanceToRect(point, rect) {
        const closestX = Math.max(rect.x, Math.min(point.x, rect.x + rect.width));
        const closestY = Math.max(rect.y, Math.min(point.y, rect.y + rect.height));
        return distance(point, { x: closestX, y: closestY });
    }

    // How far a rectangle's centre must sit from `origin` along `bearing`
    // for the nearest point of its outline to land `gap` px away — the
    // inverse of distanceToRect, so a mode keeps the same clearance
    // whatever its proportions and whichever side of the cursor it is on.
    // The nearest point is on a vertical face, a horizontal face, or a
    // corner; the first two returns are the faces and the last is the
    // corner. `cornerRadius` is clamped the way Qt clamps Rectangle.radius.
    function offsetForGap(bearing, size, gap, cornerRadius) {
        const radius = Math.min(cornerRadius, size.width / 2, size.height / 2);
        const halfWidth = size.width / 2 - radius;
        const halfHeight = size.height / 2 - radius;
        const reach = gap + radius;
        const radians = bearing * Math.PI / 180;
        const across = Math.abs(Math.cos(radians));
        const down = Math.abs(Math.sin(radians));
        if (across > 0 && (halfWidth + reach) / across * down <= halfHeight)
            return (halfWidth + reach) / across;
        if (down > 0 && (halfHeight + reach) / down * across <= halfWidth)
            return (halfHeight + reach) / down;
        const corner = halfWidth * across + halfHeight * down;
        return corner + Math.sqrt(corner * corner
            - (halfWidth * halfWidth + halfHeight * halfHeight - reach * reach));
    }

    // Which screen contains `point`, or undefined. Answering "none" is
    // correct and reachable here: this machine's monitors are
    // non-rectangular and leave uncovered regions (lore.md L25), and
    // substituting a screen would be a wrong answer no caller could detect.
    function containingScreen(point, screens) {
        for (let i = 0; i < screens.length; i++) {
            const screen = screens[i];
            if (point.x >= screen.x && point.x < screen.x + screen.width &&
                point.y >= screen.y && point.y < screen.y + screen.height) {
                return screen;
            }
        }
        return undefined;
    }
}
