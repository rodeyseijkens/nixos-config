import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

import "."

// PanelContent: notification history for PanelHost. It is loaded when
// OverlayPanels.toggle("notifications", screen) runs. The panel lists live
// notifications and the closed-history store newest first, with inline
// actions, markup bodies, Clear All and Do Not Disturb.
Item {
  id: root

  // Injected by PanelHost when present.
  property var bar: null
  property var settings: ({})
  property string moduleName: "notifications"

  implicitWidth: Style.space(340)
  implicitHeight: Style.space(520)

  BorderSurface {
    anchors.fill: parent
    color: Commons.Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, 1)
    radius: Style.cornerRadius

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.spacing.panelPadding
      spacing: Style.spacing.md

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.md

        Text {
          Layout.fillWidth: true
          text: I18n.t("notifications.title", "Notifications")
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.bold: true
          elide: Text.ElideRight
        }

        Button {
          text: I18n.t("notifications.clearAll", "Clear All")
          bordered: true
          onClicked: NotificationService.clear()
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
          id: list
          anchors.fill: parent
          clip: true
          spacing: Style.spacing.sm
          boundsBehavior: Flickable.StopAtBounds
          model: ScriptModel {
            values: NotificationService.entries
          }

          delegate: Toast {
            id: historyCard
            required property var modelData

            row: modelData
            cardWidth: ListView.view ? ListView.view.width : Style.space(300)
            place: ({ y: 0, scale: 1, opacity: 1, z: 1, front: true, hidden: false, height: 0 })
            scene: null
            expanded: true
            sole: true
            hovered: true
            paused: true
            now: NotificationService.now
            actions: {
              NotificationService.refsRevision;
              return NotificationService.actionsFor(row.key);
            }

            onActivated: NotificationService.activate(row.key)
            onDismissed: NotificationService.dismiss(row.key)
            onActionInvoked: function(identifier) { NotificationService.invokeAction(row.key, identifier); }
            onExecInvoked: function(index) { NotificationService.runExecAction(row.key, index); }
            onCodeCopied: function(code) { NotificationService.copyCode(code); }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: NotificationService.entries.length === 0
          text: I18n.t("notifications.noneRecent", "No notifications")
          color: Commons.Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.md

        Text {
          Layout.fillWidth: true
          text: I18n.t("notifications.doNotDisturb", "Do Not Disturb")
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }

        ToggleSwitch {
          checked: NotificationService.dnd
          onToggled: NotificationService.toggleDnd()
        }
      }
    }
  }
}
