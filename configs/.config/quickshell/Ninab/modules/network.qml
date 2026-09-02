import QtQuick

// Network module — connection status/rate/ping + wifi scan/connect. All
// data/actions come from logic/System.qml; see modules/template.qml for
// the general module contract.
//
// Config (moduleSettings["network"] in config.json), all optional:
//   {
//     "label": "Network",
//     "labelIcon": "",
//     "icons": {
//       "wifi": "",
//       "ethernet": "",
//       "disconnected": ""
//     }
//   }

Item {
    id: module

    readonly property bool hasIcon: true
    readonly property bool hasWidget: true
    readonly property bool hasCard: true

    property string displayMode: "icon"
    property var theme: null
    property var system: null
    property var config: ({})
    property real availableWidth: 0

    // WHAT: this module's own display config.
    readonly property string label: (typeof config.label === "string") ? config.label : "Network"
    readonly property var iconsConfig: (config.icons && typeof config.icons === "object") ? config.icons : {}
    readonly property string wifiIcon: (typeof iconsConfig.wifi === "string") ? iconsConfig.wifi : ""
    readonly property string ethernetIcon: (typeof iconsConfig.ethernet === "string") ? iconsConfig.ethernet : ""
    readonly property string disconnectedIcon: (typeof iconsConfig.disconnected === "string") ? iconsConfig.disconnected : ""
    readonly property string labelIcon: (typeof config.labelIcon === "string") ? config.labelIcon : wifiIcon

    // WHAT: which network's password field is open. "" = none.
    // WHY: the only state this module owns itself — everything else
    //   comes from `system`.
    property string expandedSsid: ""

    readonly property string connectionType: system ? system.connectionType : "disconnected"
    readonly property string iconGlyph: {
        if (connectionType === "wifi") return wifiIcon
        if (connectionType === "ethernet") return ethernetIcon
        return disconnectedIcon
    }
    readonly property string connectionLabel: {
        if (connectionType === "disconnected") return "Disconnected"
        const name = system ? system.connectionName : ""
        return name.length > 0 ? name : (system ? system.primaryIface : "")
    }

    readonly property color fg: theme ? theme.fgColor : "#cdd6f4"
    readonly property color accent: theme ? theme.accentColor : "#89b4fa"
    readonly property color altBg: theme ? theme.altBgColor : "#15151f"
    readonly property string fontFamily_: theme ? theme.fontFamily : "sans-serif"
    readonly property real baseFontSize: theme ? theme.fontSize : 13

    // WHAT: icon left-click hook (card context only — see ModuleIconSlot.qml).
    // WHY: a plain refresh is a safe default — unlike volume's mute-toggle,
    //   there's no single obvious "primary action" for a network icon that
    //   isn't a little surprising as an accidental-click outcome (connect/
    //   disconnect stay behind explicit card-mode buttons instead).
    function activateIcon() { if (system) system.refreshNetwork() }

    function toggleExpanded(ssid) {
        module.expandedSsid = (module.expandedSsid === ssid) ? "" : ssid
    }
    // WHAT: connect wrappers that also close the password field.
    function connectOpen(ssid) {
        if (system) system.connectWifiOpen(ssid)
        module.expandedSsid = ""
    }
    function connectSecured(ssid, password) {
        if (system) system.connectWifiSecured(ssid, password)
        module.expandedSsid = ""
    }

    function formatRate(bytesPerSec) {
        if (bytesPerSec < 1024) return bytesPerSec.toFixed(0) + " B/s"
        if (bytesPerSec < 1024 * 1024) return (bytesPerSec / 1024).toFixed(1) + " KB/s"
        return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
    }

    implicitWidth: displayMode === "icon" ? iconView.implicitWidth : availableWidth
    implicitHeight: {
        if (displayMode === "icon") return iconView.implicitHeight
        if (displayMode === "widget") return widgetView.implicitHeight
        return cardView.implicitHeight
    }
    width: implicitWidth
    height: implicitHeight

    // ---- icon view ----
    Item {
        id: iconView
        anchors.fill: parent
        visible: module.displayMode === "icon"
        implicitWidth: iconLabel.implicitWidth + 8
        implicitHeight: iconLabel.implicitHeight + 4

        Text {
            id: iconLabel
            anchors.centerIn: parent
            text: module.iconGlyph
            color: module.fg
            font.family: module.fontFamily_
            font.pixelSize: module.baseFontSize * 1.4
        }
    }

    // ---- widget view: icon + label + down/up rate ----
    Item {
        id: widgetView
        width: module.availableWidth
        visible: module.displayMode === "widget"
        implicitHeight: Math.max(widgetIcon.implicitHeight, widgetLabel.implicitHeight, ratesColumn.implicitHeight) + 16

        Text {
            id: widgetIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: module.iconGlyph
            color: module.fg
            font.family: module.fontFamily_
            font.pixelSize: module.baseFontSize * 1.4
        }

        Column {
            id: ratesColumn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: " " + module.formatRate(module.system ? module.system.rxRate : 0)
                color: module.fg
                font.family: module.fontFamily_
                font.pixelSize: module.baseFontSize * 0.8
            }
            Text {
                text: " " + module.formatRate(module.system ? module.system.txRate : 0)
                color: module.fg
                font.family: module.fontFamily_
                font.pixelSize: module.baseFontSize * 0.8
            }
        }

        Text {
            id: widgetLabel
            anchors.left: widgetIcon.right
            anchors.leftMargin: 8
            anchors.right: ratesColumn.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: module.connectionLabel
            color: module.fg
            font.family: module.fontFamily_
            font.pixelSize: module.baseFontSize
            elide: Text.ElideRight
        }
    }

    // ---- card view ----
    Item {
        id: cardView
        width: module.availableWidth
        visible: module.displayMode === "card"
        implicitHeight: cardColumn.implicitHeight

        Column {
            id: cardColumn
            width: module.availableWidth
            spacing: 12

            Row {
                spacing: 6
                Text {
                    text: module.labelIcon
                    color: module.fg
                    font.family: module.fontFamily_
                    font.pixelSize: module.baseFontSize
                }
                Text {
                    text: module.label
                    color: module.fg
                    font.family: module.fontFamily_
                    font.pixelSize: module.baseFontSize
                }
            }

            // ---- status block ----
            Column {
                width: module.availableWidth
                spacing: 4

                Row {
                    spacing: 8
                    Text {
                        text: module.iconGlyph
                        color: module.fg
                        font.family: module.fontFamily_
                        font.pixelSize: module.baseFontSize * 1.4
                    }
                    Text {
                        text: module.connectionLabel
                        color: module.fg
                        font.family: module.fontFamily_
                        font.pixelSize: module.baseFontSize
                        font.bold: true
                    }
                }
                Text {
                    visible: module.connectionType !== "disconnected"
                    text: (module.connectionType === "wifi" ? "Wi-Fi" : "Ethernet") + ((module.system && module.system.ipAddress.length > 0) ? " · " + module.system.ipAddress : "")
                    color: module.accent
                    font.family: module.fontFamily_
                    font.pixelSize: module.baseFontSize * 0.9
                }
                Text {
                    visible: module.connectionType === "wifi" && module.system && module.system.wifiSignal >= 0
                    text: "Signal: " + (module.system ? module.system.wifiSignal.toFixed(0) : "0") + "%"
                    color: module.accent
                    font.family: module.fontFamily_
                    font.pixelSize: module.baseFontSize * 0.9
                }
                Text {
                    text: "Ping (" + (module.system ? module.system.pingHost : "") + "): " + ((module.system && module.system.pingMs >= 0) ? module.system.pingMs.toFixed(0) + " ms" : "—")
                    color: module.accent
                    font.family: module.fontFamily_
                    font.pixelSize: module.baseFontSize * 0.9
                }
            }

            // ---- disconnect ----
            Rectangle {
                visible: module.connectionType !== "disconnected"
                width: disconnectLabel.implicitWidth + 20
                height: disconnectLabel.implicitHeight + 12
                radius: 6
                color: module.altBg
                Text {
                    id: disconnectLabel
                    anchors.centerIn: parent
                    text: "Disconnect"
                    color: module.fg
                    font.family: module.fontFamily_
                    font.pixelSize: module.baseFontSize * 0.9
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: if (module.system) module.system.disconnectPrimaryNetwork()
                }
            }

            // ---- available networks (wifi only, hidden if none found) ----
            Column {
                width: module.availableWidth
                spacing: 6
                visible: module.system && module.system.availableNetworks.length > 0

                Text {
                    text: "Available Networks"
                    color: module.fg
                    font.family: module.fontFamily_
                    font.pixelSize: module.baseFontSize
                    font.bold: true
                }

                Column {
                    width: module.availableWidth
                    spacing: 6

                    Repeater {
                        model: module.system ? module.system.availableNetworks : []
                        delegate: Column {
                            id: netRow
                            required property var modelData
                            width: module.availableWidth
                            spacing: 4

                            Item {
                                width: netRow.width
                                implicitHeight: Math.max(netIcon.implicitHeight, netLabel.implicitHeight) + 8

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Text {
                                        id: netIcon
                                        text: module.wifiIcon
                                        color: netRow.modelData.inUse ? module.accent : module.fg
                                        font.family: module.fontFamily_
                                        font.pixelSize: module.baseFontSize * 1.1
                                    }
                                    Text {
                                        id: netLabel
                                        text: netRow.modelData.ssid + (netRow.modelData.secured ? " " : "") + " (" + netRow.modelData.signal.toFixed(0) + "%)"
                                        color: netRow.modelData.inUse ? module.accent : module.fg
                                        font.family: module.fontFamily_
                                        font.pixelSize: module.baseFontSize * 0.9
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !netRow.modelData.inUse
                                    onClicked: {
                                        if (netRow.modelData.secured) module.toggleExpanded(netRow.modelData.ssid)
                                        else module.connectOpen(netRow.modelData.ssid)
                                    }
                                }
                            }

                            Row {
                                visible: module.expandedSsid === netRow.modelData.ssid
                                spacing: 8
                                width: netRow.width

                                Rectangle {
                                    width: netRow.width - connectButton.width - 8
                                    height: passwordInput.implicitHeight + 8
                                    radius: 4
                                    color: module.altBg

                                    TextInput {
                                        id: passwordInput
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        color: module.fg
                                        font.family: module.fontFamily_
                                        font.pixelSize: module.baseFontSize * 0.9
                                        echoMode: TextInput.Password
                                        clip: true
                                        onAccepted: module.connectSecured(netRow.modelData.ssid, text)
                                    }
                                }

                                Rectangle {
                                    id: connectButton
                                    width: connectLabel.implicitWidth + 16
                                    height: passwordInput.implicitHeight + 8
                                    radius: 4
                                    color: module.altBg
                                    Text {
                                        id: connectLabel
                                        anchors.centerIn: parent
                                        text: "Connect"
                                        color: module.fg
                                        font.family: module.fontFamily_
                                        font.pixelSize: module.baseFontSize * 0.9
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: module.connectSecured(netRow.modelData.ssid, passwordInput.text)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
