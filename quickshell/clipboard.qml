import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

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
        if (!entry || busy) return
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
                Qt.quit()
            } else {
                root.busy = false
                root.status = "Failed to copy clipboard entry."
            }
        }
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
            width: Math.min(parent.width - 48, 720)
            height: Math.min(parent.height - 48, 440)
            color: "#33000000" // translucent alpha mask for Hyprglass

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
                                if (!root.busy) Qt.quit()
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
}
