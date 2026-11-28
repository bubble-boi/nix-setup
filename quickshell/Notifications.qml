import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: root

    property var currentNotification: null
    property bool panelShown: false
    property bool dismissAfterAnimation: false
    property string summaryText: ""
    property string bodyText: ""

    function hideNotification(dismiss = false) {
        if (!panelShown)
            return

        if (dismiss)
            dismissAfterAnimation = true
        hideTimer.stop()
        if (hideAnimation.running)
            return

        showAnimation.stop()
        hideAnimation.from = slideTranslation.y
        hideAnimation.start()
    }
    readonly property int panelWidth: 450
    readonly property int screenMargin: 12

    NotificationServer {
        id: server
        bodySupported: true

        onNotification: notification => {
            notification.tracked = true

            const previous = root.currentNotification
            hideAnimation.stop()
            showAnimation.stop()
            root.dismissAfterAnimation = false
            root.currentNotification = notification
            root.summaryText = notification.summary || notification.appName
            root.bodyText = notification.body
            root.panelShown = true
            if (previous !== null && previous !== notification)
                previous.expire()
            hideTimer.restart()
            slideTranslation.y = notificationWindow.implicitHeight
            showAnimation.start()
        }
    }

    Connections {
        target: root.currentNotification
        ignoreUnknownSignals: true

        function onClosed() {
            root.currentNotification = null
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

        anchors {
            bottom: true
            right: true
        }
        margins {
            bottom: root.screenMargin
            right: root.screenMargin
        }

        implicitWidth: root.panelWidth
        implicitHeight: implicitWidth * 2 / 3

        color: Style.transparentColor
        exclusionMode: ExclusionMode.Ignore
        focusable: false

        Item {
            id: slidingSurface
            anchors.fill: parent

            transform: Translate {
                id: slideTranslation
                y: notificationWindow.implicitHeight
            }

            Image {
                id: background
                anchors.fill: parent
                source: "file://" + Quickshell.env("HOME") + "/.local/share/img/notify_bg.png"
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }

            Column {
                id: contents
                x: parent.width * 0.17
                y: parent.height * 0.26
                width: parent.width * 0.66
                height: parent.height * 0.50
                spacing: 12
                clip: true

                Text {
                    width: parent.width
                    text: root.summaryText
                    color: Style.darkTextColor
                    font.family: "Lugrasimo"
                    font.bold: true
                    font.pixelSize: 18
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.bodyText
                    visible: text.length > 0
                    color: Style.darkTextColor
                    font.family: "Lugrasimo"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
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
            from: notificationWindow.implicitHeight
            to: 0
            duration: Style.panelAnimationDuration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: hideAnimation
            target: slideTranslation
            property: "y"
            to: notificationWindow.implicitHeight
            duration: Style.panelAnimationDuration
            easing.type: Easing.InCubic

            onFinished: {
                root.panelShown = false
                const dismissed = root.dismissAfterAnimation
                const previous = root.currentNotification
                root.dismissAfterAnimation = false
                root.currentNotification = null
                root.summaryText = ""
                root.bodyText = ""
                if (previous !== null) {
                    if (dismissed)
                        previous.dismiss()
                    else
                        previous.expire()
                }
            }
        }
    }
}
