pragma Singleton
import Quickshell
import QtQuick

// OsdBus: the channel every keybind and IPC event uses to flash the OSD —
// holds the current OSD state and owns show/auto-hide timing —
// each showOsd restarts the hide timer, so rapid repeats just extend it.
Singleton {
  id: bus

  readonly property int legacyDuration: 2000
  readonly property int defaultDuration: 1200

  // QML has no access modifiers: _-prefixed members are internal to this module.
  property string _kind: ""
  property real _value: 0
  property real _max: 100
  property string _icon: ""
  property string _label: ""
  property string _message: ""
  property bool _hasProgress: false
  property string _progressText: ""
  property int _duration: 0
  property bool _visible: false

  readonly property string kind: _kind
  readonly property real value: _value
  readonly property real max: _max
  readonly property string icon: _icon
  readonly property string label: _label
  readonly property string message: _message
  readonly property bool hasProgress: _hasProgress
  readonly property string progressText: _progressText
  readonly property int duration: _duration
  readonly property bool visible: _visible

  Timer {
    id: hideTimer
    interval: bus._duration
    onTriggered: bus._visible = false
  }

  function present(duration: int): void {
    bus._duration = duration;
    bus._visible = true;
    if (duration > 0)
      hideTimer.restart();
    else
      hideTimer.stop();
  }

  function showOsd(kind: string, value: real, max: real, icon: string, label: string): void {
    var progress = kind === "volume" || kind === "brightness";
    bus._kind = kind;
    bus._value = value;
    bus._max = max > 0 ? max : 100;
    bus._icon = icon;
    bus._label = label;
    bus._message = progress ? "" : label;
    bus._hasProgress = progress;
    bus._progressText = "";
    present(legacyDuration);
  }

  function show(payload: var): void {
    if (typeof payload === "string") {
      showJson(payload);
      return;
    }

    var p = payload || {};
    var iconName = p.icon === undefined || p.icon === null ? "" : String(p.icon);
    var message = p.message === undefined || p.message === null ? "" : String(p.message);
    var rawValue = p.value;
    var hasValue = rawValue !== undefined && rawValue !== null && String(rawValue) !== "";
    var parsedValue = hasValue ? parseInt(String(rawValue), 10) : NaN;
    var rawMax = p.max === undefined || p.max === null ? "100" : String(p.max);
    var parsedMax = parseInt(rawMax, 10);
    var maxValue = isNaN(parsedMax) || parsedMax < 1 ? 100 : parsedMax;
    var hasProgress = hasValue && !isNaN(parsedValue) && message === "";
    var value = hasProgress ? Math.max(0, Math.min(maxValue, parsedValue)) : 0;
    var percent = hasProgress ? Math.round(value * 100 / maxValue) : -1;
    var progressText = p.progressText === undefined || p.progressText === null ? "" : String(p.progressText);
    var displayMessage = message;
    if (displayMessage === "" && hasProgress)
      displayMessage = progressText !== "" ? progressText : percent + "%";

    var rawDuration = p.duration === undefined || p.duration === null ? defaultDuration : String(p.duration);
    var parsedDuration = parseInt(rawDuration, 10);
    var duration = isNaN(parsedDuration) ? defaultDuration : Math.max(0, parsedDuration);

    bus._kind = p.kind === undefined || p.kind === null ? "" : String(p.kind);
    bus._value = value;
    bus._max = maxValue;
    bus._icon = iconFor(iconName, percent);
    bus._label = displayMessage;
    bus._message = displayMessage;
    bus._hasProgress = hasProgress;
    bus._progressText = progressText;
    present(duration);
  }

  function showJson(json: string): void {
    var payload = {};
    try {
      payload = JSON.parse(json || "{}");
    } catch (error) {
      console.warn("OsdBus.showJson: " + error);
      return;
    }
    show(payload);
  }

  function iconFor(name: string, percent: int): string {
    var n = String(name || "").toLowerCase();
    if (n === "volume-muted" || n === "volume-mute" || n === "muted" || n === "mute")
      return "\ueee8";
    if (n === "volume-low")
      return "\uf026";
    if (n === "volume-medium")
      return "\uf027";
    if (n === "volume-high" || n === "volume")
      return "\uf028";
    if (n === "microphone-muted" || n === "microphone-off" || n === "mic-muted" || n === "mic-off")
      return "\uf036d";
    if (n === "microphone" || n === "mic")
      return "\uf036c";
    if (n === "keyboard")
      return "\uf030c";
    if (n === "brightness" || n === "display")
      return "\uf0379";
    if (n === "touchpad")
      return "\uf07f8";
    if (n === "touch" || n === "touchscreen")
      return "\uf0741";
    if (n === "reboot" || n === "restart")
      return "\uf0709";
    if (n === "shutdown" || n === "power" || n === "poweroff")
      return "\uf0425";
    if (n === "logout" || n === "sign-out" || n === "leave")
      return "\uf0343";
    if (n === "media" || n === "player")
      return "\uf075a";
    if (n === "media-source" || n === "player-source")
      return "\uf075a";
    if (n === "media-play" || n === "player-play")
      return "\uf040a";
    if (n === "media-pause" || n === "player-pause")
      return "\uf03e4";
    if (n === "media-next" || n === "player-next")
      return "\uf04ad";
    if (n === "media-previous" || n === "player-previous")
      return "\uf04ae";
    if (n.length > 0)
      return name;
    if (percent <= 0)
      return "\ueee8";
    if (percent <= 33)
      return "\uf026";
    if (percent <= 66)
      return "\uf027";
    return "\uf028";
  }

  function hideOsd(): void {
    _visible = false;
  }
}
