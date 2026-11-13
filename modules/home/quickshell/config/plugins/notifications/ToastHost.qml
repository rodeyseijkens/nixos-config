import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

import "../../services"
import "."

// ToastHost: the transient notification deck. One ScreenPopup per monitor,
// bottom-right, clearing the bar; ScreenPopup owns the layer surface so this
// file never hand-rolls a per-screen layer surface.
//
// Integrate with: ToastHost {}
Scope {
  id: root

  // The bar subset is injected by the shell, exactly like other ported
  // widgets. The default keeps the host runnable during development.
  property var bar: BarApi {}

  // A reply field in the deck needs the keyboard, so the layer surface takes
  // focus only while one is open. Outside that the deck stays non-focusable,
  // which keeps it from stealing keys from the window you are typing in.
  property bool replying: false

  // Room between the bar and the bottom gap, less the popup's own margins.
  readonly property real availableHeight: Math.max(Style.space(200),
    Screen.height - (root.bar && root.bar.barHidden ? 0 : (root.bar ? root.bar.barSize : Style.bar.sizeHorizontal))
      - Style.gapsOut * 2 - Style.space(24))
  onAvailableHeightChanged: NotificationService.deckMaxHeight = availableHeight
  Component.onCompleted: {
    NotificationService.deckMaxHeight = availableHeight
    NotificationService.panelOpen = OverlayPanels.active === "notifications"
  }

  // The service keeps rows that have been seen in the panel out of the deck.
  // Mirror the panel state so opening it takes every current row over.

  Connections {
    target: OverlayPanels
    function onActiveChanged(): void {
      NotificationService.panelOpen = OverlayPanels.active === "notifications"
    }
  }

  ScreenPopup {
    placement: PopupPlacement {
      bottom: true
      right: true
      marginBottom: (root.bar && root.bar.barHidden ? 0 : (root.bar ? root.bar.barSize : Style.bar.sizeHorizontal)) + Style.gapsOut
      marginRight: Style.gapsOut
      width: NotificationService.notificationWidth
      height: -1
    }
    // While the notification panel is open the deck is not drawn at all: the
    // active notifications live in the panel's list, so the two never show the
    // same cards twice.
    showWhen: name => NotificationService.deckCount > 0
      && name === NotificationService.targetDisplayName
      && OverlayPanels.active !== "notifications"
    focusable: root.replying
    focusGrab: false

    content: Component {
      Item {
        id: deck
        anchors.fill: parent
        implicitWidth: NotificationService.notificationWidth
        // Never taller than the space under the bar: a long list of stacks is
        // clipped at the bottom rather than running off the top of the screen.
        // The rows themselves are untouched, so the panel still shows them.
        implicitHeight: Math.min(NotificationService.layout.height, root.availableHeight)
        clip: true



        Repeater {
          model: ScriptModel {
            values: NotificationService.deckRows
          }

          Toast {
            id: card
            required property var modelData

            // A delegate can outlive its row for a frame while it leaves;
            // the empty snapshot keeps every binding below from reading null.
            row: modelData || ({})
            place: NotificationService.layout.placements[row.key] || ({
              y: 0, scale: 1, opacity: 1, z: 1, front: true, hidden: false, height: 0
            })

            x: 0
            y: place.y
            z: place.z
            scale: place.scale
            opacity: place.hidden ? 0 : place.opacity
            // A shut stack is the front card plus the edges it draws; the
            // cards behind it only join in when the stack is opened. Rows
            // already seen in the panel never come back to the deck.
            visible: !place.hidden && (NotificationService.groupExpanded || place.front)
            enabled: !place.hidden

            cardWidth: NotificationService.notificationWidth
            scene: null
            expanded: NotificationService.isDeckOpen(row)
            sole: NotificationService.deckCount === 1
            // Reading them in the panel is still reading them: nothing expires
            // out from under a card that is on screen there.
            paused: OverlayPanels.active === "notifications"
            now: NotificationService.now
            actions: {
              NotificationService.refsRevision;
              return NotificationService.actionsFor(row.key);
            }
            snoozeChoices: NotificationService.snoozeOptions()

            groupCount: NotificationService.groupCountFor(row)
            deckFront: NotificationService.deckFrontKeys[row.key] === true
            showCountdown: NotificationService.option("showCountdown")
            onTargetHeightChanged: NotificationService.noteHeight(row.key, targetHeight)
            Component.onCompleted: NotificationService.noteHeight(row.key, targetHeight)
            onReplyOpenChanged: root.replying = replyOpen
            Component.onDestruction: if (replyOpen) root.replying = false
            onExpired: NotificationService.expire(row.key)
            onDismissed: NotificationService.dismissStackFor(row)
            onActivated: NotificationService.activate(row.key)
            onGroupToggled: NotificationService.toggleGroupFor(row)
            onSnoozeRequested: function(duration) { NotificationService.snoozeSource(row, duration) }
            onReplySubmitted: function(text) {
              if (NotificationService.sendInlineReply(row.key, text))
                NotificationService.dismiss(row.key)
            }
            onActionInvoked: function(identifier) { NotificationService.invokeAction(row.key, identifier); }
            onExecInvoked: function(index) { NotificationService.runExecAction(row.key, index); }
            onCodeCopied: function(code) { NotificationService.copyCode(code); }
          }
        }
      }
    }
  }

  IpcHandler {
    target: "notif"

    function toggle(): void {
      NotificationService.togglePanel()
    }

    function open(): void {
      OverlayPanels.open("notifications", NotificationService.targetDisplayName)
    }

    function close(): void {
      if (OverlayPanels.active === "notifications") OverlayPanels.close()
    }

    function clear(): void {
      NotificationService.clear()
    }
  }
}
