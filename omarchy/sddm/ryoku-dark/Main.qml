import QtQuick 2.15

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#050505"

    property string currentUser: userModel.lastUser
    property bool loginFailed: false
    property int sessionIndex: {
        for (var i = 0; i < sessionModel.rowCount(); i++) {
            var name = (sessionModel.data(
                sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
            if (name.indexOf("uwsm") !== -1)
                return i
        }
        return sessionModel.lastIndex
    }

    function submitLogin() {
        if (password.text.length > 0)
            sddm.login(currentUser, password.text, sessionIndex)
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            root.loginFailed = true
            password.text = ""
            password.forceActiveFocus()
        }
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(460, root.width - 48)
        spacing: 28

        Text {
            text: "緑"
            color: "#FFFFFF"
            font.pixelSize: 70
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "R Y O K U"
            color: "#FFFFFF"
            font.pixelSize: 22
            font.weight: Font.Medium
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: root.currentUser
            color: "#A0A0A0"
            font.pixelSize: 14
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Row {
            width: parent.width
            height: 66
            spacing: 14

            Item {
                width: 66
                height: 66

                Rectangle {
                    anchors.fill: parent
                    radius: 33
                    color: "#121212"
                    border.color: "#424242"
                    border.width: 1
                }

                Rectangle {
                    width: 17
                    height: 17
                    radius: 9
                    x: 24.5
                    y: 16
                    color: "#F5F5F5"
                }

                Rectangle {
                    width: 32
                    height: 18
                    radius: 10
                    x: 17
                    y: 36
                    color: "#F5F5F5"
                }
            }

            Rectangle {
                width: parent.width - 80
                height: 66
                radius: 10
                color: "#101010"
                border.width: 1
                border.color: password.activeFocus
                    ? "#FFFFFF" : "#383838"

                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 50
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: "#FFFFFF"
                    selectionColor: "#555555"
                    font.pixelSize: 18
                    focus: true

                    onTextChanged: root.loginFailed = false
                    onAccepted: root.submitLogin()
                }

                Text {
                    text: "→"
                    color: "#D0D0D0"
                    font.pixelSize: 22
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                }

                MouseArea {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: 48
                    height: parent.height
                    onClicked: root.submitLogin()
                }
            }
        }

        Text {
            text: root.loginFailed
                ? "Senha incorreta. Tente novamente."
                : "Digite sua senha para entrar"
            color: root.loginFailed ? "#FFFFFF" : "#777777"
            font.pixelSize: 12
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
