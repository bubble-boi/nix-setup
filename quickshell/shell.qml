
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

Scope {
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

        Clock {
            anchors.fill: parent
        }
    }

    Notifications {}
}
