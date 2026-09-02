import QtQuick

// Clock module — icon/widget/card views, see modules/template.qml for
// the general module contract. Purely local (`new Date()`, no OS call
// needed) — declares `system` for contract consistency but never reads it.
//
// Config (all optional, moduleSettings["clock"] in config.json):
//   { "format": "hh:mm", "dateFormat": "dddd, MMMM d", "weekStartsOn": "monday" }
//
// NOTE: format/dateFormat use Qt's date-format tokens (hh, mm, dddd,
// MMMM, ..., see Qt.formatDateTime), not strftime.

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

    function activateIcon() {}

    // ---- config, with fallbacks ----
    readonly property string timeFormat: (typeof config.format === "string") ? config.format : "hh:mm"
    readonly property string dateFormat: (typeof config.dateFormat === "string") ? config.dateFormat : "dddd, MMMM d"
    readonly property string weekStartsOn: (config.weekStartsOn === "sunday") ? "sunday" : "monday"

    // ---- ticking clock ----
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: module.now = new Date()
    }
    readonly property string timeText: Qt.formatDateTime(now, timeFormat)
    readonly property string dateText: Qt.formatDateTime(now, dateFormat)

    // ---- calendar (card mode) ----
    readonly property int currentYear: now.getFullYear()
    readonly property int currentMonth: now.getMonth()
    readonly property int today: now.getDate()
    readonly property var weekdayLabels: weekStartsOn === "monday"
        ? ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
        : ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    // null cells pad the grid out to a whole number of weeks
    function buildCalendarCells() {
        const firstWeekday = new Date(currentYear, currentMonth, 1).getDay()   // 0=Sun..6=Sat
        const leadingBlanks = weekStartsOn === "monday" ? ((firstWeekday + 6) % 7) : firstWeekday
        const daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate()

        const cells = []
        for (let i = 0; i < leadingBlanks; i++) cells.push(null)
        for (let d = 1; d <= daysInMonth; d++) cells.push(d)
        while (cells.length % 7 !== 0) cells.push(null)
        return cells
    }
    readonly property var calendarCells: buildCalendarCells()

    readonly property color fg: theme ? theme.fgColor : "#cdd6f4"
    readonly property color accent: theme ? theme.accentColor : "#89b4fa"
    readonly property color bg: theme ? theme.bgColor : "#1e1e2e"
    readonly property string fontFamily_: theme ? theme.fontFamily : "sans-serif"
    readonly property real baseFontSize: theme ? theme.fontSize : 13

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
            text: module.timeText
            color: module.fg
            font.family: module.fontFamily_
            font.pixelSize: module.baseFontSize
            font.bold: theme ? theme.fontBold : false
        }
    }

    // ---- widget view ----
    Item {
        id: widgetView
        width: module.availableWidth
        visible: module.displayMode === "widget"
        implicitHeight: widgetColumn.implicitHeight + 24

        Column {
            id: widgetColumn
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: module.timeText
                color: module.fg
                font.family: module.fontFamily_
                font.pixelSize: module.baseFontSize * 2.2
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: module.dateText
                color: module.accent
                font.family: module.fontFamily_
                font.pixelSize: module.baseFontSize
            }
        }
    }

    // ---- card view: header + calendar ----
    Item {
        id: cardView
        width: module.availableWidth
        visible: module.displayMode === "card"
        implicitHeight: cardColumn.implicitHeight

        Column {
            id: cardColumn
            width: parent.width
            spacing: 16

            Column {
                width: parent.width
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: module.timeText
                    color: module.fg
                    font.family: module.fontFamily_
                    font.pixelSize: module.baseFontSize * 2.4
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: module.dateText
                    color: module.accent
                    font.family: module.fontFamily_
                    font.pixelSize: module.baseFontSize
                }
            }

            Column {
                width: parent.width
                spacing: 4

                Row {
                    width: parent.width
                    Repeater {
                        model: module.weekdayLabels
                        delegate: Text {
                            required property string modelData
                            width: parent.width / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: module.accent
                            font.family: module.fontFamily_
                            font.pixelSize: module.baseFontSize * 0.85
                            font.bold: true
                        }
                    }
                }

                Grid {
                    width: parent.width
                    columns: 7

                    Repeater {
                        model: module.calendarCells
                        delegate: Item {
                            required property var modelData
                            width: parent.width / 7
                            height: width

                            readonly property bool isToday: modelData !== null && modelData === module.today

                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height) - 6
                                height: width
                                radius: width / 2
                                visible: parent.isToday
                                color: module.accent
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: modelData !== null
                                text: modelData !== null ? modelData : ""
                                color: parent.isToday ? module.bg : module.fg
                                font.family: module.fontFamily_
                                font.pixelSize: module.baseFontSize
                            }
                        }
                    }
                }
            }
        }
    }
}
