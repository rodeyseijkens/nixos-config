pragma Singleton
import QtQuick
import Quickshell

// OverlayPanels: which overlay panel is open and on which monitor. Bar
// widgets call toggle()/open(); PanelHost renders the active panel through a
// single ScreenPopup. Popups read the readonly state and never write it.
Singleton {
  id: root

  property string _active: ""
  property string _screenName: ""
  property real _anchorX: -1

  readonly property string active: _active
  readonly property string screenName: _screenName
  readonly property real anchorX: _anchorX

  function _resolveScreen(name: var): string {
    if (name !== undefined && name !== null && name !== "")
      return name;
    if (root._screenName !== "")
      return root._screenName;
    var all = Quickshell.screens;
    return all.length > 0 ? (all[0].name ?? "") : "";
  }

  function isOpen(name: string, screen: var): bool {
    if (root._active !== name)
      return false;
    if (screen === undefined || screen === null || screen === "")
      return true;
    return root._screenName === screen;
  }

  // anchorX is the screen x of the widget that opened the panel, so the
  // popup can sit above it. Omit it for keyboard/API callers; -1 centres
  // the popup with the placement's own margins.
  function open(name: string, screenName: var, anchorX: real): void {
    root._screenName = root._resolveScreen(screenName);
    root._anchorX = anchorX === undefined || anchorX === null ? -1 : anchorX;
    root._active = name;
  }

  function toggle(name: string, screenName: var, anchorX: real): void {
    var s = root._resolveScreen(screenName);
    if (root._active === name && root._screenName === s) {
      root._active = "";
      root._screenName = "";
      root._anchorX = -1;
    } else {
      root._screenName = s;
      root._anchorX = anchorX === undefined || anchorX === null ? -1 : anchorX;
      root._active = name;
    }
  }

  function close(): void {
    root._active = "";
    root._screenName = "";
    root._anchorX = -1;
  }
}
