pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// PanelSettings: the persistent store shared by panel hosts and panel bodies.
// It stores opaque per-panel maps; validation and meaning stay with each panel.
Singleton {
  id: root

  property var entries: ({})
  property var seededEntries: ({})
  property var pendingWrites: ({})
  property bool loaded: false
  property bool directoryReady: false

  signal changed(string name, var values)

  readonly property string stateHome:
    Quickshell.env("XDG_STATE_HOME") || ((Quickshell.env("HOME") || "") + "/.local/state")
  readonly property string settingsPath: stateHome + "/quickshell/panels.json"

  function copyMap(value): var {
    if (!value || typeof value !== "object" || Array.isArray(value)) return ({})
    try { return JSON.parse(JSON.stringify(value)) } catch (e) { return ({}) }
  }

  function sameValue(left, right): bool {
    try { return JSON.stringify(left) === JSON.stringify(right) } catch (e) { return left === right }
  }

  function entry(name): var {
    return Object.prototype.hasOwnProperty.call(entries, name) ? entries[name] : undefined
  }

  // Seed defaults in memory without creating a file until the user changes a
  // setting, matching the panel host's first-run behavior.
  function ensure(name, defaults): var {
    if (!loaded) return copyMap(defaults)
    if (Object.prototype.hasOwnProperty.call(entries, name)) return entries[name]

    var values = copyMap(defaults)
    var next = Object.assign({}, entries)
    next[name] = values
    entries = next
    var seeded = Object.assign({}, seededEntries)
    seeded[name] = values
    seededEntries = seeded
    changed(name, values)
    return values
  }

  function write(name, values): void {
    if (!name) return
    var clean = copyMap(values)
    var next = Object.assign({}, entries)
    next[name] = clean
    entries = next
    if (!loaded) {
      var pending = Object.assign({}, pendingWrites)
      pending[name] = clean
      pendingWrites = pending
    } else {
      persist()
    }
    changed(name, clean)
  }

  function persist(): void {
    if (!loaded || !directoryReady) return
    settingsFile.setText(JSON.stringify(entries, null, 2) + "\n")
  }

  function load(text): void {
    var parsed = ({})
    try {
      var value = JSON.parse(String(text || ""))
      if (value && typeof value === "object" && !Array.isArray(value)) parsed = value
    } catch (e) {}

    var previous = entries
    var next = Object.assign({}, seededEntries, parsed)
    for (var name in pendingWrites) next[name] = pendingWrites[name]
    var hadPendingWrites = Object.keys(pendingWrites).length > 0
    pendingWrites = ({})
    entries = next
    loaded = true

    var names = Object.keys(previous).concat(Object.keys(next))
    var seen = ({})
    for (var i = 0; i < names.length; i++) {
      var key = names[i]
      if (seen[key]) continue
      seen[key] = true
      if (!sameValue(previous[key], next[key])) changed(key, next[key])
    }

    if (hadPendingWrites) persist()
  }

  Process {
    id: makeDirectory
    command: ["mkdir", "-p", root.stateHome + "/quickshell"]
    onExited: function(code) {
      if (code !== 0) {
        console.warn("PanelSettings: could not create state directory")
        return
      }
      root.directoryReady = true
      if (root.loaded) root.persist()
      else settingsFile.reload()
    }
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    atomicWrites: true
    watchChanges: true
    printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: if (root.directoryReady) root.load("")
    onFileChanged: reload()
  }

  Component.onCompleted: makeDirectory.running = true
}
