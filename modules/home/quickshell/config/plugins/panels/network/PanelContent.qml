import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  // ---- host contract -----------------------------------------------------
  property var settings: ({})
  property string moduleName: "network"
  property var bar: null

  // ---- bar-widget API ----------------------------------------------------
  readonly property color foreground: Commons.Color.foreground
  readonly property color urgentColor: Commons.Color.urgent
  readonly property string fontFamily: Style.font.family

  readonly property bool networkManagerAvailable: Networking.backend === NetworkBackendType.NetworkManager
  readonly property var networkDevices: Networking.devices ? Networking.devices.values : []
  readonly property var wiredDevice: findDevice(DeviceType.Wired)
  readonly property var wifiDevice: findDevice(DeviceType.Wifi)
  readonly property var wifiNetworkObjects: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
  readonly property var connectedWifiNetwork: findConnectedWifiNetwork()
  readonly property string kind: {
    if (wiredDevice && wiredDevice.connected) return "ethernet"
    if (connectedWifiNetwork) return "wifi"
    if (wifiDevice && wifiDevice.connected) return "wifi"
    return "disconnected"
  }

  readonly property bool connectivityChecksEnabled: networkManagerAvailable
    && Networking.canCheckConnectivity && Networking.connectivityCheckEnabled
  readonly property string connectivity: Model.connectivityState(kind, Networking.connectivity, {
    Portal: NetworkConnectivity.Portal, Limited: NetworkConnectivity.Limited,
    Full: NetworkConnectivity.Full, None: NetworkConnectivity.None
  }, connectivityChecksEnabled)
  readonly property bool hasCaptivePortal: connectivity === "portal"
  readonly property bool restricted: hasCaptivePortal || connectivity === "limited"
  readonly property string icon: Model.connectionIcon(kind, signalStrength, connectivity)
  readonly property string statusText: {
    if (root.hasCaptivePortal) return I18n.t("network.signInRequired", "Sign in required")
    if (root.restricted) return I18n.t("network.limitedAccess", "Limited access")
    if (root.kind === "disconnected") return I18n.t("network.disconnected", "Disconnected")
    return I18n.t("network.connected", "Connected")
  }
  readonly property bool urgent: root.restricted
  readonly property bool active: root.kind !== "disconnected"
  readonly property bool available: root.networkManagerAvailable

  readonly property int signalStrength: root.kind === "wifi"
    ? Model.connectedSignalStrength(root.connectedWifiNetwork ? root.connectedWifiNetwork.signalStrength : 0, root.activeApSignal)
    : -1

  property var info: ({})
  property var wifiNetworks: []
  property bool scanning: false
  property bool wifiStationAvailable: false
  property string dnsProvider: ""
  property string pendingDnsProvider: ""
  property string bandCurrent: ""
  property string bandSelected: "auto"
  property var bandAvailable: []
  property string pendingBand: ""
  property int activeApSignal: -1
  property int activeApSignalGeneration: 0
  property int activeApSignalRequest: -1

  property real prevRxBytes: 0
  property real prevTxBytes: 0
  property real prevSampleTime: 0
  property string prevIface: ""
  property real downloadRate: 0
  property real uploadRate: 0
  property string pingIface: ""
  property var routerPingSamples: []
  property var internetPingSamples: []
  readonly property int pingHistoryWindow: 24
  readonly property int pingAverageWindow: 5
  readonly property bool hasInternetPing: Model.internetPingReadable(internetPingSamples, connectivity)
  readonly property bool hasTransferStats: info.rx_bytes !== undefined

  property string actionSsid: ""
  property string actionKind: ""
  property string failureSsid: ""
  property string failureReason: ""
  property string passwordSsid: ""
  property string passwordText: ""
  property string identityText: ""
  readonly property bool busy: actionKind !== ""

  readonly property var connectionFailReasons: ({
    NoSecrets: ConnectionFailReason.NoSecrets,
    WifiAuthTimeout: ConnectionFailReason.WifiAuthTimeout,
    WifiNetworkLost: ConnectionFailReason.WifiNetworkLost,
    WifiClientDisconnected: ConnectionFailReason.WifiClientDisconnected,
    WifiClientFailed: ConnectionFailReason.WifiClientFailed
  })

  readonly property var dnsProviders: ["DHCP", "Cloudflare", "Google", "Custom"]
  readonly property bool canShareWifi: false
  readonly property bool canToggleWifi: networkManagerAvailable && wifiStationAvailable
  readonly property bool canSelectBand: (kind === "wifi" || bandBusy)
    && (bandAvailable.length > 1 || bandPinned)
  readonly property string bandEffective: pendingBand !== "" ? pendingBand : bandSelected
  readonly property bool bandPinned: bandEffective !== "auto"
  readonly property bool bandPillsVisible: canSelectBand && bandPinned
  readonly property string bandSectionTitle: Model.bandSectionTitle(bandEffective, bandCurrent, I18n.t, I18n.formatNumber)
  readonly property bool bandBusy: pendingBand !== ""
  readonly property string dnsEffective: pendingDnsProvider !== "" ? pendingDnsProvider : dnsProvider
  readonly property bool canRunSpeedTest: false
  readonly property color hoverFill: Style.hoverFillFor(foreground, Commons.Color.accent)
  readonly property color selectedFill: Style.selectedFillFor(foreground, Commons.Color.accent)
  readonly property string toggleHint: Networking.wifiEnabled ? I18n.t("network.turnWifiOff", "Turn Wi-Fi off") : I18n.t("network.turnWifiOn", "Turn Wi-Fi on")

  property var scannerDevice: null

  implicitWidth: 400
  implicitHeight: surface.height

  function setting(name, fallback) {
    var value = root.settings ? root.settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function findDevice(type) {
    var devices = root.networkDevices || []
    var fallback = null
    for (var i = 0; i < devices.length; i++) {
      var device = devices[i]
      if (!device || device.type !== type) continue
      if (device.connected) return device
      if (!fallback) fallback = device
    }
    return fallback
  }

  function findConnectedWifiNetwork() {
    var networks = root.wifiNetworkObjects || []
    for (var i = 0; i < networks.length; i++) {
      if (networks[i] && networks[i].connected) return networks[i]
    }
    return null
  }

  function networkForSsid(ssid) {
    var networks = root.wifiNetworkObjects || []
    for (var i = 0; i < networks.length; i++) {
      if (networks[i] && networks[i].name === ssid) return networks[i]
    }
    return null
  }

  function syncWifiNetworks() {
    var nets = []
    var networks = root.wifiNetworkObjects || []
    for (var i = 0; i < networks.length; i++) {
      var network = networks[i]
      if (!network) continue
      checkActionCompletion(network)
      var row = Model.wifiRow(network)
      if (row) nets.push(row)
    }
    root.wifiNetworks = Model.sortWifiRows(nets)
    root.wifiStationAvailable = !!root.wifiDevice
    root.scanning = false
  }

  function setScannerEnabled(enabled) {
    var nextDevice = root.wifiDevice
    if (root.scannerDevice && root.scannerDevice !== nextDevice)
      root.scannerDevice.scannerEnabled = false
    root.scannerDevice = nextDevice
    if (root.scannerDevice)
      root.scannerDevice.scannerEnabled = enabled
  }

  Component.onCompleted: {
    root.refresh(true)
    root.setScannerEnabled(true)
  }
  Component.onDestruction: if (root.scannerDevice) root.scannerDevice.scannerEnabled = false

  onWifiDeviceChanged: {
    root.setScannerEnabled(true)
    root.syncWifiNetworks()
  }
  onWifiNetworkObjectsChanged: root.syncWifiNetworks()

  onKindChanged: if (root.kind !== "wifi") root.resetActiveApSignal()

  function resetActiveApSignal() {
    root.activeApSignal = -1
    root.activeApSignalGeneration++
  }

  function pollActiveApSignal() {
    if (activeApSignalProc.running) return
    root.activeApSignalRequest = root.activeApSignalGeneration
    activeApSignalProc.running = true
  }

  function finishActiveApSignal(raw) {
    if (root.activeApSignalRequest !== root.activeApSignalGeneration) return
    root.activeApSignal = Model.parseActiveApSignal(raw)
  }

  readonly property bool needsActiveApSignal: root.kind === "wifi"
    && !(root.connectedWifiNetwork && root.connectedWifiNetwork.signalStrength > 0)

  Timer {
    id: activeApSignalPoll
    interval: 5000
    repeat: true
    triggeredOnStart: true
    running: root.needsActiveApSignal
    onTriggered: root.pollActiveApSignal()
  }

  function refresh(scanWifi) {
    root.checkConnectivity()
    if (!detailsProc.running) detailsProc.running = true
    if (!dnsReadProc.running) dnsReadProc.running = true
    if (!bandProc.running) bandProc.running = true
    if (root.wifiDevice) {
      if (scanWifi === true) {
        root.scanning = true
        root.setScannerEnabled(false)
        scanRestart.start()
      } else {
        root.setScannerEnabled(true)
      }
    }
    root.syncWifiNetworks()
  }

  Timer {
    id: scanRestart
    interval: 100
    repeat: false
    onTriggered: {
      if (root.wifiDevice) {
        root.setScannerEnabled(true)
        scanDone.start()
      }
    }
  }

  Timer {
    id: scanDone
    interval: 1500
    repeat: false
    onTriggered: root.syncWifiNetworks()
  }

  function checkConnectivity() {
    if (root.connectivityChecksEnabled && root.kind !== "disconnected") Networking.checkConnectivity()
  }

  function openCaptivePortal() {
    if (!root.hasCaptivePortal) return
    Quickshell.execDetached(["xdg-open", Model.captivePortalUrl])
  }

  Timer {
    id: connectivityPoll
    interval: 10000
    repeat: true
    running: root.restricted && root.connectivityChecksEnabled
    onTriggered: root.checkConnectivity()
  }

  function toggleNetwork() {
    if (!root.networkManagerAvailable) return
    Networking.wifiEnabled = !Networking.wifiEnabled
    Qt.callLater(function() { root.refresh(true) })
  }

  // ---- details / throughput / ping ---------------------------------------
  function updateDetails(raw) {
    var next = Model.parseKeyValue(raw)
    if (root.bandBusy && !next.iface) return
    root.info = next
    root.updateThroughput(next)
    root.updatePingLatency(next)
  }

  function updateThroughput(next) {
    var state = Model.throughputState({
      prevIface: prevIface,
      prevRxBytes: prevRxBytes,
      prevTxBytes: prevTxBytes,
      prevSampleTime: prevSampleTime,
      downloadRate: downloadRate,
      uploadRate: uploadRate
    }, next, Date.now() / 1000)
    root.prevIface = state.prevIface
    root.prevRxBytes = state.prevRxBytes
    root.prevTxBytes = state.prevTxBytes
    root.prevSampleTime = state.prevSampleTime
    root.downloadRate = state.downloadRate
    root.uploadRate = state.uploadRate
  }

  function updatePingLatency(next) {
    var state = Model.pingLatencyState({
      pingIface: pingIface,
      routerPingSamples: routerPingSamples,
      internetPingSamples: internetPingSamples
    }, next, pingHistoryWindow, pingAverageWindow)
    root.pingIface = state.pingIface
    root.routerPingSamples = state.routerPingSamples
    root.internetPingSamples = state.internetPingSamples
  }

  function formatBytes(bytes) { return Model.formatBytes(bytes, I18n.formatNumber) }
  function formatRate(bytesPerSec) { return Model.formatRate(bytesPerSec, I18n.formatNumber) }
  function formatPingLatency(ms) { return Model.formatPingLatency(ms, hasInternetPing, I18n.t, I18n.formatNumber) }
  function formatPacketLoss(percent) { return Model.formatPacketLoss(percent, hasInternetPing, I18n.formatNumber) }
  function formatHeaderSpeed(mbps) { return Model.formatHeaderSpeed(mbps, I18n.formatNumber) }
  function formatHeaderFreq(mhz) { return Model.formatHeaderFreq(mhz, I18n.formatNumber) }
  function headerDetail() { return Model.headerDetail(root.info, I18n.formatNumber) }
  function bandLabel(band) { return Model.bandLabel(band, I18n.t, I18n.formatNumber) }
  function bandTooltip(band) { return Model.bandTooltip(band, I18n.t, I18n.formatNumber) }

  function wifiSectionTitle(index) { return Model.wifiSectionTitle(wifiNetworks, index, I18n.t) }
  function wifiIconFor(strength) { return Model.wifiIconFor(strength) }
  function canForgetNetwork(net) { return Model.canForgetNetwork(net) }
  function requiresCredentials(security) {
    return Model.requiresCredentials(security, WifiSecurityType.Open, WifiSecurityType.Owe)
  }
  function networkFailureReason(reason, needsCredentials) {
    return Model.networkFailureReason(reason, needsCredentials, connectionFailReasons, I18n.t)
  }
  function shouldRepromptPassphrase(reason, needsCredentials) {
    return Model.shouldRepromptPassphrase(reason, needsCredentials, connectionFailReasons)
  }

  // ---- DHCP / DNS / band commands ----------------------------------------
  readonly property var detailsCommand: ["bash", "-c", [
    "line=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null | grep ':connected' | head -1)",
    "iface=$(printf '%s' \"$line\" | cut -d: -f1)",
    "type=$(printf '%s' \"$line\" | cut -d: -f2)",
    "[ \"$type\" = \"wifi\" ] || type=ethernet",
    "[ -z \"$iface\" ] && exit 0",
    "addr=$(nmcli -t -f IP4.ADDRESS device show \"$iface\" 2>/dev/null | cut -d: -f2 | head -1)",
    "ip=${addr%/*}",
    "prefix=${addr#*/}",
    "gateway=$(nmcli -t -f IP4.GATEWAY device show \"$iface\" 2>/dev/null | cut -d: -f2 | head -1)",
    "speed=$(cat /sys/class/net/$iface/speed 2>/dev/null)",
    "duplex=$(cat /sys/class/net/$iface/duplex 2>/dev/null)",
    "rx=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null)",
    "tx=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null)",
    "wifi=$(nmcli -t -f IN-USE,SSID,SIGNAL,FREQ device wifi list ifname \"$iface\" --rescan no 2>/dev/null | grep '^\\*' | head -1)",
    "ssid=$(printf '%s' \"$wifi\" | cut -d: -f2)",
    "signal=$(printf '%s' \"$wifi\" | cut -d: -f3)",
    "freq=$(printf '%s' \"$wifi\" | cut -d: -f4)",
    "router_ping_ms=$(ping -c1 -W1 \"$gateway\" 2>/dev/null | awk -F'time=' '/time=/{print $2}' | cut -d' ' -f1)",
    "internet_ping_ms=$(ping -c1 -W1 1.1.1.1 2>/dev/null | awk -F'time=' '/time=/{print $2}' | cut -d' ' -f1)",
    "printf 'iface\\t%s\\n' \"$iface\"",
    "printf 'type\\t%s\\n' \"$type\"",
    "printf 'ip\\t%s\\n' \"$ip\"",
    "printf 'prefix\\t%s\\n' \"$prefix\"",
    "printf 'gateway\\t%s\\n' \"$gateway\"",
    "printf 'speed\\t%s\\n' \"$speed\"",
    "printf 'duplex\\t%s\\n' \"$duplex\"",
    "printf 'ssid\\t%s\\n' \"$ssid\"",
    "printf 'signal\\t%s\\n' \"$signal\"",
    "printf 'freq\\t%s\\n' \"$freq\"",
    "printf 'rx_bytes\\t%s\\n' \"$rx\"",
    "printf 'tx_bytes\\t%s\\n' \"$tx\"",
    "printf 'router_ping_ms\\t%s\\n' \"$router_ping_ms\"",
    "printf 'internet_ping_ms\\t%s\\n' \"$internet_ping_ms\""
  ].join("\n")]

  readonly property var bandReadCommand: ["bash", "-c", [
    "line=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | grep ':connected' | head -1)",
    "iface=$(printf '%s' \"$line\" | cut -d: -f1)",
    "type=$(printf '%s' \"$line\" | cut -d: -f2)",
    "[ \"$type\" = \"wifi\" ] || exit 0",
    "rows=$(nmcli -t -f IN-USE,FREQ device wifi list ifname \"$iface\" --rescan no 2>/dev/null)",
    "band=\"\"",
    "avail=\"\"",
    "while IFS=: read inuse freq; do",
    "  [ -z \"$freq\" ] && continue",
    "  f=${freq%% *}",
    "  case \"$f\" in *[!0-9]*) continue;; esac",
    "  b=\"\"",
    "  if [ \"$f\" -ge 2400 ] && [ \"$f\" -lt 2500 ]; then b=2.4",
    "  elif [ \"$f\" -ge 4900 ] && [ \"$f\" -lt 5925 ]; then b=5",
    "  elif [ \"$f\" -ge 5925 ] && [ \"$f\" -lt 7125 ]; then b=6",
    "  elif [ \"$f\" -ge 57000 ]; then b=60",
    "  fi",
    "  [ -z \"$b\" ] && continue",
    "  case \" $avail \" in *\" $b \"*) ;; *) avail=\"$avail $b\";; esac",
    "  [ \"$inuse\" = \"*\" ] && band=\"$b\"",
    "done <<EOF",
    "$rows",
    "EOF",
    "name=$(nmcli -t -f NAME connection show --active 2>/dev/null | head -1)",
    "sel=$(nmcli -t -f 802-11-wireless.band connection show \"$name\" 2>/dev/null | cut -d: -f2)",
    "case \"$sel\" in bg) sel=2.4;; a) sel=5;; *) sel=auto;; esac",
    "printf 'band\\t%s\\n' \"$band\"",
    "printf 'selected\\t%s\\n' \"$sel\"",
    "printf 'available\\t%s\\n' \"$avail\""
  ].join("\n")]

  readonly property var bandSetScript: [
    "name=$(nmcli -t -f NAME connection show --active 2>/dev/null | head -1)",
    "[ -z \"$name\" ] && exit 1",
    "band=bg",
    "[ \"$1\" = \"5\" ] || [ \"$1\" = \"6\" ] || [ \"$1\" = \"60\" ] && band=a",
    "nmcli connection modify \"$name\" 802-11-wireless.band \"$band\"",
    "nmcli connection up \"$name\""
  ].join("\n")

  readonly property var dnsReadCommand: ["bash", "-c", [
    "line=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | grep ':connected' | head -1)",
    "iface=$(printf '%s' \"$line\" | cut -d: -f1)",
    "[ -z \"$iface\" ] && exit 0",
    "nmcli -t -f IP4.DNS device show \"$iface\" 2>/dev/null | cut -d: -f2 | head -1"
  ].join("\n")]

  readonly property var dnsSetScript: [
    "name=$(nmcli -t -f NAME connection show --active 2>/dev/null | head -1)",
    "[ -z \"$name\" ] && exit 1",
    "case \"$1\" in",
    "  DHCP) nmcli connection modify \"$name\" ipv4.ignore-auto-dns no ipv4.dns \"\" ;;",
    "  Cloudflare) nmcli connection modify \"$name\" ipv4.ignore-auto-dns yes ipv4.dns \"1.1.1.1 1.0.0.1\" ;;",
    "  Google) nmcli connection modify \"$name\" ipv4.ignore-auto-dns yes ipv4.dns \"8.8.8.8 8.8.4.4\" ;;",
    "  *) exit 1 ;;",
    "esac",
    "nmcli connection up \"$name\""
  ].join("\n")

  Process {
    id: detailsProc
    command: root.detailsCommand
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateDetails(text) }
  }

  Process {
    id: activeApSignalProc
    command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL", "device", "wifi", "list", "ifname", root.wifiDevice ? root.wifiDevice.name : "", "--rescan", "no"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.finishActiveApSignal(text) }
  }

  Process {
    id: bandProc
    command: root.bandReadCommand
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var status = Model.parseBandStatus(text)
        if (root.bandBusy && status.available.length === 0) return
        root.bandCurrent = status.band
        root.bandSelected = status.selected
        root.bandAvailable = status.available
      }
    }
  }

  Process {
    id: dnsReadProc
    command: root.dnsReadCommand
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var value = String(text || "").trim()
        if (value === "" || value.indexOf(":") !== -1) root.dnsProvider = "DHCP"
        else if (value === "1.1.1.1" || value === "1.0.0.1") root.dnsProvider = "Cloudflare"
        else if (value === "8.8.8.8" || value === "8.8.4.4") root.dnsProvider = "Google"
        else root.dnsProvider = "Custom"
      }
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { id: actionStdout; waitForEnd: true }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (root.pendingDnsProvider !== "") {
        if (exitCode === 0) root.dnsProvider = root.pendingDnsProvider
        root.pendingDnsProvider = ""
      }
      if (root.pendingBand !== "") {
        if (exitCode === 0) root.bandSelected = root.pendingBand
        root.pendingBand = ""
        root.refresh()
      }
    }
  }

  Timer {
    id: detailsPoll
    interval: 1500
    repeat: true
    running: root.active
    onTriggered: if (!detailsProc.running) detailsProc.running = true
  }

  Timer {
    id: bandPoll
    interval: 4000
    repeat: true
    running: root.kind === "wifi"
    onTriggered: if (!bandProc.running) bandProc.running = true
  }

  Timer {
    id: dnsPoll
    interval: 5000
    repeat: true
    running: root.active
    onTriggered: if (!dnsReadProc.running) dnsReadProc.running = true
  }

  // ---- actions -----------------------------------------------------------
  function openPasswordPrompt(ssid) {
    if (root.passwordSsid !== ssid) {
      root.passwordText = ""
      root.identityText = ""
    }
    root.passwordSsid = ssid
  }

  function cancelPasswordPrompt() {
    root.passwordSsid = ""
    root.passwordText = ""
    root.identityText = ""
  }

  function wifiIndexForSsid(ssid) {
    for (var i = 0; i < root.wifiNetworks.length; i++) {
      if (root.wifiNetworks[i] && root.wifiNetworks[i].ssid === ssid) return i
    }
    return -1
  }

  function runNetworkAction(kind, network, callback) {
    if (root.actionKind !== "" || !network) return
    root.actionSsid = network.name || ""
    root.actionKind = kind
    root.failureSsid = ""
    root.failureReason = ""
    callback(network)
    actionTimeout.restart()
  }

  function clearNetworkAction() {
    actionTimeout.stop()
    if (root.actionKind === "connect") root.passwordSsid = ""
    root.failureSsid = ""
    root.failureReason = ""
    root.actionSsid = ""
    root.actionKind = ""
    root.refresh()
  }

  function failNetworkAction(network, reason) {
    if (!network || root.actionKind === "" || root.actionSsid !== (network.name || "")) return
    actionTimeout.stop()
    root.failureSsid = root.actionSsid
    root.failureReason = root.networkFailureReason(reason, root.requiresCredentials(network.security))
    root.actionSsid = ""
    root.actionKind = ""
    root.refresh()
  }

  function checkActionCompletion(network) {
    if (!network || root.actionKind === "" || root.actionSsid !== (network.name || "")) return
    if (root.actionKind === "connect" && network.connected) root.clearNetworkAction()
    else if (root.actionKind === "disconnect" && !network.connected && !network.stateChanging) root.clearNetworkAction()
    else if (root.actionKind === "forget" && !network.known && !network.stateChanging) root.clearNetworkAction()
  }

  function connectDirectly(ssid) {
    var network = root.networkForSsid(ssid)
    root.runNetworkAction("connect", network, function(net) { net.connect() })
  }

  function connectWithPassphrase(ssid, passphrase) {
    var network = root.networkForSsid(ssid)
    root.runNetworkAction("connect", network, function(net) { net.connectWithPsk(passphrase) })
  }

  function connectEnterprise(ssid, identity, passphrase) {
    var network = root.networkForSsid(ssid)
    root.runNetworkAction("connect", network, function() {
      enterpriseConnect.secret = passphrase
      enterpriseConnect.command = ["bash", "-c", Model.enterpriseConnectScript, "nmcli-eap", ssid, identity]
      enterpriseConnect.running = true
    })
  }

  Process {
    id: enterpriseConnect
    property string secret: ""
    stdinEnabled: true
    onStarted: {
      write(secret + "\n")
      secret = ""
    }
  }

  function disconnect(network) {
    root.runNetworkAction("disconnect", network || root.connectedWifiNetwork, function(net) { net.disconnect() })
  }

  function disconnectRow(ssid) {
    var network = root.networkForSsid(ssid)
    if (network) root.disconnect(network)
  }

  function forget(net) {
    root.runNetworkAction("forget", net ? root.networkForSsid(net.ssid) : null, function(network) { network.forget() })
  }

  function setBand(band) {
    if (!band || actionProc.running) return
    root.pendingBand = band
    actionProc.command = ["bash", "-c", root.bandSetScript, "band", band]
    actionProc.running = true
  }

  function toggleBandAuto() {
    if (root.bandSelected !== "auto") root.setBand("auto")
    else if (root.bandCurrent !== "") root.setBand(root.bandCurrent)
  }

  function setDns(provider) {
    if (!provider || actionProc.running) return
    if (provider === "Custom") {
      Quickshell.execDetached(["bash", "-lc",
        "term=$(command -v xdg-terminal-exec || command -v kitty || command -v foot || command -v alacritty || command -v wezterm || command -v xterm) || exit 1; " +
        "exec \"$term\" bash -c 'nmcli connection edit \"$(nmcli -t -f NAME connection show --active | head -1)\"'"])
      return
    }
    root.pendingDnsProvider = provider
    actionProc.command = ["bash", "-c", root.dnsSetScript, "dns", provider]
    actionProc.running = true
  }

  Timer {
    id: actionTimeout
    interval: 30000
    repeat: false
    onTriggered: {
      if (!root.actionKind) return
      root.failureSsid = root.actionSsid
      root.failureReason = I18n.t("network.failed", "Failed")
      root.actionSsid = ""
      root.actionKind = ""
      root.refresh()
    }
  }

  Connections {
    target: root
    function onConnectionKeyChanged() { Qt.callLater(root.checkConnectivity) }
  }
  readonly property string connectionKey: root.kind === "wifi" && root.wifiDevice
    ? root.kind + ":" + root.wifiDevice.name
    : (root.kind === "ethernet" && root.wiredDevice ? root.kind + ":" + root.wiredDevice.name : "")

  // ---- UI ----------------------------------------------------------------
  BorderSurface {
    id: surface
    width: parent.width
    height: Math.min(column.implicitHeight + Style.spacing.panelPadding * 2, 680)
    color: Commons.Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, 1)
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
        spacing: Style.space(12)

        // ---- Hero ----
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroSwitch.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.icon
            color: root.restricted ? root.urgentColor : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            opacity: root.networkManagerAvailable ? 1.0 : 0.5
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          ToggleSwitch {
            id: heroSwitch
            visible: root.canToggleWifi
            checked: Networking.wifiEnabled
            foreground: root.foreground
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            onToggled: root.toggleNetwork()

            PanelToolTip {
              visible: heroSwitch.containsMouse
              text: root.toggleHint
              fontFamily: root.fontFamily
            }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.rightMargin: heroSwitch.visible ? heroSwitch.width + Style.space(12) : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              id: heroSsid
              textFormat: Text.PlainText
              width: parent.width
              readonly property string title: {
                if (root.kind === "wifi" && root.connectedWifiNetwork) return root.connectedWifiNetwork.name || "Wi-Fi"
                if (root.info.type === "wifi") return root.info.ssid || "Wi-Fi"
                if (root.info.type === "ethernet") return I18n.t("network.ethernet", "Ethernet")
                return root.info.iface || (root.kind === "disconnected" ? I18n.t("network.disconnected", "Disconnected") : I18n.t("network.noConnection", "No connection"))
              }
              readonly property string detail: root.headerDetail()
              text: heroSsid.detail !== "" ? heroSsid.title + " (" + heroSsid.detail + ")" : heroSsid.title
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              id: heroMeta
              textFormat: Text.PlainText
              width: parent.width
              text: {
                if (root.hasCaptivePortal) return ""
                if (root.restricted) return I18n.t("network.limitedAccessHeader", "Limited access")
                if (root.kind === "wifi") {
                  if (root.connectedWifiNetwork) return root.statusText.toUpperCase()
                  return ""
                }
                if (root.kind === "ethernet") return root.statusText.toUpperCase()
                return I18n.t("network.notConnected", "Not connected")
              }
              visible: text !== ""
              color: root.restricted ? root.urgentColor : Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
            }
          }
        }

        Button {
          id: portalAction
          visible: root.hasCaptivePortal
          width: parent.width
          text: I18n.t("network.openCaptivePortal", "Open captive portal")
          iconText: "󰏌"
          foreground: root.urgentColor
          accent: root.urgentColor
          fontFamily: root.fontFamily
          verticalPadding: Style.space(10)
          bordered: true
          active: true
          onClicked: root.openCaptivePortal()
        }

        // ---- Device details ----
        Column {
          visible: !!root.info.iface
          width: parent.width
          spacing: Style.spacing.labelGap

          GridLayout {
            width: parent.width
            columns: 4
            columnSpacing: Style.space(20)
            rowSpacing: Style.spacing.labelGap

            InfoLabel { text: I18n.t("network.ping", "Ping") }
            DetailValue {
              text: root.formatPingLatency(root.internetPingSamples.length > 0 ? root.internetPingSamples[root.internetPingSamples.length - 1] : -1)
              color: root.hasInternetPing && root.internetPingSamples.length > 0 && root.internetPingSamples[root.internetPingSamples.length - 1] === null ? root.urgentColor : root.foreground
            }
            InfoLabel { text: I18n.t("network.packetLoss", "Loss") }
            DetailValue { text: root.formatPacketLoss(Model.pingPacketLossPercent(root.internetPingSamples)) }

            InfoLabel { text: I18n.t("network.receiving", "Receiving") }
            DetailValue { text: root.hasTransferStats ? root.formatRate(root.downloadRate) : "--" }
            InfoLabel { text: I18n.t("network.sending", "Sending") }
            DetailValue { text: root.hasTransferStats ? root.formatRate(root.uploadRate) : "--" }

            InfoLabel { text: I18n.t("network.downloaded", "Downloaded") }
            DetailValue { text: root.hasTransferStats ? root.formatBytes(parseFloat(root.info.rx_bytes || "0")) : "--" }
            InfoLabel { text: I18n.t("network.uploaded", "Uploaded") }
            DetailValue { text: root.hasTransferStats ? root.formatBytes(parseFloat(root.info.tx_bytes || "0")) : "--" }

            InfoLabel { text: I18n.t("network.ipAddress", "IP") }
            DetailValue {
              text: root.info.ip || "--"
              copyable: !!root.info.ip
              tooltipText: I18n.t("network.copyIp", "Copy IP")
            }
            InfoLabel { text: I18n.t("network.gateway", "Gateway") }
            DetailValue {
              text: root.info.gateway || "--"
              copyable: !!root.info.gateway
              tooltipText: I18n.t("network.copyGateway", "Copy gateway")
            }

            InfoLabel { text: I18n.t("network.interface", "Interface") }
            DetailValue { text: root.info.iface || "--" }
            InfoLabel { text: root.info.type === "wifi" ? I18n.t("network.frequency", "Frequency") : I18n.t("network.linkSpeed", "Link") }
            DetailValue {
              text: root.info.type === "wifi"
                ? (root.formatHeaderFreq(root.info.freq) || "--")
                : (root.formatHeaderSpeed(root.info.speed) || "--")
            }
          }
        }

        // ---- Wi-Fi band ----
        PanelSeparator { visible: root.canSelectBand; foreground: root.foreground }

        Column {
          visible: root.canSelectBand
          width: parent.width
          spacing: Style.space(10)

          Item {
            width: parent.width
            implicitHeight: Math.max(bandHeader.implicitHeight, bandAutoRow.implicitHeight)

            PanelSectionHeader {
              id: bandHeader
              text: root.bandSectionTitle
              foreground: root.foreground
              fontFamily: root.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Row {
              id: bandAutoRow
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              PanelSectionHeader {
                id: bandAutoLabel
                text: I18n.t("network.automatic", "Automatic")
                foreground: root.foreground
                fontFamily: root.fontFamily
                anchors.verticalCenter: parent.verticalCenter
              }

              ToggleSwitch {
                id: bandAutoSwitch
                trackHeight: Math.round(bandAutoLabel.font.pixelSize * 1.2)
                cursorPad: Style.space(3)
                anchors.verticalCenter: bandAutoLabel.verticalCenter
                checked: !root.bandPinned
                busy: root.bandBusy
                foreground: root.foreground
                onToggled: root.toggleBandAuto()
              }
            }
          }

          Item {
            width: parent.width
            clip: true
            visible: height > 0
            height: root.bandPillsVisible ? bandRow.implicitHeight : 0
            opacity: root.bandPillsVisible ? 1 : 0

            Row {
              id: bandRow
              width: parent.width
              spacing: Style.space(6)

              readonly property int count: Math.max(1, root.bandAvailable.length)
              readonly property real cellWidth: (width - spacing * (count - 1)) / count

              Repeater {
                model: root.bandAvailable
                delegate: Item {
                  required property var modelData
                  required property int index
                  width: bandRow.cellWidth
                  height: bandPill.implicitHeight

                  BandPill {
                    id: bandPill
                    band: modelData
                    width: parent.width
                  }
                }
              }
            }
          }
        }

        // ---- DNS ----
        PanelSeparator { foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: I18n.t("network.dnsProvider", "DNS provider")
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            id: dnsRow
            width: parent.width
            spacing: Style.space(6)

            readonly property int count: 4
            readonly property real cellWidth: (width - spacing * (count - 1)) / count

            DnsProviderPill { provider: "DHCP"; index: 0; tooltipText: I18n.t("network.dnsFromDhcp", "DNS from DHCP"); width: dnsRow.cellWidth }
            DnsProviderPill { provider: "Cloudflare"; index: 1; tooltipText: I18n.t("network.setDnsTo", "Set DNS to %1").arg("Cloudflare"); width: dnsRow.cellWidth }
            DnsProviderPill { provider: "Google"; index: 2; tooltipText: I18n.t("network.setDnsTo", "Set DNS to %1").arg("Google"); width: dnsRow.cellWidth }
            DnsProviderPill { provider: "Custom"; index: 3; tooltipText: I18n.t("network.setCustomDns", "Set custom DNS"); width: dnsRow.cellWidth }
          }
        }

        // ---- Wi-Fi networks ----
        PanelSeparator { visible: root.wifiStationAvailable; foreground: root.foreground }

        PanelSectionHeader {
          visible: root.wifiStationAvailable && root.scanning
          text: I18n.t("network.scanningWifi", "Scanning for Wi-Fi…")
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        ListView {
          id: networkList
          visible: root.wifiStationAvailable
          width: parent.width
          height: Math.min(contentHeight, Style.space(260))
          spacing: Style.space(4)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
          model: root.wifiStationAvailable ? root.wifiNetworks : []

          delegate: Item {
            required property var modelData
            required property int index
            readonly property string sectionTitle: root.wifiSectionTitle(index)
            width: ListView.view.width
            height: delegateColumn.implicitHeight

            Column {
              id: delegateColumn
              width: parent.width
              spacing: Style.space(4)

              PanelSectionHeader {
                visible: sectionTitle !== ""
                text: sectionTitle
                foreground: root.foreground
                fontFamily: root.fontFamily
                height: visible ? implicitHeight : 0
              }

              NetworkRow {
                width: parent.width
                net: modelData
                rowIndex: index
              }
            }
          }
        }
      }
    }
  }

  component BandPill: Button {
    id: pill
    required property string band

    text: root.bandLabel(band)
    tooltipText: root.bandTooltip(band)
    fontSize: Style.font.bodySmall
    foreground: root.foreground
    fontFamily: root.fontFamily
    horizontalPadding: Style.spacing.controlPaddingX
    verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
    bordered: true
    active: root.bandCurrent === band
    selected: root.bandEffective === band
    onClicked: root.setBand(band)
  }

  component DnsProviderPill: Button {
    id: pill
    required property string provider
    required property int index

    signal picked()
    text: provider === "Custom" ? I18n.t("network.dnsCustom", "Custom") : provider
    fontSize: Style.font.bodySmall
    foreground: root.foreground
    fontFamily: root.fontFamily
    horizontalPadding: Style.spacing.controlPaddingX
    verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
    bordered: true
    active: root.dnsEffective === provider
    onClicked: root.setDns(pill.provider)
  }

  component NetworkRow: CursorSurface {
    id: row
    required property var net
    required property int rowIndex

    readonly property bool isConnected: net && net.connected
    readonly property bool isKnown: !!(net && net.known)
    readonly property bool requiresCredentials: net ? root.requiresCredentials(net.security) : false
    readonly property bool isEnterprise: net
      ? (net.security === WifiSecurityType.Wpa2Eap || net.security === WifiSecurityType.WpaEap)
      : false
    readonly property bool canForget: root.canForgetNetwork(net)
    readonly property bool isBusy: root.actionKind !== "" && root.actionSsid === (net ? net.ssid : "")
    readonly property bool isFailed: root.failureReason !== "" && root.failureSsid === (net ? net.ssid : "")
    readonly property bool isPasswordOpen: root.passwordSsid !== "" && root.passwordSsid === (net ? net.ssid : "")
    readonly property bool forgetVisible: canForget && (!requiresCredentials || rightMouse.containsMouse)

    current: isConnected
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill

    function submitCredentials() {
      if (!net || root.busy || root.passwordText.length === 0) return
      if (!isEnterprise) return root.connectWithPassphrase(net.ssid, root.passwordText)
      if (root.identityText.length > 0) root.connectEnterprise(net.ssid, root.identityText, root.passwordText)
    }

    readonly property string statusText: {
      if (!net) return ""
      if (isPasswordOpen) return ""
      if (isBusy && root.actionKind === "connect") return I18n.t("network.connecting", "Connecting…")
      if (isBusy && root.actionKind === "disconnect") return I18n.t("network.disconnecting", "Disconnecting…")
      if (isBusy && root.actionKind === "forget") return I18n.t("network.forgetting", "Forgetting…")
      if (isFailed) return root.failureReason || I18n.t("network.failed", "Failed")
      if (isConnected && root.kind === "wifi" && root.hasCaptivePortal) return I18n.t("network.signInRequired", "Sign in required")
      if (isConnected) return I18n.t("network.connected", "Connected")
      return ""
    }

    readonly property color statusColor: {
      if (isFailed) return root.urgentColor
      if (isBusy) return root.foreground
      if (isConnected && root.kind === "wifi" && root.hasCaptivePortal) return root.urgentColor
      if (isConnected) return root.foreground
      return Qt.darker(root.foreground, 1.5)
    }

    implicitHeight: rowBody.implicitHeight + (isPasswordOpen ? passwordPanel.implicitHeight + Style.spacing.md : 0)

    Connections {
      target: row.net ? root.networkForSsid(row.net.ssid) : null
      function onConnectionFailed(reason) {
        var ours = root.actionKind === "connect" && root.actionSsid === (row.net.ssid || "")
        root.failNetworkAction(root.networkForSsid(row.net.ssid), reason)
        if (ours && root.shouldRepromptPassphrase(reason, row.requiresCredentials)) root.openPasswordPrompt(row.net.ssid)
      }
      function onConnectedChanged() { if (row.net) root.checkActionCompletion(root.networkForSsid(row.net.ssid)) }
      function onKnownChanged() { if (row.net) root.checkActionCompletion(root.networkForSsid(row.net.ssid)) }
      function onStateChangingChanged() { if (row.net) root.checkActionCompletion(root.networkForSsid(row.net.ssid)) }
    }

    MouseArea {
      id: rowMouse
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: rowBody.implicitHeight
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton
      cursorShape: Qt.PointingHandCursor
      enabled: !root.busy

      onClicked: {
        if (!row.net) return
        if (row.isConnected) { root.disconnectRow(row.net.ssid); return }
        if (row.requiresCredentials && !row.isKnown) { root.openPasswordPrompt(row.net.ssid); return }
        root.connectDirectly(row.net.ssid)
      }
    }

    Item {
      id: rowBody
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      implicitHeight: Math.max(networkIcon.implicitHeight, networkInfo.implicitHeight, rightAction.implicitHeight) + Style.spacing.rowPaddingX

      Text {
        id: networkIcon
        textFormat: Text.PlainText
        text: row.net ? Model.connectionIcon("wifi", row.net.signal,
          row.isConnected && root.kind === "wifi" ? root.connectivity : "") : ""
        color: row.statusColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Item {
        id: rightAction
        visible: row.requiresCredentials || row.canForget
        width: Style.space(22)
        implicitHeight: lockIndicator.implicitHeight
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        Text {
          id: lockIndicator
          textFormat: Text.PlainText
          visible: row.requiresCredentials || row.forgetVisible
          width: parent.width
          anchors.verticalCenter: parent.verticalCenter
          horizontalAlignment: Text.AlignHCenter
          text: row.forgetVisible ? "󰅙" : "󰌾"
          color: row.forgetVisible ? root.urgentColor : Qt.darker(root.foreground, 1.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
        }

        MouseArea {
          id: rightMouse
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton
          enabled: row.canForget && !root.busy
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: if (row.net) root.forget(row.net)
        }

        PanelToolTip {
          visible: rightMouse.containsMouse
          text: I18n.t("network.forgetNetwork", "Forget network")
          fontFamily: root.fontFamily
        }
      }

      Column {
        id: networkInfo
        spacing: Style.space(1)
        anchors.left: networkIcon.right
        anchors.leftMargin: Style.space(10)
        anchors.right: rightAction.visible ? rightAction.left : parent.right
        anchors.rightMargin: rightAction.visible ? Style.space(8) : 0
        anchors.verticalCenter: parent.verticalCenter

        Text {
          textFormat: Text.PlainText
          text: row.net ? (row.net.ssid || I18n.t("network.hidden", "Hidden network")) : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          width: parent.width
        }
        Text {
          textFormat: Text.PlainText
          text: row.statusText
          visible: row.statusText !== ""
          height: visible ? implicitHeight : 0
          color: row.statusColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          width: parent.width
        }
      }
    }

    Item {
      id: passwordPanel
      visible: row.isPasswordOpen
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: rowMouse.bottom
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      anchors.topMargin: Style.space(4)
      implicitHeight: (idField.visible ? idField.implicitHeight + Style.space(4) : 0) + pwField.implicitHeight + Style.spacing.rowGap
      height: implicitHeight

      TextField {
        id: idField
        visible: row.isEnterprise && !row.isBusy && !row.isFailed
        anchors.left: parent.left
        anchors.right: connectPwBtn.left
        anchors.top: parent.top
        anchors.rightMargin: Style.space(6)
        placeholderText: I18n.t("network.identity", "Identity")
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        foreground: root.foreground
        horizontalPadding: Style.spacing.controlGap
        verticalPadding: Style.spacing.controlPaddingY
        enabled: !row.isBusy
        text: row.isPasswordOpen ? root.identityText : ""

        onAccepted: pwField.forceActiveFocus()
        onTextChanged: if (row.isPasswordOpen && text !== root.identityText) root.identityText = text
        Keys.onEscapePressed: root.cancelPasswordPrompt()
        onVisibleChanged: if (visible) Qt.callLater(forceActiveFocus)
        Component.onCompleted: if (visible) Qt.callLater(forceActiveFocus)
      }

      TextField {
        id: pwField
        visible: !row.isBusy && !row.isFailed
        anchors.left: parent.left
        anchors.right: connectPwBtn.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.spacing.rowGap / 2
        anchors.rightMargin: Style.space(6)
        password: true
        placeholderText: I18n.t("network.passphrase", "Passphrase")
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        foreground: root.foreground
        horizontalPadding: Style.spacing.controlGap
        verticalPadding: Style.spacing.controlPaddingY
        enabled: !row.isBusy
        text: row.isPasswordOpen ? root.passwordText : ""

        onAccepted: row.submitCredentials()
        onTextChanged: if (row.isPasswordOpen && text !== root.passwordText) root.passwordText = text
        Keys.onEscapePressed: root.cancelPasswordPrompt()
        onVisibleChanged: if (visible && !row.isEnterprise) Qt.callLater(forceActiveFocus)
        Component.onCompleted: if (visible && !row.isEnterprise) Qt.callLater(forceActiveFocus)
      }

      BorderSurface {
        visible: row.isBusy || row.isFailed
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Style.spacing.controlHeight
        color: Style.normalFillFor(root.foreground)
        borderSpec: Border.controlSpec("normal", root.foreground, Commons.Color.accent)
        radius: Style.cornerRadius

        Text {
          textFormat: Text.PlainText
          anchors.fill: parent
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: row.isFailed ? I18n.t("network.wrongPassword", "Wrong password") : I18n.t("network.connecting", "Connecting…")
          color: row.isFailed ? root.urgentColor : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }

      PanelActionButton {
        id: connectPwBtn
        visible: !row.isBusy && !row.isFailed
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        enabled: row.net && pwField.text.length > 0 && (!row.isEnterprise || idField.text.length > 0)
        iconText: "󰄬"
        tooltipText: I18n.t("network.connect", "Connect")
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: row.submitCredentials()
      }
    }
  }

  component DetailValue: InfoValue {
    property bool copyable: false
    property string tooltipText: I18n.t("network.copyToClipboard", "Copy to clipboard")

    Layout.fillWidth: true
    horizontalAlignment: Text.AlignRight

    MouseArea {
      id: valueMouse
      anchors.fill: parent
      enabled: copyable && parent.text !== ""
      hoverEnabled: enabled
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(parent.text) + " | wl-copy"])
    }

    PanelToolTip {
      visible: valueMouse.enabled && valueMouse.containsMouse
      text: tooltipText
      fontFamily: root.fontFamily
    }
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
