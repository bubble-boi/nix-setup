
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

    PanelWindow {
        WlrLayershell.namespace: "quickshell:media"
        WlrLayershell.layer: WlrLayer.Bottom

        anchors {
            bottom: true
        }

        margins {
            bottom: 40
        }

        implicitWidth: playerControls.implicitWidth
        implicitHeight: playerControls.implicitHeight

        visible: playerControls.visible
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region { item: playerControls }

        Media {
            id: playerControls
            anchors.fill: parent
        }
    }
}
