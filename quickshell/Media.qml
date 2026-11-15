
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root

    readonly property var player: Mpris.players.values.find(
        p => p.dbusName === "org.mpris.MediaPlayer2.spotify"
    ) ?? null

    readonly property string albumArt: {
        if (!player)
            return ""

            const url = player.trackArtUrl || ""

            return url.replace(
                /ab67616d0000(?:4851|745c|1e02|f848)/,
                               "ab67616d0000b273"
            )
    }

    visible: player !== null

    implicitWidth: contentRow.implicitWidth + 24
    implicitHeight: contentRow.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#04000000"
        border.color: "#80ffffff"
        border.width: 2

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 8
            blur: 0.2

            shadowEnabled: true
            shadowColor: "#ff000000"
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 3
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 12

        Item {
            id: cover
            width: 72
            height: 72
            z: 1

            Rectangle {
                id: coverMask
                anchors.fill: parent
                radius: 10
                color: "#ffffff"
                visible: false
                layer.enabled: true
            }

            Image {
                id: coverImage
                anchors.fill: parent
                source: root.albumArt
                fillMode: Image.PreserveAspectCrop

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: coverMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: "transparent"
                border.color: "#80ffffff"
                border.width: 2

                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 8
                    blur: 0.2

                    shadowEnabled: true
                    shadowColor: "#ff000000"
                    shadowBlur: 0.5
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 3
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Item {
                id: titleSlot
                width: controlsRow.width
                height: 20

                transform: Translate {
                    y: 5
                }

                Item {
                    id: titleViewport

                    readonly property real leftInset: contentRow.spacing

                    x: -leftInset
                    width: titleSlot.width + leftInset
                    height: parent.height
                    clip: true

                    Text {
                        id: songTitle

                        text: {
                            if (!root.player)
                                return ""

                                const artist = root.player.trackArtist || ""
                                const title = root.player.trackTitle || ""

                                return artist && title
                                ? artist + " - " + title
                                : artist || title
                        }

                        font.pixelSize: 14
                        color: "#80ffffff"

                        x: titleViewport.leftInset
                        + Math.max(
                            0,
                            (titleSlot.width - paintedWidth) / 2
                        )

                        y: (titleViewport.height - height) / 2

                        transform: Translate {
                            id: titleScroll
                            x: 0
                        }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blurMax: 8
                            blur: 0.2

                            shadowEnabled: true
                            shadowColor: "#ff000000"
                            shadowBlur: 0.5
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 3
                        }

                        onTextChanged: {
                            Qt.callLater(function() {
                                if (marqueeAnimation.running)
                                    marqueeAnimation.restart()
                            })
                        }
                    }

                    NumberAnimation {
                        id: marqueeAnimation

                        target: titleScroll
                        property: "x"

                        from: titleSlot.width
                        to: -songTitle.paintedWidth
                        - titleViewport.leftInset

                        duration: Math.max(
                            1500,
                            (titleViewport.width + songTitle.paintedWidth) * 40
                        )

                        loops: Animation.Infinite

                        running: root.player !== null
                        && songTitle.paintedWidth > titleSlot.width

                        easing.type: Easing.Linear

                        onRunningChanged: {
                            if (!running)
                                titleScroll.x = 0
                        }
                    }
                }
            }

            Row {
                id: controlsRow
                spacing: 12

                Text {
                    width: 36
                    text: "⏮"
                    font.pixelSize: 28
                    color: "#80ffffff"
                    horizontalAlignment: Text.AlignHCenter

                    scale: previousMouse.pressed ? 0.9 :
                    previousMouse.containsMouse ? 1.15 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 8
                        blur: 0.2

                        shadowEnabled: true
                        shadowColor: "#ff000000"
                        shadowBlur: 0.5
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 3
                    }

                    MouseArea {
                        id: previousMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.player && root.player.canGoPrevious
                        onClicked: root.player.previous()
                    }
                }

                Text {
                    width: 36
                    text: root.player && root.player.isPlaying ? "⏸" : "▶"
                    font.pixelSize: 28
                    color: "#80ffffff"
                    horizontalAlignment: Text.AlignHCenter

                    scale: playMouse.pressed ? 0.9 :
                    playMouse.containsMouse ? 1.15 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 8
                        blur: 0.2

                        shadowEnabled: true
                        shadowColor: "#ff000000"
                        shadowBlur: 0.5
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 3
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.player && root.player.canTogglePlaying
                        onClicked: root.player.togglePlaying()
                    }
                }

                Text {
                    width: 36
                    text: "⏭"
                    font.pixelSize: 28
                    color: "#80ffffff"
                    horizontalAlignment: Text.AlignHCenter

                    scale: nextMouse.pressed ? 0.9 :
                    nextMouse.containsMouse ? 1.15 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 8
                        blur: 0.2

                        shadowEnabled: true
                        shadowColor: "#ff000000"
                        shadowBlur: 0.5
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 3
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.player && root.player.canGoNext
                        onClicked: root.player.next()
                    }
                }
            }
        }
    }
}
