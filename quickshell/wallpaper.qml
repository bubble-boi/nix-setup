
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
    property bool closing: false

    function closePanel() {
        if (closing || busy)
            return
        closing = true
        enterAnimation.stop()
        exitAnimation.from = panelTranslation.y
        exitAnimation.start()
    }

    function wrapIndex(index, count) {
        return count > 0 ? ((index % count) + count) % count : -1
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
        gallery.advance(step)
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
                    Qt.callLater(function() { gallery.reset() })
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

            transform: Translate {
                id: panelTranslation
                y: galleryWindow.implicitHeight
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.closePanel()
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

            Item {
                id: gallery
                anchors.fill: parent
                clip: false

                // The rendered image widths, not imaginary fixed-width tiles,
                // determine how far apart adjacent image centers must be.
                // Keep the 1.3x central image within the layer, including
                // the bottom gap and a small top clearance.
                readonly property real imageBottomMargin: 20
                readonly property real imageTopMargin: 8
                readonly property real baseHeight: Math.max(1, Math.min(
                    Math.round(height * 0.72),
                    Math.floor((height - imageBottomMargin - imageTopMargin) / 1.3)))
                readonly property real baseWidth: Math.round(baseHeight * 1.6)
                readonly property real imageGap: 12
                readonly property real scaleRadius: Math.max(
                    2, width / (2 * (baseWidth * 0.9 + imageGap)))
                readonly property int sideCount: Math.ceil(scaleRadius) + 3

                // Keep an absolute scroll position. Visible delegates never
                // change their image while the selection advances.
                property real position: 0
                property int baseIndex: 0
                property int queuedSteps: 0
                readonly property int poolCount: sideCount * 2 + 1

                onSideCountChanged: Qt.callLater(function() { gallery.reset() })

                function reset() {
                    slide.stop()
                    position = 0
                    baseIndex = Math.max(0, root.selectedIndex)
                    queuedSteps = 0
                    for (let i = 0; i < thumbnailRepeater.count; ++i) {
                        const item = thumbnailRepeater.itemAt(i)
                        if (item)
                            item.virtualSlot = i - sideCount
                    }
                }

                // Only recycle tiles that have completely left the viewport.
                // The center and its visible neighbors retain their Image
                // sources, eliminating the flash on each arrow-key press.
                function recycle() {
                    for (let i = 0; i < thumbnailRepeater.count; ++i) {
                        const item = thumbnailRepeater.itemAt(i)
                        if (!item)
                            continue

                        const distance = item.virtualSlot - position
                        if (distance < -sideCount)
                            item.virtualSlot += poolCount
                        else if (distance > sideCount)
                            item.virtualSlot -= poolCount
                    }
                }

                function scaleAt(distance) {
                    return 1.3 - 0.8 * Math.min(1, Math.abs(distance) / scaleRadius)
                }

                // Integrate the varying image widths from the center.
                // This gives mirrored positions and a consistent visible gap.
                function offsetFor(distance) {
                    const absolute = Math.abs(distance)
                    const inside = Math.min(absolute, scaleRadius)
                    const beyond = Math.max(0, absolute - scaleRadius)
                    const x = baseWidth * (1.3 * inside
                        - 0.4 * inside * inside / scaleRadius)
                        + imageGap * inside
                        + (baseWidth * 0.5 + imageGap) * beyond
                    return distance < 0 ? -x : x
                }

                function advance(step, fromQueue = false) {
                    if (root.busy || root.wallpapers.length < 2)
                        return

                    const direction = step < 0 ? -1 : 1

                    // Commit keyboard selection immediately, not at the end
                    // of the slide. Delegates remain bound to baseIndex,
                    // so updating selectedIndex does not reload images.
                    if (!fromQueue)
                        root.selectedIndex = root.wrapIndex(
                            root.selectedIndex + direction, root.wallpapers.length)

                    if (slide.running) {
                        queuedSteps += direction
                        return
                    }

                    slide.from = position
                    slide.to = position + direction
                    slide.start()
                }

                NumberAnimation {
                    id: slide
                    target: gallery
                    property: "position"
                    from: 0
                    to: 1
                    duration: 220
                    easing.type: Easing.InOutCubic
                    onFinished: {
                        gallery.recycle()

                        if (gallery.queuedSteps !== 0) {
                            const next = gallery.queuedSteps < 0 ? -1 : 1
                            gallery.queuedSteps -= next
                            // The queued key press already changed selection.
                            Qt.callLater(function() { gallery.advance(next, true) })
                        }
                    }
                }

                Repeater {
                    id: thumbnailRepeater
                    model: root.wallpapers.length > 0
                        ? gallery.poolCount : 0
                    delegate: Item {
                        id: thumbnail
                        required property int index
                        property int virtualSlot: index - gallery.sideCount
                        readonly property int originalIndex: root.wrapIndex(
                            gallery.baseIndex + virtualSlot, root.wallpapers.length)
                        readonly property var modelData: originalIndex >= 0
                            ? root.wallpapers[originalIndex] : null
                        readonly property real relativePosition: virtualSlot - gallery.position

                        width: gallery.baseWidth
                        height: gallery.height
                        x: gallery.width / 2 + gallery.offsetFor(relativePosition) - width / 2
                        y: 0
                        z: 100 - Math.abs(relativePosition)

                        // Cache names include path and modification time.
                        // Visible delegates check for a saved PNG before decoding originals.
                        readonly property string cachePath: modelData
                            ? root.cacheDir + "/"
                                + Qt.md5("crop-v3|" + modelData.path + "|" + modelData.mtime) + ".png"
                            : ""
                        property string previewPath: ""
                        property bool needsSaving: false
                        property bool saving: false
                        property bool previewFailed: false
                        property bool initialized: false

                        onCachePathChanged: {
                            if (initialized) {
                                previewPath = ""
                                needsSaving = false
                                saving = false
                                previewFailed = false
                            }
                        }

                        function loadOriginal() {
                            if (!modelData)
                                return
                            previewPath = modelData.path
                            needsSaving = root.cacheReady
                        }

                        Process {
                            id: cacheCheck
                            command: ["test", "-s", thumbnail.cachePath]
                            running: root.cacheReady && thumbnail.cachePath.length > 0
                                && thumbnail.previewPath.length === 0

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
                            initialized = true
                            if (root.cachePrepared && !root.cacheReady)
                                loadOriginal()
                        }

                        Image {
                            id: preview
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            transformOrigin: Item.Bottom
                            anchors.bottomMargin: gallery.imageBottomMargin
                            width: gallery.baseWidth
                            height: gallery.baseHeight
                            scale: gallery.scaleAt(thumbnail.relativePosition)
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

                        // Outline only the thumbnail closest to screen center.
                        // Keep the border outside Image so thumbnail caching cannot capture it.
                        Rectangle {
                            x: preview.x
                            y: preview.y
                            width: preview.width
                            height: preview.height
                            scale: preview.scale
                            transformOrigin: Item.Bottom
                            color: "transparent"
                            border.color: "#d8d8d8"
                            border.width: 2 / Math.max(preview.scale, 0.001)
                            visible: Math.abs(thumbnail.relativePosition) < 0.5
                        }

                        MouseArea {
                            width: preview.width * preview.scale
                            height: preview.height * preview.scale
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: preview.bottom
                            enabled: !root.busy && !slide.running
                            onClicked: {
                                root.selectedIndex = thumbnail.originalIndex
                                root.applySelected()
                            }
                        }
                    }
                }
            }

            NumberAnimation {
                id: enterAnimation
                target: panelTranslation
                property: "y"
                from: galleryWindow.implicitHeight
                to: 0
                duration: 280
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                id: exitAnimation
                target: panelTranslation
                property: "y"
                to: galleryWindow.implicitHeight
                duration: 280
                easing.type: Easing.InCubic
                onFinished: Qt.quit()
            }
        }

        Component.onCompleted: enterAnimation.start()
    }
}
