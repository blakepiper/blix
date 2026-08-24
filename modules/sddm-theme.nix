{ pkgs, palette, font }:

let
  c = palette.colors;

  mainQml = pkgs.writeText "blix-sddm-main.qml" ''
    import QtQuick 2.15
    import SddmComponents 2.0

    Rectangle {
      id: root
      width: 1920
      height: 1080
      color: "${c.background}"

      property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
      property bool loginFailed: false

      function userName(index) {
        return (userModel.data(userModel.index(index, 0), Qt.UserRole + 1) || "").toString()
      }

      property string currentUser: {
        if (userModel.lastUser && userName(userModel.lastIndex) === userModel.lastUser)
          return userModel.lastUser
        if (userModel.rowCount() > 0)
          return userName(0)
        return ""
      }

      function sessionName(index) {
        return (sessionModel.data(sessionModel.index(index, 0), Qt.UserRole + 1) || "").toString()
      }

      function cycleSession(step) {
        var count = sessionModel.rowCount()
        if (count > 0)
          root.sessionIndex = (root.sessionIndex + step + count) % count
      }

      function submitLogin() {
        if (root.currentUser !== "")
          sddm.login(root.currentUser, password.text, root.sessionIndex)
      }

      Connections {
        target: sddm

        function onLoginFailed() {
          root.loginFailed = true
          password.text = ""
          password.forceActiveFocus()
        }

        function onLoginSucceeded() {
          root.loginFailed = false
        }
      }

      Image {
        anchors.fill: parent
        source: "file://${palette.wallpaper}"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
      }

      Rectangle {
        anchors.fill: parent
        color: "${c.background}"
        opacity: 0.58
      }

      Rectangle {
        anchors.centerIn: parent
        width: 420
        height: 238
        color: "${c.surface}"
        opacity: 0.94
        border.width: 2
        border.color: "${c.border}"

        Column {
          anchors.fill: parent
          anchors.margins: 36
          spacing: 18

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "BLIX"
            color: "${c.foreground}"
            font.family: "${font}"
            font.pixelSize: 40
            font.bold: true
            font.letterSpacing: 8
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.currentUser
            color: "${c.muted}"
            font.family: "${font}"
            font.pixelSize: 14
          }

          Rectangle {
            width: parent.width
            height: 50
            color: "${c.elevated}"
            border.width: 2
            border.color: root.loginFailed ? "${c.red}" : "${c.border}"

            Text {
              anchors.centerIn: parent
              visible: password.text.length === 0
              text: "password"
              color: "${c.muted}"
              font.family: "${font}"
              font.pixelSize: 15
            }

            TextInput {
              id: password
              anchors.fill: parent
              anchors.leftMargin: 16
              anchors.rightMargin: 16
              verticalAlignment: TextInput.AlignVCenter
              horizontalAlignment: TextInput.AlignHCenter
              echoMode: TextInput.Password
              color: "${c.foreground}"
              selectionColor: "${c.primary}"
              selectedTextColor: "${c.background}"
              font.family: "${font}"
              font.pixelSize: 18
              focus: true

              onTextChanged: root.loginFailed = false

              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Tab) {
                  root.cycleSession(event.modifiers & Qt.ShiftModifier ? -1 : 1)
                  event.accepted = true
                } else if (event.key === Qt.Key_Backtab) {
                  root.cycleSession(-1)
                  event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  root.submitLogin()
                  event.accepted = true
                }
              }
            }
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.loginFailed ? "authentication failed" : "press Enter to continue"
            color: root.loginFailed ? "${c.red}" : "${c.muted}"
            font.family: "${font}"
            font.pixelSize: 12
          }
        }
      }

      Rectangle {
        id: sessionPicker
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 28
        anchors.bottomMargin: 28
        width: 236
        height: 58
        color: "${c.surface}"
        opacity: 0.94
        border.width: 2
        border.color: pickerMouse.containsMouse ? "${c.primary}" : "${c.border}"

        Column {
          anchors.centerIn: parent
          spacing: 3

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "SESSION  ‹  " + root.sessionName(root.sessionIndex) + "  ›"
            color: "${c.foreground}"
            font.family: "${font}"
            font.pixelSize: 13
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "click or press Tab to switch"
            color: "${c.muted}"
            font.family: "${font}"
            font.pixelSize: 10
          }
        }

        MouseArea {
          id: pickerMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.cycleSession(1)
            password.forceActiveFocus()
          }
        }
      }

      Component.onCompleted: password.forceActiveFocus()
    }
  '';

  metadata = pkgs.writeText "blix-sddm-metadata.desktop" ''
    [SddmGreeterTheme]
    Name=Blix
    Description=Blix login and session-switching theme
    Author=Blix contributors
    Type=sddm-theme
    Version=1.0
    QtVersion=6
  '';
in
pkgs.runCommand "blix-sddm-theme" { } ''
  mkdir -p "$out"
  cp ${mainQml} "$out/Main.qml"
  cp ${metadata} "$out/metadata.desktop"
''
