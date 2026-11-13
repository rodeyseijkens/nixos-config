pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import qs.Ui
import "../../../"
import qs.Commons
import qs.Commons as Commons
import "../../../services"
import "Model.js" as Model

// Bluetooth panel body, vendored from the upstream bluetooth plugin. This is the
// popup content only: the bar button and the panel window live in the host
// (services/PanelHost.qml + services/ScreenPopup.qml). Device actions run
// through Quickshell.Bluetooth (BluetoothAdapter/BluetoothDevice) and audio
// hand-off goes through Quickshell.Services.Pipewire — no bluetooth helper
// or the default-output helper helper CLIs remain.
Item {
  id: root

  // ----- Host-injected context -----
  property QtObject bar: null
  property var settings: ({})
  property string moduleName: "bluetooth"

  // ----- Bar-widget API (for a future widget) -----
  readonly property string icon: {
    if (!adapter) return ""
    if (!adapter.enabled) return "\u{f00b2}"
    if (connectedDevices.length > 0) return "\u{f00b1}"
    return "\u{f00af}"
  }
  readonly property string statusText: heroStatusText
  readonly property bool active: !!adapter && adapter.enabled

  // ----- Theme -----
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // The panel is loaded only while the host popup is open, so it is always
  // "opened" here. Kept as a property so the discovery logic reads the same.
  readonly property bool opened: true

  // Address -> "connecting" | "disconnecting" | "forgetting". BlueZ owns the
  // sequencing now (device.connect()/pair()/disconnect()/forget()); this map
  // only keeps the panel responsive while BlueZ catches up.
  property var pendingActions: ({})

  // The Quickshell.Bluetooth singleton is reached through an untyped alias:
  // the linter cannot resolve the module's pointer-typed members
  // (BluetoothAdapter, UntypedObjectModel) and flags a direct read.
  readonly property var bluetooth: Bluetooth
  readonly property var adapter: bluetooth ? bluetooth.defaultAdapter : null

  // True while this instance owes BlueZ a StopDiscovery: set when it starts
  // discovery (or opens onto a session already running) and cleared once
  // discovery is confirmed down after close. Ownership, not state — BlueZ's
  // Discovering property also reflects sessions other clients hold, which are
  // never this panel's to stop.
  property bool owesDiscoveryStop: false
  readonly property var devices: bluetooth && bluetooth.devices ? bluetooth.devices.values : []
  readonly property var pipewireNodes: Pipewire.nodes ? Pipewire.nodes.values : []
  property var pendingAudioOutputDevice: null
  property int pendingAudioOutputAttempts: 0

  function deviceLabel(device) {
    return Model.deviceLabel(device)
  }

  function hasHumanName(device) {
    return Model.hasHumanName(device)
  }

  readonly property var deviceGroups: Model.deviceLists(devices)
  readonly property var connectedDevices: deviceGroups.connected || []
  readonly property var knownDevices: deviceGroups.known || []
  readonly property var discoveredDevices: deviceGroups.discovered || []

  property int phraseIndex: 0
  readonly property var activePhrases: [
    I18n.t("bluetooth.phrase1"),
    I18n.t("bluetooth.phrase2"),
    I18n.t("bluetooth.phrase3"),
    I18n.t("bluetooth.phrase4"),
    I18n.t("bluetooth.phrase5"),
    I18n.t("bluetooth.phrase6"),
    I18n.t("bluetooth.phrase7"),
    I18n.t("bluetooth.phrase8")
  ]
  readonly property bool rotatingPhrases: adapter && adapter.enabled
  readonly property string heroStatusText: {
    if (!adapter) return I18n.t("bluetooth.noAdapter")
    if (!adapter.enabled) return I18n.t("bluetooth.turnedOff")
    return activePhrases[phraseIndex % activePhrases.length]
  }

  // Single cursor model shared by keyboard and mouse. Sections:
  //   "connected"  — currently connected devices; Enter disconnects.
  //   "known"      — remembered devices; Enter connects.
  //   "discovered" — unremembered devices visible while scanning; Enter connects.
  property string focusSection: "connected"
  property int selectedIndex: 0
  property bool actionFocused: false
  property bool cursorActive: false

  // Stable identity for the focused device. Devices move between sections as
  // they connect, disconnect, pair, or get forgotten, so follow the BlueZ
  // address across section changes instead of preserving a stale row index.
  property string focusedDeviceAddress: ""

  // "header" is a virtual section for the hero Bluetooth on/off toggle.
  readonly property bool headerHasCursor: cursorActive && focusSection === "header"
  readonly property string toggleHint: root.adapter && root.adapter.enabled ? I18n.t("bluetooth.turnOff") : I18n.t("bluetooth.turnOn")

  readonly property color hoverFill: bar
    ? Style.hoverFillFor(foreground, Commons.Color.accent)
    : "transparent"
  readonly property color selectedFill: bar
    ? Style.selectedFillFor(foreground, Commons.Color.accent)
    : "transparent"

  function sectionCount(section) {
    if (section === "connected") return connectedDevices.length
    if (section === "known") return knownDevices.length
    if (section === "discovered") return discoveredDevices.length
    return 0
  }

  function sectionVisible(section) {
    if (section === "connected") return connectedDevices.length > 0
    if (section === "known") return knownDevices.length > 0
    if (section === "discovered") return adapter && adapter.discovering && discoveredDevices.length > 0
    return false
  }

  readonly property var visibleSections: {
    return Model.visibleSections(deviceGroups, adapter && adapter.discovering)
  }

  function devicesForSection(section) {
    return Model.sectionDevices(deviceGroups, section)
  }

  readonly property var scrollRows: {
    var rows = []
    for (var k = 0; k < knownDevices.length; k++)
      rows.push({ dev: Model.deviceRow(knownDevices[k]), section: "known", indexInSection: k })
    if (sectionVisible("discovered"))
      for (var d = 0; d < discoveredDevices.length; d++)
        rows.push({ dev: Model.deviceRow(discoveredDevices[d]), section: "discovered", indexInSection: d })
    return rows
  }

  readonly property var connectedRows: {
    var rows = []
    for (var i = 0; i < connectedDevices.length; i++)
      rows.push(Model.deviceRow(connectedDevices[i]))
    return rows
  }

  // Live BlueZ device behind a row. Rows carry primitives only, so actions
  // resolve the backend object here rather than holding a wrapper that can
  // dangle mid-incubation.
  function deviceFor(row) {
    if (!row || !row.dev) return null
    var addr = row.dev.address || ""
    var devs = devices || []
    for (var i = 0; i < devs.length; i++) {
      if ((devs[i].address || "") === addr) return devs[i]
    }
    return null
  }

  readonly property int scrollRowIndex: {
    if (focusSection !== "known" && focusSection !== "discovered") return -1
    for (var i = 0; i < scrollRows.length; i++)
      if (scrollRows[i].section === focusSection && scrollRows[i].indexInSection === selectedIndex) return i
    return -1
  }

  function scrollSectionTitle(index) {
    var rows = scrollRows
    if (index < 0 || index >= rows.length) return ""
    if (index > 0 && rows[index - 1].section === rows[index].section) return ""
    return rows[index].section === "known" ? I18n.t("bluetooth.paired") : I18n.t("bluetooth.available")
  }

  function audioSinks() {
    var sinks = []
    for (var i = 0; i < pipewireNodes.length; i++) {
      var node = pipewireNodes[i]
      if (node && node.isSink && !node.isStream) sinks.push(node)
    }
    return sinks
  }

  function bluetoothAudioSink(device) {
    var sinks = audioSinks()
    for (var i = 0; i < sinks.length; i++) {
      if (Model.bluetoothSinkMatchesDevice(sinks[i], device)) return sinks[i]
    }
    return null
  }

  // Native hand-off: Pipewire.preferredDefaultAudioSink switches the graph
  // immediately, wpctl persists it. Replaces the default-output helper.
  function setDefaultAudioSink(sink) {
    if (!sink) return
    Pipewire.preferredDefaultAudioSink = sink
    if (sink.id !== undefined && sink.id !== null) {
      defaultSinkProc.command = ["wpctl", "set-default", String(sink.id)]
      defaultSinkProc.running = true
    }
  }

  function scheduleAudioOutputSwitch(device) {
    pendingAudioOutputDevice = {
      address: device && device.address ? device.address : "",
      name: device && device.name ? device.name : "",
      deviceName: device && device.deviceName ? device.deviceName : ""
    }
    pendingAudioOutputAttempts = 0
    audioSwitchTimer.restart()
  }

  function switchPendingAudioOutput() {
    if (!pendingAudioOutputDevice) return

    var sink = bluetoothAudioSink(pendingAudioOutputDevice)
    if (sink) {
      setDefaultAudioSink(sink)
      pendingAudioOutputDevice = null
      audioSwitchTimer.stop()
      return
    }

    pendingAudioOutputAttempts += 1
    if (pendingAudioOutputAttempts >= 8) {
      pendingAudioOutputDevice = null
      return
    }
    audioSwitchTimer.restart()
  }

  function deviceAt(section, index) {
    var list = devicesForSection(section)
    return index >= 0 && index < list.length ? list[index] : null
  }

  function pendingAction(address) {
    return Model.pendingAction(pendingActions, address)
  }

  function setPendingAction(address, action) {
    if (!address) return
    pendingActions = Model.withPendingAction(pendingActions, address, action)
    if (action) pendingTimeout.restart()
  }

  // Native device actions replace the bluetooth helper <connect|pair|
  // disconnect|forget> <address>.
  function runDeviceAction(device, action, pending) {
    if (!device || !device.address) return
    setPendingAction(device.address, pending)
    if (action === "connect" && device.connect) device.connect()
    else if (action === "pair" && device.pair) device.pair()
    else if (action === "disconnect" && device.disconnect) device.disconnect()
    else if (action === "forget" && device.forget) device.forget()
  }

  function connectDevice(device) {
    if (!device || device.connected) return
    if (device.paired || device.bonded || device.trusted) runDeviceAction(device, "connect", "connecting")
    else runDeviceAction(device, "pair", "connecting")
  }

  function disconnectDevice(device) {
    if (!device || !device.address) return
    if (!device.connected) return
    setPendingAction(device.address, "disconnecting")
    if (device.disconnect) device.disconnect()
  }

  function forgetDevice(device) {
    if (!device || !device.address) return
    runDeviceAction(device, "forget", "forgetting")
  }

  function syncPendingActions() {
    var next = Model.cloneMap(pendingActions)
    var changed = false

    for (var address in next) {
      var action = next[address]
      var found = null

      for (var i = 0; i < devices.length; i++) {
        var d = devices[i]
        if (d && d.address === address) {
          found = d
          break
        }
      }

      var finishedConnecting = action === "connecting" && found && found.connected
      if (finishedConnecting
          || (action === "disconnecting" && found && !found.connected)
          || (action === "forgetting" && (!found || (!found.paired && !found.bonded && !found.trusted)))) {
        if (finishedConnecting) scheduleAudioOutputSwitch(found)
        delete next[address]
        changed = true
      }
    }

    if (changed) pendingActions = next
  }

  function moveCursor(delta) {
    var sections = visibleSections
    if (focusSection === "header") {
      if (delta > 0 && sections && sections.length > 0) {
        focusSection = sections[0]; selectedIndex = 0; actionFocused = false
      }
      return
    }
    if (!sections || sections.length === 0) { focusSection = "header"; actionFocused = false; return }
    var sIdx = sections.indexOf(focusSection)
    if (sIdx < 0) { focusSection = sections[0]; selectedIndex = 0; actionFocused = false; return }

    var idx = selectedIndex
    var max = sectionCount(focusSection) - 1

    if (delta > 0) {
      if (idx < max) { selectedIndex = idx + 1; actionFocused = false; return }
      if (sIdx < sections.length - 1) {
        focusSection = sections[sIdx + 1]
        selectedIndex = 0
        actionFocused = false
      }
    } else {
      if (idx > 0) { selectedIndex = idx - 1; actionFocused = false; return }
      if (sIdx > 0) {
        focusSection = sections[sIdx - 1]
        selectedIndex = sectionCount(focusSection) - 1
        actionFocused = false
      } else {
        focusSection = "header"; actionFocused = false
      }
    }
  }

  function setHeaderCursor() {
    cursorActive = true
    focusSection = "header"
    actionFocused = false
  }

  function moveCursorH(delta) {
    if (!cursorActive) { cursorActive = true; return }
    if (focusSection !== "known" && focusSection !== "connected") return
    var dev = deviceAt(focusSection, selectedIndex)
    if (!dev || !dev.address) return
    if (delta > 0) actionFocused = true
    else if (delta < 0) actionFocused = false
  }

  function activateCursor() {
    if (focusSection === "header") {
      toggleBluetooth()
      return
    }
    if (actionFocused) {
      deleteSelected()
      return
    }

    if (focusSection === "connected" || focusSection === "known") {
      var dev = deviceAt(focusSection, selectedIndex)
      if (!dev) return
      if (dev.connected) disconnectDevice(dev)
      else connectDevice(dev)
      return
    }
    if (focusSection === "discovered") {
      var d = discoveredDevices[selectedIndex]
      if (!d) return
      connectDevice(d)
    }
  }

  // 'x' forgets remembered devices via the native forget() action.
  function deleteSelected() {
    if (focusSection !== "known" && focusSection !== "connected") return
    var dev = deviceAt(focusSection, selectedIndex)
    if (!dev) return
    forgetDevice(dev)
  }

  Component.onCompleted: {
    // Adopt a discovery session that is already running so a later close
    // settles it either way.
    if (adapter !== null && adapter.discovering) owesDiscoveryStop = true
    if (connectedDevices.length > 0) { focusSection = "connected"; selectedIndex = 0 }
    else if (knownDevices.length > 0) { focusSection = "known"; selectedIndex = 0 }
    else if (discoveredDevices.length > 0) { focusSection = "discovered"; selectedIndex = 0 }
    else { focusSection = "header" }
    actionFocused = false
    cursorActive = false
  }

  // Another per-monitor instance of this widget whose panel is open, if any.
  function openSibling() {
    if (!bar || typeof bar.moduleWidgets !== "function") return null
    var items = bar.moduleWidgets(moduleName)
    for (var i = 0; i < items.length; i++) {
      if (items[i] && items[i] !== root && items[i].opened === true) return items[i]
    }
    return null
  }

  function updateFocusedAddress() {
    var d = deviceAt(focusSection, selectedIndex)
    focusedDeviceAddress = d ? (d.address || "") : ""
  }

  function reselectFocusedDevice() {
    if (focusedDeviceAddress === "") {
      clampCursor()
      return
    }

    var sections = ["connected", "known", "discovered"]
    for (var s = 0; s < sections.length; s++) {
      var section = sections[s]
      if (!sectionVisible(section)) continue
      var list = devicesForSection(section)
      for (var i = 0; i < list.length; i++) {
        if (list[i] && list[i].address === focusedDeviceAddress) {
          focusSection = section
          selectedIndex = i
          clampCursor()
          return
        }
      }
    }

    clampCursor()
  }

  onSelectedIndexChanged: updateFocusedAddress()
  onFocusSectionChanged: updateFocusedAddress()
  onConnectedDevicesChanged: { reselectFocusedDevice(); syncPendingActions() }
  onKnownDevicesChanged: { reselectFocusedDevice(); syncPendingActions() }
  onDiscoveredDevicesChanged: { reselectFocusedDevice(); syncPendingActions() }
  onVisibleSectionsChanged: clampCursor()

  function clampCursor() {
    var sections = visibleSections
    if (focusSection === "header") return
    if (!sections || !sections.length) {
      selectedIndex = 0
      return
    }
    if (sections.indexOf(focusSection) < 0) {
      focusSection = sections[0]
      selectedIndex = 0
      return
    }
    var count = sectionCount(focusSection)
    if (count === 0) {
      var sIdx = sections.indexOf(focusSection)
      focusSection = sIdx > 0 ? sections[sIdx - 1] : sections[0]
      selectedIndex = Math.max(0, sectionCount(focusSection) - 1)
      return
    }
    if (selectedIndex > count - 1) selectedIndex = count - 1
    if (selectedIndex < 0) selectedIndex = 0
  }

  // ----- Layout -----
  readonly property int padding: Style.spacing.panelPadding

  implicitWidth: Style.space(380)
  implicitHeight: column.implicitHeight + padding * 2

  // Same card as every other panel: the bar's background and top-border colour.
  Rectangle {
    anchors.fill: parent
    color: Colors.base01
    border.color: Colors.base04
    border.width: 1
    radius: Style.cornerRadius
  }

  // BlueZ rejects StartDiscovery while the adapter is still powering up, and
  // discovery can also time out on its own. While the panel is open, keep
  // nudging it back on so an enabled adapter is always scanning.
  Timer {
    id: discoveryRetry
    interval: 1000
    repeat: true
    triggeredOnStart: true
    running: root.opened && root.adapter !== null && root.adapter.enabled && !root.adapter.discovering
    onTriggered: {
      root.owesDiscoveryStop = true
      root.adapter.discovering = true
    }
  }

  // The way back down. The BlueZ discovery session behind adapter.discovering
  // is held by quickshell's D-Bus connection, so nothing ends it at close.
  Timer {
    id: discoveryStop
    interval: 1000
    repeat: true
    property int attempts: 0
    running: !root.opened && root.owesDiscoveryStop && root.adapter !== null && root.adapter.discovering === true
    onRunningChanged: if (running) attempts = 0
    onTriggered: {
      var sibling = root.openSibling()
      if (sibling) {
        sibling.owesDiscoveryStop = true
        root.owesDiscoveryStop = false
        return
      }
      attempts += 1
      if (attempts > 3) { root.owesDiscoveryStop = false; return }
      root.adapter.discovering = false
    }
  }

  Connections {
    target: root.adapter
    function onDiscoveringChanged() {
      if (!root.adapter.discovering) root.owesDiscoveryStop = false
    }
  }

  // A destroyed instance cannot wait for BlueZ confirmations, so it hands any
  // debt to a surviving sibling and only writes the stop directly when it is
  // the last one standing.
  Component.onDestruction: {
    if (!owesDiscoveryStop) return
    var items = bar && typeof bar.moduleWidgets === "function" ? bar.moduleWidgets(moduleName) : []
    for (var i = 0; i < items.length; i++) {
      if (items[i] && items[i] !== root) { items[i].owesDiscoveryStop = true; return }
    }
    if (adapter !== null && adapter.discovering) adapter.discovering = false
  }

  Process {
    id: defaultSinkProc
    command: []
  }

  Timer {
    id: pendingTimeout
    interval: 20000
    repeat: false
    onTriggered: root.pendingActions = ({})
  }

  Timer {
    id: audioSwitchTimer
    interval: 500
    repeat: false
    onTriggered: root.switchPendingAudioOutput()
  }

  Timer {
    id: phraseTimer
    interval: 2800
    running: root.opened && root.rotatingPhrases
    repeat: true
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    PropertyAnimation {
      target: heroStatus; property: "opacity"
      to: 0.0; duration: Style.duration(150); easing.type: Easing.OutCubic
    }
    ScriptAction {
      script: root.phraseIndex = (root.phraseIndex + 1) % root.activePhrases.length
    }
    PropertyAnimation {
      target: heroStatus; property: "opacity"
      to: 1.0; duration: Style.duration(200); easing.type: Easing.OutCubic
    }
  }

  Connections {
    target: root
    function onRotatingPhrasesChanged() {
      if (!root.rotatingPhrases) {
        phraseSwap.stop()
        heroStatus.opacity = 1.0
      }
    }
  }

  // Native adapter power. Upstream moved the rfkill soft block instead so
  // systemd-rfkill restored it across reboots; the adapter write is the native
  // equivalent and BlueZ reports it as Powered.
  function toggleBluetooth() {
    if (!adapter) return
    adapter.enabled = !adapter.enabled
  }

  PanelKeyCatcher {
    id: keyCatcher
    anchors.fill: parent
    anchors.margins: root.padding

    onMoveRequested: function(dx, dy) {
      if (!root.cursorActive) { root.cursorActive = true; return }
      if (dy !== 0) root.moveCursor(dy)
      else if (dx !== 0) root.moveCursorH(dx)
    }
    onActivateRequested: if (root.cursorActive) root.activateCursor()
    onCloseRequested: OverlayPanels.close()
    onDeleteRequested: if (root.cursorActive) root.deleteSelected()
    onTextKey: function(t) {
      if (t === "b" || t === "B") root.toggleBluetooth()
    }

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(14)

      // ---------- Hero: Bluetooth icon · status ----------
      Item {
        width: parent.width
        implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, powerSwitch.implicitHeight)

        Text {
          id: heroIcon
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: root.icon
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.display
          opacity: root.adapter && root.adapter.enabled ? 1.0 : 0.5
        }

        ToggleSwitch {
          id: powerSwitch
          visible: !!root.adapter
          checked: !!root.adapter && root.adapter.enabled
          hasCursor: root.headerHasCursor
          foreground: root.foreground
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          onHovered: function(on) { if (on) root.setHeaderCursor() }
          onToggled: root.toggleBluetooth()

          PanelToolTip {
            visible: powerSwitch.containsMouse
            text: root.toggleHint
            fontFamily: root.fontFamily
          }
        }

        Column {
          id: heroLabels
          anchors.left: heroIcon.right
          anchors.leftMargin: Style.space(14)
          anchors.right: parent.right
          anchors.rightMargin: powerSwitch.visible ? powerSwitch.width + Style.space(12) : 0
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            text: I18n.t("bluetooth.title")
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            id: heroStatus
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
      }

      PanelSeparator {
        foreground: root.foreground
      }

      Column {
        id: connectedList
        visible: root.connectedDevices.length > 0
        width: parent.width
        spacing: Style.space(10)

        PanelSectionHeader {
          text: I18n.t("bluetooth.connected")
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Repeater {
          model: root.connectedRows
          DeviceRow {
            required property var modelData
            required property int index
            width: connectedList.width
            dev: modelData
            rowIndex: index
            sectionName: "connected"
            isDiscovered: false
          }
        }
      }

      PanelSeparator {
        visible: root.connectedDevices.length > 0 && root.scrollRows.length > 0
        foreground: root.foreground
      }

      ListView {
        id: deviceListView
        width: parent.width
        height: Math.min(contentHeight, Style.space(400))
        spacing: Style.space(10)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        model: root.scrollRows
        currentIndex: root.scrollRowIndex
        onCurrentIndexChanged: if (currentIndex >= 0) Qt.callLater(keepCurrentVisible)
        function keepCurrentVisible() {
          if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
        }

        delegate: Item {
          required property var modelData
          required property int index
          readonly property string sectionTitle: root.scrollSectionTitle(index)

          width: ListView.view.width
          height: delegateColumn.implicitHeight

          Column {
            id: delegateColumn
            width: parent.width
            spacing: Style.space(10)

            PanelSeparator {
              visible: index > 0 && sectionTitle !== ""
              height: visible ? implicitHeight : 0
              foreground: root.foreground
            }

            PanelSectionHeader {
              visible: sectionTitle !== ""
              height: visible ? implicitHeight : 0
              text: sectionTitle
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            DeviceRow {
              width: parent.width
              dev: modelData.dev
              rowIndex: modelData.indexInSection
              sectionName: modelData.section
              isDiscovered: modelData.section === "discovered"
            }
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: root.connectedDevices.length === 0 && root.scrollRows.length === 0
        text: !root.adapter ? I18n.t("bluetooth.noBluetoothAdapter")
            : !root.adapter.enabled ? I18n.t("bluetooth.turnOnToScan")
            : I18n.t("bluetooth.scanning")
        color: Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
        width: parent.width
      }
    }
  }

  // Two-line device row showing name + live status. Pending state is owned
  // by the panel so it survives rows moving between sections.
  component DeviceRow: CursorSurface {
    id: row
    required property var dev
    required property int rowIndex
    required property string sectionName
    required property bool isDiscovered

    readonly property bool isConnected: dev && dev.connected
    readonly property int devState: dev && dev.state !== undefined ? dev.state : -1
    readonly property string action: root.pendingAction(dev ? dev.address : "")
    readonly property string actionTooltip: {
      if (!dev) return ""
      if (isConnected) return I18n.t("bluetooth.disconnect")
      if (isDiscovered) return I18n.t("bluetooth.pair")
      return I18n.t("bluetooth.connect")
    }

    readonly property bool rowSelected: root.cursorActive && root.focusSection === sectionName && root.selectedIndex === rowIndex
    readonly property bool forgetAvailable: (sectionName === "known" || sectionName === "connected") && !isDiscovered
    readonly property bool showForgetButton: forgetAvailable && (rowMouse.containsMouse || rowSelected)

    hasCursor: rowSelected && !root.actionFocused
    current: isConnected
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill

    readonly property string statusText: {
      if (!dev) return ""
      if (action === "forgetting") return I18n.t("bluetooth.forgetting")
      if (action === "disconnecting" || devState === 2) return I18n.t("bluetooth.disconnecting")
      if (isConnected) {
        if (dev.batteryAvailable) return I18n.formatNumber(Math.round(dev.battery * 100)) + "%"
        return sectionName === "connected" ? "" : I18n.t("bluetooth.connectedStatus")
      }
      if (action === "connecting" || devState === 3 || dev.pairing === true) return I18n.t("bluetooth.connecting")
      if (isDiscovered) return ""
      return ""
    }

    readonly property color statusColor: {
      if (isConnected) return root.foreground
      if (action !== "" || devState === 3 || dev.pairing === true) return root.foreground
      return Qt.darker(root.foreground, 1.5)
    }

    implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: row.dev ? Qt.PointingHandCursor : Qt.ArrowCursor

      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.focusSection = row.sectionName
        root.selectedIndex = row.rowIndex
        root.actionFocused = false
      }

      onClicked: function(mouse) {
        var dev = root.deviceFor(row)
        if (!dev) return
        if (mouse.button === Qt.RightButton) {
          if (row.isConnected) root.disconnectDevice(dev)
          else if (!row.isDiscovered) root.forgetDevice(dev)
          return
        }
        if (row.isConnected) root.disconnectDevice(dev)
        else root.connectDevice(dev)
      }
    }

    PanelToolTip {
      visible: row.actionTooltip !== "" && rowMouse.containsMouse && !root.actionFocused
      text: row.actionTooltip
      fontFamily: root.fontFamily
    }

    Item {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      implicitHeight: Math.max(deviceIcon.implicitHeight, info.implicitHeight, forgetBtn.implicitHeight)

      Text {
        id: deviceIcon
        textFormat: Text.PlainText
        text: row.isConnected ? "\u{f00b1}" : "\u{f00af}"
        color: row.statusColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        id: info
        spacing: Style.space(1)
        anchors.left: deviceIcon.right
        anchors.leftMargin: Style.space(10)
        anchors.right: forgetBtn.visible ? forgetBtn.left : parent.right
        anchors.rightMargin: forgetBtn.visible ? Style.space(8) : 0
        anchors.verticalCenter: parent.verticalCenter

        Text {
          textFormat: Text.PlainText
          text: root.deviceLabel(row.dev) || I18n.t("bluetooth.device")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          width: parent.width
        }
        Text {
          textFormat: Text.PlainText
          visible: row.statusText !== ""
          text: row.statusText
          color: row.statusColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          width: parent.width
        }
      }

      PanelActionButton {
        id: forgetBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: row.showForgetButton
        iconText: "\u{f0159}"
        tooltipText: I18n.t("bluetooth.forget")
        foreground: root.foreground
        hoverColor: root.foreground
        fontFamily: root.fontFamily
        hasCursor: row.rowSelected && root.actionFocused
        onHovered: function(isHovered) {
          if (!isHovered) {
            if (rowMouse.containsMouse) root.actionFocused = false
            return
          }
          root.cursorActive = true
          root.focusSection = row.sectionName
          root.selectedIndex = row.rowIndex
          root.actionFocused = true
        }
        onClicked: {
          var dev = root.deviceFor(row)
          if (!dev) return
          root.forgetDevice(dev)
        }
      }
    }
  }
}
