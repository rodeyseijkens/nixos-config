import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"

// swaync parity: .widget-title > button — flat bg-primary, 1px base03 border,
// 3px 10px padding, bold 14px base04 text, hover fills base01.
Button {
  id: root
  font.family: Colors.fontFamily
  font.bold: true
  font.pixelSize: 14

  background: Rectangle {
    color: root.hovered ? Colors.base01 : Colors.base00
    border.color: Colors.base03
    border.width: 1
  }

  contentItem: Text {
    text: root.text
    font: root.font
    color: Colors.base04
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  leftPadding: 10
  rightPadding: 10
  topPadding: 3
  bottomPadding: 3
}
