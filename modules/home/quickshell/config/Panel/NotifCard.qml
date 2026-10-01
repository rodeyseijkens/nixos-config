import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../Services"
import "../"

// Shared notification card used by both the floating toasts and the
// control-center panel: base01 square card, 4px urgency bar, bold 14px
// summary + bold 14px "app · time" + regular 14px wrapping body,
// 200x100 image, inline reply, action buttons, circular base02 ✕.
Rectangle {
  id: root
  required property var n
  // width the text column loses to card chrome: column margins (4+4), row
  // margins (4+4), close button (20) and the gap before it (8)
  readonly property real chromeWidth: 8 + 8 + 20 + 8

  color: Colors.base01
  border.width: 0
  implicitHeight: cardCol.implicitHeight + 8

  Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 4
    color: root.n.urgency === NotificationUrgency.Critical ? Colors.base08 : (root.n.urgency === NotificationUrgency.Low ? Colors.base04 : Colors.base0B)
  }

  ColumnLayout {
    id: cardCol
    anchors.fill: parent
    anchors.margins: 4
    spacing: 4

    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: 4
      Layout.rightMargin: 4
      Layout.topMargin: 4
      spacing: 8
      ColumnLayout {
        Layout.fillWidth: true
        Layout.maximumWidth: root.width - root.chromeWidth
        spacing: 0
        Text {
          Layout.fillWidth: true
          text: root.n.summary
          font.bold: true
          font.pixelSize: 14
          font.family: Colors.fontFamily
          color: Colors.base04
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          text: root.n.appName + (NotifServer.relTime(root.n) !== "" ? " · " + NotifServer.relTime(root.n) : "")
          font.bold: true
          font.pixelSize: 14
          font.family: Colors.fontFamily
          color: Colors.base04
          elide: Text.ElideRight
          visible: text !== ""
        }
        Text {
          Layout.fillWidth: true
          text: root.n.body
          font.pixelSize: 14
          font.family: Colors.fontFamily
          color: Colors.base04
          wrapMode: Text.WrapAtWordBoundaryOrAnywhere
          visible: root.n.body !== ""
        }
      }
      Rectangle {
        Layout.preferredWidth: 20
        Layout.preferredHeight: 20
        Layout.alignment: Qt.AlignTop
        radius: 0
        color: closeMouse.containsMouse ? Colors.base03 : Colors.base02
        Text {
          anchors.centerIn: parent
          text: "✕"
          font.pixelSize: 10
          font.family: Colors.fontFamily
          color: Colors.base04
        }
        MouseArea {
          id: closeMouse
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true
          onClicked: root.n.dismiss()
        }
      }
    }

    Image {
      Layout.preferredWidth: 200
      Layout.preferredHeight: 100
      Layout.leftMargin: 4
      Layout.topMargin: 4
      fillMode: Image.PreserveAspectFit
      source: root.n.image
      visible: root.n.image !== ""
    }

    RowLayout {
      visible: root.n.hasInlineReply
      Layout.fillWidth: true
      Layout.leftMargin: 4
      Layout.rightMargin: 4
      Layout.topMargin: 4
      spacing: 4
      TextField {
        id: replyField
        Layout.fillWidth: true
        Layout.maximumWidth: root.width - root.chromeWidth - 70
        placeholderText: root.n.inlineReplyPlaceholder !== "" ? root.n.inlineReplyPlaceholder : "Reply…"
        font.family: Colors.fontFamily
        color: Colors.base04
        background: Rectangle {
          color: Colors.base01
          border.color: Colors.base01
          border.width: 1
        }
      }
      FlatButton {
        text: "Send"
        onClicked: {
          root.n.sendInlineReply(replyField.text);
          replyField.text = "";
        }
      }
    }

    Repeater {
      model: root.n.actions
      FlatButton {
        required property var modelData
        Layout.fillWidth: true
        text: modelData.text
        onClicked: modelData.invoke()
      }
    }
  }
}
