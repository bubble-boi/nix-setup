import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property bool closing: false

    function closePanel() {
        if (closing)
            return
        closing = true
        showAnimation.stop()
        hideAnimation.start()
    }

    property var entries: []
    property string query: ""
    property bool busy: false
    property string status: ""

    readonly property var filteredEntries: {
        const q = query.trim().toLowerCase()
        return entries.filter(entry => q === "" || entry.label.toLowerCase().includes(q))
    }

    function copy(index) {
        const entry = filteredEntries[index]
        if (!entry || busy || closing) return
        busy = true
        status = "Copying..."
        copyProcess.exec(["clip", "copy", entry.raw])
    }

    Process {
        id: historyProcess
        command: ["clip", "list"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const result = []
                for (const line of this.text.split("\n")) {
                    const separator = line.indexOf("\t")
                    if (separator < 1) continue
                    result.push({ raw: line, label: line.substring(separator + 1) })
                }
                root.entries = result
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.status = "Failed to read clipboard history."
        }
    }

    Process {
        id: copyProcess

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.closePanel()
            } else {
                root.busy = false
                root.status = "Failed to copy clipboard entry."
            }
        }
    }

    PanelWindow {
        id: clipboardWindow

        WlrLayershell.namespace: "quickshell:clipboard"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        implicitWidth: screen ? Math.min(screen.width - 48, 720) : 720
        implicitHeight: screen ? Math.min(screen.height - 48, 440) : 440

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: true

        Item {
            id: surface
            anchors.fill: parent
            opacity: 0

            Canvas {
                id: background
                anchors.fill: parent
                readonly property url source: "file://" + Quickshell.env("HOME") + "/.local/share/img/term_bg.png"

                onAvailableChanged: if (available) { loadImage(source); requestPaint() }
                onImageLoaded: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    const w = width, h = height
                    if (w <= 0 || h <= 0) return
                    ctx.reset()
                    ctx.clearRect(0, 0, w, h)
                    ctx.save()
                    ctx.beginPath()
                    ctx.rect(0, 0, w, h)
                    ctx.clip()
                    ctx.fillStyle = "#181818"
                    ctx.fillRect(0, 0, w, h)
                    if (isImageLoaded(background.source))
                        ctx.drawImage(background.source, 0, 0)

                    ctx.strokeStyle = "#000000"
                    ctx.lineJoin = "miter"
                    for (let i = 3; i >= 1; --i) {
                        ctx.lineWidth = i * 2
                        ctx.globalAlpha = i === 1 ? 0.10 : 0.055
                        ctx.stroke()
                    }
                    ctx.globalAlpha = 1

                    const depth = Math.min(4, w / 2, h / 2)
                    for (const edge of [
                        [0, 0, 0, depth, 0, 0, w, depth],
                        [0, h, 0, h - depth, 0, h - depth, w, depth],
                        [0, 0, depth, 0, 0, 0, depth, h],
                        [w, 0, w - depth, 0, w - depth, 0, depth, h]
                    ]) {
                        const shade = ctx.createLinearGradient(edge[0], edge[1], edge[2], edge[3])
                        shade.addColorStop(0, "rgba(0,0,0,0.35)")
                        shade.addColorStop(1, "rgba(0,0,0,0)")
                        ctx.fillStyle = shade
                        ctx.fillRect(edge[4], edge[5], edge[6], edge[7])
                    }
                    ctx.restore()
                }
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
                        color: "#000000"
                        font.family: Style.monoFontFamily
                        font.pixelSize: 15
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        enabled: !root.busy
                        onTextChanged: {
                            root.query = text
                            results.currentIndex = root.filteredEntries.length > 0 ? 0 : -1
                        }
                        onAccepted: root.copy(results.currentIndex)

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                if (!root.busy) root.closePanel()
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
                    acceptedButtons: Qt.NoButton
                    width: parent.width
                    height: parent.height - 46 - parent.spacing
                    clip: true
                    spacing: 4
                    model: root.filteredEntries
                    currentIndex: root.filteredEntries.length > 0 ? 0 : -1

                    onCurrentIndexChanged: {
                        if (currentIndex >= 0)
                            positionViewAtIndex(currentIndex, ListView.Contain)
                    }

                    delegate: Rectangle {
                        required property int index
                        required property var modelData

                        width: results.width
                        height: 44
                        color: "transparent"
                        border.color: results.currentIndex === index
                            ? "#000000" : "transparent"
                        border.width: results.currentIndex === index ? 2 : 0

                        Text {
                            anchors.fill: parent
                            anchors.margins: 12
                            verticalAlignment: Text.AlignVCenter
                            textFormat: Text.PlainText
                            text: modelData.label
                            color: "#000000"
                            font.family: Style.monoFontFamily
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.busy && !root.closing
                            onClicked: root.copy(index)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.status !== "" ? root.status : "No matching entries"
                        color: "#505050"
                        font.family: Style.monoFontFamily
                        visible: results.count === 0 || root.status !== ""
                    }
                }

            }
        }

        NumberAnimation {
            id: showAnimation
            target: surface
            property: "opacity"
            to: 1
            duration: 280
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: hideAnimation
            target: surface
            property: "opacity"
            to: 0
            duration: 280
            easing.type: Easing.InCubic
            onFinished: Qt.quit()
        }

        Component.onCompleted: {
            searchInput.forceActiveFocus()
            showAnimation.start()
        }
    }
}
