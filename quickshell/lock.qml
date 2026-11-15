import QtQuick
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

// Clock and Media are the exact same components used by shell.qml.
// A WlSessionLockSurface cannot embed a PanelWindow, so the
// existing desktop panels are recreated here with shared visual items.
ShellRoot {
    id: root

    property string password: ""
    property string status: ""
    property bool busy: false

    function tryUnlock() {
        if (busy || password.length === 0)
            return;
        status = "";
        busy = true;
        if (!pam.start()) {
            busy = false;
            status = "Failed to initialize PAM";
        }
    }

    PamContext {
        id: pam
        // Dedicated NixOS PAM service: /etc/pam.d/quickshell.
        config: "quickshell"

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
                    ? "Authentication failed"
                    : "Authentication error";
            }
        }

        onError: error => {
            root.busy = false;
            root.password = "";
            root.status = "PAM error";
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: true

        WlSessionLockSurface {
            color: "#000000"

            Item {
                anchors.fill: parent

                // The desktop uses the same ~/.current_wallpaper via hyprpaper.
                Image {
                    anchors.fill: parent
                    source: StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.current_wallpaper"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true

                    // Blur only the wallpaper, not the clock, player, or input.
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        autoPaddingEnabled: false
                        blurEnabled: true
                        blurMax: 32
                        blur: 1.0
                    }
                }

                Clock {
                    anchors.fill: parent
                }

                Media {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 40
                    width: implicitWidth
                    height: implicitHeight
                }

                // Password entry remains on the lock surface and is never
                // included in the shared desktop UI.
                TextInput {
                    id: passwordInput
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 48, 640)
                    height: 56
                    color: "#80ffffff"
                    font.pixelSize: 28
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 8
                        blur: 0.2

                        shadowEnabled: true
                        shadowColor: "#ff000000"
                        shadowBlur: 0.5
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 3
                    }
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

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: passwordInput.bottom
                    anchors.topMargin: 6
                    text: root.status
                    color: "#ff8585"
                    font.pixelSize: 14
                }
            }
        }
    }
}
