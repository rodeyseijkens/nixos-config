import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  // ---- host contract -----------------------------------------------------
  property var settings: ({})
  property string moduleName: "power"
  property var bar: null

  // ---- bar-widget API ----------------------------------------------------
  readonly property color foreground: Commons.Color.foreground
  readonly property string fontFamily: Style.font.family

  readonly property bool batteryPresent: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent)
  }
  readonly property bool discharging: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent && UPower.onBattery)
  }
  readonly property bool fullyCharged: {
    var device = UPower.displayDevice
    return device && device.isPresent && device.state === UPowerDeviceState.FullyCharged && !root.chargeThresholdActive
  }
  readonly property bool chargeThresholdActive: {
    var device = UPower.displayDevice
    return Model.chargeThresholdActive(device, root.discharging, upowerStates())
  }
  readonly property real batteryFraction: Model.batteryFraction(UPower.displayDevice)
  readonly property bool batteryFlowIdle: root.fullyCharged || root.chargeThresholdActive
  readonly property bool charging: {
    var d = UPower.displayDevice
    return !!(d && d.isPresent && !UPower.onBattery && !root.batteryFlowIdle)
  }
  readonly property string icon: batteryIcon()
  readonly property string statusText: modeLabel()
  readonly property bool urgent: root.batteryPresent && !root.charging && root.batteryFraction <= 0.15
  readonly property bool active: root.batteryPresent
  readonly property bool available: root.batteryPresent

  readonly property bool showPercentage: root.setting("showPercentage", false) === true
  property var profiles: [ "power-saver", "balanced", "performance" ]
  property string activeProfile: "balanced"
  property int profileIndex: 1
  property var batteryInfo: ({})
  property var systemInfo: ({})
  property int phraseIndex: 0

  readonly property var chargingPhrases: [
    I18n.t("power.chargingPhrase1", "Energy flowing, circuits humming"),
    I18n.t("power.chargingPhrase2", "Topping up the tank"),
    I18n.t("power.chargingPhrase3", "Charging at full tilt"),
    I18n.t("power.chargingPhrase4", "Current incoming"),
    I18n.t("power.chargingPhrase5", "Refilling the electrons"),
    I18n.t("power.chargingPhrase6", "Plugged in and powering up"),
    I18n.t("power.chargingPhrase7", "Juice on the way"),
    I18n.t("power.chargingPhrase8", "Battery taking on charge"),
    I18n.t("power.chargingPhrase9", "Feeding the battery")
  ]
  readonly property var onBatteryPhrases: [
    I18n.t("power.dischargingPhrase1", "Running on stored energy"),
    I18n.t("power.dischargingPhrase2", "Cut the cord, still going"),
    I18n.t("power.dischargingPhrase3", "Battery carrying the load"),
    I18n.t("power.dischargingPhrase4", "On battery power"),
    I18n.t("power.dischargingPhrase5", "Drawing from the cell"),
    I18n.t("power.dischargingPhrase6", "Unplugged and rolling"),
    I18n.t("power.dischargingPhrase7", "Spending stored charge"),
    I18n.t("power.dischargingPhrase8", "Battery at work"),
    I18n.t("power.dischargingPhrase9", "Portable and powered")
  ]
  readonly property var activePhrases: {
    if (root.fullyCharged) return []
    if (root.charging) return root.chargingPhrases
    if (root.discharging) return root.onBatteryPhrases
    return []
  }
  readonly property bool rotatingPhrases: root.activePhrases.length > 0
  readonly property string heroStatusText: {
    if (root.fullyCharged) return I18n.t("power.fullyCharged", "Fully charged")
    if (root.rotatingPhrases) return root.activePhrases[root.phraseIndex % root.activePhrases.length]
    return root.modeLabel()
  }

  // Geometry is content driven; PanelHost lets a ScreenPopup size itself from
  // this implicit height.
  implicitWidth: 360
  implicitHeight: surface.height

  function setting(name, fallback) {
    var value = root.settings ? root.settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function upowerStates() {
    return {
      Charging: UPowerDeviceState.Charging,
      Discharging: UPowerDeviceState.Discharging,
      FullyCharged: UPowerDeviceState.FullyCharged,
      PendingCharge: UPowerDeviceState.PendingCharge
    }
  }

  function batteryIcon() {
    return Model.batteryIcon(UPower.displayDevice, root.discharging, upowerStates())
  }

  function modeLabel() {
    return Model.modeLabel(UPower.displayDevice, root.discharging, upowerStates(), I18n.t)
  }

  function reading(raw) {
    return Model.localizeReading(raw, I18n.formatNumber)
  }

  // UPower CLI output -> the flat key/value shape the upstream panel used.
  // Keys: percentage, size, cycles, time, rate, threshold, state.
  function parseUpower(raw) {
    var out = {}
    var lines = String(raw || "").split(/\r?\n/)
    var capacity = ""
    var design = ""
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      var idx = line.indexOf(":")
      if (idx <= 0) continue
      var key = line.substring(0, idx).trim().toLowerCase()
      var value = line.substring(idx + 1).trim()
      if (key === "percentage") out.percentage = value
      else if (key === "capacity") capacity = value
      else if (key === "energy-full-design") design = value
      else if (key === "energy-full" && design === "") out.size = value
      else if (key === "cycle count") out.cycles = value
      else if (key === "energy-rate") out.rate = value
      else if (key === "time to empty" || key === "time to full") out.time = value
      else if (key === "charge-threshold" || key === "charge threshold") out.threshold = value
      else if (key === "state") out.state = value
    }
    if (out.size === undefined && capacity !== "") out.size = capacity
    return out
  }

  function parsePowerProfiles(raw) {
    var text = String(raw || "")
    var active = ""
    var listed = []
    var lines = text.split(/\r?\n/)
    for (var i = 0; i < lines.length; i++) {
      var match = /^\s*(\*)?\s*([a-z][a-z-]*):\s*$/.exec(lines[i])
      if (!match) continue
      var name = match[2]
      if (name === "driver" || name === "placeholder") continue
      if (listed.indexOf(name) === -1) listed.push(name)
      if (match[1] === "*") active = name
    }
    return { profiles: listed, active: active }
  }

  function parseSystemStats(raw) {
    var out = {}
    var lines = String(raw || "").split(/\r?\n/)
    for (var i = 0; i < lines.length; i++) {
      var idx = lines[i].indexOf("\t")
      if (idx <= 0) continue
      out[lines[i].substring(0, idx)] = lines[i].substring(idx + 1).trim()
    }
    return out
  }

  function refresh() {
    if (!root.batteryPresent) return
    if (!batteryProc.running) batteryProc.running = true
    if (!profilesProc.running) profilesProc.running = true
    if (!systemProc.running) systemProc.running = true
  }

  function setProfile(profile) {
    if (!profile || actionProc.running) return
    actionProc.command = ["powerprofilesctl", "set", profile]
    actionProc.running = true
    root.activeProfile = profile
  }

  function formatBytes(bytes) {
    var n = Number(bytes)
    if (!isFinite(n) || n < 0) n = 0
    if (n < 1024) return Math.round(n) + " B"
    if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KB"
    if (n < 1024 * 1024 * 1024) return (n / (1024 * 1024)).toFixed(1) + " MB"
    return (n / (1024 * 1024 * 1024)).toFixed(2) + " GB"
  }

  Component.onCompleted: refresh()

  onBatteryPresentChanged: if (root.batteryPresent) refresh()

  Timer {
    interval: 5000
    running: root.batteryPresent
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 2800
    running: root.rotatingPhrases
    repeat: true
    onTriggered: root.phraseIndex = (root.phraseIndex + 1) % Math.max(1, root.activePhrases.length)
  }

  Process {
    id: batteryProc
    command: ["bash", "-c", "upower -e | grep -m1 'BAT' | xargs -r upower -i"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var next = root.parseUpower(text)
        if (Object.keys(next).length > 0) root.batteryInfo = next
      }
    }
  }

  Process {
    id: profilesProc
    command: ["bash", "-c", "powerprofilesctl get 2>/dev/null; echo '---'; powerprofilesctl list 2>/dev/null"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parts = String(text || "").split("---")
        var active = String(parts[0] || "").trim()
        var parsed = root.parsePowerProfiles(parts.slice(1).join("---"))
        if (parsed.profiles.length > 0) root.profiles = parsed.profiles
        root.activeProfile = active !== "" ? active : (parsed.active || root.activeProfile)
        var idx = root.profiles.indexOf(root.activeProfile)
        root.profileIndex = idx >= 0 ? idx : 0
      }
    }
  }

  Process {
    id: systemProc
    command: ["bash", "-c",
      "printf 'cpu\\t%s\\n' \"$(top -bn1 2>/dev/null | awk '/Cpu\\(s\\)/ {print 100-$8; exit}')\"; " +
      "printf 'mem\\t%s\\n' \"$(free -b 2>/dev/null | awk '/Mem:/ {print $3\"/\"$2}')\"; " +
      "printf 'load\\t%s\\n' \"$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)\"; " +
      "printf 'uptime\\t%s\\n' \"$(cut -d' ' -f1 /proc/uptime 2>/dev/null)\"; " +
      "printf 'procs\\t%s\\n' \"$(ps -e --no-headers 2>/dev/null | wc -l)\""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var next = root.parseSystemStats(text)
        if (Object.keys(next).length > 0) root.systemInfo = next
      }
    }
  }

  Process {
    id: actionProc
    onExited: root.refresh()
  }

  BorderSurface {
    id: surface
    width: parent.width
    height: Math.min(column.implicitHeight + Style.spacing.panelPadding * 2, 620)
    color: Commons.Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Math.max(1, Style.space(2)))
    radius: Style.cornerRadius

    Flickable {
      id: flick
      anchors.fill: parent
      anchors.margins: Style.spacing.panelPadding
      contentWidth: width
      contentHeight: column.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      Column {
        id: column
        width: flick.width
        spacing: Style.space(14)

        // ---- Hero: battery icon, labels, percentage ----
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroPercent.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.batteryIcon() || "—"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroPercent.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: I18n.t("power.battery", "Battery")
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: root.heroStatusText.toUpperCase()
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Text {
            id: heroPercent
            textFormat: Text.PlainText
            text: root.reading(root.batteryInfo.percentage) || "—"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // ---- Battery progress bar ----
        Item {
          width: parent.width
          implicitHeight: Style.space(8)

          Rectangle {
            id: barTrack
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
          }

          Rectangle {
            id: barFill
            anchors.left: barTrack.left
            anchors.verticalCenter: barTrack.verticalCenter
            height: barTrack.height
            radius: barTrack.radius
            color: root.foreground
            width: Math.max(barTrack.height, barTrack.width * root.batteryFraction)
          }
        }

        // ---- Battery stats ----
        Row {
          visible: root.batteryInfo.percentage !== undefined
          width: parent.width
          spacing: Style.space(20)

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair { label: I18n.t("power.batterySize", "Battery size"); value: root.reading(root.batteryInfo.size) }
            InfoPair { label: I18n.t("power.chargeCycles", "Charge cycles"); value: root.reading(root.batteryInfo.cycles) || "—" }
          }

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair {
              label: root.chargeThresholdActive ? I18n.t("power.chargeLimit", "Charge limit") : (root.discharging ? I18n.t("power.timeLeft", "Time left") : I18n.t("power.timeToFull", "Time to full"))
              value: root.chargeThresholdActive ? (root.reading(root.batteryInfo.threshold) || "-") : (root.batteryFlowIdle ? "-" : (root.batteryInfo.time || "—"))
            }
            InfoPair {
              label: root.chargeThresholdActive ? I18n.t("power.batteryState", "Battery state") : (root.discharging ? I18n.t("power.discharging", "Discharging") : I18n.t("power.charging", "Charging"))
              value: root.chargeThresholdActive ? I18n.t("power.holding", "Holding") : (root.batteryFlowIdle ? "-" : root.reading(root.batteryInfo.rate))
            }
          }
        }

        // ---- Power profile picker ----
        PanelSeparator { foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: I18n.t("power.powerProfile", "Power profile")
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            id: profileRow
            width: parent.width
            spacing: Style.space(6)

            readonly property real cellWidth: root.profiles.length > 0
              ? (width - spacing * (root.profiles.length - 1)) / root.profiles.length
              : 0

            Repeater {
              model: root.profiles
              Button {
                required property var modelData
                width: profileRow.cellWidth
                iconText: Model.profileIcon(String(modelData))
                iconSize: Style.font.title
                text: Model.profileLabel(modelData, I18n.t)
                fontSize: Style.font.bodySmall
                foreground: root.foreground
                fontFamily: root.fontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: root.activeProfile === modelData
                onClicked: root.setProfile(modelData)
                onHovered: function(h) {
                  if (h) root.profileIndex = root.profiles.indexOf(modelData)
                }
              }
            }
          }
        }

        // ---- System stats ----
        PanelSeparator { foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.spacing.labelGap

          PanelSectionHeader {
            text: I18n.t("power.systemStats", "System stats")
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(20)

            Column {
              width: (parent.width - parent.spacing) / 2
              spacing: Style.spacing.labelGap
              InfoPair { label: I18n.t("power.cpuUsage", "CPU"); value: (root.systemInfo.cpu !== undefined ? root.systemInfo.cpu + "%" : "—") }
              InfoPair { label: I18n.t("power.memory", "Memory"); value: root.systemInfo.mem !== undefined ? root.formatMemory(root.systemInfo.mem) : "—" }
            }

            Column {
              width: (parent.width - parent.spacing) / 2
              spacing: Style.spacing.labelGap
              InfoPair { label: I18n.t("power.loadAverage", "Load"); value: root.systemInfo.load || "—" }
              InfoPair { label: I18n.t("power.processes", "Processes"); value: root.systemInfo.procs || "—" }
            }
          }
        }
      }
    }
  }

  function formatMemory(value) {
    var parts = String(value || "").split("/")
    if (parts.length !== 2) return value
    return root.formatBytes(parseFloat(parts[0])) + " / " + root.formatBytes(parseFloat(parts[1]))
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    InfoValue { text: value }
  }

  component InfoLabel: Text {
    textFormat: Text.PlainText
    color: root.foreground
    opacity: 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
