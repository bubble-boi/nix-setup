import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    property bool closing: false

    function closePanel() {
        if (closing)
            return
        closing = true
        showAnimation.stop()
        hideAnimation.from = slideTranslation.x
        hideAnimation.start()
    }

    property string query: ""
    readonly property int cornerRadius: 18
    readonly property int outerRadius: 12

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
        if (!app || closing) return

        // Preserve the existing native-Wayland launch behavior for Spotify.
        if (app.name === "Spotify")
            Quickshell.execDetached(["env", "-u", "DISPLAY", "spotify", "--ozone-platform=wayland"])
        else
            app.execute()
        root.closePanel()
    }

    PanelWindow {
        id: launcherWindow

        WlrLayershell.namespace: "quickshell:launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // Attach the launcher to the left edge, centered vertically.
        anchors.left: true
        margins.left: 0

        implicitWidth: screen ? Math.min(screen.width - 48, 320) : 320
        implicitHeight: screen
            ? Math.min(screen.height - 48, 440) + root.cornerRadius * 2
            : 490 + root.cornerRadius * 2

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: true

        Item {
            id: slidingSurface
            anchors.fill: parent

            transform: Translate {
                id: slideTranslation
                x: -launcherWindow.implicitWidth
            }

            // The notification panel's geometry rotated toward the left:
            // inverted joins where it meets the screen edge, regular rounded
            // corners at the free right edge, and a 1px outer border.
            Canvas {
                anchors.fill: parent

                onPaint: {
                    const ctx = getContext("2d")
                    const w = width
                    const h = height
                    const inverse = root.cornerRadius
                    const normal = root.outerRadius
                    const pi = Math.PI

                    ctx.clearRect(0, 0, w, h)
                    ctx.fillStyle = "#181818"
                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    ctx.arc(inverse, 0, inverse, pi, pi / 2, true)
                    ctx.lineTo(w - normal, inverse)
                    ctx.arc(w - normal, inverse + normal,
                            normal, -pi / 2, 0)
                    ctx.lineTo(w, h - inverse - normal)
                    ctx.arc(w - normal, h - inverse - normal,
                            normal, 0, pi / 2)
                    ctx.lineTo(inverse, h - inverse)
                    ctx.arc(inverse, h, inverse, -pi / 2, -pi, true)
                    ctx.closePath()
                    ctx.fill()

                    ctx.strokeStyle = "#484848"
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    // Follow the inverted upper-left and lower-left corners,
                    // leaving only the screen-attached left edge unbordered.
                    ctx.moveTo(0, 0)
                    ctx.arc(inverse, 0, inverse, pi, pi / 2, true)
                    ctx.lineTo(w - normal, inverse)
                    ctx.arc(w - normal, inverse + normal,
                            normal, -pi / 2, 0)
                    ctx.lineTo(w, h - inverse - normal)
                    ctx.arc(w - normal, h - inverse - normal,
                            normal, 0, pi / 2)
                    ctx.lineTo(inverse, h - inverse)
                    ctx.arc(inverse, h, inverse, -pi / 2, -pi, true)
                    ctx.stroke()
                }
            }

            Item {
                id: contentBody
                anchors {
                    top: parent.top
                    topMargin: root.cornerRadius
                    bottom: parent.bottom
                    bottomMargin: root.cornerRadius
                    left: parent.left
                    right: parent.right
                }

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                Rectangle {
                    width: parent.width
                    height: 46
                    color: "transparent"

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
                                root.closePanel()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down) {
                                if (results.count > 0)
                                    results.currentIndex = ((results.currentIndex < 0 ? -1 : results.currentIndex) + 1) % results.count
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                if (results.count > 0)
                                    results.currentIndex = (results.currentIndex < 0 ? 0 : results.currentIndex + results.count - 1) % results.count
                                event.accepted = true
                            }
                        }
                    }

                }

                ListView {
                    id: results
                    width: parent.width
                    height: parent.height - 58
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

                            Text {
                                width: parent.width - 44
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: Style.textColor
                                font.family: Style.fontFamily
                                font.pixelSize: 15
                                elide: Text.ElideRight
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

        NumberAnimation {
            id: showAnimation
            target: slideTranslation
            property: "x"
            from: -launcherWindow.implicitWidth
            to: 0
            duration: 280
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: hideAnimation
            target: slideTranslation
            property: "x"
            to: -launcherWindow.implicitWidth
            duration: 280
            easing.type: Easing.InCubic
            onFinished: Qt.quit()
        }

        Component.onCompleted: showAnimation.start()
    }
}
