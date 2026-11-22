import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: root

    property var currentNotification: null

    NotificationServer {
        id: server
        bodySupported: true

        onNotification: notification => {
            notification.tracked = true

            if (root.currentNotification !== null)
                root.currentNotification.expire()

            root.currentNotification = notification
            hideTimer.restart()
        }
    }

    Connections {
        target: root.currentNotification
        ignoreUnknownSignals: true

        function onClosed() {
            root.currentNotification = null
            hideTimer.stop()
        }
    }

    Timer {
        id: hideTimer
        interval: 5000
        repeat: false

        onTriggered: {
            if (root.currentNotification !== null)
                root.currentNotification.expire()
        }
    }

    PanelWindow {
        visible: root.currentNotification !== null

        WlrLayershell.namespace: "HyprGlass"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        margins.top: 16

        implicitWidth: 420
        implicitHeight: contents.implicitHeight + 28

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: false

        Rectangle {
            anchors.fill: parent
            color: "#22000000"
            radius: 0
            border.width: 0

            Column {
                id: contents
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 14
                }
                spacing: 6

                Text {
                    width: parent.width
                    text: root.currentNotification !== null
                        ? (root.currentNotification.summary || root.currentNotification.appName)
                        : ""
                    color: Style.textColor
                    font.family: Style.fontFamily
                    font.bold: true
                    font.pixelSize: 15
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.currentNotification !== null ? root.currentNotification.body : ""
                    visible: text.length > 0
                    color: Style.textColor
                    font.family: Style.monoFontFamily
                    font.pixelSize: 13
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.currentNotification !== null)
                        root.currentNotification.dismiss()
                }
            }
        }
    }
}
