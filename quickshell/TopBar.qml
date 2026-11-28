import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

Scope {
    id: root
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || null
    readonly property string track: player ? [player.trackTitle, player.trackArtist].filter(v => v).join("  —  ") : "Hi, " + (Quickshell.env("USER") || Quickshell.env("LOGNAME") || Quickshell.env("HOME").split("/").pop())
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: panel
            required property var modelData
            readonly property var monitor: Hyprland.monitorFor(screen)
            readonly property var workspaces: Hyprland.workspaces.values
                .filter(ws => ws.id > 0 && monitor !== null && ws.monitor === monitor)
                .sort((a, b) => a.id - b.id)
            readonly property var workspaceStates: workspaces.map(ws => ({
                workspaceId: ws.id,
                current: ws.active
            }))

            ListModel {
                id: workspaceModel
            }

            function syncWorkspaces() {
                if (!workspaceModel)
                    return

                const states = workspaceStates
                for (let i = 0; i < workspaceModel.count; ++i) {
                    const id = workspaceModel.get(i).workspaceId
                    const state = states.find(ws => ws.workspaceId === id)
                    if (state) {
                        workspaceModel.setProperty(i, "current", state.current)
                        workspaceModel.setProperty(i, "present", true)
                    } else {
                        workspaceModel.setProperty(i, "present", false)
                    }
                }

                for (const state of states) {
                    let i = 0
                    while (i < workspaceModel.count &&
                           workspaceModel.get(i).workspaceId < state.workspaceId)
                        ++i
                    if (i === workspaceModel.count ||
                        workspaceModel.get(i).workspaceId !== state.workspaceId) {
                        workspaceModel.insert(i, {
                            workspaceId: state.workspaceId,
                            current: state.current,
                            present: true
                        })
                    }
                }
            }

            function removeWorkspace(id) {
                for (let i = 0; i < workspaceModel.count; ++i) {
                    const entry = workspaceModel.get(i)
                    if (entry.workspaceId === id && !entry.present) {
                        workspaceModel.remove(i)
                        return
                    }
                }
            }

            onWorkspaceStatesChanged: syncWorkspaces()
            Component.onCompleted: syncWorkspaces()

            screen: modelData
            WlrLayershell.namespace: "quickshell:topbar"
            WlrLayershell.layer: WlrLayer.Top
            anchors { top: true; left: true; right: true }
            implicitHeight: 22
            exclusiveZone: 22
            color: Style.transparentColor
            focusable: false
            mask: Region {}

            BarItem {
                id: dateItem
                anchors.left: parent.left
                anchors.top: parent.top
                width: dateText.implicitWidth + 40
                flushLeft: true
                height: parent.height
                source: Style.panelBackground
                Text {
                    id: dateText
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -7
                    text: Qt.formatDateTime(clock.date, "ddd, MMM d hh:mm")
                    font.family: Style.fontFamily
                    font.pixelSize: Style.barFontSize
                    font.bold: true
                    color: Style.darkTextColor
                }
            }
            Row {
                id: workspaceRow
                readonly property real chipGap: 3
                anchors.left: dateItem.right
                anchors.leftMargin: chipGap - dateItem.sideInset
                anchors.top: parent.top
                height: parent.height

                Repeater {
                    model: workspaceModel

                    delegate: Item {
                        id: tile
                        required property int workspaceId
                        required property bool current
                        required property bool present

                        property bool initialized: false
                        property real presence: initialized && present ? 1 : 0
                        property real numberWidth: current ? 80 : 50

                        width: (numberWidth + workspaceRow.chipGap) * presence
                        height: workspaceRow.height

                        Component.onCompleted: initialized = true

                        Behavior on presence {
                            NumberAnimation {
                                duration: Style.fastAnimationDuration
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on numberWidth {
                            NumberAnimation {
                                duration: Style.fastAnimationDuration
                                easing.type: Easing.OutCubic
                            }
                        }

                        Timer {
                            interval: Style.fastAnimationDuration + 20
                            running: !tile.present
                            onTriggered: panel.removeWorkspace(tile.workspaceId)
                        }

                        BarItem {
                            id: workspaceItem
                            parallelSides: true
                            sideInset: dateItem.sideInset
                            width: sideInset + tile.numberWidth * tile.presence
                            height: tile.height
                            opacity: tile.presence
                            visible: opacity > 0
                            source: dateItem.source
                            backgroundOffsetX: workspaceRow.x + tile.x - dateItem.x

                            Text {
                                anchors.centerIn: parent
                                text: String(tile.workspaceId)
                                color: Style.darkTextColor
                                font.family: Style.fontFamily
                                font.pixelSize: Style.barFontSize
                                font.bold: true
                                font.italic: true
                                opacity: tile.current ? 1 : 0.72

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Style.fastAnimationDuration
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }
            }

            BarItem {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                readonly property real leftEnd: dateItem.width + workspaceRow.width
                readonly property real maxWidth: Math.max(0, Math.min(
                    300, parent.width * 0.42, parent.width - 2 * (leftEnd + 4),
                    2 * batteryItem.x - parent.width - 8))
                visible: width >= 60
                readonly property real contentWidth: root.player
                    ? playingIcon.implicitWidth + 6 + staticTrack.implicitWidth
                    : idleRow.implicitWidth
                width: Math.min(maxWidth, Math.ceil(contentWidth) + 48)
                height: parent.height
                source: Style.panelBackground

                Text {
                    id: playingIcon
                    visible: root.player !== null
                    x: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰝚"
                    font.family: Style.iconFontFamily
                    font.pixelSize: Style.iconFontSize
                    color: Style.darkTextColor
                }
                Item {
                    id: viewport
                    anchors.left: parent.left
                    anchors.leftMargin: root.player ? playingIcon.x + playingIcon.width + 6 : 24
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    clip: true
                    property real offset: 0
                    readonly property bool scrolling: root.player !== null && staticTrack.implicitWidth > width
                    onScrollingChanged: offset = 0
                    Connections {
                        target: root
                        function onTrackChanged() { viewport.offset = 0 }
                    }
                    Row {
                        id: idleRow
                        visible: root.player === null
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰝛"
                            font.family: Style.iconFontFamily
                            font.pixelSize: Style.iconFontSize
                            color: Style.darkTextColor
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.track
                            color: Style.darkTextColor
                            font.family: Style.fontFamily
                            font.pixelSize: Style.barFontSize
                            font.bold: true
                            textFormat: Text.PlainText
                        }
                    }

                    Text {
                        id: staticTrack
                        visible: root.player !== null && !viewport.scrolling
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.track
                        color: Style.darkTextColor
                        font.family: Style.fontFamily
                        font.pixelSize: Style.barFontSize
                        font.bold: true
                        textFormat: Text.PlainText
                    }

                    Canvas {
                        id: marquee
                        anchors.fill: parent
                        visible: viewport.scrolling
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onVisibleChanged: requestPaint()

                        Connections {
                            target: viewport
                            function onOffsetChanged() { marquee.requestPaint() }
                        }
                        Connections {
                            target: root
                            function onTrackChanged() { marquee.requestPaint() }
                        }

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.clearRect(0, 0, width, height)
                            if (!viewport.scrolling || width <= 0)
                                return
                            ctx.font = "bold " + Style.barFontSize + "px '" + Style.fontFamily + "'"
                            ctx.textBaseline = "middle"
                            ctx.fillStyle = Style.darkTextColor
                            const period = Math.max(1, ctx.measureText(root.track).width + 36)
                            const offset = viewport.offset % period
                            for (let x = -offset; x < width; x += period)
                                ctx.fillText(root.track, x, height / 2)
                            const fade = Math.min(18, width / 2)
                            const gradient = ctx.createLinearGradient(0, 0, width, 0)
                            gradient.addColorStop(0, Style.transparentColor)
                            gradient.addColorStop(fade / width, Style.maskOpaqueColor)
                            gradient.addColorStop(1 - fade / width, Style.maskOpaqueColor)
                            gradient.addColorStop(1, Style.transparentColor)
                            ctx.globalCompositeOperation = "destination-in"
                            ctx.fillStyle = gradient
                            ctx.fillRect(0, 0, width, height)
                            ctx.globalCompositeOperation = "source-over"
                        }
                    }
                    Timer {
                        interval: 16
                        repeat: true
                        running: viewport.scrolling && root.track.length > 0
                        onTriggered: viewport.offset = viewport.offset + 0.55
                    }
                }
            }
            BarItem {
                id: batteryItem
                anchors.right: parent.right
                anchors.top: parent.top
                width: batteryText.implicitWidth + 40
                flushRight: true
                height: parent.height
                source: Style.panelBackground
                Text {
                    id: batteryText
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 7
                    text: UPower.displayDevice && UPower.displayDevice.ready
                        ? Math.round(UPower.displayDevice.percentage * 100) + "%"
                        : "—%"
                    color: Style.darkTextColor
                    font.family: Style.fontFamily
                    font.pixelSize: Style.barFontSize
                    font.bold: true
                }
            }
        }
    }
}
