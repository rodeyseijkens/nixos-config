pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import qs.Commons

import "Store.js" as Store
import "Security.js" as Security
import "Delivery.js" as Delivery
import "Layout.js" as Layout

// NotificationService: the shell's org.freedesktop.Notifications daemon.
//
// It owns Quickshell's NotificationServer, the live toast model, Do Not
// Disturb, per-source snoozes and the deck layout. Surfaces (ToastHost.qml and
// PanelContent.qml) read the ready-made lists and never talk to the server
// directly. Closed notifications are dropped, never stored.
//
// Contract for the integrator:
//   NotificationService.count          live toast count
//   NotificationService.dnd            Do Not Disturb flag
//   NotificationService.clear()        dismiss everything on screen
//   NotificationService.toggleDnd()
//   NotificationService.toastRows      newest-first live rows (array)
//   NotificationService.layout         Layout.js decks/placements
//   NotificationService.settings       notification options from panels.json
//   NotificationService.snoozes        source key -> wake time (seconds)
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

  property var settings: ({})
  signal preferencesChanged(var values)
  readonly property var defaultSettings: ({
    showCountdown: false,
    alwaysShow: false,
    codesBypassQuiet: true,
    sensitiveFilter: "mask",
    snoozeDurations: ["15", "30", "60", "240", "tomorrow"],
    wakeHour: 8,
    groupLimit: 3,
    offerSnoozeWhenSharing: true,
    edgeSpacing: 16,
    expireAfterSeconds: 8,
    cardWidth: 380
  })
  readonly property bool dnd: quiet.dnd
  readonly property var snoozes: quiet.snoozes

  function setSettingsFromHost(value): void {
    settings = cleanSettings(value)
    settingsLoaded = true
    layoutRevision += 1
    refreshShareState()
  }

  function groupKeyFor(row): string {
    return Layout.groupKeyFor(row)
  }

  function groupCountFor(row): int {
    var key = groupKeyFor(row);
    var count = 0;
    for (var i = 0; i < toasts.count; i++) {
      var other = toasts.get(i);
      if (panelOnly[other.key]) continue;
      if (groupKeyFor(other) === key) count += 1;
    }
    return count;
  }

  // Every row of one source, dismissed for real: the sender is told, and the
  // cards leave the deck and the panel together.
  function closeGroup(row): void {
    var key = groupKeyFor(row);
    var keys = [];
    for (var i = 0; i < toasts.count; i++)
      if (groupKeyFor(toasts.get(i)) === key) keys.push(String(toasts.get(i).key));
    for (var j = 0; j < keys.length; j++) closeLive(keys[j], "dismissed");
  }

  function toggleGroupFor(row): void {
    toggleGroup(groupKeyFor(row));
  }

  function expireGroup(row): void {
    var key = groupKeyFor(row);
    var keys = [];
    for (var i = 0; i < toasts.count; i++)
      if (groupKeyFor(toasts.get(i)) === key) keys.push(String(toasts.get(i).key));
    for (var j = 0; j < keys.length; j++) expire(keys[j]);
  }

  // The close control on a shut stack stands for the whole stack: the card in
  // front is only what the folded deck happens to show. An open stack closes
  // the card you clicked, because its rows are separately visible then.
  function dismissStackFor(row): void {
    if (!isDeckOpen(row) && groupCountFor(row) > 1) closeGroup(row)
    else dismiss(String(row.key))
  }

  function dropLegacyHistory(): void {
    if (storeReady && !historyCleanup.running) historyCleanup.running = true
  }

  function updateSettings(values): void {
    var next = Object.assign({}, settings)
    for (var key in values) next[key] = values[key]
    settings = cleanSettings(next)
    if (settingsLoaded) preferencesChanged(settings)
    layoutRevision += 1
    refreshShareState()
  }

  function option(name): var {
    return settings[name] === undefined ? defaultSettings[name] : settings[name];
  }

  function toggleDnd(): void {
    setDnd(!dnd);
  }
  function setDnd(value: bool): void {
    var next = !!value;
    if (next === dnd) return;
    quiet = Object.assign({}, quiet, { dnd: next });
    saveQuiet();
    if (next) silenceVisibleRows();
  }

  function sourceKey(row): string {
    return String(row && (row.groupKey || row.source || row.app) || "unknown");
  }

  function isSnoozed(row): bool {
    var until = Number(quiet.snoozes[sourceKey(row)] || 0);
    return until > now / 1000;
  }

  // A quiet key as a person would name the source: "app:chat-demo" is the
  // Chat Demo app, "web:example.com" is that site, and a one-off toast has no
  // source of its own.
  function sourceLabel(key): string {
    var value = String(key || "");
    if (value.indexOf("app:") === 0)
      return value.slice(4).split(/[-_.]/).map(function(part) {
        return part ? part.charAt(0).toUpperCase() + part.slice(1) : part;
      }).join(" ");
    if (value.indexOf("web:") === 0) return value.slice(4);
    if (value.indexOf("toast:") === 0) return "One-off notification";
    return value || "Unknown source";
  }

  function quietReason(row): string {
    if (Delivery.bypassesQuiet(row)) return "";
    if (option("codesBypassQuiet") && String(row.code || "")) return "";
    if (dnd) return "dnd";
    return isSnoozed(row) ? "snoozed" : "";
  }

  function snoozeSource(row, duration): void {
    snoozeKey(sourceKey(row), duration);
  }

  function snoozeUntil(duration): real {
    // Configured durations are minutes ("15", "60"); "tomorrow" is the next
    // wake hour.
    if (String(duration) === "tomorrow") return nextWakeTime();
    var minutes = Number(duration);
    if (!isFinite(minutes) || minutes <= 0) minutes = 15;
    return now / 1000 + Math.max(60, minutes * 60);
  }

  function snoozeKey(key, duration): void {
    var until = snoozeUntil(duration);
    var next = Object.assign({}, quiet.snoozes);
    next[key] = until;
    quiet = Object.assign({}, quiet, { snoozes: next });
    saveQuiet();
    silenceSource(key);
  }

  function unsnoozeSource(key): void {
    var next = Object.assign({}, quiet.snoozes);
    delete next[key];
    quiet = Object.assign({}, quiet, { snoozes: next });
    saveQuiet();
  }

  function unsnoozeAll(): void {
    quiet = Object.assign({}, quiet, { snoozes: ({}) });
    saveQuiet();
  }

  function nextWakeTime(): real {
    var d = new Date(now);
    d.setHours(Number(option("wakeHour")) || 8, 0, 0, 0);
    if (d.getTime() <= now) d.setDate(d.getDate() + 1);
    return d.getTime() / 1000;
  }

  function silenceVisibleRows(): void {
    var keys = [];
    for (var i = 0; i < toasts.count; i++) keys.push(String(toasts.get(i).key));
    for (var j = 0; j < keys.length; j++) silenceKey(keys[j]);
  }

  function silenceSource(key): void {
    var keys = [];
    for (var i = 0; i < toasts.count; i++) {
      var row = toasts.get(i);
      if (sourceKey(row) === key) keys.push(String(row.key));
    }
    for (var j = 0; j < keys.length; j++) silenceKey(keys[j]);
  }

  function silenceKey(key): void {
    var at = rowIndexFor(key);
    if (at < 0) return;
    var ref = refs[key];
    var row = rowsByKey[key];
    toasts.remove(at);
    if (ref) { try { ref.dismiss(); } catch (e) {} }
    forgetKey(key, row);
    revision += 1;
  }

  function forgetKey(key, row): void {
    if (row && row.originalId) delete originalKeys[row.originalId];
    delete refs[key];
    delete rowsByKey[key];
    delete closedKeys[key];
    delete heights[key];
    if (panelOnly[key]) {
      var next = Object.assign({}, panelOnly);
      delete next[key];
      panelOnly = next;
    }
    refsRevision += 1;
    layoutRevision += 1;
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

  readonly property int notificationWidth: Style.space(option("cardWidth"))
  // The bar's fill and top-border colour (Colors.base01 / base04). Held as
  // literals because a pragma Singleton cannot resolve the root Colors
  // singleton reliably during construction.
  readonly property color surface: "#3C3836"
  readonly property color surfaceBorder: "#BDAE93"
  readonly property var availableSnoozeDurations: ["15", "30", "60", "120", "240", "480", "tomorrow"]

  // --------------------------------------------------------------- model
  ListModel {
    id: toasts
  }

  property int revision: 0
  property int refsRevision: 0
  property int keySeed: 0
  property real panelReplyKey: 0
  property var quiet: ({ dnd: false, snoozes: ({}) })
  property bool shareActive: false
  property bool sharePrompt: false
  property bool sharePromptDismissed: false

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

  // Rows that have been shown in the panel stay there: a notification read in
  // the panel does not pop back onto the desktop when the panel closes.
  property var panelOnly: ({})
  property bool panelOpen: false
  onPanelOpenChanged: if (panelOpen) markPanelOnly()

  function markPanelOnly(): void {
    var next = Object.assign({}, panelOnly)
    var changed = false
    for (var i = 0; i < toasts.count; i++) {
      var key = String(toasts.get(i).key)
      if (!next[key]) { next[key] = true; changed = true }
    }
    if (changed) {
      panelOnly = next
      revision += 1
    }
  }

  // The rows the deck still has to show. Rows taken up by the panel are
  // excluded; the panel itself keeps using toastRows.
  readonly property var deckRows: {
    revision;
    panelOnly;
    var out = []
    for (var i = 0; i < toasts.count; i++)
      if (!panelOnly[toasts.get(i).key]) out.push(toasts.get(i))
    return out
  }

  readonly property int deckCount: deckRows.length

  // The card a deck shows in front, by row key: the newest row of each source.
  // Cards behind it are only a peek of an edge and cannot carry buttons, so
  // this is what decides which card draws its action bar. Derived from the
  // rows alone, never from the layout, so measuring a card cannot feed back
  // into the layout that placed it.
  readonly property var deckFrontKeys: {
    revision;
    panelOnly;
    var out = {}, seen = {};
    for (var i = 0; i < toasts.count; i++) {
      var row = toasts.get(i);
      if (panelOnly[row.key]) continue;
      var key = groupKeyFor(row);
      if (seen[key]) continue;
      seen[key] = true;
      out[row.key] = true;
    }
    return out;
  }

  readonly property var layout: {
    layoutRevision;
    revision;
    panelOnly;
    // One deck per sender, always. Each stack opens and folds on its own,
    // so expanding Slack does not expand anything else.
    return Layout.compute(deckRows, {
      expanded: groupExpanded,
      openDeck: openGroup,
      groupLimit: option("groupLimit"),
      maxHeight: deckMaxHeight,
      gap: Style.space(6),
      deckGap: Style.space(11),
      heightOf: function(key) {
        return Math.max(1, service.heights[key] || Style.space(72));
      }
    });
  }

  property string openGroup: ""
  property bool groupExpanded: false

  // How tall the transient deck may grow. The host sets it from the screen it
  // draws on; until then the panel's own limit is a safe stand-in.
  property real deckMaxHeight: 900

  // Whether this row's own stack is the one that is open. Each stack opens
  // and folds on its own, so several stacks can sit on screen at once.
  function isDeckOpen(row): bool {
    return groupExpanded && groupKeyFor(row) === openGroup
  }
  readonly property ListModel model: toasts

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
    return at >= 0 ? toasts.get(at) : null;
  }

  function toggleGroup(key): void {
    if (openGroup === key && groupExpanded) {
      groupExpanded = false;
      openGroup = "";
    } else {
      openGroup = key;
      groupExpanded = true;
    }
    layoutRevision += 1;
  }

  function togglePanel(): void {
    panelReplyKey = 0;
    OverlayPanels.toggle("notifications", targetDisplayName);
  }

  function snoozeDurations(): var {
    var values = option("snoozeDurations") || [];
    var out = [];
    for (var i = 0; i < values.length; i++) {
      var value = String(values[i]);
      var label = value === "tomorrow" ? "Until tomorrow" : value === "15" ? "15m"
        : value === "30" ? "30m" : value === "60" ? "1h" : value === "120" ? "2h"
        : value === "240" ? "4h" : value === "480" ? "8h" : "";
      if (label) out.push({ value: value, label: label });
    }
    return out;
  }

  function replyTo(key): void {
    panelReplyKey = key;
    OverlayPanels.open("notifications", targetDisplayName);
  }

  function sourceIcon(row): string {
    var names = Icons.candidates(row);
    var all = (names.themed || []).concat(names.entries || []);
    for (var i = 0; i < all.length; i++) {
      var path = Quickshell.iconPath(all[i], true);
      if (path) return path;
    }
    return "";
  }

  function actionsFor(key): var {
    refsRevision;
    var ref = refs[key];
    if (!ref || !ref.actions) return [];
    var out = [];
    for (var i = 0; i < Math.min(ref.actions.length, Security.MAX_ACTIONS); i++) {
      var action = ref.actions[i];
      var id = String(action.identifier || "");
      if (!id || id === "default" || id.length > Security.MAX_ACTION_ID) continue;
      var label = Security.bounded(String(action.text || id), Security.MAX_ACTION_LABEL);
      if (/^settings$/i.test(label) || /^settings$/i.test(id)) continue;
      // A sender's own Reply action is a D-Bus round trip that closes the
      // notification; when the sender also advertises an inline reply, the
      // card's reply field is the same action without losing the message.
      if (ref.hasInlineReply && /^(reply|inline-reply)$/i.test(id)) continue;
      if (ref.hasInlineReply && /^reply\b/i.test(label)) continue;
      out.push({ id: id, text: label });
    }
    return out;
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

  function durationFor(urgency, requested): int {
    if (urgency === NotificationUrgency.Critical)
      return 0
    var ms = Number(requested)
    if (!isFinite(ms)) ms = -1
    // XDG spec: a positive timeout is the sender's own; 0 means the
    // notification stays until dismissed; -1 means the server's default.
    if (ms === 0) return 0
    if (ms > 0) return Math.max(1000, ms)
    return Math.max(3000, Number(option("expireAfterSeconds")) * 1000)
  }

  function activeRowsForSource(key): var {
    var out = [];
    for (var i = 0; i < toasts.count; i++)
      if (sourceKey(toasts.get(i)) === key) out.push(toasts.get(i));
    return out;
  }

  function allSourceKeys(): var {
    var out = [], seen = {};
    for (var i = 0; i < toasts.count; i++) {
      var key = sourceKey(toasts.get(i));
      if (seen[key]) continue;
      seen[key] = true;
      out.push(key);
    }
    for (var snoozedKey in quiet.snoozes) {
      if (Number(quiet.snoozes[snoozedKey]) > now / 1000 && !seen[snoozedKey]) {
        seen[snoozedKey] = true;
        out.push(snoozedKey);
      }
    }
    return out;
  }

  function snoozeAll(duration): void {
    var keys = allSourceKeys();
    var next = Object.assign({}, quiet.snoozes);
    var until = snoozeUntil(duration);
    for (var i = 0; i < keys.length; i++) next[keys[i]] = until;
    quiet = Object.assign({}, quiet, { snoozes: next });
    saveQuiet();
    silenceVisibleRows();
  }

  function dismissSharePrompt(): void {
    sharePrompt = false;
    sharePromptDismissed = true;
  }

  readonly property var pipewireNodes: Pipewire.nodes ? Pipewire.nodes.values : []

  function refreshShareState(): void {
    if (!option("offerSnoozeWhenSharing")) {
      sharePrompt = false;
      sharePromptDismissed = false;
      return;
    }
    var active = false;
    for (var i = 0; i < pipewireNodes.length; i++) {
      var node = pipewireNodes[i];
      if (!node || !node.isStream) continue;
      var props = node.properties || {};
      var mediaClass = String(props["media.class"] || node.type || "").toLowerCase();
      var app = String(props["application.name"] || "").toLowerCase();
      var name = String(props["node.name"] || node.name || "").toLowerCase();
      var desc = String(node.description || "").toLowerCase();
      if (mediaClass.indexOf("video") >= 0
          && /(portal|screen|screencast|capture|share)/.test(app + " " + name + " " + desc)) {
        active = true;
        break;
      }
    }
    if (active && !shareActive && !sharePromptDismissed) sharePrompt = true;
    if (!active) {
      sharePrompt = false;
      sharePromptDismissed = false;
    }
    shareActive = active;
  }

  onPipewireNodesChanged: Qt.callLater(refreshShareState)

  Timer {
    interval: 3000
    repeat: true
    running: service.option("offerSnoozeWhenSharing")
    onTriggered: service.refreshShareState()
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
    var muted = quietReason(row);

    if (muted) {
      if (at >= 0) {
        toasts.remove(at);
        revision += 1;
      }
      forgetKey(key, row);
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

    // Anything that arrives while the panel is open was read there, not on
    // the desktop, so it belongs to the panel from now on.
    if (panelOpen && !panelOnly[key]) {
      var next = Object.assign({}, panelOnly);
      next[key] = true;
      panelOnly = next;
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
  // A card that times out leaves the desktop but not the panel: it is still a
  // notification with actions until someone dismisses it. So expiry only moves
  // the row into the panel's list; nothing is sent back to the sender.
  function expire(key): void {
    var at = rowIndexFor(key);
    if (at < 0) return;
    toasts.setProperty(at, "duration", 0);
    if (!panelOnly[key]) {
      var next = Object.assign({}, panelOnly);
      next[key] = true;
      panelOnly = next;
    }
    revision += 1;
    layoutRevision += 1;
  }

  function dismiss(key): void {
    if (rowIndexFor(key) < 0) return;
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
    if (closedKeys[key]) return;
    closedKeys[key] = true;
    var row = rowsByKey[key];
    var at = rowIndexFor(key);
    if (at >= 0) {
      toasts.remove(at);
      revision += 1;
    }
    forgetKey(key, row);
    if (toasts.count === 0) {
      _deckScreen = "";
      openGroup = "";
      groupExpanded = false;
    }
  }

  function clear(): void {
    var keys = [];
    for (var i = 0; i < toasts.count; i++) keys.push(String(toasts.get(i).key));
    for (var k = 0; k < keys.length; k++) {
      var ref = refs[keys[k]];
      if (ref) { try { ref.dismiss(); } catch (e) {} }
    }
    toasts.clear();
    refs = ({});
    rowsByKey = ({});
    originalKeys = ({});
    closedKeys = ({});
    heights = ({});
    panelOnly = ({});
    revision += 1;
    refsRevision += 1;
    layoutRevision += 1;
    openGroup = "";
    groupExpanded = false;
    _deckScreen = "";
  }

  function dismissAll(): void {
    clear();
  }

  // --------------------------------------------------------------- actions
  function activate(key): void {
    var row = rowFor(key);
    if (!row) return;
    var senderPid = Number(row.senderPid || 0);
    if (senderPid > 0) {
      var active = Quickshell.toplevels.values.find(function(window) { return window.pid === senderPid; });
      if (active) {
        Hyprland.dispatch("focuswindow pid:" + senderPid);
        return;
      }
    }
    var link = String(row.link || "");
    if (!link && row.source) {
      var host = Security.canonicalHostname(String(row.source));
      if (host) link = "https://" + host + "/";
    }
    if (link) Security.openExternalUrl(link);
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
    if (!ref || !ref.hasInlineReply || typeof ref.sendInlineReply !== "function") return false;
    ref.sendInlineReply(String(text));
    return true;
  }

  function snoozeOptions(): var {
    var configured = option("snoozeDurations");
    var out = [];
    for (var i = 0; i < configured.length; i++) {
      var value = String(configured[i]);
      var label = value === "tomorrow" ? "Until tomorrow" : value === "15" ? "15 minutes"
        : value === "30" ? "30 minutes" : value === "60" ? "1 hour" : value === "120" ? "2 hours"
        : value === "240" ? "4 hours" : value === "480" ? "8 hours" : "";
      if (label) out.push({ value: value, label: label });
    }
    return out.length ? out : [{ value: "15", label: "15 minutes" }, { value: "60", label: "1 hour" }];
  }

  function saveQuiet(): void {
    if (quietLoaded) quietFile.setText(JSON.stringify({ dnd: quiet.dnd, snoozes: quiet.snoozes }, null, 2) + "\n");
  }

  function restoreQuiet(text): void {
    var parsed = null;
    try { parsed = JSON.parse(String(text || "")); } catch (e) {}
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      var snoozes = {};
      var sourceSnoozes = parsed.snoozes && typeof parsed.snoozes === "object" ? parsed.snoozes : {};
      for (var key in sourceSnoozes) {
        var until = Number(sourceSnoozes[key]);
        if (isFinite(until) && until > Date.now() / 1000) snoozes[key] = until;
      }
      quiet = { dnd: parsed.dnd === true, snoozes: snoozes };
    }
    quietLoaded = true;
    saveQuiet();
  }

  function cleanSettings(raw): var {
    var out = {};
    var base = defaultSettings;
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) return out;
    for (var key in base) {
      if (raw[key] === undefined) continue;
      var value = raw[key];
      if (["showCountdown", "alwaysShow", "codesBypassQuiet", "offerSnoozeWhenSharing"].indexOf(key) >= 0) value = value === true;
      else if (key === "groupLimit") value = Math.max(1, Math.min(6, Number(value) || 3));
      else if (key === "edgeSpacing") value = Math.max(0, Math.min(64, Number(value) || 0));
      else if (key === "expireAfterSeconds") value = Math.max(3, Math.min(30, Number(value) || 8));
      else if (key === "cardWidth") value = Math.max(300, Math.min(520, Number(value) || 380));
      else if (key === "wakeHour") value = Math.max(0, Math.min(23, Number(value) || 8));
      else if (key === "snoozeDurations") value = Array.isArray(value) ? value.filter(function(v) { return ["15", "30", "60", "120", "240", "480", "tomorrow"].indexOf(String(v)) >= 0; }).map(String) : base.snoozeDurations;
      else if (key === "sensitiveFilter") value = ["off", "mask", "redact"].indexOf(String(value)) >= 0 ? String(value) : "mask";
      out[key] = value;
    }
    return out;
  }

  readonly property string stateDir:
    (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/notifications"
  property bool storeReady: false
  property bool quietLoaded: false
  property bool settingsLoaded: false

  Process {
    id: storePrepare
    command: ["mkdir", "-p", service.stateDir, ((Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell")]
    onExited: function(code) {
      service.storeReady = code === 0;
      if (code === 0) historyCleanup.running = true;
    }
  }

  FileView {
    id: quietFile
    path: service.storeReady ? service.stateDir + "/quiet.json" : ""
    atomicWrites: true
    printErrors: false
    onLoaded: service.restoreQuiet(text())
    onLoadFailed: service.restoreQuiet("")
  }

  // Explicitly remove the previous daemon's durable history: this setup was
  // chosen to have no stored or session history.
  Process {
    id: historyCleanup
    command: ["rm", "-f", service.stateDir + "/history.json"]
  }

  Component.onCompleted: storePrepare.running = true

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
