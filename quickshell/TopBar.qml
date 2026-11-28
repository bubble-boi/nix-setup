import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

Scope {
    id: root
    readonly property url itemBackground: "file://" + Quickshell.env("HOME") + "/.local/share/img/item_bg.png"
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || null
    readonly property string track: player ? [player.trackTitle, player.trackArtist].filter(v => v).join("  —  ") : "Hi, " + (Quickshell.env("USER") || Quickshell.env("LOGNAME") || Quickshell.env("HOME").split("/").pop())
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "quickshell:topbar"
            WlrLayershell.layer: WlrLayer.Top
            anchors { top: true; left: true; right: true }
            implicitHeight: 22
            exclusiveZone: 22
            color: "transparent"
            focusable: false
            mask: Region {}

            BarItem {
                anchors.left: parent.left
                anchors.top: parent.top
                width: dateText.implicitWidth + 40
                flushLeft: true
                height: parent.height
                source: root.itemBackground
                Text {
                    id: dateText
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -7
                    text: Qt.formatDateTime(clock.date, "ddd, MMM d hh:mm")
                    font.family: Style.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: "#000000"
                }
            }
            BarItem {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                readonly property real maxWidth: Math.min(300, parent.width * 0.42)
                readonly property real contentWidth: root.player
                    ? playingIcon.implicitWidth + 6 + staticTrack.implicitWidth
                    : idleRow.implicitWidth
                width: Math.min(maxWidth, Math.ceil(contentWidth) + 48)
                height: parent.height
                source: root.itemBackground

                Text {
                    id: playingIcon
                    visible: root.player !== null
                    x: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰝚"
                    font.family: "ProFont Nerd Font"
                    font.pixelSize: 13
                    color: "#000000"
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
                            font.family: "ProFont Nerd Font"
                            font.pixelSize: 13
                            color: "#000000"
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.track
                            color: "#000000"
                            font.family: Style.fontFamily
                            font.pixelSize: 11
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
                        color: "#000000"
                        font.family: Style.fontFamily
                        font.pixelSize: 11
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
                            ctx.font = "bold 11px '" + Style.fontFamily + "'"
                            ctx.textBaseline = "middle"
                            ctx.fillStyle = "#000000"
                            const period = Math.max(1, ctx.measureText(root.track).width + 36)
                            const offset = viewport.offset % period
                            for (let x = -offset; x < width; x += period)
                                ctx.fillText(root.track, x, height / 2)
                            const fade = Math.min(18, width / 2)
                            const gradient = ctx.createLinearGradient(0, 0, width, 0)
                            gradient.addColorStop(0, "transparent")
                            gradient.addColorStop(fade / width, "white")
                            gradient.addColorStop(1 - fade / width, "white")
                            gradient.addColorStop(1, "transparent")
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
                anchors.right: parent.right
                anchors.top: parent.top
                width: batteryText.implicitWidth + 40
                flushRight: true
                height: parent.height
                source: root.itemBackground
                Text {
                    id: batteryText
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 7
                    text: UPower.displayDevice && UPower.displayDevice.ready
                        ? Math.round(UPower.displayDevice.percentage * 100) + "%"
                        : "—%"
                    color: "#000000"
                    font.family: Style.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }
}
