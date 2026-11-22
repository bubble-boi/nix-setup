
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string wallpaperDir: homeDir + "/.local/share/wallpapers"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || homeDir + "/.cache") + "/quickshell/wallpapers"

    property bool cachePrepared: false
    property bool cacheReady: false

    property var wallpapers: []
    property int selectedIndex: -1
    property bool confirmDelete: false
    property bool busy: false
    property string statusMessage: ""
    property string applyingWallpaper: ""
    property string monitorOutput: ""
    property var remainingMonitors: []

    function applyNextMonitor() {
        if (remainingMonitors.length === 0) {
            // Only persist the wallpaper after all monitors have been updated.
            persistWallpaper.exec([
                "ln", "-sfn", "--",
                applyingWallpaper, homeDir + "/.current_wallpaper"
            ])
            return
        }

        const monitor = remainingMonitors.shift()
        applyMonitor.exec([
            "hyprctl", "hyprpaper", "wallpaper",
            monitor + ", " + applyingWallpaper + ", cover"
        ])
    }

    function fileName(path) {
        return path.substring(path.lastIndexOf("/") + 1)
    }

    function fileUrl(path) {
        return "file://" + path.split("/").map(function(part) {
            return encodeURIComponent(part)
        }).join("/")
    }

    function moveSelection(step) {
        if (busy || confirmDelete || wallpapers.length === 0)
            return
            selectedIndex = Math.max(0, Math.min(wallpapers.length - 1, selectedIndex + step))
    }

    function applySelected() {
        if (busy || confirmDelete || selectedIndex < 0 || selectedIndex >= wallpapers.length)
            return

            busy = true
            statusMessage = "Applying wallpaper..."
            applyingWallpaper = wallpapers[selectedIndex].path
            monitorOutput = ""
            listMonitors.exec(["hyprctl", "-i", "0", "monitors"])
    }

    function requestDelete() {
        if (!busy && selectedIndex >= 0 && selectedIndex < wallpapers.length)
            confirmDelete = true
    }

    function deleteSelected() {
        if (busy || selectedIndex < 0 || selectedIndex >= wallpapers.length)
            return

            confirmDelete = false
            busy = true
            statusMessage = "Deleting wallpaper..."
            deleteProcess.exec([
                "sh", "-c",
                "current=$(readlink -f -- \"$1\") || exit 2; selected=$(readlink -f -- \"$2\") || exit 2; [ \"$current\" != \"$selected\" ] || exit 3; exec rm -- \"$2\"",
                "sh", homeDir + "/.current_wallpaper", wallpapers[selectedIndex].path
            ])
    }

    // Built-in Qt PNG thumbnail cache; no image conversion package needed.
    Process {
        id: prepareCache
        command: ["mkdir", "-p", root.cacheDir]
        running: true

        onExited: (exitCode, exitStatus) => {
            root.cacheReady = exitCode === 0
            root.cachePrepared = true
            if (!root.cacheReady)
                console.warn("Wallpaper thumbnail cache unavailable, using original images.")
        }
    }

    Process {
        id: scanProcess
        command: [
            "find", root.wallpaperDir,
            "-type", "f",
            "(", "-iname", "*.jpg", "-o",
            "-iname", "*.jpeg", "-o",
            "-iname", "*.png", "-o",
            "-iname", "*.webp", "-o",
            "-iname", "*.bmp", "-o",
            "-iname", "*.gif", "-o",
            "-iname", "*.tif", "-o",
            "-iname", "*.tiff", "-o",
            "-iname", "*.svg", ")",
            "-printf", "%T@\\t%p\\n"
        ]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const previous = root.selectedIndex >= 0
                && root.selectedIndex < root.wallpapers.length
                ? root.wallpapers[root.selectedIndex].path : ""

                const entries = []
                for (const line of this.text.split("\n")) {
                    const separator = line.indexOf("\t")
                    if (separator <= 0)
                        continue

                        const mtime = Number(line.substring(0, separator))
                        const path = line.substring(separator + 1)
                        if (path.length > 0 && !isNaN(mtime))
                            entries.push({ mtime: mtime, path: path })
                }

                entries.sort((a, b) => b.mtime - a.mtime)
                const oldIndex = root.selectedIndex
                root.wallpapers = entries

                let index = entries.findIndex(entry => entry.path === previous)
                if (index < 0 && entries.length > 0)
                    index = Math.min(Math.max(oldIndex, 0), entries.length - 1)
                    root.selectedIndex = index
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.statusMessage = "Failed to scan wallpaper directory."
        }
    }

    Process {
        id: listMonitors

        stdout: StdioCollector {
            onStreamFinished: root.monitorOutput = this.text
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.busy = false
                root.statusMessage = "Failed to list monitors."
                return
            }

            const monitors = []
            for (const line of root.monitorOutput.split("\n")) {
                const match = /^Monitor (\S+)/.exec(line)
                if (match)
                    monitors.push(match[1])
            }

            if (monitors.length === 0) {
                root.busy = false
                root.statusMessage = "No monitors found."
                return
            }

            root.remainingMonitors = monitors
            root.applyNextMonitor()
        }
    }

    Process {
        id: applyMonitor

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.busy = false
                root.statusMessage = "Failed to apply wallpaper to a monitor."
            } else {
                root.applyNextMonitor()
            }
        }
    }

    Process {
        id: persistWallpaper

        onExited: (exitCode, exitStatus) => {
            root.busy = false
            root.statusMessage = exitCode === 0
            ? "" : "Wallpaper applied, but failed to save selection."
        }
    }

    Process {
        id: deleteProcess

        onExited: (exitCode, exitStatus) => {
            root.busy = false
            if (exitCode === 0) {
                root.statusMessage = ""
                scanProcess.running = true
            } else if (exitCode === 3) {
                root.statusMessage = "Cannot delete current wallpaper."
            } else {
                root.statusMessage = "Failed to delete wallpaper."
            }
        }
    }

    PanelWindow {
        id: galleryWindow

        WlrLayershell.namespace: "quickshell:wallpaper"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors {
            left: true
            right: true
            bottom: true
        }

        implicitHeight: screen ? Math.round(screen.height * 0.25) : 270
        color: Style.galleryBackgroundColor
        exclusionMode: ExclusionMode.Ignore
        focusable: true

        Rectangle {
            id: content
            anchors.fill: parent
            color: Style.galleryBackgroundColor
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (root.confirmDelete)
                        root.confirmDelete = false
                        else if (!root.busy)
                            Qt.quit()
                            event.accepted = true
                } else if (root.confirmDelete) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.deleteSelected()
                        event.accepted = true
                    }
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                    root.moveSelection(-1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                    root.moveSelection(1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.applySelected()
                    event.accepted = true
                } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                    root.requestDelete()
                    event.accepted = true
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                Row {
                    id: heading
                    width: parent.width
                    height: 24
                    spacing: 16

                    Text {
                        text: "WALLPAPERS"
                        font.family: Style.fontFamily
                        font.pixelSize: 17
                        font.bold: true
                        color: Style.textColor
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.wallpapers.length + " images"
                        font.family: Style.monoFontFamily
                        font.pixelSize: 12
                        color: Style.galleryMutedColor
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.statusMessage
                        font.family: Style.monoFontFamily
                        font.pixelSize: 12
                        color: Style.textColor
                        visible: root.statusMessage.length > 0
                    }
                }

                ListView {
                    id: gallery
                    width: parent.width
                    height: Math.max(48, parent.height - heading.height - parent.spacing)
                    clip: true
                    orientation: ListView.Horizontal
                    spacing: 12
                    model: root.wallpapers
                    currentIndex: root.selectedIndex
                    cacheBuffer: 400

                    onCurrentIndexChanged: {
                        if (currentIndex >= 0)
                            positionViewAtIndex(currentIndex, ListView.Contain)
                    }

                    delegate: Item {
                        id: thumbnail
                        required property int index
                        required property var modelData

                        width: Math.round(gallery.height * 1.6)
                        height: gallery.height

                        // Cache names include path and modification time.
                        // Visible delegates check for a saved PNG before decoding originals.
                        readonly property string cachePath: root.cacheDir + "/"
                        + Qt.md5("crop-v3|" + modelData.path + "|" + modelData.mtime) + ".png"
                        property string previewPath: ""
                        property bool needsSaving: false
                        property bool saving: false
                        property bool previewFailed: false

                        function loadOriginal() {
                            previewPath = modelData.path
                            needsSaving = root.cacheReady
                        }

                        Process {
                            id: cacheCheck
                            command: ["test", "-s", thumbnail.cachePath]
                            running: root.cacheReady

                            onExited: (exitCode, exitStatus) => {
                                if (exitCode === 0) {
                                    thumbnail.previewPath = thumbnail.cachePath
                                } else {
                                    thumbnail.loadOriginal()
                                }
                            }
                        }

                        Connections {
                            target: root
                            function onCachePreparedChanged() {
                                if (!root.cacheReady)
                                    thumbnail.loadOriginal()
                            }
                        }

                        Component.onCompleted: {
                            if (root.cachePrepared && !root.cacheReady)
                                loadOriginal()
                        }

                        // Keep the image inside its own frame, with the filename
                        // fully outside the frame beneath it.
                        Rectangle {
                            id: imageFrame
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: filenameLabel.top
                            anchors.bottomMargin: 8
                            radius: 6
                            color: Style.galleryTileColor
                            border.color: root.selectedIndex === index
                            ? Style.textColor : Style.galleryBorderColor
                            border.width: root.selectedIndex === index ? 3 : 1
                            clip: true
                        }

                        Image {
                            id: preview
                            anchors.fill: imageFrame
                            anchors.margins: 4
                            source: thumbnail.previewPath.length > 0
                            ? root.fileUrl(thumbnail.previewPath) : ""
                            sourceSize: Qt.size(400, 240)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true

                            onStatusChanged: {
                                if (status === Image.Error) {
                                    if (thumbnail.previewPath === thumbnail.cachePath) {
                                        // Recover from a damaged or unreadable cached PNG.
                                        thumbnail.loadOriginal()
                                    } else if (thumbnail.previewPath.length > 0) {
                                        thumbnail.previewFailed = true
                                    }
                                }

                                if (status === Image.Ready &&
                                    thumbnail.needsSaving && !thumbnail.saving) {
                                    thumbnail.saving = true
                                    const destination = thumbnail.cachePath
                                    const started = preview.grabToImage(function(result) {
                                        if (!result.saveToFile(destination))
                                            console.warn("Failed to save PNG thumbnail: " + destination)
                                            thumbnail.needsSaving = false
                                    }, Qt.size(400, 240))

                                    if (!started) {
                                        thumbnail.needsSaving = false
                                        console.warn("Failed to capture PNG thumbnail: " + destination)
                                    }
                                    }
                            }
                        }

                        Text {
                            anchors.centerIn: preview
                            visible: thumbnail.previewPath.length === 0 || thumbnail.previewFailed
                            text: thumbnail.previewFailed
                            ? "Preview unavailable" : "Loading preview..."
                            color: Style.galleryMutedColor
                            font.family: Style.monoFontFamily
                            font.pixelSize: 12
                        }

                        Text {
                            id: filenameLabel
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            height: 26
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideMiddle
                            text: root.fileName(thumbnail.modelData.path)
                            font.family: Style.monoFontFamily
                            font.pixelSize: 12
                            color: Style.textColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.busy && !root.confirmDelete
                            onClicked: {
                                root.selectedIndex = thumbnail.index
                                root.applySelected()
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.wallpapers.length === 0
                        text: "No wallpapers found in " + root.wallpaperDir
                        font.family: Style.monoFontFamily
                        font.pixelSize: 13
                        color: Style.galleryMutedColor
                    }
                }

            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 40, 620)
                height: 96
                radius: 8
                color: Style.galleryTileColor
                border.color: Style.textColor
                border.width: 1
                visible: root.confirmDelete
                z: 10

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Delete " + (root.selectedIndex >= 0
                        ? root.fileName(root.wallpapers[root.selectedIndex].path)
                        : "") + "?"
                        font.family: Style.monoFontFamily
                        font.pixelSize: 16
                        font.bold: true
                        color: Style.textColor
                        elide: Text.ElideMiddle
                        width: Math.min(560, content.width - 60)
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "ENTER  CONFIRM     ESC  CANCEL"
                        font.family: Style.monoFontFamily
                        font.pixelSize: 13
                        color: Style.galleryMutedColor
                    }
                }
            }
        }
    }
}
