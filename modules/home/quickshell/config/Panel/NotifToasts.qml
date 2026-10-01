import Quickshell
import QtQuick
import QtQuick.Layouts
import "../Services"
import "../"

// Toast feed: the stack of transient notification cards in the top-right
// corner of each monitor; expired toasts move to the notification panel's
// history rather than vanishing.
Scope {
  id: toasts

  ScreenPopup {
    placement: PopupPlacement {
      top: true
      right: true
      marginTop: 15
      marginRight: 15
      width: 300
    }
    // swaync parity: DND suppresses the popups entirely — the notification
    // still lands in the panel's history.
    showWhen: (name) => !Preferences.dnd && NotifServer.toasts.length > 0

    content: Component {
      ColumnLayout {
        id: toastCol
        implicitWidth: 300
        spacing: 8

        Repeater {
          model: ScriptModel {
            values: NotifServer.toasts
          }

          Item {
            required property var modelData
            property var n: modelData
            Layout.preferredWidth: 300
            Layout.preferredHeight: card.implicitHeight

            Timer {
              // Expiry policy lives in NotifServer (expiryMs): notify-send/DBus
              // semantics + urgency matrix; expiry ACKS — moves the card to the
              // panel's history. Full dismissal happens only via ✕ / Clear All.
              interval: NotifServer.expiryMs(n)
              running: interval > 0
              repeat: false
              onTriggered: {
                NotifServer.ack(n.id);
              }
            }

            NotifCard {
              id: card
              anchors.fill: parent
              n: parent.n
            }

            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.RightButton
              onClicked: n.dismiss()
            }
          }
        }
      }
    }
  }
}
