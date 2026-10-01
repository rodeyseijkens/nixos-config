import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../"

RowLayout {
  id: root
  spacing: 8
  Layout.leftMargin: 10
  Layout.rightMargin: 10

  Repeater {
    model: SystemTray.items

    IconImage {
      required property SystemTrayItem modelData
      Layout.preferredWidth: 20
      Layout.preferredHeight: 20
      source: modelData.icon

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: modelData.hasMenu ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => {
          if (mouse.button === Qt.LeftButton)
            modelData.activate();
          else if (mouse.button === Qt.MiddleButton)
            modelData.secondaryActivate();
          else if (modelData.hasMenu)
            menuAnchor.open();
        }
      }

      QsMenuAnchor {
        id: menuAnchor
        menu: modelData.menu
        anchor.window: root.QsWindow.window
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
      }
    }
  }
}
