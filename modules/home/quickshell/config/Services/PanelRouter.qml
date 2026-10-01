pragma Singleton
import Quickshell

// PanelRouter: decides whether the notification panel and the calendar are
// open, and on which monitor's screen they appear. All open/close/toggle
// decisions go through it; popups bind to the readonly state and never write it.
Singleton {
  id: router

  // QML has no access modifiers: _-prefixed members are internal to this module.
  property bool _panelOpen: false
  property string _panelScreenName: ""
  property bool _calendarOpen: false
  property string _calendarScreenName: ""

  readonly property bool panelOpen: _panelOpen
  readonly property string panelScreenName: _panelScreenName
  readonly property bool calendarOpen: _calendarOpen
  readonly property string calendarScreenName: _calendarScreenName

  // Falls back to the already-open screen, then the first screen, so
  // parameterless IPC callers (keybinds) keep working.
  // NOTE: must be the qualified Quickshell.screens — the bare global does not
  // resolve inside a Singleton (ReferenceError: screens is not defined).
  function _resolveScreen(name: var, current: string): string {
    if (name !== undefined && name !== null && name !== "")
      return name;
    if (current !== undefined && current !== null && current !== "")
      return current;
    var all = Quickshell.screens;
    return all.length > 0 ? (all[0].name ?? "") : "";
  }

  function togglePanel(screenName: var): void {
    var s = _resolveScreen(screenName, _panelScreenName);
    if (_panelOpen && _panelScreenName === s) {
      _panelOpen = false;
    } else {
      _panelScreenName = s;
      _panelOpen = true;
    }
  }

  function openPanel(screenName: var): void {
    _panelScreenName = _resolveScreen(screenName, _panelScreenName);
    _panelOpen = true;
  }

  function closePanel(): void {
    _panelOpen = false;
  }

  function toggleCalendar(screenName: var): void {
    var s = _resolveScreen(screenName, _calendarScreenName);
    if (_calendarOpen && _calendarScreenName === s) {
      _calendarOpen = false;
    } else {
      _calendarScreenName = s;
      _calendarOpen = true;
    }
  }

  function closeCalendar(): void {
    _calendarOpen = false;
  }
}
