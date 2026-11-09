import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "."
import qs.Ui
import qs.Commons
import qs.Commons as Commons

// mystaryo.media — cava spectrum in the bar. Click: Now Playing + cliamp tabs.
// Design rules: MPRIS + audio-tap data only; every external boundary
// degrades to static/empty; no absolute paths, theme colors only.
BarWidget {
  id: root
  moduleName: "mystaryo.media"

  // ---- MPRIS players directly (no media service dependency) ----
  // Plain bar-widgets get null proxies, so we track Mpris.players ourselves.
  readonly property var allPlayers: Mpris.players ? Mpris.players.values : []
  // Now Playing source ("auto" = active player), stored as normalized dbus
  // suffix; cliamp never a source — it has its own tab.
  property string musicPlayerPref: "auto"
  // Set true for journal debugging (command calls, focus changes, search).
  // Default off: the widget is chatty otherwise (settings IO, cliamp IPC).
  property bool debug: false
  function dbg(msg) { try { if (root.debug) console.log("mystaryo.media: " + msg) } catch (e) {} }
  function normPlayerId(player) {
    try {
      return String(player.dbusName || "")
        .replace(/^org\.mpris\.MediaPlayer2\./, "")
        .replace(/\.instance[0-9]+$/, "")
        .toLowerCase()
    } catch (e) { return "" }
  }
  function playerMatchesPref(player) {
    var pref = String(root.musicPlayerPref || "auto").toLowerCase()
    if (pref === "" || pref === "auto") return false
    var id = normPlayerId(player)
    if (id === pref) return true
    try {
      var label = String(player.identity || player.desktopEntry || "").toLowerCase()
      if (label !== "" && (label === pref || id.indexOf(pref) !== -1 || pref.indexOf(id) !== -1)) return true
    } catch (e) {}
    return false
  }
  function setMusicPlayer(id) {
    var v = String(id || "auto").toLowerCase()
    if (v === "") v = "auto"
    if (root.musicPlayerPref === v) return
    root.musicPlayerPref = v
    saveMusicPlayer()
  }
  // Every live non-cliamp player, regardless of pref — the Settings
  // picker model (sourcePlayers above is pref-filtered instead).
  readonly property var liveAppPlayers: {
    var pool = []
    for (var i = 0; i < allPlayers.length; i++) {
      try { if (!isCliamp(allPlayers[i])) pool.push(allPlayers[i]) } catch (e) {}
    }
    return pool
  }
  readonly property var musicPlayerOptions: {
    var options = [{ id: "auto", label: "Auto (active player)" }]
    var seen = { auto: true }
    for (var i = 0; i < liveAppPlayers.length; i++) {
      var player = liveAppPlayers[i]
      var id = normPlayerId(player)
      if (id !== "" && !seen[id]) {
        seen[id] = true
        options.push({ id: id, label: shortLabel(player) })
      }
    }
    var pref = String(root.musicPlayerPref || "auto").toLowerCase()
    if (pref !== "auto" && !seen[pref]) options.push({ id: pref, label: pref + " (offline)" })
    return options
  }
  // Now Playing list: active player under Auto; locked app when present,
  // else Auto fallback so the tab never goes empty.
  readonly property var sourcePlayers: {
    var pool = []
    for (var i = 0; i < allPlayers.length; i++) {
      try { if (!isCliamp(allPlayers[i])) pool.push(allPlayers[i]) } catch (e) {}
    }
    if (pool.length === 0) return []
    var pref = String(root.musicPlayerPref || "auto").toLowerCase()
    if (pref !== "" && pref !== "auto") {
      var list = []
      for (var j = 0; j < pool.length; j++) {
        try { if (playerMatchesPref(pool[j])) list.push(pool[j]) } catch (e2) {}
      }
      if (list.length > 0) return list
    }
    var titled = null
    for (var k = 0; k < pool.length; k++) {
      try {
        if (pool[k].isPlaying) return [pool[k]]
        if (!titled && pool[k].trackTitle) titled = pool[k]
      } catch (e3) {}
    }
    if (titled) return [titled]
    return [pool[0]]
  }
  property int tabIndex: 0 // 0 = now playing, 1 = cliamp, 2 = settings
  property bool popupOpen: false
  onPopupOpenChanged: {
    if (!root.popupOpen) {
      try {
        if (root.bar && stripButton.tooltipHovered)
          root.bar.showTooltip(stripButton, stripButton.tooltipText)
      } catch (e) {}
    }
  }

  // Blinking search cursor: driven by a timer, not by focus state, so it is
  // visible whenever the cliamp tab is open (focus inside grab popups is
  // unreliable — same reason the field is key-captured, not a TextInput).
  property bool cursorOn: true
  Timer {
    id: cursorTimer
    interval: 530
    repeat: true
    running: root.popupOpen && root.tabIndex === 1
    onTriggered: root.cursorOn = !root.cursorOn
  }
  Timer {
    id: focusTimer
    interval: 250
    repeat: true
    running: root.popupOpen && root.tabIndex === 1
    property bool lastFocus: false
    onTriggered: {
      try {
        if (keyCatcher.activeFocus !== lastFocus) {
          lastFocus = keyCatcher.activeFocus
          root.dbg("catcher focus -> " + lastFocus)
        }
        if (!keyCatcher.activeFocus) keyCatcher.forceActiveFocus()
      } catch (e) {}
    }
  }

  // Called by the popup scrim's outside-click dismissal and Esc handling.
  // Without it the scrim severs our `open:` binding on first dismiss and
  // the popup never reopens.
  function close() { popupOpen = false }

  function shortLabel(player) {
    if (!player) return ""
    var dbus = String(player.dbusName || "").replace(/^org\.mpris\.MediaPlayer2\./, "").replace(/\.instance[0-9]+$/, "")
    return player.desktopEntry || player.identity || dbus || "player"
  }
  function isCliamp(player) {
    if (!player) return false
    return String(player.dbusName || "").indexOf("cliamp") !== -1
  }
  readonly property var selectedPlayer: sourcePlayers.length > 0 ? sourcePlayers[0] : null
  // Live title/artist with last-known fallback (persisted: survives reboot).
  readonly property string nowTitle: root.selectedPlayer ? (root.selectedPlayer.trackTitle || "") : ""
  readonly property string nowArtist: root.selectedPlayer ? (root.selectedPlayer.trackArtist || "") : ""
  // Live app playing flag. Rising edge = app started -> cliamp yields.
  // Falling edges never act, so mutual pauses cannot loop.
  readonly property bool appPlaying: root.selectedPlayer ? !!root.selectedPlayer.isPlaying : false
  onAppPlayingChanged: {
    if (root.appPlaying && root.cliampPlaying()) {
      pauseCliamp()
      root.lastSource = "app"
      saveSettings()
    }
  }
  property string lastTitle: ""
  property string lastArtist: ""
  // Which side played last ("app" | "cliamp") — idle strip shows its text.
  property string lastSource: "app"
  // ---- strip display source: whichever side plays wins; idle shows
  // the side that played last, dimmed. Mirrors the mutual-pause rule,
  // so display and playback can never disagree.
  function stripIsCliamp() {
    try { return root.cliampPlaying() } catch (e) { return false }
  }
  function stripPlaying() {
    // Bright iff something is actually playing (either side).
    try {
      if (stripIsCliamp()) return true
      return !!(root.selectedPlayer && root.selectedPlayer.isPlaying)
    } catch (e) { return false }
  }
  function appText(live) {
    var t = live ? root.nowTitle : root.lastTitle
    var a = live ? root.nowArtist : root.lastArtist
    if (t === "") return ""
    return t + (a !== "" ? " — " + a : "")
  }
  function stripText() {
    try {
      if (stripIsCliamp()) {
        if (root.cliampTrack !== "") return root.cliampTrack
        return "Radio " + (root.cliampState !== "" ? root.cliampState : "…")
      }
      if (root.appPlaying) return appText(true)
      // Idle: the side that played last wins, dimmed — stale titles on
      // the other side never steal the strip.
      if (root.lastSource === "cliamp" && root.cliampTrack !== "") return root.cliampTrack
      var at = appText(false)
      if (at !== "") return at
      if (root.cliampTrack !== "") return root.cliampTrack
      return "Nothing playing"
    } catch (e) { return "Nothing playing" }
  }
  onNowTitleChanged: {
    if (root.nowTitle !== "") {
      root.lastTitle = root.nowTitle
      root.lastArtist = root.nowArtist
      saveSettings()
    }
  }
  // Bar display mode: spectrum visual vs now-playing track row.
  property string barMode: "visual"
  function barModeValid(id) { return id === "visual" || id === "track" }
  function setBarMode(id) {
    if (!barModeValid(id) || root.barMode === id) return
    root.barMode = id
    saveSettings()
  }
  Component.onCompleted: { loadSettings() }

  // ---- transport on an explicit player (capability-gated, never throws) ----
  function canToggle(p) { try { return !!(p && (p.canTogglePlaying || p.canPlay || p.canPause)) } catch (e) { return false } }
  function canStep(p, dir) { try { return !!(p && ((dir < 0 && p.canGoPrevious) || (dir > 0 && p.canGoNext))) } catch (e) { return false } }
  function togglePlayer(p) {
    if (!p) return
    // Starting music pauses cliamp and owns the strip (mutual exclusion).
    try {
      if (p && !root.isCliamp(p) && !p.isPlaying) {
        pauseCliamp()
        root.lastSource = "app"
        saveSettings()
      }
    } catch (e) {}
    try {
      if (p.isPlaying) { if (p.canPause) p.pause(); else if (p.canTogglePlaying) p.togglePlaying() }
      else { if (p.canPlay) p.play(); else if (p.canTogglePlaying) p.togglePlaying() }
    } catch (e) {}
  }
  function pausePlayer(p) {
    // Pause whenever capable — no isPlaying guard: MPRIS status lags
    // reality and the guard skipped real pauses. Pausing a paused
    // player is a harmless no-op.
    if (!p) return
    try {
      if (p.canPause) { p.pause(); root.dbg("paused " + shortLabel(p)) }
      else if (p.canTogglePlaying && p.isPlaying) { p.togglePlaying(); root.dbg("toggled " + shortLabel(p)) }
      else root.dbg("unpausable " + shortLabel(p))
    } catch (e) { root.dbg("pause failed") }
  }
  function pauseCliamp() {
    // Pause whatever cliamp is doing: its MPRIS player first, else daemon
    // IPC pause with stop fallback (unknown op = safe no-op). Never throws.
    try {
      var p = cliampPlayer()
      if (p) { pausePlayer(p); return }
    } catch (e) {}
    if (root.cliampPlaying()) cliampCall("runtime.pause", {}, function(res) {
      if (res === null) cliampCall("runtime.stop", {}, function() { refreshCliampTab() })
      else refreshCliampTab()
    })
  }
  function pauseSelectedForCliamp() {
    // cliamp is starting: pause the Now Playing app (never cliamp itself).
    try {
      var p = root.selectedPlayer
      if (p && !root.isCliamp(p)) pausePlayer(p)
    } catch (e) {}
  }
  function stopPlayer(p) {
    if (!p) return
    if (root.isCliamp(p)) cliampCall("runtime.stop", {}, function() { refreshCliampTab() })
    var stopped = false
    try { if (typeof p.stop === "function") { p.stop(); stopped = true } } catch (e) {}
    if (!stopped) { try { if (p.canPause) p.pause(); else if (p.canTogglePlaying) p.togglePlaying() } catch (e2) {} }
  }
  function stepPlayer(p, dir) {
    if (!p) return
    try {
      if (dir < 0 && p.canGoPrevious) p.previous()
      else if (dir > 0 && p.canGoNext) p.next()
    } catch (e) {}
  }
  function cliampPlayer() {
    for (var i = 0; i < sourcePlayers.length; i++) {
      try { if (isCliamp(sourcePlayers[i])) return sourcePlayers[i] } catch (e) {}
    }
    return null
  }
  function cliampPlaying() {
    var p = cliampPlayer()
    try { if (p) return !!p.isPlaying } catch (e) {}
    return root.cliampState === "playing"
  }
  function cliampRadioActive() {
    return root.cliampUp && root.cliampState !== "stopped"
  }
  function toggleCliamp() {
    var p = cliampPlayer()
    if (p && root.canToggle(p)) {
      // Known play transition only: pausing cliamp needs no cross-action.
      try {
        if (!p.isPlaying) {
          pauseSelectedForCliamp()
          root.lastSource = "cliamp"
          saveSettings()
        }
      } catch (e) {}
      root.togglePlayer(p)
      return
    }
    // No MPRIS player (yet): direction unknown, so no cross-action here —
    // explicit starts below still pause the app. Toggle headless via IPC.
    cliampCall("runtime.toggle", {}, function() { refreshCliampTab() })
  }

  // ---- shared key handling: keys handled in BOTH windows (focus may sit
  // on bar or popup); only the focused catcher's handler fires.
  function handleKey(event) {
    if (event.key === Qt.Key_Escape) {
      root.close()
      event.accepted = true
      return
    }
    if (root.tabIndex !== 1 || !root.popupOpen) return
    if (event.key === Qt.Key_Backspace) {
      root.searchQuery = root.searchQuery.slice(0, -1)
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.runSearch()
      event.accepted = true
    } else if (event.text !== "") {
      root.searchQuery += event.text
      event.accepted = true
    }
  }

  // Bar-side catcher: covers the case where keyboard focus stays on the bar
  // window (e.g. transiently while the popup opens). Shares handleKey.
  Item {
    id: barCatcher
    width: 0
    height: 0
    focus: popupPanel.visible
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) { root.handleKey(event) }
  }

  // Screen hosting the bar (popup shows there; falls back to all screens).
  readonly property var barScreen: {
    try { return root.QsWindow.window.screen } catch (e) { return null }
  }
  readonly property string cavaScope: root.barScreen ? String(root.barScreen.name).replace(/[^A-Za-z0-9]/g, "_") : "0"
  // Card anchor: widget center-x / bottom-y in screen coords, captured on open.
  property real cardX: -1
  property real cardY: -1

  // ---- cava spectrum pipe ----
  readonly property int barCount: 12
  readonly property int barMax: 7
  readonly property var fpsOptions: [10, 15, 20, 30, 60]
  property int visualFps: 30
  property var barValues: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  property bool cavaDead: false
  property int cavaRestarts: 0
  property bool cavaRestartRequested: false

  readonly property string cavaConf: {
    var u = Qt.resolvedUrl("cava.conf").toString()
    if (u.indexOf("file://") === 0) u = u.substring(7)
    try { return decodeURIComponent(u) } catch (e) { return u }
  }
  function parseFrame(line) {
    // Cava emits the full FFT; downsample each group to the display bars.
    try {
      var parts = String(line).split(";")
      var count = 0
      for (var i = 0; i < parts.length; i++) {
        if (parts[i] !== "") count++
      }
      if (count < root.barCount) return
      var per = Math.floor(count / root.barCount)
      var out = []
      var pos = 0
      for (var b = 0; b < root.barCount; b++) {
        var m = 0
        for (var k = 0; k < per; k++) {
          while (pos < parts.length && parts[pos] === "") pos++
          var v = parseInt(parts[pos++], 10)
          if (isNaN(v) || v < 0) v = 0
          if (v > m) m = v
        }
        out.push(m > root.barMax ? root.barMax : m)
      }
      root.barValues = out
    } catch (e) { /* keep previous frame, never crash on junk */ }
  }
  // Use a private runtime FIFO and clean up only the recorder started here.
  Process {
    id: cavaProc
    command: ["sh", "-c", "R=${XDG_RUNTIME_DIR:-}; [ -n \"$R\" ] || exit 1; D=\"$R/mystaryo-media-" + root.cavaScope + "\"; umask 077; mkdir -p \"$D\" || exit 1; [ ! -L \"$D\" ] && [ -d \"$D\" ] || exit 1; chmod 700 \"$D\" || exit 1; [ \"$(stat -c %u \"$D\")\" = \"$(id -u)\" ] || exit 1; F=\"$D/cava.fifo\"; if [ -e \"$F\" ]; then [ ! -L \"$F\" ] && [ -p \"$F\" ] || exit 1; [ \"$(stat -c %u \"$F\")\" = \"$(id -u)\" ] || exit 1; chmod 600 \"$F\" || exit 1; else mkfifo -m 600 \"$F\" || exit 1; fi; M=$(pactl get-default-sink).monitor || exit 1; parecord --device=\"$M\" --format=s16le --rate=48000 --channels=2 --latency-msec=50 --process-time-msec=20 --raw \"$F\" & REC=$!; trap \"kill $REC 2>/dev/null; rm -f \\\"$F\\\"\" EXIT; sed -e 's/^framerate = .*/framerate = " + root.visualFps + "/' -e \"s|^source = .*|source = $F|\" \"" + root.cavaConf + "\" | cava -p /dev/stdin"]
    running: !root.cavaDead
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) { root.parseFrame(data) }
    }
    stderr: StdioCollector { waitForEnd: false }
    onExited: {
      if (root.cavaRestartRequested) {
        root.cavaRestartRequested = false
        root.cavaRestarts = 0
        restartTimer.restart()
        return
      }
      // Supervisor: restart with backoff, give up after 5 tries (flat bars).
      if (root.cavaRestarts >= 5) { root.cavaDead = true; return }
      root.cavaRestarts++
      restartTimer.start()
    }
  }
  Timer {
    id: restartTimer
    interval: 2000
    repeat: false
    onTriggered: if (!root.cavaDead) cavaProc.running = true
  }

  // ---- one-shot + async cliamp IPC helpers ----
  Component {
    id: procFactory
    Process {
      property var callback: null
      property string stdinText: ""
      stdout: StdioCollector { id: out; waitForEnd: true }
      stdinEnabled: stdinText !== ""
      onStarted: {
        if (stdinText !== "") {
          write(stdinText)
          stdinEnabled = false
        }
      }
      onExited: function(exitCode, exitStatus) {
        var cb = callback
        var txt = out.text
        callback = null
        if (cb) cb(txt, exitCode)
        destroy()
      }
    }
  }
  function runCmd(args, cb, stdinText) {
    try {
      root.dbg("runCmd " + args.slice(0, 4).join(" "))
      var p = procFactory.createObject(root, {
        command: args,
        callback: cb,
        stdinText: stdinText || ""
      })
      p.running = true
    } catch (e) { root.dbg("runCmd create failed"); if (cb) cb("", 1) }
  }
  Timer {
    id: later
    interval: 400
    repeat: false
    property var fn: null
    onTriggered: { var f = fn; fn = null; if (f) f() }
  }
  function defer(fn) { later.fn = fn; later.restart() }
  // Single round-trip: --wait blocks until the job finishes, so the
  // result (or null on any failure) comes back in one callback.
  // searchBusy guards against overlapping searches; lastError surfaces the
  // raw daemon reply when it isn't parseable (shown in the note line).
  property bool searchBusy: false
  property string lastError: ""
  function cliampCall(op, params, onDone) {
    var args = ["cliamp", "remote", "call", op, "--params", JSON.stringify(params || {}), "--wait"]
    runCmd(args, function(out) {
      var res = null
      try {
        var j = JSON.parse(out)
        if (j && j.job && j.job.state === "succeeded") res = j.job.result
        else root.lastError = String(out).substring(0, 120)
      } catch (e) {
        root.lastError = String(out).substring(0, 120)
      }
      onDone(res)
    })
  }

  // ---- cliamp tab state ----
  property bool cliampUp: false
  property bool radioStopped: false
  property string cliampState: ""
  property string cliampTrack: ""
  property var cliampStation: ({ label: "", path: "" })
  // Edge memory for the exclusion watch: first snapshot only records.
  property bool prevCliampPlaying: false
  property bool cliampKnown: false
  property var searchRows: []
  property string cliampNote: ""
  property string searchQuery: ""
  property string radioView: "all"
  property var playCounts: ({}) // normalized station key -> play count (history)
  property var favoriteStations: []
  property var recentStations: []

  // "Radio Mirchi Hindi [128k] · India" -> "radio mirchi hindi"
  function normKey(s) {
    try {
      var k = String(s || "").toLowerCase()
      var i = k.indexOf(" [")
      if (i !== -1) k = k.substring(0, i)
      var j = k.indexOf(" ·")
      if (j !== -1) k = k.substring(0, j)
      return k.trim()
    } catch (e) { return "" }
  }
  function loadPlayCounts() {
    cliampCall("runtime.history", { limit: 100 }, function(res) {
      var counts = {}
      var recent = []
      var seen = {}
      try {
        var h = (res && res.history) || []
        for (var i = 0; i < h.length; i++) {
          var t = (h[i] && h[i].track) || {}
          var label = String(t.station || t.title || t.name || "")
          var path = String(t.path || t.url || t.stream || "")
          var k = normKey(label)
          if (k !== "") counts[k] = (counts[k] || 0) + 1
          if (label !== "" && path !== "" && !seen[k]) {
            seen[k] = true
            recent.push({ label: label, path: path })
          }
        }
      } catch (e) {}
      root.playCounts = counts
      root.recentStations = recent.slice(0, 30)
    })
  }
  function isFavorite(station) {
    var key = normKey(station && station.label)
    for (var i = 0; i < favoriteStations.length; i++)
      if (normKey(favoriteStations[i].label) === key) return true
    return false
  }
  function toggleFavorite(station) {
    if (!station || !station.label || !station.path) return
    var next = []
    var key = normKey(station.label)
    var removed = false
    for (var i = 0; i < favoriteStations.length; i++) {
      if (normKey(favoriteStations[i].label) === key) {
        removed = true
        continue
      }
      next.push(favoriteStations[i])
    }
    if (!removed) next.push({ label: String(station.label), path: String(station.path) })
    favoriteStations = next.slice(-30)
    saveSettings()
  }
  function stationFromSearchRow(row) {
    var ref = row && row.ref ? row.ref : {}
    return { label: String(row && row.label || ""), path: String(ref.path || ref.url || ref.stream || "") }
  }

  // Fixed curated top-12 with direct stream URLs (from
  // https://radio.cliamp.stream/streams.m3u). Played via track.play with the
  // same {title,path,stream,realtime} shape the daemon accepts — no search
  // round-trip, so entries can never "not be found".
  readonly property var topStations: [
    { label: "Lofi Stream", path: "https://radio.cliamp.stream/lofi/stream" },
    { label: "Synthwave Stream", path: "https://radio.cliamp.stream/synthwave/stream" },
    { label: "EDM Stream", path: "https://radio.cliamp.stream/edm/stream" },
    { label: "NCS Stream", path: "https://radio.cliamp.stream/ncs/stream" },
    { label: "NCS House Stream", path: "https://radio.cliamp.stream/ncs-house/stream" },
    { label: "NCS Dubstep Stream", path: "https://radio.cliamp.stream/ncs-dubstep/stream" },
    { label: "NCS Drum & Bass Stream", path: "https://radio.cliamp.stream/ncs-dnb/stream" },
    { label: "NCS Trap Stream", path: "https://radio.cliamp.stream/ncs-trap/stream" },
    { label: "NCS Phonk Stream", path: "https://radio.cliamp.stream/ncs-phonk/stream" },
    { label: "NCS Pop Stream", path: "https://radio.cliamp.stream/ncs-pop/stream" },
    { label: "NCS Chill Stream", path: "https://radio.cliamp.stream/ncs-chill/stream" }
  ]

  function noteCliampSnapshot(snap) {
    if (!snap) {
      root.cliampUp = false
      if (!root.radioStopped) root.cliampState = ""
      root.cliampTrack = ""
      root.cliampStation = ({ label: "", path: "" })
      root.prevCliampPlaying = false
      return
    }
    root.cliampUp = true
    root.cliampState = String(snap.state || "")
    root.radioStopped = root.cliampState === "stopped"
    try {
      var lt = snap.logical_track || {}
      var label = String(lt.title || lt.station || lt.path || "")
      var path = String(lt.path || lt.url || lt.stream || "")
      root.cliampTrack = label
      root.cliampStation = { label: label, path: path }
    } catch (e) { root.cliampTrack = "" }
    // Rising edge only: cliamp started -> app yields + owns the strip.
    // First snapshot only records, so a pre-playing daemon never
    // ambushes playback on widget load. Falling edges never act.
    var nowPlaying = (root.cliampState === "playing")
    if (root.cliampKnown) {
      if (nowPlaying && !root.prevCliampPlaying) {
        if (root.appPlaying) pauseSelectedForCliamp()
        root.lastSource = "cliamp"
        saveSettings()
      }
    } else {
      root.cliampKnown = true
    }
    root.prevCliampPlaying = nowPlaying
  }
  function refreshCliampTab(skipCounts) {
    if (!skipCounts) loadPlayCounts()
    runCmd(["cliamp", "remote", "state"], function(out) {
      var snap = null
      try {
        var j = JSON.parse(out)
        if (j && j.ok) snap = j.snapshot
      } catch (e) {}
      noteCliampSnapshot(snap)
    })
  }
  // Exclusion watch: light state poll so external cliamp starts
  // (terminal, TUI) also yield the app. Rising edges only — loop-free.
  Timer {
    id: exclusionPoll
    interval: 3000
    repeat: true
    running: true
    onTriggered: refreshCliampTab(true)
  }
  function normRows(res) {
    // Normalize the various result shapes into [{label, ref}] defensively.
    var rows = []
    try {
      var list = null
      if (!res) return rows
      if (Array.isArray(res)) list = res
      else if (Array.isArray(res.playlists)) list = res.playlists
      else if (Array.isArray(res.tracks)) list = res.tracks
      else if (Array.isArray(res.items)) list = res.items
      else if (Array.isArray(res.results)) list = res.results
      if (!list) return rows
      for (var i = 0; i < list.length; i++) {
        var it = list[i] || {}
        var label = String(it.name || it.title || it.path || it.id || "")
        if (!label) continue
        rows.push({ label: label, ref: it })
      }
    } catch (e) {}
    return rows.slice(0, 30)
  }
  function playStation(station) {
    var label = ""
    var path = ""
    try { label = String(station.label || ""); path = String(station.path || "") } catch (e) {}
    if (path === "") { root.cliampNote = "Couldn't start that entry."; return }
    pauseSelectedForCliamp()
    root.lastSource = "cliamp"
    saveSettings()
    root.cliampNote = "Loading " + label + "…"
    cliampCall("track.play", { track: { title: label, path: path, stream: true, realtime: true } }, function(res) {
      if (res === null) {
        root.cliampNote = "Couldn't start " + label + "."
        return
      }
      root.cliampNote = ""
      refreshCliampTab()
    })
  }
  function runSearch() {
    var q = root.searchQuery.trim()
    root.dbg("runSearch q=" + q + " busy=" + root.searchBusy)
    if (q === "" || root.searchBusy) return
    root.searchBusy = true
    root.searchRows = []
    root.cliampNote = "Searching…"
    cliampCall("provider.search", { provider: "radio", query: q, offset: 0, limit: 50 }, function(res) {
      root.dbg("search callback res=" + (res === null ? "null" : "ok"))
      root.searchBusy = false
      if (res === null) {
        root.cliampNote = "Search failed." + (root.lastError !== "" ? " (" + root.lastError + ")" : "")
        return
      }
      // Most-listened first (by history frequency), server order kept on ties.
      var rows = normRows(res)
      try {
        rows.sort(function(a, b) {
          var ca = root.playCounts[root.normKey(a.label)] || 0
          var cb = root.playCounts[root.normKey(b.label)] || 0
          return cb - ca
        })
      } catch (e) {}
      root.searchRows = rows
      root.cliampNote = rows.length === 0 ? ("No results for '" + q + "'.") : (rows.length + (rows.length === 1 ? " result." : " results."))
    })
  }
  function playSearchRow(row) {
    var ref = null
    try { ref = row.ref } catch (e) {}
    if (!ref) { root.cliampNote = "Couldn't start that entry."; return }
    pauseSelectedForCliamp()
    root.lastSource = "cliamp"
    saveSettings()
    root.cliampNote = "Loading " + row.label + "…"
    cliampCall("track.play", { track: ref }, function(res) {
      if (res === null) {
        root.cliampNote = "Couldn't start that entry."
        return
      }
      root.cliampNote = ""
      refreshCliampTab()
    })
  }
  function startCliampDaemon(cb) {
    root.cliampNote = "Starting Radio…"
    if (root.bar) root.bar.run("setsid cliamp -d")
    var tries = 0
    var wait = function() {
      runCmd(["cliamp", "remote", "state"], function(out) {
        var up = false
        try { up = !!(JSON.parse(out) || {}).ok } catch (e) {}
        if (up) {
          root.radioStopped = false
          root.cliampNote = ""
          refreshCliampTab()
          if (cb) cb()
        } else if (++tries < 10) {
          defer(wait)
        } else {
          root.cliampNote = "Radio didn't start."
        }
      })
    }
    defer(wait)
  }
  function startRadio() {
    var station = root.topStations.length > 0 ? root.topStations[0] : null
    if (!station) return
    if (root.cliampUp) playStation(station)
    else startCliampDaemon(function() { playStation(station) })
  }

  // ---- bar visualizer style (selectable, persisted) ----
  readonly property var visualStyles: [
    { id: "wave", label: "Wave" },
    { id: "bars", label: "Bars" },
    { id: "bloom", label: "Bloom" },
    { id: "blocks", label: "Blocks" },
    { id: "dots", label: "Dots" },
    { id: "blob", label: "Blob" },
    { id: "radar", label: "Radar" },
    { id: "tide", label: "Tide" },
    { id: "stars", label: "Stars" },
    { id: "helix", label: "Helix" },
    { id: "aurora", label: "Aurora" },
    { id: "lightning", label: "Lightning" },
    { id: "orbit", label: "Orbit" },
    { id: "particles", label: "Particles" },
    { id: "comet", label: "Bounce" },
    { id: "pulse", label: "Pulse" },
    { id: "ecg", label: "ECG" },
    { id: "waveform", label: "Waveform" }
  ]
  property string visualStyle: "blocks"
  property bool settingsLoaded: false
  function visualStyleValid(id) {
    for (var i = 0; i < visualStyles.length; i++)
      if (visualStyles[i].id === id) return true
    return false
  }
  // Spectrum sensitivity presets; gain is applied in Visualizer.level().
  readonly property var sensOptions: [
    { value: 0.35, label: "Chill" },
    { value: 0.65, label: "Soft" },
    { value: 1.0, label: "Normal" },
    { value: 1.5, label: "Lively" },
    { value: 2.4, label: "Wild" }
  ]
  property real sensitivity: 1.0
  function setSensitivity(v) {
    var n = Number(v)
    if (!isFinite(n)) return
    if (n < 0.3) n = 0.3
    if (n > 2.5) n = 2.5
    if (root.sensitivity === n) return
    root.sensitivity = n
    saveSettings()
    try { vizCanvas.requestPaint() } catch (e) {}
  }
  function settingsPath() {
    try { return (Quickshell.env("HOME") || "") + "/.config/quickshell/mystaryo.media.json" } catch (e) { return "" }
  }
  function setVisualFps(v) {
    var n = Number(v)
    if (fpsOptions.indexOf(n) < 0 || root.visualFps === n) return
    root.visualFps = n
    saveSettings()
    try {
      root.cavaRestartRequested = true
      cavaProc.running = false
      restartTimer.restart()
    } catch (e) {}
  }
  function loadSettings() {
    var p = settingsPath()
    if (p === "") {
      root.settingsLoaded = true
      return
    }
    runCmd(["python3", "-c", "import sys; p=sys.argv[1];\ntry:\n print(open(p).read())\nexcept Exception:\n print('{}')", p], function(out) {
      root.settingsLoaded = true
      try {
        var j = JSON.parse(out)
        if (!j) return
        if (typeof j.visualStyle === "string") {
          var v = j.visualStyle
          if (v === "flame") v = "helix"
          if (v === "equalizer" || v === "tunnel" || v === "scanner") v = "ecg"
          if (v === "confetti") v = "fireworks"
          if (v === "fireworks" || v === "fountain") v = "comet"
          if (v === "rain") v = "comet"
          if (v === "spikes" || v === "ripple") v = "lightning"
          if (visualStyleValid(v)) {
            root.visualStyle = v
            try { vizCanvas.requestPaint() } catch (e) {}
          }
        }
        if (typeof j.musicPlayer === "string" && j.musicPlayer !== "") {
          root.musicPlayerPref = j.musicPlayer.toLowerCase()
        }
        if (typeof j.sensitivity === "number" && isFinite(j.sensitivity)) {
          var sn = j.sensitivity
          if (sn < 0.3) sn = 0.3
          if (sn > 2.5) sn = 2.5
          root.sensitivity = sn
          try { vizCanvas.requestPaint() } catch (e) {}
        }
        if (typeof j.visualFps === "number" && fpsOptions.indexOf(j.visualFps) >= 0
            && root.visualFps !== j.visualFps) {
          root.visualFps = j.visualFps
          try {
            root.cavaRestartRequested = true
            cavaProc.running = false
            restartTimer.restart()
          } catch (e) {}
        }
        if (typeof j.barMode === "string" && barModeValid(j.barMode)) {
          root.barMode = j.barMode
        }
        if (typeof j.lastTitle === "string") root.lastTitle = j.lastTitle
        if (typeof j.lastArtist === "string") root.lastArtist = j.lastArtist
        if (typeof j.lastSource === "string" && (j.lastSource === "app" || j.lastSource === "cliamp")) {
          root.lastSource = j.lastSource
        }
        if (Array.isArray(j.favoriteStations)) root.favoriteStations = j.favoriteStations.slice(0, 30)
      } catch (e) {}
    })
  }
  function saveSettings() {
    var p = settingsPath()
    if (p === "" || !root.settingsLoaded) return
    var payload = JSON.stringify({
      visualStyle: root.visualStyle,
      musicPlayer: root.musicPlayerPref,
      sensitivity: String(root.sensitivity),
      barMode: root.barMode,
      lastTitle: root.lastTitle,
      lastArtist: root.lastArtist,
      lastSource: root.lastSource,
      visualFps: String(root.visualFps),
      favoriteStations: root.favoriteStations
    })
    runCmd(["python3", "-c", "import json,os,sys; p=sys.argv[1];\ntry:\n d=json.load(open(p))\nexcept Exception:\n d={}\nif not isinstance(d, dict):\n d={}\ntry:\n v=json.load(sys.stdin)\n d['visualStyle']=v['visualStyle']\n d['musicPlayer']=v['musicPlayer']\n d['sensitivity']=float(v['sensitivity'])\n d['barMode']=v['barMode']\n d['lastTitle']=v['lastTitle']\n d['lastArtist']=v['lastArtist']\n d['lastSource']=v['lastSource']\n d['visualFps']=int(v['visualFps'])\n d['favoriteStations']=v['favoriteStations']\nexcept Exception:\n pass\nos.makedirs(os.path.dirname(p), exist_ok=True);\nopen(p,'w').write(json.dumps(d))", p], null, payload)
  }
  function saveMusicPlayer() {
    saveSettings()
  }
  function setVisualStyle(id) {
    if (!visualStyleValid(id)) return
    if (root.visualStyle === id && root.barMode === "visual") return
    root.visualStyle = id
    // Picking a visual always means showing visuals.
    if (root.barMode !== "visual") root.barMode = "visual"
    saveSettings()
    try { vizCanvas.requestPaint() } catch (e) {}
  }
  // ---- bar presence: the strip IS a stock WidgetButton; the canvas floats
  // above its blank label ignoring mouse input, so hover/clicks fall through.
  implicitWidth: root.cavaDead ? 24 : (root.barMode === "track" ? trackRow.width + Style.space(8) : vizCanvas.width + Style.space(8))
  implicitHeight: barSize
  // Tooltip gate the shell's Bar machinery reads (kept for showTooltip parity).
  readonly property bool tooltipHovered: stripButton.tooltipHovered
  onBarChanged: { if (stripButton.bar !== root.bar) stripButton.bar = root.bar }

  WidgetButton {
    id: stripButton
    anchors.fill: parent
    bar: root.bar
    text: " "
    tooltipText: root.stripIsCliamp() ? (root.cliampTrack !== "" ? root.cliampTrack : "Radio") : (root.selectedPlayer ? ((root.selectedPlayer.trackTitle || "Unknown title") + (root.selectedPlayer.trackArtist ? " — " + root.selectedPlayer.trackArtist : "")) : "Media")
    onPressed: function(button) { root.barPress(button) }
  }

  Visualizer {
    id: vizCanvas
    anchors.centerIn: parent
    width: 76
    height: parent.height
    visible: !root.cavaDead && root.barMode === "visual"
    dead: root.cavaDead
    barValues: root.barValues
    barCount: root.barCount
    barMax: root.barMax
    foreground: root.bar.barForeground
    visualStyle: root.visualStyle
    sensitivity: root.sensitivity
    frameRate: root.visualFps
  }
  // Now-playing track row (barMode "track"): transport + elided title.
  // Text clicks open the popup like the rest of the strip.
  Row {
    id: trackRow
    anchors.centerIn: parent
    spacing: Style.space(4)
    visible: !root.cavaDead && root.barMode === "track"
    // Strip transport: a real WidgetButton, so the bar's own click router
    // (registered targets only) delivers taps here instead of the strip.
    // Declared after stripButton, so it wins exactly its own rect.
    WidgetButton {
      id: toggleBtn
      bar: root.bar
      text: root.stripPlaying() ? "" : ""
      tooltipText: "Play / pause"
      onPressed: function(button) {
        if (button === Qt.RightButton) { root.barPress(button); return }
        // Pause whatever plays; idle resumes the displayed side
        // (lastSource), falling back to the app when cliamp is down.
        if (root.stripIsCliamp()) root.toggleCliamp()
        else if (root.selectedPlayer && root.selectedPlayer.isPlaying) root.togglePlayer(root.selectedPlayer)
        else if (root.lastSource === "cliamp" && root.cliampUp) root.toggleCliamp()
        else root.togglePlayer(root.selectedPlayer)
      }
    }
    Text {
      id: trackText
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(150, implicitWidth)
      elide: Text.ElideRight
      textFormat: Text.PlainText
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
      color: root.bar.foreground
      opacity: root.stripPlaying() ? 1.0 : 0.55
      text: root.stripText()
      MouseArea {
        anchors.fill: parent
        onClicked: root.barPress(Qt.LeftButton)
      }
    }
  }
  Text {
    anchors.centerIn: parent
    visible: root.cavaDead
    text: "󰎅"
    color: "#D3869B"
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.iconLarge
  }
  // Single click router used by the strip button: right-click toggles
  // Words/Spectrum, left toggles the card.
  function barPress(button) {
    if (button === Qt.RightButton) {
      root.setBarMode(root.barMode === "track" ? "visual" : "track")
      return
    }
    // Capture the widget's screen position so the card opens below it.
    try {
      var p = root.mapToGlobal(root.width / 2, root.height)
      root.cardX = p.x
      root.cardY = p.y
    } catch (e) {}
    // Popup opens where the strip points: playing side first, else the
    // side that played last, else the cliamp tab (cold-start in reach).
    if (root.stripIsCliamp()) root.tabIndex = 1
    else if (root.appPlaying) root.tabIndex = 0
    else if (root.lastSource === "cliamp") root.tabIndex = 1
    else root.tabIndex = (root.selectedPlayer && root.selectedPlayer.trackTitle) ? 0 : 1
    if (root.tabIndex === 1) refreshCliampTab()
    root.popupOpen = !root.popupOpen
  }

  // ---- popup: fullscreen transparent PanelWindow, exclusive keyboard
  // focus; scrim outside-click dismisses.
  PanelWindow {
    id: popupPanel
    visible: root.popupOpen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    screen: root.barScreen
    WlrLayershell.namespace: "mystaryo-media"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    // scrim: click anywhere outside the card dismisses
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: {
        var overWidget = root.cardX >= 0
          && mouseX >= root.cardX - root.width / 2
          && mouseX <= root.cardX + root.width / 2
          && mouseY >= root.cardY - root.height
          && mouseY <= root.cardY
        return overWidget ? Qt.PointingHandCursor : Qt.ArrowCursor
      }
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      width: 348
      height: Math.min(col.implicitHeight + Style.space(20), popupPanel.height - root.height - Style.space(48))
      // Dock below the widget; clamp into the screen; flip above if the bar
      // sits at the bottom. Falls back to the old top-right dock when the
      // anchor wasn't captured (shouldn't happen — set on every open click).
      x: {
        var sw = 0
        try { sw = root.barScreen ? root.barScreen.width : 0 } catch (e) {}
        if (root.cardX < 0 || !(sw > 0)) return sw > 0 ? Math.round(sw - card.width - Style.gapsOut) : 0
        return Math.round(Math.max(Style.gapsOut, Math.min(root.cardX - card.width / 2, sw - card.width - Style.gapsOut)))
      }
      y: {
        var sh = 0
        try { sh = root.barScreen ? root.barScreen.height : 0 } catch (e) {}
        var below = (root.cardY < 0 ? root.height : root.cardY) + Style.gapsOut
        if (sh > 0 && below + card.height > sh) {
          var above = (root.cardY < 0 ? sh : root.cardY) - Style.gapsOut - card.height
          if (above >= Style.gapsOut) return Math.round(above)
        }
        return Math.round(below)
      }
      radius: Style.cornerRadius
      color: Commons.Color.popups.background
      borderSpec: Border.localOrSurfaceSpec("popups", "border", Commons.Color.popups.border, Commons.Color.popups.border, Math.max(1, Style.space(2)))
      padding: Style.space(10)

      MouseArea { anchors.fill: parent; onClicked: {} } // swallow: not a dismiss

      Column {
        id: col
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.space(8)

      // Popup-side catcher: covers the case where keyboard focus moves into
      // the popup window. Shares handleKey with the bar-side catcher.
      Item {
        id: keyCatcher
        width: 0
        height: 0
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) { root.handleKey(event) }
      }

      // tab switcher: two text tabs plus a gear tab for settings
      Row {
        width: parent.width
        spacing: Style.space(6)
        property real tabBox: (width - spacing * 2 - nowPlayingBtn.implicitHeight) / 2
        Rectangle {
          width: parent.tabBox
          height: nowPlayingBtn.implicitHeight
          radius: Style.cornerRadius
          color: root.tabIndex === 0 ? Commons.Color.popups.border : "transparent"
          border.color: Commons.Color.popups.border
          border.width: root.tabIndex === 0 ? 0 : 1
          Button {
            id: nowPlayingBtn
            anchors.fill: parent
            iconText: ""
            text: "Now Playing"
            leftAlign: true
            foreground: root.tabIndex === 0 ? Commons.Color.popups.background : root.bar.foreground
            opacity: root.tabIndex === 0 ? 1.0 : 0.8
            onClicked: root.tabIndex = 0
          }
        }
        Rectangle {
          width: parent.tabBox
          height: cliampBtn.implicitHeight
          radius: Style.cornerRadius
          color: root.tabIndex === 1 ? Commons.Color.popups.border : "transparent"
          border.color: Commons.Color.popups.border
          border.width: root.tabIndex === 1 ? 0 : 1
          Button {
            id: cliampBtn
            anchors.fill: parent
            iconText: ""
            text: "Radio"
            leftAlign: true
            foreground: root.tabIndex === 1 ? Commons.Color.popups.background : root.bar.foreground
            opacity: root.tabIndex === 1 ? 1.0 : 0.8
            onClicked: {
              root.tabIndex = 1
              refreshCliampTab()
              try { keyCatcher.forceActiveFocus() } catch (e) {}
            }
          }
        }
        Rectangle {
          width: nowPlayingBtn.implicitHeight
          height: nowPlayingBtn.implicitHeight
          radius: Style.cornerRadius
          color: root.tabIndex === 2 ? Commons.Color.popups.border : "transparent"
          border.color: Commons.Color.popups.border
          border.width: root.tabIndex === 2 ? 0 : 1
          Button {
            anchors.fill: parent
            iconText: ""
            iconSize: Style.font.body
            foreground: root.tabIndex === 2 ? Commons.Color.popups.background : root.bar.foreground
            opacity: root.tabIndex === 2 ? 1.0 : 0.8
            onClicked: root.tabIndex = 2
          }
        }
      }

      // ---- Tab 0: now playing, follows the *selected* player ----
      Column {
        width: parent.width
        spacing: Style.space(6)
        visible: root.tabIndex === 0

        Row {
          width: parent.width
          spacing: Style.space(8)

          Rectangle {
            width: 48; height: 48
            radius: 6
            color: Qt.darker(root.bar.foreground, 2.2)
            clip: true
            Image {
              anchors.fill: parent
              source: root.selectedPlayer ? (root.selectedPlayer.trackArtUrl || "") : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              visible: source !== ""
              onStatusChanged: if (status === Image.Error) source = ""
            }
            Text {
              anchors.centerIn: parent
              visible: !root.selectedPlayer || !root.selectedPlayer.trackArtUrl
              text: "♪"
              color: root.bar.foreground
              opacity: 0.5
              font.pixelSize: Style.font.iconLarge
            }
          }

          Column {
            width: parent.width - 48 - parent.spacing
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              elide: Text.ElideRight
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
              color: root.bar.foreground
              text: {
                if (!root.selectedPlayer) return "Nothing playing"
                return root.selectedPlayer.trackTitle || "Unknown title"
              }
            }
            Text {
              textFormat: Text.PlainText
              width: parent.width
              elide: Text.ElideRight
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              color: Qt.darker(root.bar.foreground, 1.3)
              visible: text !== ""
              text: root.selectedPlayer && root.selectedPlayer.trackArtist ? root.selectedPlayer.trackArtist : ""
            }
          }
        }

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(6)
          Button {
            iconText: ""
            iconSize: Style.font.iconLarge
            foreground: root.bar.foreground
            enabled: root.canStep(root.selectedPlayer, -1)
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.stepPlayer(root.selectedPlayer, -1)
          }
          Button {
            iconText: root.selectedPlayer && root.selectedPlayer.isPlaying ? "" : ""
            iconSize: Style.font.iconLarge
            foreground: root.bar.foreground
            enabled: root.canToggle(root.selectedPlayer)
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.togglePlayer(root.selectedPlayer)
          }
          Button {
            iconText: ""
            iconSize: Style.font.iconLarge
            foreground: root.bar.foreground
            enabled: root.canStep(root.selectedPlayer, 1)
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.stepPlayer(root.selectedPlayer, 1)
          }
          Button {
            iconText: ""
            iconSize: Style.font.iconLarge
            foreground: root.bar.foreground
            enabled: root.canToggle(root.selectedPlayer)
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.stopPlayer(root.selectedPlayer)
          }
        }
      }

      // ---- Tab 1: cliamp ----
      Column {
        width: parent.width
        spacing: Style.space(6)
        visible: root.tabIndex === 1

        // now-playing header: toggle shows pause while playing, play while paused
        Row {
          width: parent.width
          spacing: Style.space(6)
          visible: root.cliampRadioActive()
          Button {
            id: cliampToggle
            iconText: root.cliampPlaying() ? "" : ""
            iconSize: Style.font.iconLarge
            foreground: root.bar.foreground
            onClicked: root.toggleCliamp()
          }
          Text {
            textFormat: Text.PlainText
            width: parent.width - cliampToggle.width - cliampFavorite.width - parent.spacing * 2
            elide: Text.ElideRight
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            color: root.bar.foreground
            anchors.verticalCenter: parent.verticalCenter
            text: root.cliampTrack !== "" ? root.cliampTrack : ("Radio " + root.cliampState)
          }
          Button {
            id: cliampFavorite
            width: Style.space(30)
            iconText: root.isFavorite(root.cliampStation) ? "★" : "☆"
            foreground: root.bar.foreground
            enabled: root.cliampStation.path !== ""
            onClicked: root.toggleFavorite(root.cliampStation)
          }
        }
        Button {
          width: parent.width
          visible: root.cliampRadioActive()
          text: "Stop Radio"
          foreground: root.bar.foreground
          bordered: true
          onClicked: {
            root.cliampNote = "Stopping Radio…"
            root.cliampCall("runtime.stop", {}, function(res) {
              if (res === null) {
                root.cliampNote = "Couldn't stop Radio."
                return
              }
              root.cliampState = "stopped"
              root.radioStopped = true
              root.cliampTrack = ""
              root.cliampStation = ({ label: "", path: "" })
              root.prevCliampPlaying = false
              root.cliampNote = ""
            })
          }
        }
        Text {
          textFormat: Text.PlainText
          width: parent.width
          elide: Text.ElideRight
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          color: Qt.darker(root.bar.foreground, 1.3)
          visible: !root.cliampUp && !root.radioStopped
          text: "Radio daemon not running."
        }
        Row {
          width: parent.width
          spacing: Style.space(6)
          visible: !root.cliampRadioActive()
          Button {
            width: parent.width
            iconText: ""
            text: "Start Radio"
            foreground: root.bar.foreground
            bordered: true
            onClicked: startRadio()
          }
          Button {
            iconText: ""
            text: "Open Radio"
            foreground: root.bar.foreground
            visible: !root.cliampUp
            onClicked: if (root.bar) root.bar.run("xdg-terminal-exec --app-id=org.quickshell.cliamp -e cliamp")
          }
        }
        Row {
          width: parent.width
          spacing: Style.space(6)
          visible: root.cliampRadioActive()
          Button {
            width: (parent.width - parent.spacing) / 2
            iconText: "★"
            text: root.radioView === "favorites" ? "All stations" : "Favorites"
            leftAlign: true
            bordered: true
            selected: root.radioView === "favorites"
            foreground: root.bar.foreground
            onClicked: {
              root.radioView = root.radioView === "favorites" ? "all" : "favorites"
              root.searchQuery = ""
              root.searchRows = []
              root.cliampNote = ""
            }
          }
          Button {
            width: (parent.width - parent.spacing) / 2
            iconText: "↻"
            text: root.radioView === "recent" ? "All stations" : "Recently played"
            leftAlign: true
            bordered: true
            selected: root.radioView === "recent"
            foreground: root.bar.foreground
            onClicked: {
              root.radioView = root.radioView === "recent" ? "all" : "recent"
              root.searchQuery = ""
              root.searchRows = []
              root.cliampNote = ""
              if (root.radioView === "recent") root.loadPlayCounts()
            }
          }
        }

        // search field with inline Search button (transport lives in the header)
        Row {
          width: parent.width
          spacing: Style.space(6)
          visible: root.cliampRadioActive() && root.radioView === "all"
          Rectangle {
            width: parent.width
            height: Math.max(searchText.implicitHeight, Style.font.bodySmall) + Style.space(8)
            radius: 6
            color: "transparent"
            border.color: Qt.darker(root.bar.foreground, 1.6)
            border.width: 1
            Text {
              id: searchText
              anchors.fill: parent
              anchors.leftMargin: Style.space(4)
              anchors.topMargin: Style.space(4)
              anchors.bottomMargin: Style.space(4)
              anchors.rightMargin: searchBtn.width + Style.space(4)
              verticalAlignment: Text.AlignVCenter
              textFormat: Text.PlainText
              color: root.searchQuery !== "" ? root.bar.foreground : Qt.darker(root.bar.foreground, 1.8)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              clip: true
              elide: Text.ElideRight
              text: root.searchQuery !== "" ? (root.searchQuery + (root.cursorOn ? "▌" : "")) : ((root.cursorOn ? "▌" : "") + "Type to search stations…")
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.IBeamCursor
              onClicked: {
                try { keyCatcher.forceActiveFocus() } catch (e) {}
                root.tabIndex = 1
              }
            }
            Button {
              id: searchBtn
              anchors.right: parent.right
              anchors.rightMargin: Style.space(2)
              anchors.verticalCenter: parent.verticalCenter
              iconText: ""
              iconSize: Style.font.body
              foreground: root.bar.foreground
              enabled: !root.searchBusy
              opacity: enabled ? 1.0 : 0.5
              z: 1
              onClicked: {
                try { keyCatcher.forceActiveFocus() } catch (e) {}
                try { root.runSearch() } catch (e2) { root.searchBusy = false; root.cliampNote = "Search failed." }
              }
            }
          }
        }

        // station list: search results when searching, else the fixed top-12.
        // scrollable when overflowing.
        Flickable {
          width: parent.width
          height: Math.min(stationList.implicitHeight, Style.space(380))
          contentWidth: width
          contentHeight: stationList.implicitHeight
          clip: true
          flickableDirection: Flickable.VerticalFlick
          visible: root.cliampRadioActive()
          Column {
            id: stationList
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: root.radioView === "all" && root.searchQuery.trim() !== "" ? root.searchRows : []
              Row {
                width: stationList.width
                spacing: Style.space(4)
                Button {
                  iconText: "⏵"
                  width: parent.width - favoriteSearch.width - parent.spacing
                  leftAlign: true
                  text: (modelData ? modelData.label : "")
                  foreground: root.bar.foreground
                  onClicked: root.playSearchRow(modelData)
                }
                Button {
                  id: favoriteSearch
                  width: Style.space(30)
                  text: root.isFavorite(root.stationFromSearchRow(modelData)) ? "★" : "☆"
                  foreground: root.bar.foreground
                  enabled: root.stationFromSearchRow(modelData).path !== ""
                  onClicked: root.toggleFavorite(root.stationFromSearchRow(modelData))
                }
              }
            }
            Text {
              textFormat: Text.PlainText
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              color: Qt.darker(root.bar.foreground, 1.4)
              visible: root.radioView === "all" && root.searchQuery.trim() !== "" && root.searchRows.length === 0 && root.cliampNote === ""
              text: "Type a name or country, then Search."
            }

            Text {
              textFormat: Text.PlainText
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              color: Qt.darker(root.bar.foreground, 1.4)
              visible: root.radioView === "all" && root.searchQuery.trim() === ""
              text: "Top 12 streams"
            }
            Text {
              textFormat: Text.PlainText
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              color: Qt.darker(root.bar.foreground, 1.4)
              visible: root.radioView === "favorites"
              text: "Favorites"
            }
            Text {
              textFormat: Text.PlainText
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              color: Qt.darker(root.bar.foreground, 1.4)
              visible: root.radioView === "favorites" && root.favoriteStations.length === 0
              text: "No favorite stations yet. Star a station to add it here."
            }
            Repeater {
              model: root.radioView === "favorites" ? root.favoriteStations : []
              Row {
                width: stationList.width
                spacing: Style.space(4)
                Button {
                  iconText: "⏵"
                  width: parent.width - favoriteTop.width - parent.spacing
                  leftAlign: true
                  text: modelData.label
                  foreground: root.bar.foreground
                  onClicked: root.playStation(modelData)
                }
                Button {
                  id: favoriteTop
                  width: Style.space(30)
                  text: "★"
                  foreground: root.bar.foreground
                  onClicked: root.toggleFavorite(modelData)
                }
              }
            }
            Text {
              textFormat: Text.PlainText
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              color: Qt.darker(root.bar.foreground, 1.4)
              visible: root.radioView === "recent"
              text: "Recently played"
            }
            Text {
              textFormat: Text.PlainText
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              color: Qt.darker(root.bar.foreground, 1.4)
              visible: root.radioView === "recent" && root.recentStations.length === 0
              text: "No recently played stations."
            }
            Repeater {
              model: root.radioView === "recent" ? root.recentStations : []
              Button {
                iconText: "↻"
                width: stationList.width
                leftAlign: true
                text: modelData.label
                foreground: root.bar.foreground
                onClicked: root.playStation(modelData)
              }
            }
            Repeater {
              model: root.radioView === "all" && root.searchQuery.trim() === "" ? root.topStations : []
              Row {
                width: stationList.width
                spacing: Style.space(4)
                Button {
                  iconText: ""
                  width: parent.width - favoriteStream.width - parent.spacing
                  leftAlign: true
                  text: ((index + 1) + ".  " + (modelData && modelData.label ? modelData.label : ""))
                  foreground: root.bar.foreground
                  onClicked: root.playStation(modelData)
                }
                Button {
                  id: favoriteStream
                  width: Style.space(30)
                  text: root.isFavorite(modelData) ? "★" : "☆"
                  foreground: root.bar.foreground
                  onClicked: root.toggleFavorite(modelData)
                }
              }
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          elide: Text.ElideRight
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          color: Qt.darker(root.bar.foreground, 1.4)
          visible: root.cliampNote !== ""
          text: root.cliampNote
        }
      }

      // ---- Tab 2: settings (bar visual styles) ----
      Column {
        width: parent.width
        spacing: Style.space(6)
        visible: root.tabIndex === 2
        Text {
          textFormat: Text.PlainText
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          color: Qt.darker(root.bar.foreground, 1.4)
          text: "Bar visual (right-click toggles Words/Spectrum)"
        }
        Grid {
          width: parent.width
          columns: 3
          spacing: Style.space(6)
          Repeater {
            model: root.visualStyles.concat([{ id: "__words", label: "Words" }])
            Button {
              width: (parent.width - parent.spacing * 2) / 3
              text: modelData.label
              leftAlign: true
              selected: modelData.id === "__words" ? root.barMode === "track" : (root.visualStyle === modelData.id && root.barMode === "visual")
              foreground: root.bar.foreground
              onClicked: {
                if (modelData.id === "__words") root.setBarMode("track")
                else root.setVisualStyle(modelData.id)
              }
            }
          }
        }
        Text {
          textFormat: Text.PlainText
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          color: Qt.darker(root.bar.foreground, 1.4)
          text: "Spectrum sensitivity"
        }
        Row {
          width: parent.width
          spacing: Style.space(6)
          Repeater {
            model: root.sensOptions
            Button {
              width: (parent.width - parent.spacing * 4) / 5
              text: modelData.label
              leftAlign: true
              selected: Math.abs(root.sensitivity - modelData.value) < 0.01
              foreground: root.bar.foreground
              onClicked: root.setSensitivity(modelData.value)
            }
          }
        }
        Text {
          textFormat: Text.PlainText
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          color: Qt.darker(root.bar.foreground, 1.4)
          text: "Visualizer FPS"
        }
        Row {
          width: parent.width
          spacing: Style.space(6)
          Repeater {
            model: root.fpsOptions
            Button {
              width: (parent.width - parent.spacing * (root.fpsOptions.length - 1)) / root.fpsOptions.length
              text: modelData + " FPS"
              leftAlign: true
              selected: root.visualFps === modelData
              foreground: root.bar.foreground
              onClicked: root.setVisualFps(modelData)
            }
          }
        }
        Text {
          textFormat: Text.PlainText
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          color: Qt.darker(root.bar.foreground, 1.4)
          text: "Now Playing source"
        }
        Flickable {
          width: parent.width
          height: Math.min(playerOptionsColumn.implicitHeight, Style.space(140))
          contentWidth: width
          contentHeight: playerOptionsColumn.implicitHeight
          clip: true
          flickableDirection: Flickable.VerticalFlick
          Column {
            id: playerOptionsColumn
            width: parent.width
            spacing: Style.space(4)
            Repeater {
              model: root.musicPlayerOptions
              Button {
                width: playerOptionsColumn.width
                text: modelData.label
                leftAlign: true
                selected: root.musicPlayerPref === modelData.id
                foreground: root.bar.foreground
                onClicked: root.setMusicPlayer(modelData.id)
              }
            }
          }
        }
      }
    }
  }
  }
}
