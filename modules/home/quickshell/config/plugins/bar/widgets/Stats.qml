import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../services"

RowLayout {
  id: root
  spacing: 0

  // shared stat block: colored rich-text label with hover dim and a
  // per-instance click action
  component StatText: Text {
    id: stat
    Layout.rightMargin: 10
    textFormat: Text.RichText
    font.bold: true
    font.family: Colors.fontFamily
    color: Colors.base05

    property int acceptButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    property var clickAction: null

    MouseArea {
      anchors.fill: parent
      acceptedButtons: stat.acceptButtons
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onEntered: stat.opacity = 0.6
      onExited: stat.opacity = 1.0
      onClicked: mouse => {
        if (stat.clickAction !== null)
          stat.clickAction(mouse);
      }
    }
  }

  Process {
    id: statProc
    command: ["sh", "-c", "grep 'cpu ' /proc/stat; free -b | awk '/Mem:/ {print $2, $3}'; df -B1 / | awk 'NR==2 {print $3, $2}'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var r = Lib.parseStats(text, root._prevTotal, root._prevIdle);
        if (r.cpuPct >= 0)
          root.cpuPct = r.cpuPct;
        root._prevTotal = r.prevTotal;
        root._prevIdle = r.prevIdle;
        if (r.memPct >= 0) {
          root.memPct = r.memPct;
          root.memUsedGiB = r.memUsedGiB;
        }
        if (r.diskPct >= 0)
          root.diskPct = r.diskPct;
      }
    }
  }

  property int cpuPct: 0
  property string cpuFreq: ""
  property bool showCpuAlt: false
  property int memPct: 0
  property string memUsedGiB: "0.0"
  property bool showMemAlt: false
  property int diskPct: 0
  property real _prevTotal: 0
  property real _prevIdle: 0

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: statProc.running = true
  }

  StatText {
    text: "<font color='" + Colors.base0D + "'></font> " + (root.showCpuAlt && root.cpuFreq !== "" ? root.cpuFreq + " GHz" : root.cpuPct + "%")
    clickAction: mouse => {
      if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton)
        btopProc.running = true;
      else
        freqProc.running = true;
    }
  }

  StatText {
    text: "<font color='" + Colors.base0C + "'>󰟜 </font>" + (root.showMemAlt ? root.memUsedGiB + " GiB" : root.memPct + "%")
    clickAction: mouse => {
      if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton)
        btopProc.running = true;
      else
        root.showMemAlt = !root.showMemAlt;
    }
  }

  StatText {
    acceptButtons: Qt.RightButton | Qt.MiddleButton
    text: "<font color='" + Colors.base0F + "'>󰋊 </font>" + root.diskPct + "%"
    clickAction: mouse => btopProc.running = true
  }

  // waybar parity: same float + terminal (launch via hl.dsp: hyprctl dispatch
  // no longer accepts legacy syntax under Hyprland ≥0.55 Lua configs).
  Process {
    id: btopProc
    command: ["hyprctl", "dispatch", "hl.dsp.exec_cmd('[float; center; size 950 650] ghostty -e btop')"]
  }

  Process {
    id: freqProc
    command: ["sh", "-c", "awk -F': ' '/cpu MHz/ {s+=$2; n++} END {if (n>0) printf \"%.2f\", s/n/1000}' /proc/cpuinfo"]
    stdout: StdioCollector {
      onStreamFinished: {
        var ghz = text.trim();
        if (ghz !== "")
          root.cpuFreq = ghz;
        root.showCpuAlt = !root.showCpuAlt;
      }
    }
  }
}
