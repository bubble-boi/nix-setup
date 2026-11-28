import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
    id: root

    property string password: ""
    property string status: ""
    property bool busy: false
    property bool unlocking: false
    property bool showLockUI: false

    function tryUnlock() {
        if (busy || unlocking || password.length === 0)
            return;

        status = "";
        busy = true;

        if (!pam.start()) {
            busy = false;
            status = "Failed to initialize PAM";
        }
    }

    Timer {
        id: enterTransition
        interval: 100
        running: true
        repeat: false
        onTriggered: root.showLockUI = true
    }

    Timer {
        id: exitTransition
        interval: 500
        repeat: false

        onTriggered: {
            sessionLock.locked = false;
            Qt.quit();
        }
    }

    PamContext {
        id: pam
        config: "quickshell"

        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(root.password);
            else if (pam.messageIsError)
                root.status = pam.message;
        }

        onCompleted: result => {
            root.password = "";

            if (result === PamResult.Success) {
                root.unlocking = true;
                root.busy = true;
                root.status = "";

                enterTransition.stop();
                root.showLockUI = false;
                exitTransition.start();
            } else {
                root.busy = false;

                if (root.status === "") {
                    root.status = result === PamResult.Failed
                    ? "Authentication failed"
                    : "Authentication error";
                }
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
            color: Style.backgroundColor

            Item {
                anchors.fill: parent

                Image {
                    anchors.fill: parent
                    source: "file://" + Quickshell.env("HOME") + "/.local/share/img/wallpaper.png"

                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    cache: true

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        autoPaddingEnabled: false
                        blurEnabled: true
                        blurMax: 32

                        blur: root.showLockUI ? 1.0 : 0.0

                        Behavior on blur {
                            NumberAnimation {
                                duration: 450
                                easing.type: Easing.InOutCubic
                            }
                        }
                    }
                }

                Clock {
                    anchors.fill: parent
                    animateToCenter: true
                    returnToLeft: root.unlocking

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 100

                        text: "󰍁"
                        font.pixelSize: 48
                        color: Style.textColor

                        opacity: root.showLockUI ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 450
                                easing.type: Easing.InOutCubic
                            }
                        }

                    }
                }

                TextInput {
                    id: passwordInput

                    anchors.centerIn: parent
                    width: Math.min(parent.width - 48, 640)
                    height: 56

                    color: Style.textColor
                    font.pixelSize: 14

                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter

                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData
                    | Qt.ImhNoPredictiveText

                    opacity: root.showLockUI ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 450
                            easing.type: Easing.InOutCubic
                        }
                    }


                    enabled: !root.busy && !root.unlocking
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
                    color: Style.errorColor
                    font.pixelSize: 14
                    font.bold: true

                    opacity: root.showLockUI ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 450
                            easing.type: Easing.InOutCubic
                        }
                    }
                }
            }
        }
    }
}
