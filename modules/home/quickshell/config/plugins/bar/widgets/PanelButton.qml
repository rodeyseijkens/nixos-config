import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Io
import "../../../"
import "../../../services"

Item {
  id: root
  required property var barScreen
  property string panel: ""
  property string glyph: ""
  property string iconSource: ""
  property string requireCommand: ""
  property bool commandAvailable: requireCommand === ""
  property bool available: true
  readonly property color activeTint: "#FE8019"
  readonly property color hoverTint: "#D79921"
  readonly property color iconTint: buttonMouse.containsMouse
    ? hoverTint
    : (OverlayPanels.isOpen(panel, barScreen ? barScreen.name : "") ? activeTint : Colors.base05)

  Layout.leftMargin: 6
  Layout.rightMargin: 6
  implicitWidth: iconSource !== "" ? 16 : glyphText.implicitWidth
  implicitHeight: Math.max(16, glyphText.implicitHeight)
  visible: available && (requireCommand === "" || commandAvailable)

  function checkCommand() {
    if (root.requireCommand === "") {
      root.commandAvailable = true;
      return;
    }
    if (executableCheck.running)
      return;
    root.commandAvailable = false;
    executableCheck.command = ["which", root.requireCommand];
    executableCheck.running = true;
  }

  onRequireCommandChanged: Qt.callLater(checkCommand)
  Component.onCompleted: checkCommand()

  Text {
    id: glyphText
    anchors.fill: parent
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    visible: iconImage.status !== Image.Ready
    text: root.glyph
    font.family: Colors.fontFamily
    font.pixelSize: 14
    color: root.iconTint
  }

  Image {
    id: iconImage
    anchors.centerIn: parent
    width: 16
    height: 16
    source: root.iconSource
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    layer.enabled: root.iconSource !== ""
    layer.effect: MultiEffect {
      colorization: 1
      colorizationColor: root.iconTint
    }
  }

  MouseArea {
    id: buttonMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: OverlayPanels.toggleFrom(root, root.panel)
  }

  Process {
    id: executableCheck
    command: []
    onExited: function(exitCode) {
      root.commandAvailable = exitCode === 0;
    }
  }
}
