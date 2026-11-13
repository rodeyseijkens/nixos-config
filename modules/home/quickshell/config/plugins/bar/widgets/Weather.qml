import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../services"

Item {
  id: root
  readonly property string tempValue: WeatherService.temperature

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
      text: WeatherService.icon
      textFormat: Text.PlainText
      font.family: Colors.fontFamily
      font.pixelSize: 22
      font.bold: true
      color: Colors.base03
      opacity: hover.hovered ? 0.6 : 1.0
    }

    Text {
      id: tempText
      text: root.tempValue !== "" ? root.tempValue + WeatherService.temperatureUnit : ""
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
      if (mouse.button === Qt.MiddleButton) WeatherService.refresh()
      else OverlayPanels.toggleFrom(root, "weather")
    }
  }
}
