import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../../../"

// System tray with an inline DBusMenu popup. Submenus drill down through
// nested QsMenuOpener objects instead of QsMenuEntry.display(), which needs
// QApplication mode and silently no-ops in Quickshell otherwise.
RowLayout {
  id: root
  spacing: 0
  Layout.leftMargin: 6
  Layout.rightMargin: 4

  property bool menuOpen: false
  property var activeItem: null
  property Item activeAnchor: null
  property var submenuStack: []

  readonly property var currentChildren: submenuStack.length > 0
    ? submenuStack[submenuStack.length - 1].opener.children
    : trayMenuOpener.children
  readonly property string currentTitle: submenuStack.length > 0
    ? submenuStack[submenuStack.length - 1].title : ""
  readonly property int submenuDepth: submenuStack.length

  Component {
    id: submenuOpenerComponent
    QsMenuOpener {}
  }

  QsMenuOpener {
    id: trayMenuOpener
    menu: root.activeItem ? root.activeItem.menu : null
  }

  function iconIsSymbolic(icon) {
    var name = String(icon || "").split("?")[0];
    return name.slice(-9) === "-symbolic";
  }

  function openMenu(item, anchorItem) {
    resetMenu();
    activeItem = item;
    activeAnchor = anchorItem;
    menuOpen = true;
    closeMenuTimer.restart();
  }

  function resetMenu() {
    var openers = submenuStack;
    submenuStack = [];
    for (var i = openers.length - 1; i >= 0; i--)
      openers[i].opener.destroy();
  }

  function closeMenu() {
    resetMenu();
    menuOpen = false;
    closeMenuTimer.stop();
    activeItem = null;
    activeAnchor = null;
  }

  function enterSubmenu(entry) {
    var opener = submenuOpenerComponent.createObject(root, {menu: entry});
    if (!opener)
      return;
    submenuStack = submenuStack.concat([{opener: opener, title: String(entry.text || "")}]);
  }

  function leaveSubmenu() {
    if (submenuStack.length === 0)
      return;
    var stack = submenuStack.slice();
    var top = stack.pop();
    submenuStack = stack;
    top.opener.destroy();
  }

  Timer {
    id: closeMenuTimer
    interval: 500
    onTriggered: root.closeMenu()
  }

  component TrayIcon: Item {
    id: trayIconRoot
    required property var icon

    Image {
      id: trayIconImage
      anchors.fill: parent
      fillMode: Image.PreserveAspectFit
      smooth: true
      sourceSize.width: Math.round(Math.min(width, height) * Screen.devicePixelRatio)
      sourceSize.height: Math.round(Math.min(width, height) * Screen.devicePixelRatio)
      source: String(trayIconRoot.icon || "")
      layer.enabled: true
      layer.effect: MultiEffect {
        colorization: 1
        colorizationColor: Colors.base05
      }
    }
  }

  Repeater {
    model: SystemTray.items

    Item {
      id: trayItemRoot
      required property var modelData
      readonly property bool visibleItem: modelData.status !== Status.Passive
      visible: visibleItem
      implicitWidth: visibleItem ? 24 : 0
      implicitHeight: visibleItem ? 24 : 0
      Layout.preferredWidth: implicitWidth
      Layout.preferredHeight: implicitHeight

      TrayIcon {
        anchors.centerIn: parent
        width: 16
        height: 16
        icon: trayItemRoot.modelData.icon
      }

      MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tooltip.show(trayItemRoot, String(trayItemRoot.modelData.tooltipTitle || trayItemRoot.modelData.title || trayItemRoot.modelData.id || ""))
        onExited: tooltip.hide()
        onPressed: mouse => {
          if (mouse.button === Qt.RightButton) {
            root.openMenu(trayItemRoot.modelData, trayItemRoot);
            mouse.accepted = true;
          }
        }
        onClicked: mouse => {
          if (mouse.button === Qt.RightButton) {
            mouse.accepted = true;
          } else if (mouse.button === Qt.MiddleButton) {
            trayItemRoot.modelData.secondaryActivate();
          } else if (trayItemRoot.modelData.onlyMenu) {
            root.openMenu(trayItemRoot.modelData, trayItemRoot);
          } else {
            trayItemRoot.modelData.activate();
          }
        }
        onWheel: wheel => trayItemRoot.modelData.scroll(wheel.angleDelta.y, false)
      }
    }
  }

  PopupWindow {
    id: menuWindow
    visible: root.menuOpen
    grabFocus: root.menuOpen
    anchor {
      window: root.activeAnchor ? root.activeAnchor.QsWindow.window : null
      item: root.activeAnchor
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      adjustment: PopupAdjustment.Slide
    }
    implicitWidth: 230
    implicitHeight: menuColumn.implicitHeight + 8
    color: "transparent"

    FocusScope {
      anchors.fill: parent
      focus: root.menuOpen

      Keys.onEscapePressed: event => {
        event.accepted = true;
        root.closeMenu();
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Colors.base00
      border.color: Colors.base04
      border.width: 1

      HoverHandler {
        onHoveredChanged: {
          if (!root.menuOpen)
            return;
          if (hovered)
            closeMenuTimer.stop();
          else
            closeMenuTimer.restart();
        }
      }

      Column {
        id: menuColumn
        width: parent.width
        anchors.top: parent.top
        anchors.topMargin: 4

        Item {
          visible: root.submenuDepth > 0
          width: menuColumn.width
          height: visible ? 26 : 0

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "‹ " + root.currentTitle
            font.family: Colors.fontFamily
            font.pixelSize: 12
            font.bold: true
            color: Colors.base0D
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onEntered: closeMenuTimer.stop()
            onExited: closeMenuTimer.restart()
            onClicked: root.leaveSubmenu()
          }
        }

        Repeater {
          model: root.currentChildren

          Item {
            id: row
            required property var modelData
            readonly property bool hovered: rowMouse.containsMouse
            width: menuColumn.width
            height: modelData.isSeparator ? 7 : 26

            Rectangle {
              anchors.fill: parent
              visible: !row.modelData.isSeparator && row.hovered
              color: Colors.base02
            }

            Rectangle {
              visible: row.modelData.isSeparator
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              height: 1
              color: Colors.base03
            }

            Text {
              visible: !row.modelData.isSeparator
              anchors.left: parent.left
              anchors.leftMargin: 10
              anchors.right: chevron.left
              anchors.rightMargin: 6
              anchors.verticalCenter: parent.verticalCenter
              text: (row.modelData.checkState === Qt.Checked ? "✓ " : "") + String(row.modelData.text || "")
              elide: Text.ElideRight
              font.family: Colors.fontFamily
              font.pixelSize: 12
              color: row.modelData.enabled ? Colors.base05 : Colors.base03
            }

            Text {
              id: chevron
              visible: !row.modelData.isSeparator && row.modelData.hasChildren
              anchors.right: parent.right
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              text: "›"
              font.family: Colors.fontFamily
              font.pixelSize: 13
              color: Colors.base04
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              enabled: !row.modelData.isSeparator && row.modelData.enabled
              hoverEnabled: true
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onEntered: closeMenuTimer.stop()
              onExited: closeMenuTimer.restart()
              onClicked: {
                if (row.modelData.hasChildren) {
                  root.enterSubmenu(row.modelData);
                } else {
                  row.modelData.triggered();
                  root.closeMenu();
                }
              }
            }
          }
        }
      }
    }
  }

  PopupWindow {
    id: tooltip
    property string text: ""
    property Item target: null
    visible: text !== "" && target !== null
    anchor {
      window: tooltip.target ? tooltip.target.QsWindow.window : null
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.width: 1
      rect.height: 1

      onAnchoring: {
        if (!tooltip.target)
          return;
        var targetItem = tooltip.target;
        var window = targetItem.QsWindow.window;
        if (!window)
          return;
        var localX = targetItem.width / 2 - tooltip.implicitWidth / 2;
        var localY = -tooltip.implicitHeight - 4;
        var point = window.contentItem.mapFromItem(targetItem, localX, localY);
        tooltip.anchor.rect.x = Math.round(point.x);
        tooltip.anchor.rect.y = Math.round(point.y);
      }
    }
    implicitWidth: tooltipText.implicitWidth + 16
    implicitHeight: tooltipText.implicitHeight + 8
    color: "transparent"

    function show(item, value) {
      if (value === "")
        return;
      target = item;
      text = value;
    }

    function hide() {
      text = "";
      target = null;
    }

    Rectangle {
      anchors.fill: parent
      color: Colors.base01
      border.color: Colors.base04
      border.width: 1

      Text {
        id: tooltipText
        anchors.centerIn: parent
        text: tooltip.text
        font.family: Colors.fontFamily
        font.pixelSize: 11
        color: Colors.base05
      }
    }
  }

}
