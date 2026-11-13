import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../../../"

Item {
  id: root

  // ---- host contract -----------------------------------------------------
  property var settings: ({})
  property var defaultSettings: ({})
  property string moduleName: "tailscale"
  property var bar: null

  // ---- bar-widget API ----------------------------------------------------
  readonly property color foreground: Commons.Color.foreground
  readonly property color urgentColor: Commons.Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: Style.font.family

  readonly property string icon: "󰖂"
  readonly property string statusText: tailscale.statusText
  readonly property bool urgent: tailscale.needsLogin
  readonly property bool active: tailscale.active
  readonly property bool available: tailscale.installed

  property string focusSection: "header"
  property int peerIndex: 0
  property int exitNodeIndex: 0
  property int mullvadRegionIndex: 0
  property bool cursorActive: false
  property bool copyMenuOpen: false
  property bool mullvadPickerOpen: false
  property string mullvadQuery: ""
  property int phraseIndex: 0
  property string peerQuery: ""
  property var copyPeer: null
  property int copyIndex: 0
  readonly property var copyOptions: copyOptionsFor(copyPeer)

  readonly property var activePhrases: [
    I18n.t("tailscale.phrase1", "Connected and meshed"),
    I18n.t("tailscale.phrase2", "Tailnet online"),
    I18n.t("tailscale.phrase3", "Peers reachable"),
    I18n.t("tailscale.phrase4", "Mesh established"),
    I18n.t("tailscale.phrase5", "WireGuard humming"),
    I18n.t("tailscale.phrase6", "Private network up"),
    I18n.t("tailscale.phrase7", "Every machine in reach"),
    I18n.t("tailscale.phrase8", "Secure link established"),
    I18n.t("tailscale.phrase9", "NAT traversed"),
    I18n.t("tailscale.phrase10", "Tailscale running")
  ]
  readonly property string heroPhraseText: activePhrases[phraseIndex % activePhrases.length]

  readonly property bool showConnections: tailscale.accounts.length > 1 || tailscale.accountsAccessDenied
  readonly property bool showPeers: tailscale.active && filteredPeers.length > 0
  readonly property var recentMullvadRegions: settings.recentMullvadRegions instanceof Array ? settings.recentMullvadRegions : []
  readonly property var recentMullvadExitNodes: recentMullvadNodes()
  readonly property var exitNodes: displayExitNodes()
  readonly property bool showExitNodes: tailscale.active && (exitNodes.length > 0 || tailscale.mullvadRegions.length > 0)
  readonly property var filteredMullvadRegions: filteredMullvadRegionNodes()
  readonly property color iconColor: tailscale.active ? foreground : dim
  readonly property color hoverFill: Style.hoverFillFor(foreground, Commons.Color.accent)
  readonly property color selectedFill: Style.selectedFillFor(foreground, Commons.Color.accent)
  readonly property string toggleHint: tailscale.active ? I18n.t("tailscale.turnOff", "Turn off") : (tailscale.needsLogin ? I18n.t("tailscale.authorizeDevice", "Authorize device") : I18n.t("tailscale.turnOn", "Turn on"))

  readonly property var filteredPeers: {
    var query = peerQuery.trim().toLowerCase()
    if (query === "") return tailscale.peers
    var result = []
    for (var i = 0; i < tailscale.peers.length; i++) {
      var p = tailscale.peers[i]
      var ip = p.TailscaleIPs && p.TailscaleIPs.length > 0 ? String(p.TailscaleIPs[0]) : ""
      var hay = (String(p.DisplayName || "") + " " + String(p.DNSName || "") + " " + ip).toLowerCase()
      if (hay.indexOf(query) !== -1) result.push(p)
    }
    return result
  }

  implicitWidth: 390
  implicitHeight: surface.height

  function setting(name, fallback) {
    var value = root.settings ? root.settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function copyOptionsFor(peer) {
    var options = []
    if (!peer) return options
    var name = String(peer.DisplayName || peer.HostName || "")
    var dns = String(peer.DNSName || "")
    var ipv6 = peer.TailscaleIPv6 && peer.TailscaleIPv6.length > 0 ? String(peer.TailscaleIPv6[0] || "") : ""
    var ip = peer.TailscaleIPs && peer.TailscaleIPs.length > 0 ? String(peer.TailscaleIPs[0]) : ""
    if (name !== "") options.push({ kind: "name", label: name })
    if (dns !== "") options.push({ kind: "dns", label: dns })
    if (ipv6 !== "") options.push({ kind: "ipv6", label: ipv6 })
    if (ip !== "") options.push({ kind: "ip", label: ip })
    return options
  }

  function copyOption(kind) {
    var peer = copyPeer
    if (peer) {
      if (kind === "name") tailscale.copyPeerName(peer)
      else if (kind === "dns") tailscale.copyPeerDnsName(peer)
      else if (kind === "ipv6") {
        var ipv6 = peer.TailscaleIPv6 && peer.TailscaleIPv6.length > 0 ? String(peer.TailscaleIPv6[0] || "") : ""
        tailscale.copyToClipboard(ipv6, String(peer.DisplayName || peer.HostName || "") + " IPv6")
      } else if (kind === "ip") tailscale.copyPeerIp(peer)
    }
    if (sharedCopyPopup) sharedCopyPopup.close()
  }

  function openCopyMenuFor(peer, row) {
    if (!peer || !peerList || !sharedCopyPopup || copyOptionsFor(peer).length === 0) return
    if (!copyPeer || String(copyPeer.id || "") !== String(peer.id || "")) copyIndex = 0
    copyPeer = peer
    copyIndex = Math.max(0, Math.min(copyIndex, copyOptions.length - 1))
    var anchor = row || peerList
    var point = anchor.mapToItem(peerList, 0, anchor.height)
    var x = peerList.LayoutMirroring.enabled ? point.x : point.x + anchor.width - sharedCopyPopup.width
    sharedCopyPopup.x = Math.max(0, Math.min(peerList.width - sharedCopyPopup.width, x))
    sharedCopyPopup.y = point.y + Style.space(4)
    sharedCopyPopup.open()
  }

  function selectedPeer() {
    if (filteredPeers.length === 0) return null
    return filteredPeers[Math.max(0, Math.min(peerIndex, filteredPeers.length - 1))]
  }

  function sendPeerFile(peer) {
    if (!peer || !tailscale.canSendFiles(peer)) return
    tailscale.sendFile(peer)
  }

  function displayExitNodes() {
    var nodes = []
    for (var i = 0; i < tailscale.tailnetExitNodes.length; i++) nodes.push(tailscale.tailnetExitNodes[i])
    for (var j = 0; j < recentMullvadExitNodes.length; j++) nodes.push(recentMullvadExitNodes[j])
    if (tailscale.mullvadRegions.length > 0) nodes.push({ id: "mullvad:add", AddMullvad: true, DisplayName: I18n.t("tailscale.chooseMullvadRegion", "Choose Mullvad region") })
    return nodes
  }

  function recentMullvadNodes() {
    var nodes = []
    var seen = {}
    for (var a = 0; a < tailscale.mullvadRegions.length && nodes.length < 5; a++) {
      var active = tailscale.mullvadRegions[a]
      var activeKey = mullvadRegionKey(active)
      if (active.ExitNode === true && activeKey !== "" && !seen[activeKey]) {
        nodes.push(active)
        seen[activeKey] = true
      }
    }
    for (var i = 0; i < recentMullvadRegions.length && nodes.length < 5; i++) {
      var region = String(recentMullvadRegions[i] || "")
      if (region === "" || seen[region]) continue
      var node = mullvadRegionNode(region)
      if (node) {
        nodes.push(node)
        seen[region] = true
      }
    }
    return nodes
  }

  function mullvadRegionKey(node) {
    if (!node) return ""
    var country = String(node.Country || "")
    var city = String(node.City || "")
    if (country === "" || city === "") return ""
    return country + "\n" + city
  }

  function mullvadRegionNode(region) {
    for (var i = 0; i < tailscale.mullvadRegions.length; i++) {
      var node = tailscale.mullvadRegions[i]
      if (mullvadRegionKey(node) === String(region || "")) return node
      if (String(node.Country || "") === String(region || "")) return node
    }
    return null
  }

  function filteredMullvadRegionNodes() {
    var query = String(mullvadQuery || "").trim().toLowerCase()
    var result = []
    for (var i = 0; i < tailscale.mullvadRegions.length; i++) {
      var node = tailscale.mullvadRegions[i]
      var label = (String(node.City || "") + " " + String(node.Country || "")).toLowerCase()
      if (query === "" || label.indexOf(query) !== -1) result.push(node)
    }
    return result
  }

  function persistRecentMullvad(region) {
    var name = String(region || "")
    if (name === "") return
    var next = [name]
    for (var i = 0; i < recentMullvadRegions.length && next.length < 5; i++) {
      var existing = String(recentMullvadRegions[i] || "")
      if (existing !== "" && existing !== name && next.indexOf(existing) === -1) next.push(existing)
    }
    root.settings = Object.assign({}, root.settings, { recentMullvadRegions: next })
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, root.settings)
  }

  function chooseExitNode(peer) {
    if (!peer) return
    if (peer.AddMullvad === true) {
      mullvadPickerOpen = !mullvadPickerOpen
      mullvadRegionIndex = 0
      if (mullvadPickerOpen) Qt.callLater(function() { if (mullvadSearch) mullvadSearch.forceActiveFocus() })
      return
    }
    if (peer.Mullvad === true) persistRecentMullvad(mullvadRegionKey(peer))
    tailscale.setExitNode(peer)
    mullvadPickerOpen = false
  }

  Timer {
    id: phraseTimer
    interval: 2800
    running: root.active
    repeat: true
    onTriggered: root.phraseIndex = (root.phraseIndex + 1) % root.activePhrases.length
  }

  Service {
    id: tailscale
    settings: root.settings
    peersWanted: true
  }

  Component.onCompleted: tailscale.refresh(false, true)

  BorderSurface {
    id: surface
    width: parent.width
    height: Math.min(column.implicitHeight + Style.spacing.panelPadding * 2, 600)
    color: Colors.base01
    borderSpec: Border.flat(Colors.base04, 1)
    radius: Style.cornerRadius

    Flickable {
      id: panelFlick
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
        width: panelFlick.width
        spacing: Style.space(12)

        // ---- Hero ----
        RowLayout {
          id: heroRow
          width: parent.width
          spacing: Style.space(12)

          TailscaleIcon {
            iconSize: Style.font.display
            color: root.iconColor
            badgeColor: root.urgentColor
            crossed: !tailscale.active && !tailscale.needsLogin
            warning: tailscale.needsLogin
            Layout.alignment: Qt.AlignVCenter
          }

          Column {
            Layout.fillWidth: true
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: tailscale.installed ? (tailscale.selfName || "Tailscale") : "Tailscale"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: tailscale.active ? root.heroPhraseText : I18n.t("tailscale.disconnectedMeta", "Disconnected")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }

          ToggleSwitch {
            id: heroSwitch
            visible: tailscale.installed
            checked: tailscale.active
            busy: tailscale.busy
            foreground: root.foreground
            Layout.alignment: Qt.AlignVCenter
            onToggled: tailscale.toggleTailscale()

            PanelToolTip {
              visible: heroSwitch.containsMouse
              text: root.toggleHint
              fontFamily: root.fontFamily
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          visible: tailscale.actionStatus !== "" || tailscale.lastError !== ""
          width: parent.width
          text: tailscale.actionStatus !== "" ? tailscale.actionStatus : tailscale.lastError
          color: tailscale.lastError !== "" && tailscale.actionStatus === "" ? root.urgentColor : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Text {
          visible: !tailscale.installed
          width: parent.width
          text: I18n.t("tailscale.notInstalled", "Tailscale is not installed")
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        // ---- Connections ----
        PanelSeparator { visible: root.showConnections; foreground: root.foreground }

        Column {
          visible: root.showConnections
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: I18n.t("tailscale.connections", "Connections")
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          AuthRow {
            visible: tailscale.accountsAccessDenied
            width: parent.width
          }

          Repeater {
            model: tailscale.accounts
            AccountRow {
              required property var modelData
              required property int index
              width: parent.width
              account: modelData
            }
          }
        }

        // ---- Exit nodes ----
        PanelSeparator { visible: root.showExitNodes; foreground: root.foreground }

        Column {
          visible: root.showExitNodes
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: I18n.t("tailscale.exitNodes", "Exit nodes")
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Column {
            id: exitNodeColumn
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.exitNodes
              ExitNodeRow {
                required property var modelData
                width: exitNodeColumn.width
                peer: modelData
              }
            }

            Column {
              visible: root.mullvadPickerOpen
              width: parent.width
              spacing: Style.space(6)

              TextField {
                id: mullvadSearch
                width: parent.width
                foreground: root.foreground
                placeholderText: I18n.t("tailscale.searchRegions", "Search regions")
                text: root.mullvadQuery
                onTextChanged: {
                  root.mullvadQuery = text
                  root.mullvadRegionIndex = 0
                }
                onAccepted: root.activateMullvadRegionCursor()
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Down) {
                    root.moveMullvadRegionCursor(1)
                    event.accepted = true
                  } else if (event.key === Qt.Key_Up) {
                    root.moveMullvadRegionCursor(-1)
                    event.accepted = true
                  } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.activateMullvadRegionCursor()
                    event.accepted = true
                  } else if (event.key === Qt.Key_Escape) {
                    root.mullvadPickerOpen = false
                    event.accepted = true
                  }
                }
              }

              Text {
                visible: root.filteredMullvadRegions.length === 0
                width: parent.width
                text: I18n.t("tailscale.noRegions", "No regions")
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignHCenter
              }

              Column {
                id: mullvadRegionColumn
                width: parent.width
                spacing: Style.space(6)

                Repeater {
                  model: root.filteredMullvadRegions
                  MullvadRegionRow {
                    required property var modelData
                    required property int index
                    width: parent.width
                    peer: modelData
                    rowIndex: index
                  }
                }
              }
            }
          }
        }

        // ---- Machines ----
        PanelSeparator { visible: tailscale.installed && tailscale.active; foreground: root.foreground }

        Column {
          visible: tailscale.installed && tailscale.active
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: {
              if (tailscale.peers.length === 0) return I18n.t("tailscale.machines", "Machines")
              var total = I18n.formatNumber(tailscale.peers.length)
              if (root.peerQuery.trim() === "") return I18n.t("tailscale.machinesCount", "%1 machines").arg(total)
              return I18n.t("tailscale.machinesFiltered", "%1 of %2 machines").arg(I18n.formatNumber(root.filteredPeers.length)).arg(total)
            }
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          TextField {
            id: peerSearch
            visible: tailscale.peers.length > 8
            width: parent.width
            foreground: root.foreground
            placeholderText: I18n.t("tailscale.searchMachines", "Search machines")
            onVisibleChanged: if (!visible && text !== "") text = ""
            onTextChanged: {
              root.peerQuery = text
              root.peerIndex = 0
              peerList.rememberedY = 0
              peerList.positionViewAtBeginning()
            }
          }

          Text {
            visible: tailscale.installed && tailscale.active && tailscale.peersLoaded && tailscale.peers.length === 0
            width: parent.width
            text: I18n.t("tailscale.noMachines", "No machines")
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            visible: tailscale.installed && tailscale.active && !tailscale.peersLoaded && tailscale.peers.length === 0
            width: parent.width
            text: I18n.t("tailscale.loadingMachines", "Loading machines…")
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            visible: tailscale.peers.length > 0 && root.filteredPeers.length === 0
            width: parent.width
            text: I18n.t("tailscale.noMatchingMachines", "No matching machines")
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            horizontalAlignment: Text.AlignHCenter
          }

          ListView {
            id: peerList
            visible: root.showPeers
            width: parent.width
            height: Math.min(contentHeight, Style.space(300))
            clip: true
            spacing: Style.space(6)
            model: root.filteredPeers
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height
            property real rememberedY: 0
            function rememberPosition() { rememberedY = contentY }
            onContentYChanged: if (moving || dragging) rememberedY = contentY
            onModelChanged: contentY = Math.max(0, Math.min(rememberedY, Math.max(0, contentHeight - height)))
            ScrollBar.vertical: ScrollBar {
              policy: ScrollBar.AsNeeded
              onPressedChanged: if (!pressed) peerList.rememberPosition()
            }

            delegate: PeerRow {
              required property var modelData
              required property int index
              width: peerList.width
              peer: modelData
              rowIndex: index
            }
          }

          Popup {
            id: sharedCopyPopup
            parent: peerList
            width: Style.space(280)
            padding: 0
            modal: false
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            onOpenedChanged: root.copyMenuOpen = opened
            background: BorderSurface {
              color: Commons.Color.popups.background
              borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, 1)
              radius: Style.cornerRadius
            }

            contentItem: Column {
              width: parent.width
              focus: true
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  sharedCopyPopup.close()
                  event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                  root.copyIndex = Math.min(root.copyOptions.length - 1, root.copyIndex + 1)
                  event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                  root.copyIndex = Math.max(0, root.copyIndex - 1)
                  event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                  root.copyOption(root.copyOptions[root.copyIndex].kind)
                  event.accepted = true
                }
              }

              Repeater {
                model: root.copyOptions
                CopyChoice {
                  required property var modelData
                  required property int index
                  width: parent.width
                  label: String(modelData.label || "")
                  selected: root.copyIndex === index
                  onHovered: root.copyIndex = index
                  onChosen: root.copyOption(String(modelData.kind || ""))
                }
              }
            }
          }
        }
      }
    }
  }

  component AuthRow: CursorSurface {
    id: authRow
    foreground: root.foreground
    implicitHeight: authContent.implicitHeight + Style.spacing.xl

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: tailscale.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
      enabled: !tailscale.busy
      onClicked: tailscale.authorizeTailscaleOperator()
    }

    RowLayout {
      id: authContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        text: "󰒃"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          text: I18n.t("tailscale.authorizeOperator", "Authorize Tailscale operator")
          textFormat: Text.PlainText
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          text: I18n.t("tailscale.authorizeHelp", "Allow this user to control Tailscale")
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }

  component AccountRow: CursorSurface {
    id: accountRow
    property var account: null
    readonly property bool selectedAccount: account && account.selected === true
    readonly property bool switchingAccount: account && tailscale.switchingAccountId === String(account.id || "")
    readonly property string accountText: account ? tailscale.accountLabel(account) : I18n.t("tailscale.account", "Account")

    current: selectedAccount
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: accountInner.implicitHeight + Style.spacing.xl

    Row {
      id: accountInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        text: ""
        color: accountRow.selectedAccount || accountRow.switchingAccount ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: accountRow.accountText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: accountRow.selectedAccount
        elide: Text.ElideRight
        width: parent.width - Style.space(22) - Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: if (accountRow.account) tailscale.switchAccount(accountRow.account.id)
    }
  }

  component PeerRow: CursorSurface {
    id: peerRow
    property var peer: null
    readonly property string peerName: peer ? String(peer.DisplayName || peer.HostName || I18n.t("tailscale.unknown", "Unknown")) : I18n.t("tailscale.unknown", "Unknown")
    readonly property string peerIp: peer && peer.TailscaleIPs && peer.TailscaleIPs.length > 0 ? String(peer.TailscaleIPs[0]) : ""
    readonly property string peerDns: peer ? String(peer.DNSName || "") : ""
    foreground: root.foreground
    implicitHeight: Math.max(peerContent.implicitHeight, copyButton.implicitHeight) + Style.spacing.rowPaddingX

    function openCopyMenu() {
      root.openCopyMenuFor(peer, peerRow)
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      hoverEnabled: true
      cursorShape: Qt.ArrowCursor
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: tailscale.osIcon(peer ? peer.OS : "")
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        id: peerContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: peerRow.peerName
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: {
            var parts = []
            if (peerRow.peerIp !== "") parts.push(peerRow.peerIp)
            if (peerRow.peerDns !== "") parts.push(peerRow.peerDns)
            return parts.join(" · ")
          }
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      PanelActionButton {
        visible: tailscale.canSendFiles(peerRow.peer)
        iconText: "󰒊"
        tooltipText: I18n.t("tailscale.sendFiles", "Send files")
        foreground: root.foreground
        fontFamily: root.fontFamily
        Layout.alignment: Qt.AlignVCenter
        onClicked: root.sendPeerFile(peerRow.peer)
      }

      PanelActionButton {
        id: copyButton
        iconText: "󰆏"
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: peerRow.peerIp !== "" || peerRow.peerName !== "" || peerRow.peerDns !== ""
        Layout.alignment: Qt.AlignVCenter
        onClicked: peerRow.openCopyMenu()
      }
    }
  }

  component CopyChoice: CursorSurface {
    id: copyChoice
    signal chosen()
    signal hovered()
    property string label: ""
    property bool selected: false

    visible: enabled
    foreground: root.foreground
    hasCursor: selected
    implicitHeight: Style.space(48)
    radius: 0

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: copyChoice.hovered()
      onClicked: copyChoice.chosen()
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)
      spacing: Style.space(10)

      Text {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        text: copyChoice.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        text: "󰆏"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }

  component ExitNodeRow: CursorSurface {
    id: exitNodeRow
    property var peer: null
    readonly property bool addMullvad: peer && peer.AddMullvad === true
    readonly property bool activeExitNode: peer && peer.ExitNode === true
    readonly property bool settingExitNode: peer && tailscale.settingExitNodeId === String(peer.id || "")
    readonly property string peerName: peer ? String(peer.DisplayName || peer.HostName || I18n.t("tailscale.unknown", "Unknown")) : I18n.t("tailscale.unknown", "Unknown")

    current: activeExitNode || settingExitNode || (addMullvad && root.mullvadPickerOpen)
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: exitNodeInner.implicitHeight + Style.spacing.xl

    Row {
      id: exitNodeInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: exitNodeRow.addMullvad ? "+" : (peer && peer.Mullvad === true ? "󰖂" : "󱇢")
        color: exitNodeRow.activeExitNode || exitNodeRow.settingExitNode || exitNodeRow.addMullvad ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: exitNodeRow.peerName
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: exitNodeRow.activeExitNode
        elide: Text.ElideRight
        width: parent.width - Style.space(22) - Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: exitNodeMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.chooseExitNode(exitNodeRow.peer)
    }

    PanelToolTip {
      visible: exitNodeMouse.containsMouse && exitNodeRow.peerName !== ""
      text: exitNodeRow.activeExitNode ? I18n.t("tailscale.disconnect", "Disconnect") : I18n.t("tailscale.connect", "Connect")
      fontFamily: root.fontFamily
    }
  }

  component MullvadRegionRow: CursorSurface {
    id: regionRow
    property var peer: null
    property int rowIndex: 0
    readonly property string regionName: root.mullvadRegionTitle(peer)
    readonly property string regionDetail: root.mullvadRegionSubtitle(peer)
    readonly property bool activeExitNode: peer && peer.ExitNode === true
    readonly property bool settingExitNode: peer && tailscale.settingExitNodeId === String(peer.id || "")
    readonly property bool selectedRegion: root.mullvadPickerOpen && root.mullvadRegionIndex === rowIndex

    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    current: activeExitNode || settingExitNode || selectedRegion
    implicitHeight: regionInner.implicitHeight + Style.spacing.lg

    Row {
      id: regionInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        text: "󰖂"
        color: regionRow.current ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        width: parent.width - Style.space(30)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: regionRow.regionName
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: regionRow.activeExitNode
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: regionRow.regionDetail
          visible: text !== ""
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }

    MouseArea {
      id: regionMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.mullvadRegionIndex = regionRow.rowIndex
      onClicked: root.chooseExitNode(regionRow.peer)
    }

    PanelToolTip {
      visible: regionMouse.containsMouse
      text: regionRow.activeExitNode ? I18n.t("tailscale.disconnect", "Disconnect") : I18n.t("tailscale.connect", "Connect")
      fontFamily: root.fontFamily
    }
  }

  function moveMullvadRegionCursor(delta) {
    if (filteredMullvadRegions.length === 0) return
    root.mullvadRegionIndex = Math.max(0, Math.min(filteredMullvadRegions.length - 1, root.mullvadRegionIndex + delta))
  }

  function activateMullvadRegionCursor() {
    var region = root.filteredMullvadRegions[root.mullvadRegionIndex]
    if (region) root.chooseExitNode(region)
  }

  function mullvadRegionTitle(peer) {
    if (!peer) return I18n.t("tailscale.unknown", "Unknown")
    var city = String(peer.City || "").trim()
    var country = String(peer.Country || "").trim()
    if (city === "" || city === "Any") return country || String(peer.DisplayName || I18n.t("tailscale.unknown", "Unknown"))
    return city
  }

  function mullvadRegionSubtitle(peer) {
    if (!peer) return ""
    return String(peer.Country || "").trim()
  }
}
