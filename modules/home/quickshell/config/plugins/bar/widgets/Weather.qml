import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../services"

Item {
  id: root
  required property var barScreen
  readonly property string tempValue: WeatherCache.barTempC !== "" ? WeatherCache.barTempC : WeatherStatus.tempC

  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight
  width: content.implicitWidth
  height: content.implicitHeight

  RowLayout {
    id: content
    anchors.fill: parent
    spacing: 4

    Text {
      id: iconText
      text: WeatherCache.barGlyph !== "" ? WeatherCache.barGlyph : WeatherStatus.icon
      textFormat: Text.PlainText
      font.family: Colors.fontFamily
      font.pixelSize: 22
      font.bold: true
      color: Colors.base03
      opacity: hover.hovered ? 0.6 : 1.0
    }

    Text {
      id: tempText
      text: root.tempValue !== "" ? root.tempValue + WeatherCache.barTempUnit : ""
      textFormat: Text.PlainText
      font.family: Colors.fontFamily
      font.pixelSize: 16
      font.bold: true
      color: Colors.base05
      opacity: hover.hovered ? 0.6 : 1.0
    }
  }

  HoverHandler {
    id: hover
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (mouse.button === Qt.MiddleButton) WeatherStatus.refresh()
      else OverlayPanels.toggle("weather", root.barScreen ? root.barScreen.name : "")
    }
  }
}
