import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../../"
import "."

// Active notifications, quiet controls and config-backed preferences. Closed
// notifications are discarded; there is no Recent or History view.
Item {
  id: root

  property var bar: null
  property var settings: ({})
  property var defaultSettings: NotificationService.defaultSettings
  property string moduleName: "notifications"
  property bool showSettings: false

  readonly property var snoozeRows: {
    var out = []
    for (var key in NotificationService.snoozes)
      out.push({ key: key, until: NotificationService.snoozes[key] })
    return out.sort(function(a, b) { return a.key.localeCompare(b.key) })
  }
  readonly property bool hasAnything: NotificationService.toastRows.length > 0 || snoozeRows.length > 0

  readonly property string stateLine: {
    var bits = []
    if (NotificationService.dnd)
      bits.push("Do Not Disturb")
    else
      bits.push(NotificationService.toastRows.length + " active")
    if (snoozeRows.length > 0)
      bits.push(snoozeRows.length + (snoozeRows.length === 1 ? " source snoozed" : " sources snoozed"))
    return bits.join(" · ")
  }

  // The panel grows with its cards instead of reserving a fixed hole, up to
  // the height the screen can spare. Beyond that the list itself scrolls.
  readonly property real maxPanelHeight: Math.max(Style.space(360), Screen.height - Style.space(120))

  readonly property real activeListHeight: {
    var rows = NotificationService.toastRows
    var total = 0
    for (var i = 0; i < rows.length; i++) {
      total += (NotificationService.heights[rows[i].key] || Style.space(72))
      if (i < rows.length - 1)
        total += Style.spacing.sm
    }
    return Math.min(total, maxPanelHeight - Style.space(220))
  }

  implicitWidth: Style.space(380)
  implicitHeight: Math.min(maxPanelHeight, content.implicitHeight + Style.spacing.panelPadding * 2)

  function timeLeft(until) {
    var mins = Math.max(1, Math.ceil((Number(until) - Date.now() / 1000) / 60))
    if (mins < 60) return mins + "m"
    var hours = Math.floor(mins / 60)
    var rest = mins % 60
    return rest ? hours + "h " + rest + "m" : hours + "h"
  }

  function bellGlyph() {
    if (NotificationService.dnd) return "\u{f009b}"      // bell off
    if (snoozeRows.length > 0) return "\u{f00a0}"        // bell with Z
    return "\u{f009a}"                                   // bell
  }

  BorderSurface {
    anchors.fill: parent
    color: Colors.base01
    borderSpec: Border.flat(Colors.base04, 1)
    radius: Style.cornerRadius

    Column {
      id: content
      anchors.fill: parent
      anchors.margins: Style.spacing.panelPadding
      spacing: Style.spacing.sm

      PanelHero {
        width: parent.width
        title: root.showSettings ? "Notification settings" : "Notifications"
        meta: root.showSettings ? "PREFERENCES" : root.stateLine
        foreground: Colors.base05
        iconOpacity: NotificationService.dnd || root.snoozeRows.length > 0 ? 1 : 0.75

        iconComponent: Component {
          Item {
            implicitWidth: Style.font.displayLarge
            implicitHeight: Style.font.displayLarge

            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: root.bellGlyph()
              color: NotificationService.dnd ? Commons.Color.urgent
                   : root.snoozeRows.length > 0 ? Commons.Color.notifications.countdown
                   : Colors.base05
              font.family: Style.font.family
              font.pixelSize: Style.font.displayLarge
            }
          }
        }

        trailingControl: Component {
          Row {
            spacing: Style.space(4)

            PanelActionButton {
              anchors.verticalCenter: parent.verticalCenter
              visible: !root.showSettings && NotificationService.toastRows.length > 0
              iconText: "\u{f0187}"
              tooltipText: "Clear all notifications"
              foreground: Colors.base05
              onClicked: NotificationService.clear()
            }

            PanelActionButton {
              anchors.verticalCenter: parent.verticalCenter
              iconText: root.showSettings ? "\u{f0141}" : "\u{f0493}"
              tooltipText: root.showSettings ? "Done" : "Notification settings"
              foreground: Colors.base05
              onClicked: root.showSettings = !root.showSettings
            }

            ToggleSwitch {
              anchors.verticalCenter: parent.verticalCenter
              visible: !root.showSettings
              // On means notifications come through; off is Do Not Disturb.
              checked: !NotificationService.dnd
              onToggled: NotificationService.toggleDnd()
            }
          }
        }
      }

      // ---------------------------------------------------------- settings --
      Column {
        width: parent.width
        spacing: Style.spacing.sm
        visible: root.showSettings

        PanelSeparator { foreground: Colors.base05; width: parent.width }

        PanelSectionHeader {
          text: "PREFERENCES"
          foreground: Colors.base05
        }

        Row {
          width: parent.width
          height: Style.spacing.controlHeight
          spacing: Style.spacing.sm
          Text {
            width: parent.width - countdown.width - parent.spacing
            text: "Expiry progress bar"
            color: Colors.base05
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            anchors.verticalCenter: parent.verticalCenter
          }
          ToggleSwitch {
            id: countdown
            checked: NotificationService.option("showCountdown")
            onToggled: NotificationService.updateSettings({ showCountdown: !NotificationService.option("showCountdown") })
          }
        }

        Row {
          width: parent.width
          height: Style.spacing.controlHeight
          spacing: Style.spacing.sm
          Text {
            width: parent.width - sensitive.width - parent.spacing
            text: "Sensitive text"
            color: Colors.base05
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            anchors.verticalCenter: parent.verticalCenter
          }
          Button {
            id: sensitive
            text: NotificationService.option("sensitiveFilter")
            bordered: true
            onClicked: {
              var values = ["off", "mask", "redact"]
              var at = values.indexOf(NotificationService.option("sensitiveFilter"))
              NotificationService.updateSettings({ sensitiveFilter: values[(at + 1) % values.length] })
            }
          }
        }

        Row {
          width: parent.width
          height: Style.spacing.controlHeight
          spacing: Style.spacing.sm
          Text {
            width: parent.width - shareOffer.width - parent.spacing
            text: "Offer snooze while sharing"
            color: Colors.base05
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            anchors.verticalCenter: parent.verticalCenter
          }
          ToggleSwitch {
            id: shareOffer
            checked: NotificationService.option("offerSnoozeWhenSharing")
            onToggled: NotificationService.updateSettings({ offerSnoozeWhenSharing: !NotificationService.option("offerSnoozeWhenSharing") })
          }
        }
      }

      // ------------------------------------------------------- sharing offer --
      Column {
        width: parent.width
        visible: !root.showSettings && NotificationService.sharePrompt
        spacing: Style.spacing.xs

        PanelSeparator { foreground: Colors.base05; width: parent.width }
        PanelSectionHeader {
          text: "SHARING DETECTED"
          foreground: Colors.base05
        }
        Text {
          width: parent.width
          text: "Snooze notifications while sharing?"
          color: Qt.darker(Colors.base05, 1.4)
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }
        Row {
          spacing: Style.spacing.xs
          Repeater {
            model: NotificationService.snoozeOptions()
            Button {
              required property var modelData
              text: modelData.label
              bordered: true
              fontSize: Style.font.caption
              verticalPadding: Style.spacing.hairline
              onClicked: {
                NotificationService.snoozeAll(modelData.value)
                NotificationService.dismissSharePrompt()
              }
            }
          }
          Button {
            text: "Not now"
            bordered: true
            fontSize: Style.font.caption
            verticalPadding: Style.spacing.hairline
            onClicked: NotificationService.dismissSharePrompt()
          }
        }
      }

      // ------------------------------------------------------ active cards --
      Column {
        width: parent.width
        spacing: Style.spacing.xs
        visible: !root.showSettings

        PanelSeparator { foreground: Colors.base05; width: parent.width }

        Item {
          width: parent.width
          height: Math.max(activeHeading.implicitHeight, Style.space(18))

          PanelSectionHeader {
            id: activeHeading
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "ACTIVE · " + NotificationService.toastRows.length
            foreground: Colors.base05
          }
        }

        Text {
          width: parent.width
          visible: NotificationService.toastRows.length === 0
          text: "No active notifications."
          color: Qt.darker(Colors.base05, 1.4)
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        ListView {
          id: list
          width: parent.width
          height: root.activeListHeight
          visible: NotificationService.toastRows.length > 0
          clip: true
          spacing: Style.spacing.sm
          boundsBehavior: Flickable.StopAtBounds
          model: ScriptModel { values: NotificationService.toastRows }

          delegate: Toast {
            id: liveCard
            required property var modelData
            // A delegate can outlive its row for a frame while it leaves;
            // the empty snapshot keeps every binding below from reading null.
            row: modelData || ({})
            cardWidth: ListView.view ? ListView.view.width : Style.space(300)
            place: ({ y: 0, scale: 1, opacity: 1, z: 1, front: true, hidden: false, height: 0 })
            scene: null
            sole: true
            paused: true
            now: NotificationService.now
            actions: {
              NotificationService.refsRevision;
              return NotificationService.actionsFor(row.key);
            }
            snoozeChoices: NotificationService.snoozeOptions()
            expanded: NotificationService.openGroup === "" || NotificationService.openGroup === NotificationService.groupKeyFor(row)
            groupCount: NotificationService.groupCountFor(row)
            deckFront: true
            onTargetHeightChanged: NotificationService.noteHeight(row.key, targetHeight)
            Component.onCompleted: NotificationService.noteHeight(row.key, targetHeight)
            onActivated: NotificationService.activate(row.key)
            onDismissed: NotificationService.dismiss(row.key)
            onGroupToggled: NotificationService.toggleGroupFor(row)
            onActionInvoked: function(identifier) { NotificationService.invokeAction(row.key, identifier); }
            onExecInvoked: function(index) { NotificationService.runExecAction(row.key, index); }
            onCodeCopied: function(code) { NotificationService.copyCode(code); }
            onReplySubmitted: function(text) {
              if (NotificationService.sendInlineReply(row.key, text))
                NotificationService.dismiss(row.key)
            }
            onSnoozeRequested: function(duration) { NotificationService.snoozeSource(row, duration) }
          }
        }
      }

      // ---------------------------------------------------- snoozed sources --
      Column {
        width: parent.width
        spacing: Style.spacing.xs
        visible: !root.showSettings

        PanelSeparator { foreground: Colors.base05; width: parent.width }

        PanelSectionHeader {
          text: "SNOOZED SOURCES"
          foreground: Colors.base05
        }

        Text {
          width: parent.width
          visible: root.snoozeRows.length === 0
          text: "No snoozed sources. Snooze a source from its notification card."
          color: Qt.darker(Colors.base05, 1.4)
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Repeater {
          model: root.snoozeRows
          Row {
            required property var modelData
            width: parent.width
            spacing: Style.spacing.sm
            Text {
              width: parent.width - wake.width - parent.spacing
              text: NotificationService.sourceLabel(modelData.key) + " · " + root.timeLeft(modelData.until)
              color: Colors.base05
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              anchors.verticalCenter: parent.verticalCenter
            }
            Button {
              id: wake
              text: "Wake"
              bordered: true
              fontSize: Style.font.caption
              verticalPadding: Style.spacing.hairline
              onClicked: NotificationService.unsnoozeSource(modelData.key)
            }
          }
        }

        Button {
          visible: root.snoozeRows.length > 1
          text: "Wake all"
          bordered: true
          fontSize: Style.font.caption
          verticalPadding: Style.spacing.hairline
          onClicked: NotificationService.unsnoozeAll()
        }
      }
    }
  }
}
