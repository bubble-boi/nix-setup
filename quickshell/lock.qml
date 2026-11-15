import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import Quickshell.Widgets

// Standalone Quickshell session lock. Does not import an existing shell.qml,
// because ShellRoot/PanelWindow cannot be embedded in a session lock surface.
ShellRoot {
    id: root

    property string password: ""
    property string status: ""
    property bool busy: false

    readonly property var spotify: {
        const players = Mpris.players.values;
        return players.find(p => p.dbusName.indexOf("spotify") !== -1) || null;
    }

    function tryUnlock() {
        if (busy || password.length === 0)
            return;
        status = "";
        busy = true;
        if (!pam.start()) {
            busy = false;
            status = "PAMを開始できない";
        }
    }

    PamContext {
        id: pam
        // NixOS: programs.hyprlock.enable = true provides /etc/pam.d/hyprlock.
        config: "hyprlock"

        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(root.password);
            else if (pam.messageIsError)
                root.status = pam.message;
        }

        onCompleted: result => {
            root.busy = false;
            root.password = "";
            if (result === PamResult.Success) {
                sessionLock.locked = false;
                Qt.quit();
            } else if (root.status === "") {
                root.status = result === PamResult.Failed
                    ? "パスワードが違う"
                    : "認証エラー";
            }
        }

        onError: error => {
            root.busy = false;
            root.password = "";
            root.status = "PAMエラー";
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: true

        WlSessionLockSurface {
            color: "#000000"

            Item {
                anchors.fill: parent

                Column {
                    id: center
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 48, 450)
                    spacing: 34

                    Column {
                        width: parent.width
                        spacing: 6

                        Text {
                            id: clockText
                            property var currentTime: new Date()
                            width: parent.width
                            color: "#ffffff"
                            text: Qt.formatDateTime(currentTime, "HH:mm")
                            font.family: "M PLUS 1 Code"
                            font.pixelSize: 82
                            font.weight: Font.Light
                            horizontalAlignment: Text.AlignHCenter

                            Timer {
                                interval: 1000
                                running: true
                                repeat: true
                                onTriggered: clockText.currentTime = new Date()
                            }
                        }

                        Text {
                            width: parent.width
                            color: "#aaaaaa"
                            text: Qt.formatDateTime(clockText.currentTime, "yyyy/MM/dd dddd")
                            font.family: "M PLUS 1 Code"
                            font.pixelSize: 17
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: parent.width
                            height: 56
                            radius: 12
                            color: "#171717"
                            border.width: 1
                            border.color: passwordInput.activeFocus ? "#999999" : "#555555"

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Password"
                                color: "#777777"
                                visible: passwordInput.text.length === 0
                                font.pixelSize: 17
                            }

                            TextInput {
                                id: passwordInput
                                anchors.fill: parent
                                anchors.leftMargin: 18
                                anchors.rightMargin: 18
                                color: "#ffffff"
                                font.pixelSize: 19
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                                enabled: !root.busy
                                focus: true
                                onTextChanged: root.password = text
                                onAccepted: root.tryUnlock()

                                Connections {
                                    target: root
                                    function onPasswordChanged() {
                                        if (passwordInput.text !== root.password)
                                            passwordInput.text = root.password;
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            height: 20
                            color: "#ff8585"
                            text: root.status
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // Spotify media controller, under the lock surface.
                Rectangle {
                    id: mediaBox
                    visible: root.spotify !== null
                    width: Math.min(parent.width - 40, 520)
                    height: 100
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 42
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 16
                    color: "#191919"
                    border.width: 1
                    border.color: "#464646"

                    ClippingRectangle {
                        id: cover
                        x: 10
                        y: 10
                        width: 80
                        height: 80
                        radius: 12
                        color: "#303030"

                        Image {
                            anchors.fill: parent
                            source: root.spotify ? root.spotify.trackArtUrl : ""
                            asynchronous: true
                            cache: false
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

                    Item {
                        id: mediaDetails
                        x: cover.x + cover.width + 14
                        y: 10
                        width: parent.width - x - 14
                        height: 80

                        Item {
                            id: titleViewport
                            width: parent.width
                            height: 29
                            clip: true

                            Text {
                                id: titleText
                                y: 4
                                text: root.spotify
                                    ? (root.spotify.trackArtist || "") + " - " + (root.spotify.trackTitle || "")
                                    : ""
                                color: "#ffffff"
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                SequentialAnimation on x {
                                    running: titleText.paintedWidth > titleViewport.width
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: 1600 }
                                    NumberAnimation {
                                        from: 0
                                        to: Math.min(0, titleViewport.width - titleText.paintedWidth - 12)
                                        duration: Math.max(2000, Math.abs(titleText.paintedWidth - titleViewport.width) * 65)
                                    }
                                    PauseAnimation { duration: 1600 }
                                    NumberAnimation { to: 0; duration: 450 }
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            spacing: 28

                            Text {
                                text: "⏮"
                                color: root.spotify && root.spotify.canGoPrevious ? "#ffffff" : "#666666"
                                font.pixelSize: 22
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.spotify && root.spotify.canGoPrevious
                                    onClicked: root.spotify.previous()
                                }
                            }

                            Text {
                                text: root.spotify && root.spotify.isPlaying ? "⏸" : "▶"
                                color: "#ffffff"
                                font.pixelSize: 22
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.spotify && root.spotify.canTogglePlaying
                                    onClicked: root.spotify.togglePlaying()
                                }
                            }

                            Text {
                                text: "⏭"
                                color: root.spotify && root.spotify.canGoNext ? "#ffffff" : "#666666"
                                font.pixelSize: 22
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.spotify && root.spotify.canGoNext
                                    onClicked: root.spotify.next()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
