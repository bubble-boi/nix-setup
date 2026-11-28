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
    readonly property int panelSize: 240
    readonly property int screenMargin: 12
    readonly property int contentPadding: 14

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

        implicitWidth: root.panelSize
        implicitHeight: root.panelSize

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

            BarItem {
                id: background
                anchors.fill: parent
                sideInset: 0
                source: Style.panelBackground
            }

            Column {
                id: contents
                anchors {
                    top: parent.top
                    topMargin: root.contentPadding
                    left: parent.left
                    leftMargin: root.contentPadding
                    right: parent.right
                    rightMargin: root.contentPadding
                }
                spacing: 6

                Text {
                    width: parent.width
                    text: root.summaryText
                    color: Style.darkTextColor
                    font.family: Style.monoFontFamily
                    font.bold: true
                    font.pixelSize: Style.inputFontSize
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
                    font.family: Style.monoFontFamily
                    font.pixelSize: Style.bodyFontSize
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 8
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
