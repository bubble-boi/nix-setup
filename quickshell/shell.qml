import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "quickshell:background"
            WlrLayershell.layer: WlrLayer.Background
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            focusable: false
            color: Style.backgroundColor

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Image {
                anchors.fill: parent
                source: Style.wallpaper
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
    }

    PanelWindow {
        WlrLayershell.namespace: "quickshell:clock"
        WlrLayershell.layer: WlrLayer.Bottom

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: Style.transparentColor
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        focusable: false

        Clock {
            anchors.fill: parent
        }
    }

    TopBar {}

    Notifications {}
}
