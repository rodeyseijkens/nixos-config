import QtQuick
import Quickshell
import ".."
import qs.Commons

// BarApi: the small surface of the the shell bar that ported widgets and panels
// actually read. One instance is injected as `bar` into vendored components,
// so they keep their upstream shape without pulling in the plugin host.
QtObject {
  id: root

  readonly property bool vertical: false
  readonly property int barSize: Style.bar.sizeHorizontal
  readonly property int sizeHorizontal: Style.bar.sizeHorizontal
  readonly property int sizeVertical: Style.bar.sizeVertical
  readonly property int iconSlot: Style.bar.iconSlot
  readonly property int statusSlot: Style.bar.statusSlot
  readonly property int iconSize: Style.bar.iconSize
  readonly property int iconFont: Style.bar.iconFont

  readonly property string fontFamily: Colors.fontFamily
  readonly property color foreground: Colors.base05
  readonly property color barForeground: Colors.base05
  readonly property color urgent: Colors.base08
  readonly property color background: Colors.base00
  readonly property bool barHidden: false
  readonly property bool hideTooltip: false
  readonly property bool traySectionDragActive: false
  readonly property bool traySectionPopoutOpen: false
  readonly property var layoutConfig: ({})
  property bool centerHoverRevealSuppressed: false

  readonly property QtObject shell: QtObject {
    function updateEntryInline(name, values) {
      PanelSettings.write(name, values)
    }
    function summon(name, payload) {
      if (name === "osd") {
        OsdBus.show(payload)
        return
      }
      console.warn("BarApi.shell.summon: unknown target " + String(name || ""))
    }
  }

  function run(command: var): void {
    Quickshell.execDetached(Array.isArray(command) ? command : [String(command)]);
  }

  function switchPanelFrom(_panel: var, _direction: var): bool {
    return false;
  }

  function moduleWidgets(_name: string): var {
    return [];
  }

  function barSizeFor(_screenName: string): int {
    return Style.bar.sizeHorizontal;
  }

  function setCenterHoverRevealSuppressed(value: bool): void {
    root.centerHoverRevealSuppressed = value;
  }

  function showTooltip() {}
  function hideTooltip() {}
}
