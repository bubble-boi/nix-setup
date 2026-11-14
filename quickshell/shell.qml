import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    WlrLayershell.namespace: "quickshell:clock"
    WlrLayershell.layer: WlrLayer.Bottom

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -300
        spacing: 8

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(
                clock.date, "dddd, MMMM d"
            ).toLowerCase()
            color: "#80ffffff"
            font.pixelSize: 28

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

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "hh:mm")
            color: "#80ffffff"
            font.pixelSize: 110
            font.bold: true

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
}
