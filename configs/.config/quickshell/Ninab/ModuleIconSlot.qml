import QtQuick

// ModuleIconSlot: hosts one module's icon view inside a Flow (the pill's
// row or the card's icon grid), owns all click handling for it — see
// modules/template.qml for why modules themselves don't do this.
//
// WHAT: interactive: false (pill) only accepts right-click; interactive:
//   true (card) accepts both — left calls activateIcon(), right requests
//   a card takeover (only if the module declares hasCard).
// WHY: an unaccepted left click in pill context falls straight through
//   to Nino's own big MouseArea ("left click expands the pill") — no
//   extra pass-through plumbing needed, that's just how Qt Quick
//   delivers an event a MouseArea didn't accept for that button.

Item {
    id: slot

    required property string moduleName
    property bool interactive: true
    property var theme: null
    property var system: null
    property var moduleConfig: ({})
    // WHAT: shared height of every slot in the same Flow row.
    // WHY: without this, Flow (which top-aligns children within a row
    //   instead of centering them) would leave a module with a shorter
    //   icon sitting near the row's top edge while the tallest icon
    //   alone looked vertically centered. 0 = "not set yet", falls back
    //   to own implicitHeight so there's no flash of 0-height before
    //   ModuleIconRow.qml computes it.
    property real rowHeight: 0

    signal cardRequested(string moduleId)

    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: loader.item ? loader.item.implicitHeight : 0
    // NOTE: plain Item, so width/height don't auto-follow implicit* —
    // this is read by the enclosing Flow to lay slots out (see
    // ModuleIconRow.qml), so it matters here more than most.
    width: implicitWidth
    height: rowHeight > 0 ? rowHeight : implicitHeight

    Loader {
        id: loader
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        // NOTE: sized to the module's own natural (implicit) size rather
        // than filling the slot, so it can center within a taller,
        // shared-height slot instead of stretching to fill it.
        source: slot.moduleName ? ("modules/" + slot.moduleName + ".qml") : ""
        onLoaded: {
            item.displayMode = "icon"
            item.theme = Qt.binding(() => slot.theme)
            item.system = Qt.binding(() => slot.system)
            item.config = Qt.binding(() => slot.moduleConfig)
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: slot.interactive ? (Qt.LeftButton | Qt.RightButton) : Qt.RightButton
        onClicked: mouse => {
            if (!loader.item) return
            if (mouse.button === Qt.LeftButton) {
                loader.item.activateIcon()
            } else if (mouse.button === Qt.RightButton) {
                if (loader.item.hasCard) slot.cardRequested(slot.moduleName)
            }
        }
    }
}
