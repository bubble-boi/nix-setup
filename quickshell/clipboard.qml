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
        hideAnimation.from = slideTranslation.x
        hideAnimation.start()
    }

    property var entries: []
    property string query: ""
    readonly property int cornerRadius: 18
    readonly property int outerRadius: 12
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

        // Attach the launcher to the left edge, centered vertically.
        anchors.left: true
        margins.left: 0

        implicitWidth: screen ? Math.min(screen.width - 48, 720) : 720
        implicitHeight: screen
            ? Math.min(screen.height - 48, 440) + root.cornerRadius * 2
            : 440 + root.cornerRadius * 2

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: true

        Item {
            id: slidingSurface
            anchors.fill: parent

            transform: Translate {
                id: slideTranslation
                x: -clipboardWindow.implicitWidth
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
                    width: parent.width
                    height: parent.height - 58
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
                            ? Style.textColor : "transparent"
                        border.width: results.currentIndex === index ? 2 : 0

                        Text {
                            anchors.fill: parent
                            anchors.margins: 12
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.label
                            color: Style.textColor
                            font.family: Style.monoFontFamily
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.busy
                            onClicked: root.copy(index)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.status !== "" ? root.status : "No matching entries"
                        color: Style.galleryMutedColor
                        font.family: Style.monoFontFamily
                        visible: results.count === 0 || root.status !== ""
                    }
                }

            }
            }
        }

        NumberAnimation {
            id: showAnimation
            target: slideTranslation
            property: "x"
            from: -clipboardWindow.implicitWidth
            to: 0
            duration: 280
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: hideAnimation
            target: slideTranslation
            property: "x"
            to: -clipboardWindow.implicitWidth
            duration: 280
            easing.type: Easing.InCubic
            onFinished: Qt.quit()
        }

        Component.onCompleted: showAnimation.start()
    }
}
