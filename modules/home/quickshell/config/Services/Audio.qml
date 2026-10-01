pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick

// Audio: the single source for what the system sounds like — volume
// percent, mute state, and the volume icon glyph from the Pipewire default
// sink. The Bar's volume widget and the OSD both consume it; changes are
// applied through pamixer.
Singleton {
  id: audio

  // QML has no access modifiers: _-prefixed members are internal to this module.
  property PwNode _sink: Pipewire.defaultAudioSink

  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  // One volume number: clamp to 0–100, round for display.
  readonly property int percent: _sink != null && _sink.audio != null
      ? Math.round(Math.max(0, Math.min(100, _sink.audio.volume * 100)))
      : 0
  readonly property bool muted: _sink != null && _sink.audio != null ? _sink.audio.muted : false

  // NF md volume family, all verified present in Maple Mono NF CN:
  // mute \uf075f, low \uf057f, medium \uf0580, high \uf057e.
  function iconOf(pct: int, isMuted: bool): string {
    if (isMuted)
      return "\u{f075f}";
    if (pct >= 66)
      return "\u{f057e}";
    if (pct >= 33)
      return "\u{f0580}";
    return "\u{f057f}";
  }
  readonly property string icon: iconOf(percent, muted)

  // Emitted after each applied change, carrying the values read back from
  // pamixer (fresher than the reactive Pipewire binding at emit time).
  signal actionApplied(pct: int, isMuted: bool)

  // One runner: each call swaps the command and spawns once — the pamixer
  // action and its read-back share that spawn, so consumers get fresh state,
  // not the pre-change pipewire event. ("--get-volume-human" prints "<n>%"
  // normally and the literal string "muted" when muted.)
  Process {
    id: runner
    command: []
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.trim().split("\n");
        var pct = lines.length > 0 && lines[0].endsWith("%") ? parseInt(lines[0]) : 0;
        var isMuted = lines.length > 1 ? lines[1].trim() === "true" : audio.muted;
        audio.actionApplied(pct, isMuted);
      }
    }
  }

  function step(n: int): void {
    runner.command = ["sh", "-c", "pamixer " + (n > 0 ? "-i" : "-d") + " " + Math.abs(n) + " --set-limit 100 --allow-boost; pamixer --get-volume-human; pamixer --get-mute"];
    runner.running = true;
  }

  function toggleMute(): void {
    runner.command = ["sh", "-c", "pamixer -t; pamixer --get-volume-human; pamixer --get-mute"];
    runner.running = true;
  }
}
