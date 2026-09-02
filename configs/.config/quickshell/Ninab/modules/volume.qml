import QtQuick
import ".."   // ModuleSlider.qml lives at the repo root, one level up from modules/

// Volume module — output/mic sliders + a live per-app volume list. All
// data/actions come from logic/System.qml; see modules/template.qml for
// the general module contract.
//
// Config (moduleSettings["volume"] in config.json), all optional:
//   {
//     "sliders": [              // one entry per known control; order = display order
//       {
//         "id": "volume",       // or "mic" — anything else is parsed but ignored
//         "icon": "",
//         "mutedIcon": "",
//         "label": "Volume",
//         "labelIcon": ""
//       }
//     ],
//     "apps": {                 // the per-app "Applications" group, card mode only
//       "enabled": true,
//       "label": "Applications",
//       "labelIcon": "",
//       "icon": "",       // generic per-row icon — individual apps don't have their own
//       "mutedIcon": ""
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

    // WHAT: this module's own display config — icon/label per known id.
    // WHY: presentation only; the live values/actions behind each id
    //   come from `system`, not from anything parsed here.
    function isArrayLike(value) {
        return !!value && typeof value.length === "number" && typeof value.filter === "function"
    }
    readonly property var defaultSliders: [
        { id: "volume", icon: "", mutedIcon: "", label: "Volume", labelIcon: "" },
        { id: "mic", icon: "", mutedIcon: "", label: "Microphone", labelIcon: "" }
    ]
    readonly property var sliderEntries: {
        if (!isArrayLike(config.sliders)) return defaultSliders
        const parsed = config.sliders
            .filter(v => v && typeof v === "object" && typeof v.id === "string")
            .map(v => ({
                id: v.id,
                icon: (typeof v.icon === "string") ? v.icon : "",
                mutedIcon: (typeof v.mutedIcon === "string") ? v.mutedIcon : "",
                label: (typeof v.label === "string") ? v.label : "",
                labelIcon: (typeof v.labelIcon === "string") ? v.labelIcon : ""
            }))
        return parsed.length > 0 ? parsed : defaultSliders
    }
    readonly property var volumeEntry: sliderEntries.find(s => s.id === "volume") || defaultSliders[0]
    // WHAT: which entries widget/card actually render.
    // WHY: only "volume"/"mic" have a real data source in System right
    //   now; anything else in config.json is parsed but skipped rather
    //   than shown as a dead control.
    readonly property var knownEntries: sliderEntries.filter(s => s.id === "volume" || s.id === "mic")

    readonly property string iconGlyph: (system && system.showMutedFor("volume")) ? volumeEntry.mutedIcon : volumeEntry.icon

    // WHAT: thin, null-safe passthrough to System's id-based dispatch.
    // WHY: lets SliderControlRow below stay oblivious to where "volume"/
    //   "mic"/an app-stream-id's value actually comes from.
    function valueFor(id) { return system ? system.valueFor(id) : 0 }
    function showMutedFor(id) { return system ? system.showMutedFor(id) : false }
    function setValueFor(id, v) { if (system) system.setValueFor(id, v) }
    function toggleMuteFor(id) { if (system) system.toggleMuteFor(id) }

    // WHAT: icon left-click hook (card context only — see ModuleIconSlot.qml).
    // WHY: mute-toggle is the standard tray-icon action for a volume module.
    function activateIcon() { if (system) system.toggleMute() }

    readonly property color fg: theme ? theme.fgColor : "#cdd6f4"
    readonly property color altBg: theme ? theme.altBgColor : "#15151f"
    readonly property string fontFamily_: theme ? theme.fontFamily : "sans-serif"
    readonly property real baseFontSize: theme ? theme.fontSize : 13

    // WHAT: slider look, sourced from Theme, not this module.
    // WHY: standalone/global style — every module's ModuleSlider shares
    //   it instead of picking its own height/radius/knob.
    readonly property real sliderHeight: theme ? theme.sliderHeight : 14
    readonly property real sliderCornerRadius: theme ? theme.sliderCornerRadius : sliderHeight / 2
    readonly property bool sliderShowKnob: theme ? theme.sliderShowKnob : false

    // WHAT: this module's own display config for the Applications group.
    readonly property var appsConfig: (config.apps && typeof config.apps === "object") ? config.apps : {}
    readonly property bool appsEnabled: (typeof appsConfig.enabled === "boolean") ? appsConfig.enabled : true
    readonly property string appsLabel: (typeof appsConfig.label === "string") ? appsConfig.label : "Applications"
    readonly property string appsLabelIcon: (typeof appsConfig.labelIcon === "string") ? appsConfig.labelIcon : ""
    readonly property string appIcon: (typeof appsConfig.icon === "string") ? appsConfig.icon : ""
    readonly property string appMutedIcon: (typeof appsConfig.mutedIcon === "string") ? appsConfig.mutedIcon : ""
    // WHAT: who's currently streaming — straight passthrough from System.
    readonly property var appStreamMeta: system ? system.appStreamMeta : []

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

    // WHAT: reusable icon+slider row, parameterized by id.
    // WHY: one component covers widget mode (bare), card mode (with a
    //   caption above it), and every Applications-group row, instead of
    //   three near-duplicate blocks of QML.
    // NOTE: QML inline components must be declared at the file's top
    //   level, not nested inside another object's children.
    component SliderControlRow: Item {
        id: controlRow
        required property string sliderId
        required property string sliderIcon
        required property string sliderMutedIcon
        width: module.availableWidth
        implicitHeight: Math.max(rowIcon.implicitHeight, rowSlider.height)

        Text {
            id: rowIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: module.showMutedFor(controlRow.sliderId) ? controlRow.sliderMutedIcon : controlRow.sliderIcon
            color: module.fg
            font.family: module.fontFamily_
            font.pixelSize: module.baseFontSize * 1.4
        }

        ModuleSlider {
            id: rowSlider
            anchors.left: rowIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            barHeight: module.sliderHeight
            cornerRadius: module.sliderCornerRadius
            showKnob: module.sliderShowKnob
            trackColor: module.altBg
            fillColor: module.fg
            value: module.valueFor(controlRow.sliderId)
            onMoved: v => module.setValueFor(controlRow.sliderId, v)
            onCommitted: v => module.setValueFor(controlRow.sliderId, v)
        }
    }

    // ---- widget view: one row per known slider entry ----
    // WHAT: icon + slider only, no label — an icon alone reads fine at
    //   widget size (labels live in card mode instead).
    // NOTE: plain Item wrapper, not a Column, so implicitHeight reads off
    //   widgetColumn the same way the rest of this file sizes things —
    //   Column/Row/Flow (unlike a plain Item) already auto-follow their
    //   own implicit size.
    Item {
        id: widgetView
        width: module.availableWidth
        visible: module.displayMode === "widget"
        implicitHeight: widgetColumn.implicitHeight

        Column {
            id: widgetColumn
            width: module.availableWidth
            spacing: 10

            Repeater {
                model: module.knownEntries
                delegate: SliderControlRow {
                    required property var modelData
                    sliderId: modelData.id
                    sliderIcon: modelData.icon
                    sliderMutedIcon: modelData.mutedIcon
                }
            }
        }
    }

    // ---- card view: known entries with captions, then Applications ----
    Item {
        id: cardView
        width: module.availableWidth
        visible: module.displayMode === "card"
        implicitHeight: cardColumn.implicitHeight

        Column {
            id: cardColumn
            width: module.availableWidth
            spacing: 16

            Repeater {
                model: module.knownEntries
                delegate: Column {
                    id: sliderSection
                    required property var modelData
                    width: module.availableWidth
                    spacing: 6

                    Row {
                        spacing: 6
                        visible: sliderSection.modelData.label.length > 0
                        Text {
                            text: sliderSection.modelData.labelIcon
                            color: module.fg
                            font.family: module.fontFamily_
                            font.pixelSize: module.baseFontSize
                        }
                        Text {
                            text: sliderSection.modelData.label
                            color: module.fg
                            font.family: module.fontFamily_
                            font.pixelSize: module.baseFontSize
                        }
                    }

                    SliderControlRow {
                        sliderId: sliderSection.modelData.id
                        sliderIcon: sliderSection.modelData.icon
                        sliderMutedIcon: sliderSection.modelData.mutedIcon
                    }
                }
            }

            // WHAT: one row per currently-playing app stream.
            // WHY: hidden entirely when empty rather than showing a dead
            //   section.
            // AI: this Repeater's model MUST stay appStreamMeta (id+name
            //   only, stable) and never a list with per-row volume baked
            //   in — that shape change once made every drag on an app
            //   slider destroy/recreate the row on each pointer-move tick
            //   (a new array every tick -> Repeater has no fine-grained
            //   diffing for a plain var model -> full rebuild -> dragged
            //   MouseArea loses its pressed state after one move). Live
            //   value comes from valueFor(id)/setValueFor(id, v) instead,
            //   same as the volume/mic rows above.
            Column {
                width: module.availableWidth
                spacing: 6
                visible: module.appsEnabled && module.appStreamMeta.length > 0

                Row {
                    spacing: 6
                    Text {
                        text: module.appsLabelIcon
                        color: module.fg
                        font.family: module.fontFamily_
                        font.pixelSize: module.baseFontSize
                    }
                    Text {
                        text: module.appsLabel
                        color: module.fg
                        font.family: module.fontFamily_
                        font.pixelSize: module.baseFontSize
                    }
                }

                Column {
                    width: module.availableWidth
                    spacing: 10

                    Repeater {
                        model: module.appStreamMeta
                        delegate: Column {
                            id: appRow
                            required property var modelData
                            width: module.availableWidth
                            spacing: 4

                            Text {
                                width: parent.width
                                text: appRow.modelData.name
                                color: module.fg
                                font.family: module.fontFamily_
                                font.pixelSize: module.baseFontSize * 0.9
                                elide: Text.ElideRight
                            }

                            SliderControlRow {
                                sliderId: appRow.modelData.id
                                sliderIcon: module.appIcon
                                sliderMutedIcon: module.appMutedIcon
                            }
                        }
                    }
                }
            }
        }
    }
}
