import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

// Metric cell used in the METRICS section: label + description on the left,
// value + unit on the right, and a thin theme-accent level bar underneath.
// The subtle rounded fill (foreground at 20% alpha, matching the hourly
// strip's NOW cell) groups each metric.
Rectangle {
  id: card

  required property string label
  required property string value
  property string unit: ""
  property string desc: ""
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  // Secondary text role — see Panel.qml dimText: alpha on the primary
  // foreground rather than the muted token, which reads poorly on the popup
  // surface.
  readonly property color dim: Util.alpha(foreground, 0.8)
  property color barColor: Commons.Color.accent
  // 0..1 bar level; -1 hides the bar (e.g. wind, which shows an arrow instead).
  property real barLevel: -1
  // Wind direction in degrees; -1 hides the arrow. The arrow points the
  // direction the wind comes FROM, matching the desc label (e.g. "South").
  property real arrowAngle: -1
  property real pad: Style.space(10)
  // Right-side value font size; overridable so a card can match its neighbours.
  property int valuePixelSize: Style.font.title

  radius: Math.min(4, Style.cornerRadius)
  color: Qt.rgba(card.foreground.r, card.foreground.g, card.foreground.b, 0.05)

  implicitWidth: content.implicitWidth + pad * 2
  implicitHeight: content.implicitHeight + pad * 2

  Column {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: card.pad
    anchors.rightMargin: card.pad
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(5)

    RowLayout {
      width: parent.width
      spacing: Style.space(8)

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: card.label
          color: card.foreground
          font.family: card.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          visible: card.desc !== ""
          text: card.desc
          color: card.dim
          font.family: card.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: card.arrowAngle >= 0
        text: "↑"
        color: card.foreground
        font.family: card.fontFamily
        font.pixelSize: Style.font.body
        rotation: card.arrowAngle
        Layout.alignment: Qt.AlignVCenter
      }

      Row {
        spacing: Style.space(2)
        Layout.alignment: Qt.AlignVCenter

        Text {
          textFormat: Text.PlainText
          id: valText
          text: card.value
          color: card.foreground
          font.family: card.fontFamily
          font.pixelSize: card.valuePixelSize
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText
          visible: card.unit !== ""
          text: card.unit
          color: card.dim
          font.family: card.fontFamily
          font.pixelSize: Style.font.bodySmall
          anchors.baseline: valText.baseline
        }
      }
    }

    Rectangle {
      visible: card.barLevel >= 0
      width: parent.width
      height: Style.space(3)
      radius: Math.min(2, Style.cornerRadius)
      color: Qt.rgba(card.foreground.r, card.foreground.g, card.foreground.b, 0.1)

      Rectangle {
        width: parent.width * Math.max(0, Math.min(1, card.barLevel))
        height: parent.height
        radius: parent.radius
        color: card.barColor
      }
    }
  }
}