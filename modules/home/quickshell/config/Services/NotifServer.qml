pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
  id: server

  // QML has no access modifiers: _-prefixed members are internal to this module.
  property var receivedAt: ({})
  property date now: new Date()

  // Quickshell's Notification exposes no timestamp, so track receipt time
  // ourselves (keyed by notification id) and render relative ages like swaync.
  // swaync parity: a popup's timeout "removes" it from the popup layer but the
  // notification stays in the panel's history until it is fully dismissed
  // (✕ / Clear All). acked = popup already shown-and-expired, still in history.
  property var acked: ({})

  // Feed views — the ordering, acked filter and toast cap live here and only
  // here; surfaces consume the ready-made lists.
  // entries: full history, newest first (notification panel).
  readonly property var entries: [...notifServer.trackedNotifications.values].reverse()
  // toasts: current generation, unacked, newest five (toast feed).
  readonly property var toasts: entries.filter(n => !n.lastGeneration && !isAcked(n.id)).slice(0, 5)
  // unreadCount: notifications that haven't expired out of the feed yet.
  readonly property int unreadCount: entries.filter(n => !isAcked(n.id)).length

  // Relative-age rendering wraps Lib.relTime (pure core) around the
  // receivedAt/now state tracked here.
  function relTime(n: var): string {
    if (!n)
      return "";
    var t = receivedAt[n.id];
    if (!t)
      return "";
    return Lib.relTime(t, server.now);
  }

  function ack(id: int): void {
    var next = Object.assign({}, server.acked);
    next[id] = true;
    server.acked = next;
  }
  function isAcked(id: int): bool {
    return acked[id] === true;
  }

  // notify-send/DBus semantics: expireTimeout 0 = never expire, < 0 (usually
  // -1) = server default -> urgency-based, > 0 = use the value verbatim.
  function expiryMs(n: var): int {
    var t = n.expireTimeout;
    if (t === 0)
      return 0;
    if (t > 0)
      return t;
    return n.urgency === NotificationUrgency.Critical ? 0 : (n.urgency === NotificationUrgency.Low ? 5000 : 10000);
  }

  function dismissAll(): void {
    for (const n of [...notifServer.trackedNotifications.values])
      n.dismiss();
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: server.now = new Date()
  }

  NotificationServer {
    id: notifServer
    bodySupported: true
    bodyMarkupSupported: true
    bodyImagesSupported: true
    imageSupported: true
    actionsSupported: true
    inlineReplySupported: true
    persistenceSupported: true
    keepOnReload: true

    onNotification: notification => {
      notification.tracked = true;
      var next = Object.assign({}, server.receivedAt);
      next[notification.id] = new Date();
      server.receivedAt = next;
    }
  }
}
