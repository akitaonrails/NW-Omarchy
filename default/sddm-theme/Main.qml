import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
    id: root
    width: 640
    height: 480
    color: "#000000"

    property string currentUser: userModel.lastUser

    // sessionIndex is the picker's current pick. We resolve the initial
    // value in Component.onCompleted (after the Repeater has populated),
    // which lets us inspect session names rather than guessing roles up front.
    property int sessionIndex: 0

    // Hidden Repeater so we can read role names off the SessionModel from
    // JS. sessionModel.data(...) is not callable from QML directly (it's a
    // C++ slot, not Q_INVOKABLE), so we instantiate one delegate per session
    // and copy the `name` role into a property we CAN read.
    Item {
        id: sessionStash
        visible: false
        Repeater {
            id: sessionRepeater
            model: sessionModel
            delegate: Item { property string sessionName: (model.name || model.display || "").toString() }
        }
    }

    function sessionName(idx) {
        if (idx < 0 || idx >= sessionRepeater.count) return ""
        var it = sessionRepeater.itemAt(idx)
        return it ? it.sessionName : ""
    }

    function cycleSession(delta) {
        var n = sessionRepeater.count
        if (n <= 0) return
        sessionIndex = (sessionIndex + delta + n) % n
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            errorMessage.text = "Login failed"
            password.text = ""
            password.focus = true
        }
        function onLoginSucceeded() {
            errorMessage.text = ""
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: root.height * 0.04
        width: parent.width

        Image {
            source: "logo.svg"
            width: root.width * 0.35
            height: Math.round(width * sourceSize.height / sourceSize.width)
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.width * 0.007

            Text {
                text: ""
                color: "#ffffff"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: root.height * 0.025
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: root.width * 0.17
                height: root.height * 0.04
                color: "#000000"
                border.color: "#ffffff"
                border.width: 1
                clip: true

                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.margins: root.height * 0.008
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: root.height * 0.02
                    font.letterSpacing: root.height * 0.004
                    passwordCharacter: "•"
                    color: "#ffffff"
                    focus: true

                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(root.currentUser, password.text, root.sessionIndex)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.cycleSession(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                            root.cycleSession(1)
                            event.accepted = true
                        }
                    }
                }
            }
        }

        Text {
            id: sessionLabel
            text: "session: " + root.sessionName(root.sessionIndex) + "   (↑/↓ to switch)"
            color: "#aaaaaa"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: root.height * 0.02
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            id: errorMessage
            text: ""
            color: "#f7768e"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: root.height * 0.018
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Component.onCompleted: {
        // Default to SDDM's last-logged-in session memory if available.
        // Otherwise prefer a uwsm-flavored session (matches the original
        // omarchy theme behaviour — Hyprland-on-uwsm is the "right" choice
        // on a fresh box). Falls through to index 0 otherwise.
        if (typeof sessionModel.lastIndex !== "undefined" && sessionModel.lastIndex >= 0) {
            sessionIndex = sessionModel.lastIndex
        } else {
            for (var i = 0; i < sessionRepeater.count; i++) {
                var it = sessionRepeater.itemAt(i)
                if (it && it.sessionName.toLowerCase().indexOf("uwsm") !== -1) {
                    sessionIndex = i
                    break
                }
            }
        }
        password.forceActiveFocus()
    }
}
