pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "../../../services"
import "Model.js" as Model

// Audio panel body, vendored from the upstream audio plugin. This is the popup
// content only: the bar button and the panel window live in the host
// (services/PanelHost.qml + services/ScreenPopup.qml), and the audio graph is
// read and written through Quickshell.Services.Pipewire and wpctl directly —
// no audio helper helper CLIs remain.
Item {
  id: root

  // ----- Host-injected context -----
  property QtObject bar: null
  property var settings: ({})
  property string moduleName: "audio"

  // ----- Bar-widget API (for a future widget) -----
  readonly property string icon: outputIcon()
  readonly property string statusText: outputVolumeName(outputMuted ? 0 : outputVolume, outputMuted)
  readonly property bool active: hasOutput && !outputMuted

  // ----- Theme -----
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // The panel is loaded only while the host popup is open, so it is always
  // "opened" here. Kept as a property so the existing graph logic reads the same.
  readonly property bool opened: true

  // ----- PipeWire graph -----
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var mprisPlayers: Mpris.players ? Mpris.players.values : []
  readonly property var activeMediaPlayer: {
    for (var i = 0; i < mprisPlayers.length; i++)
      if (mprisPlayers[i] && mprisPlayers[i].isPlaying) return mprisPlayers[i]
    return null
  }

  // Nodes of a platform's audio processing, which are neither devices nor apps,
  // stay out of every list (AudioNodes.platformHides). Most machines have none.
  readonly property var nodeNames: {
    var names = []
    for (var i = 0; i < nodes.length; i++)
      if (nodes[i] && nodes[i].name) names.push(String(nodes[i].name))
    return names
  }

  function platformHides(node) {
    return !!node && AudioNodes.platformHides(node.name, nodeNames)
  }

  // Virtual sources Quickshell cannot type are no longer enumerated (upstream
  // did this with the audio availability helper); the default source is
  // always kept below, so output/input switching still works.
  readonly property var sourceAvailability: ({})

  readonly property var candidateSinks: {
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (!n || !n.isSink || n.isStream || platformHides(n)) continue
      list.push(n)
    }
    return list
  }

  readonly property var candidateSources: {
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (!n || n.isSink || n.isStream) continue
      if (!isAudioSource(n) && !Model.isUntypedSource(n, sourceAvailability)) continue
      var name = n.name || ""
      if (name === "quickshell" || platformHides(n)) continue
      list.push(n)
    }
    return list
  }

  readonly property var candidateStreams: {
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (!n || !n.isStream || !isPlaybackStream(n)) continue
      // A tuning's output is a playback stream too, but it is the processing
      // itself rather than an application, so it does not belong in the list.
      if (platformHides(n)) continue
      list.push(n)
    }
    return list
  }

  // Identify true playback streams without reading node.properties here:
  // PwNode.properties is invalid until the node is bound, and reading it while
  // capture streams are appearing (for example, when Voxtype starts recording)
  // can destabilize Quickshell's Pipewire service. Quickshell versions differ
  // in how `type` is exposed (media.class, enum name, or numeric enum), but
  // playback streams consistently accept audio input from clients and publish
  // `isSink: true`; capture streams publish as stream sources.
  function isPlaybackStream(node) {
    return Model.isPlaybackStream(node)
  }

  function isAudioSource(node) {
    return Model.isAudioSource(node)
  }

  property var cachedAudioSinks: []
  property var cachedAudioSources: []

  readonly property var rawAudioSinks: {
    var list = candidateSinks.slice()
    if (sink && list.indexOf(sink) < 0) list.unshift(sink)
    return list
  }

  readonly property var rawAudioSources: {
    var list = candidateSources.slice()
    if (source && list.indexOf(source) < 0) list.unshift(source)
    return list
  }

  readonly property var audioSinks: rawAudioSinks.length > 0 ? rawAudioSinks : cachedAudioSinks
  readonly property var audioSources: rawAudioSources.length > 0 ? rawAudioSources : cachedAudioSources

  readonly property var audioStreams: {
    var list = []
    for (var i = 0; i < candidateStreams.length; i++)
      if (candidateStreams[i].audio) list.push(candidateStreams[i])
    return list
  }

  // Feed Repeaters with panel-local snapshots of primitives instead of the live
  // PipeWire model. PipeWire can remove nodes while Quickshell is dispatching
  // the removal signal, and a row still holding the PwNode is a QObject Qt
  // dereferences without a null check, which segfaults the shell. Rows carry id
  // and name only; every delegate resolves its own node through nodeFor().
  property var displayAudioSinks: []
  property var displayAudioSources: []
  property var displayAudioStreams: []

  // A DSP sink -- a speaker tuning, or EasyEffects -- can be the selected output
  // without being where loudness lives: changing its volume alters the level
  // going *into* the processing, so the slider would move while the speakers did
  // not. Upstream resolved the physical sink through the audio sink helper;
  // here the same outcome comes from the graph: a hardware output (ALSA/BlueZ)
  // is its own volume sink, and when the default is a virtual/DSP sink we fall
  // back to the first hardware output in the graph.
  function isHardwareSink(name) {
    var s = String(name || "")
    return s.indexOf("alsa_output.") === 0 || s.indexOf("bluez_output.") === 0
  }

  readonly property var volumeSink: {
    if (!sink) return sink
    if (isHardwareSink(sink.name)) return sink
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && n.isSink && !n.isStream && n.audio && isHardwareSink(n.name)) return n
    }
    return sink
  }

  readonly property real outputVolume: volumeSink && volumeSink.audio ? volumeSink.audio.volume : 0
  readonly property bool outputMuted: volumeSink && volumeSink.audio ? volumeSink.audio.muted : false
  // A virtual source is untyped in Quickshell (see Model.isUntypedSource), so
  // its volume and mute go through wpctl (UntypedInput), and the panel shows no
  // level meter for it: Quickshell's peak monitor takes typed nodes only.
  readonly property bool inputViaWpctl: UntypedInput.active
  readonly property bool inputLevelKnown: !inputViaWpctl || UntypedInput.known
  readonly property real inputVolume: inputViaWpctl ? UntypedInput.volume : (source && source.audio ? source.audio.volume : 0)
  readonly property bool inputMuted: inputViaWpctl ? UntypedInput.muted : (source && source.audio ? source.audio.muted : false)
  readonly property var inputPeakNode: inputViaWpctl ? null : source
  readonly property bool inputLevelShown: !!inputPeakNode

  onRawAudioSinksChanged: if (rawAudioSinks.length > 0) cachedAudioSinks = rawAudioSinks
  onRawAudioSourcesChanged: if (rawAudioSources.length > 0) cachedAudioSources = rawAudioSources

  // Single cursor model shared by keyboard and mouse. Sections:
  //   "output"  — output slider + sink device list
  //   "input"   — input slider + source device list
  //   "streams" — per-app playback streams
  // selectedIndex semantics within a section:
  //   -1            → on the slider row (h/l adjusts volume, m/Enter mute)
  //   0..N-1        → on the Nth device/stream row
  property string focusSection: "output"
  property int selectedIndex: -1
  property bool cursorActive: false

  // "header" is a virtual section for the hero output mute toggle; it sits
  // above the output section so the speaker can be muted from the keyboard.
  readonly property bool headerHasCursor: cursorActive && focusSection === "header"
  readonly property bool hasOutput: !!(volumeSink && volumeSink.audio)
  readonly property bool hasInput: !!(source && source.audio) || (inputViaWpctl && UntypedInput.known)
  readonly property bool anyAudible: (hasOutput && !outputMuted) || (hasInput && !inputMuted)
  readonly property string toggleHint: anyAudible ? I18n.t("audio.mute") : I18n.t("audio.unmute")

  readonly property color hoverFill: bar
    ? Style.hoverFillFor(foreground, Commons.Color.accent)
    : "transparent"
  readonly property color selectedFill: bar
    ? Style.selectedFillFor(foreground, Commons.Color.accent)
    : "transparent"

  function sectionCount(section) {
    if (section === "output") return displayAudioSinks.length
    if (section === "input") return displayAudioSources.length
    if (section === "streams") return displayAudioStreams.length
    return 0
  }

  function sectionVisible(section) {
    if (section === "output") return true
    if (section === "input") return displayAudioSources.length > 0 || !!source
    if (section === "streams") return displayAudioStreams.length > 0
    return false
  }

  function sectionHasSlider(section) {
    if (section === "output") return true
    if (section === "input") return !!source
    return false
  }

  readonly property var visibleSections: {
    var list = []
    if (sectionVisible("output")) list.push("output")
    if (sectionVisible("input")) list.push("input")
    if (sectionVisible("streams")) list.push("streams")
    return list
  }

  function moveCursor(delta) {
    var sections = visibleSections
    if (sections.length === 0) return
    if (focusSection === "header") {
      if (delta > 0) { focusSection = sections[0]; selectedIndex = sectionHasSlider(sections[0]) ? -1 : 0 }
      return
    }
    var sIdx = sections.indexOf(focusSection)
    if (sIdx < 0) { focusSection = sections[0]; selectedIndex = sectionHasSlider(focusSection) ? -1 : 0; return }

    var idx = selectedIndex
    var max = sectionCount(focusSection) - 1
    var hasSlider = sectionHasSlider(focusSection)
    var floor = hasSlider ? -1 : 0

    if (delta > 0) {
      if (idx < max) { selectedIndex = idx + 1; return }
      if (sIdx < sections.length - 1) {
        focusSection = sections[sIdx + 1]
        selectedIndex = sectionHasSlider(focusSection) ? -1 : 0
      }
    } else {
      if (idx > floor) { selectedIndex = idx - 1; return }
      if (sIdx > 0) {
        focusSection = sections[sIdx - 1]
        var prevMax = sectionCount(focusSection) - 1
        selectedIndex = prevMax >= 0 ? prevMax : (sectionHasSlider(focusSection) ? -1 : 0)
      } else {
        focusSection = "header"
      }
    }
  }

  function setHeaderCursor() {
    cursorActive = true
    focusSection = "header"
    selectedIndex = -1
  }

  function adjustVolume(delta) {
    if (focusSection === "output" && selectedIndex === -1) {
      setOutputVolume(outputVolume + delta)
      return
    }
    if (focusSection === "input" && selectedIndex === -1) {
      setInputVolume(inputVolume + delta)
      return
    }
    if (focusSection === "streams" && selectedIndex >= 0 && selectedIndex < displayAudioStreams.length) {
      var s = nodeFor(displayAudioStreams[selectedIndex])
      if (s && s.audio) s.audio.volume = Math.max(0, Math.min(1.5, s.audio.volume + delta))
    }
  }

  function activateCursor() {
    if (focusSection === "header") { toggleAllMuted(); return }
    if (focusSection === "output") {
      if (selectedIndex === -1) { toggleOutputMute(); return }
      var sinkNode = nodeFor(displayAudioSinks[selectedIndex])
      if (sinkNode) setDefaultSink(sinkNode)
      return
    }
    if (focusSection === "input") {
      if (selectedIndex === -1) { toggleInputMute(); return }
      var src = nodeFor(displayAudioSources[selectedIndex])
      if (src) setDefaultSource(src)
      return
    }
    if (focusSection === "streams" && selectedIndex >= 0) {
      var st = nodeFor(displayAudioStreams[selectedIndex])
      if (st && st.audio) st.audio.muted = !st.audio.muted
    }
  }

  onAudioSinksChanged: scheduleDisplayAudioModelRefresh()
  onAudioSourcesChanged: scheduleDisplayAudioModelRefresh()
  onAudioStreamsChanged: scheduleDisplayAudioModelRefresh()

  Component.onCompleted: {
    refreshDisplayAudioModels()
    focusSection = "output"
    selectedIndex = -1
    cursorActive = false
    Qt.callLater(resetScroll)
  }

  function rowSnapshot(list) {
    return Model.rowSnapshot(list)
  }

  // A row that outlives its node resolves to null, or to a node PipeWire recreated
  // under the same id and name; every binding below guards for null, and a row
  // that never held the node cannot dangle.
  function nodeFor(row) {
    if (!row) return null
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && n.id === row.id && String(n.name || "") === row.name) return n
    }
    return null
  }

  function refreshDisplayAudioModels() {
    displayAudioSinks = rowSnapshot(audioSinks)
    displayAudioSources = rowSnapshot(audioSources)
    displayAudioStreams = rowSnapshot(audioStreams)
    clampCursor()
  }

  function scheduleDisplayAudioModelRefresh() {
    audioModelRefreshTimer.restart()
  }

  function resetScroll() {
    if (!scrollArea) return
    var flick = scrollArea.contentItem
    if (flick && flick.contentY !== undefined) flick.contentY = 0
  }

  function ensureCursorVisible(item) {
    if (!item || !scrollArea) return
    var flick = scrollArea.contentItem
    if (!flick || flick.contentY === undefined) return
    var margin = 6
    var maxY = Math.max(0, (flick.contentHeight || 0) - flick.height)
    if (maxY <= Style.space(24) || (root.focusSection === "output" && root.selectedIndex === -1)) {
      flick.contentY = 0
      return
    }
    var pt = item.mapToItem(flick.contentItem || flick, 0, 0)
    var top = pt.y
    var bottom = top + (item.height || 0)
    var viewTop = flick.contentY
    var viewBottom = viewTop + flick.height
    if (top < viewTop + margin) flick.contentY = Math.max(0, Math.min(maxY, top - margin))
    else if (bottom > viewBottom - margin)
      flick.contentY = Math.max(0, Math.min(maxY, bottom + margin - flick.height))
  }

  function clampCursor() {
    var sections = visibleSections
    if (!sections || !sections.length) return
    if (focusSection === "header") return
    if (sections.indexOf(focusSection) < 0) {
      focusSection = visibleSections[0]
      selectedIndex = sectionHasSlider(focusSection) ? -1 : 0
      return
    }
    var count = sectionCount(focusSection)
    var hasSlider = sectionHasSlider(focusSection)
    var floor = hasSlider ? -1 : 0
    if (selectedIndex > count - 1) selectedIndex = Math.max(floor, count - 1)
    if (selectedIndex < floor) selectedIndex = floor
  }

  function outputIcon(volume) {
    // Match the old Waybar pulseaudio glyph set. The Material Design speaker
    // icons render visually smaller in JetBrainsMono Nerd Font.
    if (!sink || !sink.audio) return "\u{eee8}"
    if (isHeadphones(sink)) return "\u{f02cb}"
    if (outputMuted) return "\u{eee8}"
    var v = volume === undefined ? outputVolume : volume
    if (v >= 0.67) return "\u{f028}"
    if (v >= 0.34) return "\u{f027}"
    if (v > 0) return "\u{f026}"
    return "\u{eee8}"
  }

  function inputIcon() {
    if (!hasInput) return "\u{f036d}"
    return inputMuted ? "\u{f036d}" : "\u{f036c}"
  }

  function outputVolumeName(volume, muted) {
    return Model.outputVolumeName(volume, muted, I18n.t)
  }

  function setOutputVolume(v) {
    if (!volumeSink || !volumeSink.audio) return outputVolume
    var volume = Math.max(0, Math.min(1, v))
    volumeSink.audio.volume = volume
    return volume
  }

  function showVolumeOsd(volume) {
    if (!bar || !bar.shell) return
    bar.shell.summon("osd", JSON.stringify({
      icon: outputIcon(volume),
      value: Math.round(volume * 100)
    }))
  }

  function setInputVolume(v) {
    if (inputViaWpctl) {
      UntypedInput.setVolume(v)
      return
    }
    if (!source || !source.audio) return
    source.audio.volume = Math.max(0, Math.min(1, v))
  }

  function toggleOutputMute() {
    if (volumeSink && volumeSink.audio) volumeSink.audio.muted = !volumeSink.audio.muted
  }

  function toggleInputMute() {
    if (inputViaWpctl) {
      if (UntypedInput.known) UntypedInput.setMuted(!UntypedInput.muted)
    }
    else if (source && source.audio) source.audio.muted = !source.audio.muted
  }

  // The hero switch is the whole panel's on/off, so it carries both channels
  // at once. It reads as on while anything is still audible, which keeps
  // muting a single channel from the row below flipping the master switch.
  function toggleAllMuted() {
    var mute = anyAudible
    if (hasOutput) volumeSink.audio.muted = mute
    if (hasInput && inputViaWpctl) UntypedInput.setMuted(mute)
    else if (hasInput) source.audio.muted = mute
  }

  // Native output/source switching: the Quickshell preferred-default write is
  // immediate, and wpctl persists it for the wireplumber session. This replaces
  // the default-output helper / the default-input helper.
  function runWpctl(args) {
    defaultProc.command = ["wpctl"].concat(args)
    defaultProc.running = true
  }

  function setDefaultSink(node) {
    if (!node) return
    Pipewire.preferredDefaultAudioSink = node
    if (node.id !== undefined && node.id !== null) runWpctl(["set-default", String(node.id)])
  }

  function setDefaultSource(node) {
    if (!node) return
    if (node.audio) Pipewire.preferredDefaultAudioSource = node
    if (node.id !== undefined && node.id !== null) runWpctl(["set-default", String(node.id)])
  }

  function friendlyDeviceLabel(text) {
    return Model.friendlyDeviceLabel(text)
  }

  function nodeLabel(node) {
    return Model.nodeLabel(node, I18n.t)
  }

  function isHeadphones(node) {
    return Model.isHeadphones(node)
  }

  function sinkGlyph(node) {
    return Model.sinkGlyph(node)
  }

  function sourceGlyph(node) {
    return Model.sourceGlyph(node)
  }

  function rawStreamLabel(node) {
    return Model.rawStreamLabel(node)
  }

  function streamRepresent(sNode, player) {
    return Model.streamRepresentsPlayer(sNode, player, mprisPlayers, audioStreams)
  }

  function streamLabel(node) {
    return Model.streamLabel(node, mprisPlayers, audioStreams, I18n.t)
  }

  // ----- Layout -----
  readonly property int padding: Style.spacing.popupPadding
  readonly property int maxContentHeight: Style.space(560)

  implicitWidth: Style.space(380)
  implicitHeight: Math.min(panelColumn.implicitHeight + padding * 2 + card.borderTop + card.borderBottom, maxContentHeight)

  PwObjectTracker { objects: root.candidateSinks }
  PwObjectTracker { objects: root.candidateSources }
  PwObjectTracker { objects: root.audioStreams }

  PwNodePeakMonitor {
    id: inputPeakMonitor
    node: root.inputPeakNode
    enabled: !!root.inputPeakNode
  }

  // Native default-device switching (wpctl set-default <id>).
  Process {
    id: defaultProc
    command: []
  }

  Timer {
    id: audioModelRefreshTimer
    interval: 75
    repeat: false
    onTriggered: root.refreshDisplayAudioModels()
  }

  BorderSurface {
    id: card
    anchors.fill: parent
    color: Commons.Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Math.max(1, Style.space(2)))
    radius: Style.cornerRadius
    padding: root.padding
  }

  PanelKeyCatcher {
    id: keyCatcher
    anchors.fill: parent
    anchors.margins: root.padding

    onMoveRequested: function(dx, dy) {
      if (!root.cursorActive) { root.cursorActive = true; return }
      if (dy !== 0) root.moveCursor(dy)
      else if (dx !== 0) root.adjustVolume(dx * 0.05)
    }
    onActivateRequested: if (root.cursorActive) root.activateCursor()
    onCloseRequested: OverlayPanels.close()
    onTextKey: function(t) {
      // 'm' mutes whatever the cursor is on: focused section's slider for
      // output/input, the focused stream for streams.
      if (t === "m" || t === "M") {
        if (!root.cursorActive) return
        if (root.focusSection === "streams" && root.selectedIndex >= 0
            && root.selectedIndex < root.displayAudioStreams.length) {
          var s = root.nodeFor(root.displayAudioStreams[root.selectedIndex])
          if (s && s.audio) s.audio.muted = !s.audio.muted
        } else if (root.focusSection === "input") {
          root.toggleInputMute()
        } else {
          root.toggleOutputMute()
        }
      }
    }

    ScrollView {
      id: scrollArea
      anchors.fill: parent
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
      Binding {
        target: scrollArea.contentItem
        property: "interactive"
        value: panelColumn.implicitHeight > scrollArea.height
      }

      Column {
        id: panelColumn
        width: scrollArea.availableWidth
        spacing: Style.space(14)

        // ---------- Hero: speaker icon · title/status ----------
        Item {
          id: heroItem
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, powerSwitch.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.outputIcon()
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            opacity: root.outputMuted ? 0.5 : 1.0
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          ToggleSwitch {
            id: powerSwitch
            checked: root.anyAudible
            hasCursor: root.headerHasCursor
            foreground: root.foreground
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            onHovered: function(on) { if (on) root.setHeaderCursor() }
            onToggled: root.toggleAllMuted()

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
            anchors.rightMargin: powerSwitch.width + Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: I18n.t("audio.title")
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              id: heroLabel
              textFormat: Text.PlainText
              text: root.outputVolumeName(
                outputSlider.dragging ? outputSlider.liveValue : root.outputVolume,
                root.outputMuted
              ).toUpperCase()
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

        // ---- Output devices ----
        PanelSeparator {
          foreground: root.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(6)

          Item {
            width: parent.width
            implicitHeight: Math.max(outputHeader.implicitHeight, outputPercent.implicitHeight)

            PanelSectionHeader {
              id: outputHeader
              text: I18n.t("audio.output")
              foreground: root.foreground
              fontFamily: root.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: outputPercent
              textFormat: Text.PlainText
              text: I18n.formatNumber(Math.round((outputSlider.dragging ? outputSlider.liveValue : root.outputVolume) * 100)) + "%"
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              opacity: root.outputMuted ? 0.5 : 1.0
            }
          }

          CursorSurface {
            id: outputSliderRow
            width: parent.width
            height: outputSlider.implicitHeight + Style.spacing.controlGap
            hasCursor: root.cursorActive && root.focusSection === "output" && root.selectedIndex === -1
            onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(outputSliderRow)
            foreground: root.foreground
            outline: true

            PanelSlider {
              id: outputSlider
              bar: root.bar
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              minimum: 0
              maximum: 1
              step: 0.05
              value: root.outputVolume
              opacity: root.outputMuted ? 0.5 : 1.0
              enabled: !!root.sink

              onMoved: function(v) { root.setOutputVolume(v) }
              onRightClicked: root.toggleOutputMute()
            }

            HoverHandler {
              onHoveredChanged: if (hovered) {
                root.cursorActive = true
                root.focusSection = "output"
                root.selectedIndex = -1
              }
            }
          }

          Repeater {
            model: root.displayAudioSinks

            SinkRow {
              required property var modelData
              required property int index
              width: panelColumn.width
              node: root.nodeFor(modelData)
              rowIndex: index
            }
          }
        }

        // ---- Input ----
        PanelSeparator {
          visible: root.displayAudioSources.length > 0 || !!root.source
          foreground: root.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: root.displayAudioSources.length > 0 || !!root.source

          Item {
            width: parent.width
            implicitHeight: Math.max(microphoneHeader.implicitHeight, microphonePercent.implicitHeight)

            PanelSectionHeader {
              id: microphoneHeader
              text: I18n.t("audio.input")
              foreground: root.foreground
              fontFamily: root.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: microphonePercent
              textFormat: Text.PlainText
              text: root.inputLevelKnown ? I18n.formatNumber(Math.round((inputSlider.dragging ? inputSlider.liveValue : root.inputVolume) * 100)) + "%" : "\u2013"
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              opacity: root.inputMuted ? 0.5 : 1.0
            }
          }

          CursorSurface {
            id: inputSliderRow
            visible: !!root.source
            width: parent.width
            height: inputControls.implicitHeight + Style.spacing.controlGap
            hasCursor: root.cursorActive && root.focusSection === "input" && root.selectedIndex === -1
            onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(inputSliderRow)
            foreground: root.foreground
            outline: true

            Column {
              id: inputControls
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              anchors.topMargin: root.inputLevelShown ? 0 : Style.spacing.controlGap / 2
              spacing: Style.space(5)

              PanelSlider {
                id: inputSlider
                bar: root.bar
                width: parent.width
                minimum: 0
                maximum: 1
                step: 0.05
                value: root.inputVolume
                opacity: root.inputMuted ? 0.5 : 1.0
                enabled: !!root.source

                onMoved: function(v) { root.setInputVolume(v) }
                onRightClicked: root.toggleInputMute()
              }

              Rectangle {
                visible: root.inputLevelShown
                width: parent.width
                height: Math.max(Style.space(5), Style.spacing.xs)
                color: Util.alpha(root.foreground, 0.18)
                opacity: root.inputMuted ? 0.35 : 1.0

                Rectangle {
                  height: parent.height
                  width: parent.width * Math.max(0, Math.min(1, inputPeakMonitor.peak))
                  color: root.foreground
                  Behavior on width { NumberAnimation { duration: Style.duration(70) } }
                }
              }
            }

            HoverHandler {
              onHoveredChanged: if (hovered) {
                root.cursorActive = true
                root.focusSection = "input"
                root.selectedIndex = -1
              }
            }
          }

          Repeater {
            model: root.displayAudioSources

            SourceRow {
              required property var modelData
              required property int index
              width: panelColumn.width
              node: root.nodeFor(modelData)
              rowIndex: index
            }
          }
        }

        // ---- Per-app streams ----
        PanelSeparator {
          visible: root.displayAudioStreams.length > 0
          foreground: root.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(10)
          visible: root.displayAudioStreams.length > 0

          PanelSectionHeader {
            text: I18n.t("audio.sources")
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Repeater {
            model: root.displayAudioStreams

            StreamRow {
              required property var modelData
              required property int index
              width: panelColumn.width
              node: root.nodeFor(modelData)
              rowIndex: index
            }
          }
        }
      }
    }
  }

  // ---- Reusable inline components ----

  component SinkRow: CursorSurface {
    id: sinkRow
    required property var node
    required property int rowIndex

    readonly property bool isActive: root.sink && node && root.sink.id === node.id
    hasCursor: root.cursorActive && root.focusSection === "output" && root.selectedIndex === rowIndex
    onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(sinkRow)
    current: isActive
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: sinkInner.implicitHeight + Style.spacing.xl

    Row {
      id: sinkInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: root.sinkGlyph(sinkRow.node)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: root.nodeLabel(sinkRow.node)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: sinkRow.isActive
        elide: Text.ElideRight
        width: parent.width - Style.space(22) - Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.focusSection = "output"
        root.selectedIndex = sinkRow.rowIndex
      }
      onClicked: root.setDefaultSink(sinkRow.node)
    }
  }

  component SourceRow: CursorSurface {
    id: sourceRow
    required property var node
    required property int rowIndex

    readonly property bool isActive: root.source && node && root.source.id === node.id
    hasCursor: root.cursorActive && root.focusSection === "input" && root.selectedIndex === rowIndex
    onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(sourceRow)
    current: isActive
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: sourceInner.implicitHeight + Style.spacing.xl

    Row {
      id: sourceInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: root.sourceGlyph(sourceRow.node)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: root.nodeLabel(sourceRow.node)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: sourceRow.isActive
        elide: Text.ElideRight
        width: parent.width - Style.space(22) - Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.focusSection = "input"
        root.selectedIndex = sourceRow.rowIndex
      }
      onClicked: root.setDefaultSource(sourceRow.node)
    }
  }

  component StreamRow: CursorSurface {
    id: streamRow
    required property var node
    required property int rowIndex

    readonly property real streamVolume: node && node.audio ? node.audio.volume : 0
    readonly property bool streamMuted: node && node.audio ? node.audio.muted : false
    readonly property bool isActive: root.streamRepresent(node, root.activeMediaPlayer)

    hasCursor: root.cursorActive && root.focusSection === "streams" && root.selectedIndex === rowIndex
    onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(streamRow)
    current: isActive
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: streamColumn.implicitHeight + Style.spacing.xl

    Column {
      id: streamColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(2)

      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          id: streamMuteIcon
          textFormat: Text.PlainText
          text: streamRow.streamMuted ? "\u{f075f}" : "\u{f057e}"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          width: Style.space(22)
          horizontalAlignment: Text.AlignHCenter
          anchors.verticalCenter: parent.verticalCenter
          opacity: streamRow.streamMuted ? 0.5 : 1.0

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (streamRow.node && streamRow.node.audio)
                streamRow.node.audio.muted = !streamRow.node.audio.muted
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          text: root.streamLabel(streamRow.node)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: streamRow.isActive
          elide: Text.ElideRight
          width: parent.width - streamMuteIcon.width - streamPct.width - Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          id: streamPct
          textFormat: Text.PlainText
          text: I18n.formatNumber(Math.round(streamRow.streamVolume * 100)) + "%"
          color: Qt.darker(root.foreground, 1.5)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          width: Style.space(36)
          horizontalAlignment: Text.AlignRight
          anchors.verticalCenter: parent.verticalCenter
          opacity: streamRow.streamMuted ? 0.5 : 1.0
        }
      }

      PanelSlider {
        bar: root.bar
        width: parent.width
        minimum: 0
        maximum: 1.5
        step: 0.05
        value: streamRow.streamVolume
        opacity: streamRow.streamMuted ? 0.5 : 1.0

        onMoved: function(v) {
          if (streamRow.node && streamRow.node.audio) streamRow.node.audio.volume = v
        }
        onRightClicked: {
          if (streamRow.node && streamRow.node.audio)
            streamRow.node.audio.muted = !streamRow.node.audio.muted
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
      propagateComposedEvents: true
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.focusSection = "streams"
        root.selectedIndex = streamRow.rowIndex
      }
    }
  }
}
