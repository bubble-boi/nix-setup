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
            color: "black"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Image {
                anchors.fill: parent
                source: "file://" + Quickshell.env("HOME") + "/.local/share/img/wallpaper.png"
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

        color: "transparent"
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
