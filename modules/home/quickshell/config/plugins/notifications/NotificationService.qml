pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import qs.Commons

import "Store.js" as Store
import "Security.js" as Security
import "Delivery.js" as Delivery
import "Layout.js" as Layout

// NotificationService: the shell's org.freedesktop.Notifications daemon.
//
// It owns Quickshell's NotificationServer, the live toast model, the history
// store and the Do Not Disturb flag. Surfaces (ToastHost.qml and
// PanelContent.qml) read the ready-made lists and never talk to the server
// directly.
//
// Contract for the integrator:
//   NotificationService.count          live toast count
//   NotificationService.dnd            Do Not Disturb flag
//   NotificationService.clear()        dismiss everything and empty history
//   NotificationService.toggleDnd()
//   NotificationService.toastRows      newest-first live rows (array)
//   NotificationService.layout         Layout.js decks/placements
//   NotificationService.entries        newest-first live + closed history
Singleton {
  id: service

  // --------------------------------------------------------------- clocks
  property double now: Date.now()
  Timer {
    interval: 30000
    repeat: true
    running: true
    onTriggered: service.now = Date.now()
  }

  // --------------------------------------------------------------- public
  readonly property int count: toasts.count
  readonly property int unreadCount: toasts.count

  property bool dnd: false
  function toggleDnd(): void {
    dnd = !dnd;
    saveSoon("quiet");
  }
  function setDnd(value: bool): void {
    var next = !!value;
    if (next === dnd)
      return;
    dnd = next;
    saveSoon("quiet");
  }

  // The deck is pinned to the monitor a notification first landed on, so a
  // stack does not jump between outputs while it is being read.
  readonly property var displayNames: Quickshell.screens.map(function(screen) { return screen.name })
  readonly property string focusedDisplayName: {
    var name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
    return displayNames.indexOf(name) >= 0 ? name : (displayNames[0] || "");
  }
  property string _deckScreen: ""
  readonly property string targetDisplayName:
    displayNames.indexOf(_deckScreen) >= 0 ? _deckScreen : focusedDisplayName

  readonly property int notificationWidth: Style.space(380)

  // --------------------------------------------------------------- model
  ListModel {
    id: toasts
  }

  property int revision: 0
  property int refsRevision: 0
  property int keySeed: 0

  // Live sender objects, keyed by our row key. Kept out of the model: a
  // QObject in a ListModel role dangles when the server destroys it.
  property var refs: ({})
  property var rowsByKey: ({})
  property var originalKeys: ({})
  property var closedKeys: ({})
  property var heights: ({})
  property int layoutRevision: 0

  readonly property var toastRows: {
    revision;
    var out = [];
    for (var i = 0; i < toasts.count; i++)
      out.push(toasts.get(i));
    return out;
  }

  readonly property var layout: {
    layoutRevision;
    revision;
    return Layout.compute(toastRows, {
      expanded: false,
      gap: Style.space(6),
      deckGap: Style.space(11),
      heightOf: function(key) {
        return Math.max(1, service.heights[key] || Style.space(72));
      }
    });
  }

  // History: closed rows, newest first, capped by Store.js.
  property var historyEntries: []
  readonly property var history: historyEntries
  readonly property ListModel model: toasts

  readonly property var entries: {
    revision;
    var live = toastRows;
    var out = [];
    var i, j;
    for (i = 0; i < live.length; i++)
      out.push(live[i]);
    for (j = 0; j < historyEntries.length; j++) {
      var entry = historyEntries[j];
      var duplicate = false;
      for (i = 0; i < live.length; i++) {
        if (live[i].key === entry.key) {
          duplicate = true;
          break;
        }
      }
      if (!duplicate)
        out.push(entry);
    }
    out.sort(function(a, b) { return Number(b.ts || 0) - Number(a.ts || 0); });
    return out;
  }

  // --------------------------------------------------------------- helpers
  function nextKey(): string {
    var key;
    do {
      keySeed += 1;
      key = "n" + Date.now().toString(36) + keySeed.toString(36);
    } while (rowsByKey[key] || refs[key]);
    return key;
  }

  function keyForOriginal(id): string {
    if (!id)
      return "";
    var key = originalKeys[id];
    return key && refs[key] ? key : "";
  }

  function rowIndexFor(key): int {
    for (var i = 0; i < toasts.count; i++)
      if (toasts.get(i).key === key)
        return i;
    return -1;
  }

  function rowFor(key): var {
    var at = rowIndexFor(key);
    if (at >= 0)
      return toasts.get(at);
    for (var i = 0; i < historyEntries.length; i++)
      if (historyEntries[i].key === key)
        return historyEntries[i];
    return null;
  }

  function noteHeight(key, height): void {
    var value = Math.max(1, Number(height) || 0);
    if (Math.abs((heights[key] || 0) - value) < 0.5)
      return;
    var next = Object.assign({}, heights);
    next[key] = value;
    heights = next;
    layoutRevision += 1;
  }

  // What the sender put on the wire, minus the implicit default (the card
  // click) and the desktop's Settings row.
  function actionsFor(key): var {
    refsRevision;
    var ref = refs[key];
    var out = [];
    if (!ref || !ref.actions)
      return out;
    for (var i = 0; i < Math.min(ref.actions.length, Security.MAX_ACTIONS); i++) {
      var action = ref.actions[i];
      var id = String(action.identifier || "");
      if (!id || id === "default" || id.length > Security.MAX_ACTION_ID)
        continue;
      var label = Security.bounded(String(action.text || id), Security.MAX_ACTION_LABEL);
      if (/^settings$/i.test(label) || /^settings$/i.test(id))
        continue;
      out.push({ id: id, text: label });
    }
    return out;
  }

  function durationFor(urgency, requested): int {
    if (urgency === NotificationUrgency.Critical)
      return 0;
    var base = urgency === NotificationUrgency.Low ? 5000 : 8000;
    return Math.min(30000, Math.max(base, Number(requested) > 0 ? Number(requested) : 0));
  }

  // --------------------------------------------------------------- arrival
  function handleNotification(notification): void {
    var existing = keyForOriginal(notification.id);
    var key = existing || nextKey();

    notification.tracked = true;

    var row = Store.snapshot(notification, key, NotificationUrgency);
    row.duration = durationFor(notification.urgency, row.expireTimeout);

    var previous = refs[key];
    refs[key] = notification;
    refsRevision += 1;
    if (previous && previous !== notification) {
      try { previous.tracked = false; } catch (e) {}
    }
    rowsByKey[key] = row;
    if (!existing) {
      if (notification.id)
        originalKeys[notification.id] = key;
      watch(notification, key);
    }

    var at = rowIndexFor(key);
    var muted = Delivery.quietReason(row, dnd);

    if (muted) {
      if (at >= 0) {
        toasts.remove(at);
        revision += 1;
      }
      if (!Delivery.isEphemeral(row))
        recordHistory(row, muted);
      delete refs[key];
      delete rowsByKey[key];
      delete heights[key];
      refsRevision += 1;
      try { notification.tracked = false; } catch (e) {}
      return;
    }

    if (at >= 0) {
      Store.applyTo(toasts, at, row);
      revision += 1;
    } else {
      if (toasts.count === 0)
        service._deckScreen = focusedDisplayName;
      toasts.insert(0, row);
      revision += 1;
    }
  }

  function watch(notification, key): void {
    var expected = notification;

    notification.closed.connect(function() {
      if (service.refs[key] !== expected)
        return;
      delete service.refs[key];
      service.refsRevision += 1;
      Qt.callLater(function() { service.finishClosed(key, "closed"); });
    });

    // replaces_id mutates this object in place. Re-snapshot once per burst.
    var queued = false;
    var refresh = function() {
      if (!queued)
        return;
      queued = false;
      if (service.refs[key] !== expected)
        return;
      service.handleNotification(expected);
    };
    var schedule = function() {
      if (queued || service.refs[key] !== expected)
        return;
      queued = true;
      Qt.callLater(refresh);
    };
    var signals = [notification.summaryChanged, notification.bodyChanged,
                   notification.appNameChanged, notification.appIconChanged,
                   notification.imageChanged, notification.urgencyChanged,
                   notification.expireTimeoutChanged, notification.hintsChanged,
                   notification.actionsChanged];
    for (var i = 0; i < signals.length; i++)
      signals[i].connect(schedule);
  }

  // --------------------------------------------------------------- closing
  function expire(key): void {
    if (rowIndexFor(key) < 0)
      return;
    closeLive(key, "expired");
  }

  function dismiss(key): void {
    if (rowIndexFor(key) < 0) {
      removeHistory(key);
      return;
    }
    closeLive(key, "dismissed");
  }

  function closeLive(key, reason): void {
    var ref = refs[key];
    Qt.callLater(function() {
      if (service.rowIndexFor(key) < 0)
        return;
      service.finishClosed(key, reason);
      if (!ref)
        return;
      try {
        if (reason === "expired")
          ref.expire();
        else
          ref.dismiss();
      } catch (e) {}
    });
  }

  function finishClosed(key, reason): void {
    if (closedKeys[key])
      return;
    closedKeys[key] = true;

    var row = rowsByKey[key];
    var at = rowIndexFor(key);
    if (at >= 0) {
      toasts.remove(at);
      revision += 1;
    }

    if (row) {
      if (reason !== "silenced")
        recordHistory(row, reason);
      if (row.originalId)
        delete originalKeys[row.originalId];
    }

    delete refs[key];
    delete rowsByKey[key];
    delete heights[key];
    refsRevision += 1;
    layoutRevision += 1;
    if (toasts.count === 0)
      _deckScreen = "";
  }

  function clear(): void {
    var keys = [];
    for (var i = 0; i < toasts.count; i++)
      keys.push(String(toasts.get(i).key));
    for (var k = 0; k < keys.length; k++) {
      var ref = refs[keys[k]];
      if (ref) {
        try { ref.dismiss(); } catch (e) {}
      }
    }
    toasts.clear();
    refs = ({});
    rowsByKey = ({});
    originalKeys = ({});
    closedKeys = ({});
    heights = ({});
    historyEntries = [];
    revision += 1;
    refsRevision += 1;
    layoutRevision += 1;
    _deckScreen = "";
    saveSoon("history");
  }

  function dismissAll(): void {
    clear();
  }

  // --------------------------------------------------------------- actions
  function activate(key): void {
    var row = rowFor(key);
    var ref = refs[key];
    if (ref) {
      for (var i = 0; i < Math.min(ref.actions ? ref.actions.length : 0, Security.MAX_ACTIONS); i++) {
        if (String(ref.actions[i].identifier) === "default") {
          try { ref.actions[i].invoke(); } catch (e) {}
          return;
        }
      }
    }
    if (!row)
      return;
    var link = String(row.link || "");
    if (!link && row.source) {
      var host = Security.canonicalHostname(String(row.source));
      if (host)
        link = "https://" + host + "/";
    }
    if (link)
      Security.openExternalUrl(link);
  }

  function invokeAction(key, identifier): bool {
    var ref = refs[key];
    if (!ref || !ref.actions)
      return false;
    for (var i = 0; i < Math.min(ref.actions.length, Security.MAX_ACTIONS); i++) {
      if (String(ref.actions[i].identifier) !== String(identifier))
        continue;
      try { ref.actions[i].invoke(); } catch (e) { return false; }
      closeLive(key, "activated");
      return true;
    }
    return false;
  }

  function runExecAction(key, index): bool {
    var row = rowFor(key);
    var actions = Security.parseExecActions(row ? row.execActions : "");
    if (!actions || index < 0 || index >= actions.length)
      return false;
    Util.execArgv(actions[index].argv);
    closeLive(key, "activated");
    return true;
  }

  function copyCode(value): bool {
    var text = String(value || "");
    if (!text || text.length > 64)
      return false;
    Quickshell.execDetached(["wl-copy", "--sensitive", "--", text]);
    return true;
  }

  function sendInlineReply(key, text): bool {
    var ref = refs[key];
    if (!ref || !ref.hasInlineReply || typeof ref.sendInlineReply !== "function")
      return false;
    ref.sendInlineReply(String(text));
    return true;
  }

  // --------------------------------------------------------------- history
  function recordHistory(row, reason): void {
    var stamp = Date.now() / 1000;
    // closedEntry() keeps only persisted fields, so rebuild the derived
    // markup/grouping fields the cards read before putting it in the panel.
    var entry = Store.normalise(Store.closedEntry(row, reason, stamp));
    entry.closed_ts = stamp;
    entry.closed_reason = reason;
    historyEntries = Store.addHistory(historyEntries, entry, stamp);
    revision += 1;
    saveSoon("history");
  }

  function normaliseHistory(entries): var {
    var out = [];
    for (var i = 0; i < entries.length; i++) {
      var row = Store.normalise(entries[i]);
      row.closed_ts = entries[i].closed_ts;
      row.closed_reason = entries[i].closed_reason;
      out.push(row);
    }
    return out;
  }

  function removeHistory(key): void {
    var before = historyEntries.length;
    historyEntries = historyEntries.filter(function(entry) { return entry.key !== key; });
    if (historyEntries.length !== before) {
      revision += 1;
      saveSoon("history");
    }
  }

  // --------------------------------------------------------------- store
  readonly property string stateDir:
    (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/notifications"
  property bool storeReady: false
  property bool historyLoaded: false
  property bool quietLoaded: false
  property var unsaved: ({})

  function saveSoon(file): void {
    unsaved[file] = true;
    if (!saveTimer.running)
      saveTimer.start();
  }

  Timer {
    id: saveTimer
    interval: 250
    onTriggered: service.flushStore()
  }

  function flushStore(): void {
    if (unsaved.history && historyLoaded) {
      delete unsaved.history;
      historyFile.setText(Store.serialise(historyEntries));
    }
    if (unsaved.quiet && quietLoaded) {
      delete unsaved.quiet;
      quietFile.setText(Store.serialiseQuiet({ dnd: dnd }));
    }
  }

  function loadHistory(text): void {
    if (historyLoaded)
      return;
    var stored = normaliseHistory(Store.parseHistory(text));
    historyEntries = Store.retain(historyEntries.concat(stored), Date.now() / 1000);
    historyLoaded = true;
    revision += 1;
    if (unsaved.history || Store.serialise(historyEntries) !== String(text))
      saveSoon("history");
  }

  function loadQuiet(text): void {
    if (quietLoaded)
      return;
    var read = Store.parseQuiet(text);
    if (read)
      dnd = read.dnd;
    quietLoaded = true;
    if (unsaved.quiet)
      saveSoon("quiet");
  }

  Process {
    id: storePrepare
    command: ["mkdir", "-p", service.stateDir]
    onExited: function(code) { service.storeReady = code === 0; }
  }

  FileView {
    id: historyFile
    path: service.storeReady ? service.stateDir + "/history.json" : ""
    atomicWrites: true
    printErrors: false
    onLoaded: service.loadHistory(text())
    onLoadFailed: service.loadHistory("")
  }

  FileView {
    id: quietFile
    path: service.storeReady ? service.stateDir + "/quiet.json" : ""
    atomicWrites: true
    printErrors: false
    onLoaded: service.loadQuiet(text())
    onLoadFailed: service.loadQuiet("")
  }

  Component.onCompleted: storePrepare.running = true
  Component.onDestruction: flushStore()

  // --------------------------------------------------------------- server
  NotificationServer {
    id: notifServer
    bodySupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    bodyImagesSupported: true
    imageSupported: true
    actionsSupported: true
    inlineReplySupported: true
    persistenceSupported: true
    keepOnReload: true

    onNotification: function(notification) { service.handleNotification(notification); }
  }
}
