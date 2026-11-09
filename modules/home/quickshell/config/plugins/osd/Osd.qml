import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../../services"
import "../../"

// OSD: the on-screen display that flashes a brief indicator — volume,
// brightness, lock state — when a bound key or IPC event changes something.
Scope {
  id: osd

  ScreenPopup {
    placement: PopupPlacement {
      bottom: true
      marginBottom: 80
      width: 280
      height: 64
    }
    showWhen: (name) => OsdBus.visible

    content: Component {
      Rectangle {
        anchors.fill: parent
        color: Colors.base01
        border.color: Colors.base04
        border.width: 1

        Row {
          anchors.centerIn: parent
          spacing: 12

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: OsdBus.icon
            font.pixelSize: 24
            font.family: Colors.fontFamily
            color: Colors.base07
          }

          ProgressBar {
            id: osdBar
            visible: OsdBus.hasProgress
            anchors.verticalCenter: parent.verticalCenter
            width: 180
            from: 0
            to: OsdBus.max
            value: OsdBus.value

            // gruvbox base0D green — same tint the bar volume icon follows via Audio
            contentItem: Item {
              implicitHeight: 8
              implicitWidth: 180

              Rectangle {
                width: parent.width
                height: parent.height
                color: Colors.base03
              }
              Rectangle {
                width: parent.width * (osdBar.value / osdBar.to)
                height: parent.height
                color: Colors.base0D
              }
            }
            background: Rectangle {
              color: "transparent"
            }
          }

          Text {
            // volume/brightness are icon+bar only; lock-key OSDs keep their text
            visible: OsdBus.message !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, OsdBus.hasProgress ? 48 : 200)
            horizontalAlignment: OsdBus.hasProgress ? Text.AlignRight : Text.AlignLeft
            text: OsdBus.message
            font.bold: true
            font.family: Colors.fontFamily
            color: Colors.base07
            elide: Text.ElideRight
            maximumLineCount: 1
          }
        }
      }
    }
  }

  Process {
    id: brightGet
    command: ["sh", "-c", "brightnessctl get; brightnessctl max"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.trim().split("\n");
        if (lines.length >= 2) {
          var cur = parseFloat(lines[0]);
          var max = parseFloat(lines[1]);
          if (max > 0)
            OsdBus.showOsd("brightness", Lib.brightnessPct(cur, max), 100, "󰃠", "Brightness");
        }
      }
    }
  }

  // Volume icon mapping lives in Audio (iconOf); the OSD just flashes it.

  Connections {
    target: Audio
    function onActionApplied(pct: int, isMuted: bool): void {
      OsdBus.showOsd("volume", pct, 100, Audio.iconOf(pct, isMuted), isMuted ? "Muted" : "Volume");
    }
  }

  // NF md lock glyphs, verified present in Maple Mono NF CN:
  // locked \uf033e, unlocked \uf0fc6.
  readonly property string iconLock: "\u{f033e}"
  readonly property string iconUnlock: "\u{f0fc6}"

  readonly property var lockKinds: ["caps", "scroll", "num"]
  readonly property var lockLabels: ["Caps Lock", "Scroll Lock", "Num Lock"]
  // Current LED state per lock key, synced by lockPoll's first read (no flash).
  property var lockStates: [null, null, null]

  function osdFlash(i: int): void {
    var on = lockStates[i] === true;
    OsdBus.showOsd(lockKinds[i], on ? 1 : 0, 1, on ? iconLock : iconUnlock, lockLabels[i]);
  }

  // Lock-key state is read straight from the LEDs: the kernel toggles the
  // LED on key press, so polling needs no hyprland bind and reports the
  // post-toggle state. Emits only when a state changes; first read is silent.
  Process {
    id: lockPoll
    running: true
    command: ["sh", "-c", "last=; while :; do line=''; for k in capslock scrolllock numlock; do for f in /sys/class/leds/*::\"$k\"/brightness; do line=\"$line$(cat \"$f\" 2>/dev/null)\"; done; done; if [ \"$line\" != \"$last\" ]; then echo \"$line\"; last=\"$line\"; fi; sleep 0.25; done"]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        // Every LED exists per keyboard device, in sync; take any flip.
        var s = data.replace(/\s+/g, "");
        if (s.length === 0 || s.length % 3 !== 0)
          return;
        var per = s.length / 3;
        for (var i = 0; i < 3; i++) {
          var on = s.substr(i * per, per).indexOf("1") !== -1;
          if (osd.lockStates[i] === null) {
            osd.lockStates[i] = on;
          } else if (osd.lockStates[i] !== on) {
            osd.lockStates[i] = on;
            osd.osdFlash(i);
          }
        }
      }
    }
  }

  IpcHandler {
    target: "osd"

    function volume(action: string): void {
      if (action === "up" || action === "raise")
        Audio.step(5);
      else if (action === "down" || action === "lower")
        Audio.step(-5);
      else if (action === "small-up")
        Audio.step(2);
      else if (action === "small-down")
        Audio.step(-2);
      else if (action === "mute-toggle")
        Audio.toggleMute();
    }

    function brightness(action: string): void {
      const arg = {
        "up": "5%+",
        "down": "5%-",
        "max": "100%",
        "min": "0%"
      }[action];
      if (arg != null) {
        brightAction.command = ["brightnessctl", "set", arg];
        brightAction.running = true;
      }
    }

    function caps(): void {
      osdFlash(0);
    }
    function scroll(): void {
      osdFlash(1);
    }
    function num(): void {
      osdFlash(2);
    }

    function show(payloadJson: string): string {
      OsdBus.showJson(payloadJson);
      return "ok";
    }

    function close(): string {
      OsdBus.hideOsd();
      return "ok";
    }

    function state(): string {
      return OsdBus.visible ? "open" : "closed";
    }

    function ping(): string {
      return "ok";
    }
  }

  // Brightness runner: the IPC handler swaps `command` per call and the
  // exited handler chains the re-read.
  Process {
    id: brightAction
    command: []
    onExited: brightGet.running = true
  }
}
