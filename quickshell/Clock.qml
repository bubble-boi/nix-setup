import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: root

    property bool animateToCenter: false
    property bool returnToLeft: false
    property bool centered: false

    onReturnToLeftChanged: {
        if (returnToLeft)
            centered = false
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Timer {
        interval: 100
        running: root.animateToCenter
        repeat: false

        onTriggered: {
            if (!root.returnToLeft)
                root.centered = true
        }
    }

    Column {
        x: root.centered
        ? (parent.width - width) / 2
        : 100

        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -300
        spacing: -15

        Behavior on x {
            enabled: root.animateToCenter

            NumberAnimation {
                duration: 450
                easing.type: Easing.InOutCubic
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "hh:mm")
            color: Style.textColor
            font.family: Style.fontFamily
            font.pixelSize: 80
            font.bold: true

            layer.enabled: true
            layer.effect: ShadowEffect {}
        }

        Text {
            anchors.left: parent.left
            text: Qt.formatDateTime(
                clock.date, "ddd, MMM d"
            )
            color: Style.textColor
            font.family: Style.fontFamily
            font.pixelSize: 20
            font.bold: true

            layer.enabled: true
            layer.effect: ShadowEffect {}
        }
    }
}
