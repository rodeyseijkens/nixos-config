import QtQuick
import QtQuick.Effects
import qs.Commons
import "../../"

Item {
  id: root

  property string wallpaperPath: ""
  property string userName: ""
  property bool authenticating: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property string passwordText: ""
  property bool syncingPasswordText: false
  property int focusRequestSerial: 0

  readonly property bool errorState: failureMessage.length > 0
  readonly property int fieldWidth: Math.min(300, Math.max(120, width - 40))
  readonly property int fieldHeight: 50

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearRequested()

  function passwordFocus() {
    if (inputEnabled && passwordInput.enabled) passwordInput.forceActiveFocus()
  }

  function forcePasswordFocus() {
    Qt.callLater(passwordFocus)
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  function submit() {
    var value = String(passwordInput.text || "")
    if (value.length === 0 || authenticating) return
    passwordTextEdited("")
    submitPassword(value)
  }

  function clear() {
    passwordTextEdited("")
    clearRequested()
    forcePasswordFocus()
  }

  onPasswordTextChanged: syncPasswordText()
  onFocusRequestSerialChanged: forcePasswordFocus()
  onInputEnabledChanged: {
    if (inputEnabled) forcePasswordFocus()
  }

  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) forcePasswordFocus()
  }

  Rectangle {
    anchors.fill: parent
    color: Colors.base00
  }

  Image {
    id: wallpaper
    anchors.fill: parent
    source: root.wallpaperPath ? Util.fileUrl(root.wallpaperPath) : ""
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
  }

  MultiEffect {
    anchors.fill: wallpaper
    source: wallpaper
    visible: wallpaper.status === Image.Ready
    blurEnabled: wallpaper.status === Image.Ready
    blur: 0.85
    blurMax: 96
    saturation: 1.17
    contrast: -0.08
  }

  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Colors.base00, 0.3)
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: Math.round(parent.height * 0.13)
    text: Qt.formatDateTime(clock.now, "HH:mm")
    color: Util.alpha(Colors.base06, 0.9)
    font.family: Colors.fontFamily
    font.pixelSize: 115
    font.weight: Font.DemiBold
    horizontalAlignment: Text.AlignHCenter
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: Math.round(parent.height * 0.24)
    text: "- " + Qt.formatDateTime(clock.now, "dddd, MMMM dd") + " -"
    color: Util.alpha(Colors.base06, 0.9)
    font.family: Colors.fontFamily
    font.pixelSize: 18
    horizontalAlignment: Text.AlignHCenter
  }

  Rectangle {
    id: userPill
    width: root.fieldWidth
    height: root.fieldHeight
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 270
    radius: 0
    color: Util.alpha(Colors.base05, 0.2)
    border.width: Style.normalBorderWidth
    border.color: Style.normalBorderFor(Colors.base05, Colors.base0D, Colors.base08)

    Row {
      anchors.centerIn: parent
      spacing: Style.spacing.md

      Text {
        text: ""
        color: Util.alpha(Colors.base06, 0.95)
        font.family: Colors.fontFamily
        font.pixelSize: 16
        font.weight: Font.DemiBold
        verticalAlignment: Text.AlignVCenter
      }

      Text {
        text: root.userName
        color: Util.alpha(Colors.base06, 0.95)
        font.family: Colors.fontFamily
        font.pixelSize: 15
        font.weight: Font.DemiBold
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  Rectangle {
    id: field
    width: root.fieldWidth
    height: root.fieldHeight
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 200
    radius: 0
    color: Util.alpha(Colors.base05, 0.2)
    border.width: root.errorState ? Style.focusBorderWidth : (passwordInput.activeFocus ? Style.focusBorderWidth : Style.normalBorderWidth)
    border.color: root.errorState
      ? Colors.base08
      : (passwordInput.activeFocus
        ? Style.focusBorderFor(Colors.base05, Colors.base0D, Colors.base08)
        : Style.normalBorderFor(Colors.base05, Colors.base0D, Colors.base08))

    TextInput {
      id: passwordInput
      anchors.fill: parent
      anchors.leftMargin: Style.spacing.panelPadding
      anchors.rightMargin: Style.spacing.panelPadding
      verticalAlignment: TextInput.AlignVCenter
      horizontalAlignment: TextInput.AlignHCenter
      activeFocusOnTab: true
      activeFocusOnPress: true
      enabled: root.inputEnabled && !root.authenticating
      readOnly: root.authenticating
      echoMode: TextInput.Password
      passwordCharacter: "\u25CF"
      passwordMaskDelay: 0
      color: Util.alpha(Colors.base06, 0.9)
      selectionColor: Util.alpha(Colors.base0D, 0.45)
      selectedTextColor: Colors.base07
      font.family: Colors.fontFamily
      font.pixelSize: 14
      font.weight: Font.DemiBold
      cursorVisible: activeFocus && !root.authenticating && text.length > 0
      Accessible.role: Accessible.EditableText
      Accessible.name: "Password"

      onTextChanged: {
        if (!root.syncingPasswordText) root.passwordTextEdited(text)
        if (text.length > 0 && root.failureMessage.length > 0) root.clearRequested()
      }

      onAccepted: root.submit()

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
          root.clear()
          event.accepted = true
        }
      }
    }

    Text {
      anchors.fill: passwordInput
      verticalAlignment: Text.AlignVCenter
      horizontalAlignment: Text.AlignHCenter
      visible: passwordInput.text.length === 0
      text: root.authenticating ? "Checking..." : "Enter Password"
      color: Util.alpha(Colors.base06, 0.9)
      font.family: Colors.fontFamily
      font.pixelSize: 14
      font.weight: Font.DemiBold
      font.italic: true
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: field.bottom
    anchors.topMargin: Style.spacing.sm
    width: root.fieldWidth
    horizontalAlignment: Text.AlignHCenter
    visible: root.errorState
    text: root.failureMessage
    color: Colors.base08
    font.family: Colors.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Timer {
    id: clock
    interval: 1000
    repeat: true
    running: true
    triggeredOnStart: true
    property date now: new Date()
    onTriggered: now = new Date()
  }
}
