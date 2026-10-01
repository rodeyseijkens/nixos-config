pragma Singleton
import Quickshell
import QtQuick

// OsdBus: the channel every keybind and IPC event uses to flash the OSD —
// holds the current OSD state and owns show/auto-hide timing —
// each showOsd restarts the hide timer, so rapid repeats just extend it.
Singleton {
  id: bus

  // QML has no access modifiers: _-prefixed members are internal to this module.
  property string _kind: ""
  property real _value: 0
  property real _max: 100
  property string _icon: ""
  property string _label: ""
  property bool _visible: false

  readonly property string kind: _kind
  readonly property real value: _value
  readonly property real max: _max
  readonly property string icon: _icon
  readonly property string label: _label
  readonly property bool visible: _visible

  Timer {
    id: hideTimer
    interval: 2000
    onTriggered: bus._visible = false
  }

  function showOsd(kind: string, value: real, max: real, icon: string, label: string): void {
    bus._kind = kind;
    bus._value = value;
    bus._max = max > 0 ? max : 100;
    bus._icon = icon;
    bus._label = label;
    bus._visible = true;
    hideTimer.restart();
  }

  function hideOsd(): void {
    _visible = false;
  }
}
