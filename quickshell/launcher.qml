import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    property bool closing: false
    property string query: ""
    property int selectedPosition: 0

    function closePanel() {
        if (closing)
            return
        closing = true
        showAnimation.stop()
        hideAnimation.start()
    }

    property var localAppIds: []

    FolderListModel {
        id: localEntries
        folder: "file://" + Quickshell.env("HOME") + "/.local/share/applications"
        nameFilters: ["*.desktop"]
        showDirs: false
        showFiles: true
        showHidden: false

        function refreshIds() {
            const ids = []
            for (let i = 0; i < count; ++i)
                ids.push(get(i, "fileName").replace(/\.desktop$/, ""))
            root.localAppIds = ids
        }

        onCountChanged: refreshIds()
        onStatusChanged: if (status === FolderListModel.Ready) refreshIds()
        Component.onCompleted: refreshIds()
    }

    readonly property var filteredApps: {
        const q = query.trim().toLowerCase()
        const apps = [...DesktopEntries.applications.values]
        .filter(app => root.localAppIds.includes(app.id.replace(/\.desktop$/, "")))
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

    function wrap(value, count) {
        return count > 0 ? ((value % count) + count) % count : 0
    }

    function rotate(step) {
        if (!closing && filteredApps.length > 1)
            selectedPosition += step
    }

    function launchSelected() {
        if (filteredApps.length > 0)
            root.launch(wrap(selectedPosition, filteredApps.length))
    }

    onQueryChanged: selectedPosition = 0

    PanelWindow {
        id: launcherWindow

        WlrLayershell.namespace: "quickshell:launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Style.transparentColor
        exclusionMode: ExclusionMode.Ignore
        focusable: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: root.closePanel()
        }

        Item {
            id: surface
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: Math.min(340, parent.width, parent.height)
            height: width
            transformOrigin: Item.BottomLeft
            scale: 0.82
            opacity: 0

            readonly property real unit: width / 340

            Item {
                id: ring
                anchors.fill: parent
                clip: true
                readonly property real radius: 270 * surface.unit
                readonly property real stepAngle: 22.5
                property real displayPosition: root.selectedPosition
                Behavior on displayPosition {
                    enabled: root.query.trim().length === 0
                    NumberAnimation {
                        duration: Style.fastAnimationDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Repeater {
                    model: root.filteredApps

                    delegate: Item {
                        id: tile
                        required property int index
                        required property var modelData

                        readonly property real delta: {
                            const count = root.filteredApps.length
                            if (count <= 0)
                                return 0
                            const d = index - ring.displayPosition
                            // Wrap at the hidden back of the wheel.
                            return ((d + count / 2) % count + count) % count - count / 2
                        }
                        readonly property real degrees: 45 + delta * ring.stepAngle
                        readonly property real radians: degrees * Math.PI / 180
                        readonly property real distance: Math.abs(delta)
                        readonly property real focusWeight: {
                            const t = Math.max(0, 1 - distance)
                            return t * t * (3 - 2 * t)
                        }

                        width: 48 * surface.unit
                        height: width
                        x: ring.radius * Math.cos(radians) - width / 2
                        y: ring.height - ring.radius * Math.sin(radians) - height / 2
                        opacity: {
                            if (distance <= 1)
                                return 0.7 + 0.3 * focusWeight
                            if (distance <= 2)
                                return 0.7 - 0.45 * (distance - 1)
                            return Math.max(0, 0.25 * (1 - (distance - 2) / 0.5))
                        }
                        visible: opacity > 0
                        z: 1 + focusWeight

                        Image {
                            anchors.fill: parent
                            source: (tile.modelData.icon || "").startsWith("/")
                                ? "file://" + tile.modelData.icon
                                : (Quickshell.iconPath(tile.modelData.icon || "", true)
                                    || Quickshell.iconPath("application-x-executable", true))
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            scale: 1.0 + tile.focusWeight
                            sourceSize: Qt.size(256, 256)
                        }

                        MouseArea {
                            anchors.centerIn: parent
                            width: parent.width * (1 + tile.focusWeight)
                            height: width
                            enabled: tile.opacity > 0.5 && !root.closing
                            onClicked: root.launch(tile.index)
                        }
                    }
                }
            }

            TextInput {
                id: searchInput
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 12 * surface.unit
                width: 100 * surface.unit
                height: 25 * surface.unit
                color: Style.textColor
                font.family: Style.monoFontFamily
                font.pixelSize: Style.bodyFontSize * surface.unit
                horizontalAlignment: TextInput.AlignLeft
                verticalAlignment: TextInput.AlignVCenter
                opacity: text.length > 0 ? 1 : 0
                focus: true
                clip: true
                onTextChanged: root.query = text

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.closePanel()
                        break
                    case Qt.Key_Left:
                        root.rotate(1)
                        break
                    case Qt.Key_Right:
                        root.rotate(-1)
                        break
                    case Qt.Key_Up:
                        root.rotate(1)
                        break
                    case Qt.Key_Down:
                        root.rotate(-1)
                        break
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.launchSelected()
                        break
                    default:
                        return
                    }
                    event.accepted = true
                }
            }
        }

        ParallelAnimation {
            id: showAnimation
            NumberAnimation {
                target: surface
                property: "scale"
                to: 1
                duration: Style.panelAnimationDuration
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: surface
                property: "opacity"
                to: 1
                duration: Style.panelAnimationDuration
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            id: hideAnimation
            NumberAnimation {
                target: surface
                property: "scale"
                to: 0.82
                duration: Style.panelAnimationDuration
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: surface
                property: "opacity"
                to: 0
                duration: Style.panelAnimationDuration
                easing.type: Easing.InCubic
            }
            onFinished: Qt.quit()
        }

        Component.onCompleted: {
            searchInput.forceActiveFocus()
            showAnimation.start()
        }
    }
}
