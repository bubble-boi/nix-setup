
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

    // Repeat short galleries so both sides remain populated. PathView itself
    // wraps around when reaching the last model item.
    readonly property var carouselEntries: {
        const count = wallpapers.length
        if (count === 0)
            return []

        const minCount = gallery.pathItemCount + 2
        const length = Math.max(count, Math.ceil(minCount / count) * count)
        const entries = []
        for (let i = 0; i < length; ++i) {
            const wallpaper = wallpapers[i % count]
            entries.push({
                path: wallpaper.path,
                mtime: wallpaper.mtime,
                originalIndex: i % count
            })
        }
        return entries
    }
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
        if (busy || wallpapers.length < 2 || gallery.count === 0)
            return

        // Move exactly one visual tile, even when crossing the last/first image.
        if (step < 0)
            gallery.decrementCurrentIndex()
        else
            gallery.incrementCurrentIndex()

        selectedIndex = gallery.currentIndex % wallpapers.length
    }

    function applySelected() {
        if (busy || selectedIndex < 0 || selectedIndex >= wallpapers.length)
            return

            busy = true
            statusMessage = "Applying wallpaper..."
            applyingWallpaper = wallpapers[selectedIndex].path
            monitorOutput = ""
            listMonitors.exec(["hyprctl", "-i", "0", "monitors"])
    }

    function deleteSelected() {
        if (busy || selectedIndex < 0 || selectedIndex >= wallpapers.length)
            return

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
                    // Restore the selection after PathView's model has changed.
                    Qt.callLater(function() {
                        if (gallery.count > 0 && root.selectedIndex >= 0)
                            gallery.currentIndex = root.selectedIndex
                    })
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
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: true

        Item {
            id: content
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (!root.busy)
                        Qt.quit()
                    event.accepted = true
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
                    root.deleteSelected()
                    event.accepted = true
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                PathView {
                    id: gallery
                    width: parent.width
                    height: parent.height
                    clip: true
                    model: root.carouselEntries
                    interactive: false

                    readonly property real tileWidth: Math.round(height * 1.6 * 0.82)
                    readonly property real tileStep: tileWidth + 12

                    // Odd number of equally spaced tiles, with the selected tile
                    // always at the center of the horizontal path.
                    pathItemCount: Math.max(3,
                        2 * Math.ceil(width / (2 * tileStep)) + 3)
                    preferredHighlightBegin: 0.5
                    preferredHighlightEnd: 0.5
                    highlightRangeMode: PathView.StrictlyEnforceRange
                    highlightMoveDuration: 220

                    path: Path {
                        startX: gallery.width / 2
                            - gallery.pathItemCount * gallery.tileStep / 2
                        startY: gallery.height / 2
                        PathLine {
                            x: gallery.width / 2
                                + gallery.pathItemCount * gallery.tileStep / 2
                            y: gallery.height / 2
                        }
                    }

                    delegate: Item {
                        id: thumbnail
                        required property int index
                        required property var modelData

                        width: gallery.tileWidth
                        height: gallery.height
                        z: PathView.isCurrentItem ? 1 : 0

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

                        Image {
                            id: preview
                            anchors.centerIn: parent
                            width: Math.round(thumbnail.height * 1.6 * 0.72)
                            height: Math.round(thumbnail.height * 0.72)
                            scale: thumbnail.PathView.isCurrentItem ? 1.18 : 1.0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                            }
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

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.busy
                            onClicked: {
                                gallery.currentIndex = thumbnail.index
                                root.selectedIndex = thumbnail.modelData.originalIndex
                                root.applySelected()
                            }
                        }
                    }


                }

            }

        }
    }
}
