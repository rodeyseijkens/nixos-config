import QtQuick
import Quickshell
import qs.Commons

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

  ScreenPopup {
    placement: PopupPlacement {
      bottom: true
      right: true
      marginBottom: (root.bar && root.bar.barHidden ? 0 : (root.bar ? root.bar.barSize : Style.bar.sizeHorizontal)) + Style.gapsOut
      marginRight: Style.gapsOut
      width: NotificationService.notificationWidth
      height: -1
    }
    showWhen: name => NotificationService.toastRows.length > 0
      && name === NotificationService.targetDisplayName
    focusable: false
    focusGrab: false

    content: Component {
      Item {
        id: deck
        anchors.fill: parent
        implicitWidth: NotificationService.notificationWidth
        implicitHeight: NotificationService.layout.height

        Repeater {
          model: ScriptModel {
            values: NotificationService.toastRows
          }

          Toast {
            id: card
            required property var modelData

            row: modelData
            place: NotificationService.layout.placements[row.key] || ({
              y: 0, scale: 1, opacity: 1, z: 1, front: true, hidden: false, height: 0
            })

            x: 0
            y: place.y
            z: place.z
            scale: place.scale
            opacity: place.hidden ? 0 : place.opacity
            visible: !place.hidden
            enabled: !place.hidden

            cardWidth: NotificationService.notificationWidth
            scene: null
            expanded: false
            sole: NotificationService.toastRows.length === 1
            hovered: false
            now: NotificationService.now
            actions: {
              NotificationService.refsRevision;
              return NotificationService.actionsFor(row.key);
            }

            onImplicitHeightChanged: NotificationService.noteHeight(row.key, implicitHeight)
            onExpired: NotificationService.expire(row.key)
            onDismissed: NotificationService.dismiss(row.key)
            onActivated: OverlayPanels.toggle("notifications", NotificationService.targetDisplayName)
            onActionInvoked: function(identifier) { NotificationService.invokeAction(row.key, identifier); }
            onExecInvoked: function(index) { NotificationService.runExecAction(row.key, index); }
            onCodeCopied: function(code) { NotificationService.copyCode(code); }
          }
        }
      }
    }
  }
}
