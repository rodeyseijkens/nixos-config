import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Hyprland
import qs.Commons as Commons
import qs.Ui
import "../../services"
import "PolkitModel.js" as PolkitModel

Item {
  id: root

  property string fontFamily: Commons.Style.font.menuFamily
  // Bound to the central [polkit] section in shell.toml via Commons.Color.qml.
  property color accent: Commons.Color.polkit.accent
  property color background: Commons.Color.polkit.background
  property color foreground: Commons.Color.polkit.text
  property color border: Commons.Color.polkit.border
  property color borderError: Commons.Color.polkit.borderError
  property var borderSpec: Commons.Border.surfaceSpec("polkit", errorFlash ? "border-error" : "border", errorFlash ? borderError : border, Math.max(1, Commons.Style.space(2)), "border-alpha")
  property color scrim: Commons.Color.polkit.scrim
  readonly property int cornerRadius: Commons.Style.cornerRadius
  property int contentMargin: Commons.Style.spacing.panelPadding
  property int fieldHeight: Math.max(Commons.Style.space(42), Commons.Style.spacing.controlHeight)

  property bool closing: false
  property bool submitted: false
  property string currentMessage: ""
  property string currentPrompt: ""
  property string currentSupplementary: ""
  property bool responseRequired: false
  property bool responseVisible: false
  property bool failed: false
  property bool errorFlash: false
  // pam_fprintd appears in the polkit PAM stack (a sensor is enrolled).
  property bool fingerprintConfigured: false
  // Lid shut right now — the reader is physically unreachable, so we fall back
  // to the password even when a sensor is enrolled. Refreshed per request.
  property bool laptopClosed: false
  property int shakeOffset: 0
  // The password lives on root, not on the per-screen TextInput clone. IDs
  // declared inside `content: Component` are not visible to these functions.
  property string passwordText: ""

  signal focusFieldRequested()

  readonly property string activeScreenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens.length > 0 ? (Quickshell.screens[0].name ?? "") : "")

  readonly property bool dialogVisible: polkitAgent.isActive || closing
  // We show one method at a time. Fingerprint owns the dialog while PAM is
  // waiting on the reader (lid open, sensor enrolled); the moment PAM asks for
  // a password — including immediately when the lid is shut and the clamshell
  // gate skips pam_fprintd — we switch to the password field instead.
  readonly property bool fingerprintMode: fingerprintConfigured && !laptopClosed && dialogVisible && !responseRequired && !submitted && !errorFlash

  onDialogVisibleChanged: if (dialogVisible) Qt.callLater(refocus)


  function authorizationLabel(message) {
    return message ? PolkitModel.authorizationLabel(message, Commons.I18n.t) : Commons.I18n.t("polkit.authenticationNeeded")
  }

  function loadPamConfig(raw) {
    fingerprintConfigured = PolkitModel.fingerprintConfiguredFromPamConfig(raw)
  }

  function refreshLidState() {
    if (!laptopClosedProc.running) laptopClosedProc.running = true
  }

  function resetSnapshot() {
    currentMessage = ""
    currentPrompt = ""
    currentSupplementary = ""
    responseRequired = false
    responseVisible = false
    failed = false
    errorFlash = false
    submitted = false
    passwordText = ""
  }

  function syncFromFlow() {
    var flow = polkitAgent.flow
    if (!flow) return

    currentMessage = String(flow.message || "")
    currentPrompt = String(flow.inputPrompt || "")
    currentSupplementary = String(flow.supplementaryMessage || "")
    responseRequired = !!flow.isResponseRequired
    responseVisible = !!flow.responseVisible
    failed = !!flow.failed

    if (responseRequired) submitted = false
  }

  function beginFlow() {
    closeTimer.stop()
    closing = false
    submitted = false
    passwordText = ""
    refreshLidState()
    syncFromFlow()
    Qt.callLater(refocus)
  }

  // The TextInput is created inside the ScreenPopup content component, so the
  // request is broadcast and the (single) visible surface picks it up.
  function refocus() {
    if (!dialogVisible) return
    focusFieldRequested()
  }

  function submitResponse() {
    var flow = polkitAgent.flow
    if (!flow || !flow.isResponseRequired) return
    submitted = true
    errorFlash = false
    flow.submit(passwordText)
    passwordText = ""
    Qt.callLater(refocus)
  }

  function cancelRequest() {
    var flow = polkitAgent.flow
    passwordText = ""
    submitted = false
    closing = true
    closeTimer.restart()
    if (flow) flow.cancelAuthenticationRequest()
  }

  function triggerFailureFeedback() {
    submitted = false
    errorFlash = true
    passwordText = ""
    errorTimer.restart()
    shakeAnimation.restart()
    Qt.callLater(refocus)
  }

  Timer {
    id: closeTimer
    interval: 300
    repeat: false
    onTriggered: {
      closing = false
      resetSnapshot()
    }
  }

  Timer {
    id: errorTimer
    interval: 1200
    repeat: false
    onTriggered: root.errorFlash = false
  }

  SequentialAnimation {
    id: shakeAnimation
    NumberAnimation { target: root; property: "shakeOffset"; to: -8; duration: Commons.Style.duration(35); easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "shakeOffset"; to: 8; duration: Commons.Style.duration(50); easing.type: Easing.InOutQuad }
    NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: Commons.Style.duration(55); easing.type: Easing.OutQuad }
  }
  FileView {
    path: "/etc/pam.d/polkit-1"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadPamConfig(text())
    onLoadFailed: root.fingerprintConfigured = false
    onFileChanged: reload()
  }

  Process {
    id: laptopClosedProc
    command: ["bash", "-c", "grep -qs closed /proc/acpi/button/lid/*/state && echo closed || echo open"]
    stdout: StdioCollector { id: laptopClosedOut; waitForEnd: true }
    onExited: root.laptopClosed = String(laptopClosedOut.text || "").trim() === "closed"
  }

  PolkitAgent {
    id: polkitAgent
    path: "/org/quickshell/PolkitAgent"

    onAuthenticationRequestStarted: root.beginFlow()
    onIsActiveChanged: {
      if (isActive) {
        root.syncFromFlow()
        Qt.callLater(root.refocus)
      } else if (!root.closing) root.resetSnapshot()
    }
    onIsRegisteredChanged: {
      if (isRegistered) console.log("quickshell polkit agent registered")
      else console.warn("quickshell polkit agent is not registered; another agent may be running")
    }
  }

  Connections {
    target: polkitAgent.flow

    function onIsResponseRequiredChanged() {
      root.syncFromFlow()
      if (!polkitAgent.flow || !polkitAgent.flow.isResponseRequired) root.passwordText = ""
      Qt.callLater(root.refocus)
    }

    function onInputPromptChanged() { root.syncFromFlow() }
    function onResponseVisibleChanged() { root.syncFromFlow() }
    function onSupplementaryMessageChanged() { root.syncFromFlow() }
    function onFailedChanged() { root.syncFromFlow() }

    function onAuthenticationFailed() {
      root.syncFromFlow()
      root.triggerFailureFeedback()
    }

    function onAuthenticationSucceeded() {
      root.closing = true
      closeTimer.restart()
    }

    function onAuthenticationRequestCancelled() {
      root.closing = true
      closeTimer.restart()
    }
  }

  ScreenPopup {
    placement: PopupPlacement {
      left: true
      right: true
      top: true
      bottom: true
    }
    showWhen: name => root.dialogVisible && name === root.activeScreenName
    focusable: true
    focusGrab: true
    onDismissRequested: root.cancelRequest()

    content: Component {
      Item {
        id: surface
        anchors.fill: parent
        readonly property int cardHeight: height > 0
          ? Math.min(root.fieldHeight + root.contentMargin * 2, height - Commons.Style.gapsOut * 2)
          : root.fieldHeight + root.contentMargin * 2
        readonly property int cardWidth: root.fingerprintMode
          ? cardHeight
          : Math.min(Commons.Style.space(312), Math.max(Commons.Style.space(260), width - Commons.Style.gapsOut * 2))

        Connections {
          target: root
          function onFocusFieldRequested() {
            // No field exists while the fingerprint reader owns the dialog;
            // park focus on the key catcher so Escape still cancels.
            if (root.fingerprintMode) keyCatcher.forceActiveFocus()
            else passwordInput.forceActiveFocus()
          }
        }

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.refocus()
    }

    BorderSurface {
      id: card
      width: surface.cardWidth
      height: surface.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      anchors.horizontalCenterOffset: root.shakeOffset
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: root.refocus() }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.cancelRequest()
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.responseRequired) root.submitResponse()
            event.accepted = true
          }
        }
      }

      // Fingerprint mode shows just the sensor icon, centered and alone \u2014 no
      // padlock, no field, no prompt text.
      OpticalGlyph {
        anchors.centerIn: parent
        width: Math.round(root.fieldHeight * 0.7)
        height: width
        visible: root.fingerprintMode
        text: "\udb80\ude37"
        fontFamily: root.fontFamily
        fontSize: Math.round(root.fieldHeight * 0.7)
        color: root.errorFlash ? Commons.Color.polkit.textError : root.accent
      }

      Row {
        id: cardRow
        visible: !root.fingerprintMode
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Commons.Style.space(14)

        Text {
          text: "\uf023"
          color: root.errorFlash ? Commons.Color.polkit.textError : root.accent
          font.family: root.fontFamily
          font.pixelSize: Commons.Style.font.iconLarge
          width: Commons.Style.space(26)
          height: root.fieldHeight
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }

        Item {
          width: parent.width - Commons.Style.space(40)
          height: root.fieldHeight

          TextInput {
            id: passwordInput
            anchors.fill: parent
            verticalAlignment: TextInput.AlignVCenter
            activeFocusOnPress: true
            clip: true
            text: root.passwordText
            onTextEdited: root.passwordText = text
            selectionColor: Commons.Util.alpha(root.accent, 0.45)
            selectedTextColor: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Commons.Style.font.iconLarge
            echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
            passwordCharacter: "\u2022"
            color: root.errorFlash ? Commons.Color.polkit.textError : root.foreground
            cursorVisible: activeFocus && !root.submitted && !root.errorFlash
            readOnly: root.submitted || root.errorFlash
            enabled: root.dialogVisible
            onAccepted: root.submitResponse()
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                root.cancelRequest()
                event.accepted = true
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.errorFlash ? Commons.I18n.t("polkit.wrong") : (root.submitted ? Commons.I18n.t("polkit.checking") : Commons.I18n.t("polkit.enterPassword"))
            color: root.errorFlash ? Commons.Color.polkit.textError : root.foreground
            opacity: root.errorFlash ? 1 : 0.36
            font.family: root.fontFamily
            font.pixelSize: Commons.Style.font.iconLarge
            elide: Text.ElideRight
            visible: passwordInput.text.length === 0
          }

          Rectangle {
            width: Math.max(1, Commons.Style.space(2))
            height: Commons.Style.space(24)
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: root.errorFlash ? Commons.Color.polkit.textError : root.foreground
            visible: passwordInput.visible && passwordInput.activeFocus && passwordInput.text.length === 0 && !root.submitted && !root.errorFlash
          }

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            enabled: passwordInput.visible
            onClicked: passwordInput.forceActiveFocus()
          }
        }
      }
    }

    Rectangle {
      width: Math.min(justificationText.implicitWidth + Commons.Style.space(24), surface.width - Commons.Style.gapsOut * 2)
      height: Commons.Style.space(28)
      anchors.horizontalCenter: card.horizontalCenter
      anchors.bottom: card.top
      anchors.bottomMargin: Commons.Style.space(10)
      radius: root.cornerRadius
      color: root.background

      Text {
        id: justificationText
        textFormat: Text.PlainText
        anchors.fill: parent
        anchors.leftMargin: Commons.Style.space(12)
        anchors.rightMargin: Commons.Style.space(12)
        text: root.authorizationLabel(root.currentMessage)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Commons.Style.font.bodySmall
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideMiddle
      }
    }
  }
      }
    }
}
