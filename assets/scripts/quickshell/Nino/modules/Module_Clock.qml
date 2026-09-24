import QtQuick
import Quickshell
import "../presentation"
import "../services"

// Time and date. View 0 is the icon (time alone), view 2 the widget (time
// over date), view 1 the takeover — the same two lines above a calendar of
// the current month.
ModuleBase {
    id: root

    defaultView: 0
    viewNames: ({ icon: 0, takeover: 1, widget: 2 })

    optionsSchema: ({
        type: "object",
        fields: {
            view: { type: "string", default: "" },
            timeFormat: { type: "string", default: "hh:mm" },
            dateFormat: { type: "string", default: "ddd, MMM d" },
            // Shown before the time in the widget view, when non-empty.
            icon: { type: "string", default: "" },
            clicks: { type: "opaque" }
        }
    })

    // Native, and only wakes when the minute actually changes — a one-second
    // Timer would tick sixty times for every visible change.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property string timeText: Qt.formatDateTime(clock.date, options.timeFormat)
    readonly property string dateText: Qt.formatDateTime(clock.date, options.dateFormat)

    views: ({
        0: { delegate: iconView },
        1: { minHeight: 120, maxHeight: 420, delegate: takeoverView },
        2: { minWidth: 62, minHeight: 30, maxHeight: 40, delegate: widgetView }
    })

    // Clicks the config routes here act locally; everything else it names
    // goes upward as an ordinary command.
    function performLocally(action) {
        if (action !== "copyDate") return false;
        return ClipboardService.copy(dateText);
    }

    Component {
        id: iconView

        // Sizes itself, both ways: the text states its point size and the
        // host lays out against whatever that comes to.
        Text {
            text: root.timeText
            color: root.theme.text || "#ffffff"
            font.family: root.theme.font || "sans-serif"
            font.bold: root.theme.bold || false
            font.pixelSize: root.iconSizing
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Component {
        id: widgetView

        // The wrapper reports what the column comes to while letting it sit
        // centred in whatever width the host hands over.
        Item {
            implicitWidth: column.implicitWidth
            implicitHeight: column.implicitHeight

            Column {
                id: column
                anchors.centerIn: parent
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (root.options.icon ? root.options.icon + " " : "") + root.timeText
                    color: root.theme.text || "#ffffff"
                    font.family: root.theme.font || "sans-serif"
                    font.bold: root.theme.bold || false
                    font.pixelSize: (root.theme.fontSize || 12) * 1.4
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.dateText
                    color: root.theme.accent || "#87af5f"
                    font.family: root.theme.font || "sans-serif"
                    font.pixelSize: root.theme.fontSize || 12
                }
            }
        }
    }

    // The month laid out the ordinary way: seven day-name headers, then as
    // many blank cells as the 1st is days into the week, then one cell per
    // day. Needs no date arithmetic beyond what a plain Date already gives:
    // day 0 of next month is the last day of this one.
    Component {
        id: takeoverView

        Item {
            id: takeover

            // What the calendar actually comes to, so the host can give it
            // that much room and scroll over it. Declaring a minimum and
            // leaving the rest to chance is what had the module after this
            // one drawn on top of the grid.
            implicitWidth: grid.implicitWidth
            implicitHeight: grid.y + grid.height

            readonly property date today: clock.date
            readonly property int year: today.getFullYear()
            readonly property int month: today.getMonth()
            readonly property int firstWeekday: new Date(year, month, 1).getDay()
            readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
            readonly property real baseSize: root.theme.fontSize || 12

            // Shrinks to whatever width the host granted rather than
            // overflowing it: the card this usually lands in is narrow.
            readonly property real cellSize: width > 0
                ? Math.min(baseSize * 2.4, (width - grid.columnSpacing * 6) / 7)
                : baseSize * 2.4

            Column {
                id: header
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.timeText
                    color: root.theme.text || "#ffffff"
                    font.family: root.theme.font || "sans-serif"
                    font.bold: root.theme.bold || false
                    font.pixelSize: takeover.baseSize * 2.2
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.dateText
                    color: root.theme.accent || "#87af5f"
                    font.family: root.theme.font || "sans-serif"
                    font.pixelSize: takeover.baseSize * 1.2
                }
            }

            Grid {
                id: grid
                anchors.top: header.bottom
                anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 7
                rowSpacing: 4
                columnSpacing: 4

                readonly property var dayNames: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

                Repeater {
                    model: grid.dayNames

                    Text {
                        required property var modelData
                        width: takeover.cellSize
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: root.theme.accent || "#87af5f"
                        font.family: root.theme.font || "sans-serif"
                        font.pixelSize: takeover.baseSize * 0.8
                        font.bold: true
                    }
                }

                Repeater {
                    model: takeover.firstWeekday
                    Item {
                        width: takeover.cellSize
                        height: takeover.cellSize
                    }
                }

                Repeater {
                    model: takeover.daysInMonth

                    Rectangle {
                        required property int index
                        readonly property int day: index + 1
                        readonly property bool isToday: day === takeover.today.getDate()

                        width: takeover.cellSize
                        height: takeover.cellSize
                        radius: width / 2
                        color: isToday ? (root.theme.accent || "#87af5f") : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: parent.day
                            color: parent.isToday ? (root.theme.background || "#282828")
                                                  : (root.theme.text || "#ffffff")
                            font.family: root.theme.font || "sans-serif"
                            font.pixelSize: takeover.baseSize * 0.9
                        }
                    }
                }
            }
        }
    }
}
