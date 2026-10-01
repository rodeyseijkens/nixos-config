pragma Singleton
import Quickshell

// Preferences: the shell's user-facing toggles — Do Not Disturb and Bar
// visibility. State changes only through the toggle functions.
Singleton {
  id: prefs

  // QML has no access modifiers: _-prefixed members are internal to this module.
  property bool _dnd: false
  property bool _barVisible: true

  readonly property bool dnd: _dnd
  readonly property bool barVisible: _barVisible

  function toggleDnd(): void {
    _dnd = !_dnd;
  }

  function toggleBar(): void {
    _barVisible = !_barVisible;
  }
}
