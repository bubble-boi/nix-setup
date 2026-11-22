import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    property string query: ""

    readonly property var excludedApps: [
        "Alacritty",
        "fcitx5-configtool",
        "fcitx5-wayland-launcher",
        "kbd-layout-viewer5",
        "kcm_fcitx5",
        "nixos-manual",
        "org.fcitx.fcitx5-config-qt",
        "org.fcitx.Fcitx5",
        "org.fcitx.fcitx5-migrator",
        "org.fcitx.fcitx5-qt5-gui-wrapper",
        "org.fcitx.fcitx5-qt6-gui-wrapper",
        "org.freedesktop.Xwayland",
        "org.kde.konsole",
        "org.kde.kwrite",
        "org.quickshell",
        "xdg-desktop-portal-gtk"
    ]

    readonly property var filteredApps: {
        const q = query.trim().toLowerCase()
        const apps = [...DesktopEntries.applications.values]
        .filter(app => !root.excludedApps.includes(app.id))
        const matches = apps.filter(app => {
            if (q === "") return true
            const fields = [app.name, app.genericName, app.comment, app.id]
            return fields.some(value => (value || "").toLowerCase().includes(q))
        })
        matches.sort((a, b) => {
            const an = (a.name || "").toLowerCase()
            const bn = (b.name || "").toLowerCase()
            if (q !== "") {
                const ap = an.startsWith(q) ? 0 : 1
                const bp = bn.startsWith(q) ? 0 : 1
                if (ap !== bp) return ap - bp
            }
            return an.localeCompare(bn)
        })
        return matches
    }

    function launch(index) {
        const app = filteredApps[index]
        if (!app) return

        // Preserve the existing native-Wayland launch behavior for Spotify.
        if (app.name === "Spotify")
            Quickshell.execDetached(["env", "-u", "DISPLAY", "spotify", "--ozone-platform=wayland"])
        else
            app.execute()
        Qt.quit()
    }

    PanelWindow {
        WlrLayershell.namespace: "HyprGlass"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: true

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 640)
            height: Math.min(parent.height - 48, 490)
            radius: 12
            color: "#33000000" // translucent alpha mask for Hyprglass

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                Text {
                    width: parent.width
                    text: "APPLICATIONS"
                    color: Style.textColor
                    font.family: Style.fontFamily
                    font.bold: true
                    font.pixelSize: 18
                }

                Rectangle {
                    width: parent.width
                    height: 46
                    radius: 6
                    color: Style.galleryTileColor

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.margins: 12
                        color: Style.textColor
                        font.family: Style.monoFontFamily
                        font.pixelSize: 15
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        onTextChanged: {
                            root.query = text
                            results.currentIndex = root.filteredApps.length > 0 ? 0 : -1
                        }
                        onAccepted: root.launch(results.currentIndex)

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                Qt.quit()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down) {
                                if (results.count > 0)
                                    results.currentIndex = Math.min(results.count - 1, results.currentIndex + 1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                if (results.count > 0)
                                    results.currentIndex = Math.max(0, results.currentIndex - 1)
                                event.accepted = true
                            }
                        }
                    }

                }

                ListView {
                    id: results
                    width: parent.width
                    height: parent.height - 94
                    clip: true
                    spacing: 4
                    model: root.filteredApps
                    currentIndex: root.filteredApps.length > 0 ? 0 : -1

                    onCurrentIndexChanged: {
                        if (currentIndex >= 0)
                            positionViewAtIndex(currentIndex, ListView.Contain)
                    }

                    delegate: Rectangle {
                        required property int index
                        required property var modelData

                        width: results.width
                        height: 52
                        radius: 6
                        color: "transparent"
                        border.color: results.currentIndex === index
                            ? Style.textColor : "transparent"
                        border.width: results.currentIndex === index ? 2 : 0

                        Row {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 12

                            Image {
                                width: 32
                                height: 32
                                anchors.verticalCenter: parent.verticalCenter
                                source: Quickshell.iconPath(modelData.icon || "", true)
                                    || Quickshell.iconPath("application-x-executable", true)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }

                            Column {
                                width: parent.width - 44
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: modelData.name
                                    color: Style.textColor
                                    font.family: Style.fontFamily
                                    font.pixelSize: 15
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.genericName || modelData.comment || ""
                                    color: Style.galleryMutedColor
                                    font.family: Style.monoFontFamily
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.launch(index)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "No matching applications"
                        color: Style.galleryMutedColor
                        font.family: Style.monoFontFamily
                        visible: results.count === 0
                    }
                }

            }
        }
    }
}
