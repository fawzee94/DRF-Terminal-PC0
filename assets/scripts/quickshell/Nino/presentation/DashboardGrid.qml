import QtQuick

// Dashboard placement. Deliberately not the auto-flow grid: that one *packs*,
// computing positions as it goes, while this one *looks up* each card's
// already-authored col/row/w/h. Two unrelated algorithms behind one
// component would only be an internal branch. What they do share is Module
// Slot itself, via Card Body.
Item {
    id: root

    property int columns: 1
    property int rows: 1
    property var cards: []
    property var theme: ({})
    property real padding: 0
    property real gap: 0

    signal commandRequested(var message)

    readonly property real cellWidth: columns > 0
        ? (width - (columns - 1) * gap) / columns : 0
    readonly property real cellHeight: rows > 0
        ? (height - (rows - 1) * gap) / rows : 0

    function spanSize(cells, cell) {
        return cells > 0 ? cells * cell + (cells - 1) * gap : 0;
    }

    Repeater {
        model: root.cards

        Rectangle {
            id: cell
            required property var modelData

            x: (modelData.col || 0) * (root.cellWidth + root.gap)
            y: (modelData.row || 0) * (root.cellHeight + root.gap)
            width: root.spanSize(modelData.w || 1, root.cellWidth)
            height: root.spanSize(modelData.h || 1, root.cellHeight)

            // A cell carries its own resolved theme slice, so one card can
            // look different from its neighbours without the grid knowing.
            color: modelData.background || "transparent"
            radius: modelData.radius || 0
            border.width: modelData.borderWidth || 0
            border.color: modelData.accent || "transparent"

            CardBody {
                anchors.fill: parent
                anchors.margins: (cell.modelData.padding || 0) / 2
                modules: cell.modelData.modules || []
                moduleOptions: cell.modelData.moduleOptions || ({})
                theme: Object.assign({}, root.theme, cell.modelData)
                // Per card, not per dashboard: a cell sizes its own icons.
                iconSize: cell.modelData.iconSize || 0
                padding: cell.modelData.padding || 0
                gap: cell.modelData.gap || 0
                moduleAlignment: cell.modelData.moduleAlignment || ({})
                onCommandRequested: message => root.commandRequested(message)
            }
        }
    }
}
