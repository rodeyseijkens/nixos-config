pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// CalendarEvents: the shell's view of the calendar sync's event file. The
// calendar panel reads the same file for its month grid; this service exists
// so the bar can answer one question without building the panel: is something
// happening right now?
Singleton {
  id: root

  property var events: []
  property date now: new Date()

  readonly property bool happeningNow: {
    var current = root.now.getTime()
    for (var i = 0; i < root.events.length; i++) {
      var event = root.events[i]
      if (!event || event.allDay) continue
      var start = Date.parse(event.start || "")
      if (isNaN(start)) continue
      var end = Date.parse(event.end || "")
      if (isNaN(end)) end = start + 3600000
      if (start <= current && current < end) return true
    }
    return false
  }

  function applyEvents(raw) {
    var list = []
    try {
      var doc = JSON.parse(raw || "")
      if (doc && doc.version === 1 && Array.isArray(doc.events)) list = doc.events
    } catch (error) {}
    root.events = list
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }

  FileView {
    path: (Quickshell.env("HOME") || "") + "/.local/state/shell-calendar/calendar-events.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.applyEvents(text())
    onLoadFailed: root.applyEvents("")
    onFileChanged: reload()
  }
}
