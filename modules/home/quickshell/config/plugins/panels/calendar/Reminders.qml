pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model
import "Strings.js" as Strings

// Desktop notifications at each event's reminder times. Lives in the bar
// widget rather than the panel because the widget is always loaded.
//
// The desktop notification server shows the reminder; the panel hosts the
// meeting link and the event page, and offers Snooze through snooze() and
// recentlyFired.
//
// Every notification goes through process arguments, which other users of
// the computer can read. So by default a reminder carries no title, no place
// and no link: see Model.reminderTitle.
//
// What has been sent is kept in a small JSON file under XDG_RUNTIME_DIR, so a
// shell reload never repeats a reminder, while a reboot (which clears the
// directory) starts clean without flooding the day's backlog.
Scope {
  id: root

  // Already filtered by the widget (hidden calendars, declined).
  property var events: []
  property bool enabled: true
  // Name the event, its place and its link in the notification.
  property bool details: false
  property string language: "en"
  property string timeFormat: "HH:mm"
  // Several bar surfaces (one per monitor) each have a widget, and only one
  // of them may send, or every reminder would arrive once per screen.
  property var isLeader: function() { return true }

  property string statePath: (Quickshell.env("XDG_RUNTIME_DIR") || ((Quickshell.env("HOME") || "") + "/.cache"))
    + "/shell-calendar-reminders.json"
  property string notifier: "notify-send"

  // Event key (Model.reminderEventKey) → when its reminder was sent, for
  // the last Model.SNOOZE_WINDOW_MS. The panel offers "Snooze" while an
  // event is in here.
  property var recentlyFired: ({})

  readonly property int tickMs: 20000
  readonly property int minuteMs: 60 * 1000

  // { since, fired: { reminderKey: startMs }, recent: { eventKey: firedAtMs },
  //   snoozed: { eventKey: { fireAtMs, event } } }. `since` is when the file
  // was created: nothing due before it is sent, which is what keeps a first
  // run from replaying the whole day.
  property var store: null

  function canSnooze(event, nowMs) {
    return Model.canSnoozeReminder(recentlyFired, event, nowMs)
  }

  // Sends the reminder for `event` again in `minutes`, even if the event has
  // started by then, as long as it has not ended.
  function snooze(event, minutes) {
    if (!event || !store) return
    var next = copyStore(store)
    var key = Model.reminderEventKey(event)
    next.snoozed[key] = { fireAtMs: Date.now() + Math.max(1, Number(minutes) || 5) * minuteMs, event: Model.slimReminderEvent(event) }
    delete next.recent[key]
    commit(next)
  }

  // A one-off toast that is not a reminder ("No meeting to join").
  function notice(headline) {
    send(headline, "", "low")
  }

  // ---- Store

  function emptyStore(nowMs) {
    return { since: nowMs, fired: {}, recent: {}, snoozed: {} }
  }

  function copyStore(s) {
    return JSON.parse(JSON.stringify(s))
  }

  function parseStore(raw) {
    try {
      var parsed = JSON.parse(raw)
      if (!parsed || !isFinite(Number(parsed.since))) return null
      return {
        since: Number(parsed.since),
        fired: parsed.fired || {},
        recent: parsed.recent || {},
        snoozed: parsed.snoozed || {}
      }
    } catch (error) {
      return null
    }
  }

  function adopt(next) {
    root.store = next
    root.recentlyFired = next.recent
  }

  function commit(next) {
    var changed = JSON.stringify(next) !== JSON.stringify(store)
    adopt(next)
    if (changed) stateFile.setText(JSON.stringify(next))
  }

  // ---- Sending

  function tick(nowMs) {
    if (!enabled || !store || !isLeader()) return
    var next = copyStore(store)
    next.fired = Model.pruneFired(next.fired, nowMs)

    var due = Model.dueReminders(events, nowMs, next.fired, { notBeforeMs: next.since })
    for (var i = 0; i < due.length; i++) {
      notify(due[i].event, nowMs)
      next.recent[Model.reminderEventKey(due[i].event)] = nowMs
    }
    next.fired = Model.markFired(next.fired, due)

    for (var key in next.snoozed) {
      var snoozed = next.snoozed[key]
      if (!snoozed || Number(snoozed.fireAtMs) > nowMs) continue
      if (Model.timeRange(snoozed.event).end > nowMs) {
        notify(snoozed.event, nowMs)
        next.recent[key] = nowMs
      }
      delete next.snoozed[key]
    }

    next.recent = Model.pruneRecentReminders(next.recent, nowMs)
    commit(next)
  }

  function notify(event, nowMs) {
    var locale = Qt.locale(Strings.localeName(language))
    var body = Model.reminderBody(event, nowMs, language,
      function(ms) { return Qt.formatDateTime(new Date(ms), timeFormat) },
      function(ms) { return locale.toString(new Date(ms), "dddd") }, details)
    send(Model.reminderHeadline(event, nowMs, language, details), body, "normal")
  }

  // Argv arrays, never a shell string: titles and locations come from other
  // people's invitations.
  function send(title, text, urgency) {
    var command = [notifier, "--app-name=" + Strings.tr(language, "notify.app"),
      "-u", urgency, "--", Model.notificationArg(title), Model.notificationArg(text)]
    senderComponent.createObject(root, { command: command, running: true })
  }

  Component {
    id: senderComponent

    // One process per notification, gone once it exits.
    Process {}
  }

  FileView {
    id: stateFile
    path: root.statePath
    atomicWrites: true
    watchChanges: true
    printErrors: false

    onLoaded: root.adopt(root.parseStore(text()) || root.emptyStore(Date.now()))
    onLoadFailed: if (!root.store) root.commit(root.emptyStore(Date.now()))
    // The leader is the only writer, so a change it sees is its own write
    // coming back; the other screens pick it up for recentlyFired.
    onFileChanged: if (!root.isLeader()) reload()
  }

  Timer {
    interval: root.tickMs
    repeat: true
    running: root.enabled && root.store !== null
    triggeredOnStart: true
    onTriggered: root.tick(Date.now())
  }
}
