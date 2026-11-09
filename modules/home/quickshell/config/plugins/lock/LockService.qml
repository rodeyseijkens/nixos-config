import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import "../../"

Item {
  id: root

  property string pamService: "hyprlock"
  property string wallpaperPath: "/home/rodey/nixos-config/wallpapers/raw/fern.jpg"

  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
  readonly property bool locked: lockRequested || sessionLock.locked || sessionLock.secure
  readonly property bool authenticating: authenticatingPassword

  property bool lockRequested: false
  property bool authenticatingPassword: false
  property string enteredPassword: ""
  property string pendingPassword: ""
  property string failureMessage: ""
  property int failedAttempts: 0
  property string lastEvent: "init"
  property int focusRequestSerial: 0

  function beginLock() {
    if (lockRequested) return "ok"
    resetAuthentication()
    lockRequested = true
    sessionLock.locked = true
    lastEvent = "lock-requested"
    Qt.callLater(function() { root.forceFocus() })
    return "ok"
  }

  function finishUnlock() {
    if (!lockRequested) return
    lockRequested = false
    resetAuthentication()
    sessionLock.locked = false
    lastEvent = "unlocked"
  }

  function resetAuthentication() {
    enteredPassword = ""
    pendingPassword = ""
    failureMessage = ""
    failedAttempts = 0
    authenticatingPassword = false
    if (passwordPam.active) passwordPam.abort()
  }

  function submitPassword(value) {
    var password = String(value || "")
    if (!lockRequested || authenticatingPassword || password.length === 0) return

    pendingPassword = password
    failureMessage = ""
    authenticatingPassword = true

    if (!passwordPam.start()) {
      handleFailure()
      return
    }

    Qt.callLater(respondToPrompt)
  }

  function respondToPrompt() {
    if (!authenticatingPassword || !passwordPam.active || !passwordPam.responseRequired) return
    passwordPam.respond(pendingPassword)
  }

  function handleFailure() {
    if (!lockRequested) return
    authenticatingPassword = false
    enteredPassword = ""
    pendingPassword = ""
    failedAttempts += 1
    failureMessage = "Authentication failed (" + failedAttempts + ")"
    lastEvent = "auth-failed"
    Qt.callLater(function() { root.forceFocus() })
  }

  function forceFocus() {
    focusRequestSerial += 1;
  }

  function statusJson() {
    return JSON.stringify({
      locked: locked,
      requested: lockRequested,
      sessionLocked: sessionLock.locked,
      secure: sessionLock.secure,
      authenticating: authenticatingPassword,
      failedAttempts: failedAttempts,
      pamActive: passwordPam.active,
      user: userName,
      lastEvent: lastEvent
    })
  }

  WlSessionLock {
    id: sessionLock
    locked: false

    onLockStateChanged: {
      if (locked) root.lastEvent = "locked"
    }

    onSecureStateChanged: {
      if (secure) root.forceFocus()
    }

    WlSessionLockSurface {
      color: Colors.base00

      LockView {
        id: lockView
        anchors.fill: parent
        wallpaperPath: root.wallpaperPath
        userName: root.userName
        authenticating: root.authenticatingPassword
        failureMessage: root.failureMessage
        failedAttempts: root.failedAttempts
        focusRequestSerial: root.focusRequestSerial
        inputEnabled: root.lockRequested
        passwordText: root.enteredPassword
        onPasswordTextEdited: function(password) { root.enteredPassword = password }
        onSubmitPassword: function(password) { root.submitPassword(password) }
        onClearRequested: root.failureMessage = ""
      }
    }
  }

  PamContext {
    id: passwordPam
    config: root.pamService
    user: root.userName

    onResponseRequiredChanged: root.respondToPrompt()
    onPamMessage: root.respondToPrompt()

    onCompleted: function(result) {
      root.authenticatingPassword = false
      root.pendingPassword = ""
      if (!root.lockRequested) return
      if (result === PamResult.Success) root.finishUnlock()
      else root.handleFailure()
    }

    onError: function(error) {
      root.handleFailure()
    }
  }

  IpcHandler {
    target: "lock"

    function lock(): string {
      return root.beginLock()
    }

    function isLocked(): string {
      return root.locked ? "true" : "false"
    }

    function status(): string {
      return root.statusJson()
    }
  }
}
