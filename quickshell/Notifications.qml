import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: root

    property var currentNotification: null
    property bool panelShown: false
    property var dismissAfterAnimation: null

    function hideNotification(dismiss = false) {
        if (!panelShown)
            return

        if (dismiss)
            dismissAfterAnimation = currentNotification

        showAnimation.stop()
        hideAnimation.from = slideTranslation.y
        hideAnimation.start()
    }
    readonly property int cornerRadius: 18
    readonly property int bottomRadius: 12
    readonly property color notificationColor: "#181818"
    readonly property color borderColor: "#484848"

    NotificationServer {
        id: server
        bodySupported: true

        onNotification: notification => {
            notification.tracked = true

            const previous = root.currentNotification
            hideAnimation.stop()
            showAnimation.stop()
            root.dismissAfterAnimation = null
            root.currentNotification = notification
            root.panelShown = true
            if (previous !== null)
                previous.expire()
            hideTimer.restart()
            slideTranslation.y = -notificationWindow.implicitHeight
            showAnimation.start()
        }
    }

    Connections {
        target: root.currentNotification
        ignoreUnknownSignals: true

        function onClosed() {
            hideTimer.stop()
            root.hideNotification()
        }
    }

    Timer {
        id: hideTimer
        interval: 5000
        repeat: false

        onTriggered: root.hideNotification()
    }

    PanelWindow {
        id: notificationWindow
        visible: root.panelShown

        WlrLayershell.namespace: "quickshell:notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        margins.top: 0

        implicitWidth: 420 + root.cornerRadius * 2
        implicitHeight: contents.implicitHeight + 28

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: false

        Item {
            id: slidingSurface
            anchors.fill: parent

            transform: Translate {
                id: slideTranslation
                y: -notificationWindow.implicitHeight
            }

            // One outline: inverted top joins, normal bottom corners,
            // and a regular 1px border on the left, right and bottom.
            Canvas {
                anchors.fill: parent

                onPaint: {
                    const ctx = getContext("2d")
                    const w = width
                    const h = height
                    const top = root.cornerRadius
                    const bottom = root.bottomRadius
                    const left = top
                    const right = w - top
                    const pi = Math.PI

                    ctx.clearRect(0, 0, w, h)
                    ctx.fillStyle = "#181818"
                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    ctx.lineTo(w, 0)
                    ctx.arc(w, top, top, -pi / 2, -pi, true)
                    ctx.lineTo(right, h - bottom)
                    ctx.arc(right - bottom, h - bottom, bottom, 0, pi / 2)
                    ctx.lineTo(left + bottom, h)
                    ctx.arc(left + bottom, h - bottom, bottom, pi / 2, pi)
                    ctx.lineTo(left, top)
                    ctx.arc(0, top, top, 0, -pi / 2, true)
                    ctx.closePath()
                    ctx.fill()

                    ctx.strokeStyle = "#484848"
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    // Border both inverted top corners, excluding the
                    // straight upper edge where the panel touches the screen.
                    ctx.moveTo(0, 0)
                    ctx.arc(0, top, top, -pi / 2, 0)
                    ctx.lineTo(left, h - bottom)
                    ctx.arc(left + bottom, h - bottom, bottom, pi, pi / 2, true)
                    ctx.lineTo(right - bottom, h)
                    ctx.arc(right - bottom, h - bottom, bottom, pi / 2, 0, true)
                    ctx.lineTo(right, top)
                    ctx.arc(w, top, top, pi, 3 * pi / 2)
                    ctx.stroke()
                }
            }

            Column {
                id: contents
                anchors {
                    top: parent.top
                    topMargin: 14
                    horizontalCenter: parent.horizontalCenter
                }
                width: 420 - 28
                spacing: 6

                Text {
                    width: parent.width
                    text: root.currentNotification !== null
                        ? (root.currentNotification.summary || root.currentNotification.appName)
                        : ""
                    color: Style.textColor
                    font.family: Style.monoFontFamily
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
                onClicked: root.hideNotification(true)
            }
        }

        NumberAnimation {
            id: showAnimation
            target: slideTranslation
            property: "y"
            from: -notificationWindow.implicitHeight
            to: 0
            duration: 280
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: hideAnimation
            target: slideTranslation
            property: "y"
            to: -notificationWindow.implicitHeight
            duration: 280
            easing.type: Easing.InCubic

            onFinished: {
                root.panelShown = false
                const dismissed = root.dismissAfterAnimation
                root.dismissAfterAnimation = null
                const previous = root.currentNotification
                root.currentNotification = null
                if (dismissed !== null)
                    dismissed.dismiss()
                else if (previous !== null)
                    previous.expire()
            }
        }
    }
}
