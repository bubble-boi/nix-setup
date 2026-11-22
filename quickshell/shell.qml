import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string wallpaperPath: ""

    Process {
        command: ["readlink", "-f", Quickshell.env("HOME") + "/.current_wallpaper"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.wallpaperPath = this.text.trim()
        }
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): void {
            root.wallpaperPath = path
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "quickshell:clock"
            WlrLayershell.layer: WlrLayer.Bottom

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "black"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}

            Wallpaper {
                anchors.fill: parent
                sourcePath: root.wallpaperPath
            }

            Clock {
                anchors.fill: parent
            }
        }
    }

    Notifications {}
}
